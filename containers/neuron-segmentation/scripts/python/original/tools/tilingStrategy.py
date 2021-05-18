"""  
This module implements a tiling strategy to apply a 3D Unet to arbitrary input volumes.

Linus Meienberg
June 2020
"""

#%%
import numpy as np
from abc import ABC, abstractmethod # abstract base class and inheritance

#%%
class Tiling(ABC):
    """Base class that defines the interface to be implemented by any Tiling
    #TODO create an inheritance hierarchy for tiler classes and define api
    #TODO make tiler iterable
    """

    @abstractmethod
    def __len__(self):
        pass
    
    @abstractmethod
    def indexToCoordinates(self, i):
        pass
    
    @abstractmethod
    def coordinatesToIndex(self,x,y,z):
        pass

#%%
class RectangularTiling(Tiling):
    """Divides a volume into 0-alinged chunks
    """
    def __init__(self, image_shape : tuple, chunk_shape: tuple):
        assert len(image_shape) == 3
        assert len(chunk_shape) == 3
        self.image_shape = image_shape
        self.chunk_shape = chunk_shape

        # Calculate the coordinate mesh of the tiling
        # Each list goes up to the last multiple of tile_shape smaller than image_shape => endpoint excluded
        self.coords = []
        for d in range(3):
            self.coords.append(list(range(0,self.image_shape[d],self.chunk_shape[d])))

        # Expose the shape of the tiling
        self.shape = [len(d) for d in self.coords]

    def __len__(self):
        return np.prod(self.shape)

    def indexToCoordinates(self, i):
        """Convert a tile index to tiling coordinates

        Parameters
        ----------
        i : int
            tile index

        Returns
        -------
        x,y,z : int
            the coordinates of the tile in the tiling grid
        """     
         # Sanity check
        assert i >=0, 'index out of bounds'
        assert i < len(self), 'index out of bounds'
        # Convert index to the coordinates of the tile
        x = i // (self.shape[1]*self.shape[2]) # number of elements that you skip by moving one position in dim 0
        i = i % (self.shape[1]*self.shape[2])
        y = i // self.shape[2]
        z = i % self.shape[2]
        return x,y,z

    def coordinatesToIndex(self,x,y,z):
        """Converts the coordinates of a tile in the tiling grid to it's index
        """
        assert x < self.shape[0] and x >= 0, 'Coordinates out of bounds'
        assert y < self.shape[1] and y >= 0, 'Coordinates out of bounds'
        assert z < self.shape[2] and z >= 0, 'Coordinates out of bounds'
        i = x*self.shape[1]*self.shape[2]
        i += y*self.shape[2]
        i += z
        return i

    def getTile(self, i):
        """Returns the array slice coordinates for the i-th input tile.
        If a chunk protrudes from the image border, it is truncated.

        Parameters
        ----------
        i : int
            index of the input tile

        Returns
        -------
        tuple
             array slicing coordinates (x0,x1,y0,y1,z0,z1)
        """
        x,y,z = self.indexToCoordinates(i)
        # assemble the coordinates of the target chunk
        x0 = self.coords[0][x]
        y0 = self.coords[1][y]
        z0 = self.coords[2][z]
        x1 = x0 + self.chunk_shape[0]
        y1 = y0 + self.chunk_shape[1]
        z1 = z0 + self.chunk_shape[2]
        x1 = np.min([x1, self.image_shape[0]])
        y1 = np.min([y1, self.image_shape[1]])
        z1 = np.min([z1, self.image_shape[2]])
        return (x0,x1,y0,y1,z0,z1)

    def __getitem__(self, index):
        if index >= len(self):
            raise IndexError
        return self.getTile(index)
    
