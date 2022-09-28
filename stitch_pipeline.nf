#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    stitching_spark_params;
} from './params/stitching_params'

include {
    default_em_params;
    get_value_or_default;
    get_list_or_default;
    deconvolution_container_param;
    stitching_container_param;
} from './param_utils'

// app parameters
def default_params = default_em_params(params)
def final_params =  default_params +
                    stitching_spark_params(default_params) +
                    [
                        stitching_container: stitching_container_param(default_params),
                        deconvolution_container: deconvolution_container_param(default_params),
                    ]
include {
    prepare_stitching_data;
} from './processes/stitching' addParams(final_params)

include {
    prepare_tiles_for_stitching as prestitching;
} from './workflows/prestitching' addParams(final_params)

include {
    stitching;
} from './workflows/stitching' addParams(final_params)

include {
    deconvolution
} from './workflows/deconvolution' addParams(final_params)

workflow {
    def images_dir = get_value_or_default(final_params, 'images_dir', final_params.input_dir)
    def pipeline_output_dir = get_value_or_default(final_params, 'output_dir', images_dir)
    def stitching_dir = final_params.stitching_output 
            ? "${pipeline_output_dir}/${final_params.stitching_output}"
            : pipeline_output_dir

    def channels = get_list_or_default(final_params, 'channels', [])
    def skip = get_list_or_default(final_params, 'skip', [])
    // deconvolution params
    def iterations_per_channel = get_list_or_default(final_params, 'iterations_per_channel', [])
        .collect {
            it as int
        }
    def channels_psfs = channels.collect {
        def ch = it.replace('nm', '')
        return "${final_params.psf_dir}/${ch}_PSF.tif"
    }

    log.info """
        channels: ${channels}
        skipped_steps: ${skip}
        spark_workers: ${final_params.workers}
        """.stripIndent()

    def stitching_data = prepare_stitching_data(
        Channel.of(images_dir),
        Channel.of(stitching_dir),
        Channel.of(final_params.spark_work_dir)
    ) // [ input_images_dir, stitching_dir, stitching_working_dir ]

    stitching_data.subscribe { log.debug "Stitching: $it" }

    def pre_stitching_res
    if (skip.contains('prestitching')) {
        // skip prestitching
        pre_stitching_res = stitching_data
        | map {
            def (input_images_dir, stitching_dirname) = it
            [ input_images_dir, stitching_dirname ]
        }
    } else {
        pre_stitching_res = prestitching(
            stitching_data.map { it[0] },  // images dir
            stitching_data.map { it[1] },  // stitching dir
            channels,
            final_params.resolution,
            final_params.axis,
            final_params.block_size,
            final_params.app, // app.jar location
            final_params.spark_conf,
            stitching_data.map { "${it[2]}/prestitch" }, // spark_working_dir
            final_params.workers,
            final_params.worker_cores,
            final_params.gb_per_core,
            final_params.driver_cores,
            final_params.driver_memory,
            final_params.driver_stack_size,
            final_params.driver_logconfig
        ) // [ input_images_dir, stitching_dir ]
        pre_stitching_res.subscribe { log.debug "Pre stitch results: $it" }
    }

    def stitching_input
    if (skip.contains('deconvolution')) {
        // skip deconvolution
        stitching_input = stitching_data
        | join(pre_stitching_res, by:[0,1])
        | map {
            def (input_images_dir, stitching_dirname, stitching_working_dir) = it
            def stitching_dir_file = file(stitching_dirname)
            def stitching_working_dir = file(stitching_working_dir)
            def r = [ "${stitching_dir_file}", "${stitching_working_dir}" ]
            log.info "Prepare stitching input: $r"
            r
        }
    } else {
        def deconv_res = deconvolution(
            pre_stitching_res.map { it[1] }, // stitching_dir
            channels,
            channels_psfs,
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

        stitching_input = stitching_data
        | map {
            def (stitching_dirname, stitching_working_dir) = it[1..2] // [ stitching_dir, stitching_work_dir ]
            def stitching_dir_file = file(stitching_dirname)
            def stitching_working_dir = file(stitching_working_dir)
            def r = [ "${stitching_dir_file}", "${stitching_working_dir}" ]
            log.info "Prepare stitching input: $r"
            r
        }
        | join(deconv_res, by: 0) // [ stitching_dir, stitching_work_dir, channels, deconv_json_res ]

        stitching_input | view
    }

    if (!skip.contains('stitch') || !skip.contains('fuse') || !skip.contains('tiff-export')) {
        def stitching_res = stitching(
            stitching_input.map { it[0] }, // stitching_dir
            channels,
            final_params.stitching_mode,
            final_params.stitching_padding,
            final_params.stitching_blur_sigma,
            final_params.export_level,
            final_params.allow_fusestage,
            skip,
            final_params.app, // app.jar location
            final_params.spark_conf,
            stitching_input.map { "${it[1]}/stitch" }, // spark working dir
            final_params.workers,
            final_params.worker_cores,
            final_params.gb_per_core,
            final_params.driver_cores,
            final_params.driver_memory,
            final_params.driver_stack_size,
            final_params.driver_logconfig
        )
        stitching_res | view
    }
}
