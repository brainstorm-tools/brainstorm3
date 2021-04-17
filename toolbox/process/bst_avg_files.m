function [Stat, Messages, iOutFiles, AllEvents] = bst_avg_files(FilesListA, FilesListB, Function, isVariance, isWeighted, isMatchRows, isZeroBad, isPercent)
% BST_AVG_FILES: Compute statistics on one or two files sets.
%
% USAGE:  [Stat, Messages, iOutFiles, AllEvents] = bst_avg_files(FilesListA, FilesListB, Function, isVariance, isWeighted, isMatchRows, isZeroBad, isPercent)
%         [Stat, Messages, iOutFiles, AllEvents] = bst_avg_files(FilesListA, FilesListB, Function, isVariance, isWeighted, isMatchRows, isZeroBad, isPercent)
%
% INPUT:
%    - FilesListA  : Cell array of full paths to files (or loaded structures) from set A
%    - FilesListB  : Cell array of full paths to files (or loaded structures) from set B (if defined, computes the difference A-B)
%    - Function    : {'mean', 'rms', 'abs', 'norm', 'meandiffnorm', 'normdiff', 'normdiffnorm', 'median'}
%    - isVariance  : If 1, return the variance together with the mean
%    - isWeighted  : If 1, compute an average weighted with the nAvg fields found in the input files
%    - isMatchRows : If 1, match signals between files using their names
%    - isZeroBad   : If 1, the flat signals (values all equal to zero) are considered as bad and ignored from the average
%    - isPercent   : If 1, use current progress bar, and progression from 0 to 100 ("inc" only)
%
% OUTPUT:
%    - Stat: struct
%         |- ChannelFlag : array with -1 for all the bad channels found in all the processed files
%         |- MatName     : name of the file fieldname on which the stat was computed
%         |- (statname)  : values for the target statistics
%         |- Time        : time values
%    - Messages          : cell array of error/warning messages
%    - iOutFiles         : indices of the input files that were used in the average
%    - AllEvents         : combined events structures of all the input files
%
% DESCRIPTION:
%     Using West algorithm, from Wikipedia page: http://en.wikipedia.org/wiki/Algorithms_for_calculating_variance
%     D.H.D. West (1979). Communications of the ACM, 22, 9, 532-535: Updating Mean and Variance Estimates: An Improved Method
% 
%     def weighted_incremental_variance(FilesList):
%         MeanValues = 0
%         VarValues = 0
%         nGoodSamples = 0
%         for (matValues, nAvg) in FilesList:
%             nGoodSamples_old = nGoodSamples;
%             nGoodSamples = nAvg + nGoodSamples_old
%             Q = matValues - MeanValues
%             R = Q * nAvg / nGoodSamples
%             VarValues = VarValues + nGoodSamples_old * Q * R
%             MeanValues = MeanValues + R
%         VarValues = VarValues / (nGoodSamples-1)  # if sample is the population, omit -1
%         return VarValues

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
% Authors: Francois Tadel, 2008-2019


%% ===== PARSE INPUTS =====
if (nargin < 8) || isempty(isPercent)
    isPercent = 0;
end
if (nargin < 7) || isempty(isZeroBad)
    isZeroBad = 1;
end
if (nargin < 6) || isempty(isMatchRows)
    isMatchRows = 1;
end
if (nargin < 5) || isempty(isWeighted)
    isWeighted = 0;
end
if (nargin < 4) || isempty(isVariance)
    isVariance = 0;
end
if (nargin < 3) || isempty(Function)
    Function = 'mean';
end
if (nargin < 2) || isempty(FilesListB)
    FilesListB = {};
end

% Inialize returned variables
Stat      = [];
Messages  = [];
iOutFiles = [];
AllEvents = [];
% Get progress bar initial level
if isPercent && bst_progress('isVisible')
    startValue = bst_progress('get');
else
    startValue = 0;
