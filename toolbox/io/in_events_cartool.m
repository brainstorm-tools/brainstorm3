function events = in_events_cartool(sFile, EventFile)
% IN_EVENTS_CARTOOL: Read marker information from Cartool .mrk files 
%
% OUTPUT:
%    - events(i): array of structures with following fields (one structure per event type) 
%        |- label   : Identifier of event #i
%        |- samples : Array of unique time indices for event #i in the corresponding raw file
%        |- times   : Array of unique time latencies (in seconds) for event #i in the corresponding raw file

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2015

% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    error('Cannot open marker file.');
end
% Skip first line
tmp = fgetl(fid);
% Read file
mrkFile = textscan(fid, '%d %d %s');
% Close file
fclose(fid);
% File interpretation
mrk = double([mrkFile{1}, mrkFile{2}]');
if isequal(mrk(1,:), mrk(2,:))
    mrk = mrk(1,:);
end
labels = strrep(mrkFile{3}, '"', '');

% List of events
uniqueEvt = unique(labels);
% Initialize returned structure
events = repmat(db_template('event'), [1, length(uniqueEvt)]);
% Create events list
for iEvt = 1:length(uniqueEvt)
    % Find all the occurrences of event #iEvt
    iMrk = find(strcmpi(labels, uniqueEvt{iEvt}));
    % Add event structure
    events(iEvt).label      = uniqueEvt{iEvt};
    events(iEvt).epochs     = ones(1, length(iMrk));
    events(iEvt).times      = mrk(:,iMrk) ./ sFile.prop.sfreq;
    events(iEvt).reactTimes = [];
    events(iEvt).select     = 1;
    events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
    events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
end



