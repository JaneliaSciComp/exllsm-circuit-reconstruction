include {
    create_container_options;
} from '../utils/utils'

process unet_classifier {
    container { params.exm_synapse_container }
    cpus { params.unet_cpus }
    memory { params.unet_memory }
    accelerator 1
    label 'withGPU'
    containerOptions { create_container_options([
        input_image,
        output_image_arg,
    ]) }

    input:
    tuple val(input_image), val(output_image_arg), val(vol_size), val(start_subvolume), val(end_subvolume)
    val(synapse_model)

    output:
    tuple val(input_image), val(output_image), val(vol_size), val(start_subvolume), val(end_subvolume)

    script:
    output_image = output_image_arg ? output_image_arg : input_image
    def gpu_mem_growth_arg = params.use_gpu_mem_growth ? '--set_gpu_mem_growth' : ''
    """
    python /scripts/unet_gpu.py \
        -i ${input_image} \
        -m ${synapse_model} \
        --start ${start_subvolume} \
        --end ${end_subvolume} \
        ${gpu_mem_growth_arg} \
        -o ${output_image}
    """
}

process segmentation_postprocessing {
    container { params.exm_synapse_container }
    cpus { params.postprocessing_cpus }
    memory { params.postprocessing_memory }
    containerOptions { create_container_options([
        input_image,
        mask_image,
        output_image_arg,
    ]) }

    input:
    tuple val(input_image), val(mask_image), val(output_image_arg), val(output_csv_dir), val(vol_size), val(start_subvolume), val(end_subvolume)
    val(threshold)
    val(percentage)

    output:
    tuple val(input_image), val(mask_image), val(output_image), val(output_csv_dir), val(vol_size), val(start_subvolume), val(end_subvolume)

    script:
    output_image = output_image_arg ? output_image_arg : input_image
    def mask_arg = mask_image ? "-m ${mask_image}" : ''
    """
    mkdir -p ${output_csv_dir}

    /scripts/postprocess_cpu.sh \
        -i ${input_image} \
        -o ${output_image} \
        --csv_output_path ${output_csv_dir} \
        --start ${start_subvolume} \
        --end ${end_subvolume} \
        -t ${threshold} \
        -p ${percentage} \
        ${mask_arg}
    """
}

process aggregate_csvs {
    container { params.exm_synapse_container }
    label 'small'
    containerOptions { create_container_options([
        input_csvs_dir
    ]) }

    input:
    tuple val(input_csvs_dir), val(output_csv)

    output:
    tuple val(input_csvs_dir), val(output_csv)

    script:
    """
    python /scripts/aggregate_csvs.py \
        -i ${input_csvs_dir} \
        -o ${output_csv}
    """
}
