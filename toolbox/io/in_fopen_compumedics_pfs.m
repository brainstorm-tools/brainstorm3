function [sFile, ChannelMat] = in_fopen_compumedics_pfs(DataFile)
% IN_FOPEN_COMPUMEDICS_PFS: Open a Compumedics ProFusion Sleep 4 exported binary file (.sdy/.rda).
% 
% DESCRIPTION:
%     Reads the following files from an exported folder, with extension .eeg:
%       - Channel description : eeg/.sdy                     (XML file)
%       - Data header         : eeg/EEGData/EEGData.ini      (ASCII file)
%       - Data files          : eeg/EEGData/EEGData-*.rda    (Binary float)
%       - Electrode positions : eeg/ElectrodePlacements/.xml (XML file)
%       - Event markers       : eeg/EEGStudyDB.mdb           (Access database)
%
% USAGE:  [sFile, ChannelMat] = in_fopen_compumedics_pfs(DataFile)

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
% Authors: Francois Tadel, 2015-2018


%% ===== GET FILES =====
% Get base .eeg folder
RdaFile = [];
if isdir(DataFile)
    EegFolder = DataFile;
elseif strcmpi(DataFile(end-3:end), '.sdy')
    EegFolder = bst_fileparts(DataFile);
elseif strcmpi(DataFile(end-3:end), '.rda')
    EegFolder = bst_fileparts(bst_fileparts(DataFile));
    RdaFile = DataFile;
else
    error('Invalid Compumedics ProFusion Sleep exported .eeg folder.');
end
% Sensor info (.sdy)
SensorFile = file_find(EegFolder, '*.sdy', 0);
if isempty(SensorFile) || ~file_exist(SensorFile)
    error(['Could not find the sensor file .sdy in folder: ' 10 EegFolder]);
end
% Data header (EEGData/EEGData.ini)
HeaderFile = bst_fullfile(EegFolder, 'EEGData', 'EEGData.ini');
if ~file_exist(HeaderFile)
    error(['Could not find the header file: ' 10 HeaderFile]);
end
% Recordings (EEGData/EEGData-*.rda)
if isempty(RdaFile)
    filelist = dir(bst_fullfile(EegFolder, 'EEGData', 'EEGData-*.rda'));
    if isempty(filelist)
        error(['Could not find any .rda recordings in folder: ' 10 EegFolder]);
    elseif (length(filelist) > 1)
        error('Importing multiple .rda files is not supported yet.');
    end
    RdaFile = {filelist.name};
end
% Electrode positions (ElectrodePlacements/.xml)
PosFile = file_find(bst_fullfile(EegFolder, 'ElectrodePlacements'), '*.xml', 0);
if isempty(PosFile) || ~file_exist(PosFile)
    disp(['BST> Warning: Could not find a .xml position file in folder: ' 10 bst_fullfile(EegFolder, 'ElectrodePlacements')]);
    PosFile = [];
end
% Events (EEGStudyDB.mdb)
EventFile = bst_fullfile(EegFolder, 'EEGStudyDB.mdb');
if isempty(EventFile) || ~file_exist(EventFile)
    disp(['BST> Warning: Could not find events file: ' 10 EventFile]);
    EventFile = [];
end


%% ===== FILE COMMENT =====
% Get EEG folder name
[tmp, eegComment, tmp] = bst_fileparts(EegFolder);
% Extract index of the .rda file
[tmp, rdaComment, tmp] = bst_fileparts(RdaFile);
iDash = find((rdaComment == '-'), 1, 'last');
if ~isempty(iDash)
    rdaComment = rdaComment(iDash+1:end);
end
% Comment: EegFolder + .rda file number
Comment = [eegComment '-' rdaComment];


