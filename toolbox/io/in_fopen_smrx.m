function [sFile, ChannelMat] = in_fopen_smrx(DataFile)
% IN_FOPEN_SMRX: Open a Cambridge Electronic Design Spike2 64bit file (.smrx).

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
% Authors:  Francois Tadel, 2020


%% ===== SETUP MATCED LIBRARY =====
% Check operating system
if ~strcmpi(bst_get('OsType'), 'win64')
    error('The MATCED library for reading .smrx files is available only on Windows 64bit.');
end
% Add path to CED code
if isempty(getenv('CEDS64ML'))
    cedpath = fileparts(which('CEDS64Open'));
    setenv('CEDS64ML', fileparts(which('CEDS64Open')));
    CEDS64LoadLib(cedpath);
end


%% ===== READ HEADER =====
% Open file
fhand = CEDS64Open(DataFile, 1);
if (fhand < 0)
    error('Could not open file.');
end
% Read file info
hdr.timebase = CEDS64TimeBase(fhand);
hdr.maxchan = CEDS64MaxChan(fhand);
hdr.maxtime = CEDS64MaxTime(fhand);
[isOk, hdr.timedate] = CEDS64TimeDate(fhand);
hdr.timedate = double(hdr.timedate);

% Get list of channels
bst_progress('text', 'Reading channel info...');
iChan = 0;
iMarkerChan = [];
MarkerChanName = {};
for i = 1:hdr.maxchan
    % Read channel type
    chanType = CEDS64ChanType(fhand, i);
    % Check type of the channel
    switch chanType
        % ADC channels: read as signals
        case {1,9}
            iChan = iChan + 1;
            hdr.chaninfo(iChan).number = i;
            hdr.chaninfo(iChan).kind = chanType;
            [isOk, hdr.chaninfo(iChan).title] = CEDS64ChanTitle(fhand, i);
            % [isOk, hdr.chaninfo(iChan).comment] = CEDS64ChanComment(fhand, i);
            hdr.chaninfo(iChan).div = CEDS64ChanDiv(fhand, i);
            hdr.chaninfo(iChan).idealRate = CEDS64IdealRate(fhand, i);
            hdr.chaninfo(iChan).realRate = 1 ./ (hdr.timebase .* hdr.chaninfo(iChan).div);
            % Convert units to gain
            [isOk, hdr.chaninfo(iChan).units] = CEDS64ChanUnits(fhand, i);
            chUnits = lower(strtrim(hdr.chaninfo(iChan).units));
            if ~isempty(chUnits)
                if ~isempty(strfind(chUnits, 'μ')) || ~isempty(strfind(chUnits, 'micro'))
                    hdr.chaninfo(iChan).gain = 1e-6;
                elseif ~isempty(strfind(chUnits, 'milli')) || ~isempty(strfind(chUnits, 'mv'))
                    hdr.chaninfo(iChan).gain = 1e-3;
                else
                    hdr.chaninfo(iChan).gain = 1;
                end
            end
        % Markers and events
        case {2,3,4,5,6,7,8}
        	iMarkerChan(end+1) = i;
            [isOk, chTitle] = CEDS64ChanTitle(fhand, i);
            chTitle = str_remove_spec_chars(chTitle);
            if ~isempty(chTitle)
                MarkerChanName{end+1} = chTitle;
            else
                MarkerChanName{end+1} = num2str(i);
            end
    end
end
hdr.nchan = length(hdr.chaninfo);
% Get maximum sampling rate
[sfreq, chMax] = max([hdr.chaninfo.idealRate]);


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder    = 'l';
sFile.filename     = DataFile;
sFile.format       = 'EEG-SMRX';
sFile.prop.sfreq   = sfreq;
sFile.prop.times   = round([0, hdr.maxtime .* hdr.timebase] .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
sFile.channelflag  = ones(hdr.nchan,1);
sFile.device       = 'CED Spike2';
sFile.header       = hdr;
sFile.acq_date     = datestr(datenum(hdr.timedate(7), hdr.timedate(6), hdr.timedate(5)), 'dd-mmm-yyyy');
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nchan]);
% For each channel
for iChan = 1:hdr.nchan
    ChannelMat.Channel(iChan).Type = 'EEG';
    ChannelMat.Channel(iChan).Name = hdr.chaninfo(iChan).title;
