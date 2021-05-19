include {
    create_container_options;
} from '../utils/utils'

process create_n5_volume {
    label 'small'

    container { params.exm_synapse_dask_container }
    containerOptions { create_container_options([
        template_image_dir,
        output_image_dir,
    ]) }

    input:
    tuple val(template_image), val(output_image)

    output:
    tuple val(template_image), val(output_image)

    script:
    def template_image_dir = file(template_image).parent
    def output_image_dir = file(output_image).parent
    """
    mkdir -p ${output_image_dir}
    /entrypoint.sh create_n5 -o ${output_image} -t ${template_image} --compression ${params.n5_compression}
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
    containerOptions { create_container_options([
        input_stack_dir,
        output_stack_dir,
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
    containerOptions { create_container_options([
        input_n5_file,
        output_dir,
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
