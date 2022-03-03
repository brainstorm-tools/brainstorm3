function [OutputFiles, Messages, isError] = bst_timefreq(Data, OPTIONS)
% BST_TIMEFREQ: Compute time-frequency decompositions of the signals.
%
% USAGE:  [OutputFiles, Messages, isError] = bst_timefreq(Data, OPTIONS)
%                                  OPTIONS = bst_timefreq();
%
% INPUTS:
%     - Data: Can be one of the following
%          - String, filename
%          - Cell-array of strings, filenames
%          - Matrix of time-series [nRow x nTime]
%          - Cell-array of matrices of time series
%     - OPTIONS: Structure with the following fields
%          - Method       : {'morlet', 'fft', 'psd', 'hilbert', 'mtmconvol'}
%          - Output       : {'average', 'all'}
%          - Comment      : Output file comment
%          - ListFiles    : Cell array of filenames, used only if Data is a matrix of data (used to reference the "parent" file)
%          - iTargetStudy : Specify output study
%          - TimeVector   : Full time vector of the data to process
%          - SensorTypes  : Cell-array of strings, sensors to process (can be sensor names or sensor types)
%          - RowNames     : Names of the rows in the data matrix that is processed (sensors name, scout name, etc.)
%          - Freqs        : Frequencies to process, vector or frequency bands (cell array)
%          - TimeBands    : Cell array, time bands to process when not using the original file time
%          - MorletFc     : Parameter for Morlet wavelets
%          - MorletFwhmTc : Parameter for Morlet wavelets
%          - Measure      : Function to apply to the TF coefficients after computation: {'Power', 'none'}
%          - ClusterFuncTime : When is the cluster function supposed to be applied respect with the TF decomposition: {'before', 'after'}
% 
% OUTPUTS:
%     - OutputFiles : Cell-array, list of files that were created
%                     or the contents of the file if we don't know where to save them
%     - Messages    : String, reports errors and warnings
%     - isError     : 1 if an error happened during the process

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
% Authors: Francois Tadel, 2010-2021
%          Hossein Shahabi, 2020-2021
%          Raymundo Cassani, 2020-2021

% ===== DEFAULT OPTIONS =====
Def_OPTIONS.Comment         = '';
Def_OPTIONS.Method          = 'morlet';
Def_OPTIONS.Freqs           = [];
Def_OPTIONS.TimeVector      = [];
Def_OPTIONS.TimeBands       = [];
Def_OPTIONS.TimeWindow      = [];
Def_OPTIONS.ClusterFuncTime = 'none';
Def_OPTIONS.Measure         = 'power';
Def_OPTIONS.Output          = 'all';
Def_OPTIONS.RemoveEvoked    = 0;
Def_OPTIONS.MorletFc        = 1;
Def_OPTIONS.MorletFwhmTc    = 3;
Def_OPTIONS.WinLength       = [];
Def_OPTIONS.WinOverlap      = 50;
Def_OPTIONS.WinStd          = 0;
Def_OPTIONS.isMirror        = 0;
Def_OPTIONS.SensorTypes     = 'MEG, EEG';
Def_OPTIONS.Clusters        = {};
Def_OPTIONS.ScoutFunc       = [];
Def_OPTIONS.SurfaceFile     = [];
Def_OPTIONS.iTargetStudy    = [];
Def_OPTIONS.SaveKernel      = 0;
Def_OPTIONS.nComponents     = 1;
Def_OPTIONS.NormalizeFunc   = 'none';
Def_OPTIONS.ft_mtmconvol    = [];
Def_OPTIONS.PowerUnits      = 'physical';

% Return the default options
if (nargin == 0)
    OutputFiles = Def_OPTIONS;
    return
end
% Copy default options to OPTIONS structure (do not replace defined values)
OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);
% Check if the signal processing toolbox is available
UseSigProcToolbox = bst_get('UseSigProcToolbox');


% ===== PARSE INPUTS =====
% Initializations
OutputFiles = {};
Messages = [];
isError  = 0;
% Data: List of data blocks/files to process
if ~iscell(Data)
    Data = {Data};
end
% OPTIONS
nGoodSamples_avg = [];
isAverage        = strcmpi(OPTIONS.Output, 'average');
nAvg             = 1;
nAvgTotal        = 0;
TF_avg           = [];
ChannelFlag      = [];
RowNames         = [];
InitTimeVector   = [];
nRows            = [];
strHistory       = [];
% Number of frequency bands
if iscell(OPTIONS.Freqs)
    FreqBands = OPTIONS.Freqs;
else
    FreqBands = [];
end
isAddedCommentSensor = 0;
isAddedCommentOptions = 0;
isAddedCommentNorm = 0;
% Cannot do average and "save kernel" at the same time
if isAverage && OPTIONS.SaveKernel
    Messages = 'Incompatible options: 1)Keep the inversion kernel and 2)average trials';
    isError = 1;
    return;
