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
        echo "TIFF image selected for extracting metadata: \${a_tiff_img}"
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
    val(input_h5_file)
    val(output_dir)

    output:
    tuple val(input_h5_file), val(output_dir)

    script:
    def args_list = [
        '-i',
        input_h5_file,
        '-o',
        output_dir,
    ]
    def args = args_list.join(' ')
    """
    mkdir -p ${output_dir}
    python /scripts/h5_to_tif.py ${args}
    """
}

process unet_classifier {
    container { params.exm_synapse_container }
    cpus { params.synapse_segmentation_cpus }
    accelerator 1
    label 'withGPU'

    input:
    val(input_image)
    val(model_file)
    val(volume_limits)
    val(output_image_arg)

    output:
    tuple val(input_image), val(output_image), val(volume_limits)

    script:
    output_image = output_image_arg ? output_image_arg : input_image
    def args_list = []
    args_list << '-i' << input_image
    args_list << '-m' << model_file,
    args_list << '-l' << "${volume_limits}"
    args_list << '-o' << output_image
    def args = args_list.join(' ')
    """
    python /scripts/unet_gpu.py ${args}
    """
}

process segmentation_postprocessing {
    container { params.exm_synapse_container }
    cpus { params.mask_synapses_cpus }

    input:
    val(input_image)
    val(mask_image)
    val(volume_limits)
    val(threshold)
    val(percentage)
    val(output_image_arg)

    output:
    tuple val(input_image), val(mask_image), val(output_image), val(volume_limits)

    script:
    output_image = output_image_arg ? output_image_arg : input_image

    def args_list = []
    args_list << '-i' << input_image
    args_list << '-o' << output_image
    args_list << '-o' << output_image
    args_list << '-l' << "${volume_limits}"
    args_list << '-p' << percentage
    args_list << '-t' << threshold
    if (mask_image) {
        args_list << '-m' << mask_image
    }
    def args = args_list.join(' ')
    """
    /scripts/postprocess_cpu.sh ${args}
    """
}
