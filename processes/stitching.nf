process prepare_stitching_data {
    label 'small'
    label 'preferLocal'
    container { params.stitching_container }
    
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

process clone_stitched_tiles_from_template {
    label 'small'
    label 'preferLocal'
    container { params.stitching_container }

    input:
    tuple val(stitched_tiles_template),
          val(source_tiles_file),
          val(target_tiles_file)
    
    output:
    tuple val(stitched_tiles_template),
          val(source_tiles_file),
          val(target_tiles_file),
          env(source_tiles_content),
          env(target_tiles_content)

    script:
    """
    cp ${stitched_tiles_template} ${target_tiles_file}
    source_tiles_content=`cat ${source_tiles_file}`
    target_tiles_content=`cat ${target_tiles_file}`
    """
}

process clone_with_decon_tiles {
    label 'small'
    label 'preferLocal'
    container { params.stitching_container }

    input:
    tuple val(data_dir), val(ch)

    output:
    tuple val(data_dir),
          val(ch),
          env(cloned_deconv_final_file),
          env(source_tiles_content),
          env(target_tiles_content)

    script:
    def deconv_final_file = "${data_dir}/${ch}-decon-final.json"
    def deconv_tiles_file = "${data_dir}/${ch}-decon.json"
    """
    if [[ -f ${deconv_final_file} ]]; then
        # if deconv file exists do not do anything
        cloned_deconv_final_file=null
        source_tiles_content=null
        target_tiles_content=null
    else
        if [[ -f ${deconv_tiles_file} ]]; then
            cp "${data_dir}/${ch}-final.json" "${deconv_final_file}" || \
            cp "${data_dir}/${ch}.json" "${deconv_final_file}" || \
            true
            if [[ -f ${deconv_final_file} ]]; then
                cloned_deconv_final_file=${deconv_final_file}
                source_tiles_content=`cat ${deconv_tiles_file}`
                target_tiles_content=`cat ${deconv_final_file}`
            else
                echo "Could not find any source for ${data_dir}/${ch}.json to create to ${deconv_final_file}"
                cloned_deconv_final_file=null
                source_tiles_content=null
                target_tiles_content=null
            fi
        else
            echo "Cannot clone final decon file ${deconv_final_file} because ${deconv_tiles_file} cannot be found"
            cloned_deconv_final_file=null
            source_tiles_content=null
            target_tiles_content=null
        fi
    fi
    """
}