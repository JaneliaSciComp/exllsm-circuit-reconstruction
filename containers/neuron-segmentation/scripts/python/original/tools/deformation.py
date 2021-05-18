"""This Module provides methods to perform elastic deformations of images, 3D volumes and associated segmentation masks
"""

#%% Imports 
import numpy as np
import matplotlib.pyplot as plt

# Scipy interpolation and image manipulation 
import scipy.interpolate
import scipy.ndimage

#%% Helper functions to visualize Distortions

# Edge grid lines into an image tensor
def edge_grid(im, grid_size):
    """Returns a 2D image tensor with a black grid overlay.
       Usefull to visualize the distortions introduced in image processing



    Parameters
    ----------
    im : 2D image tensor
        the image that is edged
    grid_size : int     
        the spacing of the grid lines in both directions

    Returns
    -------
    image tensor    
        A copy of the inital image tensor with a grid overlay
    """
    # Copy tensor
    tensor = im.copy() # deep copy of the image tensor
    # Draw grid lines
    for i in range(0, tensor.shape[0], grid_size):
        tensor[i,:,:] = 0
    for j in range(0, tensor.shape[1], grid_size):
        tensor[:,j,:] = 0
    
    return tensor

#%% Elastic Deformation I 

def getCoordinateMappingFromDisplacementField(dx, dy):
    """Generate a coordinate mapping from output to input coordinates given a displacement field

    Parameters
    ----------
    dx, dy
       tensors of the same size as the image tensor in x,y dimensions.
       Holds the x and y component of the displacement vector applied at any position in the image

    Returns
    -------
    callable
        A coordinate mapping (x,y,c) -> (x,y,c) from output to input coordinates
    """
    # Define a callable that maps output coordinates to origin coordinates
    def getOriginCords(coords):
        # coords are assumed to be a coordinate tuple (x,y,c)
        x = coords[0] + dx[coords[0], coords[1]]
        y = coords[1] + dy[coords[0], coords[1]]
        return (x,y,coords[2])

    # return the callable
    return getOriginCords

def displacementGridField2D(image_shape, n_lines = 5, loc = 0, scale = 10):
    """Generate a displacement field that results in an elastic deformation of the input image.
       
       This method implements the approach described in (#TODO cite unet paper)[]
       A coarse grid with the same extent as the image is created.
       For each node in the grid a random displacement vector is sampled from a gaussian distribution
       The displacement at any given point in the output image is interpolated to get a smooth displacement vector field.


    Parameters
    ----------
    image_shape : tuple
        shape of the image tensor
    n_lines : int, optional
        the number of lines in the displacment grid in each direction, by default 5
    loc, scale : float
        center and standard deviation of the normal distribution that is sampled to populate the displacement grid

    dx, dy
       tensors of the same size as the image tensor in x,y dimensions.
       Holds the x and y component of the displacement vector applied at any position in the image
    """    
    ## define grid
    input_shape = image_shape # (x,y,c) shape of input image
    # n_lines = 5 # first and last line coincide with the image border !
    assert n_lines >=4, 'Bicubic interpolation needs at least 4 displacement vectors in each direction.'

    # Set up the coordinates op the displacement grid 
    grid_x, grid_y = np.linspace(0,input_shape[0],n_lines, dtype=np.integer), np.linspace(0,input_shape[1],n_lines, dtype=np.integer)
    #grid_cx, grid_cy = np.meshgrid(grid_x,grid_y) # point n in the mesh has position (grid_cx[n],grid_cy[n])
    mesh_size = (len(grid_x),len(grid_y))

    ## draw displacement vectors on grid
    # draw (dx,dy) ~ N(loc,scale) for every entry in the mesh
    grid_dx = np.random.normal(loc = loc, scale = scale, size = mesh_size) 
    grid_dy = np.random.normal(loc = loc, scale = scale, size = mesh_size) 

    ## calculate pixel wise displacement by bicubic interpolation
    """ 
    RectBivariateSpline(x, y, z)
    Bivariate spline approximation over a rectangular mesh.
    Can be used for both smoothing and interpolating data.

    x,y array_like 1-D arrays of coordinates in strictly ascending order.

    z array_like 2-D array of data with shape (x.size,y.size).
    """
    interpolator_dx = scipy.interpolate.RectBivariateSpline(grid_x, grid_y, grid_dx)
    interpolator_dy = scipy.interpolate.RectBivariateSpline(grid_x, grid_y, grid_dy)

    xx, yy = np.meshgrid(np.arange(input_shape[0]), np.arange(input_shape[1]), indexing='ij')
    dx = interpolator_dx.ev(xx,yy)
    dy = interpolator_dy.ev(xx,yy)

    return dx, dy


