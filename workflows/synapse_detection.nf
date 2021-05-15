
include {
    n5_to_tiff;
} from '../processes/synapse_detection'

include {
    classify_and_connect_regions_in_volume as classify_presynaptic_regions;
    classify_and_connect_regions_in_volume as classify_postsynaptic_regions;
    connect_regions_in_volume;
} from './segmentation_tools'

include {
    tiff_to_n5_with_metadata;
} from './tiff_to_n5'

include {
    index_channel;
} from '../utils/utils'


workflow presynaptic_in_volume {
    take:
    input_data // presynaptic_stack
    output_dir

    main:
    def presynaptic_stack_name = "pre_synapse"
    def n5_input_stacks = prepare_n5_inputs(
        input_data,
        output_dir,
        presynaptic_stack_name
    )

    def presynaptic_n1_results = classify_presynaptic_regions(
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[presynaptic_stack_name][0],
                "${output_dirname}/pre_synapse_seg.n5",
                n5_stacks[presynaptic_stack_name][1],
            ]
        },
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                '',
                create_post_output_name(output_dirname,
                                        'pre_synapse_seg_post',
                                        params.presynaptic_stage2_threshold,
                                        params.presynaptic_stage2_percentage),
            ]
        },
        params.synapse_model,
        params.presynaptic_stage2_threshold,
        params.presynaptic_stage2_percentage,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    } // [ output_dir, pre_synapse, '', pre_synapse_seg, pre_synapse_seg_post, size ]

    def final_n5_stacks = n5_input_stacks
    | join(presynaptic_n1_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
            presynaptic_stack, mask, presynaptic_seg_stack, presynaptic_seg_post_stack,
            stack_size) = it
        [
            output_dirname,
            n5_stacks + [
                "pre_synapse_seg": [ presynaptic_seg_stack, stack_size ],
                "pre_synapse_seg_post": [ presynaptic_seg_post_stack, stack_size ],
            ]
        ]
    }

    emit:
    done = final_n5_stacks
}

// Workflow A - Neuron 1 presynaptic to Neuron 2
workflow presynaptic_n1_to_n2 {
    take:
    input_data // [ presynaptic_stack, n1_mask_stack, n2_mask_stack ]
    output_dir

    main:
    def presynaptic_stack_name = "pre_synapse"
    def n1_stack_name = "n1_mask"
    def n2_stack_name = "n2_mask"

    def n5_input_stacks = prepare_n5_inputs(
        input_data,
        output_dir,
        [ presynaptic_stack_name, n1_stack_name, n2_stack_name ]
    )

    // Segment presynaptic volume and identify presynaptic regions that colocalize with neuron1 mask
    def presynaptic_n1_results = classify_presynaptic_regions(
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[presynaptic_stack_name][0],
                "${output_dirname}/pre_synapse_seg.n5",
                n5_stacks[presynaptic_stack_name][1],
            ]
        },
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[n1_stack_name][0],
                create_post_output_name(output_dirname,
                                        'pre_synapse_seg_n1',
                                        params.presynaptic_stage2_threshold,
                                        params.presynaptic_stage2_percentage),
            ]
        },
        params.synapse_model,
        params.presynaptic_stage2_threshold,
        params.presynaptic_stage2_percentage,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    } // [ output_dir, pre_synapse, n1, synapse_seg, synapse_seg_n1, size ]

    def presynaptic_to_n1_n5_stacks = n5_input_stacks
    | join(presynaptic_n1_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             presynaptic_stack, n1_stack,
             presynaptic_seg_stack, presynaptic_seg_n1_stack,
             stack_size) = it
        [
            output_dirname,
            n5_stacks + [
                "pre_synapse_seg": [ presynaptic_seg_stack, stack_size ],
                "pre_synapse_seg_n1": [ presynaptic_seg_n1_stack, stack_size ]
            ]
        ]
    }

    // Colocalize presynaptic n1 with n2
    def synapse_n1_n2_results = connect_regions_in_volume(
        presynaptic_to_n1_n5_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks["pre_synapse_seg_n1"][0],
                n5_stacks[n2_stack_name][0],
                create_post_output_name(output_dirname,
                                        'pre_synapse_seg_n1_n2',
                                        params.postsynaptic_stage3_threshold,
                                        params.postsynaptic_stage3_percentage),
                n5_stacks[n2_stack_name][1],
            ]
        },
        params.postsynaptic_stage2_threshold,
        params.postsynaptic_stage2_percentage,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    }  // [ working_dir, synapse_seg_n1, n2, synapse_size, synapse_seg_n1_n2, synapse_seg_n1_n2_csv ]

    // prepare the final result
    def final_n5_stacks = presynaptic_to_n1_n5_stacks
    | join(synapse_n1_n2_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             presynaptic_seg_n1_stack, post_synapse_seg_pre_synapse_seg_n1_stack,
             pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_stack,
             stack_size) = it
        [
            output_dirname,
            n5_stacks + [
                "pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1": [ pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_stack, stack_size ]
            ]
        ]
    }
    
    emit:
    done = final_n5_stacks
}


