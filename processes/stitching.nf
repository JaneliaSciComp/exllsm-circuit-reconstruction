include {
    read_json;
} from '../utils/utils'

process prepare_stitching_data {
    input:
    val(input_dir)
    val(output_dir)
    val(dataset_name)
    val(stitching_output)
    val(working_dir)

    output:
    tuple val(dataset_name),
          val(dataset_input_dir),
          val(stitching_dir),
          val(dataset_output_dir),
          val(stitching_working_dir)

    script:
    dataset_input_dir = "${input_dir}/${dataset_name}/images"
    dataset_output_dir = "${output_dir}/${dataset_name}"
    stitching_dir = stitching_output
        ? "${dataset_output_dir}/${stitching_output}"
        : dataset_output_dir
    stitching_working_dir = working_dir
        ? "${working_dir}/${dataset_name}"
        : "${stitching_dir}/tmp"
    """
    umask 0002
    mkdir -p "${stitching_dir}"
    mkdir -p "${stitching_working_dir}"
    cp "${dataset_input_dir}/ImageList_images.csv" "${stitching_dir}"
    """
}

process get_stitched_volume_meta {
    executor "local"

    input:
    tuple val(dataset),
          val(stitching_dir),
          val(ch),
          val(scale)

    output:
    tuple val(dataset),
          val(stitching_dir),
          val(ch),
          val(scale),
          val(metadata)

    exec:
    try {
        def attr_file = file("${stitching_dir}/export.n5/c${ch}/s${scale}/attributes.json")
        println "!!!!!! ${attr_file}"
        metadata = read_json(attr_file)
    } catch (Throwable e) {
        e.printStackTrace()
        throw e
    }
}