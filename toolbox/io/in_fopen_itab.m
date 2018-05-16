function [sFile, ChannelMat] = in_fopen_itab(DataFile)
% IN_FOPEN_ITAB: Open a ITAB raw MEG file.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_itab(DataFile)

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
% Authors: Francois Tadel, 2015-2018
        

%% ===== READ HEADER =====
% Locate header file
HeaderFile = [DataFile '.mhd'];
if ~file_exist(HeaderFile)
    error(['Header file was not found: ' HeaderFile]);
end
% Read header
hdr = read_itab_mhd(HeaderFile);
% Get endianness
switch (hdr.data_type)
    case {0,1,2},  byteorder = 'b';
    case {3,4,5},  byteorder = 'l';
    otherwise,     error('Data type not supported.');
end


%% ===== CREATE CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'ITAB channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nchan]);
iChannels = 1:hdr.nchan;
% For each channel
for i = 1:hdr.nchan
    ChannelMat.Channel(i).Name    = hdr.ch(iChannels(i)).label;
    ChannelMat.Channel(i).Comment = '';
    % Position
    for iCoil = 1:hdr.ch(iChannels(i)).ncoils
        ChannelMat.Channel(i).Loc(:,iCoil)    = hdr.ch(iChannels(i)).position(iCoil).r_s' ./ 1000;
        ChannelMat.Channel(i).Orient(:,iCoil) = hdr.ch(iChannels(i)).position(iCoil).u_s' ./ 1000;
        ChannelMat.Channel(i).Weight(1,iCoil) = hdr.ch(iChannels(i)).wgt(iCoil);
    end    
    % Type: everything below the "_"
    iUnder = find(ChannelMat.Channel(i).Name == '_');
    if (length(iUnder) == 1) && (iUnder > 1)
        Type = ChannelMat.Channel(i).Name(1:iUnder-1);
        % Rename some known types
        switch (Type)
            case 'MAG',   ChannelMat.Channel(i).Type = 'MEG';
            case 'REF',   ChannelMat.Channel(i).Type = 'MEG REF';
            case 'ELEC',  ChannelMat.Channel(i).Type = 'EEG';
            otherwise,    ChannelMat.Channel(i).Type = Type;
        end
    else
        ChannelMat.Channel(i).Type = 'MISC';
    end
end
% Channel flag
ChannelFlag = double([hdr.ch(iChannels).flag] == 0);
ChannelFlag(ChannelFlag == 0) = -1;


% %% ===== ADD MEG POSITIONS =====
% iChan = channel_find(ChannelMat.Channel, 'MEG');
% % Position / orientation
% if ~isempty(SensorDat)
%     % Split the matrix in sensor and 
%     LocAll    = SensorDat(1:size(SensorDat,1)/2, :);
%     OrientAll = SensorDat((size(SensorDat,1)/2+1):end, :);
%     % Normalize orientation vector
%     OrientAll = bst_bsxfun(@rdivide, OrientAll, sqrt(sum(OrientAll.^2,2)));
%     % Apply to every sensor
%     for i = 1:length(iChan)
%         ind = str2double(ChannelMat.Channel(i).Name);
%         if ~isempty(ind) && ~isnan(ind) && (ind <= size(LocAll,1))
%             ChannelMat.Channel(i).Loc    = LocAll(ind,:)' ./ 1000;
%             ChannelMat.Channel(i).Orient = OrientAll(ind,:)';
%         end
%     end
% end
% % Add definition of sensors
% ChannelMat.Channel = ctf_add_coil_defs(ChannelMat.Channel, 'KRISS');


%% ===== EXTRA HEAD POINTS =====
% Get extra head points
HpLoc = hdr.marker;
iGood = find(~all(HpLoc == 0, 1));
HpLoc = HpLoc(:,iGood) ./ 1000;
nPoints = size(HpLoc,2);
% Save points in channel structure
if ~isempty(HpLoc) && (nPoints > 3)
    % All positions
    ChannelMat.HeadPoints.Loc = HpLoc;
    % All types and labels
    ChannelMat.HeadPoints.Type  = repmat({'EXTRA'}, 1, nPoints);
    ChannelMat.HeadPoints.Label = repmat({'EXTRA'}, 1, nPoints);
    % First three points: NAS/LPA/RPA
    ChannelMat.HeadPoints.Label{1} = 'NAS';
    ChannelMat.HeadPoints.Label{2} = 'RPA';
    ChannelMat.HeadPoints.Label{3} = 'LPA';
    ChannelMat.HeadPoints.Type{1} = 'CARDINAL';
    ChannelMat.HeadPoints.Type{2} = 'CARDINAL';
    ChannelMat.HeadPoints.Type{3} = 'CARDINAL';
    % Force re-alignment on the new set of NAS/LPA/RPA (switch from coil-based to SCS anatomical-based coordinate system)
    ChannelMat = channel_detect_type(ChannelMat, 1, 0);
end


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = byteorder;
sFile.filename   = DataFile;
sFile.format     = 'ITAB';
sFile.device     = 'ITAB MEG';
sFile.header     = hdr;
% Comment: short filename
[tmp__, sFile.comment, tmp__] = bst_fileparts(DataFile);
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq   = hdr.smpfq;
sFile.prop.samples = [0, hdr.ntpdata - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag = ChannelFlag;
% Acquisition date
sFile.acq_date = str_date(hdr.date);


%% ===== EVENTS =====
if (hdr.nsmpl >= 1)
    % Get events
    allStart = [hdr.smpl(1:hdr.nsmpl).start];
    allType  = [hdr.smpl(1:hdr.nsmpl).type];
    uniqueType = unique(allType);
    % Initialize list of events
    events = repmat(db_template('event'), 1, length(uniqueType));
    % Format list
    for iEvt = 1:length(uniqueType)
        % Ask for a label
        events(iEvt).label      = num2str(uniqueType(iEvt));
        events(iEvt).color      = [];
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        % Find list of occurences of this event
        iOcc = find(strcmpi(allType, uniqueType(iEvt)));
        % Get time and samples  (considering that samples are zero-based)
        events(iEvt).samples = allStart(iOcc);
        events(iEvt).times   = events(iEvt).samples ./ sFile.prop.sfreq;
        % Epoch: set as 1 for all the occurrences
        events(iEvt).epochs = ones(1, length(events(iEvt).samples));
    end
    % Import this list
    sFile = import_events(sFile, [], events);
end




