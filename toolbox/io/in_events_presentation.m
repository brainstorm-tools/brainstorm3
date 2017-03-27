function events = in_events_presentation(sFile, EventFile)
% IN_EVENTS_PRESENTATION: Read stimulation times from Presentation software (.log files)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Robert Oostenveld, 2017

% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    error('Cannot open marker file.');
end
% Skip first line
tmp = fgetl(fid);
% Read file
mrk = textscan(fid, '%*d %*s %s %d');
% Close file
fclose(fid);

% List of events
uniqueEvt = unique(mrk{1});
% Initialize returned structure
events = repmat(db_template('event'), [1, length(uniqueEvt)]);
% Create events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of event #iEvt
    iMrk = find(strcmpi(mrk{1}, uniqueEvt{iEvt}));
    % Add event structure
    events(iEvt).label   = uniqueEvt{iEvt};
    events(iEvt).epochs  = ones(1, length(iMrk));
    events(iEvt).times   = double(mrk{2}(iMrk)') .* 1e-4;
    events(iEvt).samples = round(events(iEvt).times .* sFile.prop.sfreq);
    events(iEvt).reactTimes  = [];
    events(iEvt).select      = 1;
end



