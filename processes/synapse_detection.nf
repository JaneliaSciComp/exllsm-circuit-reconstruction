include {
    create_container_options;
} from '../utils/utils'

process unet_classifier {
    container { params.exm_synapse_container }
    cpus { cpus }
    memory { memory }
    accelerator 1
    label 'withGPU'
    containerOptions { create_container_options([
        input_image,
        output_image_arg,
    ]) }

    input:
    tuple val(input_image),
          val(input_dataset),
          val(output_image_arg),
          val(output_dataset),
          val(vol_size),
          val(start_subvolume),
          val(end_subvolume)
    val(synapse_model)
    val(cpus)
    val(memory)

    output:
    tuple val(input_image),
          val(input_dataset),
          val(output_image),
          val(output_dataset),
          val(vol_size),
          val(start_subvolume),
          val(end_subvolume)

    script:
    output_image = output_image_arg ? output_image_arg : input_image
    def gpu_mem_growth_arg = params.use_gpu_mem_growth ? '--set_gpu_mem_growth' : ''
    def predict_threshold = params.synapse_predict_threshold
        ? "--predict-th ${params.synapse_predict_threshold}"
        : ''
    def input_dataset_arg = input_dataset
        ? "--input_data_set ${input_dataset}"
        : '' 
    def output_dataset_arg = output_dataset
        ? "--output_data_set ${output_dataset}"
        : ''
    def unet_runner = params.unet_completed
        ? 'echo'
        : ''
    """
    ${unet_runner} python /scripts/unet_gpu.py \
        -i ${input_image} ${input_dataset_arg} \
        -m ${synapse_model} \
        --start ${start_subvolume} \
        --end ${end_subvolume} \
        ${predict_threshold} \
        ${gpu_mem_growth_arg} \
        -o ${output_image} ${output_dataset_arg}
    """
}

process segmentation_postprocessing {
    container { params.exm_synapse_container }
    cpus { cpus }
    memory { memory }
    containerOptions { create_container_options([
        input_image,
        mask_image,
        output_image_arg,
    ]) }

    input:
    tuple val(input_image),
          val(input_dataset),
          val(mask_image),
          val(mask_dataset),
          val(output_image_arg),
          val(output_dataset),
          val(output_csv_dir),
          val(vol_size),
          val(start_subvolume),
          val(end_subvolume)
    val(threshold)
    val(percentage)
    val(cpus)
    val(memory)
    val(postprocessing_threads)

    output:
    tuple val(input_image),
          val(input_dataset),           
          val(mask_image),
          val(mask_dataset),
          val(output_image),
          val(output_dataset),
          val(output_csv_dir),
          val(vol_size),
          val(start_subvolume),
          val(end_subvolume)

    script:
    output_image = output_image_arg ? output_image_arg : input_image
    def input_dataset_arg = input_dataset
        ? "--input_data_set ${input_dataset}"
        : '' 
    def output_dataset_arg = output_dataset
        ? "--output_data_set ${output_dataset}"
        : '' 
    def mask_dataset_arg = mask_dataset
        ? "--mask_data_set ${mask_dataset}"
        : '' 
    def mask_arg = mask_image ? "-m ${mask_image} ${mask_dataset_arg}" : ''
    def nthreads_arg = postprocessing_threads > 1
        ? "--nthreads ${postprocessing_threads}"
        : ''
    """
    mkdir -p ${output_csv_dir}

    /scripts/postprocess_cpu.sh \
        -i ${input_image} ${input_dataset_arg} \
        -o ${output_image} ${output_dataset_arg} \
        --csv_output_path ${output_csv_dir} \
        --start ${start_subvolume} \
        --end ${end_subvolume} \
        -t ${threshold} \
        -p ${percentage} \
        ${nthreads_arg} \
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
