function seg_img = close_and_watershed_transform(img)
    disp('Morphological closing...')
    closed_img = closing_img(img);
    disp('Starrt watershed segmentation...');
    seg_img = water_shed(closed_img);
    disp('Completed watershed segmentation...');
end

function seg_img = closing_img(img)
    % Image closing
    img(img~=0) = 1;
    SE = strel('sphere',3);
    seg_img = imclose(img,SE);
    seg_img(seg_img~=0) = 255;
end

function seg_img = water_shed(bw)
    % Watershed segmentation
    bw(bw~=0) = 1;
    D = -bwdist(~bw);
    mask = imextendedmin(D,2);
    D2 = imimposemin(D,mask);
    Ld = watershed(D2);
    seg_img = bw;
    seg_img(Ld==0) = 0;
    seg_img(seg_img~=0) = 255;
end
