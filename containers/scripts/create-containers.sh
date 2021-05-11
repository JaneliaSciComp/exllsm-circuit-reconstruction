DIR=$(cd "$(dirname "$0")"; pwd)

source ${DIR}/container-versions.sh

docker build \
    -t registry.int.janelia.org/exm-analysis/synapse:${synapse-version} \
    -t synapse:${synapse-version} \
    -t synapse \
    containers/synapse

docker build \
    -t registry.int.janelia.org/exm-analysis/synapse-dask:${synapse-dask-version} \
    -t synapse-dask:${synapse-dask-version} \
    -t synapse-dask \
    containers/synapse-dask
