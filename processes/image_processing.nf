include {
    create_container_options;
} from '../utils/utils'

process prepare_mask_dirs {
    label 'preferLocal'

    input:
    tuple val(input_dir), val(shared_temp_dir), val(output_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    script:
    threshold_dir = "${shared_temp_dir}/threshold"
    connect_dir = "${shared_temp_dir}/connect"
    """
    umask 0002
    mkdir -p "${shared_temp_dir}"
    mkdir -p "${output_dir}"
    """
}

process threshold_mask {

    container { params.fiji_macro_container }
    containerOptions { create_container_options([ input_dir, file(threshold_dir).parent ]) }

    cpus { params.threshold_cpus }
    memory { "${params.threshold_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    script:
    if (params.containsKey('threshold')) 
    """
    mkdir -p "${threshold_dir}"
    /app/fiji/entrypoint.sh --headless -macro thresholding_multithread.ijm "${params.threshold_cpus},${input_dir}/,${threshold_dir}/,${params.threshold}"
    """
    else
    """
    ln -s "${input_dir}" "${threshold_dir}"
    """ 
}

process convert_from_mask {
    label 'withAVX2'

    container { params.fiji_macro_container }
    containerOptions { create_container_options([ threshold_dir, file(connect_dir).parent ]) }

    cpus { params.convert_mask_cpus }
    memory { "${params.convert_mask_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    script:
    """
    mkdir -p "${connect_dir}"
    /app/fiji/entrypoint.sh --headless -macro ExpandMask_ExM.ijm "${threshold_dir}/,${connect_dir}/,${params.convert_mask_cpus}"
    """
}

process get_brick_files {
    label 'preferLocal'

    input:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir), env(BRICKS)

    script:
    """
    BRICKS=`ls -d ${connect_dir}/**/*.zip`
    """
}

process connect_tiff {
    label 'withGPU'

    container { params.fiji_macro_container }
    containerOptions { create_container_options([ connect_dir, "/etc/OpenCL" ]) }

    cpus { params.connect_mask_cpus }
    memory { "${params.connect_mask_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir), val(brick)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir), val(brick)

    script:
    """
    export CL_LOG_ERRORS=stdout
    /app/fiji/entrypoint.sh --headless -macro Mask_connectionGPU.ijm "${brick},${params.mask_connection_distance},${params.mask_connection_iterations}"
    """
}

process convert_to_mask {
    label 'withAVX2'

    container { params.fiji_macro_container }
    containerOptions { create_container_options([ threshold_dir, connect_dir ]) }

    cpus { params.convert_mask_cpus }
    memory { "${params.convert_mask_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    script:
    """
    /app/fiji/entrypoint.sh --headless -macro ExpandMask_ExM.ijm "${threshold_dir}/,${connect_dir}/,${params.convert_mask_cpus}"
    """
}

process complete_mask {
    label 'preferLocal'

    input:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    output:
    tuple val(input_dir), val(output_dir), val(shared_temp_dir), val(threshold_dir), val(connect_dir)

    script:
    """
    cp ${connect_dir}/*.tif ${output_dir}/
    if [[ "${params.clean_temp_dirs}" == "true" ]]; then
        rm -rf ${params.shared_temp_dir}
    fi
    """
}

process crosstalk_subtraction {

    container { params.fiji_macro_container }
    containerOptions { create_container_options([ input_dir, file(output_dir).parent ]) }

    cpus { params.crosstalk_subtraction_cpus }
    memory { "${params.crosstalk_subtraction_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro subtracting_multithread.ijm "${params.crosstalk_subtraction_cpus},${input_dir}/,${output_dir}/,${params.crosstalk_threshold}"
    """
}

process crop_tiff {

    container { params.fiji_macro_container }
    containerOptions { create_container_options([ input_dir, file(output_dir).parent, roi_path ]) }

    cpus { params.crop_cpus }
    memory { "${params.crop_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir), val(roi_path)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro ROI_Crop_multithread.ijm "${params.crop_format},${params.crop_cpus},${params.crop_start_slice},${params.crop_end_slice},${input_dir}/,${output_dir}/,${roi_path}/"
    """
}

process threshold_tiff {

    container { params.fiji_macro_container }
    containerOptions { create_container_options([ input_dir, file(output_dir).parent ]) }

    cpus { params.threshold_cpus }
    memory { "${params.threshold_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro thresholding_multithread.ijm "${params.threshold_cpus},${input_dir}/,${output_dir}/,${params.threshold}"
    """
}

process tiff_to_mips {

    container { params.fiji_macro_container }
    containerOptions { create_container_options([ input_dir, file(output_dir).parent ]) }

    cpus { params.create_mip_cpus }
    memory { "${params.create_mip_mem_gb} GB" }

    input:
    tuple val(input_dir), val(output_dir)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    """
    mkdir -p "${output_dir}"
    /app/fiji/entrypoint.sh --headless -macro MIPmultithread.ijm "${params.create_mip_cpus},${input_dir}/,${output_dir}/"
    """
}
