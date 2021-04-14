
include {
    hdf5_to_tiff;
} from '../processes/synapse_detection'

include {
    classify_and_connect_regions_in_volume as classify_and_connect_presynaptic_n1_regions;
    classify_and_connect_regions_in_volume as classify_and_connect_presynaptic_regions
    classify_and_connect_regions_in_volume as classify_and_connect_postsynaptic_n2_regions;
    connect_regions_in_volume as mask_with_n2;
} from './segmentation_tools'

include {
    merge_2_channels;
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

// workflow presynaptic_in_volume {
//     take:
//     synapse_stack_dir
//     output_dir

//     main:
//     def tmp_volumes_subfolder = 'tmp'
//     def synapse_data = synapse_tiff_to_h5(
//         synapse_stack_dir, // synapse
//         output_dir.map { "${it}/${tmp_volumes_subfolder}/synapse.h5" }
//     ) // [ synapse_tiff_stack, synapse_h5_file, synapse_volume ]
//     | join(merge_2_channels(synapse_stack_dir, output_dir), by:0)
//     // [ synapse_tiff_stack, synapse_h5_file, synapse_volume, output_dir ]

//     def presynaptic_vol_regions = classify_and_connect_presynaptic_regions(
//         synapse_data.map { it[1] }, // synapse
//         synapse_data.map { it[2] }, // synapse_vol
//         params.synapse_model,
//         '', // no neuron mask
//         [width:0, height:0, depth:0], // 0 neuron volume
//         synapse_data.map { "${it[3]}/${tmp_volumes_subfolder}/synapse_seg.h5" },
//         synapse_data.map { "${it[3]}/${tmp_volumes_subfolder}/synapse_seg_post.h5" }
//     ) // [ synapse, synapse_vol, mask, mask_vol, seg_synapse, post_seg_synapse ]
//     | map {
//         // drop mask and mask_vol as they don't contain any information
//         def synapse_image = file(it[0])
//         [
//             it[0], it[1], // synapse, synapse_vol
//             it[4], // seg_synapse
//             it[5], // post_seg_synapse
//             "${synapse_image.parent.parent}", // output_dir 
//         ]
//     } // [ synapse, synapse_vol, synapse_seg, post_synapse_seg, output_dir ]

//     emit:
//     done = post_synapse_seg_results
// }

workflow presynaptic_n1_to_n2 {
    take:
    input_data // channel of tuples [ presynapse_image, n1_mask, n2_mask, output_dir ]

    main:
    def tmp_volumes_subfolder = 'tmp'

    def synapse_data = input_data
    | map {
        def (synapse_tiff, n1_mask_tiff, n2_mask_tiff, output_dir) = it
        [ synapse_tiff, "${output_dir}/${tmp_volumes_subfolder}/synapse.h5" ]
    }
    | synapse_tiff_to_h5 // [ synapse_stack, synapse_h5, synapse_size ]
    | map {
        def h5_file = file(it[1])
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, h5_file, size ]

    def n1_data = input_data
    | map {
        def (synapse_tiff, n1_mask_tiff, n2_mask_tiff, output_dir) = it
        [ n1_mask_tiff, "${output_dir}/${tmp_volumes_subfolder}/n1_mask.h5" ]
    }
    | neuron1_tiff_to_h5 // [ n1_mask_stack, n1_mask_h5, n1_size ]
    | map {
        def h5_file = file(it[1])
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, h5_file, size ]

    def n2_data = input_data
    | map {
        def (synapse_tiff, n1_mask_tiff, n2_mask_tiff, output_dir) = it
        [ n2_mask_tiff, "${output_dir}/${tmp_volumes_subfolder}/n2_mask.h5" ]
    }
    | neuron2_tiff_to_h5 // [ n2_mask_stack, n2_mask_h5, n2_size ]
    | map {
        def h5_file = file(it[1])
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, h5_file, size ]

    def synapse_inputs = synapse_data
    | join(n1_data, by:0)
    | join(n2_data, by:0) 
    // [ working_dir, synapse_tiff, synapse_h5, synapse_size, n1_tiff, n1_h5, n1_size, n2_tiff, n2_h5, n2_size ]

    def presynaptic_n1_regions = synapse_inputs
    | map {
        def (working_dir, synapse_tiff, synapse, synapse_size, n1_tiff, n1, n1_size) = it
        [ synapse_h5, synapse_size, n1, n1_size, "${working_dir}/synapse_seg.h5", "${working_dir}/synapse_seg_n1.h5" ]
    }
    | classify_and_connect_presynaptic_n1_regions
    | map {
        def h5_file = file(it[1])
        [ "${h5_file.parent}" ] + it
    } // [ working_dir, synapse, synapse_size, n1, n1_size, synapse_seg, synapse_seg_n1 ]

    def mask_n2_inputs = synapse_inputs
    | join(presynaptic_n1_regions)

    def synapse_n1_n2_results = mask_n2_inputs
    | map {
        def (working_dir, synapse_tiff, synapse, synapse_size, n1_tiff, n1, n1_size, n2_tiff, n2, n2_size) = it
        [ "${working_dir}/synapse_seg_n1.h5", synapse_size, n2, n2_size, "${working_dir}/synapse_seg_n1_n2.h5" ]
    }
    | mask_with_n2
    | map {
        def h5_file = file(it[1])
        [ "${h5_file.parent}" ] + it
    }  // [ working_dir, synapse_seg_n1, synapse_size, n2, n2_size, synapse_seg_n1_n2 ]

    // prepare the final result
    done = synapse_inputs
    | join(synapse_n1_n2_results, by: 0)
    | map {
        def (working_path, synapse_tiff, synapse, synapse_size, n1_tiff, n1, n1_size, n2_tiff, n2, n2_size) = it
        def working_dir = file(working_path)
        [ 
            synapse, synapse_size, n1, n1_size, n2, n2_size, 
            "${working_dir}/synapse_seg.h5", "${working_dir}/synapse_seg_n1.h5", "${working_dir}/synapse_seg_n1_n2.h5",
            "${working_dir.parent}",
        ]
    }  // [ synapse, synapse_vol, n1, n1_vol, n2, n2_vol, synapse_seg, synapse_seg_n1, synapse_seg_n1_n2, output_dir ]
    
    emit:
    done
}

// Workflow C - Neuron 1 presynaptic to Neuron 2 restricted post synaptic
// workflow presynaptic_n1_to_postsynaptic_n2 {
//     take:
//     pre_synapse_stack_dir
//     neuron1_stack_dir
//     post_synapse_stack_dir
//     output_dir

//     main:
//     def tmp_volumes_subfolder = 'tmp'

//     def pre_synapse_data = pre_synapse_tiff_to_h5(
//         pre_synapse_stack_dir, // pre_synapse
//         output_dir.map { "${it}/${tmp_volumes_subfolder}/pre_synapse.h5" }
//     ) // [ pre_synapse_tiff_stack, pre_synapse_h5_file, pre_synapse_volume ]
//     | map {
//         def h5_file = file(it[1])
//         [ "${h5_file.parent}" ] + it
//     } // [ working_dir, tiff_stack, h5_file, volume ]

//     def n1_data = neuron1_tiff_to_h5(
//         neuron1_stack_dir, // n1
//         output_dir.map { "${it}/${tmp_volumes_subfolder}/n1_mask.h5" }
//     ) // [ neuron1_tiff_stack, neuron1_h5_file, neuron1_volume ]
//     | map {
//         def h5_file = file(it[1])
//         [ "${h5_file.parent}" ] + it
//     } // [ working_dir, tiff_stack, h5_file, volume ]

//     def post_synapse_data = post_synapse_tiff_to_h5(
//         post_synapse_stack_dir, // post_synapse
//         output_dir.map { "${it}/${tmp_volumes_subfolder}/post_synapse.h5" }
//     ) // [ post_synapse_tiff_stack, post_synapse_h5_file, post_synapse_volume ]
//     | map {
//         def h5_file = file(it[1])
//         [ "${h5_file.parent}" ] + it
//     } // [ working_dir, tiff_stack, h5_file, volume ]

//     def pre_synaptic_n1_inputs = pre_synapse_data
//     | join(n1_data, by:0)
//     | join(post_synapse_data, by:0) 
//     // [ working_dir, pre_synapse_tiff, pre_synapse_h5, pre_synapse_vol, n1_tiff, n1_h5, n1_vol, post_synapse_tiff, post_synapse_h5, post_synapse_vol ]

//     def presynaptic_n1_regions = classify_and_connect_presynaptic_n1_regions(
//         pre_synaptic_n1_inputs.map { it[1] }, // pre_synapse
//         pre_synaptic_n1_inputs.map { it[2] }, // pre_synapse_vol
//         params.synapse_model,
//         pre_synaptic_n1_inputs.map { it[5] }, // n1
//         pre_synaptic_n1_inputs.map { it[6] }, // n1_vol
//         pre_synaptic_n1_inputs.map { "${it[0]}/pre_synapse_seg.h5" },
//         pre_synaptic_n1_inputs.map { "${it[0]}/pre_synapse_seg_n1.h5" },
//     ) // [ pre_synapse, pre_synapse_vol, n1, n1_vol, pre_synapse_seg, pre_synapse_seg_n1 ]
//     | map {
//         def h5_file = file(it[1])
//         [ "${h5_file.parent}" ] + it
//     } // [ working_dir, pre_synapse, pre_synapse_vol, n1, n1_vol, pre_synapse_seg, pre_synapse_seg_n1 ]

//     def post_to_pre_synaptic_inputs = pre_synaptic_n1_inputs
//      | join(presynaptic_n1_regions, by:0)

//     def post_to_pre_synaptic_results = classify_and_connect_postsynaptic_to_presynaptic_n1_regions(
//         pre_synaptic_n1_inputs.map { it[8] }, // post_synapse
//         pre_synaptic_n1_inputs.map { it[9] }, // post_synapse_vol
//         params.synapse_model,
//         pre_synaptic_n1_inputs.map { it[15] }, // pre_synapse_seg_n1
//         pre_synaptic_n1_inputs.map { it[3] }, // pre_synapse_vol
//         pre_synaptic_n1_inputs.map { "${it[0]}/post_synapse_seg.h5" },
//         pre_synaptic_n1_inputs.map { "${it[0]}/post_synapse_seg_pre_synapse_seg_n1.h5" }
//     )
//     emit:
//     done = post_to_pre_synaptic_results
// }
