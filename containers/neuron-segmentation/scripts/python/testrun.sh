python volumeSegmentation.py \
    --whole_vol_shape 2560,6150,10325 \
    --start 2000,2500,2000 \
    --end 2250,2750,2250 \
    -m /groups/dickson/home/lillvisj/UNET_neuron/trained_models/neuron4_p2/neuron4_150.h5 \
    -i /nrs/dickson/lillvis/temp/ExM/P1_pIP10/20200808/images/export_substack_crop.n5 \
    -id /c1/s0 \
    -o /nrs/scicompsoft/goinac/lillvis/results/test/Q1seg.n5 \
    --with_post_processing
