def synapse_params() {
    [
        // synapse detection params
        pipeline: 'presynaptic_in_volume',
        synapse_model: '/groups/dickson/dicksonlab/lillvis/ExM/Ding-Ackerman/crops-for-training_Oct2018/DING/model_DNN/saved_unet_model_2020/unet_model_synapse2020_6/unet_model_synapse2020_6.whole.h5',

        pre_synapse_stack_dir: '',
        pre_synapse_in_dataset: '',

        n1_stack_dir: '',
        n1_in_dataset: '',

        n2_stack_dir: '',
        n2_in_dataset: '',

        post_synapse_stack_dir: '',
        post_synapse_in_dataset: '',

        working_container: '', // default N5 container name

        working_pre_synapse_container: '', // pre-synapse
        working_pre_synapse_dataset: 'pre_synapse/s0',

        working_n1_mask_container: '', // n1
        working_n1_mask_dataset: 'n1_mask/s0',

        working_n2_mask_container: '', // n2
        working_n2_mask_dataset: 'n2_mask/s0',

        working_post_synapse_container: '', // post-synapse
        working_post_synapse_dataset: 'post_synapse/s0',

        working_pre_synapse_seg_container: '', // pre-synapse seg
        working_pre_synapse_seg_dataset: 'pre_synapse_seg/s0',

        working_post_synapse_seg_container: '', // post-synapse seg
        working_post_synapse_seg_dataset: 'post_synapse_seg/s0',

        working_pre_synapse_seg_post_container: '', // post pre-synapse seg
        working_pre_synapse_seg_post_dataset: 'pre_synapse_seg_post/s0',

        working_pre_synapse_seg_n1_container: '', // pre-synapse seg + n1
        working_pre_synapse_seg_n1_dataset: 'pre_synapse_seg_n1/s0',

        working_pre_synapse_seg_n1_n2_container: '', // pre-synapse seg + n1 + n2
        working_pre_synapse_seg_n1_n2_dataset: 'pre_synapse_seg_n1_n2/s0',

        working_post_synapse_seg_n1_container: '', // post-synapse seg + pre-synapse seg + n1
        working_post_synapse_seg_n1_n5_dataset: 'post_synapse_seg_pre_synapse_seg_n1/s0',

        working_pre_synapse_seg_post_synapse_seg_n1_container: '', // (pre-synapse seg + n1) + [ post-synapse seg + (pre-synapse seg + n1) ]
        working_pre_synapse_seg_post_synapse_seg_n1_dataset: 'pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1/s0',

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
