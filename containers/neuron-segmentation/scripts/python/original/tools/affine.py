""" Affine Transformations of 3D image tensors

This module implements tools for rotation and scaling of 3D imaging data.

Linus Meienberg
June 2020
"""
#%% Imports 

import math
import numpy as np 
from scipy import ndimage
import scipy.spatial.transform


def getRandomRotation()->np.array:
    """Return a uniformly sampled 3D rotation in (3,3) matrix form.
    """
    rot = scipy.spatial.transform.Rotation.random() # Draw a uniformly random rotation
    return rot.as_matrix() # Return the rotation in matrix form

# %%
def constructScalingMatrix(scaling_factor):
    """Constructs the transformation matrix of a uniform scaling operation.

    Parameters
    ----------
    scaling_factor : float
        the scaling factor

    Returns
    -------
    numpy array
        Matrix with shape (3,3) describing the uniform scaling.
    """
    return np.eye(3)*scaling_factor

def getRandomScaling(lb=0.9, ub=1.1):
    # Note that volumetric scaling range is given by [lb**3,ub**3]
    scaling = np.random.uniform(lb,ub)
    return constructScalingMatrix(scaling)

# %%
def getRandomAffine():
    """Construct a random affine transformation by composition of a random rotation and random scaling

    Returns
    -------
    numpy array 
        Matrix with shape (3,3) describing the affine transformation.
    """
    rotation = getRandomRotation()
    scaling = getRandomScaling()
    return np.matmul(rotation,scaling)

def applyAffineTransformation(image, transformation_matrix, interpolation_order = 1):
    """Apply an affine transformation to a multichannel 3D image tensor.
    The coordinate system of the image tensor is shifted to it's center before the transformation matrix is applied.
    Output coordinates that are mapped outside the input image are filled by reflecting the input image.

    Parameters
    ----------
    image : tensor
        3D image tensor with shape (x,y,z,c) where c are the channels or (x,y,z)
    transformation_matrix : matrix
        Matrix with shape (3,3) describing a three dimensional affine transformation.
    interpolation_order : int
        Fractionated pixel coordinates are interpolated by splines of this order. 
        If order 0 is specified, nearest neighbour interpolation is used. Use this setting when transforming masks.

    Returns
    -------
    tensor
        3D image tensor of the same shape as the input image.
    """
    assert len(image.shape)==3 or len(image.shape)==4, 'image must be (x,y,z,c) or (x,y,z)'
    # get inverse transformation. 
    inverse = np.linalg.inv(transformation_matrix)

    # shift the center of the coordinate system to the middle of the volume
    center = [dim//2 for dim in image.shape[:3]] # calculate the image center exclude last dim (channel) if present (X,Y,Z,c) or (x,y,z)
    center_mapping = np.dot(inverse, center) # Calculate where the center of the input region is mapped to 
    center_shift = center-center_mapping # Calculate the shift of the center point => Add this to make the center points of the input and output region congruent
    # apply affine transform to each channel of the image
    out = np.zeros_like(image)
    if len(image.shape)==4: #(x,y,z,c) format
        for channel in range(image.shape[-1]):
            out[...,channel] = ndimage.affine_transform(image[...,channel],
            inverse, offset=center_shift,
            mode='reflect',
            order=interpolation_order)
    elif len(image.shape)==3: #(x,y,z) format
        out = ndimage.affine_transform(image, inverse, offset=center_shift, mode='reflect', order=interpolation_order)
    
    return out



