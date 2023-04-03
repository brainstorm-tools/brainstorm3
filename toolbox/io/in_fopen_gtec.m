function [sFile, ChannelMat] = in_fopen_gtec(DataFile)
% IN_FOPEN_GTEC: Open a g.tec/g.Recorder .mat/.hdf5 file.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_gtec(DataFile)

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
% Authors: Francois Tadel, 2015-2018


%% ===== READ FILE HEADER =====
% Get format
[fPath,fBase,fExt] = bst_fileparts(DataFile);
% MATLAB .mat
if strcmpi(fExt, '.mat')
    warning('off', 'MATLAB:unknownObjectNowStruct');
    FileMat = load(DataFile, '-mat');
    warning('on', 'MATLAB:unknownObjectNowStruct');
    % Check file contents
    if isempty(FileMat) || ~isfield(FileMat, 'P_C_S') || isempty(FileMat.P_C_S)
        error('Invalid g.tec Matlab export: Missing field "P_C_S".');
    end
    % Save file header
    hdr = FileMat.P_C_S;
    hdr.format = 'mat';
    hdr.nEpochs = size(hdr.data, 1);
    hdr.nTime = size(hdr.data, 2);
    
% HDF5
elseif strcmpi(fExt, '.hdf5')
    % h5disp(DataFile) 
    % info = hdf5info(DataFile);  
    % s = hdf5read(DataFile, '/RawData/AcquisitionTaskDescription')
    % s = hdf5read(DataFile, '/RawData/SessionDescription')
    % s = hdf5read(DataFile, '/RawData/SubjectDescription')
    % s = hdf5read(DataFile, '/RawData/Samples')
    
    % Read acquisition parameters
    try
        AcqXml = hdf5read(DataFile, 'RawData/AcquisitionTaskDescription');
        sAcqXml = in_xml(AcqXml.Data);
    catch
        error('Invalid g.tec HDF5 file: Missing dataset "RawData/AcquisitionTaskDescription".');
    end
    % Read data
    try
        Data = hdf5read(DataFile,'RawData/Samples');
    catch
        error('Invalid g.tec HDF5 file: Missing dataset "RawData/Samples".');
    end
    % Read events
    hdr.markername = [];
    hdr.marker     = [];
    try
        % Get events timing and ID
        evtTime = double(hdf5read(DataFile, '/AsynchronData/Time'));
        evtID = double(hdf5read(DataFile, '/AsynchronData/TypeID'));
        % Get events descriptions
        sSignalType = hdf5read(DataFile, '/AsynchronData/AsynchronSignalTypes');
        sSignalTypeXml = in_xml(sSignalType.Data);
        triggerName = cellfun(@(c)c.text, {sSignalTypeXml.ArrayOfAsynchronSignalDescription.AsynchronSignalDescription.Name}, 'UniformOutput', 0);
        triggerID = cellfun(@(c)str2num(c.text), {sSignalTypeXml.ArrayOfAsynchronSignalDescription.AsynchronSignalDescription.ID});
        % Find used trigger types
        iUsedTrig = find(ismember(triggerID, unique(evtID)));
        % Keep only used triggers
        if ~isempty(iUsedTrig)
            triggerName = triggerName(iUsedTrig);
            triggerID = triggerID(iUsedTrig);
            % Create list of trigger entries based on trigger IDs
            evtTrigIndex = zeros(length(evtID), 1);
            for i = 1:length(triggerID)
                evtTrigIndex(evtID == triggerID(i)) = i;
            end
            % Convert to obtain the same marker info as in the .mat files
            hdr.markername = triggerName;
            hdr.marker = [evtTime', ones(length(evtTime),1), evtTrigIndex];
        end
    catch
        e = lasterr();
        disp(['gtect> No events could be read from this file.' 10 ...
              'gtect> Error: ' e]);
        hdr.markername = [];
        hdr.marker = [];
    end
    % Read information of interest
    hdr.format = 'hdf5';
    hdr.numberchannels = str2num(sAcqXml.AcquisitionTaskDescription.NumberOfAcquiredChannels.text);
    hdr.samplingfrequency = str2num(sAcqXml.AcquisitionTaskDescription.SamplingFrequency.text);
    hdr.nTime = size(Data, 2);
    % Get channel name
    hdr.channelname = cell(1, hdr.numberchannels);
    for i = 1:hdr.numberchannels
        if (i <= length(sAcqXml.AcquisitionTaskDescription.ChannelProperties.ChannelProperties)) && ~isempty(sAcqXml.AcquisitionTaskDescription.ChannelProperties.ChannelProperties(i).ChannelName)
            hdr.channelname{i} = sAcqXml.AcquisitionTaskDescription.ChannelProperties.ChannelProperties(i).ChannelName.text;
        end
    end
    % Information not found (yet)
    hdr.amplifiername = 'gtect';
    hdr.nEpochs       = 1;
    hdr.pretrigger    = 0;
else
    error('Invalid g.tec file.');
end


%% ===== FILL STRUCTURE =====
% Initialize returned file structure                    
sFile = db_template('sfile');                     
% Add information read from header
sFile.filename   = DataFile;
sFile.fid        = [];  
sFile.format     = 'EEG-GTEC';
sFile.device     = hdr.amplifiername;
sFile.byteorder  = 'l';
sFile.header     = hdr;
% Properties of the recordings
sFile.prop.sfreq   = double(hdr.samplingfrequency);
sFile.prop.times   = ([0, hdr.nTime-1] - hdr.pretrigger) ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
sFile.channelflag  = ones(hdr.numberchannels,1); % GOOD=1; BAD=-1;
% Epochs, if any
if (hdr.nEpochs > 1)
    for i = 1:hdr.nEpochs
        sFile.epochs(i).label   = sprintf('Trial #%d', i);
        sFile.epochs(i).times   = sFile.prop.times;
        sFile.epochs(i).nAvg    = 1;
        sFile.epochs(i).select  = 1;
        sFile.epochs(i).bad         = 0;
        sFile.epochs(i).channelflag = [];
    end
end


%% ===== EVENTS =====
for iEvt = 1:length(hdr.markername)
    % Get all the occurrences
    iOcc = find(hdr.marker(:,3) == iEvt);
    % Create event structure
    sFile.events(iEvt).label   = hdr.markername{iEvt};
    samples = hdr.marker(iOcc,1)';
    sFile.events(iEvt).epochs  = hdr.marker(iOcc,2)';
    if ~isempty(sFile.epochs)
        for i = 1:length(samples)
            iEpoch =  sFile.events(iEvt).epochs(i);
            samples(i) = samples(i) + round(sFile.epochs(iEpoch).times(1) * sFile.prop.sfreq) - 1;
        end
    end
    sFile.events(iEvt).times    = samples ./ sFile.prop.sfreq;
    sFile.events(iEvt).select   = 1;
    sFile.events(iEvt).channels = [];
    sFile.events(iEvt).notes    = [];
end


%% ===== CHANNEL FILE =====
% Initialize structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'g.tec channels';
ChannelMat.Channel = repmat(db_template('channeldesc'), 1, hdr.numberchannels);
% Channels information
for iChan = 1:hdr.numberchannels
    if ~isempty(hdr.channelname) && ~isempty(hdr.channelname{iChan})
        ChannelMat.Channel(iChan).Name = hdr.channelname{iChan};
    else
        ChannelMat.Channel(iChan).Name = sprintf('E%03d', iChan);
    end
    ChannelMat.Channel(iChan).Type    = 'EEG';
    ChannelMat.Channel(iChan).Loc     = [0; 0; 0];
    ChannelMat.Channel(iChan).Orient  = [];
    ChannelMat.Channel(iChan).Weight  = 1;
    ChannelMat.Channel(iChan).Comment = [];  
end









