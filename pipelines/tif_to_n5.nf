#!/usr/bin/env nextflow

/*
Parameters:
    input_dir
    output_n5
    output_dataset
*/

nextflow.enable.dsl=2

include {
    default_em_params;
    exm_synapse_dask_container_param;
    exm_neuron_segmentation_container;
} from '../param_utils'

def final_params = default_em_params(params)
// app parameters
def app_params = final_params + [
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params),
    exm_neuron_segmentation_container: exm_neuron_segmentation_container(final_params),
]

include {
    tiff_to_n5;
} from '../processes/n5_tools' addParams(app_params)

workflow {
    tiff_to_n5(
        Channel.of(
            [
                app_params.input_dir,
                "",
                app_params.output_n5,
                app_params.output_dataset
            ]
        ),
        app_params.partial_volume
    ) 
}
