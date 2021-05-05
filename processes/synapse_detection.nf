include {
    read_json;
} from '../utils/utils'

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

def readN5Attributes(n5Path) {
    def attributesFilepath = "${n5Path}/s0/attributes.json"
    def attributesFile = new File(attributesFilepath)
    if (attributesFile.exists()) {
        return read_json(attributesFile)
    } else
        return [:]
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
    tuple val(input_stack_dir), val(output_n5_stack)

    output:
    tuple val(input_stack_dir), val(output_n5_stack)

    script:
    def chunk_size = params.block_size
    """
    mkdir -p ${file(output_n5_stack).parent}

    if [[ -f "${input_stack_dir}/s0/attributes.json" ]]; then
        ln -s ${input_stack_dir} ${output_n5_stack}
    else
        /entrypoint.sh tif_to_n5 -i ${input_stack_dir} -o ${output_n5_stack} -c ${chunk_size}
    fi
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
    tuple val(input_image), val(mask_image), val(start_subvolume), val(end_subvolume), val(output_image_arg), val(output_csv_dir), val(vol_size)
    val(percentage)
    val(threshold)

    output:
    tuple val(input_image), val(mask_image), val(start_subvolume), val(end_subvolume), val(output_image), val(output_csv_dir), val(vol_size)

    script:
    output_image = output_image_arg ? output_image_arg : input_image
    def mask_arg = mask_image ? "-m ${mask_image}" : ''
    """
    mkdir -p ${output_csv_dir}

    /scripts/postprocess_cpu.sh \
        -i ${input_image} \
        -o ${output_image} \
        --csv_output_path ${output_csv_dir} \
        --start ${start_subvolume} \
        --end ${end_subvolume} \
        -p ${percentage} \
        -t ${threshold} \
        ${mask_arg}
    """
}

process aggregate_csvs {
    container { params.exm_synapse_container }
    label 'small'

    input:
    tuple val(input_csvs_dir), val(output_csv)

    output:
    tuple val(input_csvs_dir), val(output_csv)

    script:
    """
    i=0 # Reset a counter
    for fn in ${input_csvs_dir}/*.csv; do 
        if [ "\$fn"  != "${output_csv}" ] ; then 
            if [[ \$i -eq 0 ]] ; then 
                head -1  "\$fn" >   "${output_csv}" # Copy header if it is the first file
            fi
            tail -n +2  "\$fn" >>  "${output_csv}" # Append from the 2nd line each file
            i=\$(( \$i + 1 ))
        fi
    done
    """
}