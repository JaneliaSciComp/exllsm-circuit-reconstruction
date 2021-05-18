"""Collection of utilities to run 3D Unet

CNN arithmetics
Data Input Pipeline

"""

#%% 

import os, pathlib
import random

import tensorflow as tf
from tensorflow import keras

import numpy as np
import scipy

#%% Import modules providing tools for image manipulation
import sys
import tools.deformation as deformation
import tools.affine as affine


def check_size(size, n_blocks):
    """Checks if a valid unet architecture with n blocks can be constructed from an image input 

    Parameters
    ----------
    size : int    
        side length of input volume (cube)
    n_blocks : int
        the number of blocks in the downsampling and upsampling path

    Returns
    -------
    boolean, int
        validity, size of output image (0 if false)
    """
    x = size
    outputs = []

    # Input Block
    x -= 4 # two convolution operations
    outputs.append(x)
    # downsampling
    if not x%2==0: # check if 2x2 max pooling tiles nicely
            #print('Input block: max pool input not divisible by 2')
            return False, 0
    x /= 2

    # downsampling
    for n in range(n_blocks):
        x -= 4 # two conv layers 3x3
        outputs.append(x) # store output dimension
        if not x%2==0: # check if 2x2 max pooling tiles nicely
            #print('Down {} max pool input {} not divisible by 2'.format(n+1,x))
            return False, 0
        x /= 2

    
    # bottleneck block
    x -= 4
    x *= 2

    # upsampling
    for n in range(n_blocks):
        skip = outputs.pop()
        if not (skip-x)%2==0:
            print('Up {} crop from {} to {} not centered'.format(n,skip,x))
            return False, 0
        x -= 4 # two conv layers 3x3
        x *= 2 # upsampling
    
    # output block
    skip = outputs.pop()
    if not (skip-x)%2==0:
        print('Output block: crop from {} to {} not centered'.format(skip,x))
        return False, 0
    x -=4

    #print('image size valid')
    if x>0:
        return True, x
    else:
        return False, 0

#%% Mask conversion tools
def applySoftmax(prediction):
    """Converts an output of logits to pseudo class probabilities using the softmax function

    Parameters
    ----------
    prediction : image tensor
        tensor where the last axis corresponds to different classes. Values are raw class logits.

    Returns
    -------
    image tensor
        tensor where the last axis corresponds to different classes. Values are pseudo probabilities.
    """
    return scipy.special.softmax(prediction, axis= -1)

def segmentationMask(prediction, restoreChannelDim=True):
    """Convert an image tensor with per class logit / probabilities to a segmentation mask using argmax.
    Each pixel holds the integer of the class number with the highest score.    

    Parameters
    ----------
    prediction : image tensor
        tensor where the last axis corresponds to different classes.

    Returns
    -------
    segmentation mask
        tensor with rank reduced by 1, each pixel holds the number of the class with the highest probability
    """
    seg =  np.argmax(prediction, axis = -1)
    if restoreChannelDim:
        seg = np.expand_dims(seg, axis= -1)
    return seg

#%% Load an example image 3d image

def _getImage(path, color_mode = 'grayscale'):
    """Load an image as a numpy array using the keras API

    Parameters
    ----------
    path : String
        path to the image
    color_mode : str, optional
        the color mode used to load the image, by default 'grayscale' which loads a single channel

    Returns
    -------
    tensor
        image tensor of format (x,y,c)
    """
    return keras.preprocessing.image.img_to_array(keras.preprocessing.image.load_img(path, color_mode=color_mode))
#%% Tools for dataset preparation

def load_volume(directory):
    """Load a sclice of the 3D image dataset contained in a directory with the following structure:
    directory
        - image
            - image000
            - image001
            ...
        - mask
            - mask000
            - mask001
            ...
    where the images in each folder are ordered slices of the same 3D volume. 
    Images are assumed to contain a single chanel.

    Parameters
    ----------
    directory : string 
        path to the directory containing the slice of the 3D image

    Returns
    -------
    dict
        'shape' : The shape of the 3D volume
        'image' : Input Image tensor
        'mask'  : Target Image tensor
    """
    # Prepend common base directory
    input_dir = os.path.join(directory, 'image')
    target_dir = os.path.join(directory, 'mask')

    # The following is a multiline python generator expression !
    input_tensor = np.stack(
        [_getImage(os.path.join(input_dir, fname)) for fname in os.listdir(input_dir)]
    )
    target_tensor = np.stack(
        [_getImage(os.path.join(target_dir, fname)) for fname in os.listdir(target_dir)]
    )
    
    assert input_tensor.shape == target_tensor.shape, 'Image and mask need to have the same shape'
    
    output = {}
    output['shape'] = input_tensor.shape
    output['image'] = input_tensor
    output['mask']  = target_tensor

    return output

def tf_elastic(image: tf.Tensor, mask: tf.Tensor):
    image_shape = image.shape
    mask_shape = mask.shape
    image, mask = tf.numpy_function(elasticDeformation, inp=[image,mask], Tout=(tf.float32,tf.int32))
    image.set_shape(image_shape)
    mask.set_shape(mask_shape)
    return image, mask