#%%
class UnetTiling3D(Tiling):
    """
    The input volume is tiled with the output shape of the unet. 
    Each output tile is symmetrically expanded to the input shape to get the corresponding input for the unet.
    The tiles are ennumerated internally and can be accessed either by their coordinates in the rectangular tiling or their index.

    If desired a subvolume can be specified within the image volume. The resulting tiling covers only the subvolume but makes use of image data outside the subvolume if it is available.

    Internally, axis aligned boundary boxes are specified as coordinate tuples of the form (x0,y0,z0,x1,y1,z1) (diagonal oposite corners that define a rectangular volume)
    Coordinates may protrude from the image shape. Use a Canvas class to handle these cases when reading and writing to arrays.
    """

    def __init__(self, image_shape: tuple, tiling_subvolume = None,  output_shape=(132,132,132), input_shape=(220,220,220)):
        """
        Parameters
        ----------
        image_shape : tuple
            the shape of the image volume for which a tiling is calculated
        tiling_subvolume : None or tuple
            the shape of the subvolume that should be tiled. If None is specified the tiling extends over the entire image_shape.
        output_shape : tuple
            shape of the segmentation output of the unet
        input_shape : tuple
            shape of the image input of the unet
        """
        super().__init__()

        self.image_shape = image_shape
        # If the tiling shape is not supplied, assume that the tiling extends over the entire image
        if tiling_subvolume is None:
            self.tiling_subvolume = (0,0,0,) + self.image_shape # The entire image is given by the tuple (0,0,0,x_max,y_max,z_max)
        else:
            self.tiling_subvolume = tiling_subvolume

        # Store output and input shape of the unet and check for correct number of dimensions
        self.output_shape = output_shape
        self.input_shape = input_shape
        assert len(self.image_shape) == 3, 'Specify a single channel 3D image with format (x,y,z)'
        assert len(self.tiling_subvolume) == 6, 'Specify a 3D tiling subvolume as coordinate tuple (x0,y0,z0,x1,y1,z1)'
        assert len(self.output_shape) == 3, 'Specify the extent of the output shape as (x,y,z)'
        assert len(self.input_shape) == 3, 'Specify the extent of the input shape as (x,y,z)'
        assert self.output_shape <= self.input_shape, 'The input shape cannot be smaller than the output shape'
        
        # Calculate the coordinate mesh of the tiling
        # For each axis there are as many tiles as the number of output shapes that fit between the borders of the subvolume
        self.coords = []
        for d in range(3):
            self.coords.append(
                list(range( self.tiling_subvolume[d], # subvolume start point in dimension d
                            self.tiling_subvolume[d+3], # subvolume end point
                            self.output_shape[d] )) # Output shape in this dimension 
            )

        # Expose the shape of the tiling
        self.shape = [len(d) for d in self.coords]

    def __len__(self):
        return np.prod(self.shape)

    def indexToCoordinates(self, i):
        """Convert a tile index to tiling coordinates

        Parameters
        ----------
        i : int
            tile index

        Returns
        -------
        x,y,z : int
            the coordinates of the tile in the tiling grid
        """     
         # Sanity check
        assert i >=0, 'index out of bounds'
        assert i < len(self), 'index out of bounds'
        # Convert index to the coordinates of the tile
        x = i // (self.shape[1]*self.shape[2]) # number of elements that you skip by moving one position in dim 0
        i = i % (self.shape[1]*self.shape[2])
        y = i // self.shape[2]
        z = i % self.shape[2]
        return x,y,z

    def coordinatesToIndex(self,x,y,z):
        """Converts the coordinates of a tile in the tiling grid to it's index
        """
        assert x < self.shape[0] and x >= 0, 'Coordinates out of bounds'
        assert y < self.shape[1] and y >= 0, 'Coordinates out of bounds'
        assert z < self.shape[2] and z >= 0, 'Coordinates out of bounds'
        i = x*self.shape[1]*self.shape[2]
        i += y*self.shape[2]
        i += z
        return i

    def getOutputTile(self, i):
        """Returns an axis aligned boundary box defining the i-th output tile. 

        Parameters
        ----------
        i : int
            index of the output tile

        Returns
        -------
        tuple
            aabb coordinate tuple (x0,y0,z0,x1,y1,z1) (diagonal oposite corners that define a rectangular volume)
        """
        x,y,z = self.indexToCoordinates(i)
        # assemble the coordinates of the target chunk
        x0 = self.coords[0][x]
        y0 = self.coords[1][y]
        z0 = self.coords[2][z]
        x1 = x0 + self.output_shape[0]
        y1 = y0 + self.output_shape[1]
        z1 = z0 + self.output_shape[2]
        return (x0,y0,z0,x1,y1,z1)

    def getInputTile(self, i):
        """Returns the axis alinged boundary box of the i-th input tile.

        Parameters
        ----------
        i : int
            index of the input tile

        Returns
        -------
        tuple
             aabb coordinate tuple (x0,y0,z0,x1,y1,z1) (diagonal oposite corners that define a rectangular volume)
        """
        aabb = self.getOutputTile(i) # get the aabb of the corresponding input tile 
        delta = np.subtract(self.input_shape,self.output_shape) // 2 # symmetric expansion in each direction
        # we have to subtract delta from the inital coords and add it to the stop coords
        delta = np.concatenate((-delta, delta))
        aabb = np.add(aabb,delta) # element wise addition
        return tuple(aabb)

    def getInputVolume(self):
        """Returns the axis alinged boundary box of the tilings input volume.
        This possibly contains values that protrudes from the image shape. Use Canvas to handle this.
        """
        start_corner = self.getInputTile(0)[:3] # get the first corner of the first input tile
        end_corner = self.getInputTile(len(self)-1)[3:] # get the second corner of the last input tile
        return start_corner + end_corner

    def getAdjacentTiles(self, i : int) -> list:
        """Returns a list with the indices of adjacent tiles. (Rectangular tiles that share a face with the reference tile)

        Parameters
        ----------
        i : int
            index of the reference tile

        Returns
        -------
        list
            indices of adjacent tiles or None in format [x_pre, x_post, y_pre, y_post, z_pre, z_post]
        """
        adjacent = []
        # get the coordinates of the current tile
        coords = self.indexToCoordinates(i)
        # In every dimension
        for d in range(3):
            # Add or subtract one position
            for n in [-1,1]:
                try:
                    new_coords = list(coords)
                    new_coords[d] += n
                    # try to convert to tile index -> fails if nonexistent
                    new_i = self.coordinatesToIndex(*new_coords)
                    adjacent.append(new_i)
                except AssertionError:
                    adjacent.append(None)
        return adjacent

