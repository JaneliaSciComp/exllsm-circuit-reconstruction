include {
    spark_cluster_start;
    run_spark_app_on_existing_cluster as run_connected_components;
    run_spark_app_on_existing_cluster as run_downsample_components;
} from '../external-modules/spark/lib/workflows'

include {
    terminate_spark;
} from '../external-modules/spark/lib/processes'

include {
    index_channel;
} from '../utils/utils'

workflow connected_components {
    take:
    input_dir // n5 dir
    input_dataset // n5 container sub-dir (c0/s0)
    output_dataset
    components_app
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
    def terminate_app_name = 'terminate-connected-comps'

    // index inputs so that I can pair inputs with the corresponding spark URI and/or spark working dir
    def indexed_input_dir = index_channel(input_dir)
    def indexed_input_dataset = index_channel(input_dataset)
    def indexed_output_dataset = index_channel(output_dataset)
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
        | join(indexed_output_dataset)

    def connected_comps_args = indexed_data
    | map {
        def (idx,
             spark_work_dir,
             spark_uri,
             currrent_input_dir,
             current_input_dataset,
             current_output_dataset) = it
        def args_list = []
        args_list << "-n ${currrent_input_dir}"
        args_list << "-i ${current_input_dataset}"
        args_list << "-o ${current_output_dataset}"
        args_list << "-m ${params.min_connected_pixels}"
        args_list << "-s ${params.connected_pixels_shape}"
        if (params.connected_pixels_threshold > 0)
            args_list << "-t ${params.connected_pixels_threshold}"
        def block_size = get_connected_comps_block_size()
        if (block_size)
            args_list << "-b ${block_size}"
        [
            spark_uri,
            args_list.join(' '),
            spark_work_dir,
        ]
    }

    def connected_comps_res = run_connected_components(
        connected_comps_args.map { it[0] }, // spark uri
        components_app,
        'org.janelia.saalfeldlab.n5.spark.N5ConnectedComponentsSpark',
        connected_comps_args.map { it[1] }, // args
        'connected_comps.log',
        terminate_app_name,
        spark_conf,
        connected_comps_args.map { it[2] }, // spark work dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig,
        spark_driver_deploy
    )

    def downsampled_connected_res
    if (params.downsample_connected_comps) {
        def downsample_comps_args = indexed_data
        | join(connected_comps_res, by: 1)
        | map {
            def (spark_work_dir,
                idx,
                spark_uri,
                currrent_input_dir,
                current_input_dataset,
                current_output_dataset) = it
            def args_list = []
            args_list << "-n ${currrent_input_dir}"
            args_list << "-i ${current_output_dataset}"
            [
                spark_uri,
                args_list.join(' '),
                spark_work_dir,
            ]
        }
        downsampled_connected_res = run_downsample_components(
            downsample_comps_args.map { it[0] }, // spark uri
            components_app,
            'org.janelia.saalfeldlab.n5.spark.downsample.scalepyramid.N5NonIsotropicScalePyramidSpark',
            downsample_comps_args.map { it[1] }, // args
            'downsample_comps.log',
            terminate_app_name,
            spark_conf,
            downsample_comps_args.map { it[2] }, // spark work dir
            spark_workers,
            spark_worker_cores,
            spark_gbmem_per_core,
            spark_driver_cores,
            spark_driver_memory,
            spark_driver_stack,
            spark_driver_logconfig,
            spark_driver_deploy
        )
    } else {
        downsampled_connected_res = connected_comps_res
    }
    // terminate stitching cluster
    done = terminate_spark(
        downsampled_connected_res.map { it[1] },
        terminate_app_name
    )
    | join(indexed_data, by:1)
    | map {
        def (spark_work_dir,
             terminate_fn,
             idx,
             spark_uri,
             current_input_dir,
             current_input_dataset,
             current_output_dataset) = it
        def r = [
            current_input_dir,
            current_input_dataset,
            current_output_dataset
        ]
        log.info "Completed connected components: ${it} -> ${r}"
        r
    }

    emit:
    done

def get_connected_comps_block_size() {
    if (params.connected_comps_block_size instanceof String && params.connected_comps_block_size) {
        params.connected_comps_block_size
    } else {
        ''
    }
}