// Workflow C - Neuron 1 presynaptic to Neuron 2 restricted post synaptic
workflow presynaptic_n1_to_postsynaptic_n2 {
    take:
    input_data // [ presynaptic_stack, neuron_mask_stack, postsynaptic_stack ]
    output_dir

    main:
    // store all input stacks in n5 stores
    def presynaptic_stack_name = "pre_synapse"
    def neuron_stack_name = "neuron_mask"
    def postsynaptic_stack_name = "post_synapse"

    def n5_input_stacks = prepare_n5_inputs(
        input_data,
        output_dir,
        [ presynaptic_stack_name, neuron_stack_name, postsynaptic_stack_name ]
    )
 
    // Segment presynaptic volume and identify presynaptic regions that colocalize with neuron1 mask
    def presynaptic_n1_results = classify_presynaptic_regions(
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[presynaptic_stack_name][0],
                "${output_dirname}/pre_synapse_seg.n5",
                n5_stacks[presynaptic_stack_name][1],
            ]
        },
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[neuron_stack_name][0],
                create_post_output_name(output_dirname,
                                        'pre_synapse_seg_n1',
                                        params.presynaptic_stage2_threshold,
                                        params.presynaptic_stage2_percentage),
            ]
        },
        params.synapse_model,
        params.presynaptic_stage2_threshold,
        params.presynaptic_stage2_percentage,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    } // [ output_dir, pre_synapse, n1, synapse_seg, synapse_seg_n1, size ]

    presynaptic_n1_results.subscribe { log.debug "presynaptic n1 results: $it" }

    def presynaptic_to_n1_n5_stacks = n5_input_stacks
    | join(presynaptic_n1_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             presynaptic_stack, neuron_stack,
             presynaptic_seg_stack, presynaptic_seg_n1_stack,
             stack_size) = it
        def d = [
            output_dirname,
            n5_stacks + [
                "pre_synapse_seg": [ presynaptic_seg_stack, stack_size ],
                "pre_synapse_seg_n1": [ presynaptic_seg_n1_stack, stack_size ]
            ]
        ]
        log.debug "N5 stacks after presynaptic n1: $d"
        d
    }

    // Segment postsynaptic volume and identify postsynaptic regions that colocalize with presynaptic neuron1
    // (postsynaptic neuron2 colocalized with presynaptic neuron1)
    def postsynaptic_to_presynaptic_results = classify_postsynaptic_regions(
        presynaptic_to_n1_n5_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[postsynaptic_stack_name][0],
                "${output_dirname}/post_synapse_seg.n5",
                n5_stacks[postsynaptic_stack_name][1],
            ]
        },
        presynaptic_to_n1_n5_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks["pre_synapse_seg_n1"][0],
                create_post_output_name(output_dirname,
                                        'post_synapse_seg_pre_synapse_seg_n1',
                                        params.postsynaptic_stage2_threshold,
                                        params.postsynaptic_stage2_percentage),
            ]
        },
        params.synapse_model,
        params.postsynaptic_stage2_threshold,
        params.postsynaptic_stage2_percentage,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, post_synapse, pre_synapse_seg_n1, post_synapse_seg, post_synapse_seg_pre_synapse_seg_n1, post_synapse_size ]

    postsynaptic_to_presynaptic_results.subscribe { log.debug "postsynapttic masked with presynaptic n1 results: $it" }

    def postsynaptic_to_presynaptic_to_n1_n5_stacks = presynaptic_to_n1_n5_stacks
    | join(postsynaptic_to_presynaptic_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             postsynaptic_stack, presynaptic_seg_n1_stack,
             postsynaptic_seg_stack, postsynaptic_seg_presynaptic_seg_n1_stack,
             stack_size) = it
        def d = [
            output_dirname,
            n5_stacks + [
                "post_synapse_seg": [ postsynaptic_seg_stack, stack_size ],
                "post_synapse_seg_pre_synapse_seg_n1": [ postsynaptic_seg_presynaptic_seg_n1_stack, stack_size ]
            ]
        ]
        log.debug "N5 stacks after postsynaptic masked with presynaptic n1: $d"
        d
    }

    // Identify neuron1 presynaptic regions that colocalize with neuron2 postsynaptic
    def presynaptic_to_postsynaptic_to_presynaptic_to_n1_results = connect_regions_in_volume(
        postsynaptic_to_presynaptic_to_n1_n5_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks["pre_synapse_seg_n1"][0],
                n5_stacks["post_synapse_seg_pre_synapse_seg_n1"][0],
                create_post_output_name(output_dirname,
                                        'pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1',
                                        params.postsynaptic_stage3_threshold,
                                        params.postsynaptic_stage3_percentage),
                n5_stacks["post_synapse_seg_pre_synapse_seg_n1"][1],
            ]
        },
        params.postsynaptic_stage3_threshold,
        params.postsynaptic_stage3_percentage,
    )
    | map {
        def n5_file = file(it[0])
        [ "${n5_file.parent}" ] + it
    } // [ working_dir, synapse_seg_n1, post_synapse_seg_pre_synapse_seg_n1, pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1, synapse_size, pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_csv ]

    presynaptic_to_postsynaptic_to_presynaptic_to_n1_results.subscribe { log.debug "presynaptic n1 masked with postsynapttic results: $it" }

    def final_n5_stacks = postsynaptic_to_presynaptic_to_n1_n5_stacks
    | join(presynaptic_to_postsynaptic_to_presynaptic_to_n1_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             presynaptic_seg_n1_stack, post_synapse_seg_pre_synapse_seg_n1_stack,
             pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_stack,
             stack_size) = it
        def d = [
            output_dirname,
            n5_stacks + [
                "pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1": [ pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_stack, stack_size ]
            ]
        ]
        log.debug "N5 stacks after presynaptic n1 masked with postsynaptic: $d"
        d
    }

    emit:
    done = final_n5_stacks
}

