function Labels = in_label_itksnap(LabelsFile)
% IN_LABEL_ITKSNAP: Import list of anatomical labels from a ITK-SnAP Label Description File
%
% FILE FORMAT: Text file with 0 or more header lines (empty or start with #),
%              followed by one line per ROI, with random sequences of separators (tabs and spaces)
%
% Entry format:
%   IDX   -R-  -G-  -B-  -A-  VIS MSH  LABEL
%
% Fields:
%    IDX:   Zero-based index
%    -R-:   Red color component   (0..255)
%    -G-:   Green color component (0..255)
%    -B-:   Blue color component  (0..255)
%    -A-:   Label transparency    (0.00 .. 1.00)
%    VIS:   Label visibility      (0 or 1)
%    IDX:   Label mesh visibility (0 or 1)
%  LABEL:   Label description     Double-quouted string "label description"
%
%  IDX   -R-  -G-  -B-  -A-  VIS MSH  LABEL
%   1   255   52   39    1    1   0   "corticofugal tract and corona radiata"
%   3     0    0  255    1    1   0   "Subthalamic nucleus"

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
% Authors: Raymundo Cassani, 2026

% Initialize returned variable
Labels = [];

% Open file
fid = fopen(LabelsFile, 'r');
if (fid < 0)
    error('BST> Cannot open file.');
end
% Get location in file
pos = ftell(fid);
% Skip header lines
line_hdr = strtrim(fgetl(fid));
while isempty(line_hdr) || (ischar(line_hdr) && strcmp(line_hdr(1), '#'))
    % Update position
    pos = ftell(fid);
    line_hdr = strtrim(fgetl(fid));
end
% Return location in file just before first non-header line
fseek(fid, pos, 'bof');

% Store everything in a cell array of string
txtCell = textscan(fid,'%d %d %d %d %f %d %d %q');
% Close file
fclose(fid);

% Copy ID, NAME, COLOR
Labels = cell(size(txtCell{1},1),3);
Labels(:,1) = num2cell(double(txtCell{1}));
Labels(:,2) = txtCell{8};
Labels(:,3) = num2cell(double([txtCell{2}, txtCell{3}, txtCell{4}]), 2);

