# Image Processing

This set of workflows includes various image processing tasks:
* 3D mask connection
* ROI cropping
* Cross-talk subtraction
* MIP creation

## Global Optional Parameters

These parameters are required for all workflows:

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --fiji_macro_container | registry.int.janelia.org/exm-analysis/exm-tools-fiji:1.0.1 | Docker container for image processing Fiji macros |

## 3D mask connection

Usage: 
    ./connect_pipeline.nf --input_mask_dir INPUT_MASK_DIR --shared_temp_dir SHARED_TEMP_DIR --output_dir OUTPUT_DIR

The 3D mask connection workflow consists of a thresholding step, followed by a conversion into a block-based format, then connection, and then conversion back to TIFF.

### Required Parameters

These parameters are required for all workflows:

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_mask_dir | Path to directory containing your neuron mask |
| --shared_temp_dir | Path to a directory for temporary data (shared with all cluster nodes) |
| --output_dir | Path where the final fully-connected mask should be generated |

### Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --mask_connection_vx | 20 |  |
| --mask_connection_time | 4 |  |
| --threshold_cpus | 4 | Number of CPUs to use for thresholding mask |
| --threshold_mem_gb | 8 | Amount of memory (GB) to allocate for thresholding mask |
| --convert_mask_cpus | 3 | Number of CPUs to use for importing mask |
| --convert_mask_mem_gb | 45 | Amount of memory (GB) to allocate for importing mask |
| --connect_mask_cpus | 32 | Number of CPUs to use for connecting mask |
| --connect_mask_mem_gb | 192 | Amount of memory (GB) to allocate for connecting mask |

## ROI cropping

TBD

## Cross-talk subtraction

TBD

## MIP creation

TBD
