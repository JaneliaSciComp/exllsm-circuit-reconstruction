include {
    spark_params;
} from './spark_params'

def n52tif_spark_params(Map ps) {
    def n52tif_spark_cmdline_params = ps.n52tif_spark
        ? ps.n52tif_spark
        : [:]
    spark_params() +
    [
        spark_container_name: 'n5-spark-tools',
        spark_container_version: '3.8.0',
    ] +
    n52tif_spark_cmdline_params
}
