"""Implementation of a Unet architecture for 3D microscopy data

The original Unet architecure: "U-Net: Convolutional Networks for Biomedical
Image Segmentation" by Ronneberger et al.

3D Implementation as demonstrated in "3D U-Net: Learning Dense Volumetric
Segmentation from Sparse Annotation" by Ozgün et al. (Lift operations to 3D, different scheme for expansion and contraction of the number of feature channels)

Implementation details inspired by the model code a the NVIDIA Deep Learning Example [UNet_Medical](https://github.com/NVIDIA/DeepLearningExamples/tree/master/TensorFlow2/Segmentation/UNet_Medical)

"""

#NOTE If layers receive multiple input tensors when called, pass them as a list in the inputs argument

#%%
import tensorflow as tf 
import tensorflow.keras.backend as K
import numpy as np

#%% CONSTRUCTION OF UNET by subclassing model

class Unet(tf.keras.Model):

    def __init__(self, name= 'Unet', n_blocks= 2, initial_filters= 32, **kwargs):
        super(Unet, self).__init__(name=name, **kwargs)

        # instantiate unet blocks
        filters = initial_filters
        self.input_block = InputBlock(initial_filters= filters) 
        filters *= 2 # filters are doubled in second conv operation
        

        self.down_blocks = []
        for index in range(n_blocks):
            self.down_blocks.append(DownsampleBlock(filters, index+1))
            filters *= 2  # filters are doubled in second conv operation


        self.bottleneck_block = BottleneckBlock(filters)
        filters *= 2  # filters are doubled in second conv operation

        self.up_blocks = []
        for index in range(n_blocks)[::-1]:
            filters = filters//2  # half the number of filters in first convolution operation
            self.up_blocks.append(UpsampleBlock(filters, index+1))

        filters = filters//2 # half the number of filters in first convolution operation
        self.output_block = OutputBlock(filters, n_classes=2)

    def call(self, inputs, training=True):
        skip = []

        out, residual = self.input_block(inputs)
        skip.append(residual)

        for down_block in self.down_blocks:
            out, residual = down_block(out)
            skip.append(residual)

        out = self.bottleneck_block(out, training)

        for up_block in self.up_blocks:
            out = up_block([out, skip.pop()])

        out = self.output_block([out, skip.pop()])

        return out

#%% construct model via sequential API

def build_unet(input_shape, n_blocks= 2, initial_filters= 32, useSoftmax=False, bottleneckDropoutRate=0.2, spatialDropout=False, spatialDropoutRate = 0.2, **kwargs):
    # Create a placeholder for the data that will be fed to the model
    inputs = tf.keras.layers.Input(shape=input_shape)
    x = inputs
    skips = []

    # instantiate unet blocks
    filters = initial_filters

    # Thread through input block
    x, residual = InputBlock(initial_filters=filters)(x)
    skips.append(residual)
    filters *= 2 # filters are doubled in second conv operation
    
    for index in range(n_blocks):
        x, residual = DownsampleBlock(filters=filters, index=index+1,
                                    spatialDropout=spatialDropout,
                                    spatialDropoutRate=spatialDropoutRate )(x)
        skips.append(residual)
        filters *= 2  # filters are doubled in second conv operation

    x = BottleneckBlock(filters, dropoutRate=bottleneckDropoutRate)(x)
    filters *= 2  # filters are doubled in second conv operation

    for index in range(n_blocks)[::-1]:
        filters = filters//2  # half the number of filters in first convolution operation
        x = UpsampleBlock(filters, index+1)([x, skips.pop()])

    filters = filters//2 # half the number of filters in first convolution operation
    x = OutputBlock(filters, n_classes=2)([x,skips.pop()])

    if useSoftmax:
        print('Model predicts softmax pseudoprobabilities')
        x = tf.keras.layers.Softmax(axis=-1)(x)
    
    unet = tf.keras.Model(inputs=inputs, outputs=x)
    return unet

#%%IMPLEMENTATION OF UNET BLOCKS

""" When tf.keras.Model is subclassed:

Use the constructor method __init__ to instantiate the layers as variables of the model instance
layer parameters are specified but the input shape is passed in the call function


define the method call() providing the input arguments for evaluation of the model
pass them stepwise through the model layers
return the output of the block / model

"""

