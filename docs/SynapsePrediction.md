# Synapse Prediction

Synapse prediction can be run in multiple workflows, depending on the experimental design and data available. When running synapse prediction on large image volumes, the volume is partitioned into sub-volumes. The workflow is run on each sub-volume and reassembled.

See below for details about each workflow:

* Synapse Segmentation: Synaptic structures are detected using a 3D U-Net convolutional neural network.
* Synapse Segmentation Post-processing: Applies image closing, watershed segmentation, optional size filter, and optional colocalization analysis to Synapse Segmentation results. 

The following workflows integrate Synapse Segmentation and Synapse Segmentation Post-processing. 

* Workflow A: Quantifies neuron 1 presynaptic sites and connections from neuron 1 to neuron 2. Requires a presynaptic channel and masks for neuron 1 and neuron 2.
* Workflow B: Quantifies neuron 1 presynaptic sites and connections from neuron 1 to neuron 2. Requires a presynaptic channel, a postsynaptic channel restricted to neuron 2, and a neuron 1 mask.
* Workflow C: Quantifies synaptic sites in a volume. No neuron information is needed, but synaptic sites in a neuron can be quantified. Requires a synaptic channel with optional neuron mask. 

![ExLLSM_synapseworkflows](https://user-images.githubusercontent.com/8125635/133476417-7252c10b-75e8-48a3-af30-05e9d5ae1eb5.png)

Details on methods to generate neurons masks for ExLLSM images can be found in the [Neuron Segmentation](NeuronSegmentation.md) and [Image Processing](ImageProcessing.md) sections.

Each workflow generates intermediate data volumes that are typically stored in the same N5 container but in different N5 datasets. The default N5 container name for intermediate data is specified by the `--working_container` parameter and the parameters for the intermediate datasets with their default values are defined below in the '[Global Optional Parameters](#global_optional_parameters)' section

## Global Required Parameters
These parameters are required for all workflows:

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --pipeline | Pipeline to run. Valid options: presynaptic_n1_to_n2, presynaptic_n1_to_postsynaptic_n2, presynaptic_in_volume, classify_synapses, collocate_synapses |
| --synapse_model | Path to trained synapse model in HDF5 format |

## Global Optional Parameters

Frequently used parameters:

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --output_dir | | Output directory for results |
| --n5_compression | gzip | Compression for N5 volumes |
| --tiff2n5_cpus | 3 | Number of CPUs to use for converting TIFF to n5 |
| --n52tiff_cpus | 3 | Number of CPUs to use for converting n5 to TIFF |
| --unet_cpus | 4 | Number of CPUs to use for each U-NET prediction job |
| --postprocessing_cpus | 3 | Number of CPUs to use for post-processing (e.g. image closing, watershed, quantification, etc.) |
| --volume_partition_size | 512 | Size of sub-volumes to process in parallel. Should be a multiple of --block_size. |
| --presynaptic_stage2_threshold | 300 | Minimum voxel size of each presynaptic site in stage 2 of Workflows A-C. |
| --presynaptic_stage2_percentage | 0.5 | Minimum presynaptic site % overlap with neuron 1 in order to be assigned to neuron 1 in stage 2 of Workflows A-C. Objects below this threshold are removed. 1 = whether the centroid falls within the mask. |
| --postsynaptic_stage2_threshold | 200 | Minimum voxel size of the postsynaptic site in stage 3 of Workflow B. |
| --postsynaptic_stage2_percentage | 0.001 | Minimum synaptic site % overlap with synaptic partner to be assigned a connections. Stage 3 in Workflows A-B (see Workflow specifics below). Objects below this threshold are removed. 1 = whether the centroid falls within the mask. |
| --postsynaptic_stage3_threshold | 400 | Minimum voxel size of each presynaptic site in Stage 4 of Workflow B. |
| --postsynaptic_stage3_percentage | 0.001 | Minimum presynaptic site % overlap with postsynaptic partner to be assigned a connections. Stage 4 in Workflow B. Objects below this threshold are removed. 1 = whether the centroid falls within the mask. |
| --with_pyramid | true | If set it generates the downsampling N5 pyramid for all UNet and Post-processing results. |
| --with_vvd | false | If set it creates VVD files of the UNet and Post-processing results. The base VVD output dir is set by --vvd_output_dir |
| --vvd_output_dir | | base VVD output dir. If this is not set but --with_vvd is set then the default VVD output dir will be the 'vvd' sub-directory under the N5 container dir. The name of the VVD volume is based on the stage that created the volume: 'pre_synapse_seg', or 'pre_synapse_seg_n1', or 'pre_synapse_seg_n1_n2'. The current implementation is an all or nothing - it does not support generating VVD files only for certain stages. |

Rarely used parameters to change the name of working_containers and working_datsets:

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --working_container | `--pipeline` value | The default N5 container used for intermediate data |
| --working_pre_synapse_container | Same as `--working_container` | The N5 pre synaptic container if the input is a TIFF stack; if the pre-synaptic data is already in N5 this is ignored |
| --working_pre_synapse_dataset | 'pre_synapse/s0' | The N5 dataset if the input is a TIFF stack |
| --working_n1_mask_container | Same as `--working_container` | The N5 neuron 1 mask container if the input is a TIFF stack; if the neuron 1 mask is already in N5 this is ignored |
| --working_n1_mask_dataset | 'n1_mask/s0' | The N5 dataset if the input is a TIFF stack |
| --working_n2_mask_container | Same as `--working_container` | The N5 neuron 2 mask container if the input is a TIFF stack; if the neuron 2 mask is already in N5 this is ignored |
| --working_n2_mask_dataset | 'n2_mask/s0' | The N5 dataset if the input is a TIFF stack |
| --working_post_synapse_container | Same as `--working_container` | The N5 post synaptic channel if the input is a TIFF stack; if the post-synaptic data is already in N5 this is ignored |
| --working_post_synapse_dataset | 'post_synapse/s0' | The N5 dataset if the input is a TIFF stack |
| --working_pre_synapse_seg_container | same as `--working_container` | Pre-synaptic segmentation N5 result |
| --working_pre_synapse_seg_dataset | 'pre_synapse_seg/s0' | Pre-synaptic segmentation N5 dataset |
| --working_post_synapse_seg_container | same as `--working_container` | Post-synaptic segmentation N5 result|
| --working_post_synapse_seg_dataset | 'post_synapse_seg/s0' | Post-synaptic segmentation N5 dataset |
| --working_pre_synapse_seg_post_container | same as `--working_container` | N5 container for pre-synaptic segmentation after post processing |
| --working_pre_synapse_seg_post_dataset | 'pre_synapse_seg_post/s0' | N5 dataset for pre-synaptic segmentation after post processing |
| --working_pre_synapse_seg_n1_container | same as `--working_container` | N5 container for pre-synaptic segmentation after post processing with N1 mask |
| --working_pre_synapse_seg_n1_dataset | 'pre_synapse_seg_n1/s0' | N5 dataset for pre-synaptic segmentation after post processing N1 mask |
| --working_pre_synapse_seg_n1_n2_container | same as `--working_container` | N5 container for pre-synaptic segmentation after post processing with N1 followed by post processing with N2 |
| --working_pre_synapse_seg_n1_n2_dataset | 'pre_synapse_seg_n1_n2/s0' | N5 dataset for pre-synaptic segmentation after post processing with N1 followed by post processing with N2 |
| --working_post_synapse_seg_n1_container | same as `--working_container` | N5 container for post-synaptic segmentation after post processing with pre-synaptic segmentation and N1 mask |
| --working_post_synapse_seg_n1_dataset | 'post_synapse_seg_pre_synapse_seg_n1/s0' | N5 dataset for post-synaptic segmentation after post processing with pre-synaptic segmentation and N1 mask |
| --working_pre_synapse_seg_post_synapse_seg_n1_container | same as `--working_container` | N5 container after post processing pre-synaptic segmentation with N1 and with post-synaptic segmentation |
| --working_pre_synapse_seg_post_synapse_seg_n1_dataset | 'pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1/s0' | N5 datasset after post processing pre-synaptic segmentation with N1 and with post-synaptic segmentation |

## Workflow A: Neuron 1 Presynaptic to Neuron 2

Usage ([example](../examples/presynaptic_n1_to_n2.sh)):

    ./synapse_pipeline.nf --pipeline=presynaptic_n1_to_n2 [arguments]

Assigns presynaptic sites to neurons based on site colocalization with neuron masks.

This workflow depends on masked neuron channels obtained with one of the [Neuron Segmentation Workflows](NeuronSegmentation.md). 

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --n1 | Volume (TIFF series or n5) containing Neuron #1 |
| --n1_in_dataset | Neuron 1 dataset if the neuron input stack is an N5 container |
| --n2 | Volume (TIFF series or n5) containing Neuron #2 | If this is empty the post-processing with N2 mask should generate the same results as as pre-synaptic segmentation with N1 mask, but the operation will be performed |
| --n2_in_dataset | Neuron 2 dataset if the neuron input stack is an N5 container |
| --presynapse | Volume (TIFF series or n5) containing pre-synaptic channel  |
| --presynapse_in_dataset | Pre-synaptic dataset if the input is N5  |


## Workflow B: Neuron 1 Presynaptic to Neuron 2 and Neuron 2 Presynaptic to Neuron 1

Usage:

    ./synapse_pipeline.nf --pipeline presynaptic_n1_to_n2 [arguments]

This is the same as Workflow A but you would also reverse `--n1` and `--n2`.


## Workflow C: Neuron 1 Presynaptic to Neuron 2 Restricted Postsynaptic 

Usage ([example](../examples/presynaptic_n1_to_postsynaptic_n2.sh)):

    ./synapse_pipeline.nf --pipeline presynaptic_n1_to_postsynaptic_n2 [arguments]

When pre/postsynaptic sites are expressed in a neuron-specific manner, e.g. through the use of driver line, this workflow can:
1) segment presynaptic and postsynaptic channels
2) identify presynaptic that colocalizes with neuron channel ("neuron 1 presynaptic")
3) identify postsynaptic that colocalizes with neuron 1 presynaptic
4) identify neuron 1 presynaptic that colocalizes with neuron 2 postsynaptic

