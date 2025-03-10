function OutputFiles = bst_connectivity(FilesA, FilesB, OPTIONS)
% BST_CONNECTIVITY: Computes a connectivity metric between two files A and B
%
% USAGE:  OutputFiles = bst_connectivity(FilesA, FilesB, OPTIONS)
%             OPTIONS = bst_connectivity()
%
% References: 
%   wPLI and debiased wPLI as defined in:
%     Vinck M, Oostenveld R, van Wingerden M, Battaglia F, Pennartz CM
%     An improved index of phase-synchronization for electrophysiological data in the presence of volume-conduction, noise and sample-size bias
%     Neuroimage, Apr 2011, https://pubmed.ncbi.nlm.nih.gov/21276857
%   wPLI = abs(E{imag(Sab)}) / E{abs(imag(Sab))}; E{} is expectation value, i.e. terms we must average. Sab is the cross-spectrum.
%   Debiased wPLI square, eq. 33 in same publication, after simplifications:
%   dwPLI = (N * E{imag(Sab)}^2 - E{imag(Sab)^2}) / (N * E{abs(imag(Sab))}^2 - E{imag(Sab)^2})


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
% Authors: Francois Tadel, Gian-Marco Dumas, Sylvain Baillet, 2012-2022
%          Martin Cousineau, 2017
%          Hossein Shahabi, 2019-2020
%          Daniele Marinazzo, 2022
%          Marc Lalancette, Raymundo Cassani, 2023

% FilesA/B variables are now sInput structures (required for PCA). Code still compatible with cells
% of file names (as before 2023), when PCA is not requested

%% ===== DEFAULT OPTIONS =====
Def_OPTIONS.Method        = 'corr';
Def_OPTIONS.ProcessName   = '';
Def_OPTIONS.TargetA       = [];
Def_OPTIONS.TargetB       = [];
Def_OPTIONS.Freqs         = 0;
Def_OPTIONS.TimeWindow    = [];
Def_OPTIONS.IgnoreBad     = 0;             % For recordings: Ignore bad channels
Def_OPTIONS.UnconstrFunc  = 'max';         % Unconstrained sources: max was forced pre-2023, keep as default in code, but GUI option default is 'pca'.
Def_OPTIONS.ScoutFunc     = 'all';         % Scout function {mean, max, pca, std, all}
Def_OPTIONS.ScoutTime     = 'before';      % When to apply scout function: {before, after}
Def_OPTIONS.PcaOptions    = [];            % Options for scout or unconstrained function 'pca', from panel_pca
Def_OPTIONS.RemoveMean    = 1;             % Option for Correlation
Def_OPTIONS.CohMeasure    = 'mscohere';    % {'mscohere'=Magnitude-square, 'icohere'=Imaginary, 'icohere2019', 'lcohere2019'}
Def_OPTIONS.WinLen        = [];            % Option for coherence & PLV 2023
Def_OPTIONS.WinOverlap    = 0.50;          % Option for spectral estimates (Coherence 2021, PLV 2023)
Def_OPTIONS.MaxFreqRes    = [];            % Option for spectral estimates (Coherence deprecated, spectral Granger)
Def_OPTIONS.MaxFreq       = [];            % Option for spectral estimates (Coherence, PLV, spectral Granger)
Def_OPTIONS.GrangerOrder  = 10;            % Option for Granger causality
Def_OPTIONS.GrangerDir    = 'out';         % Option for Granger causality
Def_OPTIONS.RemoveEvoked  = 0;             % Removed evoked response to each single trial (useful to bring signals closer to a stationnary state)
Def_OPTIONS.isMirror      = 1;             % Option for filtering bands (PLV, PTE, etc.); deprecated default is 1, now always 0 in calling processes
Def_OPTIONS.PlvMeasure    = 'magnitude';   % Option for phase synchronization estimates (PLV process)
Def_OPTIONS.isSymmetric   = [];            % Optimize processing and storage for simple matrices
Def_OPTIONS.pThresh       = 0.05;          % Significance threshold for the metric
Def_OPTIONS.OutputMode    = 'input';       % {'avg','input','concat','avgcoh'}
Def_OPTIONS.iOutputStudy  = [];
Def_OPTIONS.isSave        = 1;
Def_OPTIONS.tfMeasure     = 'hilbert';     % Option for henv, coherence & PLV 2023 {hilbert, morlet, stft}
Def_OPTIONS.TimeRes       = [];            % Option for henv, coherence & PLV 2023 {full, windowed, none} (replaces '...t' methods, and former dynamic/static)
% Def_OPTIONS.nAvgLen       = 1;             % Option for coherence & PLV 2023, for 'windowed' time resolution
Def_OPTIONS.MorletFc      = [];            % Option for envelope correlation 'morlet'
Def_OPTIONS.MorletFwhmTc  = [];            % Option for envelope correlation 'morlet'
Def_OPTIONS.StftWinLen    = [];            % Option for STFT coherence and & PLV 2023
Def_OPTIONS.StftWinOvr    = [];            % Option for STFT coherence and & PLV 2023
% Return the default options
if (nargin == 0)
    OutputFiles = Def_OPTIONS;
    return
end


%% ===== INITIALIZATIONS =====
% Copy default options to OPTIONS structure (do not replace defined values)
OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);

% Compatibility: old time-resolved methods ending it 't'
if ismember(OPTIONS.Method, {'plvt','ciplvt','wplit'})
    OPTIONS.Method(end) = '';
    OPTIONS.TimeRes = 'full';
end

% Initialize output variables
OutputFiles = {};
% AllComments = {};
Ravg = [];
nAvg = 0;
nFiles = length(FilesA);

% Initialize progress bar
if bst_progress('isVisible')
    startValue = bst_progress('get');
else
    startValue = 0;
end
% If only one file: process as only one file (no concatenation, no average removal)
if (nFiles == 1)
    OPTIONS.OutputMode = 'input';
    OPTIONS.RemoveEvoked = 0;
end
% Frequency bands
if ~isempty(OPTIONS.Freqs) 
    nFreqBands = size(OPTIONS.Freqs, 1);
    if iscell(OPTIONS.Freqs)
        % Get frequency bands once for methods that need them.
        BandBounds = process_tf_bands('GetBounds', OPTIONS.Freqs);
    end
end
% Frequency limits: 0 = disable
if isequal(OPTIONS.MaxFreq, 0)
    OPTIONS.MaxFreq = [];
end
% Frequency max resolution: 0 = error
if (isempty(OPTIONS.MaxFreqRes) || (OPTIONS.MaxFreqRes <= 0)) && isempty(OPTIONS.StftWinLen) && ...
        (strcmpi(OPTIONS.tfMeasure, 'stft') || ismember(OPTIONS.Method, {'spgranger'}))
    bst_report('Error', OPTIONS.ProcessName, [], 'Invalid frequency resolution.');
    return;
end
% Processing [1xN] or [NxN]
isConnNN = isempty(FilesB);
% Keep original input files for attaching output node in tree, and for history, when doing PCA.
OrigFilesA = GetFileNames(FilesA);
if isConnNN
    OrigFilesB = OrigFilesA;
else
    OrigFilesB = GetFileNames(FilesB);
end    
% Symmetric storage?
if isempty(OPTIONS.isSymmetric)
    OPTIONS.isSymmetric = any(strcmpi(OPTIONS.Method, {'corr','cohere','plv','ciplv','wpli','aec','henv'})) && (isempty(FilesB) || (isequal(OrigFilesA, OrigFilesB) && isequal(OPTIONS.TargetA, OPTIONS.TargetB)));
end
% Options for LoadInputFile(), for FilesA and FilesB separately
LoadOptionsA.IgnoreBad   = OPTIONS.IgnoreBad;  % From data files: KEEP the bad channels
LoadOptionsA.ProcessName = OPTIONS.ProcessName;
if strcmpi(OPTIONS.ScoutTime, 'before')
    LoadOptionsA.TargetFunc = OPTIONS.ScoutFunc;
else
    LoadOptionsA.TargetFunc = 'All';
end
% Load kernel-based results as kernel+data for coherence and phase metrics only.
% This is always for 1xN, i.e. the B side has all sources and the A side has only one signal.
% Kernel on the A side is not implemented.
methodsKernelBased = {'plv', 'ciplv', 'wpli', 'dwpli', 'pli', 'cohere'};
LoadOptionsA.LoadFull = 1; % ~isempty(OPTIONS.TargetA)  || ~ismember(OPTIONS.Method, {'cohere','plv','ciplv','wpli'});  
LoadOptionsB = LoadOptionsA;
LoadOptionsB.LoadFull = ~isempty(OPTIONS.TargetB) || ~ismember(OPTIONS.Method, methodsKernelBased);
% Use the signal processing toolbox?
if bst_get('UseSigProcToolbox')
    hilbert_fcn = @hilbert;
else
    hilbert_fcn = @oc_hilbert;
end
% Were scouts requested?
OPTIONS.isScoutA = ~isempty(OPTIONS.TargetA) && (isstruct(OPTIONS.TargetA) || iscell(OPTIONS.TargetA));
OPTIONS.isScoutB = ~isempty(OPTIONS.TargetB) && (isstruct(OPTIONS.TargetB) || iscell(OPTIONS.TargetB));
% No scouts. Avoid confusion.
if ~OPTIONS.isScoutA && ~OPTIONS.isScoutB
    OPTIONS.ScoutFunc = 'all';
