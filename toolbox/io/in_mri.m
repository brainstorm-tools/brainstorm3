function [MRI, vox2ras] = in_mri(MriFile, FileFormat, isInteractive, isNormalize)
% IN_MRI: Detect file format and load MRI file.
% 
% USAGE:  in_mri(MriFile, FileFormat='ALL')
% INPUT:
%     - MriFile       : full path to a MRI file
%     - FileFormat    : Format of the input file (default = 'ALL')
%     - isInteractive : 0 or 1
%     - isNormalize   : If 1, converts values to uint8 and scales between 0 and 1
% OUTPUT:
%     - MRI         : Standard brainstorm structure for MRI volumes

% NOTES:
%     - MRI structure:
%         |- Voxsize:   [x y z], size of each MRI voxel, in millimeters
%         |- Cube:      MRI volume 
%         |- SCS:       Subject Coordinate System definition
%         |    |- NAS:    [x y z] coordinates of the nasion, in voxels
%         |    |- LPA:    [x y z] coordinates of the left pre-auricular point, in voxels
%         |    |- RPA:    [x y z] coordinates of the right pre-auricular point, in voxels
%         |    |- R:      Rotation to convert MRI coordinates -> SCS coordinatesd
%         |    |- T:      Translation to convert MRI coordinates -> SCS coordinatesd
%         |- Landmarks[]: Additional user-defined landmarks
%         |- NCS:         Normalized Coordinates System (Talairach, MNI, ...)     
%         |    |- AC:             [x y z] coordinates of the Anterior Commissure, in voxels
%         |    |- PC:             [x y z] coordinates of the Posterior Commissure, in voxels
%         |    |- IH:             [x y z] coordinates of any Inter-Hemispheric point, in voxels
%         |- Comment:     MRI description

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2016

% Parse inputs
if (nargin < 4) || isempty(isNormalize)
    isNormalize = 1;
end
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 1;
end
if (nargin < 2) || isempty(FileFormat)
    FileFormat = 'ALL';
end
% Get current byte order
ByteOrder = bst_get('ByteOrder');
if isempty(ByteOrder)
    ByteOrder = 'n';
end
% Initialize returned variables
MRI = [];
vox2ras = [];

% ===== GUNZIP FILE =====
% Get file extension
[filePath, fileBase, fileExt] = bst_fileparts(MriFile);
% If file is gzipped
if strcmpi(fileExt, '.gz')
    % Get temporary folder
    tmpDir = bst_get('BrainstormTmpDir');
    % Target file
    gunzippedFile = bst_fullfile(tmpDir, fileBase);
    % Unzip file
    res = org.brainstorm.file.Unpack.gunzip(MriFile, gunzippedFile);
    if ~res
        error(['Could not gunzip file "' MriFile '" to:' 10 gunzippedFile ]);
    end
    % Import gunzipped file
    MriFile = gunzippedFile;
    [filePath, fileBase, fileExt] = bst_fileparts(MriFile);
end

                
%% ===== DETECT FILE FORMAT =====
isMni = strcmpi(FileFormat, 'ALL-MNI');
if ismember(FileFormat, {'ALL', 'ALL-MNI'})
    % Switch between file extensions
    switch (lower(fileExt))
        case '.mri',                  FileFormat = 'CTF';
        case {'.ima', '.dim'},        FileFormat = 'GIS';
        case {'.img','.hdr','.nii'},  FileFormat = 'Nifti1';
        case '.fif',                  FileFormat = 'Neuromag';
        case {'.mgz','.mgh'},         FileFormat = 'MGH';
        case {'.mnc','.mni'},         FileFormat = 'MINC';
        case '.mat',                  FileFormat = 'BST';
        otherwise,                    error('File format could not be detected, please specify a file format.');
    end
end

% ===== LOAD MRI =====
% Switch between file formats
switch (FileFormat)   
    case 'CTF'
        MRI = in_mri_ctf(MriFile);  % Auto-detect file format
    case 'GIS'
        MRI = in_mri_gis(MriFile, ByteOrder);
    case {'Nifti1', 'Analyze'}
        if isInteractive
            [MRI, vox2ras] = in_mri_nii(MriFile, 0, []); % Function automatically detects right byte order
        else
            [MRI, vox2ras] = in_mri_nii(MriFile, 0, 1); % Function automatically detects right byte order
        end
    case 'MGH'
        MRI = in_mri_mgh(MriFile);
    case 'KIT'
        error('Not supported yet');
    case 'Neuromag'
        error('Not supported yet');
    case 'MINC'
        MRI = in_mri_mnc(MriFile);
    case 'FT-MRI'
        MRI = in_mri_fieldtrip(MriFile);
    case 'BST'
        % Check that the filename contains the 'subjectimage' tag
        if ~isempty(strfind(lower(fileBase), 'subjectimage'))
            MRI = load(MriFile);
        end
    otherwise
        error(['Unknown format: ' FileFormat]);
end

% If nothing was loaded
if isempty(MRI)
    return
end


