include {
    spark_params;
} from './spark_params'

def vvd_params() {
    [
        // VVD conversion params
        vvd_data_type: 'uint16',
        vvd_min_scale_factor: 1.0,
        vvd_max_scale_factor: 10.0,
        vvd_pyramid_level: 5,
        vvd_scale_levels: '',
        vvd_export_cpus: 32,
        vvd_export_mem_gb: 192,
        vvd_block_size: '256,256,256'
    ]
}

def vvd_spark_params(Map ps) {
    def vvd_spark_cmdline_params = ps.vvd_spark
        ? ps.vvd_spark
        : [:]
    spark_params(ps) +
    [
        spark_container_repo: 'ghcr.io/janeliascicomp',
        spark_container_name: 'n5-spark-tools',
        spark_container_version: '3.11.2',
        workers: 8,
        worker_cores: 16,
        gb_per_core: 14
    ] +
    vvd_spark_cmdline_params
}