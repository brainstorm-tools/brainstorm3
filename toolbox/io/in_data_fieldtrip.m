function [DataMat, ChannelMat] = in_data_fieldtrip(DataFile, isInteractive)
% IN_DATA_FIELDTRIP: Read recordings from FieldTrip structures (ft_datatype_timelock, ft_datatype_raw)
%
% USAGE:  [DataMat, ChannelMat] = in_data_fieldtrip(DataFile, isInteractive)

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
% Authors: Francois Tadel, 2015-2021

% Parse inputs
if (nargin < 2) || isempty(isInteractive)
    isInteractive = 1;
end

% Get format
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Initialize returned structure
DataMat = db_template('DataMat');
DataMat.Comment  = fBase;
DataMat.Device   = 'FieldTrip';
DataMat.DataType = 'recordings';
DataMat.nAvg     = 1;


% ===== LOAD FILE =====
% Load structure
ftMat = load(DataFile);
fields = fieldnames(ftMat);
% If the .time field is not directly accessible, try one level down
if ~isfield(ftMat, 'time')
    for i = 1:length(fields)
        if isfield(ftMat.(fields{i}), 'time')
            ftMat = ftMat.(fields{i});
            break;
        end
    end
end
% Check all the required fields
if ~isfield(ftMat, 'time') || ~isfield(ftMat, 'label') || (~isfield(ftMat, 'avg') && ~isfield(ftMat, 'trial'))
    error(['This file is not a valid FieldTrip recordings structure (timelocked or raw).' 10 'Missing fields: "time", "label", "avg" or "trial".']);
end
% No bad channels information
nChannels = length(ftMat.label);
DataMat.ChannelFlag = ones(nChannels, 1);


% ===== GET SIGNALS =====
% Data type: timelocked
if isfield(ftMat, 'avg') && ~isempty(ftMat.avg)
    DataMat.F    = double(ftMat.avg);
    DataMat.Time = double(ftMat.time);
    if isfield(ftMat, 'var')
        DataMat.Std = sqrt(double(ftMat.var));
    end
    if isfield(ftMat, 'dof')
        DataMat.nAvg = max(double(ftMat.dof(:)));
    end

% Data type: raw
elseif isfield(ftMat, 'trial') && ~isempty(ftMat.trial)
    % === GET TRIAL INFO ===
    % Get trial info, if available
    trialId = ones(length(ftMat.trial), 1);
    trialinfoClean = [];
    % Cleanup trialinfo
    if isfield(ftMat, 'trialinfo') && (size(ftMat.trialinfo,1) == length(ftMat.trial)) && isnumeric(ftMat.trialinfo)
        iGoodCol = find(~any(isnan(ftMat.trialinfo),1) & ~all(bst_bsxfun(@minus, ftMat.trialinfo, ftMat.trialinfo(1,:)) == 0, 1));
        if ~isempty(iGoodCol)
            trialinfoClean = ftMat.trialinfo(:, iGoodCol);
        end
    end
    % Select columns of trial ID
    if ~isempty(trialinfoClean)
        % Ask the user for confirmation
        if isInteractive
            % Ask which column to use in the trialinfo field
            nCol = size(trialinfoClean,2);
            res = java_dialog('question', [...
                'A field "trialinfo" with ' num2str(nCol) ' column(s) is avaiable in the file.' 10 10 ...
                'Which column to use to label the imported trials?'], ...
                'Trial classification', [], cat(2, 'None', cellfun(@num2str, num2cell(1:nCol), 'UniformOutput', 0)));
            if isempty(res)
                DataMat = [];
                ChannelMat = [];
                return;
            end
            if ~isequal(res, 'None')
                trialId = trialinfoClean(:, str2double(res));
            end
        % Automatic: use the first column only
        else
            trialId = trialinfoClean(:,1);
        end
    end
    
    % === CREATE DATA STRUCTURES ===
    % Duplicate structure: return one file for each trial
    DataMat = repmat(DataMat, 1, length(ftMat.trial));
    % Process by trial id
    uniqueId = unique(trialId);
    % Copy the data for each trials
    for iId = 1:length(uniqueId)
        % Get all the trials for this ID
        iIdTrials = find(trialId == uniqueId(iId));
        % Loop on trials
        for i = 1:length(iIdTrials)
            iTrial = iIdTrials(i);
            % Get signals
            DataMat(iTrial).F = double(ftMat.trial{iTrial});
            % Get time
            if iscell(ftMat.time)
                DataMat(iTrial).Time = double(ftMat.time{iTrial});
            else
                DataMat(iTrial).Time = double(ftMat.time);
            end
            % Use the trial ID as the file comment
            if (length(uniqueId) > 1)
                DataMat(iTrial).Comment = num2str(uniqueId(iId));
            end
            % Add trial index to the comment
            if (length(iIdTrials) > 1) 
                DataMat(iTrial).Comment = [DataMat(iTrial).Comment, sprintf(' (#%d)', i)];
            end
        end
    end
end


% ===== CREATE CHANNEL FILE =====
% Default channel structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'FieldTrip channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, nChannels]);
% Basic channel properties
for i = 1:nChannels
    ChannelMat.Channel(i).Name    = ftMat.label{i};
    ChannelMat.Channel(i).Comment = [];
    ChannelMat.Channel(i).Loc     = [0; 0; 0];
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    if isfield(ftMat, 'chantype') && ~isempty(ftMat.chantype)
        ChannelMat.Channel(i).Type = upper(ftMat.chantype{i});
    end
end

% Read detailed information from .grad and .elec fields
ChannelMat = read_fieldtrip_chaninfo(ChannelMat, ftMat);

% If none of the channels are set, make it all "EEG"
isEmptyType = cellfun(@isempty, {ChannelMat.Channel.Type});
if all(isEmptyType)
    [ChannelMat.Channel.Type] = deal('EEG');
% If only a few are empty: tag them as "OTHER"
elseif any(isEmptyType)
    [ChannelMat.Channel(isEmptyType).Type] = deal('OTHER');
end


