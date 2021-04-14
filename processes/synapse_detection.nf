process duplicate_h5_volume {
    container { params.exm_synapse_container }

    input:
    val(data) // [ input_image, image_size, output_image, ... ]

    output:
    val(data)

    script:
    // the method expects the first 3 elements of the 'data' tuple
    // to be input_image, image_size and output_image
    def (input_image, image_size, output_image) = data
    """
    mkdir -p ${file(output_image).parent}
    python /scripts/create_h5.py \
        '-f' ${output_image} \
        '-s' ${image_size.depth},${image_size.width},${image_size.height}
    """
}

process extract_tiff_stack_metadata {
    container { params.exm_synapse_container }

    input:
    val(tiff_stack_dir)

    output:
    tuple val(tiff_stack_dir), env(width), env(height), env(depth)

    script:
    if (tiff_stack_dir) {
        """
        a_tiff_img=`ls ${tiff_stack_dir}/*.tif | head -n 1`
        echo "TIFF image selected from ${tiff_stack_dir} for extracting metadata: \${a_tiff_img}"
        height=`gm identify \${a_tiff_img} | cut -d ' ' -f 3 | cut -d '+' -f 1 | cut -d 'x' -f 1`
        width=`gm identify \${a_tiff_img} | cut -d ' ' -f 3 | cut -d '+' -f 1 | cut -d 'x' -f 2`
        depth=`ls ${tiff_stack_dir}/*.tif | wc -l`
        echo "Volume dimensions: \${width} x \${height} x \${depth}"
        """
    } else {
        """
        width=0
        height=0
        depth=0
        """
    }
}

process tiff_to_hdf5 {
    container { params.exm_synapse_container }
    cpus { params.tiff2h5_cpus }

    input:
    tuple val(input_tiff_stack_dir), val(output_h5_file)

    output:
    tuple val(input_tiff_stack_dir), val(output_h5_file)

    script:
    """
    mkdir -p ${file(output_h5_file).parent}
    python /scripts/tif_to_h5.py '-i' ${input_tiff_stack_dir} '-o' ${output_h5_file}
    """
}

process hdf5_to_tiff {
    container { params.exm_synapse_container }
    cpus { params.h52tiff_cpus }

    input:
    tuple val(input_h5_file), val(output_dir)

    output:
    tuple val(input_h5_file), val(output_dir)

    script:
    """
    mkdir -p ${output_dir}
    python /scripts/h5_to_tif.py '-i' ${input_h5_file} '-o' ${output_dir}
    """
}

process unet_classifier {
    container { params.exm_synapse_container }
    cpus { params.synapse_segmentation_cpus }
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
        '-i' ${input_image} \
        '-m' ${synapse_model} \
        -l ${start_subvolume},${end_subvolume} \
        '-o' ${output_image}
    """
}

process segmentation_postprocessing {
    container { params.exm_synapse_container }
    cpus { params.mask_synapses_cpus }

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
        -o ${output_image} \
        -l ${start_subvolume},${end_subvolume} \
        -p ${percentage} \
        -t ${threshold} \
        ${mask_arg}
    """
}
