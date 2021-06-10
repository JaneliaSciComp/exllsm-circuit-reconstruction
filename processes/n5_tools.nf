include {
    create_container_options;
} from '../utils/utils'

process create_n5_volume {
    label 'small'

    container { params.exm_synapse_dask_container }
    containerOptions { create_container_options([
        file(template_image).parent,
    ]) }

    input:
    tuple val(template_image),
          val(template_dataset),
          val(output_image),
          val(target_dataset),
          val(data_type)

    output:
    tuple val(template_image),
          val(template_dataset),
          val(output_image),
          val(target_dataset)

    script:
    def output_image_dir = file(output_image).parent
    def template_dataset_arg = template_dataset ? "--template_data_set ${template_dataset}" : ''
    def target_dataset_arg = target_dataset ? "--target_data_set ${target_dataset}" : ''
    def data_type_arg = data_type ? "--dtype ${data_type}" : ''
    """
    mkdir -p ${output_image_dir}
    /entrypoint.sh create_n5 \
        -o ${output_image} \
        -t ${template_image} \
        ${template_dataset_arg} ${target_dataset_arg} \
        --compression ${params.n5_compression} \
        ${data_type_arg}
    """
}

process read_n5_metadata {
    label 'small'

    container { params.exm_synapse_dask_container }
    containerOptions { create_container_options([
        n5_stack,
    ]) }

    input:
    val(n5_stack)

    output:
    tuple val(n5_stack), env(n5_attributes)

    script:
    def n5_attributes_file = "${n5_stack}/attributes.json"
    """
    n5_attributes=`cat ${n5_attributes_file} || true`
    if [[ -z \${n5_attributes} ]]; then
        n5_attributes=null
    fi
    """
}

process tiff_to_n5 {
    container { params.exm_synapse_dask_container }
    cpus { params.tiff2n5_cpus }
    memory { params.tiff2n5_memory }
    containerOptions { create_container_options([
        file(input_dir).parent,
    ]) }

    input:
    tuple val(input_dir), val(input_dataset),
          val(output_dir), val(output_dataset)
    val(partial_volume)

    output:
    tuple env(n5_stack),
          val(input_dir), val(input_dataset),
          env(output_n5_dir), env(output_n5_dataset) // actual output

    script:
    def input_stack_dir = file("${input_dir}/${input_dataset}")
    def input_fname_pattern_arg = params.input_imgname_pattern
        ? "--input_name_pattern \"${params.input_imgname_pattern}\""
        : ''
    def output_dir_as_file = file("${output_dir}")
    def output_stack_dir = file("${output_dir}/${}")
    def chunk_size = params.block_size
    def distributed_args = ''
    if (params.tiff2n5_workers > 1) {
        distributed_args = "--distributed --workers ${params.tiff2n5_workers}"
    }
    def subvol_arg = ''
    if (partial_volume) {
        subvol_arg = "--subvol \"${partial_volume}\""
    }
    def n5_dataset = output_dataset
        ? "${output_dataset}"
        : "${params.default_n5_dataset}" // use default
    """
    mkdir -p ${output_dir_as_file.parent}
    if [[ -f "${input_stack_dir}/attributes.json" ]]; then
        # there was no conversion
        echo "No tiff to N5 conversion was necessary for ${input_stack_dir}"
        n5_stack=${input_stack_dir}
        output_n5_dir=${input_dir}
        output_n5_dataset=${input_dataset}
    else
        # convert tiffs to n5
        echo "Convert ${input_stack_dir} ${params.input_imgname_pattern} -> ${output_dir_as_file}:${n5_dataset}"
        /entrypoint.sh tif_to_n5 \
        -i ${input_stack_dir} ${input_fname_pattern_arg} \
        -o ${output_dir} -d ${n5_dataset} \
        -c "${chunk_size}" \
        ${distributed_args} \
        ${subvol_arg} \
        --compression ${params.n5_compression}
        # set the return value
        n5_stack="${output_dir_as_file}/${n5_dataset}"
        output_n5_dir=${output_dir_as_file}
        output_n5_dataset=${n5_dataset}
    fi
    """
}
