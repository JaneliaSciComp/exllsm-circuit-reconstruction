"""
Tools for visualization of 3D image data

Linus Meienberg
June 2020
"""
import numpy as np
import scipy

import matplotlib.pyplot as plt

if (False):
    from mayavi import mlab

    # %% 3D Visualization tools
    def show3DImage(image_tensor, channel=0, mode = 'image', newFigure = True, **kwargs):
        """Visualize a single channel 3D image using mayavi's isosurface plot

        Parameters
        ----------
        image_tensor : tensor
            tensor of rank 4 in format (x,y,z,c)
        channel : int, optional
            the channel to visualize, by default 0
        mode : str, optional
            the visualization mode. Set to {'image','mask'}
        """
        if mode is 'image':
            n_contours = 4
            transparent = True
        elif mode is 'mask':
            n_contours = 10
            transparent = False
        else:
            raise ValueError('Visualization mode undefined')
        if newFigure:
            mlab.figure(size=(500,500))
        plot = mlab.contour3d(image_tensor[...,channel], contours = n_contours, transparent=transparent, **kwargs)
        return mlab.gcf()

    def show3DDisplacementField(dx, dy, dz, mask_points=2000, scale_factor=50., newFigure=True, **kwargs):
        """Visualize a 3D vector field using mayavi.

        Parameters
        ----------
        dx, dy, dz : tensor
            rank three tensors holding the x,y,z components of the 3D vector field.
        mask_points : int, optional
            How many vectors to mask out for each vector displayed, by default 2000
        scale_factor : float, optional
            factor by which arrows are scaled for displaying the vector field, by default 50

        Returns
        -------
        mlab.figure
            Mayavi plot according to the running backend.
        """
        if newFigure:
            mlab.figure(size=(500,500))
        plot = mlab.pipeline.vector_field(dx, dy, dz)
        mlab.pipeline.vectors(plot, mask_points=mask_points, scale_factor=scale_factor, **kwargs)
        return mlab.gcf()
    # %%

    def showCutplanes(image_tensor, channel=0, hint = True, newFigure = True, **kwargs):
        """Shows an interactive plot with two movable cutplanes through a 3d volume

        Parameters
        ----------
        image_tensor : tensor
            tensor of rank 4 in format (x,y,z,c)
        channel : int, optional
            the channel to visualize, by default 0
        hint : bool, optional
            wheter to show a faint outline of the 3d volume, by default True
        newFigure : bool, optional
            wheter to create a new figure in mlab , by default True

        Returns
        -------
        [type]
            [description]
        """
        if newFigure:
            mlab.figure(size=(700,700))
        s = image_tensor[...,channel]
        src = mlab.pipeline.scalar_field(s)
        mid_x = s.shape[0] // 2
        mid_y = s.shape[1] // 2
        # numpy : np.ptp() = max()-min()
        if hint:
            mlab.pipeline.iso_surface(src, contours = [np.min(s)+0.8*s.ptp(), ], opacity = 0.3, **kwargs)
        mlab.pipeline.image_plane_widget(src,
                                        plane_orientation = 'x_axes',
                                        slice_index = mid_x, **kwargs)
        mlab.pipeline.image_plane_widget(src,
                                        plane_orientation = 'y_axes',
                                        slice_index = mid_y, **kwargs)
        mlab.outline()
        return mlab.gcf()


def showLogitDistribution(prediction, savePath=None):
    """Shows the distribution of the predicted logit values for each channel in a segmentation mask.

    Parameters
    ----------
    prediction : segmentation mask
        tensor with format (...,x,y,z,c) where each of the n_classes channels stores the logits for that pixel to belong to that class.
    """
    
    plt.figure()
    
    data_range = np.linspace(np.min(prediction), np.max(prediction), 10)

    for c in range(prediction.shape[-1]):
        hist, bins = np.histogram(prediction[...,c], bins=data_range)
        width = 0.7 * (bins[1] - bins[0])
        center = (bins[:-1] + bins[1:]) / 2
        plt.bar(center, hist, align='center', width=width, label='channel ' + str(c))

    plt.title('Distribution of logits per channel in the prediction')
    plt.xlabel('Predicted logit class probabilities')
    plt.ylabel('count')
    plt.legend()
    #plt.show()
    if not savePath is None:
        plt.savefig(savePath)

