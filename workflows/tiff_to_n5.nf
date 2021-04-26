include {
    read_n5_metadata;
    tiff_to_n5;
} from '../processes/synapse_detection'

workflow tiff_to_n5_with_metadata {
    take:
    input_data // pair of tiff_stack and n5_file

    main:
    def n5_results = tiff_to_n5(input_data)
    def stack_with_metadata = read_n5_metadata(n5_results)

    emit:
    done = stack_with_metadata
}
