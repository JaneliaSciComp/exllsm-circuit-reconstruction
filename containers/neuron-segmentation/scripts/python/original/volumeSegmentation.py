""" 
This script applies a pretrained model file to a large image volume saved in hdf5 or n5 format.
"""

#%% Imports 
import sys, getopt
import random
import numpy as np 
import matplotlib.pyplot as plt 
import tensorflow as tf

import os, sys, time

import tools.tilingStrategy as tilingStrategy
import tools.metrics as netrics
import unet.utilities as utilities
import unet.model as model
import tools.postProcessing as postProcessing
import tools.preProcessing as preProcessing

import h5py
import z5py
from tqdm import tqdm


#%% Script variables

## IMAGE I/O
# Specify the path to the image volume stored as h5 file
#image_path = '/nrs/dickson/lillvis/temp/linus/Unet_Evaluation/RegionCrops/Q1.h5'
image_path = os.path.abspath('/nrs/dickson/lillvis/temp/ExM/P1_pIP10/20200808/images/export_substack_crop.n5')

# Specify the group name of the image channel
image_channel_key = 'c1/s0'

# Specify the file name and the group name under which the segmentation output should be saved (this can also be the input file to which a new dataset is added)
output_directory = "/nrs/scicompsoft/goinac/lillvis/results/test" # directory for report files
output_path = '/nrs/scicompsoft/goinac/lillvis/results/test/Q1seg.n5' # path to the output file 
output_channel_key = 'test'
# Specify wheter to output a binary segmentation mask or an object probability map
binary = False

## Model File 
# Specify the path to the pretrained model file
model_path = '/groups/dickson/home/lillvisj/UNET_neuron/trained_models/neuron4_p2/neuron4_150.h5'


model_input_shape = (220,220,220)
model_output_shape = (132,132,132)
batch_size = 1 # Tune batch size to speed up computation.


# Specify wheter to run the postprocessing function on the segmentation ouput
postprocessing = True

# Infer file types from file extension
input_filetype = os.path.splitext(image_path)[1] # should be ".h5" or ".n5" depending on filetype that is read in.
output_filetype = os.path.splitext(output_path)[1] # should be ".h5" or ".n5" depending in filetype that is written out.


#%% Setup
def gpu_fix():
    # Fix for tensorflow-gpu issues that I found online... (don't ask me what it does)
    gpus = tf.config.experimental.list_physical_devices('GPU')
    if gpus:
        try:
            # Currently, memory growth needs to be the same across GPUs
            for gpu in gpus:
                tf.config.experimental.set_memory_growth(gpu, True)
                logical_gpus = tf.config.experimental.list_logical_devices('GPU')
                print(len(gpus), "Physical GPUs,", len(logical_gpus), "Logical GPUs")
        except RuntimeError as e:
            # Memory growth must be set before GPUs have been initialized
            print(e)

def parallel_hdf5_read(image_path, image_channel_key, location):
    # This code was adapted from Josh's pipeline
    read_img = True
    while read_img:
        try:
            with h5py.File(image_path, 'r') as f:
                im = f[image_channel_key][location[0]:location[1], location[2]:location[3], location[4]:location[5]]
            read_img = False
        except OSError:  # If other process is accessing the image, wait 5 seconds to try again
            time.sleep(random.randint(1,5))
    return im

def parallel_n5_read(image_path, image_channel_key, location):
    read_img = True
    print('!!!!!N5 READ',image_path, image_channel_key, location)
    while read_img:
        try:
            with z5py.File(image_path, 'r') as f:
                im = f[image_channel_key][location[0]:location[1], location[2]:location[3], location[4]:location[5]]
            read_img = False
        except OSError:  # If other process is accessing the image, wait 5 seconds to try again
            time.sleep(random.randint(1,5))
    return im

