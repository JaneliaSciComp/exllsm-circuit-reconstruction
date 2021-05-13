#!/usr/bin/env python

import sys
import argparse
import csv
import os
import time
import numpy as np
import watershed


from skimage.measure import label, regionprops
import skimage.io
from n5_utils import read_n5_block, write_n5_block


def tif_read(file_name):
    """
    read tif image as (slices, rows, cols) shape
    and returns it as (cols, rows, slices
    so the addressing of the in memory array will be [x, y, z]
    """
    im = skimage.io.imread(file_name)
    im_array = im.transpose(2, 1, 0)
    return im_array


def tif_write(im_array, file_name):
    """
    the input im_array has the shape (cols, rows, slices)
    and it writes it as (slices, rows, cols)
    """
    im = im_array.transpose(2, 1, 0)
    skimage.io.imsave(file_name, im)
    return None


def remove_small_piece(out_path, prefix, img, start, end, mask=None, threshold=10, percentage=1.0, connectivity=3):
    """
    Remove blobs that have less than N voxels.
    Write final result to output hdf5 file, output a .csv file indicating the location and size of each synapses.
    Args:
    out_path: location to write CSV files
    prefix: prefix for CSV filenames
    img: image to operate on in the shape (cols, rows, slices)
    start: (x,y,z) tuple indicating starting corner
    end: (x,y,z) tuple indicating ending corner
    mask: optional mask image
    threshold: threshold to remove small blobs (default=10)
    percentage: threshold to remove the object if it falls in the mask less than a percentage. If percentage is 1, criteria will be whether the centroid falls within the mask
    """

    print('Removing small blobs - initially there are ', np.count_nonzero(img), 'voxels')
    img[img != 0] = 1
    label_img = label(img, connectivity=connectivity)
    regionprop_img = regionprops(label_img)
    idx = 0

    csv_filepath = out_path + '/' + prefix + '_stats' + \
        '_x' + str(start[0]) + '_' + str(end[0]) + \
        '_y' + str(start[1]) + '_' + str(end[1]) + \
        '_z' + str(start[2]) + '_' + str(end[2]) + \
        '.csv'

    for props in regionprop_img:
        num_voxel = props.area
        print('num voxels: ', num_voxel)
        curr_obj = np.zeros(img.shape, dtype=img.dtype)
        curr_obj[label_img == props.label] = 1
        # because the image array has shape (cols, rows, slices)
        # the coord comming from region properties will be
        # in the form (x, y, z) instead of (slice, row, col)
        center_x, center_y, center_z = props.centroid

        if mask is not None:
            assert mask.shape == img.shape, 'Mask and image shapes do not match!'
        else:
            mask = np.ones(img.shape, dtype=img.dtype)

        curr_obj = curr_obj * mask
        num_masked_voxels = np.count_nonzero(curr_obj)
        print('  Non zero after masking: ', num_masked_voxels)

        exclude = False
        if num_voxel < threshold:
            exclude = True
        if percentage < 1:
            if num_masked_voxels < num_voxel*percentage:
                exclude = True
        else:
            if mask[int(center_x), int(center_y), int(center_z)] == 0:
                exclude = True

        if exclude:
            print('  Excluding label', str(props.label), 'at', props.centroid)
            img[label_img == props.label] = 0
        else:
            print('  Including label ', str(props.label), 'at', props.centroid)
            if idx == 0:
                with open(csv_filepath, 'w') as csv_file:
                    print('Writing to', csv_filepath)
                    writer = csv.writer(
                        csv_file, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
                    writer.writerow(
                        [' ID ', ' Num vxl ', ' centroid ', ' bbox x ', ' bbox y ', ' bbox vol '])

            idx += 1
            min_x, min_y, min_z, max_x, max_y, max_z = props.bbox
            bbox_x = (int(min_x+start[0]), int(max_x+start[0]))
            bbox_y = (int(min_y+start[1]), int(max_y+start[1]))
            bbox_z = (int(min_z+start[2]), int(max_z+start[2]))

            center = (int(center_x+start[0]),
                      int(center_y+start[1]),
                      int(center_z+start[2]))

            csv_row = [str(idx), str(num_voxel), str(center),
                       str(bbox_x), str(bbox_y), str(bbox_z)]
            with open(csv_filepath, 'a') as csv_file:
                writer = csv.writer(csv_file, delimiter=',',
                                    quotechar='"', quoting=csv.QUOTE_MINIMAL)
                writer.writerow(csv_row)

    img[img != 0] = 255
    print('Non-zero voxels:', np.count_nonzero(img))
    return img


def main():

    parser = argparse.ArgumentParser(description='Apply U-NET post-processing')

    parser.add_argument('-i', '--input_path', dest='input_path', type=str, required=True,
                        help='Path to the input n5')

    parser.add_argument('--data_set', dest='data_set', type=str, default='/s0',
                        help='Path to data set (default "/s0")')

    parser.add_argument('-o', '--output_path', dest='output_path', type=str, required=True,
                        help='Path to the (already existing) output n5')

    parser.add_argument('--csv_output_path', dest='csv_output_path', type=str, required=False,
                        help='Path to an existing folder where CSV output should be written. Defaults to the parent of --output.')

    parser.add_argument('--start', dest='start_coord', type=str, required=True, metavar='x1,y1,z1',
                        help='Starting coordinate (x,y,z) of block to process')

    parser.add_argument('--end', dest='end_coord', type=str, required=True, metavar='x2,y2,z2',
                        help='Ending coordinate (x,y,z) of block to process')

    parser.add_argument('-m', '--mask', dest='mask_path', type=str, required=True,
                        help='Path to the U-Net model n5')

    parser.add_argument('--mask_data_set', dest='mask_data_set', type=str, default='/s0',
                        help='Path to mask data set (default "/s0")')

    parser.add_argument('-t', '--threshold', dest='threshold', type=int, default=400,
                        help='Threshold to remove small blobs (default 400)')

    parser.add_argument('-p', '--percentage', dest='percentage', type=float, default=1.0,
                        help='threshold to remove the object if it falls in the mask less than a percentage. If percentage is 1, criteria will be whether the centroid falls within the mask.')

    parser.add_argument('-c', '--connectivity', dest='connectivity', type=int, default=3,
                        help='Specify region connectivity')
    parser.add_argument('--keep_ws_tiff', dest='keep_ws_tiff', action='store_true', default=False,
                        help='If true keep the tiffs generated by the watershed')

    args = parser.parse_args()
    start = tuple([int(d) for d in args.start_coord.split(',')])
    end = tuple([int(d) for d in args.end_coord.split(',')])
    out_path = os.path.dirname(args.output_path)

    # Read part of the mask image based upon location
    if args.mask_path is not None:
        print('Read mask', args.mask_path)
        mask = read_n5_block(args.mask_path, args.mask_data_set, start, end)
        # if the mask has all 0s, write out the result directly
        if np.count_nonzero(mask) == 0:
            write_n5_block(args.output_path, args.data_set, start, end, mask)
            print('DONE! Location of the mask has all 0s.')
            sys.exit(0)
    else:
        mask = None

    # Read part of the n5 image file based upon location
    img = read_n5_block(args.input_path, args.data_set, start, end)

    start_time = time.time()
    print('#############################')
    out_img_name = 'closed'

    prefix = os.path.splitext(os.path.split(args.output_path)[1])[0]

    out_img_path = out_path + '/' + prefix + '_' + out_img_name + \
        '_x' + str(start[0]) + '_' + str(end[0]) + \
        '_y' + str(start[1]) + '_' + str(end[1]) + \
        '_z' + str(start[2]) + '_' + str(end[2]) + \
        '.tif'

    print('Writing tiff image for watershed:', out_img_path)
    tif_write(img, out_img_path)

    print('Applying closing/watershed algorithms in MATLAB')
    watershed.initialize_runtime(['-nojvm', '-nodisplay'])
    ws = watershed.initialize()
    ws.closing_watershed(out_img_path)
    elapsed_time = time.time() - start_time
    print(f'Completed watershed segmentation in {elapsed_time:0.4f} seconds')
    ws.quit()

    segmented_img_data = tif_read(out_img_path)
    print('Segmented image shape: ', segmented_img_data.shape)

    csv_out_path = args.csv_output_path or out_path

    print('Removing small pieces (and writing CSV outputs)')
    img = remove_small_piece(csv_out_path,
                             prefix,
                             segmented_img_data,
                             start,
                             end,
                             mask=mask,
                             threshold=args.threshold,
                             percentage=args.percentage,
                             connectivity=args.connectivity)

    write_n5_block(args.output_path, args.data_set, start, end, img)

    if not args.keep_ws_tiff and os.path.exists(out_img_path):
        os.remove(out_img_path)

    elapsed_time = time.time() - start_time
    print(f'DONE! Total running time was {elapsed_time:0.4f} seconds')


if __name__ == '__main__':
    main()
