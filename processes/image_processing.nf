process prepare_mask_dirs {
    container { params.deconvolution_container }

    input:
    val(input_dir)
    val(shared_temp_dir)
    val(output_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    script:
    def threshold_dir = "${shared_temp_dir}/threshold"
    def connect_dir = "${shared_temp_dir}/connect"
    """
    umask 0002
    mkdir -p "${shared_temp_dir}"
    mkdir -p "${threshold_dir}"
    mkdir -p "${connect_dir}"
    mkdir -p "${output_dir}"
    """
}

process threshold_tiff {
    container { params.fiji_macro_container }

    cpus { params.threshold_cpus }
    memory { "${params.threshold_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro thresholding_multithread.ijm "${params.threshold_cpus},${input_dir},${output_dir},${params.threshold}"
    """
}

process convert_to_or_from_mask {
    container { params.fiji_macro_container }
    clusterOptions '-R"select[avx2]"'

    cpus { params.convert_mask_cpus }
    memory { "${params.convert_mask_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro ExpandMask_ExM.ijm "${input_dir},${output_dir},${params.convert_mask_cpus}"
    """
}

process connect_tiff_mask {
    container { params.fiji_macro_container }
    label 'withGPU'

    cpus { params.connect_mask_cpus }
    memory { "${params.connect_mask_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    script:
    """
    /app/fiji/entrypoint.sh --headless -macro Mask_connectionGPU.ijm "${connect_dir},${params.mask_connection_vx},${params.mask_connection_time}"
    """
}

process crosstalk_subtraction {
    container { params.fiji_macro_container }

    cpus { params.crosstalk_subtraction_cpus }
    memory { "${params.crosstalk_subtraction_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro subtracting_multithread.ijm "${params.crosstalk_subtraction_cpus},${input_dir},${output_dir},${params.crosstalk_threshold}"
    """
}

process crop_tiff {

    container { params.fiji_macro_container }

    cpus { params.crop_cpus }
    memory { "${crop_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir), val(roi_path)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro ROI_Crop_multithread.ijm "${params.crop_format},${params.crop_cpus},${params.crop_start_slice},${params.crop_end_slice},${input_dir},${output_dir},${roi_path}"
    """
}

process create_mip {
    container { params.fiji_macro_container }

    cpus { params.create_mip_cpus }
    memory { "${params.create_mip_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro MIPmultithread.ijm "${params.create_mip_cpus},${input_dir},${output_dir}"
    """
}

process vvd_export {
    container { params.fiji_macro_container }
    clusterOptions '-R"select[avx2]"'

    cpus { params.vvd_export_cpus }
    memory { "${params.vvd_export_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro VVD_creator_cluster.ijm "$input_dir/,$PWD/,${params.vvd_export_cpus},${params.vvd_pyramid_level},${params.vvd_final_ratio},${params.vvd_min_threshold},${params.vvd_max_threshold}"
    """
}

