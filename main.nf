#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_spark_params;
} from './external-modules/spark/lib/param_utils'

// app parameters
params.stitching_app = 'external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar'
params.resolution = '0.104,0.104,0.18'
params.axis = '-y,-x,z'
params.wave_length = '488nm 560nm 642nm'
params.block_size = '128,128,64'

final_params = default_spark_params() + params

include {
    stitching;
} from './workflows/stitching' addParams(lsf_opts: final_params.lsf_opts, 
                                         crepo: final_params.crepo,
                                         spark_version: final_params.spark_version)

// spark config
spark_conf = final_params.spark_conf
spark_work_dir = file(final_params.spark_work_dir)
spark_workers = final_params.workers
spark_worker_cores = final_params.worker_cores
gb_per_core = final_params.gb_per_core
driver_cores = final_params.driver_cores
driver_memory = final_params.driver_memory
driver_logconfig = final_params.driver_logconfig

stitching_app = file(final_params.stitching_app)
data_dir = file(final_params.data_dir)
resolution = final_params.resolution
axis_mapping = final_params.axis
wave_lengths = final_params.wave_length?.tokenize(' ')
block_size = final_params.block_size

if( !spark_work_dir.exists() ) {
    spark_work_dir.mkdirs()
}

workflow {
    stitching(
        stitching_app,
        data_dir,
        resolution,
        axis_mapping,
        wave_lengths,
        block_size,
        spark_conf,
        spark_work_dir,
        spark_workers,
        spark_worker_cores,
        gb_per_core,
        driver_cores,
        driver_memory,
        driver_logconfig
    ) \
    | view
}
