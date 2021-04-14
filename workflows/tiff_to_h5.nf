include {
    extract_tiff_stack_metadata;
    tiff_to_hdf5;
} from '../processes/synapse_detection'

workflow tiff_to_h5_with_metadata {
    take:
    input_data // pair of tiff_stack and h5_file

    main:
    def hdf5_results = tiff_to_hdf5(input_data)
    def metadata = get_tiff_stack_metadata(input_data.map { it[1] })

    def stack_with_metadata = hdf5_results
    | join(metadata) // [ tiff_stack, h5_file, metadata ]

    emit:
    done = stack_with_metadata
}

workflow get_tiff_stack_metadata {
    take:
    tiff_stack_dir

    main:
    stack_with_metadata = extract_tiff_stack_metadata(tiff_stack_dir)
    | map {
        [
            it[0],
            [
                width: it[1] as int,
                height: it[2] as int,
                depth: it[3] as int,
            ],
        ]
    }

    emit:
    stack_with_metadata
}
