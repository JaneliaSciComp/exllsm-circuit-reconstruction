#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_spark_params;
} from './external-modules/spark/lib/param_utils'

include {
    default_em_params;
    get_value_or_default;
    get_list_or_default;
    deconvolution_container_param;
    stitching_container_param;
} from './param_utils'

// app parameters
final_params = default_spark_params() + default_em_params() + params

stitch_params = final_params + [
    stitching_container: stitching_container_param(final_params)
]
include {
    prepare_stitching_data;
} from './processes/stitching' addParams(stitch_params)

include {
    prepare_tiles_for_stitching as prestitching;
} from './workflows/prestitching' addParams(stitch_params)

include {
    stitching;
} from './workflows/stitching' addParams(stitch_params)

deconv_params = final_params + [
    deconvolution_container: deconvolution_container_param(final_params),
]
include {
    deconvolution
} from './workflows/deconvolution' addParams(deconv_params)

images_dir = final_params.images_dir
pipeline_output_dir = get_value_or_default(final_params, 'output_dir', images_dir)
stitching_dir = final_params.stitching_output 
        ? "${pipeline_output_dir}/${final_params.stitching_output}"
        : pipeline_output_dir

channels = get_list_or_default(final_params, 'channels', [])

// spark config
spark_conf = final_params.spark_conf
spark_work_dir = final_params.spark_work_dir
spark_workers = final_params.workers
spark_worker_cores = final_params.worker_cores
spark_gb_per_core = final_params.gb_per_core
spark_driver_cores = final_params.driver_cores
spark_driver_memory = final_params.driver_memory
spark_driver_stack = final_params.driver_stack
spark_driver_logconfig = final_params.driver_logconfig

// deconvolution params
iterations_per_channel = get_list_or_default(final_params, 'iterations_per_channel', []).collect {
    it as int
}
channels_psfs = channels.collect {
    ch = it.replace('nm', '')
    return "${final_params.psf_dir}/${ch}_PSF.tif"
}

workflow {
    def stitching_data = prepare_stitching_data(
        Channel.of(images_dir),
        Channel.of(stitching_dir),
        Channel.of(spark_work_dir)
    ) // [ input_images_dir, stitching_dir, stitching_working_dir ]

    stitching_data.subscribe { log.debug "Stitching: $it" }

    def pre_stitching_res = prestitching(
        final_params.stitching_app,
        stitching_data.map { it[0] },  // images dir
        stitching_data.map { it[1] },  // stitching dir
        channels,
        final_params.resolution,
        final_params.axis,
        final_params.block_size,
        spark_conf,
        stitching_data.map { "${it[2]}/prestitch" }, // spark_working_dir
        spark_workers,
        spark_worker_cores,
        spark_gb_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig
    ) // [ input_images_dir, stitching_dir ]

    pre_stitching_res.subscribe { log.debug "Pre stitch results: $it" }

    def deconv_res = deconvolution(
        pre_stitching_res.map { it[1] }, // stitching_dir
        channels,
        channels_psfs,
        final_params.psf_z_step_um,
        final_params.background,
        iterations_per_channel
    )
    | groupTuple(by: 1) // groupBy input_dir
    | map {
        [
            it[1], // stitching_dir
            it[0], // channels
            it[2]  // deconv_res
        ]
    }
    deconv_res | view

    def stitching_input = stitching_data
    | map {
        it[1..2] // [ stitching_dir, stitching_work_dir ]
    }
    | join(deconv_res, by: 0) // [ stitching_dir, stitching_work_dir, channels, deconv_json_res ]

    stitching_input | view

    def stitching_res = stitching(
        final_params.stitching_app,
        stitching_input.map { it[0] }, // stitching_dir
        channels,
        final_params.stitching_mode,
        final_params.stitching_padding,
        final_params.blur_sigma,
        final_params.export_level,
        final_params.export_fusestage,
        spark_conf,
        stitching_input.map { "${it[1]}/stitch" }, // spark working dir
        spark_workers,
        spark_worker_cores,
        spark_gb_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig
    )
    stitching_res | view
}
