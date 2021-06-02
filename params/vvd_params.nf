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

def vvd_spark_params() {
    def vvd_spark_cmdline_params = ps.vvd_spark
        ? ps.vvd_spark
        : [:]
    spark_params() +
    vvd_spark_cmdline_params
}