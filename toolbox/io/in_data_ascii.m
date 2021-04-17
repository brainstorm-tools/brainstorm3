function [DataMat, ChannelMat] = in_data_ascii( DataFile )
% IN_DATA_ASCII: Read an ASCII EEG file.
%
% INPUT:
%    - DataFile : Full path to a recordings file (called 'data' files in Brainstorm)
% OUTPUT: 
%    - DataMat : Brainstorm standard recordings ('data') structure

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
% Authors: Francois Tadel, 2008-2017


%% ===== GET OPTIONS =====
% Get options
OPTIONS = bst_get('ImportEegRawOptions');


%% ===== READ ASCII FILE =====
% Initialize returned structures
DataMat = db_template('DataMat');
DataMat.Comment  = 'EEG/ASCII';
DataMat.DataType = 'recordings';
DataMat.Device   = 'Unknown';
ChannelMat = [];
% Read file
DataMat.F = in_ascii(DataFile, OPTIONS.SkipLines, OPTIONS.isChannelName);
if isempty(DataMat.F)
    DataMat = [];
    bst_error(['Cannot read file: "' DataFile '"'], 'Import RAW EEG data', 0);
    return
end
% Check matrix orientation
switch OPTIONS.MatrixOrientation
    case 'channelXtime'
        % OK
    case 'timeXchannel'
        % Transpose needed
        DataMat.F = DataMat.F';
end
% Build time vector
DataMat.Time = ((0:size(DataMat.F,2)-1) ./ OPTIONS.SamplingRate - OPTIONS.BaselineDuration);
% ChannelFlag
DataMat.ChannelFlag = ones(size(DataMat.F,1), 1);

% If channel names is included: extract and convert data matrix to numeric values
if OPTIONS.isChannelName
    % Get channel names
    chNames = DataMat.F(:,1);
    % Get data values
    DataMat.F = cellfun(@str2num, DataMat.F(:,2:end));
    % Create channel file
    ChannelMat = db_template('channelmat');
    ChannelMat.Channel = repmat(db_template('channeldesc'), 1, length(chNames));
    [ChannelMat.Channel.Type] = deal('EEG');
    [ChannelMat.Channel.Name] = deal(chNames{:});
end
% Replace NaN with 0
DataMat.F(isnan(DataMat.F)) = 0;

% Apply voltage units (in Brainstorm: recordings are stored in Volts)
switch (OPTIONS.VoltageUnits)
    case '\muV'
        DataMat.F = DataMat.F * 1e-6;
    case 'mV'
        DataMat.F = DataMat.F * 1e-3;
    case 'V'
        % Nothing to change
    case 'None'
        % Nothing to change
end
% Save number of trials averaged
DataMat.nAvg = OPTIONS.nAvg;

% Build comment
[fPath, fBase, fExt] = bst_fileparts(DataFile);
DataMat.Comment = fBase;


