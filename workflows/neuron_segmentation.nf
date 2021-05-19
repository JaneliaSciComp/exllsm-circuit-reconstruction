include {
    tiff_to_n5_with_metadata;
} from './tiff_to_n5'

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
    def neuron_seg_inputs = index_channel(input_dir)
    | join (index_channel(output_dir), by: 0)
    | map {
        def (index, input_dirname, output_dirname) = it
        [ input_dirname, output_dirname ]
    }
    neuron_n5_inputs = tiff_to_n5_with_metadata(neuron_seg_inputs, params.neuron_input_dataset)

    emit:
    done = neuron_seg_inputs
}