#%%
def displacementGridField3D(image_shape, n_lines = 5, loc = 0, scale = 20):
    """Generate a displacement field that results in an elastic deformation of the input image.
       
       This method implements the approach described in (#TODO cite unet paper)[]
       A coarse grid with the same extent as the image is created.
       For each node in the grid a random displacement vector is sampled from a gaussian distribution
       The displacement at any given point in the output image is interpolated to get a smooth displacement vector field.


    Parameters
    ----------
    image_shape : tuple
        shape of the 3D image tensor
    n_lines : int, optional
        the number of lines in the displacment grid in each direction, by default 5
    loc, scale : float
        center and standard deviation of the normal distribution that is sampled to populate the displacement grid

    Returns
    -------
    list
       [dx, dy, dz] three tensors of the same size as the image tensor in x,y,z dimensions.
       Hold the components of the displacement vector applied at any position in the image.
    """    
    ## define grid
    input_shape = image_shape # (x,y,c) shape of input image
    # n_lines = 5 # first and last line coincide with the image border !
    assert n_lines >=2, 'Linear interpolation needs at least two displacement vectors in each direction.'

    # Set up the coordinates of the displacement grid 
    grid_x, grid_y, grid_z = np.linspace(0,input_shape[0],n_lines, dtype=np.integer), np.linspace(0,input_shape[1],n_lines, dtype=np.integer), np.linspace(0,input_shape[2],n_lines, dtype=np.integer)
    grid_xx, grid_yy, grid_zz = np.meshgrid(grid_x,grid_y,grid_z,indexing='ij') # point n in the mesh has position (grid_xx[n],grid_yy[n],grid_zz[n])
    mesh_size = (len(grid_x),len(grid_y),len(grid_z))

    #NOTE the coordinates of the grid lines (grid_x,...) ned to be STRICTLY ascending

    ## draw displacement vectors on grid
    # draw (dx,dy) ~ N(loc,scale) for every entry in the mesh
    grid_dx = np.random.normal(loc = loc, scale = scale, size = mesh_size) 
    grid_dy = np.random.normal(loc = loc, scale = scale, size = mesh_size)
    grid_dz = np.random.normal(loc = loc, scale = scale, size = mesh_size)

    # Use Radial Basis Function Interpolation to get a smooth interpolation in 3D
    # Since this is a computationally expensive task sample an intermediate grid with reduced resolution
    # perform fine grained interpolation with cheaper linear methods

    # Set up the coordinates of the intermediate grid with a spacing of c -> c^3 less dense
    intermediate_x, intermediate_y, intermediate_z = np.linspace(0,input_shape[0],10, dtype=np.integer), np.linspace(0,input_shape[1],10, dtype=np.integer), np.linspace(0,input_shape[2],10, dtype=np.integer)
    intermediate_xx, intermediate_yy, intermediate_zz = np.meshgrid(intermediate_x,intermediate_y,intermediate_z,indexing='ij') # point n in the mesh has position (grid_xx[n],grid_yy[n],grid_zz[n])
    intermediate_size = (len(intermediate_x),len(intermediate_y),len(intermediate_z))

    interp_x = scipy.interpolate.Rbf(grid_xx,grid_yy,grid_zz,grid_dx)
    intermediate_dx = interp_x(intermediate_xx, intermediate_yy, intermediate_zz)
    interp_y = scipy.interpolate.Rbf(grid_xx,grid_yy,grid_zz,grid_dy)
    intermediate_dy = interp_x(intermediate_xx, intermediate_yy, intermediate_zz)
    interp_z = scipy.interpolate.Rbf(grid_xx,grid_yy,grid_zz,grid_dz)
    intermediate_dz = interp_x(intermediate_xx, intermediate_yy, intermediate_zz)

    # Use linear interpolation to upsample to whole image volume
    # get the coordinates of all points in the image volume 
    xx, yy, zz = np.meshgrid(np.arange(input_shape[0]), np.arange(input_shape[1]), np.arange(input_shape[2]), indexing='ij')
    interpolation_coordinates = np.stack((xx,yy,zz), axis=-1)

    ## calculate pixel wise displacement by linear interpolation
    dx = scipy.interpolate.interpn(
            (intermediate_x, intermediate_y, intermediate_z), # The points defining the regular grid in n dimensions.
            intermediate_dx, # The data on the regular grid in n dimensions.
            interpolation_coordinates) # The coordinates to sample the gridded data at
    dy = scipy.interpolate.interpn(
            (intermediate_x, intermediate_y, intermediate_z), # The points defining the regular grid in n dimensions.
            intermediate_dy, # The data on the regular grid in n dimensions.
            interpolation_coordinates) # The coordinates to sample the gridded data at
    dz = scipy.interpolate.interpn(
            (intermediate_x, intermediate_y, intermediate_z), # The points defining the regular grid in n dimensions.
            intermediate_dz, # The data on the regular grid in n dimensions.
            interpolation_coordinates) # The coordinates to sample the gridded data at    

    return (dx, dy, dz)

