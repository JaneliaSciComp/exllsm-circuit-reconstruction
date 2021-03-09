#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_spark_params;
} from './external-modules/spark/lib/param_utils'

include {
    default_em_params;
    get_value_or_default;
    get_list_or_default;
} from './param_utils'

// app parameters
final_params = default_spark_params() + default_em_params() + params

include {
    prepare_stitching_data;
    prepare_tiles_for_stitching;
} from './workflows/stitching' addParams(lsf_opts: final_params.lsf_opts, 
                                         crepo: final_params.crepo,
                                         spark_version: final_params.spark_version)

// include {
//     deconvolution
// } from './workflows/deconvolution' addParams(lsf_opts: final_params.lsf_opts, 
//                                              deconvrepo: final_params.deconvrepo)

data_dir = final_params.data_dir
pipeline_output_dir = get_value_or_default(final_params, 'output_dir', data_dir)
create_output_dir(pipeline_output_dir)

channels = get_list_or_default(final_params, 'channels', [])

// spark config
spark_conf = final_params.spark_conf
spark_work_dir = final_params.spark_work_dir
spark_workers = final_params.workers
spark_worker_cores = final_params.worker_cores
gb_per_core = final_params.gb_per_core
driver_cores = final_params.driver_cores
driver_memory = final_params.driver_memory
driver_stack = final_params.driver_stack
driver_logconfig = final_params.driver_logconfig

stitching_app = final_params.stitching_app
resolution = final_params.resolution
axis_mapping = final_params.axis

// deconvolution params
psf_dirname = final_params.psf_dir
iterations_per_channel = get_list_or_default(final_params, 'iterations_per_channel', []).collect {
    it as int
}
channels_psfs = channels.collect {
    ch = it.replace('nm', '')
    return "${psf_dirname}/${ch}_PSF.tif"
}

workflow {
    def datasets = Channel.fromList(
        get_list_or_default(final_params, 'datasets', [])
    )
    def stitching_data = prepare_stitching_data(
        datasets,
        data_dir,
        pipeline_output_dir,
        final_params.stitching_output,
        spark_work_dir
    )

    pre_stitching_res = prepare_tiles_for_stitching(
        stitching_app,
        stitching_data.map { it[0] },  // dataset
        stitching_data.map { it[1] },  // dataset input dir
        channels,
        resolution,
        axis_mapping,
        block_size,
        spark_conf,
        spark_work_dir,
        spark_workers,
        spark_worker_cores,
        gb_per_core,
        driver_cores,
        driver_memory,
        driver_stack,
        driver_logconfig
    )
    // deconv_res = deconvolution(
    //     pre_stitching_res, 
    //     channels,
    //     channels_psfs,
    //     psf_z_step_um,
    //     background,
    //     iterations_per_channel,
    //     deconv_cores)
    
    // deconv_res | view
}

def get_step_output_dir(output_parent_dir, step_output) {
    step_output
        ? new File(output_parent_dir)
        : new File(output_parent_dir, step_output)
}
