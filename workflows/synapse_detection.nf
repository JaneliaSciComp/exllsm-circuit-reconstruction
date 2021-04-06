
include {
    cp_file;
    hdf5_to_tiff;
    synapse_segmentation;
    mask_synapses;
    mask_synapses as mask_n1_synapses;
    mask_synapses as mask_n2_synapses;
} from '../processes/synapse_detection'

include {
    tiff_to_h5_with_metadata as synapse_tiff_to_h5;
    tiff_to_h5_with_metadata as neuron_tiff_to_h5;
} from './tiff_to_h5'

include {
    index_channel;
} from '../utils/utils'

workflow find_synapses {
    take:
    dataset
    synapse_stack_dir
    neuron1_stack_dir
    neuron2_stack_dir
    output_dir
    working_dir

    main:
    def working_dir = output_dir.map { "${it}/tmp" }
    def indexed_dirs = index_channel(working_dir) | join(index_channel(output_dir))

    def synapse_data = synapse_tiff_to_h5(
        synapse_stack_dir,
        working_dir.map { "$it/synapse.h5" }
    ) // [ synapse_tiff_stack, synapse_h5_file, synapse_metadata ]

    def synapse_seg_inputs = synapse_data
    | flatMap {
        println "Prepare synapse segmentation inputs for $it"
        partition_volume(it[1], it[2], params.volume_partition_size)
    } // [ synapse_h5_file, synapse_vol_partition ]

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
            it[0], // synapse_h5_file
            "${synapse_h5_file.parent}", // synapse_h5_working_dir
            it[1], // list of synapse volume partitions
        ]
    }
    | join(indexed_dirs, by:1) // [ working_dir, synapse_h5_file, synapse_vol_partitions, index, output_dir ]

    def neuron1_data = neuron1_tiff_to_h5(
        neuron1_stack_dir,
        working_dir.map { "$it/neuron1_mask.h5" }
    ) // [ neuron1_tiff_stack, neuron1_h5_file, neuron1_metadata ]

    // copy synapse segmentation for post processing
    def synapse_seg_copy = cp_file (
        synapse_seg_results.map {
            [
                it[1], // synapse_h5_file
                "${it[0]}/synapse_n1.h5",
            ]
        }
    )
    | map {
        def dest_file = file(it[1])
        [
            "${dest_file.parent}", // working_dir
            it[1], // synapse_n1_h5_file for postprocessing
        ]
    }

    def neuron1_mask_inputs = neuron1_data
    | flatMap {
        partition_volume(it[1], it[2], params.volume_partition_size)
    } // [ neuron1_h5_file, neuron1_volume_partition ]
    | map {
        def neuron1_h5_file = file(it[0])
        [
            "${neuron1_h5_file.parent}", // working dir
            it[0], // neuron1_h5_file
            it[1] // neuron1_vol_partition
        ]
    }
    | combine(synapse_seg_copy, by:0) // [ working_dir, neuron1_h5_file, neuron1_vol_partition, synapse_h5_file ]

    def neuron1_masked_synapses = mask_n1_synapses(
        neuron1_mask_inputs.map { it[3] }, // synapse_h5_file
        neuron1_mask_inputs.map { it[1] }, // neuron1_h5_mask_file
        neuron1_mask_inputs.map { it[2] }, // neuron1_vol_partition
        params.synapse_mask_threshold,
        params.synapse_mask_percentage
    )
    | groupTuple(by: [0,1])
    | map {
        println "Neuron1 mask synapse results: $it"
        def masked_n1_synapse_file = file(it[0])
        def 
        [
            it[0], // synapse_n1_h5_file
            "${masked_n1_synapse_file.parent}", // working dir
        ]
    }

    def neuron2_data = neuron2_tiff_to_h5(
        neuron2_stack_dir,
        working_dir.map { "$it/neuron2_mask.h5" }
    ) // [ neuron2_tiff_stack, neuron2_h5_file, neuron2_metadata ]

    // copy synapse masked with neuron1 for masking it next with neuron2 image
    def masked_synapse_n1_copy = cp_file (
        neuron1_masked_synapses.map {
            [
                it[0], // synapse_n1_h5_file
                "${it[0]}/synapse_n1_n2.h5",
            ]
        }
    )
    | map {
        def dest_file = file(it[1])
        [
            "${dest_file.parent}", // working_dir
            it[1], // synapse_n1_n2_h5_file for postprocessing
        ]
    }

    def neuron2_mask_inputs = neuron2_data
    | flatMap {
        partition_volume(it[1], it[2], params.volume_partition_size)
    } // [ neuron2_h5_file, neuron2_volume_partition ]
    | map {
        def neuron2_h5_file = file(it[0])
        [
            "${neuron2_h5_file.parent}", // working dir
            it[0], // neuron2_h5_file
            it[1] // neuron2_vol_partition
        ]
    }
    | combine(masked_synapse_n1_copy, by:0) // [ working_dir, neuron2_h5_file, neuron2_vol_partition, synapse_h5_file ]

    def neuron2_masked_synapses = mask_n2_synapses(
        neuron2_mask_inputs.map { it[3] }, // synapse_h5_file
        neuron2_mask_inputs.map { it[1] }, // neuron2_h5_mask_file
        neuron2_mask_inputs.map { it[2] }, // neuron2_vol_partition
        params.synapse_mask_threshold,
        params.synapse_mask_percentage
    )
    | groupTuple(by: [0,1])
    | map {
        println "Neuron2 mask synapse results: $it"
        def masked_n1_n2_synapse_file = file(it[0])
        def 
        [
            it[0], // synapse_n1_n2_h5_file
            "${masked_n1_n2_synapse_file.parent}", // working dir
        ]
    }
    def masked_synapses = neuron2_masked_synapses

    def convert_masked_synapses_to_tiff_inputs = masked_synapses
    | join(indexed_dirs, by:1)
    | map {
        // [ working_dir, masked_h5_file, index, output_dir ]
        [
            it[1], // masked_h5_file
            it[3], // output_dir
        ]
    }

    def synapses_as_tiff_results = hdf5_to_tiff(
        convert_masked_synapses_to_tiff_inputs.map { it[0] },
        convert_masked_synapses_to_tiff_inputs.map { "${it[1]}/masked_synapses_tiff_results" }
    )

    emit:
    done = synapses_as_tiff_results
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
