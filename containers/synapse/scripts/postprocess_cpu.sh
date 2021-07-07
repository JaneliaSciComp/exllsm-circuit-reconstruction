#!/bin/bash
set -e
umask 0002

if [[ -d /scratch ]]; then
    export MCR_CACHE_ROOT="/scratch/${USER}/mcr_cache_$$"
else
    export MCR_CACHE_ROOT=`mktemp -u`
fi

echo "Using MCR_CACHE_ROOT: ${MCR_CACHE_ROOT}"
[ -d ${MCR_CACHE_ROOT} ] || mkdir -p ${MCR_CACHE_ROOT}

function clean {
    echo "Cleaning up MCR_CACHE_ROOT: ${MCR_CACHE_ROOT}"
    rm -rf ${MCR_CACHE_ROOT}
}
trap clean EXIT

python /scripts/postprocess_cpu.py $*
