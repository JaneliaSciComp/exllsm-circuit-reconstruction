"""
This module contains functions for post processing of segmentation masks or probability maps
"""
import numpy as np

import skimage.morphology
import skimage.segmentation
import skimage.measure
from tqdm import tqdm


def clean_watershed(probability_map: np.ndarray, high_confidence_threshold=0.98, low_confidence_threshold=0.2):
    """
    This method generates a 'cleaned' segmentation mask from a probability map. It is assumed that a single object is present in the image together with some disconnected fragments that should be ignored.
    In a first step, high probability regions are taken as a seed point from which the foreground region is expanded by scikit-image's watershed algorithm.
    The region is expanded only where the foreground probability exceeds the low confidence threshold.

    Parameters
    ----------
    probability_map : np.ndarray
        Segmentation output holding foreground probabilities
    high_confidence_threshold : float
        seed regions must exceed this probability
    low_confidence_threshold : float
        the region is not expanded to parts of the map that lie below this probability
    """
    # Generate binary masks for high and low confidence areas
    low_confidence = probability_map > low_confidence_threshold
    high_confidence = probability_map > high_confidence_threshold
    # Set up an array of markers for skimage's watershed function
    # conversion to an integer array has the same effect !
    cleaned = skimage.segmentation.watershed(
        -probability_map, high_confidence.astype(np.int), mask=low_confidence)
    return cleaned > 0  # Return a boolean tensor


def clean_floodFill(probability_map: np.ndarray, high_confidence_threshold=0.98, low_confidence_threshold=0.2):
    """
    This method generates a 'cleaned' segmentation mask from a probability map. It is assumed that a single object is present in the image together with some disconnected fragments that should be ignored.
    Connected regions where the probability map exceeds the high confidence threshold are found.
    The probability map is thresholded at low confidence threshold and the high probability regions are expanded within the thresholded area.
    Only parts of the probability map reached in the flood filing operation are retained.

    Parameters
    ----------
    probability_map : np.ndarray
        Segmentation output holding foreground probabilities. The input to the function is modified directly!
    high_confidence_threshold : float
        seed regions must exceed this probability
    low_confidence_threshold : float
        the region is not expanded to parts of the map that lie below this probability

    """
    # Generate binary mask for high probability regions
    high_confidence = probability_map > high_confidence_threshold
    # Label connected regions in high probability mask
    labels, num = skimage.morphology.label(high_confidence, return_num=True)
    # Calculate region statistics
    region_stats = skimage.measure.regionprops(labels)
    # From this point on we no longer need the high confidence mask or the label mask
    del high_confidence
    del labels
    # The centroids of the regions can lie outside of the region itself!
    # Use an arbitrary point belonging to the region instead
    # centroids = [(int(region_stats[i].centroid[0]),int(region_stats[i].centroid[1]),int(region_stats[i].centroid[2]))
    #             for i in range(num)]  # read centroid coords and convert to int
    # take coordinates of the first point in each region
    seedpoints = [tuple(region.coords[0, :]) for region in region_stats]
    # From this point on we no longer need the region stats
    del region_stats

    # Threshold at low confidence and set up integer mask
    low_confidence = (probability_map >
                      low_confidence_threshold).astype(np.int)

    # Perform flood filling starting from high proba regions
    fill_value = 2  # int value used to label area reached by flood fill
    for label in tqdm(range(num), desc="Cleaning Segmentation Result (FloodFill)"):
        # test if seed point has allready been reached
        if low_confidence[seedpoints[label]] != fill_value:
            skimage.morphology.flood_fill(
                low_confidence, seedpoints[label], new_value=fill_value, in_place=True)

    # Retain only the part reached by flood filling
    cleaned_mask = low_confidence == fill_value
    # Set values outside mask to 0
    probability_map[np.invert(cleaned_mask)] = 0
    return probability_map


# %% Remove small objects
def removeSmallObjects(image: np.ndarray, probabilityThreshold=0.2, size_threshold=2000):
    """
    Removes areas of the mask that are smaller than a predefined number of voxels.
    Only the parts of the mask higher than the probability threshold are detected, measured and removed ! (low p fringes around objects are not cleaned up)
    Code reused from skimage.remove_small_objects.

    Parameters
    ----------
    image : np.ndarray
        the image tensor
    size_threshold : int, optional
        the minimal number of connected voxels, by default 2000

    Returns
    -------
    np.ndarray
        the cleaned up image tensor
    """
    regions = skimage.morphology.label(
        image > probabilityThreshold)  # Create labeled regions for all areas exceeding the probability threshold
    # calculate the voxel count of all labeled regions
    component_sizes = np.bincount(regions.ravel())
    # boolean vector with regions failing threshold
    too_small = component_sizes < size_threshold
    too_small_mask = too_small[regions]  # binary mask, true for small objects
    image[too_small_mask] = 0  # set regions to 0
    return image
