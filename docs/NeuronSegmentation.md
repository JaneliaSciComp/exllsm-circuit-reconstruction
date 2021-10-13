# Neuron Segmentation Workflows

Neuron segmentation can be accomplished using manual, semi-automatic, or [automatic workflows](#automatic-neuron-segmentation-workflow). The semi-automatic and automatic tools work well to segment neurons from background signals and off-target antibody labeling. However, they are not constructed to segment a group of neurons that contact each other into individual neurons. As such, they are well-suited to quickly segmenting images that label individual neurons or multiple connected neurons that are being analyzed as a group. To segment individual neurons in a volume in which multiple neurons are labeled, the automatic and semi-automatic tools can be used for initial segmentation from background, but the user will need to manually inspect and edit the results to generate individual neuron masks. 

## Manual and Semi-automatic Neuron Segmentation Workflows


**Figure 1: Overview of the Manual and Semi-automatic Neuron Segmentation Workflows**

![segmentation_workflow](https://user-images.githubusercontent.com/8125635/137171294-3f6458d7-ddd2-4b1f-acd5-3358dfe4f501.png)

Manual and semi-automatic segmentation is accomplished using [VVD Viewer](https://github.com/JaneliaSciComp/VVDViewer). VVD Viewer is an open-source interactive rendering tool for light microscopy data visualization and analysis. We have developed VVD Viewer to allow manual and user-guided semi-automatic neuron segmentation of large ExLLSM image volumes. Segmentaion of datasets <5TB has been tested extensively. 

Image volumes stored as N5 files can be opened directy into VVD Viewer and visualized by dragging the parent N5 directory into the VVD Viewer Render View window. However, segmentation has not been optimized for these file types. Instead, it is recommended that VVD pyramid files are used for ExLLSM analysis. 

Therefore, ExLLSM image volumes are first [converted to VVD Viewer pyramid files](./ImageProcessing.md). Neurons are then segmented in VVD Viewer and saved as a TIFF series. A postprocessing workflow is required to convert the TIFF series to the final neuron mask used to [analyze connectivity](./SynapsePrediction.md). These postprocessing steps include pixel intensity thresholding, 3D component connecting, voxel shape conversion, N5 component analysis, and component size filtering. Each of these post VVD segmentation steps is described in [Image Processing](./ImageProcessing.md) and we have generated a [Post VVD Neuron Segmentation Processing Workflow](post-vvd-neuron-segmentation-processing-workflow) to run the entire postprocessing pipeline in sequence. 

Recommended VVD Viewer settings, basic controls, and segmentation tools and strategies are documented in this section. 

* [Recommended VVD Viewer Settings for ExLLSM data](#vvd-viewer-recommended-setings)
* [Basic VVD Viewer Controls](#vvd-viewer-basic-controls)
* [Manual and Semi-automatic ExLLSM Image Segmentation](#vvd-viewer-segmentation)
* [Post VVD Neuron Segmentation Processing](#post-vvd-neuron-segmentation-processing)

### VVD Viewer recommended settings

Upon starting VVD Viewer for the first time, click the Settings box at the top of the window. 

In the Project panel:
* Set Paint History to 1 or 2

In the Performance panel:
* Enable streaming for large datasets
* Set the Graphics Memory to the correct value based on your system
* Large Data Size of 1000 MB
* Brick Size of 512
* Response Time of 100  ms
* Set the Buffer Size as high as possible based on your system. 

In the Rendering panel:
* Enable Micro Blending
* Set Mesh Transparency Quality to 10

The Project, Rendering, and Performance settings may require testing to find the optimal values for your system. If rendering is slow, try setting the Paint History value to 1 or 0, disabling Micro Blending, and reducing the Mesh Transparency Quality values. Turning on the Variable Sample Rate options in Performance may also be helpful. For new Settings to take effect, close VVD Viewer and repoen. The updated settings should now be present.

### VVD Viewer basic controls

**Figure 2: The VVD Viewer GUI**

![VVDbasics](https://user-images.githubusercontent.com/8125635/137042755-4b81b87d-1c46-4a50-8f7d-fa8a0caddebf.png)

|Key | Task       | Description                                                                           |
|----|------------|---------------------------------------------------------------------------------------|
|1| open VVD pyramid file | Either use the Open Volume button or drag the .vvd file into VVD Viewer |
|2| pan image | ctrl+right click and drag the mouse in the Render View window |
|3| zoom | scroll the mouse trackball in the Render View window |
|4| rotate | right click and drag the mouse in the Render View Window |
|5| view volume details | click the Info box at the top of the Render View window. this will show the VVD pyramid being viewed and additional information |
|6| increase resolution of rendering | the VVD pyramid being viewed (e.g. full resolution = Max, most downsampled pyramid = Min) can be switched by clicking on the Quality menu at the top of the Render View. zooming will also increase resolution if Standard or above is selected. |
|7| change name of the volume | right click on the volume name in the Workspace panel and click Rename |
|8| change volume color | click the box at the bottom of the Properties panel |
|9| change scale | set the x/y/z voxel size values at the bottom of the Properties panel |
|10| adjust gamma, saturation, etc. | sliders found in the Properties panel |
|11| visualize a subset of the volume | adjust values in the Clipping Planes. checking the link button will allow scrolling through the volume at a given subvolume |
|12| change Clipping Plane orientation | rotate image as desired, click Align to View in Clipping Planes Rotations panel |
|13| add legend to Render View for image captures and videos | click the Legend button at the top of the Render View window |
|14| capture image in the Render View | click the capture button at the top of the Render View window |
|15| create videos of the Render View | go to the Advanced tab in the Record/Export Panel. add desired views in the Render View in sequence. set the time between view transitions. click save to generate a video of each view added and the 3D transitions between the added views |

### VVD Viewer segmentation

Images can be segmented in VVD Viewer based on a voxel intensity threshold (manual) and based on a combination of a voxel intensity threshold and a component size threshold (semi-automatic).

#### VVD Viewer basic segmentation controls

| Task       | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| manually segment based on voxel intensity | open the Analyze window, click the Paint Brush tab, set a voxel intensity Threshol value; click Select and right click and drag the mouse to select in the Render View window (or shift+right click and drag the mouse); after selecting, the threshold value can be updated and the selection based on the new threshold will be displayed upon hitting enter |
| manually unselect | open the Analyze window, click the Paint Brush tab, click Unselect and right click and drag the mouse in the Render View window |
| reset all segmentation | open the Analyze window, click the Paint Brush tab, click Reset |
| semi-automatically segment based on voxel intensity and voxel size | open the Analyze window, click the Analysis tab, set a voxel intensity Threshold and Min vx. size values, and click Analyze |
| save project/selection/segmentation mask | click the Save Project button and name the .vrp file |
| import segmentation mask | to return to a project, you can use the Open Project button. however, you can also import a previously saved mask onto a VVD volume which can be faster. to do this, right click on the name of the image volume in the Workspace panel. click Import Mask. navigate to the appropriate .vrp_files folder. open the .msk file. the .msk must be the same dimensions as the volume to import |
| save full resolution segmentation | to save the segmented volume as an 8-bit TIFF series, click the Hide Outside box inthe Properties panel. then click on the save floppy disk icon at the top of the Workspace panel. create a directory for the TIFF series, pick a file name (0 -- subsequent z slices will be saved as 1, 2, 3, etc.). this process may take an hour or more depending on the size of the volume. |

### Manual segmentation

Manual segmentation in VVD Viewer is not entirely manual -- intensity thresholds are utilized to facilitate voxel selections. This makes the even manual segmentation via VVD Viewer reasonably efficient, and in some cases this approach may be sufficient to segment images as desired. Additionally, these manual segmentation tools will be used to edit semi-automatic segmentation results. 

To manually segment based on voxel intensity, open the Analyze window and select the Paint Brush tab. Pick an intensity threshold and press Select. In the Render View window, right click the mouse and paint or select the regions of interest. You can also avoid pressing Select and use shift+right click in the Render View window to make voxel selections. Here, the threshold used was too low and large chunks of background signal were selected (Fig. 3).

**Figure 3: Manual voxel selection using an intensity threshold that is too low**

![manualselect1](https://user-images.githubusercontent.com/8125635/137046058-992f4c67-5c9d-4830-8b48-2e5fb6672e08.png)

With this selection, you can change the threshold value in the Paint Brush toolbox, press enter, and the selection based on the new threshold will appear in the Render View window. You can also Unselect a previous selection using the Unselect tool. Simply click on Unselect, then right click in the Render View window to remove selected voxels from the segmentation by dragging the mouse (Fig. 4).

**Figure 4: Manually unselecting voxels**

![unselect1](https://user-images.githubusercontent.com/8125635/137046252-7aa4fbda-2ff5-4685-9cee-2907088f51dc.png)

Of course, you can also test additional thresholds to find one that cleanly selects the neurons of interst. Here, the threshold was increased from 20 in the first example to 40 (Fig. 5). This appears to do a much better job of selecting only voxels of interest. However, there is likely to be significant variability in voxel intensity throughout the sample so the result needs to be inspected closely. See below for efficient segmentation editing and refinement strategies.

**Figure 5: Manual voxel selection using an appropriate intensity threshold**

![manualselect2](https://user-images.githubusercontent.com/8125635/137046446-93fbe5a7-d26c-4345-9a8f-b3a0593188d7.png)

### Semi-automatic segmentation

Semi-automatic segmentation is accomplished by using a combination of voxel intensity and component size thresholds. This is done via the Component Analyzer tool (found in the Analysis tab of the Analyze window). It may take some trial and error to find an appropriate combination of voxel intensity and component size that segments the neurons properly (or at least provides a helpful start), but this is usually a straight forward process. 

Here, the thresholds are too low. The tool selects most of the image (Fig. 6).

**Figure 6: Semi-automatic segmentation using thresholds that are too low**

![component_analyzer_bad1](https://user-images.githubusercontent.com/8125635/137029694-e2476947-67a0-45fb-b929-4a368235c285.png)

By increasing the voxel intensity threshold from 5 to 30, the neurons of interest are grossly selected and most of the background is avoided (Fig. 7).

**Figure 7: Semi-automatic segmentation using appropriate thresholds**

![component_analyzer_good1](https://user-images.githubusercontent.com/8125635/137029686-7f963e97-28f8-4036-abff-b1a0b1076001.png)

To inspect the quality of the result, adjust the Clipping Planes, zoom in, increase the Quality of the rendering to visualize a full or close-to-full resolution pyramid, and scan through the image in small chunks (or single slices) (Fig. 8). If you have what appears to be a solid segmentation result -- or at least a good start -- save the project. This may take some time depending on the size of the volume. However, the mask itself will save very quickly and can be immediately loaded into a new instance of VVD Viewer for editing. 

To quickly import a previously saved mask, open a new instance of VVD Viewer and open the original .vvd pyramid file. Right click on the volume name in the Workspace panel, select Import Mask, go to the .vrp_files folder that was just generated upon saving the project, and select the .msk. This will import the mask onto the image volume.

Now, the automatic segmentation results can be manually adjusted using the Select and Unselect Paint Brush tools described in the Manual Segmentation section above. Making manual edits using the Paint Brush tools by systematically stepping through small subvoumes of the image allows corrections to be done in a relatively efficient manner. **Be sure to save the project periodically (plausibly with updated file names so you can return to a previous version if accidentally make incorrect edits) to ensure that manual segmentation work is not lost.**

Here, by looking at 100 z-slices and scanning through the volume, we see that several portions of the neuron bundle were missed by the Component Analyzer (Fig. 8).

**Figure 8: Voxels labeling neurons of interest that were missed by semi-automatic segmenation**

![manualedit_1large](https://user-images.githubusercontent.com/8125635/137029059-fd5a1597-240b-497c-b8fd-c67a6a7aa457.png)

After finding a suitable pixel intensity threshold, missed voxels can be manually selected using the Paint Brush as demonstrated on a small region of the neuron bundle in Figure 9. 

**Figure 9: Using manual voxel selection to correct the semi-automatic segmentation results**

![manualedit_2-3large](https://user-images.githubusercontent.com/8125635/137029211-45bff703-d19b-4a4a-a0ab-6d4149b0cb25.png)

Repeat this through the volume to cleanly segment the image as desired. If close inspection reveals many errors, try running Component Analyzer again with new voxel intensity and/or size thresholds. 

Once you are satisfied with the result, you can save an 8-bit TIFF series of the segmentation. To do this, click the Mask: Hide Outside box at the bottom of the Properties Panel and click the Save floppy disk icon at the top of the Workspace panel. Create a directory for the TIFF series. Each tiff will be named in ascending sequence. This process may take an hour or more if the volume is large. 

### Post VVD Neuron Segmentation Processing


![segmentation_workflow](https://user-images.githubusercontent.com/8125635/137175656-7d8e36fb-6449-4e45-a32c-895882edb9b9.png)


We now have a TIFF series of the segmented volume. However, this segmentation result will overmask the neuron on the edges in most cases (Fig. 10B, E, H, K). This is because the segmentation result was generated on a downsampled VVD pyramid. This was necessary to allow fast segmentation and smooth 3D editing of the multi-terabyte full resolution image volume. To correct overmasking and to generate a final binary mask of the neuron that can be used for further data analysis, we have developed a Post VVD Viewer segmentation image processing workflow. The steps and representative results of this workflow are detailed in Figure 10. 

**Figure 10: Example of a VVD Viewer segmentation mask and post-VVD mask processing results**

![post_VVD_examples](https://user-images.githubusercontent.com/8125635/137176640-428164b6-bec8-4faf-ab09-9fb49968f0e6.png)

The first step of this is to remove the blocky overmasking present in the original VVD generated TIFF series. Because the TIFF series retains the original pixel intensities at 8-bit, we can use an intensity threshold to remove the overmasking. Thresholding removes the overmasking and gives a binary mask that is true to the neural signal (Fig. 10C, E, I, K). We found that a suitable threshold value could be identified by generating a maximum intensity projection (MIP) of the TIFF series, opening that MIP in Fiji (https://imagej.net/software/fiji/), and identifying the Huang and Li threshold values of the MIP (Fiji/Image/Adjust/Threshold). In most cases one or both of these values worked well. However in some cases these values were too low and a higher value was used. Inspecting the thresholds on the MIP generally was a reliable indicator of the full resolution result in 3D. However, this was not always the case and the final mask generated should be overlaid on the original image volume and inspected carefully. 

To generate a MIP, use the TIFF Converter

**TIFF Converter**

The TIFF converter pipeline operates on TIFF series, and converts the data in various ways. For details, check out [Image Processing](./ImageProcessing.md).

Generate a maximum intensity projection (MIP):

    ./pipelines/tiff_converter.nf --input_dir INPUT_TIFF_DIR --mips_output_dir OUTPUT_DIR

After thresholding, the neuron mask will be true to the fluorescent signal of the neuron. However, at 8X, the fluorescent signal along neurons is not completely continuous due to gaps in antibody labeling. To fill these gaps a 3D component connecting algorithm is used. We connected gaps of 20 voxels or less, and iterated this process four times. This reliably connected disconnected neuron components that were clearly part of a continuous neuron with minimal unwanted connections in our 8X ExLLSM images (Fig. 10D, F, J, L). However, different parameters can be used if these do not work well with your data. 

The final steps of the process are to (optionally) convert the pixel shape from diamond to box (doing this will connect some previously disconnected pixels) and to analyze and remove connected components smaller than 2000 pixels (this value can also be changed). The result of these steps creates a binary mask of the neuron signal in the imaging volume that can be used to [analyze connectivity](./SynapsePrediction.md). All of the steps in this process, from thresholding to size filtering can be run using the Post VVD Neuron Segmentation Processing Workflow.   

**Post VVD Neuron Segmentation Processing Workflow**

Each of the components of this Workflow are described in detail in [Image Processing](./ImageProcessing.md). The Workflow runs thresholding, 3D mask connection, TIFF to N5 conversion, a pixel shape change, a connected components analysis, and a size filter to remove components below a given pixel threshold.

Usage:

    ./pipelines/post_vvd_workflow.nf --input_dir INPUT_MASK_DIR --shared_temp_dir SHARED_TEMP_DIR --output_dir OUTPUT_DIR --threshold NUMBER --mask_connection_distance=20 --mask_connection_iterations=4 --connect_mask_mem_gb=100 --output_n5 OUTPUT_N5 --with_connected_comps=true --runtime_opts="-B <OUTPUT_DIR> -B <parent of OUTPUT_N5>"

##### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_dir | Path to directory containing your neuron mask |
| &#x2011;&#x2011;shared_temp_dir | Path to a directory for temporary data (shared with all cluster nodes) -- **this directory will be automatically deleted, so be sure to geneate a unique directory for temp files**|
| --output_dir | Path where the final fully-connected mask should be generated as a TIFF series |
| --output_n5 | Path where final N5 should be generated (if this is empty, no N5 will be generated which means connected components will not run) |

##### Optional Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --with_connected_comps | Generated connected components (see [Connected Components Analysis](./ImageProcessing.md#connected-omponents-analysis) for other parameters). Accepted valued: true or false |
| --mask_connection_distance | 20 | Connection distance  |
| &#x2011;&#x2011;mask_connection_iterations | 4 | Number of iterations |
| --threshold | | Optional intensity threshold to apply before connecting mask |
|--connected_pixels_shape | diamond| Changes the pixel shape (alternative: box) |
| --threshold_cpus | 4 | Number of CPUs to use for thresholding mask |
| --threshold_mem_gb | 8 | Amount of memory (GB) to allocate for thresholding mask |
| --convert_mask_cpus | 3 | Number of CPUs to use for importing mask |
| --convert_mask_mem_gb | 45 | Amount of memory (GB) to allocate for importing mask |
| --connect_mask_cpus | 32 | Number of CPUs to use for connecting mask |
| --connect_mask_mem_gb | 192 | Amount of memory (GB) to allocate for connecting mask |



## Automatic Neuron Segmentation Workflow

The automatic neuron segmentation workflow runs 3D U-Net classification followed by optional post-processing steps. This pipeline has not been tested extensively. 

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


