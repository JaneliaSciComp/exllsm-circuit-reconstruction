DIR=$(cd "$(dirname "$0")"; pwd)

source ${DIR}/container-versions.sh

docker build \
    --build-arg SYNAPSE_DETECTOR_GIT_TAG=${synapse_git_hash} \
    -t registry.int.janelia.org/exm-analysis/synapse:${synapse_version} \
    -t synapse:${synapse_version} \
    -t synapse \
    containers/synapse

docker build \
    -t registry.int.janelia.org/exm-analysis/synapse-dask:${synapse_dask_version} \
    -t synapse-dask:${synapse_dask_version} \
    -t synapse-dask \
    containers/synapse-dask

docker build \
    --build-arg NEURON_SEGMENTATION_GIT_TAG=${neuron_segmentation_git_hash} \
    -t registry.int.janelia.org/exm-analysis/neuron-segmentation:${neuron_segmentation_version} \
    -t neuron-segmentation:${neuron_segmentation_version} \
    -t neuron-segmentation \
    containers/neuron-segmentation

docker build \
    --build-arg STITCHING_SPARK_GIT_TAG=${stitching_git_hash} \
    -t registry.int.janelia.org/exm-analysis/stitching:${stitching_version} \
    -t stitching:${stitching_version} \
    -t stitching \
    containers/stitching

docker build \
    --build-arg STITCHING_SPARK_GIT_TAG=${n5_spark_tools_git_hash} \
    -t registry.int.janelia.org/exm-analysis/n5-spark-tools:${n5_spark_tools_version} \
    -t n5-spark-tools:${n5_spark_tools_version} \
    -t n5-spark-tools \
    containers/n5-spark-tools
