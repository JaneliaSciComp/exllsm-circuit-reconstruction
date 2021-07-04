#!/bin/bash
DIR=$(cd "$(dirname "$0")"; pwd)
pushd $DIR/..

NEURON_DIR=/nrs/dickson/lillvis/temp/ExM/P1_pIP10/20200808/images/export_substack_crop.n5
RES_DIR=/nrs/scicompsoft/rokicki/exm/results/comps/q1_seg.n5
PROFILE=lsf
PROJECT_CODE="dickson"

./neuron_segmentation_pipeline.nf \
         -profile ${PROFILE} \
         --lsf_opts "-P $PROJECT_CODE" \
         --runtime_opts "-B /nrs/scicompsoft/goinac -B /nrs/scicompsoft/rokicki -B /nrs/dickson" \
         --block_size '250,250,250' \
         --partial_volume "0,0,0,250,250,250" \
         --volume_partition_size 250 \
         --synapse_model $MODEL \
         --neuron_stack_dir ${NEURON_DIR} \
         --neuron_input_dataset /c1/s0 \
         --neuron_output_dataset /segmented/s0 \
         --output_dir ${RES_DIR} \
         --workers 4 \
         --worker_cores 16 \
         --gb_per_core 15 \
         --neuron_percent_scaling_tiles 0.1 \
         --with_connected_comps \
         --spark_work_dir "$PWD/local" \
         --neuron_vvd_output ${RES_DIR}/vvd "$@"

popd
