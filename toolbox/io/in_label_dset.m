function sScouts = in_label_dset(LabelFile)
% IN_LABEL_DSET: Import an atlas from a AFNI/SUMA sparse ROI file.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014

% Open file
fid = fopen(LabelFile, 'r');
if (fid<0) 
    error('Unable to open file.');
end
% Read the whole file
labels = textscan(fid, '%d %d', 'CommentStyle', '#');
if (length(labels) ~= 2)
    error('Invalid .dset file.');
end
% Close file
fclose(fid);

% Convert the vertex indices from 0-base to 1-base
labels{1} = labels{1} + 1;
% Get a unique list of labels
uniqueLabels = unique(labels{2});
% Initialize returned scout list
sScouts = repmat(db_template('scout'), 1, length(uniqueLabels));
% Create one scout per label
for i = 1:length(uniqueLabels)
    sScouts(i).Vertices = double(labels{1}(labels{2} == uniqueLabels(i))');
    sScouts(i).Seed  = [];
    sScouts(i).Color = [];
    sScouts(i).Label = num2str(uniqueLabels(i));
end




