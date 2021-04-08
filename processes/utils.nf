process merge_3_channels {
    executor 'local'

    input:
    valv1)
    val(v2)
    val(v3)

    output:
    tuple val(v1), val(v2), val(v3)

    exec:
    // nothing to do
}

process merge_4_channels {
    executor 'local'

    input:
    valv1)
    val(v2)
    val(v3)
    val(v4)

    output:
    tuple val(v1), val(v2), val(v3), val(v4)

    exec:
    // nothing to do
}

process merge_7_channels {
    executor 'local'

    input:
    valv1)
    val(v2)
    val(v3)
    val(v4)
    val(v5)
    val(v6)
    val(v7)

    output:
    tuple val(v1), val(v2), val(v3), val(v4), val(v5), val(v6), val(v7)

    exec:
    // nothing to do
}

process cp_file {
    container { params.exm_synapse_container }

    input:
    val(input_f)
    val(output_arg)

    output:
    tuple val(input_f), val(output_f)

    script:
    if (output_arg) {
        output_f = output_arg
        def output_dir = file(output_f).parent
        """
        mkdir -p ${output_dir}
        cp ${input_f} ${output_f}
        """
    } else {
        output_f = input_f
        """
        """
    }
}

process duplicate_h5_volume {
    container { params.exm_synapse_container }

    input:
    val(in_fn)
    val(volume)
    val(out_fn_arg)

    output:
    tuple val(in_fn), val(out_fn)

    script:
    if (out_fn_arg) {
        out_fn = out_fn_arg        
        def width = volume.width
        def height = volume.height
        def depth = volume.depth
        def out_dir = file(out_fn).parent

        def args_list = [
            '-f',
            out_fn,
            '-s',
            "${depth},${width},${height}",
        ]
        def args = args_list.join(' ')
        """
        mkdir -p ${out_dir}
        python /scripts/create_h5.py ${args}
        """
    } else {
        out_fn = in_fn
        """
        """
    }
}