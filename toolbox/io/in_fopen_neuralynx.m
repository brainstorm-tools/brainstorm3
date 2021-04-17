function [sFile, ChannelMat] = in_fopen_neuralynx(DataFile)
% IN_FOPEN_NEURALYNX Open Neuralynx recordings (.ncs and .nse).
% 
% DESCRIPTION:
%     Reads all the following files available in the same folder:
%       - *.ncs:  Single continuous channel file 
%       - *.nse:  Single electrode waveform file (spikes)
%       - *.nev:  Event information
%     Handling of the Neuralynx files is inspired from FieldTrip: 
%       http://www.fieldtriptoolbox.org/getting_started/neuralynx
%
%     NCS files structure:  
%        |- Header ASCII: 16*1044 bytes
%        |- Records: nRecords x 1044 bytes
%             |- TimeStamp    : uint64
%             |- ChanNumber   : int32
%             |- SampFreq     : int32
%             |- NumValidSamp : int32
%             |- Data         : 512 x int16
%     NSE files structure:  
%        |- Header ASCII: 16*1044 bytes
%        |- Records: nRecords x 112 bytes
%             |- TimeStamp    : uint64
%             |- ScNumber     : int32
%             |- CellNumber   : int32
%             |- Param        : 8 x int32
%             |- Data         : NumSamples x int16
        
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
% Authors: Francois Tadel, 2015-2019


%% ===== GET FILES =====
% Get base dataset folder
if isdir(DataFile)
    hdr.BaseFolder = DataFile;
elseif strcmpi(DataFile(end-3:end), '.ncs') || strcmpi(DataFile(end-3:end), '.nse') || strcmpi(DataFile(end-3:end), '.nev')
    hdr.BaseFolder = bst_fileparts(DataFile);
else
    error('Invalid Neuralynx folder.');
end
% Event files (.nev)
EventFile = file_find(hdr.BaseFolder, '*.nev', 0);
if isempty(EventFile) || ~file_exist(EventFile)
    disp(['BST> Warning: Events file not found in folder: ' 10 hdr.BaseFolder]);
    EventFile = [];
end
% Recordings (*.ncs; *.nse)
NcsFiles = dir(bst_fullfile(hdr.BaseFolder, '*.ncs'));
NseFiles = dir(bst_fullfile(hdr.BaseFolder, '*.nse'));
if isempty(NcsFiles)
    error(['Could not find any .ncs recordings in folder: ' 10 hdr.BaseFolder]);
end
ChanFiles = sort({NcsFiles.name, NseFiles.name});


%% ===== FILE COMMENT =====
% Get base folder name
[tmp, dirComment, tmp] = bst_fileparts(hdr.BaseFolder);
% Comment: BaseFolder + number or files
Comment = [dirComment '-' num2str(length(ChanFiles)) 'ncs'];


