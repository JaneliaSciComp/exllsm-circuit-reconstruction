include {
    spark_cluster_start;
    run_spark_app_on_existing_cluster as run_parse_tiles;
    run_spark_app_on_existing_cluster as run_tiff2n5;
    run_spark_app_on_existing_cluster as run_flatfield_correction;
} from '../external-modules/spark/lib/workflows'

include {
    terminate_spark as terminate_pre_stitching;
} from '../external-modules/spark/lib/processes'

include {
    entries_inputs_args
} from './stitching_utils'

include {
    index_channel;
} from '../utils/utils'

workflow prepare_tiles_for_stitching {
    take:
    input_dir
    stitching_dir
    channels
    resolution
    axis_mapping
    block_size
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
    def terminate_app_name = 'terminate-pre-stitching'

    // index inputs so that I can pair inputs with the corresponding spark URI and/or spark working dir
    def indexed_input_dir = index_channel(input_dir)
    def indexed_stitching_dir = index_channel(stitching_dir)
    def indexed_spark_work_dir = index_channel(spark_work_dir)

    // start a spark cluster
    def spark_cluster_res = spark_cluster_start(
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

    def indexed_data = indexed_spark_work_dir \
        | join(indexed_spark_uri)
        | join(indexed_input_dir)
        | join(indexed_stitching_dir) // [ idx, work_dir, uri, input_dir, stitching_dir ]

    // prepare parse tiles
    def parse_tiles_args = prepare_app_args(
        "parseTiles",
        "org.janelia.stitching.ParseTilesImageList",
        indexed_data,
        indexed_spark_work_dir, //  here I only want a tuple that has the working dir as the 2nd element
        { current_images_dir, current_stitching_dir ->
            def args_list = []
            args_list << "-i ${current_stitching_dir}/ImageList_images.csv"
            if (resolution) {
                args_list << "-r '${resolution}'"
            }
            if (axis_mapping) {
                args_list << "-a '${axis_mapping}'"
            }
            args_list << "-b ${current_images_dir}"
            args_list << "--skipMissingTiles"
            args_list.join(' ')
        }
    )
    def parse_res = run_parse_tiles(
        parse_tiles_args.map { it[0] }, // spark uri
        stitching_app,
        parse_tiles_args.map { it[1] }, // main
        parse_tiles_args.map { it[2] }, // args
        parse_tiles_args.map { it[3] }, // log
        terminate_app_name, // terminate name
        spark_conf,
        parse_tiles_args.map { it[4] }, // spark work dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig,
        spark_driver_deploy
    )

    // prepare tiff to n5
    def tiff_to_n5_args = prepare_app_args(
        "tiff2n5",
        "org.janelia.stitching.ConvertTIFFTilesToN5Spark",
        indexed_data,
        parse_res,
        { current_images_dir, current_stitching_dir ->
            def tile_json_inputs = entries_inputs_args(
                current_stitching_dir,
                channels,
                '-i',
                '',
                '.json'
            )
            "${tile_json_inputs} --blockSize '${block_size}'"
        }
    )
    def tiff2n5_res = run_tiff2n5(
        tiff_to_n5_args.map { it[0] }, // spark uri
        stitching_app,
        tiff_to_n5_args.map { it[1] }, // main
        tiff_to_n5_args.map { it[2] }, // args
        tiff_to_n5_args.map { it[3] }, // log
        terminate_app_name, // terminate name
        spark_conf,
        tiff_to_n5_args.map { it[4] }, // spark work dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig,
        spark_driver_deploy
    )

    // prepare flatfield
    def flatfield_args = prepare_app_args(
        "flatfield",
        "org.janelia.flatfield.FlatfieldCorrection",
        indexed_data,
        tiff2n5_res,
        { current_images_dir, current_stitching_dir ->
            def n5_json_input = entries_inputs_args(
                current_stitching_dir,
                channels,
                '-i',
                '-n5',
                '.json'
            )
            "${n5_json_input} -v 101 --2d --bins 256"
        }
    )
    def flatfield_res = run_flatfield_correction(
        flatfield_args.map { it[0] }, // spark uri
        stitching_app,
        flatfield_args.map { it[1] }, // main
        flatfield_args.map { it[2] }, // args
        flatfield_args.map { it[3] }, // log
        terminate_app_name, // terminate name
        spark_conf,
        flatfield_args.map { it[4] }, // spark work dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig,
        spark_driver_deploy
    )

    // terminate stitching cluster
    done = terminate_pre_stitching(
        flatfield_res.map { it[1] },
        terminate_app_name
    )
    | join(indexed_data, by:1) | map { 
        // [ work_dir, <ignored from terminate>,  idx, uri, stitching_dir ]
        log.info "Completed pre stitching for ${it}"
        // input_dir, stitching_dir
        [ it[4], it[5] ]
    }

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
        // [ work_dir, idx, uri, input_dir, stitching_dir, <ignored elem from prev res> ]
        log.debug "Create ${app_name} inputs from ${it}"
        def (spark_work_dir, idx, spark_uri, input_dir, stitching_dir) = it
        def app_args = app_args_closure.call(input_dir, stitching_dir)
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
