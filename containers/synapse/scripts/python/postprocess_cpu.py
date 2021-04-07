import sys
import getopt
import numpy as np
import watershed
import csv
import os
import time

from skimage.measure import label, regionprops
from utils import hdf5_read, hdf5_write, tif_read, tif_write


def remove_small_piece(out_hdf5_file, img_file_name, location, mask=None, threshold=10, percentage=1.0):
    """
    remove blobs that have less than N voxels
    write final result to output hdf5 file, output a .csv file indicating the location and size of each synapses
    Args:
    out_hdf5_file: output hdf5 file
    img_file_name: tif image file for processing
    mask: mask image
    location: a tuple of (min_row, min_col, min_vol, max_row, max_col, max_vol) indicating img location on the hdf5 file
    threshold: threshold to remove small blobs (default=10)
    percentage: threshold to remove the object if it falls in the mask less than a percentage. If percentage is 1, criteria will be whether the centroid falls within the mask
    """

    print('Removing small blobs from ', img_file_name, ' and save results to ', out_hdf5_file, ' at location ', location)
    img = tif_read(img_file_name)
    img[img != 0] = 1
    label_img = label(img, connectivity=3)
    regionprop_img = regionprops(label_img)
    idx = 0

    out_path = os.path.dirname(out_hdf5_file)
    csv_name = 'stats_r'+str(location[0])+'_'+str(location[3]-1)+'_c'+str(
        location[1])+'_'+str(location[4]-1)+'_v'+str(location[2])+'_'+str(location[5]-1)+'.csv'
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
    print('Write post processed image to ', out_hdf5_file, ' at location ', location)
    hdf5_write(img, out_hdf5_file, location)
    return None


def main(argv):
    """
    Main function
    """
    hdf5_file = None
    location = []
    mask_file = None
    threshold = 400
    percentage = 1.0
    try:
        options, remainder = getopt.getopt(argv, "i:l:m:t:p:", [
                                           "input_file=", "location=", "mask_file=", "threshold=", "percentage="])
    except:
        print("ERROR:", sys.exc_info()[0])
        print("Usage: postprocess_cpu.py -i <input_hdf5_file> -l <location> -m <mask_file> -t <threshold> -p <percentage>")
        sys.exit(1)

    # Get input arguments
    for opt, arg in options:
        if opt in ('-i', '--input_file'):
            hdf5_file = arg
        elif opt in ('-l', '--location'):
            location.append(arg.split(","))
            location = tuple(map(int, location[0]))
        elif opt in ('-m', '--mask_file'):
            mask_file = arg
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

    start = time.time()
    print('#############################')
    out_img_name = img_path+'/r'+str(location[0])+'_'+str(location[3])+'_c'+str(
        location[1])+'_'+str(location[4])+'_v'+str(location[2])+'_'+str(location[5])+'.tif'
    print('Writing tiff image for watershed:', out_img_name)
    tif_write(img, out_img_name)
    watershed.initialize_runtime(['-nojvm', '-nodisplay'])
    ws = watershed.initialize()
    flag = ws.closing_watershed(out_img_name)
    ws.quit()
    remove_small_piece(out_hdf5_file=hdf5_file, img_file_name=out_img_name,
                       location=location, mask=mask, threshold=threshold, percentage=percentage)
    if os.path.exists(out_img_name):
        os.remove(out_img_name)
    end = time.time()
    print("DONE! Running time is {} seconds".format(end-start))


if __name__ == "__main__":
    main(sys.argv[1:])