%% ===== READ DATA HEADERS =====
hdr.chan_headers = {};
hdr.chan_files = {};
% Read the headers for all the files
for i = 1:length(ChanFiles)
    % Read full header
    newHeader = neuralynx_getheader(bst_fullfile(hdr.BaseFolder, ChanFiles{i}));
    % Check for some important fields
    if ~isfield(newHeader, 'RecordSize') || ~isfield(newHeader, 'SamplingFrequency') || ~isfield(newHeader, 'ADBitVolts')
        error(['Missing fields in the file header of file: ' ChanFiles{i}]);
    end
    % Compute number of records saved in the file
    nRecordsFile = round((newHeader.FileSize - newHeader.HeaderSize) / newHeader.RecordSize);
    % Check if there are missing timestamps in the file
    if isfield(newHeader, 'LastTimeStamp') && ~isempty(newHeader.LastTimeStamp)
        nRecordsTime = round(double(newHeader.LastTimeStamp - newHeader.FirstTimeStamp) / 1e6 * newHeader.SamplingFrequency / 512) + 1;
        if (nRecordsTime < nRecordsFile)
            disp(['Neuralynx> Warning: The file is longer than expected: ' ChanFiles{i}]);
            disp(sprintf('Neuralynx> Truncating file to %d records instead of %d...', nRecordsTime, nRecordsFile));
            nRecordsFile = nRecordsTime;
        end
    end
    % Extract information needed for opening the file
    if (i == 1)
        hdr.FirstTimeStamp        = newHeader.FirstTimeStamp;
        hdr.LastTimeStamp         = newHeader.LastTimeStamp;
        hdr.NumSamples            = nRecordsFile * 512;
        hdr.SamplingFrequency     = newHeader.SamplingFrequency;
        if isfield(newHeader, 'HardwareSubSystemType')
            hdr.HardwareSubSystemType = newHeader.HardwareSubSystemType;
        end
    % Make sure the values are the same across files
    elseif (hdr.SamplingFrequency ~= newHeader.SamplingFrequency)
        disp(['BST> Warning: Sampling frequency in "' ChanFiles{i} '" is incompatible with "' ChanFiles{1} '". Skipping file...']);
        continue;
    elseif isfield(newHeader, 'LastTimeStamp') && ~isempty(newHeader.LastTimeStamp) && ((hdr.FirstTimeStamp ~= newHeader.FirstTimeStamp) || (hdr.LastTimeStamp ~= newHeader.LastTimeStamp))
        disp(['BST> Warning: Timestamps in "' ChanFiles{i} '" do not match "' ChanFiles{1} '". Skipping file...']);
        continue;
    % For .nse files: Compute the spike times
    elseif strcmpi(newHeader.FileExtension, 'NSE')
        newHeader.SpikeTimes = double(newHeader.SpikeTimeStamps - hdr.FirstTimeStamp) / 1e6;
    end
    
    % Save all file names
    hdr.chan_headers{end+1} = newHeader;
    hdr.chan_files{end+1}   = ChanFiles{i};
end
hdr.NumChannels = length(hdr.chan_files);


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder = 'l';
sFile.filename  = hdr.BaseFolder;
sFile.format    = 'EEG-NEURALYNX';
if isfield(hdr, 'HardwareSubSystemType')
    sFile.device = hdr.HardwareSubSystemType;
else
    sFile.device = 'Neuralynx';
end
sFile.header    = hdr;
sFile.comment   = Comment;
% Consider that the sampling rate of the file is the sampling rate of the first signal
sFile.prop.sfreq   = hdr.SamplingFrequency;
sFile.prop.times   = [0, hdr.NumSamples - 1] ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% No info on bad channels
sFile.channelflag = ones(hdr.NumChannels, 1);


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Neuralynx channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.NumChannels]);
% For each channel
for i = 1:hdr.NumChannels
    [fPath,fName,fExt] = bst_fileparts(hdr.chan_files{i});
    ChannelMat.Channel(i).Name    = fName;
    ChannelMat.Channel(i).Loc     = [0; 0; 0];
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
    ChannelMat.Channel(i).Comment = [];
end


%% ===== READ EVENTS =====
% Events are saved in the file Events.nev
if ~isempty(EventFile)
    % Read the .nve file using FieldTrip routine
    nev = neuralynx_read_nev(EventFile);
    % Create events list
    if ~isempty(nev)
        % Retrieve information of interest
        allTypes = [nev.EventNumber];
        allSamples  = [nev.TimeStamp];
        % Convert the time stamps to time from the beginning of the file
        allSamples = round(double(allSamples - hdr.FirstTimeStamp) / 1e6 .* sFile.prop.sfreq);
        % Get list of events
        [uniqueType, iUnique] = unique(allTypes);
        iUnique = sort(iUnique);
        uniqueType = allTypes(iUnique);
        uniqueString = {nev(iUnique).EventString};
        % Initialize list of events
        events = repmat(db_template('event'), 1, length(uniqueType));
        % Format list
        for iEvt = 1:length(uniqueType)
            % Find list of occurences of this event
            iOcc = ((allTypes == uniqueType(iEvt)) & (allSamples >= 0));
            % Fill events structure
            events(iEvt).label      = uniqueString{iEvt};
            events(iEvt).color      = [];
            events(iEvt).reactTimes = [];
            events(iEvt).select     = 1;
            events(iEvt).times      = allSamples(iOcc) ./ sFile.prop.sfreq;
            events(iEvt).epochs     = ones(1, length(events(iEvt).times));  % Epoch: set as 1 for all the occurrences
            events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
            events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
        end
        % Import this list
        sFile = import_events(sFile, [], events);
    end
end


