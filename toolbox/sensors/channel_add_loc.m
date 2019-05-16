function channel_add_loc(iStudies, LocChannelFile, isInteractive)
% CHANNEL_ADD_LOC: Add the positions of the EEG electrodes from a another channel file.
% 
% USAGE:  channel_add_loc(iStudies, LocChannelFile=[ask], isInteractive=0)
%         channel_add_loc(iStudies, LocChannelMat,        isInteractive=0)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014-2019

% Parse inputs
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 0;
end
if (nargin < 2) || isempty(LocChannelFile)
    LocChannelFile = [];
end
Messages = '';

% Get Brainstorm channel file
isTemplate = 0;
if ~isempty(LocChannelFile)
    if ischar(LocChannelFile)
        LocChannelMat = in_bst_channel(LocChannelFile);
        % Check if the input file is a template
        defaultsDir = bst_fullfile(bst_get('BrainstormDefaultsDir'), 'eeg');
        isTemplate = ~isempty(strfind(LocChannelFile, defaultsDir));
    else
        LocChannelMat = LocChannelFile;
        LocChannelFile = [];
    end
% Import positions from external file
else
    if isInteractive
        isFixUnits = [];
        isApplyVox2ras = [];
    else
        isFixUnits = 0;
        isApplyVox2ras = 1;
    end
    [LocChannelMat, ChannelFile, FileFormat] = import_channel(iStudies, [], [], 0, 0, 0, isFixUnits, isApplyVox2ras);
end
% Nothing loaded: exit
if isempty(LocChannelMat)
    return;
