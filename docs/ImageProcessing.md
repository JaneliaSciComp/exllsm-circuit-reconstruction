# Image Processing

This set of workflows includes various image processing tasks:
* 3D mask connection
* ROI cropping
* Thresholding
* MIP creation
* VVD file creation

## Global Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --fiji_macro_container | registry.int.janelia.org/exm-analysis/exm-tools-fiji:1.0.1 | Docker container for image processing Fiji macros |


## 3D mask connection

Usage: 

    ./connect_pipeline.nf --input_mask_dir INPUT_MASK_DIR --shared_temp_dir SHARED_TEMP_DIR --output_dir OUTPUT_DIR

The 3D mask connection workflow consists of a thresholding step, followed by a conversion into a block-based format, then connection, and then conversion back to TIFF.

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_mask_dir | Path to directory containing your neuron mask |
| --shared_temp_dir | Path to a directory for temporary data (shared with all cluster nodes) |
| --output_dir | Path where the final fully-connected mask should be generated |

### Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --mask_connection_distance | 20 | Connection distance  |
| --mask_connection_iterations | 4 | Number of iterations |
| --threshold_cpus | 4 | Number of CPUs to use for thresholding mask |
| --threshold_mem_gb | 8 | Amount of memory (GB) to allocate for thresholding mask |
| --convert_mask_cpus | 3 | Number of CPUs to use for importing mask |
| --convert_mask_mem_gb | 45 | Amount of memory (GB) to allocate for importing mask |
| --connect_mask_cpus | 32 | Number of CPUs to use for connecting mask |
| --connect_mask_mem_gb | 192 | Amount of memory (GB) to allocate for connecting mask |


## ROI cropping

Usage:

    ./pipelines/crop_tiff.nf --input_dir INPUT_DIR --output_dir OUTPUT_DIR --roi_dir= ROI_DIR --crop_start_slice=START_SLICE --crop_end_slice=END_SLICE --crop_format=uncompressedTIFF

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_dir | Directory containing input TIFF slices | 
| --output_dir | Directory where output TIFF slices will be saved |
| --roi_dir | Directory containing the region-of-interest in [Fiji ROI format](https://github.com/imagej/imagej1/blob/master/ij/io/RoiDecoder.java) | 
| --crop_start_slice | Index of first Z slice to include in the output |
| --crop_end_slice | Index of the last Z slice to include in the output |

### Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --crop_format | TIFFPackBits_8bit | Output format, one of: ZIP, uncompressedTIFF, TIFFPackBits_8bit, or LZW |
| --crop_cpus | 4 | Number of CPUs to use for cropping process |
| --crop_mem_gb | 8 | Amount of memory (GB) to allocate for cropping process |


## Thresholding

Usage:

    ./pipelines/thresholding.nf --input_dir=INPUT_DIR --output_dir=OUTPUT_DIR --threshold=THRESHOLD

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_dir | Directory containing input TIFF slices | 
| --output_dir | Directory where output TIFF slices will be saved |
| --threshold | Intensity threshold |

### Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --threshold_cpus | 4 | Number of CPUs to use for thresholding mask |
| --threshold_mem_gb | 8 | Amount of memory (GB) to allocate for thresholding mask |


## MIP creation

Generates MIPs for an N5 image.

Usage:

    ./n5_converter.nf TBD

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --images_dir | Path to input N5 | 
| --output_dir | Directory where output TIFF slices will be saved |
| --mips_output_dir | Directory where MIPs will be saved |

### Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --create_mip_cpus | 4 | Number of CPUs to use for MIP creation process |
| --create_mip_mem_gb | 8 | Amount of memory (GB) to allocate for MIP creation process |


## VVD file creation

Exports an N5 to VVD format.

Usage:

    ./n5_converter.nf TBD

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --images_dir | Path to input N5 | 
| --default_n5_dataset | N5 data set | 
| --vvd_output_dir | Directory where output VVD files will be saved |

### Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --vvd_min_scale_factor | 0 | |
| --vvd_max_scale_factor | 10 | |
| --vvd_pyramid_level | 5 | |
| --vvd_scale_levels | | |
| --vvd_final_ratio | 10 | |
| --vvd_min_threshold | 100 | |
| --vvd_max_threshold | 2100 | |
| --vvd_export_cpus | 32 | |
| --vvd_export_mem_gb | 192 | |