def showZSlices(volume, channel=0, n_slices = 4, title=None, mode='gray', plot_size=4, vmin=None, vmax=None, savePath=None):
    """Shows a series of slices through a 3d volume at different z levels.

    Parameters
    ----------
    volume : image tensor
        rank 4 tensor with shape (x,y,z,c) or (z,x,y) if mode is 'h5'
    channel : int, optional
        the channel to visualize, by default 0
        if None is specified, a rank 3 tensor with shape (x,y,z) is assumed
    n_slices : int, optional
        the number of z slices to show, by default 4
    title : str, optional
        the titel of the plot, by default None
    mode : str, optional
        'rgb' if the image has three channels that form an rgb image
        'gray' if only the selected channel should be rendered in grayscale (default)
        'h5' if a h5 image tensor is accessed directly (one channel with format (z,x,y))
    plot_size : int, optional
        [description], by default 4
    vmin : [type], optional
        [description], by default None
    vmax : [type], optional
        [description], by default None

    Raises
    ------
    ValueError
        [description]
    """
    # volume is expected to be in format (x,y,z,c)
    z_extent = volume.shape[2]
    if mode is 'h5':
        z_extent = volume.shape[0]
    slice_z = np.linspace(0,z_extent,n_slices+2).astype(int)[1:-1] # n_slices+2 evently spaced planes, leave first and last one out

    fig, axs = plt.subplots(1, n_slices, figsize=(plot_size*n_slices+2,plot_size+0.25))
    fig.suptitle(title, fontsize=15)

    for i, ax in enumerate(axs):
        z = slice_z[i]
        ax.set_title('slice @ z='+str(z))
        if mode is 'rgb':
            ax.imshow(volume[:,:,z,:])
        elif mode is 'gray':
            if not channel is None:
                ax.imshow(volume[:,:,z,channel], cmap='Greys', vmin=vmin, vmax=vmax)
            else:
                ax.imshow(volume[:,:,z], cmap='Greys', vmin=vmin, vmax=vmax)
        elif mode is 'h5':
            ax.imshow(volume[z,:,:], cmap='Greys',  vmin=vmin, vmax=vmax)
        else:
            raise ValueError('Mode not implemented')

    #plt.show()
    if not savePath is None:
        plt.savefig(savePath)

def makeRGBComposite(r,g,b,gain=(1,1,1)):
    """combine three tensors of shape (...,1) to a three channel composite of shape (...,3) where each channel is multiplied by the corresponding gain

    Parameters
    ----------
    r,g,b : image tensor
        tensor of format (...,1)
    gain : tuple, optional
        the gain per channel, by default (1,1,1)

    Returns
    -------
    image tensor    
        three channel composite
    """
    if type(gain) is tuple:
        assert len(gain) is 3, 'specify gain for 3 channels (g_r,g_g,g_b)'
    else:
        gain = (gain,gain,gain)

    assert not r is None, 'specify at one input channel in r'
    if g is None:
        g = np.zeros_like(r)
    if b is None:
        b = np.zeros_like(g)

    composite = r*[1,0,0] + g*[0,1,0] + b*[0,0,1]
    composite *= gain
    return composite
    
def showProjections(volumes: list, axis = -1, channel=None, mode='max', title=None, size=4, savePath=None, **kwargs):
    """Plot a projected view of a list of 3d volumes

    Parameters
    ----------
    volumes : list
        a list of 3d volumes in (x,y,z) or optionally (x,y,z,c)
    axis : int, optional
        the axis along which the volumes are projected on the image plane, by default -1
    channel : int , optional
        the index of the channel to visualize, by default None -> (x,y,z) format
    mode : str, optional
        the projection mode either 'max' or 'mean', by default 'max'
    title : str, optional
        The plot title, by default None
    """
    # Set up a figure with a plot for each volume in the list
    fig, axs = plt.subplots(1, len(volumes), figsize=(2+size*len(volumes),size))
    fig.suptitle(title)

    for i, ax in enumerate(axs):
        # pick the ith volume and a channel of one is specified
        if not channel is None:
            volume = volumes[i][...,channel]
        else:
            volume = volumes[i]
        # use max or mean projection according to mode
        if mode is 'max':
            projected = np.max(volume, axis=axis)
        else:
            projected = np.mean(volume, axis=axis)
                
        ax.imshow(projected, **kwargs)
    
    #plt.show()
    if not savePath is None:
        plt.savefig(savePath)


# %%
