process prepare_deconv_dir {
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
    val(psf_z_step)
    val(iterations)

    output:
    tuple val(ch),
          val(data_dir),
          val(output_dir),
          val(tile_file),
          val(output_file)

    script:
    def app_args_list = [
        tile_file,
        output_file,
        psf_input,
        flatfield_dir,
        background,
        z_resolution,
        psf_z_step,
        iterations
    ]
    def app_args = app_args_list.join(' ')
    """
    umask 0002
    /app/entrypoint.sh ${app_args}
    """
}

def get_flatfield_file(input_dir, ch) {
    ["-flatfield", "-n5-flatfield"]
        .collect { flatfield_suffix ->
            file("${input_dir}/${ch}${flatfield_suffix}/attributes.json")
        }
        .find { it.exists() }
}
