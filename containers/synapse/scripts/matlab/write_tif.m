function write_tif(data, name)
    % Write data into tif image
    slices = size(data, 3);
    disp(['Write image info ', name, ' (', string(slices), ' slices) ', string(size(data))])
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
