
include {
    create_n5_volume;
} from '../processes/n5_tools'

include {
    unet_classifier;
    segmentation_postprocessing;
    aggregate_csvs;
} from '../processes/synapse_detection'

include {
    index_channel;
} from '../utils/utils'

// Partition the input volume and call the UNet classifier for each subvolume
// The input_data contains a tuple with 
workflow classify_regions_in_volume {
    take:
    input_data // [ input_image, output_image, size ]
    unet_model

    main:
    def unet_inputs = input_data
    | map {
        def (in_image, out_image) = it
        [ in_image, out_image, params.default_n5_dataset ]
    }
    | create_n5_volume
    | join(input_data, by: [0,1])
    | flatMap {
        def (in_image, out_image, image_size) = it
        partition_volume(image_size).collect {
            def (start_subvol, end_subvol) = it
            [ in_image, out_image, image_size, start_subvol, end_subvol, ]
        }
    } // [ in_image, start_subvol, end_subvol, out_image, image_size ]

    def unet_classifier_results = unet_classifier(unet_inputs, unet_model)
    | groupTuple(by: [0,1,2]) // wait for all subvolumes to be done
    | map {
        def (in_image, out_image, image_size) = it
        [ in_image, out_image, image_size, ]
    }

    emit:
    done = unet_classifier_results
}

// connect and select regions from input image that are above a threshold
// if a mask is defined only select the regions that match the mask (mask can be empty - '')
// this is done as a post-process of the UNet classifier
workflow connect_regions_in_volume {
    take:
    input_data // channel of [ input_image, mask, output_image, size ]
    threshold
    percentage

    main:
    def re_arranged_input_data = input_data
    | map {
        def (in_image, mask, out_image, size) = it
        [ in_image, out_image, mask, size ]
    }
    def post_processing_inputs = re_arranged_input_data
    | map {
        def (in_image, out_image) = it
        [ in_image, out_image, params.default_n5_dataset  ]
    }
    | create_n5_volume
    | join(re_arranged_input_data, by: [0,1])
    | flatMap {
        def (in_image, out_image, mask, size) = it
        def out_image_file = file(out_image)
        def csv_folder_name = out_image_file.name - ~/\.\w+$/
        partition_volume(size).collect {
            def (start_subvol, end_subvol) = it
            [
                in_image, mask, out_image,
                "${out_image_file.parent}/${csv_folder_name}_csv",
                size, start_subvol, end_subvol,
            ]
        }
    }

    def post_processing_results = segmentation_postprocessing(
        post_processing_inputs,
        threshold,
        percentage,
    )
    | groupTuple(by: [0,1,2,3,4]) // wait for all subvolumes to be done
    | map {
        def (in_image, mask, out_image, out_csvs_dir,
             size, start_subvol_list, end_subvol_list) = it
        def output_csv_file = out_csvs_dir.replace('_csv', '.csv')
        def r = [ out_csvs_dir, output_csv_file, in_image, mask, out_image, size ]
        log.debug "Segmentation post-processing result: $it -> $r"
        r
    }

    def final_post_processing_results = aggregate_csvs(
        post_processing_results.map { it[0..1] }
    )
    | join(post_processing_results, by:[0,1])
    | map {
        def (out_csvs_dir, output_csv_file, in_image, mask, out_image, size) = it
        [ in_image, mask, out_image, size, output_csv_file ]
    }

    emit:
    done = final_post_processing_results
}

