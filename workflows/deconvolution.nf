include {
    json_text_to_data;
    data_to_json_text;
} from '../utils/utils'

include {
    get_flatfield_attributes;
    deconvolution_job;
    prepare_deconv_dir;
    read_file_content as read_file_content_for_tile_files;
    read_file_content as read_file_content_for_update;
    write_file_content;
} from '../processes/deconvolution'

workflow deconvolution {
    take:
    data_dir
    channels
    channels_psfs
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
                def (ch, ch_psf, ch_iterations) = ch_info
                def tiles_json_file = file("${input_dir}/${ch}.json")
                [
                    input_dir,
                    ch,
                    tiles_json_file,
                    output_dir,
                    ch_psf, // channel psf
                    ch_iterations, // iterations per channel
                ]
            }
    }

    def flatfield_data = get_flatfield_attributes(
        deconv_input.map { it[0..1] }
    )
    | map {
        def (input_dir, ch, flatfield_attrs_file, flatfield_attrs_content) = it
        def background_intensity
        if (params.background != null && params.background != '') {
            background_intensity = params.background as float
        } else { 
            def flatfield_attrs = json_text_to_data(flatfield_attrs_content)
            background_intensity = flatfield_attrs.pivotValue
        }
        def d = [
            input_dir, ch, flatfield_attrs_file, background_intensity
        ]
        log.debug "Flatfield data: $d"
        d
    }

    def tile_files = read_file_content_for_tile_files(
        deconv_input.map { it[2] }
    )
    | flatMap {
        def (tiles_json_file, tiles_json_content) = it
        json_text_to_data(tiles_json_content)
            .collect { tile ->
                def tile_z_resolution = tile.pixelResolution[2]
                [ tiles_json_file, tile.file, tile_z_resolution ]
            }
    }

    def deconv_job_inputs = deconv_input
    | join(flatfield_data, by:[0,1])
    | map {
        def (input_dir, 
            ch,
            tiles_json_file,
            output_dir,
            ch_psf,
            ch_iterations,
            flatfield_attrs_file,
            background
        ) = it
        [
            tiles_json_file,
            input_dir,
            ch,
            flatfield_attrs_file,
            background,
            output_dir,
            ch_psf,
            ch_iterations
        ]
    }
    | combine(tile_files, by:0)
    | map {
        def (tiles_json_file,
            input_dir,
            ch,
            flatfield_attrs_file,
            background,
            output_dir,
            ch_psf,
            ch_iterations,
            tile_img_file,
            tile_z_resolution
        ) = it
        def flatfield_dir = file(flatfield_attrs_file).parent
        def d = [
            ch,
            tile_img_file,
            input_dir,
            output_dir,
            tile_deconv_output(input_dir, tile_img_file),
            ch_psf,
            flatfield_dir,
            background,
            tile_z_resolution,
            ch_iterations
        ]
        log.debug "Deconvolution job input: $it -> $d"
        d
    }

    def deconv_results = deconvolution_job(
        deconv_job_inputs.map { it[0] }, // ch
        deconv_job_inputs.map { it[1] }, // tile_file
        deconv_job_inputs.map { it[2] }, // input dir
        deconv_job_inputs.map { it[3] }, // output dir
        deconv_job_inputs.map { it[4] }, // output tile file
        deconv_job_inputs.map { it[5] }, // psf file
        deconv_job_inputs.map { it[6] }, // flatten dir
        deconv_job_inputs.map { it[7] }, // background
        deconv_job_inputs.map { it[8] }, // z resolution
        deconv_job_inputs.map { it[9] } // iterations
    )
    | filter { it[5] != 'null' } // filter out tiles that do not exist
    | groupTuple(by: [0,1,2])
    | map { it[0..3] } // [ ch, input_dir, output_dir, list_of_tile_files ]

    def deconv_results_to_write = deconv_results
    | map {
        def (ch, input_dir) = it
        "${input_dir}/${ch}.json"
    }
    | read_file_content_for_update
    | map {
        def (tiles_json_filename, tiles_json_content) = it
        def tiles_json_file = file(tiles_json_filename)
        def ch = tiles_json_file.name.replace('.json','')
        [ ch, "${tiles_json_file.parent}", tiles_json_content ]
    }
    | join(deconv_results, by:[0,1])
    | map {
        def (
            ch,
            input_dir,
            tiles_json_content,
            output_dir,
            list_of_tile_files
        ) = it
        def deconv_tiles_json_content = data_to_json_text(
            json_text_to_data(tiles_json_content)
                .findAll { tile -> list_of_tile_files.contains(tile.file) }
                .collect { tile ->
                    def tile_img_file = tile.file
                    def tile_deconv_img_file = tile_deconv_output(input_dir, tile_img_file)
                    tile.file = tile_deconv_img_file
                    tile
                }
        )
        def dconv_tiles_json_file = "${input_dir}/${ch}-decon.json"
        def r = [ dconv_tiles_json_file, ch, input_dir, deconv_tiles_json_content ]
        log.debug "Prepare writing json content to ${dconv_tiles_json_file} for ${input_dir}:${ch}"
        r
    }

    def final_deconv_results = write_file_content(
        deconv_results_to_write.map { [ it[0], it[3] ] }
    )
    | map { [it] }
    | join(deconv_results_to_write, by:0)
    | map {
        def (dconv_tiles_json_file, ch, input_dir) = it
        def deconv_res = [
            ch,
            input_dir,
            dconv_tiles_json_file
        ]
        log.info "Deconvolution result for ${input_dir}:${ch} -> ${deconv_res}"
        deconv_res
    }

    emit:
    done = final_deconv_results
}


def deconv_output_dir(data_dir) {
    return "${data_dir}/matlab_decon"
}

def tile_deconv_output(data_dir, tile_filename) {
    def fn_and_ext = new File(tile_filename).getName().split("\\.")
    def output_dir = deconv_output_dir(data_dir)
    return "${output_dir}/${fn_and_ext[0]}_decon.${fn_and_ext[1]}"
}
