function [hCuts, OutputOptions] = mri_draw_cuts(hFig, OPTIONS)
% MRI_DRAW_CUTS: Plot a MRI volume in a 3D visualization figure (three orthogonal cuts).
%
% USAGE:  hCuts = mri_draw_cuts(hFig, OPTIONS)
% INPUT: (structure OPTIONS)
%     - sMri             : Brainstorm MRI structure
%     - iMri             : Indice of MRI structure in GlobalData.Mri array
%     - cutsCoords       : [x,y,z] location of the cuts in the volume
%                          (value that is set to NaN => cut is not displayed)
%     - MriThreshold     : Intensity threshold above which a voxel is displayed in the MRI slice.
%     - MriAlpha         : Transparency of MRI slices
%     - MriColormap      : Colormap to use to display the slices
%    (optional)
%     - OverlayCube      : 3d-volume (same size than MRI) with specific data values
%     - OverlayThreshold : Intensity threshold above which a voxel is overlayed in the MRI slices.
%     - OverlayAlpha     : Overlayed voxels transparency 
%     - OverlayColormap  : Colormap to use to display the overlayed data
%     - OverlayBounds    : [minValue, maxValue]: amplitude of the OverlayColormap
%     - isMipAnatomy     : 1=compute maximum intensity projection in the MRI volume
%     - isMipFunctional  : 1=compute maximum intensity projection in the OVerlay volume
%     - UpsampleImage    : 0=disabled, >0=upsample factor
%
% OUTPUT:
%     - hCuts         : [3x1 double] Graphic handles to the images that were created
%     - OutputOptions : structure with some output information
%          |- MipAnatomy    : {3x1 cell}
%          |- MipFunctional : {3x1 cell}

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2006-2020

global GlobalData;

%% ===== INITIALIZATION =====
isOverlay = ~isempty(OPTIONS.OverlayCube);
% Output variable
hCuts = [-1 -1 -1];
OutputOptions.MipAnatomy    = cell(3,1);
OutputOptions.MipFunctional = cell(3,1);
% Colormap bounds
if isempty(OPTIONS.sMri.Histogram.intensityMax)
    MriColormapBounds = [];
else
    MriColormapBounds = [0 double(OPTIONS.sMri.Histogram.intensityMax)];
end
% Get the type of figure
FigureId = getappdata(hFig, 'FigureId');
% Get in which axes we are supposed to display the MRI
switch (FigureId.Type)
    case {'3DViz', 'Topography'}
        hTarget = findobj(hFig, '-depth', 1, 'tag', 'Axes3D');
    case 'MriViewer'
        % Get figure handles
        Handles = bst_figures('GetFigureHandles', hFig);
        hTarget = [Handles.imgs_mri, Handles.imgc_mri, Handles.imga_mri];
end
% Get index for 4th dimension ("time")
if ~isempty(GlobalData.UserTimeWindow.NumberOfSamples) && (size(OPTIONS.sMri.Cube, 4) == GlobalData.UserTimeWindow.NumberOfSamples) && (GlobalData.UserTimeWindow.CurrentTime == round(GlobalData.UserTimeWindow.CurrentTime))
    i4 = GlobalData.UserTimeWindow.CurrentTime;
else
    i4 = 1;
end


