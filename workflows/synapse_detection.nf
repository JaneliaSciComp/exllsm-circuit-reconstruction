
include {
    tiff_to_hdf5;
} from '../processes/synapse_detection'

workflow find_synapses {
    take:
    input_dir
    output_dir
    working_dir

    main:
    def hdf5_results = tiff_to_hdf5(input_dir, working_dir)

    emit:
    done = hdf5_results
}
