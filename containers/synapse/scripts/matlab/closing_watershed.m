function flag = closing_watershed(img_name)
    [data_path, name, ext] = fileparts(img_name);
    disp(['Loading for watershed segmentation', img_name]);
    img = read_tif(img_name);
    disp(['Close and watershed transform...', img_name]);
    img = close_and_watershed_transform(img);
    disp(['Writing watershed segmentation result', img_name]);
    write_tif(img, img_name);
    flag = 1;
end
