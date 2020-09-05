function [hFig, iDS, iFig] = view_channels(ChannelFile, Modality, isMarkers, isLabels, hFig, is3DElectrodes, selChannels)
% VIEW_CHANNELS: Display a channel file in all the associated 3DViz figure.
%
% USAGE: view_channels(ChannelFile, Modality, isMarker=1, isLabels=1, hFig=[], is3DElectrodes=0, selChannels=[])
%        view_channels(ChannelFile, Modality)
% OUTPUT: 
%     - hFig : Matlab handle to the 3DViz figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

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
% Authors: Francois Tadel, 2008-2019

global GlobalData;
% Parse inputs
if (nargin < 7) || isempty(selChannels)
    selChannels = [];
end
if (nargin < 6) || isempty(is3DElectrodes)
    is3DElectrodes = 0;
end
if (nargin < 5) || isempty(hFig)
    hFig = [];
end
if (nargin < 4) || isempty(isLabels) || isempty(isMarkers)
    isMarkers = 1;
    isLabels  = 1;
end
iDS  = [];
iFig = [];
% Get short path to this file
ChannelFile = file_short(ChannelFile);
    
% ===== GET/CREATE DATASET =====
if isempty(hFig)
    % Get Study that holds this ChannelFile
    sStudy = bst_get('ChannelFile', ChannelFile);
    % If this surface does not belong to any subject
    if isempty(sStudy)
        StudyFile = '';
        SubjectFile = '';
        %warning('This surface does not belong to any database subject.');
        % Check that the SurfaceFile really exist as an absolute file path
        if ~file_exist(ChannelFile)
            bst_error(['File not found : "', ChannelFile, '"'], 'Display surface');
            return
        end
    else
        StudyFile   = sStudy.FileName;
        SubjectFile = sStudy.BrainStormSubject;
        iDS = [];
        % Get GlobalData DataSet associated with channel file
        iDSChannel = bst_memory('GetDataSetChannel', ChannelFile);
        if ~isempty(iDSChannel) && ~isempty([GlobalData.DataSet(iDSChannel).Figure])
            iDS = iDSChannel;
        end
        iDSStudy   = [];
        iDSSubject = [];
        % ChannelFile not found in DataSets (or DataSet has no figure), try StudyFile
        if isempty(iDS)
            iDSStudy = bst_memory('GetDataSetStudy', StudyFile);
            if ~isempty(iDSStudy) && ~isempty([GlobalData.DataSet(iDSStudy).Figure])
                iDS = iDSStudy;
            end
        end
        % StudyFile not found in DataSets, try SubjectFile
        if isempty(iDS)
            iDSSubject = bst_memory('GetDataSetSubject', SubjectFile, 0);
            % Do not accept DataSet if an other ChannelFile is already attributed to the DataSet
            iDSSubject = iDSSubject(cellfun(@(c)isempty(c), {GlobalData.DataSet(iDSSubject).ChannelFile}));
            % Check if Datasets are acceptable
            if ~isempty(iDSSubject) && ~isempty([GlobalData.DataSet(iDSSubject).Figure])
                iDS = iDSSubject(1);
            end
        end
        % If no dataset with figure was selected, get the first dataset without figures
        if isempty(iDS)
            iDS = [iDSChannel iDSStudy iDSSubject];
            if ~isempty(iDS)
                iDS = iDS(1);
            end
        end
    end
    % If no existing dataset is found : create a new one
    if isempty(iDS)
       iDS = bst_memory('GetDataSetEmpty');
    end
    iDS = iDS(1);
    GlobalData.DataSet(iDS).SubjectFile = SubjectFile;
    GlobalData.DataSet(iDS).StudyFile   = StudyFile;
   
% ===== RE-USE EXISTING FIGURE =====
else
    % Get figure definition
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
end

