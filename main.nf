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
    exm_synapse_container_param;
} from './param_utils'

// app parameters
final_params = default_spark_params() + default_em_params() + params

include {
    prepare_stitching_data;
    get_stitched_volume_meta
} from './processes/stitching' addParams(final_params)

include {
    prepare_tiles_for_stitching;
} from './workflows/prestitching' addParams(final_params)

include {
    stitching;
    mock_stitching;
} from './workflows/stitching' addParams(final_params)

deconv_params = final_params + [
    deconvolution_container: deconvolution_container_param(final_params),
]
include {
    deconvolution
} from './workflows/deconvolution' addParams(deconv_params)

synapse_params = final_params + [
    exm_synapse_container: exm_synapse_container_param(final_params),
]
include {
    find_synapses;
    get_tiff_stack_metadata;
} from './workflows/synapse_detection' addParams(synapse_params)

data_dir = final_params.data_dir
pipeline_output_dir = get_value_or_default(final_params, 'output_dir', data_dir)
create_output_dir(pipeline_output_dir)

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
    def datasets = Channel.fromList(
        get_list_or_default(final_params, 'datasets', [])
    )
    def stitching_data = prepare_stitching_data(
        data_dir,
        pipeline_output_dir,
        datasets,
        final_params.stitching_output,
        spark_work_dir
    ) // [ dataset, dataset_input_dir, stitching_dir, dataset_output_dir, stitching_working_dir ]

    stitching_data.subscribe { log.debug "Stitching: $it" }
/*!!!!!!
    def pre_stitching_res = prepare_tiles_for_stitching(
        final_params.stitching_app,
        stitching_data.map { it[0] },  // dataset
        stitching_data.map { it[1] },  // data input dir
        stitching_data.map { it[2] },  // stitching dir
        channels,
        final_params.resolution,
        final_params.axis,
        final_params.block_size,
        spark_conf,
        stitching_data.map { "${it[4]}/prestitch" }, // spark_working_dir
        spark_workers,
        spark_worker_cores,
        spark_gb_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig
    )

    pre_stitching_res.subscribe { log.debug "Pre stitch results: $it" }

    def deconv_res = deconvolution(
        pre_stitching_res.map { it[0] }, // dataset
        pre_stitching_res.map { it[2] }, // stitching_dir
        channels,
        channels_psfs,
        final_params.psf_z_step_um,
        final_params.background,
        iterations_per_channel
    )
    | groupTuple(by: [0,2]) // groupBy [ dataset, input_dir ]
    | map {
        [
            it[0], // dataset
            it[2], // stitching_dir
            it[1], // channels
            it[3]  // deconv_res
        ]
    }
    deconv_res | view

    def stitching_input = deconv_res
    | join(stitching_data, by: 0) // [ dataset, stitching_dir, channels, deconv_json_res, dataset_input_dir, stitching_dir, dataset_output_dir, dataset_working_dir ]

    stitching_input | view

    def stitching_res = stitching(
        final_params.stitching_app,
        stitching_input.map { it[0] }, // dataset
        stitching_input.map { it[1] }, // stitching_dir
        channels, // channels
        final_params.stitching_mode,
        final_params.stitching_padding,
        final_params.blur_sigma,
        final_params.export_level,
        final_params.export_fusestage,
        spark_conf,
        stitching_input.map { "${it[7]}/stitch" }, // spark working dir
        spark_workers,
        spark_worker_cores,
        spark_gb_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig
    )
    stitching_res | view
!!!!!*/

    def stitching_res = mock_stitching(
        final_params.stitching_app,
        stitching_data.map { it[0] }, // dataset
        stitching_data.map { it[2] }, // stitching_dir
        channels, // channels
        final_params.stitching_mode,
        final_params.stitching_padding,
        final_params.blur_sigma,
        final_params.export_level,
        final_params.export_fusestage,
        spark_conf,
        stitching_data.map { "${it[4]}/stitch" }, // spark working dir
        spark_workers,
        spark_worker_cores,
        spark_gb_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig
    )

    def synapse_ch_metadata = get_tiff_stack_metadata(
        stitching_res.map { "${it[1]}/slice-tiff-s${final_params.synapse_channel}/ch${final_params.synapse_channel_subfolder}" }
    )
    synapse_ch_metadata | view

    def n1_ch_metadata = get_tiff_stack_metadata(
        stitching_res.map { "${it[1]}/slice-tiff-s${final_params.synapse_channel}/ch${final_params.n1_channel_subfolder}" }
    )
    n1_ch_metadata | view

    def synapse_input =  stitching_data
    | map {
        // [ dataset, stitching_dir, synapse_channel, export_scale ]
        [ it[0], it[2], final_params.synapse_channel, final_params.export_level ]
    }
    | join(stitching_res, by: [0,1])
    | get_stitched_volume_meta
    | join(stitching_data, by:0)
    | map {
        [ 
            it[0], // dataset
            it[1], // stitching_dir
            it[5], // dataset_input_dir
            it[7], // dataset_results_dir
            it[2], // synapse channel
            it[3], // export scale
            it[4], // volume metadata
        ]
    }

/*
    def synapses_res = find_synapses(
        synapse_input.map { it[0] }, //dataset
        synapse_input.map { "${it[1]}/slice-tiff-s${it[5]}/ch${it[4]}" },
        synapse_input.map { "${it[3]}/synapses" },
        synapse_input.map { "${it[3]}/h5_tmp" },
        synapse_input.map { it[6] } // metadata
    )

    synapses_res | view
*/
}

def create_output_dir(output_dirname) {
    def output_dir = file(output_dirname)
    output_dir.mkdirs()
}

def get_step_output_dir(output_parent_dir, step_output) {
    step_output
        ? new File(output_parent_dir)
        : new File(output_parent_dir, step_output)
}
