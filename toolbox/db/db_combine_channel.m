function [isNewFile, Message] = db_combine_channel( iSrcStudies, iDestStudy, UserConfirm, NoWarning )
% DB_COMBINE_CHANNEL: Create a channel file for a study that do not have one yet. 
%
% USAGE:  db_combine_channel( iSrcStudies, iDestStudy, UserConfirm, NoWarning )
%         db_combine_channel( iSrcStudies, iDestStudy, UserConfirm )
%         db_combine_channel( iSrcStudies, iDestStudy )
%
% INPUT:
%     - iSrcStudies : Indices of the study that are used to create the new channel file
%     - iDestStudy  : Indice of the study that needs a new channel file
%     - UserConfirm : If 1, ask user confirmation, 
%                     if 0, create new channel file automatically
%     - NoWarning   : If 1, does not display any warning/error
%
% OUPUT:
%     - isNewFile   : 1 if a new channel file was created in destination study
%                     0 else
% 
% DESCRIPTION: 
%     - Create a channel coherent with other input studies.
%     - Do not replace any previous channel file.
%     - If more than one source channel file, the channels locations are averaged.

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
% Authors: Francois Tadel, 2009-2012


%% ===== PARSE INPUTS =====
isNewFile = 0;
Message = [];
% Parse inputs
if (nargin < 4) || isempty(NoWarning)
    NoWarning = 0;
end
if (nargin < 3) || isempty(UserConfirm)
    UserConfirm = 1;
end
if (length(iDestStudy) > 1)
    error('Destination study must be unique.');    
end
if isempty(iDestStudy) || isequal(iSrcStudies, iDestStudy)
    return
end
% Get protocol directories
ProtocolInfo = bst_get('ProtocolInfo');
ChannelMats = {};

%% ===== LOAD CHANNEL FILES =====
for i = 1:length(iSrcStudies)
    % Get study structure
    iStudy = iSrcStudies(i);
    sStudy = bst_get('Study', iStudy);
    % If study is an analysis node (@INTRA), or no channel file in this study: ignore it
    if isempty(sStudy.Channel) % || strcmpi(sStudy.Name, bst_get('DirAnalysisIntra'))
        continue;
    end
    % Get channel file
    ChannelFile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.Channel.FileName);
    % Load channel file
    ChannelMats{end + 1} = in_bst_channel(ChannelFile);
end

% If no valid source channel files
if isempty(ChannelMats)
    return
end
    
%% ===== COMPUTE CHANNEL MEAN =====
[MeanChannelMat, Message] = channel_average(ChannelMats);
% An error occurred 
if isempty(MeanChannelMat) 
    if ~NoWarning
        bst_error(Message, 'Combine channel files', 0);
    end
    return;
end


%% ===== CHECK DESTINATION STUDY =====
sDestStudy = bst_get('Study', iDestStudy);
% If there is already channel, check if it is different from the initial one
if ~isempty(sDestStudy.Channel)
    % Channel file already exist: load previous channel file
    oldChannelMat = in_bst_channel(sDestStudy.Channel.FileName);
    % Get all locations and all orientations
    allLocOld  = [oldChannelMat.Channel.Loc];
    allLocMean = [MeanChannelMat.Channel.Loc];
    allOrientOld  = [oldChannelMat.Channel.Orient];
    allOrientMean = [MeanChannelMat.Channel.Orient];
    % Check for empty arrays
    if isempty(allLocOld)
        allLocOld = [0;0;0];
    end
    if isempty(allLocMean)
        allLocMean = [0;0;0];
    end
    if isempty(allOrientOld)
        allOrientOld = [0;0;0];
    end
    if isempty(allOrientMean)
        allOrientMean = [0;0;0];
    end
    % If new averaged channel file is the same than the prvious one: exit
    if isequal({oldChannelMat.Channel.Type}, {MeanChannelMat.Channel.Type}) && ...
       isequal({oldChannelMat.Channel.Name}, {MeanChannelMat.Channel.Name}) && ...
       (numel(allLocOld) == numel(allLocMean)) && (max(abs(allLocOld(:) - allLocMean(:))) < .001) && ...
       (numel(allOrientOld) == numel(allOrientMean)) && (max(abs(allOrientOld(:) - allOrientMean(:))) < .001) && ...
       isequal(oldChannelMat.Projector, MeanChannelMat.Projector)
        return
    end
end

%% ===== SAVE NEW CHANNEL FILE =====
if UserConfirm
    ChannelReplace = 1;  % Ask user confirmation
else
    ChannelReplace = 2;  % Do not ask user confirmation
end
ChannelAlign = 0;
% Set the new channel file
ChannelFile = db_set_channel(iDestStudy, MeanChannelMat, ChannelReplace, ChannelAlign);
isNewFile = ~isempty(ChannelFile);


