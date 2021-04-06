#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_em_params;
    get_value_or_default;
    get_list_or_default;
    exm_synapse_container_param;
} from './param_utils'

// app parameters
final_params = default_em_params() + params

include {
    get_stitched_data;
} from './processes/stitching' addParams(final_params)

synapse_params = final_params + [
    exm_synapse_container: exm_synapse_container_param(final_params),
]
include {
    find_synapses_without_neuron_info;
} from './workflows/synapse_detection' addParams(synapse_params)

data_dir = final_params.data_dir
pipeline_output_dir = get_value_or_default(final_params, 'output_dir', data_dir)
create_output_dir(pipeline_output_dir)

workflow {
    def datasets = get_list_or_default(final_params, 'datasets', [])
    def stitched_data = Channel.fromList(
        get_stitched_data(
            pipeline_output_dir,
            datasets,
            final_params.stitching_output
        )
    ) // [ dataset, dataset_stitched_dir, dataset_output_dir ]

    def synapses_res = find_synapses_without_neuron_info(
        stitched_data.map { it[0] }, // dataset
        stitched_data.map { "${it[1]}/slice-tiff-s${final_params.export_level}/${final_params.synapse_channel_subfolder}" }, // synapse channel stack
        stitched_data.map { "${it[2]}/synapses" } // output dir
    )

    synapses_res | view

}

def create_output_dir(output_dirname) {
    def output_dir = file(output_dirname)
    output_dir.mkdirs()
}
