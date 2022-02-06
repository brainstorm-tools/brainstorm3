function tree_view_clusters( bstNodes )
% TREE_VIEW_CLUSTERS: Display clusters for all the results depending on the input tree nodes.
%
% USAGE: tree_view_clusters( bstNodes )
%        tree_view_clusters( )          : Use selected nodes in the tree

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
% Authors: Francois Tadel, 2009-2014

% If no nodes is provided in argument
if (nargin == 0) || isempty(bstNodes)
    % Get tree handle
    ctrl = bst_get('PanelControls', 'protocols');
    if isempty(ctrl) || isempty(ctrl.jTreeProtocols)
        return;
    end
    % Get nodes selected in tree
    selectedPaths = ctrl.jTreeProtocols.getSelectionPaths();
    bstNodes = [];
    for iPath = 1:length(selectedPaths)
        bstNodes = [bstNodes selectedPaths(iPath).getLastPathComponent()];
    end
end
% If no node selcted : return
if isempty(bstNodes)
    return
end

DataFiles = {};
% Get all the Data files that are classified in the input nodes
[iStudies, iDatas] = tree_dependencies(bstNodes, 'data');
if isequal(iStudies, -10)
    disp('BST> Error in tree_dependencies.');
    return;
end
% Get data filenames
if ~isempty(iDatas)
    DataFiles = cell(1, length(iDatas));
    for i = 1:length(iDatas)
        sStudy = bst_get('Study', iStudies(i));
        DataFiles{i} = sStudy.Data(iDatas(i)).FileName;
    end
end

% Get all the Stat files that are classified in the input nodes
[iStudies, iStat] = tree_dependencies(bstNodes, 'pdata');
if isequal(iStudies, -10)
    disp('BST> Error in tree_dependencies.');
    return;
end
% Get data filenames
if ~isempty(iStat)
    DataFiles = cell(1, length(iStat));
    for i = 1:length(iStat)
        sStudy = bst_get('Study', iStudies(i));
        DataFiles{i} = sStudy.Stat(iStat(i)).FileName;
    end
end
% If no results found in selected nodes
if isempty(DataFiles)
    java_dialog('warning', 'No data file to display.', 'Display clusters');
    return
end

% ===== DISPLAY SELECTED SCOUTS =====
view_clusters(DataFiles);









