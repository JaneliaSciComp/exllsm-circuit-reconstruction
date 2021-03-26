function flag = closing_watershed(img_name)
    [data_path, name, ext] = fileparts(img_name);
    img = read_tif(img_name);
    img = closing_img(img);
    img = water_shed(img);
    write_tif(img, img_name);
    flag = 1;
end

function img = read_tif(img_file)
    % Read tif image
    disp(['Loading ', img_file]);
    im_info = imfinfo(img_file);
    rows = im_info(1).Height;
    cols = im_info(1).Width;
    slices = numel(im_info);
    img = zeros(rows, cols, slices, 'uint16');
    for slice = 1:slices
        img(:,:,slice)=imread(img_file, slice);
    end
    disp(['Finished loading ', img_file]);
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

function seg_img = closing_img(img)
    % Image closing
    disp('Image closing...')
    img(img~=0)=1;
    SE=strel('sphere',3);
    seg_img=imclose(img,SE);
    % % image filling
    % seg_img=imfill(seg_img,'holes');
    seg_img(seg_img~=0) = 255;
end

function seg_img = water_shed(bw)
    % Watershed segmentation
    disp('Watershed segmentation...');
    bw(bw~=0) = 1;
    D = -bwdist(~bw);
    mask = imextendedmin(D,2);
    D2 = imimposemin(D,mask);
    Ld = watershed(D2);
    seg_img = bw;
    seg_img(Ld==0) = 0;
    seg_img(seg_img~=0) = 255;
end
