""" 
This script calculates the scaling factor of a given volume
"""
import argparse
import numpy as np
import time

from tools.tilingStrategy import UnetTiling3D
from tools.preProcessing import calculateScalingFactor
from n5_utils import read_n5_zyx_image


def main():
    start_time = time.time()

    parser = argparse.ArgumentParser(description='Volume scaling factor')

    parser.add_argument('-i', '--input',
                        dest='image_path', type=str, required=True,
                        help='Path to the input n5')

    parser.add_argument('-d', '--data_set',
                        dest='data_set', type=str, default="/s0",
                        help='Path to input data set (default "/s0")')

    parser.add_argument('-n', '--n_tiles',
                        dest='n_tiles', type=int, required=True,
                        help='Number of tiles used to calculate the mean')

    parser.add_argument('--partition_size',
                        dest='partition_size', type=str,
                        default='200,200,200',
                        metavar='dx,dy,dz',
                        help='Chunk size')

    parser.add_argument('--scaling_plots_dir',
                        dest='scaling_plots_dir', type=str,
                        help='Directory in which to output sccaling plots')

    parser.add_argument('--start',
                        dest='start_coord', type=str,
                        metavar='x1,y1,z1',
                        help='Starting coordinate (x,y,z) of block to process')

    parser.add_argument('--end',
                        dest='end_coord', type=str,
                        metavar='x2,y2,z2',
                        help='Ending coordinate (x,y,z) of block to process')

    args = parser.parse_args()

    zyx_img = read_n5_zyx_image(args.image_path, args.data_set)
    image_shape = (zyx_img.shape[2], zyx_img.shape[1], zyx_img.shape[0])
    print('Read image', args.image_path, args.data_set, 'of size', image_shape)

    partition_size = tuple([int(d) for d in args.partition_size.split(',')])

    if args.start_coord:
        start = tuple([int(d) for d in args.start_coord.split(',')])
    else:
        start = (0,0,0)
    if args.end_coord:
        end = tuple([int(d) for d in args.end_coord.split(',')])
    else:
        end = image_shape

    tiling = UnetTiling3D(image_shape,
                          tiling_subvolume=start+end,
                          input_shape=partition_size,
                          output_shape=partition_size)

    indices = np.arange(len(tiling))
    subset = np.random.choice(indices, replace=False, size=args.n_tiles)

    def get_xyz_tile_from_yzx_image(an_zyx_image, tile):
        print('Get tile block:', tile)
        return an_zyx_image[tile[4]:tile[5], tile[2]:tile[3], tile[0]:tile[1]].transpose(2, 1, 0)

    def get_plot_file(tile):
        if args.scaling_plots_dir is None:
            return None
        else:
            fname = f'{tile[0]}_{tile[2]}_{tile[4]}_expFit.png'
            return args.scaling_plots_dir + '/' + fname

    sfs = []  # list of scaling factors obtained for individual tiles
    ti = 0
    for index in subset:
        ti = ti + 1
        print("Sampling Tile {}: {}".format(ti, index))
        tile = tiling.getInputTile(index)
        t = get_xyz_tile_from_yzx_image(zyx_img, tile)
        sf = calculateScalingFactor(t, get_plot_file(tile))
        if sf != np.nan:
            sfs.append(sf)

    if len(sfs) > 0:
        mean_sf = np.nanmean(sfs)
        print('tile-wise scaling factors', sfs)
        print('Calculated a scaling factor of {} based on {}/{} tiles'.format(mean_sf, args.n_tiles, len(tiling)))
    else:
        print('No scaling factor could be computed for any of the selected tiles')
        print('Calculated a scaling factor of null based on {}/{} tiles'.format(args.n_tiles, len(tiling)))

    print("Completed scaling factor computation in {} seconds".format(time.time()-start_time))


if __name__ == "__main__":
    main()
