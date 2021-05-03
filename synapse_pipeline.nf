#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_em_params;
    get_value_or_default;
    exm_synapse_container_param;
    exm_synapse_dask_container_param;
} from './param_utils'

// app parameters
final_params = default_em_params() + params

synapse_params = final_params + [
    exm_synapse_container: exm_synapse_container_param(final_params),
    exm_synapse_dask_container: exm_synapse_dask_container_param(final_params),
]
include {
    presynaptic_in_volume;
    presynaptic_n1_to_n2;
    presynaptic_n1_to_postsynaptic_n2;
} from './workflows/synapse_detection' addParams(synapse_params)

pipeline_output_dir = final_params.output_dir

workflow {
    def synapses_res;
    switch(final_params.pipeline) {
        case 'presynaptic_n1_to_n2':
            if (!final_params.pre_synapse_stack_dir ||
                !final_params.n1_stack_dir ||
                !final_params.n2_stack_dir) {
                log.error "'--pre_synapse_stack_dir', '--n1_stack_dir','--n2_stack_dir' must be defined"
                exit(1)
            }
            synapses_res = presynaptic_n1_to_n2(
                Channel.of(
                    [
                        final_params.pre_synapse_stack_dir,
                        final_params.n1_stack_dir,
                        final_params.n2_stack_dir,
                        "${pipeline_output_dir}/presynaptic_n1_to_n2_n5",
                    ]
                )
            )
            break;
        case 'presynaptic_n1_to_postsynaptic_n2':
            if (!final_params.pre_synapse_stack_dir ||
                !final_params.n1_stack_dir ||
                !final_params.post_synapse_stack_dir) {
                log.error "'--pre_synapse_stack_dir', '--n1_stack_dir','--post_synapse_stack_dir' must be defined"
                exit(1)
            }
            synapses_res = presynaptic_n1_to_postsynaptic_n2(
                Channel.of(
                    [
                        final_params.pre_synapse_stack_dir,
                        final_params.n1_stack_dir,
                        final_params.post_synapse_stack_dir,
                        "${pipeline_output_dir}/presynaptic_n1_to_restricted_post_n2_n5",
                    ]
                )
            )
            break;
        case 'presynaptic_in_volume':
        default:
            if (!final_params.pre_synapse_stack_dir) {
                log.error "'--pre_synapse_stack_dir' must be defined"
                exit(1)
            }
            synapses_res = presynaptic_in_volume(
                Channel.of(
                    [
                        final_params.pre_synapse_stack_dir,
                        "${pipeline_output_dir}/presynaptic_in_volume_n5",
                    ]
                )
            )
            break;
    }

    synapses_res | view
}