#%%
class OverlappingUnetTiling3D(UnetTiling3D):
    """Derived from UnetTiling3D, instead of using adjacent output Tiles to cover the input image, each tile is shifted only by a given stepsize in each dimension.
    This allows for mutually overlapping tiles.
    """
    def __init__(self, image_shape, output_shape=(132,132,132), input_shape=(220,220,220), delta=(8,8,8), containTiling=False):
        """
        Parameters
        ----------
        image_shape : tuple
            the shape of the volume that should be tiled
        output_shape : tuple
            shape of the segmentation output of the unet
        input_shape : tuple
            shape of the image input of the unet
        delta : tuple
            spacing of the tiling grid as (dx,dy,dz)
        containTiling: bool
            wheter the ouput tile grid should be centered on the available data. This tries to prevent the input regions to extend past the image borders but also makes some border pixels inaccessible by the unet output.
        """
        super().__init__(image_shape, output_shape, input_shape)
        self.image_shape = image_shape
        # Store output and input shape of the unet and check for correct number of dimensions
        self.output_shape = output_shape
        self.input_shape = input_shape
        assert len(self.image_shape) == 3, 'Specify a single channel 3D image with format (x,y,z)'
        assert len(self.output_shape) == 3, 'Specify the extent of the output shape as (x,y,z)'
        assert len(self.input_shape) == 3, 'Specify the extent of the input shape as (x,y,z)'
        assert self.output_shape <= self.input_shape, 'The input shape cannot be smaller than the output shape'
        # Store delta and check for correct number of dimensions
        self.delta = delta
        assert len(self.delta) == 3 , 'Specify the spacing of the tiling grid as (dx,dy,dz)'
        assert self.delta <= self.output_shape, 'The spacing must be smaller or equal to the output shape to prevent gaps between tiles'

        # Calculate the coordinate mesh of the tiling
        # Each list goes up to the last multiple of the step size smaller than image_shape 
        self.coords = [] # list of coordinates, one entry for each axis
        for d in range(3):
            self.coords.append([]) # list of grid nodes along axis d
            offset = (self.input_shape[d]-self.output_shape[d])//2 # offset by input region border
            if containTiling:
                i = offset
            else:
                i = 0 # start tiling with ouput region at image border

            while True:
                self.coords[d].append(i)
                if containTiling:
                    # add the next grid position until the input tile protrudes from the image for the first time
                    if i+ self.output_shape[d] + offset >= self.image_shape[d]:
                        break
                else:
                    # add the next grid position until the output tile protrudes from the image for the first time.
                    if i+self.output_shape[d] > self.image_shape[d]:
                        break
                i += delta[d]

        # Expose the shape of the tiling
        self.shape = tuple([len(d) for d in self.coords])
