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
    input_data // [ presynaptic_container, presynaptic_dataset ]
    output_dir

    main:
    def presynaptic_stack_name = 'pre_synapse'
    def n1_stack_name = 'n1_mask'

    def n5_input_stacks = prepare_n5_inputs(
        [
            presynaptic_stack_name,
            n1_stack_name,
        ],
        input_data,
        output_dir,
        [
            get_n5_container_name('working_pre_synapse_container'),
            params.working_pre_synapse_dataset,
            get_n5_container_name('working_n1_mask_container'),
            params.working_n1_mask_dataset,
        ]
    )
    def presynaptic_n1_results = classify_presynaptic_regions(
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[presynaptic_stack_name][0], // input_n5_dir
                n5_stacks[presynaptic_stack_name][1], // input_datasett
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_pre_synapse_seg_container')
                ), // unet_n5_dir
                params.working_pre_synapse_seg_dataset, // unet_dataset
                n5_stacks[presynaptic_stack_name][2],
            ]
        },
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[n1_stack_name][0], // mask_n5_dir
                n5_stacks[n1_stack_name][1], // mask_dataset
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_pre_synapse_seg_post_container')
                ), // post_unet_n5_dir
                params.working_pre_synapse_seg_post_dataset, // post_unet_dataset
                create_post_output_name(output_dirname,
                                        'pre_synapse_seg_post',
                                        params.presynaptic_stage2_threshold,
                                        params.presynaptic_stage2_percentage),
            ]
        },
        params.synapse_model,
        params.presynaptic_stage2_threshold,
        params.presynaptic_stage2_percentage,
        params.unet_cpus,
        params.unet_memory,
        params.postprocessing_cpus,
        params.postprocessing_memory,
        params.postprocessing_threads,
    )
    | map {
        def csv_file = file(it[-1])
        [ "${csv_file.parent}" ] + it
    } // [ output_dir, pre_synapse, '', pre_synapse_seg, pre_synapse_seg_post, size ]

    def final_n5_stacks = n5_input_stacks
    | join(presynaptic_n1_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
            presynaptic_container, presynaptic_dataset,
            mask_container, mask_dataset,
            presynaptic_seg_container, presynaptic_seg_dataset,
            presynaptic_seg_post_container, presynaptic_seg_post_dataset,
            stack_size,
            csv_results) = it
        log.info "!!!!!!!!!! MASK CONTAINER $mask_container"
        def post_pre_synaptic_seg_key = mask_container
            ? 'pre_synapse_seg_n1'
            : 'pre_synapse_seg_post'
        [
            output_dirname,
            n5_stacks + [
                'pre_synapse_seg': [
                    presynaptic_seg_container,
                    presynaptic_seg_dataset,
                    stack_size
                ],
                post_pre_synaptic_seg_key: [ presynaptic_seg_post_container, presynaptic_seg_post_dataset, stack_size ],
            ]
        ]
    }
    final_n5_stacks.subscribe { log.debug "final presynaptic in volume results: $it" }

    emit:
    done = n5_input_stacks
}

