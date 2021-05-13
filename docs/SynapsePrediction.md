# Synapse Prediction

Synapse prediction can be run in multiple workflows, depending on the experimental design and data available.

See below for details about the workflows:
* Workflow A: Neuron 1 Presynaptic to Neuron 2
* Workflow B: Neuron 1 Presynaptic to Neuron 2 and Neuron 2 Presynaptic to Neuron 1
* Workflow C: Neuron 1 Presynaptic to Neuron 2 Restricted Postsynaptic 
* Workflow D: Presynaptic in Volume

## Global Required Parameters

These parameters are required for all workflows:

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --pipeline | Pipeline to run (valid options: presynaptic_n1_to_n2, presynaptic_n1_to_postsynaptic_n2, presynaptic_in_volume) |
| &#x2011;&#x2011;synapse_model | Path to trained synapse model in HDF5 format |

## Global Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --n5_compression | gzip | Compression for N5 volumes |
| --tiff2n5_cpus | 3 | Number of CPUs to use for converting TIFF to n5 |
| --n52tiff_cpus | 3 | Number of CPUs to use for converting n5 to TIFF |
| --unet_cpus | 4 | Number of CPUs to use for each U-NET prediction job |
| --postprocessing_cpus | 3 | Number of CPUs to use for post-processing (e.g. image closing, watershed, quantification, etc.) |
| --volume_partition_size | 512 | Size of sub-volumes to process in parallel. Should be a multiple of --block_size. |
| --presynaptic_stage2_threshold | 400 | Voxel threshold (smallest blob to include), for stage 2 presynaptic processing. | 
| --presynaptic_stage2_percentage | 0.5 | Threshold to remove the object if it falls in the mask less than a percentage. If percentage is >=1, criteria will be whether the centroid falls within the mask. | 
| --postsynaptic_stage2_threshold | 200 | Same as above for stage 2 postsynaptic processing. | 
| --postsynaptic_stage2_percentage | 0.001 | Same as above for stage 2 postsynaptic processing. | 
| --postsynaptic_stage3_threshold | 400 | Same as above for stage 3 processing. | 
| &#x2011;&#x2011;postsynaptic_stage3_percentage | 0.001 | Same as above for stage 3 processing. | 


## Workflow A: Neuron 1 Presynaptic to Neuron 2

Usage:

    ./synapse_pipeline.nf --pipeline=presynaptic_n1_to_n2 [arguments]

(See [example](examples/presynaptic_n1_to_n2.sh) invocation)

Assigns presynaptic sites to neurons based on site colocalization with neuron masks.

This workflow depends on masked neuron channels obtained with one of the [Neuron Segmentation Workflows](NeuronSegmentation.md). 

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --n1_stack_dir | Volume (TIFF series or n5) containing Neuron #1 |
| --n2_stack_dir | Volume (TIFF series or n5) containing Neuron #2 |
| &#x2011;&#x2011;pre_synapse_stack_dir | Volume (TIFF series or n5) containing pre-synaptic channel  |


## Workflow B: Neuron 1 Presynaptic to Neuron 2 and Neuron 2 Presynaptic to Neuron 1

Usage:

    ./synapse_pipeline.nf --pipeline presynaptic_n1_to_n2 [arguments]

This is the same as Workflow A but you would also reverse `--n1_stack_dir` and `--n2_stack_dir`.


## Workflow C: Neuron 1 Presynaptic to Neuron 2 Restricted Postsynaptic 

Usage:

    ./synapse_pipeline.nf --pipeline presynaptic_n1_to_postsynaptic_n2 [arguments]

(See [example](examples/presynaptic_n1_to_postsynaptic_n2.sh) invocation)

When pre/postsynaptic sites are expressed in a neuron-specific manner, e.g. through the use of driver line, this workflow can:
1) segment presynaptic and postsynaptic channels
2) identify presynaptic that colocalizes with neuron channel ("neuron 1 presynaptic")
3) identify postsynaptic that colocalizes with neuron 1 presynaptic
4) identify neuron 1 presynaptic that colocalizes with neuron 2 postsynaptic

This workflow depends on masked neuron channels obtained with one of the [Neuron Segmentation Workflows](NeuronSegmentation.md). 

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --n1_stack_dir | Volume (TIFF series or n5) containing Neuron #1 |
| --pre_synapse_stack_dir | Volume (TIFF series or n5) containing pre-synaptic channel  |
| &#x2011;&#x2011;post_synapse_stack_dir |  Volume (TIFF series or n5) containing post-synaptic channel |


## Workflow D: Presynaptic in Volume

Usage: 

    ./synapse_pipeline.nf --pipeline presynaptic_in_volume [arguments]

This workflow ignores neurons and identifies all presynaptic sites in the given volume.

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| &#x2011;&#x2011;pre_synapse_stack_dir | Volume (TIFF series or n5) containing synaptic channel  |

