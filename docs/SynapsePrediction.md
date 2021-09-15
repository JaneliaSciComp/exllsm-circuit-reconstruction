# Synapse Prediction

Synapse prediction can be run in multiple workflows, depending on the experimental design and data available. When running synapse prediction on large image volumes, the volume is partitioned into sub-volumes. The workflow is run on each sub-volume and reassembled.

See below for details about each workflow:

* [Synapse Segmentation](synapse-segmentation): Synaptic structures are detected using a 3D U-Net convolutional neural network.
* [Synapse Segmentation Post-processing](synapse-segmentation-post-processing): Applies image closing, watershed segmentation, optional size filter, and optional colocalization analysis to Synapse Segmentation results. 

The following workflows integrate Synapse Segmentation and Synapse Segmentation Post-processing steps to automatically run frequently used analyses in sequence. 

* [Workflow A](workflow-a): Quantifies neuron 1 presynaptic sites and connections from neuron 1 to neuron 2. Requires a presynaptic channel and masks for neuron 1 and neuron 2.
* [Workflow B](workflow-b): Quantifies neuron 1 presynaptic sites and connections from neuron 1 to neuron 2. Requires a presynaptic channel, a postsynaptic channel restricted to neuron 2, and a neuron 1 mask.
* [Workflow C](workflow-c): Quantifies synaptic sites in a volume. No neuron information is needed, but synaptic sites in a neuron can be quantified. Requires a synaptic channel with optional neuron mask. 