end
% Error if trying to compute across multiple subjects, but skip for legacy calls (file names instead of input structures).
% There are further checks later when using scouts, if mixing surface files.
if ~isempty(FilesA) && isstruct(FilesA) && ~strcmpi(OPTIONS.OutputMode, 'input')
    uniqSubj = unique({FilesA.SubjectFile});
    if numel(uniqSubj) > 1
        bst_report('Error', OPTIONS.ProcessName, [], ['<html>Connectivity cannot be computed directly across subjects. Select files from one subject at a time.<BR>' ...
            '(See also <a href="https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting#Loop_over_subjects">Scripting Tutorial</a>)']);
        return;
    end
end

%% ===== PCA =====
sInputToDel = [];
% Flatten unconstrained source orientations with PCA.
if strcmpi(OPTIONS.UnconstrFunc, 'pca')
    % This was not previously an option in this process, give errors if legacy call with missing options or file names as inputs.
    if (~isempty(FilesA) && ~isstruct(FilesA)) || (~isempty(FilesB) && ~isstruct(FilesB))
        bst_report('Error', OPTIONS.ProcessName, [], 'When selecting PCA, bst_connectivity now requires sInput structures instead of file names as inputs.');
        return;
    end
    % Check if there are unconstrained sources. The function only checks the first file. Other files
    % would be checked for inconsistent dimensions in bst_pca, and if so there will be an error.
    isUnconstrA = ~( isempty(FilesA) || ~isfield(FilesA, 'FileType') || ~ismember(FilesA(1).FileType, {'results', 'timefreq'}) || ...
        ~any(process_extract_scout('CheckUnconstrained', OPTIONS.ProcessName, FilesA(1))) ); % any() needed for mixed models
    isUnconstrB = ~(isempty(FilesB) || ~isfield(FilesB, 'FileType') || ~ismember(FilesB(1).FileType, {'results', 'timefreq'}) || ...
        ~any(process_extract_scout('CheckUnconstrained', OPTIONS.ProcessName, FilesB(1)))); % any() needed for mixed models
    if isempty(isUnconstrA) || isempty(isUnconstrB)
        return; % Error already reported;
    end
    % Flattening needed.
    if isUnconstrA || isUnconstrB
        if isempty(OPTIONS.PcaOptions)
            bst_report('Error', sProcess, [], 'Missing PCA options for flattening unconstrained sources.');
            return;
        end
        % FilesA/B are replaced by temporary files as needed by RunTempPcaFlat.
        [FilesA, isTempPcaA, FilesB, isTempPcaB] = process_extract_scout('RunTempPcaFlat', OPTIONS.ProcessName, ...
            OPTIONS.PcaOptions, FilesA, FilesB);
        if isTempPcaA
            sInputToDel = [sInputToDel, FilesA];
        end
        if isTempPcaB
            sInputToDel = [sInputToDel, FilesB];
        end
        % We no longer have unconstrained sources.
        OPTIONS.UnconstrFunc = 'none';
    end
end

% Catch errors from this point to ensure temporary files are deleted.
try

% Extract scouts with PCA, and save time series in temp files.
if strcmpi(OPTIONS.ScoutFunc, 'pca') && ~isempty(OPTIONS.PcaOptions) && ~strcmpi(OPTIONS.PcaOptions.Method, 'pca')
    % Check inputs
    if (~isempty(FilesA) && ~isstruct(FilesA)) || (~isempty(FilesB) && ~isstruct(FilesB))
        bst_report('Error', OPTIONS.ProcessName, [], 'When selecting PCA, bst_connectivity now requires sInput structures instead of file names as inputs.');
        return;
    end
    % FilesA/B are replaced by temporary files as needed by RunTempPcaScout. It also correctly ignores non-result inputs.
    [FilesA, isTempPcaA, FilesB, isTempPcaB] = process_extract_scout('RunTempPcaScout', OPTIONS.ProcessName, ...
        OPTIONS.PcaOptions, FilesA, OPTIONS.TargetA, FilesB, OPTIONS.TargetB);
    if isTempPcaA
        sInputToDel = [sInputToDel, FilesA];
    end
    if isTempPcaB
        sInputToDel = [sInputToDel, FilesB];
    end
    % Here we must keep the scout function as 'pca' so that the temp atlas-based files are loaded properly.
end
% Else: we accept pca scout function without options or with file names as inputs as a legacy call.
% There will be a warning about deprecated pca through LoadInputFiles > process_extract_scout.

% Convert inputs to file names
FilesA = GetFileNames(FilesA);
FilesB = GetFileNames(FilesB);


%% ===== HISTORY =====
% History: keep list of inputs (original files), and history of 1st input (possibly temp file) if averaging
% If using temp files for flattening or scout PCA, this is the only place the % kept variance
% message and PCA input file list will be saved.
OutHist = struct;
if ~strcmpi(OPTIONS.OutputMode, 'input')
    if isConnNN
        OutHist = bst_history('add', OutHist, 'src', sprintf('Connectivity across %d files; history of the first input:', nFiles));
    else
        OutHist = bst_history('add', OutHist, 'src', sprintf('Connectivity across %d pairs of files; history of the first A input:', nFiles));
    end
    DataFile = file_resolve_link(FilesA{1});
    % Load file
    warning off MATLAB:load:variableNotFound
    DataHist = load(DataFile, 'History');
    warning on MATLAB:load:variableNotFound
    if ~isempty(DataHist)
        DataHist = CleanHist(DataHist);
        OutHist = bst_history('add', OutHist, DataHist.History, ' - ');
    end
    if ~isConnNN
        OutHist = bst_history('add', OutHist, 'src', sprintf('Connectivity across %d pairs of files; history of the first B input:', nFiles));
        DataFile = file_resolve_link(FilesB{1});
        % Load file
        warning off MATLAB:load:variableNotFound
        DataHist = load(DataFile, 'History');
        warning on MATLAB:load:variableNotFound
        if ~isempty(DataHist)
            DataHist = CleanHist(DataHist);
            OutHist = bst_history('add', OutHist, DataHist.History, ' - ');
        end
    end
    if isConnNN
        OutHist = bst_history('add', OutHist, 'src', sprintf('Connectivity across %d files; input files:', nFiles));
    else
        OutHist = bst_history('add', OutHist, 'src', sprintf('Connectivity across %d pairs of files; input files:', nFiles));
    end
    for iFile = 1:nFiles
        if isConnNN
            OutHist = bst_history('add', OutHist, 'src', [' - ' OrigFilesA{iFile}]);
        else
            OutHist = bst_history('add', OutHist, 'src', [' -A: ' OrigFilesA{iFile} ' -B: ' OrigFilesB{iFile}]);
        end
    end
end
    

%% ===== CONCATENATE INPUTS / REMOVE AVERAGE =====
sAverageA = [];
sAverageB = [];
nTrials = 1; % for Granger
% How to read the files
switch (OPTIONS.OutputMode)
    case 'concat',  isConcat = 1;
    case 'avgcoh',  isConcat = 2;
    otherwise,      isConcat = 0;
end

% === LOAD CALLS ONLY ===
% % Prepare load calls, data will be loaded in bst_cohn_2021
% if strcmpi(OPTIONS.OutputMode, 'avgcoh') && ~OPTIONS.RemoveEvoked
% % (nTrials only used for granger - not coh)    
% %     % Number of concatenated trials to process 
% %     nTrials = nFiles;
%     % Load first FileA, for getting all the file metadata
%     sInputA = bst_process('LoadInputFile', FilesA{1}, OPTIONS.TargetA, OPTIONS.TimeWindow, LoadOptionsA);
%     if (size(sInputA.Data,2) < 2)
%         bst_report('Error', OPTIONS.ProcessName, FilesA{1}, 'Invalid time selection, check the input time window.');
%         CleanExit; return;
%     end
%     % FilesA load calls
%     sInputA.Data = cell(1, nFiles);
%     for iFile = 1:nFiles
%         sInputA.Data{iFile} = {@bst_process, 'LoadInputFile', FilesA{iFile}, OPTIONS.TargetA, OPTIONS.TimeWindow, LoadOptionsA};
%     end
%     FilesA = FilesA(1);
%     % FilesB load calls
%     if ~isConnNN
%         % Load first FileB, for getting all the file metadata
%         sInputB = bst_process('LoadInputFile', FilesB{1}, OPTIONS.TargetB, OPTIONS.TimeWindow, LoadOptionsB);
%         if (size(sInputB.Data,2) < 2)
%             bst_report('Error', OPTIONS.ProcessName, FilesB{1}, 'Invalid time selection, check the input time window.');
%             CleanExit; return;
%         end
%         % FilesB load calls
%         sInputB.Data = cell(1, nFiles);
%         for iFile = 1:nFiles
%             sInputB.Data{iFile} = {@bst_process, 'LoadInputFile', FilesB{iFile}, OPTIONS.TargetB, OPTIONS.TimeWindow, LoadOptionsB};
%         end
%         FilesB = FilesB(1);
%     else
%         sInputB = sInputA;
%     end