def displacementGridField3DLinear(image_shape, n_lines = 5, loc = 0, scale = 10):
    """Generate a displacement field that results in an elastic deformation of the input image.
       
       This method implements the approach described in (#TODO cite unet paper)[]
       A coarse grid with the same extent as the image is created.
       For each node in the grid a random displacement vector is sampled from a gaussian distribution
       The displacement at any given point in the output image is interpolated to get a smooth displacement vector field.


    Parameters
    ----------
    image_shape : tuple
        shape of the 3D image tensor
    n_lines : int, optional
        the number of lines in the displacment grid in each direction, by default 5
    loc, scale : float
        center and standard deviation of the normal distribution that is sampled to populate the displacement grid

    Returns
    -------
    list
       [dx, dy, dz] three tensors of the same size as the image tensor in x,y,z dimensions.
       Hold the components of the displacement vector applied at any position in the image.
    """    
    ## define grid
    input_shape = image_shape # (x,y,c) shape of input image
    # n_lines = 5 # first and last line coincide with the image border !
    assert n_lines >=2, 'Linear interpolation needs at least two displacement vectors in each direction.'

    # Set up the coordinates op the displacement grid 
    grid_x, grid_y, grid_z = np.linspace(0,input_shape[0],n_lines, dtype=np.integer), np.linspace(0,input_shape[1],n_lines, dtype=np.integer), np.linspace(0,input_shape[2],n_lines, dtype=np.integer)
    #grid_cx, grid_cy = np.meshgrid(grid_x,grid_y) # point n in the mesh has position (grid_cx[n],grid_cy[n])
    mesh_size = (len(grid_x),len(grid_y),len(grid_z))

    #NOTE the coordinates of the grid lines (grid_x,...) ned to be STRICTLY ascending

    ## draw displacement vectors on grid
    # draw (dx,dy) ~ N(loc,scale) for every entry in the mesh
    grid_dx = np.random.normal(loc = loc, scale = scale, size = mesh_size) 
    grid_dy = np.random.normal(loc = loc, scale = scale, size = mesh_size)
    grid_dz = np.random.normal(loc = loc, scale = scale, size = mesh_size)

    # get the coordinates of all points in the image volume 
    xx, yy, zz = np.meshgrid(np.arange(input_shape[0]), np.arange(input_shape[1]), np.arange(input_shape[2]), indexing='ij')
    interpolation_coordinates = np.stack((xx,yy,zz), axis=-1)

    ## calculate pixel wise displacement by linear interpolation
    dx = scipy.interpolate.interpn(
            (grid_x, grid_y, grid_z), # The points defining the regular grid in n dimensions.
            grid_dx, # The data on the regular grid in n dimensions.
            interpolation_coordinates) # The coordinates to sample the gridded data at
    dy = scipy.interpolate.interpn(
            (grid_x, grid_y, grid_z), # The points defining the regular grid in n dimensions.
            grid_dy, # The data on the regular grid in n dimensions.
            interpolation_coordinates) # The coordinates to sample the gridded data at
    dz = scipy.interpolate.interpn(
            (grid_x, grid_y, grid_z), # The points defining the regular grid in n dimensions.
            grid_dz, # The data on the regular grid in n dimensions.
            interpolation_coordinates) # The coordinates to sample the gridded data at

    return (dx, dy, dz)
