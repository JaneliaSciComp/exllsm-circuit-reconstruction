""" 
This script calculates the scaling factor of a given volume
"""
import argparse


from tools.tilingStrategy import RectangularTiling
from tools.preProcessing import calculateScalingFactor
from n5_utils import read_n5_image


def main():
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

    parser.add_argument('--chunk_size',
                        dest='chunk_size', type=str,
                        default='200,200,200',
                        metavar='dx,dy,dz',
                        help='Chunk size')

    parser.add_argument('--scaling_plots_dir',
                        dest='scaling_plots_dir', type=str,
                        help='Directory in which to output sccaling plots')

    args = parser.parse_args()

    img = read_n5_image(args.image_path, args.data_set)
    image_shape = img.shape
    print('Read image', args.image_path, args.data_set, 'of size', image_shape)

    chunk_size = tuple([int(d) for d in args.chunk_size.split(',')])

    tiling = RectangularTiling(image_shape, chunk_shape=chunk_size)
    indices = np.arange(len(tiling))
    subset = np.random.choice(indices, replace=False, size=n_tiles)

    def get_tile(image, tile):
        print('Get tile block:', tile)
        return image[tile[0]:tile[1], tile[2]:tile[3], tile[4]:tile[5]]

    def get_plot_file(tile):
        if args.scaling_plots_dir is None:
            return None
        else:
            fname = f'{tile[0]}_{tile[2]}_{tile[4]}_expFit.png'
            return args.scaling_plots_dir + '/' + fname

    sfs = []  # list of scaling factors obtained for individual tiles
    for index in subset:
        print("Sampling Tile {}".format(index))
        t = get_tile(image, index)
        sf = calculateScalingFactor(t, get_plot_file(t))
        if sf != np.nan:
            sfs.append(sf)

    if len(sfs) > 0:
        mean_sf = np.nanmean(sfs)
        print('tile-wise scaling factors', sfs)
        print('Calculated a scaling factor of {} based on {}/{} tiles'.format(mean_sf, n_tiles, len(tiling)))
    else:
        print('No scaling factor could be computed for any of the selected tiles')
        print('Calculated a scaling factor of null based on {}/{} tiles'.format(n_tiles, len(tiling)))


if __name__ == "__main__":
    main()
