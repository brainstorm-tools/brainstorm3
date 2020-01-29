function sFile = in_fopen_egi(DataFile, EpochFile, BciFile, ImportOptions)
% IN_FOPEN_EGI: Open a EGI .raw file (continuous recordings).
%
% USAGE:  sFile = in_fopen_egi(DataFile, EpochFile, BciFile, ImportOptions)
%         sFile = in_fopen_egi(DataFile, EpochFile, BciFile)
%         sFile = in_fopen_egi(DataFile, EpochFile)             : Auto-detect .bci file (or do not use one)
%         sFile = in_fopen_egi(DataFile)                        : Auto-detect .epoc file (or do not use one)
%
%     - ImportOptions : Structure that describes how to import the recordings.
%       => Fields used: DisplayMessages

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
% Authors: Francois Tadel, 2009-2015
        
%% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end
% Locate .bci file(s)
[fPath, fBase, fExt] = bst_fileparts(DataFile);
if (nargin < 3) || isempty(BciFile) || ~file_exist(BciFile)
    BciFile = bst_fullfile(fPath, [fBase '.bci']);
    if ~file_exist(BciFile)
        bciList = dir(bst_fullfile(fPath, '*.bci'));
        if ~isempty(bciList)
            BciFile = cell(length(bciList), 1);
            for i = 1:length(bciList);
                BciFile{i} = bst_fullfile(fPath, bciList(i).name);
            end
        else
            BciFile = [];
        end
    end
end
% Locate .epoc/.epo file
if (nargin < 2) || isempty(EpochFile) || ~file_exist(EpochFile)
    EpochFile = bst_fullfile(fPath, [fBase '.epoc']);
    if ~file_exist(EpochFile)
        EpochFile = bst_fullfile(fPath, [fBase '.epo']);
        if ~file_exist(EpochFile)
            EpochFile = [];
        end
    end
end


%% ===== READ HEADER =====
% Open file
byteorder = 'b';
sfid = fopen(DataFile, 'r', byteorder);
if (sfid == -1)
    error('Could not open file.');
end
% Read header 
bst_progress('text', 'Reading header...');
header = egi_read_header(sfid);


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = byteorder;
sFile.filename   = DataFile;
sFile.format     = 'EEG-EGI-RAW';
sFile.prop.sfreq = double(header.samplingRate);
sFile.prop.nAvg  = 1;
sFile.channelflag= ones(header.numChans,1);
sFile.device     = 'EGI';
sFile.header     = header;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;
% Acquisition date
sFile.acq_date = datestr(datenum([header.recordingTime.Year, header.recordingTime.Month, header.recordingTime.Day]), 'dd-mmm-yyyy');


%% ===== CHECK FILE INTEGRITY =====
% Get theoretical size of the file, based on the information of the header
theorySize = header.numSamples * (header.numChans + header.numEvents) * header.bytesize + header.datapos;
% Get real size of the file
fileInfo = dir(DataFile);
realSize = fileInfo.bytes;
% If file is too short: warning
if (realSize < theorySize)
    isFix = java_dialog('confirm', sprintf(['This file looks damaged: its size does not match the information in the header.\n', ...
                                            'Header information: %d bytes\n', ...
                                            'Size on the hard drive: %d bytes\n\n', ...
                                            'Do you want to try to open this file anyway?'], theorySize, realSize), ...
                                   'Read EGI file');
    % User canceled: Stop importing file
    if ~isFix
        fclose(sfid);
        sFile = [];
        return
    end
    % Fix the number of samples: set to what is available on the hard drive
    header.numSamples = floor((realSize - header.datapos) / (header.numChans + header.numEvents) / header.bytesize);
    sFile.header.numSamples = header.numSamples;
end


%% ===== READ EPOCHS AND EVENTS =====
isUseBci = 0;
if (sFile.header.numEvents >= 1)
    if ImportOptions.DisplayMessages
        options = java_dialog('checkbox', 'Options for EGI raw files:', 'Read EGI file', [], ...
                              {'Read events', ...
                               'Read as epoched data', ...
                               'Import bad channels/trials (.bci)'}, [1, 1, ~isempty(BciFile)]);
        % User canceled: Stop importing file
        if isempty(options)
            fclose(sfid);
            sFile = [];
            return
        end
        isReadEvents = options(1);
        isUseEpoc = options(2);
        isUseBci = options(3);
    else
        isReadEvents = 1;
        isUseEpoc = 1;
        isUseBci = (~isempty(BciFile) && ischar(BciFile));
    end
    if isReadEvents
        bst_progress('text', 'Reading events channel...');
        [sFile.events, sFile.epochs, sFile.header.epochs_tim0] = egi_read_events(sFile, sfid, isUseEpoc);
    end
