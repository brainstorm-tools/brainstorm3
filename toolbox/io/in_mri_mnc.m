function MRI = in_mri_mnc(MriFile)
% IN_MRI_MNC: Reads a structural MINC MRI (*.mnc).
%
% USAGE:  [MRI, hdr] = in_mri_mnc(MriFile);

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
% Authors: Francois Tadel, 2013; Martin Cousineau, 2017

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
    format_name = 'NetCDF';
else
    format_name = 'HDF5';
end

disp([10 'MINC> Reading ' upper(format) ' file (' format_name ').']);
[hdr,Cube] = minc_read(MriFile);
spaces = {'xspace', 'yspace', 'zspace'};

% Make sure dimensions are in the right order
iSpaces = zeros(1,3);
for i=1:3
    iSpaces(i) = find(strcmpi(hdr.info.dimension_order, spaces{i}));
end
Cube = permute(Cube, iSpaces);

% Flip volume if negative step
n = size(Cube);
for i=1:3
    [keys, step] = minc_variable_fixed(hdr, spaces{i}, 'step');
    if step < 0
        Cube = flip(Cube, i);
        hdr = setfield(hdr, keys{1:end}, {abs(step)});
        hdr.info.mat(i,i) = abs(step);
        hdr.info.mat(i,4) = (n(i) - 1) * step + hdr.info.mat(i,4);
    end
end

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

function [keys,val] = minc_variable_fixed(hdr,var_name,att_name)
% Fixed version of MOMINC's minc_variable supporting attribute names with
% prefixes. Also returns a list of keys to access val in hdr.

hdr = hdr.details;
list_var = {hdr.variables(:).name}; 
keys = {'details', 'variables'};

if nargin == 1
    val = list_var;
    keys{3} = {':'};
    keys{4} = {'name'};
    return
end

ind = find(ismember(list_var,var_name));
if isempty(ind)
    error('Could not find variable %s in HDR',var_name)
end

ind = ind(1);
varminc = hdr.variables(ind);
list_att = varminc.attributes;
keys{3} = {ind};

if nargin == 2
    val = list_att;
    keys{4} = 'attributes';
    return
end

% Find exact attribute name or at least a unique one with the name suffixed
if sum(ismember(list_att, att_name))
    ind2 = find(ismember(list_att, att_name));
elseif sum(~cellfun(@isempty, regexp(list_att, ['/' att_name '$']))) == 1
    ind2 = find(~cellfun(@isempty, regexp(list_att, ['/' att_name '$'])));
else
    error('Could not find attribute %s in variable %s',att_name,var_name)
end

val = varminc.values{ind2};
keys{4} = 'values';
keys{5} = {ind2};


