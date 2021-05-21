def default_em_params() {
    [
        deconv_repo: 'registry.int.janelia.org/janeliascicomp',
        exm_repo: 'registry.int.janelia.org/exm-analysis',

        // global parameters
        block_size: '512,512,512',
        resolution: '0.104,0.104,0.18',
        n5_compression: 'gzip',

        // stitching params
        images_dir: '',
        psf_dir: '',
        output_dir: '',
        spark_container_repo: 'registry.int.janelia.org/exm-analysis',
        spark_container_name: 'stitching',
        spark_container_version: '1.8.1',
        spark_local_dir: "/tmp",
        stitching_app: '/app/app.jar',
        driver_stack: '128m',
        stitching_output: '',
        axis: '-y,-x,z',
        channels: '488nm,560nm,642nm',
        stitching_mode: 'incremental',
        stitching_padding: '0,0,0',
        stitching_blur_sigma: '2',
        export_level: '0',
        allow_fusestage: false,

        // deconvolution params
        deconv_cpus: 4,
        background: '',
        psf_z_step_um: '0.1',
        iterations_per_channel: '10,10,10',

        // image processing
        fiji_macro_container: 'registry.int.janelia.org/exm-analysis/exm-tools-fiji:1.0.1',

        // 3D mask connection params
        threshold: 255,
        mask_connection_vx: 20,
        mask_connection_time: 4,
        threshold_cpus: 4,
        threshold_mem_gb: 8,
        convert_mask_cpus: 3,
        convert_mask_mem_gb: 45,
        connect_mask_cpus: 32,
        connect_mask_mem_gb: 192,

        // crosstalk subtraction params
        crosstalk_threshold: 255,
        crosstalk_subtraction_cpus: 4,
        crosstalk_subtraction_mem_gb: 8,

        // ROI cropping params
        crop_format: "TIFFPackBits_8bit", // "ZIP", "uncompressedTIFF", "TIFFPackBits_8bit", "LZW"
        crop_start_slice: -1,
        crop_end_slice: -1,
        crop_cpus: 4,
        crop_mem_gb: 8,

        // VVD conversion params
        vvd_pyramid_level: 5,
        vvd_final_ratio: 10,
        vvd_min_threshold: 100,
        vvd_max_threshold: 2100,
        vvd_export_cpus: 32,
        vvd_export_mem_gb: 192,
        
        // MIP creation params
        create_mip_cpus: 4,
        create_mip_mem_gb: 8,

        // synapse detection params
        default_n5_dataset: '/s0',
        pipeline: 'presynaptic_in_volume',
        synapse_model: '/groups/dickson/dicksonlab/lillvis/ExM/Ding-Ackerman/crops-for-training_Oct2018/DING/model_DNN/saved_unet_model_2020/unet_model_synapse2020_6/unet_model_synapse2020_6.whole.h5',
        pre_synapse_stack_dir: '',
        n1_stack_dir: '',
        n2_stack_dir: '',
        post_synapse_stack_dir: '',
        tiff2n5_cpus: 3,
        tiff2n5_memory: '3 G',
        n52tiff_cpus: 3,
        n52tiff_memory: '3 G',
        unet_cpus: 3,
        unet_memory: '3 G',
        use_gpu_mem_growth: false,
        postprocessing_cpus: 3,
        postprocessing_memory: '3 G',
        partial_volume: '',
        volume_partition_size: 512,
        presynaptic_stage2_threshold: 400,
        presynaptic_stage2_percentage: 0.5,
        postsynaptic_stage2_threshold: 200,
        postsynaptic_stage2_percentage: 0.001,
        postsynaptic_stage3_threshold: 400,
        postsynaptic_stage3_percentage: 0.001,

        // neuron segmentation
        neuron_scaling_cpus: 1,
        neuron_scaling_memory: '1 G',
        neuron_scaling_tiles: 0,
        neuron_percent_scaling_tiles: 0,
        neuron_scaling_partition_size: '396,396,396',
        max_scaling_tiles_per_job: 50,
        neuron_scaling_plots_dir: '',

        neuron_segmentation_cpus: 1,
        neuron_segmentation_memory: '1 G',
        with_neuron_post_segmentation: true,
        use_gpu_mem_growth: true,
        neuron_model: '/groups/dickson/home/lillvisj/UNET_neuron/trained_models/neuron4_p2/neuron4_150.h5',
        neuron_input_dataset: '/s0',
        neuron_output_dataset: '/s0',
        neuron_mask_as_binary: false,
        neuron_seg_unet_batch_sz: 1,
        neuron_seg_model_in_dims: '220,220,220',
        neuron_seg_model_out_dims: '132,132,132',
        neuron_seg_high_th: 0.98,
        neuron_seg_low_th: 0.2,
        neuron_seg_small_region_prob_th: 0.2,
        neuron_seg_small_region_size_th: 2000,
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
        "${ps.deconv_repo}/matlab-deconv:1.0"
    else
        deconvolution_container
}

def exm_synapse_container_param(Map ps) {
    def exm_synapse_container = ps.exm_synapse_container
    if (!exm_synapse_container)
        "${ps.exm_repo}/synapse:1.2.2"
    else
        exm_synapse_container
}

def exm_synapse_dask_container_param(Map ps) {
    def exm_synapse_dask_container = ps.exm_synapse_dask_container
    if (!exm_synapse_dask_container)
        "${ps.exm_repo}/synapse-dask:1.2.0"
    else
        exm_synapse_dask_container
}

def exm_neuron_segmentation_container(Map ps) {
    def exm_neuron_segmentation_container = ps.exm_neuron_segmentation_container
    if (!exm_neuron_segmentation_container)
        "${ps.exm_repo}/neuron-segmentation:1.0.0"
    else
        exm_neuron_segmentation_container
}