% Cannot use option "save kernel" with continuous raw files
elseif OPTIONS.SaveKernel && ischar(Data{1}) && any(~cellfun(@(c)isempty(strfind(c, '@raw')), Data))
    Messages = 'Cannot use the optimization option "save the inversion kernel" with continuous raw files.';
    isError = 1;
    return;
end
% Cannot use the options "normalized units" and "frequency bands" at the same time
if strcmpi(OPTIONS.Method, 'psd') && strcmpi(OPTIONS.PowerUnits, 'normalized') && ~isempty(FreqBands)
    Messages = 'Cannot use the options "normalized units" and "frequency bands" together.';
    isError = 1;
    return;      
end
        
% Progress bar
switch(OPTIONS.Method)
    case 'morlet',    strMap = 'time-frequency maps';
    case 'fft',       strMap = 'FFT values';
    case 'psd',       strMap = 'PSD values';
    case 'sprint',    strMap = 'SPRiNT maps';
    case 'hilbert',   strMap = 'Hilbert maps';
    case 'mtmconvol', strMap = 'multitaper maps';
end


% ===== COMPUTE EVOKED RESPONSE =====
DataAvg = [];
if OPTIONS.RemoveEvoked && (length(Data) > 1)
    % Input=file names
    if ischar(Data{1})
        [Stat, Messages] = bst_avg_files(Data, [], 'mean', 0, 0, 0, 0, 1);
        if ~isempty(Messages)
            isError = 1;
            return;
        end
        DataAvg = Stat.mean;
    % Input=data blocks
    elseif all(cellfun(@(c)isequal(size(c), size(Data{1})), Data))
        DataAvg = mean(cat(4, Data{:}), 4);
    % Invalid data size
    else
        Messages = 'To remove the evoked response, all the trials must have the same size.';
        isError = 1;
        return;
    end
