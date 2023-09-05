function events = in_events_kit(sFile, EventFile)
% IN_EVENTS_KIT: Read the events descriptions for a Yokogawa/KIT file.
%
% USAGE:  events = in_events_kit(sFile, EventFile)
%
% This function is based on the Yokogawa MEG reader toolbox version 1.4.
% For copyright and license information and software documentation, 
% please refer to the contents of the folder brainstorm3/external/yokogawa

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
% Authors: Francois Tadel, 2013


% Read file info using Yokogawa functions
header.events   = getYkgwHdrEvent(EventFile);     % Get information about trigger events.
header.bookmark = getYkgwHdrBookmark(EventFile);  % Get information about bookmark.

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
        events(iEvt).channels   = [];
        events(iEvt).notes      = [];
    end
end
% Bookmarks
if ~isempty(header.bookmark)
    % All all the events types
    uniqueNames = unique({header.bookmark.label});
    % Create events structures: one per category of event
    for i = 1:length(uniqueNames)
        % Add a new event category
        iEvt = length(events) + 1;
        % Find all the occurrences of event #iEvt
        iMrk = find(strcmpi({header.bookmark.label}, uniqueNames{i}));
        % Add event structure
        events(iEvt).label      = uniqueNames{i};
        events(iEvt).epochs     = ones(1, length(iMrk));
        events(iEvt).times      = header.bookmark(iMrk).sample_no ./ sFile.prop.sfreq;
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).channels   = [];
        events(iEvt).notes      = [];
    end
end



