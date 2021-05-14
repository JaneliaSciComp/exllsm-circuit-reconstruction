
include {
    create_n5_volume;
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
        [ in_image, out_image ]
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
        [ in_image, out_image ]
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
    | groupTuple(by: [0..4]) // wait for all subvolumes to be done
    | map {
        def (in_image, mask, out_image, out_csvs_dir,
             size, start_subvol_list, end_subvol_list) = it
        def output_csv_file = out_csvs_dir.replace('_csv', '.csv')
        [ out_csvs_dir, output_csv_file, in_image, mask, out_image, size ]
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
    done = post_processing_results
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
        def (idx, in_image, unet_output, image_size, mask, post_unet_output) = it
        [ in_image, unet_output, mask, post_unet_output, image_size ]
    }

    def classifier_results = classify_regions_in_volume(
        unet_input,
        unet_model
    ) // [ input_image, unet_image, image_size,  ]

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

    // prepare the final result
    done = input_data
    | map {
        def (in_image, unet_output, mask, post_unet_output, image_size) = it
        [ unet_output, mask, post_unet_output, image_size, in_image ]
    }
    | join(post_classifier_results, by: [0..3])
    | map {
        def (unet_output, mask, post_unet_output, image_size,
             in_image, post_unet_csv) = it
        def r = [
            in_image,
            mask,
            unet_out_image,
            post_unet_out_image,
            image_size,
            post_unet_csv,
        ]
        log.debug "Post U-Net results: $it -> $r"
        r
    } // [ input_image, mask, unet_output, post_unet_output, size, post_unet_csv ]

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
