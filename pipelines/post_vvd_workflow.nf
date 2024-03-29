#!/usr/bin/env nextflow

/*
Parameters:
    input_dir
    output_dir
    shared_temp_dir
    threshold
    mask_connection_distance
    mask_connection_iterations
    with_connected_comps
    output_n5
*/

nextflow.enable.dsl=2

include {
    default_em_params;
    exm_synapse_dask_container_param;
    exm_neuron_segmentation_container;
} from '../param_utils'

def em_params = default_em_params(params)
def final_params = em_params + [
    exm_synapse_dask_container: exm_synapse_dask_container_param(em_params),
    exm_neuron_segmentation_container: exm_neuron_segmentation_container(em_params),
]

include {
    neuron_connected_comps_spark_params;
} from '../params/neuron_params'

def app_params = final_params + 
                 neuron_connected_comps_spark_params(final_params) 

include {
    connected_components;
} from '../workflows/connected_components' addParams(app_params)

include {
    connect_mask;
} from '../pipelines/connect_mask' addParams(app_params)

include {
    prepare_mask_dirs;
    threshold_mask;
    convert_from_mask;
    get_brick_files;
    connect_tiff;
    convert_to_mask;
    complete_mask;
} from '../processes/image_processing' addParams(app_params)

include {
    tiff_to_n5;
} from '../processes/n5_tools' addParams(app_params)

workflow post_vvd {
    take:
    input_vals

    main:
    connected_tiff = connect_mask(input_vals) 

    if (app_params.output_n5 || app_params.with_connected_comps) {

        n5_params = connected_tiff | map {
                            def (input_dir, output_dir, shared_temp_dir, threshold_dir, connect_dir) = it  
                            def output_n5 = app_params.output_n5 
                                ? "${app_params.output_n5}" 
                                : "${output_dir}/export.n5"
                            def n5_dataset = app_params.output_dataset
                                ? "${app_params.output_dataset}"
                                : "${params.default_n5_dataset}"
                            [ output_dir, "", output_n5, n5_dataset ]
                        }
        
        n5_export = tiff_to_n5(n5_params, app_params.partial_volume)
        n5_export.subscribe { log.debug "N5 export: $it" }

        if (app_params.with_connected_comps) {
            def session_id = UUID.randomUUID()
            connected_comps_res = connected_components(
                n5_export.map { it[3] }, // n5 input
                n5_export.map { it[4] }, // n5 container sub-dir (e.g. /s0)
                app_params.connected_dataset, // sub dir for connected comp
                app_params.app,
                app_params.spark_conf,
                n5_export.map {
                    // this is just so that it would not start the cluster before
                    // the n5 export completes
                    "${app_params.spark_work_dir}/${session_id}/connected-comps"
                }, // spark_working_dir
                app_params.workers,
                app_params.worker_cores,
                app_params.gb_per_core,
                app_params.driver_cores,
                app_params.driver_memory,
                app_params.driver_stack_size,
                app_params.driver_logconfig
            )
            connected_comps_res.subscribe { log.debug "Connected components: $it" }
        } 
        else {
            log.debug "Skipping connected components"
        }
    }
    else {
        log.debug "Skipping n5 output"
    }
    
    
}

workflow {

    post_vvd(
        Channel.of(
            [
                app_params.input_dir, 
                app_params.shared_temp_dir, 
                app_params.output_dir
            ]
        )
    )

}