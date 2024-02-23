function L = gardel_reproduce(varargin)

    % get the MRI file
    [sSubject, iSubject] = bst_get('Subject', 'Subject_F1988I21');
    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    sMri = bst_memory('LoadMri', MriFile);
    % disp(sMri);
    
    % get the CT file
    CTFile = 'Subject_F1988I21/subjectimage_sub-F1988I21-F1988I21_CT_ct2mri_masked_reslice.mat';
    sCt = bst_memory('LoadMri', CTFile);
    % disp(sCt.Histogram);
    
    % threshold the CT
    thresh = (sCt.Histogram.whiteLevel + sCt.Histogram.intensityMax) / 2;
    
    ctmask = (sCt.Cube(:,:,:,1) > thresh);
    % Closing all the faces of the cube
    ctmask(1,:,:)   = 0*ctmask(1,:,:);
    ctmask(end,:,:) = 0*ctmask(1,:,:);
    ctmask(:,1,:)   = 0*ctmask(:,1,:);
    ctmask(:,end,:) = 0*ctmask(:,1,:);
    ctmask(:,:,1)   = 0*ctmask(:,:,1);
    ctmask(:,:,end) = 0*ctmask(:,:,1);
    % view_mri_slices(ctmask, 'y', 4);
    
    % perform dilate
    ctmaskDilate = mri_dilate(ctmask, 6);
    % view_mri_slices(ctmaskDilate, 'y', 4);
    
    % perform bwconncomp
    cc = bwconncomp(ctmaskDilate);
    disp(cc);
    
    for i=1:cc.NumObjects
        ctmask(cc.PixelIdxList{i}) = 1;
    end
    % view_mri_slices(ctmask, 'y', 4);
    
    % watershed
    D = bwdist(~ctmask);
    D = -D;
    L = watershed(D);
    L(~ctmask) = 0;
    
    L = L & ~mri_dilate(~L, 3);

    % view_mri_slices(L, 'y', 4);
end


