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

process check_stitch_result_clone_args {
    label 'small'
    label 'preferLocal'

    input:
    tuple val(stitched_result),
          val(source_candidate_1),
          val(source_candidate_2),
          val(target_stitched_result)
    
    output:
    tuple val(stitched_result),
          env(source_tiles_file),
          env(target_tiles_file)

    script:
    """
    if [[ -f ${target_stitched_result} ]]; then
        target_tiles_file=null
    else
        target_tiles_file=${target_stitched_result}
    fi
    if [[ -f ${source_candidate_1} ]]; then
        source_tiles_file=${source_candidate_1}
    elif [[ -f ${source_candidate_2} ]]; then
        source_tiles_file=${source_candidate_1}
    else
        echo "Neither ${source_candidate_1} or ${source_candidate_2} was found"
        source_tiles_file=null
    fi
    """
}
