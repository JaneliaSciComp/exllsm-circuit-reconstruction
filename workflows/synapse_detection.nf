
include {
    tiff_to_hdf5;
} from '../processes/synapse_detection'

workflow find_synapses {
    take:
    dataset
    input_dir
    output_dir
    working_dir
    metadata

    main:
    def hdf5_result   s = tiff_to_hdf5(input_dir, working_dir)
    def subvols = metadata | flatMap {
        def width = it.dimensions[0]
        def height = it.dimensions[1]
        def depth = it.dimensions[2]
        def ncols = (width % 1000) > 0 ? (width / 1000 + 1) : (width / 1000)
        def nrows =  height % 1000) > 0 ? (height / 1000 + 1) : (height / 1000)
        def nslices = depth % 1000) > 0 ? (depth / 1000 + 1) : (depth / 1000)
        [0..ncols, 0..nrows, 0..nslices].combinations()
    }

    emit:
    done = vols
}
