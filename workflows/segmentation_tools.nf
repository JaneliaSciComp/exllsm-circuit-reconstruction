
include {
    duplicate_h5_volume;
    unet_classifier;
    segmentation_postprocessing;
} from '../processes/synapse_detection'

include {
    merge_2_channels;
    merge_3_channels;
    merge_4_channels;
} from '../processes/utils'

// Partition the input volume and call the UNet classifier for each subvolume
// The input_data contains a tuple with 
workflow classify_regions_in_volume {
    take:
    input_data // channel of [input_image, image_size, output_immage ]

    main:
    def classifier_data = duplicate_h5_volume(input_data)

    def unet_inputs = classifier_data
    | flatMap {
        def (in_img_fn, img_size, out_img_fn) = it
        partition_volume(in_img_fn, img_size, params.volume_partition_size, out_img_fn)
    } // [ in_img_fn, img_subvol, out_img_fn ]

    def unet_classifier_results = unet_classifier(unet_inputs)
    | groupTuple(by: [0,2]) // wait for all subvolumes to be done

    // prepare the final result
    done = input_data
    | join(unet_classifier_results, by:[0,2])
    | map {
        def (in_img_fn, out_img_fn, img_size) = it
        [ in_img_fn, img_size, out_img_fn ]
    }

    emit:
    done
}

// connect and select regions from input image that are above a threshold
// if a mask is defined only select the regions that match the mask (mask can be empty - '')
// this is done as a post-process of the UNet classifier
workflow connect_regions_in_volume {
    take:
    input_data // channel of [ input_image, input_image_size, mask, mask_size, output_image ]

    main:
    def output_data = input_data
    | map {
        def (in_image, in_image_size, mask, mask_size, out_image) = it
        [ in_image, in_image_size, out_image]
    }
    | duplicate_h5_volume

    def mask_data = input_data
    | map {
        // re-arrange the data for the join
        def (in_image, in_image_size, mask, mask_size, out_image) = it
        // if there's no mask defined, use the input image size to partition the work
        if (!mask) {
            mask_size = in_image_size
        }
        [ in_image, in_image_size, out_image, mask, mask_size ]
    }

    def post_processing_inputs = mask_data
    | join(output_data, by:[0..2])
    | flatMap {
        def (in_image, in_image_size, out_image, mask, mask_size) = it
        partition_volume(mask, mask_size, params.volume_partition_size,
                         [in_image, in_image_size, out_image])
    } // [ mask, mask_subvol, in_img_file, in_img_size, out_img_file]
    | map {
        def (mask, mask_subvol, in_image, in_image_size, out_image) = it
        [ in_image, mask, mask_subvol, out_image ]
    }

    def post_processing_results = segmentation_postprocessing(post_processing_inputs)
    | groupTuple(by: [0..2]) // wait for all subvolumes to be done
    
    // prepare the final result
    done = mask_data.map {
        def (in_image, in_image_size, out_image, mask, mask_size) = it
        [ in_image, mask, out_image, in_image_size, mask_size ]
    }
    | join(post_processing_results, by:[0..2])
    | map {
        def (in_image, mask, out_image, in_image_size, mask_size) = it
        [ in_image, in_image_size, mask, mask_size, out_image ]
    }

    emit:
    done
}

// This workflow applies the UNet classifier and 
// then it connects the regions found by UNet and applies the given mask if a mask is provided
workflow classify_and_connect_regions_in_volume {
    take:
    input_data // channel of tuples [ in_image, in_image_size, mask, mask_size, unet_output, post_unet_output ]

    main:
    def classifier_results = classify_regions_in_volume(
        input_data.map {
            def (in_image, in_image_size, mask, mask_size, unet_out_image) = it
            [ in_image, in_image_size, unet_out_image ]
        }
    ) // [ input_image, input_image_size, unet_image ]

    def post_classifier_inputs = input_data
    | map {
        // re-arrange the data for the join
        def (in_image, in_image_size, mask, mask_size, unet_out_image, post_unet_out_image) = it
        [ in_image, in_image_size, unet_out_image, mask, mask_size, post_unet_out_image ]
    }
    | join(classifier_results, by:[0..2])

    def post_classifier_results = connect_regions_in_volume(
        post_classifier_inputs.map {
            def (in_image, in_image_size, unet_out_image, mask, mask_size, post_unet_out_image) = it
            [ unet_out_image, in_image_size, mask, mask_size, post_unet_out_image ]
        }
    ) // [ unet_image, input_image_size, mask, mask_size, post_unet_image ]

    // prepare the final result
    done = input_data
    | map {
        def (in_image, in_image_size, mask, mask_size, unet_out_image, post_unet_out_image) = it
        [ unet_out_image, in_image_size, mask, mask_size, post_unet_out_image, in_image ]
    }
    | join(post_classifier_results, by: [0,2,4])
    | map {
        def (unet_out_image, in_image_size, mask, mask_size, post_unet_out_image, in_image) = it
        [ in_image, in_image_size, mask, mask_size, unet_out_image, post_unet_out_image ]
    }

    emit:
    done
}

def partition_volume(fn, volume, partition_size, additional_fields) {
    def width = volume.width
    def height = volume.height
    def depth = volume.depth
    def ncols = ((width % partition_size) > 0 ? (width / partition_size + 1) : (width / partition_size)) as int
    def nrows =  ((height % partition_size) > 0 ? (height / partition_size + 1) : (height / partition_size)) as int
    def nslices = ((depth % partition_size) > 0 ? (depth / partition_size + 1) : (depth / partition_size)) as int
    log.info "Partition $fn of size $volume into $ncols x $nrows x $nslices subvolumes"
    [0..ncols-1, 0..nrows-1, 0..nslices-1]
        .combinations()
        .collect {
            def start_col = it[0] * partition_size
            def end_col = start_col + partition_size
            if (end_col > width) {
                end_col = width
            }
            def start_row = it[1] * partition_size
            def end_row = start_row + partition_size
            if (end_row > height) {
                end_row = height
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
