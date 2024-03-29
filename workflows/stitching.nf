include {
    spark_cluster;
    run_spark_app_on_existing_cluster as run_stitching;
    run_spark_app_on_existing_cluster as run_fuse;
    run_spark_app_on_existing_cluster as run_export;
} from '../external-modules/spark/lib/workflows'

include {
    terminate_spark as terminate_stitching;
} from '../external-modules/spark/lib/processes'

include {
    clone_stitched_tiles_from_template;
    clone_with_decon_tiles;
} from '../processes/stitching'

include {
    write_file_content;
} from '../processes/content_utils'

include {
    entries_inputs_args
} from './stitching_utils'

include {
    index_channel;
    json_text_to_data;
    data_to_json_text;
} from '../utils/utils'

workflow stitching {
    take:
    stitching_dir
    channels
    stitching_mode
    stitching_padding
    stitching_blur_sigma
    export_level
    allow_fusestage
    skipped_steps
    stitching_app
    spark_conf
    spark_work_dir
    spark_workers
    spark_worker_cores
    spark_gbmem_per_core
    spark_driver_cores
    spark_driver_memory
    spark_driver_stack
    spark_driver_logconfig

    main:
    def spark_driver_deploy = ''
    def terminate_app_name = 'terminate-stitching'

    // index inputs so that I can pair dataset name with the corresponding spark URI and/or spark working dir
    def indexed_stitching_dir = index_channel(stitching_dir)
    def indexed_spark_work_dir = index_channel(spark_work_dir)

    // start a spark cluster
    def spark_cluster_res = spark_cluster(
        spark_conf,
        spark_work_dir,
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        terminate_app_name
    ) // [ spark_uri, spark_work_dir ]

    def indexed_spark_uri = spark_cluster_res
    | join(indexed_spark_work_dir, by:1)
    | map {
        def indexed_uri = [ it[2], it[1] ]
        log.debug "Indexed spark URI from $it -> ${indexed_uri}"
        return indexed_uri
    }

    // create a channel of tuples:  [index, spark_uri, dataset, stitching_dir, spark_work_dir]
    def indexed_data = indexed_spark_work_dir \
        | join(indexed_spark_uri)
        | join(indexed_stitching_dir) // [ idx, work_dir, uri, stitching_dir ]

    def stitch_res
    if (skipped_steps.contains('stitch')) {
        // skip stitching
        stitch_res = indexed_spark_work_dir
    } else {
        // prepare stitching tiles
        def json_inputs_to_stitch = index_tile_filenames_by_ch(
            get_stitching_tile_json_inputs(
                params.stitching_json_inputs,
                channels
            )
        )
        def stitching_args = prepare_app_args(
            "stitch",
            "org.janelia.stitching.StitchingSpark",
            indexed_data,
            indexed_spark_work_dir, //  here I only want a tuple that has the working dir as the 2nd element
            { current_stitching_dir ->
                def tile_json_inputs = entries_inputs_args(
                    current_stitching_dir,
                    json_inputs_to_stitch.values(),
                    '-i',
                    '', // suffix was already appended in get_stitching_tile_json_inputs
                    '.json'
                )
                def args_list = []
                args_list
                    << '--stitch'
                    <<  '-r' << '-1'
                    << tile_json_inputs
                    << '--mode' << "'${stitching_mode}'"
                    << '--padding' << "'${stitching_padding}'"
                    << '--blurSigma' << "${stitching_blur_sigma}"

                args_list.join(' ')
            }
        )
        def stitch_app_res = run_stitching(
            stitching_args.map { it[0] }, // spark uri
            stitching_app,
            stitching_args.map { it[1] }, // main
            stitching_args.map { it[2] }, // args
            stitching_args.map { it[3] }, // log
            terminate_app_name, // terminate name
            spark_conf,
            stitching_args.map { it[4] }, // spark work dir
            spark_workers,
            spark_worker_cores,
            spark_gbmem_per_core,
            spark_driver_cores,
            spark_driver_memory,
            spark_driver_stack,
            spark_driver_logconfig,
            spark_driver_deploy
        )
        def a_stitched_result = json_inputs_to_stitch
                                    .collect {
                                        def (ch, ch_fn) = [it.key, it.value]
                                        def ch_fn_suffix = ch_fn.replaceAll(ch,'')
                                        [ ch, ch_fn_suffix, "${ch}${ch_fn_suffix}-final"]
                                    }
				                    .first()
        def tile_files_to_clone = index_tile_filenames_by_ch(channels)
                                    .findAll { ch, ch_fn ->
                                        !json_inputs_to_stitch.containsKey(ch)
                                    }
                                    .collect { 
                                        def (ch, ch_fn) = [it.key, it.value]
                                        [
                                            a_stitched_result[2],
                                            "${ch}${a_stitched_result[1]}",
                                            "${ch}${a_stitched_result[1]}-final"
                                        ]
                                    }
        if (tile_files_to_clone.size() == 0) {
            stitch_res = stitch_app_res
        } else {
            def clone_stitched_tiles_inputs = indexed_data
            | join(stitch_app_res, by:1)
            | map {
                def (spark_work_dir, idx, spark_uri, current_stitching_dir) = it
                [ spark_uri, spark_work_dir, current_stitching_dir ]
            }
            | combine(tile_files_to_clone)
            | map {
                def (spark_uri, spark_work_dir, current_stitching_dir,
                     stitched_result_name,
                     source_tiles_filename,
                     cloned_result_name) = it
                [
                    "${current_stitching_dir}/${stitched_result_name}.json",
                    "${current_stitching_dir}/${source_tiles_filename}.json",
                    "${current_stitching_dir}/${cloned_result_name}.json",
                    spark_uri,
                    spark_work_dir,
                    current_stitching_dir,
                ]
            }
            // copy the stitched results into the clone
            def clone_stitched_tiles_results = clone_stitched_tiles_from_template(
                clone_stitched_tiles_inputs.map { it[0..2] }
            )
            | join(clone_stitched_tiles_inputs, by:[0,1,2])
            | map {
                // take the tiles from the source_tiles_file
                // and replace them in the clone - target_tiles_file
                def (stitched_tiles_template,
                    source_tiles_file,
                    target_tiles_file,
                    source_tiles_content,
                    target_tiles_content,
                    spark_uri,
                    spark_work_dir,
                    current_stitching_dir) = it
                log.debug "Copy tile files from ${source_tiles_file} to be written to ${target_tiles_file}"
                [
                    target_tiles_file,
                    spark_uri,
                    spark_work_dir,
                    current_stitching_dir,
                    copy_tile_files(source_tiles_content, target_tiles_content),
                ]
            }
            stitch_res = update_tile_file_content(clone_stitched_tiles_results)
            | map {
                def (target_tiles_file,
                     spark_uri,
                     spark_work_dir,
                     current_stitching_dir) = it
                [ spark_uri, spark_work_dir, current_stitching_dir, target_tiles_file ]
            }
            | groupTuple(by: [0,1,2])
            stitch_res.subscribe { log.debug "Cloned stitch result $it" }
        }
    }

    def fuse_res
    if (skipped_steps.contains('fuse')) {
        fuse_res = stitch_res
    } else {
        // identify tile files that may need to have
        // the tile files replaced with the corresponding deconv tiles
        def indexed_default_fused_files = index_tile_filenames_by_ch(channels)
                                    .collectEntries { ch, ch_fn ->
                                        [
                                            ch,
                                            "${ch}-decon-final"
                                        ]
                                    }
        def indexed_stitched_deconv_files = index_tile_filenames_by_ch(
            get_stitching_tile_json_inputs(
                params.stitching_json_inputs,
                channels
            )
        )
        .findAll { ch, ch_fn ->
            // filter stitch inputs that use decon tiles if stitch was not skipped
            // if stitch was skipped we cannot tell for sure whether the
            // 'decon-final' files are there
            !skipped_steps.contains('stitch') && ch_fn == "${ch}-decon"
        }
        .collectEntries {
            // append '-final' suffix because stitch step generates <input>-final.json 
            [ it.key, "${it.value}-final" ]
        }
        def json_inputs_to_fuse = index_tile_filenames_by_ch(
            get_fuse_tile_json_inputs(
                params.fuse_to_n5_json_inputs,
                channels
            )
        )
        def candidate_ch_to_clone_with_deconv_tiles = json_inputs_to_fuse
                                    .findAll { ch, ch_fn ->
                                        // filter out files that don't use deconv tiles, i.e.,
                                        // they don't have a 'decon' suffix or we know for sure
                                        // that deconv tiles were used for stitching
                                        indexed_default_fused_files.containsKey(ch) &&
                                        !indexed_stitched_deconv_files.containsKey(ch) &&
                                        ch_fn == indexed_default_fused_files.get(ch)
                                    }
                                    .collect {
                                        it.key // return only the channel
                                    }
        def fuse_working_data
        if (candidate_ch_to_clone_with_deconv_tiles.size() > 0) {
            // these are just candidates which will actually be skipped
            // if the stitch step uses the default inputs
            log.info "Candidates for updating tiles with decon tiles: ${candidate_ch_to_clone_with_deconv_tiles}"
            def clone_with_decon_tiles_inputs = indexed_data
            | join(stitch_res, by:1)
            | map {
                def (spark_work_dir, idx, spark_uri, current_stitching_dir) = it
                [ spark_uri, spark_work_dir, current_stitching_dir ]
            }
            | combine(candidate_ch_to_clone_with_deconv_tiles)
            | map {
                def (spark_uri, spark_work_dir, current_stitching_dir, ch) = it
                [
                    current_stitching_dir,
                    ch,
                    spark_uri,
                    spark_work_dir,
                ]
            }

            def clone_with_decon_tiles_results = clone_with_decon_tiles_inputs
            | map {
                it[0..1]
            }
            | clone_with_decon_tiles
            | filter {
                def (current_stitching_dir,
                     ch,
                     target_tiles_file) = it
                target_tiles_file != "null"
            }
            | join(clone_with_decon_tiles_inputs, by:[0,1])
            | map {
                def (current_stitching_dir,
                     ch,
                     target_tiles_file,
                     source_tiles_content,
                     target_tiles_content,
                     spark_uri,
                     spark_work_dir) = it
                [
                    target_tiles_file,
                    spark_uri,
                    spark_work_dir,
                    current_stitching_dir,
                    copy_tile_files(source_tiles_content, target_tiles_content),
                ]
            }
            | update_tile_file_content
            | map {
                def (target_tiles_file,
                     spark_uri,
                     spark_work_dir,
                     current_stitching_dir) = it
                [ spark_uri, spark_work_dir, current_stitching_dir, target_tiles_file ]
            }
            | groupTuple(by: [0,1,2])

            fuse_working_data = stitch_res
            | concat(clone_with_decon_tiles_results)
            | unique { it[1] }
        } else {
            // there are no files actually used for the fuse step
            // that need the tiles to be replaced with the deconv tiles
            fuse_working_data = stitch_res
        }
        // prepare fuse tiles
        def fuse_args = prepare_app_args(
            "fuse",
            "org.janelia.stitching.StitchingSpark",
            indexed_data,
            fuse_working_data,
            { current_stitching_dir ->
                def tile_json_inputs = entries_inputs_args(
                    current_stitching_dir,
                    json_inputs_to_fuse.values(),
                    '-i',
                    '', // suffix was already appended in get_fuse_tile_json_inputs
                    '.json'
                )
                def args_list = []
                args_list
                    << '--fuse'
                    << tile_json_inputs
                    << '--blending'
                if (allow_fusestage) {
                    args_list << '--fusestage'
                }

                args_list.join(' ')
            }
        )
        fuse_res = run_fuse(
            fuse_args.map { it[0] }, // spark uri
            stitching_app,
            fuse_args.map { it[1] }, // main
            fuse_args.map { it[2] }, // args
            fuse_args.map { it[3] }, // log
            terminate_app_name, // terminate name
            spark_conf,
            fuse_args.map { it[4] }, // spark work dir
            spark_workers,
            spark_worker_cores,
            spark_gbmem_per_core,
            spark_driver_cores,
            spark_driver_memory,
            spark_driver_stack,
            spark_driver_logconfig,
            spark_driver_deploy
        )
    }

    def export_res
    if (skipped_steps.contains('tiff-export')) {
        export_res = fuse_res
    } else {
        // prepare export tiles
        def export_args = prepare_app_args(
            "export",
            "org.janelia.stitching.N5ToSliceTiffSpark",
            indexed_data,
            fuse_res,
            { current_stitching_dir ->
                def args_list = []
                args_list
                    << '-i' << "${current_stitching_dir}/export.n5"
                    << '--scaleLevel' << "${export_level}"
                args_list.join(' ')
            }
        )
        export_res = run_export(
            export_args.map { it[0] }, // spark uri
            stitching_app,
            export_args.map { it[1] }, // main
            export_args.map { it[2] }, // args
            export_args.map { it[3] }, // log
            terminate_app_name, // terminate name
            spark_conf,
            export_args.map { it[4] }, // spark work dir
            spark_workers,
            spark_worker_cores,
            spark_gbmem_per_core,
            spark_driver_cores,
            spark_driver_memory,
            spark_driver_stack,
            spark_driver_logconfig,
            spark_driver_deploy
        )
    }

    // terminate stitching cluster
    done = terminate_stitching(
        export_res.map { it[1] },
        terminate_app_name
    )
    | join(indexed_data, by:1) | map { 
        // [ work_dir, <ignored from terminate>,  idx, uri, stitching_dir, dataset]
        def r = it[4] // stitching_dir
        log.info "Completed stitching for ${it} -> $r"
        return r
    } // stitching_dir

    emit:
    done
}