% === LOAD AND CONCATENATE === (Granger, PTE)
% Load all the data and concatenate it
if (isConcat >= 1)
    bst_progress('text', 'Loading input files...');
    % Number of concatenated trials to process (for Granger)
    nTrials = nFiles;
    % Concatenate FileA
    sInputA = LoadAll(FilesA, OPTIONS.TargetA, OPTIONS.TimeWindow, LoadOptionsA, isConcat, OPTIONS.RemoveEvoked, startValue);
    if isempty(sInputA)
        bst_report('Error', OPTIONS.ProcessName, FilesA, 'Could not calculate the average of input files A: the number of signals of all the files must be identical.');
        CleanExit; return;
    end
    FilesA = FilesA(1);
    % Concatenate FileB
    if ~isConnNN
        sInputB = LoadAll(FilesB, OPTIONS.TargetB, OPTIONS.TimeWindow, LoadOptionsB, isConcat, OPTIONS.RemoveEvoked, startValue);
        if isempty(sInputB)
            bst_report('Error', OPTIONS.ProcessName, FilesB, 'Could not calculate the average of input files B: the number of signals of all the files must be identical.');
            CleanExit; return;
        end
        FilesB = FilesB(1);
        % Some quality check
        if (size(sInputA.Data,2) ~= size(sInputB.Data,2))
            bst_report('Error', OPTIONS.ProcessName, [FilesA(:)', FilesB(:)'], 'Files A and B must have the same number of time samples.');
            CleanExit; return;
        end
    else
        sInputB = sInputA;
    end

% === LOAD AND REMOVE AVERAGE ===
elseif OPTIONS.RemoveEvoked
    % Average: Files A
    [~, sAverageA] = LoadAll(FilesA, OPTIONS.TargetA, OPTIONS.TimeWindow, LoadOptionsA, 0, 1, startValue);
    if isempty(sAverageA)
        bst_report('Error', OPTIONS.ProcessName, FilesA, 'Could not calculate the average of input files A: the dimensions of all the files must be identical.');
        CleanExit; return;
    end
    % Average: Files B
    if ~isConnNN
        [~, sAverageB] = LoadAll(FilesB, OPTIONS.TargetB, OPTIONS.TimeWindow, LoadOptionsB, 0, 1, startValue);
        if isempty(sAverageB)
            bst_report('Error', OPTIONS.ProcessName, FilesB, 'Could not calculate the average of input files B: the dimensions of all the files must be identical.');
            CleanExit; return;
        end
    end
end
if isConnNN
    FilesB = FilesA;
end 


%% ===== CALCULATE CONNECTIVITY =====
SurfaceFileA = [];
SurfaceFileB = [];
% Save scouts structures in the options
OPTIONS.sScoutsA = [];
OPTIONS.sScoutsB = [];
R = [];
Time = [];
nWinLenSamples = [];

