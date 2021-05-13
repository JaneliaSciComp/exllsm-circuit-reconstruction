#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_em_params;
} from './param_utils'

// app parameters
final_params = default_em_params() + params

include {
    connect_mask;
} from './workflows/image_processing'

workflow {

    connect_mask(
        Channel.of(
            [
                final_params.input_mask_dir, 
                final_params.shared_temp_dir, 
                final_params.output_mask_dir
            ]
        )
    )

}