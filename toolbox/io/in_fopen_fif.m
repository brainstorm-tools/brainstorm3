function [sFile, ChannelMat] = in_fopen_fif(DataFile, ImportOptions)
% IN_FOPEN_FIF: Open a FIF file, and get all the data and channel information.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_fif(DataFile, ImportOptions)
%         [sFile, ChannelMat] = in_fopen_fif(DataFile)
%
% INPUT: 
%     - ImportOptions : Structure that describes how to import the recordings. Fields directly used:
%       => Fields used: ChannelAlign, ChannelReplace, EventsMode, DisplayMessages

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
% Authors: Francois Tadel, 2009-2019

%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end

%% ===== CHECK FILE TYPE =====
% Check if file is an event file
[fPath, fBase, fExt] = bst_fileparts(DataFile);
if ~strcmpi(fExt, '.fif')
    error(['File is not in FIF format: ' 10 '"' DataFile '"']);
elseif (length(fBase) > 4) && strcmpi(fBase(end-3:end), '-eve')
    % Event file => try to find the regular file
    DataFile = bst_fullfile(fPath, [fBase(1:end-4), fExt]);
    if ~file_exist(DataFile)
        error('You are trying to import an event file.');
    else
        warning(['Selected file was an event file. Now reading file:' 10 DataFile]); 
    end
end

%% ===== OPEN FIF FILE =====
% Open file
[ fid, tree ] = fiff_open(DataFile);
if (fid < 0)
    error(['Cannot open FIFF file : "' DataFile '"']);
end
% Read info structure
try
    [ info, meas ] = fiff_read_meas_info(fid, tree);
catch
    err = lasterror;
    disp([10 'BST> Error: Could not find measurement data: ' 10 err.message 10]);
    info.chs = [];
    info.dig = fif_read_headpoints(fid, tree);
    meas = [];
end

% Check if file was opened successfully
isNoData = ~isfield(info, 'sfreq');
if isNoData && isempty(info.chs) && isempty(info.dig)
    sFile = [];
    ChannelMat = [];
    fclose(fid);
    return
end

% Initialize file structure
sFile = db_template('sfile');
% Fill this structure
sFile.filename = DataFile;
sFile.format   = 'FIF';

% Part reserved to FIF files with recordings
if ~isNoData
    sFile.prop.sfreq  = double(info.sfreq);
end
% Header of the FIF file
sFile.header.tree = tree;
sFile.header.info = info;
sFile.header.meas = meas;
sFile.header.fif_list = {DataFile};
sFile.header.fif_times = [];
sFile.header.fif_headers = [];
    
%% ===== READ CHANNEL FILE =====
% Read channel file from FIF and default coils file
[ChannelMat, Device] = in_channel_fif(sFile, ImportOptions);
% Get bad channels
ChannelFlag = ones(length(ChannelMat.Channel),1);
if isfield(info, 'bads') && ~isempty(info.bads)
    % For each bad channel (referenced by channel name): find its indice
    for iBad = 1:length(info.bads)
        iChan = find(strcmpi(info.bads(iBad), info.ch_names));
        ChannelFlag(iChan) = -1;
    end
end
% Find if results are already compensated
if ~isempty(ChannelMat.MegRefCoef)
    % Get current level of compensation
    iMeg = good_channel(ChannelMat.Channel, [], 'MEG');
    currentComp = bitshift(double([info.chs(iMeg).coil_type]), -16);
    % If not all the same value: error
    if ~all(currentComp == currentComp(1))
        error('CTF compensation is not set equally on all MEG channels');
    end
    % Current compensation order
    sFile.prop.currCtfComp = currentComp(1);
    % Destination compensation order (keep compensation order, unless it is 0)
    if (currentComp(1) == 0)
        sFile.prop.destCtfComp = 3;
    else
        sFile.prop.destCtfComp = currentComp(1);
    end
end

% Store results in sFile structure
sFile.device      = Device;
sFile.channelflag = ChannelFlag;
sFile.byteorder = 'b';
% Acquisition date (saved in POSIX format in FIF file)
if isfield(info, 'meas_date') && ~isempty(info.meas_date)
    sFile.acq_date = str_date(info.meas_date(1), 'posix');
