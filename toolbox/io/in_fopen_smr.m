function [sFile, ChannelMat] = in_fopen_smr(DataFile)
% IN_FOPEN_SMR: Open a Cambridge Electronic Design Spike2 file (.smr/.son).

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
% Authors:  Malcolm Lidierth, 2006-2007, King's College London
%           Adapted by Francois Tadel for Brainstorm, 2017-2021


%% ===== READ HEADER =====
% Get file type
[fPath, fBase, fExt]=fileparts(DataFile);
if strcmpi(fExt,'.smr') || strcmpi(fExt,'.smrx')
    byteorder = 'l';  % Spike2 for Windows source file: little-endian
elseif strcmpi(fExt,'.son')
    byteorder = 'b';  % Spike2 for Mac file: Big-endian
else
    error('Not a Spike2 file.');
end
% Open file
fid = fopen(DataFile, 'r', byteorder);
if (fid == -1)
    error('Could not open file.');
end

% Get file header
hdr = SONFileHeader(fid);
% Get list of channels
iChan = 0;
iMarkerChan = [];
for i = 1:hdr.channels
    bst_progress('text', sprintf('Reading channel info... [%d%%]', round(i/hdr.channels*100)));
    % Read channel information
    c = SONChannelInfo(fid, i);
    % Check type of the channel
    switch c.kind
        % ADC channels: read as signals
        case {1,9}
            iChan = iChan + 1;
            hdr.chaninfo(iChan).number    = i;
            hdr.chaninfo(iChan).kind      = c.kind;
            hdr.chaninfo(iChan).title     = c.title;
            hdr.chaninfo(iChan).comment   = c.comment;
            hdr.chaninfo(iChan).phyChan   = c.phyChan;
            hdr.chaninfo(iChan).idealRate = c.idealRate;
            % Read blocks
            hdr.chaninfo(iChan).blocks = SONGetBlockHeaders(fid, i);
        % Markers and events
        case {2,3,4,5,6,7,8}
        	iMarkerChan(end+1) = i;
    end
end
hdr.num_channels = length(hdr.chaninfo);
% Get maximum sampling rate
[sfreq, chMax] = max([hdr.chaninfo.idealRate]);


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder    = byteorder;
sFile.filename     = DataFile;
sFile.format       = 'EEG-SMR';
sFile.prop.sfreq   = sfreq;
sFile.prop.times   = [0, sum(hdr.chaninfo(chMax).blocks(5,:)) - 2] ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
sFile.channelflag  = ones(hdr.num_channels,1);
sFile.device       = 'CED Spike2';
sFile.header       = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.num_channels]);
% For each channel
for iChan = 1:hdr.num_channels
    ChannelMat.Channel(iChan).Type = 'EEG';
    ChannelMat.Channel(iChan).Name = hdr.chaninfo(iChan).title;
end


%% ===== READ MARKER INFORMATION =====
iChanMissing = [];
for iChan = 1:length(iMarkerChan)
    % Read channel
    try
        [d,header] = SONGetChannel(fid, iMarkerChan(iChan));
    catch
        iChanMissing = [iChanMissing, iMarkerChan(iChan)];
        continue;
    end
    if isempty(d) || isempty(header)
        continue;
    end
    % Get timing
    switch (header.kind)
        case {2,3,4}
            timeEvt = d(:)';
        case {5,6,7,8}
            timeEvt = d.timings(:)';
    end
    % Create event structure
    iEvt = length(sFile.events) + 1;
    if ~isempty(header.title)
        sFile.events(iEvt).label = header.title;
    else
        sFile.events(iEvt).label = sprintf('unknown_%02d', iEvt);
    end
    sFile.events(iEvt).times    = round(double(timeEvt).* sFile.prop.sfreq) ./ sFile.prop.sfreq;
    sFile.events(iEvt).epochs   = ones(size(sFile.events(iEvt).times));
    sFile.events(iEvt).select   = 1;
    sFile.events(iEvt).channels = cell(1, size(sFile.events(iEvt).times, 2));
    sFile.events(iEvt).notes    = cell(1, size(sFile.events(iEvt).times, 2));
end
% Display missing channels
if ~isempty(iChanMissing)
    disp(['SON> Missing channels: ' sprintf('%d ', iChanMissing)]);
end

% Close file
fclose(fid);


