function events = in_events_kdf(sFile, EventFile)
% IN_EVENTS_KDF: Read the events descriptions from a KRISS .trg file.
%
% USAGE:  events = in_events_kdf(sFile, EventFile)

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
% Authors: Francois Tadel, 2014

% Initialize returned variable
events = repmat(db_template('event'), 0);
% Load trigger file
EventDat = load(EventFile, '-ASCII');
if isempty(EventDat)
    return;
end

% Consider both the stim and responses as events of the same level
AllEvt = [EventDat(:,1:2); EventDat(EventDat(:,4)~=0, 3:4)];
% Get all the unique events
uniqueEvt = unique(AllEvt(:,2));
% Create events structures: one per category of event
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of event #iEvt
    iMrk = find(AllEvt(:,2) == uniqueEvt(iEvt));
    % Add event structure
    events(iEvt).label      = num2str(uniqueEvt(iEvt));
    events(iEvt).epochs     = ones(1, length(iMrk));
    events(iEvt).times      = AllEvt(iMrk,1)' ./ sFile.prop.sfreq;
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).channels   = [];
    events(iEvt).notes      = [];
end



