import sys
import getopt
import numpy as np
import gc
import time
import os

from utils import hdf5_read, hdf5_write
from tensorflow.keras.models import load_model
from tensorflow.keras import backend as K


def masked_binary_crossentropy(y_true, y_pred):
    mask = K.cast(K.not_equal(y_true, 2), K.floatx())
    score = K.mean(K.binary_crossentropy(y_pred*mask, y_true*mask), axis=-1)
    return score


def masked_accuracy(y_true, y_pred):
    mask = K.cast(K.not_equal(y_true, 2), K.floatx())
    score = K.mean(K.equal(y_true*mask, K.round(y_pred*mask)), axis=-1)
    return score


def masked_error_pos(y_true, y_pred):
    mask = K.cast(K.equal(y_true, 1), K.floatx())
    error = (1-y_pred) * mask
    score = K.sum(error) / K.maximum(K.sum(mask), 1)
    return score


def masked_error_neg(y_true, y_pred):
    mask = K.cast(K.equal(y_true, 0), K.floatx())
    error = y_pred * mask
    score = K.sum(error) / K.maximum(K.sum(mask), 1)
    return score


def unet_classifier(img, model_h5_file, input_sz=(64, 64, 64),
                    step=(24, 24, 24), mask=None):
    """
    Test 3D-Unet on an image data
    args:
    img: image data for testing
    input_sz: U-net input size
    step: number of voxels to move the sliding window in x-,y-,z- direction
    mask: (optional) a mask applied to the img 
    """

    print("Doing prediction using 3D-Unet model ", model_h5_file)
    if mask is not None:
        assert mask.shape == img.shape, "Mask and image shapes do not match!"

    unet_model = load_model(model_h5_file,
                            custom_objects={'masked_binary_crossentropy': masked_binary_crossentropy,
                                            'masked_accuracy': masked_accuracy,
                                            'masked_error_pos': masked_error_pos,
                                            'masked_error_neg': masked_error_neg})

    gap = (int((input_sz[0]-step[0])/2),
           int((input_sz[1]-step[1])/2), int((input_sz[2]-step[2])/2))
    img = np.float32(img)
    img = (img - img.mean()) / img.std()

    # expand the image to deal with edge issue
    new_img = np.zeros((img.shape[0]+gap[0]+input_sz[0],
                        img.shape[1]+gap[1]+input_sz[1],
                        img.shape[2]+gap[2]+input_sz[2]),
                       dtype=img.dtype)
    new_img[gap[0]:new_img.shape[0]-input_sz[0], 
            gap[1]:new_img.shape[1]-input_sz[1],
            gap[2]:new_img.shape[2]-input_sz[2]] = img
    img = new_img
    del new_img
    predict_img = np.zeros(img.shape, dtype=img.dtype)

    for row in range(0, img.shape[0]-input_sz[0], step[0]):
        for col in range(0, img.shape[1]-input_sz[1], step[1]):
            for vol in range(0, img.shape[2]-input_sz[2], step[2]):
                patch_img = np.zeros((1, input_sz[0], input_sz[1], input_sz[2], 1),
                                     dtype=img.dtype)
                patch_img[0, :, :, :, 0] = img[row:row+input_sz[0],
                                               col:col+input_sz[1],
                                               vol:vol+input_sz[2]]
                patch_predict = unet_model.predict(patch_img)
                predict_img[row+gap[0]:row+gap[0]+step[0], col+gap[1]:col+gap[1]+step[1], vol+gap[2]:vol+gap[2]+step[2]] \
                    = patch_predict[0, :, :, :, 0]

    predict_img[predict_img >= 0.5] = 255
    predict_img[predict_img < 0.5] = 0
    predict_img = np.uint8(predict_img)
    predict_img = predict_img[gap[0]:predict_img.shape[0]-input_sz[0], gap[1]                              :predict_img.shape[1]-input_sz[1], gap[2]:predict_img.shape[2]-input_sz[2]]

    if mask is not None:
        mask[mask != 0] = 1
        predict_img = predict_img * mask

    K.clear_session()
    gc.collect()
    print("U-Net DONE!")
    return predict_img


def main(argv):
    """
    Main function
    """
    hdf5_file = None
    model_h5_file = None
    output_hdf5_file = None
    location = []
    try:
        options, remainder = getopt.getopt(
            argv, "i:o:l:m:", ["input_file=", "output_file=", "location=", "model_file="])
    except:
        print("ERROR:", sys.exc_info()[0])
        print("Usage: unet_gpu.py -i <input_hdf5_file> " +
              "-o <output_hdf5_file> -l <location> -m <model_h5_file>")
        sys.exit(1)

    # Get input arguments
    for opt, arg in options:
        if opt in ('-i', '--input_file'):
            hdf5_file = arg
        elif opt in ('-o', '--output_file'):
            output_hdf5_file = arg
        elif opt in ('-l', '--location'):
            location = tuple(map(int, arg.split(',')))
        elif opt in ('-m', '--model_file'):
            model_h5_file = arg

    # Read part of the hdf5 image file based upon location
    if len(location):
        print('Read ', hdf5_file, ' subvolume: ', location)
        img = hdf5_read(hdf5_file, location)
    else:
        print("ERROR: location need to be provided!")
        sys.exit(1)

    if output_hdf5_file is None:
        output_hdf5_file = hdf5_file

    start = time.time()
    print('#############################')
    img = unet_classifier(img, model_h5_file)
    print('write classifier result to ', output_hdf5_file, ' at ', location)
    hdf5_write(img, output_hdf5_file, location)
    end = time.time()
    print("DONE! 3D U-Net running time is {} seconds".format(end-start))


if __name__ == "__main__":
    main(sys.argv[1:])
