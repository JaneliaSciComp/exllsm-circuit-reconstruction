#!/bin/bash
DIR=$(cd "$(dirname "$0")"; pwd)
pushd $DIR/..

# The temporary directory needs to have 10 GB to store large Docker images
export TMPDIR="${TMPDIR:-/opt/tmp}"
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-$TMPDIR}"

INPUT_DIR="/nrs/scicompsoft/goinac/lillvis/DA1/images"
OUTPUT_DIR="/nrs/scicompsoft/rokicki/exm/results/stitching"
PSF_DIR="/groups/dickson/dicksonlab/lillvis/ExM/lattice/PSFs/20200928/PSFs"

PROFILE=lsf
BIND_FLAGS="-B /scratch -B $INPUT_DIR -B $OUTPUT_DIR -B $PDF_DIR"
PROJECT_CODE="dickson"

./stitch_pipeline.nf \
        -profile $PROFILE \
        --lsf_opts "-P $PROJECT_CODE" \
        --runtime_opts "${BIND_FLAGS}" \
        --workers 4 \
        --gb_per_core 15 \
        --worker_cores 16 \
        --driver_memory 10g \
        --spark_work_dir "$PWD/local" \
        --wait_for_spark_timeout_seconds 300 \
        --images_dir "$INPUT_DIR" \
        --output_dir "$OUTPUT_DIR" \
        --psf_dir "$PSF_DIR" \
        --deconv_cores 4 \
        -with-tower http://nextflow.int.janelia.org/api "$@"

popd