end


%% ===== READ DATA DESCRIPTION =====
% Get number of epochs
[epochs, sFile.header.epochData] = fif_get_epochs(sFile, fid);
nEpochs = length(epochs);

% === CHANNELS ONLY ===
% No recordings in FIF file, only channels => Nothing to read
if isempty(meas)
    sFile.format = 'channels';
% === RAW FILE ===
elseif (nEpochs == 0)
    % Read RAW file information
    raw = fif_setup_raw(sFile, fid, 1);
    % Fill sFile structure   
    sFile.prop.times = double([raw.first_samp, raw.last_samp]) ./ sFile.prop.sfreq;
    sFile.header.raw = raw;
    sFile.header.fif_times = sFile.prop.times;
    sFile.header.fif_headers = {sFile.header};
    % Read events information
    if iscell(ImportOptions.EventsMode) || ~strcmpi(ImportOptions.EventsMode, 'ignore')
        [sFile.events, ImportOptions] = fif_read_events(sFile, ChannelMat, ImportOptions);
        % Operation cancelled by user
        if isequal(sFile.events, -1)
            sFile = [];
            fclose(fid);
            return;
        end
    end
% === EVOKED/EPOCHED FILE ===
else
    % Build epochs structure
    for i = 1:length(epochs)
        sFile.epochs(i).label   = epochs(i).label;
        sFile.epochs(i).times   = epochs(i).times;
        sFile.epochs(i).nAvg    = epochs(i).nAvg;
        sFile.epochs(i).select  = isempty(strfind(epochs(i).label, 'std err'));
        sFile.epochs(i).bad         = 0;
        sFile.epochs(i).channelflag = [];
    end
    % Extract global min/max for time and samples indices
    sFile.prop.times = [min([sFile.epochs.times]),   max([sFile.epochs.times])];