% Loop over input files
for iFile = 1 : length(FilesA)
    % Increments here, and in LoadAll above. 100 points are assigned per process (in bst_process('run'))
    bst_progress('set',  round(startValue + (iFile-1) / nFiles * 100));
    %% ===== LOAD SIGNALS =====
    if ismember(OPTIONS.OutputMode, {'avg','input'})
        bst_progress('text', 'Loading input files...');
        % Load reference signal
        sInputA = bst_process('LoadInputFile', FilesA{iFile}, OPTIONS.TargetA, OPTIONS.TimeWindow, LoadOptionsA);
        if (size(sInputA.Data,2) < 2)
            bst_report('Error', OPTIONS.ProcessName, FilesA{iFile}, 'Invalid time selection, check the input time window.');
            CleanExit; return;
        end
        % Check for atlas-based files: no "after" option for the scouts
        if isfield(sInputA, 'Atlas') && ~isempty(sInputA.Atlas) && (3*length(sInputA.Atlas.Scouts) >= size(sInputA.Data,1))
            if strcmpi(OPTIONS.ScoutTime, 'after') % and thus not 'all'
                bst_report('Warning', OPTIONS.ProcessName, FilesA{iFile}, 'Inputs are atlas-based files (already scouts). Cannot apply selected scout function after connectivity.');
                OPTIONS.ScoutTime = 'before';
            end
            sInputA.DataType = 'matrix'; % This should already be the case.
        end
        % Note number of time samples
        if (iFile == 1) || strcmpi(OPTIONS.OutputMode, 'input') 
            nTime = size(sInputA.Data,2);
        % Averaging: check for similar dimension in time
        elseif strcmpi(OPTIONS.OutputMode, 'avg') && (size(sInputA.Data,2) ~= nTime)
            bst_report('Error', OPTIONS.ProcessName, FilesA{iFile}, 'Invalid time selection, probably due to different time vectors in the input files.');
            CleanExit; return;
        end
        % Remove average
        if ~isempty(sAverageA)
            sInputA.Data = sInputA.Data - sAverageA.Data;
        end
        % If a target signal was defined
        if ~isConnNN
            % Load target signal
            sInputB = bst_process('LoadInputFile', FilesB{iFile}, OPTIONS.TargetB, OPTIONS.TimeWindow, LoadOptionsB);
            if isempty(sInputB.Data)
                bst_report('Error', OPTIONS.ProcessName, FilesB{iFile}, 'Invalid time selection, check the input time window.');
                CleanExit; return;
            end
            % Check for atlas-based files: no "after" option for the scouts
            if isfield(sInputB, 'Atlas') && ~isempty(sInputB.Atlas) && (3*length(sInputB.Atlas.Scouts) >= size(sInputB.Data,1))
                if strcmpi(OPTIONS.ScoutTime, 'after') % and thus not 'all'
                    bst_report('Warning', OPTIONS.ProcessName, FilesB{iFile}, 'Inputs B are atlas-based files (already scouts). Cannot apply selected scout function after connectivity.');
                    OPTIONS.ScoutTime = 'before';
                end
                sInputB.DataType  = 'matrix';
            end
            % Check same time in A and B
            if (nTime ~= size(sInputB.Data,2))
                bst_report('Error', OPTIONS.ProcessName, {FilesA{iFile}, FilesB{iFile}}, 'Files A and B must have the same number of time samples.');
                CleanExit; return;
            end
            % Remove average
            if ~isempty(sAverageB)
                sInputB.Data = sInputB.Data - sAverageB.Data;
            end
        % Else: Use the same info as FileA
        else
            sInputB = sInputA;
        end
    end
    % Get the sampling frequency
    sfreq = 1 ./ (sInputA.Time(2) - sInputA.Time(1));
    % Round the sampling frequency at 1e6
    sfreq = round(sfreq * 1e6) * 1e-6;
    nA = size(sInputA.Data,1);
    nB = size(sInputB.Data,1);
    % Number of sources if B is kernel-based
    if ~isempty(sInputB.ImagingKernel) && ismember(OPTIONS.Method, methodsKernelBased)
        nB = size(sInputB.ImagingKernel, 1);
    end
    
    % ===== CHECK UNCONSTRAINED SOURCES =====
    % Unconstrained models?
    isUnconstrA = ismember(sInputA.DataType, {'results', 'scouts', 'matrix'}) && ~isempty(sInputA.nComponents) && (sInputA.nComponents ~= 1);
    isUnconstrB = ismember(sInputB.DataType, {'results', 'scouts', 'matrix'}) && ~isempty(sInputB.nComponents) && (sInputB.nComponents ~= 1);
    % Mixed source models now supported, but check further if we're using any scouts from unconstrained regions.
    if isUnconstrA && (sInputA.nComponents == 0)
        % Here, the sInput structures are based on 'matrix' template, but also much like atlas-based
        % result files. We can use this function to get the nComp info for each scout (but GridAtlas
        % already fixed in bst_process 'LoadInputFile').
        [~, ~, nComp] = process_extract_scout('FixAtlasBasedGrid', OPTIONS.ProcessName, FilesA{iFile}, sInputA);
        isUnconstrA = any(nComp ~= 1); 
    end
    if isUnconstrB && (sInputB.nComponents == 0)
        [~, ~, nComp] = process_extract_scout('FixAtlasBasedGrid', OPTIONS.ProcessName, FilesB{iFile}, sInputB);
        isUnconstrB = any(nComp ~= 1);
    end
    
    % ===== GET SCOUTS SCTRUCTURES =====
    % TODO: We may not need this. sInputA/B.Atlas could be used instead of sScoutsA/B, which are only used for comments and 'after' scout extraction.
    % This is a bit slow: only load once if surface files match.
    % Selected scout function now saved in sScouts in GetScoutsInfo (overrides the one stored in the SurfaceFile, to use scout function requested in the process options).
    % Scouts for FilesB
    if OPTIONS.isScoutB
        % Verify if surface files match.
        if iFile == 1 || ~strcmpi(SurfaceFileB, sInputB.SurfaceFile)
            if iFile == 1
                SurfaceFileB = sInputB.SurfaceFile;
            elseif ~strcmpi(SurfaceFileB, sInputB.SurfaceFile) && ~strcmpi(OPTIONS.OutputMode, 'input')
                % One could process individual files based on different surface files (or subjects),
                % but not average those in this function.
                bst_report('Error', OPTIONS.ProcessName, FilesB{iFile}, 'Cannot compute connectivity across files from different subjects or surfaces together.');
                CleanExit; return;
            end
            OPTIONS.sScoutsB = process_extract_scout('GetScoutsInfo', OPTIONS.ProcessName, [], sInputB.SurfaceFile, OPTIONS.TargetB, [], OPTIONS.ScoutFunc);
        end
    end
    % Scouts for FilesA
    if OPTIONS.isScoutA
        if iFile == 1 || ~strcmpi(SurfaceFileA, sInputA.SurfaceFile)
            if iFile == 1
                SurfaceFileA = sInputA.SurfaceFile;
            elseif ~strcmpi(SurfaceFileA, sInputA.SurfaceFile) && ~strcmpi(OPTIONS.OutputMode, 'input')
                % One could process individual files based on different surface files (or subjects),
                % but not average those in this function.
                bst_report('Error', OPTIONS.ProcessName, FilesA{iFile}, 'Cannot compute connectivity across files from different subjects or surfaces together.');
                CleanExit; return;
            elseif ~isConnNN && isfield(sInputB, 'SurfaceFile') && ~strcmpi(sInputA.SurfaceFile, sInputB.SurfaceFile)
                bst_report('Error', OPTIONS.ProcessName, {FilesA{iFile}, FilesB{iFile}}, 'Cannot compute connectivity between files from different subjects or surfaces.');
                CleanExit; return;
            end
            if isConnNN || isequal(OPTIONS.TargetA, OPTIONS.TargetB)
                OPTIONS.sScoutsA = OPTIONS.sScoutsB;
            else
                OPTIONS.sScoutsA = process_extract_scout('GetScoutsInfo', OPTIONS.ProcessName, [], sInputA.SurfaceFile, OPTIONS.TargetA, [], OPTIONS.ScoutFunc);
            end
        end
    end
    
    %% ===== COMPUTE CONNECTIVITY METRIC =====
    % The sections below must return R matrices with dimensions: [nA x nB x nTime x nFreq]
    % or R structure with fields that are combined after file averaging.

    switch (OPTIONS.Method)
        % === CORRELATION ===
        case 'corr'
            DisplayUnits = 'Correlation';
            bst_progress('text', sprintf('Calculating: Correlation [%dx%d]...', nA, nB));
            Comment = 'Corr';
            % Verify WinLen argument for windowed metric
            if strcmpi(OPTIONS.TimeRes, 'windowed')
                % Window length and overlap in samples
                nWinLenSamples    = round(OPTIONS.WinLen * sfreq);
                nWinOvelapSamples = round(OPTIONS.WinOverlap * nWinLenSamples);
                if nWinLenSamples >= nTime
                    Message = 'File time duration too short wrt requested window length. Only computing one estimate across all time.';
                    bst_report('Warning', OPTIONS.ProcessName, unique({FilesA{iFile}, FilesB{iFile}}), Message);
                    % Avoid further checks and error messages.
                    OPTIONS.TimeRes = 'none';
                end
            end
            % Compute correlation
            if strcmpi(OPTIONS.TimeRes, 'windowed')
                Comment = [Comment '-time'];
                % Get [start, end] indices for windows
                [~, ixs] = bst_epoching(1 : length(sInputA.Time), nWinLenSamples, nWinOvelapSamples);
                nTimeOut = size(ixs,1);
                % Center of the time window (sample 1 = 0 s)
                Time = reshape((mean(ixs, 2)-1) ./ sfreq, 1, []);
                % Initialize R
                R = zeros(nA, nB, nTimeOut);
                for iWin = 1 : size(ixs, 1)
                    R(:,:,iWin) = bst_corrn(sInputA.Data(:, ixs(iWin,1) : ixs(iWin,2)), sInputB.Data(:, ixs(iWin,1): ixs(iWin,2)), OPTIONS.RemoveMean);
                end
            else
                % All the correlations with one call
                R = bst_corrn(sInputA.Data, sInputB.Data, OPTIONS.RemoveMean);
            end
            
        % ==== GRANGER ====
        case 'granger'
            DisplayUnits = 'Granger causality';
            bst_progress('text', sprintf('Calculating: Granger [%dx%d]...', nA, nB));
            % Using the connectivity toolbox developed at USC
            inputs.partial     = 0;
            inputs.nTrials     = nTrials;
            inputs.standardize = true;
            inputs.flagFPE     = true;
            inputs.lag         = 0;
            inputs.flagELM     = false;
            %inputs.rho         = 50;
            % If computing a 1xN interaction: selection of the Granger orientation
            if (nA == 1) && strcmpi(OPTIONS.GrangerDir, 'in')
                R = bst_granger(sInputA.Data, sInputB.Data, OPTIONS.GrangerOrder, inputs);
            else
                % [sink x source] = bst_granger(sink, source, ...)
                R = bst_granger(sInputB.Data, sInputA.Data, OPTIONS.GrangerOrder, inputs);
            end
            % Granger function returns a connectivity matrix [sink x source] = [to x from] => Needs to be transposed
            R = R';
            % Comment
            if (nA == 1)
                Comment = ['Granger(' OPTIONS.GrangerDir ')'];
            else
                Comment = 'Granger';
            end
            
        % ==== GRANGER SPECTRAL ====
        case 'spgranger'
            DisplayUnits = 'Granger causality';
            bst_progress('text', sprintf('Calculating: Granger spectral [%dx%d]...', nA, nB));
            % Using the connectivity toolbox developed at USC
            inputs.partial     = 0;
            inputs.nTrials     = nTrials;
            inputs.standardize = true;
            inputs.flagFPE     = true;
            inputs.lag         = 0;
            inputs.flagELM     = false;
            inputs.freqResolution = OPTIONS.MaxFreqRes;
            %inputs.rho         = 50;
            % If computing a 1xN interaction: selection of the Granger orientation
            if (nA == 1) && strcmpi(OPTIONS.GrangerDir, 'in')
                [R, ~, OPTIONS.Freqs] = bst_granger_spectral(sInputA.Data, sInputB.Data, sfreq, OPTIONS.GrangerOrder, inputs);
            else
                [R, ~, OPTIONS.Freqs] = bst_granger_spectral(sInputB.Data, sInputA.Data, sfreq, OPTIONS.GrangerOrder, inputs);
            end
            R = permute(R, [2 1 3]);
            % Remove the values at 0Hz => Meaningless
            iZero = find(OPTIONS.Freqs == 0);
            if ~isempty(iZero)
                OPTIONS.Freqs(iZero) = [];
                R(:,:,iZero) = [];
            end
            % Keep only the frequency bins we are interested in
            if ~isempty(OPTIONS.MaxFreq) && (OPTIONS.MaxFreq ~= 0)
                % Get frequencies of interest
                iFreq = find(OPTIONS.Freqs <= OPTIONS.MaxFreq);
                if isempty(iFreq)
                    bst_report('Error', OPTIONS.ProcessName, unique({FilesA{iFile}, FilesB{iFile}}), sprintf('No frequencies estimated below the highest frequency of interest (%1.2fHz). Nothing to save...', OPTIONS.MaxFreq));
                    CleanExit; return;
                end
                % Cut the unwanted frequencies
                R = R(:,:,iFreq);
                OPTIONS.Freqs = OPTIONS.Freqs(iFreq);
            end
            % Comment
            if (nA == 1)
                Comment = sprintf('SpGranger(%s,%1.1fHz)', OPTIONS.GrangerDir, OPTIONS.Freqs(2)-OPTIONS.Freqs(1));
            else
                Comment = sprintf('SpGranger(%1.1fHz)', OPTIONS.Freqs(2)-OPTIONS.Freqs(1));
            end
            % Reshape as [nA x nB x nTime x nFreq]
            R = reshape(R, size(R,1), size(R,2), 1, size(R,3));
            
        % ==== AEC ====
        % WARNING: This function has been deprecated. Now using the HENV implementation instead
        % See discussion on the forum: https://neuroimage.usc.edu/forums/t/30358
        case 'aec'   % DEPRECATED
            DisplayUnits = 'Average envelope correlation';
            bst_progress('text', sprintf('Calculating: AEC [%dx%d]...', nA, nB));
            Comment = 'AEC';

            % Initialize returned matrix
            R = zeros(nA, nB, nFreqBands);
            % Loop on each frequency band
            for iBand = 1:nFreqBands
                % Band-pass filter in one frequency band + Apply Hilbert transform
                DataAband = process_bandpass('Compute', sInputA.Data, sfreq, BandBounds(iBand,1), BandBounds(iBand,2));
                HA = transpose(hilbert_fcn(transpose(DataAband)));
                if isConnNN
                    HB = HA;
                else
                    DataBband = process_bandpass('Compute', sInputB.Data, sfreq, BandBounds(iBand,1), BandBounds(iBand,2));
                    HB = transpose(hilbert_fcn(transpose(DataBband)));
                end
                if OPTIONS.isOrth
                    if isConnNN
                        for iSeed = 1:size(HA,1)
                            % Orthogonalize complex coefficients, based on Hipp et al. 2012
                            % HBo is the amplitude of the component orthogonal to HA                            
                            HBo = imag(bsxfun(@times, HB, conj(HA(iSeed,:))./abs(HA(iSeed,:))));
                            % The orthogonalized signal can be computed like this (not necessary here):
                            % HBos = real(HBo .* ((1i*HA)./abs(HA)));
                            % avoid rounding errors
                            HBo(abs(HBo./abs(HB))<2*eps)=0;
                            % Compute correlation coefficients
                            R(iSeed,:,iBand) = correlate_dims(abs(HBo), abs(HA(iSeed,:)), 2);
                        end
                        % average the two "directions"
                        R(:,:,iBand) = (R(:,:,iBand)+R(:,:,iBand)')/2;
                    else
                        for iSeed = 1:size(HA,1)
                            HAo = imag(bsxfun(@times, HA(iSeed,:), conj(HB)./abs(HB)));
                            HBo = imag(bsxfun(@times, HB, conj(HA(iSeed,:))./abs(HA(iSeed,:))));
                            % avoid rounding errors
                            HAo(abs(bsxfun(@rdivide,HAo,abs(HA(iSeed,:))))<2*eps)=0;
                            HBo(abs(HBo./abs(HB))<2*eps)=0;
                            % Compute correlation coefficients
                            r1 = correlate_dims(abs(HA(iSeed,:)), abs(HBo), 2);
                            r2 = correlate_dims(abs(HB), abs(HAo), 2);
                            R(iSeed,:,iBand) = (r1+r2)/2;
                        end
                    end
                else
                    ampA = abs(HA);
                    ampB = abs(HB);
                    R(:,:,iBand) = bst_corrn(ampA,ampB);
                end
            end
            % Reshape as [nA x nB x nTime x nFreq]
            R = reshape(R, size(R,1), size(R,2), 1, size(R,3));
            
        % ==== COHERENCE & PHASE SYNC METRICS ====
        case {'plv', 'ciplv', 'wpli', 'dwpli', 'pli', 'cohere'} % 'dwpli', 'pli' not available in GUI
            % This case is also now used for time-resolved

            % Verify WinLen argument for windowed metric
            if strcmpi(OPTIONS.TimeRes, 'windowed')
                if ~isempty(OPTIONS.WinLen)
                    % Window length and overlap in samples
                    nWinLenSamples    = round(OPTIONS.WinLen * sfreq);
                    nWinOvelapSamples = round(OPTIONS.WinOverlap * nWinLenSamples);
                    if nWinLenSamples <= 1
                        Message = 'Requested window length smaller than one sample. Keeping full time resolution.';
                        bst_report('Info', OPTIONS.ProcessName, unique({FilesA{iFile}, FilesB{iFile}}), Message);
                        OPTIONS.TimeRes = 'full';
                    elseif nWinLenSamples >= nTime
                        Message = 'File time duration too short wrt requested window length. Only computing one estimate across all time.';
                        bst_report('Warning', OPTIONS.ProcessName, unique({FilesA{iFile}, FilesB{iFile}}), Message);
                        % Avoid further checks and error messages.
                        OPTIONS.TimeRes = 'none';
                    end
                else % empty WinLen: full time resolution
                    OPTIONS.TimeRes = 'full';
                end
            end

            % Display units and Comment
            switch OPTIONS.Method
                case 'plv'
                    DisplayUnits = 'Phase locking value';
                    Comment = 'PLV';
                case 'ciplv'
                    %DisplayUnits = 'Lagged phase synchronization';
                    DisplayUnits = 'Corrected imaginary PLV';
                    Comment = 'ciPLV';
                case 'wpli'
                    DisplayUnits = 'Weighted phase lag index';
                    Comment = 'wPLI';
                case 'dwpli'
                    DisplayUnits = 'Debiased wPLI';
                    Comment = 'dwPLI';
                case 'pli'
                    DisplayUnits = 'Phase lag index';
                    Comment = 'PLI';
                case 'cohere'
                    switch OPTIONS.CohMeasure
                        case 'mscohere'
                            DisplayUnits = 'Magnitude-squared coherence';
                            Comment = 'MSCoh';
                        case 'icohere2019'
                            DisplayUnits = 'Imaginary coherence';
                            Comment = 'ImCoh';
                        case 'icohere'
                            DisplayUnits = 'Squared lagged coherence';
                            Comment = 'LagCoh2';
                        case 'lcohere2019'
                            DisplayUnits = 'Lagged coherence';
                            %DisplayUnits = 'Corrected imaginary coherence';
                            Comment = 'LagCoh';
                    end
            end
            Comment = [Comment '-' OPTIONS.tfMeasure];
            if ismember(OPTIONS.TimeRes, {'full', 'windowed'})
                Comment = [Comment '-time'];
            end
            bst_progress('text', sprintf('Calculating: %s %s [%dx%d]...', OPTIONS.tfMeasure, Comment, nA, nB));

            switch OPTIONS.tfMeasure
                % "Instantaneous" formulae, using Hilbert transform.
                % Morlet wavelets are implemented the same way: full time resolution for each frequency
                case {'hilbert', 'morlet'}
                    % Deal with time resolution options, and initialize accumulators
                    if isempty(R) || strcmpi(OPTIONS.OutputMode, 'input')
                        switch OPTIONS.TimeRes
                            case 'full'
                                % Output time vector equal input time vector
                                nTimeOut = nTime;
                                Time = sInputA.Time;
                                nWinLenSamples = 1;
                                % Full time resolution, do nothing
                                TimeAvgFunc = @(X, dim) X;
                            case 'windowed'
                                % Output time vector: center of windows
                                [~, ixs] = bst_epoching(sInputA.Time, nWinLenSamples, nWinOvelapSamples);
                                nTimeOut = size(ixs,1);
                                % Center of the time window (sample 1 = 0 s)
                                Time = reshape((mean(ixs, 2)-1) ./ sfreq, 1, []);
                                % Time vector below replicates henv times: half a sample after actual center
                                % Time = reshape(floor(mean(ixs, 2)) ./ sfreq, 1, []);
                                % Average in time windows
                                TimeAvgFunc = @(X, dim) bst_epoching(X, nWinLenSamples, nWinOvelapSamples, dim, 1);
                            case 'none'
                                % No output time vector
                                nTimeOut = 1;
                                Time = [];
                                nWinLenSamples = nTime;
                                % Average across time
                                TimeAvgFunc = @(X, dim) mean(X, dim);
                            otherwise
                                error('Unknown time resolution param');
                        end
                        switch OPTIONS.Method
                            case 'cohere'
                                R.Sab = complex(zeros(nA, nB, nTimeOut, nFreqBands));
                                R.Saa = zeros(nA, nTimeOut, nFreqBands);
                                if ~isConnNN
                                    R.Sbb = zeros(nB, nTimeOut, nFreqBands);
                                end
                            case {'plv', 'ciplv'}
                                R.Sab = complex(zeros(nA, nB, nTimeOut, nFreqBands));
                            case 'pli'
                                R.SgnImSab = zeros(nA, nB, nTimeOut, nFreqBands);
                            case 'wpli'
                                R.ImSab = zeros(nA, nB, nTimeOut, nFreqBands);
                                R.AbsImSab = zeros(nA, nB, nTimeOut, nFreqBands);
                            case 'dwpli'
                                R.ImSab = zeros(nA, nB, nTimeOut, nFreqBands);
                                R.AbsImSab = zeros(nA, nB, nTimeOut, nFreqBands);
                                R.SqImSab = zeros(nA, nB, nTimeOut, nFreqBands);
                            otherwise
                                error('Unknown connectivity method.');
                        end
                        nWin = 0;
                        % Add the number of averaged samples & files to the report (only once per output file)
                        Message = sprintf('Estimating across %d time samples', nWinLenSamples); % samples are not independent due to bandpass filter
                        if ~strcmpi(OPTIONS.OutputMode, 'input') && nFiles > 1
                            Message = [Message sprintf(' per file, across %d files', nFiles)];
                        end
                        if ~isempty(Time)
                            Message = [Message ', for each output time point'];
                        end
                        bst_report('Info', OPTIONS.ProcessName, unique({FilesA{iFile}, FilesB{iFile}}), Message);
                    end

                    % Process one band at a time to minimize memory requirements.
                    for iBand = 1:nFreqBands
                        switch OPTIONS.tfMeasure
                            case 'hilbert'
                                % Band-pass filter in one frequency band
                                DataBand = process_bandpass('Compute', sInputA.Data, sfreq, BandBounds(iBand,1), BandBounds(iBand,2), 'bst-hfilter-2019', OPTIONS.isMirror);
                                % Analytic signals (original + i * Hilbert transform)
                                HA = transpose(hilbert_fcn(transpose(DataBand)));
                                if ~isConnNN
                                    DataBand = process_bandpass('Compute', sInputB.Data, sfreq, BandBounds(iBand,1), BandBounds(iBand,2), 'bst-hfilter-2019', OPTIONS.isMirror);
                                    HB = transpose(hilbert_fcn(transpose(DataBand)));
                                end
                            case 'morlet'
                                % Compute wavelet decompositions
                                % Not sure why, but bst_timefreq removes 0 freq (DC) first, and it does change the result.
                                if iBand == 1
                                    % Remove mean of the signal
                                    sInputA.Data = bst_bsxfun(@minus, sInputA.Data, mean(sInputA.Data,2));
                                end
                                HA = morlet_transform(sInputA.Data, sInputA.Time, OPTIONS.Freqs(iBand), OPTIONS.MorletFc, OPTIONS.MorletFwhmTc, 'n');
                                if ~isConnNN
                                    if iBand == 1
                                        % Remove mean of the signal
                                        sInputB.Data = bst_bsxfun(@minus, sInputB.Data, mean(sInputB.Data,2));
                                    end
                                    HB = morlet_transform(sInputB.Data, sInputB.Time, OPTIONS.Freqs(iBand), OPTIONS.MorletFc, OPTIONS.MorletFwhmTc, 'n');
                                end
                        end
                        % Apply kernel if needed
                        if ~isConnNN && ~isempty(sInputB.ImagingKernel)
                            HB = sInputB.ImagingKernel * HB;
                        end
                        % PLV: Normalize first, keep only phase info.
                        if ismember(OPTIONS.Method, {'plv', 'ciplv'})
                            HA = HA ./ abs(HA);
                            if ~isConnNN
                                HB = HB ./ abs(HB);
                            end
                        end
                        % Compute "instantaneous cross-spectrum" first, keeping time.
                        if ismember(OPTIONS.TimeRes, {'full', 'windowed'}) || ismember(OPTIONS.Method, {'pli', 'wpli', 'dwpli'})
                            if isConnNN
                                Sab = bsxfun(@times, permute(HA, [1, 3, 2]), conj(permute(HA, [3, 1, 2])));
                            else
                                Sab = bsxfun(@times, permute(HA, [1, 3, 2]), conj(permute(HB, [3, 1, 2])));
                            end
                        else % no time and {'plv', 'ciplv', 'cohere'}
                            % More efficient to get time-averaged Sab directly in these cases.
                            if isConnNN
                                Sab = HA * HA' / nTime; % ' is conjugate transpose
                            else
                                Sab = HA * HB' / nTime; % ' is conjugate transpose
                            end
                        end
                        switch OPTIONS.Method
                            case {'plv', 'ciplv', 'cohere'}
                                R.Sab(:,:,:,iBand) = R.Sab(:,:,:,iBand) + TimeAvgFunc(Sab, 3); % only term that's still complex
                                if strcmpi(OPTIONS.Method, 'cohere')
                                    R.Saa(:,:,iBand) = R.Saa(:,:,iBand) + TimeAvgFunc(abs(HA).^2, 2);
                                    if ~isConnNN
                                        R.Sbb(:,:,iBand) = R.Sbb(:,:,iBand) + TimeAvgFunc(abs(HB).^2, 2);
                                    end
                                end
                            case 'pli'
                                R.SgnImSab(:,:,:,iBand) = R.SgnImSab(:,:,:,iBand) + TimeAvgFunc(sign(imag(Sab)), 3);
                            case 'wpli'
                                R.ImSab(:,:,:,iBand) = R.ImSab(:,:,:,iBand) + TimeAvgFunc(imag(Sab), 3);
                                R.AbsImSab(:,:,:,iBand) = R.AbsImSab(:,:,:,iBand) + TimeAvgFunc(abs(imag(Sab)), 3);
                            case 'dwpli'
                                R.ImSab(:,:,:,iBand) = R.ImSab(:,:,:,iBand) + TimeAvgFunc(imag(Sab), 3);
                                R.AbsImSab(:,:,:,iBand) = R.AbsImSab(:,:,:,iBand) + TimeAvgFunc(abs(imag(Sab)), 3);
                                R.SqImSab(:,:,:,iBand) = R.SqImSab(:,:,:,iBand) + TimeAvgFunc(imag(Sab).^2, 3);
                        end
                    end
                    % If time-averaged, already divided by nTime.
                    nWin = nWin + 1;

                case 'stft'
                    % "Spectral" formulae, using Fourier transform in windows (short-time Fourier transform)
                    % There could be files from different runs and different kernels, so must apply kernel here (in bst_xspectrum).
                    % Non-linear functions of cross-spectrum also require the kernel to be applied first.

                    % Request time-resolved output from bst_xspectrum for OPTIONS.TimeRes = full or windowed
                    TimeRes = 1;
                    if strcmpi(OPTIONS.TimeRes, 'none')
                        TimeRes = 0;
                    end
                    if isConnNN
                        % Avoid passing redundant data
                        [S, nWinFile, OPTIONS.Freqs, Time, Messages] = bst_xspectrum(sInputA.Data, [], ...
                            sfreq, OPTIONS.StftWinLen, OPTIONS.StftWinOvr, OPTIONS.MaxFreq, sInputB.ImagingKernel, OPTIONS.Method, TimeRes);
                    else
                        [S, nWinFile, OPTIONS.Freqs, Time, Messages] = bst_xspectrum(sInputA.Data, sInputB.Data, ...
                            sfreq, OPTIONS.StftWinLen, OPTIONS.StftWinOvr, OPTIONS.MaxFreq, sInputB.ImagingKernel, OPTIONS.Method, TimeRes);
                    end
                    % Error processing
                    if isempty(S)
                        bst_report('Error', OPTIONS.ProcessName, unique({FilesA{iFile}, FilesB{iFile}}), Messages);
                        return;
                    elseif ~isempty(Messages)
                        bst_report('Warning', OPTIONS.ProcessName, unique({FilesA{iFile}, FilesB{iFile}}), Messages);
                    end
                    % Average S terms (Sab, Saa, AbsImSab, etc) across windows
                    Terms = fieldnames(S);
                    if strcmp(OPTIONS.TimeRes, 'windowed')
                        % Adjust window length and overlap to number of STFT windows
                        nWinLenAvg = floor(nWinLenSamples ./ round(OPTIONS.StftWinLen * sfreq));
                        nWinOvrAvg = floor(OPTIONS.WinOverlap * nWinLenAvg);
                        [~, ixs] = bst_epoching(Time, nWinLenAvg, nWinOvrAvg);
                        Time = reshape(mean(Time(ixs),2), 1, []);
                        for f = 1:numel(Terms)
                            % Windows are the second-to-last dimension
                            dim = length(size(S.(Terms{f})))-1;
                            S.(Terms{f}) = bst_epoching(S.(Terms{f}), nWinLenAvg, nWinOvrAvg, dim, 1);
                        end
                        % Add the number of averaged windows & files to the report
                        nWinLenSamples = nWinLenAvg;
                    elseif strcmp(OPTIONS.TimeRes, 'none')
                        % Add time dimension
                       for f = 1:numel(Terms)
                            % Insert a singleton second-to-last dimension
                            order = 1 : (length(size(S.(Terms{f}))) + 1);
                            newOrder = [order(1:end-2), order(end:-1:end-1)];
                            S.(Terms{f}) = permute(S.(Terms{f}), newOrder);
                       end
                    end
                    % Initial R or Accumulate R
                    if isempty(R) || strcmpi(OPTIONS.OutputMode, 'input')
                        % Initialize accumulators
                        for f = 1:numel(Terms)
                            R.(Terms{f}) = S.(Terms{f});
                        end
                        nWin = 0;
                        % Add the number of averaged windows & files to the report (only once per output file)
                        switch OPTIONS.TimeRes
                            case 'full'
                                nAvgLen = 1;
                            case 'windowed'
                                nAvgLen = nWinLenAvg;
                            case 'none'
                                nAvgLen = nWinFile;
                        end
                        Message = sprintf('Estimating across %d windows of %d samples each', nAvgLen, round(OPTIONS.StftWinLen * sfreq));
                        if ~strcmpi(OPTIONS.OutputMode, 'input') && nFiles > 1
                            Message = [Message sprintf(' per file, across %d files', nFiles)];
                        end
                        if ~isempty(Time)
                            Message = [Message ', for each output time point'];
                        end
                        bst_report('Info', OPTIONS.ProcessName, unique({FilesA{iFile}, FilesB{iFile}}), Message);
                    else
                        % Sum terms
                        for f = 1:numel(Terms)
                            R.(Terms{f}) = R.(Terms{f}) + S.(Terms{f});
                        end
                    end
                    % If averaging over consecutive stft windows (TimeRes = 'windowed'), already divided by nWinFile.
                    nWin = nWin + 1;
            end % tfmeasure switch

        % ==== PTE ====
        case 'pte'
            DisplayUnits = 'Phase transfer entropy';
            bst_progress('text', sprintf('Calculating: PTE [%dx%d]...', nA, nB));
            Comment = 'PTE';
            if OPTIONS.isNormalized
                Comment = [Comment, ' [Normalized]']; %#ok<*AGROW> 
            end
            % Intitialize returned matrix
            R = zeros(nA, nB, 1, nFreqBands);
            % Loop on each frequency band
            for iBand = 1:nFreqBands
                % Band-pass filter in one frequency band
                DataAband = process_bandpass('Compute', sInputA.Data, sfreq, BandBounds(iBand,1), BandBounds(iBand,2), 'bst-hfilter-2019', OPTIONS.isMirror);
                % Compute PTE
                [dPTE, PTE] = PhaseTE_MF(permute(DataAband, [2 1]));
                if OPTIONS.isNormalized
                    R(:,:,1,iBand) = dPTE;
                else
                    R(:,:,1,iBand) = PTE;
                end
            end
            
        % ==== henv ====
        case 'henv'
            switch OPTIONS.CohMeasure
                case 'coh'
                    DisplayUnits = 'Coherence';
                    Comment = 'Coh';
                case 'msc'
                    DisplayUnits = 'Magnitude-squared coherence';
                    Comment = 'MSCoh';
                case 'lcoh'
                    DisplayUnits = 'Lagged coherence';
                    Comment = 'LagCoh';
                case 'penv'
                    DisplayUnits = 'Envelope correlation';
                    Comment = 'EnvCorr';
                case 'oenv'
                    DisplayUnits = 'Orthogonalized envelope correlation';
                    Comment = 'OEnvCorr';
            end
            bst_progress('text', sprintf('Calculating: %s [%dx%d]...',OPTIONS.CohMeasure, nA, nB));
            % Warning when using the split option
            if (OPTIONS.tfSplit > 1)
                bst_report('Warning', OPTIONS.ProcessName, [], ['Using the option "Split large data" should be avoided until fixed.' 10 'See: https://neuroimage.usc.edu/forums/t/37624']);
            end
            % Process options
            OPTIONS.SampleRate = sfreq;
            % Compute envelope correlation
            [R, timeSamples, Nwin] = bst_henv(sInputA.Data, sInputB.Data, sInputA.Time, OPTIONS);
            % Output file time
            Time = timeSamples + sInputB.Time(1);
            % File comment
            Comment = [Comment '-' OPTIONS.tfMeasure];
            if ismember(OPTIONS.TimeRes, {'full', 'windowed'}) && numel(Time) > 1
                Comment = [Comment '-time'];
            end
            % Add the number of averaged samples & files to the report (only once per output file)
            if strcmpi(OPTIONS.TimeRes, 'none')
                Message = sprintf('Estimating across %d time samples', nTime); % samples are not independent due to bandpass filter
            else % 'windowed'
                Message = sprintf('Estimating across %d time samples', round(OPTIONS.WinLen * sfreq)); % samples are not independent due to bandpass filter
            end
            if ~strcmpi(OPTIONS.OutputMode, 'input') && nFiles > 1
                Message = [Message sprintf(' per file, across %d files', nFiles)];
            end
            if numel(Time) > 1
                Message = [Message ', for each output time point'];
            end
            bst_report('Info', OPTIONS.ProcessName, unique({FilesA{iFile}, FilesB{iFile}}), Message);
                    
        otherwise
            bst_report('Error', OPTIONS.ProcessName, [], ['Invalid method "' OPTIONS.Method '".']);
            CleanExit; return;
    end
    % Replace any NaN values with zeros
    if isnumeric(R)
        R(isnan(R)) = 0;
        R(isinf(R)) = 0;
    end
    
    
    %% ===== FINALIZE OR ACCUMULATE =====
    if strcmpi(OPTIONS.OutputMode, 'input')
        % History: keep datafile history (if not averaging)
        OutHist = struct;
        DataFile = file_resolve_link(FilesB{iFile});
        % Load file
        warning off MATLAB:load:variableNotFound
        DataHist = load(DataFile, 'History');
        warning on MATLAB:load:variableNotFound
        if ~isempty(DataHist)
            DataHist = CleanHist(DataHist);
            OutHist = bst_history('add', OutHist, 'src', 'Connectivity: input file history:');
            OutHist = bst_history('add', OutHist, DataHist.History, ' - ');
        end
        OutputFiles{iFile} = Finalize(OrigFilesB{iFile});
        R = [];
    elseif strcmpi(OPTIONS.OutputMode, 'avg')
        % Sum terms and continue file loop.
        if isnumeric(R)
            if isempty(Ravg)
                Ravg = R ./ nFiles;
            elseif ~isequal(size(Ravg), size(R))
                bst_report('Error', OPTIONS.ProcessName, [], 'Input files have different size dimensions or different lists of bad channels.');
                return;
            else
                Ravg = Ravg + R ./ nFiles;
            end
        % Else R is a struct and terms are already being summed into its fields directly.
        end
    else % case 'concat'
        Ravg = R;
    end
end

if ~strcmpi(OPTIONS.OutputMode, 'input')
    if isnumeric(R) && ~isempty(Ravg)
        R = Ravg;
    end
    OutputFiles{1} = Finalize;
end

catch ME
    CleanExit;
    rethrow(ME);
end

%% ===== DELETE TEMP PCA FILES =====
CleanExit;


%% ========================================================================
%  ===== SUPPORT SUB-FUNCTIONS ============================================
%  ========================================================================

%% ===== DELETE TEMP PCA FILES before exiting =====
function CleanExit
    % Delete temp PCA files.
    if ~isempty(sInputToDel)
        process_extract_scout('DeleteTempResultFiles', OPTIONS.ProcessName, sInputToDel);
    end
end


%% ===== ASSEMBLE CONNECTIVITY METRIC FROM ACCUMULATED TERMS =====
function NewFile = Finalize(DataFile)
    if nargin < 1
        DataFile = [];
    end
    if isstruct(R)
        switch OPTIONS.Method
            case 'plv'
                R = R.Sab / nWin;
            case 'ciplv'
                R = imag(R.Sab) ./ sqrt(nWin^2 - real(R.Sab).^2 + eps); % eps in case /sqrt(1-1)
            case 'wpli'
                % Original definition, but without overall abs()
                % (Factors of 1/nWin (for averaging) cancel between numerator and denominator.)
                R = R.ImSab ./ R.AbsImSab; 
            case 'dwpli'
                % Debiased square definition
                % (Factors of 1/nWin (for averaging) also cancel with extra nWin factors in the dwPLI formula.)
                R = (R.ImSab.^2 - R.SqImSab) ./ (R.AbsImSab.^2 - R.SqImSab);
            case 'pli'
                R = R.SgnImSab / nWin;
            case 'cohere'
                % Reshape Saa as [nA, 1, nFreq] or [nA, 1, nTime, nFreq], and Sbb as [1, nB, ...] for C denominator.
                % Still complex at this step, keep in R.Sab.
                if isConnNN
                    R.Sab = bst_bsxfun(@rdivide, R.Sab, sqrt(bst_bsxfun(@times, permute(R.Saa, [1,4,2,3]), permute(R.Saa, [4,1,2,3]))));
                else
                    R.Sab = bst_bsxfun(@rdivide, R.Sab, sqrt(bst_bsxfun(@times, permute(R.Saa, [1,4,2,3]), permute(R.Sbb, [4,1,2,3]))));
                end
                % All these measures give real positive values.
                switch OPTIONS.CohMeasure
                    case 'mscohere'
                        % Magnitude-squared Coherence
                        % MSC = |C|^2 = C .* conj(C) = |Sxy|^2/(Sxx*Syy)
                        R = abs(R.Sab).^2;
                    case {'icohere2019'}
                        % Imaginary Coherence (2019)
                        % IC = Im(C) = Im(Sxy)/sqrt(Sxx*Syy)
                        R = abs(imag(R.Sab));
                    case 'lcohere2019'
                        % Lagged Coherence (2019)
                        % LC = Im(C)/sqrt(1-[Re(C)]^2) = Im(Sxy)/sqrt(Sxx*Syy - [Re(Sxy)]^2)
                        R = abs(imag(R.Sab)) ./ sqrt(1-real(R.Sab).^2);
                        % For diagonal elements (self-connectivity), R = 0/0. Replace by 0.
                        R(isnan(R(:))) = 0;
                    case 'icohere'
                        % "Imaginary Coherence" (before 2019) = actually squared lagged coherence.
                        % (LC)^2 = Im(C)^2 / (1-Re(C)^2)
                        R = imag(R.Sab).^2 ./ (1-real(R.Sab).^2);
                        R(isnan(R(:))) = 0;
                end
        end
    end

    %% ===== APPLY FINAL MEASURE =====
    if (ismember(OPTIONS.Method, {'plv','ciplv','wpli','dwpli','pli'}) && strcmpi(OPTIONS.PlvMeasure, 'magnitude')) || ...
            ismember(OPTIONS.Method, {'cohere'})
        R = abs(R);
    end

    %% ===== PROCESS UNCONSTRAINED SOURCES: MAX =====
    % R matrix is: [nA x nB x nTime x nFreq]
    if isUnconstrA || isUnconstrB
        % If there are negative values: take the value with maximum magnitude
        if ~isreal(R) || any(R(:) < 0)
            UnconstrFunc = 'absmax';
        % If all the values are positive: use Matlab's max()
        else
            UnconstrFunc = 'max';
        end
        % Dimension #1
        if isUnconstrA
            [R, sInputA.GridAtlas, sInputA.RowNames] = bst_source_orient([], sInputA.nComponents, sInputA.GridAtlas, R, UnconstrFunc, sInputA.DataType, sInputA.RowNames);
        end
        % Dimension #2
        if isUnconstrB
            R = permute(R, [2 1 3 4]);
            [R, sInputB.GridAtlas, sInputB.RowNames] = bst_source_orient([], sInputB.nComponents, sInputB.GridAtlas, R, UnconstrFunc, sInputB.DataType, sInputB.RowNames);
            R = permute(R, [2 1 3 4]);
        end
    end

    %% ===== PROCESS SCOUTS =====
    % TODO: Currently done in SaveFile with special external function, but would make sense to do here with the
    % same 2-step permutation approach as for unconstrained sources, possibly calling bst_scout_value if it's extended
    % to work with arrays with more dimensions. Also would likely have better performance (no loop over all frequencies and times).
    
    %% ===== SAVE FILE =====
    % Comment: add source x target or input
    Comment = [Comment ': '];
    % 1xN and AxB
    if ~isConnNN
        % Seed(s) (scout)
        if OPTIONS.isScoutA
            if (length(OPTIONS.sScoutsA) == 1)
                Comment = [Comment, OPTIONS.sScoutsA.Label];
            else
                Comment = [Comment, num2str(length(OPTIONS.sScoutsA))];
            end
        % Seed (sensor or row)
        elseif (length(sInputA.RowNames) == 1)
            if iscell(sInputA.RowNames)
                Comment = [Comment, sInputA.RowNames{1}];
            else
                Comment = [Comment, '#', num2str(sInputA.RowNames(1))];
            end
        end
        % Number of target (scouts)
        if OPTIONS.isScoutB
            Comment = [Comment, ' x ' num2str(length(OPTIONS.sScoutsB)), ' scouts'];
        end
        % Add scout function and time if they are relevant
        if ~strcmpi(OPTIONS.ScoutFunc, 'All') && (OPTIONS.isScoutA || OPTIONS.isScoutB)
             Comment = [Comment, ', ',  OPTIONS.ScoutFunc, ' ', OPTIONS.ScoutTime];
        end
    %NxN
    else
        Comment = [Comment, sInputA.Comment];
    end

    % For now, nAvg is kept for methods where the final values are averages: averaging is done after full connectivity, including e.g. abs. 
    % The methods listed here were not (yet) modified with the 2023 file averaging changes.
    if strcmpi(OPTIONS.OutputMode, 'avg') && ismember(OPTIONS.Method, {'corr', 'granger', 'spgranger', 'aec', 'pte', 'henv'})
        nAvg = nFiles;
    else
        nAvg = 1;
    end

    % Comment: append (n files, n win|samp) when computing/averaging across files and/or time
    AvgComment = '';
    if ~strcmpi(OPTIONS.OutputMode, 'input') && nFiles > 1
        AvgComment = [AvgComment sprintf('%d files', nFiles)];
    end
    if ~isempty(nWinLenSamples) && nWinLenSamples > 1
        if ~isempty(AvgComment)
            AvgComment = [AvgComment ','];
        end
        if strcmpi(OPTIONS.tfMeasure, 'stft')
            AvgComment = [AvgComment sprintf('%d win', nWinLenSamples)];
        else
            AvgComment = [AvgComment sprintf('%d samp', nWinLenSamples)];
        end
    end
    if ~isempty(AvgComment)
        % Remove previous parentheses
        [~, tmpStrs] = regexp(Comment,'\(#.+\)','match','split');
        Comment = deblank([tmpStrs{:}]);
        % Still add "Avg:" for some methods (those where averaging not yet modified 2023)
        if nAvg > 1 
            Comment = ['Avg: ' Comment];
        end
        % Add new parentheses
        Comment = [Comment ' (' AvgComment ')'];
    end

    NewFile = [];
    bst_progress('text', 'Saving results...');

    % ===== PREPARE OUTPUT STRUCTURE =====
    % Create file structure
    FileMat = db_template('timefreqmat');
    FileMat.Atlas = db_template('atlas');
    FileMat.Atlas.Name = '';
    % Reshape: [nA x nB x nTime x nFreq] => [nA*nB x nTime x nFreq]
    FileMat.TF           = reshape(R, [], size(R,3), size(R,4));
    FileMat.DisplayUnits = DisplayUnits;
    FileMat.Comment      = Comment;
    FileMat.DataType     = sInputB.DataType;
    FileMat.Freqs        = OPTIONS.Freqs;
    FileMat.Method       = OPTIONS.Method;
    FileMat.DataFile     = file_win2unix(DataFile);
    FileMat.nAvg         = nAvg;
    % Head model
    if isfield(sInputA, 'HeadModelFile') && ~isempty(sInputA.HeadModelFile)
        FileMat.HeadModelFile = sInputA.HeadModelFile;
        FileMat.HeadModelType = sInputA.HeadModelType;
    elseif isfield(sInputB, 'HeadModelFile') && ~isempty(sInputB.HeadModelFile)
        FileMat.HeadModelFile = sInputB.HeadModelFile;
        FileMat.HeadModelType = sInputB.HeadModelType;
    end
    % Time vector
    if ~isempty(OPTIONS.TimeRes) && ismember(OPTIONS.TimeRes, {'full', 'windowed'}) && ~isempty(Time)
        FileMat.Time      = Time;
        FileMat.TimeBands = [];
    else
        FileMat.Time      = sInputB.Time([1,end]);
        FileMat.TimeBands = {OPTIONS.Method, sInputB.Time(1), sInputB.Time(end)};
    end
    % Measure
    FileMat.Measure = 'other';
    % Row names: NxM
    FileMat.RefRowNames = sInputA.RowNames;
    FileMat.RowNames    = sInputB.RowNames;
    % Atlas: save A in first index
    if ~isempty(sInputA.Atlas)
        FileMat.Atlas(1) = sInputA.Atlas(1);
    end
    % Atlas: save B in second index if it is not NxN
    if ~isempty(sInputB.Atlas) && ~isConnNN
        FileMat.Atlas(2) = sInputB.Atlas(1);
    end
    % Surface & grid: save from B, otherwise if missing, save from A.
    if ~isempty(sInputB.SurfaceFile)
        FileMat.SurfaceFile = sInputB.SurfaceFile;
    elseif ~isempty(sInputA.SurfaceFile)
        FileMat.SurfaceFile = sInputA.SurfaceFile;
    end
    if ~isempty(sInputB.GridLoc)
        FileMat.GridLoc = sInputB.GridLoc;
    elseif ~isempty(sInputA.GridLoc)
        FileMat.GridLoc = sInputA.GridLoc;
    end
    if ~isempty(sInputB.GridAtlas)
        FileMat.GridAtlas = sInputB.GridAtlas;
    elseif ~isempty(sInputA.GridAtlas)
        FileMat.GridAtlas = sInputA.GridAtlas;
    end
    % History
    % If using temp files for flattening or scout PCA, this is the only place the % kept variance
    % message and PCA input file list will be saved.
    if ~isempty(OutHist)
        FileMat = bst_history('add', FileMat, OutHist.History);
    end
    % History: Computation
    FileMat = bst_history('add', FileMat, 'compute', ['Connectivity measure: ', OPTIONS.Method, ' (see the field "Options" for input parameters)']);

    % Save options structure
    FileMat.Options = OPTIONS;

    % ===== PROCESS SCOUTS =====
    % Process scouts: call aggregating function
    if (OPTIONS.isScoutA || OPTIONS.isScoutB) && strcmpi(OPTIONS.ScoutTime, 'after') && ~strcmpi(OPTIONS.ScoutFunc, 'all')
        FileMat = process_average_rows('ProcessConnectScouts', FileMat, OPTIONS.ScoutFunc, OPTIONS.sScoutsA, OPTIONS.sScoutsB);
    end
    
    % ===== OPTIMIZE STORAGE FOR SYMMETRIC MATRIX =====
    % Keep only the values below the diagonal
    if FileMat.Options.isSymmetric && (size(FileMat.TF,1) == length(FileMat.RowNames)^2)
        FileMat.TF = process_compress_sym('Compress', FileMat.TF);
    end
        
    % ===== SAVE FILE =====
    if OPTIONS.isSave
        % Get output study
        if ~isempty(OPTIONS.iOutputStudy)
            iOutputStudy = OPTIONS.iOutputStudy;
        else  % OutputType = 'input'
            iOutputStudy = sInputB.iStudy;
        end
        sOutputStudy = bst_get('Study', iOutputStudy);
        % File tag
        if (length(FileMat.RefRowNames) == 1)
            fileTag = 'connect1';
        else
            fileTag = 'connectn';
        end
        % Output filename
        NewFile = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), ['timefreq_' fileTag '_' OPTIONS.Method]);
        % Save file
        bst_save(NewFile, FileMat, 'v6');
        % Add file to database structure
        db_add_data(iOutputStudy, NewFile, FileMat);
    else
        NewFile = FileMat;
    end