end
% Check number of inputs for difference
isDiff = ~isempty(FilesListB);
if isDiff && (length(FilesListA) ~= length(FilesListB))
    error('Difference of files: number of files in sets A and B must be equal.');
end
% Progress bar
if ~isPercent
    bst_progress('start', 'Computing mean', 'Initialization...', 0, 100);
end


%% ===== GET COMMON ROWS =====
% Get the list of common rows (only the files with named signals: matrix and timefreq)
if isMatchRows && ismember(file_gettype(FilesListA{1}), {'matrix','timefreq','pmatrix','ptimefreq'})
    bst_progress('text', 'Reading the signal names...');
    % Identify the list of all the rows in all the files
    [DestRowNames, AllRowNames, iRowsSrc, iRowsDest, Messages] = process_stdrow('GetUniformRows', [FilesListA, FilesListB], 'all');
    if ~isempty(Messages)
        Messages = [Messages, 10];
    end
    if isempty(DestRowNames)
        Messages = [Messages, 'AVG> Could not find a common list of rows: Trying to average directly the matrices...' 10 ...
                              'AVG> To avoid this warning, uncheck the option "Match signals" in the process options.'];
    end
else
    DestRowNames = [];
end


%% ===== MEAN/VAR COMPUTATION =====
VarValues    = [];
MeanValues   = [];
MeanMatName  = [];
NbChannels   = 0;
initTimeVector = [];
initRowNames = [];
nGoodSamples = [];
GridAtlas    = [];
nComponents  = 1;
Freqs        = [];
TFmask       = [];
isData       = 0;
nFiles       = length(FilesListA);
nFilesValid  = 0;
nAvgTotal    = 0;
LeffTotal    = 0;
sFile.events = repmat(db_template('event'), 0);
RefRowNames  = [];

