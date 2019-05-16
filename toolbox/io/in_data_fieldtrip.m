function [DataMat, ChannelMat] = in_data_fieldtrip(DataFile)
% IN_DATA_FIELDTRIP: Read recordings from FieldTrip structures (ft_datatype_timelock, ft_datatype_raw)
%
% USAGE:  [DataMat, ChannelMat] = in_data_fieldtrip( DataFile )

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
% Authors: Francois Tadel, 2015-2019

% Get format
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Initialize returned structure
DataMat = db_template('DataMat');
DataMat.Comment  = fBase;
DataMat.Device   = 'FieldTrip';
DataMat.DataType = 'recordings';
DataMat.nAvg     = 1;

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
    % Duplicate structure: return one file for each trial
    DataMat = repmat(DataMat, 1, length(ftMat.trial));
    % Copy the data for each trials
    for i = 1:length(DataMat)
        DataMat(i).F = double(ftMat.trial{i});
        if iscell(ftMat.time)
            DataMat(i).Time = double(ftMat.time{i});
        else
            DataMat(i).Time = double(ftMat.time);
        end
        % Add trial number to the comment
        DataMat(i).Comment = [DataMat(i).Comment, sprintf(' (#%d)', i)];
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


