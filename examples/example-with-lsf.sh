./main.nf -profile lsf \
        --runtime_opts "-e -B /nrs/scicompsoft/goinac" \
        --lsf_opts "-P scicompsoft" \
        --workers 3 \
        --worker_cores 3 \
        --driver_memory 10g \
        --spark_work_dir "$PWD/local" \
        --data_dir /nrs/scicompsoft/goinac/lillvis/DA1/images

