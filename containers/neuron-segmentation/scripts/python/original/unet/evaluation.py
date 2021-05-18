"""This script evaluates the performance of a pretrained unet
"""

#%% Imports
import os
from random import shuffle
import sys
from importlib import reload

import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf

sys.path.append('/nrs/dickson/lillvis/temp/linus/GPU_Cluster/modules/')
import Dataset3D
import tilingStrategy
import visualization

sys.path.append('..')
import metrics

import model
import utilities


#%% Script variables

# Set verbosity of script 
silent = True
# where to save the evaluation report
saveDir = '/nrs/dickson/lillvis/temp/linus/GPU_Cluster/20210112_Augumentation/affine/evaluation/'
if not os.path.exists(saveDir):
    os.makedirs(saveDir)

# Location of the evaluation datasets
dataset_path = '/nrs/dickson/lillvis/temp/linus/GPU_Cluster/20210112_ThesisExperiments/evaluation_dataset.h5'
# Number of examples to use for evaluation
n_val = 40
# List of entry keys defining the evaluation subset (overrides) n_val if specified.
subset = None

# Location of the pretrained model file
model_path = '/nrs/dickson/lillvis/temp/linus/GPU_Cluster/20210112_Augumentation/affine/augumentation_affine30.h5'

# visualize evaluation examples once every visualization_fraction instances
visualization_intervall = 10

# wheter to occlude parts of the image
occlude = False
occlusion_size = 40

# Output size of the unet. (Input size should be compatible with dataset)
output_shape = (132,132,132)

#%% Script Setup

# small print helper function
def printv(*args):
    if not silent:
        print(*args)

eval_report = {} # create dictonary for evaluation report

# Fix for tensorflow-gpu issues that I found online... (don't ask me what it does)


gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
  try:
    # Currently, memory growth needs to be the same across GPUs
    for gpu in gpus:
      tf.config.experimental.set_memory_growth(gpu, True)
    logical_gpus = tf.config.experimental.list_logical_devices('GPU')
    printv(len(gpus), "Physical GPUs,", len(logical_gpus), "Logical GPUs")
  except RuntimeError as e:
    # Memory growth must be set before GPUs have been initialized
    printv(e)

#%% Load evaluation data

dataset = Dataset3D.Dataset(dataset_path, append = False, readonly=True) # The Dataset3D class handles all file level i/o operations
printv('Dataset {} contains {} records'.format(dataset, len(dataset)))
printv('Dataset metadata entries:')
printv(dataset.getAttributes().keys())

if subset is None:
    # get a list of all records in the database
    entries = list(dataset.keys())
    # shuffle entries
    np.random.shuffle(entries)
    # Make a train test split and retrieve a callable -> that produces a generator -> that yields the recods specified by the key list in random order
    subset = entries[:n_val]
else:
    n_val = len(subset) # adjust number of validation examples to the provided list
printv('Using random subset of size {} :'.format(n_val)+ str(subset))
eval_report['evaluation dataset'] = dataset_path
eval_report['model file'] = model_path
eval_report['number of evaluation examples'] = n_val
eval_report['evaluation example keys'] = subset
# use the random subset generated above or reuse the keys of another run for comparability
samples = dataset.getGenerator(subset, shuffle=False)

#%% Build tf data input pipeline

# Instantiate tf Datasets from the generator producing callables, specify the datatype and shape of the generator output
validationset_raw = tf.data.Dataset.from_generator(samples, 
    output_types=(tf.float32, tf.int32),
    output_shapes=(tf.TensorShape([220,220,220]),tf.TensorShape([220,220,220])))
    # each entry is preprocessed by passing it through this function

# EXPECT normalized image chanel !
# EXPECT binarized masks
def preprocess(x,y):
    x = tf.expand_dims(x, axis=-1) # The unet expects the input data to have an additional channel axis.
    y = tf.one_hot(y, depth=2, dtype=tf.int32) # one hot encode to int tensor
    return x, y

