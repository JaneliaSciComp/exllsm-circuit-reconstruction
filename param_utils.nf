def default_em_params() {
    [
        exm_repo: 'registry.int.janelia.org/janeliascicomp',

        datasets: '',
        data_dir: '',
        output_dir: '',

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

        // synapse detection params
        exm_synapse_container: '/groups/dickson/home/lillvisj/model_DNN/singularity_build_test/singularity_for_2D_synapse2020_6.simg', // !!! THIS NEEDS FIXED
        synapse_channel: 'ch0',
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
        "${ps.exm_repo}/matlab-deconv:1.0"
    else
        deconvolution_container
}

def exm_synapse_container_param(Map ps) {
    def exm_synapse_container = ps.exm_synapse_container
    if (!exm_synapse_container)
        "${ps.exm_repo}/exm_synapse:1.0"
    else
        exm_synapse_container
}