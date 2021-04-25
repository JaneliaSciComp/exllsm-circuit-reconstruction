#!/usr/bin/env python

import warnings
import argparse
import zarr
import skimage.io
import dask.array as da


def save_tif(filename, img):
    '''
    Save the given image to a TIFF file
    '''
    with warnings.catch_warnings():
        # Ignore "low contrast image" warnings
        warnings.simplefilter("ignore")
        skimage.io.imsave(filename, img)


def n5_block_to_tif(n5_path, data_set, output_file, start, end, dtype_override=None):
    '''
    Write a block from the given n5 data set to a TIFF file
    '''
    store = zarr.N5Store(n5_path+data_set)
    volume = da.from_zarr(store)
    block = volume[start[2]:end[2],start[1]:end[1],start[0]:end[0]]
    if dtype_override and dtype_override != 'same':
        block = block.astype(dtype_override, casting='safe')
    save_tif(output_file, block)


def n5_volume_to_2d_tif_series(n5_path, data_set, output_dir, dtype_override=None, prefix=''):
    '''
    Write n5 volume into 2D TIFF slices
    '''
    store = zarr.N5Store(n5_path+"/"+data_set)
    volume = da.from_zarr(store)

    def save_file(arr, block_info=None):
        slice_num = block_info[0]["chunk-location"][0]
        slice_img = arr[0]
        filename = "%s/%s%d.tif" % (output_dir, prefix, slice_num)
        if dtype_override and dtype_override != 'same':
            slice_img = slice_img.astype(dtype_override, casting='safe')
        save_tif(filename, slice_img)
        return arr

    new_shape = (1,) + volume.shape[1:]
    print('Rechunking to', new_shape)
    slices = volume.rechunk(new_shape)
    slices.map_blocks(save_file, dtype=slices.dtype).compute() # call function on every block


def main():
    parser = argparse.ArgumentParser(description='Convert a TIFF series to a chunked n5 volume')

    parser.add_argument('-i', '--input', dest='input_path', type=str, required=True, \
        help='Path to the directory containing the n5')

    parser.add_argument('-d', '--data_set', dest='data_set', type=str, default="/s0", \
        help='Path to data set (default "/s0")')

    parser.add_argument('-o', '--output', dest='output_path', type=str, required=True, \
        help='Path to the output TIFF file (if exporting single block) or directory containing TIFF series')

    parser.add_argument('--start', dest='start_coord', type=str, default=None, metavar='x1,y1,z1', \
        help='Starting coordinate (x,y,z)')

    parser.add_argument('--end', dest='end_coord', type=str, default=None, metavar='x2,y2,z2', \
        help='Ending coordinate (x,y,z)')

    parser.add_argument('--dtype', dest='dtype', type=str, default='same', \
        help='Set the output dtype. Use "same" to keep the same dtype as the input. (default=same)')

    args = parser.parse_args()

    from dask.diagnostics import ProgressBar
    pbar = ProgressBar()
    pbar.register()

    if args.start_coord and args.end_coord:
        start = tuple([int(d) for d in args.start_coord.split(',')])
        end = tuple([int(d) for d in args.end_coord.split(',')])
        n5_block_to_tif(args.input_path, args.data_set, args.output_path, start, end, dtype_override=args.dtype)
    else:
        n5_volume_to_2d_tif_series(args.input_path, args.data_set, args.output_path, dtype_override=args.dtype)


if __name__ == "__main__":
    main()