include {
    read_n5_metadata;
    tiff_to_n5;
} from '../processes/n5_tools'

include {
    json_text_to_data;
} from '../utils/utils'

workflow tiff_to_n5_with_metadata {
    take:
    input_data // pair of tiff_stack and n5_file
    n5_dataset

    main:
    def n5_results = tiff_to_n5(input_data)
    def stack_with_metadata = read_n5_metadata(
        n5_results.map { it[1] }
        n5_dataset
    )
    | map {
        def (n5_stack, n5_attributes_content) = it
        def n5_stack_dims = json_text_to_data(n5_attributes_content).dimensions
        [ n5_stack_dims, n5_stack]
    }
    | join(n5_results, by:1)
    | map {
        def (n5_stack, n5_stack_dims, tiff_stack) = it
        [ tiff_stack, n5_stack, n5_stack_dims ]
    }

    emit:
    done = stack_with_metadata
}
