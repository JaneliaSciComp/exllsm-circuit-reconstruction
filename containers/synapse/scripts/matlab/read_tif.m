function im_info = read_tif(img_file)
    % Read tif image
    im_info = imfinfo(img_file);
    rows = im_info(1).Height;
    cols = im_info(1).Width;
    slices = numel(im_info);
    disp(['Image info ', img_file, ' ', string(rows), ' ', string(cols), ' ', string(slices)])
    img = zeros(rows, cols, slices, 'uint16');
    for slice = 1:slices
        img(:,:,slice)=imread(img_file, slice);
    end
end
