import sys
import getopt
import numpy as np
import watershed
import matlab
import csv
import os
import time

from skimage.measure import label, regionprops
from utils import hdf5_read, hdf5_write

from _internal.mlarray_utils import _get_strides, _get_mlsize


# BEGIN:
# copied from SO:
# https://stackoverflow.com/questions/10997254/converting-numpy-arrays-to-matlab-and-vice-versa
def _wrapper__init__(self, arr):
    assert arr.dtype == type(self)._numpy_type
    self._python_type = type(arr.dtype.type().item())
    self._is_complex = np.issubdtype(arr.dtype, np.complexfloating)
    self._size = _get_mlsize(arr.shape)
    self._strides = _get_strides(self._size)[:-1]
    self._start = 0

    if self._is_complex:
        self._real = arr.real.ravel(order='F')
        self._imag = arr.imag.ravel(order='F')
    else:
        self._data = arr.ravel(order='F')


_wrappers = {}


def _define_wrapper(matlab_type, numpy_type):
    t = type(matlab_type.__name__, (matlab_type,), dict(
        __init__=_wrapper__init__,
        _numpy_type=numpy_type
    ))
    # this tricks matlab into accepting our new type
    t.__module__ = matlab_type.__module__
    _wrappers[numpy_type] = t


_define_wrapper(matlab.double, np.double)
_define_wrapper(matlab.single, np.single)
_define_wrapper(matlab.uint8, np.uint8)
_define_wrapper(matlab.int8, np.int8)
_define_wrapper(matlab.uint16, np.uint16)
_define_wrapper(matlab.int16, np.int16)
_define_wrapper(matlab.uint32, np.uint32)
_define_wrapper(matlab.int32, np.int32)
_define_wrapper(matlab.uint64, np.uint64)
_define_wrapper(matlab.int64, np.int64)
_define_wrapper(matlab.logical, np.bool_)


def as_matlab(arr):
    try:
        cls = _wrappers[arr.dtype.type]
    except KeyError:
        raise TypeError("Unsupported data type")
    return cls(arr)
# END: SO copy


def remove_small_piece(out_hdf5_file, img, location, mask=None, threshold=10, percentage=1.0):
    """
    remove blobs that have less than N voxels
    write final result to output hdf5 file, output a .csv file indicating the location and size of each synapses
    Args:
    out_hdf5_file: output hdf5 file
    img: image to process
    mask: mask image
    location: a tuple of (min_row, min_col, min_vol, max_row, max_col, max_vol) indicating img location on the hdf5 file
    threshold: threshold to remove small blobs (default=10)
    percentage: threshold to remove the object if it falls in the mask less than a percentage. If percentage is 1, criteria will be whether the centroid falls within the mask
    """

    print('Removing small blobs from source image of size ', img.shape,
          ' and save results to ', out_hdf5_file, ' at location ', location)
    img[img != 0] = 1
    label_img = label(img, connectivity=3)
    regionprop_img = regionprops(label_img)
    idx = 0

    out_path = os.path.dirname(out_hdf5_file)
    out_img_name = os.path.splitext(os.path.split(out_hdf5_file)[1])[0]
    csv_name = out_img_name +\
        '_stats_x'+str(location[0])+'_'+str(location[3]) +\
        '_y'+str(location[1])+'_'+str(location[4]) +\
        '_z'+str(location[2])+'_'+str(location[5]-1) +\
        '.csv'
    csv_filepath = out_path+'/'+csv_name
    print('CSV results file: ', csv_filepath)
    for props in regionprop_img:
        num_voxel = props.area
        curr_obj = np.zeros(img.shape, dtype=img.dtype)
        curr_obj[label_img == props.label] = 1
        center_row, center_col, center_vol = props.centroid

        if mask is not None:
            assert mask.shape == img.shape, "Mask and image shapes do not match!"
        else:
            mask = np.ones(img.shape, dtype=img.dtype)
        curr_obj = curr_obj * mask

        exclude = False
        if num_voxel < threshold:
            exclude = True
        if percentage < 1:
            if np.count_nonzero(curr_obj) < num_voxel*percentage:
                exclude = True
        else:
            if mask[int(center_row), int(center_col), int(center_vol)] == 0:
                exclude = True

        if exclude:
            img[label_img == props.label] = 0
        else:
            if idx == 0:
                print('Write header to CSV file ', csv_filepath)
                with open(csv_filepath, 'w') as csv_file:
                    writer = csv.writer(csv_file,
                                        delimiter=',',
                                        quotechar='"',
                                        quoting=csv.QUOTE_MINIMAL)
                    writer.writerow([' ID ',
                                     ' Num vxl ',
                                     ' centroid ',
                                     ' bbox row ',
                                     ' bbox col ',
                                     ' bbox vol '])
            idx += 1
            min_row, min_col, min_vol, max_row, max_col, max_vol = props.bbox
            bbox_row = (int(min_row+location[0]), int(max_row+location[0]))
            bbox_col = (int(min_col+location[1]), int(max_col+location[1]))
            bbox_vol = (int(min_vol+location[2]), int(max_vol+location[2]))

            center = (int(center_row+location[0]),
                      int(center_col+location[1]),
                      int(center_vol+location[2]))

            csv_row = [str(idx), str(num_voxel), str(center),
                       str(bbox_row), str(bbox_col), str(bbox_vol)]
            with open(csv_filepath, 'a') as csv_file:
                writer = csv.writer(csv_file, delimiter=',',
                                    quotechar='"', quoting=csv.QUOTE_MINIMAL)
                writer.writerow(csv_row)

    img[img != 0] = 255
    print('Write post processed image to ',
          out_hdf5_file, ' at location ', location)
    hdf5_write(img, out_hdf5_file, location)
    return None


