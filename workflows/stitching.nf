include {
    spark_cluster;
    run_spark_app_on_existing_cluster;
    terminate_spark;
} from '../external-modules/spark/lib/spark' addParams(lsf_opts: params.lsf_opts, 
                                                       crepo: params.crepo,
                                                       spark_version: params.spark_version)

workflow stitching {
    take:
    stitching_app
    data_dir
    resolution
    axis_mapping
    wave_lengths
    block_size
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
    parse_res = run_spark_app_on_existing_cluster(
        spark_uri,
        stitching_app,
        "org.janelia.stitching.ParseTilesImageList",
        "-i ${data_dir}/ImageList_images.csv \
         -r '${resolution}' \
         -a '${axis_mapping}' \
         -b ${data_dir} \
         --skipMissingTiles",
        "parseTiles.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '128m',
        driver_logconfig,
        ''
    )
    wave_json_input = wave_lengths_json_inputs(data_dir, wave_lengths)
    tiff2n5_res = run_spark_app_on_existing_cluster(
        spark_uri,
        stitching_app,
        "org.janelia.stitching.ConvertTIFFTilesToN5Spark",
        "${wave_json_input} \
         --blockSize '${block_size}'",
        "tiff2n5.log",
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

    tiff2n5_res \
    | map { spark_work_dir } \
    | terminate_spark \
    | set { done }

    emit:
    done
}

def wave_lengths_json_inputs(data_dir, wave_lengths) {
    println "!!!!! WL " + wave_lengths
    wave_lengths_args = wave_lengths.inject('') {
        arg, item -> "${arg} -i ${data_dir}/${item}.json"
    }
    println "!!!!! WL args " + wave_lengths_args
    return wave_lengths_args.join(' ')
}