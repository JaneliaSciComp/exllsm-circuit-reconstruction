# Neuron Segmentation Workflows

Neuron segmentation can be accomplished using semi-automatic or automatic workflows. This document describes a part of the semi-automatic workflow and describes how to run the automatic neuron segmentation workflow.

## Semi-automatic Pipeline

[VVD Viewer](https://github.com/JaneliaSciComp/VVDViewer) is an open-source interactive rendering tool for light microscopy data visualization and analysis. We have developed VVD Viewer to allow user-guided, semi-automatic neuron segmentation of large ExLLSM image volumes. 

Image volumes stored as N5 files can be dragged directy into VVD Viewer and visualized. However, segmentation has not been optimized for these file types. Instead, it is recommended that VVD pyramid files are used for ExLLSM analysis. 

ExLLSM image volumes are first [converted to VVD Viewer pyramid files](./ImageProcessing.md). Neurons are then semi-automatically segmented in VVD Viewer and saved as a TIFF series. A postprocessing workflow is required to convert the TIFF series to the final neuron mask used to [analyze connectivity](./SynapsePrediction.md). These postprocessing steps include pixel intensity thresholding, 3D component connecting, voxel shape conversion, N5 component analysis, and component size filtering. Each of these post VVD segmentation steps is described in [Image Processing](./ImageProcessing.md) and we have generated a [Post VVD Neuron Segmentation Processing Workflow](./ImageProcessing.md#post-vvd-neuron-segmentation-processingworkflow) to run the entire postprocessing pipeline in sequence. 

Recommended VVD Viewer settings, basic controls, and segmentation protocols are documented here. 

VVD Viewer recommended settings for ExLLSM data
Basic VVD Viewer controls
Manual and Semi-automatic ExLLSM image segmentation
Editing and saving semi-automatically generated segmentation results


### VVD Viewer recommended settings

Upon starting VVD Viewer for the first time, click the Settings box at the top of the window. In the Project panel, it is recommended that Paint History be set to 1 or 2. This allows actions to be undone which can, of course, be very helpful. If the system allows, in the Rendering panel, Enable Micro Blending and set Mesh Transparency Quality to 10. In the Performance panel, Enable streaming for large datasets. Set the Graphics Memory to the correct value based on your system. Set a Large Data Size of 1000 MB, Brick Size of 512, and Response Time of 100  ms. Set the Buffer Size as high as possible based on your system. The Rendering and Performance settings may require testing to find the optimal values for your system. Try reducing the values if rendering is slow. The Variable Sample Rate options in Performance may also be helpful.  To save Settings, close VVD Viewer and repoen. The updated settings should now be present.

### VVD Viewer basic controls

| Task       | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| open VVD pyramid file | Either use the Open Volume button or drag the .vvd file into VVD Viewer |
| pan image | ctrl+right click and drag the mouse in the Render View window |
| zoom | scroll the mouse trackball in the Render View window |
| rotate | right click and drag the mouse in the Render View Window |
| visualize a subset of the volume | adjust values in the Clipping Planes. checking the link button will allow scrolling through the volume at a given subvolume |
| change Clipping Plane orientation | rotate image as desired, click Align to View in Clipping Planes Rotations panel |
| change name of the volume | right click on the volume name in the Workspace panel and click Rename |
| change volume color | click the box at the bottom of the Properties panel |
| change scale | set the x/y/z voxel size values at the bottom of the Properties panel |
| adjust gamma, saturation, etc. | sliders found in the Properties panel |
| add legend to Render View for image captures and videos | click the Legend button at the top of the Render View window |
| capture image in the Render View | click the capture button at the top of the Render View window |
| create videos of the Render View | go to the Advanced tab in the Record/Export Panel. add desired views in the Render View in sequence. set the time between view transitions. click save to generate a video of each view added and the 3D transitions between the added views |

### VVD Viewer segmentation controls

| Task       | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| manually segment based on pixel intensity | open the Analyze window, click the Paint Brush tab, set a pixel intensity Threshol value; click Select and right click and drag the mouse to select in the Render View window (or shift+right click and drag the mouse); after selecting, the threshold value can be updated and the selection based on the new threshold will be displayed upon hitting enter |
| manually unselect | open the Analyze window, click the Paint Brush tab, click Unselect and right click and drag the mouse in the Render View window |
| reset all segmentation | open the Analyze window, click the Paint Brush tab, click Reset |
| semi-automatically segment based on pixel intensity and voxel size | open the Analyze window, click the Analysis tab, set a pixel intensity Threshold and Min vx. size values, and click Analyze |
| save project/selection/segmentation mask | click the Save Project button and name the .vrp file |
| import segmentation mask | to return to a project, you can use the Open Project button. however, you can also import a previously saved mask onto a VVD volume which can be faster. to do this, right click on the name of the image volume in the Workspace panel. click Import Mask. navigate to the appropriate .vrp_files folder. open the .msk file. the .msk must be the same dimensions as the volume to import |
| save full resolution segmentation | to save the segmented volume as an 8-bit TIFF series, click the Hide Outside box inthe Properties panel. then click on the save floppy disk icon at the top of the Workspace panel. create a directory for the TIFF series, pick a file name (0 -- subsequent z slices will be saved as 1, 2, 3, etc.). this process may take an hour or more depending on the size of the volume. |

## Automatic Pipeline

The automatic neuron segmentation workflow runs 3D U-Net classification followed by optional post-processing steps. 

The output of the U-Net is a probability array with voxel values between 0 and 1. The optional postprocessing steps include voxel intensity thresholding to remove low confidence voxels, a voxel shape change, and a voxel size threshold to remove small components. 

There are multiple methods to run the postprocessing steps. Based on testing, the current recommendation is to set --with_neuron_post_segmentation to false and --with_connected_comps to true. Then use N5 connected components analysis to apply a voxel intensity threhsold on the U-Net probability array, change voxel shape, and to apply a component size filter. 

When running neuron segmentation on large image volumes, the volume is partitioned into sub-volumes. The U-Net is run on each sub-volume and reassembled. Postprocessing steps are run on the assembled volume. The pipeline also includes an optional step to precompute a scaling factor to be used on all tiles. The alternative is to compuate the scaling factor on each tile (recommended).

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


