def default_em_params() {
    [
        scicomp_repo: 'registry.int.janelia.org/janeliascicomp',
        exm_repo: 'registry.int.janelia.org/exm-analysis',

        datasets: '',
        data_dir: '',
        output_dir: '',
        stitched_data_dir: '',

        stitching_output: 'stitching',

        // stitching params
        stitching_app: 'external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar',
        driver_stack: '128m',
        stitching_output: 'stitching',
        resolution: '0.104,0.104,0.18',
        axis: '-y,-x,z',
        channels: '488nm,560nm,642nm',
        block_size: '128,128,64',
        retile_z_size: '64',
        stitching_mode: 'incremental',
        stitching_padding: '0,0,0',
        blur_sigma: '2',
        export_level: '0',
        export_fusestage: false,

        deconv_cpus: 4,
        background: '',
        psf_z_step_um: '0.1',
        iterations_per_channel: '10,10,10',

        pipeline: 'presynaptic_in_volume',
        // synapse detection params
        pre_synapse_channel_subfolder: '',
        n1_channel_subfolder: '',
        n2_channel_subfolder: '',
        post_synapse_channel_subfolder: '',

        tiff2h5_cpus: 3,
        h52tiff_cpus: 3,
        unet_cpus: 4,
        synapse_model: '/groups/dickson/dicksonlab/lillvis/ExM/Ding-Ackerman/crops-for-training_Oct2018/DING/model_DNN/saved_unet_model_2020/unet_model_synapse2020_6/unet_model_synapse2020_6.whole.h5',
        postprocessing_cpus: 3,
        volume_partition_size: 1000,
        presynaptic_stage2_threshold: 100,
        presynaptic_stage2_percentage: 1,
        postsynaptic_stage2_threshold: 100,
        postsynaptic_stage2_percentage: 1,
    ]
}

def get_value_or_default(Map ps, String param, String default_value) {
    if (ps[param])
        ps[param]
    else
        default_value
}

def get_list_or_default(Map ps, String param, List default_list) {
    def value
    if (ps[param])
        value = ps[param]
    else
        value = null
    return value
        ? value.tokenize(',').collect { it.trim() }
        : default_list
}

def deconvolution_container_param(Map ps) {
    def deconvolution_container = ps.deconvolution_container
    if (!deconvolution_container)
        "${ps.scicomp_repo}/matlab-deconv:1.0"
    else
        deconvolution_container
}

def exm_synapse_container_param(Map ps) {
    def exm_synapse_container = ps.exm_synapse_container
    if (!exm_synapse_container)
        "${ps.exm_repo}/synapse:1.0.0"
    else
        exm_synapse_container
}

def get_stitched_data_dir(Map ps) {
    if (ps.stitched_data_dir) {
        ps.stitched_data_dir
    } else {
        get_value_or_default(ps, 'output_dir', ps.data_dir)
    }
}

def default_presynapse_ch_dir(Map ps, parent_dir) {
    if (ps.pre_synapse_channel_subfolder) {
        "${parent_dir}/${ps.pre_synapse_channel_subfolder}"
    } else {
        "${parent_dir}/slice-tiff-s${ps.export_level}/ch0"
    }
}

def default_n1_ch_dir(Map ps, parent_dir) {
    if (ps.n1_channel_subfolder) {
        "${parent_dir}/${ps.n1_channel_subfolder}"
    } else {
        "${parent_dir}/slice-tiff-s${ps.export_level}/ch1"
    }
}

def default_n2_ch_dir(Map ps, parent_dir) {
    if (ps.n2_channel_subfolder) {
        "${parent_dir}/${ps.n2_channel_subfolder}"
    } else {
        "${parent_dir}/slice-tiff-s${ps.export_level}/ch2"
    }
}

def default_postsynapse_ch_dir(Map ps, parent_dir) {
    if (ps.postsynapse_channel_subfolder) {
        "${parent_dir}/${ps.postsynapse_channel_subfolder}"
    } else {
        "${parent_dir}/slice-tiff-s${ps.export_level}/ch2"
    }
}
