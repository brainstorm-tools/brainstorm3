function events = in_events_video(sFile, ChannelMat, EventFile, format)
% IN_EVENTS_VIDEO: Read video events information from a text file 
%
% USAGE:  events = in_events_array(sFile, ChannelMat, EventFile) 
% 
%   EventFile must be text file in the form hh:mm:ss:ff

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
% Authors: Francois Tadel, Elizabeth Bock, 2012-2014

%% ===== READ FILE =====
% Read text file
fid = fopen(EventFile);

nEvents = 0;
while(1)
    tline = fgetl(fid);
    if tline<0
        break;
    end
    % Convert string hh:mm:ss:ff -> hhmmssff
    spl = str_split(tline,':');
    nEvents = nEvents + 1;
    EventsMat(nEvents) = str2double([spl{1:4}]);
end
fclose(fid)


%% ===== CONVERT VIDEO TIME TO FILE TIME =====
% read the video channel from the recording
iVideo = find(strcmpi({ChannelMat.Channel(:).Type}, 'Video'));
if isempty(iVideo)
    error('No video time channel in this file');
end
[F, TimeVector] = in_fread(sFile, ChannelMat, [], round(sFile.prop.times .* sFile.prop.sfreq), iVideo);

% Read channel data for each event
iEvents = bst_closest(EventsMat, F);
eveTimes = TimeVector(iEvents);

%% ===== CONVERT TO BRAINSTORM STRUCTURE =====
% Initialize list of events
events = db_template('event');
% Ask for a label
res = java_dialog('input', 'Please enter a label for this event:', 'Event Label');
if isempty(res)
    events.label = '1';
else
    events.label = res;
end
events.times      = eveTimes;
events.epochs     = ones(1, length(eveTimes)); % Epoch: set as 1 for all the occurrences
events.color      = [];
events.reactTimes = [];
events.select     = 1;
events.channels   = cell(1, size(events.times, 2));
events.notes      = cell(1, size(events.times, 2));