#%%
class Canvas():
    """Base class that provides i/o operations to a large 3D array using axis aligned bounding boxes
    """

    def __init__(self, image):
        super().__init__()
        assert len(image.shape) == 3,'Specify a 3D array, was ' + str(image.shape)
        self.image = image
        self.shape = self.image.shape

    def cropAndPadAABB(self, aabb):
        """Extracts the region specified by the aabb from the canvas.
        If the aabb protrudes from the canvas, it's content is reflected allow extraction of the aabb

        Parameters
        ----------
        aabb : tuple
            aabb coordinate tuple (x0,y0,z0,x1,y1,z1) (diagonal oposite corners that define a rectangular volume)

        Returns
        -------
        3d tensor
            the region of the volume that was specified by the aabb
        """
        # clip the aabb if it protrudes from the canvas
        start = [ np.max([0, d]) for d in aabb[:3] ] # origo is at (0,0,0)
        stop = [ np.min([self.image.shape[i], aabb[i+3]]) for i in range(3) ]
        # calculate the padding in each direction
        pre_pad = [ np.max([0, -d]) for d in aabb[:3] ]
        post_pad = [ np.max([0, aabb[i+3] - self.image.shape[i] ]) for i in range(3) ]
        padding = tuple([ (pre_pad[i], post_pad[i]) for i in range(3) ] )
        # extract valid/ clipped portion of the aabb
        data = self.image[start[0]:stop[0],start[1]:stop[1],start[2]:stop[2]]
        # pad the slice to the required size
        data = np.pad(data, pad_width=padding, mode='reflect')
        return data

    def writeAABB(self, aabb, tile):
        """Writes a rectangular tile of data to a position in the canvas specified by the aabb

        Parameters
        ----------
        aabb : tuple
            aabb coordinate tuple (x0,y0,z0,x1,y1,z1) (diagonal oposite corners that define a rectangular volume)
        tile : 3d tensor
            a rectangular array of data
        """
        aabb_volume = tuple([aabb[i+3]-aabb[i] for i in range(3)]) # calculate the volume specified by the aabb
        assert tile.shape == aabb_volume, 'Slice needs to have the same volume as the aabb'

        # clip the target aabb if it protrudes from the canvas volume to get the target coordinates
        start = [ np.max([0, d]) for d in aabb[:3] ] # origo is at (0,0,0)
        stop = [ np.min([self.image.shape[i], aabb[i+3]]) for i in range(3) ]

        # calculate the crop that must be applied to the tile before writing to target coordinates
        tile_start = [ np.max([0, -d]) for d in aabb[:3] ]
        tile_stop = [ np.max([0, aabb[i+3] - self.image.shape[i] ]) for i in range(3) ]
        #print('unet output mask crop from {} to {}'.format(slice_start,slice_stop))

        # crop the padding away
        tile_cropped = tile[tile_start[0]:-tile_stop[0] or None,
                              tile_start[1]:-tile_stop[1] or None,
                              tile_start[2]:-tile_stop[2] or None]
        
        # write the cropped slice to the target position in the mask
        self.image[start[0]:stop[0],start[1]:stop[1],start[2]:stop[2]] = tile_cropped
