process prepare_deconv_dir {
    container { params.deconvolution_container }
    executor "Local"

    input:
    val(dataset)
    val(data_dir)
    val(deconv_dir)

    output:
    tuple val(dataset), val(data_dir), val(deconv_dir)

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
    val(dataset)
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
    tuple val(dataset),
          val(ch),
          val(data_dir),
          val(output_dir),
          val(tile_file),
          val(output_file)

    script:
    """
    umask 0002
    /app/entrypoint.sh \
        ${tile_file} \
        ${output_file} \
        ${psf_input} \
        ${flatfield_dir} \
        ${background} \
        ${z_resolution} \
        ${psf_z_step} \
        ${iterations}
    """
}
