
include {
    hdf5_to_tiff;
} from '../processes/synapse_detection'

include {
    classify_and_connect_regions as classify_and_connect_presynaptic_n1_regions;
    classify_and_connect_regions as classify_and_connect_presynaptic_regions
    connect_regions_in_volume as mask_with_n2;
} from './segmentation_tools'

include {
    merge_2_channels;
    merge_4_channels;
    merge_7_channels;
} from '../processes/utils'

include {
    tiff_to_h5_with_metadata as synapse_tiff_to_h5;
    tiff_to_h5_with_metadata as neuron1_tiff_to_h5;
    tiff_to_h5_with_metadata as neuron2_tiff_to_h5;
    tiff_to_h5_with_metadata as pre_synapse_tiff_to_h5;
    tiff_to_h5_with_metadata as post_synapse_tiff_to_h5;
} from './tiff_to_h5'

include {
    index_channel;
} from '../utils/utils'

workflow presynaptic_in_volume {
    take:
    synapse_stack_dir
    output_dir

    main:
    def tmp_volumes_subfolder = 'tmp'
    def synapse_data = synapse_tiff_to_h5(
        synapse_stack_dir, // synapse
        output_dir.map { "${it}/${tmp_volumes_subfolder}/synapse.h5" }
    ) // [ synapse_tiff_stack, synapse_h5_file, synapse_volume ]
    | join(merge_2_channels(synapse_stack_dir, output_dir), by:0)
    // [ synapse_tiff_stack, synapse_h5_file, synapse_volume, output_dir ]

    def presynaptic_vol_regions = classify_and_connect_presynaptic_regions(
        synapse_data.map { it[1] }, // synapse
        synapse_data.map { it[2] }, // synapse_vol
        params.synapse_model,
        '', // no neuron mask
        [width:0, height:0, depth:0], // 0 neuron volume
        synapse_data.map { "${it[3]}/${tmp_volumes_subfolder}/synapse_seg.h5" },
        synapse_data.map { "${it[3]}/${tmp_volumes_subfolder}/synapse_seg_post.h5" }
    ) // [ synapse, synapse_vol, mask, mask_vol, seg_synapse, post_seg_synapse ]
    | map {
        // drop mask and mask_vol as they don't contain any information
        def synapse_image = file(it[0])
        [
            it[0], it[1], // synapse, synapse_vol
            it[4], // seg_synapse
            it[5], // post_seg_synapse
            "${synapse_image.parent.parent}", // output_dir 
        ]
    } // [ synapse, synapse_vol, synapse_seg, post_synapse_seg, output_dir ]

    emit:
    done = post_synapse_seg_results
}

workflow presynaptic_n1_to_n2 {
    take:
    synapse_stack_dir
    neuron1_stack_dir
    neuron2_stack_dir
    output_dir

    main:
    def tmp_volumes_subfolder = 'tmp'
    def input_data = merge_4_channels(synapse_stack_dir, neuron1_stack_dir, neuron2_stack_dir, output_dir)
    // [ synapse_tiff_stack, n1_tiff_stack, n2_tiff_stack, output_dir ]

    def synapse_data = synapse_tiff_to_h5(
        synapse_stack_dir, // synapse
        output_dir.map { "${it}/${tmp_volumes_subfolder}/synapse.h5" }
    ) // [ synapse_tiff_stack, synapse_h5_file, synapse_volume ]
    | map {
        def h5_file = it[2]
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, h5_file, volume ]

    def n1_data = neuron1_tiff_to_h5(
        neuron1_stack_dir, // n1
        output_dir.map { "${it}/${tmp_volumes_subfolder}/n1_mask.h5" }
    ) // [ neuron1_tiff_stack, neuron1_h5_file, neuron1_volume ]
    | map {
        def h5_file = it[2]
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, h5_file, volume ]

    def n2_data = neuron2_tiff_to_h5(
        neuron2_stack_dir, // n2
        output_dir.map { "${it}/${tmp_volumes_subfolder}/n2_mask.h5" }
    ) // [ neuron2_tiff_stack, neuron2_h5_file, neuron2_volume ]
    | map {
        def h5_file = it[2]
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, h5_file, volume ]

    def synapse_inputs = synapse_data
    | join(n1_data, by:0)
    | join(n2_data, by:0) 
    // [ working_dir, synapse_tiff, synapse_h5, synapse_vol, n1_tiff, n1_h5, n1_vol, n2_tiff, n2_h5, n2_vol ]

    def synapses_results = find_synapses_from_n1_to_n2(
        synapse_inputs.map { it[2] }, // synapse_file
        synapse_inputs.map { it[3] }, // synapse_vol
        synapse_inputs.map { it[5] }, // n1
        synapse_inputs.map { it[6] }, // n1_vol
        synapse_inputs.map { it[8] }, // n2
        synapse_inputs.map { it[9] }, // n2_vol
        synapse_inputs.map { it[0] }  // working_dir
    )

    emit:
    done = synapses_results
}

