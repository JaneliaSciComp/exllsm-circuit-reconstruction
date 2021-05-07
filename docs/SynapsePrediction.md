# Synapse Prediction

Synapse prediction can be run in multiple workflows, depending on the experimental design and data available.

These workflows depend on masked neuron channels obtained with one of the (Neuron Segmentation Workflows)[NeuronSegmentation.md]. 

## Workflow A: Neuron 1 Presynaptic to Neuron 2

Run using `--pipeline=presynaptic_n1_to_n2`.



## Workflow B: Neuron 1 Presynaptic to Neuron 2 and Neuron 2 Presynaptic to Neuron 1

Run using `--pipeline=presynaptic_n1_to_n2`.

This is the same as Workflow A but also reverses the neurons. 


# Workflow C: Neuron 1 Presynaptic to Neuron 2 Restricted Postsynaptic 

Run using `--pipeline=presynaptic_n1_to_postsynaptic_n2`.



## Workflow D: Presynaptic in Volume

Run using `--pipeline=presynaptic_in_volume`.

This workflow ignores neurons and identifies all presynaptic sites in the given volume.


## Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --pipeline | Pipeline to run (valid options: presynaptic_n1_to_n2, presynaptic_n1_to_postsynaptic_n2, presynaptic_in_volume) |
| --synapse_model | Path to trained synapse model in HDF5 format |
| --n1_stack_dir | Volume (TIFF series or n5) containing Neuron #1 |
| --n2_stack_dir | Volume (TIFF series or n5) containing Neuron #2 |
| --pre_synapse_stack_dir | Volume (TIFF series or n5) containing pre-synaptic channel  |
| --post_synapse_stack_dir |  Volume (TIFF series or n5) containing post-synaptic channel |

## Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --tiff2n5_cpus | 3 | Number of CPUs to use for converting TIFF to n5 |
| --n52tiff_cpus | 3 | Number of CPUs to use for converting n5 to TIFF |
| --unet_cpus | 4 | Number of CPUs to use for each U-NET prediction job |
| --postprocessing_cpus | 3 | Number of CPUs to use for post-processing (e.g. image closing, watershed, quantification, etc.) |
| --volume_partition_size | 512 | Size of sub-volumes to process in parallel. Should be a multiple of --block_size. |
| --presynaptic_stage2_threshold | 100 | TBD | 
| --presynaptic_stage2_percentage | 1 | TBD | 
| --postsynaptic_stage2_threshold | 100 | TBD | 
| --postsynaptic_stage2_percentage | 1 | TBD | 
