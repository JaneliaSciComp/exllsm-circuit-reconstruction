include {
    spark_cluster;
    spark_start_app;
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
    spark_uri \
    | map {[
        it,
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '128m',
        driver_logconfig,
        '',
        stitching_app,
        "org.janelia.stitching.ParseTilesImageList",
        "-i ${data_dir}/ImageList_images.csv \
         -r ${resolution} \
         -a ${axis_mapping} \
         -b ${data_dir} \
         --skipMissingTiles",
         "parseTiles.log"]} \
    | spark_start_app \
    | map {[
        spark_uri,
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '',
        driver_logconfig,
        '',
        stitching_app,
        "org.janelia.stitching.ConvertTIFFTilesToN5Spark",
        "-i ${data_dir}/488nm.json \
         -i ${data_dir}/560nm.json \
         -i ${data_dir}/642nm.json \
         --blockSize ${block_size}",
         "tiff2n5.log"]} \
    | spark_start_app
    | map { spark_work_dir } \
    | terminate_spark \
    | set { done }

    emit:
    done

}

def wave_lengths_json_inputs(data_dir, wave_lengths) {
    wave_lengths
        .map { wl ->
            "-i ${data_dir}/${wl}.json"
        }
        .join(' ')
}