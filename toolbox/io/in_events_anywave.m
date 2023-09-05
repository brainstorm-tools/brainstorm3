function events = in_events_anywave(sFile, EventFile)
% IN_EVENTS_ANYWAVE: Read the events descriptions for a AnyWave file.
%
% USAGE:  events = in_events_anywave(sFile, EventFile)
%
% REFERENCE: https://meg.univ-amu.fr/wiki/AnyWave:ADES#The_marker_file_.28.mrk.29

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
% Authors: Konstantinos Nasiotis, 2020
%          Francois Tadel, 2022

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

if isempty(dataArray) || isempty(dataArray{1})
    events = [];
    return;
end

% Convert the contents of columns containing numeric text to numbers.
% Replace non-numeric text with NaN.
raw = repmat({''},length(dataArray{1}),length(dataArray)-1);
for col=1:length(dataArray)-1
    raw(1:length(dataArray{col}),col) = dataArray{col};
end
numericData = NaN(size(dataArray{1},1),size(dataArray,2));

for col=[2,3,4]
    % Converts text in the input cell array to numbers. Replaced non-numeric
    % text with NaN.
    rawData = dataArray{col};
    for row=1:size(rawData, 1)
        % Create a regular expression to detect and remove non-numeric prefixes and
        % suffixes.
        regexstr = '(?<prefix>.*?)(?<numbers>([-]*(\d+[\,]*)+[\.]{0,1}\d*[eEdD]{0,1}[-+]*\d*[i]{0,1})|([-]*(\d+[\,]*)*[\.]{1,1}\d+[eEdD]{0,1}[-+]*\d*[i]{0,1}))(?<suffix>.*)';
        try
            result = regexp(rawData{row}, regexstr, 'names');
            numbers = result.numbers;
            
            % Detected commas in non-thousand locations.
            invalidThousandsSeparator = false;
            if any(numbers==',')
                thousandsRegExp = '^\d+?(\,\d{3})*\.{0,1}\d*$';
                if isempty(regexp(numbers, thousandsRegExp, 'once'))
                    numbers = NaN;
                    invalidThousandsSeparator = true;
                end
            end
            % Convert numeric text to numbers.
            if ~invalidThousandsSeparator
                numbers = textscan(strrep(numbers, ',', ''), '%f');
                numericData(row, col) = numbers{1};
                raw{row, col} = numbers{1};
            end
        catch me
        end
    end
end

% Split data into numeric and cell columns.
rawNumericColumns = raw(:, [2,3,4]);
rawCellColumns = raw(:, [1,5,6]);

% Replace non-numeric cells with NaN
R = cellfun(@(x) ~isnumeric(x) && ~islogical(x),rawNumericColumns); % Find non-numeric cells
rawNumericColumns(R) = {NaN}; % Replace non-numeric cells

% Allocate imported array to column variable names
Label           = rawCellColumns(:, 1);
frequencies     = cell2mat(rawNumericColumns(:, 1));
times           = cell2mat(rawNumericColumns(:, 2));
duration        = cell2mat(rawNumericColumns(:, 3));
OptionalCol     = rawCellColumns(:, [2,3]);


%% ===== DETECT CHANNELS/COLORS =====
Color = cell(1, size(Label,1));
Channels = cell(1, size(Label,1));
for iMrk = 1:size(OptionalCol,1)
    for iCol = 1:size(OptionalCol,2)
        % Empty column
        if isempty(OptionalCol{iMrk,iCol})
            continue;
        % Color: #RRGGBB
        elseif (OptionalCol{iMrk,iCol}(1) == '#')
            if (length(OptionalCol{iMrk,iCol}) == 7)
                Color{iMrk} = [hex2dec(OptionalCol{iMrk,iCol}(2:3)), hex2dec(OptionalCol{iMrk,iCol}(4:5)), hex2dec(OptionalCol{iMrk,iCol}(6:7))] ./ 255;
            end
        % Channel names: separated with commas
        else
            Channels{iMrk} = str_split(OptionalCol{iMrk,iCol}, ',');
        end
    end
end


%% ===== DETECT NOTES =====
% Second column of the file: contains an integer, most likely a frequency, or -1 if not defined
Notes = cell(1, size(Label,1));
for iMrk = 1:size(OptionalCol,1)
    % No value
    if isnan(frequencies(iMrk)) || (frequencies(iMrk) == -1)
        continue;
    end
    % Frequency value
    Notes{iMrk} = [num2str(frequencies(iMrk)) ' Hz'];
end


%% ===== ADD FIRST CHANNEL TO EVENT LABEL ======
% Get rid of the EEG prefix on the electrode channels and combine with the event label
for iMrk = 1:length(Label)
    if ~isempty(Channels{iMrk})
        Label{iMrk} = [Label{iMrk}, ' ', strtrim(strrep(Channels{iMrk}{1}, 'EEG', ''))];
    end
end


%% ===== CREATE BRAINSTORM STRUCTURE =====
% Initialize returned structure
events = repmat(db_template('event'), 0);
% Create one category of event per label
uniqueLabels = unique(Label);
for i = 1:length(uniqueLabels)
    % Add a new event category
    iEvt = length(events) + 1;
    iOcc = find(strcmp(Label, uniqueLabels{i}));
    % Add event structure
    events(iEvt).label = uniqueLabels{i};
    events(iEvt).epochs = ones(1,length(iOcc));
    % Extended events
    if all(duration(iOcc) == 0)
        events(iEvt).times = times(iOcc)';
    else
        events(iEvt).times = [times(iOcc)'; times(iOcc)' + duration(iOcc)'];
    end
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).color      = Color{iOcc(1)};
    events(iEvt).channels   = Channels(iOcc);
    events(iEvt).notes      = Notes(iOcc);
end