end


%% ===== READ MARKER INFORMATION =====
iEvt = 0;
for i = 1:length(iMarkerChan)
    bst_progress('text', sprintf('Reading event channel %d/%d...', i, length(iMarkerChan)));

    % Read markers
    warning('off', 'MATLAB:structOnObject');
    maxEvt = round(hdr.maxtime .* hdr.timebase .* sFile.prop.sfreq / 10);
    [nMrkRead, objMrk] = CEDS64ReadMarkers(fhand, iMarkerChan(i), maxEvt, 0);
    warning('on', 'MATLAB:structOnObject');
    % Create groups of markers with similar codes
    if ~isempty(objMrk)
        % Check event codes that are used
        isCode1 = ~all([objMrk.m_Code1] == objMrk(1).m_Code1);
        isCode2 = ~all([objMrk.m_Code2] == objMrk(1).m_Code2);
        isCode3 = ~all([objMrk.m_Code3] == objMrk(1).m_Code3);
        isCode4 = ~all([objMrk.m_Code4] == objMrk(1).m_Code4);
        % Create list of event names
        mrkNames = repmat(MarkerChanName(i), 1, nMrkRead);
        for iMrk = 1:nMrkRead
            if isCode1
                mrkNames{iMrk} = [mrkNames{iMrk}, '-', num2str(objMrk(iMrk).m_Code1)];
            end
            if isCode2
                mrkNames{iMrk} = [mrkNames{iMrk}, '-', num2str(objMrk(iMrk).m_Code2)];
            end
            if isCode3
                mrkNames{iMrk} = [mrkNames{iMrk}, '-', num2str(objMrk(iMrk).m_Code2)];
            end
            if isCode4
                mrkNames{iMrk} = [mrkNames{iMrk}, '-', num2str(objMrk(iMrk).m_Code2)];
            end
        end
        % List of different markers
        [uniqueNames, iUnique] = unique(mrkNames);
        uniqueNames = mrkNames(sort(iUnique));
        % Build events list
        for iUniqueEvt = 1:length(uniqueNames)
            iEvt = iEvt + 1;
            % Find all the occurrences of this event
            iOcc = find(strcmpi(uniqueNames{iUniqueEvt}, mrkNames));
            % Concatenate all times
            t = round(double([objMrk(iOcc).m_Time]) .* hdr.timebase .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
            % Create structure
            sFile.events(iEvt).label    = file_unique(MarkerChanName{i}, {sFile.events.label});
            sFile.events(iEvt).times    = t;
            sFile.events(iEvt).epochs   = ones(1, length(t));
            sFile.events(iEvt).select   = 1;
            sFile.events(iEvt).channels = [];
            sFile.events(iEvt).notes    = [];
        end

    % Read events
    else
        [nEvtRead, evtTicks] = CEDS64ReadEvents(fhand, iMarkerChan(i), hdr.maxtime, 0);
        if ~isempty(evtTicks)
            iEvt = iEvt + 1;
            t = round(double(reshape(evtTicks,1,[])) .* hdr.timebase .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
            sFile.events(iEvt).label    = file_unique(MarkerChanName{i}, {sFile.events.label});
            sFile.events(iEvt).times    = t;
            sFile.events(iEvt).epochs   = ones(1, length(t));
            sFile.events(iEvt).select   = 1;
            sFile.events(iEvt).channels = [];
            sFile.events(iEvt).notes    = [];
        end
    end
end

% Close file
CEDS64Close(fhand);


