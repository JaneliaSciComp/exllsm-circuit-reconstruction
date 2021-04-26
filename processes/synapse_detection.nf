process create_n5_volume {
    container { params.exm_synapse_dask_container }

    input:
    val(input_tuple) // [ input_image, image_size, output_image, ... ]

    output:
    val(input_tuple)

    script:
    // the method expects the first 3 elements of the 'input_tuple' tuple
    // to be input_image, image_size and output_image
    def (input_image, image_size, output_image) = input_tuple
    """
    mkdir -p ${file(output_image).parent}
    /entrypoint.sh create_n5 -o ${output_image} -t ${input_image}
    """
}

import groovy.json.JsonSlurper
def readN5Attributes(n5Path) {
    def attributesFilepath = "${n5Path}/s0/attributes.json"
    def attributesFile = new File(attributesFilepath)
    if (attributesFile.exists()) {
        def jsonSlurper = new JsonSlurper()
        return jsonSlurper.parseText(attributesFile.text)
    }
    return null
}

process read_n5_metadata {
    executor 'local'

    input:
    tuple val(tiff_stack_dir), val(n5_file)

    output:
    tuple val(tiff_stack_dir), val(n5_file), val(dimensions)

    exec:
    dimensions = readN5Attributes(n5_file).dimensions
}

process tiff_to_n5 {
    container { params.exm_synapse_dask_container }
    cpus { params.tiff2n5_cpus }

    input:
    tuple val(input_tiff_stack_dir), val(output_n5_file)

    output:
    tuple val(input_tiff_stack_dir), val(output_n5_file)

    script:
    def chunk_size = params.block_size
    """
    mkdir -p ${file(output_n5_file).parent}
    /entrypoint.sh tif_to_n5 -i ${input_tiff_stack_dir} -o ${output_n5_file} -c ${chunk_size}
    """
}

process n5_to_tiff {
    container { params.exm_synapse_dask_container }
    cpus { params.n52tiff_cpus }

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

process unet_classifier {
    container { params.exm_synapse_container }
    cpus { params.unet_cpus }
    accelerator 1
    label 'withGPU'

    input:
    tuple val(input_image), val(start_subvolume), val(end_subvolume), val(output_image_arg), val(vol_size)
    val(synapse_model)

    output:
    tuple val(input_image), val(start_subvolume), val(end_subvolume), val(output_image), val(vol_size)

    script:
    output_image = output_image_arg ? output_image_arg : input_image
    """
    python /scripts/unet_gpu.py \
        -i ${input_image} \
        -m ${synapse_model} \
        --start ${start_subvolume} \
        --end ${end_subvolume} \
        -o ${output_image}
    """
}

process segmentation_postprocessing {
    container { params.exm_synapse_container }
    cpus { params.postprocessing_cpus }

    input:
    tuple val(input_image), val(mask_image), val(start_subvolume), val(end_subvolume), val(output_image_arg), val(vol_size)
    val(percentage)
    val(threshold)

    output:
    tuple val(input_image), val(mask_image), val(start_subvolume), val(end_subvolume), val(output_image), val(vol_size)

    script:
    output_image = output_image_arg ? output_image_arg : input_image
    def mask_arg = mask_image ? "-m ${mask_image}" : ''
    """
    /scripts/postprocess_cpu.sh \
        -i ${input_image} \
        -o ${output_image} \
        --start ${start_subvolume} \
        --end ${end_subvolume} \
        -p ${percentage} \
        -t ${threshold} \
        ${mask_arg}
    """
}
