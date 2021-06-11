include {
    spark_params;
} from './spark_params'

def neuron_params() {
    [
        // neuron segmentation
        input_imgname_pattern: '',
        skip_segmentation: false,
        neuron_scaling_cpus: 1,
        neuron_scaling_memory: '1 G',
        user_defined_scaling: '',
        neuron_scaling_tiles: 0,
        neuron_percent_scaling_tiles: 0,
        neuron_scaling_partition_size: '396,396,396',
        neuron_segmentation_partition_size: '', // by default use volume_partition_size
        max_scaling_tiles_per_job: 40,
        neuron_scaling_plots_dir: '',
        with_connected_comps: true,
        downsample_connected_comps: true,
        connected_comps_block_size: '128,128,128', // block size used for generating connected comps
        neuron_vvd_output: '', // VVD output directorry
        vvd_scale_levels: '1,1,1:2,2,2',
        min_connected_pixels: 2000, // minimum pixels in a connected component to be kept
        connected_pixels_shape: "diamond", // shape of neighborhood (default "diamond", option "box")
        connected_pixels_threshold: 200, // threshold value for neuron segmentation binarization
        neuron_conn_comp_dataset: '/c1/s0',

        neuron_segmentation_cpus: 1,
        neuron_segmentation_memory: '1 G',
        with_neuron_post_segmentation: true,
        use_gpu_mem_growth: true,
        neuron_model: '/groups/dickson/home/lillvisj/UNET_neuron/trained_models/neuron4_p2/neuron4_150.h5',
        neuron_input_dataset: '',
        neuron_output_dataset: '/s0',
        unsegmented_dataset: '/raw/s0', // dataset used for the raw neuron volume if the neuron input is tiff
        neuron_mask_as_binary: false,
        neuron_seg_unet_batch_sz: 1,
        neuron_seg_model_in_dims: '220,220,220',
        neuron_seg_model_out_dims: '132,132,132',
        neuron_seg_high_th: 0.98,
        neuron_seg_low_th: 0.2,
        neuron_seg_small_region_prob_th: 0.9,
        neuron_seg_small_region_size_th: 1000,
    ]
}

def neuron_connected_comps_spark_params(Map ps) {
    def neuron_comps_spark_cmdline_params = ps.neuron_comps_spark
        ? ps.neuron_comps_spark
        : [:]
    [
        workers: 1,
        worker_cores: 1,
        driver_cores: 1,
        gb_per_core: 1,
    ] +
    spark_params() +
    [
        spark_container_name: 'n5-spark-tools',
        spark_container_version: '3.8.0',
    ] +
    neuron_comps_spark_cmdline_params
}
