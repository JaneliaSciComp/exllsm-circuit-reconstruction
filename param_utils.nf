def default_em_params() {
    [
        scicomp_repo: 'registry.int.janelia.org/janeliascicomp',
        exm_repo: 'registry.int.janelia.org/exm-analysis',

        data_dir: '',
        output_dir: '',

        stitching_output: 'stitching',

        // stitching params
        spark_container_repo: 'registry.int.janelia.org/exm-analysis',
        spark_container_name: 'stitching',
        spark_container_version: '1.8.1',
        spark_local_dir: "/tmp",
        stitching_app: '/app/app.jar',
        driver_stack: '128m',
        stitching_output: 'stitching',
        resolution: '0.104,0.104,0.18',
        axis: '-y,-x,z',
        channels: '488nm,560nm,642nm',
        block_size: '512,512,512',
        retile_z_size: '64',
        stitching_mode: 'incremental',
        stitching_padding: '0,0,0',
        blur_sigma: '2',
        export_level: '0',
        export_fusestage: false,

        // deconvolution params
        deconv_cpus: 4,
        background: '',
        psf_z_step_um: '0.1',
        iterations_per_channel: '10,10,10',

        pipeline: 'presynaptic_in_volume',
        // synapse detection params
        pre_synapse_stack_dir: '',
        n1_stack_dir: '',
        n2_stack_dir: '',
        post_synapse_stack_dir: '',

        tiff2n5_cpus: 3,
        n52tiff_cpus: 3,
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

def stitching_container_param(Map ps) {
    def stitching_container = ps.stitching_container
    if (!stitching_container)
        "${ps.exm_repo}/stitching:1.8.1"
    else
        stitching_container
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
        "${ps.exm_repo}/synapse:1.1.0"
    else
        exm_synapse_container
}

def exm_synapse_dask_container_param(Map ps) {
    def exm_synapse_dask_container = ps.exm_synapse_dask_container
    if (!exm_synapse_dask_container)
        "${ps.exm_repo}/synapse-dask:1.0.0"
    else
        exm_synapse_dask_container
}
