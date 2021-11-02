# Image Processing

This set of workflows includes various image processing tasks:

* [ROI cropping](#roi-cropping)
* [3D component connection](#3d-component-connection)
* [Pixel intensity thresholding](#pixel-intensity-thresholding)
* [Connected components analysis](#connected-components-analysis)
* [Pixel shape change](#connected-components-analysis)
* [Component size thresholding](#connected-components-analysis)
* [MIP generation](#tiff-converter)
* [TIFF to N5/VVD conversion](#tiff-converter)
* [N5 to TIFF/VVD conversion](#n5-converter)
* [N5 multiscale pyramid generation](#n5-converter)
* [N5 resaving](#n5-converter)
* [Post VVD Neuron Segmentation Processing Workflow](#post-vvd-neuron-segmentation-processing-workflow)

## Global Optional Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --fiji_macro_container | registry.int.janelia.org/exm-analysis/exm-tools-fiji:1.1.0 | Docker container for image processing Fiji macros |
| --exm_synapse_dask_container | registry.int.janelia.org/exm-analysis/synapse-dask:1.3.1 | Docker container for Dask-based processing scripts |
| &#x2011;&#x2011;exm_neuron_segmentation_container | registry.int.janelia.org/exm-analysis/neuron-segmentation:1.0.0 | Docker container for neuron segmentation scripts |
| --spark_work_dir | $workDir/spark | Path to directory containing Spark working files and logs |
| --workers | 4 | Number of Spark workers to use for Spark jobs |
| --worker_cores | 4 | Number of cores allocated to each Spark worker |
| --gb_per_core | 15 | Size of memory (in GB) that is allocated for each core of a Spark worker. The total memory usage for Spark jobs will be workers *worker_cores* gb_per_core. |
| --driver_memory | 15g | Amount of memory to allocate for the Spark driver |
| --driver_stack_size | 128m | Amount of stack space to allocate for the Spark driver |

## ROI cropping

Crops a TIFF series in x/y/z based on an x/y ROI and start and end z slices.

Usage:

    ./pipelines/crop_tiff.nf --input_dir INPUT_DIR --output_dir OUTPUT_DIR --roi_dir ROI_DIR --crop_start_slice START_SLICE --crop_end_slice END_SLICE --crop_format uncompressedTIFF

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_dir | Directory containing input TIFF slices |
| --output_dir | Directory where output TIFF slices will be saved |
| --roi_dir | Directory containing the region-of-interest in [Fiji ROI format](https://github.com/imagej/imagej1/blob/master/ij/io/RoiDecoder.java) |
| --crop_start_slice | Index of first Z slice to include in the output |
| --crop_end_slice | Index of the last Z slice to include in the output |

### Optional Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --crop_format | uncompressedTIFF | Output format, one of: ZIP, uncompressedTIFF, TIFFPackBits_8bit, or LZW |
| --crop_cpus | 24 | Number of CPUs to use for cropping process |
| --crop_mem_gb | 16 | Amount of memory (GB) to allocate for cropping process |

## 3D component connection

Converts an input TIFF series into a block-based format, then runs a connection algorithm, and then converts back to TIFF series.

Usage:

    ./pipelines/connect_mask.nf --input_dir INPUT_MASK_DIR --shared_temp_dir SHARED_TEMP_DIR --output_dir OUTPUT_DIR

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_dir | Path to directory containing your neuron mask |
| --shared_temp_dir | Path to a directory for temporary data (shared with all cluster nodes) |
| --output_dir | Path where the final fully-connected mask should be generated |

### Optional Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --mask_connection_distance | 20 | Connection distance in voxels  |
| &#x2011;&#x2011;mask_connection_iterations | 4 | Number of connection interations (i.e. connect components 20 vx apart four times) |
| --threshold | | Optional pixel intensity threshold to apply before connecting mask |
| --clean_temp_dirs | true | Remove temporary files created inside `--shared_temp_dir` after a successful pipeline run |
| --convert_mask_cpus | 32 | Number of CPUs to use for importing mask |
| --convert_mask_mem_gb | 45 | Amount of memory (GB) to allocate for importing mask |
| --connect_mask_cpus | 32 | Number of CPUs to use for connecting mask |
| --connect_mask_mem_gb | 192 | Amount of memory (GB) to allocate for connecting mask |

## Pixel intensity thresholding

Applies an intensity thresholding operation to a TIFF series.

Usage:

    ./pipelines/thresholding.nf --input_dir INPUT_DIR --output_dir OUTPUT_DIR --threshold THRESHOLD

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_dir | Directory containing input TIFF slices |
| --output_dir | Directory where output TIFF slices will be saved |
| --threshold | Intensity threshold |

### Optional Parameters

| Argument   | Default |                                                                             |
|------------|---------|-----------------------------------------------------------------------------|
| --threshold_cpus | 24 | Number of CPUs to use for thresholding mask |
| --threshold_mem_gb | 16 | Amount of memory (GB) to allocate for thresholding mask |

## Connected Components Analysis

Uses [n5-spark](https://github.com/saalfeldlab/n5-spark) to find and label all connected components in a binary mask extracted from the input N5 dataset, and saves the relabeled dataset as an uint64 output dataset. This process also saves statistics on the component sizes. Includes options to **Change the Pixel Shape** (diamond or box), to **Apply a Pixel Intensity Threshold**, and to **Apply a Component Size Threshold**.

Usage:

    ./pipelines/connected_components.nf --runtime_opts="-B INPUT_DIR" --input_n5 INPUT_N5 --input_dataset /c0/s0 --connected_dataset /connected/s0

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_n5 | Path to input N5 |

### Optional Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --input_dataset | /s0 | Input data set to process |
| --connected_dataset | /connected/s0 | Output data set |
| --connected_pixels_shape | box | Shape used for connected components (alternative: diamond) |
| --min_connected_pixels | 2000 | Components below this number of pixels are removed |
| --connected_pixels_threshold | .8 | Intensity threshold. Pixels below this threshold are discarded. This process is applied before size thresholding. |
| &#x2011;&#x2011;connected_comps_block_size | 128,128,64 | Block size used for generating connected components |
| --connected_comps_pyramid | false | If true generates multiscale pyramids for connected components |

## TIFF Converter

The TIFF converter pipeline operates on TIFF series, and converts the data in various ways. Note that any Spark-based tool still requires the bind mounts to be set explicitly using `--runtime_opts`.

Usage:

Generate a maximum intensity projection (MIP):

    ./pipelines/tiff_converter.nf --input_dir INPUT_TIFF_DIR --mips_output_dir OUTPUT_DIR

Convert from TIFF to N5 format:

    ./pipelines/tiff_converter.nf --input_dir INPUT_TIFF_DIR --output_n5 OUTPUT_N5 --output_dataset /s0

Convert from TIFF to VVD format (uses a fork of [n5-spark](https://github.com/JaneliaSciComp/n5-spark) -- see [Global Optional Parameters](#global-optional-parameters) for Spark-specific parameters):

    ./pipelines/tiff_converter.nf --input_dir INPUT_TIFF_DIR --vvd_output_dir OUTPUT_DIR 

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_dir | Directory containing input TIFF slices |
| --output_n5 | Path where output N5 will be saved |
| --mips_output_dir | Directory where MIPs will be saved |
| --vvd_output_dir | Directory where output VVD files will be saved |

### Optional Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --create_mip_cpus | 24 | Number of CPUs to use for generating the MIP |
| --create_mip_mem_gb | 8 | Amount of memory (GB) to allocate for generating the MIP |
| --output_dataset | /s0 | N5 data set |
| --partial_volume | | Comma delimited coordinates defining a bounding box for the partial volume. If set, only this partial volume is processed. |
| --vvd_block_size | 256,256,256 | Block size to use for VVD output. |
| --vvd_data_type | uint16 | Coerced data type for the VVD output. You can set this to the empty string to use the input data type, but VVD cannot read certain data types like uin64, which is why the default here is uint16. |
| --vvd_min_threshold | | Minimum value of the input range to be used for the conversion (default is min type value for integer types, or 0 for real types) |
| --vvd_max_threshold | | Maximum value of the input range to be used for the conversion (default is max type value for integer types, or 1 for real types). |
| --vvd_min_scale_factor | 0 | Minimum downsampling factor for the VVD multiscale pyramid. |
| &#x2011;&#x2011;vvd_max_scale_factor | 10 | Maximum downsampling factor for the VVD multiscale pyramid. |
| --vvd_pyramid_level | 5 | Number of levels in the multiscale pyramid. |
| --vvd_scale_levels | | Explicit downsampling factors, delimited by colons (`:`). When specifying multiple factors, each factor builds on the last. This cannot be used with `--vvd_min_scale_factor`, `--vvd_max_scale_factor`, and `--vvd_pyramid_level`. |

## N5 Converter

The N5 converter pipeline operates on N5 containers, and converts the data in various ways. All of the options can be enabled at once if desired. Note that any Spark-based tool still requires the bind mounts to be set explicitly using `--runtime_opts`.

Usage:

Add a multiscale pyramid to an existing N5:

    ./pipelines/n5_converter.nf --runtime_opts="-B INPUT_DIR" --input_dir INPUT_N5 --multiscale_pyramid=true

Convert N5 to TIFF:

    ./pipelines/n5_converter.nf --runtime_opts="-B INPUT_DIR" --input_dir INPUT_N5 --tiff_output_dir OUTPUT_DIR

Generate MIPs, saving the MIPs inside the N5 container:

    ./pipelines/n5_converter.nf --runtime_opts="-B INPUT_N5" --input_dir INPUT_N5 --mips_output_dir INPUT_N5/mips

Convert N5 to VVD, saving the VVD files inside the N5 container:

    ./pipelines/n5_converter.nf --runtime_opts="-B INPUT_N5" --input_dir INPUT_N5 --vvd_output_dir INPUT_N5/vvd

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_dir | Path to input N5 |

### Optional Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --input_dataset | /s0 | N5 data set to process |
| --multiscale_pyramid | false | Generate multiscale pyramid (i.e. /s1, /s2, etc.) |
| --tiff_output_dir | | Directory where output TIFF slices will be saved |
| --mips_output_dir | | Directory where MIPs will be saved |
| --vvd_output_dir | | Directory where output VVD files will be saved |
| --use_n5_spark_tools | true | Set to false to use Dask tools when possible. They're much faster than the Spark tools, but not as well tested. |
| --vvd_block_size | 256,256,256 | Block size to use for VVD output. |
| --vvd_data_type | uint16 | Coerced data type for the VVD output. You can set this to the empty string to use the input data type, but VVD cannot read certain data types like uin64, which is why the default here is uint16. |
| --vvd_min_threshold | | Minimum value of the input range to be used for the conversion (default is min type value for integer types, or 0 for real types) |
| --vvd_max_threshold | | Maximum value of the input range to be used for the conversion (default is max type value for integer types, or 1 for real types). |
| --vvd_min_scale_factor | 0 | Minimum downsampling factor for the VVD multiscale pyramid. |
| &#x2011;&#x2011;vvd_max_scale_factor | 10 | Maximum downsampling factor for the VVD multiscale pyramid. |
| --vvd_pyramid_level | 5 | Number of levels in the multiscale pyramid. |
| --vvd_scale_levels | | Explicit downsampling factors, delimited by colons (`:`). When specifying multiple factors, each factor builds on the last. This cannot be used with `--vvd_min_scale_factor`, `--vvd_max_scale_factor`, and `--vvd_pyramid_level`. |
| --tiff2n5_cpus | 24 | Number of CPUs to use for TIFF to N5 |
| --tiff2n5_memory | 126 | Amount of meory (GB) to allocate for TIFF to N5 |
| --n52tiff_cpus | 24 | Number of CPUs to use for Dask-based n5 to TIFF (only used if `--use_n5_spark_tools=false`) |
| --n52tiff_memory | 126 | Amount of memory (GB) to allocate for Dask-based n5 to TIFF (only used if `--use_n5_spark_tools=false`) |

## Post VVD Neuron Segmentation Processing Workflow

Usage:

    ./pipelines/post_vvd_workflow.nf --input_dir INPUT_MASK_DIR --shared_temp_dir SHARED_TEMP_DIR --output_dir OUTPUT_DIR --mask_connection_distance=20 --mask_connection_iterations=4 --connect_mask_mem_gb=100 --output_n5 OUTPUT_N5 --with_connected_comps=true --runtime_opts="-B <OUTPUT_DIR> -B <parent of OUTPUT_N5>"

This is the post-VVD Viewer semi-automatic neuron segmentation workflow. Runs thresholding, 3D mask connection, TIFF to n5 conversion, and n5 connected components.

### Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --input_dir | Path to directory containing your neuron mask |
| &#x2011;&#x2011;shared_temp_dir | Path to a directory for temporary data (shared with all cluster nodes) -- THIS WILL BE DELETED SO BE SURE TO MAKE A UNIQUE DIRECTORY FOR TEMP FILES|
| --output_dir | Path where the final fully-connected mask should be generated as a TIFF series |
| --output_n5 | Path where final n5 should be generated (if this is empty, no N5 will be generated which means connected components will not run) |

### Optional Parameters

| Argument   | Default | Description                                                                 |
|------------|---------|-----------------------------------------------------------------------------|
| --with_connected_comps | Generated connected components (see *Connected Components* pipeline for other parameters). Accepted valued: true or false |
| --mask_connection_distance | 20 | Connection distance  |
| &#x2011;&#x2011;mask_connection_iterations | 4 | Number of iterations |
| --threshold | | Optional intensity threshold to apply before connecting mask |
| --threshold_cpus | 24 | Number of CPUs to use for thresholding mask |
| --threshold_mem_gb | 16 | Amount of memory (GB) to allocate for thresholding mask |
| --convert_mask_cpus | 32 | Number of CPUs to use for importing mask |
| --convert_mask_mem_gb | 45 | Amount of memory (GB) to allocate for importing mask |
| --connect_mask_cpus | 32 | Number of CPUs to use for connecting mask |
| --connect_mask_mem_gb | 192 | Amount of memory (GB) to allocate for connecting mask |
