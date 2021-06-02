def global_em_params() {
    [
        deconv_repo: 'registry.int.janelia.org/janeliascicomp',
        exm_repo: 'registry.int.janelia.org/exm-analysis',

        // global parameters
        block_size: '512,512,512',
        resolution: '0.104,0.104,0.18',
        n5_compression: 'gzip',

        images_dir: '',
        output_dir: '',

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

        // MIP creation params
        create_mip_cpus: 4,
        create_mip_mem_gb: 8,
    ]
}