#%%
class AbsoluteCanvas():
    def __init__(self, image_shape : tuple, canvas_area : tuple, image: np.array):
        """Base class that handels read and write access to 3D volumes.
        Axis aligned boundary boxes in format (x0,y0,z0,x1,y1,z1) are used to specify subvolumes.
        If a subvolumes should be read that protrudes from the image, Canvas will mirror it at the border.
        If a subvolume should be written that protrudes from the writing area tha input is cropped.
    

        Parameters
        ----------
        image_shape : tuple
            shape of the entire image.  
        canvas_area : tuple or None
            axis aligned boundary box defining the subvolume to which read and write access are allowed. 
            If None is specified, the canvas area extends over the entire image.
        image : np.array
            Image data or preallocated array to which will be written.
        """
        super().__init__()
        
        # If no canvas area is specified we work on the entire image shape
        if canvas_area is None:
            canvas_area = (0,0,0,) + image_shape
        
        # Check that the supplied image array has the same shape as the subvolume that we have read / write access to
        assert len(image.shape) == 3,'Specify a 3D array'
        for d in range(3):
            assert canvas_area[d+3] - canvas_area[d] == image.shape[d], 'The image must have the same extent as the canvas area' +'\nfor d = {} canvas area was {} image shape was {}'.format(d,canvas_area[d+3] - canvas_area[d],image.shape[d])
    
        self.image = image
        self.canvas_area = canvas_area
        self.image_shape = image_shape

    def cropAndPadAABB(self, aabb):
        """Extracts the region specified in absolute coordinates from the canvas.
        If the aabb protrudes from the canvas area, it's content is reflected allow extraction of the aabb

        Parameters
        ----------
        aabb : tuple
            aabb coordinate tuple (x0,y0,z0,x1,y1,z1) in global coordinate system (diagonal oposite corners that define a rectangular volume)

        Returns
        -------
        3d tensor
            the region of the volume that was specified by the aabb
        """
        # clip the aabb if it protrudes from the canvas area
        start = np.array([ np.max([self.canvas_area[i], aabb[i]]) for i in range(3) ]) # origo is at canvas_area[:3]
        stop = np.array([ np.min([self.canvas_area[i+3], aabb[i+3]]) for i in range(3) ]) # end is at canvas_area[3:]
        # calculate the padding in each direction
        pre_pad = np.array([ np.max([0, self.canvas_area[i] - aabb[i]]) for i in range(3) ])
        post_pad = np.array([ np.max([0, aabb[i+3] - self.canvas_area[i+3] ]) for i in range(3) ])
        padding = tuple([ (pre_pad[i], post_pad[i]) for i in range(3) ] )
        # shift global coordinates by the offset of the canvas area
        start -= np.array(self.canvas_area[:3])
        stop -= np.array(self.canvas_area[:3])
        # extract valid/ clipped portion of the aabb
        data = self.image[start[0]:stop[0],start[1]:stop[1],start[2]:stop[2]]
        # pad the slice to the required size
        data = np.pad(data, pad_width=padding, mode='reflect')
        return data

    def writeAABB(self, aabb, tile):
        """Writes a rectangular tile of data to a position in the canvas specified by absolute coordinates

        Parameters
        ----------
        aabb : tuple
            aabb coordinate tuple (x0,y0,z0,x1,y1,z1) (diagonal oposite corners that define a rectangular volume)
        tile : 3d tensor
            a rectangular array of data
        """
        aabb_volume = tuple([aabb[i+3]-aabb[i] for i in range(3)]) # calculate the volume specified by the aabb
        assert tile.shape == aabb_volume, 'Slice needs to have the same volume as the aabb'

        # clip the target aabb if it protrudes from the canvas area to get the target coordinates
        start = np.array([ np.max([self.canvas_area[i], aabb[i]]) for i in range(3) ]) # origo is at canvas_area[:3]
        stop = np.array([ np.min([self.canvas_area[i+3], aabb[i+3]]) for i in range(3) ]) # end is at canvas_area[3:]

        # calculate the crop that must be applied to the tile before writing to target coordinates
        tile_start = np.array([ np.max([0, self.canvas_area[i] - aabb[i]]) for i in range(3) ])
        tile_stop = np.array([ np.max([0, aabb[i+3] - self.canvas_area[i+3] ]) for i in range(3) ])
        #print('unet output mask crop from {} to {}'.format(slice_start,slice_stop))

        # crop the padding away
        tile_cropped = tile[tile_start[0]:-tile_stop[0] or None,
                              tile_start[1]:-tile_stop[1] or None,
                              tile_start[2]:-tile_stop[2] or None]
        
        # shift global coordinates by the offset of the canvas area
        start -= np.array(self.canvas_area[:3])
        stop -= np.array(self.canvas_area[:3])

        # write the cropped slice to the target position in the mask
        self.image[start[0]:stop[0],start[1]:stop[1],start[2]:stop[2]] = tile_cropped