# Crop
def crop_mask(x, y, mask_size=output_shape):
    # apply crop after batch dimension is added x and y have (b,x,y,z,c) format while mask size has (x,y,z) format => add offset of 1
    crop = [(y.shape[d+1]-mask_size[d])//2 for d in range(3)]
    #keras implicitly assumes channels last format
    y = tf.keras.layers.Cropping3D(cropping=crop)(y)
    return x, y

# Occlude parts of the input image
def occlude(x,y):
    x,y = utilities.tf_occlude(x, y, occlusion_size = occlusion_size)
    return x,y


validationset = validationset_raw.map(preprocess)

# Add occlusions if specified by the user
if occlude:
    validationset = validationset.map(occlude)

validationset = validationset.batch(1).map(crop_mask).prefetch(1)
validationset_iter = iter(validationset)

#%% Reload a pretrained model

#model_path = 'C:\\Users\\Linus Meienberg\\Google Drive\\Janelia\\ImageSegmentation\\3D Unet\\VVDMaskNetwork\\VVDOvermask_0922'

# Restore the trained model. Specify where keras can find custom objects that were used to build the unet
unet = tf.keras.models.load_model(model_path, compile=False,
                                  custom_objects={"InputBlock" : model.InputBlock,
                                                    "DownsampleBlock" : model.DownsampleBlock,
                                                    "BottleneckBlock" : model.BottleneckBlock,
                                                    "UpsampleBlock" : model.UpsampleBlock,
                                                    "OutputBlock" : model.OutputBlock})

# Compile the model using dummy values for loss function (evaluation loss is not reported)
unet.compile(loss = model.weighted_cce_dice_loss(class_weights=[1,5], dice_weight=0.3),
             metrics=['acc', metrics.MeanIoU(num_classes=2, name='meanIoU')])

#%% Evaluate model

# evaluate keras metrics
loss, accuracy, iou = unet.evaluate(validationset, verbose=0)
eval_report['pixel wise accuracy'] = accuracy
eval_report['mean IoU'] = iou

# set up lists to store ground truth and prediction values
y_true, y_pred = [],[]
# set up list to hold precision, recall curves
thresholds = np.linspace(0,1,21)
precision_curves, recall_curves = [],[]
auc_scores = []
# get an new iterator on the validation set
validationset_iter = iter(validationset)
for n, (im, msk) in enumerate(validationset_iter):
    # get prediction for image
    pred = unet.predict(im)
    # convert to pseudoprobability
    pred = tf.nn.softmax(pred, axis=-1)
    y_pred.append(pred.numpy()[0,...,1])
    # get binary y_true from mask
    y_true.append(msk.numpy()[0,...,1])

    # Calculate binary prediction performance on aggregated model output
    # Doing this every 20 steps limits the amount of RAM used to store y_true / y_pred
    if (n+1)%20==0 or n+1==n_val:
        y_true = np.stack(y_true, axis=0)
        y_pred = np.stack(y_pred, axis=0)
        batch_precision, batch_recall, batch_thresholds, batch_auc = metrics.precisionRecall(y_true,y_pred)
        # Extract values at relevant thresholds
        precision_curve, recall_curve = [],[]
        for t in thresholds:
            index = np.sum( batch_thresholds < t )
            precision_curve.append(batch_precision[index])
            recall_curve.append(batch_recall[index])
        # Add curves and auc of batch to list
        precision_curves.append(precision_curve)
        recall_curves.append(recall_curve)
        auc_scores.append(batch_auc)
        # Clear y_true / y_pred
        y_true, y_pred = [], []

    ## visualize some training examples and the unet ouput
    if (n+1)%visualization_intervall==0:
        # set up save path
        savePath = saveDir+'val_{}'.format(n)
        # select tensor slices
        im = im.numpy()[0,44:176,44:176,44:176,0] # crop image and convert to (x,y,z) format (im is z normalized)
        msk = msk.numpy()[0,...,1] # extract fist channel of mask for vis
        pred = pred.numpy()[0,...,1]
        # create visualization
        visualization.showZSlices(im ,channel=None,vmin=0,vmax=1, n_slices=6, title='Input Image', savePath=savePath+'_0_im.png')
        visualization.showZSlices(msk,channel=None,vmin=0,vmax=1, n_slices=6, title='True Mask', savePath=savePath+'_1_true.png')
        visualization.showZSlices(pred,channel=None,vmin=0,vmax=1, n_slices=6, title='Predicted Mask Pseudoprobability', savePath=savePath+'_2_pred.png')
        mask_overlay = visualization.makeRGBComposite(r=msk[...,np.newaxis], g=pred[...,np.newaxis] ,b=None, gain=1.) # Make an overlay of the true mask (red) and the predicted mask (green)
        visualization.showZSlices(mask_overlay,n_slices=6, mode='rgb', title='True Mask @red Prediction @green', savePath=savePath+'_3_overlay.png')
        #mask_overlay = visualization.makeRGBComposite(r=msk[...,np.newaxis], g=pred[...,np.newaxis] ,b=im[...,np.newaxis], gain=(1.,1.,0.5)) # Make an overlay of the true mask (red) and the predicted mask (green)
        #visualization.showZSlices(mask_overlay,n_slices=6, mode='rgb', title='True Mask @red Prediction @green Image @blue')
    printv('evaluated {}/{}'.format(n,n_val)) # give
    
plt.figure()
for recall , precision in zip(recall_curves, precision_curves):
    plt.plot(recall,precision)
plt.title('Binary Classification Performance on batches')
plt.xlabel('Recall')
plt.ylabel('Precision')
plt.xlim([0,1.01])
plt.ylim([0,1.01])
plt.savefig(saveDir+'PrecisionRecallBatch.png')

# Calculate mean curves and mean auc
recall_mean = np.mean( np.array(recall_curves) , axis = 0)
precision_mean = np.mean( np.array(precision_curves) , axis = 0)
auc_mean = np.mean(np.array(auc_scores))

plt.figure()
plt.plot(recall_mean,precision_mean)
plt.title('Binary Classification Performance')
plt.xlabel('Recall')
plt.ylabel('Precision')
plt.xlim([0,1.01])
plt.ylim([0,1.01])
plt.text(0.1,0.1,'roc auc : {}'.format(auc_mean))
plt.savefig(saveDir+'PrecisionRecall.png')

summary = '\nthreshold precision recall\n'
for i,t in enumerate(thresholds):
    summary  = summary + '{:.2f} {:.2f} {:.2f}'.format(t,precision_mean[i],recall_mean[i]) + '\r\n'
printv(summary)
eval_report['binary classification performance'] = summary
eval_report['mean auc'] = auc_mean

#%% Write evaluation Report
reportFile = open(saveDir+'report.txt','w')

for key in eval_report.keys():
    reportFile.write(str(key)+' : ')
    reportFile.write(str(eval_report[key])+'\r\n')
reportFile.close()

# %%
