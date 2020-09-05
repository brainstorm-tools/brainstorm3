function events = in_events_ricoh(sFile, EventFile)
% IN_EVENTS_RICOH: Read the events descriptions for a RICOH MEG file.
%
% USAGE:  events = in_events_ricoh(sFile, EventFile)
%
% This function is based on the Ricoh MEG reader toolbox version 1.0.
% For copyright and license information and software documentation, 
% please refer to the contents of the folder brainstorm3/external/ricoh

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
% Authors: Francois Tadel, 2018

% Read file info using Ricoh functions
header.events     = getRHdrEvent(EventFile);       % Get information about trigger events.
header.annotation = getRHdrAnnotation(EventFile);  % Get information about annotations.

% Initialize returned structure
events = repmat(db_template('event'), 0);
% Triggers
if ~isempty(header.events)
    % All all the events types
    uniqueNames = unique({header.events.name});
    % Create events structures: one per category of event
    for i = 1:length(uniqueNames)
        % Add a new event category
        iEvt = length(events) + 1;
        % Find all the occurrences of event #iEvt
        iMrk = find(strcmpi({header.events.name}, uniqueNames{i}));
        % Get all samples
        allSamples = [header.events(iMrk).sample_no];
        % Get the epoch numbers (only ones for continuous and averaged files)
        if (sFile.header.acq.acq_type == 1) || (sFile.header.acq.acq_type == 2) 
            iEpochs = ones(1, length(iMrk));
        else
            iEpochs = floor(allSamples / sFile.header.acq.frame_length) + 1;
            allSamples = allSamples - (iEpochs-1) .* sFile.header.acq.frame_length;
        end
        % Add event structure
        events(iEvt).label      = uniqueNames{i};
        events(iEvt).epochs     = iEpochs;
        events(iEvt).times      = allSamples ./ sFile.prop.sfreq;
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
        events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
    end
end
% Annotations
if ~isempty(header.annotation)
    % Get annotation label
    annotLabel = cell(1,length(header.annotation));
    for i = 1:length(header.annotation)
        if ~isempty(strtrim(header.annotation(i).comment))
            annotLabel{i} = strtrim(header.annotation(i).comment);
            annotLabel{i}(annotLabel{i} == 0) = [];
        elseif ~isempty(header.annotation(i).label) && isnumeric(header.annotation(i).label)
            annotLabel{i} = ['annot_', num2str(header.annotation(i).label)];
        else
            annotLabel{i} = 'Unknown';
        end
    end
        
    % All all the events types
    uniqueNames = unique(annotLabel);
    % Create events structures: one per category of event
    for i = 1:length(uniqueNames)
        % Add a new event category
        iEvt = length(events) + 1;
        % Find all the occurrences of event #iEvt
        iMrk = find(strcmpi(annotLabel, uniqueNames{i}));
        % Get all samples
        allSamples = [header.annotation(iMrk).sample_no];
        % Get the epoch numbers (only ones for continuous and averaged files)
        if (sFile.header.acq.acq_type == 1) || (sFile.header.acq.acq_type == 2) 
            iEpochs = ones(1, length(iMrk));
        else
            iEpochs = floor(allSamples / sFile.header.acq.frame_length) + 1;
            allSamples = allSamples - (iEpochs-1) .* sFile.header.acq.frame_length;
        end
        % Add event structure
        events(iEvt).label      = uniqueNames{i};
        events(iEvt).epochs     = iEpochs;
        events(iEvt).times      = allSamples ./ sFile.prop.sfreq;
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
        events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
    end
end



