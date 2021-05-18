"""
Segment a very large image using multiple workers on Janelia's cluster
11/16/2020
Linus Meienberg
"""

#%% Imports
import os
import sys
import subprocess
import numpy as np
import z5py
import h5py

module_path = 'C:/Users/Linus Meienberg/Google Drive/Janelia/ImageSegmentation/'
sys.path.append(module_path)
sys.path.append(module_path+'3D Unet/')
sys.path.append(module_path+'tools/')

import tilingStrategy, preProcessing

#%% Script variables

############## Input / Output ####################


# path to the input file (h5 or n5 image) where the large image is stored
dataset_path = os.path.abspath('D:/Janelia/UnetTraining/RegionCrops/Q1/Q1.h5')
#'/mnt/d/Janelia/UnetTraining/RegionCrops/Q1/Q1.h5'
#'/nrs/dickson/lillvis/temp/linus/Unet_Evaluation/RegionCrops/Q1.h5'

# path of the input dataset within the file system of the h5 container
input_key = 't0/channel1'
#'/mnt/d/Janelia/UnetTraining/RegionCrops/Q1/Q1.n5'
# use z5py for n5 format
#dataset = z5py.File(dataset_path)
# use h5py for h5 format

# directory for report files
output_directory = "D:/Janelia/testSegmentationMultiWorker/"
#"/mnt/d/Janelia/UnetTraining/test/" 

# Path to the output file where segmented output is written to
output_path = "D:/Janelia/testSegmentationMultiWorker/Q1seg.n5"
#"/mnt/d/Janelia/UnetTraining/test/test.h5"
#"/nrs/dickson/lillvis/temp/linus/GPU_Cluster/20201118_MultiWorkerSegmentation/Q1_mws.h5"
#"/mnt/d/Janelia/UnetTraining/test.h5"

# path of the output dataset within the file system of the h5 container
output_key = "test"

# Infer file types from file extension
input_filetype = os.path.splitext(dataset_path)[1] # should be ".h5" or ".n5" depending on filetype that is read in.
output_filetype = os.path.splitext(output_path)[1] # should be ".h5" or ".n5" depending in filetype that is written out.


############ Job Submission ##############
# The prefix used for naming of parallel segmentation jobs
job_prefix = 'mseg_'

# Size of the subvolumes delegated to each worker. Ideally this is a multiple of the unet output size
# The chunk delegated to each worker should fit the available working memory.
side_length = 132 * 3
chunk_shape = (side_length,side_length,side_length) 

# Whether to write the segmentation result as a binary mask or foreground probabilities (0-1)
binary = False

# The unet requires scaling of the intensities in the input image.
# The scaling factor can be calculated once by sampling random tiles in the input image or individually for each submitted job
precalculateScalingFactor = True
n_tiles = 18 # number of tiles to randomly sample for calculation of the scaling factor

#%% Open input dataset and define tiling
if input_filetype == ".h5":
    dataset = h5py.File(dataset_path, mode='r')
    image = dataset[input_key]

elif input_filetype == ".n5":
    dataset = z5py.File(dataset_path, mode='r',use_zarr_format=False)
    image = dataset[input_key]
else:
    print("filetype " + input_filetype + " is not supported")
    

#%% remember the shape of the image
image_shape = image.shape

tiling = tilingStrategy.RectangularTiling(image_shape, chunk_shape=chunk_shape)
print('Jobs are created based on a tiling of ' + str(tiling.shape) + ', ' + str(len(tiling)) + ' tiles in total.')

if(precalculateScalingFactor):
    # For very large images: Calculate a common scaling factor by randomly subsampling the input image
    def getTile(image, tile):
        return image[tile[0]:tile[1], tile[2]:tile[3], tile[4]:tile[5]]

    indices = np.arange(len(tiling))
    subset = np.random.choice(indices, replace=False, size=n_tiles)
    sf = [] # list of scaling factors obtained for individual tiles
    for index in subset:
        print("Sampling Tile {}".format(index))
        sf.append( preProcessing.calculateScalingFactor(
                      getTile(image, tiling.getTile(index)),
                      output_directory=output_directory,
                      filename='fit'+str(index)))
    mean_sf = np.nanmean(sf)
    print('tile-wise scaling factor' + str(sf))
    print('Precalculated a scaling factor of {} based on {}/{} tiles'.format(mean_sf, n_tiles, len(tiling)))

# Release Resources
dataset.close()


# %% Allocate a dataset for the segmentation output
# Handle allocation of a h5 dataset
if output_filetype == ".h5":
    output_file = h5py.File(output_path, mode='a') # open in append mode

    if(output_key in output_file): # check if output dataset allready exists
        print('overwritting existing dataset')
        del output_file[output_key] # if so delete it
    # allocate integer or float tensor depending on output format
    if(binary):
        output_file.create_dataset(name=output_key, shape=image_shape, dtype=np.uint8)
    else:
        output_file.create_dataset(name=output_key, shape=image_shape, dtype=np.float32)

    output_file.close()
# Handle allocation of a n5 dataset.
if output_filetype == ".n5":
    output_file = z5py.File(output_path, mode='a')
    if(output_key in output_file):
        print("Overwriting exisiting dataset")
        del output_file[output_key]
    
    if(binary):
        output_file.create_dataset(name=output_key,shape=image_shape, dtype=np.uint8)
    else:
        output_file.create_dataset(name=output_key, shape=image_shape, dtype=np.float32)

# %% Dispatch jobs on subvolumes
jobs = []
for i in range(len(tiling)):
    tile = tiling.getTile(i)
    tile = str(tile).replace('(','').replace(')','')
    imshape = str(image_shape).replace('(','').replace(')','')
    # Command line argument to invoke volume segmentation:
    # bsub -J jobname -n 5 -gpu "num=1" -q gpu_rtx -o jobname.log python volumeSegmentation.py -l loc,at,i,o,n,n
    # bsub -J lsegtot -n 5 -gpu "num=1" -q gpu_rtx -o segtot.log python volumeSegmentation.py
    jobname = job_prefix + str(i)
    logfile = jobname + '.log'

    """
    # debug on home desktop
    arglist = ['python','volumeSegmentation.py','-l',tile,'--image_shape',imshape,'--scaling',str(mean_sf)]
    print(str(arglist))
    with open(logfile, mode="w") as f:
        jobs.append(subprocess.Popen(arglist, stdout = f, stderr = f))
        # Debug only (wait until subprocess is finished)
        jobs[-1].wait()
    """
    
    # Construct command line argument for janelia's cluster job submission system
    arglist = ['bsub','-J',jobname,'-n','5','-gpu', '\"num=1\"', '-q', 'gpu_rtx', '-o', logfile, 'python', 'volumeSegmentation.py']
    if(precalculateScalingFactor):
        arglist.extend(['--scaling', str(mean_sf)])
    arglist.extend(['-l', tile])
    arglist.extend(['--image_shape', imshape])
    
    print("created job : " + str(arglist))
    jobs.append(
        subprocess.Popen(arglist)
        )


# %%