%     % Read events
%     [fifEvt, mappings] = fiff_read_events(fid,tree);
%     if ~isempty(fifEvt) && ~isempty(mappings)
%         % Initialize returned structure
%         uniqueEvt = unique(fifEvt(:,3)');
%         events = repmat(db_template('event'), [1, length(uniqueEvt)]);
%         % Parse event names
%         mappings = str_split(mappings, ';');
%         mappings = cellfun(@(c)str_split(c,':'), mappings, 'UniformOutput', 0);
%         if (length(mappings) >= 2)
%             mappings = reshape([mappings{:}], 2, [])';
%         else
%             mappings = [];
%         end
%         % Create events list
%         for iEvt = 1:length(uniqueEvt)
%             % Find all the occurrences of event #iEvt
%             iMrk = find(fifEvt(:,3) == uniqueEvt(iEvt));
%             % Event label
%             if ~isempty(mappings) && ismember(num2str(uniqueEvt(iEvt)), mappings(:,2))
%                 iMap = find(strcmpi(mappings(:,2), num2str(uniqueEvt(iEvt))));
%                 events(iEvt).label = mappings{iMap, 1};
%             else
%                 events(iEvt).label = num2str(uniqueEvt{iEvt});
%             end
%             % 
%             epochSmp = round((sFile.prop.times(2) - sFile.prop.times(1)) .* sFile.prop.sfreq);
%             samples = double(fifEvt(iMrk,1))';
%             events(iEvt).epochs     = floor(samples ./ epochSmp) + 1;
%             events(iEvt).times      = mod(samples, epochSmp) ./ sFile.prop.sfreq + sFile.prop.times(1);
%             events(iEvt).reactTimes = [];
%             events(iEvt).select     = 1;
%             events(iEvt).channels   = cell(1, size(events(iEvt).times, 2));
%             events(iEvt).notes      = cell(1, size(events(iEvt).times, 2));
%         end
%         sFile.events = events;
%     end
end


%% ===== GET LINKED FILES =====
% Recordings bigger than 2Gb can't be stored in FIF format, and need to be split in multiple files.
% We expect to call in_fopen_fif.m on the first .fif file in the list, and then the files should be
% chained using the fields FIFF_REF_FILE_NAME.
% If linked files are found, in_fopen_fif is called recursively and appended to the definition of the first file.

% Only RAW files can be linked
if ~isempty(meas) && (nEpochs == 0) && (~isempty(raw.next_fname) || ~isempty(raw.next_num))
    NextFile = [];
    % 1) If there is already a file name, try to use it
    if ~isempty(raw.next_fname)
        NextFile = bst_fullfile(fPath, raw.next_fname);
        % File doesn't exist...
        if ~file_exist(NextFile)
            NextFile = [];
        end
    end
    % 2) Try to find the format of the files using the file number
    %    (major problem: sometimes the first file is not numbered)
    if isempty(NextFile) && ~isempty(raw.next_num)
        % Trying with -0
        numTag = sprintf('-%d', raw.next_num - 1);
        iNum = strfind(sFile.filename, numTag);
        if ~isempty(iNum)
            % Keep only the last occurrence (the same string may appear before in the filename)
            iNum = iNum(end);
            NextFile = [sFile.filename(1:iNum-1), sprintf('-%d', raw.next_num), sFile.filename(iNum+length(numTag):end)];
        else
            % Trying with -00 (for BIDS-compatible split naming: https://github.com/mne-tools/mne-python/blob/cd0eff12535880cd7a6551ad4ceeff771ea8b3a9/mne/io/utils.py#L323)
            numTag = sprintf('-%02d', raw.next_num - 1);
            iNum = strfind(sFile.filename, numTag);
            if ~isempty(iNum)
                iNum = iNum(end);
                NextFile = [sFile.filename(1:iNum-1), sprintf('-%02d', raw.next_num), sFile.filename(iNum+length(numTag):end)];
            end
        end
        % File doesn't exist...
        if ~file_exist(NextFile)
            NextFile = [];
        end
    end
    % Get the other FIF files in the folder, to look for file #1 (in case number #0 is not numbered)
    if isempty(NextFile) && (raw.next_num == 1)
        dirFif = dir(bst_fullfile(fPath, ['*', fExt]));
        curFile = [fBase, fExt];
        listFif = setdiff({dirFif.name}, curFile);
        numTag = sprintf('-%d', raw.next_num);
        % Remove the num tag in all the filenames, and see if we find the current file
        for iFile = 1:length(listFif)
            iNum = strfind(listFif{iFile}, numTag);
            if ~isempty(iNum)
                iNum = iNum(end);
                if strcmp(curFile, [listFif{iFile}(1:iNum-1), listFif{iFile}(iNum+length(numTag):end)])
                    NextFile = bst_fullfile(fPath, listFif{iFile});
                    break;
                end
            end
        end
    end
    
    % Read linked file
    if ~isempty(NextFile)
        % Display linked file
        disp([10 'FIF> Linking next file: ' NextFile]);
        % Load the header of the linked file recursively
        sFileNext = in_fopen_fif(NextFile, ImportOptions);
        % Concatenate files (check time compatibility)
        if isempty(sFileNext)
            % File could not be read...
            warning(['FIF> Missing link: Could not read file: ' NextFile]);
        elseif (sFile.prop.sfreq ~= sFileNext.prop.sfreq) || (sFileNext.prop.times(1) - sFile.prop.times(2) - 1/sFile.prop.sfreq > 0.001)
            warning(['FIF> Missing link: Recordings in the following files are not contiguous:' 10 ...
                    DataFile ': ' sprintf('%1.3fs - %1.3fs', sFile.prop.times) 10 ...
                    NextFile ': ' sprintf('%1.3fs - %1.3fs', sFileNext.prop.times)]);
        else
            sFile.prop.times = [sFile.prop.times(1), sFileNext.prop.times(2)];
            % Add to list of files
            sFile.header.fif_list    = [sFile.header.fif_list, sFileNext.header.fif_list];
            sFile.header.fif_times   = cat(1, sFile.header.fif_times, sFileNext.header.fif_times);
            sFile.header.fif_headers = [sFile.header.fif_headers, sFileNext.header.fif_headers];
            % Import events from the next file
            if ~isempty(sFileNext.events)
                sFile = import_events(sFile, [], sFileNext.events);
            end
        end
    else
        warning(['FIF> Missing link: Could not find the file following "' DataFile '".']);
    end
end


% Close file
if ~isempty(fopen(fid))
    fclose(fid);
end

