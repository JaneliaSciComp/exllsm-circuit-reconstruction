process prepare_stitching_data {
    executor 'local'
    
    input:
    val(input_images_dir)
    val(stitching_output_dir)
    val(working_dir)

    output:
    tuple val(input_images_dir),
          val(stitching_output_dir),
          val(stitching_working_dir)

    script:
    stitching_working_dir = working_dir
        ? working_dir
        : "${stitching_output_dir}/tmp"
    """
    umask 0002
    mkdir -p "${stitching_output_dir}"
    mkdir -p "${stitching_working_dir}"
    cp "${input_images_dir}/ImageList_images.csv" "${stitching_output_dir}"
    """
}
