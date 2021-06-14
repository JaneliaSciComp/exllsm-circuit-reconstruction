#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_em_params;
    exm_synapse_dask_container_param;
    exm_neuron_segmentation_container;
    get_spark_working_dir;
} from './param_utils'

// app parameters
def final_params = default_em_params(params)

def converter_params = final_params + [
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params),
]

include {
    vvd_spark_params;
} from './params/vvd_params'

include {
    n5_2_tif_spark_params;
} from './params/n5_2_tif_params'

def vvd_params = converter_params +
                 vvd_spark_params(final_params) 

include {
    n5_to_vvd;
} from './workflows/n5_tools' addParams(vvd_params)

def n5_2_tif_params = converter_params +
                      n5_2_tif_spark_params(final_params)

include {
    downsample_n5;
    n5_to_tiff as n5_to_tiff_using_spark;
    n5_to_mips;
} from './workflows/n5_tools' addParams(n5_2_tif_params)

include {
    n5_to_tiff as n5_to_tiff_using_dask;
} from './processes/n5_tools' addParams(n5_2_tif_params)

workflow {
    if (n5_2_tif_params.with_downsampling) {
        def n5_downsample_res = downsample_n5(
            n5_2_tif_params.images_dir,  // input N5 dir
            n5_2_tif_params.default_n5_dataset,  // N5 dataset
            n5_2_tif_params.app,
            n5_2_tif_params.spark_conf,
            "${get_spark_working_dir(n5_2_tif_params.spark_work_dir)}/n5-downsample",
            n5_2_tif_params.workers,
            n5_2_tif_params.worker_cores,
            n5_2_tif_params.gb_per_core,
            n5_2_tif_params.driver_cores,
            n5_2_tif_params.driver_memory,
            n5_2_tif_params.driver_stack_size,
            n5_2_tif_params.driver_logconfig
        )
        n5_downsample_res.subscribe { log.debug "N5 downsample result: $it" }
    }
    if (n5_2_tif_params.tiff_output_dir) {
        if (n5_2_tif_params.use_n5_spark_tools) {
            def n5_to_tiff_res = n5_to_tiff_using_spark(
                n5_2_tif_params.images_dir,  // input N5 dir
                n5_2_tif_params.default_n5_dataset,  // N5 dataset
                n5_2_tif_params.tiff_output_dir, // output dir
                n5_2_tif_params.app,
                n5_2_tif_params.spark_conf,
                "${get_spark_working_dir(n5_2_tif_params.spark_work_dir)}/n5-to-tiff",
                n5_2_tif_params.workers,
                n5_2_tif_params.worker_cores,
                n5_2_tif_params.gb_per_core,
                n5_2_tif_params.driver_cores,
                n5_2_tif_params.driver_memory,
                n5_2_tif_params.driver_stack_size,
                n5_2_tif_params.driver_logconfig
            )
            n5_to_tiff_res.subscribe { log.debug "N5 to TIFF result using N5 spark tools: $it" }
        } else {
            def n5_to_tiff_res = n5_to_tiff_using_dask(
                n5_2_tif_params.images_dir,  // input N5 dir
                n5_2_tif_params.default_n5_dataset,  // N5 dataset
                n5_2_tif_params.tiff_output_dir, // output dir
            )
            n5_to_tiff_res.subscribe { log.debug "N5 to TIFF result using N5 dask tools: $it" }
        }
    }

    if (n5_2_tif_params.mips_output_dir) {
        def n5_to_mips_res = n5_to_mips(
            n5_2_tif_params.images_dir,  // input N5 dir
            n5_2_tif_params.default_n5_dataset,  // N5 dataset
            n5_2_tif_params.mips_output_dir, // output dir
            n5_2_tif_params.app,
            n5_2_tif_params.spark_conf,
            "${get_spark_working_dir(n5_2_tif_params.spark_work_dir)}/n5-to-mips",
            n5_2_tif_params.workers,
            n5_2_tif_params.worker_cores,
            n5_2_tif_params.gb_per_core,
            n5_2_tif_params.driver_cores,
            n5_2_tif_params.driver_memory,
            n5_2_tif_params.driver_stack_size,
            n5_2_tif_params.driver_logconfig
        )
        n5_to_mips_res.subscribe { log.debug "N5 to MIPs result: $it" }
    }

    if (vvd_params.vvd_output_dir) {
        def n5_to_vvd_res = n5_to_vvd(
            vvd_params.images_dir,  // input N5 dir
            vvd_params.default_n5_dataset,  // N5 dataset
            vvd_params.vvd_output_dir, // output dir
            vvd_params.app,
            vvd_params.spark_conf,
            "${get_spark_working_dir(vvd_params.spark_work_dir)}/n5-to-vvd",
            vvd_params.workers,
            vvd_params.worker_cores,
            vvd_params.gb_per_core,
            vvd_params.driver_cores,
            vvd_params.driver_memory,
            vvd_params.driver_stack_size,
            vvd_params.driver_logconfig
        )
    }
}