![ExLLSM_synapseworkflows](https://user-images.githubusercontent.com/8125635/133482088-9c448f84-2d21-42fd-99f5-107ae576b4ff.png)

Details on methods to generate neurons masks for ExLLSM images can be found in the [Neuron Segmentation](NeuronSegmentation.md) and [Image Processing](ImageProcessing.md) sections.

Each workflow generates intermediate data volumes that are by default stored in the same N5 container but in different N5 datasets. The default N5 container name for intermediate data is specified by the `--working_container` parameter and the parameters for the intermediate datasets with their default values are defined below in the [Rarely used Global Optional Parameters](#rarely-used-global-optional-parameters) section.

## Global Required Parameters
These parameters are required for all workflows:

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --pipeline | Pipeline to run. Valid options: presynaptic_n1_to_n2, presynaptic_n1_to_postsynaptic_n2, presynaptic_in_volume, classify_synapses, collocate_synapses |
| --synapse_model | Path to trained synapse model in HDF5 format |
| --output_dir | | Output directory for results |

## Frequently used Global Optional Parameters

These parameters specify computation parameters and key aspects of data analysis. [Rarely used Global Optional Parameters](#rarely-used-global-optional-parameters) related to container naming are listed at the bottom of the page.

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --n5_compression | gzip | Compression for N5 volumes |
| --tiff2n5_cpus | 3 | Number of CPUs to use for converting TIFF to n5 |
| --n52tiff_cpus | 3 | Number of CPUs to use for converting n5 to TIFF |
| --unet_cpus | 4 | Number of CPUs to use for each U-NET prediction job |
| --postprocessing_cpus | 3 | Number of CPUs to use for post-processing (e.g. image closing, watershed, quantification, etc.) |
| --volume_partition_size | 512 | Size of sub-volumes to process in parallel. Should be a multiple of --block_size. |
| --presynaptic_stage2_threshold | 300 | Minimum voxel size of each synaptic site in stage 2 of Workflows A-C. |
| --presynaptic_stage2_percentage | 0.5 | Minimum presynaptic site % overlap with neuron 1 in order to be assigned to neuron 1 in stage 2 of Workflows A-C. Objects below this threshold are removed. 1 = whether the centroid falls within the mask. |
| --postsynaptic_stage2_threshold | 200 | Minimum voxel size of the postsynaptic site in stage 3 of Workflow B. |
| --postsynaptic_stage2_percentage | 0.001 | Minimum synaptic site % overlap with synaptic partner to be assigned a connection. Stage 3 in Workflows A-B (see Workflow specifics below). Objects below this threshold are removed. 1 = whether the centroid falls within the mask. |
| --postsynaptic_stage3_threshold | 400 | Minimum voxel size of each presynaptic site in Stage 4 of Workflow B. |
| --postsynaptic_stage3_percentage | 0.001 | Minimum presynaptic site % overlap with postsynaptic partner to be assigned a connection. Stage 4 in Workflow B. Objects below this threshold are removed. 1 = whether the centroid falls within the mask. |
| --with_pyramid | true | If set it generates the downsampling N5 pyramid for all UNet and Post-processing results. |
| --with_vvd | false | If set it creates VVD files of the UNet and Post-processing results. The base VVD output dir is set by --vvd_output_dir |
| --vvd_output_dir | | base VVD output dir. If this is not set but --with_vvd is set then the default VVD output dir will be the 'vvd' sub-directory under the N5 container dir. The name of the VVD volume is based on the stage that created the volume: 'pre_synapse_seg', or 'pre_synapse_seg_n1', or 'pre_synapse_seg_n1_n2'. The current implementation is an all or nothing - it does not support generating VVD files only for certain stages. |



## Workflow A

Usage ([example](../examples/presynaptic_n1_to_n2.sh)):

    ./synapse_pipeline.nf --pipeline=presynaptic_n1_to_n2 [arguments]

See the [schematic of Workflow A](#synapse-prediction) above. This workflow requires a presynaptic channel and neuron mask channels. If only one neuron mask is provided, it will identify synaptic sites in that neuron. If two neuron masks are included it will identify presynaptic sites in one neuron mask and connections between the two neuron masks. This workflow:

1) detects presynaptic sites using a 3D U-Net convolutional neural network
2) runs post-processing steps on this result (image closing, watershed segmentation and a size filter) and identifies post-processed presynaptic sites that colocalize with neuron 1
3) identifies connections between neuron 1 and neuron 2 based on neuron 1 presyaptic site colocalization with neuron 2

This workflow requires on masked neuron channels obtained with one of the [Neuron Segmentation Workflows](NeuronSegmentation.md). 

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --n1 | Volume (TIFF series or n5) containing Neuron #1 |
| --n1_in_dataset | Neuron 1 dataset if the neuron input stack is an N5 container; i.e. c0/s0 |
| --n2 | Volume (TIFF series or n5) containing Neuron #2 | If this is empty the post-processing with N2 mask should generate the same results as as pre-synaptic segmentation with N1 mask, but the operation will be performed |
| --n2_in_dataset | Neuron 2 dataset if the neuron input stack is an N5 container; i.e. c1/s0 |
| --presynapse | Volume (TIFF series or n5) containing pre-synaptic channel  |
| --presynapse_in_dataset | Pre-synaptic dataset if the input is N5; i.e. c2/s0  |


## Workflow B

Usage ([example](../examples/presynaptic_n1_to_postsynaptic_n2.sh)):

    ./synapse_pipeline.nf --pipeline presynaptic_n1_to_postsynaptic_n2 [arguments]

See the [schematic of Workflow B](#synapse-prediction) above. This workflow requires a presynaptic channel, a postsynaptic channel, and a neuron mask channel. It is designed to analyze postsynaptic data that is genetically restricted to identified neurons, but can be utilized in other ways. It will identify presynaptic sites in the neuron mask and connections between the neuron 1 presnaptic sites and the postsynaptic sites. This workflow:

1) detects presynaptic and postsynaptic sites using a 3D U-Net convolutional neural network
2) runs post-processing steps on the presynaptic channel result (image closing, watershed segmentation and a size filter) and identifies post-processed presynaptic sites that colocalize with neuron 1
3) runs post-processing steps on the postsynaptic channel result (image closing, watershed segmentation and a size filter) and identifies connections as post-processed postsynaptic sites that colocalize with neuron 1 presynaptic sites  
4) identifies presynpatic sites that colocalize with stage 3 results

