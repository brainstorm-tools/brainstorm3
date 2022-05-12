function [sMriNew, Transf, errMsg] = mri_resample(MriFile, CubeDim, Voxsize, Method)
% MRI_RESAMPLE:  Reslice a volume using new dimensions and voxel resolution.
%
% USAGE:     [sMriNew, Transf, errMsg] = mri_resample(sMri,    CubeDim=[ask], Voxsize=[ask], Method='linear')
%         [MriFileNew, Transf, errMsg] = mri_resample(MriFile, CubeDim=[ask], Voxsize=[ask], Method='linear')
%
% INPUTS:
%    - MriFile : Relative path to a Brainstorm MRI file (containing a Braintsorm MRI structure)
%    - sMri    : Brainstorm MRI structure (fields Cube, Voxsize, SCS, NCS...) 
%    - CubeDim : Dimensions [x,y,z] in voxels of the output volume
%    - Voxsize : Resolution [x,y,z] in millimeters of one voxel of the output volume
%    - Method  : Interpolation method: {'linear', 'spline', 'cubic', 'nearest'}
%
% OUTPUTS:
%    - MriFileNew : Relative path to the new Brainstorm MRI file (containing the structure sMriNew)
%    - sMriNew    : Brainstorm MRI structure with the resampled volume
%    - Transf     : [4x4] transformation matrix to convert MRI coordinates from the old volume to the new volume
%    - errMsg     : Error messages if any

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
% Authors: Francois Tadel, 2016-2021

% ===== PARSE INPUTS =====
sMriNew = [];
Transf = [];
errMsg = [];
% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'MRI resample', 'Loading volume...');
end
% USAGE: mri_resample(sMri, ...)
if isstruct(MriFile)
    sMri = MriFile;
    MriFile = [];
% USAGE: mri_resample(MriFile, ...)
elseif ischar(MriFile)
    sMri = in_mri_bst(MriFile);
else
    error('Invalid call.');
end
% Resampling method
if (nargin < 4) || isempty(Method)
    Method = 'linear';
end
% Ask for destination sampling
oldCubeDim = size(sMri.Cube(:,:,:,1));
if (nargin < 3) || isempty(CubeDim) || isempty(Voxsize)
    % Default values: current ones
    oldVoxsize = sMri.Voxsize;
    % Ask for size and resolution
    res = java_dialog('input', {'New MRI dimensions in voxels: [x,y,z]', 'New MRI resolution in millimeters: [x,y,z]', 'Method: linear, spline, cubic, nearest'}, 'Resample MRI', [], ...
                      {sprintf('[%d, %d, %d]', oldCubeDim), sprintf('[%1.4f, %1.4f, %1.4f]', oldVoxsize), 'linear'});
    % If user cancelled: return
    if isempty(res)
        if ~isProgress
            bst_progress('stop');
        end
        return
    end
    % Get new values
    CubeDim = str2num(res{1});
    Voxsize = str2num(res{2});
    Method = res{3};
    if (length(CubeDim) ~= 3) || (length(Voxsize) ~= 3)
        errMsg = 'Invalid inputs.';
        if ~isProgress
            bst_progress('stop');
        end
        return;
    elseif (all(CubeDim == oldCubeDim) && all(abs(Voxsize - oldVoxsize) < 1e-4))
        sMriNew = sMri;
        errMsg = 'No modification.';
        if ~isProgress
            bst_progress('stop');
        end
        return;
    elseif ~ismember(Method, {'linear', 'spline', 'cubic', 'nearest'})
        sMriNew = sMri;
        errMsg = ['Invalid method: ' Method];
        if ~isProgress
            bst_progress('stop');
        end
        return;
    end
end


% ===== INTERPOLATE MRI VOLUME =====
bst_progress('text', 'Resampling volume...');
% Original position vectors
X1 = (((0:oldCubeDim(1)-1) + 0.5) - oldCubeDim(1)/2) .* sMri.Voxsize(1);
Y1 = (((0:oldCubeDim(2)-1) + 0.5) - oldCubeDim(2)/2) .* sMri.Voxsize(2);
Z1 = (((0:oldCubeDim(3)-1) + 0.5) - oldCubeDim(3)/2) .* sMri.Voxsize(3);
% Destination position vectors
X2 = (((0:CubeDim(1)-1) + 0.5) - CubeDim(1)/2) .* Voxsize(1);
Y2 = (((0:CubeDim(2)-1) + 0.5) - CubeDim(2)/2) .* Voxsize(2);
Z2 = (((0:CubeDim(3)-1) + 0.5) - CubeDim(3)/2) .* Voxsize(3);
% Mesh grids
[Xgrid2, Ygrid2, Zgrid2] = meshgrid(Y2, X2, Z2);
% Interpolate volume(s)
n4 = size(sMri.Cube,4);
newCube = cell(1,n4);
for i4 = 1:n4
    newCube{i4} = single(interp3(Y1, X1, Z1, double(sMri.Cube(:,:,:,i4)), Xgrid2, Ygrid2, Zgrid2, Method, 0));
end
newCube = cat(4, newCube{:});
% Initialize transformed structure
sMriNew         = sMri;
sMriNew.Cube    = newCube;
sMriNew.Voxsize = Voxsize;


