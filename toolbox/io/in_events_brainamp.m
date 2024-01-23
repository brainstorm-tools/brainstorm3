function events = in_events_brainamp(sFile, ChannelMat, EventFile)
% IN_EVENTS_BRAINAMP: Open a BrainVision BrainAmp .vmrk file.
%
% OUTPUT:
%    - events(i): array of structures with following fields (one structure per event type) 
%        |- label   : Identifier of event #i
%        |- samples : Array of unique time indices for event #i in the corresponding raw file
%        |- times   : Array of unique time latencies (in seconds) for event #i in the corresponding raw file
%                     => Not defined for files read from -eve.fif files

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
% Authors: Francois Tadel, 2012
%          Raymundo Cassani, 2024


% Open and read file
fid = fopen(EventFile,'r');
% Markers list
Markers = {};
isMarkerSection = 0;
% Read file line by line
while 1
    % Read one line
    newLine = fgetl(fid);
    if ~ischar(newLine)
        break;
    end
    % Lines to skip
    if isempty(newLine)
        continue;
    elseif ~isempty(strfind(lower(newLine), '[marker infos]'))
        isMarkerSection = 1;
    elseif ~isMarkerSection || ismember(newLine(1), {'[', ';', char(10), char(13)}) || ~any(newLine == '=')
        continue;
    end
    % Find the first '=' (and marker names start with 'Mk')
    iEqual = find(newLine == '=', 1);
    if isempty(iEqual) || (iEqual < 3) || (iEqual == length(newLine)) || ~strcmpi(newLine(1:2), 'Mk')
        continue;
    end
    % Split around the '=' and ','
    argLine = strtrim(str_split(newLine(iEqual+1:end) , ',', 0));
    if (length(argLine) < 5)
        continue;
    end
    % Marker label
    if ~isempty(argLine{2})
        mlabel = argLine{2};
    else
        mlabel = 'Mk';
    end
    % Marker channels
    if str2num(argLine{5}) == 0
        channels = {[]};
    else
        channels = {{ChannelMat.Channel(str2num(argLine{5})).Name}};
    end
    % Add markers entry: {name, type, start, length}
    Markers(end+1,:) = {mlabel, argLine{1}, str2num(argLine{3}), str2num(argLine{4}), channels};
end
% Close file
fclose(fid);

% List of events
if isempty(Markers)
    uniqueEvt = [];
else
    uniqueEvt = unique(Markers(:,1)');
end
% Initialize returned structure
events = repmat(db_template('event'), [1, length(uniqueEvt)]);
% Create events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of event #iEvt
    iMrk = find(strcmpi(Markers(:,1)', uniqueEvt{iEvt}));
    % Add event structure
    events(iEvt).label   = uniqueEvt{iEvt};
    events(iEvt).epochs  = ones(1, length(iMrk));   
    samples = [Markers{iMrk,3}];
    if any([Markers{iMrk,4}] > 1)
        samples(2,:) = [Markers{iMrk,3}] + [Markers{iMrk,4}];
    end
    events(iEvt).times      = samples ./ sFile.prop.sfreq;
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).notes      = [];
    if all(cellfun(@isempty, [Markers{iMrk,5}]))
        events(iEvt).channels = [];
    else
        % Handle channel-wise events
        events(iEvt).channels = [Markers{iMrk,5}];
    end
end

% Merge channel-wise events with same times
for iEvt = 1:length(events)
    if ~isempty(events(iEvt).channels)
        % Find occurrences with channel
        iwChannel = find(~cellfun(@isempty, [events(iEvt).channels]));
        iwDelete = [];
        for iw = 1 : length(iwChannel)
            if ~ismember(iw, iwDelete)
                % Find others channel-wise events with the same time, and not to be deleted yet
                iwOthers = find(all(bsxfun(@eq, events(iEvt).times(:,iw), events(iEvt).times), 1));
                % Exclude own
                iwOthers = setdiff(iwOthers, iw);
                % Only consider ones with channel
                iwOthers = intersect(iwOthers, iwChannel);
                for ix = 1 : length(iwOthers)
                    % Append the channel names
                    events(iEvt).channels{iw} = [events(iEvt).channels{iw}, events(iEvt).channels{iwOthers(ix)}];
                    iwDelete = [iwDelete, iwOthers(ix)];
                end
            end
        end
        events(iEvt).epochs(iwDelete) = [];
        events(iEvt).times(:,iwDelete) = [];
        events(iEvt).channels(:,iwDelete) = [];
    end
end


