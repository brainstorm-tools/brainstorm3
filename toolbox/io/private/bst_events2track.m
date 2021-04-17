function track = bst_events2track( sFile, evtDuration )
% BST_EVENTS2TRACK: Converts a list of events into a digital track of data.
%
% USAGE:  track = bst_events2track( sFile, evtDuration )
%
% INPUT:
%     - sFile       : Structure representing a raw file open in Brainstorm
%     - evtDuration : Default duration (in time samples) for the events without temporal extension

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
% Authors: Francois Tadel, 2010-2013

% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(evtDuration)
    evtDuration = 1;
end

% ===== GET EVENTS VALUES =====
nEvt = length(sFile.events);
% evtVal = zeros(1, nEvt);
% for i = 1:nEvt
%     % Try to find a number in the event name
%     iStartInd = find(ismember(sFile.events(i).label, '1234567890'), 1);
%     if ~isempty(iStartInd)
%         evtVal(i) = sscanf(sFile.events(i).label(iStartInd:end), '%d');
%     end
% end
evtVal = 1:length(sFile.events);

% Events with no values in their names
iEvtZero = find(evtVal == 0);
tmpVal = 1;
for i = 1:length(iEvtZero)
    % Get the first value that is not already used by an event
    while ismember(tmpVal, evtVal)
        tmpVal = tmpVal + 1;
    end
    evtVal(iEvtZero(i)) = tmpVal;
end

% ===== BUILD DATA TRACK =====
% Initialize track with empty values
nSamples = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq) + 1;
track = zeros(1, nSamples);
% Add events one by one to the track
for i = 1:nEvt
    % If no occurrences: skip
    if isempty(sFile.events(i).times)
        continue;
    end
    % Get list of samples to set to this event
    samples = [];
    for iOccur = 1:size(sFile.events(i).times, 2)
        occ = round(sFile.events(i).times(:,iOccur) .* sFile.prop.sfreq);
        % Single events
        if (size(occ, 1) == 1)
            samples = [samples, occ + (1:evtDuration)];
        % Extended events
        else
            if (occ(1) ~= occ(2))
                samples = [samples, occ(1)+1:occ(2)];
            else
                samples = [samples, occ(1):occ(2)];
            end
        end
    end
    % If FIF events track: remove the first sample offset
    if strcmpi(sFile.format, 'FIF')
        samples = samples - double(sFile.header.raw.first_samp);
    else
        samples = samples - round(sFile.prop.times(1) .* sFile.prop.sfreq) + 1;
    end
    
    % Check if any of those samples was already attributed to another event
    if any(track(samples) ~= 0)
        error(['Cannot export tracks with more than one event at each time instant.', 10, 'Please export events separately.']);
    end
    % Set track value
    track(samples) = evtVal(i);
end







