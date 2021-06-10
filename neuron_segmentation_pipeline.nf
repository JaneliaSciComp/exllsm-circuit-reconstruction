#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_em_params;
    get_value_or_default;
    exm_synapse_dask_container_param;
    exm_neuron_segmentation_container;
} from './param_utils'

// app parameters
def final_params = default_em_params(params)

def neuron_seg_params = final_params + [
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params),
    exm_neuron_segmentation_container: exm_neuron_segmentation_container(final_params),
]

include {
    neuron_segmentation;
} from './workflows/neuron_segmentation' addParams(neuron_seg_params)

include {
    neuron_connected_comps_spark_params
} from './params/neuron_params'

def neuron_comp_params = neuron_seg_params +
                         neuron_connected_comps_spark_params(final_params) 

include {
    connected_components
} from './workflows/connected_components' addParams(neuron_comp_params)


include {
    vvd_spark_params
} from './params/vvd_params'

def vvd_params = neuron_seg_params +
                 vvd_spark_params(final_params) 

include {
    n5_to_vvd
} from './workflows/n5_tools' addParams(vvd_params)

workflow {
    def neuron_res
    if (neuron_seg_params.skip_segmentation) {
        neuron_res = Channel.of(
            [
                neuron_seg_params.neuron_stack_dir,
                neuron_seg_params.neuron_input_dataset,
                neuron_seg_params.output_dir,
                neuron_seg_params.neuron_output_dataset,
            ]
        )
    } else {
        neuron_res = neuron_segmentation(
            [
                neuron_seg_params.neuron_stack_dir,
                neuron_seg_params.neuron_input_dataset,
            ],
            [
                neuron_seg_params.output_dir,
                neuron_seg_params.neuron_output_dataset,
                neuron_seg_params.unsegmented_dataset,
            ]
        );
    }
    neuron_res.subscribe { log.debug "Neuron segmentation result: $it" }

    def connected_comps_res;
    if (neuron_seg_params.with_connected_comps) {
        connected_comps_res = connected_components(
            neuron_res.map { it[2] },  // neuron segmented N5 dir
            neuron_res.map { it[3] },  // segmented neuron dataset
            neuron_comp_params.neuron_conn_comp_dataset, // sub dir for connected comp
            neuron_comp_params.app,
            neuron_comp_params.spark_conf,
            neuron_res.map {
                // this is just so that it would not start the cluster before
                // the segmentation completes
                "${get_spark_working_dir(neuron_comp_params.spark_work_dir)}/connected_comps",
            }, // spark_working_dir
            neuron_comp_params.workers,
            neuron_comp_params.worker_cores,
            neuron_comp_params.gb_per_core,
            neuron_comp_params.driver_cores,
            neuron_comp_params.driver_memory,
            neuron_comp_params.driver_stack_size,
            neuron_comp_params.driver_logconfig
        )
    } else {
        log.info "Skip connected components step"
        connected_comps_res = neuron_res
        | map {
            def (unsegmented_dir, unsegmented_dataset,
                segmented_dir, segmented_dataset) = it
            [
                segmented_dir,
                segmented_dataset,
                segmented_dataset // same as segmented dataset since this was a no op
            ]
        }
    }
    connected_comps_res.subscribe { log.debug "Neuron connected commponents: $it" }

    if (vvd_params.neuron_vvd_output) {
        def n52vvd_res = n5_to_vvd(
            connected_comps_res.map { it[0] }, // neuron segmented N5 dir
            connected_comps_res.map { it[2] }, // sub dir for connected comp
            vvd_params.neuron_vvd_output,
            vvd_params.app,
            vvd_params.spark_conf,
            connected_comps_res.map {
                // this is just so that it would not start the cluster before
                // the conneccted components completes
                "${get_spark_working_dir(vvd_params.spark_work_dir)}/n52vvd"
            }, // spark_working_dir
            vvd_params.workers,
            vvd_params.worker_cores,
            vvd_params.gb_per_core,
            vvd_params.driver_cores,
            vvd_params.driver_memory,
            vvd_params.driver_stack_size,
            vvd_params.driver_logconfig
        )
    }
}

def get_spark_working_dir(base_dir) {
    base_dir ? base_dir : '/tmp'
}
