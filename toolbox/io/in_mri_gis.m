function MRI = in_mri_gis(MriFile,ByteOrder)
% IN_MRI_GIS: Read GIS (.ima) MRI, from BrainVisa.
%
% USAGE:  in_mri_gis(MriFile)
%
% INPUT:
%     - MriFile : full path to a MRI file
%     - ByteOrder : {'l' for little endian, or 'b' for big endian}
%                   Default : native (current machine)
%
% OUTPUT: 
%     - MRI     : Standard brainstorm structure for MRI volumes
%
% SEE ALSO: in_mri

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
% Authors: Francois Tadel, 2008

% ===== CHECK INPUT FILES =====
if (length(MriFile) < 5)
    error('Not a valid filename : "%s".', MriFile);
end
MriFile_ima = strrep(MriFile, '.dim', '.ima');
MriFile_dim = strrep(MriFile, '.ima', '.dim');
% Check the existence of .ima file
if ~file_exist(MriFile_ima)
    error('Data file does not exist : "%s".', MriFile_ima);
end
% Check .dim file
if ~file_exist(MriFile_dim)
    error('Header file does not exist : "%s".', MriFile_dim);
end

% ===== READ HEADER FILE (.dim) =====
% Open file
fid =  fopen(MriFile_dim, 'r');
if (fid < 0)
    error(['Cannot open file: ' MriFile_dim]);
end
% Get first line
dim = fscanf(fid, '%d %d %d %d')';
% Read all the file
opt = fread(fid, [1 Inf], '*char');
% Close file
fclose(fid);
% Read tags
dx = str2double(get_option(opt, '-dx'));
dy = str2double(get_option(opt, '-dy'));
dz = str2double(get_option(opt, '-dz'));
bo = get_option(opt, '-bo');
datatype = get_option(opt, '-type');
% Interpret tags
switch bo
    case 'ABCD',  ByteOrder = 'b';
    case 'DCBA',  ByteOrder = 'l';
end
MRI.Voxsize = [dx dy dz];
DataClass = lower(strrep(datatype,'S','int'));


% ===== READ DATA FILE (.ima) =====
% Open .ima file 
file = fopen(MriFile_ima, 'rb', ByteOrder);
if (file < 0)
    error(['Cannot open file: ' MriFile]);
end
% Read the whole volume / store in a huge vector   
MRI.Cube = fread(file, prod(dim(1:3)), ['*' DataClass]);
fclose(file);
% Reshape it into a 3-D array.
MRI.Cube = reshape(MRI.Cube, dim(1:3)); 
% Equivalent
MRI.Cube = MRI.Cube(end:-1:1, end:-1:1, end:-1:1);
end


%% ===== READ OPTION IN STRING ======
function value = get_option(s, tag)
    value = '';
    % Find tag in string
    iTag = strfind(s, tag);
    if isempty(iTag)
        return
    end
    % Get string that follows it
    iVal = iTag + length(tag) + 1;
    value = sscanf(s(iVal:end), '%s', 1);
end



