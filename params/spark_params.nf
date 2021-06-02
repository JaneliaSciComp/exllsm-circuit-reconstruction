include {
    default_spark_params;
} from '../external-modules/spark/lib/param_utils'

def spark_params() {
    default_spark_params() +
    [
        spark_container_repo: 'registry.int.janelia.org/exm-analysis',
        spark_container_name: 'stitching',
        spark_container_version: '1.9.0',
        spark_local_dir: "/tmp",
        app: '/app/app.jar',
    ]
}
