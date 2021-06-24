#!/usr/bin/env nextflow
/*
Parameters:
    input_dir
    output_dir
    threshold
*/

nextflow.enable.dsl=2

include {
    default_em_params;
} from '../param_utils'

// app parameters
def final_params = default_em_params(params)

include {
    threshold_tiff;
} from '../processes/image_processing' addParams(final_params)

workflow {

    threshold_tiff(
        Channel.of(
            [
                final_params.input_dir, 
                final_params.output_dir
            ]
        )
    )

}