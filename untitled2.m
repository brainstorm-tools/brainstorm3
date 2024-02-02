TmpDir1 = 'E:\Brainstorm\Data\sub-F1961K3A\CT';
TmpDir2 = 'E:\Brainstorm\Data\sub-F1961K3A\sMRI';
ctImgFile = bst_fullfile(TmpDir1, 'sub-F1961K3A-F1961K3A_CT.nii.gz');
mrImgFile = bst_fullfile(TmpDir2, 'sub-F1961K3A-F1961K3A_MRI.nii.gz');
% disp(ctImgFile);

[sSubject, iSubject] = bst_get('Subject', 'Subject_F1961K3A');
MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
sMri = bst_memory('LoadMri', MriFile);
disp(sMri);

CTFile = 'Subject_F1961K3A/subjectimage_sub-F1961K3A-F1961K3A_CT_ct2mri_masked_reslice.mat';
sCT = bst_memory('LoadMri', CTFile);
disp(sCT);

[sSurf, iSurf] = bst_memory('LoadSurface', MriFile,  'Cortex');
% disp(sSurf.Comment);

[ct_img, ct_vox2ras, ct_tReorient] = in_mri(ctImgFile, 'ALL', 0, 0);
[mr_img, mr_vox2ras, mr_tReorient] = in_mri(mrImgFile, 'ALL', 0, 0);
% disp(ct_vox2ras);
% disp(ct_img);
% disp(ct_vox2ras);
% disp(ct_tReorient);
MaxElecs = 250;

[ct_img, ct_img_rng] = normalizeImage(ct_img.Cube);
% disp(ct_img);

ct_img_rng = double(ct_img_rng);
ct_img = double(ct_img);
% disp(ct_img_rng);

ElecRad = 2; %total radius of standard ad-tech grid electrode (4mm dia, 2.3mm exposed)
XYZScale = [0.4000 0.3991 0.3998]; %need to swap x/y if comparing with connected components
% MRInfo = app.MRInfo;

TMax = (ct_img_rng(4)-ct_img_rng(1))/(ct_img_rng(2)-ct_img_rng(1)); %max (CTRng(4)) normalized with respect to 1st (CTRng(1)) and 99th (CTRng(2)) percentiles
TMin = 1; %99th percentil
% disp(TMax);
% disp(TMin);
Thresh = linspace(TMax, TMin, 21); 
Thresh(1) = [];
% disp(Thresh);

ThreshHU = Thresh*(ct_img_rng(2)-ct_img_rng(1))+ct_img_rng(1); %thresholds in raw units
% disp(ThreshHU);

ElecVolVox = ceil(4/3*pi*mean(ElecRad./XYZScale).^3); %approximate volume of an electrode (standard ecog - typically largest intracranial electrode) in number of voxels
ElecVolRng = [6,ElecVolVox]; %6 voxels as minimum seems to work well for a wide range of electrode types

CCList = cell(length(Thresh),1);
WCList = cell(length(Thresh),1);

for k=1:length(Thresh)
    app.WaitH.Value = k/length(Thresh);
    
    ImgBin = ct_img>Thresh(k);
    % disp(ImgBin);

    CC = bwconncomp(ImgBin,6);
    CCSize = cellfun(@length,CC.PixelIdxList);
    % disp(CCSize);

    idx = CCSize<ElecVolRng(1)|CCSize>ElecVolRng(2);
    CC.PixelIdxList(idx) = [];
    CC.NumObjects = length(CC.PixelIdxList);
    % disp(CC.NumObjects);

    if CC.NumObjects>0
        s = regionprops3(CC,ct_img.*ImgBin,'weightedcentroid','meanintensity');
                
        WC = s.WeightedCentroid;
        % disp(WC);
        WC(:,[1,2]) = WC(:,[2,1]);
        % disp(WC);
        % disp(sMri.InitTransf{2});
        WCmm = [WC,ones(size(WC,1),1)]*sMri.InitTransf{2}'; 
        WCmm(:,4) = [];
        
        % idx = LeG_intriangulation(sSurf.Vertices,sSurf.Faces,WCmm);
        % 
        % s(~idx,:) = [];
        % WC(~idx,:) = [];
        % CC.PixelIdxList(~idx) = [];
        CC.NumObjects = length(CC.PixelIdxList);
        
        [~,sidx] = sort([s.MeanIntensity],'descend');
        
        WC = round(WC(sidx,:));
        WCList(k) = {WC};
        CCList(k) = {CC};
    end
end

NumObj = cellfun(@(x)size(x,1),WCList);

cc = bwconncomp(abs(diff(NumObj))<=5 & NumObj(1:end-1)>10);%change in number of detected electrodes (as threshold decreases) should be less than 5 and total number greater than 10
skipflag = true;
if cc.NumObjects>0
    ccsize = cellfun(@length,cc.PixelIdxList);
    cc.PixelIdxList(ccsize<2) = []; %need at least 3 (2 diffs) stable thresholds where number of detected electrodes does not change by more than 5
    cc.NumObjects = length(cc.PixelIdxList);
    if cc.NumObjects>0
        ccval = cellfun(@(x)mean(NumObj(x)),cc.PixelIdxList);
        [~,midx] = max(ccval); %find the threshold segment with the largest number of electrodes
        idx = cc.PixelIdxList{midx};
%         [~,midx] = max(NumObj(idx)); %find the theshold with the largest number of electrodes within the chosen segment
%         idx = idx(midx);
        idx = idx(round(end/2)); %choose the middle index of cluster
        skipflag = false;
    end
end
if skipflag %if no stable clusters are found, do this
    idx = find(NumObj>10 & NumObj<MaxElecs);
    if ~isempty(idx)
        idx = idx(round(end/2));
    else
        idx = round(length(Thresh)/2);
    end
end

WC = WCList{idx};
THU = ThreshHU(idx);
T = Thresh(idx);
% disp(T);
% disp(WC);

%outlier removal
pd = pdist2(WC,WC,'euclidean','smallest',2); %find closest electrode to each detected electrode
WC(pd(end,:)*mean(XYZScale)<1,:) = []; %remove detections that are closer than 1mm
WC(MaxElecs+1:end,:) = []; %remove if more than 250 detections
% disp(T);
% disp(WC);
hFig = view_mri(CTFile);
Handles = bst_figures('GetFigureHandles', hFig);

for i=1:length(WC)
    figure_mri('SetLocation', 'mri', hFig, [], WC(i,:));
    Handles.LocEEG(i,:) = WC(i,:);
    Handles.hPointEEG(i,:) = figure_mri('PlotPoint', sCT, Handles, Handles.LocEEG(i,:), [1 1 0], 5, '');
    % Handles.hTextEEG(1,:)  = figure_mri('PlotText', sMri, Handles, Handles.LocEEG(1,:), [1 1 0], '', '');
end
figure_mri('UpdateVisibleLandmarks', sCT, Handles);

function [img, rng] = normalizeImage(img, varargin)
    mode = 'prctile';
    if nargin>2
        mode = varargin{1};
    end
    switch mode
        case 'minmax'
            rng = [min(img(:)),max(img(:))];
            img = (img-rng(1))/(rng(2)-rng(1));
        otherwise
            rng = prctile(img(:),[1,99,0,100]);
            img = (img-rng(1))/(rng(2)-rng(1));
    end
end