def tf_affine(image: tf.Tensor, mask: tf.Tensor):
    image_shape = image.shape
    mask_shape = mask.shape
    image, mask = tf.numpy_function(affineTransformation, inp=[image,mask], Tout=(tf.float32,tf.int32))
    image.set_shape(image_shape)
    mask.set_shape(mask_shape)
    return image, mask

#%%
def tf_occlude(image: tf.Tensor, mask: tf.Tensor, occlusion_size = 50):
    """ TF Wrapper for numpy function
    Blanks out a cubic subvolume of the image tensor in each channel and each example in the batch

    Parameters
    ----------
    image : np.ndarray
        image tensor in xyzc format
    mask : np.ndarray
        mask tensor (unaltered)
    occlusion_size : int, optional
        side length of the cubic subvolume, by default 50

    Returns
    -------
    image, mask
        the processed image, mask pair
    """
    image_shape = image.shape
    mask_shape = mask.shape
    image, mask = tf.numpy_function(np_occlude, inp=[image,mask], Tout=(tf.float32,tf.int32))
    image.set_shape(image_shape)
    mask.set_shape(mask_shape)
    return image, mask

def np_occlude(image, mask, occlusion_size = 50):
    """Blanks out a cubic subvolume of the image tensor in each channel and each example in the batch

    Parameters
    ----------
    image : np.ndarray
        image tensor
    mask : np.ndarray
        mask tensor (unaltered)
    occlusion_size : int, optional
        side length of the cubic subvolume, by default 50

    Returns
    -------
    image, mask
        the processed image, mask pair
    """
    image_shape = image.shape
    coords = [np.random.choice(image_shape[n] - occlusion_size) for n in range(0,3)]
    [coords.append(coord + occlusion_size) for coord in coords[:3]]
    image[coords[0]:coords[3],coords[1]:coords[4],coords[2]:coords[5],:] = 0
    return image, mask


#%%
def elasticDeformation(image, mask):
    """Apply the same elastic deformation to an image and it's associated mask

    Parameters
    ----------
    image : tensor
    mask : tensor

    Returns
    -------
    image, mask
        elasticaly deformed tensors
    """
    # We know that the mask region is equal or smaller than the image region
    # Generate a displacement Field for the image region
    displacementField = deformation.displacementGridField3D(image.shape)
    #displacementField = deformation.smoothedRandomField(image.shape, alpha=300, sigma=8)
    # Calculate the crop to extract the mask region from the image region
    #crop = tuple([(image.shape[i]-mask.shape[i])//2 for i in range(len(image.shape))])
    # Extract the part of the displacement field that applies to the mask
    #mask_displacementField = tuple(
    #            [dd[crop[0]:-crop[0] or None,crop[1]:-crop[1] or None, crop[2]:-crop[2] or None] 
    #            for dd in displacementField])
    # apply displacement fields
    image = deformation.applyDisplacementField3D(image, *displacementField, interpolation_order=1)
    #mask = deformation.applyDisplacementField3D(mask, *mask_displacementField, interpolation_order=0)
    mask = deformation.applyDisplacementField3D(mask, *displacementField, interpolation_order=0)
    return image, mask

def affineTransformation(image, mask):
    tm = affine.getRandomAffine()
    image = affine.applyAffineTransformation(image, tm, interpolation_order = 1)
    mask = affine.applyAffineTransformation(mask, tm, interpolation_order=0)
    return image, mask

def augument(image, mask, elasticDeformation=True, affineTransform=False):
    if elasticDeformation:
        image, mask = elasticDeformation(image, mask)
    if affineTransform:
        image, mask = affineTransform(image, mask)
    return image, mask

