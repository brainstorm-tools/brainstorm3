function varargout = auto_3dscanner(varargin)
% AUTO_3DSCANNER: Automatic electrode detection and labelling of 3D Scanner acquired mesh
% 
% USAGE: [capCenters2d, capImg2d, surface3dscannerUv] = auto_3dscanner('FindElectrodesEegCap', surface3dscanner, isWhiteCap)
%        auto_3dscanner('WarpLayout2Mesh', capCenters2d, capImg2d, surface3dscannerUv, channelRef, eegPoints)
%        [nLandmarkLabels, eegCapLandmarkLabels] = auto_3dscanner('GetEegCapLandmarkLabels', eegCapName)
%
% PARAMETERS:
%    - surface3dscanner     : The 3D mesh surface obtained from the 3d Scanner loaded into brainstorm 
%    - isWhiteCap           : Set if the 3D mesh surface correspongs to a white EEG cap
%    - surface3dscannerUv   : 'surface3dscanner' above along with the UV texture information of the surface
%    - capImg2d             : Flattend 2D grayscale image of the mesh
%    - capCenters2d         : The ceters of the various electrodes detected in the flattened 2D image of the mesh
%    - channelRef           : The channel file containing all the layout information of the cap
%    - eegCapName           : Name of the EEG cap
%    - eegCapLandmarkLabels : The manually chosen list of labels of the electrodes to be used as initilization for automation
%    - nLandmarkLabels      : The count for the number of chosen electrode labels above
%
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Anand A. Joshi, Chinmay Chinara, 2024

eval(macro_method);
end

%% ===== FIND ELECTRODES ON THE EEG CAP =====
function [capCenters2d, capImg2d, surface3dscannerUv] = FindElectrodesEegCap(surface3dscanner, isWhiteCap)
    % Hyperparameters for circle detection
    % NOTE: these values can vary for new caps
    minRadius = 1;
    maxRadius = 25;
    
    % create a copy of the input mesh to add UV texture information to it as well
    surface3dscannerUv = surface3dscanner;

    % Flatten the 3D mesh to 2D space
    [surface3dscannerUv.u, surface3dscannerUv.v] = bst_project_2d(surface3dscanner.Vertices(:,1), surface3dscanner.Vertices(:,2), surface3dscanner.Vertices(:,3), '2dcap');
    
    % Perform image processing to detect the electrode locations
    % Convert to grayscale
    grayness = surface3dscanner.Color*[1;1;1]/sqrt(3);
    
    % Interpolate and fit flattended mesh image to a 512x512 grid 
    % NOTE: Should work with any flattened cap mesh but needs more testing
    ll=linspace(-1,1,512);
    [X,Y]=meshgrid(ll,ll);
    capImg2d = 0*X;
    capImg2d(:) = griddata(surface3dscannerUv.u(1:end),surface3dscannerUv.v(1:end),grayness,X(:),Y(:),'linear');

    % For white caps
    if isWhiteCap
        capImg2d = imcomplement(capImg2d);
    end
    
    % Detect the centers of the electrodes which appear as circles in the flattened image whose radii are in the range below
    capCenters2d = imfindcircles(capImg2d, [minRadius maxRadius]);
end

