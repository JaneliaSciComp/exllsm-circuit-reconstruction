
include {
    unet_classifier;
    segmentation_postprocessing;
} from '../processes/synapse_detection'

include {
    merge_3_channels;
    merge_4_channels;
    duplicate_h5_volume;
} from '../processes/utils'

workflow classify_regions_in_volume {
    take:
    input_image // input image filename
    volume // image volume as a map [width: <val>, height: <val>, depth: <val>]
    model // classifier's model
    output_image // output image filename

    main:
    def seg_data = merge_3_channels(input_image, volume, model)
    | join(duplicate_h5_volume(input_image, volume, output_image), by: 0)
    // [ input, volume, model, output]

    def seg_inputs = seg_data
    | flatMap {
        def img_fn = it[0] // image file name
        def img_vol = it[1] // image volume
        def classifier = it[2] // classifier's model
        def out_img_fn = it[3] // output image file name
        partition_volume(img_fn, img_vol, params.volume_partition_size, [classifier, out_img_fn])
    } // [ img_file, img_subvol, model, out_img_file ]

    def seg_results = unet_classifier(
        seg_inputs.map { it[0] },
        seg_inputs.map { it[2] },
        seg_inputs.map { it[1] },
        seg_inputs.map { it[3] }
    )
    | groupTuple(by: [0,1])
    | map {
        [ it[0], it[1] ] // [ input_img, output_img ]
    }
    | join(seg_data)
    | map {
        [ it[0], it[2], it[1] ] 
    } // [ input_image_file, image_volume, output_image_file ]

    emit:
    done = seg_results
}

workflow locate_regions_in_volume {
    take:
    input_image_filename
    image_volume
    mask_filename
    mask_volume
    output_image_filename

    main:
    def locate_data = merge_4_channels(input_image_filename, mask_filename, image_volume, mask_volume)
    | map {
        def mask_fn = it[1]
        def m_vol = mask_fn ? it[3] : it[2]
        it[0..2] + m_vol
    }
    | join(duplicate_h5_volume(input_image_filename, image_volume, output_image_filename), by: 0)
    // [ input_img, mask, image_volume, mask_volume, output_img]

    def mask_inputs = locate_data
    | flatMap {
        def img_fn = it[0]
        def img_vol = it[2]
        def mask_fn = it[1]
        def mask_vol = it[3]
        def out_img_fn = it[4]
        partition_volume(mask_fn, mask_vol, params.volume_partition_size, [img_fn, img_vol, out_img_fn])
    } // [ mask_file, subvol, in_img_file, img_vol, out_img_file]

    def mask_results = segmentation_postprocessing(
        mask_inputs.map { it[2] }, // input image file,
        mask_inputs.map { it[0] }, // mask file
        mask_inputs.map { it[1] }, // subvol
        params.synapse_mask_threshold,
        params.synapse_mask_percentage,
        mask_inputs.map { it[4] } // output image file
    )
    | groupTuple(by: [0,1,2])
    | map {
        [ it[0], it[1], it[2] ] // [ input_image_file, mask_file, output_image_file ]
    }
    | join(locate_data, by:[0,1])
    | map {
        // [ input_image, mask, output_image, image_vol, mask_vol, output_image ]
        [ it[0], it[3], it[1], it[4], it[2] ]
    } // [ input_image, image_volume, mask_image, mask_volume, output_image ]

    emit:
    done = mask_results
}

def partition_volume(fn, volume, partition_size, additional_fields) {
    def width = volume.width
    def height = volume.height
    def depth = volume.depth
    def ncols = (width % partition_size) > 0 ? (width / partition_size + 1) : (width / partition_size)
    def nrows =  (height % partition_size) > 0 ? (height / partition_size + 1) : (height / partition_size)
    def nslices = (depth % partition_size) > 0 ? (depth / partition_size + 1) : (depth / partition_size)
    [0..nrows-1, 0..ncols-1, 0..nslices-1]
        .combinations()
        .collect {
            def start_row = it[0] * partition_size
            def end_row = start_row + partition_size
            if (end_row > height) {
                end_row = height
            }
            def start_col = it[1] * partition_size
            def end_col = start_col + partition_size
            if (end_col > width) {
                end_col = width
            }
            def start_slice = it[2] * partition_size
            def end_slice = start_slice + partition_size
            if (end_slice > depth) {
                end_slice = depth
            }
            def sub_vol = [
                fn,
                "${start_col},${start_row},${start_slice},${end_col},${end_row},${end_slice}",
            ]
            if (additional_fields) {
                sub_vol + additional_fields
            } else {
                sub_vol
            }
        }
}
