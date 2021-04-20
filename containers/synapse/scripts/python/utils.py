import numpy as np
import h5py
import skimage.io
import time
import os
import random
import sys

from filelock import FileLock


def tif_read(file_name):
    """
    read tif image in (rows,cols,slices) shape
    """
    im = skimage.io.imread(file_name)
    im_array = np.zeros((im.shape[1], im.shape[2], im.shape[0]),
                        dtype=im.dtype)
    for i in range(im.shape[0]):
        im_array[:, :, i] = im[i]
    return im_array


def tif_write(im_array, file_name):
    """
    write an array with (rows,cols,slices) shape into a tif image
    """
    im = np.zeros((im_array.shape[2], im_array.shape[0], im_array.shape[1]),
                  dtype=im_array.dtype)
    for i in range(im_array.shape[2]):
        im[i] = im_array[:, :, i]
    skimage.io.imsave(file_name, im)
    return None


def hdf5_create(file_name, volume_shape):
    with h5py.File(file_name, 'w') as f:
        dset = f.create_dataset(
            'volume', shape=volume_shape, chunks=(100, 100, 100))


def hdf5_read(file_name, location):
    """
    read part of the hdf5 image in (rows,cols,slices) shape
    Args:
    file_name: hdf5 file name
    location: a tuple of (min_row, min_col, min_vol, max_row, max_col, max_vol) indicating what area to read
    """
    print('Read ', file_name, ' subvolume ', location)
    read_img = True
    retry = 0
    while read_img and retry < 10:
        retry = retry + 1
        try:
            lock = FileLock(file_name + '.lock')
            with lock.acquire(timeout=180):
                with h5py.File(file_name, 'r') as f:
                    im = f['volume'][location[2]:location[5], location[0]:location[3], location[1]:location[4]]
                read_img = False
        except OSError:  # If other process is accessing the image, wait 5 seconds to try again
            None
        except Timeout:
            print('Lock timeout ', file_name, ' retry ', retry, file=sys.stderr)
        if read_img:
            max_sleep = 10
            time.sleep(random.randint(max_sleep-10, max_sleep))
            if retry % 5 == 0:
                print('Tried to read ', file_name, ' at ', location, retry, ' times', file=sys.stderr)

    if read_img:
        print('Error reading ', file_name, ' subvolume ', location, file=sys.stderr)
        raise ValueError

    im_array = np.zeros((im.shape[1], im.shape[2], im.shape[0]),
                        dtype=im.dtype)
    for i in range(im.shape[0]):
        im_array[:, :, i] = im[i]

    return im_array


def hdf5_write(im_array, file_name, location):
    """
    write an image array into part of the hdf5 image file
    Args:
    im_array: an image array
    file_name: an existing hdf5 file to partly write in
    location: a tuple of (min_row, min_col, min_vol, max_row, max_col, max_vol) indicating what area to write
    """
    assert os.path.exists(file_name), print("ERROR: hdf5 file does not exist!")
    im = np.zeros((im_array.shape[2], im_array.shape[0], im_array.shape[1]),
                  dtype=im_array.dtype)
    for i in range(im_array.shape[2]):
        im[i] = im_array[:, :, i]
    print('Write ', file_name, ' subvolume ', location)
    write_img = True
    retry = 0
    while write_img and retry < 100:
        retry = retry + 1
        try:
            lock = FileLock(file_name + '.lock')
            with lock.acquire(timeout=180):
                with h5py.File(file_name, 'r+') as f:
                    f['volume'][location[2]:location[5], location[0]:location[3], location[1]:location[4]] = im
                write_img = False
        except OSError:  # If other process is accessing the image, wait 5 seconds to try again
            None
        except Timeout:
            print('Lock timeout ', file_name, ' retry ', retry, file=sys.stderr)
        if write_img:
            max_sleep = 10
            time.sleep(random.randint(max_sleep-10, max_sleep))
            if retry % 5 == 0:
                print('Tried to write ', file_name, ' at ', location, retry, ' times', file=sys.stderr)

    if write_img:
        print('Error writing ', file_name, ' subvolume ', location, file=sys.stderr)
        raise ValueError
    return None
