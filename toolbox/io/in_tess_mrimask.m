function TessMat = in_tess_mrimask(MriFile, isMni, SelLabels)
% IN_TESS_MRIMASK: Import an MRI as a mask or atlas, and tesselate the volumes in it
%
% USAGE:  TessMat = in_tess_mrimask(MriFile, isMni=0, SelLabels=[all])
%         TessMat = in_tess_mrimask(sMri,    isMni=0, SelLabels=[all])

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
% Authors: Francois Tadel, 2012-2020

% Parse inputs
if (nargin < 3) || isempty(SelLabels)
    SelLabels = [];
end
if (nargin < 2) || isempty(isMni)
    isMni = 0;
end

% Read MRI volume
if ischar(MriFile)
    % Try to get volume labels for this atlas automatically
    [Labels, AtlasName] = mri_getlabels(MriFile);
    % Read volume
    isInteractive = ~isempty(AtlasName) && ~ismember(AtlasName, {'aseg', 'svreg', 'freesurfer', 'marsatlas'});
    if isMni
        sMri = in_mri(MriFile, 'ALL-MNI', 0, 0);
    else
        sMri = in_mri(MriFile, 'ALL', isInteractive, 0);
        if strcmp(AtlasName, 'svreg')
            sMri.Cube = mod(sMri.Cube,1000);
        end
    end
    if isempty(sMri)
        TessMat = [];
        return;
    end
else
    sMri = MriFile;
    MriFile = [];
    Labels = [];
    AtlasName = [];
end
% Convert to double and keep only the first volume (if multiple)
sMri.Cube = double(sMri.Cube(:,:,:,1));
% Get al the values in the MRI
allValues = unique(sMri.Cube);
% If values are not integers, it is not a mask or an atlas: it has to be binarized first
if any(allValues ~= round(allValues))
    % Warning: not a binary mask
    isConfirm = java_dialog('confirm', ['Warning: This is not a binary mask.' 10 'Try to import this MRI as a surface anyway?'], 'Import binary mask');
    if ~isConfirm
        TessMat = [];
        return;
    end
    % Analyze MRI histogram
    Histogram = mri_histogram(sMri.Cube);
    % Binarize based on background level
    sMri.Cube = (sMri.Cube > Histogram.bgLevel);
    allValues = [0,1];
end
% Display warning when no MNI transformation available
if isMni && (~isfield(sMri, 'NCS') || ...
    ((~isfield(sMri.NCS, 'R') || ~isfield(sMri.NCS, 'T') || isempty(sMri.NCS.R) || isempty(sMri.NCS.T)) && ... 
     (~isfield(sMri.NCS, 'iy') || isempty(sMri.NCS.iy))))
    isMni = 0;
    disp('Error: No MNI transformation available in this file.');
end

% If the volume contains labels
if (length(allValues) > 10) && ~isempty(MriFile) && ~isempty(Labels)
    % FreeSurfer ASEG
    if strcmp(AtlasName, 'aseg') || strcmp(AtlasName, 'freesurfer')
        % Keep only a subset of labels
        if ~isempty(SelLabels)
            Labels = Labels(ismember(Labels(:,2), SelLabels), :);
        end
        % Group the cerebellum white+cortex voxels
        sMri.Cube(sMri.Cube == 7) = 8;
        sMri.Cube(sMri.Cube == 46) = 47;
        % Group all the brainstem elements
        sMri.Cube(sMri.Cube == 170) = 16;
        sMri.Cube(sMri.Cube == 171) = 16;
        sMri.Cube(sMri.Cube == 172) = 16;
        sMri.Cube(sMri.Cube == 173) = 16;
        sMri.Cube(sMri.Cube == 174) = 16;
        sMri.Cube(sMri.Cube == 175) = 16;
        sMri.Cube(sMri.Cube == 177) = 16;
        sMri.Cube(sMri.Cube == 178) = 16;
        sMri.Cube(sMri.Cube == 179) = 16;
        % Update unique values
        allValues = unique(sMri.Cube);
        
    % BrainSuite SVREG
    elseif strcmp(AtlasName, 'svreg') 
        % Keep only a subset of labels
        if ~isempty(SelLabels)
            Labels = Labels(ismember(Labels(:,2), SelLabels), :);
        end
        % Remove 4th digit decimal (indicates GM/WM)
        isGM = ((sMri.Cube >= 1000) & (sMri.Cube < 2000));
        isWM = ((sMri.Cube >= 2000) & (sMri.Cube < 3000));
        sMri.Cube(isGM) = sMri.Cube(isGM) - 1000;
        sMri.Cube(isWM) = sMri.Cube(isWM) - 2000;
    end

    % Keep only the labelled areas
    [allValues, I, J] = intersect([Labels{:,1}], allValues);
    Labels = Labels(I,:);
    % Get labelled values in alphabetical order 
    allValues = [Labels{:,1}];
