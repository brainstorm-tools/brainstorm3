function Transf = in_transform_xfm(XfmFile)
% IN_TRANSFORM_XFM:  Read an MNI affine transformation matrix.

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
% Authors: Francois Tadel, 2015

% Initialize returned value
Transf = [];

% Open file
fid = fopen(XfmFile, 'r');
% Read the entire file
strFile = fread(fid, [1,Inf], '*char');
% Close file 
fclose(fid);

% Find the transformation
tag = 'Linear_Transform =';
iStart = strfind(lower(strFile), lower(tag));
% Tag not found
if isempty(iStart)
    return;
end

% Read the matrix
strMatrix = strFile(iStart + length(tag):end);
strMatrix(strMatrix == ';') = [];
% Convert to double values
XFM = str2num(strMatrix);
% If not enough values are available
if (size(XFM,1) < 3) || (size(XFM,2) < 4)
    return;
end

% Get rotation and translation
Transf.R = XFM(1:3,1:3);
Transf.T = XFM(1:3,4) ./ 1000;

    
    
    
    