%% ===== NORMALIZE VALUES =====
% Normalize if the cube is not already in uint8 (and if not loading an atlas)
if isNormalize && ~strcmpi(FileFormat, 'ALL-MNI') && ~isa(MRI.Cube, 'uint8')
    % Convert to double for calculations
    MRI.Cube = double(MRI.Cube);
    % Start values at zeros
    MRI.Cube = MRI.Cube - min(MRI.Cube(:));
    % Normalize between 0 and 255 and save as uint8
    MRI.Cube = uint8(MRI.Cube ./ max(MRI.Cube(:)) .* 255);
end

%% ===== CONVERT OLD STRUCTURES TO NEW ONES =====
% Apply a coordinates correction
correction = [.5 .5 0];
if isfield(MRI, 'SCS') && isfield(MRI.SCS, 'FiducialName') && ~isempty(MRI.SCS.FiducialName) && isfield(MRI.SCS, 'mmCubeFiducial') && ~isempty(MRI.SCS.mmCubeFiducial)
    % === NASION ===
    iNas = find(strcmpi(MRI.SCS.FiducialName, 'nasion') | strcmpi(MRI.SCS.FiducialName, 'NAS'));
    if ~isempty(iNas)
        MRI.SCS.NAS = MRI.SCS.mmCubeFiducial(:, iNas)' + correction;
    end
    % === LPA ===
    iLpa = find(strcmpi(MRI.SCS.FiducialName, 'LeftPreA') | strcmpi(MRI.SCS.FiducialName, 'LPA'));
    if ~isempty(iLpa)
        MRI.SCS.LPA = MRI.SCS.mmCubeFiducial(:, iLpa)' + correction;
    end
    % === RPA ===
    iRpa = find(strcmpi(MRI.SCS.FiducialName, 'RightPreA') | strcmpi(MRI.SCS.FiducialName, 'RPA'));
    if ~isempty(iRpa)
        MRI.SCS.RPA = MRI.SCS.mmCubeFiducial(:, iRpa)' + correction;
    end
    % Remove old fields
    MRI.SCS = rmfield(MRI.SCS, 'mmCubeFiducial');
    MRI.SCS = rmfield(MRI.SCS, 'FiducialName');
end
if isfield(MRI, 'talCS') && isfield(MRI.talCS, 'FiducialName') && ~isempty(MRI.talCS.FiducialName) && isfield(MRI.talCS, 'mmCubeFiducial') && ~isempty(MRI.talCS.mmCubeFiducial)
    NCS = db_template('NCS');
    % === AC ===
    iAc = find(strcmpi(MRI.talCS.FiducialName, 'AC'));
    if ~isempty(iAc)
        NCS.AC = MRI.talCS.mmCubeFiducial(:, iAc)' + correction;
    end
    % === PC ===
    iPc = find(strcmpi(MRI.talCS.FiducialName, 'PC'));
    if ~isempty(iPc)
        NCS.PC = MRI.talCS.mmCubeFiducial(:, iPc)' + correction;
    end
    % === IH ===
    iIH = find(strcmpi(MRI.talCS.FiducialName, 'IH') | strcmpi(MRI.talCS.FiducialName, 'IC'));
    if ~isempty(iIH)
        NCS.IH = MRI.talCS.mmCubeFiducial(:, iIH)' + correction;
    end
    % Add new field
    MRI.NCS = NCS;
    % Remove old fields
    MRI = rmfield(MRI, 'talCS');
end


%% ===== COMPUTE SCS TRANSFORMATION =====
% If SCS was defined but transformation not computed
if isfield(MRI, 'SCS') && all(isfield(MRI.SCS, {'NAS','LPA','RPA'})) ...
                       && ~isempty(MRI.SCS.NAS) && ~isempty(MRI.SCS.RPA) && ~isempty(MRI.SCS.LPA) ...
                       && (~isfield(MRI.SCS, 'R') || isempty(MRI.SCS.R))
    try
        % Compute transformation
        scsTransf = cs_compute(MRI, 'scs');
        % If the SCS fiducials stored in the MRI file are not valid : ignore them
        if isempty(scsTransf)
            MRI = rmfield(MRI, 'SCS');
        % Else: use SCS transform
        else
            MRI.SCS.R      = scsTransf.R;
            MRI.SCS.T      = scsTransf.T;
            MRI.SCS.Origin = scsTransf.Origin;
        end
    catch
        bst_error('Impossible to identify the SCS coordinate system with the specified coordinates.', 'MRI Viewer', 0);
    end
end

%% ===== SAVE MNI TRANSFORMATION =====
if isMni && ~isempty(vox2ras) && (~isfield(MRI, 'NCS') || ~isfield(MRI.NCS, 'R') || isempty(MRI.NCS.R))
    % 2nd operation: Change reference from (0,0,0) to (.5,.5,.5)
    vox2ras = vox2ras * [1 0 0 -.5; 0 1 0 -.5; 0 0 1 -.5; 0 0 0 1];
    % 1st operation: Convert from MRI(mm) to voxels
    vox2ras = vox2ras * diag(1 ./ [MRI.Voxsize, 1]);
    % Copy MNI transformation to output structure
    MRI.NCS.R = vox2ras(1:3,1:3);
    MRI.NCS.T = vox2ras(1:3,4);
    % Compute default fiducials positions based on MNI coordinates
    MRI = mri_set_default_fid(MRI);
end




