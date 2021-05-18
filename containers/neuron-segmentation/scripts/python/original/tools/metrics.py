"""A collection of evaluation metrics to assess the performance in 3D image segmentation tasks

   Linus Meienberg
   July 2020
"""
#%%
import numpy as np
import tensorflow as tf
from tensorflow.keras import backend as K

def intersection_over_union(true_mask, predicted_mask, num_classes=2, smooth=1):
    """Calculate the intersection over union metric for two sparse segmentation masks.

    Parameters
    ----------
    true_mask : tensor
        true segmentation mask in format (b,x,y,z,1) or (b,x,y,z)
    predicted_mask : tensor
        predicted segmentation mask in format (b,x,y,z,1) or (b,x,y,z)
    num_classes : int, optional
        the number of classes present in the segmentation mask, by default 2
    smooth : float, optional
        constant added to intersection and union. Smooths iou score for very sparse classes.

    Returns
    -------
    list
        the iou for each predicted class
    """
    if true_mask.shape[-1] == 1:
        true_mask = true_mask[...,0]
    if predicted_mask.shape[-1] == 1:
        predicted_mask = predicted_mask[...,0]

    assert true_mask.shape == predicted_mask.shape, 'segmentation masks do not match: shapes {} and {}'.format(true_mask.shape,predicted_mask.shape)

    iou = []
    # calculate iou for every class
    for c in range(num_classes):
        y_true = true_mask == c
        y_pred = predicted_mask == c
        intersection = np.sum(y_true & y_pred)
        union = np.sum(y_true) + np.sum(y_pred) - intersection
        iou.append((intersection+smooth)/(union+smooth))
    
    return iou


class MeanIoU(tf.keras.metrics.MeanIoU):
    def __init__(self, num_classes, name=None, dtype=None):
        super().__init__(num_classes, name, dtype)

    def update_state(self, y_true, y_pred, sample_weight=None):
        y_true = K.cast(K.argmax(y_true,axis=-1), tf.int32)
        y_pred = K.cast(K.argmax(y_pred,axis=-1), tf.int32)
        return super().update_state(y_true,y_pred,sample_weight)


def keras_IoU(num_classes = 2, smooth=1):
    """Return a callable / metric that returns the mean IoU for a semantic segmentation task.

    Parameters
    ----------
    num_classes : int, optional
        the number of classes, by default 2
    smooth : int, optional
        a constant used to smooth IoU values in very rare cases, by default 1
    """
    
    def IoU(y_true, y_pred):
        """Returns the mean IoU for a semantic segmentation task.

        Parameters
        ----------
        y_true : tf.Tensor
            a one hot encoded categorical ground thruth segmentation mask (x,y,z,c)
        y_pred : tf.Tensor
            multichannel logit predictions for each category 
        """
        # convert the model output to a sparse segmentation mask (use argmax on channel axis since argmax on logits and pseudoprobabilities is the same)
        mask_pred = K.argmax(y_pred, axis=-1)
        mask_true = K.argmax(y_true, axis=-1)
        # Sum up the intersection over union score for each class
        iou = 0
        for c in range(num_classes):
            # Binary arrays (class present / absent at each pixel) for ground thruth and prediction
            target = K.cast(mask_true == c, tf.bool)
            prediction = K.cast(mask_pred == c, tf.bool)
            # Intersection is element wise and
            intersection = K.sum(tf.logical_and(target, prediction))
            # Union is sum minus intersection
            union = K.sum(target) + K.sum(prediction) - intersection
            iou += ((intersection+smooth)/(union+smooth))

        # divide by number of classes to get mean class IoU
        return iou /num_classes

    return IoU
# %% Tools to evaluate binary prediction, ground truth pairs
from sklearn.metrics import precision_recall_curve, roc_auc_score

def precisionRecall(y_true: np.ndarray, y_pred: np.ndarray) -> tuple:
    # We expect y_true to be a binary ground truth tensor (b,x,y,z) holding entries 0/1
    # y_pred is a probability map for the object channel (p(pixel==1)) in format (b,x,y,z)
    precision, recall, thresholds = precision_recall_curve(y_true.flat, y_pred.flat, pos_label = 1)
    auc = roc_auc_score(y_true.flat,y_pred.flat)
    return precision, recall, thresholds, auc
# %%