end
% Get new channel names
locChanNames = {LocChannelMat.Channel.Name};
% Replace "'" with "p"
locChanNames = strrep(locChanNames, '''', 'p');

% Process all the studies in input
for is = 1:length(iStudies)
    % Multiple channels: add a header
    if (length(iStudies) > 1)
        Messages = [Messages, sprintf('Study #%d: ', iStudies(is))];
    end
    % Get study
    sStudy = bst_get('Study', iStudies(is));
    % No channel file: warning
    if isempty(sStudy.Channel) || isempty(sStudy.Channel(1).FileName)
        Messages = [Messages, 'No channel file available.', 10];
        continue;
    end
    % Get channel file
    ChannelFile = sStudy.Channel(1).FileName;
    ChannelMat = in_bst_channel(ChannelFile);
    % Initialize counters
    nUpdated = 0;
    nNotFound = 0;
    % For all the channels, look for its definition in the LOC EEG cap
    for ic = 1:length(ChannelMat.Channel)
        chName = ChannelMat.Channel(ic).Name;
        % Replace "'" with "p"
        chName = strrep(chName, '''', 'p');
        % Look for the exact channel name
        idef = find(strcmpi(chName, locChanNames));
        % If not found, look for an alternate version (with or without trailing zeros...)
        if isempty(idef) && ismember(lower(chName(1)), 'abcdefghijklmnopqrstuvwxyz') && ismember(lower(chName(end)), '0123456789')
            [chGroup, chTag, chInd] = panel_montage('ParseSensorNames', ChannelMat.Channel(ic));
            % Look for "A01"
            idef = find(strcmpi(sprintf('%s%02d', strrep(chTag{1}, '''', 'p'), chInd(1)), locChanNames));
            if isempty(idef)
                % Look for "A1"
                idef = find(strcmpi(sprintf('%s%d', strrep(chTag{1}, '''', 'p'), chInd(1)), locChanNames));
            end
        end
        % If the channel is found has a valid 3D position
        if ~isempty(idef) && (size(ChannelMat.Channel(ic).Loc,2) <= 1) && ~isequal(LocChannelMat.Channel(idef).Loc, [0;0;0])
            % If the channel is already considered as EEG, do not change its type, otherwise set it to EEG
            if ~ismember(ChannelMat.Channel(ic).Type, {'EEG','SEEG','ECOG'})
                ChannelMat.Channel(ic).Type = 'EEG';
            elseif ismember(LocChannelMat.Channel(idef).Type, {'SEEG','ECOG'})
                ChannelMat.Channel(ic).Type = LocChannelMat.Channel(idef).Type;
            end
            ChannelMat.Channel(ic).Loc    = LocChannelMat.Channel(idef).Loc;
            ChannelMat.Channel(ic).Orient = LocChannelMat.Channel(idef).Orient;
            ChannelMat.Channel(ic).Weight = LocChannelMat.Channel(idef).Weight;
            nUpdated = nUpdated + 1;
            % If not a template: add head points
            if ~isTemplate
                % Initialize list of head points as cell arrays (if not it concatenate as strings)
                if isempty(ChannelMat.HeadPoints.Label)
                    ChannelMat.HeadPoints.Label = {};
                    ChannelMat.HeadPoints.Type = {};
                end
                % Add as head points (if doesn't exist yet)
                if isempty(ChannelMat.HeadPoints.Loc) || all(sqrt(sum(bst_bsxfun(@minus, ChannelMat.HeadPoints.Loc, ChannelMat.Channel(ic).Loc) .^ 2, 1)) > 0.0001)
                    ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   ChannelMat.Channel(ic).Loc];
                    ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, ChannelMat.Channel(ic).Name];
                    ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  'EXTRA'];
                end
            end
        elseif ismember(ChannelMat.Channel(ic).Type, {'EEG','SEEG','ECOG'})
            ChannelMat.Channel(ic).Type = [ChannelMat.Channel(ic).Type, '_NO_LOC'];
            nNotFound = nNotFound + 1;
        end
    end
    % No channels were found
    if (nUpdated == 0)
        Messages = [Messages, 'No channel matching the loaded cap.', 10];
        continue;
    else
        Messages = [Messages, sprintf('%d channels updated, %d channels not found.\n', nUpdated, nNotFound)];
    end
    % Copy fiducials (if they are available in the new file and not in the original one)
    if (~isfield(ChannelMat, 'SCS') || ~isfield(ChannelMat.SCS, 'NAS') || isempty(ChannelMat.SCS.NAS)) && (isfield(LocChannelMat, 'SCS') && isfield(LocChannelMat.SCS, 'NAS') && ~isempty(LocChannelMat.SCS.NAS))
        ChannelMat.SCS = LocChannelMat.SCS;
    end
    % Delete existing headpoints in the case of an EEG template (unless there are many more points than electrodes)
    if isTemplate && ~isempty(ChannelMat.HeadPoints.Loc)
        Messages = [Messages, sprintf('%d head points removed.\n', size(ChannelMat.HeadPoints.Loc,2))];
        ChannelMat.HeadPoints.Loc = [];
        ChannelMat.HeadPoints.Label = {};
        ChannelMat.HeadPoints.Type = {};
    % Copy the head points if they don't exist yet
    elseif isempty(ChannelMat.HeadPoints.Loc) && ~isempty(LocChannelMat.HeadPoints.Loc)
        ChannelMat.HeadPoints = LocChannelMat.HeadPoints;
        Messages = [Messages, sprintf('%d head points added.\n', size(LocChannelMat.HeadPoints.Loc,2))];
    end
    % Force updating SEEG/ECOG electrodes
    for Modality = {'SEEG', 'ECOG'}
        if ismember(Modality{1}, {ChannelMat.Channel.Type})
            ChannelMat = panel_ieeg('DetectElectrodes', ChannelMat, Modality{1}, [], 1);
        end
    end
    % History: Added channel locations
    ChannelMat = bst_history('add', ChannelMat, 'addloc', ['Added EEG positions from "' LocChannelMat.Comment '"']);
    % Save modified file
    bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
    % Reload study
    db_reload_studies(iStudies);
end
% Message: Summary
if isInteractive
    java_dialog('msgbox', Messages, 'Add EEG positions');
end



