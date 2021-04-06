import sys
import getopt
import os
import h5py
import skimage.io


def h5_volume_to_tif_slices(input_h5_file, output_dir):
    '''
    Write hdf5 volume into tif 2D slices
    Args:
    input_h5_file: input hdf5 file name
    output_dir: output directory for tif slices
    '''

    assert os.path.exists(input_h5_file), "Hdf5 file does not exist!!"
    if not os.path.exists(output_dir):
        os.mkdir(output_dir)

    z = 0
    while z >= 0:
        try:
            with h5py.File(input_h5_file, 'r', libver='latest', swmr=True) as f:
                img = f['volume'][z, :, :]
        except ValueError:
            print("Whole volume has been processed!")
            sys.exit(1)

        file_name = output_dir+'/'+str(z)+'.tif'
        skimage.io.imsave(file_name, img)
        z += 1

    return None


def main(argv):

    input_h5_file = None
    output_dir = None

    try:
        options, remainder = getopt.getopt(
            argv, "i:o:", ["input=", "output_dir="])
    except getopt.GetoptError:
        print("ERROR!")
        print("Usage: h5_to_tif.py -i <input_h5_file> -o <output_directory>")
        sys.exit(1)

    for opt, arg in options:
        if opt in ('-i', '--input'):
            input_file = arg
        elif opt in ('-o', '--output_dir'):
            output_dir = arg

    if output_dir is None:
        output_dir = os.path.dirname(os.path.abspath(input_file))

    h5_volume_to_tif_slices(input_file, output_dir)


if __name__ == "__main__":
    main(sys.argv[1:])
