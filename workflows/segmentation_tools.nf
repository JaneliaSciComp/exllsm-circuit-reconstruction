
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

include {
    partition_volume;
} from './segmentation_utils'

// Partition the input volume and call the UNet classifier for each subvolume
// The input_data contains a tuple with 
workflow classify_regions_in_volume {
    take:
    input_data // [ input_image, input_dataset, output_image, output_dataset, size ]
    unet_model
    unet_cpus
    unet_memory

    main:
    def unet_inputs = input_data
    | map {
        def (in_image, in_dataset,
             out_image, out_dataset) = it
        def d = [
            in_image, in_dataset,
            out_image, out_dataset,
            '' // same datatype
        ]
        log.debug "create_n5_volume: $d"
        d
    }
    | create_n5_volume
    | join(input_data, by: [0,1,2,3])
    | flatMap {
        def (in_image, in_dataset,
             out_image, out_dataset,
             image_size) = it
        partition_volume(image_size, params.partial_volume, params.volume_partition_size).collect {
            def (start_subvol, end_subvol) = it
            [
                in_image, in_dataset,
                out_image, out_dataset,
                image_size,
                start_subvol, end_subvol,
            ]
        }
    } // [ in_image, start_subvol, end_subvol, out_image, image_size ]

    def unet_classifier_results = unet_classifier(
        unet_inputs,
        unet_model,
        unet_cpus,
        unet_memory,
    )
    | groupTuple(by: [0,1,2,3,4]) // wait for all subvolumes to be done
    | map {
        def (in_image, in_dataset,
             out_image, out_dataset,
             image_size) = it
        [ in_image, in_dataset, out_image, out_dataset, image_size, ]
    }

    emit:
    done = unet_classifier_results
}

// connect and select regions from input image that are above a threshold
// if a mask is defined only select the regions that match the mask (mask can be empty - '')
// this is done as a post-process of the UNet classifier
workflow connect_regions_in_volume {
    take:
    input_data // channel of [ input_image, input_dataset, mask, mask_dataset, output_image, output_dataset, size, output_csv ]
    threshold
    percentage
    postprocessing_cpus
    postprocessing_memory
    postprocessing_threads
    skip_empty_mask

    main:
    def re_arranged_input_data = input_data
    | filter {
        def (in_image, in_dataset,
             mask, mask_dataset) = it
        !skip_empty_mask || mask
    }
    | map {
        def (in_image, in_dataset,
             mask, mask_dataset,
             out_image, output_dataset,
             size,
             output_csv) = it
        [
            in_image, in_dataset,
            out_image, output_dataset,
            mask, mask_dataset,
            size,
            output_csv
        ]
    }
    def post_processing_inputs = re_arranged_input_data
    | map {
        def (in_image, in_dataset,
             out_image, output_dataset) = it
        [
            in_image, in_dataset,
            out_image, output_dataset,
            '' // same datatype
        ]
    }
    | create_n5_volume
    | join(re_arranged_input_data, by: [0,1,2,3])
    | flatMap {
        def (in_image, in_dataset,
             out_image, output_dataset,
             mask, mask_dataset,
             size,
             output_csv) = it
        partition_volume(size, params.partial_volume, params.volume_partition_size).collect {
            def (start_subvol, end_subvol) = it
            def d = [
                in_image, in_dataset,
                mask, mask_dataset,
                out_image, output_dataset,
                output_csv,
                size,
                start_subvol, end_subvol,
            ]
            log.debug "segmentation_postprocessing: $d"
            d
        }
    }

    def post_processing_results = segmentation_postprocessing(
        post_processing_inputs,
        threshold,
        percentage,
        postprocessing_cpus,
        postprocessing_memory,
        postprocessing_threads
    )
    | groupTuple(by: [0,1,2,3,4,5,6,7]) // wait for all subvolumes to be done
    | map {
        def (in_image, in_dataset,
             mask, mask_dataset,
             out_image, output_dataset,
             out_csvs_dir,
             size,
             start_subvol_list,
             end_subvol_list) = it
        def output_csv_file = out_csvs_dir.replace('_csv', '.csv')
        def r = [
                    out_csvs_dir, output_csv_file,
                    in_image, in_dataset,
                    mask, mask_dataset,
                    out_image, output_dataset,
                    size
                ]
        log.debug "Segmentation post-processing result: $it -> $r"
        r
    }

    def final_post_processing_results = post_processing_results
    | map {
        it[0..1]
    }
    | aggregate_csvs
    | join(post_processing_results, by:[0,1])
    | map {
        def (out_csvs_dir, output_csv_file,
             in_image, in_dataset,
             mask, mask_dataset,
             out_image, output_dataset,
             size) = it
        [
            in_image, in_dataset,
            mask, mask_dataset,
            out_image, output_dataset,
            size,
            output_csv_file
        ]
    }

    emit:
    done = final_post_processing_results
}