%% ===== WARP ELECTRODE LOCATIONS FROM EEG CAP MANUFACTURER LAYOUT AVAILABLE IN BRAINSTORM TO THE MESH =====
function capPoints3d = WarpLayout2Mesh(capCenters2d, capImg2d, surface3dscannerUv, channelRef, eegPoints)
    % Hyperparameters for warping and interpolation
    % NOTE: these values can vary for new caps
    % Number of iterations to run warp-interpolation on 
    numIters  = 1000;
    % Defines the rigidity of the warping (check the 'tpsGetWarp' function for more details)
    lambda    = 100000;
    % Dimension of the flattened cap from mesh
    capImgDim = length(capImg2d);
    % Threshold for ignoring some border pixels that might be bad detections
    ignorePix = 15;
    
    % Get current montage
    DigitizeOptions = bst_get('DigitizeOptions');
    panel_fun = @panel_digitize;
    if isfield(DigitizeOptions, 'Version') && strcmpi(DigitizeOptions.Version, '2024')
        panel_fun = @panel_digitize_2024;
    end
    curMontage = panel_fun('GetCurrentMontage');

    % Convert EEG cap manufacturer layout from 3D to 2D
    capLayoutPts3d = [channelRef.Loc]';
    [X1, Y1] = bst_project_2d(capLayoutPts3d(:,1), capLayoutPts3d(:,2), capLayoutPts3d(:,3), '2dcap');
    capLayoutPts2d = [X1 Y1];
    
    % Get EEG cap landmark labels used for initialization
    [nLandmarkLabels, capLandmarkLabels] = GetEegCapLandmarkLabels(curMontage.Name);
    
    % Sort as per the initialization landmark points of EEG Cap  
    landmarkPoints = capLayoutPts2d(find(ismember({channelRef.Name},capLandmarkLabels)),:);
    nonLandmarkPoints = capLayoutPts2d(find(~ismember({channelRef.Name},capLandmarkLabels)),:);
    capLayoutPts2dSorted = cat(1, landmarkPoints, nonLandmarkPoints);
    
    %% Warping EEG cap layout electrodes to mesh 
    % Get 2D projected landmark points to be used for initialization
    capLayoutPts2dInit = capLayoutPts2dSorted(1:nLandmarkLabels, :);
    % Get 2D projected points of the 3D points selected by the user on the mesh 
    [x2, y2] = bst_project_2d(eegPoints(1:nLandmarkLabels,1), eegPoints(1:nLandmarkLabels,2), eegPoints(1:nLandmarkLabels,3), '2dcap');
    % Reprojection into the space of the flattened mesh dimensions
    capUserSelectPts2d = ([x2 y2]+1) * capImgDim/2;
    
    % Delete the manual electrodes selected in figure to update it with the automatic detected ones
    for i=1 : length(eegPoints)
        panel_fun('DeletePoint_Callback');
    end

    % Do the warping and interpolation
    warp = tpsGetWarp(10, capLayoutPts2dInit(:,1)', capLayoutPts2dInit(:,2)', capUserSelectPts2d(:,1)', capUserSelectPts2d(:,2)' );
    [xsR,ysR] = tpsInterpolate(warp, capLayoutPts2dSorted(:,1)', capLayoutPts2dSorted(:,2)', 0);
    capLayoutPts2dSorted(:,1) = xsR;
    capLayoutPts2dSorted(:,2) = ysR;
    % 'ignorePix' is just a hyperparameter. It is because if some point is detected near the border then it is 
    % too close to the border; it moves it inside. It leaves a margin of 'ignorePix' pixels around the border
    capLayoutPts2dSorted = max(min(capLayoutPts2dSorted,capImgDim-ignorePix),ignorePix);
    
    % Warp and interpolate to get the best point fitting 
    for numIter=1:numIters
        fprintf('.');
        % Nearest point search between the layout and detected circle centers from the 2D flattened mesh
        % 'k' is an index into points from the available layout
        k = dsearchn(capLayoutPts2dSorted, capCenters2d);
        [vecLayoutPts,ind] = unique(k);
            
        % distance between the layout and detected circle centers from the 2D flattened mesh 
        vecLayout2Mesh = capCenters2d(ind,:)-capLayoutPts2dSorted(vecLayoutPts,:);
        dist = sqrt(vecLayout2Mesh(:,1).^2+vecLayout2Mesh(:,2).^2);
        
        % Identify outliers with 3*scaled_MAD from median and remove them
        % Use 'rmoutliers' for Matlab >= R2018b
        if bst_get('MatlabVersion') >= 905
            [~, isoutlier] = rmoutliers(dist);
        % Implementation
        else
            mad = median(abs(dist-median(dist)));
            c = -1/(sqrt(2) * erfcinv(3/2)) * 2;
            scaled_mad = c * mad;
            isoutlier  = find(abs(dist-median(dist)) > 3*scaled_mad);
        end
        ind(isoutlier) = [];
        vecLayoutPts(isoutlier) = [];
        
        % Perform warping and interpolation to fit the points
        warp = tpsGetWarp(lambda, capLayoutPts2dSorted(vecLayoutPts,1)', capLayoutPts2dSorted(vecLayoutPts,2)', capCenters2d(ind,1)', capCenters2d(ind,2)' );
        [xsR,ysR] = tpsInterpolate(warp, capLayoutPts2dSorted(:,1)', capLayoutPts2dSorted(:,2)', 0);
        
        % Perform gradual warping for half the iterations and fast warping for the rest of the iterations
        if numIter<numIters/2
            capLayoutPts2dSorted(:,1) = 0.9*capLayoutPts2dSorted(:,1) + 0.1*xsR;
            capLayoutPts2dSorted(:,2) = 0.9*capLayoutPts2dSorted(:,2) + 0.1*ysR;
        else
            capLayoutPts2dSorted(:,1) = xsR;
            capLayoutPts2dSorted(:,2) = ysR;
        end
        
        % 'ignorePix' is just a hyperparameter. It is because if some point is detected near the border then it is 
        % too close to the border; it moves it inside. It leaves a margin of 'ignorePix' pixels around the border
        capLayoutPts2dSorted = max(min(capLayoutPts2dSorted,capImgDim-ignorePix),ignorePix);
    end
    
    % Interpolation of the fitted points to the image space of the layout   
    ll=linspace(-1,1,capImgDim);
    [X1,Y1]=meshgrid(ll,ll);    
    capLayoutPts2dU = interp2(X1,xsR,ysR);
    capLayoutPts2dV = interp2(Y1,xsR,ysR);
    
    % Get the desired electrode locations on the 3D EEG cap 
    capPoints3d(:,1) = griddata(surface3dscannerUv.u, surface3dscannerUv.v, surface3dscannerUv.Vertices(:,1), capLayoutPts2dU, capLayoutPts2dV);
    capPoints3d(:,2) = griddata(surface3dscannerUv.u, surface3dscannerUv.v, surface3dscannerUv.Vertices(:,2), capLayoutPts2dU, capLayoutPts2dV);
    capPoints3d(:,3) = griddata(surface3dscannerUv.u, surface3dscannerUv.v, surface3dscannerUv.Vertices(:,3), capLayoutPts2dU, capLayoutPts2dV);
end

%% ===== GET LANDMARK LABELS OF EEG CAP =====
% For every new variety of cap we need to edit this function
function [nLandmarkLabels, eegCapLandmarkLabels] = GetEegCapLandmarkLabels(eegCapName)
    eegCapLandmarkLabels = {};
    switch(eegCapName)
        case 'ANT Waveguard (65)'
            eegCapLandmarkLabels = {'Fpz', 'T7', 'T8', 'Oz'};
        case 'BrainProducts ActiCap (68)'
            eegCapLandmarkLabels = {'T7', 'T8', 'Oz', 'GND'};
        case 'WearableSensing DSI-24 with REF (22)'
            eegCapLandmarkLabels = {'T4', 'T3', 'Fpz'};
        otherwise
            nLandmarkLabels = 0;
            return;
    end
    nLandmarkLabels = length(eegCapLandmarkLabels);
end