end % Finalize() sub-function
end % main


%% ===== LOAD ALL INPUTS =====
function [sConcat, sAverage] = LoadAll(FileNames, Target, TimeWindow, LoadOptions, isConcat, isAverage, startValue)
    sConcat = [];
    sAverage = [];
    for iFile = 1:length(FileNames)
        % Load file
        bst_progress('set',  round(startValue + (iFile-1) / length(FileNames) * 100));
        sTmp = bst_process('LoadInputFile', FileNames{iFile}, Target, TimeWindow, LoadOptions);
        if isempty(sTmp.Data)
            return;
        end
        % Concatenate with previous file (old coherence)
        if (isConcat == 1)
            if isempty(sConcat)
                sConcat = sTmp;
            elseif ~isequal(size(sConcat.Data,1), size(sTmp.Data,1))
                sAverage = [];
                sConcat = [];
                return;
            else
                sConcat.Data = [sConcat.Data, sTmp.Data];
                sConcat.Time = [sConcat.Time, sTmp.Time + sTmp.Time(2) - 2*sTmp.Time(1) + sConcat.Time(end)];
            end
        % Load a cell array (coherence 2021)
        elseif (isConcat == 2)
            if isempty(sConcat)
                sConcat = sTmp;
                sConcat.Data = {sConcat.Data};
            else
                sConcat.Data{end+1} = sTmp.Data;
                sConcat.Time = [sConcat.Time, sTmp.Time + sTmp.Time(2) - 2*sTmp.Time(1) + sConcat.Time(end)];
            end
        end
        % Average with previous files
        if isAverage
            if isempty(sAverage)
                sAverage = sTmp;
                sAverage.Data = sAverage.Data ./ length(FileNames);
            else
                if ~isequal(size(sAverage.Data), size(sTmp.Data))
                    sAverage = [];
                    sConcat = [];
                    return;
                end
                sAverage.Data = sAverage.Data + sTmp.Data ./ length(FileNames);
            end
        end
    end
    % Remove average from concatenated files
    if (isConcat >= 1) && isAverage
        for iFile = 1:length(FileNames)
            if (isConcat == 1)
                iSmp = [1, size(sAverage.Data,2)] + (iFile-1) * size(sAverage.Data,2);
                sConcat.Data(:,iSmp(1):iSmp(2)) = sConcat.Data(:,iSmp(1):iSmp(2)) - sAverage.Data;
            elseif (isConcat == 2)
                sConcat.Data{iFile} = sConcat.Data{iFile} - sAverage.Data;
            end
        end
    end
