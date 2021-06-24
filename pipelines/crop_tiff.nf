#!/usr/bin/env nextflow

/*
Parameters:
    input_dir
    output_dir
    roi_dir
    crop_start_slice
    crop_end_slice
    crop_format (one of "TIFFPackBits_8bit", "ZIP", "uncompressedTIFF", "TIFFPackBits_8bit", "LZW")
*/

nextflow.enable.dsl=2

include {
    default_em_params;
} from '../param_utils'

// app parameters
def final_params = default_em_params(params)

include {
    crop_tiff;
} from '../processes/image_processing' addParams(final_params)

workflow {

    crop_tiff(
        Channel.of(
            [
                final_params.input_dir, 
                final_params.output_dir,
                final_params.roi_dir,
            ]
        )
    )

}