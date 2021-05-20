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
    def neuron_seg_inputs = tiff_to_n5_with_metadata(input_data, params.neuron_input_dataset)

    def neuron_scaling_results = neuron_scaling_factor(
        neuron_seg_inputs.map { it[0] }
    )

    def neuron_seg_results = create_n5_volume(
        neuron_seg_inputs.map {
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
    )
    | join(neuron_seg_inputs, by:[0,1])
    | join(neuron_scaling_results, by:0)
    | flatMap {
        def (in_image, out_image, image_size, neuron_scaling) = it
        def image_sz_str = "${image_size[0]},${image_size[1]},${image_size[2]}"
        def scaling_factor = neuron_scaling == 'null' ? '' : neuron_scaling
        partition_volume(image_size).collect {
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
    input_dir

    main:
    done = compute_unet_scaling(input_dir)

    emit:
    done
}
