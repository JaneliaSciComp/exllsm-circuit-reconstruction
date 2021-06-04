def synapse_params() {
    [
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
        tiff2n5_workers: 0,
        n52tiff_cpus: 4, // it needs 9 cores for a 512x512x512 chunk size on Janelia's LSF
        n52tiff_memory: '3 G', // in fact it needs 126G for a 512x512x512 chunk size
        unet_cpus: 1,
        unet_memory: '3 G',
        use_gpu_mem_growth: false,
        postprocessing_cpus: 3,
        postprocessing_memory: '3 G',
        presynaptic_stage2_threshold: 400,
        presynaptic_stage2_percentage: 0.5,
        postsynaptic_stage2_threshold: 200,
        postsynaptic_stage2_percentage: 0.001,
        postsynaptic_stage3_threshold: 400,
        postsynaptic_stage3_percentage: 0.001,
    ]
}
