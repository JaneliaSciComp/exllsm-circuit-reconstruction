def synapse_params() {
    [
        // synapse detection params
        pipeline: 'presynaptic_in_volume',
        synapse_model: '/groups/dickson/dicksonlab/lillvis/ExM/Ding-Ackerman/crops-for-training_Oct2018/DING/model_DNN/saved_unet_model_2020/unet_model_synapse2020_6/unet_model_synapse2020_6.whole.h5',

        presynapse: '',
        presynapse_in_dataset: '',

        n1: '',
        n1_in_dataset: '',

        n2: '',
        n2_in_dataset: '',

        postsynapse: '',
        postsynapse_in_dataset: '',

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
        working_post_synapse_seg_n1_dataset: 'post_synapse_seg_pre_synapse_seg_n1/s0',

        working_pre_synapse_seg_post_synapse_seg_n1_container: '', // (pre-synapse seg + n1) + [ post-synapse seg + (pre-synapse seg + n1) ]
        working_pre_synapse_seg_post_synapse_seg_n1_dataset: 'pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1/s0',

        unet_cpus: 1,
        unet_memory: '3 G',
        postprocessing_cpus: 3,
        postprocessing_memory: '3 G',
        postprocessing_threads: 3,
        presynaptic_stage2_threshold: 400,
        presynaptic_stage2_percentage: 0.5,
        postsynaptic_stage3_threshold: 200,
        postsynaptic_stage3_percentage: 0.001,
        postsynaptic_stage4_threshold: 400,
        postsynaptic_stage4_percentage: 0.001,
    ]
}
