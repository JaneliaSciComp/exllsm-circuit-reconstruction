process merge_2_channels {
    executor 'local'

    input:
    val(v1)
    val(v2)

    output:
    tuple val(v1),
          val(v2)

    script:
    // nothing to do
    """
    """
}

process merge_3_channels {
    executor 'local'

    input:
    val(v1)
    val(v2)
    val(v3)

    output:
    tuple val(v1),
          val(v2),
          val(v3)

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
    tuple val(v1),
          val(v2),
          val(v3),
          val(v4)

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
    tuple val(v1),
          val(v2),
          val(v3),
          val(v4),
          val(v5),
          val(v6),
          val(v7)


    script:
    // nothing to do
    """
    """
}
