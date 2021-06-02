#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_em_params;
    get_value_or_default;
    exm_synapse_dask_container_param;
    exm_neuron_segmentation_container;
} from './param_utils'

// app parameters
def final_params = default_em_params(params)

def neuron_seg_params = final_params + [
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params),
    exm_neuron_segmentation_container: exm_neuron_segmentation_container(final_params),
]

include {
    neuron_segmentation;
} from './workflows/neuron_segmentation' addParams(neuron_seg_params)

include {
    neuron_connected_comps_spark_params
} from './params/neuron_params'

def neuron_comp_params = neuron_seg_params +
                         neuron_connected_comps_spark_params(final_params) 

include {
    connected_components
} from './workflows/connected_components' addParams(neuron_comp_params)


include {
    vvd_spark_params
} from './params/vvd_params'

def vvd_params = neuron_seg_params +
                 vvd_spark_params(final_params) 

include {
    n5_to_vvd
} from './workflows/n5_tools' addParams(vvd_params)

pipeline_output_dir = final_params.output_dir

workflow {
    def neuron_res = neuron_segmentation(
        final_params.neuron_stack_dir,
        pipeline_output_dir,
    );
    neuron_res | view
    def connected_comps_res;
    if (final_params.with_connected_comps) {
        connected_comps_res = connected_components(
            stitching_data.map { it[0] },  // images dir
            stitching_data.map { it[1] },  // stitching dir
            channels,
            final_params.resolution,
            final_params.axis,
            final_params.block_size,
            final_params.stitching_app,
            spark_conf,
            stitching_data.map { "${it[2]}/prestitch" }, // spark_working_dir
            spark_workers,
            spark_worker_cores,
            spark_gb_per_core,
            spark_driver_cores,
            spark_driver_memory,
            spark_driver_stack,
            spark_driver_logconfig

        )
    } else {
        connected_comps_res = neuron_res
    }
    connected_comps_res | view
    if (final_params.with_vvd_convert) {

    }
}
