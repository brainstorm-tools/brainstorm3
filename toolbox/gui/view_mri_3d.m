function [hFig, iDS, iFig] = view_mri_3d(MriFile, OverlayFile, SurfAlpha, hFig)
% VIEW_MRI_3D: Display a MRI in a 3DViz figure.
%
% USAGE:  [hFig, iDS, iFig] = view_mri_3d(MriFile, OverlayFile=[], SurfAlpha=[], 'NewFigure')
%         [hFig, iDS, iFig] = view_mri_3d(MriFile, OverlayFile=[], SurfAlpha=[], hFig)
%         [hFig, iDS, iFig] = view_mri_3d(MriFile, OverlayFile=[], SurfAlpha=[], iDS)
%
% INPUT:
%     - MriFile     : full path to the surface file to display 
%     - SurfAlpha   : value that indicates surface transparency (optional)
%     - "NewFigure" : force new figure creation (do not re-use a previously created figure)
%     - hFig        : Specify the figure in which to display the MRI
%     - iDS         : Specify which loaded dataset to use
%
% OUTPUT : 
%     - hFig : Matlab handle to the 3DViz figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array
% If an error occurs : all the returned variables are set to an empty matrix []

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
% Authors: Francois Tadel, 2008-2017

global GlobalData;

% ===== PARSE INPUTS =====
iDS  = [];
iFig = [];
NewFigure = 0;
% Get options
if (nargin < 4) || isempty(hFig)
    hFig = [];
elseif ischar(hFig) && strcmpi(hFig, 'NewFigure')
    hFig = [];
    NewFigure = 1;
elseif ishandle(hFig)
    [hFig,iFig,iDS] = bst_figures('GetFigure', hFig);
elseif (round(hFig) == hFig) && (hFig <= length(GlobalData.DataSet))
    iDS = hFig;
    hFig = [];
else
    error('Invalid figure handle.');
end
if (nargin < 3) || isempty(SurfAlpha)
    SurfAlpha = [];
end
if (nargin < 2) || isempty(OverlayFile)
    OverlayFile = [];
end

% ===== GET SUBJECT INFO =====
% Get Subject that holds this MRI
[sSubject, iSubject, iMri] = bst_get('MriFile', MriFile);
SubjectFile = sSubject.FileName;
% Create dataset
if isempty(iDS)
    % If this surface does not belong to any subject
    if isempty(sSubject)
        % Check that the MriFile really exist as an absolute file path
        if ~file_exist(MriFile)
            bst_error(['File not found : "', MriFile, '"'], 'Display surface');
            return
        end
        % Create an empty DataSet
        SubjectFile = '';
        iDS = bst_memory('GetDataSetEmpty');
    else
        % Get GlobalData DataSet associated with subjectfile (create if does not exist)
        iDS = bst_memory('GetDataSetSubject', SubjectFile, 1);
    end
    iDS = iDS(1);
end

% ===== LOAD OVERLAY FILE =====
if ~isempty(OverlayFile)
    % Get file type
    FileType = file_gettype(OverlayFile);
    isStat = any(strcmpi(FileType, {'pdata', 'presults', 'ptimefreq'}));
    % Load the overlay file
    switch lower(FileType)
        case {'cortex', 'innerskull', 'outerskull', 'scalp', 'tess'}
            OverlayType = 'Surface';
        case 'subjectimage'
            OverlayType = 'Anatomy';
        otherwise
            error('To do: See view_mri.m');
    end
end


% ===== CREATE NEW FIGURE =====
bst_progress('start', 'View surface', 'Loading MRI file...');
if isempty(hFig)
    % Prepare FigureId structure
    FigureId = db_template('FigureId');
    FigureId.Type     = '3DViz';
    FigureId.SubType  = '';
    FigureId.Modality = '';
    % Create figure
    if NewFigure
        [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate');
    else
        [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId);
    end
    % If figure was not created
    if isempty(hFig)
        bst_error('Could not create figure.', 'View MRI', 0);
        return;
    end
else
    isNewFig = 0;
end
% If there is already a volume displayed in this figure, create a new one
TessInfo = getappdata(hFig, 'Surface');
if ~isempty(TessInfo) && ismember('Anatomy', {TessInfo.Name})
    [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId, 'AlwaysCreate');
end
% Set application data
setappdata(hFig, 'SubjectFile',  SubjectFile);

% ===== DISPLAY MRI =====
% Add MRI to the figure
iSurf = panel_surface('AddSurface', hFig, MriFile);
if isempty(iSurf)
    return
end
% Set transparency
if ~isempty(SurfAlpha)
    panel_surface('SetSurfaceTransparency', hFig, iSurf, SurfAlpha);
end
% Add data on the MRI slices 
if ~isempty(OverlayFile)
    isOk = panel_surface('SetSurfaceData', hFig, iSurf, OverlayType, OverlayFile, isStat);
    if ~isOk
        close(hFig);
        return;
    end
end
% Update figure selection
bst_figures('SetCurrentFigure', hFig, '3D');
% Update Colormap
figure_3d('ColormapChangedCallback', iDS, iFig);
% Update figure name
bst_figures('UpdateFigureName', hFig);
% Camera basic orientation
if isNewFig
    figure_3d('SetStandardView', hFig, 'top');
end
% Set figure visible
set(hFig, 'Visible', 'on');
bst_progress('stop');
% Select surface tab
if isNewFig
    gui_brainstorm('SetSelectedTab', 'Surface');
end



