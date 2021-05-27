process get_flatfield_attributes {
    label 'small'
    label 'preferLocal'
    container { params.deconvolution_container }

    input:
    tuple val(input_dir), val(ch)

    output:
    tuple val(input_dir), val(ch), env(attr_file), stdout

    script:
    """
    attr_file_list=`ls ${input_dir}/${ch}-*flatfield/attributes.json || true`
    if [[ -z \${attr_file_list} ]]; then
        echo "null"
        attr_file=null
    else
        cat \${attr_file_list}
        attr_file=\${attr_file_list}
    fi
    """
}

process deconvolution_job {
    container { params.deconvolution_container }
    cpus { params.deconv_cpus }

    input:
    val(ch)
    val(tile_file)
    val(data_dir)
    val(output_dir)
    val(output_file)
    val(psf_input)
    val(flatfield_dir)
    val(background)
    val(z_resolution)
    val(iterations)

    output:
    tuple val(ch),
          val(data_dir),
          val(output_dir),
          val(tile_file),
          val(output_file),
          env(output_deconv_file)

    script:
    def app_args_list = [
        tile_file,
        output_file,
        psf_input,
        flatfield_dir,
        background,
        z_resolution,
        params.psf_z_step_um,
        iterations
    ]
    def app_args = app_args_list.join(' ')
    """
    umask 0002
    if [[ -e ${tile_file} ]]; then
        /app/entrypoint.sh ${app_args}
        output_deconv_file=${output_file}
    else
        output_deconv_file="null"
    fi
    """
}

process prepare_deconv_dir {
    label 'small'
    label 'preferLocal'
    container { params.deconvolution_container }

    input:
    val(data_dir)
    val(deconv_dir)

    output:
    tuple val(data_dir), val(deconv_dir)

    script:
    """
    umask 0002
    mkdir -p "${deconv_dir}"
    """
}
