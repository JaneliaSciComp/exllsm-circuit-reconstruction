#!/bin/bash
DIR=$(cd "$(dirname "$0")"; pwd)
pushd $DIR/..

NEURON_DIR=/nrs/dickson/lillvis/temp/ExM/P1_pIP10/20200808/images/export_substack_crop.n5
RES_DIR=/nrs/scicompsoft/goinac/lillvis/results/test/Q1seg.n5
PROFILE=standard
PROJECT_CODE="dickson"

./neuron_segmentation_pipeline.nf \
         -profile ${PROFILE} \
         --lsf_opts "-P $PROJECT_CODE" \
         --runtime_opts "-B /nrs/scicompsoft/goinac -B /nrs/dickson" \
         --block_size '500,500,500' \
         --partial_volume "1500,2000,0,500,500,500" \
         --volume_partition_size 500 \
         --synapse_model $MODEL \
         --neuron_stack_dir ${NEURON_DIR} \
         --neuron_input_dataset /c1/s0 \
         --neuron_output_dataset /seg \
         --output_dir ${RES_DIR}

popd
