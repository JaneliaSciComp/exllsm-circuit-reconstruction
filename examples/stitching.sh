#!/bin/bash
DIR=$(cd "$(dirname "$0")"; pwd)
pushd $DIR/..

# The temporary directory needs to have 10 GB to store large Docker images
export TMPDIR="${TMPDIR:-/opt/tmp}"
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-$TMPDIR}"

PROFILE=lsf
CONTAINER_ENV_ARG="-e --env \"USER=$USER\""
INPUT_DIR=/nrs/scicompsoft/goinac/lillvis/DA1/images
BIND_FLAGS="-B /scratch -B /nrs/scicompsoft/rokicki -B $INPUT_DIR -B /groups/dickson/dicksonlab/lillvis/ExM/lattice/PSFs"
PSF_DIR="/groups/dickson/dicksonlab/lillvis/ExM/lattice/PSFs/20200928/PSFs"
PROJECT_CODE="dickson"

./stitch_pipeline.nf \
        -profile $PROFILE \
        --lsf_opts "-P $PROJECT_CODE" \
        --runtime_opts "-e ${BIND_FLAGS} ${CONTAINER_ENV_ARG}" \
        --workers 4 \
        --gb_per_core 15 \
        --worker_cores 16 \
        --driver_memory 10g \
        --spark_work_dir "$PWD/local" \
        --wait_for_spark_timeout_seconds 300 \
        --stitching_app "$PWD/external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar" \
        --images_dir $INPUT_DIR \
        --output_dir /nrs/scicompsoft/rokicki/exm/results/stitching \
        --psf_dir $PSF_DIR \
        --deconv_cores 4 \
        -with-tower http://nextflow.int.janelia.org/api "$@"
popd
