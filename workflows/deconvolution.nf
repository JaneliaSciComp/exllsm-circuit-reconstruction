include {
    read_config;
} from ('./stitching_utils')

workflow deconvolution {
    take:
    data_dir
    channels
    channels_psfs
    psf_z_step_um
    background
    iterations_per_channel
    deconv_cores

    main:
    deconv_dir = deconv_output_dir(data_dir)
    
    deconv_process_input_list = GroovyCollections.transpose([channels, channels_psfs, iterations_per_channel])
        .collect { ch_info ->
            ch = ch_info[0]
            ch_psf = ch_info[1]
            iterations = ch_info[2]
            tiles_config_file = file("${data_dir}/${ch}.json")
            tiles_data = read_config(tiles_config_file)
            flatfield_attrs_file = ["-flatfield", "-n5-flatfield"]
                .collect { file("${data_dir}/${ch}${it}/attributes.json") }
                .find { it.exists() }
            if (background != null && background != '') {
                background_intensity = background as float
            } else { 
                flatfield_config = read_config(flatfield_attrs_file)
                background_intensity = flatfield_config.pivotValue
            }
            return tiles_data
                .collect { tile_config ->
                    tile_filename = tile_config["file"]
                    resolutions = tile_config["pixelResolution"]
                    return [
                        "tile_filepath": tile_filename,
                        "output_tile_dir": deconv_dir,
                        "output_tile_filepath": tile_deconv_output(data_dir, tile_filename),
                        "psf_filepath": ch_psf,
                        "flatfield_dirpath": flatfield_attrs_file.getParent(),
                        "background_value": background_intensity,
                        "data_z_resolution": resolutions[2],
                        "psf_z_step": psf_z_step_um,
                        "num_iterations": iterations
                    ]
                }
        }
        .flatten()
/*
        .collect {
            [
                it.tile_filepath,
                it.output_tile_dir,
                it.output_tile_filepath,
                it.psf_filepath,
                it.flatfield_dirpath,
                it.background_value,
                it.data_z_resolution,
                it.psf_z_step,
                it.num_iterations
            ]
        }
*/
    deconv_process_input = Channel.fromList(deconv_process_input_list)
    
    emit:
    deconv_process_input
}


process deconvolution_job {
    container = "${params.deconvrepo}/:1.0"

    cpus { ncores }

    input:
    tuple path(tile_file),
          path(output_dir),
          path(output_file),
          path(psf_input),
          path(flatfield_dir),
          val(background),
          val(z_resolution),
          val(psf_z_step),
          val(iterations)

    output:
    path(deconv_result)

    script:
    """
    umask 0002
    mkdir -p ${output_dir}
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

def deconv_output_dir(data_dir) {
    return "${data_dir}/matlab_decon"
}

def tile_deconv_output(data_dir, tile_filename) {
    fn_and_ext = new File(tile_filename).getName().split("\\.")
    output_dir = deconv_output_dir(data_dir)
    return "${output_dir}/${fn_and_ext[0]}_decon.${fn_and_ext[1]}"
}