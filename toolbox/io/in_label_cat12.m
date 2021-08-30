function Labels = in_label_cat12(LabelsFile)
% IN_LABEL_CAT12: Import list of anatomical labels from a CAT12 .csv file
%
% FILE FORMAT: CSV file with at least 2 columns ROIid and ROIname. Example:
%    ROIid;ROIabbr;ROIname;ROIcolor
%    1;lPreCG;Left Precentral gyrus;203 142 203
%    2;rPreCG;Right Precentral gyrus;203 142 203  

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
% Authors: Francois Tadel, 2021

% Initialize returned variable
Labels = [];

% Read CSV file with columns: ROIid;ROIabbr;ROIname;ROIcolor
CatCsv = in_tsv(LabelsFile, {'ROIid','ROIabbr','ROIname','ROIcolor'}, 0, ';');
if any(cellfun(@isempty, reshape(CatCsv(:,[1,3]), [], 1)))
    disp('BST> Error: Missing columns is CSV file: ROIid or ROIname.');
end

% Copy ID and NAME
Labels = cell(size(CatCsv,1),3);
Labels(:,1) = cellfun(@str2double, CatCsv(:,1), 'UniformOutput', 0);
Labels(:,2) = CatCsv(:,3);

% Default color table
ColorTable = round(panel_scout('GetScoutsColorTable') * 255);

% ROIcolor: If there is a column ROIcolor: copy it
if ~any(cellfun(@isempty, CatCsv(:,4)))
    Labels(:,3) = cellfun(@str2num,  CatCsv(:,4), 'UniformOutput', 0);
% ROIabbr: If there is a column ROIabbr, use it to match left/right colors
elseif ~any(cellfun(@isempty, CatCsv(:,2)))
    iColor = 0;
    % Add color to each label
    for iLabel = 1:size(CatCsv,1)
        % Find previous color for the symmetrical region
        if (iLabel > 1) && (CatCsv{iLabel,2}(1) == 'r')
            iRow = find(strcmpi(CatCsv(1:iLabel-1,2), ['l', CatCsv{iLabel,2}(2:end)]));
        elseif (iLabel > 1) && (CatCsv{iLabel,2}(1) == 'l')
            iRow = find(strcmpi(CatCsv(1:iLabel-1,2), ['r', CatCsv{iLabel,2}(2:end)]));
        else
            iRow = [];
        end
        % If previous region found: use its color
        if ~isempty(iRow)
            Labels{iLabel,3} = Labels{iRow,3};
        % Otherwise: use a new color
        else
            iColor = iColor + 1;
            Labels{iLabel,3} = ColorTable(mod(iColor, size(ColorTable,1)) + 1, :);
        end
    end
% Otherwise, use random colors
else
    Labels(:,3) = cellfun(@(c)ColorTable(c,:), num2cell(mod(0:size(CatCsv,1)-1, size(ColorTable,1)) + 1), 'UniformOutput', 0);
end


