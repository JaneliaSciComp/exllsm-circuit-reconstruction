
include {
    hdf5_to_tiff;
} from '../processes/synapse_detection'

include {
    classify_regions_in_volume as classify_synapses;
    locate_regions_in_volume as mask_synapses_with_n1;
    locate_regions_in_volume as mask_synapses_witth_n2;
} from './segmentation_tools'

include {
    merge_4_channels;
    merge_7_channels;
} from '../processes/utils'

include {
    tiff_to_h5_with_metadata as synapse_tiff_to_h5;
    tiff_to_h5_with_metadata as neuron1_tiff_to_h5;
    tiff_to_h5_with_metadata as neuron2_tiff_to_h5;
} from './tiff_to_h5'

include {
    index_channel;
} from '../utils/utils'

workflow presynaptic_n1_to_n2 {
    take:
    synapse_stack_dir
    neuron1_stack_dir
    neuron2_stack_dir
    output_dir

    main:
    def input_data = merge_4_channels(synapse_stack_dir, neuron1_stack_dir, neuron2_stack_dir, output_dir)
    | map {
        it + "${it[3]}/tmp"
    } // [ synapse_tiff_stack, n1_tiff_stack, n2_tiff_stack, output_dir, working_dir ]

    def synapse_data = synapse_tiff_to_h5(
        input_data.map { it[0] }, // synapse
        input_data.map { "${it[4]}/synapse.h5" }
    ) // [ synapse_tiff_stack, synapse_h5_file, synapse_volume ]

    def n1_data = neuron1_tiff_to_h5(
        input_data.map { it[1] }, // n1
        input_data.map { "${it[4]}/n1_mask.h5" }
    ) // [ neuron1_tiff_stack, neuron1_h5_file, neuron1_volume ]

    def n2_data = neuron2_tiff_to_h5(
        input_data.map { it[2] }, // n2
        input_data.map { "${it[4]}/n2_mask.h5" }
    ) // [ neuron2_tiff_stack, neuron2_h5_file, neuron2_volume ]
/*
    def synapse_inputs = input_data | join(synapse_data, by:0)
    | map {
        // [synapse_tiff, n1_tiff, n2_tiff, output, working, synapse_h5, synapse_vol ]
        it[1..6] // drop synapse_tiff
    }
    | join(n1_data, by:0)
    | map {
        // [ n1_tiff, n2_tiff, output, working, synapse_h5, synapse_vol, n1_h5, n1_vol ]
        it[1..7]
    } join(n2_data, by:0)
    | map {
        // [ n2_tiff, output, working, synapse_h5, synapse_vol, n1_h5, n1_vol, n2_h5, n2_vol ]
        it[3..8] + [ it[2], it[1] ]
    } // [ synapse_h5, synapse_vol, n1_h5, n1_vol, n2_h5, n2_vol, working, output ]

    def synapses_results = find_synapses_from_n1_to_n2(
        synapse_inputs.map { it[0] }, // synapse_file
        synapse_inputs.map { it[1] }, // synapse_vol
        synapse_inputs.map { it[2] }, // n1
        synapse_inputs.map { it[3] }, // n1_vol
        synapse_inputs.map { it[4] }, // n2
        synapse_inputs.map { it[5] }, // n2_vol
        synapse_inputs.map { it[6] }  // working_dir
    )
*/
    emit:
    done = input_data
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

    def synapse_seg_results = classify_synapses(
        synapse_seg_inputs.map { it[0] },
        synapse_seg_inputs.map { it[1] },
        params.synapse_model,
        synapse_seg_inputs.map { "${it[6]}/synapse_seg.h5" }
    ) // [ synapse_h5, synapse_vol, seg_synapse_h5 ]
    | join(synapse_seg_inputs, by:[0,1]) // [ synapse, synapse_vol, seg_synapse, n1_h5, n1_vol, n2_h5, n2_vol, output_dir ]

    def synapse_n1_mask_results = mask_synapses_with_n1(
        synapse_seg_results.map { it[2] }, // seg_synapse
        synapse_seg_results.map { it[1] }, // synapse vol
        synapse_seg_results.map { it[3] }, // n1
        synapse_seg_results.map { it[4] }, // n1_vol
        synapse_seg_results.map { "${it[7]}/synapse_n1.h5" }
    ) // [ seg_synapse, synapse_vol, n1, n1_vol, synapse_n1 ]
    | join(synapse_seg_results.map {
        [ it[2], it[1] ] + it[3..7] + it[0] // [ seg_synapse, synapse_vol, n1, n1_vol, n2, n2_vol, output_dir, synapse ]
    }, by:[0..3]) // [ seg_synapse, synapse_vol, n1, n1_vol, synapse_n1, n2, n2_vol, output_dir, synapse ]

    def synapse_n2_mask_results = mask_synapses_witth_n2(
        synapse_n1_mask_results.map { it[4] }, // synapse_n1
        synapse_n1_mask_results.map { it[1] }, // synapse vol
        synapse_n1_mask_results.map { it[5] }, // n2
        synapse_n1_mask_results.map { it[6] }, // n2_vol
        synapse_n1_mask_results.map { "${it[7]}/synapse_n1_n2.h5" }
    ) // [ synapse_n1, synapse_vol, n2, n2_vol, synapse_n1_n2 ]
    | join(synapse_n1_mask_results.map {
        [ it[4], it[1], it[5], it[6], it[0], it[8], it[2], it[3], it[7] ]
        // [ synapse_n1, synapse_vol, n2, n2_vol, seg_synapse, synapse, n1, n1_vol, output_dir ]
    }, by:[0:3]) // [ synapse_n1, synapse_vol, n2, n2_vol, synapse_n1_n2, seg_synapse, synapse, n1, n1_vol, output_dir ]
    | map {
        [ it[6], it[1], it[7], it[8], it[2], it[3], it[5], it[0], it[4], it[9] ]
    } // [ synapse, synapse_vol, n1, n1_vol, n2_vol, synapse_seg, synapse_n1, synapse_n1_n2, output_dir ]

    emit:
    done = synapse_seg_inputs
}


