# Neuron Segmentation Workflows

Neuron segmentation can be accomplished using semi-automatic or automatic workflows. This document describes a part of the semi-automatic workflow and describes how to run the automatic neuron segmentation workflow.

## Semi-automatic Pipeline

[VVD Viewer](https://github.com/JaneliaSciComp/VVDViewer) is an open-source interactive rendering tool for light microscopy data visualization and analysis. We have developed VVD Viewer to allow user-guided, semi-automatic neuron segmentation of large ExLLSM image volumes. 

ExLLSM image volumes are first [converted to VVD Viewer pyramid files](./ImageProcessing.md). Neurons and are then semi-automatically segmented in VVD Viewer and saved as a TIFF series. A postprocessing workflow is required to convert the TIFF series to the final neuron mask used to [analyze connectivity](./SynapsePrediction.md). These postprocessing steps include pixel intensity thresholding, 3D component connecting, N5 component analysis, voxel shape conversion, and component size filtering. Each step is described in [Image Processing](./ImageProcessing.md) and we have generated a [VVD Neuron Segmentation Postprocessing Workflow](./ImageProcessing.md#vvd-neuron-segmentation-postprocessing-workflow) to run the entire postprocessing pipeline in sequence.

## Automatic Pipeline

The automatic neuron segmentation workflow runs 3D U-Net classification followed by optional post-processing steps. 

The output of the U-Net is a probability array with voxel values between 0 and 1. The optional postprocessing steps include voxel intensity thresholding to remove low confidence voxels, a voxel shape change, and a voxel size threshold to remove small components. 

There are multiple methods to run the postprocessing steps. Based on testing, the current recommendation is to set --with_neuron_post_segmentation to false and --with_connected_comps to true. Then use N5 connected components to apply a voxel intensity threhsold on the U-Net probability array, change voxel shape, and to apply a component size filter. 

When running neuron segmentation on large image volumes, the volume is partitioned into sub-volumes. The U-Net is run on each sub-volume and reassembled. Postprocessing steps are run on the assembled volume. The pipeline also includes an optional step to precompute a scaling factor for each tile. The alternative is to compuate a scaling factor on each tile (recommended).

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
| --neuron_scaling_memory| 1 GB | Memory resources needed for scaling factor jobs; for larger `neuron_scaling_partition_size` you may have to increase the memory required by each job |
| --neuron_mask_as_binary | false | Flag to output the neuron mask as binary |
| --with_neuron_post_segmentation | true | If set run neuron segmentation post-processing |
| --neuron_model| | location of the U-Net model |
| --neuron_input_dataset | /s0 | N5 dataset to segmentation |
| --neuron_output_dataset | /s0 | Output N5 dataset of the segmentation result |
| --neuron_seg_model_in_dims | 220,220,220 | Model input shape |
| --neuron_seg_model_out_dims | 132,132,132 | Model output shape |
| --neuron_seg_high_th | 0.98 | If --with_neuron_post_segmentation = true: High confidence threshold for postprocess flood filling step. |
| --neuron_seg_low_th | 0.2 | If --with_neuron_post_segmentation = true: Low confidence threshold for postprocess flood filling step. |
| &#x2011;&#x2011;neuron_seg_small_region_prob_th | 0.9 | If --with_neuron_post_segmentation = true: Small region probability threshold |
| --neuron_seg_small_region_size_th | 1000 | If --with_neuron_post_segmentation = true: Small region size threshold |
| --neuron_segmentation_cpus | 1 | CPU resources required for each segmentation job |
| --neuron_segmentation_memory | 1 G | Memory resources required for each segmentation job |
| --with_connected_comps | true | If true runs the N5 spark based connected components analysis. This is necessary to change voxel shape, apply a voxel intensity threhsold on the U-Net probability array, and a component size filter. |
| --connected_dataset | c1/s0 | default dataset used for connected components |
| --connected_pixels_shape | diamond | Shape used for connected components. Alternative option is 'box' |
| --min_connected_pixels | 2000 | Components below this size are discarded from final result. |
| --connected_pixels_threshold | .8 | Pixel intensity threshold value for neuron component analysis. It is a double value < 1 because the result of the segmentation is a probability array. |
| --connected_comps_block_size | 128,128,128 | Block size used for generating component analysis results. |
| --connected_comps_pyramid | false | If true generates multiscale N5 pyramids for component analysis results. |


