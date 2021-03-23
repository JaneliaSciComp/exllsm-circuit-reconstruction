process tiff_to_hdf5 {
    container { params.exm_synapse_container }
    cpus { params.tiff2h5_cpus }

    input:
    val(input_dir)
    val(output_dir)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    """
    mkdir -p ${output_dir}
    python /scripts/tif_to_h5.py -i ${input_dir} -o ${output_dir}
    """
}

process synapse_segmentation {
    container { params.exm_synapse_container }
    cpus { params.synapse_segmentation_cpus }
    accelerator 1
    label 'withGPU'

    input:
    val(input_dir)
    val(model_file)
    val(volume_limits)

    output:
    tuple val(input_dir), val(output_dir)

    script:
    def args_list = [
        '-i',
        "${input_dir}/slices_to_volume.h5",
        '-l',
        "${volume_limits}"
    ]
    def = args_list.join(' ')
    """
    python /scripts/unet_gpu.py ${args}
    """
}
