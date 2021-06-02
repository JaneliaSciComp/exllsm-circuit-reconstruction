include {
    spark_params;
} from './spark_params'

def vvd_params() {
    [
        // VVD conversion params
        vvd_pyramid_level: 5,
        vvd_final_ratio: 10,
        vvd_min_threshold: 100,
        vvd_max_threshold: 2100,
        vvd_export_cpus: 32,
        vvd_export_mem_gb: 192,
    ]
}

def vvd_spark_params(Map ps) {
    def vvd_spark_cmdline_params = ps.vvd_spark
        ? ps.vvd_spark
        : [:]
    spark_params() +
    [
        spark_container_name: 'n5-spark-tools',
        spark_container_version: '3.8.0',
    ] +
    vvd_spark_cmdline_params
}