workflow update_tile_file_content {
    take:
    tile_file_with_content // tuple in which the first element is the file name and the last is the content

    main:
    done = tile_file_with_content
    | map {
        [ it[0], it[-1] ] // filename and content
    }
    | write_file_content
    | join(tile_file_with_content, by:0)

    emit:
    done
}

def prepare_app_args(app_name,
                     app_main,
                     indexed_data,
                     previous_result_dir,
                     app_args_closure) {
    return indexed_data
    | join(previous_result_dir, by: 1)
    | map {
        // [ work_dir, idx, uri, stitching_dir, dataset, <ignored elem from prev res> ]
        log.debug "Create ${app_name} inputs from ${it}"
        def (spark_work_dir, idx, spark_uri, stitching_dir) = it
        def app_args = app_args_closure.call(stitching_dir)
        def app_inputs = [
            spark_uri,
            app_main,
            app_args,
            "${app_name}.log",
            spark_work_dir
        ]
        log.debug "${app_name} app input ${idx}: ${app_inputs}"
        return app_inputs
    }
}

def get_stitching_tile_json_inputs(stitching_inputs, default_channels) {
    if (stitching_inputs instanceof String && stitching_inputs) {
        stitching_inputs.tokenize(',').collect { it.trim() }
    } else {
        default_channels.collect { "${it}-decon" }
    }
}

def get_fuse_tile_json_inputs(fuse_inputs, default_channels) {
    if (fuse_inputs instanceof String && fuse_inputs) {
        fuse_inputs.tokenize(',').collect { it.trim() }
    } else {
        default_channels.collect { "${it}-decon-final" }
    }
}

def index_tile_filenames_by_ch(stitched_filenames) {
    stitched_filenames
        .collectEntries {
            def ch_key = it.replaceAll(/\..*$/, '')
            [ ch_key.tokenize('-').first(), ch_key ]
        }
}

def copy_tile_files(source_tiles_content, dest_tiles_content) {
    def indexed_source_tiles = json_text_to_data(source_tiles_content)
        .collectEntries { tile ->
            [ tile.index, tile ]
        }
    def dest_tiles = json_text_to_data(dest_tiles_content)
        .collect { tile ->
            def source_tile = indexed_source_tiles.get(tile.index)
            if (source_tile) {
                tile.file = source_tile.file
            } else {
                tile.file = null
            }
            tile
        }
        .findAll { tile -> tile.file != null}
    data_to_json_text(dest_tiles)
}

