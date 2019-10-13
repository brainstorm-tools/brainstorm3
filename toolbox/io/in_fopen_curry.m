function [sFile, ChannelMat] = in_fopen_curry(DataFile)
% IN_FOPEN_CURRY: Open a Curry 6-7 (.dat/.dap/.rs3) or Curry 8 (.cdt/.dpa)
%
% USAGE:  [sFile, ChannelMat] = in_fopen_curry(DataFile)

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
% Authors: Initial code from EEGLAB plugin loadcurry 2.0: Matt Pontifex, pontifex@msu.edu
%          Adaptation for Brainstorm 3: Francois Tadel, 2018


%% ===== GET FILES =====
% Get version of curry
[fPath, fBase, fExt] = bst_fileparts(DataFile);
switch (fExt)
    % Curry 6-7
    case '.dat'
        hdr.curryvers = 7;
        HdrFile = fullfile(fPath, [fBase, '.dap']);
        ChanFile = fullfile(fPath, [fBase, '.rs3']);
        EvtFile = fullfile(fPath, [fBase, '.cef']);
        EvtFileAlt = fullfile(fPath, [fBase, '.ceo']);
        % Check for mandatory files
        if ~file_exist(HdrFile) || ~file_exist(ChanFile)
            error('Missing Curry 7 .dap or .rs3 file.');
        end
    % Curry 8
    case '.cdt'
        hdr.curryvers = 8;
        HdrFile = fullfile(fPath, [fBase, '.cdt.dpa']);
        ChanFile = HdrFile;
        EvtFile = fullfile(fPath, [fBase, '.cdt.cef']);
        EvtFileAlt = fullfile(fPath, [fBase, '.cdt.ceo']);
        % Check for mandatory files
        if ~file_exist(HdrFile)
            error('Missing Curry 8 .cdt.dpa file.');
        end
    otherwise
        error('Unsupported file format.');
end