% ===== UPDATE FIDUCIALS =====
% Transformation: old MRI => new MRI   (millimeters, so no scaling)
T = - oldCubeDim ./2 .*sMri.Voxsize + CubeDim ./2 .*Voxsize;
% Update fiducials
if ~isequal(T, [0 0 0])
    if isfield(sMri, 'SCS') && isfield(sMri.SCS, 'NAS') && ~isempty(sMri.SCS.NAS)
        sMriNew.SCS.NAS = sMri.SCS.NAS + T;
    end
    if isfield(sMri, 'SCS') && isfield(sMri.SCS, 'LPA') && ~isempty(sMri.SCS.LPA)
        sMriNew.SCS.LPA = sMri.SCS.LPA + T;
    end
    if isfield(sMri, 'SCS') && isfield(sMri.SCS, 'RPA') && ~isempty(sMri.SCS.RPA)
        sMriNew.SCS.RPA = sMri.SCS.RPA + T;
    end
    if isfield(sMri, 'SCS') && isfield(sMri.SCS, 'Origin') && ~isempty(sMri.SCS.Origin)
        sMriNew.SCS.Origin = sMri.SCS.Origin + T;
    end
    if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'AC') && ~isempty(sMri.NCS.AC)
        sMriNew.NCS.AC = sMri.NCS.AC + T;
    end
    if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'PC') && ~isempty(sMri.NCS.PC)
        sMriNew.NCS.PC = sMri.NCS.PC + T;
    end
    if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'IH') && ~isempty(sMri.NCS.IH)
        sMriNew.NCS.IH = sMri.NCS.IH + T;
    end
    if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'Origin') && ~isempty(sMri.NCS.Origin)
        sMriNew.NCS.Origin = sMri.NCS.Origin + T;
    end
end


% ===== UPDATE TRANSFORMATIONS =====
Transf = [eye(3), T'; 0 0 0 1];
% Update Brainstorm transformations: SCS and NCS
if ~isequal(Transf, eye(4))
    % Update SCS transformation: MRI(mm)=>SCS
    if isfield(sMri, 'SCS') && isfield(sMri.SCS, 'R') && ~isempty(sMri.SCS.R) && isfield(sMri.SCS, 'T') && ~isempty(sMri.SCS.T)
        % Compute new transformation matrices to SCS
        Tscs = [sMri.SCS.R, sMri.SCS.T; 0 0 0 1] * inv(Transf);
        % Report in the new MRI structure
        sMriNew.SCS.R = Tscs(1:3,1:3);
        sMriNew.SCS.T = Tscs(1:3,4);
    end    
    % Update linear MNI transformation: MRI(mm)=>NCS
    if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'R') && ~isempty(sMri.NCS.R) && isfield(sMri.NCS, 'T') && ~isempty(sMri.NCS.T)
        % Compute new transformation matrices to SCS
        Tncs = [sMri.NCS.R, sMri.NCS.T; 0 0 0 1] * inv(Transf);
        % Report in the new MRI structure
        sMriNew.NCS.R = Tncs(1:3,1:3);
        sMriNew.NCS.T = Tncs(1:3,4);
    end
end
% Update vox2ras: MRI(voxels)=>World(mm), see cs_convert for details on relations between this matrix and Brainstorm's NCS and SCS transformations
if isfield(sMri, 'InitTransf') && ~isempty(sMri.InitTransf) && any(ismember(sMri.InitTransf(:,1), 'vox2ras'))
    iTransf = find(strcmpi(sMri.InitTransf(:,1), 'vox2ras'), 1);
    vox2ras = sMriNew.InitTransf{iTransf(1),2};
    vox2ras(1:3,1:3) = vox2ras(1:3,1:3) * diag(Voxsize ./ sMri.Voxsize);
    vox2ras(1:3,4) = vox2ras(1:3,4) - T';
    sMriNew.InitTransf{iTransf(1),2} = vox2ras;
end


% ===== REMOVE OTHER FIELDS =====
% Remove initial nifti header
if isfield(sMri, 'Header')
    sMriNew.Header = [];
end
% Remove non-linear transformations
if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'iy') && ~isempty(sMri.NCS.iy)
    sMriNew.NCS.iy = [];
end
if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'y') && ~isempty(sMri.NCS.y)
    sMriNew.NCS.y = [];
end
if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'y_vox2ras') && ~isempty(sMri.NCS.y_vox2ras)
    sMriNew.NCS.y_vox2ras = [];
end
if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'y_method') && ~isempty(sMri.NCS.y_method)
    sMriNew.NCS.y_method = [];
end


% ===== SAVE NEW FILE =====
% Save output
if ~isempty(MriFile)
    bst_progress('text', 'Saving new file...');
    % Get subject
    [sSubject, iSubject, iMri] = bst_get('MriFile', MriFile);
    % Update comment
    sMriNew.Comment = [sMriNew.Comment, '_resample'];
    sMriNew.Comment = file_unique(sMriNew.Comment, {sSubject.Anatomy.Comment});
    % Add history entry
    sMriNew = bst_history('add', sMriNew, 'resample', sprintf('MRI resampled: CubeDim=[%d,%d,%d] Voxsize=[%1.4f,%1.4f,%1.4f].', CubeDim, Voxsize));
    % Save new file
    newMriFile = file_unique(strrep(file_fullpath(MriFile), '.mat', '_resample.mat'));
    shorMriFile = file_short(newMriFile);
    % Save new MRI in Brainstorm format
    sMriNew = out_mri_bst(sMriNew, newMriFile);

    % Register new MRI
    iAnatomy = length(sSubject.Anatomy) + 1;
    sSubject.Anatomy(iAnatomy) = db_template('Anatomy');
    sSubject.Anatomy(iAnatomy).FileName = shorMriFile;
    sSubject.Anatomy(iAnatomy).Comment  = sMriNew.Comment;
    % Update subject structure
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'anatomy', iSubject, iAnatomy);
    % Save database
    db_save();
    % Return output filename
    sMriNew = shorMriFile;
end
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