%% ===== DISPLAY SLICES =====
for iCoord = 1:3
    % Ignore the slice if indice is NaN
    if isnan(OPTIONS.cutsCoords(iCoord))
        continue
    end
    
    % === GET MRI SLICE ===
    % If maximum intensity power required
    if OPTIONS.isMipAnatomy 
        % If the maximum is not yet computed: compute it
        if isempty(OPTIONS.MipAnatomy{iCoord})
            sliceMri = double(mri_getslice(OPTIONS.sMri.Cube(:,:,:,i4), OPTIONS.cutsCoords(iCoord), iCoord, OPTIONS.isMipAnatomy)');
            OutputOptions.MipAnatomy{iCoord} = sliceMri;
        % Else: use the previously computed maximum
        else
            sliceMri = OPTIONS.MipAnatomy{iCoord};
        end
    % Else: just extract a slice from the volume
    else
        sliceMri = double(mri_getslice(OPTIONS.sMri.Cube(:,:,:,i4), OPTIONS.cutsCoords(iCoord), iCoord, OPTIONS.isMipAnatomy)');
    end
    
    % === GET OVERLAY SLICE ===
    % Get Overlay slice
    if isOverlay
        MriOptions = bst_get('MriOptions');
        % If no data (if overlaying a mask of surface, for instance) => no smoothing
        if isequal(OPTIONS.OverlayBounds, [-1 1]) || isequal(OPTIONS.OverlayBounds, [-0.5, 0.5])
            MriOptions.OverlaySmooth = [];
        end
        % If maximum intensity power required
        if OPTIONS.isMipFunctional 
            % If the maximum is not yet computed: compute it
            if isempty(OPTIONS.MipFunctional{iCoord})
                sliceOverlay = double(mri_getslice(OPTIONS.OverlayCube, OPTIONS.cutsCoords(iCoord), iCoord, OPTIONS.isMipFunctional, MriOptions.OverlaySmooth, OPTIONS.sMri.Voxsize)');
                OutputOptions.MipFunctional{iCoord} = sliceOverlay;
            % Else: use the previously computed maximum
            else
                sliceOverlay = OPTIONS.MipFunctional{iCoord};
            end
        % Else: just extract a slice from the volume
        else
            sliceOverlay = double(mri_getslice(OPTIONS.OverlayCube, OPTIONS.cutsCoords(iCoord), iCoord, OPTIONS.isMipFunctional, MriOptions.OverlaySmooth, OPTIONS.sMri.Voxsize)');
        end
    else
        sliceOverlay = [];
    end

    % === APPLY COLORMAP ===
    % Alpha value depends on if MIP is used
    if OPTIONS.isMipFunctional && ~OPTIONS.isMipAnatomy
        alphaValue = .3;
    else
        alphaValue = 0;
    end
    % Compute alpha map
    sliceSize = size(sliceMri);
    AlphaMap = ones(sliceSize) * (1 - OPTIONS.MriAlpha);
    AlphaMap(sliceMri < OPTIONS.MriThreshold) = alphaValue;
    % Apply colormap to slice
    cmapSlice = ApplyColormap(sliceMri, OPTIONS.MriColormap, MriColormapBounds, OPTIONS.MriIndexed);

    % === Display overlay slice ===
    if isOverlay
        % Apply colormap to overlay slice
        cmapOverlaySlice = ApplyColormap(sliceOverlay, OPTIONS.OverlayColormap, OPTIONS.OverlayBounds, OPTIONS.OverlayIndexed);
        % Build overlay mask
        overlayMask = (sliceOverlay ~= 0);
        % Threshold data values
        if ~OPTIONS.OverlayAbsolute && (OPTIONS.OverlayBounds(1) == -OPTIONS.OverlayBounds(2))
            overlayMask(abs(sliceOverlay) < OPTIONS.OverlayThreshold * max(abs(OPTIONS.OverlayBounds))) = 0;
        elseif (OPTIONS.OverlayBounds(2) <= 0)
            overlayMask(sliceOverlay > OPTIONS.OverlayBounds(2)) = 0;
        else
            overlayMask((sliceOverlay < OPTIONS.OverlayBounds(1) + (OPTIONS.OverlayBounds(2)-OPTIONS.OverlayBounds(1)) * OPTIONS.OverlayThreshold)) = 0;
        end

        % Theshold objects sizes
        if (OPTIONS.OverlaySizeThreshold > 1)
            [maskLabel, num, sz] = dg_label(overlayMask, 8);
            overlayMask(sz < 3 * OPTIONS.OverlaySizeThreshold) = 0;
        end
        % Apply real transparency value
        overlayMask = double(overlayMask) * (1 - OPTIONS.OverlayAlpha);
        % Draw overlay slice over MRI slice
        cmapSlice(:,:,1) = cmapSlice(:,:,1) .* (1 - overlayMask) + cmapOverlaySlice(:,:,1) .* overlayMask;
        cmapSlice(:,:,2) = cmapSlice(:,:,2) .* (1 - overlayMask) + cmapOverlaySlice(:,:,2) .* overlayMask;
        cmapSlice(:,:,3) = cmapSlice(:,:,3) .* (1 - overlayMask) + cmapOverlaySlice(:,:,3) .* overlayMask;
    end
    
    % Display function depends on figure type
    switch (FigureId.Type)
        case {'3DViz', 'Topography'}
            hCut = PlotSlice3DViz(hTarget, cmapSlice, OPTIONS.cutsCoords(iCoord), iCoord, OPTIONS.sMri, AlphaMap, OPTIONS.UpsampleImage);
            % Plot tensors
            if isequal(FigureId.SubType, 'Tensors') && ~OPTIONS.isFast
                isProgress = bst_progress('isVisible');
                if ~isProgress
                    bst_progress('start', 'MRI display', 'Updating tensors...');
                end
                PlotTensor3DViz(hFig, hTarget, OPTIONS.cutsCoords(iCoord), iCoord, OPTIONS.sMri);
                if ~isProgress
                    drawnow;
                    bst_progress('stop');
                end
            end
        case 'MriViewer'
            hCut = PlotSliceMriViewer(hTarget(iCoord), cmapSlice);
    end
    if ~isempty(hCut)
        hCuts(iCoord) = hCut;
    end
end
end


%% ================================================================================================
%  ===== INTERNAL FUNCTIONS =======================================================================
%  ================================================================================================
%% ===== APPLY COLORMAP =====
% APPLY_COLORMAP: Apply a colormap to an array : convert values from indexed colors to RGB.
% USAGE:  cmapA = ApplyColormap( A, CMap, intensityBounds, isIndexed )
%         cmapA = ApplyColormap( A, CMap )
% INPUT:
%     - A    : Array [N,1]
%     - CMap : Colormap [nbColor,3], all values in [0,1]
%     - intensityBounds : (minVal,maxVal) indicates to which values of A array the first and last
%                         colors of colormap CMap are assigned.
%                         If not specified: use [min(A), max(A)]
function cmapA = ApplyColormap( A, CMap, intensityBounds, isIndexed )
    % Parse inputs
    if (nargin < 3) || isempty(isIndexed)
        isIndexed = 0;
    end
    if (nargin < 3) || isempty(intensityBounds)
        intensityBounds = [min(A(:)), max(A(:))];
    end
    % If slice is empty : return
    if (intensityBounds(1)==intensityBounds(2))   % || (intensityBounds(2) == 0)
        cmapA = repmat(A, [1 1 3]);
        return
    end
    % Convert everything to double
    A = double(A);
    intensityBounds = double(intensityBounds);
    
    % Indexed colormap (integer values)
    if isIndexed
        % Consider that input values are indices in the lookup table
        A = bst_saturate(round(A) + 1, [1, size(CMap,1)]);
    % Linear mapping (real values)
    else
        % If some values are below (resp. above) the lower (resp. upper) bound => saturate
        A(A < intensityBounds(1)) = intensityBounds(1);
        A(A > intensityBounds(2)) = intensityBounds(2);
        % Reduce array amplitude to the the colormap size
        A = floor( (A - intensityBounds(1)) ./ (intensityBounds(2)-intensityBounds(1)) .* (size(CMap,1)-1) ) + 1;
    end
    % Create RGB array
    cmapA = cat(3, reshape(CMap(A,1), size(A)), ...
                   reshape(CMap(A,2), size(A)), ...
                   reshape(CMap(A,3), size(A)));
end

%% ===== PLOT SLICES IN 3D ======
function hCut = PlotSlice3DViz(hAxes, cmapSlice, sliceLocation, dim, sMri, AlphaMap, UpsampleImage)
    % Get locations of the slice
    nbPts = 50;
    baseVect = linspace(0,1,nbPts);
    mriSize = size(sMri.Cube);
    switch (dim)
        case 1
            voxX = ones(nbPts) .* sliceLocation; 
            voxY = meshgrid(baseVect)  .* mriSize(2);   
            voxZ = meshgrid(baseVect)' .* mriSize(3); 
        case 2
            voxX = meshgrid(baseVect)  .* mriSize(1); 
            voxY = ones(nbPts) .* sliceLocation;     
            voxZ = meshgrid(baseVect)' .* mriSize(3); 
        case 3
            voxX = meshgrid(baseVect)  .* mriSize(1); 
            voxY = meshgrid(baseVect)' .* mriSize(2); 
            voxZ = ones(nbPts) .* sliceLocation;            
    end

    % === Switch coordinates from MRI-CS to SCS ===
    % Apply Rotation/Translation
    voxXYZ = [voxX(:), voxY(:), voxZ(:)];
    scsXYZ = cs_convert(sMri, 'voxel', 'scs', voxXYZ);
    if isempty(scsXYZ)
        disp(['BST> Warning: Could not plot the MRI in 3D.' 10 ...
              'BST> The SCS coordinates are not available for this MRI: define NAS/LPA/RPA fiducials.']);
        hCut = [];
        return;
    end
    % Get coordinates of the points
    x = reshape(scsXYZ(:,1), nbPts, nbPts);
    y = reshape(scsXYZ(:,2), nbPts, nbPts);
    z = reshape(scsXYZ(:,3), nbPts, nbPts);

    % === SMOOTH IMAGE ===
    if (UpsampleImage > 0)
        x = imresize(x, UpsampleImage);
        y = imresize(y, UpsampleImage);
        z = imresize(z, UpsampleImage);
        cmapSlice = imresize(cmapSlice, UpsampleImage);
        AlphaMap = imresize(AlphaMap, UpsampleImage);
    end
    
    % === PLOT SURFACE ===
    tag = sprintf('MriCut%d', dim);
    % Delete previous cut
    delete(findobj(hAxes, '-depth', 1, 'Tag', tag));
    % Plot new surface  
    hCut = surface('XData',     x, ...
                   'YData',     y, ...
                   'ZData',     z, ...
                   'CData',     cmapSlice, ...
                   'FaceColor',        'texturemap', ...
                   'FaceAlpha',        'texturemap', ...
                   'AlphaData',        AlphaMap, ...
                   'AlphaDataMapping', 'none', ...
                   'EdgeColor',        'none', ...
                   'AmbientStrength',  .5, ...
                   'DiffuseStrength',  .5, ...
                   'SpecularStrength', 0, ...
                   'Tag',              tag, ...
                   'Parent',           hAxes);
end


%% ===== PLOT SLICES IN MRIVIEWER ======
function hCut = PlotSliceMriViewer(hImg, cmapSlice)
    % Get locations of the slice
    set(hImg, 'CData', cmapSlice);
    hCut = hImg;
end


%% ===== PLOT TENSORS IN 3D FIGURE =====
function hTensorCut = PlotTensor3DViz(hFig, hAxes, sliceLocation, dim, sMri)
    % Get figure handles
    Handles = bst_figures('GetFigureHandles', hFig);
    s = Handles.TensorDisplay;
    if isempty(s)
        hTensorCut = [];
        return;
    end
    % Find elements in the current cut
    iElemCut = find(abs(s.ElemCenterVox(:,dim) - sliceLocation) < s.tol .* sMri.Voxsize(dim) .* 1000);
    % Scaling tensor object size
    factor = 4 / 1000; % 4=optimal value for the SCS coordinates, 1000=display S/m values at a millimeter scale
    % Different display modes
    switch lower(s.DisplayMode)
        case 'ellipse'
            % Delete previous slices
            delete(findobj(hAxes, '-depth', 1, 'Tag', 'TensorEllipses'));
            % Define ellipse geometry
            nVert = 32;
            [sphereVertex, sphereFaces] = tess_sphere(nVert);
            % Assemble faces
            tensorFaces = repmat(sphereFaces, length(iElemCut), 1) + ...
                repmat(reshape(repmat((0:length(iElemCut)-1)*nVert, size(sphereFaces,1), 1), [], 1), 1, 3);
            % Assemble colors: abs([v(2,1) v(1,1) v(3,1)])
            tensorColor = reshape(repmat(abs(s.Tensors(iElemCut,[2,1,3]))', size(sphereFaces,1), 1), 3, [])';
            % Assemble all tensors ellipsoids
            tensorVertices = repmat(sphereVertex, length(iElemCut), 1);
            for i = 1:length(iElemCut)
                iVertSph = ((i-1) * nVert + 1) : i*nVert;
                % Scaling
                tensorVertices(iVertSph,:) = bst_bsxfun(@times, tensorVertices(iVertSph,:), s.Tensors(iElemCut(i), 10:12) .* factor);
                % Rotation
                tensorVertices(iVertSph,:) = (reshape(s.Tensors(iElemCut(i), 1:9),3,3) * tensorVertices(iVertSph,:)')';
                % Translation
                tensorVertices(iVertSph,:) = bst_bsxfun(@plus, tensorVertices(iVertSph,:), s.ElemCenter(iElemCut(i),:));
            end
            % Plot tensors
            hTensorCut = patch(...
                'Faces',            tensorFaces, ...
                'Vertices',         tensorVertices,...
                'FaceColor',        'flat', ...
                'FaceVertexCData',  tensorColor, ...
                'EdgeColor',        'none', ...
                'BackfaceLighting', 'unlit', ...
                'AmbientStrength',  0.7, ...
                'DiffuseStrength',  0.3, ...
                'SpecularStrength', 0, ...
                'FaceLighting',     'gouraud', ...
                'Tag',              'TensorEllipses', ...
                'Parent',           hAxes);

        case 'arrow'
            % Delete previous slices
            delete(findobj(hAxes, '-depth', 1, 'Tag', 'TensorArrows'));
%             delete(findobj(hAxes, '-depth', 1, 'Tag', 'TensorDots'));
            % Assemble colors: abs([v(2,1) v(1,1) v(3,1)])
            tensorColor = reshape(repmat(abs(s.Tensors(iElemCut,[2,1,3]))', 2, 1), 3, [])';
            % Vertices: Segments from element centers in the direction of the tensor
            vertArrows = [s.ElemCenter(iElemCut,:)'; ...
                          s.ElemCenter(iElemCut,:)' + factor .* s.Tensors(iElemCut, 10:12)' .* s.Tensors(iElemCut, 1:3)'];
            % Display arrows
            hTensorCut = patch(...
                'Vertices', reshape(vertArrows, 3, [])', ...
                'Faces', [(1:2:2*length(iElemCut))', (2:2:2*length(iElemCut))'], ...
                'LineWidth',        1, ...
                'FaceVertexCData',  tensorColor, ...
                'FaceColor',       'none', ...
                'EdgeColor',       'flat', ...
                'MarkerFaceColor', 'none', ...
                'Tag',              'TensorArrows', ...
                'Parent',           hAxes);
%             % Add markers at the center of the elements
%             hTensorDots = line(s.ElemCenter(iElemCut,1), s.ElemCenter(iElemCut,2), s.ElemCenter(iElemCut,3), ...
%                 'Parent',          hAxes, ...
%                 'LineStyle',       'none', ...
%                 'MarkerEdgeColor', [1 1 1], ...
%                 'MarkerSize',      4, ...
%                 'Marker',          '.', ...
%                 'Tag',             'TensorDots');
        otherwise
            error('Invalid display mode.');
    end
end


