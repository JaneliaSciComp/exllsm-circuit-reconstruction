#!/usr/bin/env python

import argparse
import zarr
import numcodecs as codecs
import dask_image.imread
from dask.delayed import delayed


def tif_series_to_n5_volume(input_path, output_path, data_set, compressor, \
                            chunk_size=(512,512,512), dtype='same', overwrite=True):
    '''
    Convert TIFF slices into an n5 volume with given chunk size. 
    This method processes only one Z chunk at a time, to avoid overwhelming worker memory. 
    '''
    images = dask_image.imread.imread(input_path+'/*.tif')
    volume = images.rechunk(chunk_size)

    if dtype=='same':
        dtype = volume.dtype
    else:
        volume = volume.astype(dtype)

    store = zarr.N5Store(output_path)
    num_slices = volume.shape[0]
    chunk_z = chunk_size[2]
    ranges = [(c, c+chunk_z if c+chunk_z<num_slices else num_slices) for c in range(0,num_slices,chunk_z)]

    print("Saving volume")
    print(f"  compressor: {compressor}")
    print(f"  shape:      {volume.shape}")
    print(f"  chunking:   {chunk_size}")
    print(f"  dtype:      {dtype}")
    print(f"  to path:    {output_path}{data_set}")

    # Create the array container
    zarr.create(
            shape=volume.shape,
            chunks=chunk_size,
            dtype=dtype,
            compressor=compressor,
            store=store,
            path=data_set,
            overwrite=overwrite
        )

    # Proceed slab-by-slab through Z so that memory is not overwhelmed
    for r in ranges:
        print("Saving slice range", r)
        regions = (slice(r[0], r[1]), slice(None), slice(None))
        slices = volume[regions]
        z = delayed(zarr.Array)(store, path=data_set)
        slices.store(z, regions=regions, lock=False, compute=True)

    print("Saved n5 volume to", output_path)


def main():
    parser = argparse.ArgumentParser(description='Convert a TIFF series to a chunked n5 volume')

    parser.add_argument('-i', '--input', dest='input_path', type=str, required=True, \
        help='Path to the directory containing the TIFF series')

    parser.add_argument('-o', '--output', dest='output_path', type=str, required=True, \
        help='Path to the n5 directory')

    parser.add_argument('-d', '--data_set', dest='data_set', type=str, default="/s0", \
        help='Path to output data set (default is /s0)')

    parser.add_argument('-c', '--chunk_size', dest='chunk_size', type=str, \
        help='Comma-delimited list describing the chunk size. Default is 512,512,512.', default="512,512,512")

    parser.add_argument('--dtype', dest='dtype', type=str, default='same', \
        help='Set the output dtype. Default is the same dtype as the template.')

    parser.add_argument('--compression', dest='compression', type=str, default='bz2', \
        help='Set the compression. Valid values any codec id supported by numcodecs including: raw, lz4, gzip, bz2, blosc. Default is bz2.')

    parser.add_argument('--distributed', dest='distributed', action='store_true', \
        help='Run with distributed scheduler (default)')
    parser.set_defaults(distributed=False)

    parser.add_argument('--workers', dest='workers', type=int, default=20, \
        help='If --distributed is set, this specifies the number of workers (default 20)')

    parser.add_argument('--dashboard', dest='dashboard', action='store_true', \
        help='Run a web-based dashboard on port 8787')
    parser.set_defaults(dashboard=False)

    args = parser.parse_args()

    if args.compression=='raw':
        compressor = None
    else:
        compressor = codecs.get_codec(dict(id=args.compression))

    if args.distributed:
        dashboard_address = None
        if args.dashboard: 
            dashboard_address = ":8787"
            print(f"Starting dashboard on {dashboard_address}")

        from dask.distributed import Client
        client = Client(processes=True, n_workers=args.workers, \
            threads_per_worker=1, dashboard_address=dashboard_address)
        
    else:
        from dask.diagnostics import ProgressBar
        pbar = ProgressBar()
        pbar.register()

    tif_series_to_n5_volume(args.input_path, args.output_path, args.data_set, compressor, \
        chunk_size=[int(c) for c in args.chunk_size.split(',')], dtype=args.dtype)


if __name__ == "__main__":
    main()