% Process all the files
for iFile = 1:nFiles
    bst_progress('set',  round(startValue + iFile/nFiles*100));

    % === LOAD FILE ===
    % Load file #iFile
    if ischar(FilesListA{iFile})
        bst_progress('text', ['Processing file : "' FilesListA{iFile} '"...']);
        [sMat, matName] = in_bst(FilesListA{iFile});
    % File is already loaded
    else
        bst_progress('text', sprintf('Processing file: %d/%d...', iFile, nFiles));
        sMat = FilesListA{iFile};
        % Detect data field
        if isfield(sMat, 'F')
            matName = 'F';
        elseif isfield(sMat, 'ImageGridAmp')
            matName = 'ImageGridAmp';
        elseif isfield(sMat, 'TF')
            matName = 'TF';
        elseif isfield(sMat, 'Value')
            matName = 'Value';
        elseif isfield(sMat, 'tmap')
            matName = 'tmap';
        else
            Messages = [Messages, 'Error: Cannot average this type of files.'];
            break;
        end
    end
    
    % Unconstrained sources: Compute the norm of the three orientations
    if strcmpi(matName, 'ImageGridAmp') && (sMat.nComponents ~= 1) && ismember(Function, {'norm', 'rms', 'normdiff', 'normdiffnorm'})
        sMat = process_source_flat('Compute', sMat, 'rms');
    end
    
    % Copy additional fields
    if isfield(sMat, 'nComponents') && ~isempty(sMat.nComponents)
        nComponents = sMat.nComponents;
    end
    if isfield(sMat, 'GridAtlas') && ~isempty(sMat.GridAtlas)
        GridAtlas = sMat.GridAtlas;
    end
    if isfield(sMat, 'Freqs') && ~isempty(sMat.Freqs)
        Freqs = sMat.Freqs;
    end
    if isfield(sMat, 'TFmask') && ~isempty(sMat.TFmask)
        TFmask = sMat.TFmask;
    end
    
    % Get values to process
    matValues = double(sMat.(matName));
    TimeVector = sMat.Time;
    % Effective number of averages (now replaces poorly tracked nAvg)
    Leff = sMat.Leff;
    if (Leff == 0)
        Messages = [Messages, 'Error: Field Leff=0, you are trying to average scaled dSPM.'];
        return;
    end
    % Count number of previous averages for weighted average
    if isWeighted
        nAvg = sMat.nAvg;
    else
        nAvg = 1;
    end
    nAvgTotal = nAvgTotal + nAvg;
        
    % Apply default measure to TF values
    if strcmpi(matName, 'TF') && ~isreal(matValues)
        % Get default function
        defMeasure = process_tf_measure('GetDefaultFunction', sMat);
        % Apply default function
        [matValues, isError] = process_tf_measure('Compute', matValues, sMat.Measure, defMeasure);
        if isError
            Messages = [Messages, 'Error: Invalid measure conversion: ' sMat.Measure ' => ' defMeasure];
            continue;
        end
    end
    % Read specific fields
    if isfield(sMat, 'Measure')
        Measure = sMat.Measure;
    else
        Measure = [];
    end
    if ~isempty(DestRowNames)
        RowNames = DestRowNames;
    elseif isfield(sMat, 'RowNames') && ~isempty(sMat.RowNames)
        RowNames = sMat.RowNames;
    elseif isfield(sMat, 'Description') && ~isempty(sMat.Description)
        RowNames = sMat.Description;
    else
        RowNames = [];
    end
    if isfield(sMat, 'RefRowNames') && ~isempty(sMat.RefRowNames)
        RefRowNames = sMat.RefRowNames;
    end
    if isfield(sMat, 'Events') && ~isempty(sMat.Events)
        Events = sMat.Events;
    else
        Events = [];
    end

    % === CHANNEL ORDER ===
    % Re-order rows in matrix/timefreq files
    if ~isempty(DestRowNames) && ~isequal(AllRowNames{iFile}, DestRowNames)
        tmpValues = zeros(length(DestRowNames), size(matValues,2), size(matValues,3));
        tmpValues(iRowsDest{iFile},:,:) = matValues(iRowsSrc{iFile},:,:);
        matValues = tmpValues;
    end
    % Remove the @filename at the end of the row names (if DestRowNames, this had been done already in process_stdrow)
    if ~isempty(RowNames) && iscell(RowNames) && isempty(DestRowNames)
        for iRow = 1:length(RowNames)
            iAt = find(RowNames{iRow} == '@', 1);
            if ~isempty(iAt) && any(RowNames{iRow}(iAt+1:end) == '/')
                RowNames{iRow} = strtrim(RowNames{iRow}(1:iAt-1));
            end
        end
    end
    
    % === BAD CHANNELS ===
    % Use an existing list of bad channels
    if isfield(sMat, 'ChannelFlag') && ~isempty(sMat.ChannelFlag) && (length(sMat.ChannelFlag) == size(matValues,1))
        ChannelFlag = sMat.ChannelFlag;
    % Else: Detect bad channels in matrix/timefreq files
    elseif ~isempty(RowNames)
        % By default: all channels are good
        ChannelFlag = ones(size(matValues,1),1);
        % Exclude the flat signals (all values are exactly zero)
        if isZeroBad
            % Detect the rows for which all the values are exactly zero
            iBadChan = find(all(all(matValues==0,2),3));
            % If there are some: tag them as bad
            if ~isempty(iBadChan)
                ChannelFlag(iBadChan) = -1;
            end
        end
    else
        ChannelFlag = [];
    end
    % Clear the loaded file
    clear sMat;

    % === DIFFERENCE A-B ===
    % Substract file from set B, if applicable
    if isDiff
        % Load file #iFile
        if ischar(FilesListB{iFile})
            sMat2 = in_bst(FilesListB{iFile});
        % File is already loaded
        else
            sMat2 = FilesListB{iFile};
        end
        % Check measure of TF values
        if strcmpi(matName, 'TF') && ~isreal(sMat2.(matName))
            error('Compute a measure on the TF files first.');
        end
        % Unconstrained sources: Compute the norm of the three orientations
        if strcmpi(matName, 'ImageGridAmp') && (sMat2.nComponents ~= 1) && ismember(Function, {'norm', 'rms', 'normdiff', 'normdiffnorm'})
            sMat2 = process_source_flat('Compute', sMat2, 'rms');
        end
        % Re-order rows in matrix/timefreq files
        if ~isempty(DestRowNames) && ~isequal(AllRowNames{nFiles + iFile}, DestRowNames)
            tmpValues = zeros(length(DestRowNames), size(sMat2.(matName),2), size(sMat2.(matName),3));
            tmpValues(iRowsDest{nFiles + iFile},:,:) = sMat2.(matName)(iRowsSrc{nFiles + iFile},:,:);
            sMat2.(matName) = tmpValues;
        end
        % Add bad channels from file B to file A
        if ~isempty(ChannelFlag) && isfield(sMat2, 'ChannelFlag')
            ChannelFlag(sMat2.ChannelFlag == -1) = -1;
        % Detect bad channels in matrix/timefreq files
        elseif ~isempty(RowNames) && isZeroBad
            % Detect the rows for which all the values are exactly zero
            iBadChan = find(all(all(sMat2.(matName)==0,2),3));
            if ~isempty(iBadChan)
                ChannelFlag(iBadChan) = -1;
            end
        end
        % Check size
        if ~isempty(matValues) && ~isequal(size(matValues), size(sMat2.(matName)))
            Messages = [Messages, sprintf('Files #A%d and #B%d have different numbers of channels or time samples.\n', iFile, iFile)];
            continue;
        end
        % Substract two files: A - B (absolute values or relative)
        switch (Function)
            case {'mean', 'meandiffnorm', 'median'}
                matValues = matValues - double(sMat2.(matName));
            case 'rms'
                matValues = matValues.^2 - double(sMat2.(matName)).^2;
                if isVariance
                    error('Variance output for RMS computation does not make sense.');
                end
            case {'abs','norm','normdiff','normdiffnorm'}
                matValues = abs(matValues) - abs(double(sMat2.(matName)));
        end
        % Use the norm of the difference: |A-B|
        if ismember(Function, {'meandiffnorm','normdiffnorm'})
            % Unconstrained sources: Compute the norm of the three orientations
            if strcmpi(matName, 'ImageGridAmp') && (sMat2.nComponents ~= 1)
                sMat2.(matName) = matValues;
                sMat2 = process_source_flat('Compute', sMat2, 'rms');
                matValues = sMat2.(matName);
                % Update number of components
                if isfield(sMat2, 'nComponents') && ~isempty(sMat2.nComponents)
                    nComponents = sMat2.nComponents;
                end
            else
                matValues = abs(matValues);
            end
        end
        % Effective number of averages
        % Leff = 1 / sum_i(w_i^2 / Leff_i),  with w1=1 and w2=-1
        %      = 1 / (1/Leff_A + 1/Leff_B))
        Leff = 1 / (1/Leff + 1/sMat2.Leff);
        % Clear the loaded file
        clear sMat2;
    % Else: Apply absolute values if necessary
    else
        switch (Function)
            case 'mean'          % Nothing to do
            case 'rms',          matValues = matValues .^ 2;
            case {'abs','norm'}, matValues = abs(matValues);
        end
    end
    
    % === EFFECTIVE NUMBER OF AVERAGES ===
    % LeffTotal = 1 / sum_i(w_i^2 / Leff_i)
    if isWeighted
        % w_i = Leff_i / sum_i(Leff_i)
        % Will need to divide final averaged values by sum_i(Leff_i)=sum_i(wi) after the computation
        w = Leff;
        % => LeffTotal = sum(Leff_i)
        LeffTotal = LeffTotal + Leff;
    else
        % w_i = 1 / nFiles(valid)
        % Will need to divide final averaged values by nFiles(Valid)=sum_i(wi) after the computation
        w = 1;
        % LeffTotal = nFiles^2 / sum(1/Leff_i)
        % Computing here only the sum, and will compute the final value at the end
        LeffTotal = LeffTotal + 1 ./ Leff;
    end
    
    % === CHECK DIMENSIONS ===
    % If file is first of the list
    if (iFile == 1)
        % Initialize data fields
        MeanValues = zeros(size(matValues));
        if isVariance
            VarValues = zeros(size(matValues));
        end
        MeanMatName = matName;
        % If processing recordings (="data") files
        isData = strcmpi(MeanMatName, 'F');
        % Good channels
        NbChannels = length(ChannelFlag);
        if isData && ~isempty(ChannelFlag)
            nGoodSamples = zeros(NbChannels, 1);
        else
            nGoodSamples = zeros(size(matValues,1), 1);
        end
        % Initial Time Vector
        initTimeVector = TimeVector;
        initMeasure = Measure;
        if (length(TimeVector) >= 2)
            sFile.prop.sfreq = 1 ./ (TimeVector(2) - TimeVector(1));
        else
            sFile.prop.sfreq = 1000;
        end
        % Initial row names
        initRowNames = RowNames;
    % All other files
    else
        % If current matrix has not the same size than the others
        if ~isequal([size(MeanValues,1),size(MeanValues,2),size(MeanValues,3)], [size(matValues,1),size(matValues,2),size(matValues,3)])
            Messages = [Messages, sprintf('Error: File #%d contains a data matrix that has a different size:\n', iFile)];
            if ischar(FilesListA{iFile})
                Messages = [Messages, FilesListA{iFile}, 10];
            end
            continue;
        elseif ~strcmpi(MeanMatName, matName)
            Messages = [Messages, sprintf('Error: File #%d has a different type. All the result files should be of the same type (full results or kernel-only):\n', iFile)];
            if ischar(FilesListA{iFile})
                Messages = [Messages, FilesListA{iFile}, 10];
            end
            continue;
        % Check time values
        elseif (length(initTimeVector) ~= length(TimeVector)) && ~all(initTimeVector == TimeVector)
            Messages = [Messages, sprintf('Error: File #%d has a different time definition:\n', iFile)];
            if ischar(FilesListA{iFile})
                Messages = [Messages, FilesListA{iFile}, 10];
            end
            continue;
        % Check TF measure
        elseif ~isempty(initMeasure) && ~strcmpi(Measure, initMeasure)
            Messages = [Messages, sprintf('Error: File #%d has a different measure applied to the time-frequency coefficients:\n', iFile)];
            if ischar(FilesListA{iFile})
                Messages = [Messages, FilesListA{iFile}, 10];
            end
            continue;
        end
        % Check row names
        if ~isequal(initRowNames, RowNames)
            Messages = [Messages, sprintf('Warning: File #%d has a different list of row names, averaging them might be inappropriate.\n', iFile)];
            if ischar(FilesListA{iFile})
                Messages = [Messages, FilesListA{iFile}, 10];
            end
        end
    end

    % === CHECK NUMBER OF CHANNELS ===
    nGoodSamples_old = nGoodSamples;
    if ~isempty(ChannelFlag) && (NbChannels ~= length(ChannelFlag))
        if isData
            % Data : number of channels MUST be the same for all samples
            error('All the input files should have the same number of channels.');
        else
            % Results and other: Simply ignore ChannelFlag definition
            NbChannels = 0;
            iGoodRows = true(size(matValues,1), 1);
        end
    else
        % Get good channels
        if ~isempty(ChannelFlag)
            iGoodRows = (ChannelFlag == 1);
        else
            iGoodRows = true(size(matValues,1), 1);
        end
    end
    % Count good channels (not necessarily an integer anymore: Leff can be any scalar)
    % nGoodSamples(iGoodRows) = nGoodSamples(iGoodRows) + nAvg;
    nGoodSamples(iGoodRows) = nGoodSamples(iGoodRows) + w;
    % Add file to the list of files used in the average
    iOutFiles(end+1) = iFile;
    
    % === ADD NEW VALUES ===
    % Median
    if strcmpi(Function, 'median')
        MeanValues(:,:,:,length(iOutFiles)) = matValues;
    % Mean/Variance
    else
        % Q = matValues - MeanValues
        matValues(iGoodRows,:) = matValues(iGoodRows,:) - MeanValues(iGoodRows,:);
        % R = Q * nAvg / nGoodSamples
        % R = bst_bsxfun(@rdivide, matValues(iGoodRows,:) .* nAvg, nGoodSamples(iGoodRows));
        R = bst_bsxfun(@rdivide, matValues(iGoodRows,:) .* w, nGoodSamples(iGoodRows));
        if isVariance
            % VarValues = VarValues + nGoodSamples_old * Q * R
            matValues(iGoodRows,:) = matValues(iGoodRows,:) .* R;
            VarValues(iGoodRows,:) = VarValues(iGoodRows,:) + bst_bsxfun(@times, matValues(iGoodRows,:), nGoodSamples_old(iGoodRows));
        end
        MeanValues(iGoodRows,:) = MeanValues(iGoodRows,:) + R;
    end
    nFilesValid = nFilesValid + 1;
    
    % === ADD EVENTS ===
    if ~isempty(Events)
        sFile = import_events(sFile, [], Events);
    end
