"""This script trains a Unet architecture and saves the trained model to a folder
"""

#%% Input Ouput loctions
#TODO add custom modules to path
module_path = '..\\'
training_dataset_path = 'D:\\Janelia\\test\\testset.h5'
save_dir = 'D:\\Janelia\\UnetTraining\\20210428_ResumeTraining\\'
model_file_name = 'resumed'

# OPTIONAL Resume training from an existing model file
# Ensure that Architecture Parameters are the same as in the pretrained model
# Training parameters can be changed
resume_training = True # switch if training should be resumed
pretrained_model_path = "D:\\Janelia\\UnetTraining\\20210428_ResumeTraining\\initial3.h5" # path to the pretrained model file

#%% Architecture Parameters

initial_filters = 1 # the number of filter maps in the first convolution operation
bottleneckDropoutRate = 0.2
spatialDropout = False
spatialDropoutRate = 0.2

# ATTENTION these parameters are not freely changable -> CNN arithmetics
n_blocks = 2 # the number of Unet downsample/upsample blocks
input_size = (220,220,220) # Input size of the unet. Attention: needs to be compatible with training data library
output_size = (132,132,132) # Ouput size of the unet. This is a function of the input size and network architecture.

# Size of examples in the training library
library_size = (220,220,220)

#%% Training Parameters
test_fraction = 0.2 # fraction of training examples that are set aside in the validation set

affineTransform = True 
elasticDeformation = False
occlusions = False
occlusion_size = 40 # side length of occuled cubes in training examples

n_epochs = 3 # number of epochs to train the model
object_class_weight = 5 # factor by which pixels showing the neuron are multiplied in the loss function
dice_weight = 0.3 # contribution of dice loss (rest is cce)
batch_size = 1

#%% Setup

import os
import sys

import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf

print(os.getcwd())
os.makedirs(save_dir, exist_ok=True) # Ensure that output folder for diagnostics is created

sys.path.append(os.path.abspath(module_path))
sys.path.append(os.path.abspath(module_path+'/3D Unet/'))
sys.path.append(os.path.abspath(module_path+'/tools/'))

import metrics
import model
import utilities
import Dataset3D

# Use external library for data augumentation
import elasticdeform


# Perform dark GPU MAGIK
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

#%% Build data input pipeline
print('loading training dataset')
#load the training dataset
dataset = Dataset3D.Dataset(training_dataset_path, append=False, readonly=True) # The Dataset3D class handles all file level i/o operations
# get a list of all records in the database and shuffle entries
entries = list(dataset.keys())
np.random.shuffle(entries)

# Make a train test split and retrieve a callable -> that produces a generator -> that yields the recods specified by the key list in random order
n_val = np.ceil(test_fraction*len(entries)).astype(np.int)
training = dataset.getGenerator(entries[:-n_val])
test = dataset.getGenerator(entries[-n_val:])

# Instantiate tf Datasets from the generator producing callables, specify the datatype and shape of the generator output
trainingset_raw = tf.data.Dataset.from_generator(training, 
    output_types=(tf.float32, tf.int32),
    output_shapes=(tf.TensorShape(library_size),tf.TensorShape(library_size)))
testset_raw = tf.data.Dataset.from_generator(test, 
    output_types=(tf.float32, tf.int32),
    output_shapes=(tf.TensorShape(library_size),tf.TensorShape(library_size)))

# the dataset is expected to be preprocessed (image normalized, mask binarized)
def preprocess(x,y):
    x = tf.expand_dims(x, axis=-1) # The unet expects the input data to have an additional channel axis.
    y = tf.one_hot(y, depth=2, dtype=tf.int32) # one hot encode to int tensor
    return x, y

