function ChannelMat = channel_detect_type( ChannelMat, isAlign, isRemoveFid )
% CHANNEL_DETECT_TYPE: Detect some auxiliary EEG channels in a channel structure.
%
% USAGE:  ChannelMat = channel_detect_type( ChannelMat, isAlign=0, isRemoveFid=0 )

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
% Authors: Francois Tadel, 2009-2017

% Parse inputs
if (nargin < 2) || isempty(isAlign)
    isAlign = 0;
end
if (nargin < 3) || isempty(isRemoveFid)
    isRemoveFid = 1;
end

%% ===== DETECT SENSOR TYPES =====
% Add orientation fields
if ~isfield(ChannelMat, 'SCS') || isempty(ChannelMat.SCS)
    ChannelMat.SCS = db_template('SCS');
end
% Add head points field
HeadPoints.Loc   = [];
HeadPoints.Label = {};
HeadPoints.Type  = {};
% If some fiducials are defined in the imported channel file
iDelChan = [];
iEegNoLoc = [];
iEegLoc = [];
iCheck = channel_find(ChannelMat.Channel, 'EEG, Fiducial, SEEG, ECOG, MISC');
for i = 1:length(iCheck)
    iChan = iCheck(i);
    if isempty(ChannelMat.Channel(iChan).Name)
        continue;
    end
    % Check name
    chName = lower(ChannelMat.Channel(iChan).Name);
    switch(chName)
        case {'nas', 'nasion', 'nz', 'fidnas', 'fidnz', 'n'}  % NASION
            if ~isempty(ChannelMat.Channel(iChan).Loc) && ~all(ChannelMat.Channel(iChan).Loc == 0)
                iDelChan = [iDelChan, iChan];
                % ChannelMat.SCS.NAS = ChannelMat.Channel(iChan).Loc(:,1)' .* 1000;
                ChannelMat.SCS.NAS = ChannelMat.Channel(iChan).Loc(:,1)';  % CHANGED 09-May-2013 (suspected bug, not tested)
            end
            ChannelMat.Channel(iChan).Type = 'Misc';
        case {'lpa', 'pal', 'og', 'left', 'fidt9', 'leftear', 'l'} % LEFT EAR
            if ~isempty(ChannelMat.Channel(iChan).Loc) && ~all(ChannelMat.Channel(iChan).Loc == 0)
                iDelChan = [iDelChan, iChan];
                % ChannelMat.SCS.LPA = ChannelMat.Channel(iChan).Loc(:,1)' .* 1000;
                ChannelMat.SCS.LPA = ChannelMat.Channel(iChan).Loc(:,1)';   % CHANGED 09-May-2013 (suspected bug, not tested)
                % Add as head point
                HeadPoints.Loc   = [HeadPoints.Loc,   ChannelMat.SCS.LPA'];
                HeadPoints.Label = [HeadPoints.Label, 'LPA'];
                HeadPoints.Type  = [HeadPoints.Type,  'CARDINAL'];
            end
            ChannelMat.Channel(iChan).Type = 'Misc';
        case {'rpa', 'par', 'od', 'right', 'fidt10', 'rightear', 'r'} % RIGHT EAR
            if ~isempty(ChannelMat.Channel(iChan).Loc) && ~all(ChannelMat.Channel(iChan).Loc == 0)
                iDelChan = [iDelChan, iChan];
                % ChannelMat.SCS.RPA = ChannelMat.Channel(iChan).Loc(:,1)' .* 1000;
                ChannelMat.SCS.RPA = ChannelMat.Channel(iChan).Loc(:,1)';   % CHANGED 09-May-2013 (suspected bug, not tested)
                % Add as head point
                HeadPoints.Loc   = [HeadPoints.Loc,   ChannelMat.SCS.RPA'];
                HeadPoints.Label = [HeadPoints.Label, 'RPA'];
                HeadPoints.Type  = [HeadPoints.Type,  'CARDINAL'];
            end
            ChannelMat.Channel(iChan).Type = 'Misc';
        case {'fid', 'fidcz'} % Other fiducials
            iDelChan = [iDelChan, iChan];
            % Add as head point
            if ~isempty(ChannelMat.Channel(iChan).Loc) && ~all(ChannelMat.Channel(iChan).Loc == 0)
                HeadPoints.Loc   = [HeadPoints.Loc,   ChannelMat.Channel(iChan).Loc(:,1)];
                HeadPoints.Label = [HeadPoints.Label, ChannelMat.Channel(iChan).Name];
                HeadPoints.Type  = [HeadPoints.Type,  'CARDINAL'];
            end
        case {'ref','eegref','eref','vref','ref.'}
            ChannelMat.Channel(iChan).Type = 'EEG REF';
            % Add as head point
            if ~isempty(ChannelMat.Channel(iChan).Loc) && ~all(ChannelMat.Channel(iChan).Loc == 0)
                HeadPoints.Loc   = [HeadPoints.Loc,   ChannelMat.Channel(iChan).Loc(:,1)];
                HeadPoints.Label = [HeadPoints.Label, ChannelMat.Channel(iChan).Name];
                HeadPoints.Type  = [HeadPoints.Type,  'EXTRA'];
            end
        % OTHER NON-EEG CHANNELS
        otherwise
            % Different types
            if ~isempty(strfind(chName, 'eog')) || ~isempty(strfind(chName, 'veo')) || ~isempty(strfind(chName, 'heo'))
                ChannelMat.Channel(iChan).Type = 'EOG';
            elseif ~isempty(strfind(chName, 'ecg')) || ~isempty(strfind(chName, 'ekg'))
                ChannelMat.Channel(iChan).Type = 'ECG';
            elseif ~isempty(strfind(chName, 'emg'))
                ChannelMat.Channel(iChan).Type = 'EMG';
            elseif ~isempty(strfind(chName, 'seeg'))
                ChannelMat.Channel(iChan).Type = 'SEEG';
            elseif ~isempty(strfind(chName, 'ecog'))
                ChannelMat.Channel(iChan).Type = 'ECOG';
            elseif ~isempty(strfind(chName, 'pulse'))
                ChannelMat.Channel(iChan).Type = 'Misc';
            elseif ~isempty(strfind(chName, 'mast'))
                ChannelMat.Channel(iChan).Type = 'MAST';
            elseif ~isempty(strfind(chName, 'trig')) && (length(chName) < 12)
                ChannelMat.Channel(iChan).Type = 'STIM';
            % Head points (ZEBRIS)
            elseif ~isempty(strfind(chName, 'sfh')) || ~isempty(strfind(chName, 'sfl')) || ~isempty(strfind(chName, 'SL_')) || ~isempty(strfind(chName, 'SP_')) 
                iDelChan = [iDelChan, iChan];
            end
            % Add as head point
            if ~isempty(ChannelMat.Channel(iChan).Loc) && ~all(ChannelMat.Channel(iChan).Loc == 0)
                HeadPoints.Loc   = [HeadPoints.Loc,   ChannelMat.Channel(iChan).Loc(:,1)];
                HeadPoints.Label = [HeadPoints.Label, ChannelMat.Channel(iChan).Name];
                HeadPoints.Type  = [HeadPoints.Type,  'EXTRA'];
            end
    end
    % Check type
    if strcmpi(ChannelMat.Channel(iChan).Type, 'fiducial')
        iDelChan = [iDelChan, iChan];
    end
    % Count channels with and without locations
    if ismember(ChannelMat.Channel(iChan).Type, {'EEG','SEEG','ECOG'})
        if isempty(ChannelMat.Channel(iChan).Loc) || isequal(ChannelMat.Channel(iChan).Loc, [0;0;0])
            iEegNoLoc(end+1) = iChan;
        else
            iEegLoc(end+1) = iChan;
        end
    end
end

% Add head points: Only if there are no other head points already defined
if ~isfield(ChannelMat, 'HeadPoints') || ~isfield(ChannelMat.HeadPoints, 'Loc') || isempty(ChannelMat.HeadPoints.Loc)
    ChannelMat.HeadPoints = HeadPoints;
end
% If there are a few channels without location: set type to EEG_NO_LOC
if ~isempty(iEegLoc) && ~isempty(iEegNoLoc) && (length(iEegLoc) > length(iEegNoLoc))
    [ChannelMat.Channel(iEegNoLoc).Type] = deal('EEG_NO_LOC');
end
% Delete fiducials from channel file
if isRemoveFid
    ChannelMat.Channel(iDelChan) = [];
end
% If there are less than a certain number of "EEG" channels, but with other displayable modalities let's consider it's not EEG
iEEG = channel_find(ChannelMat.Channel, 'EEG');
if (length(iEEG) < 5) && ~isempty(channel_find(ChannelMat.Channel, 'MEG,SEEG,ECOG'))
    [ChannelMat.Channel(iEEG).Type] = deal('Misc');
end


%% ===== DETECT FIDUCIALS IN HEAD POINTS =====
if (~isfield(ChannelMat, 'SCS') || ~isfield(ChannelMat.SCS, 'NAS') || isempty(ChannelMat.SCS.NAS)) && ...
   (isfield(ChannelMat, 'HeadPoints') && isfield(ChannelMat.HeadPoints, 'Label') && ~isempty(ChannelMat.HeadPoints.Label))
    % Get the three fiducials in the head points
    iNas = find(strcmpi(ChannelMat.HeadPoints.Label, 'Nasion') | strcmpi(ChannelMat.HeadPoints.Label, 'NAS'));
    iLpa = find(strcmpi(ChannelMat.HeadPoints.Label, 'Left')   | strcmpi(ChannelMat.HeadPoints.Label, 'LPA'));
    iRpa = find(strcmpi(ChannelMat.HeadPoints.Label, 'Right')  | strcmpi(ChannelMat.HeadPoints.Label, 'RPA'));
    % If they are all defined: use them
    if ~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa)
        ChannelMat.SCS.NAS = mean(ChannelMat.HeadPoints.Loc(:,iNas)', 1);
        ChannelMat.SCS.LPA = mean(ChannelMat.HeadPoints.Loc(:,iLpa)', 1);
        ChannelMat.SCS.RPA = mean(ChannelMat.HeadPoints.Loc(:,iRpa)', 1);
    end
end


%% ===== ALIGN IN SCS COORDINATES =====
% Re-align in the Brainstorm/CTF coordinate system, if it is not already
if isAlign && all(isfield(ChannelMat.SCS, {'NAS','LPA','RPA'})) && (length(ChannelMat.SCS.NAS) == 3) && (length(ChannelMat.SCS.LPA) == 3) && (length(ChannelMat.SCS.RPA) == 3)
    % Force vector orientations
    ChannelMat.SCS.NAS = ChannelMat.SCS.NAS(:)';
    ChannelMat.SCS.LPA = ChannelMat.SCS.LPA(:)';
    ChannelMat.SCS.RPA = ChannelMat.SCS.RPA(:)';
    % Compute transformation
    transfSCS = cs_compute(ChannelMat, 'scs');
    ChannelMat.SCS.R      = transfSCS.R;
    ChannelMat.SCS.T      = transfSCS.T;
    ChannelMat.SCS.Origin = transfSCS.Origin;
    % Convert the fiducials positions
    %   NOTE: The division/multiplication by 1000 is to compensate the T/1000 applied in the cs_convert().
    %         This hack was added becaue cs_convert() is intended to work on sMri structures, 
    %         in which NAS/LPA/RPA/T fields are in millimeters, while in ChannelMat they are in meters.
    ChannelMat.SCS.NAS = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.NAS ./ 1000) .* 1000;
    ChannelMat.SCS.LPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.LPA ./ 1000) .* 1000;
    ChannelMat.SCS.RPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.RPA ./ 1000) .* 1000;
    % Process each sensor
    for i = 1:length(ChannelMat.Channel)
        % Converts the electrodes locations to SCS (subject coordinates system)
        if ~isempty(ChannelMat.Channel(i).Loc)
            ChannelMat.Channel(i).Loc = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.Channel(i).Loc' ./ 1000)' .* 1000;
        end
        if ~isempty(ChannelMat.Channel(i).Orient)
            ChannelMat.Channel(i).Orient = ChannelMat.SCS.R * ChannelMat.Channel(i).Orient;
        end
    end
    % Process the head points    % ADDED 27-May-2013
    if ~isempty(ChannelMat.HeadPoints) && ~isempty(ChannelMat.HeadPoints.Type) && ~isempty(ChannelMat.HeadPoints.Loc)
        ChannelMat.HeadPoints.Loc = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.HeadPoints.Loc' ./ 1000)' .* 1000;
    end
    % Add to the list of transformation
    ChannelMat.TransfMeg{end+1} = [ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1];
    ChannelMat.TransfMegLabels{end+1} = 'Native=>Brainstorm/CTF';
    ChannelMat.TransfEeg{end+1} = [ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1];
    ChannelMat.TransfEegLabels{end+1} = 'Native=>Brainstorm/CTF';
end


%% ===== CHECK SENSOR NAMES =====
% Check for empty channels
iEmpty = find(cellfun(@isempty, {ChannelMat.Channel.Name}));
for i = 1:length(iEmpty)
    ChannelMat.Channel(iEmpty(i)).Name = sprintf('%04d', iEmpty(i));
end
% Check for duplicate channels
for i = 1:length(ChannelMat.Channel)
    iOther = setdiff(1:length(ChannelMat.Channel), i);
    ChannelMat.Channel(i).Name = file_unique(ChannelMat.Channel(i).Name, {ChannelMat.Channel(iOther).Name});
end
% Get again EEG channels
iEegAll = channel_find(ChannelMat.Channel, {'EEG', 'SEEG', 'ECOG'});
% Remove "-Ref" if all the channels contain it
Tags = {'-ref', 'ref', '-fcz', '-rpar'};
for iTag = 1:length(Tags)
    % Check for all channels
    isTag = cellfun(@(c)strfind(lower(c),Tags{iTag}), {ChannelMat.Channel.Name}, 'UniformOutput', 0);
    if all(~cellfun(@isempty, isTag))
        for i = 1:length(ChannelMat.Channel)
            ChannelMat.Channel(i).Name(isTag{i}(1):isTag{i}(1) + length(Tags{iTag}) - 1) = [];
        end
    % Check for EEG only
    elseif (length(iEegAll) > 4)
        isTag = cellfun(@(c)strfind(lower(c),Tags{iTag}), {ChannelMat.Channel(iEegAll).Name}, 'UniformOutput', 0);
        if all(~cellfun(@isempty, isTag))
            for i = 1:length(iEegAll)
                ChannelMat.Channel(iEegAll(i)).Name(isTag{i}(1):isTag{i}(1) + length(Tags{iTag}) - 1) = [];
            end
        end
    end
end


    