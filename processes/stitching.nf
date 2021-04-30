process prepare_stitching_data {
    container { params.stitching_container }

    input:
    val(input_dir)
    val(output_dir)
    val(working_dir)

    output:
    tuple val(input_images_dir),
          val(stitching_dir),
          val(stitching_working_dir)

    script:
    input_images_dir = "${input_dir}/images"
    stitching_dir = output_dir
    stitching_working_dir = working_dir
        ? working_dir
        : "${stitching_dir}/tmp"
    """
    umask 0002
    mkdir -p "${stitching_dir}"
    mkdir -p "${stitching_working_dir}"
    cp "${input_images_dir}/ImageList_images.csv" "${stitching_dir}"
    """
}
