
include {
    n5_to_tiff;
} from '../processes/synapse_detection'

include {
    classify_and_connect_regions_in_volume as classify_presynaptic_regions;
    classify_and_connect_regions_in_volume as classify_postsynaptic_regions;
    connect_regions_in_volume;
} from './segmentation_tools'

include {
    tiff_to_n5_with_metadata as synapse_to_n5;
    tiff_to_n5_with_metadata as neuron1_to_n5;
    tiff_to_n5_with_metadata as neuron2_to_n5;
    tiff_to_n5_with_metadata as pre_synapse_to_n5;
    tiff_to_n5_with_metadata as post_synapse_to_n5;
} from './tiff_to_n5'

include {
    index_channel;
} from '../utils/utils'

workflow presynaptic_in_volume {
    take:
    input_data // [ presynaptic_stack, output_dir ]

    main:
    def synapse_inputs = input_data
    | map {
        def (synapse_stack, output_dir) = it
        [ synapse_stack, "${output_dir}/synapse.n5" ]
    }
    | synapse_to_n5 // [ synapse_stack, synapse_n5, synapse_size ]
    | map {
        // prepare the arguments for classifying and connecting presynapses
        // without any neuron information - neuron mask will be an empty string
        def (synapse_stack, synapse, synapse_size) = it
        def working_dir = file(synapse).parent
        def d = [
            synapse,
            '', // no neuron mask info
            synapse_size,
            "${working_dir}/synapse_seg.n5",
            "${working_dir}/synapse_seg_post.n5"
        ]
        log.debug "Pre-synaptic regions inputs: $d"
        d
    }
    
    def post_synapse_seg_results = classify_presynaptic_regions(
        synapse_inputs,
        params.synapse_model,
        params.presynaptic_stage2_percentage,
        params.presynaptic_stage2_threshold,
    )
    | map {
        def (synapse, mask, synapse_size, synapse_seg, synapse_seg_post) = it
        def synapse_file = file(synapse)
        def r = [ synapse, synapse_size, synapse_seg, synapse_seg_post, "${synapse_file.parent.parent}" ]
        log.debug "Pre-synaptic in volume results: $r"
        r
    } // [ synapse, synapse_size, synapse_seg, synapse_seg_post, output_dir ]

    emit:
    done = post_synapse_seg_results
}

