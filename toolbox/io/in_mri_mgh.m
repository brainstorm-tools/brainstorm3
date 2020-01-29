function [sMri, vox2ras] = in_mri_mgh(MriFile, isApplyBst, isApplyVox2ras)
% IN_MRI_MGH: Read a structural MGH MRI (or gzipped MGZ).
%
% USAGE:  [sMri, vox2ras] = in_mri_mgh(MriFile, isApplyBst=[ask], isApplyVox2ras=[ask]);
%
% INPUT:
%    - MriFile    : full path to a MRI file, WITH EXTENSION
%    - isApplyBst : If 1, apply best orientation found to match Brainstorm convention
%                   considering that the volume is aligned as the standard T1.mgz in the 
%                   FreeSurfer output folder.
%    - isApplyVox2ras : Apply additional transformation to the volume
% OUTPUT:
%    - sMri    : Standard brainstorm structure for MRI volumes
%    - vox2ras : [4x4] transformation matrix: voxels to RAS coordinates
%
% FORMAT: https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/MghFormat

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
% Authors: Francois Tadel, 2008-2018

% Parse inputs
if (nargin < 3) || isempty(isApplyVox2ras)
    isApplyVox2ras = [];
end
if (nargin < 2) || isempty(isApplyBst)
    isApplyBst = [];
end


%% ===== UNZIP FILE =====
[MRIpath, MRIbase, MRIext] = bst_fileparts(MriFile);
% If file is gzipped
if strcmpi(MRIext, '.mgz')
    % Get temporary folder
    tmpDir = bst_get('BrainstormTmpDir');
    % Target file
    gunzippedFile = bst_fullfile(tmpDir, [MRIbase, '.mgh']);
    % Unzip file
    res = org.brainstorm.file.Unpack.gunzip(MriFile, gunzippedFile);
    if ~res
        error(['Could not gunzip file "' MriFile '" to:' 10 '"' gunzippedFile '"']);
    end
    % Import dunzipped file
    MriFile = gunzippedFile;
end
         
         
%% ===== LOAD MGH HEADER =====
% Open file
fid = fopen(MriFile, 'rb', 'b') ;
if (fid < 0)
    error(['Could not open file : "' MriFile '".']);
end

% Read header
hdr.version = fread(fid, 1, 'int');
hdr.ndim1   = fread(fid, 1, 'int');
hdr.ndim2   = fread(fid, 1, 'int');
hdr.ndim3   = fread(fid, 1, 'int');
hdr.nframes = fread(fid, 1, 'int');
hdr.type    = fread(fid, 1, 'int');
hdr.dof     = fread(fid, 1, 'int');

unused_space_size = 256 - 2 ;
hdr.ras_good_flag = fread(fid, 1, 'short') ;

if (hdr.ras_good_flag)
    Voxsize = fread(fid, 3, 'float32')' ;
    hdr.Mdc     = fread(fid, 9, 'float32') ;
    hdr.Mdc     = reshape(hdr.Mdc,[3 3]);
    hdr.Pxyz_c  = fread(fid, 3, 'float32') ;
    unused_space_size = unused_space_size - (3*4 + 4*3*4) ; % space for ras transform
    % Assemble vox2ras matrix
    D = diag(Voxsize);
    Pcrs_c = [hdr.ndim1/2, hdr.ndim2/2, hdr.ndim3/2]'; % Should this be kept?
    Pxyz_0 = hdr.Pxyz_c - hdr.Mdc * D * Pcrs_c;
    vox2ras = [hdr.Mdc * D, Pxyz_0;  ...
	           0 0 0 1];
else
    vox2ras = [];
end

% Position at the end of the header
fseek(fid, unused_space_size, 'cof') ;


%% ===== LOAD MRI VOLUME =====
nv = hdr.ndim1 * hdr.ndim2 * hdr.ndim3 * hdr.nframes;
% Determine number of bytes per voxel
switch hdr.type
    case 0,  precision = 'uchar';
    case 1,  precision = 'int';
    case 3,  precision = 'float32';
    case 4,  precision = 'short';
end
% Read volume
Cube = fread(fid, nv, precision);
% Check whole volume was read
if(numel(Cube) ~= nv)
    error('Unrecognized data format.');
end
% Load MR params
if(~feof(fid))
    [hdr.mr_parms, count] = fread(fid,4,'float32');
    if (count ~= 4)
        error('Error reading MR params.');
    end
end
% Close file
fclose(fid) ;

% Prepare volume
Cube = reshape(Cube, [hdr.ndim1 hdr.ndim2 hdr.ndim3 hdr.nframes]);
% Keep only first time frame
if (hdr.nframes > 1)
    Cube = Cube(:,:,:,1);
end


%% ===== TRANSFORM TO BRAINSTORM COORDINATES =====
% Ask user
if isempty(isApplyBst)
    isApplyBst = java_dialog('confirm', ['Apply the standard transformation FreeSurfer=>Brainstorm?' 10 10 ...
                                         'Answer "yes" if importing transformed volumes such as T1.mgz in the' 10 ...
                                         'FreeSurfer output folder, or other volumes in the same folder.' 10 10],  'MRI orientation');
end

% Apply transformation
if isApplyBst
    % Permute MRI dimensions
    Cube = permute(Cube, [2 3 1]);
    Voxsize = Voxsize([2 3 1]);
    % Rotation / Axis Y
    Cube = permute(Cube, [3 2 1]);
    Cube = bst_flip(Cube, 3);
    Voxsize = Voxsize([3 2 1]);
    % Flip / X
    Cube = bst_flip(Cube, 1);

    % Report these changes to the vox2ras matrix
    if ~isempty(vox2ras)
        TransBst = [-1,  0,  0,  size(Cube,1)-1;
                     0,  0, -1,  size(Cube,2)-1;
                     0,  1,  0   0;
                     0,  0,  0   1];
        vox2ras = vox2ras * TransBst;
    end
    isApplyVox2ras = 0;
end

% ===== CREATE BRAINSTORM STRUCTURE =====
sMri = struct('Cube',   Cube, ...
             'Voxsize', Voxsize, ...
             'Comment', 'MRI', ...
             'Header',  hdr);

% ===== VOLUME ORIENTATION =====
% Apply orientation to the volume
if ~isempty(vox2ras) && ~isequal(isApplyVox2ras, 0)
    [vox2ras, sMri] = cs_nii2bst(sMri, vox2ras, isApplyVox2ras);
end



