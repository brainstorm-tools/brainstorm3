function hFig = view_gridloc(HeadModelFile, GridType, AnatOverlay)
% VIEW_GRIDLOC: Show the source grid points in 'mixed' and 'volume' head models
%
% USAGE:  hFig = view_gridloc(HeadModelFile, GridType='V')               % Display grid on the cortex surface used by the head model
%         hFig = view_gridloc(HeadModelFile, GridType='V', 'MRI')        % Display grid on subject's default MRI
%         hFig = view_gridloc(HeadModelFile, GridType='V', SurfaceFile)  % Display grid on a specific surface

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
% Authors: Francois Tadel, 2014-2020

% Parse inputs
if (nargin < 3) || isempty(AnatOverlay)
    AnatOverlay = [];
end
if (nargin < 2) || isempty(GridType)
    GridType = 'V';
end


%% ===== LOAD DATA =====
% Load head model
HeadModelMat = in_bst_headmodel(HeadModelFile, 0, 'GridLoc', 'GridOrient', 'GridAtlas', 'SurfaceFile', 'HeadModelType');
% Get subject
sSubject = bst_get('SurfaceFile', HeadModelMat.SurfaceFile);
if isempty(sSubject.iScalp)
    error('No scalp surface available');
end
if isempty(sSubject.iAnatomy)
    error('No MRI volume available');
end


%% ===== DISPLAY SURFACES =====
% Display only selected scouts
panel_scout('SetScoutShowSelection', 'select');
% Display cortex surface used in the head model
if isempty(AnatOverlay)
    hFig = view_surface(HeadModelMat.SurfaceFile, 0.95, [], 'NewFigure');
% Display subject's default MRI 
elseif strcmpi(AnatOverlay, 'MRI')
    hFig = view_mri_3d(sSubject.Anatomy(sSubject.iAnatomy).FileName, HeadModelFile, 0, 'NewFigure');
    panel_scout('SetDefaultOptions');
    panel_scout('PlotScouts', [], hFig);
    panel_scout('UpdateScoutsDisplay', hFig);
% Display user-defined surface
elseif ~isempty(file_fullpath(AnatOverlay))
    hFig = view_surface(AnatOverlay, 0.95, [], 'NewFigure');
end
% Set orientation: left
figure_3d('SetStandardView', hFig, 'left');
% Update figure name
set(hFig, 'Name', ['Check source grid: ' HeadModelFile]);
% Get axes handles
hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');


%% ===== DISPLAY GRID POINTS =====
switch (HeadModelMat.HeadModelType)
    case 'volume'
        % Plot points
        line(HeadModelMat.GridLoc(:,1), HeadModelMat.GridLoc(:,2), HeadModelMat.GridLoc(:,3), ...
             'LineStyle',   'none', ...
             'Color',       [0 1 0], ...
             'MarkerSize',  2, ...
             'Marker',      '.', ...
             'Tag',         'ptCheckGrid', ...
             'Parent',      hAxes);
    case 'mixed'
        % Get grid atlas
        sScouts = HeadModelMat.GridAtlas.Scouts;
        if isempty(HeadModelMat.GridAtlas) || isempty(HeadModelMat.GridAtlas.Scouts)
            error('No source model atlas in the headmodel file.');
        end
        % Loop on all the regions
        for i = 1:length(sScouts)
            % Skip regions that are not "volume"
            if ~strcmpi(sScouts(i).Region(2), GridType) || (strcmpi(GridType,'S') && ~isempty(strfind(sScouts(i).Label, 'Cortex')))
                continue;
            end
            % Get location
            GridLoc = HeadModelMat.GridLoc(sScouts(i).GridRows,:);
            % Plot points
            if strcmpi(GridType, 'V')
                line(GridLoc(:,1), GridLoc(:,2), GridLoc(:,3), ...
                     'LineStyle',       'none', ...
                     'Color',            sScouts(i).Color, ...
                     'MarkerFaceColor',  sScouts(i).Color, ...
                     'MarkerSize',       1, ...
                     'Marker',           'o', ...
                     'Tag',              'ptCheckGrid', ...
                     'Parent',           hAxes);
            else
                line(GridLoc(:,1), GridLoc(:,2), GridLoc(:,3), ...
                     'LineStyle',       'none', ...
                     'Color',            sScouts(i).Color, ...
                     'MarkerFaceColor',  sScouts(i).Color, ...
                     'MarkerSize',       2, ...
                     'Marker',           'o', ...
                     'Tag',              'ptCheckGrid', ...
                     'Parent',           hAxes);
            end
        end
    otherwise
        error('No custom source grids in this headmodel.');
end 
    



