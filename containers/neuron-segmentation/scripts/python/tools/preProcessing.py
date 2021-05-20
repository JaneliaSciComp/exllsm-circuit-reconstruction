"""
Image preprocessing routines
"""

import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import HuberRegressor


def calculateScalingFactor(x, plot_file=None):
    """
    This Preprocessing function calculates a scaling factor for the pixel intensities, such that the majority of pixel values lie in the intervall [0,1]

    The intensity distribution of the image is assumed to be of the form 
        P(I) = P_0 * exp(-b*I) 
            or in log form
        log(P(I)) = log(P_0) - b*I
        I : pixel intensity
        P(I) : probability / relative counts in histogram

    For a given image b is estimated using Huber regression (outlier robust linear regression, implemented in scikit learn)

    The decay rate b is adjusted to be comparable between samples by scaling the intensity values I
        scaling_factor = b_measured/b_target

    Empirically, a target decay rate of b_target = ln(10)/0.5 was chosen. This corresponds to a reduction of intensity counts by a factor of 10, every 0.5 Intensity units in the histogram.

    Parameters
    ----------
    x : image tensor

    output_directory : str (optional)
        If specified, diagnostic plots are created in the indicated directory
    filename : str (optional)
        filename for diagnostic plot files.

    Returns
    -------
    float   
        scaling factor. Returns Nan if calculation of scaling factor fails. (eg if only background is present in the image)
    """
    x = x.astype(np.float32)
    # calculate intensity distribution
    # EMPIRICAL the majority of intensity values should be within this range for ALL imaged regions!
    counts, bins = np.histogram(x, bins=1000, range=[0, 4000])
    # Calculate mean bin value and log counts
    mean_bins = (bins[:-1] + bins[1:])/2
    np.seterr(divide='ignore')  # we know there will be 0s
    log_counts = np.log(counts)
    np.seterr(divide='warn')
    # Drop all bins with zero count (gives runnaway when taking log counts / not informative)
    mean_bins = mean_bins[np.isfinite(log_counts)]
    log_counts = log_counts[np.isfinite(log_counts)]

    # If we have only a very small number of bins with observations (e.g. if  all pixels belong to the background)
    num_obs = len(log_counts)
    if num_obs < 10:
        print(
            "not enough observations for inference of scaling factor from histogram slope")
        return np.nan

    # Instantiate and fit the Huber Regressor
    # Use sklearns default values -> fits intercept, epsilon = 1.35, alpha = 1e-4
    huber = HuberRegressor()
    # sklearn X,y synthax where X is a matrix (samples x observation) and y a vector (samples,) of target values
    huber.fit(mean_bins.reshape(-1, 1), log_counts)
    # Calculate scaling factor
    # EMPIRICAL Probability should reduce to 1/10th after 0.5 intensity units to get an intensity distribution within [0,1]
    b_target = -np.log(10)/0.5
    scaling_factor = huber.coef_[0]/b_target

    if plot_file is not None:
        # Show exponential Fit
        plt.figure()
        # scatter plot histogram data
        plt.scatter(mean_bins, log_counts, marker='.')
        # line plot huber regressor fit
        plt.plot(mean_bins, huber.predict(mean_bins.reshape(-1, 1)),
                 color='red')
        plt.ylim([-1, 25])
        plt.ylabel('log(Counts)')
        plt.xlabel('Pixel Intensity')
        plt.legend(['Huber Regression', 'Counts'])
        plt.savefig(plot_file)
        plt.close()

    return scaling_factor


def scaleImage(x, scaling_factor):
    """
    Scale the pixel values of an image by a given scaling factor
    """
    x = x.astype(np.float32)
    x *= np.array(scaling_factor)

    return x


def preprocessImage(x, mean, std):
    """
    Preprocess image by z score normalization.
    This function shifts intensity values by their mean and scales them by the standard deviation to get a zero centered distribution with a std of 1.

    Parameters
    ----------
    x : image tensor
    mean : float
        mean intensity value
    std : float
        standard deviaton

    Returns
    -------
    image tensor
        z normalized image
    """
    # clip, and z normalize image
    x = x.astype(np.float32)
    x = np.clip(x, 0, 1400)
    x = np.subtract(x, mean)
    x = np.divide(x, std)
    return x
