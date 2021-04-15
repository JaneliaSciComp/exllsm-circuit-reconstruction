function flag = closing_watershed(img_name)
    [data_path, name, ext] = fileparts(img_name);
    disp(['Loading for watershed segmentation', img_name]);
    img = read_tif(img_name);
    disp('Close and watershed transform...', img_name);
    img = close_and_watershed_transform(img);
    disp('Writing watershed segmentation result', img_name);
    write_tif(img, img_name);
    flag = 1;
end

function img = read_tif(img_file)
    % Read tif image
    im_info = imfinfo(img_file);
    rows = im_info(1).Height;
    cols = im_info(1).Width;
    slices = numel(im_info);
    img = zeros(rows, cols, slices, 'uint16');
    for slice = 1:slices
        img(:,:,slice)=imread(img_file, slice);
    end
end

function write_tif(data, name)
    % Write data into tif image
    slices = size(data, 3);
    for slice = 1:slices
        if slice == 1
            imwrite(data(:,:,slice), name);
        else
            imwrite(data(:,:,slice), name, 'WriteMode', 'append');
        end
    end
    imageDescription = sprintf('ImageJ=1.43d\nimages=%d\nslices=%d',slices,slices);
    t = Tiff(name,'r+');
    for slice = 1:slices
        setDirectory(t, slice);
        setTag(t, Tiff.TagID.ImageDescription, imageDescription);
        rewriteDirectory(t);
    end
    close(t);
end