end

    
% ===== LOOP ON FILES =====
bst_progress('start', 'Frequency analysis', ['Computing ' strMap '...'], 0, 2 * length(Data));
% Loop on all the data blocks
for iData = 1:length(Data)
    % ===== GET INITIAL DATA FILE =====
    % If data block is a file
    isFile = ischar(Data{iData});
    if isFile 
        InitFile = Data{iData};
    elseif isempty(OPTIONS.ListFiles)
        InitFile = [];
    else
        InitFile = OPTIONS.ListFiles{iData};
    end
    % Get source information
    if ~isempty(InitFile)
        % Get file in database
        [sStudy, iStudy, iFile, DataType] = bst_get('AnyFile', InitFile);
        % Convert file type
        if strcmpi(DataType, 'link')
            DataType = 'results';
        end
    else
        DataType = 'scout';
        iStudy = [];
    end    
    % Output study
    if isequal(OPTIONS.iTargetStudy, 'NoSave')
        iTargetStudy = [];
    elseif ~isempty(OPTIONS.iTargetStudy)
        iTargetStudy = OPTIONS.iTargetStudy;
    else
        iTargetStudy = iStudy;
    end
    
    % ===== READ DATA =====
    iGoodChannels = [];
    ImagingKernel = [];
    SurfaceFile   = [];
    GridLoc       = [];
    GridAtlas     = [];
    Atlas         = [];
    HeadModelType = [];
    HeadModelFile = [];
    BadSegments   = [];
    if isFile
        % Select subset of data
        switch (DataType)
            case 'data'
                % Get channel file
                ChannelFile = bst_get('ChannelFileForStudy', sStudy.FileName);
                if isempty(ChannelFile)
                    error('No channel definition available for this file.');
                end
                % Read file
                sMat = in_bst_data(InitFile, 'F', 'Time', 'ChannelFlag', 'nAvg', 'Events');
                % Load channel file
                ChannelMat  = in_bst_channel(ChannelFile);
                ChannelFlag = sMat.ChannelFlag;
                % Raw file 
                if isstruct(sMat.F)
                    sFile = sMat.F;
                    % Check that we are not reading from a epoched file
                    if (length(sFile.epochs) > 1)
                        Messages = 'Files with epochs are not supported by this process.';
                        isError = 1;
                        return;
                    end
                    % Read input data
                    [F, sMat.Time, BadSegments] = ReadRawRecordings(sFile, sMat.Time, ChannelMat, OPTIONS);
                % Imported data file
                else
                    F = sMat.F;
                    % Remove evoked response
                    if OPTIONS.RemoveEvoked
                        F = F - DataAvg;
                    end
                    % Detect bad segments
                    sMat.events = sMat.Events;
                    sMat.prop.sfreq = 1 ./ (sMat.Time(2) - sMat.Time(1));
                    isChannelEvtBad = 0;
                    BadSegments = panel_record('GetBadSegments', sMat, isChannelEvtBad) - sMat.prop.sfreq * sMat.Time(1) + 1;
                end
                nAvg = sMat.nAvg;
                OPTIONS.TimeVector = sMat.Time;
                % Get channels we want to process
                if ~isempty(OPTIONS.SensorTypes)
                    [iChannels, SensorComment] = channel_find(ChannelMat.Channel, OPTIONS.SensorTypes);
                else
                    iChannels = 1:length(ChannelMat.Channel);
                    SensorComment = [];
                end
                % Not average file: keep only the good channels
                if ~isAverage
                    iChannels = intersect(iChannels, find(ChannelFlag == 1));
                end
                % No sensors: error
                if isempty(iChannels)
                    Messages = 'No sensors are selected.';
                    isError = 1;
                    return;
                end
                % Add comment
                if ~isAddedCommentSensor && ~isempty(SensorComment)
                    isAddedCommentSensor = 1;
                    OPTIONS.Comment = [OPTIONS.Comment ' (', SensorComment, ')'];
                end
                % Remove the unnecessary data
                F = F(iChannels, :);
                ChannelFlag = ChannelFlag(iChannels);
                RowNames = {ChannelMat.Channel(iChannels).Name};

                % Accumulator for good rows markers
                if isAverage
                    % Check for same number of rows
                    if isempty(nRows)
                        nRows = size(F,1);
                    elseif (nRows ~= size(F,1))
                        Messages = 'Input files do not have the same number of channels: Cannot compute average.';
                        isError = 1;
                        return;
                    end
                    if isempty(nGoodSamples_avg)
                        nGoodSamples_avg = zeros(size(F,1), 1);
                    end
                    iGoodChannels = find(ChannelFlag == 1);
                    nGoodSamples_avg(iGoodChannels) = nGoodSamples_avg(iGoodChannels) + nAvg;
                end
                nComponents = 1;
                
            case 'results'
                % The dynamic ZScore has to be applied before any other computation
                if ~isempty(strfind(InitFile, '_zscored'))
                    Messages = 'Cannot process dynamic zscores of sources.';
                    isError = 1;
                    return;
                % The pre-computed average is in full format
                elseif OPTIONS.RemoveEvoked
                    isLoadFull = 1;
                else
                    isLoadFull = 0;
                end
                % Get inversion kernel
                ResultsMat = in_bst_results(InitFile, isLoadFull, 'ImageGridAmp', 'ImagingKernel', 'GoodChannel', 'nComponents', 'DataFile', 'nAvg', 'Time', 'Atlas', 'SurfaceFile', 'GridLoc', 'GridAtlas', 'Atlas', 'HeadModelType', 'HeadModelFile');
                % Row "names" for sources: source indices
                nComponents   = ResultsMat.nComponents;
                SurfaceFile   = ResultsMat.SurfaceFile;
                GridLoc       = ResultsMat.GridLoc;
                GridAtlas     = ResultsMat.GridAtlas;
                Atlas         = ResultsMat.Atlas;
                HeadModelType = ResultsMat.HeadModelType;
                HeadModelFile = ResultsMat.HeadModelFile;
                if isempty(GridAtlas)
                    nSources = max(size(ResultsMat.ImageGridAmp,1), size(ResultsMat.ImagingKernel,1)) ./ ResultsMat.nComponents;
                else
                    nSources = size(GridAtlas.Grid2Source);
                end
                
                % Kernel results: Process the recordings file
                if ~isempty(ResultsMat.ImagingKernel) && isempty(ResultsMat.ImageGridAmp)
                    ImagingKernel = ResultsMat.ImagingKernel;
                    % Load associated data file
                    sMat = in_bst_data(sStudy.Result(iFile).DataFile);
                    % Raw recordings
                    if isstruct(sMat.F)
                        sFile = sMat.F;
                        % Get channel file
                        ChannelFile = bst_get('ChannelFileForStudy', sStudy.FileName);
                        if isempty(ChannelFile)
                            error('No channel definition available for this file.');
                        end
                        % Load channel file
                        ChannelMat  = in_bst_channel(ChannelFile);
                        % Check that we are not reading from a epoched file
                        if (length(sFile.epochs) > 1)
                            Messages = 'Files with epochs are not supported by this process.';
                            isError = 1;
                            return;
                        end
                        % Read input data
                        [F, sMat.Time, BadSegments] = ReadRawRecordings(sFile, sMat.Time, ChannelMat, OPTIONS);
                    % Imported recordings
                    else
                        F = sMat.F;
                        % Detect bad segments
                        sMat.events = sMat.Events;
                        sMat.prop.sfreq = 1 ./ (sMat.Time(2) - sMat.Time(1));
                        isChannelEvtBad = 0;
                        BadSegments = panel_record('GetBadSegments', sMat, isChannelEvtBad) - sMat.prop.sfreq * sMat.Time(1) + 1;
                    end
                    % Get indices of channels for this results file
                    F = F(ResultsMat.GoodChannel, :);
                    nAvg = sMat.nAvg;
                    OPTIONS.TimeVector = sMat.Time;
                % Full results: Proces the sources time series
                else
                    F    = ResultsMat.ImageGridAmp;
                    nAvg = ResultsMat.nAvg;
                    OPTIONS.TimeVector = ResultsMat.Time;
                    % Remove evoked response
                    if OPTIONS.RemoveEvoked
                        F = F - DataAvg;
                    end
                end
                % RowNames: If it comes from an atlas: keep the atlas labels
                if isfield(ResultsMat, 'Atlas') && ~isempty(ResultsMat.Atlas) && ~isempty(ResultsMat.Atlas.Scouts)
                    RowNames = {ResultsMat.Atlas.Scouts.Label};
                % Else: use row indices
                else
                    RowNames = 1:nSources;
                end
                
            case 'matrix'
                % Read file
                sMat = in_bst_matrix(InitFile);
                F    = sMat.Value;
                nAvg = sMat.nAvg;
                OPTIONS.TimeVector = sMat.Time;
                % Row name in Description field
                if (numel(sMat.Description) ~= size(F,1))
                    Messages = 'Only the "matrix" file that represent scouts/clusters time series can be processed by this function.';
                    isError = 1;
                    return;
                end
                RowNames = sMat.Description';
                nComponents = 1;
                % Remove evoked response
                if OPTIONS.RemoveEvoked
                    F = F - DataAvg;
                end
                    
            otherwise
                Messages = ['Unsupported data type: ' DataType];
                isError = 1;
                return;
        end
        clear ResultsMat sMat;
        % Keep only the required time window
        if ~isempty(OPTIONS.TimeWindow)
            % Find the indices of the time window in the original time vector
            iTime = bst_closest(OPTIONS.TimeWindow, OPTIONS.TimeVector);
            % If the time window is invalid: start index=stop index
            if (iTime(1) == iTime(2))
                Messages = ['Selected time window is not valid for one of the input files.' 10 ...
                            'If you are processing files with different time definitions,' 10 ...
                            'consider using the process Standardize > Uniform epoch time.'];
                isError = 1;
                return;
            end
            % Keep only the time window of interest
            iTime = iTime(1):iTime(2);
            OPTIONS.TimeVector = OPTIONS.TimeVector(iTime);
            F = F(:,iTime);
        end
        
    % ===== PROCESS DATA BLOCKS =====
    else
        RowNames = OPTIONS.RowNames{iData};
        F = Data{iData};
        % Remove evoked response
        if OPTIONS.RemoveEvoked
            F = F - DataAvg;
        end
        % Restore initial time vector, in case it was modified by the process
        if isempty(InitTimeVector)
            InitTimeVector = OPTIONS.TimeVector;
        else
            OPTIONS.TimeVector = InitTimeVector;
        end
        % Data type: 'cluster' or 'scout'
        if strcmpi(DataType, 'data')
            DataType = 'cluster';
            nComponents = 1;
        else
            DataType = 'scout';
            if (length(OPTIONS.nComponents) == 1)
                nComponents = OPTIONS.nComponents;
            else
                nComponents = OPTIONS.nComponents(iData);
            end
            
            % PSD: we don't want the bad segments
            if ~isempty(iStudy) && strcmpi(OPTIONS.Method, 'psd') && ~isempty(sStudy.Result(iFile).DataFile)
                % Load associated data file
                sMat = in_bst_data(sStudy.Result(iFile).DataFile);
                % Raw file
                if isstruct(sMat.F)
                    sFile = sMat.F;
                else
                    sFile = sMat;
                    sFile.events = sMat.Events;
                    sFile.prop.sfreq = 1 ./ (sMat.Time(2) - sMat.Time(1));
                end
                % Get list of bad segments in file
                isChannelEvtBad = 0;
                BadSegments = panel_record('GetBadSegments', sFile, isChannelEvtBad);
                % Convert them to the beginning of the time section that is processed
                BadSegments = BadSegments - sFile.prop.sfreq * sMat.Time(1) + 1;
            end
        end
        nAvg = 1;
    end
    % Get signal frequency
    sfreq = 1 ./ (OPTIONS.TimeVector(2) - OPTIONS.TimeVector(1));
    % Use surface file from the input
    if isempty(SurfaceFile) && isfield(OPTIONS, 'SurfaceFile') && ~isempty(OPTIONS.SurfaceFile) && iscell(OPTIONS.SurfaceFile) && (iData <= length(OPTIONS.SurfaceFile))
        SurfaceFile = OPTIONS.SurfaceFile{iData};
    end
    
    % ===== COMPUTE TRANSFORM =====
    isMeasureApplied = 0;
    switch (OPTIONS.Method)
        % Morlet wavelet transform (Dimitrios Pantazis)
        case 'morlet'
            % Remove mean of the signal
            F = bst_bsxfun(@minus, F, mean(F,2));
            % Group in frequency bands
            if ~isempty(FreqBands)
                OPTIONS.Freqs = [];
                % Get frequencies for each frequency bands
                evalFreqBands = process_tf_bands('Eval', FreqBands);
                % Loop on each frequency
                for iBand = 1:size(evalFreqBands,1)
                    freq = evalFreqBands{iBand,2};
                    % If there are only two values: use 4 values for the frequency band
                    if (length(freq) == 2)
                        freq = linspace(freq(1), freq(2), 4);
                    end
                    % Add to the frequencies to process
                    OPTIONS.Freqs = [OPTIONS.Freqs, freq];
                end
            end
            % Invalid frequencies
            if iscell(OPTIONS.Freqs) || isempty(OPTIONS.Freqs) || any(OPTIONS.Freqs <= 0)
                Messages = 'Invalid frequency definition: All frequencies must be > 0.';
                isError = 1;
                return;
            end
            % Compute wavelet decompositions
            TF = morlet_transform(F, OPTIONS.TimeVector, OPTIONS.Freqs, OPTIONS.MorletFc, OPTIONS.MorletFwhmTc, 'n');

        % FFT: Matlab function fft
        case 'fft'
            % Use psd function, single window.
            [TF, OPTIONS.Freqs, Nwin, Messages] = bst_psd(F, sfreq, [], 0, BadSegments, ImagingKernel, [], OPTIONS.PowerUnits);
            % Keep only first and last time instants
            OPTIONS.TimeVector = OPTIONS.TimeVector([1 end]);
            % Imaging kernel is already applied: don't do it twice
            ImagingKernel = [];
            % Measure is already applied (power)
            isMeasureApplied = 1;
            
        % PSD: Homemade computation based on Matlab's FFT
        case 'psd'
            % Calculate PSD/FFT
            [TF, OPTIONS.Freqs, Nwin, Messages] = bst_psd(F, sfreq, OPTIONS.WinLength, OPTIONS.WinOverlap, BadSegments, ImagingKernel, OPTIONS.WinStd, OPTIONS.PowerUnits);
            if isempty(TF)
                continue;
            end
            % Imaging kernel is already applied: don't do it twice
            ImagingKernel = [];
            % Keep only first and last time instants
            OPTIONS.TimeVector = OPTIONS.TimeVector([1 end]);
            % Comment
            if ~isAddedCommentOptions
                isAddedCommentOptions = 1;
            else
                ims = strfind(OPTIONS.Comment, 'ms ');
                if ~isempty(ims)
                    OPTIONS.Comment = OPTIONS.Comment(ims+3:end);
                end
            end
            OPTIONS.Comment = sprintf('PSD: %d/%dms %s', Nwin, round(OPTIONS.WinLength.*1000), OPTIONS.Comment);
            % Measure is already applied (power)
            isMeasureApplied = 1;
            
        % SPRiNT: Spectral Parameterization Resolved iN Time (Luc Wilson)
        case 'sprint'
            % Calculate PSD/FFT
            if isequal(DataType,'results') % Source data
                OPTIONS.SPRiNTopts.imgK = ImagingKernel;
                ImagingKernel = []; % Do not apply twice
            end
            [TF, Messages, OPTIONS] = bst_sprint(F, sfreq, RowNames, OPTIONS);
            if iData == 1 % Only add comment once
                OPTIONS.Comment = [OPTIONS.Comment ', ' sprintf('%d-%dHz', round(OPTIONS.SPRiNTopts.freqrange.Value{1}(1)),round(OPTIONS.SPRiNTopts.freqrange.Value{1}(2)))];
            end
                
        % Hilbert
        case 'hilbert'
            % Get bounds of each frequency bands
            BandBounds = process_tf_bands('GetBounds', FreqBands);
            % Intitialize returned matrix
            TF = zeros(size(F,1), size(F,2), size(BandBounds,1));
            % Loop on each frequency band
            for iBand = 1:size(BandBounds,1)
                % Band-pass filter in one frequency band
                isMirror = 0;
                isRelax = 0;
                Fband = process_bandpass('Compute', F, sfreq, BandBounds(iBand,1), BandBounds(iBand,2), 'bst-hfilter-2019', isMirror, isRelax);
                % Fband = process_bandpass('Compute', F, sfreq, BandBounds(iBand,1), BandBounds(iBand,2), 'bst-fft-fir', OPTIONS.isMirror);
                % Apply Hilbert transform
                if UseSigProcToolbox
                    TF(:,:,iBand) = hilbert(Fband')';
                else
                    TF(:,:,iBand) = oc_hilbert(Fband')';
                end
            end
            
        % Multitaper
        case 'mtmconvol'
            mt = OPTIONS.ft_mtmconvol;
            % Configuration inspired from SPM function spm_eeg_specest_mtmconvol
            dt = OPTIONS.TimeVector(end) - OPTIONS.TimeVector(1) + diff(OPTIONS.TimeVector(1:2));
            fsample = 1 ./ diff(OPTIONS.TimeVector(1:2));
            df = unique(diff(mt.frequencies));
            if length(df) == 1  
                pad = ceil(dt*df)/df;
            else
                pad = [];
            end
            % Correct the time step to the closest multiple of the sampling interval to keep the time axis uniform
            mt.timestep = round(fsample * mt.timestep) / fsample;
            % Time axis
            timeoi = (OPTIONS.TimeVector(1) + mt.timeres/2) : mt.timestep : (OPTIONS.TimeVector(end) - mt.timeres/2 - 1/fsample); 
            % Frequency resolution for each frequency
            freqres = mt.frequencies / mt.freqmod;
            freqres(find(freqres < 1/mt.timeres)) = 1/mt.timeres;
            
            % Call fieldtrip function
            [TF, ntaper, OPTIONS.Freqs, OPTIONS.TimeVector] = ft_specest_mtmconvol(F, OPTIONS.TimeVector, ...
                'taper',     mt.taper, ...
                'timeoi',    timeoi, ...
                'freqoi',    mt.frequencies,...
                'timwin',    repmat(mt.timeres, 1, length(mt.frequencies)), ...
                'tapsmofrq', freqres, ...
                'pad',       pad, ...
                'verbose',   0);
            % Permute dimensions to get [nChannels x nTime x nFreq x nTapers]
            TF = permute(TF, [2 4 3 1]);
    end
    bst_progress('inc', 1);
    % Set to zero the bad channels
    if ~isempty(iGoodChannels)
        iBadChannels = setdiff(1:size(F,1), iGoodChannels);
        if ~isempty(iBadChannels)
            TF(iBadChannels, :, :, :) = 0;
        end
    end
    % Clean memory
    clear F;

    % ===== REBUILD FULL SOURCES =====
    % Kernel => Full results
    if strcmpi(DataType, 'results') && ~isempty(ImagingKernel) && ~OPTIONS.SaveKernel
        % Initialize full time-frequency matrix
        TF_full = zeros(size(ImagingKernel,1), size(TF,2), size(TF,3), size(TF,4));
        % Loop on the frequencies and tapers
        for itaper = 1:size(TF,4)
            for ifreq = 1:size(TF,3)
                TF_full(:,:,ifreq,itaper) = ImagingKernel * TF(:,:,ifreq,itaper);
            end
        end
        % Replace previous values with new ones
        TF = TF_full;
        clear TF_full;
    end
    % Cannot save kernel when components > 1
    if strcmpi(DataType, 'results') && OPTIONS.SaveKernel && (nComponents ~= 1)
        Messages = ['Cannot keep the inversion kernel when processing unconstrained sources.' 10 ...
                    'Please selection the option "Optimize: No, save full sources."'];
        isError = 1;
        return;
    end
    
    % ===== APPLY MEASURE =====
    if ~isMeasureApplied
        % Multitaper: average power across tapers
        if strcmpi(OPTIONS.Method, 'mtmconvol')
            TF = nanmean(TF .* conj(TF), 4);
            % Power or magnitude
            if strcmpi(OPTIONS.Measure, 'magnitude')
                TF = sqrt(TF);
            end
        % Other measures: Apply the expected measure
        else
            switch lower(OPTIONS.Measure)
                case 'none'       % Nothing to do
                case 'power',     TF = abs(TF) .^ 2;
                case 'magnitude', TF = abs(TF);
                otherwise,        error('Unknown measure.');
            end
        end
    end
    
    % ===== PROCESS UNCONSTRAINED SOURCES =====
    % Unconstrained sources => SUM for each point  (only if not complex)
    if ismember(DataType, {'results','scout','matrix'}) && ~isempty(nComponents) && (nComponents ~= 1)
        % This doesn't work for complex values: TODO
        if strcmpi(OPTIONS.Measure, 'none')
            Messages = ['Cannot keep the complex values when processing unconstrained sources.' 10 ...
                        'Please selection the option "Optimize: No, save full sources."'];
            isError = 1;
            return;
        end
        % Apply orientation
        [TF, GridAtlas, RowNames] = bst_source_orient([], nComponents, GridAtlas, TF, 'sum', DataType, RowNames);
    end

    % ===== PROCESS POWER FOR SCOUTS =====
    % Get the lists of clusters
    [tmp,I,J] = unique(RowNames);
    ScoutNames = RowNames(sort(I));
    % If processing data blocks and if there are identical row names => Processing clusters / scouts
    if ~isFile && ~isempty(OPTIONS.Clusters) && (length(ScoutNames) ~= length(RowNames))
        % If cluster function should be applied AFTER time-freq: we have now all the time series
        if strcmpi(OPTIONS.ClusterFuncTime, 'after')
            TF_cluster = zeros(length(ScoutNames), size(TF,2), size(TF,3));
            % For each unique row name: compute a measure over the clusters values
            for iScout = 1:length(ScoutNames)
                indClust = find(strcmpi(ScoutNames{iScout}, RowNames));
                % Compute cluster/scout measure
                for iFreq = 1:size(TF,3)
                    TF_cluster(iScout,:,iFreq) = bst_scout_value(TF(indClust,:,iFreq), OPTIONS.ScoutFunc);
                end
            end
            % Save only the requested rows
            RowNames = ScoutNames;
            TF = TF_cluster;
        % Just make all RowNames unique
        else
            initRowNames = RowNames;
            RowNames = cell(size(TF,1),1);
            % For each row name: update name with the index of the row
            for iScout = 1:length(ScoutNames)
                indClust = find(strcmpi(ScoutNames{iScout}, initRowNames));
                % Process each cluster element: add an indice
                for i = 1:length(indClust)
                    RowNames{indClust(i)} = sprintf('%s.%d', ScoutNames{iScout}, i);
                end
            end
        end
    end

    % ===== NORMALIZE VALUES =====
    if ~isempty(OPTIONS.NormalizeFunc) && ismember(OPTIONS.NormalizeFunc, {'multiply', 'multiply2020'})
        % Call normalization function
        [TF, errorMsg] = process_tf_norm('Compute', TF, OPTIONS.Measure, OPTIONS.Freqs, OPTIONS.NormalizeFunc);
        % Error handling
        if ~isempty(errorMsg)
            Messages = errorMsg;
            isError = 1;
            return;
        end
        % Add normalization comment
        if ~isAddedCommentNorm
            isAddedCommentNorm = 1;
            OPTIONS.Comment = [OPTIONS.Comment ' | ' strrep(OPTIONS.NormalizeFunc, '2020', '')];
        end
    end

    
    % ===== SAVE FILE / COMPUTE AVERAGE =====
    % Only save average
    if isAverage
        % First loop: create the accumulator
        if isempty(TF_avg)
            TF_avg = zeros(size(TF));
        % Other loops: check if data size is coherent with previous loops
        elseif ~isequal(size(TF), size(TF_avg))
            Messages = 'Input files have different or number of elements: cannot compute average...';
            isError = 1;
            return;
        end
        % Add block to accumulator
        TF_avg = TF_avg + TF * nAvg;
        nAvgTotal = nAvgTotal + nAvg;
        % Add history message
        strHistory = [strHistory, ' - Average TF: ', InitFile, 10];
    % Save all the time-frequency maps
    else
        % Save file
        SaveFile(iTargetStudy, InitFile, DataType, RowNames, TF, OPTIONS, FreqBands, SurfaceFile, GridLoc, GridAtlas, HeadModelType, HeadModelFile, nAvg, Atlas, strHistory);
    end
    bst_progress('inc', 1);
end


% ===== SAVE AVERAGE =====
% Finish to compute average
if isAverage
    bst_progress('start', 'Time-frequency', 'Saving average...');
    % Non-recordings: divide everything 
    if isempty(nGoodSamples_avg)
        TF_avg = TF_avg ./ nAvgTotal;
    % Else: we have the information channel by channel
    else
        % Delete the channels that are bad everywhere
        iBad = find(nGoodSamples_avg == 0);
        if ~isempty(iBad)
            TF_avg(iBad,:,:) = [];
            nGoodSamples_avg(iBad) = [];
            RowNames(iBad) = [];
        end
        % Divide channel by channel
        for i = 1:length(nGoodSamples_avg)
            TF_avg(i,:,:) = TF_avg(i,:,:) ./ nGoodSamples_avg(i);
        end
    end
    % Related file: ignore if more than one in input
    if (length(Data) > 1)
        InitFile = '';
    end
    % Save file
    SaveFile(iTargetStudy, InitFile, DataType, RowNames, TF_avg, OPTIONS, FreqBands, SurfaceFile, GridLoc, GridAtlas, HeadModelType, HeadModelFile, nAvgTotal, Atlas, strHistory);
end



%% ===== SAVE FILE =====
    function SaveFile(iTargetStudy, DataFile, DataType, RowNames, TF, OPTIONS, FreqBands, SurfaceFile, GridLoc, GridAtlas, HeadModelType, HeadModelFile, nAvgFile, Atlas, strHistory)
        % Create file structure
        FileMat = db_template('timefreqmat');
        FileMat.Comment   = OPTIONS.Comment;
        FileMat.DataType  = DataType;
        FileMat.TF        = TF;
        FileMat.Time      = OPTIONS.TimeVector;
        FileMat.TimeBands = [];
        FileMat.Freqs     = OPTIONS.Freqs;
        FileMat.RowNames  = RowNames;
        FileMat.Measure   = OPTIONS.Measure;
        FileMat.Method    = OPTIONS.Method;
        FileMat.nAvg      = nAvgFile;
        FileMat.Leff      = nAvgFile;
        FileMat.SurfaceFile   = SurfaceFile;
        FileMat.GridLoc       = GridLoc;
        FileMat.GridAtlas     = GridAtlas;
        FileMat.HeadModelType = HeadModelType;
        FileMat.HeadModelFile = HeadModelFile;
        FileMat.Atlas         = Atlas;
        % Parent file
        if ~isempty(DataFile)
            FileMat.DataFile = file_short(DataFile);
        else
            FileMat.DataFile = [];
        end
        % Options
        FileMat.Options.Method          = OPTIONS.Method;
        FileMat.Options.Measure         = OPTIONS.Measure;
        FileMat.Options.Normalized      = OPTIONS.NormalizeFunc;
        FileMat.Options.Output          = OPTIONS.Output;
        FileMat.Options.RemoveEvoked    = OPTIONS.RemoveEvoked;
        FileMat.Options.MorletFc        = OPTIONS.MorletFc;
        FileMat.Options.MorletFwhmTc    = OPTIONS.MorletFwhmTc;
        FileMat.Options.ClusterFuncTime = OPTIONS.ClusterFuncTime;
        FileMat.Options.PowerUnits      = OPTIONS.PowerUnits;
        % Compute edge effects mask
        if ismember(OPTIONS.Method, {'hilbert', 'morlet'})
            FileMat.TFmask = process_timefreq('GetEdgeEffectMask', FileMat.Time, FileMat.Freqs, FileMat.Options);
        elseif ismember(OPTIONS.Method, 'mtmconvol')
            % FileMat.TFmask = permute(~any(isnan(FileMat.TF),1), [3,2,1]);
            FileMat.TF(isnan(FileMat.TF)) = 0;
        end
        % Add SPRiNT structure
        if isequal(OPTIONS.Method,'sprint')
            FileMat.Options.SPRiNT      = OPTIONS.SPRiNT;
        end
        % History: Computation
        FileMat = bst_history('add', FileMat, 'compute', 'Time-frequency decomposition');
        if ~isempty(strHistory)
            FileMat = bst_history('add', FileMat, 'compute', strHistory);
        end
        
        % Apply time and frequency bands
        if ~isempty(FreqBands) || ~isempty(OPTIONS.TimeBands)
            if strcmpi(OPTIONS.Method, 'hilbert') && ~isempty(OPTIONS.TimeBands)
                [FileMat, Messages] = process_tf_bands('Compute', FileMat, [], OPTIONS.TimeBands);
            elseif strcmpi(OPTIONS.Method, 'morlet') || strcmpi(OPTIONS.Method, 'psd') 
                [FileMat, Messages] = process_tf_bands('Compute', FileMat, FreqBands, OPTIONS.TimeBands);
            end
            if isempty(FileMat)
                if ~isempty(Messages)
                    error(Messages);
                else
                    error('Unknow error while processing time or frequency bands.');
                end
            end
        end
        
        % Save the file
        if ~isempty(iTargetStudy)
            % Get output study
            sTargetStudy = bst_get('Study', iTargetStudy);
            % Output filename
            fileName = 'timefreq';
            if strcmpi(OPTIONS.Output, 'all') && ~isempty(FileMat.DataFile)
                % Get filename
                [fPath, fBase, fExt] = bst_fileparts(FileMat.DataFile);
                % Look for a trial tag in the filename
                iTagStart = strfind(fBase, '_trial');
                if ~isempty(iTagStart)
                    % Extract the last occurrence in case it's also in the folder name
                    iTagStart = iTagStart(end);
                    iTagStop = iTagStart + find(fBase(iTagStart+6:end) == '_',1) + 4;
                    if isempty(iTagStop)
                        iTagStop = length(fBase);
                    end
                    fileName = [fileName, fBase(iTagStart:iTagStop)];
                end
            end
            if OPTIONS.SaveKernel
                fileName = [fileName '_KERNEL_' OPTIONS.Method];
            else
                fileName = [fileName '_' OPTIONS.Method];
            end
            FileName = bst_process('GetNewFilename', bst_fileparts(sTargetStudy.FileName), fileName);
            % Save file
            bst_save(FileName, FileMat, 'v6');
            % Add file to database structure
            db_add_data(iTargetStudy, FileName, FileMat);
            % Return new filename
            OutputFiles{end+1} = FileName;
        % Returns the contents of the file instead of saving them
        else
            OutputFiles{end+1} = FileMat;
        end
    end

end


%% ===== READ RAW DATA =====
function [F, TimeVector, BadSegments] = ReadRawRecordings(sFile, TimeVector, ChannelMat, OPTIONS)
    % Reading options
    ImportOptions = db_template('ImportOptions');
    ImportOptions.ImportMode = 'Time';
    ImportOptions.Resample   = 0;
    ImportOptions.UseCtfComp = 1;
    ImportOptions.UseSsp     = 1;
    ImportOptions.RemoveBaseline = 'no';
    ImportOptions.DisplayMessages = 0;
    % Get samples to read
    if ~isempty(OPTIONS.TimeWindow)
        SamplesBounds = round(sFile.prop.times(1) .* sFile.prop.sfreq) + bst_closest(OPTIONS.TimeWindow, TimeVector) - 1;
    else
        SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
    end
    % Read data
    [F, TimeVector] = in_fread(sFile, ChannelMat, 1, SamplesBounds, [], ImportOptions);
    % PSD: we don't want the bad segments
    if strcmpi(OPTIONS.Method, 'psd')
        % Get list of bad segments in file
        isChannelEvtBad = 0;
        BadSegments = panel_record('GetBadSegments', sFile, isChannelEvtBad);
        % Convert them to the beginning of the time section that is processed
        BadSegments = BadSegments - SamplesBounds(1) + 1;
    else
        BadSegments = [];
    end
end