%% ===== READ SENSOR FILE =====
% Read XML sensor file
hdr.xmlchan = in_xml(SensorFile);
% Extract list of channel names
chnames = {hdr.xmlchan.ProFusionEEGStudy.Channels.Channel.name};
% Get sampling frequency
sfreq = str2double(hdr.xmlchan.ProFusionEEGStudy.Study.eeg_sample_rate);
if isempty(sfreq) || isnan(sfreq)
    error('Invalid sampling frequency.');
end
% Save number of channels
hdr.nchannels = length(chnames);


%% ===== READ CHANNEL POSITIONS =====
if ~isempty(PosFile)
    % Read XML pos file
    hdr.xmlpos = in_xml(PosFile);
    % Extract list of channel names
    chnames_pos = [hdr.xmlpos.Electrodes.Electrode.Label];
    chnames_pos = {chnames_pos.text};
    % Rebuild array of positions
    chposX = [hdr.xmlpos.Electrodes.Electrode.XCoordinate];
    chposX = str2double({chposX.text});
    chposY = [hdr.xmlpos.Electrodes.Electrode.YCoordinate];
    chposY = str2double({chposY.text});
    chpos = [chposX', chposY'];
    % Remove all the channels that are not present in the current recordings, and TRIGGER channel
    iDel = [find(~ismember(chnames_pos, chnames)), ...
            find(strcmpi(chnames_pos, 'Trigger'))];
    if ~isempty(iDel)
        chnames_pos(iDel) = [];
        chpos(iDel,:) = [];
    end
    % Center on (0,0) and normalize
    %chpos = bst_bsxfun(@minus, chpos, (max(chpos)+min(chpos))/2);
    chpos = bst_bsxfun(@minus, chpos, mean(chpos));
    chpos = 0.120 * bst_bsxfun(@rdivide, chpos, max(abs(chpos)));
else
    chnames_pos = [];
    chpos = [];
end


%% ===== READ DATA HEADER =====
% Open and read file
fid = fopen(HeaderFile,'r');
if (fid < 0)
    error(['Cannot open header file: ' HeaderFile]);
end
% Default values
hdr.rda_nsamples = [];
% Read file line by line
while 1
    % Read one line
    newLine = fgetl(fid);
    % End of file: Quit loop
    if ~ischar(newLine)
        break;
    end
    % If there are no '=' signs: next line
    if isempty(newLine) || ~any(newLine == '=')
        continue;
    end
    % Split line based on '=' sign
    argLine = strtrim(str_split(newLine, '='));
    % Get number of time points per .rda file
    if strcmpi(argLine{1}, 'Integral space size in samples')
        hdr.rda_nsamples = str2num(argLine{2});
    end
end
% Close file
fclose(fid);
% If we could read the number samples per rda file and the index of the rda file: calculate the start of the file
if ~isempty(hdr.rda_nsamples) && ~isempty(str2num(rdaComment))
    hdr.rda_startsmp = hdr.rda_nsamples * (str2num(rdaComment) - 1);
    hdr.rda_startstr = datestr(hdr.rda_startsmp * sfreq /86400, 'HH:MM:SS');
    timeComment = [' [' hdr.rda_startstr ']'];
else
    hdr.rda_startsmp = [];
    hdr.rda_startstr = '';
    timeComment = '';
end


%% ===== READ BINARY HEADER =====
% Open file
fid = fopen(DataFile, 'r', 'ieee-le');
if (fid < 0)
    error(['Could not open data file: ' DataFile]);
