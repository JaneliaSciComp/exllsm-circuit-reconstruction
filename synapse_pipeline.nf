#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_em_params;
    get_value_or_default;
    exm_synapse_container_param;
    exm_synapse_dask_container_param;
} from './param_utils'

// app parameters
def final_params = default_em_params(params)

include {
    n5_tools_spark_params;
} from './params/n5_tools_params'

def downsample_params = final_params +
                        n5_tools_spark_params(final_params)

def synapse_params = final_params + [
    working_container: get_value_or_default(final_params, 'working_container', "${final_params.pipeline}.n5"),
    exm_synapse_container: exm_synapse_container_param(final_params),
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params),
    downsample: downsample_params,
]

include {
    classify_synapses;
    collocate_synapses;
    presynaptic_in_volume;
    presynaptic_n1_to_n2;
    presynaptic_n1_to_postsynaptic_n2;
} from './workflows/synapse_detection' addParams(synapse_params)

pipeline_output_dir = synapse_params.output_dir

workflow {
    def synapses_res;
    switch(synapse_params.pipeline) {
        case 'classify_synapses':
            if (!synapse_params.pre_synapse_stack_dir) {
                log.error "'--pre_synapse_stack_dir' must be defined"
                exit(1)
            }
            synapses_res = classify_synapses(
                [
                    synapse_params.pre_synapse_stack_dir,
                    synapse_params.pre_synapse_in_dataset,
                ],
                pipeline_output_dir,
            )
            break
        case 'collocate_synapses':
            if (!synapse_params.pre_synapse_stack_dir ||
                !synapse_params.n1_stack_dir) {
                log.error "'--pre_synapse_stack_dir', '--n1_stack_dir' must be defined"
                exit(1)
            }
            synapses_res = collocate_synapses(
                [
                    synapse_params.pre_synapse_stack_dir,
                    synapse_params.pre_synapse_in_dataset,
                    synapse_params.n1_stack_dir,
                    synapse_params.n1_in_dataset,
                ],
                pipeline_output_dir,
            )
            break
        case 'presynaptic_n1_to_n2':
            if (!synapse_params.pre_synapse_stack_dir ||
                !synapse_params.n1_stack_dir) {
                log.error "'--pre_synapse_stack_dir', '--n1_stack_dir' must be defined; '--n2_stack_dir' is optional"
                exit(1)
            }
            synapses_res = presynaptic_n1_to_n2(
                [
                    synapse_params.pre_synapse_stack_dir,
                    synapse_params.pre_synapse_in_dataset,
                    synapse_params.n1_stack_dir,
                    synapse_params.n1_in_dataset,
                    synapse_params.n2_stack_dir,
                    synapse_params.n2_in_dataset,
                ],
                pipeline_output_dir,
            )
            break
        case 'presynaptic_n1_to_postsynaptic_n2':
            if (!synapse_params.pre_synapse_stack_dir ||
                !synapse_params.n1_stack_dir ||
                !synapse_params.post_synapse_stack_dir) {
                log.error "'--pre_synapse_stack_dir', '--n1_stack_dir','--post_synapse_stack_dir' must be defined"
                exit(1)
            }
            synapses_res = presynaptic_n1_to_postsynaptic_n2(
                [
                    synapse_params.pre_synapse_stack_dir,
                    synapse_params.pre_synapse_in_dataset,
                    synapse_params.n1_stack_dir,
                    synapse_params.n1_in_dataset,
                    synapse_params.post_synapse_stack_dir,
                    synapse_params.post_synapse_in_dataset,
                ],
                pipeline_output_dir,
            )
            break
        case 'presynaptic_in_volume':
        default:
            if (!synapse_params.pre_synapse_stack_dir) {
                log.error "'--pre_synapse_stack_dir' must be defined"
                exit(1)
            }
            synapses_res = presynaptic_in_volume(
                [
                    synapse_params.pre_synapse_stack_dir,
                    synapse_params.pre_synapse_in_dataset,
                    synapse_params.n1_stack_dir,
                    synapse_params.n1_in_dataset,
                ],
                pipeline_output_dir,
            )
            break
    }

    synapses_res | view
}
