function out_events_bids( sFile, EventsFile )
% OUT_EVENTS_BIDS: export a BIDS _events.tsv file (columns "onset", "duration", "trial_type").
%
% USAGE:  out_events_bids( sFile, EventsFile )

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
% Authors: Edouard Delaire, 2024
%          Raymundo Cassani, 2025

% Concatenate all the events together
allTime = zeros(2,0);
allInd  = [];
allCha  = {};
% Convert event real timing (Brainstorm) to onset (latencies) from the first sample in the file
% See specs: https://bids-specification.readthedocs.io/en/stable/04-modality-specific-files/05-task-events.html
for i = 1:length(sFile.events)
    % Simple events
    if (size(sFile.events(i).times, 1) == 1)
        allTime = [allTime, [sFile.events(i).times - sFile.prop.times(1); 0*sFile.events(i).times]];
    % Extented events
    elseif (size(sFile.events(i).times, 1) == 2)
        allTime = [allTime, sFile.events(i).times - sFile.prop.times(1)];
    end
    allInd = [allInd, repmat(i, 1, size(sFile.events(i).times,2))];
    % Channel info
    if isempty(sFile.events(i).channels)
        evtCha = repmat({[]}, 1, size(sFile.events(i).times,2));
    else
        evtCha = sFile.events(i).channels;
    end
    allCha = [allCha, evtCha];
end
% Sort based on time
[tmp, iSort] = sort(allTime(1,:));
% Apply sorting to both arrays
allTime = allTime(:,iSort);
allInd  = allInd(iSort);
allCha  = allCha(iSort);
anyChannelwise = any(~cellfun(@isempty, allCha));

% Save file (ascii)
fout = fopen(EventsFile, 'w');
if (fout < 0)
    warning('Cannot open file.');
    return
end

% Write header
header_format = '%s\t%s\t%s';
header_names  = {'onset', 'duration', 'trial_type'};
if anyChannelwise
    header_format = [header_format, '\t%s'];
    header_names  = [header_names, {'channel'}];
end
fprintf(fout, [header_format, '\n'], header_names{:});
%fprintf(fout,'%s\t%s\t%s\n', 'onset', 'duration', 'trial_type');

% Write all the events, one by line
event_format = '%g\t%g\t%s';
if anyChannelwise
    event_format = [event_format, '\t%s'];
end

for i = 1:length(allInd)
    % Get event structure
    sEvt = sFile.events(allInd(i));
    % Simple events
    if (size(sEvt.times, 1) == 1)
        event_values = {allTime(1,i), 0, sEvt.label};
    % Extended events
    elseif (size(sEvt.times, 1) == 2)
        event_values = {allTime(1,i), allTime(2,i) - allTime(1,i), sEvt.label};
    end
    % Channel information
    if anyChannelwise
        % Add empty channel (all channels)
        event_values = [event_values, {[]}];
        % Save one event entry for each indicated channel
        if ~isempty(allCha{i})
            for ic = 1 : numel(allCha{i})
                event_values{end} = allCha{i}{ic};
                fprintf(fout, [event_format, '\n'], event_values{:});
            end
        else
            fprintf(fout, [event_format, '\n'], event_values{:});
        end
    else
        fprintf(fout, [event_format, '\n'], event_values{:});
    end
end
% Close file
fclose(fout);