// This workflow applies the UNet classifier and 
// then it connects the regions found by UNet and applies the given mask if a mask is provided
workflow classify_and_connect_regions_in_volume {
    take:
    unet_input // [ in_image, in_dataset, unet_output, unet_dataset, image_size ]
    post_input // [ mask, mask_dataset, post_unet_output, post_unet_dataset, output_csv ]
    unet_model
    threshold
    percentage
    unet_cpus
    unet_memory
    postprocessing_cpus
    postprocessing_memory
    postprocessing_threads

    main:
    def input_data = index_channel(unet_input)
    | join(index_channel(post_input), by:0)
    | map {
        def (idx, unet_args, post_unet_args) = it
        def (in_image, in_dataset,
             unet_output, unet_dataset,
             image_size) = unet_args
        def (mask, mask_dataset,
             post_unet_output, post_unet_dataset,
             output_csv) = post_unet_args
        def d = [
            in_image, in_dataset,
            unet_output, unet_dataset,
            mask, mask_dataset,
            post_unet_output, post_unet_dataset,
            image_size,
            output_csv
        ]
        log.debug "U-Net and Post U-Net input: $it -> $d"
        d
    }

    def classifier_results = classify_regions_in_volume(
        unet_input,
        unet_model,
        unet_cpus,
        unet_memory,
    ) // [ input_image, input_dataset, unet_image, unet_dataset, image_size,  ]

    classifier_results.subscribe { log.debug "U-Net results: $it" }

    def post_classifier_inputs = input_data
    | join(classifier_results, by: [0,1,2,3])
    | map {
        def (in_image, in_dataset,
             unet_output, unet_dataset,
             mask, mask_dataset,
             post_unet_output, post_unet_dataset,
             image_size,
             output_csv) = it
        def d = [
            unet_output, unet_dataset,
            mask, mask_dataset,
            post_unet_output, post_unet_dataset,
            image_size,
            output_csv
        ]
        log.debug "Post U-Net inputs: $it -> $d"
        d
    }

    def post_classifier_results = connect_regions_in_volume(
        post_classifier_inputs,
        threshold,
        percentage,
        postprocessing_cpus,
        postprocessing_memory,
        postprocessing_threads,
        false
    ) // [ unet_image, mask, post_unet_image, image_size, post_unet_csv ]

    post_classifier_results.subscribe { log.debug "Post U-Net results: $it" }

    // prepare the final result
    done = input_data
    | map {
        def (in_image, in_dataset,
             unet_output, unet_dataset,
             mask, mask_dataset,
             post_unet_output, post_unet_dataset,
             image_size,
             output_csv) = it
        [
            unet_output, unet_dataset,
            mask, mask_dataset,
            post_unet_output, post_unet_dataset,
            image_size,
            in_image, in_dataset,
        ]
    }
    | join(post_classifier_results, by: [0,1,2,3,4,5,6])
    | map {
        def (unet_output, unet_dataset,
             mask, mask_dataset,
             post_unet_output, post_unet_dataset,
             image_size,
             in_image, in_dataset,
             post_unet_csv) = it
        def r = [
            in_image, in_dataset,
            mask, mask_dataset,
            unet_output, unet_dataset,
            post_unet_output, post_unet_dataset,
            image_size,
            post_unet_csv,
        ]
        log.debug "Post U-Net final results: $it -> $r"
        r
    } // [ input_image, mask, unet_output, post_unet_output, size, post_unet_csv ]

    emit:
    done
}
