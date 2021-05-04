PROFILE=$1
PROJECT_CODE=$2

./main.nf \
        -profile $PROFILE \
        --runtime_opts "-e -B /nrs/scicompsoft/goinac -B /groups/dickson/dicksonlab/lillvis" \
        --lsf_opts "-P $PROJECT_CODE" \
        --workers 1 \
        --worker_cores 6 \
        --driver_memory 10g \
        --spark_work_dir "$PWD/local" \
        --stitching_app "$PWD/external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar" \
        --images_dir /nrs/scicompsoft/goinac/lillvis/DA1/images \
        --output_dir /nrs/scicompsoft/goinac/lillvis/results/DA1 \
        --psf_dir /groups/dickson/dicksonlab/lillvis/ExM/lattice/PSFs/20200928/PSFs \
        --deconv_cores 4