%% ===== READ PARAMETER FILE =====
% Open parameter file
fid = fopen(HdrFile,'rt');
if (fid == -1)
   error(['Unable to open file: ' HdrFile']);
end
try
    Cell = textscan(fid,'%s','whitespace','','endofline','§');
catch
    % In case of earlier versions of Matlab or Older Computers
    fclose(fid); 
    fid = fopen(HdrFile,'rt');
    f = dir(HdrFile);
    try
        Cell = textscan(fid,'%s','whitespace','','endofline','§','BufSize',round(f.bytes+(f.bytes*0.2)));
    catch
        fclose(fid);
        fid = fopen(HdrFile,'rt');
        Cell = textscan(fid,'%s','whitespace','','BufSize',round(f.bytes+(f.bytes*0.2)));
    end
end
fclose(fid);            
cont = cell2mat(Cell{1});

% read parameters from file
% tokens (second line is for Curry 6 notation)
tok = { 'NumSamples'; 'NumChannels'; 'NumTrials'; 'SampleFreqHz';  'TriggerOffsetUsec';  'DataFormat'; 'DataSampOrder';   'SampleTimeUsec'; 
        'NUM_SAMPLES';'NUM_CHANNELS';'NUM_TRIALS';'SAMPLE_FREQ_HZ';'TRIGGER_OFFSET_USEC';'DATA_FORMAT';'DATA_SAMP_ORDER'; 'SAMPLE_TIME_USEC' };

% scan in Cell 1 for keywords - all keywords must exist!
nt = size(tok,1);
a = zeros(nt,1);
for i = 1:nt
     ctok = tok{i,1};
     ix = strfind(cont,ctok);
     if ~isempty ( ix )
         text = sscanf(cont(ix+numel(ctok):end),' = %s');     % skip =
         if strcmp ( text,'ASCII' ) || strcmp ( text,'CHAN' ) % test for alphanumeric values
             a(i) = 1;
         else 
             c = sscanf(text,'%f');         % try to read a number
             if ~isempty ( c )
                 a(i) = c;                  % assign if it was a number
             end
         end
     end 
end

% derived variables. numbers (1) (2) etc are the token numbers
hdr.nSamples    = a(1)+a(1+nt/2);
hdr.nChannels   = a(2)+a(2+nt/2);
hdr.nTrials     = a(3)+a(3+nt/2);
hdr.fFrequency  = a(4)+a(4+nt/2);
hdr.fOffsetUsec = a(5)+a(5+nt/2);
hdr.nASCII      = a(6)+a(6+nt/2);
hdr.nMultiplex  = a(7)+a(7+nt/2);
hdr.fSampleTime = a(8)+a(8+nt/2);
if (hdr.fFrequency == 0 && hdr.fSampleTime ~= 0)
    hdr.fFrequency = 1000000 / hdr.fSampleTime;
end

% Epoched files not supported yet
if (hdr.nMultiplex ~= 0)
    error('Multiplexed data not supported yet: post a message on the Brainstorm user forum to request this feature.');
end

%Search for Impedance Values
tixstar = strfind(cont,'IMPEDANCE_VALUES START_LIST');
tixstop = strfind(cont,'IMPEDANCE_VALUES END_LIST');
hdr.impedancelist = []; 
hdr.impedancematrix = [];
if (~isempty(tixstar)) && (~isempty(tixstop))
    text = cont(tixstar:tixstop-1);
    tcell = textscan(text,'%s');
    tcell = tcell{1,1};
    for tcC = 1:size(tcell,1)
       tcell{tcC} = str2num(tcell{tcC}); % data was read in as strings - force to numbers
       if ~isempty(tcell{tcC}) % skip if it is not a number
           hdr.impedancelist(end+1) = tcell{tcC};
       end
    end
    % Curry records last 10 impedances
    hdr.impedancematrix = reshape(hdr.impedancelist,[(size(hdr.impedancelist,2)/10),10])';
    hdr.impedancematrix(hdr.impedancematrix == -1) = NaN; % screen for missing
end

% === READ EPOCH LABELS ===
hdr.epochlabels = {};
if (hdr.nTrials > 1)
    epocstar = strfind(cont,'EPOCH_LABELS START_LIST');
    epocstop = strfind(cont,'EPOCH_LABELS END_LIST');
    if (~isempty(epocstar)) && (~isempty(epocstop))
        text = strrep(cont(epocstar:epocstop-1), char(13), ''); 
        tcell = str_split(text, char(10));
        if (length(tcell) == hdr.nTrials + 1)
            hdr.epochlabels = tcell(2:end);
        end
    end
end


%% ===== READ CHANNEL INFO =====            
fid = fopen(ChanFile,'rt');
if (fid == -1)
   error(['Unable to open file: ' ChanFile]);
end
try
    Cell = textscan(fid,'%s','whitespace','','endofline','§');
catch
    fclose(fid);
    fid = fopen(ChanFile,'rt');
    f = dir(ChanFile);
    try
        Cell = textscan(fid,'%s','whitespace','','endofline','§','BufSize',round(f.bytes+(f.bytes*0.2)));
    catch
        fclose(fid);
        fid = fopen(ChanFile,'rt');
        Cell = textscan(fid,'%s','whitespace','','BufSize',round(f.bytes+(f.bytes*0.2)));
    end
end
fclose(fid);
cont = cell2mat(Cell{1});

% read labels from rs3 file
% initialize labels
hdr.labels = num2cell(1:hdr.nChannels);
for i = 1:hdr.nChannels
    text = sprintf('EEG%d',i);
    hdr.labels(i) = cellstr(text);
end

% scan in Cell 1 for LABELS (occurs four times per channel group)
ix = strfind(cont,[char(10),'LABELS']);
nt = size(ix,2);
nc = 0;
for i = 4:4:nt                                                      % loop over channel groups
    newlines = ix(i-1) + strfind(cont(ix(i-1)+1:ix(i)),char(10));   % newline
    last = hdr.nChannels - nc;
    for j = 1:min(last,size(newlines,2)-1)                          % loop over labels
        text = cont(newlines(j)+1:newlines(j+1)-1);
        if isempty(strfind(text,'END_LIST'))
            nc = nc + 1;
            hdr.labels(nc) = cellstr(text);
        else 
            break
        end
    end 
end

% Read sensor locations from rs3 file
hdr.sensorpos = zeros(3,0);
% Scan in Cell 1 for SENSORS (occurs four times per channel group)
ix = strfind(cont,[char(10),'SENSORS']);
nt = size(ix,2);
nc = 0;
for i = 4:4:nt                                                      % loop over channel groups
    newlines = ix(i-1) + strfind(cont(ix(i-1)+1:ix(i)),char(10));   % newline
    last = hdr.nChannels - nc;
    for j = 1:min(last,size(newlines,2)-1)                          % loop over labels
        text = cont(newlines(j)+1:newlines(j+1)-1);
        if isempty(strfind(text,'END_LIST'))
            nc = nc + 1;
            tcell = textscan(text,'%f');                           
            posx = tcell{1}(1);
            posy = tcell{1}(2);
            posz = tcell{1}(3);
            hdr.sensorpos = cat ( 2, hdr.sensorpos, [ posx; posy; posz ] );
        else 
            break
        end
    end 
end



%% ===== READ EVENTS FILE =====
% initialize events
hdr.ne = 0;
hdr.events = zeros(4,0);
annotations = cellstr('empty');

% find appropriate file
fid = fopen(EvtFile,'rt');
if (fid < 0)
    fid = fopen(EvtFileAlt,'rt');
end

if (fid >= 0)              
    try
        Cell = textscan(fid,'%s','whitespace','','endofline','§');
    catch
        fclose(fid);
        fid = fopen(EvtFile,'rt');
        if fid < 0
            fid = fopen(EvtFileAlt,'rt');
            f = dir(EvtFileAlt);
        else
            f = dir(EvtFile);
        end
        try
            Cell = textscan(fid,'%s','whitespace','','endofline','§','BufSize',round(f.bytes+(f.bytes*0.2)));
        catch
            fclose(fid);
            fid = fopen(EvtFile,'rt');
            if fid < 0
                fid = fopen(EvtFileAlt,'rt');
                f = dir(EvtFileAlt);
            else
                f = dir(EvtFile);
            end
            Cell = textscan(fid,'%s','whitespace','','BufSize',round(f.bytes+(f.bytes*0.2)));
        end
    end
    fclose(fid);
    cont = cell2mat(Cell{1});

    % scan in Cell 1 for NUMBER_LIST (occurs five times)
    ix = strfind(cont,'NUMBER_LIST');

    newlines = ix(4) - 1 + strfind(cont(ix(4):ix(5)),char(10));     % newline
    last = size(newlines,2)-1;
    for j = 1:last                                                  % loop over labels
        text = cont(newlines(j)+1:newlines(j+1)-1);
        tcell = textscan(text,'%d');                           
        sample = tcell{1}(1);                                       % access more content using different columns
        type = tcell{1}(3);
        startsample = tcell{1}(5);
        endsample = tcell{1}(6);
        hdr.ne = hdr.ne + 1;
        hdr.events = cat ( 2, hdr.events, [ sample; type; startsample; endsample ] );
    end

    % scan in Cell 1 for REMARK_LIST (occurs five times)
    ix = strfind(cont,'REMARK_LIST');
    na = 0;

    newlines = ix(4) - 1 + strfind(cont(ix(4):ix(5)),char(10));     % newline
    last = size(newlines,2)-1;
    for j = 1:last                                                  % loop over labels
        text = cont(newlines(j)+1:newlines(j+1)-1);
        na = na + 1;
        annotations(na) = cellstr(text);
    end    
end


%% ===== READ ASCII DATA =====
if (hdr.nASCII == 1)
    fid = fopen(DataFile,'rt');
    if (fid == -1)
       error(['Unable to open file: ' DataFile]);
    end
    f = dir(DataFile);
    try
        fclose(fid);
        fid = fopen(DataFile,'rt');
        Cell = textscan(fid,'%f',hdr.nChannels*hdr.nSamples*hdr.nTrials);
    catch
        fclose(fid);
        fid = fopen(DataFile,'rt');
        Cell = textscan(fid,'%f',hdr.nChannels*hdr.nSamples*hdr.nTrials, 'BufSize',round(f.bytes+(f.bytes*0.2)));
    end
    fclose(fid);
    hdr.data = reshape([Cell{1}],hdr.nChannels,hdr.nSamples*hdr.nTrials);
else
    hdr.data = [];
end


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format = 'EEG-CURRY';
sFile.device = 'Neuroscan Curry';
sFile.header = hdr;
% Comment: short filename
[tmp__, sFile.comment, tmp__] = bst_fileparts(DataFile);
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq = hdr.fFrequency;
sFile.prop.times = round(hdr.fOffsetUsec .* 1e-6 * hdr.fFrequency + [0, hdr.nSamples - 1]) ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.nChannels,1);
% Acquisition date
sFile.acq_date = [];


%% ===== EPOCHS =====
if (hdr.nTrials >= 2)
    for iEpoch = 1:hdr.nTrials
        if ~isempty(hdr.epochlabels)
            sFile.epochs(iEpoch).label = hdr.epochlabels{iEpoch};
        else
            sFile.epochs(iEpoch).label = sprintf('Epoch #%d', iEpoch);
        end
        sFile.epochs(iEpoch).times   = sFile.prop.times;
        sFile.epochs(iEpoch).nAvg    = 1;
        sFile.epochs(iEpoch).select  = 1;
        sFile.epochs(iEpoch).bad     = 0;
        sFile.epochs(iEpoch).channelflag = [];
    end
end


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nChannels]);
% For each channel
for i = 1:hdr.nChannels
    % Trigger channel
    if strcmpi(hdr.labels,'Trigger')
        ChannelMat.Channel(i).Type = 'STIM';
        ChannelMat.Channel(i).Name = 'Trigger';
        ChannelMat.Channel(i).Loc  = [0; 0; 0];
    % Regular EEG channel
    else
        ChannelMat.Channel(i).Type = 'EEG';
        % Label if available
        if (i <= length(hdr.labels))
            ChannelMat.Channel(i).Name = hdr.labels{i};
        else
            ChannelMat.Channel(i).Name = 'E';
        end
        % Add positions if available
        if (i <= size(hdr.sensorpos,2))
            ChannelMat.Channel(i).Loc = [-1 * hdr.sensorpos(2,i); hdr.sensorpos(1,i); hdr.sensorpos(3,i)] ./ 1000;
        else
            ChannelMat.Channel(i).Loc = [0; 0; 0];
        end
    end
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
end