// Workflow A - Neuron 1 presynaptic to Neuron 2
workflow presynaptic_n1_to_n2 {
    take:
    input_data // [ presynapse_image, n1_mask, n2_mask, output_dir ]

    main:
    def synapse_data = input_data
    | map {
        def (synapse_stack, n1_mask_stack, n2_mask_stack, output_dir) = it
        [ synapse_stack, "${output_dir}/synapse.n5" ]
    }
    | synapse_to_n5 // [ synapse_stack, synapse_n5, synapse_size ]
    | map {
        def n5_file = file(it[1])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, n5_file, size ]

    def n1_data = input_data
    | map {
        def (synapse_stack, n1_mask_stack, n2_mask_stack, output_dir) = it
        [ n1_mask_stack, "${output_dir}/n1_mask.n5" ]
    }
    | neuron1_to_n5 // [ n1_mask_stack, n1_mask_n5, n1_size ]
    | map {
        def n5_file = file(it[1])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, n5_file, size ]

    def n2_data = input_data
    | map {
        def (synapse_stack, n1_mask_stack, n2_mask_stack, output_dir) = it
        [ n2_mask_stack, "${output_dir}/n2_mask.n5" ]
    }
    | neuron2_to_n5 // [ n2_mask_stack, n2_mask_n5, n2_size ]
    | map {
        def n5_file = file(it[1])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, n5_file, size ]

    def synapse_inputs = synapse_data
    | join(n1_data, by:0)
    | join(n2_data, by:0) 
    // [ working_dir, synapse_stack, synapse_n5, synapse_size, n1_stack, n1_n5, n1_size, n2_stack, n2_n5, n2_size ]

    def presynaptic_n1_inputs = synapse_inputs
    | map {
        def (working_dir, synapse_stack, synapse, synapse_size, n1_tiff, n1, n1_size) = it
        def r = [ synapse, n1, synapse_size, "${working_dir}/synapse_seg.n5", "${working_dir}/synapse_seg_n1.n5" ]
        log.debug "Pre-synaptic n1 inputs: $r"
        r
    }

    def presynaptic_n1_regions = classify_presynaptic_regions(
        presynaptic_n1_inputs,
        params.synapse_model,
        params.presynaptic_stage2_percentage,
        params.presynaptic_stage2_threshold,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, synapse, n1, synapse_size, synapse_seg, synapse_seg_n1 ]

    def mask_n2_inputs = synapse_inputs
    | join(presynaptic_n1_regions, by:0)
    | map {
        def (working_dir, synapse_stack, synapse, synapse_size, n1_tiff, n1, n1_size, n2_tiff, n2, n2_size) = it
        def d = [ "${working_dir}/synapse_seg_n1.n5", n2, synapse_size, "${working_dir}/synapse_seg_n1_n2.n5" ]
        log.debug "Pre-synaptic n1 to mask with n2 inputs: $d"
        d
    }
    
    def synapse_n1_n2_results = connect_regions_in_volume(
        mask_n2_inputs,
        params.postsynaptic_stage2_percentage,
        params.postsynaptic_stage2_threshold,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    }  // [ working_dir, synapse_seg_n1, n2, synapse_size, synapse_seg_n1_n2, synapse_seg_n1_n2_csv ]

    // prepare the final result
    done = synapse_inputs
    | join(synapse_n1_n2_results, by:0)
    | map {
        def (working_path, synapse_stack, synapse, synapse_size, n1_tiff, n1, n1_size, n2_tiff, n2, n2_size) = it
        def working_dir = file(working_path)
        def r = [
            synapse, n1, n2,
            synapse_size,
            "${working_dir}/synapse_seg.n5",
            "${working_dir}/synapse_seg_n1.n5",
            "${working_dir}/synapse_seg_n1_n2.n5",
            "${working_dir.parent}",
        ]
        log.debug "Pre-synaptic n1 to n2 results:  $r"
        r
    }  // [ synapse, n1, n2, size, synapse_seg, synapse_seg_n1, synapse_seg_n1_n2, output_dir ]
    
    emit:
    done
}

