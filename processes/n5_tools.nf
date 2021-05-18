process create_n5_volume {
    label 'small'

    container { params.exm_synapse_dask_container }

    input:
    tuple val(template_image), val(output_image)

    output:
    tuple val(template_image), val(output_image)

    script:
    """
    mkdir -p ${file(output_image).parent}
    /entrypoint.sh create_n5 -o ${output_image} -t ${template_image} --compression ${params.n5_compression}
    """
}

process read_n5_metadata {
    label 'small'

    container { params.exm_synapse_dask_container }

    input:
    val(n5_stack)

    output:
    tuple val(n5_stack), env(n5_attributes)

    script:
    def n5_attributes_file = "${n5_stack}/s0/attributes.json"
    """
    if [[ -e ${n5_attributes_file} ]]; then
        n5_attributes=`cat ${n5_attributes_file}`
    else
        n5_attributes=null
    fi
    """
}

process tiff_to_n5 {
    container { params.exm_synapse_dask_container }
    cpus { params.tiff2n5_cpus }
    memory { params.tiff2n5_memory }

    input:
    tuple val(input_stack_dir), val(output_n5_stack)

    output:
    tuple val(input_stack_dir), val(output_n5_stack)

    script:
    def chunk_size = params.block_size
    def create_empty_n5 = """
    cat > "${output_n5_stack}/attributes.json" <<EOF
    {"n5":"2.2.0"}
    EOF
    """.stripIndent()

    """
    mkdir -p ${file(output_n5_stack).parent}

    if [[ -f "${input_stack_dir}/s0/attributes.json" ]]; then
        mkdir ${output_n5_stack}
        ln -s "${input_stack_dir}/s0" "${output_n5_stack}/s0" || true
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