def generateVariants(images, masks, variants,  elasticDeformation=True, affineTransform=True):
    """Generate a given number of augumentes images from a list of 3D image tensors. Random transformations are reused on each input image befor new ones are drawn.

    Parameters
    ----------
    images : list
        list of 3D image tensors in format (x,y,z,c)
    masks : list 
        list of 3D segmentation masks in format (x,y,z,1)
    variants : int
        the number of augumented image, mask pairs to create
    elasticDeformation : bool, optional
        wheter to apply elastic deformation, by default True
    affineTransform : bool, optional
        wheter to apply random rotation and scaling, by default True

    Returns
    -------
    tuple   
        tuple of lists holding corresponding augumented 3D images and segmentation masks
    """
    # we want to create #variant images from #images originals minimizing the number of 
    image_variants = []
    mask_variants = []
    # Check if new variants are still needed
    while len(image_variants) < variants:
        # Draw new random operations
        if elasticDeformation:
            image_shape = images[0].shape[:-1] # All images have the same dimensions, exclude channel axis
            mask_shape = masks[0].shape[:-1] # get the shape of the segmentation mask
            displacementField = deformation.displacementGridField3D(image_shape=image_shape)

            # Handle case if images and masks are allready precropped, centered volumes of different size
            if not image_shape == mask_shape:
                crop = tuple([(image_shape[i]-mask_shape[i])//2 for i in range(len(image_shape))])
                mask_displacementField = tuple(
                    [d[crop[0]:-crop[0] or None,crop[1]:-crop[1] or None, crop[2]:-crop[2] or None] 
                    for d in displacementField])

        if affineTransform:
            transformationMatrix = affine.getRandomAffine()

        # Apply them to all originals
        for im, mask in zip(images,masks):
            # Process a new image and a mask only as long as we need aditional variants
            if len(image_variants) < variants:
                if elasticDeformation:
                    im = deformation.applyDisplacementField3D(im, *displacementField, interpolation_order = 1)
                    if image_shape == mask_shape:
                        mask = deformation.applyDisplacementField3D(mask, *displacementField, interpolation_order = 0)
                    else:
                        mask = deformation.applyDisplacementField3D(mask, *mask_displacementField, interpolation_order= 0)

                if affineTransform:
                    im = affine.applyAffineTransformation(im, transformationMatrix, interpolation_order = 1)
                    mask = affine.applyAffineTransformation(mask, transformationMatrix, interpolation_order=0)

                image_variants.append(im) # Also updates the length of the list
                mask_variants.append(mask) 

    return image_variants, mask_variants


class Dataset3D(keras.utils.Sequence):

    def  __init__(self, batch_size, batches, mask_crop, images, masks, augument=False, elastic=False, affine=False):
        """Custom keras Sequence to simplify training. Performs on the fly data augumentation if specified.
        The size of the segmentation masks is reduced to fit the output of the unet by a central crop.

        Parameters
        ----------
        batch_size : int
            number of image mask pairs in a batch
        batches : int
            number of batches in the dataset
        mask_crop : int
            number of pixels to crop from each border of the segmentation mask
        images : list
            list of 3D image tensors in format (x,y,z,c)
        masks : list 
            list of 3D segmentation masks in format (x,y,z,1)
        augument : bool, optional
            wheter to augument the images if false the original data is used, by default False
        elastic : bool, optional
            wheter to use elastic deformation, by default False
        affine : bool, optional
            wheter to use random rotation and scaling, by default False
        """
        super().__init__()
        self.batch_size = batch_size
        self.batches = batches
        self.images = images
        self.masks = masks
        self.augument = augument
        self.elastic = elastic
        self.affine = affine
        if not augument:
            assert batch_size<=len(images), 'Allow data augumentation to create variants'
        if augument:
            assert elastic or affine, 'Allow at least one augumentation mechanism to generate variants'
        self.mask_crop = mask_crop
        self.cropper = keras.layers.Cropping3D(cropping=mask_crop) # Symmetric removal of mask crop pixels before and after x,y,z


    def __len__(self):
        return self.batches

    def __getitem__(self, idx):
        # images and masks are allready loaded into memory
        batch_images = []
        batch_masks = []

        # augument images 
        if self.augument:
            batch_images, batch_masks = generateVariants(self.images, self.masks, self.batch_size,
                                                         self.elastic, self.affine)
            
            # shuffle the images and mask pairs in the same order
            new_order = np.arange(self.batch_size) 
            random.shuffle(new_order) # a shuffled list of old indices is created IN PLACE
            batch_images = [batch_images[i] for i in new_order]
            batch_masks = [batch_masks[i] for i in new_order]
        else:
            indices = np.arange(len(self.images))
            random.shuffle(indices)
            indices = indices[:self.batch_size] # take the first batch_size indices (batch_size<=len(images) is guaranteed)
            batch_images = [self.images[i] for i in indices]
            batch_masks = [self.masks[i] for i in indices]
        
        # stack tensor lists to batch tensors
        batch_images = np.stack(batch_images)
        batch_masks = np.stack(batch_masks)

        #NOTE There are values > 1 in the binary mask which is an artifact of the mask creation process
        # clip the mask at 1 to binarize it again
        batch_masks = tf.clip_by_value(batch_masks, 0, 1)

        # crop masks to output region of Unet
        batch_masks = self.cropper(batch_masks).numpy()
        # cast to integer values
        batch_masks = batch_masks.astype(int)
        
        return batch_images, batch_masks


def getTestImage(image_size = (220,220,220), mask_size= (132,132,132), addAxis=True):
    image = np.zeros(image_size, dtype=np.float32)
    # generate a stripe pattern
    #for z in range(0,image_size[0],50):
    #    image[z:z+10,:,:] = np.ones((10,image_size[1],image_size[2]))
    
    # paint axes
    image[:,:50,:50] = 1
    image[:50,:,:50] = 1
    image[:50,:50,:] = 1

    mask = image
    if not image_size == mask_size:
                crop = tuple([(image_size[i]-mask_size[i])//2 for i in range(len(image_size))])
                mask = mask[crop[0]:-crop[0] or None,crop[1]:-crop[1] or None, crop[2]:-crop[2] or None]
    if addAxis:
        return image[...,np.newaxis], mask[...,np.newaxis]
    else:
        return image, mask
# %%