def _crop_concat(input, residual_input):
    """Concatenate two 3D images after cropping residual input to the size of input.
    The last (channel) dimension of the tensors is joined. The difference of the input sizes must be even to allow for a central crop.

    Parameters
    ----------
    input : tf.Tensor   
        3d image tensor in the format (batch, x, y, z, channels)
    residual_input : tf.Tensor
        3d image tensor in the format (batch, x, y, z, channels)

    Returns
    -------
    tf.Tensor
        Cropped and conatenated 3d image tensor of the same shape as input
    """
    crop = [(residual_input.shape[d]-input.shape[d])//2 for d in range(1,4)]
    #print('crop = {}'.format(crop))
    x = tf.keras.layers.Cropping3D(cropping=crop)(residual_input)
    x = tf.keras.layers.Concatenate(axis=-1)([input, x])
    return x 


class InputBlock(tf.keras.layers.Layer):
    #TODO a class that implements a keras model (can be used as building block) and bundles the input operations of the Unet 
    def __init__(self, initial_filters=8, **kwargs):
        """Unet Input Block

        Performs:
        Convolution of input image with #initial_filters
        Convolution doubling the #filters
        Divert output for skip connection
        Downsample by Max Pooling

        Parameters
        ----------
        initial_filters : int
            the number of initial convolution filters. Grows exponentially with model depth.
        """
        super(InputBlock, self).__init__(**kwargs)
        self.initial_filters = initial_filters
        # Instantiate Block 
        with tf.name_scope('input_block'):
            self.conv1 = tf.keras.layers.Conv3D(filters = initial_filters,
                                                kernel_size=(3,3,3),
                                                activation = tf.nn.relu)
            self.conv2 = tf.keras.layers.Conv3D(filters= initial_filters*2,
                                                kernel_size= (3,3,3),
                                                activation=tf.nn.relu)
            self.maxpool = tf.keras.layers.MaxPool3D(pool_size=(2,2,2), strides= (2,2,2))

    def call(self, inputs):
        x = self.conv1(inputs)
        x = self.conv2(x)
        out = self.maxpool(x)
        return out, x # Provide full res intermediate x for skip connection

    def get_config(self):
        config = super(InputBlock, self).get_config()
        config.update({"initial_filters" : self.initial_filters})
        return config

class DownsampleBlock(tf.keras.layers.Layer):
    """Unet Downsample Block

    Perform two convolutions with a specified number of filters.
    Double the amount of filters in the second convolution.
    Divert output for skip connection.
    Downsample by max pooling for lower level input.
    """
    def __init__(self, filters, index, spatialDropout=False, spatialDropoutRate=0.2, **kwargs):
        """Unet Downsample Block

        Parameters
        ----------
        filters : int
            Number of filters in the first convolution
        index : int
            index / depth of the block
        spatialDropout : wheter to use spatial Dropout (randomly sets entire feature maps to 0)
        """
        super(DownsampleBlock,self).__init__(**kwargs)
        with tf.name_scope('downsample_block_{}'.format(index)):
            self.index = index
            self.filters = filters
            self.spatialDropout = spatialDropout
            if spatialDropout:
                self.spatialDropout = tf.keras.layers.SpatialDropout3D(rate=spatialDropoutRate)
            self.conv1 = tf.keras.layers.Conv3D(filters=filters,
                                        kernel_size = (3,3,3),
                                        activation=tf.nn.relu)
            self.conv2 = tf.keras.layers.Conv3D(filters=filters*2,
                                        kernel_size = (3,3,3),
                                        activation=tf.nn.relu)
            self.maxpool = tf.keras.layers.MaxPool3D(pool_size=(2,2,2), strides = (2,2,2))

    def call(self, inputs):
        x = inputs
        if self.spatialDropout:
            x = self.spatialDropout(x)
        x = self.conv1(x)
        if self.spatialDropout:
            x = self.spatialDropout(x)
        x = self.conv2(x)
        out = self.maxpool(x)
        return out, x

    def get_config(self):
        config = super(DownsampleBlock, self).get_config()
        config.update({"filters" : self.filters, "index" : self.index})
        return config

class BottleneckBlock(tf.keras.layers.Layer):
    """Central / Bottleneck Block of Unet Architecture
    
    Perform two unpadded convolutions before upsampling to begin the reconstructing pathway
    Include a Dropout layer for training the network
    """
    def __init__(self, filters, dropoutRate=0.2, **kwargs):
        """Unet Bottleneck Block

        Parameters
        ----------
        filters : int
            number of filters in the first convolution operation.
        """
        super(BottleneckBlock,self).__init__(**kwargs)
        with tf.name_scope('bottleneck_block'):
            self.filters = filters
            self.conv1 = tf.keras.layers.Conv3D(filters=filters,
                                        kernel_size = (3,3,3),
                                        activation=tf.nn.relu)
            self.conv2 = tf.keras.layers.Conv3D(filters=filters*2,
                                        kernel_size = (3,3,3),
                                        activation=tf.nn.relu)
            self.dropout = tf.keras.layers.Dropout(rate=dropoutRate)
            self.upsample = tf.keras.layers.Conv3DTranspose(filters=filters*2,
                                                            kernel_size = (2,2,2),
                                                            strides= (2,2,2))
    
    def call(self, inputs, training):
        x = self.conv1(inputs)
        x = self.conv2(x)
        x = self.dropout(x, training=training) # Don't use dropout for predictions outside training
        x = self.upsample(x)
        return x

    def get_config(self):
        config = super(BottleneckBlock, self).get_config()
        config.update({"filters" : self.filters})
        return config
    
class UpsampleBlock(tf.keras.layers.Layer):
    """Unet Upsample Block

    Crop and concatenate skip input of corresponding depth to input from layer below.
    Perform two convolutions with a specified number of filters and upsample.
    The first convolution operation reduces the number of feature channels accoring to the current depth in the network

    """

    def __init__(self, filters, index, **kwargs):
        """Upsample Block if Unet Architecture

        Parameters
        ----------
        filters : int 
            Number of feature channels in the convolution operation.
        index : int
            index / depth of the block
        """
        super(UpsampleBlock, self).__init__(**kwargs)
        with tf.name_scope('upsample_block_{}'.format(index)):
            self.index = index
            self.filters = filters
            self.conv1 = tf.keras.layers.Conv3D(filters=filters,
                                        kernel_size = (3,3,3),
                                        activation=tf.nn.relu)
            self.conv2 = tf.keras.layers.Conv3D(filters=filters,
                                        kernel_size = (3,3,3),
                                        activation=tf.nn.relu)
            self.upsample = tf.keras.layers.Conv3DTranspose(filters=filters,
                                                            kernel_size=(2,2,2),
                                                            strides=(2,2,2))

    def call(self, inputs):
        x = _crop_concat(input=inputs[0], residual_input=inputs[1])
        x = self.conv1(x)
        x = self.conv2(x)
        x = self.upsample(x)
        return x

    def get_config(self):
        config = super(UpsampleBlock, self).get_config()
        config.update({"filters" : self.filters, "index" : self.index})
        return config

class OutputBlock(tf.keras.layers.Layer):
    """Unet Ouput Block

    Perform three unpadded convolutions.
    The last convolution operation reduces the output volume to the desired number of output channels for classification.
    The model returns raw logits.

    """
    def __init__(self, filters,  n_classes, **kwargs):
        super(OutputBlock, self).__init__(**kwargs)
        with tf.name_scope('output_block'):
            self.filters = filters
            self.n_classes = n_classes
            self.conv1 = tf.keras.layers.Conv3D(filters=filters,
                                        kernel_size = (3,3,3),
                                        activation=tf.nn.relu)
            self.conv2 = tf.keras.layers.Conv3D(filters=filters,
                                        kernel_size = (3,3,3),
                                        activation=tf.nn.relu)
            self.conv3 = tf.keras.layers.Conv3D(filters=n_classes,
                                                kernel_size=(1,1,1),
                                                activation = None)


    def call(self, inputs):
        x = _crop_concat(input=inputs[0], residual_input=inputs[1])
        x = self.conv1(x)
        x = self.conv2(x)
        x = self.conv3(x)
        return x

    def get_config(self):
        config = super(OutputBlock, self).get_config()
        config.update({"filters" : self.filters, "n_classes" : self.n_classes})
        return config


def weighted_cce_dice_loss(class_weights, dice_weight=1, fromLogits=True):
    dice_weight = tf.keras.backend.variable(dice_weight)
    cce = weighted_categorical_crossentropy(class_weights, fromLogits)
    dice = soft_dice_loss(fromLogits)
    
    def cce_dice(y_true, y_pred):
        return (1-dice_weight)*cce(y_true,y_pred) + dice_weight*dice(y_true,y_pred)

    return cce_dice

# %%

def weighted_categorical_crossentropy(class_weights, fromLogits=True):
    # As seen on GitHub https://gist.github.com/wassname/ce364fddfc8a025bfab4348cf5de852d by wassname
    weights = tf.keras.backend.variable(class_weights, dtype=tf.float32)
    num_classes = len(class_weights)

    def loss(y_true, y_pred):
        # Keras defines the following shapes for the inputs to the loss function:
        # y_true => (batch_size, d0, ..., dN) for ground truth
        # y_pred => (batch_size, d0, ..., dN) for predicted values
        # where dN is a channel dimension whose length is the number of classes c
        
        # deduce weights for batch samples based on their true label (tensor of the same shape as onehot_labels with the corresponding class weight as value)
        voxel_weights = tf.reduce_sum(weights * K.cast(y_true, tf.float32), axis=-1) # reduce along last axis( (c,) * (b,x,y,z,c) ) -> (b,x,y,z)

        # compute a tensor with the unweighted cross entropy loss
        unweighted_loss = tf.keras.losses.categorical_crossentropy(y_true,y_pred, from_logits=fromLogits) #(b,x,y,z)
        weighted_loss = unweighted_loss * voxel_weights # (b,x,y,z) * (b,x,y,z) broadcasts the second array such that each channel is multiplied by it's weight

        return tf.reduce_mean(weighted_loss, axis=[1,2,3]) #(b,)
    
    return loss


def soft_dice_loss(fromLogits= True):
    """
    Soft dice loss is derived from the dice score. 
    It measures the overlap between the predicted and true mask regions for each channel.
    Dice loss penalizes low confidence predictions in the ground truth region and high confidence predictions outside of it.

    Wrapper for Jeremy Jordany implementation.

    Parameters
    ----------
    y_true : tensor with shape (...,1)
        ground truth integer segmentation mask
    y_pred : tensor with shape (...,c)
        raw logit predictions of the model

    Returns
    -------
    callable   
        the averaged soft dice loss
    """
    def loss(y_true: tf.Tensor , y_pred:tf.Tensor ):
        ohe_true = K.cast(y_true, tf.float32)
        if fromLogits:
            # apply softmax to logits
            y_pred = K.softmax(y_pred, axis=-1)
        return soft_dice(ohe_true,y_pred)

    return loss

# %%
def soft_dice(y_true, y_pred, epsilon=1e-6):
    ''' 
    This code adapted from [Jeremy Jordan](https://www.jeremyjordan.me/semantic-segmentation/) 

    Soft dice loss calculation for arbitrary batch size, number of classes, and number of spatial dimensions.
    Assumes the `channels_last` format.
  
    # Arguments
        y_true: b x X x Y( x Z...) x c One hot encoding of ground truth
        y_pred: b x X x Y( x Z...) x c Network output, must sum to 1 over c channel (such as after softmax) 
        epsilon: Used for numerical stability to avoid divide by zero errors
    
    # References
        V-Net: Fully Convolutional Neural Networks for Volumetric Medical Image Segmentation 
        https://arxiv.org/abs/1606.04797
        More details on Dice loss formulation 
        https://mediatum.ub.tum.de/doc/1395260/1395260.pdf (page 72)
        
        Adapted from https://github.com/Lasagne/Recipes/issues/99#issuecomment-347775022
    '''
    
    # skip the batch and class axis for calculating Dice score
    axes = tuple(range(1, len(y_pred.shape)-1)) 
    numerator = 2. * K.sum(y_pred * y_true, axes)
    denominator = K.sum(K.square(y_pred) + K.square(y_true), axes)
    
    return 1 - K.mean((numerator + epsilon) / (denominator + epsilon)) # average over classes and batch

"""
#%% Test loss fn 

weights = [2,1]
loss = weighted_categorical_crossentropy(weights)


y_true = np.array([[0,1],[1,0]])[np.newaxis,np.newaxis,np.newaxis,...]
#y_pred = np.array([[0.5,0.5],[0.5,0.5]], np.float32)[np.newaxis,np.newaxis,np.newaxis,...]
y_pred = np.array([[10.,10.],[-10.,10.]], np.float32)[np.newaxis,np.newaxis,np.newaxis,...]

print(tf.nn.softmax(y_pred))

#%% Reference loss -> sum of pixel wise categorical crossentropy in batch
#tf.reduce_sum( tf.keras.losses.categorical_crossentropy(y_true,y_pred, from_logits=True), axis=[1,2,3] )
tf.keras.losses.categorical_crossentropy(y_true,y_pred, from_logits=True)*tf.constant([1.,2.])
# %%
loss(y_true,y_pred)
# %%
"""