#%%
def smoothedRandomField(image_shape, n_dim = 3, alpha=300, sigma=8):
    """Generate a displacement field that results in an elastic deformation of the input image.

    Samples an uniform random distribution over the extent of the input image and smooths the values by applying a gaussian filter.
    the resulting displacement field is added to determine the origin coordinates for each position in the output image
    
    Parameters
    ----------
    image_shape : tuple
        shape of the input image (spatial extent of the image region excluding channel dimension)
    alpha : float
        amplitude of the displacement field
    sigma : float
        standard deviation of the gaussian kernel

    Returns
    -------
    list
       tensors of the same size as the image tensor in x,y dimensions.
       Holds the x and y component of the displacement vector applied at any position in the image
    """
    random_state = np.random.RandomState(None)
    # Local distortion 
    # *tuple unpacks the content of the tuple and passes them as arguments to the function -> collected by *args
    # (random_state.rand(*shape) * 2 - 1) gives a tensor specified by shape filled with univariate random numbers shifted to [-1,1)
    # gaussian filter smooths this array where the std in all direction is specified by sigma (large sigma gives smooth displacement arrays)
    #dx = scipy.ndimage.gaussian_filter((random_state.rand(*image_shape[:2]) * 2 - 1), sigma) * alpha # apply a gaussian filter (smoothing) on a list of displacement values
    #dy = scipy.ndimage.gaussian_filter((random_state.rand(*image_shape[:2]) * 2 - 1), sigma) * alpha
    # sigma => smoothing of displacement vector field
    # alpha => amplitude of displacement vector field
    
    # For each dimension get a tensor with the same shape as the image holding one (scalar) component of the displacement vector
    delta = []
    for dimension in range(n_dim):
        delta.append(scipy.ndimage.gaussian_filter( 
            (random_state.rand(*image_shape[:n_dim])*2-1) # Draw random uniformly distributed values in [-1,1]
            , sigma) * alpha) # smooth them with a gaussian kernel with std sigma and scale the values by alpha
   
    return delta

#%% Method to transform images given a mapping

def mapImage(image, mapping, interpolation_order=1):
    """Perform a gemetric transformation of the input image as given by the mapping.
    
    Parameters
    ----------
    image : image tensor
        input image
    mapping : callable
        mapping: output (x,y,c) -> input (x,y,c)
    interpolation_order : int 
        Order of the spline polynomial used in interpolation of fractionated input coordinates.
        Set order 0 to use nearest neighbour interpolation which preserves integer class labels

    Returns
    -------
    image tensor
        transformed image
    """
    mapped = scipy.ndimage.geometric_transform(image,
                                               mapping, # Provide a callable that maps input to output cords
                                               mode='reflect', # Reflect image at borders to get values outside image domain
                                               order=interpolation_order) # Interpolate fractionated pixel values using biquadratic interpolation
    return mapped

