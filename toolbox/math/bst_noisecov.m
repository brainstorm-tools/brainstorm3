function NoiseCovFiles = bst_noisecov(iTargetStudies, iDataStudies, iDatas, Options, isDataCov)
% BST_NOISECOV: Compute noise covariance matrix for a set of studies.
%
% USAGE:  NoiseCovFiles = bst_noisecov(iTargetStudies, iDataStudies, iDatas, Options=[ask], isDataCov=0)                      
%               Options = bst_noisecov()
%
% INPUT: 
%     - iTargetStudies : List of studies indices for which the noise covariance matrix is produced
%     - iDataStudies   : [1,nData] int, List of data files to use for computation (studies indices)
%                        If not defined or [], uses all the recordings from all the studies (iTargetStudies)
%     - iDatas         : [1,nData] int, List of data files to use for computation (data indices)
%     - isDataCov      : If 1, saves the result as the data covariance, if 0 saves it as the noise covariance
%     - Options        : Structure with the following fields (if not defined: asked to the user)
%           |- Baseline        : [tStart, tStop]; range of time values considered as baseline
%           |- RemoveDcOffset  : {'file', 'all'}; 'all' removes the baseline avg file by file; 'all' computes the baseline avg from all the files
%           |- ReplaceFile     : If 1 replaces automatically the previous noisecov file without asking the user for a confirmation
%           |- ChannelTypes    : Cell array with the list of selected channel types

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
% Authors: Francois Tadel, 2009-2022

%% ===== RETURN DEFAULT OPTIONS =====
% Options structure
if (nargin == 0)
    NoiseCovFiles = struct(...
        'Baseline',        [-.1, 0], ...
        'DataTimeWindow',  [0, 1], ...
        'RemoveDcOffset',  'file', ...
        'ReplaceFile',     [], ...
        'ChannelTypes',    []);
    return;
end

%% ===== PARSE INPUTS =====
if (nargin < 5) || isempty(isDataCov)
    isDataCov = [];
end
if (nargin < 4) || isempty(Options)
    Options = [];
end
NoiseCovFiles = {};
isRaw = 0;
% Get source files
if (nargin < 3) || isempty(iDataStudies) || (length(iDataStudies) ~= length(iDatas))
    % Get all the datafiles depending on the target studies
    sStudies = bst_get('Study', iTargetStudies);
    sDatas = [sStudies.Data];
    DataFiles = {sDatas.FileName};
else
    % Unique studies
    uniqueStudies = unique(iDataStudies);
    DataFiles = {};
    % For each study
    for i = 1:length(uniqueStudies)
        % Get study
        iStudy = uniqueStudies(i);
        sStudy = bst_get('Study', iStudy);
        iDataLocal = iDatas(iDataStudies == iStudy);
        % Add files to list
        DataFiles = cat(2, DataFiles, {sStudy.Data(iDataLocal).FileName});
        % Raw data
        isRaw = any(strcmpi({sStudy.Data(iDataLocal).DataType}, 'raw'));
    end
end
% Default file tag
if isDataCov
    strComment = 'Data covariance';
else
    strComment = 'Noise covariance';
end


%% ===== GET DATA CHANNELS =====
% Get channel studies
sTargetStudies = bst_get('Study', iTargetStudies);
% Find a study with channel file
iWithChan = find(~cellfun(@isempty, {sTargetStudies.Channel}), 1);
if isempty(iWithChan)
    error('No channel file.');
end
% Get one channel study
sStudy = sTargetStudies(iWithChan);
% Load channel file
ChannelMat = in_bst_channel(sStudy.Channel.FileName);
% Get all the valid channels
iChan = good_channel(ChannelMat.Channel, [], {'MEG','EEG','ECOG','SEEG'});
nChanAll = length(ChannelMat.Channel);
% Get the possible channe types
ChannelTypes = unique({ChannelMat.Channel(iChan).Type});