// This workflow applies the UNet classifier and 
// then it connects the regions found by UNet and applies the given mask if a mask is provided
workflow classify_and_connect_regions_in_volume {
    take:
    unet_input // [ in_image, unet_output, image_size ]
    post_input // [ mask, post_unet_output ]
    unet_model
    threshold
    percentage

    main:
    def input_data = index_channel(unet_input)
    | join(index_channel(post_input), by:0)
    | map {
        def (idx, unet_args, post_unet_args) = it
        def (in_image, unet_output, image_size) = unet_args
        def (mask, post_unet_output) = post_unet_args
        def d = [ in_image, unet_output, mask, post_unet_output, image_size ]
        log.debug "U-Net and Post U-Net input: $it -> $d"
        d
    }

    def classifier_results = classify_regions_in_volume(
        unet_input,
        unet_model
    ) // [ input_image, unet_image, image_size,  ]

    classifier_results.subscribe { log.debug "U-Net results: $it" }

    def post_classifier_inputs = input_data
    | join(classifier_results, by: [0,1])
    | map {
        def (in_image, unet_output, mask, post_unet_output, image_size) = it
        def d = [ unet_output, mask, post_unet_output, image_size ]
        log.debug "Post U-Net inputs: $it -> $d"
        d
    }

    def post_classifier_results = connect_regions_in_volume(
        post_classifier_inputs,
        threshold,
        percentage
    ) // [ unet_image, mask, post_unet_image, image_size, post_unet_csv ]

    post_classifier_results.subscribe { log.debug "Post U-Net results: $it" }

    // prepare the final result
    done = input_data
    | map {
        def (in_image, unet_output, mask, post_unet_output, image_size) = it
        [ unet_output, mask, post_unet_output, image_size, in_image ]
    }
    | join(post_classifier_results, by: [0,1,2,3])
    | map {
        def (unet_output, mask, post_unet_output, image_size,
             in_image, post_unet_csv) = it
        def r = [
            in_image,
            mask,
            unet_output,
            post_unet_output,
            image_size,
            post_unet_csv,
        ]
        log.debug "Post U-Net final results: $it -> $r"
        r
    } // [ input_image, mask, unet_output, post_unet_output, size, post_unet_csv ]

    emit:
    done
}

def partition_volume(volume) {
    partition_size = params.volume_partition_size
    def (start_x, start_y, start_z, dx, dy, dz) = get_processed_volume(volume, params.partial_volume)
    def ncols = ((dx % partition_size) > 0 ? (dx / partition_size + 1) : (dx / partition_size)) as int
    def nrows =  ((dy % partition_size) > 0 ? (dy / partition_size + 1) : (dy / partition_size)) as int
    def nslices = ((dz % partition_size) > 0 ? (dz / partition_size + 1) : (dz / partition_size)) as int
    [0..ncols-1, 0..nrows-1, 0..nslices-1]
        .combinations()
        .collect {
            def start_col = it[0] * partition_size
            def end_col = start_col + partition_size
            if (end_col > dx) {
                end_col = dx
            }
            def start_row = it[1] * partition_size
            def end_row = start_row + partition_size
            if (end_row > dy) {
                end_row = dy
            }
            def start_slice = it[2] * partition_size
            def end_slice = start_slice + partition_size
            if (end_slice > dz) {
                end_slice = dz
            }
            [
                "${start_x + start_col},${start_y + start_row},${start_z + start_slice}",
                "${start_x + end_col},${start_y + end_row},${start_z + end_slice}"
            ]
        }
}

def get_processed_volume(volume, partial_volume) {
    def (width, height, depth) = volume
    if (partial_volume) {
        def (start_x, start_y, start_z, dx, dy, dz) = partial_volume.split(',').collect { it as int }
        if (start_x < 0 || start_x >= width) {
            log.error "Invalid start x: ${start_x}"
            throw new IllegalArgumentException("Invalid start x: ${start_x}")
        }
        if (start_y < 0 || start_y >= height) {
            log.error "Invalid start y: ${start_y}"
            throw new IllegalArgumentException("Invalid start y: ${start_y}")
        }
        if (start_z < 0 || start_z >= depth) {
            log.error "Invalid start z: ${start_z}"
            throw new IllegalArgumentException("Invalid start z: ${start_z}")
        }
        if (start_x + dx > width) dx = width - start_x
        if (start_y + dy > height) dy = height - start_y
        if (start_z + dz > depth) dz = depth - start_z
        [ start_x, start_y, start_z, dx, dy, dz]
    } else {
        [ 0, 0, 0, width, height, depth]
    }
}
