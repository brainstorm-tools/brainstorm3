function channel_add_loc(iStudies, LocChannelFile, isInteractive)
% CHANNEL_ADD_LOC: Add the positions of the EEG electrodes from a another channel file.
% 
% USAGE:  channel_add_loc(iStudies, LocChannelFile=[ask], isInteractive=0)
%         channel_add_loc(iStudies, LocChannelMat,        isInteractive=0)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014

% Parse inputs
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 0;
end
if (nargin < 2) || isempty(LocChannelFile)
    LocChannelFile = [];
end
Messages = '';

% Get Brainstorm channel file
if ~isempty(LocChannelFile)
    if ischar(LocChannelFile)
        LocChannelMat = in_bst_channel(LocChannelFile);
    else
        LocChannelMat = LocChannelFile;
        LocChannelFile = [];
    end
% Import positions from external file
else
    LocChannelMat = import_channel([], [], [], 0, 0);
end
% Nothing loaded: exit
if isempty(LocChannelMat)
    return;
end

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
        idef = find(strcmpi(ChannelMat.Channel(ic).Name, {LocChannelMat.Channel.Name}));
        if ~isempty(idef) && (size(ChannelMat.Channel(ic).Loc,2) <= 1) && ~isequal(LocChannelMat.Channel(idef).Loc, [0;0;0])
            ChannelMat.Channel(ic).Type   = 'EEG';
            ChannelMat.Channel(ic).Loc    = LocChannelMat.Channel(idef).Loc;
            ChannelMat.Channel(ic).Orient = LocChannelMat.Channel(idef).Orient;
            ChannelMat.Channel(ic).Weight = LocChannelMat.Channel(idef).Weight;
            nUpdated = nUpdated + 1;
            % Initialize list of head points as cell arrays (if not it concatenate as strings)
            if isempty(ChannelMat.HeadPoints.Label)
                ChannelMat.HeadPoints.Label = {};
                ChannelMat.HeadPoints.Type = {};
            end
            % Add as head points
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   ChannelMat.Channel(ic).Loc];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, ChannelMat.Channel(ic).Name];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  'EXTRA'];
        elseif strcmpi(ChannelMat.Channel(ic).Type, 'EEG')
            ChannelMat.Channel(ic).Type = 'EEG_NO_LOC';
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
    % Copy the head points
    if isempty(ChannelMat.HeadPoints.Loc) && ~isempty(LocChannelMat.HeadPoints.Loc)
        ChannelMat.HeadPoints = LocChannelMat.HeadPoints;
        Messages = [Messages, sprintf('%d head points added.\n', size(LocChannelMat.HeadPoints.Loc,2))];
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



