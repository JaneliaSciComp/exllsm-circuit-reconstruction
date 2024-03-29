#!/usr/bin/env python

import argparse
import zarr
import numcodecs as codecs

def create_dataset(output_n5, template_n5, compression='same',
                   dtype='same', template_data_set='/s0',
                   target_data_set='/s0', overwrite=True):

    template = zarr.open(store=zarr.N5Store(template_n5), mode='r')[template_data_set]
    out = zarr.open(store=zarr.N5Store(output_n5), mode='a')
        
    if compression == 'raw':
        compressor = None
    elif compression == 'same':
        compressor = template.compressor
    else:
        compressor = codecs.get_codec(dict(id=compression))

    if dtype=='same':
        dtype = template.dtype
        
    print("Using compressor:", compressor or 'raw')

    print("Creating n5 data set with:")
    print(f"  compressor: {compressor}")
    print(f"  shape:      {template.shape}")
    print(f"  chunking:   {template.chunks}")
    print(f"  dtype:      {dtype}")
    print(f"  to path:    {output_n5}{target_data_set}")

    out.create_dataset(target_data_set,
        shape=template.shape,
        chunks=template.chunks,
        dtype=dtype,
        compressor=compressor,
        overwrite=overwrite)


def main():

    parser = argparse.ArgumentParser(description='Create an empty n5 data set')

    parser.add_argument('-o', '--output', dest='output_path',
        type=str, required=True,
        help='Path for the n5 to be created')

    parser.add_argument('--target_data_set', dest='target_data_set',
        type=str, default='/s0',
        help='Target dataset to be created in the output n5 container')

    parser.add_argument('-t', '--template', dest='template_path',
        type=str, required=True,
        help='Path to an existing n5 to use as a template')

    parser.add_argument('--template_data_set', dest='template_data_set',
        type=str, default='/s0',
        help='Source dataset to be replicated')

    parser.add_argument('--dtype', dest='dtype',
        type=str, default='same',
        help='Set the output dtype. Default is the same dtype as the template.')

    parser.add_argument('--compression', dest='compression',
        type=str, default='same',
        help='Set the compression. Valid values any codec id supported by numcodecs including: '+ \
             'raw, lz4, gzip, bz2, blosc. Default is the same compression as the template.')

    args = parser.parse_args()
    
    create_dataset(args.output_path, args.template_path,
                  compression=args.compression,
                  dtype=args.dtype,
                  template_data_set=args.template_data_set,
                  target_data_set=args.target_data_set)


if __name__ == "__main__":
    main()