%% ===== READ ALL TIME VECTORS =====
% Progress bar
bst_progress('start', 'Read recordings information', 'Analysing input files...', 0, length(DataFiles));
% Regular list of imported data files
if ~isRaw
    nFiles = length(DataFiles);
    DataMats = repmat(struct('Time', [], 'SamplingRate', [], 'nAvg', [], 'Leff', [], 'iEpoch', [], 'iBadTime', []), nFiles);
    % Loop on all input files
    for iFile = 1:length(DataFiles)
        % Load file metadata
        DataMat = in_bst_data(DataFiles{iFile}, 'Time', 'nAvg', 'Leff');
        % Check file time
        if (length(DataMat.Time) < 3)
            error(['File has no time dimension: ' DataFiles{iFile}]);
        end
        % Check sampling rate 
        if (iFile == 1)
            SamplingRate = DataMat.Time(2) - DataMat.Time(1);
        elseif (abs(SamplingRate - (DataMat.Time(2) - DataMat.Time(1))) > 1e-6)
            error(['The files you selected have different sampling frequencies. They should not be processed together.' 10 ...
                   'Please only select recordings with the same sampling frequency.']);
        end
        % Save values
        DataMats(iFile).Time = DataMat.Time;
        DataMats(iFile).nAvg = DataMat.nAvg;
        DataMats(iFile).Leff = DataMat.Leff;
        bst_progress('inc', 1);
    end
% Raw file
else
    % Only one raw file allowed
    if (length(DataFiles) > 1)
        error('Only one raw file allowed for covariance computation');
    end
    nFiles = 1;
    % Read the description of the raw file
    RawMat = in_bst_data(DataFiles{1});
    sFile = RawMat.F;
    clear RawMat;
    % Get bad segments/epochs
    [badSeg, badEpochs] = panel_record('GetBadSegments', sFile);
    
    % Initialize DataMats structure
    DataMats = repmat(struct('Time', [], 'nAvg', [], 'Leff', [], 'iEpoch', [], 'iBadTime', []), 0);
    % Define size of blocks to read
    MAX_BLOCK_SIZE = 10000;
    % Loop on epochs
    for iEpoch = 1:max(length(sFile.epochs), 1)
        % Bad epoch
        if ~isempty(sFile.epochs) && sFile.epochs(iEpoch).bad
            disp(sprintf('NOISECOV> Ignoring epoch #%d (tagged as bad)', iEpoch));
        end
        % Get the bad segments for this epoch
        iBadEpoch = find(badEpochs == iEpoch);
        if ~isempty(iBadEpoch)
            badSegEpoc = badSeg(:, iBadEpoch);
        else
            badSegEpoc = [];
        end
        % Get total number of samples
        if ~isempty(sFile.epochs)
            samples = round(sFile.epochs(iEpoch).times .* sFile.prop.sfreq);
            nAvg = double(sFile.epochs(iEpoch).nAvg);
        else
            samples = round(sFile.prop.times .* sFile.prop.sfreq);
            nAvg = 1;
        end
        totalSmpLength = double(samples(2) - samples(1)) + 1;
        % Number of blocks to split this epoch in
        nbBlocks = ceil(totalSmpLength / MAX_BLOCK_SIZE);
        % For each block
        for iBlock = 1:nbBlocks
            % Get samples indices for this block (start ind = 0)
            smpBlock = samples(1) + [(iBlock - 1) * MAX_BLOCK_SIZE, min(iBlock * MAX_BLOCK_SIZE - 1, totalSmpLength - 1)];
            smpList = smpBlock(1):smpBlock(2);
            % Create a data block
            iNew = length(DataMats) + 1;
            DataMats(iNew).iEpoch = iEpoch;
            DataMats(iNew).Time   = smpList ./ sFile.prop.sfreq;
            DataMats(iNew).nAvg   = nAvg;
            DataMats(iNew).Leff   = nAvg;
            % Remove the portions that have bad segments in them
            iBadTime = [];
            for ix = 1:size(badSegEpoc, 2)
                iBadTime = [iBadTime, find((smpList >= badSegEpoc(1,ix)) & (smpList <= badSegEpoc(2,ix)))];
            end
            if ~isempty(iBadTime)
                DataMats(iNew).iBadTime = iBadTime;
            end
        end
    end
    SamplingRate = 1 ./ sFile.prop.sfreq;