end
% Read file header
hdr.rda.sealed = fread(fid, 1, 'bool');  
hdr.rda.pdel   = fread(fid, 1, 'long'); 
unused         = fread(fid, [1 95], '*char');
% Read segment
iseg = 1;
hdr.rda.segment(iseg).magic        = fread(fid, 1, '*int64');
hdr.rda.segment(iseg).first_sample = fread(fid, 1, '*int64');
hdr.rda.segment(iseg).num_samples  = fread(fid, 1, '*int64'); 
hdr.rda.segment(iseg).closed       = fread(fid, 1, 'bool');
unused                             = fread(fid, [1 175], '*char');
hdr.rda.segment(iseg).pos          = ftell(fid);
% Read other segments ?
% Close file
fclose(fid);


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder = 'l';
sFile.filename  = RdaFile;
sFile.format    = 'EEG-COMPUMEDICS-PFS';
sFile.device    = 'Compumedics ProFusion Sleep EEG';
sFile.header    = hdr;
sFile.comment   = [Comment timeComment];
sFile.condition = Comment;
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq = sfreq;
sFile.prop.times = [0, double(hdr.rda.segment(1).num_samples) - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg  = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.nchannels, 1);
% Acquisition date
try
    sFile.acq_date = str_date(hdr.xmlchan.ProFusionEEGStudy.Study.creation_time);
catch
end

%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Compumedics channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nchannels]);
% For each channel
for i = 1:hdr.nchannels
    ChannelMat.Channel(i).Name    = chnames{i};
    ChannelMat.Channel(i).Loc     = [0; 0; 0];
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
    % Location: Get from position file if possible
    if ~isempty(chnames_pos) && ~isempty(chpos)
        iPos = find(strcmpi(chnames{i}, chnames_pos));
        if ~isempty(iPos)
            ChannelMat.Channel(i).Loc = [chpos(iPos,1); chpos(iPos,2); 0];
        else
            ChannelMat.Channel(i).Type = 'EEG_NO_LOC';
        end
    end
end


%% ===== READ EVENTS =====
% Events are saved in an Access database: EEGStudyDB.mdb
if ~isempty(EventFile)
    Access = [];
    eventsMat = cell(0,5);
    try 
        % Open Access database with ActiveX server
        Access = actxserver('access.application');
        dbEvt = Access.DBEngine.OpenDatabase(EventFile);
        % Get all the events
        recordsEvt = dbEvt.OpenRecordset('SELECT EventTypeID, EventCategoryID, StartSecondHi, DurationHi, EventString FROM EEGEvent WHERE IsEndEvent=false;');
        % Loop for get all the values
        while ~recordsEvt.EOF
            eventsMat(end+1,:) = recordsEvt.GetRows()';
        end
        % Close database
        dbEvt.Close();
    catch
        disp('BST> Error: Could not start Access to read EEGStudyDB.mdb');
    end
    % Close database
    if ~isempty(Access) && iscom(Access)
        delete(Access);
    end
    
    % Create events list
    if ~isempty(eventsMat)
        % Retrieve information of interest
        allTypes     = double([eventsMat{:,1}]);
        allStart     = double([eventsMat{:,3}]);
        allDurations = double([eventsMat{:,4}]);
        % Get list of events
        [uniqueType, iUnique] = unique(allTypes);
        uniqueType = allTypes(sort(iUnique));
        % Initialize list of events
        events = repmat(db_template('event'), 1, length(uniqueType));
        % Format list
        for iEvt = 1:length(uniqueType)
            % Find list of occurences of this event
            iOcc = find((allTypes == uniqueType(iEvt)) & (allStart > 0));
            % Fill events structure
            events(iEvt).label      = num2str(uniqueType(iEvt));
            events(iEvt).color      = [];
            events(iEvt).reactTimes = [];
            events(iEvt).select     = 1;
            % If there are non-negative durations: create extended events
            if any(allDurations(iOcc) ~= 0)
                evtDurations = max(allDurations(iOcc), 1);
                samples = [allStart(iOcc); allStart(iOcc) + evtDurations];
            else
                samples = allStart(iOcc);
            end
            % Convert to time
            events(iEvt).times    = samples ./ sFile.prop.sfreq;
            events(iEvt).epochs   = ones(1, length(events(iEvt).times));  % Epoch: set as 1 for all the occurrences
            events(iEvt).channels = cell(1, size(events(iEvt).times, 2));
            events(iEvt).notes    = cell(1, size(events(iEvt).times, 2));
        end
        % Import this list
        sFile = import_events(sFile, [], events);
    end
end