This workflow depends on masked neuron channels obtained with one of the [Neuron Segmentation Workflows](NeuronSegmentation.md). 

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --n1 | Volume (TIFF series or n5) containing Neuron #1 |
| --n1_in_dataset | Neuron 1 dataset if the neuron input stack is an N5 container; i.e. c0/s0 |
| --presynapse | Volume (TIFF series or n5) containing pre-synaptic channel  |
| --presynapse_in_dataset | Pre-synaptic dataset if the input is N5; i.e. c1/s0  |
| --postsynapse |  Volume (TIFF series or n5) containing post-synaptic channel |
| --postsynapse_in_dataset | Post-synaptic dataset if the input is N5; i.e. c2/s0  |


## Workflow C

Usage: 

    ./synapse_pipeline.nf --pipeline presynaptic_in_volume [arguments]

See the [schematic of Workflow C](#synapse-prediction) above. This workflow ignores neurons and identifies all synaptic sites labeled in a single channel in the given volume. However, if a neuron mask is included, it will identify synaptic sites in that neuron.

This workflow:

1) detects synaptic sites using a 3D U-Net convolutional neural network
2) runs post-processing steps on this result (image closing, watershed segmentation and a size filter)

### Required Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --presynapse | | Volume (TIFF series or n5) containing synaptic channel  |
| --presynapse_in_dataset | | synaptic dataset if the input is N5; i.e. c0/s0  |
| --presynaptic_stage2_threshold | 300 | This is not a required parameter, but if it is provided will specify the minimum voxel size of each synaptic site in stage 2. This works with or without a neuron mask. |
| --n1 | | This is not a required parameter but if it is provided, only synaptic sites that colocalize with this mask will be identified. Volume (TIFF series or n5) containing Neuron #1 |
| --n1_in_dataset | | Neuron 1 dataset if the neuron input stack is an N5 container; i.e. c1/s0 |
| --presynaptic_stage2_percentage | 0.5 | This is not a required parameter, but if it is provided will specify the minimum synaptic site % overlap with neuron 1 in order to be assigned to neuron 1 in stage 2. Objects below this threshold are removed. 1 = whether the centroid falls within the mask. |

## Synapse Segmentation

Usage: 

    ./synapse_pipeline.nf --pipeline classify_synapses [arguments]

