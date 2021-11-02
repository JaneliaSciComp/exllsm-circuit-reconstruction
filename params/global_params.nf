def global_em_params() {
    [
        deconv_repo: 'registry.int.janelia.org/janeliascicomp',
        exm_repo: 'registry.int.janelia.org/exm-analysis',

        // global parameters
        partial_volume: '',
        volume_partition_size: 512,
        block_size: '512,512,512',
        resolution: '0.104,0.104,0.18',
        n5_compression: 'gzip',
        default_n5_dataset: 's0',
        use_gpu_mem_growth: true,

        input_dir: '',
        output_dir: '',
        input_dataset: '/s0',
        output_dataset: '/s0',
        connected_dataset: '/connected/s0',

        // image processing
        fiji_macro_container: 'registry.int.janelia.org/exm-analysis/exm-tools-fiji:1.1.0',

        // 3D mask connection params
        threshold: '',
        mask_connection_distance: 20,
        mask_connection_iterations: 4,
        clean_temp_dirs: true,
        threshold_cpus: 24,
        threshold_mem_gb: 16,
        convert_mask_cpus: 32,
        convert_mask_mem_gb: 120,
        connect_mask_cpus: 1,
        connect_mask_mem_gb: 10,

        // crosstalk subtraction params
        crosstalk_threshold: 255,
        crosstalk_subtraction_cpus: 4,
        crosstalk_subtraction_mem_gb: 8,

        // ROI cropping params
        crop_format: "uncompressedTIFF", // "ZIP", "uncompressedTIFF", "TIFFPackBits_8bit", "LZW"
        crop_start_slice: -1,
        crop_end_slice: -1,
        crop_cpus: 24,
        crop_mem_gb: 16,

        // MIP creation params
        create_mip_cpus: 24,
        create_mip_mem_gb: 8,

        tiff2n5_cpus: 24, // it needs 9 cores for a 512x512x512 chunk size on Janelia's LSF
        tiff2n5_memory: '126 G', // in fact it needs 126G for a 512x512x512 chunk size
        tiff2n5_workers: 0,
        n52tiff_cpus: 24,
        n52tiff_memory: '126 G',

        multiscale_pyramid: false,
        with_pyramid: false,
        tiff_output_dir: '',
        use_n5_spark_tools: true,
        with_vvd: false,
        vvd_output_dir: '',
        mips_output_dir: '',
        mips_step: '',
    ]
}
