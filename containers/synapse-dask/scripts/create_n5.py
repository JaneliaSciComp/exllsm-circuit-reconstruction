#!/usr/bin/env python

import argparse
import zarr

def create_dataset(output_n5, template_n5, dtype_override):

    subpath = '/s0'
    template = zarr.open(store=zarr.N5Store(template_n5), mode='r')[subpath]

    print("Creating n5 data set with:")
    print("  shape", template.shape)
    print("  chunks", template.chunks)

    out = zarr.open(store=zarr.N5Store(output_n5), mode='a')

    if dtype_override:
        dtype = dtype_override
    else:
        dtype = template.dtype

    out.create_dataset(subpath, shape=template.shape, chunks=template.chunks, dtype=dtype, overwrite=True)


def main():

    parser = argparse.ArgumentParser(description='Create an empty n5 data set')

    parser.add_argument('-o', '--output', dest='output_path', type=str, required=True, \
        help='Path for the n5 to be created')

    parser.add_argument('-t', '--template', dest='template_path', type=str, required=True, \
        help='Path to an existing n5 to use as a template')

    parser.add_argument('--dtype', dest='dtype', type=str, default=None, \
        help='Set the output dtype')

    args = parser.parse_args()
    
    create_dataset(args.output_path, args.template_path, args.dtype)


if __name__ == "__main__":
    main()