// Workflow C - Neuron 1 presynaptic to Neuron 2 restricted post synaptic
workflow presynaptic_n1_to_postsynaptic_n2 {
    take:
    pre_synapse_stack_dir
    neuron1_stack_dir
    post_synapse_stack_dir
    output_dir

    main:
    def tmp_volumes_subfolder = 'tmp'
    def input_data = merge_4_channels(pre_synapse_stack_dir, neuron1_stack_dir, post_synapse_stack_dir, output_dir)
    // [ synapse_tiff_stack, n1_tiff_stack, n2_tiff_stack, output_dir ]

    def pre_synapse_data = pre_synapse_tiff_to_h5(
        pre_synapse_stack_dir, // pre_synapse
        output_dir.map { "${it}/${tmp_volumes_subfolder}/pre_synapse.h5" }
    ) // [ pre_synapse_tiff_stack, pre_synapse_h5_file, pre_synapse_volume ]
    | map {
        def h5_file = it[2]
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, h5_file, volume ]

    def n1_data = neuron1_tiff_to_h5(
        neuron1_stack_dir, // n1
        output_dir.map { "${it}/${tmp_volumes_subfolder}/n1_mask.h5" }
    ) // [ neuron1_tiff_stack, neuron1_h5_file, neuron1_volume ]
    | map {
        def h5_file = it[2]
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, h5_file, volume ]

    def post_synapse_data = post_synapse_tiff_to_h5(
        post_synapse_stack_dir, // post_synapse
        output_dir.map { "${it}/${tmp_volumes_subfolder}/post_synapse.h5" }
    ) // [ post_synapse_tiff_stack, post_synapse_h5_file, post_synapse_volume ]
    | map {
        def h5_file = it[2]
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, h5_file, volume ]

    def synapse_inputs = pre_synapse_data
    | join(n1_data, by:0)
    | join(post_synapse_data, by:0) 
    // [ working_dir, pre_synapse_tiff, pre_synapse_h5, pre_synapse_vol, n1_tiff, n1_h5, n1_vol, post_synapse_tiff, post_synapse_h5, post_synapse_vol ]

    emit:
    done = synapse_inputs
}


workflow find_synapses_from_n1_to_n2 {
    take:
    synapse_filename
    synapse_vol
    n1_filename
    n1_vol
    n2_filename
    n2_vol
    output_dir

    main:
    def synapse_seg_inputs = merge_7_channels(
        synapse_filename,
        synapse_vol,
        n1_filename,
        n1_vol,
        n2_filename,
        n2_vol,
        output_dir
    )

    def presynaptic_n1_regions = classify_and_connect_presynaptic_n1_regions(
        synapse_filename,
        synapse_vol,
        params.synapse_model,
        n1_filename,
        n1_vol,
        output_dir.map { "${it}/synapse_seg.h5" },
        output_dir.map { "${it}/synapse_seg_n1.h5" },
    ) // [ synapse, synapse_vol, n1, n1_vol, seg_synapse, n1_seg_synapse ]

    presynaptic_n1_regions.subscribe { log.debug "Pre-synaptic n1 results: $it" }

    def mask_n2_inputs = presynaptic_n1_regions
    | join(synapse_seg_inputs, by:[0:3])
    | map {
        // [ synapse, synapse_vol, n1, n1_vol, synapse_seg, synapse_seg_n1, n2, n2_vol, output_dir ]
        // rearrange them to be able to join these with the results
        [ it[5], it[1], it[6], it[7], it[0], it[4], it[2], it[3], it[8] ]
    } // [ synapse_seg_n1, synapse_vol, n2, n2_vol, synapse, synapse_seg, n1, n1_vol, output_dir ]
    
    def synapse_n1_n2_results = mask_with_n2(
        mask_n2_inputs.map { it[0] }, // synapse_seg_n1
        mask_n2_inputs.map { it[1] }, // synapse vol
        mask_n2_inputs.map { it[2] }, // n2
        mask_n2_inputs.map { it[3] }, // n2_vol
        mask_n2_inputs.map { "${it[8]}/synapse_seg_n1_n2.h5" }
    ) // [ synapse_seg_n1, synapse_vol, n2, n2_vol, synapse_seg_n1_n2 ]
    join(mask_n2_inputs, by:[0..3])
    | map {
        // [ synapse_seg_n1, synapse_vol, n2, n2_vol, synapse_seg_n1_n2, synapse, synapse_seg, n1, n1_vol, output_dir ]
        // rearrange the final results
        [ 
            it[5], it[1],// synapse, synapse_vol
            it[7], it[8], // n1, n1_vol
            it[2], it[3], // n2, n2_vol
            it[6], // synapse_seg
            it[0], // synapse_seg_n1
            it[4], // synapse_seg_n1_n2
            it[9], // output_dir
        ]
    } // [ synapse, synapse_vol, n1, n1_vol, n2, n2_vol, synapse_seg, synapse_seg_n1, synapse_seg_n1_n2, output_dir ]

    emit:
    done = synapse_n1_n2_results
}
