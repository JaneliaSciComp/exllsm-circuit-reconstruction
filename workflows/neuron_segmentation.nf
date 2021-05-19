include {
    tiff_to_n5_with_metadata;
} from './tiff_to_n5'

include {
    create_n5_volume;
} from '../processes/n5_tools'

include {
    unet_volume_segmentation;
} from '../processes/neuron_segmentation'

include {
    index_channel;
} from '../utils/utils'

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
    def neuron_with_metadata = tiff_to_n5_with_metadata(input_data, params.neuron_input_dataset)
    neuron_with_metadata | view
    def neuron_seg_inputs = create_n5_volume(
        neuron_with_metadata.map {
            def (in_image, out_image, sz) = it
            log.info "Volume size: $sz"
            [
                in_image, out_image,
                params.neuron_input_dataset, params.neuron_output_dataset,
            ]
        }
    )
    | join(neuron_with_metadata, by:[0,1])


    emit:
    done = neuron_seg_inputs
}