def crop_mask(x, y, mask_size= output_size):
    # apply crop after batch dimension is added x and y have (b,x,y,z,c) format while mask size has (x,y,z) format => add offset of 1
    crop = [(y.shape[d+1]-mask_size[d])//2 for d in range(3)]
    #keras implicitly assumes channels last format
    y = tf.keras.layers.Cropping3D(cropping=crop)(y)
    return x, y

def occlude(x,y):
    x,y = utilities.tf_occlude(x, y, occlusion_size = occlusion_size)
    return x,y

def random_elastic_deform(x, y):
    # create a 5x5x5 grid of random displacement vectors
    x,y = elasticdeform.deform_random_grid([x,y], sigma=4, points=(5,5,5),
                                            order=[2,0], mode="reflect", prefilter=False) # use order 0 (nearest neigbour interpolation for mask)
    return x,y

def tf_random_elastic_deform(image: tf.Tensor, mask: tf.Tensor):
    image_shape = image.shape
    mask_shape = mask.shape
    image, mask = tf.numpy_function(random_elastic_deform,
                                    inp=[image,mask],
                                    Tout=(tf.float32,tf.int32))
    image.set_shape(image_shape)
    mask.set_shape(mask_shape)
    return image, mask

#%%
# chain dataset transformations to construct the input pipeline for training

# apply elastic deformations to raw dataset before expanding dimensions
if elasticDeformation:
    #trainingset = trainingset.map(utilities.tf_elastic)
    # set the number of parallel calls to a value suitable for your machine (probably the number of logical processors)
    trainingset = trainingset_raw.map(tf_random_elastic_deform)#, num_parallel_calls=9)
else:
    trainingset = trainingset_raw # just feed raw dataset into subsequent steps
# expand dimensions of image and masl
trainingset = trainingset.map(preprocess)
# apply affine transformations
if affineTransform:
    trainingset = trainingset.map(utilities.tf_affine)

# apply occlusions
if occlusions:
    trainingset = trainingset.map(occlude)

trainingset = trainingset.batch(batch_size).map(crop_mask).prefetch(5)
testset = testset_raw.map(preprocess).batch(batch_size).map(crop_mask).prefetch(5)

#%% Construct model
unet = model.build_unet(input_shape = input_size +(1,),
                        n_blocks=n_blocks,
                        initial_filters=initial_filters,
                        bottleneckDropoutRate=bottleneckDropoutRate,
                        spatialDropout=spatialDropout,
                        spatialDropoutRate=spatialDropoutRate)

# If we want to resume training load the pretrained model file instead
if resume_training:
    print("Resuming training from model file at " + pretrained_model_path)
    unet = tf.keras.models.load_model(pretrained_model_path, custom_objects={"InputBlock" : model.InputBlock,
                                                    "DownsampleBlock" : model.DownsampleBlock,
                                                    "BottleneckBlock" : model.BottleneckBlock,
                                                    "UpsampleBlock" : model.UpsampleBlock,
                                                    "OutputBlock" : model.OutputBlock}, compile=False)
#%% Setup Training
unet.compile(
    optimizer = tf.keras.optimizers.Adam(),
    #loss = model.weighted_categorical_crossentropy(class_weights=[1,40]),
    loss = model.weighted_cce_dice_loss(class_weights=[1,object_class_weight], dice_weight=dice_weight),
    metrics = ['acc', metrics.MeanIoU(num_classes=2, name='meanIoU')]
             )
#%% Train
history = unet.fit(trainingset, epochs=n_epochs,
                   validation_data= testset,
                   verbose=1,
                   callbacks=[tf.keras.callbacks.ModelCheckpoint(save_dir+model_file_name+'{epoch}.h5', # Name of checkpoint file
                                                                 #save_best_only=True, # Wheter to save each epoch or only the best model according to a metric
                                                                 #monitor='val_meanIoU', # Which quantity should be used for model selection
                                                                 #mode='max' # We want this metric to be as large as possible
                                                                 ),
                              tf.keras.callbacks.CSVLogger(filename=save_dir+model_file_name+'.log')
                             ],
                   )

 
 #%% Evaluate

## Generate some Plots from training history 
# Plot the evolution of the training loss
plt.figure()
plt.plot(history.history['loss'])
plt.plot(history.history['val_loss'])
plt.legend(['training','validation'])
plt.title('Evolution of training loss')
plt.xlabel('epochs')
plt.ylabel('Spare Categorial Crossentropy')
plt.savefig(save_dir +'loss.png')

#Plot the evolution of pixel wise prediction accuracy
plt.figure()
plt.plot(history.history['acc'])
plt.plot(history.history['val_acc'])
plt.title('Evolution of Accuracy')
plt.xlabel('epoch')
plt.ylabel('categorial accuracy')
plt.legend(['training', 'validation'])
plt.savefig(save_dir+'accuracy.png')

#Plot evolution of mean IoU Metric
plt.figure()
plt.plot(history.history['meanIoU'])
plt.plot(history.history['val_meanIoU'])
plt.title('Evolution of Mean IoU')
plt.xlabel('epoch')
plt.ylabel('mean intersection over union')
plt.legend(['training', 'validation'])
plt.savefig(save_dir+'iou.png')


#%% Save some image mask pairs for visual inspection
if(False):
    import itertools
    import imageio
    tds = iter(trainingset)
    tds_raw = iter(trainingset_raw)
    for i in range(3):
        x,y = next(tds)
        xr, yr = next(tds_raw)
        imageio.volsave(save_dir+"image"+str(i)+".tif", x.numpy()[0,...,0])
        y = y.numpy()[0,...,1] # extract foreground map and pad to original size
        imageio.volsave(save_dir+"mask"+str(i)+".tif", np.pad(y, (44,44)) )
        imageio.volsave(save_dir+"mask_raw"+str(i)+".tif", yr)

    # Generate test image and apply deformation step manualy
    ti, tm = utilities.getTestImage(mask_size=(220,220,220), addAxis=False)
    tid, tmd = random_elastic_deform(ti, tm)
    imageio.volsave(save_dir+"testimage.tif", ti)
    imageio.volsave(save_dir+"testmask.tif", tm)
    imageio.volsave(save_dir+"testimage_deformed.tif", tid)
    imageio.volsave(save_dir+"testmask_deformed.tif",tmd)
# %%
