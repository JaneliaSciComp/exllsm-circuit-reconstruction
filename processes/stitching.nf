include {
    read_json;
} from '../utils/utils'

def get_stitched_data(data_dir, output_dir, datasets, stitching_output) {
    datasets.collect { dataset_name ->
        def dataset_input_dir = "${data_dir}/${dataset_name}"
        def dataset_stitching_dir = get_dataset_stitching_dir(dataset_input_dir, stitching_output)
        def dataset_output_dir = "${output_dir}/${dataset_name}"
        def r = [
            dataset_name,
            dataset_stitching_dir,
            dataset_output_dir,
        ]
        log.debug "Stitched data: $r"
        r
    }
}

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
          val(dataset_stitching_dir),
          val(dataset_output_dir),
          val(dataset_stitching_working_dir)

    script:
    dataset_input_dir = "${input_dir}/${dataset_name}/images"
    dataset_output_dir = "${output_dir}/${dataset_name}"
    dataset_stitching_dir = get_dataset_stitching_dir(dataset_output_dir, stitching_output)
    dataset_stitching_working_dir = working_dir
        ? "${working_dir}/${dataset_name}"
        : "${dataset_stitching_dir}/tmp"
    """
    umask 0002
    mkdir -p "${dataset_stitching_dir}"
    mkdir -p "${dataset_stitching_working_dir}"
    cp "${dataset_input_dir}/ImageList_images.csv" "${dataset_stitching_dir}"
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

def get_dataset_stitching_dir(dataset_output_dir, stitching_output) {
    stitching_output instanceof String && stitching_output
        ? "${dataset_output_dir}/${stitching_output}"
        : dataset_output_dir
}