end
% Get number of samples and sampling rates
nSamples = length([DataMats.Time]) - length([DataMats.iBadTime]);
% Close progress bar
bst_progress('stop');
% Check number of actual samples available for computation
if (nSamples == 0)
    error('This selection does not contain any file that can be used for computing the covariance matrix.');
end


%% ===== GET NOISECOV OPTIONS ======
% Get number of files
nBlocks = length(DataMats);
% If the options were not passed in argument
if isempty(Options)
    % Loop to get all the valid times
    allTimes = [];
    for iFile = 1:length(DataMats)
        tmpTime = DataMats(iFile).Time;
        tmpTime(DataMats(iFile).iBadTime) = [];
        allTimes = [allTimes, tmpTime];
    end
    % Prepare GUI options
    guiOptions.timeSamples  = sort(allTimes);
    guiOptions.nFiles       = nFiles;
    guiOptions.nBlocks      = nBlocks;
    guiOptions.nChannels    = length(iChan);
    guiOptions.freq         = 1 ./ SamplingRate;
    guiOptions.isDataCov    = isDataCov;
    guiOptions.ChannelTypes = ChannelTypes;
    % Display dialog window
    Options = gui_show_dialog(strComment, @panel_noisecov, 1, [], guiOptions);
    if isempty(Options)
        return
    end
end
% Get only the channels of the selected modality
if ~isempty(Options.ChannelTypes)
    iChan = good_channel(ChannelMat.Channel, [], Options.ChannelTypes);
end
if isempty(iChan)
    error('No channels are selected from this file.');
end


%% ===== COMPUTE AVERAGE/TIME =====
if strcmpi(Options.RemoveDcOffset, 'all')
    % Compute the average across ALL the time samples of ALL the files
    Favg = zeros(nChanAll, 1);
    Ntotal = zeros(nChanAll, 1);
    % Progress bar
    bst_progress('start', 'Average across time', 'Computing average across time...', 0, nBlocks);
    % Loop on all the files
    for iFile = 1:nBlocks
        bst_progress('inc', 1);
        % Load recordings
        [DataMat, iTimeBaseline] = ReadRecordings();
        if isempty(iTimeBaseline)
            continue
        end
        % Get good channels
        iGoodChan = intersect(find(DataMat.ChannelFlag == 1), iChan);
        
        % === Compute average ===
        % Favg(iGoodChan)   = Favg(iGoodChan)   + double(DataMat.nAvg) .* sum(DataMat.F(iGoodChan,iTimeBaseline),2);
        % Ntotal(iGoodChan) = Ntotal(iGoodChan) + double(DataMat.nAvg) .* length(iTimeBaseline);
        Favg(iGoodChan)   = Favg(iGoodChan)   + double(DataMat.Leff) .* sum(DataMat.F(iGoodChan,iTimeBaseline),2);
        Ntotal(iGoodChan) = Ntotal(iGoodChan) + double(DataMat.Leff) .* length(iTimeBaseline);
    end
    % Remove zero-values in Ntotal
    Ntotal(Ntotal == 0) = 1;
    % Divide each channel by total number of time samples
    Favg = Favg ./ Ntotal;
end