// Workflow C - Neuron 1 presynaptic to Neuron 2 restricted post synaptic
workflow presynaptic_n1_to_postsynaptic_n2 {
    take:
    input_data // [ pre_synapse_stack, neuron1_stack, post_synapse_stack, output_dir ]

    main:

    def pre_synapse_data = input_data
    | map {
        def (pre_synapse_stack, n1_mask_stack, post_synapse_stack, output_dir) = it
        [ pre_synapse_stack, "${output_dir}/pre_synapse.n5" ]
    }
    | synapse_to_n5 // [ pre_synapse_stack, pre_synapse_n5, pre_synapse_size ]
    | map {
        def n5_file = file(it[1])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, n5_file, size ]

    def n1_data = input_data
    | map {
        def (pre_synapse_stack, n1_mask_stack, post_synapse_stack, output_dir) = it
        [ n1_mask_stack, "${output_dir}/n1_mask.n5" ]
    }
    | neuron1_to_n5 // [ n1_mask_stack, n1_mask_n5, n1_size ]
    | map {
        def n5_file = file(it[1])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, n5_file, size ]

    def post_synapse_data = input_data
    | map {
        def (pre_synapse_stack, n1_mask_stack, post_synapse_stack, output_dir) = it
        [ pre_synapse_stack, "${output_dir}/post_synapse.n5" ]
    }
    | post_synapse_to_n5 // [ post_synapse_stack, post_synapse_n5, poost_synapse_size ]
    | map {
        def n5_file = file(it[1])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, tiff_stack, n5_file, size ]

    def pre_and_post_synaptic_data = pre_synapse_data
    | join(n1_data, by:0)
    | join(post_synapse_data, by:0) 
    // [ working_dir, pre_synapse_stack, pre_synapse_n5, pre_synapse_vol, n1_tiff, n1_n5, n1_vol, post_synapse_stack, post_synapse_n5, post_synapse_vol ]

    def presynaptic_n1_inputs = pre_and_post_synaptic_data
    | map {
        def (working_dir, pre_synapse_stack, pre_synapse, pre_synapse_size, n1_tiff, n1, n1_size) = it
        def r = [ pre_synapse, n1, pre_synapse_size, "${working_dir}/pre_synapse_seg.n5", "${working_dir}/pre_synapse_seg_n1.n5" ]
        log.debug "Pre-synaptic n1 inputs: $r"
        r
    }

    def presynaptic_n1_regions = classify_presynaptic_regions(
        presynaptic_n1_inputs,
        params.synapse_model,
        params.presynaptic_stage2_percentage,
        params.presynaptic_stage2_threshold,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, pre_synapse, n1, synapse_size, synapse_seg, synapse_seg_n1 ]

    def post_to_pre_synaptic_inputs = pre_and_post_synaptic_data
    | join(presynaptic_n1_regions, by:0)
    | map {
        def (working_dir, pre_synapse_stack, pre_synapse, pre_synapse_size, n1_tiff, n1, n1_size, post_synapse_stack, post_synapse, post_synapse_size) = it
        def d = [ post_synapse, "${working_dir}/pre_synapse_seg_n1.n5", post_synapse_size, "${working_dir}/post_synapse_seg.n5", "${working_dir}/post_synapse_seg_pre_synapse_seg_n1.n5" ]
        log.debug "Pre-synaptic n1 to n2 restricted post-synaptic inputs: $d"
        d
    }

    def post_to_pre_synaptic_results = classify_postsynaptic_regions(
        post_to_pre_synaptic_inputs,
        params.synapse_model,
        params.postsynaptic_stage2_percentage,
        params.postsynaptic_stage2_threshold,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, post_synapse, pre_synapse_seg_n1, post_synapse_size, post_synapse_seg, post_synapse_seg_pre_synapse_seg_n1 ]

    def pre_to_post_synaptic_inputs = presynaptic_n1_regions
    | join(post_to_pre_synaptic_results)
    | map {
        def (
            working_dir,
            pre_synapse, n1, synapse_size, synapse_seg, synapse_seg_n1,
            post_synapse, pre_synapse_seg_n1, post_synapse_size, post_synapse_seg, post_synapse_seg_pre_synapse_seg_n1
        ) = it
        def d = [ synapse_seg_n1, post_synapse_seg_pre_synapse_seg_n1, synapse_size, "${working_dir}/presynatic_seg_n1_postsynaptic_n2_from_n1.n5"]
        d
    }

    def pre_n1_to_post_synaptic_n2_results = connect_regions_in_volume(
        pre_to_post_synaptic_inputs,
        params.postsynaptic_stage3_percentage,
        params.postsynaptic_stage3_threshold,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, synapse_seg_n1, post_synapse_seg_pre_synapse_seg_n1, synapse_size, pre_synapse_seg_n1_postsynaptic_n2_from_n1, pre_synapse_seg_n1_postsynaptic_n2_from_n1_csv ]

    // prepare the final result
    done = pre_and_post_synaptic_data
    | join(pre_n1_to_post_synaptic_n2_results, by:0)
    | map {
        def (working_path, pre_synapse_stack, pre_synapse, pre_synapse_size, n1_tiff, n1, n1_size, post_synapse_stack, post_synapse, post_synapse_size) = it
        def working_dir = file(working_path)
        def r = [
            pre_synapse, n1, post_synapse,
            pre_synapse_size,
            "${working_dir}/pre_synapse_seg.n5",
            "${working_dir}/pre_synapse_seg_n1.n5",
            "${working_dir}/post_synapse_seg.n5",
            "${working_dir}/post_synapse_seg_pre_synapse_seg_n1.n5",
            "${working_dir}/presynatic_seg_n1_postsynaptic_n2_from_n1.n5",
            "${working_dir.parent}",
        ]
        log.debug "Pre-synaptic n1 to restricted post-synaptic n2 results:  $r"
        r
    }

    emit:
    done
}