end

% For deprecated AEC
function R = correlate_dims(A, B, dim)
    A = bsxfun( @minus, A, mean( A, dim) );
    B = bsxfun( @minus, B, mean( B, dim) );
    A = normr(A);
    B = normr(B);
    R = sum(bsxfun(@times, A, B), dim);
end
function x = normr(x)
    n = sqrt(sum(x.^2,2));
    x(n~=0,:) = bsxfun(@rdivide, x(n~=0,:), n(n~=0));
    x(n==0,:) = 1 ./ sqrt(size(x,2));
end

function Hist = CleanHist(Hist)
    % Copy the history of the first file (but remove the entries "import_epoch" and "import_time")
    if ~isempty(Hist.History)
        % Remove entry 'import_epoch'
        iLineEpoch = find(strcmpi(Hist.History(:,2), 'import_epoch'));
        if ~isempty(iLineEpoch)
            Hist.History(iLineEpoch,:) = [];
        end
        % Remove entry 'import_time'
        iLineTime  = find(strcmpi(Hist.History(:,2), 'import_time'));
        if ~isempty(iLineTime)
            Hist.History(iLineTime,:) = [];
        end
    end
end

function Files = GetFileNames(Files)
    if ~isempty(Files)
        if isstruct(Files)
            Files = {Files.FileName};
        elseif ischar(Files)
            Files = {Files};
        end
    end
end
