include {
    read_n5_metadata;
    tiff_to_n5;
} from '../processes/n5_tools'

include {
    json_text_to_data;
} from '../utils/utils'

workflow tiff_to_n5_with_metadata {
    take:
    input_data // pair of input_stack and n5_file
    partial_volume
    n5_dataset

    main:
    def n5_results = tiff_to_n5(input_data, partial_volume)
    n5_results.subscribe { log.debug "TIFF to N5 result: $it" }

    def stack_with_metadata = read_n5_metadata(
        n5_results.map { it[0] },
        n5_dataset
    )
    | map {
        def (n5_stack, n5_attributes_content) = it
        def n5_stack_dims = json_text_to_data(n5_attributes_content).dimensions
        def r = [ n5_stack, n5_stack_dims ]
        log.debug "N5 stack with dims: $r"
        r
    }
    | join(n5_results, by:0)
    | map {
        def (n5_stack_used_4_dim, n5_stack_dims, input_stack, output_n5_stack) = it
        [ input_stack, output_n5_stack, n5_stack_dims ]
    }

    emit:
    done = stack_with_metadata
}
