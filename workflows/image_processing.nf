include {
    convert_to_or_from_mask;
    connect_tiff_mask;
} from '../processes/image_processing'

workflow connect_mask {
    take:
    input_mask_dir
    shared_temp_dir
    output_dir

    main:
    dirs_tuple = prepare_mask_dirs(input_mask, shared_temp_dir, output_dir)
    
    connected_tiff = dirs_tuple 
                    | threshold_tiff
                    | convert_to_or_from_mask
                    | connect_tiff_mask
                    | convert_to_or_from_mask
    
    emit:
    connected_tiff
}
