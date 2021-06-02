include {
    spark_cluster_start;
    run_spark_app_on_existing_cluster as run_n5_to_vvd;
} from '../external-modules/spark/lib/workflows'

include {
    terminate_spark;
} from '../external-modules/spark/lib/processes'

workflow n5_to_vvd {
    take:
    input_dir // n5 dir
    input_dataset // n5 container sub-dir
    output_dir
    n5_app
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
    def terminate_app_name = 'terminate-n5-to-vvd'

    // index inputs so that I can pair inputs with the corresponding spark URI and/or spark working dir
    def indexed_input_dir = index_channel(input_dir)
    def indexed_input_dataset = index_channel(input_dataset)
    def indexed_output_dir = index_channel(output_dir)
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
        | join(indexed_input_dataset)
        | join(indexed_output_dir)

    def n5_to_vvd_args = indexed_data
    | map {
        def (idx,
             spark_work_dir,
             spark_uri,
             currrent_input_dir,
             current_input_dataset,
             current_output_dir) = it
        def args_list = []
        [
            spark_uri,
            args_list.join(' '),
            spark_work_dir,
        ]
    }

    def n5_to_vvd_res = run_n5_to_vvd(
        n5_to_vvd_args.map { it[0] }, // spark uri
        components_app,
        'org.janelia.saalfeldlab.n5.spark.N5ToVVDSpark',
        n5_to_vvd_args.map { it[1] }, // args
        'n5_to_vvd.log',
        terminate_app_name,
        spark_cconf,
        n5_to_vvd_args.map { it[2] }, // spark work dir
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
    done = terminate_spark(
        n5_to_vvd_res.map { it[1] },
        terminate_app_name
    )
    | join(indexed_data, by:1) | map { 
        log.info "Completed N5 to VVD: ${it}"
        it
    }

    emit:
    done
}

