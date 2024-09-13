function varargout = auto_3dscanner(varargin)
% AUTO_3DSCANNER: Automatic detection and labelling of 3D Scanner acquired mesh
% 
% USAGE: auto_3dscanner('findElectrodesEegCap', head_surface)
%        auto_3dscanner('warpLayout2Mesh', centerscap, ChannelRef, cap_img, head_surface, EegPoints)
%        [nLandmarkLabels, eegCapLandmarkLabels] = auto_3dscanner('getEegCapLandmarkLabels', capName)
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
function [centers_cap, cap_img, head_surface] = findElectrodesEegCap(head_surface)
    global Digitize

    % Flatten the 3D mesh to 2D space
    [head_surface.u, head_surface.v] = bst_project_2d(head_surface.Vertices(:,1), head_surface.Vertices(:,2), head_surface.Vertices(:,3), '2dcap');
    
    % perform image processing to detect the electrode locations
    grayness = head_surface.Color*[1;1;1]/sqrt(3);
    
    % fit image to a 512x512 grid 
    % #######################################################################
    % ### NOTE: Should work with any iamge fitting but needs more testing ###
    % #######################################################################
    ll=linspace(-1,1,512);
    [X,Y]=meshgrid(ll,ll);
    vc_sq = 0*X;
    vc_sq(:) = griddata(head_surface.u(1:end),head_surface.v(1:end),grayness,X(:),Y(:),'linear');

    [curMontage, nEEG] = GetCurrentMontage();
    if ~isempty(regexp(curMontage.Name, 'ActiCap', 'match'))
        vc_sq = imcomplement(vc_sq);
    end

    % toggle comment depending on cap
    if ~isempty(regexp(curMontage.Name, 'ActiCap', 'match'))
        [centers, radii, metric] = imfindcircles(vc_sq,[6 55]); % 66 easycap
    elseif ~isempty(regexp(curMontage.Name, 'Waveguard', 'match'))
        [centers, radii, metric] = imfindcircles(vc_sq,[1 25]); % 65 ANT waveguard
    else % NEED TO WORK ON THIS
        bst_error('EEG cap not supported', Digitize.Type, 0);
        return;
    end

    centers_cap = centers; 
    cap_img = vc_sq;
end

