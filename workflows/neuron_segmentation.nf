include {
    tiff_to_n5_with_metadata;
} from './tiff_to_n5'

include {
    create_n5_volume;
} from '../processes/n5_tools'

include {
    compute_unet_scaling;
    unet_volume_segmentation;
} from '../processes/neuron_segmentation'

include {
    index_channel;
} from '../utils/utils'

include {
    partition_volume;
    number_of_subvols
} from './segmentation_utils'

workflow neuron_segmentation {
    take:
    input_dir
    output_dir

    main:
    def input_data = index_channel(input_dir)
    | join (index_channel(output_dir), by: 0)
    | map {
        def (index, input_dirname, output_dirname) = it
        [ input_dirname, output_dirname ]
    }

    def neuron_seg_inputs = tiff_to_n5_with_metadata(
        input_data,
        params.partial_volume,
        params.neuron_input_dataset)

    neuron_seg_inputs.subscribe { log.debug "Neuron N5 inputs: $it" }

    def neuron_scaling_results = neuron_seg_inputs
    | map {
        def (in_image, out_image, sz) = it
        [ in_image, sz ]
    }
    | neuron_scaling_factor

    neuron_scaling_results.subscribe { log.debug "Neuron scaling results: $it" }

    // get the partition size for calculating the scaling factor
    def scaling_factor_chunk_sizes = params.neuron_scaling_partition_size
                                        .tokenize(',')
                                        .collect { it.trim() as int }

    def neuron_seg_vol = neuron_seg_inputs
    | map {
        def (in_image, out_image, sz) = it
        def datatype = params.neuron_mask_as_binary
            ? 'uint8'
            : 'float32'
        log.info "Volume size: $sz"
        [
            in_image, out_image,
            params.neuron_input_dataset, params.neuron_output_dataset,
            datatype,
        ]
    }
    | create_n5_volume

    neuron_seg_vol.subscribe { log.debug "New neuron segmmented volume: $it" }

    def neuron_seg_results = neuron_seg_vol
    | join(neuron_seg_inputs, by:[0,1])
    | join(neuron_scaling_results, by:0)
    | flatMap {
        def (in_image, out_image, image_size, neuron_scaling) = it
        def image_sz_str = "${image_size[0]},${image_size[1]},${image_size[2]}"
        def scaling_factor = neuron_scaling == 'null' ? '' : neuron_scaling
        partition_volume(image_size, params.partial_volume, scaling_factor_chunk_sizes).collect {
            def (start_subvol, end_subvol) = it
            [
                in_image, out_image,
                image_sz_str, start_subvol, end_subvol,
                scaling_factor,
            ]
        }
    }
    | unet_volume_segmentation
    | groupTuple(by: [0,1,2]) // wait for all subvolumes to be done


    emit:
    done = neuron_seg_results
}

workflow neuron_scaling_factor {
    take:
    input_data

    main:
    if (params.neuron_scaling_tiles > 0 ||
        (params.neuron_percent_scaling_tiles > 0 && params.neuron_percent_scaling_tiles < 1)) {
        def scaling_factor_chunk_sizes = params.neuron_scaling_partition_size
                                            .tokenize(',')
                                            .collect { it.trim() as int }
        def scaling_factor_inputs = input_data
        | flatMap {
            def (image_filename, image_size) = it
            // calculate an optimal partitioning for neuron_scaling
            // the formula is based on not having more than <max_scaling_tiles_per_job>
            // tiles process for scaling factor in a single job
            // Formula used is scaling_chunk_size * cubic_root(max_scaling_tiles_per_job / percent_tiles_for_scaling)
            def n_tiles = number_of_subvols(image_size, params.partial_volume, scaling_factor_chunk_sizes)
            log.debug "Number of tiles for ${image_filename} of size ${image_size} using chunks of ${scaling_factor_chunk_sizes}"
            def percentage_used_for_scaling = 0
            if (params.neuron_scaling_tiles > 0) {
                percentage_used_for_scaling = params.neuron_scaling_tiles / n_tiles
            } else {
                percentage_used_for_scaling = params.neuron_percent_scaling_tiles
            }

            def partition_size_for_scaling = (scaling_factor_chunk_sizes.min() *
                Math.cbrt(params.max_scaling_tiles_per_job / percentage_used_for_scaling)) as int
            partition_volume(image_size, params.partial_volume, partition_size_for_scaling).collect {
                def (start_subvol, end_subvol) = it
                [
                    image_filename, start_subvol, end_subvol, percentage_used_for_scaling
                ]
            }
        }
        def scaling_factor_results = compute_unet_scaling(
            scaling_factor_inputs.map { it[0..2] },
            0, // we always pass the tiles used for scaling as a percentage
            scaling_factor_inputs.map { it[3] },
        )
        | groupTuple(by: 0)
        | map {
            def (input_image, scaling_factors) = it
            // average the scaling factors
            log.debug "Compute mean scaling factor for ${input_image} from ${scaling_factors}"
            def valid_scaling_factors = scaling_factors
                .findAll { it != 'null' && it != 'nan' }
                .collect { it as double }
            def scaling_factor = valid_scaling_factors 
                ? (valid_scaling_factors.average() as String)
                : 'null'
            [ input_image, scaling_factor ]
        }
        scaling_factor_results.subscribe { log.debug "Scaling factor result: $it" }

        done = scaling_factor_results
    } else {
        // no scaling factor is calculated
        done = input_data
        | map {
            def (image_filename) = it
            [ image_filename, params.user_defined_scaling ]
        }
    }

    emit:
    done
}
