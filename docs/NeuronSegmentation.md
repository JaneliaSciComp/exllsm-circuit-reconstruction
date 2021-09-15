# Neuron Segmentation Workflows

Segmentation of neurons can be automated or semi-automated. This document describes how to run the
automatic neuron segmentation.

## Automated Pipeline

The automatic neuron segmentation is based on running a 3D U-Net classification followed by an optional post-processing step that eliminates small regions. The pipeline also includes an optional step to precompute a scaling factor for each tile.

Usage:

    ./neuron_segmentation_pipeline.nf [arguments]

## Neuron Segmentation Parameters

| Argument | Default | Description |
|----------|---------|-------------|
| --neuron_scaling_partition_size | '396,396,396' | Sub-volume partition size for running the U-Net model. This should be a multiple of the neuron model output shape |
| --neuron_scaling_tiles| 0 (None) | Number of tiles randomly sampled from the entire volume to be used for calculating the scaling factor. The scaling factor used for segmentation will be the average of all values computed for the sampled tiles. This value takes precedence over the `neuron_percent_scaling_tiles` |
| --neuron_percent_scaling_tiles | 0 (None) | Percentage of the tiles randomly sampled from the volume to calculate the scaling factor. If there's no number of tiles specified for scaling factor the scaling factor will be computed for each sub-volume |
| --user_defined_scaling | | User defined scaling factor if one doesn't want the scaling to be comnputed for each tile |
| --max_scaling_tiles_per_job | 40 | This is the value used for parallelizing the scaling factor computation so that in each job there will not be more than the specified number of tiles used to to compute the scaling factor. The final scaling factor will average the values returned by each individual job |
| --neuron_scaling_plots_dir | | If this is set the scaling factor jobs will output the 'Huber Regression' plots in this directory, for all tiles used for scaling factor computation |
| --neuron_scaling_cpus | 1 | CPU resources required for calculating the scaling factor |
| --neuron_scaling_memory| 1 GB | memory resources needed for scaling factor jobs; for larger `neuron_scaling_partition_size` you may have to increase the memory required by each job |
| --neuron_mask_as_binary | false | flag to output the neuron mask as binary |
| --with_neuron_post_segmentation | true | if set run neuron segmentation post-processing |
| --neuron_model| | location of the U-Net model |
| --neuron_input_dataset | /s0 | default N5 dataset used for segmentation |
| --neuron_output_dataset | /s0 | default N5 dataset of the result of the segmentation |
| --neuron_seg_model_in_dims | 220,220,220 | Model input shape |
| --neuron_seg_model_out_dims | 132,132,132 | Model output shape |
| --neuron_seg_high_th | 0.98 | high confidence threshold for post process flood filling |
| --neuron_seg_low_th | 0.2 | low confidence threshold for post process flood filling |
| &#x2011;&#x2011;neuron_seg_small_region_prob_th | 0.9 | small region probability threshold |
| --neuron_seg_small_region_size_th | 1000 | small region size threshold |
| --neuron_segmentation_cpus | 1 | CPU resources required for each segmentation job |
| --neuron_segmentation_memory | 1 G | Memory resources required for each segmentation job |
| --with_connected_comps | true | If true runs the N5 Spark based connected components |
| --connected_dataset | c1/s0 | default dataset used for connected components |
| --connected_pixels_shape | diamond | Shape used for connected components |
| --min_connected_pixels | 2000 | Min pixels threshold used to decide whether to keep the component or not |
| --connected_pixels_threshold | .8 | threshold value for neuron connected components. It is a double value < 1 because the result of the segmentation is a probability array. |
| --connected_comps_block_size | 128,128,128 | Block size used for generating connected comps |
| --connected_comps_pyramid | false | If true generates multiscale pyramids for connected components |

## [Postprocessing for user-guided semi-automatic VVD Viewer segmentation](#post-vvd-semi-automatic-neuron-segmentation)

Workflow to threshold, 3D connect, and size filter neuron masks generated in VVD Viewer. 