def parallel_hdf5_write(im, output_path, output_channel_key, location):
    """
    write an image array into part of the hdf5 image file
    Args:
    im: an image array
    output_path: an existing hdf5 file to partly write in
    output_channel_key: the (absolute) name of the output hdf5 dataset in the file
    location: a tuple of (x0,x1,y0,y1,z0,z1) indicating what area to write
    """
    assert os.path.exists(output_path), \
        print("ERROR: hdf5 file does not exist!")        
    write_img = True
    while write_img:
        try:
            with h5py.File(output_path, 'r+') as f:
                f[output_channel_key][location[0]:location[1], location[2]:location[3], location[4]:location[5]] = im
            write_img = False
        except OSError: # If other process is accessing the image, wait 5 seconds to try again
            time.sleep(random.randint(1,5))
    return None

def parallel_n5_write(im, output_path, output_channel_key, location):
    """
    write an image array into part of the hdf5 image file
    Args:
    im: an image array
    output_path: an existing hdf5 file to partly write in
    output_channel_key: the (absolute) name of the output hdf5 dataset in the file
    location: a tuple of (x0,x1,y0,y1,z0,z1) indicating what area to write
    """
    assert os.path.exists(output_path), \
        print("ERROR: hdf5 file does not exist!")        
    write_img = True
    while write_img:
        try:
            with z5py.File(output_path, 'r+') as f:
                f[output_channel_key][location[0]:location[1], location[2]:location[3], location[4]:location[5]] = im
            write_img = False
        except OSError: # If other process is accessing the image, wait 5 seconds to try again
            time.sleep(random.randint(1,5))
    return None

