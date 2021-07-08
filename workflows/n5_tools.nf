include {
    spark_cluster;
    run_spark_app_on_existing_cluster as run_n5_pyramid;
    run_spark_app_on_existing_cluster as run_n5_to_vvd;
    run_spark_app_on_existing_cluster as run_n5_to_tiff;
    run_spark_app_on_existing_cluster as run_n5_to_mips;
} from '../external-modules/spark/lib/workflows'

include {
    terminate_spark;
} from '../external-modules/spark/lib/processes'

include {
    index_channel;
} from '../utils/utils'

workflow tiff_to_vvd {
    take:
    input_dir // tiff series dir
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
    def terminate_app_name = 'terminate-tiff-to-vvd'

    // index inputs so that I can pair inputs with the corresponding spark URI and/or spark working dir
    def indexed_input_dir = index_channel(input_dir)
    def indexed_output_dir = index_channel(output_dir)
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

    def indexed_data = indexed_spark_work_dir \
        | join(indexed_spark_uri)
        | join(indexed_input_dir)
        | join(indexed_output_dir)

    def n5_to_vvd_args = indexed_data
    | map {
        def (idx,
             spark_work_dir,
             spark_uri,
             currrent_input_dir,
             current_output_dir) = it
        def args_list = []
        args_list << "-i ${currrent_input_dir}"
        args_list << "-o ${current_output_dir}"
        if (params.n5_compression) {
            args_list << "-c ${params.n5_compression}"
        }
        args_list << "-b ${params.block_size}"
        if (params.vvd_scale_levels) {
            args_list << get_vvd_downsize(params.vvd_scale_levels)
                .inject('') {
                    arg, item -> "${arg} -f ${item}"
                }
        } else {
            if (params.vvd_pyramid_level > 0) {
                args_list << "-l ${params.vvd_pyramid_level}"
            }
            if (params.vvd_min_scale_factor > 0) {
                args_list << "-fmin ${params.vvd_min_scale_factor}"
            }
            if (params.vvd_max_scale_factor > 0) {
                args_list << "-fmax ${params.vvd_max_scale_factor}"
            }
        }
        [
            spark_uri,
            args_list.join(' '),
            spark_work_dir,
        ]
    }

    def n5_to_vvd_res = run_n5_to_vvd(
        n5_to_vvd_args.map { it[0] }, // spark uri
        n5_app,
        'org.janelia.saalfeldlab.n5.spark.SliceTiffToVVDSpark',
        n5_to_vvd_args.map { it[1] }, // args
        'tiff_to_vvd.log',
        terminate_app_name,
        spark_conf,
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
    | join(indexed_data, by:1)
    | map {
        log.info "Completed N5 to VVD: ${it}"
        it
    }

    emit:
    done
}

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
        args_list << "-ni ${currrent_input_dir}"
        args_list << "-i ${current_input_dataset}"
        args_list << "-o ${current_output_dir}"
        if (params.n5_compression) {
            args_list << "-c ${params.n5_compression}"
        }
        if (params.vvd_data_type) {
            args_list << "-t ${params.vvd_data_type}"
        }
        args_list << "-b ${params.block_size}"
        if (params.vvd_scale_levels) {
            args_list << get_vvd_downsize(params.vvd_scale_levels)
                .inject('') {
                    arg, item -> "${arg} -f ${item}"
                }
        } else {
            if (params.vvd_pyramid_level > 0) {
                args_list << "-l ${params.vvd_pyramid_level}"
            }
            if (params.vvd_min_scale_factor > 0) {
                args_list << "-fmin ${params.vvd_min_scale_factor}"
            }
            if (params.vvd_max_scale_factor > 0) {
                args_list << "-fmax ${params.vvd_max_scale_factor}"
            }
            if (params.vvd_min_threshold > 0) {
                args_list << "-min ${params.vvd_min_threshold}"
            }
            if (params.vvd_max_threshold > 0) {
                args_list << "-max ${params.vvd_max_threshold}"
            }
        }
        [
            spark_uri,
            args_list.join(' '),
            spark_work_dir,
        ]
    }

    def n5_to_vvd_res = run_n5_to_vvd(
        n5_to_vvd_args.map { it[0] }, // spark uri
        n5_app,
        'org.janelia.saalfeldlab.n5.spark.N5ToVVDSpark',
        n5_to_vvd_args.map { it[1] }, // args
        'n5_to_vvd.log',
        terminate_app_name,
        spark_conf,
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
    | join(indexed_data, by:1)
    | map {
        log.info "Completed N5 to VVD: ${it}"
        it
    }

    emit:
    done
}

def get_vvd_downsize(downsize_scales) {
    if (!downsize_scales) {
        ['1,1,1']
    } else {
        downsize_scales.tokenize(':').collect { it.trim() }
    }
}