end
% Get file samples indices
if ~isempty(sFile.epochs)
    sFile.prop.times = [min([sFile.epochs.times]), max([sFile.epochs.times])];
else
    sFile.prop.times = [0, header.numSamples - 1] ./ sFile.prop.sfreq;
end
% Close data file
fclose(sfid);


%% ===== READ EPOCH FILE =====
bst_progress('text', 'Reading epoch file...');
% If epoch file was found, read it
if ~isempty(EpochFile) && ~isempty(sFile.epochs)
    % Open .EPOC file
    fid2 = fopen(EpochFile, 'r');
    if (fid2 == -1)
        error('Brainstorm:InvalidEpocFile', ['Cannot open EPOCH file: ' strrep(EpochFile,'\','\\') '"']);
    end
    % Read file
    % EpochList = textscan(fid2, '%s%*[^\n]');
    EpochList = textscan(fid2, '%s%*[^\n]', 'Delimiter', '-');
    EpochList = cellfun(@strtrim, EpochList, 'UniformOutput', false);
    % Close file
    fclose(fid2);
    % Extract only conditions names
    if iscell(EpochList) && (length(EpochList) >= 1)
        EpochList = EpochList{1};
        % Look for errors between number of epochs in RAW and EPOC files
        if (length(EpochList) ~= length(sFile.epochs))
            warning('Brainstorm:InvalidEpochFile', ['Invalid epoch file "' strrep(EpochFile,'\','\\') '".' 10 10 'Number of epochs does not match with .RAW file.']);
        else
            % Build Matlab structures to represent these epochs
            isAllEqual = all(strcmpi(EpochList, EpochList{1}));
            for i = 1:length(EpochList)
                if isAllEqual
                    sFile.epochs(i).label = sprintf('%s#%03d', EpochList{i}, i);
                else
                    sFile.epochs(i).label = EpochList{i};
                end
            end
        end
    end
end

%% ===== READ BCI FILE =====
% If epoch file was found, read it
if isUseBci && ~isempty(sFile.epochs)
    bst_progress('text', 'Reading metadata (.bci) file...');
    % Pick file if multiple choice (or no choice)
    if isempty(BciFile) || ~ischar(BciFile)
        BciFile = java_getfile('open', 'Import metadata...', bst_fileparts(DataFile), 'single', 'files', ...
                               {{'.bci'}, 'EGI metadata (*.bci)', 'EGI-BCI'}, 1);
        if isempty(BciFile)
            return
        end
    end
    % Open file
    fid2 = fopen(BciFile, 'r');
    if (fid2 == -1)
        error('Brainstorm:InvalidBciFile', ['Cannot open BCI file: ' strrep(BciFile,'\','\\') '"']);
    end
    % Skip the first line
    fgetl(fid2);
    % Prepare variables
    isBadTrial = [];
    channelflag = {};
    % Loop line/line until reaching the end
    while 1
        % Read one line
        epochLine = fgetl(fid2);
        if isempty(epochLine) || (isnumeric(epochLine) && (epochLine == -1)) || isempty(strtrim(epochLine))
            break;
        end
        % Read epoch information
        [epochInfo, pos] = textscan(epochLine, '%s %d %d %s', 1);  % Epoch name
        isBadTrial(end+1) = strcmpi(epochInfo{4}, 'bad');
        % Read channel info
        channelinfo = sscanf(epochLine(pos:end), '%d', [2, header.numChans]);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% WARNING: MIGHT BE WRONG....
        %%% The number of channels in the BCI file is the number of electrodes, while
        %%% we need to define a channelflag with for all the channels of data
        %%% => There is typically at least one more channel (ref/cz)
        %%% => Using the global channelflag size, and filling it with hoping that all the 
        %%%    real EEG electrodes are all a the beginning of the list
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        channelflag{end+1} = sFile.channelflag;
        channelflag{end}(channelinfo(2,:) == 0) = -1;
    end   
    % Close file
    fclose(fid2);
    
    % Copy those information in the epochs structure, if valid
    nEpochs = length(sFile.epochs);
    if (length(isBadTrial) == nEpochs) && (length(channelflag) == nEpochs)
        for iEpoch = 1:nEpochs
            sFile.epochs(iEpoch).bad = isBadTrial(iEpoch);
            sFile.epochs(iEpoch).channelflag = channelflag{iEpoch}(:);
        end
    else
        warning('EGI> Metadata file (.bci) could not be read: Invalid format.');
    end
end




