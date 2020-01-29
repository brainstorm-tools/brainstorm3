function [ftData, DataMat, ChannelMat, iChannels] = out_fieldtrip_data( DataFile, ChannelFile, SensorTypes, isTimelock )
% OUT_FIELDTRIP_DATA: Converts a data file into a FieldTrip structure (ft_datatype_timelock.m / ft_datatype_raw.m)
% 
% USAGE:  [ftData, DataMat, ChannelMat, iChannels] = out_fieldtrip_data( DataFile, ChannelFile=[], SensorTypes/iChannels=[], isTimelock=0 );
%         [ftData, DataMat, ChannelMat, iChannels] = out_fieldtrip_data( DataMat,  ChannelMat=[],  SensorTypes/iChannels=[], isTimelock=0 );
%
% INPUTS:
%    - DataFile     : Relative path to a recordings file available in the database
%    - DataMat      : Brainstorm data file structure
%    - ChannelFile  : Relative path to a channel file available in the database (if not provided: look for it based on the DataFile)
%    - ChannelMat   : Brainstorm channel file structure
%    - iChannels    : Vector of selected channel indices
%    - SensorTypes  : Names or types of channels, separated with commas
%    - isTimelock   : If 1, return a FieldTrip structure "timelock"  (see ft_datatype_timelock.m)
%                     If 0, return a FieldTrip structure "raw"       (see ft_datatype_raw.m)

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
% Authors: Roey Schurr, Arnaud Gloaguen, Francois Tadel, 2015-2016


% ===== PARSE INPUT =====
if (nargin < 4) || isempty(isTimelock)
    isTimelock = 0;
end
if (nargin < 3) || isempty(SensorTypes)
    SensorTypes = [];
end
if (nargin < 2) || isempty(ChannelFile)
    ChannelMat  = [];
    ChannelFile = [];
elseif isstruct(ChannelFile)
    ChannelMat   = ChannelFile;
    ChannelFile = [];
else
    ChannelMat = [];
end
if isstruct(DataFile)
    DataMat  = DataFile;
    DataFile = [];
end


% ===== LOAD INPUTS =====
% Load data file
if ~isempty(DataFile)
    DataMat = in_bst_data(DataFile);
    % Get ChannelFile if not provided
    if isempty(ChannelFile)
        ChannelFile = bst_get('ChannelFileForStudy', DataFile);
    end
end
% Load channel file
if ~isempty(ChannelFile) && isempty(ChannelMat)
    ChannelMat = in_bst_channel(ChannelFile);
end
% Make sure that the channel file is defined
if isempty(ChannelMat)
    error('No channel file available for the input files.');
end
% Find sensors by names/types
if ~isempty(SensorTypes)
    if ischar(SensorTypes)
        iChannels = channel_find(ChannelMat.Channel, SensorTypes);
        if isempty(iChannels)
            error(['Channels not found: ' SensorTypes]);
        end
    elseif isnumeric(SensorTypes)
        iChannels = SensorTypes;
    else
        error('Invalid input type for parameter "SensorTypes".');
    end
% Default channel selection: all
else
    iChannels = 1:size(DataMat.F,1);
end

% ===== RECORDINGS =====
% Convert to FieldTrip data structure
ftData = struct();
ftData.dimord  = 'chan_time';
% Timelock structure: see ft_datatype_timelock.m
if isTimelock
    ftData.avg  = DataMat.F(iChannels,:);
    ftData.time = DataMat.Time;
%     if isfield(DataMat, 'Std') && ~isempty(DataMat.Std)
%         ftData.var = DataMat.Std(iChannels,:);
%     end
% Raw structure: see ft_datatype_raw.m
else
    ftData.trial{1} = DataMat.F(iChannels,:);
    ftData.time{1}  = DataMat.Time;
end

% ===== CHANNEL INFO =====
% Keep only the selected channels
ftChannelMat = ChannelMat;
ftChannelMat.Channel = ftChannelMat.Channel(iChannels);
% Initialize the channel-related fields
ftData.label = {ftChannelMat.Channel.Name}';
% Get channel structures
[elec, grad] = out_fieldtrip_channel(ftChannelMat, 1);
% Add to data structure
if ~isempty(elec)
    ftData.elec = elec;
end
if ~isempty(grad)
    ftData.grad = grad;
end
    





