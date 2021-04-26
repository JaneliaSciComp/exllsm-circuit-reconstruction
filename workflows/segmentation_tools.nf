
include {
    create_n5_volume;
    unet_classifier;
    segmentation_postprocessing;
} from '../processes/synapse_detection'

// Partition the input volume and call the UNet classifier for each subvolume
// The input_data contains a tuple with 
workflow classify_regions_in_volume {
    take:
    input_data // [input_image, image_size, output_immage ]
    unet_model

    main:
    def unet_inputs = create_n5_volume(input_data)
    | flatMap {
        def (in_image, image_size, out_image) = it
        partition_volume(image_size).collect {
            def (start_subvol, end_subvol) = it
            [ in_image, start_subvol, end_subvol, out_image, image_size ]
        }
    } // [ in_image, start_subvol, end_subvol, out_image, image_size ]

    def unet_classifier_results = unet_classifier(unet_inputs, unet_model)
    | groupTuple(by: [0,3,4]) // wait for all subvolumes to be done
    | map {
        def (in_image, start_subvol_list, end_subvol_list, out_image, image_size) = it
        [ in_image, image_size, out_image ]
    }

    emit:
    done = unet_classifier_results
}

// connect and select regions from input image that are above a threshold
// if a mask is defined only select the regions that match the mask (mask can be empty - '')
// this is done as a post-process of the UNet classifier
workflow connect_regions_in_volume {
    take:
    input_data // channel of [ input_image, mask, size, output_image ]
    percentage
    threshold

    main:
    def mask_data = input_data
    | map {
        // re-arrange the parameters so that the first 3 elements
        // are the ones expected by create_n5_volume, i.e.
        // [input_image, size, output_image]
        def (in_image, mask, size, out_image) = it
        [ in_image, size, out_image, mask ]
    }
    | create_n5_volume

    def post_processing_inputs = mask_data
    | flatMap {
        def (in_image, size, out_image, mask) = it
        partition_volume(size).collect {
            def (start_subvol, end_subvol) = it
            [ in_image, mask, start_subvol,  end_subvol, out_image, size ]
        }
    }

    def post_processing_results = segmentation_postprocessing(
        post_processing_inputs,
        percentage,
        threshold
    )
    | groupTuple(by: [0,1,4,5]) // wait for all subvolumes to be done
    | map {
        def (in_image, mask, start_subvol_list, end_subvol_list, out_image, size) = it
        [ in_image, mask, size, out_image ]
    }

    emit:
    done = post_processing_results
}

// This workflow applies the UNet classifier and 
// then it connects the regions found by UNet and applies the given mask if a mask is provided
workflow classify_and_connect_regions_in_volume {
    take:
    input_data // [ in_image, mask, image_size, unet_output, post_unet_output ]
    unet_model
    percentage
    threshold

    main:
    def classifier_results = classify_regions_in_volume(
        input_data.map {
            def (in_image, mask, image_size, unet_out_image) = it
            [ in_image, image_size, unet_out_image ]
        },
        unet_model
    ) // [ input_image, image_size, unet_image ]

    def post_classifier_inputs = input_data
    | map {
        // re-arrange the data for the join
        def (in_image, mask, image_size, unet_out_image, post_unet_out_image) = it
        [ in_image, image_size, unet_out_image, mask, post_unet_out_image ]
    }
    | join(classifier_results, by:[0..2])

    def post_classifier_results = connect_regions_in_volume(
        post_classifier_inputs.map {
            def (in_image, image_size, unet_out_image, mask, post_unet_out_image) = it
            [ unet_out_image, mask, image_size, post_unet_out_image ]
        },
        percentage,
        threshold
    ) // [ unet_image, mask, image_size, post_unet_image ]

    // prepare the final result
    done = input_data
    | map {
        def (in_image, mask, image_size, unet_out_image, post_unet_out_image) = it
        [ unet_out_image, mask, image_size, post_unet_out_image, in_image ]
    }
    | join(post_classifier_results, by: [0..3])
    | map {
        def (unet_out_image, mask, image_size, post_unet_out_image, in_image) = it
        [ in_image, mask, image_size, unet_out_image, post_unet_out_image ]
    }

    emit:
    done
}

def partition_volume(volume) {
    partition_size = params.volume_partition_size
    def width = volume[0]
    def height = volume[1]
    def depth = volume[2]
    def ncols = ((width % partition_size) > 0 ? (width / partition_size + 1) : (width / partition_size)) as int
    def nrows =  ((height % partition_size) > 0 ? (height / partition_size + 1) : (height / partition_size)) as int
    def nslices = ((depth % partition_size) > 0 ? (depth / partition_size + 1) : (depth / partition_size)) as int
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
            [
                "${start_col},${start_row},${start_slice}",
                "${end_col},${end_row},${end_slice}"
            ]
        }
}