#%% Data Input
def main(argv):

    # Can be commented out on cluster.
    gpu_fix()

    #%% Check if this file has been invoked with command line arguments specifying a subvolume to work on
    work_on_subvolume = False
    location = []
    image_shape = [] # shape of the entire dataset
    scalingFactor = None # Holds a precomputed scaling value if it has allready been calculated
    #%%
    try:
        options, remainder = getopt.getopt(argv, "l:", ["location=","scaling=","image_shape="])
    except Exception as e:
        print("ERROR:", sys.exc_info()[0]) 
        print(e)
        print("Usage: unet_gpu.py -l <location>\nwhere location is specified as x0,x1,y0,y1,z0,z1")
        sys.exit(1)

    # Get input arguments
    for opt, arg in options:
        if opt in ('-l', '--location'):
            location.append(arg.split(","))
            location = tuple(map(int, location[0]))
            assert len(location) == 6, 'There must be 6 coordinates to define a subvolume'
            print("working on subvolume with location : " + str(location))
            work_on_subvolume = True
        if opt in ('--scaling'):
            scalingFactor = float(arg)
            print('Scaling image by precomputed factor of ' + str(scalingFactor))
        if opt in ('--image_shape'):
            image_shape.append(arg.split(","))
            image_shape = tuple(map(int, image_shape[0]))
            assert len(image_shape) == 3, 'There must be 3 coordinates that define image shape'
            print("working on dataset of total shape: " + str(image_shape))

    #%%
    # Load image or image subvolume into working memory
    if(work_on_subvolume):
        # Parse the tiling subvolume from slice to aabb notation
        tiling_subvolume_aabb = np.array((location[0],location[2],location[4],location[1],location[3],location[5])) # x0,x1,y0,y1,z0,z1 -> x0,y0,z0,x1,y1,z1

        # Calculate the shape of the subvolume
        tiling_subvolume_shape = tiling_subvolume_aabb[3:] - tiling_subvolume_aabb[:3] # (x1,y1,z1) - (x0,y0,z0)

        # Create a tiling of the subvolume using absolute coordinates
        print("targeted subvolume for segmentation: " + str(tiling_subvolume_aabb))
        print("targeted subvolume shape: ",tiling_subvolume_shape)
        print("global image shape : " + str(image_shape))
        tiling = tilingStrategy.UnetTiling3D(image_shape, tiling_subvolume_aabb, model_output_shape, model_input_shape )

        # Load the input area required to evaluate the output tiles of the subvolume tiling
        input_volume_aabb = np.array(tiling.getInputVolume()) # aabb of input volume as x0,y0,z0,x1,y1,z1
        print('input_volume_aabb:',input_volume_aabb)

        # clip the aabb if it protrudes from the canvas
        start = [ np.max([0, d]) for d in input_volume_aabb[:3] ] # origo is at (0,0,0)
        stop = [ np.min([image_shape[i], input_volume_aabb[i+3]]) for i in range(3) ] # max extent is image shape
        adjusted_input_volume_aabb = np.array(start + stop)

        print('!!!! START:',start,'!!!STOP',stop)
        print('!!!! ADJUSTED AABB:',adjusted_input_volume_aabb)

        adjusted_input_volume_shape = adjusted_input_volume_aabb[3:] - adjusted_input_volume_aabb[:3]
        adjusted_input_volume_slice = (adjusted_input_volume_aabb[0],adjusted_input_volume_aabb[3],adjusted_input_volume_aabb[1],adjusted_input_volume_aabb[4],adjusted_input_volume_aabb[2],adjusted_input_volume_aabb[5]) # x0,y0,z0,x1,y1,z1 -> x0,x1,y0,y1,z0,z1 (Convert aabb to array slice)
        print('Fetching data from input slice ' + str(adjusted_input_volume_slice))

        if(input_filetype == ".h5"):
            image = parallel_hdf5_read(image_path, image_channel_key, adjusted_input_volume_slice)
        elif(input_filetype == ".n5"):
            image = parallel_n5_read( image_path, image_channel_key, adjusted_input_volume_slice)
        else:
            raise(ValueError("Filetype " + input_filetype + " not supported."))

    # If we want to work on the entire input file.    
    else:
        if(input_filetype == ".h5"):
            print('Opening hdf5 file ' + image_path)
            image_h5 = h5py.File(image_path, mode='r+') # Open h5 file with read / write access
            #print(image_h5.keys()) # Show Groups (Folders) in root Group of the h5 archive
            image = image_h5[image_channel_key] # Open the image dataset
            image = image[...] # Copy content to working memory
            # Close image dataset
            image_h5.close()
        elif(input_filetype == ".n5"):
            print('Opening n5 file ' + image_path)
            image_n5 = z5py.File(image_path, mode='r+') # Open h5 file with read / write access
            print(image_n5.keys()) # Show Groups (Folders) in root Group of the h5 archive
            image = image_n5[image_channel_key] # Open the image dataset
            image = image[...] # Copy content to working memory
            # Close image dataset
            image_n5.close()
        else:
            raise(ValueError("Filetype " + input_filetype + " not supported."))

    #%%
    # Calculate scaling factor from image data if no predefined value was given
    if scalingFactor is None: 
        scalingFactor = preProcessing.calculateScalingFactor(image, output_directory=output_directory, filename='scalingFactor')

    # Apply preprocessing globaly !
    image = preProcessing.scaleImage(image, scalingFactor, output_directory=output_directory, filename='scalingFactor')

    #%% Load Model File
    # Restore the trained model. Specify where keras can find custom objects that were used to build the unet
    unet = tf.keras.models.load_model(model_path, compile=False,
                                    custom_objects={"InputBlock" : model.InputBlock,
                                                        "DownsampleBlock" : model.DownsampleBlock,
                                                        "BottleneckBlock" : model.BottleneckBlock,
                                                        "UpsampleBlock" : model.UpsampleBlock,
                                                        "OutputBlock" : model.OutputBlock})

    print('The unet works with\ninput shape {}\noutput shape {}'.format(unet.input.shape,unet.output.shape))

    #%%
    if(work_on_subvolume):
        # Create an absolute Canvas from the input region (this is the targeted output expanded by adjacent areas that are relevant for segmentation)
        print('!!!! INPUT CANVAS PARAMS:',image_shape, adjusted_input_volume_aabb, image.shape)
        input_canvas = tilingStrategy.AbsoluteCanvas(image_shape, canvas_area = adjusted_input_volume_aabb, image=image)
        # Create an empty absolute Canvas for the targeted output region of the mask
        print('!!!! OUTPUT CANVAS PARAMS:',image_shape, tiling_subvolume_aabb, tiling_subvolume_shape)
        output_canvas = tilingStrategy.AbsoluteCanvas(image_shape, canvas_area=tiling_subvolume_aabb, image=np.zeros(shape=tiling_subvolume_shape))
        # Create the unet tiler instance
        tiler = tilingStrategy.UnetTiler3D(tiling,input_canvas,output_canvas)
    else:
        # Work on the entire input image and assemble a congruent mask
        # Set up a unet tiler for the input image
        # with mask = None, a new array with the same size as the image is allocated by the UnetTiler3D class
        tiler = tilingStrategy.UnetTiler3D.forEntireCongruentData(image,mask=None,output_shape=model_output_shape, input_shape=model_input_shape)


    #%% Perform segmentation
    def preprocess_dataset(x):
        x = tf.expand_dims(x, axis=-1) # The unet expects the input data to have an additional channel axis.
        return x

    predictionset_raw = tf.data.Dataset.from_generator(tiler.getGeneratorFactory(),
        output_types = (tf.float32),
        output_shapes= (tf.TensorShape(model_input_shape)))

    predictionset = predictionset_raw.map(preprocess_dataset).batch(batch_size).prefetch(2)

    #%% 
    # Counter variable over all tiles
    tile = 0 
    progress_bar = tqdm(desc='Tiles processed', total = len(tiler))

    dataset_iterator = iter(predictionset) # create an iterator on the tf dataset

    while tile < len(tiler):
        inp = next(dataset_iterator)
        print('!!!INP:',inp.shape)
        batch = unet.predict(inp) # predict one batch

        print('!!!TILE:',tile)
        # Reduce the channel dimension to binary or pseudoprobability
        if(binary):
            batch = np.argmax(batch, axis=-1)# use argmax on channels 
        else:
            batch = tf.nn.softmax(batch, axis=-1)[...,1] # use softmax on channels and retain object cannel 

        # Write each tile in the batch to it's correct location in the output
        for i in range(batch.shape[0]):
            tiler.writeSlice(tile, batch[i,...])
            tile += 1
        
        progress_bar.update(batch.shape[0])


    # Apply post Processing globaly
    if(postprocessing):
        postProcessing.clean_floodFill(tiler.mask.image, high_confidence_threshold=0.98, low_confidence_threshold=0.2)
        postProcessing.removeSmallObjects(tiler.mask.image, probabilityThreshold = 0.2, size_threshold = 2000)

    #%% Save segmentation result
    # Parallel writing when working on subvolume
    if(work_on_subvolume):
        if(output_filetype == ".h5"):
            parallel_hdf5_write(tiler.mask.image, output_path, output_channel_key, location)
        elif(output_filetype == ".n5"):
            parallel_n5_write(tiler.mask.image, output_path, output_channel_key, location)
        else:
            raise(ValueError("Filetype " + output_filetype + " not supported."))
    
    # Single worker mode
    else:
        if(output_filetype == ".h5"):
            output_h5 = h5py.File(output_path, mode='a') # Open h5 file, create if it does not exist yet
            print('Segmentation Output is written to ' + output_path + '/' + output_channel_key)
            if output_channel_key in output_h5:
                print('overwriting previous data')
                del output_h5[output_channel_key]
                
            if(binary):
                #mask = output_h5.require_dataset(output_channel_key, shape=image.shape , dtype=np.uint8) # Use integer tensor to save memory
                output_h5.create_dataset(output_channel_key, data=tiler.mask.image, dtype=np.uint8)
            else:
                #mask = output_h5.require_dataset(output_channel_key, shape=image.shape, dtype = np.float32)
                output_h5.create_dataset(output_channel_key, data=tiler.mask.image, dtype=np.float32)
            output_h5.close()
        elif(output_filetype == ".n5"):
            output_n5 = z5py.File(output_path, mode='a') # Open h5 file, create if it does not exist yet
            print('Segmentation Output is written to ' + output_path + '/' + output_channel_key)
            if output_channel_key in output_n5:
                print('overwriting previous data')
                del output_n5[output_channel_key]
                
            if(binary):
                output_n5.create_dataset(output_channel_key, data=tiler.mask.image, dtype=np.uint8)
            else:
                output_n5.create_dataset(output_channel_key, data=tiler.mask.image, dtype=np.float32)
            output_n5.close()

# %%
if __name__ == "__main__":
    main(sys.argv[1:])