% ===== LOAD CHANNEL FILE IF NOT DONE =====
% Also check if we are processing the same channel file, which can be
% different when doing real-time head position alignment (2 helmets from
% different datasets in the same figure).
if isempty(GlobalData.DataSet(iDS).ChannelFile) || ~strcmpi(GlobalData.DataSet(iDS).ChannelFile, ChannelFile) || ...
   (~GlobalData.DataSet(iDS).isChannelModified && isempty(GlobalData.DataSet(iDS).Channel))
    % Check if this channel file is already loaded and modified in another DataSet
    iDSother = setdiff(1:length(GlobalData.DataSet), iDS);
    if ~isempty(iDSother) && any([GlobalData.DataSet(iDSother).isChannelModified])
        % Ask user
        isSave = java_dialog('confirm', ...
            ['This channel file is being edited in another window.' 10 ...
             'Save the modifications so the new figure can show updated positions?'], 'Save modifications');
        % Force saving of the modifications
        if isSave
            bst_memory('SaveChannelFile', iDSother(1));
        end
    end
    % Load channel file
    ChannelMat = in_bst_channel(ChannelFile);
    % Copy information in memory
    GlobalData.DataSet(iDS).ChannelFile     = ChannelFile;
    GlobalData.DataSet(iDS).Channel         = ChannelMat.Channel;
    GlobalData.DataSet(iDS).MegRefCoef      = ChannelMat.MegRefCoef;
    GlobalData.DataSet(iDS).Projector       = ChannelMat.Projector;
    GlobalData.DataSet(iDS).IntraElectrodes = ChannelMat.IntraElectrodes;
    GlobalData.DataSet(iDS).HeadPoints      = ChannelMat.HeadPoints;
end

% ===== CREATE 3DVIZ FIGURE =====
% Progress bar
isProgress = ~bst_progress('isVisible');
if isProgress
    bst_progress('start', 'View sensors', 'Loading data...');
end
if isempty(hFig)
    % Prepare FigureId structure
    FigureId = db_template('FigureId');
    FigureId.Type     = '3DViz';
    FigureId.SubType  = '';
    FigureId.Modality = Modality;
    % Create figure
    [hFig, iFig, isNewFig] = bst_figures('CreateFigure', iDS, FigureId);
    % If figure was not created: Display an error message and return
    if isempty(hFig)
        bst_error('Cannot create figure', '3D figure creation...', 0);
        return;
    end
    setappdata(hFig, 'StudyFile',    StudyFile);
    setappdata(hFig, 'SubjectFile',  SubjectFile);
else
    isNewFig = 0;
    % Get existing list of selected channels
    if ~isempty(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels)
        selChannels = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    end
end
% Make sure that the Modality is saved
GlobalData.DataSet(iDS).Figure(iFig).Id.Modality = Modality;
% Set application data
setappdata(hFig, 'DataFile', '');
setappdata(hFig, 'isSensorsOnly', 1);

% ===== DISPLAY SENSORS =====
% Update figure selection
bst_figures('SetCurrentFigure', hFig, '3D');
% Get default selected channels for this modality
if isempty(selChannels)
    % Get selected channels
    selChannels = good_channel(GlobalData.DataSet(iDS).Channel, [], Modality);
    % Remove the channels with empty positions
    iNoLoc = find(cellfun(@isempty, {GlobalData.DataSet(iDS).Channel.Loc}));
    if ~isempty(iNoLoc)
        selChannels = setdiff(selChannels, iNoLoc);
    end
    if isempty(selChannels) && ~isempty(iNoLoc)
        error('None of the channels have positions defined.');
    end
end
% Set figure selected sensors
GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = selChannels;
% Display sensors
if is3DElectrodes
    figure_3d('PlotSensors3D', iDS, iFig);
    if isLabels
        figure_3d('ViewSensors', hFig, 1, 1, 0, Modality);
    end
elseif ismember(lower(Modality), {'ctf', 'vectorview306', '4d', 'kit', 'kriss', 'babymeg', 'ricoh'})
    figure_3d('PlotCoils', hFig, Modality, isMarkers);
elseif ismember(lower(Modality), {'nirs','nirs-brs'})
    figure_3d('PlotNirsCap', hFig, isMarkers);
else
    isMesh = ~isequal(Modality, 'SEEG');
    figure_3d('ViewSensors', hFig, isMarkers, isLabels, isMesh, Modality);
end
% Update lights
camlight(findobj(hFig, 'Tag', 'FrontLight'), 'headlight');
% Update figure name
bst_figures('UpdateFigureName', hFig);
% Camera basic orientation
if isNewFig
    figure_3d('SetStandardView', hFig, 'top');
end
% Show figure
set(hFig, 'Visible', 'on');
% Close progress bar
if isProgress
    bst_progress('stop');
end