def main(argv):
    """
    Main function
    """
    hdf5_file = None
    mask_file = None
    output_hdf5_file = None
    location = []
    threshold = 400
    percentage = 1.0
    try:
        options, remainder = getopt.getopt(argv, "i:l:m:o:t:p:", [
                                           "input_file=", "location=", "mask_file=",
                                           "output_file="
                                           "threshold=", "percentage="])
    except:
        print("ERROR:", sys.exc_info()[0])
        print("Usage: postprocess_cpu.py -i <input_hdf5_file> " +
              "-l <location> -m <mask_file> -o <output_file> " +
              "-t <threshold> -p <percentage>")
        sys.exit(1)

    # Get input arguments
    for opt, arg in options:
        if opt in ('-i', '--input_file'):
            hdf5_file = arg
        elif opt in ('-m', '--mask_file'):
            mask_file = arg
        elif opt in ('-o', '--output_file'):
            output_hdf5_file = arg
        elif opt in ('-l', '--location'):
            location = tuple(map(int, arg.split(',')))
        elif opt in ('-t', '--threshold'):
            threshold = int(arg)
        elif opt in ('-p', '--percentage'):
            percentage = float(arg)

    # Read part of the hdf5 image file based upon location
    if len(location):
        img = hdf5_read(hdf5_file, location)
        img_path = os.path.dirname(hdf5_file)
    else:
        print("ERROR: location need to be provided!")
        sys.exit(1)

    # Read part of the hdf5 mask image based upon location
    if mask_file is not None:
        mask = hdf5_read(mask_file, location)
        # if the mask has all 0s, write out the result directly
        if np.count_nonzero(mask) == 0:
            hdf5_write(mask, hdf5_file, location)
            print("DONE! Location of the mask has all 0s.")
            sys.exit(0)
    else:
        mask = None

    if output_hdf5_file is None:
        output_hdf5_file = hdf5_file

    start = time.time()
    print('#############################')
    out_img_name = os.path.splitext(os.path.split(output_hdf5_file)[1])[0]
    print('Processing image for watershed:', img.shape, out_img_name)
    watershed.initialize_runtime(['-nojvm', '-nodisplay'])
    ws = watershed.initialize()
    matlab_img = as_matlab(img)
    matlab_segmented_img = ws.close_and_watershed_transform(
        matlab_img)
    print('Completed watershed segmentation ', matlab_segmented_img.size)
    segmented_img_data = np.array(matlab_segmented_img._data).reshape(
        matlab_segmented_img.size, order='F')
    print('Segmented image shape: ', segmented_img_data.shape)
    ws.quit()

    remove_small_piece(out_hdf5_file=output_hdf5_file,
                       img=segmented_img_data,
                       location=location,
                       mask=mask,
                       threshold=threshold,
                       percentage=percentage)
    end = time.time()
    print("DONE! Running time is {} seconds".format(end-start))


if __name__ == "__main__":
    main(sys.argv[1:])
