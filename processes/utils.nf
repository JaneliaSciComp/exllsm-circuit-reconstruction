process merge_3_channels {
    executor 'local'

    input:
    val(v1)
    val(v2)
    val(v3)

    output:
    tuple val(v1), val(v2), val(v3)

    script:
    // nothing to do
    """
    """
}

process merge_4_channels {
    executor 'local'

    input:
    val(v1)
    val(v2)
    val(v3)
    val(v4)

    output:
    tuple val(v1), val(v2), val(v3), val(v4)

    script:
    // nothing to do
    """
    """
}

process merge_7_channels {
    executor 'local'

    input:
    val(v1)
    val(v2)
    val(v3)
    val(v4)
    val(v5)
    val(v6)
    val(v7)

    output:
    tuple val(v1), val(v2), val(v3), val(v4), val(v5), val(v6), val(v7)

    script:
    // nothing to do
    """
    """
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
    def out_file = file(out_fn_arg)
    def width = volume.width
    def height = volume.height
    def depth = volume.depth
    def out_dir = "${out_file.parent}"
    out_fn = "${out_file}"

    def args_list = [
        '-f',
        out_file,
        '-s',
        "${depth},${width},${height}",
    ]
    def args = args_list.join(' ')
    """
    mkdir -p ${out_dir}
    python /scripts/create_h5.py ${args}
    """
}