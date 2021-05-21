include {
    create_container_options;
} from '../utils/utils'

process compute_unet_scaling {
    container { params.exm_neuron_segmentation_container }
    cpus { params.neuron_scaling_cpus }
    memory { params.neuron_scaling_memory }
    containerOptions { create_container_options([
        input_image,
    ]) }

    input:
    tuple val(input_image), val(start), val(end)
    val(n_tiles_for_scaling) // number of tiles used for computing the scaling
    val(percent_tiles_for_scaling) // percentage of the tiles used for scaling

    output:
    tuple val(input_image), env(scaling)

    script:
    def scaling_partition_size_arg = params.neuron_scaling_partition_size
        ? "--partition_size ${params.neuron_scaling_partition_size}"
        : ''
    def scaling_plots_dir_arg = params.neuron_scaling_plots_dir
        ? "--scaling_plots_dir ${params.neuron_scaling_plots_dir}"
        : ''
    def scaling_plots_mkdir = params.neuron_scaling_plots_dir
        ? "mkdir -p ${params.neuron_scaling_plots_dir}"
        : ''
    def start_arg = start ? "--start ${start}" : ''
    def end_arg = end ? "--end ${end}" : ''
    def n_tiles_arg = (n_tiles_for_scaling as int) > 0
        ? "-n ${n_tiles_for_scaling}"
        : ''
    def percent_tiles_arg = (percent_tiles_for_scaling as float) > 0
        ? "-p ${percent_tiles_for_scaling}"
        : ''
    """
    ${scaling_plots_mkdir}
    scaling_log=\$PWD/scaling.log
    /entrypoint.sh volumeScalingFactor \
        -i ${input_image} \
        -d ${params.neuron_input_dataset} \
        ${n_tiles_arg} ${percent_tiles_arg} \
        ${scaling_partition_size_arg} \
        ${scaling_plots_dir_arg} \
        ${start_arg} ${end_arg} \
        > \$scaling_log
    echo "Extract scaling factor from \$scaling_log"
    scaling=`grep -o "Calculated a scaling factor of \\(.*\\) based on" \$scaling_log | cut -d ' ' -f6`
    """
}

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
    def binary_mask_arg = params.neuron_mask_as_binary ? '--as_binary_mask' : ''
    """
    /entrypoint.sh volumeSegmentation \
        -i ${input_image} \
        -id ${params.neuron_input_dataset} \
        -o ${output_image} \
        -od ${params.neuron_output_dataset} \
        -m ${params.neuron_model} \
        --image_shape ${vol_size} \
        --start ${start_subvolume} \
        --end ${end_subvolume} \
        ${scaling_arg} \
        ${gpu_mem_growth_arg} \
        --unet_batch_size ${params.neuron_seg_unet_batch_sz} \
        --model_input_shape ${params.neuron_seg_model_in_dims} \
        --model_output_shape ${params.neuron_seg_model_out_dims} \
        ${binary_mask_arg} \
        ${post_processing_arg} \
        --high_threshold ${params.neuron_seg_high_th} \
        --low_threshold ${params.neuron_seg_low_th} \
        --small_region_probability_threshold ${params.neuron_seg_small_region_prob_th} \
        --small_region_size_threshold ${params.neuron_seg_small_region_size_th}
    """
}
