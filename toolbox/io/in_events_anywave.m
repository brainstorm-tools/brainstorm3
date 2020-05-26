function events = in_events_anywave(sFile, EventFile)
% IN_EVENTS_ANYWAVE: Read the events descriptions for a AnyWave file.
%
% USAGE:  events = in_events_anywave(sFile, EventFile)

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
% Authors: Konstantinos Nasiotis, 2020

%% Matlab generated script - LOAD THE EVENT FILE
% Initialize variables.

delimiter = '\t';
startRow = 2;

% Read columns of data as text:
% For more information, see the TEXTSCAN documentation.
formatSpec = '%s%s%s%s%s%s%[^\n\r]';

% Open the text file.
fileID = fopen(EventFile,'r');

% Read columns of data according to the format.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');

% Close the text file.
fclose(fileID);

% Convert the contents of columns containing numeric text to numbers.
% Replace non-numeric text with NaN.
raw = repmat({''},length(dataArray{1}),length(dataArray)-1);
for col=1:length(dataArray)-1
    raw(1:length(dataArray{col}),col) = dataArray{col};
end
numericData = NaN(size(dataArray{1},1),size(dataArray,2));

for col=[2,3,4,6]
    % Converts text in the input cell array to numbers. Replaced non-numeric
    % text with NaN.
    rawData = dataArray{col};
    for row=1:size(rawData, 1);
        % Create a regular expression to detect and remove non-numeric prefixes and
        % suffixes.
        regexstr = '(?<prefix>.*?)(?<numbers>([-]*(\d+[\,]*)+[\.]{0,1}\d*[eEdD]{0,1}[-+]*\d*[i]{0,1})|([-]*(\d+[\,]*)*[\.]{1,1}\d+[eEdD]{0,1}[-+]*\d*[i]{0,1}))(?<suffix>.*)';
        try
            result = regexp(rawData{row}, regexstr, 'names');
            numbers = result.numbers;
            
            % Detected commas in non-thousand locations.
            invalidThousandsSeparator = false;
            if any(numbers==',');
                thousandsRegExp = '^\d+?(\,\d{3})*\.{0,1}\d*$';
                if isempty(regexp(numbers, thousandsRegExp, 'once'));
                    numbers = NaN;
                    invalidThousandsSeparator = true;
                end
            end
            % Convert numeric text to numbers.
            if ~invalidThousandsSeparator;
                numbers = textscan(strrep(numbers, ',', ''), '%f');
                numericData(row, col) = numbers{1};
                raw{row, col} = numbers{1};
            end
        catch me
        end
    end
end


% Split data into numeric and cell columns.
rawNumericColumns = raw(:, [2,3,4,6]);
rawCellColumns = raw(:, [1,5]);


% Replace non-numeric cells with NaN
R = cellfun(@(x) ~isnumeric(x) && ~islogical(x),rawNumericColumns); % Find non-numeric cells
rawNumericColumns(R) = {NaN}; % Replace non-numeric cells

% Allocate imported array to column variable names
Label           = rawCellColumns(:, 1);
frequencies     = cell2mat(rawNumericColumns(:, 1));
times           = cell2mat(rawNumericColumns(:, 2));
VarName13       = cell2mat(rawNumericColumns(:, 3));
Electrode_label = rawCellColumns(:, 2);
VarName15       = cell2mat(rawNumericColumns(:, 4));

% Clear temporary variables
clearvars filename delimiter startRow formatSpec fileID dataArray ans raw col numericData rawData row regexstr result numbers invalidThousandsSeparator thousandsRegExp me rawNumericColumns rawCellColumns R;


%% Combine electrode and label

% Get rid of the EEG prefix on the electrode channels and combine with the
% event label
all_event_labels = cell(length(Electrode_label),1);
for iEvent = 1:length(Electrode_label)
    Electrode_label{iEvent} = erase(Electrode_label{iEvent}, {'EEG',','});
    all_event_labels{iEvent} = [Label{iEvent} ' ' Electrode_label{iEvent}];
end

[uniqueLabels, ia, iAssignmentOnUniqueLabels] =unique(all_event_labels);


%% Add everything in the brainstorm format

% Initialize returned structure
events = repmat(db_template('event'), 0);
% Triggers
if ~isempty(uniqueLabels)
    % Create events structures: one per category of event
    for i = 1:length(uniqueLabels)
        % Add a new event category
        iEvt = length(events) + 1;
        
        % Add event structure
        events(iEvt).label      = uniqueLabels{i};
        events(iEvt).epochs     = ones(1,sum(iAssignmentOnUniqueLabels == i));
        events(iEvt).times      = times(iAssignmentOnUniqueLabels == i)';
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).color      = rand(1,3);
        events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
        
        all_frequencies = frequencies(iAssignmentOnUniqueLabels == i);
        for iNote = 1:sum(iAssignmentOnUniqueLabels == i)
            events(iEvt).notes{iNote}  = [num2str(all_frequencies(iNote)) ' Hz'];
        end
    end
end



