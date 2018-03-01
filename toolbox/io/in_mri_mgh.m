function MRI = in_mri_mgh(MriFile)
% IN_MRI_MGH: Read a structural MGH MRI (or gzipped MGZ).
%
% USAGE:  MRI = in_mri_mgh(MriFile);
%
% INPUT:
%     - MriFile : full path to a MRI file, WITH EXTENSION
% OUTPUT:
%     - MRI : Standard brainstorm structure for MRI volumes
%
% FORMAT: https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/MghFormat

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2015


%% ===== INITIALIZATION =====   
% Output variable
MRI = struct('Cube',    [], ...
             'Voxsize', [1 1 1], ...
             'Comment', 'MRI', ...
             'Header',  []);

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
    MRI.Voxsize = fread(fid, 3, 'float32')' ;
    hdr.Mdc     = fread(fid, 9, 'float32') ;
    hdr.Mdc     = reshape(hdr.Mdc,[3 3]);
    hdr.Pxyz_c  = fread(fid, 3, 'float32') ;
    unused_space_size = unused_space_size - (3*4 + 4*3*4) ; % space for ras transform
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
MRI.Cube = fread(fid, nv, precision);
% Check whole volume was read
if(numel(MRI.Cube) ~= nv)
    bst_error('Unrecognized data format.', 'Import MGH MRI', 0);
    MRI = [];
    return;
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


%% ===== RETURN DATA =====
% Prepare volume
MRI.Cube = reshape(MRI.Cube, [hdr.ndim1 hdr.ndim2 hdr.ndim3 hdr.nframes]);
% Keep only first time frame
if (hdr.nframes > 1)
    MRI.Cube = MRI.Cube(:,:,:,1);
end

% Transform volume to get something similar to CTF orientation

% Permute MRI dimensions
MRI.Cube = permute(MRI.Cube, [2 3 1]);
% Update voxel size
MRI.Voxsize = MRI.Voxsize([2 3 1]);

% Rotation / Axis Y
MRI.Cube = permute(MRI.Cube, [3 2 1]);
MRI.Cube = bst_flip(MRI.Cube, 3);
% Update voxel size
MRI.Voxsize = MRI.Voxsize([3 2 1]);

% Flip / X
MRI.Cube = bst_flip(MRI.Cube, 1);

MRI.Header = hdr;




