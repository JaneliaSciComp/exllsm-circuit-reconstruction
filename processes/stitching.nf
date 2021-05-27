process prepare_stitching_data {
    label 'small'
    label 'preferLocal'
    
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

process clone_stitched_tiles_args {
    label 'small'
    label 'preferLocal'

    input:
    tuple val(stitched_tiles_template),
          val(source_tiles_file),
          val(target_tiles_file)
    
    output:
    tuple val(stitched_tiles_template),
          val(source_tiles_file),
          env(source_tiles_content),
          val(target_tiles_file),
          env(target_tiles_content)

    script:
    """
    cp ${stitched_tiles_template} ${target_tiles_file}
    source_tiles_content=`cat ${source_tiles_file}`
    target_tiles_content=`cat ${target_tiles_file}`
    """
}
