"""
Provides tools to create, maintain and access training datasets from 3D microscopy data.

Linus Meienberg
August 2020
"""

import numpy as np
import random
import h5py
from tqdm import tqdm

# Heavily relies on acces to image volumes through tiler classes
import tilingStrategy


def getRandomIndices(tiler: tilingStrategy.UnetTiler3D , n_samples: int) -> list:
    """Samples random indices from a tiled image volume

    Parameters
    ----------
    tiler : tilingStrategy.UnetTiler3D
        A Tiled image volume
    n_samples : int
        the number of samples to draw

    Returns
    -------
    list
        the indices of the random tiles
    """
    assert n_samples<len(tiler), 'Cannot sample more than {} samples from this tiling'.format(len(tiler))
    sample_indices = np.random.choice( np.arange(len(tiler)), size=n_samples, replace=False) # choose n_samples random chunks from the volume
    return sample_indices

def getMeanSignalStrengths(tiler: tilingStrategy.UnetTiler3D, indices: list) -> list:
    """Get a list of mean signal strength (average pixel value) for a list of tile indices

    Parameters
    ----------
    tiler : tilingStrategy.UnetTiler3D
        A tiled image volume
    indices : list
        tile indices

    Returns
    -------
    list
        the signal strength in each tile
    """
    mean_signal_strengths = [ np.mean(tiler.getSlice(i, outputOnly=True)) for i in tqdm(indices)]
    return mean_signal_strengths

def sampleMaskProportion(tiler: tilingStrategy.UnetTiler3D, indices: list) -> list:
    """Get a list of mask proportions for each tile. Mask proportion is the fraction of foreground / object pixels in the output region of a tile.

    Parameters
    ----------
    tiler : tilingStrategy.UnetTiler3D
        A tiled image volume
    indices : list
        tile indices

    Returns
    -------
    list
        the mask proportion in each tile
    """
    sample_volume = np.prod(tiler.tiling.output_shape) # number of pixels in the sample volume
    sample_mask_proportion = [ 
        np.count_nonzero(tiler.getMaskSlice(i)) / sample_volume
         for i in tqdm(indices) ]

    return sample_mask_proportion


def thresholdedSampling(indices: list, scalar_measure: list, threshold: float, n_samples: int, above_threshold_ratio=0.5) -> list:
    """Sample tile indices from a list based on a scalar_measure known for each tile. Tiles are grouped in two categories by thresholding the scalar measure. 
    The above_threshold_ratio specifies the fraction of indices that should belong to the group exceeding the threshold.

    Parameters
    ----------
    indices : list
        tile indices to sample from
    scalar_measure : list
        scalar measure calculated for each tile
    threshold : float
        the threshold applied to the scalar measure
    n_samples : int
        the number of indices in the output list
    above_threshold_ratio : float, optional
        The proportion of above threshold tiles in the output list, by default 0.5

    Returns
    -------
    list
        tile indices
    """
    # clip value to prevent nummerical errors
    above_threshold_ratio = np.clip(above_threshold_ratio,1e-4,1-1e-4)
    # split the indeces
    is_high = [int(signal > threshold) for signal in scalar_measure]
    # weight each sample by it's class probability
    proba = np.multiply(is_high, above_threshold_ratio/np.sum(is_high)) + np.multiply(np.subtract(1,is_high), (1-above_threshold_ratio)/(len(is_high)-np.sum(is_high)))
    #print(proba)
    samples = np.random.choice(indices, size=n_samples, replace=False, p=proba)
    return samples

