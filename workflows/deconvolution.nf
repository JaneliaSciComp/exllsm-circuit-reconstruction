include {
    read_config;
    write_config;
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
    deconv_dir = file(deconv_output_dir(data_dir))
    if(!deconv_dir.exists()) {
        deconv_dir.mkdirs()
    }

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
                        "ch": ch,
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
                .findAll {
                    file(it.tile_filepath).exists()
                }
        }
        .flatten()
        .collect {
            [
                it.ch,
                it.tile_filepath,
                it.output_tile_dir,
                it.output_tile_filepath,
                it.psf_filepath,
                it.flatfield_dirpath,
                it.background_value,
                it.data_z_resolution,
                it.psf_z_step,
                it.num_iterations,
                deconv_cores
            ]
        }
    deconv_process_input = Channel.fromList(deconv_process_input_list)
    deconv_jobs_results = deconvolution_job(deconv_process_input)
    deconv_jobs_results
        .groupTuple(by:0)
        .map { ch_res ->
            tiles_config_file = file("${data_dir}/${ch_res[0]}.json")
            tiles_data = read_config(tiles_config_file)
            deconv_data = tiles_data
                            .collect { tile_config ->
                                tile_filename = tile_config.file
                                tile_deconv_file = tile_deconv_output(data_dir, tile_filename)
                                tile_config.file = tile_deconv_file
                                return tile_config
                            }
            dconv_json_file = file("${data_dir}/${ch}-decon.json")
            write_config(deconv_data, dconv_json_file)
        }
        .set { deconv_results }

    emit:
    deconv_results
}


process deconvolution_job {
    container = "${params.deconvrepo}/matlab-deconv:1.0"

    cpus { ncores }

    input:
    tuple val(ch),
          val(tile_file),
          val(output_dir),
          val(output_file),
          val(psf_input),
          val(flatfield_dir),
          val(background),
          val(z_resolution),
          val(psf_z_step),
          val(iterations),
          val(ncores)

    output:
    tuple val(ch), val(tile_file), val(output_file)

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

def deconv_output_dir(data_dir) {
    return "${data_dir}/matlab_decon"
}

def tile_deconv_output(data_dir, tile_filename) {
    fn_and_ext = new File(tile_filename).getName().split("\\.")
    output_dir = deconv_output_dir(data_dir)
    return "${output_dir}/${fn_and_ext[0]}_decon.${fn_and_ext[1]}"
}