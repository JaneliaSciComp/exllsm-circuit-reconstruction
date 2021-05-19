include {
    create_container_options;
} from '../utils/utils'

process unet_volume_segmentation {
    container { params.exm_neuron_segmentation_container }
    cpus { params.neuron_segmentation_cpus }
    memory { params.neuron_segmentation_memory }
    accelerator 1
    label 'withGPU'
    containerOptions { create_container_options([
        input_image,
        output_image,
        file(params.neuron_model).parent
    ]) }

    input:
    tuple val(input_image), val(output_image), val(vol_size), val(start_subvolume), val(end_subvolume), val(scaling)

    output:
    tuple val(input_image), val(output_image), val(vol_size), val(start_subvolume), val(end_subvolume)

    script:
    def gpu_mem_growth_arg = params.use_gpu_mem_growth ? '--set_gpu_mem_growth' : ''
    def post_processing_arg = params.with_neuron_post_segmentation ? '--with_post_processing' : ''
    def scaling_arg = scaling ? "--scaling ${scaling}" : ''
    """
    /entrypoint.sh volumeSegmentation \
        -i ${input_image} \
        -id ${params.neuron_input_dataset} \
        -o ${output_image} \
        -od ${params.neuron_output_dataset} \
        -m ${params.neuron_model} \
        --whole_vol_shape ${vol_size} \
        --start ${start_subvolume} \
        --end ${end_subvolume} \
        ${scaling_arg} \
        --unet_batch_size ${params.neuron_seg_unet_batch_sz} \
        --model_input_shape ${params.neuron_seg_model_in_dims} \
        --model_output_shape ${params.neuron_seg_model_out_dims} \
        ${post_processing_arg} \
        --high_threshold ${params.neuron_seg_high_th} \
        --low_threshold ${params.neuron_seg_low_th} \
        --small_region_probability_threshold ${params.neuron_seg_small_region_prob_th} \
        --small_region_size_threshold ${params.neuron_seg_small_region_size_th}
    """
}