workflow n5_to_tiff {
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
    def terminate_app_name = 'terminate-n5-to-tiff'

    // index inputs so that I can pair inputs with the corresponding spark URI and/or spark working dir
    def indexed_input_dir = index_channel(input_dir)
    def indexed_input_dataset = index_channel(input_dataset)
    def indexed_output_dir = index_channel(output_dir)
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

    def indexed_data = indexed_spark_work_dir \
        | join(indexed_spark_uri)
        | join(indexed_input_dir)
        | join(indexed_input_dataset)
        | join(indexed_output_dir)

    def n5_to_tiff_args = indexed_data
    | map {
        def (idx,
             spark_work_dir,
             spark_uri,
             currrent_input_dir,
             current_input_dataset,
             current_output_dir) = it
        def args_list = []
        args_list << "-n ${currrent_input_dir}"
        args_list << "-i ${current_input_dataset}"
        args_list << "-o ${current_output_dir}"
        [
            spark_uri,
            args_list.join(' '),
            spark_work_dir,
        ]
    }

    def n5_to_tiff_res = run_n5_to_tiff(
        n5_to_tiff_args.map { it[0] }, // spark uri
        n5_app,
        'org.janelia.saalfeldlab.n5.spark.N5ToSliceTiffSpark',
        n5_to_tiff_args.map { it[1] }, // args
        'n5_to_tiff.log',
        terminate_app_name,
        spark_conf,
        n5_to_tiff_args.map { it[2] }, // spark work dir
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
        n5_to_tiff_res.map { it[1] },
        terminate_app_name
    )
    | join(indexed_data, by:1)
    | map {
        log.info "Completed N5 to TIFF: ${it}"
        it
    }

    emit:
    done
}

workflow n5_to_mips {
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
    def terminate_app_name = 'terminate-n5-to-mips'

    // index inputs so that I can pair inputs with the corresponding spark URI and/or spark working dir
    def indexed_input_dir = index_channel(input_dir)
    def indexed_input_dataset = index_channel(input_dataset)
    def indexed_output_dir = index_channel(output_dir)
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

    def indexed_data = indexed_spark_work_dir \
        | join(indexed_spark_uri)
        | join(indexed_input_dir)
        | join(indexed_input_dataset)
        | join(indexed_output_dir)

    def n5_to_mips_args = indexed_data
    | map {
        def (idx,
             spark_work_dir,
             spark_uri,
             currrent_input_dir,
             current_input_dataset,
             current_output_dir) = it
        def args_list = []
        args_list << "-n ${currrent_input_dir}"
        args_list << "-i ${current_input_dataset}"
        args_list << "-o ${current_output_dir}"
        if (params.mips_step) {
            args_list << "-m ${params.mips_step}"
        }
        [
            spark_uri,
            args_list.join(' '),
            spark_work_dir,
        ]
    }

    def n5_to_mips_res = run_n5_to_mips(
        n5_to_mips_args.map { it[0] }, // spark uri
        n5_app,
        'org.janelia.saalfeldlab.n5.spark.N5MaxIntensityProjectionSpark',
        n5_to_mips_args.map { it[1] }, // args
        'n5_to_mips.log',
        terminate_app_name,
        spark_conf,
        n5_to_mips_args.map { it[2] }, // spark work dir
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
        n5_to_mips_res.map { it[1] },
        terminate_app_name
    )
    | join(indexed_data, by:1)
    | map {
        log.info "Completed N5 to MIPs: ${it}"
        it
    }

    emit:
    done
}

workflow n5_scale_pyramid_nonisotropic {
    take:
    input_dir // n5 dir
    input_dataset // n5 container sub-dir
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
    def terminate_app_name = 'terminate-n5-pyramid'

    // index inputs so that I can pair inputs with the corresponding spark URI and/or spark working dir
    def indexed_input_dir = index_channel(input_dir)
    def indexed_input_dataset = index_channel(input_dataset)
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

    def indexed_data = indexed_spark_work_dir \
        | join(indexed_spark_uri)
        | join(indexed_input_dir)
        | join(indexed_input_dataset)

    def n5_pyramid_args = indexed_data
    | map {
        def (idx,
             spark_work_dir,
             spark_uri,
             currrent_input_dir,
             current_input_dataset) = it
        def args_list = []
        args_list << "-n ${currrent_input_dir}"
        args_list << "-i ${current_input_dataset}"
        args_list << "-r ${params.resolution}"
        [
            spark_uri,
            args_list.join(' '),
            spark_work_dir,
        ]
    }

    def n5_pyramid_res = run_n5_pyramid(
        n5_pyramid_args.map { it[0] }, // spark uri
        n5_app,
        'org.janelia.saalfeldlab.n5.spark.downsample.scalepyramid.N5NonIsotropicScalePyramidSpark',
        n5_pyramid_args.map { it[1] }, // args
        'n5_pyramid.log',
        terminate_app_name,
        spark_conf,
        n5_pyramid_args.map { it[2] }, // spark work dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack,
        spark_driver_logconfig,
        spark_driver_deploy
    )

    // terminate spark cluster
    done = terminate_spark(
        n5_pyramid_res.map { it[1] },
        terminate_app_name
    )
    | join(indexed_data, by:1)
    | map {
        log.info "Completed N5 downsampling: ${it}"
        it
    }

    emit:
    done
}
