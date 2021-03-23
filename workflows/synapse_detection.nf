
include {
    tiff_to_hdf5;
    synapse_segmentation;
} from '../processes/synapse_detection'

include {
    index_channel;
} from '../utils/utils'

workflow find_synapses {
    take:
    dataset
    input_dir
    output_dir
    working_dir
    metadata

    main:
    def indexed_working_dir = index_channel(working_dir)
    def indexed_metadata = index_channel(metadata)
    def hdf5_results = tiff_to_hdf5(input_dir, working_dir)
    def synapse_seg_inputs = indexed_working_dir
    | join(hdf5_results, by:1)
    | map {
        [
            it[1], // index
            it[0], // working_dir
        ]
    }
    | join(indexed_metadata)
    | flatMap {
        def wd = it[1] // working dir
        def md = it[2] // metadata
        def width = md.dimensions[0]
        def height = md.dimensions[1]
        def depth = md.dimensions[2]
        def ncols = (width % 1000) > 0 ? (width / 1000 + 1) : (width / 1000)
        def nrows =  (height % 1000) > 0 ? (height / 1000 + 1) : (height / 1000)
        def nslices = (depth % 1000) > 0 ? (depth / 1000 + 1) : (depth / 1000)
        [0..nrows-1, 0..ncols-1, 0..nslices-1]
            .combinations()
            .collect {
                def start_row = it[0] * 1000
                def end_row = start_row + 1000
                if (end_row > height) {
                    end_row = height
                }
                def start_col = it[1] * 1000
                def end_col = start_col + 1000
                if (end_col > width) {
                    end_col = width
                }
                def start_slice = it[2] * 1000
                def end_slice = start_slice + 1000
                if (end_slice > depth) {
                    end_slice = depth
                }
                [
                    wd,
                    "${start_row},${start_col},${start_slice},${end_row},${end_col},${end_slice}",
                ]
            }
    }
    def synapse_seg_results = synapse_segmentation(
        synapse_seg_inputs.map { it[0] }
        params.synapse_model,
        synapse_seg_inputs.map { it[1] }
    )

    emit:
    done = synapse_seg_results
}