workflow prepare_n5_inputs {
    take:
    input_stacks // tuple with all input stacks
    output_dir
    stack_names // names for the corresponding output stacks

    main:
    // store all input stacks in n5 stores
    def unflattened_input_data = index_channel(output_dir)
    | join (index_channel(input_stacks), by: 0)
    | flatMap {
        def (index, output_dirname, input_stack_dirs) = it
        if (stack_names instanceof String) {
            // this is the case for synapse in volume
            [
                [ input_stack_dirs, stack_names ]
            ]
        } else {
            [ input_stack_dirs, stack_names ]
                .transpose()
                .collect {
                    def (input_stack_dir, stack_name) = it
                    [ output_dirname, input_stack_dir, stack_name ]
                }
        }
    }

    def n5_stacks = unflattened_input_data
    | map {
        def (output_dir, input_stack_dir, stack_name) = it
        [ input_stack_dir, "${output_dir}/${stack_name}.n5" ]
    }
    | input_stacks_to_n5
    | join(unflattened_input_data, by: [0,1])
    | map {
        def (output_dirname, input_stack_dir, output_stack, stack_size, stack_name) = it
        [
            output_dirname,
            [("${stack_name}" as String): [ output_stack, stack_size ]]
        ]
    }
    | groupTuple(by: 0)
    | map {
        def (output_dirname, list_of_stacks) = it
        // combine all stacks in a single map
        def data_stacks = list_of_stacks
            .inject([:]) {
                arg, item -> arg + item
            }
        [ output_dirname,  data_stacks ]
    } // [ output_dir, {<stack_name>: [<stack_n5_dir>, <stack_size>]} ]

    n5_stacks.subscribe { log.debug "N5 stacks: $it" }
 
    emit:
    done = n5_stacks
}

workflow input_stacks_to_n5 {
    take:
    input_data // [ input_stack, output_stack ]

    main:
    def output_data = tiff_to_n5_with_metadata(input_data)
    | map {
        def output_stack = file(it[1])
        [ "${output_stack.parent}" ] + it
    } // // [ parent_output_stack, input_stack, output_stack, stack_volume_size ]

    emit:
    done = output_data
}

def create_post_output_name(dirname, fname, threshold, perccentage) {
    def suffix = "t${threshold}_p${perccentage}".replace('.', 'd')
    "${dirname}/${fname}_${suffix}.n5"
}