%% ===== CREATE EVENTS STRUCTURE =====
% If there are events: create a create an events structure
if ~isempty(hdr.events)
    % Initialize events list
    sFile.events = repmat(db_template('event'), 0);
    % Events list: [ sample; type; startsample; endsample ]
    evtList = double(hdr.events);
    uniqueEvt = unique(evtList(2,:));
    % Build events list
    for iEvt = 1:length(uniqueEvt)
        % Find all the occurrences of this event
        iOcc = find(evtList(2,:) == uniqueEvt(iEvt));
        % Simple event: If the duration of all the events is one sample
        if (max(evtList(4,iOcc) - evtList(3,iOcc)) == 0)
            smp = evtList(1,iOcc);
        % Exented event
        else
            smp = evtList(3:4,iOcc);
        end
        % Set event
        sFile.events(iEvt).label    = num2str(uniqueEvt(iEvt));
        sFile.events(iEvt).times    = smp ./ sFile.prop.sfreq;
        sFile.events(iEvt).epochs   = 1 + 0*smp(1,:);
        sFile.events(iEvt).select   = 1;
        sFile.events(iEvt).channels = cell(1, size(sFile.events(iEvt).times, 2));
        sFile.events(iEvt).notes    = cell(1, size(sFile.events(iEvt).times, 2));
    end
    
    % Handle Epoched Datasets
    if (hdr.nTrials > 1)
        error('Not supported yet.');
    end
end
    