#%%
class UnetTiler3D():
    def __init__(self, tiling: UnetTiling3D, image: Canvas, mask: Canvas):
        """Construct a Utility class that manages input and output of 3D Unet tiles to image and mask arrays.

        Parameters
        ----------
        tiling : UnetTiling
            The tiling of the joint image and mask space. Possibly covering only a target subvolume.
        image : Canvas
            A canvas providing access to input image data.
        mask : Canvas or None
            A canvas providing access to ground truth mask data or to store the output segmentation data
        """
        self.tiling = tiling
        self.image = image
        self.mask = mask
        # expose the shape of the tiling
        self.shape = tiling.shape

    @classmethod
    def forEntireCongruentData(cls, image, mask=None, output_shape=(132,132,132), input_shape=(220,220,220)):
        """
        This function creates an instance of UnetTiler3D given a concrete image and optionally a mask tensor.
        It is assumed that the tiling should extent over the entire input image.
        Image and Mask arrays are assumed to be of the same size and congruent.
        If a preexisting tensor is specified as the mask, it is overwritten. If no mask is specified, a new one is allocated as a numpy ndarray.

        The input volume is tiled with the output shape of the unet. 
        Each output tile is symmetrically expanded to the input shape to get the corresponding input for the unet.
        The tiles are ennumerated internally and can be accessed either by their coordinates in the rectangular tiling or their index.
        Internally, axis aligned boundary boxes are specified as coordinate tuples of the form (x0,y0,z0,x1,y1,z1) (diagonal oposite corners that define a rectangular volume)
        Image and Mask read/write:
        Tiles can be read from the image and written to the corresponding mask location with their index.
        
        Parameters
        ----------
        image : image tensor
            the input tensor
        output_shape : tuple
            shape of the segmentation output of the unet
        input_shape : tuple
            shape of the image input of the unet
        """
        image_canvas = Canvas(image) # Use a canvas for i/o on the image

        # Allocate an array to assemble the mask in if not specified
        if mask is None:
            mask_canvas = Canvas(np.zeros_like(image)) # Allocate a tensor where the segmentation mask is stored
        else:
            assert image.shape == mask.shape, 'The mask and image array need to be of the same shape'
            mask_canvas = Canvas(mask)

        # Instantiate UnetTiling over image and mask
        tiling = UnetTiling3D(image_shape=image.shape, tiling_subvolume= None, output_shape=output_shape, input_shape=input_shape)

        # create and return an initialized instance of UnetTiler3D
        return UnetTiler3D(tiling, image_canvas, mask_canvas)

    # Expose the number of tiles 
    def __len__(self):
        return np.prod(self.shape)

    def getSlice(self, index, outputOnly=False):
        """Get the i-th input tile of the image.
        Parameters
        ----------
        index : int
            the index of the image tile
        outputOnly : bool
            wheter the slice should be narrowed down to the output region only
        Returns
        -------
        3d tensor
            the i-th input tile of the image
        """
        if outputOnly:
            aabb = self.tiling.getOutputTile(index)
        else:
            # get the aabb of the unet input slice
            aabb = self.tiling.getInputTile(index)
        # read out the aabb from the image data
        data = self.image.cropAndPadAABB(aabb)
        return data

    def getMaskSlice(self, index, cropped=True):
        """Get the i-th output tile of the mask.
        Parameters
        ----------
        index : int
            the index of the mask tile
        cropped : bool
            wheter to extract the cropped (output) region of the mask tile or the whole input region (congruent to getSlice)
        Returns
        -------
        3d tensor
            the i-th output tile of the mask
        """
        if cropped:
            # get the aabb of the unet OUTPUT slice
            aabb = self.tiling.getOutputTile(index)
        else:
            # get the aabb of the unet INPUT slice
            aabb = self.tiling.getInputTile(index)
        # extract the specified region from the mask array    
        data = self.mask.cropAndPadAABB(aabb)
        return data
    
    def writeSlice(self, index, tile):
        """Writes the i-th tile of the mask to it's corresponding position in the mask tensor.
        Parameters
        ----------
        index : int
            the index of the mask tile
        tile : 3d tensor
            the i-th output tile of the mask
        """
        assert tile.shape == self.tiling.output_shape, 'Slice needs to have the output shape of the unet'
        assert index>=0 and index < len(self), 'Index out of bounds'
        aabb = self.tiling.getOutputTile(index) # retrieve aabb that belongs to the slice index
        self.mask.writeAABB(aabb, tile)

    def getGeneratorFactory(self):
        """Returns a generator function that iterates over all tiles of the Unet Tiler
        """
        def generatorFactory():
            for tile in range(len(self)):
                yield self.getSlice(tile)

        return generatorFactory

