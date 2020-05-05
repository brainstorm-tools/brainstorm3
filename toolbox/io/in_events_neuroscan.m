function events = in_events_neuroscan(sFile, EventFile)
% IN_EVENTS_NEUROSCAN: Read marker information from Neuroscan .ev2 files 
%
% DESCRIPTION:
%     The .ev2 files are simple text files, one event per line:
%     <index> <value> <response> <accuracy> <response_time> <sample_offset>  

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
% Authors: Francois Tadel, 2013

% Open file
fid = fopen(EventFile, 'r');
if (fid < 0)
    error('Cannot open marker file.');
end
% Read file
mrk = textscan(fid, '%d %s %s %f %f %d');
% Close file
fclose(fid);

% === PROCESS STIM ===
% List of events
uniqueStim = setdiff(unique(mrk{2}), '0');
uniqueResp = setdiff(unique(mrk{3}), '0');
% Initialize returned structure
events = repmat(db_template('event'), [1, length(uniqueStim) + length(uniqueResp)]);
% Create events list
for iEvt = 1:length(uniqueStim)
    % Find all the occurrences of event #iEvt
    iMrk = find(strcmpi(mrk{2}, uniqueStim{iEvt}));
    % Add event structure
    events(iEvt).label   = ['Stim ' uniqueStim{iEvt}];
    events(iEvt).epochs  = ones(1, length(iMrk));
    events(iEvt).times   = double(mrk{6}(iMrk)') ./ sFile.prop.sfreq;
    events(iEvt).select  = 1;
    if any(mrk{5}(iMrk) ~= 0)
        events(iEvt).reactTimes = mrk{5}(iMrk)';
    else
        events(iEvt).reactTimes = [];
    end
    events(iEvt).channels = cell(1, size(events(iEvt).times, 2));
    events(iEvt).notes    = cell(1, size(events(iEvt).times, 2));
end

% === PROCESS RESPONSE ===
for iEvt = 1:length(uniqueResp)
    iEvtAll = length(uniqueStim) + iEvt;
    % Find all the occurrences of event #iEvt
    iMrk = find(strcmpi(mrk{3}, uniqueResp{iEvt}));
    % Add event structure
    events(iEvtAll).label   = ['Resp ' uniqueResp{iEvt}];
    events(iEvtAll).epochs  = ones(1, length(iMrk));
    events(iEvtAll).times   = double(mrk{6}(iMrk)') ./ sFile.prop.sfreq;
    events(iEvtAll).select  = 1;
    if any(mrk{5}(iMrk) ~= 0)
        events(iEvtAll).reactTimes = mrk{5}(iMrk)';
    else
        events(iEvtAll).reactTimes = [];
    end
    events(iEvtAll).channels = cell(1, size(events(iEvtAll).times, 2));
    events(iEvtAll).notes    = cell(1, size(events(iEvtAll).times, 2));
end

