# Stitching Workflow

The distributed stitching workflows ingests expansion microscopy data as a TIFF slice series and runs the following processing:
- Conversion to n5
- Flatfield correction
- Deconvolution
- Stitching
- Export to n5 and TIFF slice series

All steps besides deconvolution use the [stitching-spark](https://github.com/saalfeldlab/stitching-spark) code from the Saalfeld Lab at Janelia. 

Deconvolution uses a MATLAB script (details TBD). 

## Required Parameters

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| images_dir | Path to directory containing TIFF slices and the ImageList.csv file |
| output_dir | Path to output directory | 
| psf_dir | Path to a point-spread functions for your microscope (details TBD) |

## Optional Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --spark_container_repo | registry.int.janelia.org/exm-analysis | Docker registry and repository for the spark container |
| --spark_container_name | stitching | Name for the container in the spark_container_repo | 
| &#x2011;&#x2011;spark_container_version | `pinned` | Version for the container in the spark_container_repo |
| --stitching_app | /app/app.jar | Path to the JAR file containing the stitching application. |
| --workers | 4 | Number of Spark workers to use for stitching |
| --worker_cores | 4 | Number of cores allocated to each Spark worker |
| --gb_per_core | 15 | Size of memory (in GB) that is allocated for each core of a Spark worker. The total memory usage for stitching will be workers * worker_cores * gb_per_core. | 
| --driver_memory | 15g | Amount of memory to allocate for the Spark driver |
| --driver_stack | 128m | Amount of stack space to allocate for the Spark driver |
| --stitching_output | | Output directory for stitching (relative to --output_dir) |
| --resolution | 0.104,0.104,0.18 | Resolution of the input imagery |
| --axis | -y,-x,z | Axis mapping for objective to pixel coordinates conversion when parsing metadata. Minus sign flips the axis. |
| --channels | 488nm,560nm,642nm | List of channels to stitch |
| --block_size | 128,128,64 | Block size to use when converting to n5 before stitching |
| --stitching_mode | incremental | |
| --stitching_padding | 0,0,0 | |
| --stitching_blur_sigma | 2 | |
| --deconv_cpus | 4 | Number of CPUs to use for deconvolution |
| --background | | TBD |
| --psf_z_step_um | 0.1 | TBD |
| --iterations_per_channel | 10,10,10 | TBD |
| --export_level | 0 | Scale level to export after stitching |
| --allow_fusestage | false | Allow fusing tiles using their stage coordinates |
