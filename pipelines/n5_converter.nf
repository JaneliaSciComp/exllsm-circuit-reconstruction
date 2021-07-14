#!/usr/bin/env nextflow

/*
Parameters:
    input_dir
    input_dataset
    with_pyramid - if true, generate multiscale pyramid inside the input_dir
    tiff_output_dir - if set, convert n5 to tiff and save it to this directory
    mips_output_dir - if set, generates MIPs and save them to this directory
    vvd_output_dir - if set, convert n5 to VVD format and save to this directory
*/

nextflow.enable.dsl=2

include {
    default_em_params;
    exm_synapse_dask_container_param;
    exm_neuron_segmentation_container;
} from '../param_utils'

// app parameters
def final_params = default_em_params(params)

def converter_params = final_params + [
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params),
]

include {
    vvd_spark_params;
} from '../params/vvd_params'

include {
    n5_tools_spark_params;
} from '../params/n5_tools_params'

def vvd_params = converter_params +
                 vvd_spark_params(final_params) 

include {
    n5_to_vvd;
} from '../workflows/n5_tools' addParams(vvd_params)

def n5_tools_params = converter_params +
                      n5_tools_spark_params(final_params)

include {
    n5_scale_pyramid_nonisotropic;
    n5_to_tiff as n5_to_tiff_using_spark;
    n5_to_mips;
} from '../workflows/n5_tools' addParams(n5_tools_params)

include {
    n5_to_tiff as n5_to_tiff_using_dask;
} from '../processes/n5_tools' addParams(n5_tools_params)

workflow {
    def cluster_id = UUID.randomUUID()

    if (n5_tools_params.multiscale_pyramid) {
        def n5_pyramid_res = n5_scale_pyramid_nonisotropic(
            n5_tools_params.input_dir,  // input N5 dir
            n5_tools_params.input_dataset,  // N5 dataset
            n5_tools_params.app,
            n5_tools_params.spark_conf,
            "${n5_tools_params.spark_work_dir}/${cluster_id}/n5-pyramid",
            n5_tools_params.workers,
            n5_tools_params.worker_cores,
            n5_tools_params.gb_per_core,
            n5_tools_params.driver_cores,
            n5_tools_params.driver_memory,
            n5_tools_params.driver_stack_size,
            n5_tools_params.driver_logconfig
        )
        n5_pyramid_res.subscribe { log.debug "N5 downsample result: $it" }
    }
    if (n5_tools_params.tiff_output_dir) {
        if (n5_tools_params.use_n5_spark_tools) {
            def n5_to_tiff_res = n5_to_tiff_using_spark(
                n5_tools_params.input_dir,  // input N5 dir
                n5_tools_params.input_dataset,  // N5 dataset
                n5_tools_params.tiff_output_dir, // output dir
                n5_tools_params.app,
                n5_tools_params.spark_conf,
                "${n5_tools_params.spark_work_dir}/${cluster_id}/n5-to-tiff",
                n5_tools_params.workers,
                n5_tools_params.worker_cores,
                n5_tools_params.gb_per_core,
                n5_tools_params.driver_cores,
                n5_tools_params.driver_memory,
                n5_tools_params.driver_stack_size,
                n5_tools_params.driver_logconfig
            )
            n5_to_tiff_res.subscribe { log.debug "N5 to TIFF result using N5 spark tools: $it" }
        } else {
            def n5_to_tiff_res = n5_to_tiff_using_dask(
                Channel.of([
                    n5_tools_params.input_dir,  // input N5 dir
                    n5_tools_params.input_dataset,  // N5 dataset
                    n5_tools_params.tiff_output_dir // output dir
                ])
            )
            n5_to_tiff_res.subscribe { log.debug "N5 to TIFF result using N5 dask tools: $it" }
        }
    }

    if (n5_tools_params.mips_output_dir) {
        def n5_to_mips_res = n5_to_mips(
            n5_tools_params.input_dir,  // input N5 dir
            n5_tools_params.input_dataset,  // N5 dataset
            n5_tools_params.mips_output_dir, // output dir
            n5_tools_params.app,
            n5_tools_params.spark_conf,
            "${n5_tools_params.spark_work_dir}/${cluster_id}/n5-to-mips",
            n5_tools_params.workers,
            n5_tools_params.worker_cores,
            n5_tools_params.gb_per_core,
            n5_tools_params.driver_cores,
            n5_tools_params.driver_memory,
            n5_tools_params.driver_stack_size,
            n5_tools_params.driver_logconfig
        )
        n5_to_mips_res.subscribe { log.debug "N5 to MIPs result: $it" }
    }

    if (vvd_params.vvd_output_dir) {
        def n5_to_vvd_res = n5_to_vvd(
            vvd_params.input_dir,  // input N5 dir
            vvd_params.input_dataset,  // N5 dataset
            vvd_params.vvd_output_dir, // output dir
            vvd_params.app,
            vvd_params.spark_conf,
            "${vvd_params.spark_work_dir}/${cluster_id}/n5-to-vvd",
            vvd_params.workers,
            vvd_params.worker_cores,
            vvd_params.gb_per_core,
            vvd_params.driver_cores,
            vvd_params.driver_memory,
            vvd_params.driver_stack_size,
            vvd_params.driver_logconfig
        )
        n5_to_vvd_res.subscribe { log.debug "N5 to VVD results: $it" }
    }
}
