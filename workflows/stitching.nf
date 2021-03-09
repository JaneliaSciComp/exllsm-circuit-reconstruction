include {
    spark_cluster;
    run_spark_app_on_existing_cluster as run_parse_tiles;
    run_spark_app_on_existing_cluster as run_tiff2n5;
    run_spark_app_on_existing_cluster as run_flatfield_correction;
    run_spark_app_on_existing_cluster as run_stitching;
    run_spark_app_on_existing_cluster as run_final_stitching;
} from '../external-modules/spark/lib/workflows' addParams(lsf_opts: params.lsf_opts, 
                                                           crepo: params.crepo,
                                                           spark_version: params.spark_version)

include {
    terminate_spark as terminate_pre_stitching;
    terminate_spark as terminate_stitching;
} from '../external-modules/spark/lib/processes' addParams(lsf_opts: params.lsf_opts, 
                                                           crepo: params.crepo,
                                                           spark_version: params.spark_version)

include {
    prepare_stitching_data;
} from '../processes/stitching'

include {
    entries_inputs_args
} from './stitching_utils'

workflow prepare_stitching_data {
    take:
    datasets // queue or value channel of dataset names
    input_dir // queue or value channel of input dirs
    output_dir // queue or value channel of output
    stitching_output // value channel with relative path to stitching output
    work_dir // value channel with work dir

    main:
    stitching_data = prepare_stitching_data(
        input_dir,
        output_dir,
        datasets,
        stitching_output,
        work_dir
    )

    emit:
    stitching_data
} // [ dataset, dataset_input_dir, stitching_dir, stitching_working_dir ]

workflow prepare_tiles_for_stitching {
    take:
    stitching_app
    dataset
    stitching_dir
    channels
    resolution
    axis_mapping
    block_size
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
    def terminate_stitching = 'terminate-pre-stitching'

    // index inputs so that I can pair acq name with the corresponding spark URI and/or spark working dir
    def indexed_dataset = index_channel(dataset)
    def indexed_stitching_dir = index_channel(stitching_dir)
    def indexed_spark_work_dir = index_channel(spark_work_dir)

    // start a spark cluster
    def spark_cluster_res = spark_cluster(
        spark_conf,
        spark_work_dir,
        spark_workers,
        spark_worker_cores,
        spark_worker_cores * spark_gbmem_per_core,
        terminate_stitching
    ) // [ spark_uri, spark_work_dir ]
    // print spark cluster result
    spark_cluster_res.subscribe {  log.debug "Spark cluster result: $it"  }

    def indexed_spark_uri = spark_cluster_res
        .join(indexed_spark_work_dir, by:1)
        .map {
            def indexed_uri = [ it[2], it[1] ]
            log.debug "Create indexed spark URI from $it -> ${indexed_uri}"
            return indexed_uri
        }

    // create a channel of tuples:  [index, spark_uri, dataset, stitching_dir, spark_work_dir]
    def indexed_data = indexed_spark_work_dir \
        | join(indexed_spark_uri)
        | join(indexed_stitching_dir)
        | join(indexed_dataset) // [ idx, work_dir, uri, stitching_dir, dataset ]

    // prepare parse tiles
    def parse_tiles_args = prepare_app_args(
        "parseTiles",
        "org.janelia.stitching.ParseTilesImageList",
        indexed_data,
        indexed_spark_work_dir, //  here I only want a tuple that has the working dir as the 2nd element
        { dataset_name, dataset_stitching_dir ->
            "-i ${dataset_stitching_dir}/ImageList_images.csv " +
            "-r '${resolution}' "  +
            "-a '${axis_mapping}' " +
            "-b ${dataset_stitching_dir} " +
            "--skipMissingTiles "
        }
    )

    parse_res = run_parse_tiles(
        parse_tiles_args.map { it[0] }, // spark uri
        stitching_app,
        parse_tiles_args.map { it[1] }, // main
        parse_tiles_args.map { it[2] }, // args
        parse_tiles_args.map { it[3] }, // log
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
        { dataset_name, dataset_stitching_dir ->
            def tile_json_inputs = entries_inputs_args(
                stitching_dir,
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
        { dataset_name, dataset_stitching_dir ->
            def n5_json_input = entries_inputs_args(
                stitching_dir,
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
        terminate_stitching
    )
    | join(indexed_data, by:1) | map { 
        // [ work_dir, <ignored from terminate>,  idx, uri, stitching_dir, dataset]
        log.debug "Completed pre stitching for ${it}"
        // dataset_name, stitching_dir
        [ it[5], it[4] ]
    }

    emit:
    done
}

workflow stitching {
    take:
    stitching_app
    data_dir
    channels
    export_level
    spark_conf
    spark_work_dir
    nworkers
    worker_cores
    memgb_per_core
    driver_cores
    driver_memory
    driver_logconfig

    main:
    spark_uri = spark_cluster(spark_conf, spark_work_dir, nworkers, worker_cores)
    stitching_json_inputs = channels_json_inputs(data_dir, channels, '-decon')
    stitching_res = run_stitching(
        spark_uri,
        stitching_app,
        "org.janelia.stitching.StitchingSpark",
        "--stitch \
        -r -1 \
        ${stitching_json_inputs} \
        --mode 'incremental' \
        --padding '0,0,0' --blurSigma 2",
        "stitching.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '',
        driver_logconfig,
        ''
    )

    final_stitching_json_inputs = channels_json_inputs(data_dir, channels, '-decon-final')
    final_stitching_res = run_final_stitching(
        stitching_res,
        stitching_app,
        "org.janelia.stitching.StitchingSpark",
        "--fuse ${final_stitching_json_inputs} --blending",
        "stitching-final.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '',
        driver_logconfig,
        ''
    )

    export_res = run_final_stitching(
        final_stitching_res,
        stitching_app,
        "org.janelia.stitching.N5ToSliceTiffSpark",
        "-i ${data_dir}/export.n5 --scaleLevel ${export_level}",
        "export.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '',
        driver_logconfig,
        ''
    )

    export_res \
    | map { spark_work_dir } \
    | terminate_stitching \
    | map { data_dir }
    | set { done }

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
        def idx = it[1]
        def spark_work_dir = it[0] // spark work dir is the key
        def dataset = it[4]
        def spark_uri = it[2]
        def stitching_dir = it[3]
        def app_args = app_args_closure.call(dataset, stitching_dir)
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
