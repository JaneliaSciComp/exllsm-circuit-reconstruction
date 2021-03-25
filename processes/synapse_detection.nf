process extract_tiff_stack_metadata {
    container { params.exm_synapse_container }

    input:
    val(tiff_stack_dir)

    output:
    tuple val(tiff_stack_dir), env(width), env(height), env(depth)

    script:
    """
    a_tiff_img=`ls ${tiff_stack_dir}/*.tif | head -n 1`
    echo "TIFF image selected for extracting metadata: \${a_tiff_img}"
    width=`gm identify \${a_tiff_img} | cut -d ' ' -f 3 | cut -d '+' -f 1 | cut -d 'x' -f 1`
    height=`gm identify \${a_tiff_img} | cut -d ' ' -f 3 | cut -d '+' -f 1 | cut -d 'x' -f 2`
    depth=`ls ${tiff_stack_dir}/*.tif | wc -l`
    echo "Volume dimensions: \${width} x \${height} x \${depth}"
    """
}

process tiff_to_hdf5 {
    container { params.exm_synapse_container }
    cpus { params.tiff2h5_cpus }

    input:
    val(input_tiff_stack_dir)
    val(output_h5_file)

    output:
    tuple val(input_tiff_stack_dir), val(output_h5_file)

    script:
    def output_h5_dir = file(output_h5_file).parent
    def args_list = [
        '-i',
        input_tiff_stack_dir,
        '-o',
        output_h5_file,
    ]
    def args = args_list.join(' ')
    """
    mkdir -p ${output_h5_dir}
    python /scripts/tif_to_h5.py ${args}
    """
}

process hdf5_to_tiff {
    container { params.exm_synapse_container }
    cpus { params.h52tiff_cpus }

    input:
    val(input_dir)
    val(output_dir)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    def args_list = [
        '-i',
        input_dir,
        '-o',
        output_dir,
    ]
    def args = args_list.join(' ')
    """
    mkdir -p ${output_dir}
    python /scripts/h5_to_tif.py ${args}
    """
}

process synapse_segmentation {
    container { params.exm_synapse_container }
    cpus { params.synapse_segmentation_cpus }
    accelerator 1
    label 'withGPU'

    input:
    val(input_image)
    val(model_file)
    val(volume_limits)

    output:
    tuple val(input_image), val(volume_limits)

    script:
    def args_list = [
        '-i',
        input_image,
        '-l',
        volume_limits,
    ]
    def args = args_list.join(' ')
    """
    python /scripts/unet_gpu.py ${args}
    """
}

process mask_synapses {
    container { params.exm_synapse_container }
    cpus { params.mask_synapses_cpus }

    input:
    val(input_image)
    val(mask_image)
    val(volume_limits)
    val(threshold)
    val(percentage)

    output:
    tuple val(input_image), val(volume_limits)

    script:
    def args_list = [
        '-i',
        input_image,
        '-l',
        volume_limits,
        '-t',
        threshold,
        '-p',
        percentage,
    ]
    if (mask_image) {
        args_list << '-m' << mask_image
    }
    def args = args_list.join(' ')
    """
    python /scripts/postprocess_cpu.py ${args}
    """
}
