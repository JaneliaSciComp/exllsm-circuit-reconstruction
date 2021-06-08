#!/usr/bin/env python

import argparse
import zarr
import numcodecs as codecs

from dask_image.imread import _map_read_frame
from dask.delayed import delayed


def tif_series_to_n5_volume(input_path, output_path, data_set, compressor,
                            subvolume=None,
                            chunk_size=(512, 512, 512),
                            dtype='same',
                            overwrite=True):
    '''
    Convert TIFF slices into an n5 volume with given chunk size. 
    This method processes only one Z chunk at a time, to avoid overwhelming worker memory. 
    '''
    images = read_tiff_stack(input_path+'/*.tif')
    volume = images.rechunk(chunk_size)

    if dtype == 'same':
        dtype = volume.dtype
    else:
        volume = volume.astype(dtype)

    store = zarr.N5Store(output_path)
    num_slices = volume.shape[0]
    chunk_z = chunk_size[2]

    def in_subvol(c, cz):
        if subvolume is None:
            return True
        else:
            return c + cz > subvolume[2] and c < subvolume[5]

    ranges = [(c, c+chunk_z if c+chunk_z < num_slices else num_slices)
              for c in range(0, num_slices, chunk_z) if in_subvol(c, chunk_z)]

    print("Saving volume")
    if subvolume is not None:
        print(f"  subvolume: {subvolume}")
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
        z_slice = slice(r[0], r[1])

        if subvolume is None:
            x_slice = slice(None)
            y_slice = slice(None)
        else:
            x_slice = slice(subvolume[0], subvolume[3])
            y_slice = slice(subvolume[1], subvolume[4])

        regions = (z_slice, y_slice, x_slice)
        slices = volume[regions]
        z = delayed(zarr.Array)(store, path=data_set)
        slices.store(z, regions=regions, lock=False, compute=True)

    print('Saved n5 volume', str(volume.shape), 'to', output_path)


def read_tiff_stack(fname, nframes=1, *, arraytype="numpy"):
    """
    Read image data into a Dask Array.
    Provides a simple, fast mechanism to ingest image data into a
    Dask Array.
    Parameters
    ----------
    fname : str or pathlib.Path
        A glob like string that may match one or multiple filenames.
    nframes : int, optional
        Number of the frames to include in each chunk (default: 1).
    arraytype : str, optional
        Array type for dask chunks. Available options: "numpy", "cupy".
    Returns
    -------
    array : dask.array.Array
        A Dask Array representing the contents of all image files.
    """

    sfname = str(fname)
    if not isinstance(nframes, numbers.Integral):
        raise ValueError("`nframes` must be an integer.")
    if (nframes != -1) and not (nframes > 0):
        raise ValueError("`nframes` must be greater than zero.")

    if arraytype == "numpy":
        arrayfunc = np.asanyarray
    elif arraytype == "cupy":   # pragma: no cover
        import cupy
        arrayfunc = cupy.asanyarray

    with pims.open(sfname) as imgs:
        shape = (len(imgs),) + imgs.frame_shape
        dtype = np.dtype(imgs.pixel_type)

    if nframes == -1:
        nframes = shape[0]

    if nframes > shape[0]:
        warnings.warn(
            "`nframes` larger than number of frames in file."
            " Will truncate to number of frames in file.",
            RuntimeWarning
        )
    elif shape[0] % nframes != 0:
        warnings.warn(
            "`nframes` does not nicely divide number of frames in file."
            " Last chunk will contain the remainder.",
            RuntimeWarning
        )

    def file_index(filename):
        _dirpath, name = os.path.split(filename)
        stem, _ext = os.path.splitext(name)
        try:
            return int(stem)
        except ValueError:
            return filename

    filenames = sorted(glob.glob(sfname), key=file_index)

    # place source filenames into dask array
    if len(filenames) > 1:
        ar = da.from_array(filenames, chunks=(nframes,))
        multiple_files = True
    else:
        ar = da.from_array(filenames * shape[0], chunks=(nframes,))
        multiple_files = False

    # read in data using encoded filenames
    a = ar.map_blocks(
        _map_read_frame,
        chunks=da.core.normalize_chunks(
            (nframes,) + shape[1:], shape),
        multiple_files=multiple_files,
        new_axis=list(range(1, len(shape))),
        arrayfunc=arrayfunc,
        meta=arrayfunc([]).astype(dtype),  # meta overwrites `dtype` argument
    )

    return a


def main():
    parser = argparse.ArgumentParser(
        description='Convert a TIFF series to a chunked n5 volume')

    parser.add_argument('-i', '--input', dest='input_path', type=str, required=True,
                        help='Path to the directory containing the TIFF series')

    parser.add_argument('-o', '--output', dest='output_path', type=str, required=True,
                        help='Path to the n5 directory')

    parser.add_argument('-d', '--data_set', dest='data_set', type=str, default="/s0",
                        help='Path to output data set (default is /s0)')

    parser.add_argument('-c', '--chunk_size', dest='chunk_size', type=str,
                        help='Comma-delimited list describing the chunk size. Default is 512,512,512.', default="512,512,512")

    parser.add_argument('--dtype', dest='dtype', type=str, default='same',
                        help='Set the output dtype. Default is the same dtype as the template.')

    parser.add_argument('--compression', dest='compression', type=str, default='bz2',
                        help='Set the compression. Valid values any codec id supported by numcodecs including: raw, lz4, gzip, bz2, blosc. Default is bz2.')

    parser.add_argument('--distributed', dest='distributed', action='store_true',
                        help='Run with distributed scheduler (default)')
    parser.set_defaults(distributed=False)

    parser.add_argument('--workers', dest='workers', type=int, default=20,
                        help='If --distributed is set, this specifies the number of workers (default 20)')

    parser.add_argument('--subvol', dest='subvolume', type=str,
                        help='Subvolume to be converted')

    parser.add_argument('--dashboard', dest='dashboard', action='store_true',
                        help='Run a web-based dashboard on port 8787')
    parser.set_defaults(dashboard=False)

    args = parser.parse_args()

    if args.subvolume is not None:
        subvolume_tuple = [int(d) for d in args.subvolume.split(',')]
        start = subvolume_tuple[:3]
        dims = subvolume_tuple[3:]
        end = [start[i] + dims[i] for i in range(3)]
        subvolume = tuple(start + end)
    else:
        subvolume = None

    if args.compression == 'raw':
        compressor = None
    else:
        compressor = codecs.get_codec(dict(id=args.compression))

    if args.distributed:
        dashboard_address = None
        if args.dashboard:
            dashboard_address = ":8787"
            print(f"Starting dashboard on {dashboard_address}")

        from dask.distributed import Client
        client = Client(processes=True, n_workers=args.workers,
                        threads_per_worker=1, dashboard_address=dashboard_address)

    else:
        from dask.diagnostics import ProgressBar
        pbar = ProgressBar()
        pbar.register()

    tif_series_to_n5_volume(args.input_path, args.output_path, args.data_set,
                            compressor,
                            subvolume=subvolume,
                            chunk_size=[int(c)
                                        for c in args.chunk_size.split(',')],
                            dtype=args.dtype)


if __name__ == "__main__":
    main()