%% ===== WARP ELECTRODE LOCATIONS FROM EEG CAP MANUFACTURER LAYOUT AVAILABLE IN BRAINSTORM TO THE MESH =====
function capPoints3d = warpLayout2Mesh(centerscap, ChannelRef, cap_img, head_surface, EegPoints) 
    global Digitize

    % Hyperparameters for warping and interpolation
    numIters   = 1000;
    lambda    = 100000;
    % dimension of the flattened cap from mesh
    capImgDim = length(cap_img);
    % ignore pixels threshold
    ignorePix = 15;
    
    
    % Get current montage
    [curMontage, nEEG] = GetCurrentMontage();

    % Convert EEG cap manufacturer layout from 3D to 2D
    tmp = [ChannelRef.Loc]';
    [X1, Y1] = bst_project_2d(tmp(:,1), tmp(:,2), tmp(:,3), '2dcap');
    centerssketch_temp = [X1 Y1];
    
    % Get cap landmark labels
    [nLandmarkLabels, capLandmarkLabels] = getEegCapLandmarkLabels(curMontage.Name);
    
    % Sort as per the initialization landmark points of EEG Cap  
    landmarkPoints = centerssketch_temp(find(ismember({ChannelRef.Name},capLandmarkLabels)),:);
    nonLandmarkPoints = centerssketch_temp(find(~ismember({ChannelRef.Name},capLandmarkLabels)),:);
    centerssketch = cat(1, landmarkPoints, nonLandmarkPoints);
    
    %% Warping EEG cap layout electrodes to mesh 
    % Get 2D projected points of the available 3D layout points in Brainstorm
    sketch_pts = centerssketch(1:nLandmarkLabels, :);
    % Get 2D projected points of the 3D points selected by the user on the mesh 
    [x2, y2] = bst_project_2d(EegPoints(1:nLandmarkLabels,1), EegPoints(1:nLandmarkLabels,2), EegPoints(1:nLandmarkLabels,3), '2dcap');
    % Reprojection into the space of the flattened mesh dimensions
    cap_pts = ([x2 y2]+1) * capImgDim/2;
    for i=1:4
        DeletePoint_Callback();
    end

    % Do the warping and interpolation
    warp = tpsGetWarp(10, sketch_pts(:,1)', sketch_pts(:,2)', cap_pts(:,1)', cap_pts(:,2)' );
    [xsR,ysR] = tpsInterpolate(warp, centerssketch(:,1)', centerssketch(:,2)', 0);
    centerssketch(:,1) = xsR;
    centerssketch(:,2) = ysR;
    % 15 is just a hyperparameter. It is because if some point is detected near the border then it is too close to the border, 
    % it moves it inside. It leaves a margin of 15 pixels around the border
    centerssketch = max(min(centerssketch,capImgDim-ignorePix),ignorePix);
    
    for kk=1:numIters
        fprintf('.');
        %tic
        k=dsearchn(centerssketch,centerscap);
    
        %k is an index into sketch pts
        [vec_atlas_pts,ind]=unique(k);
    
        vec_atlas2sub=centerscap(ind,:)-centerssketch(vec_atlas_pts,:);
        dist = sqrt(vec_atlas2sub(:,1).^2+vec_atlas2sub(:,2).^2);
        
        % Identify outliers with 3*scaled_MAD from median
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
        vec_atlas_pts(isoutlier) = [];
    
        warp = tpsGetWarp(lambda, centerssketch(vec_atlas_pts,1)', centerssketch(vec_atlas_pts,2)', centerscap(ind,1)', centerscap(ind,2)' );
    
        [xsR,ysR] = tpsInterpolate( warp, centerssketch(:,1)', centerssketch(:,2)', 0);
    
        if kk<numIters/2
            centerssketch(:,1) = 0.9*centerssketch(:,1) + 0.1*xsR;
            centerssketch(:,2) = 0.9*centerssketch(:,2) + 0.1*ysR;
        else
            centerssketch(:,1) = xsR;
            centerssketch(:,2) = ysR;
        end

        centerssketch = max(min(centerssketch,512-15),15);
    end

    ll=linspace(-1,1,capImgDim);
    [X1,Y1]=meshgrid(ll,ll);
    
    u_sketch = interp2(X1,xsR,ysR);
    v_sketch = interp2(Y1,xsR,ysR);
    
    u_cap=head_surface.u;
    v_cap=head_surface.v;
    
    % get the desired electrodes on the 3D EEG cap 
    capPoints3d(:,1)=griddata(u_cap,v_cap,head_surface.Vertices(:,1),u_sketch,v_sketch);
    capPoints3d(:,2)=griddata(u_cap,v_cap,head_surface.Vertices(:,2),u_sketch,v_sketch);
    capPoints3d(:,3)=griddata(u_cap,v_cap,head_surface.Vertices(:,3),u_sketch,v_sketch);
end

%% ===== GET LANDMARK LABELS OF EEG CAP =====
% for every new variety of cap we need to edit this function
function [nLandmarkLabels, eegCapLandmarkLabels] = getEegCapLandmarkLabels(capName)
    global Digitize

    eegCapLandmarkLabels = {};
    switch(capName)
        case 'ANT Waveguard (65)'
            eegCapLandmarkLabels = {'Fpz', 'T7', 'T8', 'Oz'};
        case 'BrainProducts ActiCap (66)'
            eegCapLandmarkLabels = {'GND', 'Oz', 'T7', 'T8'};
        otherwise
            nLandmarkLabels = 0;
            return;
    end
    nLandmarkLabels = length(eegCapLandmarkLabels);
end