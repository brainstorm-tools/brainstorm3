function varargout = channel_detect_eegcap_auto(varargin)
% CHANNEL_DETECT_EEGCAP_AUTO: Automatic electrode detection and labelling of 3D Scanner acquired mesh
% 
% USAGE: [capCenters2d, capImg2d, surface3dscannerUv] = channel_detect_eegcap_auto('FindElectrodesEegCap', surface3dscanner, isWhiteCap)
%        channel_detect_eegcap_auto('WarpLayout2Mesh', capCenters2d, capImg2d, surface3dscannerUv, channelRef, eegPoints)
%        eegCapLandmarkLabels = channel_detect_eegcap_auto('GetEegCapLandmarkLabels', channelRef)
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
% Authors: Anand A. Joshi,   2024
%          Chinmay Chinara,  2024
%          Raymundo Cassani, 2024

eval(macro_method);
end

%% ===== FIND ELECTRODES ON THE EEG CAP UV =====
function [sSurfCap, capImg2d, capCenters2d, capRadii2d] = FindElectrodesEegCap(sSurfCap)
    capCenters2d = [];
    capImg2d     = [];
    capRadii2d   = [];
    sSurfCap.u   = [];
    sSurfCap.v   = [];
    if isempty(sSurfCap.Color)
        return
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % TODO: Find cap color from texture not form montage name
    % Get current montage
    DigitizeOptions = bst_get('DigitizeOptions');
    panel_fun = @panel_digitize;
    if isfield(DigitizeOptions, 'Version') && strcmpi(DigitizeOptions.Version, '2024')
        panel_fun = @panel_digitize_2024;
    end
    curMontage = panel_fun('GetCurrentMontage');
    isWhiteCap = 0;
    % For white caps change the color space by inverting the colors
    % NOTE: only 'Acticap' is the tested white cap (needs work on finding a better aprrooach)
    if ~isempty(regexp(curMontage.Name, 'ActiCap', 'match'))
        isWhiteCap = 1;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Image size [px]
    capImg2dSize = 900;
    capRangeinIm = 1.5;
    % Hyperparameters for circle detection [px]
    % NOTE: these values can vary for new caps
    minRadius = 1;
    maxRadius = 25;
    
    % Flatten the 3D mesh to 2D space
    [sSurfCap.u, sSurfCap.v] = bst_project_2d(sSurfCap.Vertices(:,1), sSurfCap.Vertices(:,2), sSurfCap.Vertices(:,3), '2dcap');
    
    % Perform image processing to detect the electrode locations
    % Convert to grayscale
    grayness = sSurfCap.Color*[1;1;1]/sqrt(3);
    
    % Interpolate and fit flattended mesh image from [-capRangeinIm to capRangeinIm] in a 512x512 grid
    % NOTE: Should work with any flattened cap mesh but needs more testing
    ll=linspace(-capRangeinIm, capRangeinIm, capImg2dSize);
    [X,Y]=meshgrid(ll,ll);
    capImg2d = 0*X;
    warning('off','MATLAB:scatteredInterpolant:DupPtsAvValuesWarnId');
    capImg2d(:) = griddata(sSurfCap.u(1:end),sSurfCap.v(1:end),grayness,X(:),Y(:),'linear');
    warning('on','MATLAB:scatteredInterpolant:DupPtsAvValuesWarnId');

    % For white caps
    if isWhiteCap
        capImg2d = imcomplement(capImg2d);
    end
    
    % Detect the centers of the electrodes which appear as circles in the flattened image whose radii are in the range below
    warning('off','images:imfindcircles:warnForSmallRadius');
    warning('off','images:imfindcircles:warnForLargeRadiusRange');
    [capCenters2d, capRadii2d] = imfindcircles(capImg2d, [minRadius maxRadius]);
    warning('on','images:imfindcircles:warnForSmallRadius');
    warning('on','images:imfindcircles:warnForLargeRadiusRange');
end


