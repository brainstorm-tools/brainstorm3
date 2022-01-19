function mat = in_duneuro_bin(inFile)
% IN_DUNEURO_BIN Read matrix from a DUNEuro binary file

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
% Authors: Juan Garcia-Prieto, Takfarinas Medani, 2019
%          Francois Tadel, 2020

% Open file
[fid, message] = fopen(inFile);
if (fid < 0)
    error(['Could not open file: ' message]);
end

% Read header
dims = fscanf(fid, '::%d::%d::');
if (length(dims) ~= 2)
    error('Invalid DUNEuro binary file: missing header "::nrows::ncols::".');
end

% Read binary matrix
mat = fread(fid, [dims(2), dims(1)], 'double')';

% Close file
fclose(fid);



