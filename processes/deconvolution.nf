process deconvolution_job {
    container = "${params.deconvrepo}/matlab-deconv:1.0"

    cpus { ncores }

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
    val(ncores)

    output:
    tuple val(ch),
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
