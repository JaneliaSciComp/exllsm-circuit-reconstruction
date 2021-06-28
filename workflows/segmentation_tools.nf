
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
    downsample_n5;
} from './n5_tools' addParams(params + params.downsample_params)

include {
    n5_to_vvd;
} from './n5_tools' addParams(params + params.vvd_params)

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
    if (params.with_downsampling) {
        def n5_downsampled_res = downsample_n5(
            unet_classifier_results.map { it[2] }, // UNet N5 container
            unet_classifier_results.map { it[3] }, // UNet N5 dataset
            params.downsample_params.app,
            params.downsample_params.spark_conf,
            unet_classifier_results.map {
                get_spark_working_dir(params.downsample_params.spark_work_dir, 'unet', it[3])
            },
            params.downsample_params.workers,
            params.downsample_params.worker_cores,
            params.downsample_params.gb_per_core,
            params.downsample_params.driver_cores,
            params.downsample_params.driver_memory,
            params.downsample_params.driver_stack_size,
            params.downsample_params.driver_logconfig
        )
        n5_downsampled_res.subscribe { log.debug "UNET downsample result: $it" }
    }
    if (params.with_vvd) {
        def vvd_res = n5_to_vvd(
            unet_classifier_results.map { it[2] }, // N5 container
            unet_classifier_results.map { it[3] }, // N5 dataset
            unet_classifier_results.map {
                get_vvd_output_dir(
                    params.vvd_output_dir ? params.vvd_output_dir : "${it[2]}/vvd",
                    it[3])
            }, // VVD output dir
            params.vvd_params.app,
            params.vvd_params.spark_conf,
            unet_classifier_results.map {
                get_spark_working_dir(params.vvd_params.spark_work_dir, 'vvd_unet', it[3])
            },
            params.vvd_params.workers,
            params.vvd_params.worker_cores,
            params.vvd_params.gb_per_core,
            params.vvd_params.driver_cores,
            params.vvd_params.driver_memory,
            params.vvd_params.driver_stack_size,
            params.vvd_params.driver_logconfig
        )
        vvd_res.subscribe { log.debug "UNET VVD result: $it" }
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

    main:
    def re_arranged_input_data = input_data
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

    if (params.with_downsampling) {
        def n5_downsampled_res = downsample_n5(
            post_processing_results.map { it[6] }, // n5 dir
            post_processing_results.map { it[7] }, // n5 dataset
            params.downsample_params.app,
            params.downsample_params.spark_conf,
            post_processing_results.map {
                get_spark_working_dir(params.downsample_params.spark_work_dir, 'post_unet', it[7])
            },
            params.downsample_params.workers,
            params.downsample_params.worker_cores,
            params.downsample_params.gb_per_core,
            params.downsample_params.driver_cores,
            params.downsample_params.driver_memory,
            params.downsample_params.driver_stack_size,
            params.downsample_params.driver_logconfig
        )
        n5_downsampled_res.subscribe { log.debug "Post UNET downsample result: $it" }
    }
    if (params.with_vvd) {
        def vvd_res = n5_to_vvd(
            post_processing_results.map { it[6] }, // N5 container
            post_processing_results.map { it[7] }, // N5 dataset
            post_processing_results.map {
                get_vvd_output_dir(
                    params.vvd_output_dir ? params.vvd_output_dir : "${it[6]}/vvd",
                    it[7])
            }, // VVD output dir
            params.vvd_params.app,
            params.vvd_params.spark_conf,
            post_processing_results.map {
                get_spark_working_dir(params.vvd_params.spark_work_dir, 'vvd_unet', it[3])
            },
            params.vvd_params.workers,
            params.vvd_params.worker_cores,
            params.vvd_params.gb_per_core,
            params.vvd_params.driver_cores,
            params.vvd_params.driver_memory,
            params.vvd_params.driver_stack_size,
            params.vvd_params.driver_logconfig
        )
        vvd_res.subscribe { log.debug "Post UNET VVD result: $it" }
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

def get_spark_working_dir(base_dir, step, target_dataset) {
    def d = base_dir ? base_dir : '/tmp'
    def target_file = file(target_dataset)
    // dataset typically is <synapse-workflow-stage>/s0 and
    // I want to use the <synapse-workflow-stage> value
    "${d}/${step}/${target_file.parent.name}"
}

def get_vvd_output_dir(vvd_output_dir, target_dataset) {
    def target_file = file(target_dataset)
    // dataset typically is <synapse-workflow-stage>/s0 and
    // I want to use the <synapse-workflow-stage> value
    "${vvd_output_dir}/${target_file.parent.name}"

}