end
% Nothing was processed
if isempty(MeanValues)
    return;
end
% Bad channels = channels that are BAD in ALL the samples
if (NbChannels > 0)
    MeanBadChannels = find(nGoodSamples == 0);
else
    MeanBadChannels = [];
end
% Output bad channels
if strcmpi(matName, 'F') || (strcmpi(matName, 'Value') && isstruct(FilesListA{iFile}) && isfield(FilesListA{iFile}, 'ChannelFlag') && ~isempty(FilesListA{iFile}.ChannelFlag))
    OutChannelFlag  = ones(NbChannels, 1);
    OutChannelFlag(MeanBadChannels) = -1;
else
    OutChannelFlag = [];
end

% === FINALIZE COMPUTATION ===
% Median
if strcmpi(Function, 'median')
    MeanValues = median(MeanValues, 4);
% RMS
elseif strcmpi(Function, 'rms')
    MeanValues = sqrt(MeanValues);
end
% Variance
if isVariance
    iMulti = (nGoodSamples > 1);
    iOther = (nGoodSamples <= 1);
    % If n>1: 
    VarValues(iMulti,:) = bst_bsxfun(@rdivide, VarValues(iMulti,:), (nGoodSamples(iMulti)-1));
    % If n<=1: Var = 0
    VarValues(iOther, :) = 0;
    Stat.var = VarValues;
end
% Effective number of averages (for regular non-weigthed average)
if ~isWeighted
    LeffTotal = nFilesValid^2 / LeffTotal;
end
% Time vector
Stat.MatName      = MeanMatName;
Stat.mean         = MeanValues;
Stat.Time         = initTimeVector;
Stat.nAvg         = nAvgTotal;
Stat.Leff         = LeffTotal;
Stat.Measure      = initMeasure;
Stat.ChannelFlag  = OutChannelFlag;
Stat.RowNames     = RowNames;
Stat.RefRowNames  = RefRowNames;
Stat.nGoodSamples = nGoodSamples;
Stat.nComponents  = nComponents;
Stat.GridAtlas    = GridAtlas;
Stat.Freqs        = Freqs;
Stat.TFmask       = TFmask;
% Remove last \n at the end of the messages
if ~isempty(Messages)
    Messages = Messages(1:end-1);
end
% Return the list of all the events found in all the files
AllEvents = sFile.events;

% Close progress bar
if ~isPercent
    bst_progress('stop');
end






