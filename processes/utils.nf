process read_file_content {
    label 'small'

    container { params.deconvolution_container }

    input:
    val(f)

    output:
    tuple val(f), stdout

    script:
    """
    if [[ -e ${f} ]]; then
        cat ${f}
    else
        echo "null"
    fi
    """
}

process write_file_content {
    label 'small'

    container { params.deconvolution_container }

    input:
    tuple val(f), val(content)

    output:
    val(f)

    script:
    // the content should be a single line otherwise cat is messed up
    """
    cat > $f <<EOF
    ${content}
    EOF
    """
}
