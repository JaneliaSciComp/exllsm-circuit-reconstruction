include {
    read_json;
    write_json;
} from '../utils/utils'

include {
    prepare_deconv_dir;
    deconvolution_job;
} from '../processes/deconvolution'

workflow deconvolution {
    take:
    dataset
    data_dir
    channels
    channels_psfs
    psf_z_step_um
    background
    iterations_per_channel

    main:
    def deconv_input = prepare_deconv_dir(
        dataset
        data_dir,
        data_dir.map { deconv_output_dir(it) }
    )
    | flatMap {
        current_dataset = it[0]
        input_dir = it[1]
        output_dir = it[2]
        [channels, channels_psfs, iterations_per_channel]
            .transpose()
            .collect { ch_info ->
                def ch = ch_info[0]
                def tiles_file = file("${input_dir}/${ch}.json")
                def flatfield_file = ["-flatfield", "-n5-flatfield"]
                    .collect { flatfield_suffix ->
                        file("${input_dir}/${ch}${flatfield_suffix}/attributes.json")
                    }
                    .find { it.exists() }
                def background_intensity
                if (background != null && background != '') {
                    background_intensity = background as float
                } else { 
                    flatfield_config = read_json(flatfield_file)
                    background_intensity = flatfield_config.pivotValue
                }
                
                [
                    current_dataset,
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
        def current_dataset = it[0]
        def input_dir = it[1]
        def output_dir = it[2]
        def tiles_file = it[3]
        def flatfield_file = it[4]
        def ch = it[5]
        def ch_psf_file = it[6]
        def iterations = it[7]
        def background_intensity = it[8]
        read_json(tiles_file)
            .collect { tile ->
                def tile_filename = tile.file
                def z_resolution = tile.pixelResolution[2]
                [
                    current_dataset,
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
    | filter { file(it[1]).exists() } // tile_file exists

    def deconv_results = deconvolution_job(
        deconv_input.map { it[0] }, // dataset
        deconv_input.map { it[1] }, // ch
        deconv_input.map { it[2] }, // tile_file
        deconv_input.map { it[3] }, // input dir
        deconv_input.map { it[4] }, // output dir
        deconv_input.map { it[5] }, // output tile file
        deconv_input.map { it[6] }, // psf file
        deconv_input.map { it[7] }, // flatten dir
        deconv_input.map { it[8] }, // background
        deconv_input.map { it[9] }, // z resolution
        deconv_input.map { it[10] }, // psf z step
        deconv_input.map { it[11] } // iterations
    )
    | groupTuple(by: [0,1,2,3])
    | map { res ->
        def current_dataset = res[0] 
        def ch = res[1]
        def input_dir = res[2]
        def dconv_json_file = file("${input_dir}/${ch}-decon.json")
        log.info "Create deconvolution output for channel ${ch} -> ${dconv_json_file}"
        def tiles_file = file("${input_dir}/${ch}.json")
        def deconv_tiles = read_json(tiles_file)
                            .collect { tile ->
                                def tile_filename = tile.file
                                def tile_deconv_file = tile_deconv_output(input_dir, tile_filename)
                                tile.file = tile_deconv_file
                                tile
                            }
        write_json(deconv_tiles, dconv_json_file)
        def deconv_res = [
            current_dataset,
            ch,
            input_dir,
            dconv_json_file
        ]
        log.info "Deconvolution result for ${current_dataset}:${ch} -> ${deconv_res}"
        deconv_res
    }

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
