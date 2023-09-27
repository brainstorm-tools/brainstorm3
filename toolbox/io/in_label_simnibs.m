function Labels = in_label_simnibs(LabelsFile)
% IN_LABEL_SIMNIBS: Import list of anatomical labels from a SimNIBS _LUT.txt file
%
% FILE FORMAT: Text file with one header line, followed by one line per ROI, with random sequences of separators (tabs and spaces)
%    #No.	  Label Name:			   R   G   B   A
%    2	  Left-Cerebral-White-Matter       245 245 245 255 
%    3	  Left-Cerebral-Cortex     	   205 62 78 255 

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
% Authors: Francois Tadel, 2023

% Initialize returned variable
Labels = [];

% Open file
fid = fopen(LabelsFile, 'r');
if (fid < 0)
    error('CTF> Cannot open file.');
end
% Skip header line
fgetl(fid);
% Store everything in a cell array of string
txtCell = textscan(fid,'%d %s %d %d %d %d');
% Close file
fclose(fid);

% Copy ID, NAME, COLOR
Labels = cell(size(txtCell{1},1),3);
Labels(:,1) = num2cell(double(txtCell{1}));
Labels(:,2) = txtCell{2};
Labels(:,3) = num2cell(double([txtCell{3}, txtCell{4}, txtCell{5}]), 2);

