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
    tuple val(template_image), val(output_image),
          val(template_dataset), val(target_dataset),
          val(data_type)

    output:
    tuple val(template_image), val(output_image)

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
    val(n5_dataset)

    output:
    tuple val(n5_stack), env(n5_attributes)

    script:
    def n5_attributes_file = "${n5_stack}/${n5_dataset}/attributes.json"
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
        file(input_stack_dir).parent,
    ]) }

    input:
    tuple val(input_stack_dir), val(output_n5_stack)

    output:
    tuple env(n5_stack), val(input_stack_dir), val(output_n5_stack)

    script:
    def output_stack_dir = file(output_n5_stack).parent
    def chunk_size = params.block_size
    """
    if [[ -f "${input_stack_dir}/attributes.json" ]]; then
        n5_stack=${input_stack_dir}
    else
        mkdir -p ${output_stack_dir}
        /entrypoint.sh tif_to_n5 -i ${input_stack_dir} -o ${output_n5_stack} -c ${chunk_size} --compression ${params.n5_compression}
        n5_stack=${output_n5_stack}
    fi
    """
}

process tiff_to_n5_with_links {
    container { params.exm_synapse_dask_container }
    cpus { params.tiff2n5_cpus }
    memory { params.tiff2n5_memory }
    containerOptions { create_container_options([
        file(input_stack_dir).parent,
    ]) }

    input:
    tuple val(input_stack_dir), val(output_n5_stack)

    output:
    tuple val(input_stack_dir), val(output_n5_stack)

    script:
    def output_stack_dir = file(output_n5_stack).parent
    def chunk_size = params.block_size
    def create_empty_n5 = """
    cat > "${output_n5_stack}/attributes.json" <<EOF
    {"n5":"2.2.0"}
    EOF
    """.stripIndent()

    """
    mkdir -p ${output_stack_dir}

    if [[ -f "${input_stack_dir}/attributes.json" ]]; then
        mkdir -p ${output_n5_stack}
        for s in `ls -d ${input_stack_dir}/*` ; do
            if [[ -d "\$s" ]] ; then
                echo "Create link for \$s"
                ln -s "\$s" "${output_n5_stack}/\$(basename \$s)" || true
            fi
        done
        ${create_empty_n5}
    else
        /entrypoint.sh tif_to_n5 -i ${input_stack_dir} -o ${output_n5_stack} -c ${chunk_size} --compression ${params.n5_compression}
    fi
    """
}

process n5_to_tiff {
    container { params.exm_synapse_dask_container }
    cpus { params.n52tiff_cpus }
    memory { params.n52tiff_memory }
    containerOptions { create_container_options([
        input_n5_file,
    ]) }

    input:
    tuple val(input_n5_file), val(output_dir)

    output:
    tuple val(input_n5_file), val(output_dir)

    script:
    """
    mkdir -p ${output_dir}
    /entrypoint.sh n5_to_tif.py -i ${input_n5_file} -o ${output_dir}
    """
}
