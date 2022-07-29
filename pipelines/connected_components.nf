#!/usr/bin/env nextflow

/*
Parameters:
    input_n5
    input_dataset
    connected_dataset
    min_connected_pixels
    connected_pixels_shape
    connected_pixels_threshold
*/

nextflow.enable.dsl=2

include {
    default_em_params;
    exm_synapse_dask_container_param;
    exm_neuron_segmentation_container;
} from '../param_utils'

// app parameters
def final_params = default_em_params(params)

def neuron_seg_params = final_params + [
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params),
    exm_neuron_segmentation_container: exm_neuron_segmentation_container(final_params),
]

include {
    neuron_connected_comps_spark_params;
} from '../params/neuron_params'

def neuron_comp_params = neuron_seg_params +
                         neuron_connected_comps_spark_params(final_params) 

include {
    connected_components;
} from '../workflows/connected_components' addParams(neuron_comp_params)

workflow {
    def session_id = UUID.randomUUID()

    connected_comps_res = connected_components(
        neuron_comp_params.input_n5, // n5 input
        neuron_comp_params.input_dataset, // n5 container sub-dir (c0/s0)
        neuron_comp_params.connected_dataset, // sub dir for connected comp
        neuron_comp_params.app,
        neuron_comp_params.spark_conf,
        "${neuron_comp_params.spark_work_dir}/${session_id}/connected-comps",
        neuron_comp_params.workers,
        neuron_comp_params.worker_cores,
        neuron_comp_params.gb_per_core,
        neuron_comp_params.driver_cores,
        neuron_comp_params.driver_memory,
        neuron_comp_params.driver_stack_size,
        neuron_comp_params.driver_logconfig
    )

    connected_comps_res.subscribe { log.debug "Neuron connected commponents: $it" }
}