This workflow depends on masked neuron channels obtained with one of the [Neuron Segmentation Workflows](NeuronSegmentation.md). 

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --n1 | Volume (TIFF series or n5) containing Neuron #1 |
| --n1_in_dataset | Neuron 1 dataset if the neuron input stack is an N5 container |
| --presynapse | Volume (TIFF series or n5) containing pre-synaptic channel  |
| --presynapse_in_dataset | Pre-synaptic dataset if the input is N5  |
| --postsynapse |  Volume (TIFF series or n5) containing post-synaptic channel |
| --postsynapse_in_dataset | Post-synaptic dataset if the input is N5  |



## Workflow D: Presynaptic in Volume

Usage: 

    ./synapse_pipeline.nf --pipeline presynaptic_in_volume [arguments]

This workflow ignores neurons and identifies all presynaptic sites in the given volume.

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --presynapse | Volume (TIFF series or n5) containing synaptic channel  |
| --presynapse_in_dataset | Pre-synaptic dataset if the input is N5  |
| --n1 | This is not a required parameter but if it is provided it will be used to mask the classified presynaptic regions, otherwise it will identify all regions in the volume and no mask will be used   |
| --n1_in_dataset | Neuron 1 dataset if the neuron input stack is an N5 container |
| --working_post_synapse_seg_container | The N5 container used for the post processed presynaptic segmentation result if no mask is provided |
| --working_post_synapse_seg_dataset | The dataset inside the N5 container used for post processed presynaptic segmentation if no mask neuron is provided |
| --working_pre_synapse_seg_n1_container | The N5 container used for the post processed presynaptic segmentation result when neuron mask is used |
| --working_pre_synapse_seg_n1_dataset | The dataset inside the N5 container used for post processed presynaptic segmentation when a neuron mask is used |