// Workflow A - Neuron 1 presynaptic to Neuron 2
workflow presynaptic_n1_to_n2 {
    take:
    input_data // [ presynaptic_stack, n1_mask_stack, n2_mask_stack ]
    output_dir

    main:
    def presynaptic_stack_name = 'pre_synapse'
    def n1_stack_name = 'n1_mask'
    def n2_stack_name = 'n2_mask'

    def n5_input_stacks = prepare_n5_inputs(
        [
            presynaptic_stack_name,
            n1_stack_name,
            n2_stack_name,
        ],
        input_data,
        output_dir,
        [ 
            get_n5_container_name('working_pre_synapse_container'),
            params.working_pre_synapse_dataset,
            get_n5_container_name('working_n1_mask_container'),
            params.working_n1_mask_dataset,
            get_n5_container_name('working_n2_mask_container'),
            params.working_n2_mask_dataset,
        ]
    )

    // Segment presynaptic volume and identify presynaptic regions that colocalize with neuron1 mask
    def presynaptic_n1_results = classify_presynaptic_regions(
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[presynaptic_stack_name][0], // input_n5_dir
                n5_stacks[presynaptic_stack_name][1], // input_dataset_name
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_pre_synapse_seg_container')
                ), // unet_n5_dir
                params.working_pre_synapse_seg_dataset, // unet_dataset
                n5_stacks[presynaptic_stack_name][2], // input size
            ]
        },
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[n1_stack_name][0], // mask_n5_dir
                n5_stacks[n1_stack_name][1], // mask_dataset
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_pre_synapse_seg_n1_container')
                ), // post_unet_n5_dir
                params.working_pre_synapse_seg_n1_dataset, // post_unet_dataset
                create_post_output_name(
                    output_dirname,
                    'pre_synapse_seg_n1',
                    params.presynaptic_stage2_threshold,
                    params.presynaptic_stage2_percentage) // post csv data dir
            ]
        },
        params.synapse_model,
        params.presynaptic_stage2_threshold,
        params.presynaptic_stage2_percentage,
        params.unet_cpus,
        params.unet_memory,
        params.postprocessing_cpus,
        params.postprocessing_memory,
        params.postprocessing_threads,
    )
    | map {
        def csv_file = file(it[-1])
        [ "${csv_file.parent}" ] + it
    } // [ output_dir, pre_synapse, n1, synapse_seg, synapse_seg_n1, size ]

    def presynaptic_to_n1_n5_stacks = n5_input_stacks
    | join(presynaptic_n1_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             presynaptic_container_dir, presynaptic_dataset, 
             n1_container_dir, n1_dataset,
             presynaptic_seg_container_dir, presynaptic_seg_dataset,
             presynaptic_seg_n1_container_dir, presynaptic_seg_n1_dataset,
             stack_size,
             csv_results) = it
        [
            output_dirname,
            n5_stacks + [
                'pre_synapse_seg': [
                    presynaptic_seg_container_dir,
                    presynaptic_seg_dataset,
                    stack_size
                ],
                'pre_synapse_seg_n1': [
                    presynaptic_seg_n1_container_dir,
                    presynaptic_seg_n1_dataset,
                    stack_size
                ]
            ]
        ]
    }

    // Colocalize presynaptic n1 with n2
    def synapse_n1_n2_results = connect_regions_in_volume(
        presynaptic_to_n1_n5_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks["pre_synapse_seg_n1"][0], // input n5
                n5_stacks["pre_synapse_seg_n1"][1], // input dataset
                n5_stacks[n2_stack_name][0], // mask n5
                n5_stacks[n2_stack_name][1], // mask dataset
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_pre_synapse_seg_n1_n2_container'),
                ), // output n5
                params.working_pre_synapse_seg_n1_n2_dataset, // output dataset
                n5_stacks[n2_stack_name][2], // size
                create_post_output_name(
                    output_dirname,
                    'pre_synapse_seg_n1_n2',
                    params.postsynaptic_stage2_threshold,
                    params.postsynaptic_stage2_percentage), // csv ouput
            ]
        },
        params.postsynaptic_stage2_threshold,
        params.postsynaptic_stage2_percentage,
        params.postprocessing_cpus,
        params.postprocessing_memory,
        params.postprocessing_threads,
    )
    | map {
        def csv_file = file(it[-1])
        [ "${csv_file.parent}" ] + it
    }  // [ working_dir, synapse_seg_n1, n2, synapse_size, synapse_seg_n1_n2, synapse_seg_n1_n2_csv ]

    // prepare the final result
    def final_n5_stacks = presynaptic_to_n1_n5_stacks
    | join(synapse_n1_n2_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             presynaptic_seg_n1_container, presynaptic_seg_n1_dataset,
             n2_container, n2_dataset,
             presynaptic_seg_n1_n2_container, presynaptic_seg_n1_n2_dataset,
             stack_size,
             csv_results) = it
        [
            output_dirname,
            n5_stacks + [
                "pre_synapse_seg_n1_n2": [
                    presynaptic_seg_n1_n2_container,
                    presynaptic_seg_n1_n2_dataset,
                    stack_size
                ]
            ]
        ]
    }
    final_n5_stacks.subscribe { log.debug "final presynaptic n1 to n2 results: $it" }

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
        [
            presynaptic_stack_name,
            neuron_stack_name,
            postsynaptic_stack_name,
        ],
        input_data,
        output_dir,
        [
            get_n5_container_name('working_pre_synapse_container'),
            params.working_pre_synapse_dataset,
            get_n5_container_name('working_n1_mask_container'),
            params.working_n1_mask_dataset,
            get_n5_container_name('working_post_synapse_container'),
            params.working_post_synapse_dataset,
        ]
    )
 
    // Segment presynaptic volume and identify presynaptic regions that colocalize with neuron1 mask
    def presynaptic_n1_results = classify_presynaptic_regions(
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[presynaptic_stack_name][0], // input n5 container
                n5_stacks[presynaptic_stack_name][1], // input dataset
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_pre_synapse_seg_container')
                ), // unet_n5_dir
                params.working_pre_synapse_seg_dataset, // unet_dataset
                n5_stacks[presynaptic_stack_name][2], // input size
            ]
        },
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[neuron_stack_name][0], // mask n5 container
                n5_stacks[neuron_stack_name][1], // mask dataset
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_pre_synapse_seg_n1_container')
                ), // post_unet_n5_dir
                params.working_pre_synapse_seg_n1_dataset, // post_unet_dataset
                create_post_output_name(
                    output_dirname,
                    'pre_synapse_seg_n1',
                    params.presynaptic_stage2_threshold,
                    params.presynaptic_stage2_percentage), // post unet csv
            ]
        },
        params.synapse_model,
        params.presynaptic_stage2_threshold,
        params.presynaptic_stage2_percentage,
        params.unet_cpus,
        params.unet_memory,
        params.postprocessing_cpus,
        params.postprocessing_memory,
        params.postprocessing_threads,
    )
    | map {
        def csv_file = file(it[-1])
        [ "${csv_file.parent}" ] + it
    } // [ output_dir, pre_synapse, n1, synapse_seg, synapse_seg_n1, size ]

    presynaptic_n1_results.subscribe { log.debug "presynaptic n1 results: $it" }

    def presynaptic_to_n1_n5_stacks = n5_input_stacks
    | join(presynaptic_n1_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             presynaptic_container_dir, presynaptic_dataset, 
             n1_container_dir, n1_dataset,
             presynaptic_seg_container_dir, presynaptic_seg_dataset,
             presynaptic_seg_n1_container_dir, presynaptic_seg_n1_dataset,
             stack_size,
             csv_results) = it
        [
            output_dirname,
            n5_stacks + [
                "pre_synapse_seg": [
                    presynaptic_seg_container_dir,
                    presynaptic_seg_dataset,
                    stack_size
                ],
                "pre_synapse_seg_n1": [
                    presynaptic_seg_n1_container_dir,
                    presynaptic_seg_n1_dataset,
                    stack_size
                ]
            ]
        ]
    }

    // Segment postsynaptic volume and identify postsynaptic regions that colocalize with presynaptic neuron1
    // (postsynaptic neuron2 colocalized with presynaptic neuron1)
    def postsynaptic_to_presynaptic_results = classify_postsynaptic_regions(
        n5_input_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks[postsynaptic_stack_name][0], // input n5 container
                n5_stacks[postsynaptic_stack_name][1], // input dataset
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_post_synapse_seg_container')
                ), // unet_n5_dir
                params.working_post_synapse_seg_dataset, // unet_dataset
                n5_stacks[postsynaptic_stack_name][2],
            ]
        },
        presynaptic_to_n1_n5_stacks.map {
            def (output_dirname, n5_stacks) = it
            [
                n5_stacks["pre_synapse_seg_n1"][0], // mask n5 container
                n5_stacks["pre_synapse_seg_n1"][1], // mask dataset
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_post_synapse_seg_n1_container')
                ), // post_unet_n5_dir
                params.working_post_synapse_seg_n1_dataset, // post_unet_dataset
                create_post_output_name(output_dirname,
                                        'post_synapse_seg_pre_synapse_seg_n1',
                                        params.postsynaptic_stage2_threshold,
                                        params.postsynaptic_stage2_percentage),
            ]
        },
        params.synapse_model,
        params.postsynaptic_stage2_threshold,
        params.postsynaptic_stage2_percentage,
        params.unet_cpus,
        params.unet_memory,
        params.postprocessing_cpus,
        params.postprocessing_memory,
        params.postprocessing_threads,
    )
    | map {
        def csv_file = file(it[-1])
        [ "${csv_file.parent}" ] + it
    } // [ output_dir, post_synapse, pre_synapse_seg_n1, post_synapse_seg, post_synapse_seg_pre_synapse_seg_n1, post_synapse_size ]

    postsynaptic_to_presynaptic_results.subscribe { log.debug "postsynapttic masked with presynaptic n1 results: $it" }

    def postsynaptic_to_presynaptic_to_n1_n5_stacks = presynaptic_to_n1_n5_stacks
    | join(postsynaptic_to_presynaptic_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             postsynaptic_container, postsynaptic_dataset,
             presynaptic_seg_n1_container, presynaptic_seg_n1_dataset,
             postsynaptic_seg_container, postsynaptic_seg_dataset,
             postsynaptic_seg_presynaptic_seg_n1_container, postsynaptic_seg_presynaptic_seg_n1_dataset,
             stack_size,
             csv_results) = it
        def d = [
            output_dirname,
            n5_stacks + [
                "post_synapse_seg": [
                    postsynaptic_seg_container,
                    postsynaptic_seg_dataset,
                    stack_size
                ],
                "post_synapse_seg_pre_synapse_seg_n1": [
                    postsynaptic_seg_presynaptic_seg_n1_container,
                    postsynaptic_seg_presynaptic_seg_n1_dataset,
                    stack_size
                ]
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
                n5_stacks["pre_synapse_seg_n1"][0], // input n5
                n5_stacks["pre_synapse_seg_n1"][1], // input dataset
                n5_stacks["post_synapse_seg_pre_synapse_seg_n1"][0], // mask n5
                n5_stacks["post_synapse_seg_pre_synapse_seg_n1"][1], // mask dataset
                get_container_fullpath(
                    output_dirname,
                    get_n5_container_name('working_pre_synapse_seg_post_synapse_seg_n1_container'),
                ), // output n5
                params.working_pre_synapse_seg_post_synapse_seg_n1_dataset, // output dataset
                n5_stacks["post_synapse_seg_pre_synapse_seg_n1"][2], // size
                create_post_output_name(output_dirname,
                                        'pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1',
                                        params.postsynaptic_stage3_threshold,
                                        params.postsynaptic_stage3_percentage), // csv output
            ]
        },
        params.postsynaptic_stage3_threshold,
        params.postsynaptic_stage3_percentage,
        params.postprocessing_cpus,
        params.postprocessing_memory,
        params.postprocessing_threads,
    )
    | map {
        def csv_file = file(it[-1])
        [ "${csv_file.parent}" ] + it
    } // [ working_dir, synapse_seg_n1, post_synapse_seg_pre_synapse_seg_n1, pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1, synapse_size, pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_csv ]

    presynaptic_to_postsynaptic_to_presynaptic_to_n1_results.subscribe { log.debug "presynaptic n1 masked with postsynapttic results: $it" }

    def final_n5_stacks = postsynaptic_to_presynaptic_to_n1_n5_stacks
    | join(presynaptic_to_postsynaptic_to_presynaptic_to_n1_results, by:0)
    | map {
        def (output_dirname, n5_stacks,
             presynaptic_seg_n1_container, presynaptic_seg_n1_dataset,
             post_synapse_seg_pre_synapse_seg_n1_container, post_synapse_seg_pre_synapse_seg_n1_dataset,
             pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_container, pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_dataset,
             stack_size,
             csv_results) = it
        def d = [
            output_dirname,
            n5_stacks + [
                "pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1": [
                    pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_container,
                    pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1_dataset,
                    stack_size
                ]
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
    stack_names // names for the corresponding output stacks
    input_stacks // tuple with all input stacks
    output_dir
    working_stacks

    main:
    // store all input stacks in n5 stores
    def unflattened_input_data = index_channel(output_dir)
    | join (index_channel(input_stacks), by: 0)
    | join (index_channel(working_stacks), by: 0)
    | flatMap {
        // we convert names to file type in order to normalize file names
        // to prevent 'a//b' in the path
        def (index,
             output_dirname,
             input_stacks_with_datasets,
             working_containers_with_datasets) = it
        def output_dir_as_file = file(output_dirname)
        def stack_name_list = stack_names instanceof String
            ? [ stack_names ]
            : stack_names
        def named_stacks = [
            stack_name_list,
            input_stacks_with_datasets.collate(2),
            working_containers_with_datasets.collate(2)
        ]
        named_stacks
            .transpose()
            .collect {
                def (stack_name, 
                     input_stack, // [ container, dataset ]
                     working_container_with_dataset) = it
                def (input_container_dir, input_dataset) = input_stack
                def (working_container, working_dataset) = working_container_with_dataset
                def input_container_dir_as_file = input_container_dir
                    ? file(input_container_dir)
                    : ''
                [
                    "${output_dir_as_file}",
                    stack_name,
                    "${input_container_dir_as_file}",
                    input_dataset,
                    working_container,
                    working_dataset,
                ]
            }
    }

    unflattened_input_data.subscribe { log.debug "prepare_n5_inputs: N5 input $it" }

    def n5_stacks = unflattened_input_data
    | map {
        def (output_dirname,
             stack_name,
             input_container_dir,
             input_dataset,
             working_container,
             working_dataset) = it
        def d = [
            get_container_fullpath(input_container_dir, ''),
            input_dataset,
            get_container_fullpath(output_dirname, working_container),
            working_dataset,
            output_dirname,
            stack_name,
        ]
        log.info "input_stacks_to_n5 input: $d"
        d
    }
    | input_stacks_to_n5
    | join(unflattened_input_data, by: [0,1])
    | map {
        def (output_dirname,
             stack_name,
             input_stack_dir, input_dataset,
             output_stack_dir, output_dataset,
             stack_size) = it
        [
            output_dirname,
            [(stack_name as String): [ output_stack_dir, output_dataset, stack_size ] ]
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
    } // [ output_dir, {<stack_name>: [<stack_n5_container>, <stack_dataset>, <stack_size>]} ]

    n5_stacks.subscribe { log.info "prepare_n5_inputs: N5 stacks: $it" }
 
    emit:
    done = n5_stacks
}

workflow input_stacks_to_n5 {
    take:
    input_data // [ input_stack, input_dataset, output_stack, output_dataset, output_dir, stack_name ]

    main:
    def empty_stacks = input_data
    | filter { !it[0] }
    | map {
        def (input_stack, input_dataset,
             output_stack, output_dataset,
             output_dirname, stack_name) = it
        [
            output_dirname, stack_name,
            input_stack, input_dataset,
            output_stack, output_dataset,
            [0, 0, 0]
        ]
    }

    def tiff_to_n5_inputs = input_data
    | filter { it[0] } // input_dir must be set
    | map {
        def (input_dir, input_dataset,
             output_dir, output_dataset) = it
        [ input_dir, input_dataset, output_dir, output_dataset ]
    }
    def output_data = tiff_to_n5_with_metadata(
        tiff_to_n5_inputs,
        params.partial_volume
    )
    | join(input_data, by: [0,1,2,3])
    | map {
        def (input_stack, input_dataset,
             output_stack, output_dataset,
             dims,
             output_dirname, stack_name) = it
        [
            output_dirname, stack_name,
            input_stack, input_dataset,
            output_stack, output_dataset,
            dims
        ]
    } // [ parent_output_dir, stack_name, input_stack, output_stack, stack_volume_size ]
    | concat(empty_stacks)


    output_data.subscribe { log.debug "input_stacks_to_n5: N5 stack: $it" }

    emit:
    done = output_data
}

def create_post_output_name(dirname, fname, threshold, perccentage) {
    def suffix = "t${threshold}_p${perccentage}".replace('.', 'd')
    "${dirname}/${fname}_${suffix}_csv"
}

def get_container_fullpath(output_dir, container_dirname) {
    if (output_dir) {
        def container_path = new File("${output_dir}", "${container_dirname}")
        "${container_path.canonicalPath}"
    } else {
        ''
    }
}

def get_n5_container_name(container_key) {
    get_value_with_default_param(params, container_key, 'working_container')
}

def get_value_with_default_param(Map ps, String param, String default_param) {
    if (ps[param])
        ps[param]
    else
        ps[default_param]
}
