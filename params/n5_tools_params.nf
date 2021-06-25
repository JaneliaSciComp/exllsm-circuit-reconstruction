include {
    spark_params;
} from './spark_params'

def n5_tools_spark_params(Map ps) {
    def n5_tools_spark_cmdline_params = ps.n5_tools_spark
        ? ps.n5_tools_spark
        : [:]
    spark_params(ps) +
    [
        spark_container_name: 'n5-spark-tools',
        spark_container_version: '3.8.0',
    ] +
    n5_tools_spark_cmdline_params
}
