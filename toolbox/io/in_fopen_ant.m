function [sFile, ChannelMat] = in_fopen_ant(DataFile)
% IN_FOPEN_ANT: Open an ANT EEProbe .cnt file (continuous recordings).
%
% USAGE:  [sFile, ChannelMat] = in_fopen_ant(DataFile)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2017
        

%% ===== READ HEADER =====
% Read a small block of data, to get all the extra information
hdr = eepv4_read_info(DataFile);
% Copy some fields for backward compatibility with previous versions of the library
hdr.nsample = hdr.sample_count;

% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-ANT-CNT';
sFile.prop.sfreq = double(hdr.sample_rate);
sFile.device     = 'ANT';
sFile.header     = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;
% Time and samples indices
sFile.prop.samples = [0, hdr.sample_count - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% Get bad channels
sFile.channelflag = ones(hdr.channel_count, 1);


%% ===== EVENTS =====
if isfield(hdr, 'triggers') && ~isempty(hdr.triggers)
    % Get list of events
    allNames = {hdr.triggers.label};
    [uniqueEvt, iUnique] = unique(allNames);
    uniqueEvt = allNames(sort(iUnique));
    % Initialize list of events
    events = repmat(db_template('event'), 1, length(uniqueEvt));
    % Format list
    for iEvt = 1:length(uniqueEvt)
        % Ask for a label
        events(iEvt).label      = uniqueEvt{iEvt};
        events(iEvt).color      = [];
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        % Find list of occurences of this event
        iOcc = find(strcmpi(allNames, uniqueEvt{iEvt}));
        % Get time and samples
        events(iEvt).samples = round([hdr.triggers(iOcc).seconds_in_file] .* sFile.prop.sfreq);
        events(iEvt).times   = events(iEvt).samples ./ sFile.prop.sfreq;
        % Epoch: set as 1 for all the occurrences
        events(iEvt).epochs = ones(1, length(events(iEvt).samples));
    end
    % Import this list
    sFile = import_events(sFile, [], events);
    
%% ===== EXTERNAL EVENT FILE =====   
else
    % If a .trg file exists with the same name: load it
    [fPath, fBase, fExt] = bst_fileparts(DataFile);
    TrgFile = bst_fullfile(fPath, [fBase '.trg']);
    % If file exists
    if file_exist(TrgFile)
        sFile = import_events(sFile, [], TrgFile, 'ANT');
    end
end


%% ===== CREATE DEFAULT CHANNEL FILE =====
% Create channel structure
Channel = repmat(db_template('channeldesc'), [1 hdr.channel_count]);
for i = 1:hdr.channel_count
    Channel(i).Name    = hdr.channels(i).label;
    Channel(i).Type    = 'EEG';
    Channel(i).Orient  = [];
    Channel(i).Weight  = 1;
    Channel(i).Comment = [];
    Channel(i).Loc = [0; 0; 0];
end
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'ANT standard position';
ChannelMat.Channel = Channel;
     



