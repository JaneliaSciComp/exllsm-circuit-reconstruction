"""Image preprocessing routines
"""

import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import HuberRegressor


def calculateScalingFactor(x, output_directory = None, filename = None):
    """This Preprocessing function calculates a scaling factor for the pixel intensities, such that the majority of pixel values lie in the intervall [0,1]

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
    counts, bins = np.histogram(x, bins=1000, range=[0,4000]) # EMPIRICAL the majority of intensity values should be within this range for ALL imaged regions!
    # Calculate mean bin value and log counts
    mean_bins = (bins[:-1] + bins[1:])/2
    log_counts = np.log(counts) 
    # Drop all bins with zero count (gives runnaway when taking log counts / not informative)
    mean_bins = mean_bins[np.isfinite(log_counts)]
    log_counts = log_counts[np.isfinite(log_counts)]

    # If we have only a very small number of bins with observations (e.g. if  all pixels belong to the background)
    num_obs = len(log_counts)
    if num_obs < 10:
        print("not enough observations for inference of scaling factor from histogram slope")
        return np.nan
    
    # Instantiate and fit the Huber Regressor
    huber = HuberRegressor() # Use sklearns default values -> fits intercept, epsilon = 1.35, alpha = 1e-4
    huber.fit(mean_bins.reshape(-1,1), log_counts) # sklearn X,y synthax where X is a matrix (samples x observation) and y a vector (samples,) of target values
    # Calculate scaling factor
    b_target = -np.log(10)/0.5 # EMPIRICAL Probability should reduce to 1/10th after 0.5 intensity units to get an intensity distribution within [0,1]
    scaling_factor = huber.coef_[0]/b_target
    #print('scaling intensity values by ' + str(scaling_factor))

    if not output_directory is None:
        assert not filename is None, 'Specify a file name'
        # Show exponential Fit
        plt.figure()
        plt.scatter(mean_bins, log_counts, marker='.') # scatter plot histogram data
        #plt.hist(bins[:-1], bins, weights=log_counts_complete) # Plot precomputed histogram
        plt.plot(mean_bins,huber.predict(mean_bins.reshape(-1,1)), color = 'red') # line plot huber regressor fit
        plt.ylim([-1,25])
        plt.ylabel('log(Counts)')
        plt.xlabel('Pixel Intensity')
        plt.legend(['Huber Regression','Counts'])
        #plt.title('Approximation of Intensity Counts by Exponential Distribution\n' + filename + ' log(P(I)) = ' + str(huber.coef_[0]) + ' *I+ ' + str(huber.intercept_))
        plt.savefig(output_directory + 'region_'+filename+'_expFit.png')

        

    return scaling_factor

def scaleImage(x, scaling_factor, output_directory = None, filename = None):
    """Scale the pixel values of an image by a given scaling factor
    """
    x = x.astype(np.float32)
    x *= np.array(scaling_factor)

    if not output_directory is None:
        assert not filename is None, 'Specify a file name'
        # Show scaled intensity distribution
        plt.figure()
        plt.hist(x.reshape(-1,1), bins = 500, range=[0,2], log=True)
        plt.ylabel('log(Counts)')
        plt.xlabel('Adjusted Pixel Intensity')
        plt.title('Adjusted intensity distribution for region ' + filename)
        plt.savefig(output_directory + 'region_'+filename+'_scaled.png')

    return x


def preprocessImage(x, mean, std):
    """Preprocess image by z score normalization.
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
    x = np.clip(x,0, 1400)
    x = np.subtract(x, mean)
    x = np.divide(x, std)
    return x