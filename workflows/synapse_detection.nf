
include {
    synapse_segmentation;
    mask_synapses;
} from '../processes/synapse_detection'

include {
    tiff_and_h5_with_metadata as synapse_tiff_and_h5;
    tiff_and_h5_with_metadata as neuron_tiff_and_h5;
} from './tiff_to_h5'

include {
    index_channel;
} from '../utils/utils'

workflow find_synapses {
    take:
    dataset
    synapse_stack_dir
    neuron_stack_dir
    output_dir
    working_dir

    main:
    def indexed_working_dir = index_channel(working_dir)

    def synapse_data = synapse_tiff_and_h5(
        synapse_stack_dir,
        working_dir.map { "$it//synapse.h5" }
    ) // [ synapse_tiff_stack, synapse_h5_file, synapse_metadata ]

    def synapse_seg_inputs = synapse_data
    | flatMap {
        println "Prepare synapse segmentation inputs for $it"
        partition_volume(it[1], it[2], params.volume_partition_size)
    }

    def synapse_seg_results = synapse_segmentation(
        synapse_seg_inputs.map { it[0] },
        params.synapse_model,
        synapse_seg_inputs.map { it[1] }
    )
    | groupTuple(by: 0) // [ synapse_h5_file, list_of_volume_partitions ]
    | map {
        println "Synapse segmentation results: $it"
        def synapse_h5_file = file(it[0])
        [
            "${synapse_h5_file.parent}", // working_dir
            it[0], // synapse_h5_file
        ]
    }

    def neuron_mask_inputs = neuron_tiff_and_h5(
        neuron_stack_dir,
        working_dir.map { "$it//neuron_mask.h5" }
    ) // [ synapse_tiff_stack, synapse_h5_file, synapse_metadata ]
    | map {
        def neuron_h5_file = file(it[1])
        [
            "${neuron_h5_file.parent}", // working_dir
            it[1], // neuron_h5_file
            it[2], // volume dims
        ]
    }
    | join(synapse_seg_results, by:0)
    | flatMap {
        // [ working_dir, neuron_h5, neuron_vol_dims, synapse_h5 ]
        println it
        def neuron_h5 = it[1]
        def synapse_h5 = it[3]
        def neuron_vol = it[2]
        partition_volume(neuron_h5, neuron_vol, params.volume_partition_size)
            .collect {
                [
                    it[0], // neuron_h5
                    synapse_h5,
                    it[1], // neuron_vol_partition
                ]
            }
    }

    def neuron_masked_synapses = mask_synapses(
        neuron_mask_inputs.map { it[1] }, // synapse image
        neuron_mask_inputs.map { it[0] }, // neuron mask image
        neuron_mask_inputs.map { it[2] }, // neuron vol partition
        params.synapse_mask_threshold,
        params.synapse_mask_percentage
    )
    | groupTuple(by: [0,1])
    | map {
        println "Mask synapse results: $it"
        [
            it[0], // synapse_h5
            it[1], // neuron_h5
        ]
    }

    emit:
    done = neuron_masked_synapses
}

def partition_volume(fn, volume, partition_size) {
    def width = volume.width
    def height = volume.height
    def depth = volume.depth
    def ncols = (width % partition_size) > 0 ? (width / partition_size + 1) : (width / partition_size)
    def nrows =  (height % partition_size) > 0 ? (height / partition_size + 1) : (height / partition_size)
    def nslices = (depth % partition_size) > 0 ? (depth / partition_size + 1) : (depth / partition_size)
    [0..nrows-1, 0..ncols-1, 0..nslices-1]
        .combinations()
        .collect {
            def start_row = it[0] * partition_size
            def end_row = start_row + partition_size
            if (end_row > height) {
                end_row = height
            }
            def start_col = it[1] * partition_size
            def end_col = start_col + partition_size
            if (end_col > width) {
                end_col = width
            }
            def start_slice = it[2] * partition_size
            def end_slice = start_slice + partition_size
            if (end_slice > depth) {
                end_slice = depth
            }
            [
                fn,
                "${start_row},${start_col},${start_slice},${end_row},${end_col},${end_slice}",
            ]
        }
}
