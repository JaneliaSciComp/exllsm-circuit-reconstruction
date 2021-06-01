DIR=$(cd "$(dirname "$0")"; pwd)

source ${DIR}/container-versions.sh

docker push registry.int.janelia.org/exm-analysis/synapse:${synapse_version}
docker push registry.int.janelia.org/exm-analysis/synapse-dask:${synapse_dask_version}
docker push registry.int.janelia.org/exm-analysis/neuron-segmentation:${neuron_segmentation_version}
docker push registry.int.janelia.org/exm-analysis/stitching:${stitching_version}