% No labels available
else
    Labels = {};
end
% Remove zero (background)
allValues = setdiff(allValues, 0);
    
TessMat = repmat(struct('Comment', [], 'Vertices', [], 'Faces', []), [1, 0]);
% Generate a tesselation for all the others
for i = 1:length(allValues)
    % Display progress bar
    if (length(allValues) > 1)
        bst_progress('text', sprintf('Importing atlas surface #%d/%d...', i, length(allValues)));
    end

    % Get the binary mask of the current region
    mask = (sMri.Cube == allValues(i));
    % Fill small holes
    mask = mri_dilate(mask, 1);
    mask = mask & ~mri_dilate(~mask, 1);
    % Close the volumes by setting to zero all the edges
    mask([1,end],:,:) = 0;
    mask(:,[1,end],:) = 0;
    mask(:,:,[1,end]) = 0;
    % Empty mask: skip
    if ~any(mask(:))
        continue;
    end
    
    % Comment field
    if ~isempty(Labels)
        Comment = Labels{i,2};
    elseif (length(allValues) > 1)
        Comment = sprintf('%d', allValues(i));
    elseif ~isempty(MriFile)
        [fPath, fBase, fExt] = bst_fileparts(MriFile);
        Comment = fBase;
    else
        Comment = 'mask';
    end
    
    % Add new tesselation
    iTess = [];
    % If importing an atlas in MNI coordinates
    if isMni
        % Get the coordinates of all the points in the mask
        Pvox = [];
        iMask = find(mask);
        [Pvox(:,1),Pvox(:,2),Pvox(:,3)] = ind2sub(size(mask), iMask);
        % Convert to MNI coordinates
        Pmni = cs_convert(sMri, 'voxel', 'mni', Pvox);
        % Find left and right areas
        iL = find(Pmni(:,1) < 0);
        iR = find(Pmni(:,1) >= 0);
        % If this is a bilateral region: split in two
        if ~isempty(iL) && ~isempty(iR) && (length(iL) / length(iR) < 1.6) && (length(iL) / length(iR) > 0.4)
            % Create two separate masks
            maskL = mask;
            maskR = mask;
            maskL(iMask(iR)) = 0;
            maskR(iMask(iL)) = 0;
            % Tesselate left
            [Vertices, Faces] = TesselateMask(sMri, maskL, isMni);
            if ~isempty(Vertices)
                iTess = length(TessMat) + 1;
                TessMat(iTess).Comment  = [Comment, ' L'];
                TessMat(iTess).Vertices = Vertices;
                TessMat(iTess).Faces    = Faces;
            end
            % Tesselate right
            [Vertices, Faces] = TesselateMask(sMri, maskR, isMni);
            if ~isempty(Vertices)
                iTess = length(TessMat) + 1;
                TessMat(iTess).Comment  = [Comment, ' R'];
                TessMat(iTess).Vertices = Vertices;
                TessMat(iTess).Faces    = Faces;
            end
        end
    end
    
    % If tesselation was not already added
    if isempty(iTess)
        % Tesselate surface
        [Vertices,Faces] = TesselateMask(sMri, mask, isMni);
        % Create new entry
        if ~isempty(Vertices)
            iTess = length(TessMat) + 1;
            TessMat(iTess).Comment  = Comment;
            TessMat(iTess).Vertices = Vertices;
            TessMat(iTess).Faces    = Faces;
        end
    end
end
end



%% ===== FINALIZE SURFACE =====
function [Vertices, Faces] = TesselateMask(sMri, mask, isMni)
    % Create an isosurface
    [Faces, Vertices] = mri_isosurface(mask, 0.5);
    % Convert to Brainstorm format
    Vertices = Vertices(:, [2 1 3]);
    Faces    = Faces(:, [2 1 3]);
    % Convert coordinates
    if isMni
        % Convert from voxels to MNI space
        Vertices = cs_convert(sMri, 'voxel', 'mni', Vertices);
    else
        % Convert from voxels to MRI (in meters)
        Vertices = cs_convert(sMri, 'voxel', 'mri', Vertices);
    end
    % Remove small objects
    [Vertices, Faces] = tess_remove_small(Vertices, Faces);
    % Compute vertex-vertex connectivity
    VertConn = tess_vertconn(Vertices, Faces);
    % Smooth surface
    Vertices = tess_smooth(Vertices, 1, 2, VertConn, 0);
    % Enlarge a bit
    VertNormals = tess_normals(Vertices, Faces, VertConn);
    Vertices = Vertices + 0.0002 * VertNormals;
end