%% ===== WARP REFERENCE CAP ELECTRODE LOCATIONS USING DIGITIZED POINTS =====
function capPoints = WarpLayout2Digitized(capChannelFile, eegPoints, sSurf, capImg2d, capCenters2d, capRadii2d)

    capPoints = struct();

    % Format input data, depending on the caller
    DigitizeOptions = bst_get('DigitizeOptions');
    if isfield(DigitizeOptions, 'Version') && strcmpi(DigitizeOptions.Version, '2024')
        panel_fun = @panel_digitize_2024;
        eegPointsLabels = {eegPoints.Label};
        eegPointsLoc = cat(1, eegPoints.Loc);
    else
        panel_fun = @panel_digitize;
        eegPointsLabels = eegPoints.Label;
        eegPointsLoc = cat(1, eegPoints.EEG);
    end

    % Get EEG cap landmark labels used for initialization
    [capLandmarkLabels, capValidEegChan] = GetEegCapInfo(capChannelFile);
    % Check that all landmarks are acquired
    if ~all(ismember(capLandmarkLabels, eegPointsLabels))
        bst_error('Not all EEG landmarks are provided', 'Auto electrode location', 1);
        return
    end
    % Indices for points to compute warp
    capLayoutNames = {capValidEegChan.Name};
    [~, iwarp] = ismember(eegPointsLabels, capLayoutNames);

    % Perform warpping in the UV space
    isUVspace = all(~cellfun(@isempty, {capImg2d, capCenters2d, capRadii2d, sSurf.u, sSurf.v}));

    bst_progress('start', '3Dscanner', 'Automatic labelling of EEG sensors...', 0, 100);

    % Delete the manual electrodes selected in figure to update it with the automatic detected ones
    for i=1 : length(eegPoints)
        panel_fun('DeletePoint_Callback');
    end

    % === 1. Intial rigid transformation using landmarks. EEG cap layout --> EEG digitized cap
    capPoints3d = [capValidEegChan.Loc]';
    % Find best possible rigid transformation (rotation+translation)
    [R,T] = rot3dfit(capPoints3d(iwarp, :), eegPointsLoc);
    % Use transformation on the entire cap
    capPoints3d = capPoints3d*R + ones(size(capPoints3d,1),1)*T;
    % Project them to the 3Dscan mesh
    warning('off','MATLAB:scatteredInterpolant:DupPtsAvValuesWarnId');
    capPoints3d = channel_project_scalp(sSurf.Vertices, capPoints3d);
    warning('on','MATLAB:scatteredInterpolant:DupPtsAvValuesWarnId');

    % === 2. Refine positions for EEG digitized cap using UV mapping from 3Dscan
    if isUVspace
        % Dimension of the flattened cap from mesh
        capImgDim = length(capImg2d);
        capRangeinIm = 1.5;
        % Threshold for ignoring some border pixels that might be bad detections
        ignorePix = 15;

        % Convert cap 3D locations to 2D (UV space)
        [X1, Y1] = bst_project_2d(capPoints3d(:,1), capPoints3d(:,2), capPoints3d(:,3), '2dcap');
        capLayoutPts2d = ([X1 Y1] * capImgDim/2/capRangeinIm) + capImgDim/2;

        % 'ignorePix' is just a hyperparameter. It is because if some point is detected near the border then it is
        % too close to the border; it moves it inside. It leaves a margin of 'ignorePix' pixels around the border
        capLayoutPts2d = max(min(capLayoutPts2d,capImgDim-ignorePix),ignorePix);

        % Show image
        hImFig = figure();
        ax = gca();
        imshow(capImg2d');
        hold on
        viscircles(ax, fliplr(capCenters2d), capRadii2d, 'Color','r');
        scatter(ax, capLayoutPts2d(:,2), capLayoutPts2d(:,1), '+b')
        axis(ax, 'xy')
        set(ax, 'XDir', 'reverse')

        % Ask if continue with refinement
        isRefinement = java_dialog('confirm', ['This is the image' 10 10 ...
                                    'Do you want to continue?'], 'Auto detect EEG electrodes');
        if isRefinement
            close(hImFig);

            % Hyperparameters for warping and interpolation
            % NOTE: these values can vary for new caps
            % Number of iterations to run warp-interpolation on
            numIters  = 1000;
            % Defines the rigidity of the warping (check the 'tpsGetWarp' function for more details)
            lambda    = 100000;

            % Warp and interpolate to get the best point fitting
            for numIter=1:numIters
                % Show progress
                progressPrc = round(100 .* numIter ./ numIters);
                if progressPrc > 0 && ~mod(progressPrc, 5)
                    bst_progress('set', progressPrc);
                end
                % Nearest point search between the layout and detected circle centers from the 2D flattened mesh
                % 'k' is an index into points from the available layout
                k = dsearchn(capLayoutPts2d, capCenters2d);
                [vecLayoutPts,ind] = unique(k);

                % distance between the layout and detected circle centers from the 2D flattened mesh
                vecLayout2Mesh = capCenters2d(ind,:)-capLayoutPts2d(vecLayoutPts,:);
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
                warp = tpsGetWarp(lambda, capLayoutPts2d(vecLayoutPts,1)', capLayoutPts2d(vecLayoutPts,2)', capCenters2d(ind,1)', capCenters2d(ind,2)' );
                [xsR,ysR] = tpsInterpolate(warp, capLayoutPts2d(:,1)', capLayoutPts2d(:,2)', 0);

                % Perform gradual warping for half the iterations and fast warping for the rest of the iterations
                if numIter<numIters/2
                    capLayoutPts2d(:,1) = 0.9*capLayoutPts2d(:,1) + 0.1*xsR;
                    capLayoutPts2d(:,2) = 0.9*capLayoutPts2d(:,2) + 0.1*ysR;
                else
                    capLayoutPts2d(:,1) = xsR;
                    capLayoutPts2d(:,2) = ysR;
                end

                % 'ignorePix' is just a hyperparameter. It is because if some point is detected near the border then it is
                % too close to the border; it moves it inside. It leaves a margin of 'ignorePix' pixels around the border
                capLayoutPts2d = max(min(capLayoutPts2d,capImgDim-ignorePix),ignorePix);
            end

            % Interpolation of the fitted points to the image space of the layout
            ll=linspace(-capRangeinIm, capRangeinIm, capImgDim);
            [X1,Y1]=meshgrid(ll,ll);
            capLayoutPts2dU = interp2(X1,xsR,ysR);
            capLayoutPts2dV = interp2(Y1,xsR,ysR);

            % Get the desired electrode locations on the 3D EEG cap
            warning('off','MATLAB:scatteredInterpolant:DupPtsAvValuesWarnId');
            capPoints3d(:,1) = griddata(sSurf.u, sSurf.v, sSurf.Vertices(:,1), capLayoutPts2dU, capLayoutPts2dV);
            capPoints3d(:,2) = griddata(sSurf.u, sSurf.v, sSurf.Vertices(:,2), capLayoutPts2dU, capLayoutPts2dV);
            capPoints3d(:,3) = griddata(sSurf.u, sSurf.v, sSurf.Vertices(:,3), capLayoutPts2dU, capLayoutPts2dV);
            warning('on','MATLAB:scatteredInterpolant:DupPtsAvValuesWarnId');
        end
    end

    % Build output
    for iPoint = 1 : length(capLayoutNames)
        % Check if using new version
        if isfield(DigitizeOptions, 'Version') && strcmpi(DigitizeOptions.Version, '2024')
            capPoints(iPoint).Label  = capLayoutNames(iPoint);
            capPoints(iPoint).Loc    = capPoints3d(iPoint, :);
        else
            capPoints.Label{iPoint}  = capLayoutNames(iPoint);
            capPoints.EEG(iPoint, :) = capPoints3d(iPoint, :);
        end
    end
end


%% ===== GET REFERENCE EEG CAP INFO =====
function [capLandmarkLabels, capValidEegChan] = GetEegCapInfo(ChannelFile)
    capLandmarkLabels = {};
    capValidEegChan   = [];
    if ~file_exist(ChannelFile)
        return
    end
    % Load channel file (EEG cap)
    ChannelMat = in_bst_channel(ChannelFile);
    % Get valid sensors: EEG or EEG REF and with Loc info
    iValidType = channel_find(ChannelMat.Channel, {'EEG', 'EEG REF'});
    iHasLoc = find(~cellfun(@isempty, {ChannelMat.Channel(:).Loc}));
    iValid  = intersect(iValidType, iHasLoc);
    % Not valid if Loc has NaN or is [0 0 0]
    iNotValid = find(any(isnan([ChannelMat.Channel(iValid).Loc])) | all([ChannelMat.Channel(iValid).Loc] == 0));
    iValid(iNotValid) = [];
    capValidEegChan = ChannelMat.Channel(iValid);
    % Find bounding positions
    ChanLoc = [ChannelMat.Channel(iValid).Loc]';
    [~, iMaxLoc] = max(ChanLoc);
    [~, iMinLoc] = min(ChanLoc);
    % Find most anterior electrode  ~ FPz
    frontElec = ChannelMat.Channel(iValid(iMaxLoc(1))).Name;
    % Find most left electrode      ~ T7
    leftElec  = ChannelMat.Channel(iValid(iMaxLoc(2))).Name;
    % Find most right Electrode     ~ T8
    rightElec = ChannelMat.Channel(iValid(iMinLoc(2))).Name;
    % Find most posterior electrode ~ Oz
    postElec  = ChannelMat.Channel(iValid(iMinLoc(1))).Name;
    % Find most superior electrode  ~ Cz
    topElec   = ChannelMat.Channel(iValid(iMaxLoc(3))).Name;
    % Final list of landmarks
    capLandmarkLabels = unique({frontElec, leftElec, rightElec, postElec, topElec}, 'stable');
end
