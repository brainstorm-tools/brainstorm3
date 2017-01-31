function MRI = in_mri_mnc(MriFile)
% IN_MRI_MNC: Reads a structural MINC MRI (*.mnc).
%
% USAGE:  [MRI, hdr] = in_mri_mnc(MriFile);

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013

% ===== DETECT FORMAT =====
% Open file
fid = fopen(MriFile, 'r');
if (fid < 0)
	error('Cannot open file.');
end
% Read the first 4 bytes to detect the format
f = fread(fid, [1 4], '*char');
if isequal(f(2:4), 'HDF')
    format = 'minc2';
elseif isequal(f(1:3), 'CDF')
    format = 'minc1';
else
    error('Could not detect MINC version.');
end
% Close file
fclose(fid);

% ===== METHOD 1: MOMINC =====
% Read MINC1 volume
if strcmpi(format, 'minc1')
    disp([10 'MINC> Reading MINC1 file (NetCDF).']);
    [hdr,Cube] = minc_read(MriFile);
else
    %error('MINC2 format not supported yet...');
    disp([10 'MINC> Reading MINC2 file (HDF5).']);
    [hdr,Cube] = minc_read(MriFile);
end

% % Flip volume if necessary
% step = [minc_variable(hdr, 'xspace', 'step'), minc_variable(hdr, 'yspace', 'step'), minc_variable(hdr, 'zspace', 'step')];
% if (length(step) == 3)
%     if (step(1) < 0)
%         
%     end
% end

% Create Brainstorm structure
MRI = db_template('mrimat');
MRI.Comment = 'MRI';
MRI.Cube    = Cube;
MRI.Voxsize = hdr.info.voxel_size;
MRI.Header  = hdr;

% % ===== METHOD 2: MNC2NII =====
% % Get temporary folder
% bstTmp = bst_get('BrainstormTmpDir');
% bstDir = bst_get('BrainstormHomeDir');
% % Check if mnc2nii is available
% if ispc
%     exe = ['"' bstDir '\external\mnc2nii\mnc2nii.exe" "' MriFile '" tmp.nii'];
% else
%     exe = ['mnc2nii "' MriFile '" tmp.nii'];
% end
% % Change folder because of some stupid bug of mnc2nii (crashes when there is a "." in the path of the output file)
% curdir = pwd;
% cd(bstTmp);
% % Execute mnc2nii
% [status, result] = system(exe);
% % Restore initial folder
% cd(curdir);
% % Exectution worked: convert MNC to NII
% if (status == 0)
%     % Import tmp.nii using standard NIfTI functions
%     MRI = in_mri_nii(bst_fullfile(bstTmp, 'tmp.nii'));
%     % Convert negative values to something
%     if any(MRI.Cube(:) < 0)
%         MRI.Cube = MRI.Cube - min(MRI.Cube(:));
%     end
% % Else: try to decode the MINC volume
% else
%     % Error message
%     bst_error(['Error: mnc2nii not found on your computer (or it crashed).', 10 ...
%                'Please install the MINC tools on your system and add the bin folder to your system path.'], 'Import MINC file', 0);
%     return
% end


        