class Dataset():
    """Utility class that interfaces a dataset saved in a h5 file.

    Corresponding input tiles and mask output tiles are stored in the same group.
    The layout of the dataset is:
        -item 1
            -image a
            -mask a
        -item 2
            -image b 
            -mask b
    """

    def __init__(self, dataset_path, append=True, readonly=False):
        """Instantiate a Dataset class linked to the repository specified in the dataset path

        Parameters
        ----------
        dataset_path : str
            repository location
        append : bool, optional
            whether to append to a preexisting file, by default True
        readonly : bool, optional
            whether to open file in readonly mode
        """
        if readonly:
            assert not append, "cannot append in readonly mode"
        super().__init__()
        if append:
            self.dataset_h5 = h5py.File(dataset_path, mode='a')
        elif readonly:
            self.dataset_h5 = h5py.File(dataset_path, mode='r') # open file in read only mode
        else:
            self.dataset_h5 = h5py.File(dataset_path, mode='x') # create new, fail if exists
        # keep track of existing groups
        if len(self.keys())>0:
            print('Opened dataset with {} preexisting items.'.format(len(self.keys())))
            if not readonly:
                print('Overwriting items with the same name.')


    def __len__(self):
        """Define the length of the dataset as the number of groups it contains
        """
        return len(self.dataset_h5.keys())

    def __getitem__(self, index):
        """Returns the i-th element of the dataset. Note that the hdf5 file implements a dictionary without guarantees on the ordering of it's keys.
        This method just returns the element that belongs to the i-th key in lexicographic order.

        Parameters
        ----------
        index : int
            index of the element to retrieve

        Returns
        -------
        tuple
            a tuple containing the input image, output mask and metadata of the record
        """
        #assert index < len(self)
        key = sorted(self.keys())[index]
        return self.get(key)

    def keys(self):
        return self.dataset_h5.keys()

    def add_tiles(self, tiler, indices, key_prefix='', cropMask=False, preprocessingFunction= None, binarizeMask = False, metadata = {}):
        """Add a multiple records specified by a tiler and a list of indices.

        Parameters
        ----------
        tiler : tilingStrategy.tiler
            tiler that yields image and mask tiles
        indices : int
            the indices of the tiles to add
        key_prefix : str, optional
            prefix to the tile index, used to create the record key, by default ''
        cropMask : bool
            wheter to save precropped mask tiles or congruent image mask pairs
        preprocessingFunction : callable, optional
            preprocessing function to apply to the input, by default None
        binarizeMask : bool, optional
            wheter to binarize the mask, by default False
        metadata : dict, optional
            a dictonary containing the metadata of the record
        """
        for index in tqdm(indices, desc='Tiles added'):
            
            # fetch the data
            image, mask = tiler.getSlice(index), tiler.getMaskSlice(index, cropped=cropMask)

            # preprocess if necessary
            if not preprocessingFunction is None:
                image = preprocessingFunction(image)
            if binarizeMask:
                mask = np.clip(mask,0,1)

            group_name = key_prefix + str(index)
            # save the tile number
            metadata['tile_index'] = index

            self.add(group_name, image, mask, metadata)

            
    
    def add(self, key, image, mask, metadata={}):
        """Add a record to the database

        Parameters
        ----------
        key : str
            key with wich the record can be retrieved
        image : image tensor
            the input image
        mask : image tensor
            the output mask
        metadata : dict, optional
            a dictonary containing the metadata of the record
        """
        # check if the item allready exists
        if key in self.keys():
            print('\nOverwriting item {}'.format(key))
            del self.dataset_h5[key] # delete the group

        # create the group and write image and masks datasets
        self.dataset_h5.create_group(key)
        self.dataset_h5[key].create_dataset('image', data=image)
        self.dataset_h5[key].create_dataset('mask', data=mask)

        # save metadata about group creation
        for name in metadata.keys():
            self.dataset_h5[key].attrs.create(name, metadata[name])

    def delete(self,key):
        """Delete a record from the dataset.

        Parameters
        ----------
        key : str
            the key of the record that should be removed from the dataset
        """
        if type(key) is int:
            key = str(key)
        if not key in self.keys():
                print('Key {} not contained in dataset - key ignored'.format(key))
        else:
            del self.dataset_h5[key]

    def get(self, key):
        """Retrieve a record by it's key  
        reads the image tensors into a numpy ndarray and converts them to numpy dtypes

        Parameters
        ----------
        key : str
            the record key

        Returns
        -------
        tuple (dataset, dataset, dict)
            input image, mask, metadata
        """
        if type(key) is int:
            key = str(key)
        assert key in self.keys(), 'Key not contained in dataset'
        image = self.dataset_h5[key]['image'][:].astype(np.float32)
        mask =  self.dataset_h5[key]['mask'][:].astype(np.int32)

        metadata = {}
        for atr in self.dataset_h5[key].attrs.keys():
            metadata[atr] = self.dataset_h5[key].attrs[atr]
        return (image, mask, metadata)

    def get_Record_by_Metadata(self, attribute_key : str, attribute_value=None) -> list :
        """Gets all records in the dataset that have an entry specified by the key.
        Only return the records where the entry has the specified value, if specified.

        Parameters
        ----------
        attribute_key : str
            The key of the metadata entry / record attribute to search for.
        attribute_value : str, optional
            The required value of the metadata entry / record attribute 
            for the record to be included in the output list, by default None

        Returns
        -------
        list
            The keys of all records in the dataset that have the specified attribute and optionally the specified value.
        """
        keys = []

        # iterate over all records in the dataset
        for record_key in self.keys():
            # Get the metadata of the record
            record_attributes = self.dataset_h5[record_key].attrs
            # Check if the key is contained in the record metadata
            if attribute_key in record_attributes.keys:
                # check if value comparison is needed
                if not attribute_value is None:
                    # compare values
                    if str(record_attributes[attribute_key]) == attribute_value:
                        keys.append(record_key)
                    else:
                        pass
                        # Don't add the record since it's 'key' attribute has not the desired value
                else: # No value comparison is needed
                    keys.append(record_key)
        
        return keys 

    def getGenerator(self, keys, shuffle=True):
        """Returns a generator function that iterates over the specified keys.
        The generator yield a tuple consisting of the image input and the mask output for each.

        Parameters
        ----------
        keys : list
            list of keys that identify the dataset records over which the generator should iterate
        shuffle : bool
            wheter to shuffle the keys each time a generator over the keys is returned
        Returns
        -------
        generator
            a generator running over the keys in random order

            Yields
            -------
            tuple   
                the input image and corresponding output mask
        """
        # return a callabe that constructs a generator that iterates over the specified keys
        assert set(keys).issubset(self.keys()), 'Keys contain unknown entries'
        

        def getGen():
            if shuffle:
                random.shuffle(keys) # iterate in random order
            for key in keys:
                image, mask, _ = self.get(key)
                yield (image, mask)
        
        return getGen

    def setAttribute(self, key, value):
        self.dataset_h5.attrs.create(key,value) # write to h5 file attributes

    def getAttributes(self):
        return self.dataset_h5.attrs

    def close(self):
        self.dataset_h5.flush()
        self.dataset_h5.close()
