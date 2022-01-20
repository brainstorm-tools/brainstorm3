function tree_view_scouts( bstNodes )
% TREE_VIEW_SCOUTS: Display scouts for all the results depending on the input tree nodes.
%
% USAGE: tree_view_scouts( bstNodes )
%        tree_view_scouts( )          : Use selected nodes in the tree

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
% Authors: Francois Tadel, 2008-2014

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

% Get all the Data files that are classified in the input nodes
[iStudies, iResults] = tree_dependencies(bstNodes, 'results');
iStudies_stat = []; 
iResults_stat = [];
iStudies_tf   = [];
iResults_tf   = [];
if ~isempty(iStudies)
    [iStudies_stat, iResults_stat] = tree_dependencies(bstNodes, 'presults');
    if ~isempty(iStudies_stat)
        [iStudies_tf, iResults_tf] = tree_dependencies(bstNodes, 'timefreq');
    end
end
% Errors
if isequal(iStudies, -10) || isequal(iStudies_stat, -10) || isequal(iStudies_tf, -10)
    java_dialog('warning', 'Error in file selection.', 'Display scouts');
    return;
end
% If no results found in selected nodes
if isempty(iResults) && isempty(iResults_stat) && isempty(iResults_tf)
    java_dialog('warning', 'No source results to display.', 'Display scouts');
    return
% Cannot mix different types of files
elseif ~isempty(iResults_tf) && (~isempty(iResults) || ~isempty(iResults_stat))
    java_dialog('warning', 'Cannot mix input from different file types.', 'Display scouts');
    return
end

% Get results filenames
ResultsFiles = {};
for i = 1:length(iResults)
    sStudy = bst_get('Study', iStudies(i));
    ResultsFiles{end+1} = sStudy.Result(iResults(i)).FileName;
end
for i = 1:length(iResults_stat)
    sStudy = bst_get('Study', iStudies_stat(i));
    ResultsFiles{end+1} = sStudy.Stat(iResults_stat(i)).FileName;
end
for i = 1:length(iResults_tf)
    sStudy = bst_get('Study', iStudies_tf(i));
    ResultsFiles{end+1} = sStudy.Timefreq(iResults_tf(i)).FileName;
end

% Check TF files
if ~isempty(iResults_tf)
    % Find PAC files
    isPac = ~cellfun(@(c)isempty(strfind(c,'_pac_fullmaps')), ResultsFiles) || ~cellfun(@(c)isempty(strfind(c,'_dpac_fullmaps')), ResultsFiles);
    if any(isPac) && ~all(isPac)
        java_dialog('warning', 'Cannot mix input from different file types.', 'Display scouts');
        return;
    elseif ~any(isPac)
%         java_dialog('warning', ['No source results to display.' 10 10, ...
%                                 'To display the spectrum or time-frequency decomposition of a scout,' 10 ...
%                                 'please use the Process1 tab to calculate it directly from the source file.'], 'Display scouts');
%         return;
    end
else
    isPac = [];
end


% If no scouts are available: load surface
sScouts = panel_scout('GetScouts');
if isempty(sScouts)
    % Get surface filename
    ResultsMat = in_bst_results(ResultsFiles{1}, 0, 'SurfaceFile');
    if isempty(ResultsMat.SurfaceFile)
        error('Cannot display scouts for volume-based sources.');
    end
    % Force loading of the surface in the interface
    sSurf = bst_memory('LoadSurface', ResultsMat.SurfaceFile);
    % Set the surface as the current surface
    panel_scout('SetCurrentSurface', sSurf.FileName);
    % If still no scouts are available: error
    sScouts = panel_scout('GetScouts');
    if isempty(sScouts)
        bst_memory('UnloadSurface', sSurf.FileName);
        bst_error('No scouts defined in the current atlas.');
    end
    % Select all the scouts
    TargetScouts = 1:length(sScouts);
else
    TargetScouts = 'SelectedScouts';
end
    
% ===== DISPLAY SELECTED SCOUTS =====
% Average of directPAC maps
if ~isempty(isPac) && all(isPac)
    % Get selected scouts
    if isequal(TargetScouts, 'SelectedScouts')
        sPacScouts = panel_scout('GetSelectedScouts');
    else
        sPacScouts = TargetScouts;
    end
    % No selected scouts
    if isempty(sScouts)
        return;
    end
    % List all vertices
    AllVertices = unique([sScouts.Vertices]);
    % Open one window per file in input
    for iFile = 1:length(ResultsFiles)
        view_pac(ResultsFiles{iFile}, AllVertices);
    end
% Regular time-series scouts
else
    view_scouts(ResultsFiles, TargetScouts);
end









