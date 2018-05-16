function varargout = process_zscore_dynamic( varargin )
% PROCESS_ZSCORE_DYNAMIC: Prepares a file for dynamic display of the zscore (load-time)
%
% DESCRIPTION:  For each channel:
%     1) Compute mean m and variance v for baseline
%     2) For each time sample, subtract m and divide by v
                        
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Z-score normalization [DEPRECATED]';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 411;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SourceEstimation#Z-score';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % Definition of the options
    sProcess.options.description.Comment = ['For each signal in input:<BR>' ...
                                            '1) Compute mean <I>m</I> and variance <I>v</I> for the baseline<BR>' ...
                                            '2) For each time sample, subtract <I>m</I> and divide by <I>v</I><BR>' ...
                                            'Z = (Data - <I>m</I>) / <I>v</I><BR><BR>'];
    sProcess.options.description.Type    = 'label';
    % === Baseline time window
    sProcess.options.baseline.Comment = 'Baseline:';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    % === Absolute values for sources
    sProcess.options.source_abs.Comment = ['<B>Use absolute values of source activations</B><BR>' ...
                                           'or the norm of the three orientations for unconstrained maps.'];
    sProcess.options.source_abs.Type    = 'checkbox';
    sProcess.options.source_abs.Value   = 0;
    sProcess.options.source_abs.InputTypes = {'results'};
    % === Dynamic Z-score
    sProcess.options.dynamic.Comment    = ['<B>Dynamic</B>: The standardized values are not saved to the file,<BR>' ...
                                           'they are computed on the fly when the file is loaded.<BR>' ...
                                           'Only available for constrained source models.'];
    sProcess.options.dynamic.Type       = 'checkbox';
    sProcess.options.dynamic.Value      = 0;
    sProcess.options.dynamic.InputTypes = {'results'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    % Get time window
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        Time = sProcess.options.baseline.Value{1};
    else
        Time = [];
    end
    % Add time window to the comment
    if isempty(Time)
        Comment = 'Z-score normalization: [All file]';
    elseif any(abs(Time) > 2)
        Comment = sprintf('Z-score normalization: [%1.3fs,%1.3fs]', Time(1), Time(2));
    else
        Comment = sprintf('Z-score normalization: [%dms,%dms]', round(Time(1)*1000), round(Time(2)*1000));
    end
end


%% ===== RUN =====
% USAGE:  OutputFile = process_zscore_dynamic('Run', sProcess, sInput)
%         OutputFile = process_zscore_dynamic('Run', sProcess, sInputBaseline, sInput)
function OutputFile = Run(sProcess, sInputBaseline, sInput) %#ok<DEFNU>   
    disp('BST> process_zscore_dynamic.m is deprecated, use "Standardize > Baseline normalization" instead.');
    % ===== OPTIONS =====
    % Initialize output file list
    OutputFile = [];
    processOptions = {};
    % Parse inputs
    if (nargin < 3) || isempty(sInput)
        sInput = sInputBaseline;
        isBinaryInput = 0;
    else
        isBinaryInput = 1;
    end
    % Get options
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        ZScore.baseline = sProcess.options.baseline.Value{1};
        processOptions = cat(2, processOptions, {'baseline', sProcess.options.baseline.Value{1}});
    else
        ZScore.baseline = [];
    end
    if isfield(sProcess.options, 'sensortypes') && ~isempty(sProcess.options.sensortypes)
        SensorsTypes = sProcess.options.sensortypes.Value;
        processOptions = cat(2, processOptions, {'sensortypes', sProcess.options.sensortypes.Value});
    else
        SensorsTypes = [];
    end
    % Check file types
    if ~strcmpi(sInputBaseline.FileType, sInput.FileType)
        bst_report('Error', sProcess, sInputBaseline, 'Files in sets A and B must be of the same type.');
        return;
    end
    % Load kernel-based results as FULL sources
    OPTIONS.ProcessName = func2str(sProcess.Function);
    OPTIONS.LoadFull = 1;
    % Absolute values
    isAbsolute = isfield(sProcess.options, 'source_abs') && isfield(sProcess.options.source_abs, 'Value') && ~isempty(sProcess.options.source_abs.Value) && sProcess.options.source_abs.Value;
    processOptions = cat(2, processOptions, {'source_abs', isAbsolute});
    % Report the option for following processes (static or dynamic Z-score)
    ZScore.abs = isAbsolute;
    % Dynamic Z-score
    isDynamic = isfield(sProcess.options, 'dynamic') && isfield(sProcess.options.dynamic, 'Value') && ~isempty(sProcess.options.dynamic.Value) && sProcess.options.dynamic.Value;

    % ===== ABSOLUTE + UNCONSTRAINED + DYNAMIC: IMPOSSIBLE =====
    % Absolute values
    if isAbsolute && strcmpi(sInputBaseline.FileType, 'results')
        % Load just the number of components from the first results file
        ResMat = in_bst_results(sInput.FileName, 0, 'nComponents');
        % Non-constrained sources: impossible
        if (ResMat.nComponents ~= 1)
            isDynamic = 0;
            bst_report('Info', sProcess, [], 'Incompatible options for unconstrained sources: norm of three orientations and dynamic Z-score.');
        end
    end
    
    % ===== BRANCH TO STATIC Z-SCORE =====
    % Dynamic or static?   (only useful for kernel-based source files)
    if isempty(strfind(sInput.FileName, '_KERNEL_')) || ~isDynamic
        bst_report('Info', sProcess, [], 'Calling static Z-score process.');
        % If there is no point in calling the dynamic Z-score: call the static one
        if isBinaryInput
            sOutput = bst_process('CallProcess', 'process_zscore_ab', sInputBaseline.FileName, sInput.FileName, processOptions{:});
        else
            sOutput = bst_process('CallProcess', 'process_zscore', sInput.FileName, [], processOptions{:});
        end
        % Return directly from here
        if ~isempty(sOutput)
            OutputFile = {sOutput.FileName};
        end
        return;
    end

    % ===== GET CHANNEL INDICES =====
    % If processing recordings and sensor types is not empty
    if strcmpi(sInput.FileType, 'data') && ~isempty(SensorsTypes)
        % Load channel file
        ChannelMat = in_bst_channel(sInput.ChannelFile);
        % Find selected sensors
        iChannels = channel_find(ChannelMat.Channel, SensorsTypes);
        % Find channels to exclude from the computation
        iRowExclude = setdiff(1:length(ChannelMat.Channel), iChannels);
    else
        iRowExclude = [];
    end

    % ===== LOAD DATA =====
    % Load the baseline
    sData = bst_process('LoadInputFile', sInputBaseline.FileName, [], ZScore.baseline, OPTIONS);
    if isempty(sData) || isempty(sData.Data)
        return;
    end
    % Check for measure
    if ~isreal(sData.Data)
        bst_report('Error', sProcess, sInputBaseline, 'Cannot process complex values. Please apply a measure to the values before calling this function.');
        return;
    end
    
    % ===== COMPUTE MEAN/STD =====
    % If the metrics have to be calculated from absolute values
    if ZScore.abs
        sData.Data = abs(sData.Data);
    end
    % Calculate mean and standard deviation
    [ZScore.mean, ZScore.std] = process_zscore('ComputeStat', sData.Data);
    % Set rows that were not supposed to normalized to m=0 and std=1
    if ~isempty(iRowExclude)
        ZScore.mean(iRowExclude) = 0;
        ZScore.std(iRowExclude)  = 1;
    end

    % ===== OUTPUT STRUCTURE =====
    % Load full original file
    if strcmpi(sInput.FileType, 'results') && strcmpi(sInput.FileName(1:5), 'link|')
        [InputResFile, InputDataFile] = file_resolve_link(sInput.FileName);
        sMat = load(InputResFile);
        sMat.DataFile = file_short(InputDataFile);
    else
        sMat = load(file_fullpath(sInput.FileName));
    end
    % Add the structure zscore + other file modifications
    sMat.ZScore = ZScore;
    % Define default colormap type
    if strcmpi(sInput.FileType, 'results')
        sMat.ColormapType = 'stat1';
    else
        sMat.ColormapType = 'stat2';
    end
    % Data files: set that it is not recordings anymore
    if strcmpi(sInput.FileType, 'data')
        sMat.DataType = 'zscore';
    end
    % Define file tag
    if ZScore.abs
        sMat.Comment = [sMat.Comment ' | abs | zscored'];
        fileTag = '_abs_zscore';
    else
        sMat.Comment = [sMat.Comment ' | zscored'];
        fileTag = '_zscore';
    end
    % Change function in results files
    if strcmpi(sInput.FileType, 'results')
        sMat.Function = 'zscore';
    end
    % Add history entry
    sMat = bst_history('add', sMat, 'process', [func2str(sProcess.Function) ': ' FormatComment(sProcess)]);

    % ===== SAVE FILE =====
    InputFileFull = file_fullpath(sInput.FileName);
    % Get output study and filename
    [sOutputStudy, iOutputStudy] = bst_get('AnyFile', sInput.FileName);
    OutputFileFull = file_unique(strrep(InputFileFull, '.mat', [fileTag '.mat']));
    % Save new file
    bst_save(OutputFileFull, sMat, 'v6');
    % Add file to database structure
    db_add_data(iOutputStudy, OutputFileFull, sMat);
    % Return short filename
    OutputFile = file_short(OutputFileFull);
end


%% ===== COMPUTE DYNAMIC ZSCORE =====
% USAGE:  [Data, ZScore] = process_zscore_dynamic('Compute', Data, ZScore, Time, ImagingKernel, F)    % Estimate ZScore for kernel-based sources
%         [Data, ZScore] = process_zscore_dynamic('Compute', Data, ZScore, Time)
%         [Data, ZScore] = process_zscore_dynamic('Compute', Data, ZScore)
function [Data, ZScore] = Compute(Data, ZScore, Time, ImagingKernel, F) %#ok<DEFNU>
    % Time is optional for some calls
    if (nargin < 5)
        ImagingKernel = [];
        F = [];
    end
    if (nargin < 3)
        Time = [];
    end
    % Error in file structure
    if ~isfield(ZScore, 'mean') || ~isfield(ZScore, 'std') || ~isfield(ZScore, 'abs')
        error('Error in file structure.');
    end
    % Apply absolute value
    if ZScore.abs && ~isempty(Data)
        Data = abs(Data);
    end
    % Calculate mean and std if not available yet
    if isempty(ZScore.mean) || isempty(ZScore.std)
        if isempty(Time)
            error('Operation not supported.');
        end
        % Find baseline indices
        iBaseline = panel_time('GetTimeIndices', Time, ZScore.baseline);
        if isempty(iBaseline)
            bst_report('Error', 'process_zscore_dynamic', [], 'Baseline definition is not valid for this file.');
            Data = [];
            return;
        end
        % Compute from the Data matrix
        if isempty(ImagingKernel)
            [ZScore.mean, ZScore.std] = process_zscore('ComputeStat', Data(:,iBaseline,:));
        elseif ZScore.abs
            [ZScore.mean, ZScore.std] = process_zscore('ComputeStat', abs(ImagingKernel * F(:,iBaseline)));
        else
            [ZScore.mean, ZScore.std] = process_zscore('ComputeStat', ImagingKernel * F(:,iBaseline));
        end
    end
    % Apply Z-score
    if ~isempty(Data)
        Data = bst_bsxfun(@minus,   Data, ZScore.mean);
        Data = bst_bsxfun(@rdivide, Data, ZScore.std);
    end
end


