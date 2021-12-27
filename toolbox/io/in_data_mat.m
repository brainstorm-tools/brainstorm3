function DataMat = in_data_mat( DataFile )
% IN_DATA_MAT: Read EEG recordings stored in a free .MAT file.

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
% Authors: Francois Tadel, 2009-2016


%% ===== GET OPTIONS =====
% Get options
OPTIONS = bst_get('ImportEegRawOptions');


%% ===== READ MATRIX FILE =====
% Read file
RawMat = load(DataFile);
% Get fields 
fields = fieldnames(RawMat);
validFields = {};
% Loop to find the possible fields
for i = 1:length(fields)
    if ~isempty(RawMat.(fields{i})) && isnumeric(RawMat.(fields{i})) && (numel(RawMat.(fields{i})) > 31)
        validFields{end+1} = fields{i};
    end
end
if isempty(validFields)
    DataMat = [];
    bst_error(['No valid recordings field in: "' DataFile '"'], 'Import EEG data', 0);
    return
end
% Ask user which field to use, if there is more than one
if (length(validFields) > 1)
    res = java_dialog('question', 'Please select the field that contains your EEG recordings:', ...
                      'Import EEG data', [], validFields);
    % If user did not answer: exit
    if isempty(res)
        DataMat = [];
        return
    end
else
    res = validFields{1};
end
% Use selected field
FileData = RawMat.(res);

% Check matrix orientation
switch OPTIONS.MatrixOrientation
    case 'channelXtime'
        % OK
    case 'timeXchannel'
        % Transpose needed
        FileData = permute(FileData, [2 1 3]);
end

% Build time vector
Time = ((0:size(FileData,2)-1) ./ OPTIONS.SamplingRate - OPTIONS.BaselineDuration);
% ChannelFlag
ChannelFlag = ones(size(FileData,1), 1);
% Apply voltage units (in Brainstorm: recordings are stored in Volts)
switch (OPTIONS.VoltageUnits)
    case '\muV'
        FileData = FileData * 1e-6;
    case 'mV'
        FileData = FileData * 1e-3;
    case 'V'
        % Nothing to change
    case 'None'
        % Nothing to change
end
% If only one time frame: double it
if (size(FileData, 2) == 1)
    FileData = repmat(FileData, [1 2 1]);
end
    
% If loading 3D matrix: 3rd dimension is the epoch list
nbEpoch = size(FileData, 3);

% Initialize returned structure
DataMat = db_template('datamat');
DataMat.Comment     = 'EEG/MAT';
DataMat.ChannelFlag = ChannelFlag;
DataMat.Time        = Time;
DataMat.Device      = 'Unknown';
DataMat.nAvg        = OPTIONS.nAvg;
DataMat = repmat(DataMat, [nbEpoch, 1]);

% Process each epoch
BaseComment = DataMat(1).Comment;
for i = 1:nbEpoch
    DataMat(i).F = double(FileData(:,:,i));
    % Add indice number for multiple epochs
    if (nbEpoch > 1)
        DataMat(i).Comment = sprintf('%s #%d', BaseComment, i);
    end
end



