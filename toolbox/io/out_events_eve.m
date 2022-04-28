function out_events_eve( sFile, EventsFile )
% OUT_EVENTS_EVE: Export events to a Neuromag/MNE .eve file.
%
% USAGE:  out_events_eve( sFile, EventsFile )

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
% Authors: Francois Tadel, 2010

% Build a data track for the events
track = bst_events2track( sFile, 1 );
% Detect value changes
diffTrack = diff([track(1), track]);
iChange = find(diffTrack ~= 0);
% If not events: error
if isempty(iChange)
    error('No events selected.');
end

% Get initial time offset
if strcmpi(sFile.format, 'FIF') && isfield(sFile.header, 'raw') && ~isempty(sFile.header.raw.first_samp)
    offsetSample = sFile.header.raw.first_samp;
else
    offsetSample = 0;
end

% Save file (ascii)
fout = fopen(EventsFile, 'w');
if (fout < 0)
    warning('Cannot open file.');
    return
end
% Write all the value changes
for i = 1:length(iChange)
    % Get time and sample value
    evtSample = offsetSample + iChange(i) - 1;
    evtTime = double(evtSample) ./ double(sFile.prop.sfreq);
    % Write event to file
    fprintf(fout, '%8d %10.4f     %6d    %6d\n', evtSample, evtTime, track(iChange(i) - 1), track(iChange(i)));
end
% Close file
fclose(fout);





