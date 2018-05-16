function [OutputFile, ChannelMat, ChannelReplace, ChannelAlign, Modality] = db_set_channel( iStudy, ChannelMat, ChannelReplace, ChannelAlign )
% DB_SET_CHANNEL: Define a channel file for a given study.
%
% USAGE:  db_set_channel( iStudy, ChannelMat,  ChannelReplace=1, ChannelAlign=1 )
%         db_set_channel( iStudy, ChannelMat ) 
%         db_set_channel( iStudy, ChannelFile, ... )
%
% INPUT:
%    - iStudy         : Indice of study to update
%    - ChannelMat     : Contents of channel file (optional)
%                       If not defined or []: Copy file pointed by sChannelDb
%    - ChannelFile    : Relative path to channel file
%    - ChannelReplace : 0, do not replace if channel file already exist
%                       1, replace old channel file after user confirmation
%                       2, replace old channel file without user confirmation
%    - ChannelAlign   : 0, do not perform automatic headpoints-based alignment
%                       1, perform automatic alignment after user confirmation
%                       2, perform automatic alignment without user confirmation
% OUTPUT:
%    - OutputFile: Newly created channel file (empty is no file created)

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
% Authors: Francois Tadel, 2009-2013

%% ===== PARSE INPUTS =====
% Check inputs
if (nargin < 4) || isempty(ChannelAlign)
    ChannelAlign = 1;
end
if (nargin < 3) || isempty(ChannelReplace)
    ChannelReplace = 1;
end
if (nargin < 2) 
    error('Invalid call.');
end
Modality = [];
% Call with multiple studies: recursive call
if (length(iStudy) > 1)
    OutputFile = {};
    for i = 1:length(iStudy)
        [OutputFile{end+1}, tmp, ChannelReplace, ChannelAlign] = db_set_channel(iStudy(i), ChannelMat, ChannelReplace, ChannelAlign);
    end
    return;
end

% Channel: Existing file
if ischar(ChannelMat)
    % Load existing file
    ChannelFile = ChannelMat;
    ChannelMat = in_bst_channel(ChannelFile);
    % Output filename: same as input
    [fPath, fBase, fExt] = bst_fileparts(ChannelFile);
    OutputFile = [fBase, fExt];
% Channel: Structure
elseif isstruct(ChannelMat)
    % Detect device type
    DeviceTag = channel_detect_device(ChannelMat);
    % Output filename: channel_devicetag.mat
    OutputFile = ['channel', DeviceTag, '.mat'];
end


%% ===== OVERWRITE CHANNEL FILE =====
% Get study structure
sStudy = bst_get('Study', iStudy);
% If channel already defined, check if need to update
if ~isempty(sStudy.Channel)
    % Old channel file
    oldChannelFile = file_fullpath(sStudy.Channel.FileName);
    % No need to replace (no overwrite, or previous version equals new one)
    if (ChannelReplace == 0)
        OutputFile = [];
        return
    % Replace only with user confirmation
    elseif (ChannelReplace == 1)
        % Ask user confirmation
        res = java_dialog('confirm', ['Warning: a channel file is already defined for this study,' 10 ...
                               '"' sStudy.Channel.FileName '".' 10 10 ...
                               'Delete previous channel file ?' 10], 'Replace channel file');
        % If user did not accept : return
        if ~res
            OutputFile = [];
            return
        end
        ChannelReplace = 2;
        % Delete previous channel file
        file_delete(oldChannelFile, 1);
    end
end


%% ===== COMMENT FIELD =====
% Add comment field if it does not exist
if ~isfield(ChannelMat, 'Comment') || isempty(ChannelMat.Comment)
    ChannelMat.Comment = 'Channels';
end
% Add number of channels to the comment
ChannelMat.Comment = str_remove_parenth(ChannelMat.Comment, '(');
ChannelMat.Comment = [ChannelMat.Comment, sprintf(' (%d)', length(ChannelMat.Channel))];


%% ===== SAVE FILE =====
% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
% Output filename
OutputFile = bst_fullfile(bst_fileparts(sStudy.FileName), OutputFile);
OutputFileFull = bst_fullfile(ProtocolInfo.STUDIES, OutputFile);
% Save file
bst_save(OutputFileFull, ChannelMat, 'v7');
% New channel structure
sChannelDb = db_template('Channel');
sChannelDb.FileName   = OutputFile;
sChannelDb.Comment    = ChannelMat.Comment;
sChannelDb.nbChannels = length(ChannelMat.Channel);
[sChannelDb.Modalities, sChannelDb.DisplayableSensorTypes] = channel_get_modalities(ChannelMat.Channel);
% Get the leading modality
if any(ismember({'MEG','MEG GRAD','MEG MAG'}, sChannelDb.DisplayableSensorTypes))
    Modality = 'MEG';
elseif ismember('EEG', sChannelDb.DisplayableSensorTypes)
    Modality = 'EEG';
elseif ismember('NIRS', sChannelDb.DisplayableSensorTypes)
    Modality = 'NIRS';
else
    Modality = [];
end
        

%% ===== UPDATE DATABASE =====
% Register file in database
sStudy.Channel = sChannelDb;
bst_set('Study', iStudy, sStudy);
% Update tree
panel_protocols('UpdateNode', 'Study', iStudy);
% Save database
db_save();


%% ===== AUTOMATIC ALIGNMENT =====
% Performed registration
if (ChannelAlign >= 1)
    % Display intial registration
    if (ChannelAlign == 1)
        % No modality that can be used
        if isempty(Modality)
            return;
        end
        % Display initial registration
        bst_memory('UnloadAll', 'Forced');
        channel_align_manual(OutputFileFull, Modality, 0);
        % Ask for confirmation before ICP alignment
        isConfirm = 1;
    else
        % ChannelAlign=2: DO NOT ask for confirmation before ICP alignment
        isConfirm = 0;
    end
    
    % Call automatic registration for MEG
    [ChannelMat, R, T, isSkip, isUserCancel] = channel_align_auto(OutputFile, [], 0, isConfirm);
    % User validated: keep this answer for the next round (force alignment for next call)
    if ~isSkip
        if isUserCancel
            ChannelAlign = 0;
        elseif ~isempty(ChannelMat)
            ChannelAlign = 2;
        else
            ChannelAlign = 0;
        end
    end
end



