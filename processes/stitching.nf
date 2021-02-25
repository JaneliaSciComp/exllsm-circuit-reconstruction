process prepare_stitching_data {
    input:
    val(input_dir)
    val(output_dir)
    val(dataset_name)
    val(stitching_output)
    val(working_dir)

    output:
    tuple val(dataset_name), val(dataset_input_dir), val(stitching_dir), val(stitching_working_dir)

    script:
    def input_images_dir = "${input_dir}/${dataset_name}/images"
    dataset_output_dir = "${output_dir}/${dataset_name}"
    stitching_dir = stitching_output
        ? dataset_output_dir
        : "${dataset_output_dir}/${stitching_output}"
    stitching_working_dir = working_dir
        ? "${working_dir}/${dataset_name}"
        : "${stitching_dir}/tmp"
    dataset_input_dir = "${stitching_dir}/images"
    """
    mkdir -p "${stitching_dir}"
    mkdir -p "${stitching_working_dir}"
    ln -s "${input_images_dir}" "${dataset_input_dir}" || true
    """
}
