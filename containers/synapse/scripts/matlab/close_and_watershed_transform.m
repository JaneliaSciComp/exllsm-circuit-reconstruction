function img = close_and_watershed_transform(img)
    img = closing_img(img);
    img = water_shed(img);
    disp(['Completed watershed segmentation...', string(size(img))]);
end

function seg_img = closing_img(img)
    % Image closing
    img(img~=0) = 1;
    SE = strel('sphere',3);
    disp(['Morphological closing... ', string(size(img))])
    seg_img = imclose(img, SE);
    seg_img(seg_img~=0) = 255;
end

function seg_img = water_shed(bw)
    % Watershed segmentation
    bw(bw~=0) = 1;
    disp(['Find distance transform... ', string(size(bw))]);
    D = -bwdist(~bw);
    disp(['Find small spots in the image...', string(size(D))])
    mask = imextendedmin(D, 2);
    disp(['Modify distance transform ...', string(size(D)), ' to only have minima at mask ', string(size(mask))])
    D2 = imimposemin(D, mask);
    disp(['Apply watershed transform...', string(size(D2))])
    Ld = watershed(D2);
    seg_img = bw;
    seg_img(Ld==0) = 0;
    seg_img(seg_img~=0) = 255;
end