%% ===== COMPUTE NOISE COVARIANCE =====
Ntotal   = zeros(nChanAll);
NoiseCov = zeros(nChanAll);
FourthMoment = zeros(nChanAll);
% Progress bar
bst_progress('start', strComment, ['Computing ' lower(strComment) '...'], 0, nBlocks);
drawnow
% Loop on all the files
for iFile = 1:nBlocks
    bst_progress('inc', 1);
    % Load recordings
    [DataMat, iTimeBaseline, iTimeCov] = ReadRecordings();
    if isempty(iTimeBaseline)
        continue
    end
    N = length(iTimeCov);
    
    % === Compute average ===
    if strcmpi(Options.RemoveDcOffset, 'file')
        % Get good channels
        iGoodChan = intersect(find(DataMat.ChannelFlag == 1), iChan);
        % Average baseline values
        Favg = mean(DataMat.F(:,iTimeBaseline), 2);
    end
    
    % === Compute covariance ===
    % Remove average
    DataMat.F(iGoodChan,:) = bst_bsxfun(@minus, DataMat.F(iGoodChan,:), Favg(iGoodChan,1));
    % Compute covariance for this file
    % fileCov  = DataMat.nAvg .* (DataMat.F(iGoodChan,iTimeCov)    * DataMat.F(iGoodChan,iTimeCov)'   );
    % fileCov2 = DataMat.nAvg .* (DataMat.F(iGoodChan,iTimeCov).^2 * DataMat.F(iGoodChan,iTimeCov)'.^2);
    fileCov  = DataMat.Leff .* (DataMat.F(iGoodChan,iTimeCov)    * DataMat.F(iGoodChan,iTimeCov)'   );
    fileCov2 = DataMat.Leff .* (DataMat.F(iGoodChan,iTimeCov).^2 * DataMat.F(iGoodChan,iTimeCov)'.^2);
    % Add file covariance to accumulator
    NoiseCov(iGoodChan,iGoodChan)     = NoiseCov(iGoodChan,iGoodChan)     + fileCov;
    FourthMoment(iGoodChan,iGoodChan) = FourthMoment(iGoodChan,iGoodChan) + fileCov2;
    Ntotal(iGoodChan,iGoodChan) = Ntotal(iGoodChan,iGoodChan) + N;
end
% Remove zeros from N matrix
Ntotal(Ntotal <= 1) = 2;
% Divide final matrix by number of samples
NoiseCov     = NoiseCov     ./ (Ntotal - 1);
FourthMoment = FourthMoment ./ (Ntotal - 1);
% Display result in the command window
nSamplesTotal = max(Ntotal(:));
% disp(['Number of time samples used for the noise covariance: ' num2str(nSamplesTotal)]);
% Check for NaN values
if (nnz(isnan(NoiseCov)) > 0)
    error('The output covariance contains NaN values. Please check your recordings and tag the bad channels correctly.');
end

%% ===== IMPORTING IN DATABASE =====
% Build file structure
NoiseCovMat = db_template('noisecovmat');
NoiseCovMat.NoiseCov     = NoiseCov;
NoiseCovMat.Comment      = [strComment ': '];
NoiseCovMat.nSamples     = Ntotal;
NoiseCovMat.FourthMoment = FourthMoment;
% Add names of sensors
allTypes = unique({ChannelMat.Channel(iChan).Type});
if all(ismember({'MEG MAG', 'MEG GRAD'}, allTypes))
    allTypes = setdiff(allTypes, {'MEG MAG', 'MEG GRAD'});
    allTypes = union(allTypes, {'MEG'});
end
for i = 1:length(allTypes)
    NoiseCovMat.Comment = [NoiseCovMat.Comment, allTypes{i}];
    if (i < length(allTypes))
        NoiseCovMat.Comment = [NoiseCovMat.Comment, ', '];
    end
end
% Add history entry
if isDataCov
    if isempty(Options.DataTimeWindow)
        strTime = 'Data=[All file], ';
    elseif (max(abs(Options.DataTimeWindow)) > 2)
        strTime = sprintf('Data=[%1.3f, %1.3f]s, ', Options.DataTimeWindow);
    else
        strTime = sprintf('Data=[%d, %d]ms, ', round(Options.DataTimeWindow * 1000));
    end
    if isempty(Options.Baseline)
        strTime = [strTime, 'Baseline=[All file]'];
    elseif (max(abs(Options.Baseline)) > 2)
        strTime = [strTime, sprintf('Baseline=[%1.3f, %1.3f]s', Options.Baseline)];
    else
        strTime = [strTime, sprintf('Baseline=[%d, %d]ms', round(Options.Baseline * 1000))];
    end
else
    if isempty(Options.Baseline)
        strTime = '[All file]';
    elseif (max(abs(Options.Baseline)) > 2)
        strTime = sprintf('[%1.3f, %1.3f]s', Options.Baseline);
    else
        strTime = sprintf('[%d, %d]ms', round(Options.Baseline * 1000));
    end
end
NoiseCovMat = bst_history('add', NoiseCovMat, 'compute', sprintf('Computed based on %d files (%d blocks, %d samples): %s, %s', nFiles, nBlocks, nSamplesTotal, strTime, Options.RemoveDcOffset));
% Add list of input files in history
for iSrc = 1:length(DataFiles)
    NoiseCovMat = bst_history('add', NoiseCovMat, 'src', DataFiles{iSrc});
end
% Save in database
NoiseCovFiles = import_noisecov(iTargetStudies, NoiseCovMat, Options.ReplaceFile, isDataCov);
% Close progress bar
bst_progress('stop');




%% ========================================================================
%  ======= SUPPORT FUNCTIONS ==============================================
%  ========================================================================

%% ===== READ RECORDINGS BLOCK =====
    function [DataMat, iTimeBaseline, iTimeCov] = ReadRecordings()
        iTimeBaseline = [];
        iTimeCov = [];
        if ~isRaw
            bst_progress('text', ['File: ' DataFiles{iFile}]);
            DataMat = in_bst_data(DataFiles{iFile}, 'F', 'ChannelFlag', 'Time', 'nAvg', 'Leff');
        else
            DataMat = DataMats(iFile);
            % If file is block does not contain any baseline segment: skip it
            if (length(DataMats(iFile).Time) < 2) || (~isempty(Options.Baseline) && ((DataMats(iFile).Time(end) < Options.Baseline(1)) || (DataMats(iFile).Time(1) > Options.Baseline(2))))
                return;
            end
            % Read raw block
            UseSsp = 1;
            [DataMat.F, DataMat.Time] = panel_record('ReadRawBlock', sFile, ChannelMat, DataMats(iFile).iEpoch, DataMats(iFile).Time([1,end]), 0, 1, 'no', UseSsp);
            DataMat.ChannelFlag = sFile.channelflag;
        end
        % WE DON'T WANT TO APPLY THE AVERAGE REFERENCE AT THIS STAGE: NOISE COV IS CALCULATED ON ORIGINAL MONTAGE, AND AVG REF IS CALCULATED IN PROCESS_INVERSE.
%         % Apply average reference: separately SEEG, ECOG, EEG
%         if any(ismember(unique({ChannelMat.Channel.Type}), {'EEG','ECOG','SEEG'}))
%             sMontage = panel_montage('GetMontageAvgRef', ChannelMat.Channel, DataMat.ChannelFlag);
%             DataMat.F = sMontage.Matrix * DataMat.F;
%         end
        % If not enough time frames (ie. if data files)
        if (length(DataMat.Time) <= 2) || (size(DataMat.F,2) <= 2)
            return;
        end
        % Check size
        if (size(DataMat.F,1) ~= nChanAll)
            error('Number of channels is not constant.');
        end
        % Get the times required in the block (only when there are bad segments in raw files)
        if isRaw && ~isempty(DataMat.iBadTime)
            DataMat.Time(DataMat.iBadTime) = [];
            DataMat.F(:, DataMat.iBadTime) = [];
        end
        % Get times that are considered as baseline
        if isempty(DataMat.Time)
            iTimeBaseline = [];
        elseif ~isempty(Options.Baseline)
            iTimeBaseline = panel_time('GetTimeIndices', DataMat.Time, Options.Baseline);
        else
            iTimeBaseline = 1:length(DataMat.Time);
        end
        % Get the time indices on which to compute the covariance 
        if isDataCov
            if isempty(DataMat.Time)
                iTimeCov = [];
            elseif ~isempty(Options.DataTimeWindow)
                iTimeCov = panel_time('GetTimeIndices', DataMat.Time, Options.DataTimeWindow);
            else
                iTimeCov = 1:length(DataMat.Time);
            end
        else
            iTimeCov = iTimeBaseline;
        end
    end
end









