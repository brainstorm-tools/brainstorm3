function Labels = in_label_mricron(LabelsFile)
% IN_LABEL_MRICRON: Import list of anatomical labels from a .txt file as the
%                   atlases distributed as part of the MRIcron software.
%
% FILE FORMAT: TXT file with at least 2 space-separated columns:
%                  label_index and label_name. Example:
%    1 Precentral_L 2001
%    2 Precentral_R 2002
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
%
% Authors: Raymundo Cassani, 2022

% Initialize returned variable
Labels = [];

% Open file
fid = fopen(LabelsFile, 'r');
if (fid < 0)
    error('CTF> Cannot open file.');
end
% Store everything in a cell array of string
txtCell = textscan(fid,'%d %s %*[^\n]');
% Close file
fclose(fid);

% Copy ID and NAME
Labels = cell(size(txtCell{1},1),3);
Labels(:,1) = num2cell(double(txtCell{1}));
Labels(:,2) = txtCell{2};

% Default color table
ColorTable = round(panel_scout('GetScoutsColorTable') * 255);
% Default color table
Labels(:,3) = cellfun(@(c)ColorTable(c,:), num2cell(mod(0:size(Labels,1)-1, size(ColorTable,1)) + 1), 'UniformOutput', 0);

% Use label_name to match left/right colors
% Find names ending in _r, _R, _l or _L
ixs_rl = find(cell2mat(cellfun(@(x) ~isempty(regexpi(x, '_[rl]$')), Labels(:,2),'Un',0)));
% Names without hemisphere
clean_names = cellfun(@(x) x(1:end-2), Labels(ixs_rl, 2),'Un',0);
unique_clean_names = unique(clean_names);
for ix_clean = 1 : length(unique_clean_names)
    % Find symmetrical regions, and set same color
    ixs = ixs_rl(strcmp(clean_names, unique_clean_names(ix_clean)));
    if length(ixs) == 2
        Labels(ixs(2), 3) = Labels(ixs(1), 3);
    end
end
