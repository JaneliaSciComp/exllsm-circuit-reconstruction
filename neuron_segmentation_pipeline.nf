#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_em_params;
    get_value_or_default;
    exm_synapse_dask_container_param;
    exm_neuron_segmentation_container;
} from './param_utils'

// app parameters
final_params = default_em_params() + params

neuron_seg_params = final_params + [
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params),
    exm_neuron_segmentation_container: exm_neuron_segmentation_container(final_params),
]

include {
    neuron_segmentation;
} from './workflows/neuron_segmentation' addParams(neuron_seg_params)

pipeline_output_dir = final_params.output_dir

workflow {
    def neuron_res = neuron_segmentation(
        final_params.neuron_stack_dir,
        pipeline_output_dir,
    );
    neuron_res | view
}
