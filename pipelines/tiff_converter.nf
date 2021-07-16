#!/usr/bin/env nextflow

/*
Parameters:
    input_dir
    output_n5
    output_dataset
    vvd_output_dir
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
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params)
]

include {
    tiff_to_n5;
} from '../processes/n5_tools' addParams(app_params)

include {
    tiff_to_mips;
} from '../processes/image_processing' addParams(app_params)

include {
    vvd_spark_params;
} from '../params/vvd_params' addParams(app_params)

def vvd_params = app_params +
                 vvd_spark_params(final_params) 

include {
    tiff_to_vvd;
} from '../workflows/n5_tools' addParams(vvd_params)

workflow {
    if (vvd_params.output_n5) {
        def tiff_to_n5_res = tiff_to_n5(
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
        tiff_to_n5_res.subscribe { log.debug "TIFF to N5 results: $it" }
    }

    if (app_params.mips_output_dir) {
        def tiff_to_mips_res = tiff_to_mips(
            Channel.of(
                [
                    app_params.input_dir,
                    app_params.mips_output_dir
                ]
            )
        )
        tiff_to_mips_res.subscribe { log.debug "TIFF to MIPs result: $it" }
    }

    if (vvd_params.vvd_output_dir) {
        def cluster_id = UUID.randomUUID()
        def cluster_work_dir = "${vvd_params.spark_work_dir}/${cluster_id}/tiff-to-vvd"
        def tiff_to_vvd_res = tiff_to_vvd(
            vvd_params.input_dir,  // input TIFF dir
            vvd_params.vvd_output_dir, // output dir
            vvd_params.app,
            vvd_params.spark_conf,
            cluster_work_dir,
            vvd_params.workers,
            vvd_params.worker_cores,
            vvd_params.gb_per_core,
            vvd_params.driver_cores,
            vvd_params.driver_memory,
            vvd_params.driver_stack_size,
            vvd_params.driver_logconfig
        )
        tiff_to_vvd_res.subscribe { log.debug "TIFF to VVD results: $it" }
    }
}
