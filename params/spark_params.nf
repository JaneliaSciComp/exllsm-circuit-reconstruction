include {
    default_spark_params;
} from '../external-modules/spark/lib/param_utils'

def spark_params(Map ps) {
    default_spark_params() +
    [
        spark_container_repo: 'public.ecr.aws/janeliascicomp/exm-analysis',
        spark_local_dir: "/tmp",
        app: '/app/app.jar',
        driver_stack_size: '', // default spark
    ] + ps
}