Workflows A-C may not be suitable for all data and analysis needs. Synapse Segmentation and Synapse Segmentation Post-processing can be run independently to allow maximum flexibility and to reduce running redundant processes when analying connecitivty between multiple neuron pairs in a volume ([see below](#synapse-segmentation-post-processing). 

This will detect synaptic sites using a 3D U-Net convolutional neural network. 

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --presynapse | Volume (TIFF series or n5) containing synaptic channel  |
| --presynapse_in_dataset | synaptic dataset if the input is N5; i.e. c0/s0  |

## Synapse Segmentation Post-processing

Usage:

    ./synapse_pipeline.nf --pipeline collocate_synapses [arguments]

Workflows A-C may not be suitable for all data and analysis needs. Synapse Segmentation and Synapse Segmentation Post-processing can be run independently to allow maximum flexibility and to reduce running redundant processes when analying connecitivty between multiple neuron pairs in a volume. For example, imagine you wanted to quantify connectivity reciprocally between two neurons (instead of quantifying connectivity between two neurons in just one direction as described in Workflow A). Using only Workflow A to do this would run Synapse Segmentation on the same presynaptic data twice. 

To avoid this unecessary computation time and expense, you can use --pipeline collocate_synapses. This will run only the Synapse Segmentation Post-processing steps (image closing, watershed segmentation, size filering) and colocalization analysis. Thus, you can run Workflow A once to quantify connections from neuron 1 to neuron 2. Then run --pipeline collocate_synapses to quantify presynaptic sites in neuron 2. Then run --pipeline collocate_synapses again to quantify connections from neuron 2 to neuron 1. This requires additional user input, but avoids running Synapse Segmentation twice on the same data. These tools can also be used to quantify connectivity using data types beyond those described here (e.g. genetically restricted presynaptic sites with ubiquitous postsynaptic sites and a neuron  mask).

Below parameters that would produce the result desribed above are indicated.

### Required Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --presynapse | | Volume (TIFF series or n5) containing synaptic channel analysed by Synapse Segmentation; i.e. presynaptic_n1_to_n2.n5 from the Workflow A run  |
| --presynapse_in_dataset | | segmented synaptic dataset if the input is N5; i.e. pre_synapse_seg/s0 from the Workflow A run |
| --presynaptic_stage2_threshold | 300 | Specifies the minimum voxel size of each synaptic site in stage 2 (as in Workflows A-B). |
| --n1 | | Volume (TIFF series or n5) containing Neuron #1. In the example described above n1 would now be what was called n2 in the initial Workflow A run. |
| --n1_in_dataset | | Neuron 1 dataset if the neuron input stack is an N5 container. In the example described above n1 would now be what was called n2 in the initial Workflow A run. |
| --presynaptic_stage2_percentage | 0.5 | Specifies the minimum synaptic site % overlap with neuron 1 in order to be assigned to neuron 1 in stage 2 (as in Workflows A-B). Objects below this threshold are removed. 1 = whether the centroid falls within the mask. |

The above would identify the presynaptic sites in neuron 2. To find the connections from neuron 2 to neuron 1, run --pipeline collocate_synapses again, this time replacing --presynapse with the N5 directory generated in the previous step, --presynapse_in_dataset with pre_synapse_seg_n1/s0 data generated in the previous step, --n1 with the original Workflow A n1 (here the postsynaptic neuron), and --presynaptic_stage2_percentage with 0.001. These steps would generate the reciprocal to the data generated in Workflow A. 

### Rarely used Global Optional Parameters 

These parameters can be used to change the name of working_containers and working_datsets:

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
| --working_pre_synapse_seg_container | same as `--working_container` | Presynaptic segmentation N5 result |
| --working_pre_synapse_seg_dataset | 'pre_synapse_seg/s0' | Presynaptic segmentation N5 dataset |
| --working_post_synapse_seg_container | same as `--working_container` | Postsynaptic segmentation N5 result|
| --working_post_synapse_seg_dataset | 'post_synapse_seg/s0' | Postsynaptic segmentation N5 dataset |
| --working_pre_synapse_seg_post_container | same as `--working_container` | N5 container for presynaptic segmentation after post processing |
| --working_pre_synapse_seg_post_dataset | 'pre_synapse_seg_post/s0' | N5 dataset for presynaptic segmentation after post processing |
| --working_pre_synapse_seg_n1_container | same as `--working_container` | N5 container for presynaptic segmentation after post processing with N1 mask |
| --working_pre_synapse_seg_n1_dataset | 'pre_synapse_seg_n1/s0' | N5 dataset for presynaptic segmentation after post processing N1 mask |
| --working_pre_synapse_seg_n1_n2_container | same as `--working_container` | N5 container for presynaptic segmentation after post processing with N1 followed by post processing with N2 |
| --working_pre_synapse_seg_n1_n2_dataset | 'pre_synapse_seg_n1_n2/s0' | N5 dataset for presynaptic segmentation after post processing with N1 followed by post processing with N2 |
| --working_post_synapse_seg_n1_container | same as `--working_container` | N5 container for postsynaptic segmentation after post processing with pre-synaptic segmentation and N1 mask |
| --working_post_synapse_seg_n1_dataset | 'post_synapse_seg_pre_synapse_seg_n1/s0' | N5 dataset for postsynaptic segmentation after post processing with pre-synaptic segmentation and N1 mask |
| --working_pre_synapse_seg_post_synapse_seg_n1_container | same as `--working_container` | N5 container after post processing presynaptic segmentation with N1 and with post-synaptic segmentation |
| --working_pre_synapse_seg_post_synapse_seg_n1_dataset | 'pre_synapse_seg_n1_post_synapse_seg_pre_synapse_seg_n1/s0' | N5 datasset after post processing presynaptic segmentation with N1 and with post-synaptic segmentation |
