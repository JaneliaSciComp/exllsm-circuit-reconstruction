include {
    spark_params;
} from './spark_params'

def stitching_params() {
    [
        skip: '', // stitching steps to skip
        psf_dir: '',
        stitching_output: '',
        axis: '-y,-x,z',
        channels: '488nm,560nm,642nm',
        stitching_mode: 'incremental',
        stitching_padding: '0,0,0',
        stitching_blur_sigma: '2',
        // the default stiching inputs based on the channels parameter is 488nm-decon,560nm-decon,642nm-decon
        stitching_json_inputs: '', // this can override the default stitching inputs and allows us to do stitching 
                                    // using 1 or more raw channel inputs, in that case the stitching_json_inputs would be
                                    // 488nm or it can be "488nm,560nm" or "488nm,560nm,642nm"
        fuse_to_n5_json_inputs: '', // this will override the default inputs to be used for fuse step and then exported to n5
                                    // keep in mind that the entries will be used as they are
        export_level: '0',
        allow_fusestage: false,

        // deconvolution params
        deconv_cpus: 4,
        background: '100',
        psf_z_step_um: '0.1',
        iterations_per_channel: '10,10,10',
    ]
}

def stitching_spark_params(Map ps) {
    def stitching_spark_cmdline_params = ps.stitching_spark
        ? ps.stitching_spark
        : [:]
    spark_params(ps) +
    [
        spark_container_name: 'stitching',
        spark_container_version: '1.9.0',
        driver_stack_size: '128m', // stitching requires a larger driver stack size
    ] +
    stitching_spark_cmdline_params
}
