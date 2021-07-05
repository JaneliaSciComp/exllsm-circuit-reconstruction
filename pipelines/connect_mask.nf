#!/usr/bin/env nextflow

/*
Parameters:
    input_dir
    output_dir
    shared_temp_dir
    mask_connection_distance
    mask_connection_iterations
*/

nextflow.enable.dsl=2

include {
    default_em_params;
} from '../param_utils'

// app parameters
def final_params = default_em_params(params)

include {
    prepare_mask_dirs;
    convert_from_mask;
    append_brick_files;
    connect_tiff;
    convert_to_mask;
    complete_mask;
} from '../processes/image_processing' addParams(final_params)

workflow connect_mask {
    take:
    input_vals

    main:
    connected_tiff = prepare_mask_dirs(input_vals) 
                    | convert_from_mask
                    | append_brick_files
                    | flatMap {
                        def (input_dir, output_dir, shared_temp_dir, threshold_dir, connect_dir, bricks) = it
                        bricks.tokenize(' ').collect { brick_file ->
                            [ input_dir, output_dir, shared_temp_dir, threshold_dir, connect_dir, brick_file ]
                        }
                    }
                    | connect_tiff
                    | groupTuple(by:[0,1,2,3,4])
                    | map { it[0..4] }
                    | convert_to_mask
                    | complete_mask
    
    emit:
    connected_tiff
}

workflow {

    connect_mask(
        Channel.of(
            [
                final_params.input_dir, 
                final_params.shared_temp_dir, 
                final_params.output_dir
            ]
        )
    )

}