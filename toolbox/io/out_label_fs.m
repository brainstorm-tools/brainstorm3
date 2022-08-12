function out_label_fs(LabelFile, Comment, Vertices, Pos, Values)
% Writes FreeSurfer label file.
%
% INPUTS:
%    - LabelFile : Output file
%    - Comment   : Comment for the first line of the label file
%    - Vertices  : Vertex indices (0 based, column 1)
%    - Pos       : Locations in meters (columns 2 - 4 divided by 1000)
%    - Values    : Values at the vertices (column 5)
%
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

[fid, message] = fopen(LabelFile, 'w');
if (fid < 0)
    error('Cannot open file %s (%s)', LabelFile, message);
end

fprintf(fid,'# %s\n', Comment);
fprintf(fid, '%d\n', length(Vertices));
for k = 1:length(Vertices)
   fprintf(fid,'%d %.2f %.2f %.2f %f\n', Vertices(k), 1000*Pos(k,:), Values(k));
end

fclose(fid);

