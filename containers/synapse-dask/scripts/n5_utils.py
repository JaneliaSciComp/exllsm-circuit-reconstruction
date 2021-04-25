"""
Common utilities for reading n5 formatted data
"""
import zarr

def read_n5_block(path, data_set, start, end):
    """
    Reads and returns an image block from the specified n5 location.
    path: path to the N5 directory
    data_set: path to the data set inside the n5, e.g. "/s0"
    start: tuple x,y,z indicating the starting corner of the data block
    end: tuple (x,y,z) indicating the ending corner of the data block
    """
    n5_path = path+data_set
    img = zarr.open(store=zarr.N5Store(n5_path), mode='r')
    img = img[start[2]:end[2], start[1]:end[1], start[0]:end[0]]
    # zarr loads zyx order
    return img[...].transpose(2, 1, 0)


def write_n5_block(path, data_set, start, end, data):
    """
    Writes the given image block to the specified n5 location.
    path: path to the N5 directory
    data_set: path to the data set inside the n5, e.g. "/s0"
    start: tuple x,y,z indicating the starting corner of the data block
    end: tuple (x,y,z) indicating the ending corner of the data block
    """
    n5_path = path+data_set
    img = zarr.open(store=zarr.N5Store(n5_path), mode='a')
    # zarr writes zyx order
    img = img[...].transpose(2, 1, 0)
    img[start[2]:end[2], start[1]:end[1], start[0]:end[0]] = data
