function [hFig, iDS, iFig] = view_video(FileName, PlayerType, isNewFigure)
% VIEW_VIDEO Display a video, synchronized in time with the currently loaded file.
%
% USAGE: [hFig, iDS, iFig] = view_video(FileName, PlayerType='VideoReader', isNewFigure=0)
%
% OUTPUT : 
%     - hFig : Matlab handle to the figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

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
% Authors: Francois Tadel, 2015


%% ===== INITIALIZATION =====
global GlobalData;
% Parse inputs
if (nargin < 3) || isempty(isNewFigure) || (isNewFigure == 0)
    CreateMode = '';
else
    CreateMode = 'AlwaysCreate';
end
if (nargin < 2) || isempty(PlayerType)
    PlayerType = 'VideoReader';
end


%% ===== LOAD LINK ====
VideoStart = 0;
FileType = file_gettype(FileName);
switch (FileType)
    case 'videolink'
        FileMat = load(FileName);
        VideoFile = FileMat.LinkTo;
        if isfield(FileMat, 'VideoStart') && ~isempty(FileMat.VideoStart)
            VideoStart = FileMat.VideoStart;
        end
    case 'video'
        VideoFile = FileName;
    otherwise
        error('Invalid video file.');
end


%% ===== GET ALL ACCESSIBLE DATA =====
% Get study
[sStudy, iStudy, iFile, DataType] = bst_get('AnyFile', FileName);
if isempty(sStudy)
    error('File is not registered in database.');
end
StudyFile = sStudy.FileName;
% Get existing dataset
iDS = bst_memory('GetDataSetStudy', StudyFile);
% Create new dataset
if isempty(iDS)
    iDS = bst_memory('GetDataSetEmpty');
    GlobalData.DataSet(iDS).SubjectFile = file_short(sStudy.BrainStormSubject);
    GlobalData.DataSet(iDS).StudyFile   = file_short(sStudy.FileName);
end


%% ===== CREATE A NEW FIGURE =====
% Prepare FigureId structure
FigureId.Type     = 'Video';
FigureId.SubType  = '';
FigureId.Modality = '';
% Create TimeSeries figure
[hFig, iFig] = bst_figures('CreateFigure', iDS, FigureId, CreateMode, StudyFile);
if isempty(hFig)
    bst_error('Cannot create figure', 'Open video', 0);
    return;
end
% Configure figure
setappdata(hFig, 'FileName', FileName);


%% ===== LOAD VIDEO =====
bst_progress('start', 'Open video', 'Loading video...');
% Set the player to use for this figure
GlobalData.DataSet(iDS).Figure(iFig).Handles.PlayerType  = PlayerType;
GlobalData.DataSet(iDS).Figure(iFig).Handles.VideoStart = VideoStart;
% Load video
isOk = figure_video('LoadVideo', hFig, VideoFile);
% If the video was successfully loaded: show the figure
if isOk
    % Update figure title
    bst_figures('UpdateFigureName', hFig);
    % Set figure visible
    set(hFig, 'Visible', 'on');
% If there was an error: close the figure
else
    close(hFig);
end
bst_progress('stop');








