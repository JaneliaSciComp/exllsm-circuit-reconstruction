include {
    extract_tiff_stack_metadata;
    tiff_to_hdf5;
} from '../processes/synapse_detection'

workflow tiff_and_h5_with_metadata {
    take:
    tiff_stack_dir
    h5_file

    main:
     def hdf5_results = tiff_to_hdf5(
        tiff_stack_dir,
        h5_file
    )
    def metadata = get_tiff_stack_metadata(tiff_stack_dir)

    def stack_with_metadata = hdf5_results
    | join(metadata)

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
