function out_events_video( sFile, ChannelMat, EventsFile )
% OUT_EVENTS_VIDEO: Export events to a text file with the corresponding video time stamp.
%
% USAGE:  out_events_video( sFile, ChannelMat, EventsFile )
%
%   video time hhmmssff -> hh:mm:ss:ff

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
% Authors: Francois Tadel, Elizabeth Bock, 2012-2014

%% ===== GET EVENTS =====
evt = sFile.events;
nEventGroups = length(evt);
% Must be a real link to a CTF file
if ~isfield(ChannelMat, 'Channel') || ~isfield(ChannelMat.Channel, 'Type')
    error('No video time channel in this file');
end
% Save file (ascii)
fout = fopen(EventsFile, 'w');
if (fout < 0)
    warning('Cannot open file.');
    return
end

%% ===== CONVERT EVENTS TO VIDEO TIME =====
iVideo = find(strcmpi({ChannelMat.Channel(:).Type}, 'Video'));
if isempty(iVideo)
    error('No video time channel in this file');
end
SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
[F, TimeVector] = in_fread(sFile, ChannelMat, [], SamplesBounds, iVideo);

% Read channel data for each event
videoTimes = [];
for i = 1:nEventGroups
    eventTimes = evt(i).times;
    iEvents = bst_closest(eventTimes, TimeVector);
    videoTimes = [videoTimes F(iEvents)];
end

%% ===== WRITE EVENTS TO FILE =====
for j = 1:length(videoTimes)
    % Format video time hhmmssff -> hh:mm:ss:ff
    str = '00000000';
    vidStr = num2str(videoTimes(j));
    vidStart = 8-length(vidStr)+1;
    str(vidStart:8) = vidStr;
    fprintf(fout, '%s:%s:%s:%s\n', str(1:2), str(3:4), str(5:6), str(7:8));
end
% Close file
fclose(fout);