#%% Methods to efficiently transform a collection of images

def applyDisplacementField2D(image, dx, dy, interpolation_order = 1):
    """Transform an image by applying a 2D displacement field of the same dimensions.

    Parameters
    ----------
    image : image tensor
        the input image
    dx, dy : matrix
        matrix that holds the x/y component of the displacement vector for each pixel position
    interpolation_order : int, optional
        the order of the spline used to interpolate fractionated pixel values, by default 1
        set 0 to use nearest neighbour interpolation (e.g. in segmentation masks)

    Returns
    -------
    [type]
        [description]
    """
    shape = image.shape
    xx, yy = np.meshgrid(np.arange(shape[0]), np.arange(shape[1]), indexing='ij') # coordinates (x,y) of all pixels in two lists (x1,x2,...)(y1,y2,...)
    # var = a,b,c assigns a tuple
    # np.reshape(y+dy, (-1, 1)) recasts the output (coord mesh y + y displacement) y coordinates to a onedimensional array (col vector, all lined up in x direction)
    input_coordinates = np.reshape(xx+dx, (-1, 1)), np.reshape(yy+dy, (-1, 1))
    #print(indices[0].shape)

    # Use the x,y mapping relation to map all channels
    output = np.zeros_like(image)
    # after interpolating all values in single file reshape to input dimensions
    for c in range(shape[2]):
        output[:,:,c] =scipy.ndimage.map_coordinates(image[:,:,c], input_coordinates, order=interpolation_order, mode='reflect').reshape(shape[:2])
    
    return output

def applyDisplacementField3D(image, dx, dy, dz, interpolation_order = 1):
    """Transform an image volume by applying a 3D displacement field of the same dimensions.

    Parameters
    ----------
    image : image tensor
        the input image
    dx, dy, dz : 3D tensors
        tensors that holds the x/y/z component of the displacement vector for each pixel position
    interpolation_order : int, optional
        the order of the spline used to interpolate fractionated pixel values, by default 1
        set 0 to use nearest neighbour interpolation (e.g. in segmentation masks)

    Returns
    -------
    [type]
        [description]
    """
    shape = image.shape
    assert len(shape)==4, 'Tensor of rank 4 expected (x,y,z,c)'
    xx, yy, zz = np.meshgrid(np.arange(shape[0]), np.arange(shape[1]), np.arange(shape[2]), indexing='ij') # coordinates (x,y) of all pixels in two lists (x1,x2,...)(y1,y2,...)
    # var = a,b,c assigns a tuple
    # np.reshape(y+dy, (-1, 1)) recasts the output (coord mesh y + y displacement) y coordinates to a onedimensional array (col vector, all lined up in x direction)
    input_coordinates = np.reshape(xx+dx, (-1, 1)), np.reshape(yy+dy, (-1, 1)), np.reshape(zz+dz, (-1,1))
    #print(indices[0].shape)

    # Use the x,y,z mapping relation to map all channels
    output = np.zeros_like(image)
    if len(image.shape)==4: #(x,y,z,c) format
        # after interpolating all values in single file reshape to input dimensions
        for c in range(shape[-1]):
            output[...,c] =scipy.ndimage.map_coordinates(image[...,c], input_coordinates, order=interpolation_order, mode='reflect').reshape(shape[:-1])
    elif len(image.shape)==3: # (x,y,z) format
        output = scipy.ndimage.map_coordinates(image, input_coordinates, order=interpolation_order, mode='reflect' ).reshape(image.shape)
    
    return output