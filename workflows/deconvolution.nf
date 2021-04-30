include {
    read_json;
    write_json;
} from '../utils/utils'

include {
    get_flatfield_file;
    prepare_deconv_dir;
    deconvolution_job;
} from '../processes/deconvolution'

workflow deconvolution {
    take:
    data_dir
    channels
    channels_psfs
    psf_z_step_um
    background
    iterations_per_channel

    main:
    def deconv_input = prepare_deconv_dir(
        data_dir,
        data_dir.map { deconv_output_dir(it) }
    )
    | flatMap {
        def (input_dir, output_dir) = it
        [channels, channels_psfs, iterations_per_channel]
            .transpose()
            .collect { ch_info ->
                def ch = ch_info[0]
                def tiles_file = file("${input_dir}/${ch}.json")
                def flatfield_file = get_flatfield_file(input_dir, ch)
                def background_intensity
                if (background != null && background != '') {
                    background_intensity = background as float
                } else { 
                    flatfield_config = read_json(flatfield_file)
                    background_intensity = flatfield_config.pivotValue
                }
                [
                    input_dir,
                    output_dir,
                    tiles_file,
                    flatfield_file,
                    ch,
                    ch_info[1], // channel psf
                    ch_info[2], // iterations
                    background_intensity
                ]
            }
    }
    | flatMap {
        def (input_dir, output_dir, tiles_file, flatfield_file, ch, ch_psf_file, iterations, background_intensity) = it
        read_json(tiles_file)
            .collect { tile ->
                def tile_filename = tile.file
                def z_resolution = tile.pixelResolution[2]
                [
                    ch,
                    tile_filename,
                    input_dir,
                    output_dir,
                    tile_deconv_output(input_dir, tile_filename),
                    ch_psf_file,
                    flatfield_file.parent,
                    background_intensity,
                    z_resolution,
                    psf_z_step_um,
                    iterations
                ]
            }
    }
    | filter {
        def r = file(it[2]).exists()
        if (r) {
            // tile_file exists
            log.debug "Deconvolution input: $it"
        }
        r
    }

    def deconv_results = deconvolution_job(
        deconv_input.map { it[0] }, // ch
        deconv_input.map { it[1] }, // tile_file
        deconv_input.map { it[2] }, // input dir
        deconv_input.map { it[3] }, // output dir
        deconv_input.map { it[4] }, // output tile file
        deconv_input.map { it[5] }, // psf file
        deconv_input.map { it[6] }, // flatten dir
        deconv_input.map { it[7] }, // background
        deconv_input.map { it[8] }, // z resolution
        deconv_input.map { it[9] }, // psf z step
        deconv_input.map { it[10] } // iterations
    )
    | groupTuple(by: [0,1,2])
    | map { res ->
        def ch = res[0]
        def input_dir = res[1]
        def dconv_json_file = file("${input_dir}/${ch}-decon.json")
        log.info "Create deconvolution output for ${input_dir}:${ch} -> ${dconv_json_file}"
        def tiles_file = file("${input_dir}/${ch}.json")
        def deconv_tiles = read_json(tiles_file)
                            .collect { tile ->
                                def tile_filename = tile.file
                                def tile_deconv_file = tile_deconv_output(input_dir, tile_filename)
                                tile.file = tile_deconv_file
                                tile
                            }
                            .findAll { tile ->
                                file(tile.file).exists()
                            }
        write_json(deconv_tiles, dconv_json_file)
        def deconv_res = [
            ch,
            input_dir,
            dconv_json_file
        ]
        log.info "Deconvolution result for ${input_dir}:${ch} -> ${deconv_res}"
        deconv_res
    } // [ channel, stitching_dir, deconv_json_file ]

    emit:
    done = deconv_results
}


def deconv_output_dir(data_dir) {
    return "${data_dir}/matlab_decon"
}

def tile_deconv_output(data_dir, tile_filename) {
    def fn_and_ext = new File(tile_filename).getName().split("\\.")
    def output_dir = deconv_output_dir(data_dir)
    return "${output_dir}/${fn_and_ext[0]}_decon.${fn_and_ext[1]}"
}
