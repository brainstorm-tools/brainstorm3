function varargout = bst_process( varargin )
% BST_PROCESS: Apply a list of processes to a set of files.
%
% USAGE:          sNewFiles = bst_process('Run', sProcesses, sInputs, sInputs2,  isReport=1)
%               OutputFiles = bst_process('CallProcess', sProcess,    sInputs,   sInputs2,   OPTIONS)
%               OutputFiles = bst_process('CallProcess', sProcess,    FileNames, FileNames2, OPTIONS)
%               OutputFiles = bst_process('CallProcess', ProcessName, sInputs,   sInputs2,   OPTIONS)
%               OutputFiles = bst_process('CallProcess', ProcessName, FileNames, FileNames2, OPTIONS)
%                   sInputs = bst_process('GetInputStruct', FileNames)
% [sStudy, iStudy, Comment] = bst_process('GetOutputStudy', sProcess, sInputs, intraCondName, isCreateCond=1) 
%                   Comment = bst_process('GetStatComment', sProcess, sInputs, sInputs2)
% [sInput, nSignals, iRows] = bst_process('LoadInputFile',  FileName, Target=[], TimeWindow=[], OPTIONS=[LoadFull=1])
%                   OPTIONS = bst_process('LoadInputFile')
%              ScoutsStruct = bst_process('LoadScouts', FileNames, ScoutSel, ScoutFunc, TimeWindow=[])

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
% Authors: Francois Tadel, 2010-2019; Martin Cousineau, 2017

eval(macro_method);
end


%% ===== RUN PROCESSES =====
function [sInputs, sInputs2] = Run(sProcesses, sInputs, sInputs2, isReport)
    % Initializations
    if (nargin < 4) || isempty(isReport)
        isReport = 1;
    end
    if (nargin < 3) || isempty(sInputs2)
        sInputs2 = [];
    end
    % Check if first structure is still correct (indices match filename)
    if ~isempty(sInputs) && isstruct(sInputs) && ~strcmpi(sInputs(1).FileType, 'import')
        sInputsTest = GetInputStruct(sInputs(1).FileName);
        if ~isequal(sInputsTest, sInputs(1))
            disp('BST> bst_process: File indices changed, reloading files list...');
            sInputs = {sInputs.FileName};
            if ~isempty(sInputs2) && isstruct(sInputs2)
                sInputs2 = {sInputs2.FileName};
            end
        end
    end
    % Create inputs structures
    if ischar(sInputs) || iscell(sInputs)
        sInputs = GetInputStruct(sInputs);
    end
    if ischar(sInputs2) || iscell(sInputs2)
        sInputs2 = GetInputStruct(sInputs2);
    end
    StudyToRedraw = {};
    isReload = 0;
    % List all the input files
    if ~isempty(sInputs2)
        sInputAll = {sInputs, sInputs2};
    else
        sInputAll = sInputs;
    end
    % Start a new report session
    if isReport
        bst_report('Start', sInputAll);
    end
    UseProgress = 1;
    % Group some processes together to optimize the pipeline speed
    sProcesses = OptimizePipeline(sProcesses);
    
    % ===== PARALLEL PROCESSING =====
    % Can we apply parallel processing?
    %   - parallel option has to be enabled
    %   - matlabpool function must be available
    %   - process does not modify the time definition (not possible for resampling)
    isParallel = 0;
    hPool = [];
    if (exist('matlabpool', 'file') ~= 0) || (exist('parpool', 'file') ~= 0)
        % Look for a process with a parallel computing option
        for iProc = 1:length(sProcesses)
            opts = sProcesses(iProc).options;
            isParallel = isParallel || (isfield(opts, 'parallel') && ~isempty(opts.parallel) && opts.parallel.Value);
        end
        % Start parallel pool
        if isParallel
            try
                if (bst_get('MatlabVersion') >= 802)
                    hPool = parpool;
                else
                    matlabpool open;
                end
            catch
            end
        end
    end
    
    % ===== APPLY PROCESSES =====
    for iProc = 1:length(sProcesses)
        OutputFiles  = {};
        OutputFiles2 = {};
        % Start a new report session
        if isReport && ~(isfield(sProcesses(iProc).options, 'save') && isfield(sProcesses(iProc).options.save, 'Value') && ~isempty(sProcesses(iProc).options.save.Value) && ~sProcesses(iProc).options.save.Value)
            if ~isempty(sInputs2)
                bst_report('Process', sProcesses(iProc), {sInputs, sInputs2});
            else
                bst_report('Process', sProcesses(iProc), sInputs);
            end
        end
        % Don't update the progress bar
        if isfield(sProcesses(iProc).options, 'progressbar') && isfield(sProcesses(iProc).options.progressbar, 'Value') && isequal(sProcesses(iProc).options.progressbar.Value, 0)
            UseProgress = 0;
        else
            UseProgress = 1;
        end
        % Check the order of the subjects for paired processes
        if sProcesses(iProc).isPaired && (length(sInputs) > 2) && (length(sInputs) == length(sInputs2)) && (length(unique({sInputs.SubjectName})) == length(sInputs)) && ...
                (length(unique({sInputs2.SubjectName})) == length(sInputs2)) && ~isequal({sInputs.SubjectName}, {sInputs2.SubjectName})
            bst_report('Warning', sProcesses(iProc), [], 'The subjects are not in the same order in FilesA and FilesB.');
        end
        % Apply process #iProc
        switch lower(sProcesses(iProc).Category)
            case {'filter', 'filter2'}
                % Make sure that file type is indentical for both sets
                if strcmpi(sProcesses(iProc).Category, 'filter2') && ~isempty(sInputs) && ~isempty(sInputs2) && ~strcmpi(sInputs(1).FileType, sInputs2(1).FileType)
                    bst_report('Error', sProcesses(iProc), [], 'Cannot process inputs from different types.');
                    break;
                end
                % Progress bar
                if UseProgress
                    bst_progress('start', 'Process', ['Running process: ' sProcesses(iProc).Comment '...'], 0, 100 * length(sProcesses) * length(sInputs));
                    bst_progress('set', 100 * (iProc-1) * length(sInputs));
                end
                % Process each input file
                for iInput = 1:length(sInputs)
                    % Capture process crashes
                    try
                        % Apply filter to file
                        if strcmpi(sProcesses(iProc).Category, 'filter')
                            OutputFiles{iInput} = ProcessFilter(sProcesses(iProc), sInputs(iInput));
                        else
                            OutputFiles{iInput} = ProcessFilter2(sProcesses(iProc), sInputs(iInput), sInputs2(iInput));
                        end
                    catch
                        strError = bst_error();
                        if strcmpi(sProcesses(iProc).Category, 'filter')
                            bst_report('Error', sProcesses(iProc), sInputs(iInput), strError);
                        else
                            bst_report('Error', sProcesses(iProc), [sInputs(iInput), sInputs2(iInput)], strError);
                        end
                        continue;
                    end
                    % Increase progress bar
                    if UseProgress
                        bst_progress('set', 100 * ((iProc-1) * length(sInputs) + iInput));
                    end
                end
                
            case {'stat1', 'stat2'}
                % Progress bar
                if UseProgress
                    bst_progress('start', 'Process', ['Running process: ' sProcesses(iProc).Comment '...'], 0, 100 * length(sProcesses));
                    bst_progress('set', 100 * (iProc-1));
                end
                % Capture process crashes
                try
                    OutputFiles = ProcessStat(sProcesses(iProc), sInputs, sInputs2);
                catch
                    strError = bst_error();
                    bst_report('Error', sProcesses(iProc), sInputAll, strError);
                    OutputFiles = {};
                end
                
            case {'file', 'file2'}
                % Progress bar
                if UseProgress
                    bst_progress('start', 'Process', ['Running process: ' sProcesses(iProc).Comment '...'], 0, 100 * length(sProcesses) * length(sInputs));
                    bst_progress('set', 100 * (iProc-1) * length(sInputs));
                end
                % Process each input file
                for iInput = 1:length(sInputs)
                    % Capture process crashes
                    try
                        if strcmpi(sProcesses(iProc).Category, 'file')
                            tmpFiles = sProcesses(iProc).Function('Run', sProcesses(iProc), sInputs(iInput));
                        else
                            tmpFiles = sProcesses(iProc).Function('Run', sProcesses(iProc), sInputs(iInput), sInputs2(iInput));
                        end
                    catch
                        strError = bst_error();
                        if strcmpi(sProcesses(iProc).Category, 'file')
                            bst_report('Error', sProcesses(iProc), sInputs(iInput), strError);
                        else
                            bst_report('Error', sProcesses(iProc), [sInputs(iInput), sInputs2(iInput)], strError);
                        end
                        continue;
                    end
                    % Add new files to the final list of output files
                    if ~isempty(tmpFiles)
                        OutputFiles = [OutputFiles, tmpFiles];
                    end
                    % Increase progress bar
                    if UseProgress
                        bst_progress('set', 100 * ((iProc-1) * length(sInputs) + iInput));
                    end
                end
                
            case {'custom', 'custom2'}
                % Progress bar
                if UseProgress
                    bst_progress('start', 'Process', ['Running process: ' sProcesses(iProc).Comment '...'], 0, 100 * length(sProcesses));
                    bst_progress('set', 100 * (iProc-1));
                end
                % Capture process crashes
                try
                    if strcmpi(sProcesses(iProc).Category, 'custom')
                        if isempty(sInputs2)
                            OutputFiles = sProcesses(iProc).Function('Run', sProcesses(iProc), sInputs);
                        else
                            OutputFiles = sProcesses(iProc).Function('Run', sProcesses(iProc), sInputs, sInputs2);
                        end
                    else
                        [OutputFiles, OutputFiles2] = sProcesses(iProc).Function('Run', sProcesses(iProc), sInputs, sInputs2);
                    end
                catch
                    strError = bst_error();
                    bst_report('Error', sProcesses(iProc), sInputAll, strError);
                    OutputFiles  = {};
                    OutputFiles2 = {};
                end
        end
        % Remove empty filenames
        if iscell(OutputFiles)
            iEmpty = find(cellfun(@isempty, OutputFiles));
            if ~isempty(iEmpty)
                OutputFiles(iEmpty) = [];
            end
        end
        if iscell(OutputFiles2)
            iEmpty = find(cellfun(@isempty, OutputFiles2));
            if ~isempty(iEmpty)
                OutputFiles2(iEmpty) = [];
            end
        end
        % No output: exit the loop
        if isempty(OutputFiles) || isequal(OutputFiles, {[]})
            sInputs = [];
            sInputs2 = [];
            break;
        elseif ~ischar(OutputFiles) && ~iscell(OutputFiles)
            sInputs = OutputFiles;
            sInputs2 = OutputFiles2;
            continue;
        end
        % Import -> import: Do not update the input
        if isequal(OutputFiles, {'import'})
            continue;
        end
        % Get new inputs structures
        sInputs = GetInputStruct(OutputFiles);
        if ~isempty(OutputFiles2)
            sInputs2 = GetInputStruct(OutputFiles2);
        else
            sInputs2 = [];
        end
        % Get all the studies to update
        allStudies = bst_get('Study', unique([sInputs.iStudy]));
        if ~isempty(allStudies)
            StudyToRedraw = cat(2, StudyToRedraw, {allStudies.FileName});
        end
        % Are those studies supposed to be reloaded
        isReload = isReload || (~strcmpi(sProcesses(iProc).Category, 'Filter') && isfield(sProcesses(iProc).options, 'overwrite') && isfield(sProcesses(iProc).options.overwrite, 'Value') && isequal(sProcesses(iProc).options.overwrite.Value, 1));
    end

    % Close matlab parallel pool
    if isParallel
        if (bst_get('MatlabVersion') >= 802) && ~isempty(hPool)
            delete(hPool);
        else
            matlabpool close;
        end        
    end
    
    % ===== UPDATE INTERFACE =====
    % If there are studies to redraw
    if ~isempty(StudyToRedraw)
        StudyToRedraw = unique(StudyToRedraw);
        % Get all the study indices
        iStudyToRedraw = [];
        for i = 1:length(StudyToRedraw)
            [sStudy, iStudy] = bst_get('Study', StudyToRedraw{i});
            iStudyToRedraw = [iStudyToRedraw, iStudy];
        end
        % Full reload
        if isReload
            db_reload_studies(iStudyToRedraw, 1);
        % Simple tree update
        else
            % Update results links in target study
            db_links('Study', iStudyToRedraw);
            % Update tree 
            panel_protocols('UpdateNode', 'Study', iStudyToRedraw);
        end
        % Select first target study as current node
        try
            nodeStudy = panel_protocols('SelectStudyNode', iStudyToRedraw(1));
        catch
            disp('BST> Warning: Could not select the output file in the tree.'); 
            nodeStudy = [];
        end
        % Save database
        db_save();
        drawnow;
        % Select first output file
        if ~isempty(OutputFiles)
            panel_protocols('SelectNode', nodeStudy, OutputFiles{1});
        end
    end
    % Close progress bar (unless the last process does not use the progress bar)
    if UseProgress
        bst_progress('stop');
    end
    % Report processing
    if isReport
        % Save report
        ReportFile = bst_report('Save', sInputs);
        % Open report (errors only)
        bst_report('Open', ReportFile, 0);
    end
end


%% ===== PROCESS: FILTER =====
function OutputFile = ProcessFilter(sProcess, sInput)
    OutputFile = [];
    fileTag = '';

    % ===== SELECT CHANNELS =====
    % Read the channel file
    if ~isempty(sInput.ChannelFile)
        ChannelMat = in_bst_channel(sInput.ChannelFile);
    else
        ChannelMat = [];
    end
    % Specific selection
    if ismember(sInput.FileType, {'data', 'raw'}) && ~isempty(sInput.ChannelFile) && isfield(sProcess.options, 'sensortypes') && ~isempty(sProcess.options.sensortypes)
        % Get channel indices
        iSelRows = channel_find(ChannelMat.Channel, sProcess.options.sensortypes.Value);
        % If no selection: file not processed
        if isempty(iSelRows)
            bst_report('Error', sProcess, sInput, ['Selected sensor types are not available in file "' sInput.FileName '".']);
            return;
        elseif numel(iSelRows) == numel(ChannelMat.Channel) 
            % All selected.
            iSelRows = [];
            AllSensorTypes = [];
        else
            AllSensorTypes = unique({ChannelMat.Channel(iSelRows).Type});
        end
    % All the signals
    else
        iSelRows = [];
        AllSensorTypes = [];
    end
    
    % ===== LOAD FILE =====
    % Raw file: do not load full file
    if strcmpi(sInput.FileType, 'raw')
        isLoadFull = 0;
    else
        isLoadFull = 1;
    end
    % Read input files
    [sMat, matName] = in_bst(sInput.FileName, [], isLoadFull);
    if isfield(sMat, 'Measure')
        sInput.Measure = sMat.Measure;
        % Do not allow complex values
        if ~ismember(func2str(sProcess.Function), {'process_tf_measure', 'process_matlab_eval', 'process_extract_time'}) && ~isreal(sMat.(matName))
            bst_report('Error', sProcess, sInput, 'Cannot process complex values. A measure have to be applied to this data before (power, magnitude, phase...)');
            return;
        end
    else
        sInput.Measure = [];
    end
    % Do not allow Time Bands
    if isfield(sMat, 'TimeBands') && ~isempty(sMat.TimeBands) && ismember(func2str(sProcess.Function), {'process_average_time', 'process_baseline_norm', 'process_extract_time'}) 
        % && isfield(sMat, 'Measure') && ~strcmpi(sMat.Measure, 'other') && ~strcmpi(sMat.Measure, 'plv')
        bst_report('Error', sProcess, sInput, 'Cannot process values averaged by time bands.');
        return;
    end
    % Is this a continuous file?
    isRaw = isstruct(sMat.(matName));

    % Absolute values of sources / norm or unconstrained sources
    isAbsolute = ~isRaw && strcmpi(matName, 'ImageGridAmp') && ((sProcess.isSourceAbsolute >= 1) || isfield(sProcess.options, 'source_abs') && isfield(sProcess.options.source_abs, 'Value') && ~isempty(sProcess.options.source_abs.Value) && sProcess.options.source_abs.Value);
    if isAbsolute
        % Unconstrained sources: Norm of the three orientations
        if isfield(sMat, 'nComponents') && (sMat.nComponents ~= 1)
            sMat = process_source_flat('Compute', sMat, 'rms');
            strTag = 'norm';
        % Constrained sources: Absolute values
        else
            strTag = 'abs';
            sMat.Comment = [sMat.Comment, ' | ', strTag];
        end
        % Enforce absolute values
        sMat.(matName) = abs(sMat.(matName));
        % Add tags
        fileTag = [fileTag, '_', strTag];
    end
    % Get data matrix
    matValues = sMat.(matName);
    % Get std matrix
    if isfield(sMat, 'Std') && ~isempty(sMat.Std)
        stdValues = sMat.Std;
    else
        stdValues = [];
    end
    % Get TFmask matrix
    if isfield(sMat, 'TFmask') && ~isempty(sMat.TFmask)
        TFmask = sMat.TFmask;
    else
        TFmask = [];
    end
    
    % Progress bar comment
    txtProgress = ['Running process: ' sProcess.Comment '...'];
    % Copy channel flag information
    if isfield(sMat, 'ChannelFlag')
        sInput.ChannelFlag = sMat.ChannelFlag;
    end
    % Copy nAvg information
    if isfield(sMat, 'nAvg') && ~isempty(sMat.nAvg)
        sInput.nAvg = sMat.nAvg;
    else
        sInput.nAvg = 1;
    end
    % Copy Leff (effective number of averages)
    if isfield(sMat, 'Leff') && ~isempty(sMat.Leff)
        sInput.Leff = sMat.Leff;
    else
        sInput.Leff = 1;
    end
    % Raw files
    isReadAll = isRaw && isfield(sProcess.options, 'read_all') && isfield(sProcess.options.read_all, 'Value') && isequal(sProcess.options.read_all.Value, 1);
    if isRaw
        sFileIn = matValues;
        clear matValues;
        iEpoch = 1;
        nEpochs = length(sFileIn.epochs);
        % Get size of input data
        nRow = length(sMat.ChannelFlag);
        nCol = length(sMat.Time);
        % Get subject
        sSubject = bst_get('Subject', sInput.SubjectName);
        % ERROR: File does not exist
        if ~file_exist(sFileIn.filename)
            bst_report('Error', sProcess, sInput, [...
                'This file has been moved, deleted, is used by another program,' 10 ...
                'or is on a drive that is currently not connected to your computer.']);
            return;
        end
        % ERROR: Cannot process channel/channel uncompensated CTF files
        if ismember(1,sProcess.processDim) && ~isReadAll && ismember(sFileIn.format, {'CTF','CTF-CONTINUOUS'}) && ...
                (sFileIn.prop.currCtfComp ~= 3) && (isempty(AllSensorTypes) || any(ismember(AllSensorTypes, {'MEG','MEG REF','MEG GRAD','MEG MAG'})))
            bst_report('Error', sProcess, sInput, [...
                'This CTF file was not saved with the 3rd order compensation.' 10 ...
                'To process this file, you have the following options: ' 10 ...
                '  1) Check the option "Process the entire file at once", only if the entire file fits in memory.' 10 ...
                '  2) Run the process "Artifacts > Apply SSP & CTF compensation" first to save a compensated file.']);
            return;
        end
        % ERROR: SSP cannot be applied for channel/channel processing
        if ismember(1,sProcess.processDim) && ~isReadAll && ~isempty(ChannelMat.Projector) && any([ChannelMat.Projector.Status] == 1)
            % Verify if any channels that need to be projected are selected.
            % Build projector matrix
            Projector = process_ssp2('BuildProjector', ChannelMat.Projector, 1);
            % Apply projector
            if ~isempty(Projector)
                % Get bad channels
                iBadChan = find(sMat.ChannelFlag == -1);
                % Remove bad channels from the projector (similar as in process_megreg)
                if ~isempty(iBadChan)
                    Projector(iBadChan,:) = 0;
                    Projector(:,iBadChan) = 0;
                    Projector(iBadChan,iBadChan) = eye(length(iBadChan));
                end
                % Apply projector
                if ~isempty(iSelRows)
                    % Channels that are modified by projector.
                    isProjected = sum(Projector ~= 0, 2) > 1;
                    if any(isProjected(iSelRows))
                        
                        bst_report('Error', sProcess, sInput, [...
                            'This file contains SSP projectors, which require all the channels to be read at the same time.' 10 ...
                            'To process this file, you have the following options: ' 10 ...
                            '  1) Check the option "Process the entire file at once" (possible only if the entire file fits in memory).' 10 ...
                            '  2) Run the process "Artifacts > Apply SSP & CTF compensation" first to save a compensated file.' 10 ...
                            '  3) Delete the SSP from this file, process it, then recalculate the SSP on the new file.']);
                        return;
                    end
                end
            end
        end
        % If there are some projectors that are not saved yet: cannot accept default channel files
        if (sSubject.UseDefaultChannel ~= 0) && ~isempty(ChannelMat.Projector) && any([ChannelMat.Projector.Status] == 1)
            bst_report('Error', sProcess, sInput, [...
                'This process would modify the channel file, it cannot be applied if the subject ' 10 ...
                'uses a shared channel file. To fix this problem, edit the subject and use the option' 10 ...
                '"No, use one channel file per acquisition run (MEG or EEG)".']);
            return;  
        end
        % Prepare import options
        % NOTE: FORCE READING CLEAN DATA (CTF compensators + Previous SSP)
        ImportOptions = db_template('ImportOptions');
        ImportOptions.ImportMode      = 'Time';
        ImportOptions.DisplayMessages = 0;
        if ismember(sFileIn.format, {'CTF','CTF-CONTINUOUS'}) && ...
                (isempty(AllSensorTypes) || any(ismember(AllSensorTypes, {'MEG','MEG REF','MEG GRAD','MEG MAG'})))
            ImportOptions.UseCtfComp  = 1;
        else
            ImportOptions.UseCtfComp  = 0; % otherwise reading raw CTF file without selecting any MEG channels would fail.
        end
        ImportOptions.UseSsp          = 1;
        ImportOptions.RemoveBaseline  = 'no';
        % Force reading of the entire RAW file at once
        if isReadAll
            bst_progress('text', [txtProgress, ' [reading]']);
            FullFileMat = in_fread(sFileIn, ChannelMat, iEpoch, [], [], ImportOptions);
        end
    else
        iEpoch = 1;
        nEpochs = 1;
        % Get size of input data
        [nRow, nCol, nFreq] = size(matValues);
    end
    % If native file with multiple epochs: ERROR
    if isRaw && (nEpochs > 1)
        bst_report('Error', sProcess, sInput, 'Impossible to process native epoched/averaged files. Please import them in database or convert them to continuous.');
        return;
    end
    % Get process tag
    processTag = [];
    if ~isempty(sProcess.FileTag)
        if ischar(sProcess.FileTag)
            processTag = sProcess.FileTag;
        elseif isa(sProcess.FileTag, 'function_handle')
            processTag = sProcess.FileTag(sProcess);
        end
    end
    % Build output file tag
    if ~isempty(processTag)
        fileTag = [fileTag, '_', processTag];
    end
    % Get file type
    fileType = file_gettype(sInput.FileName);
    
    % ===== OVERWRITE ? =====
    isOverwrite = isfield(sProcess.options, 'overwrite') && sProcess.options.overwrite.Value;
    % Overwrite required: check if it is doable
    if isOverwrite
        % Ignore overwrite for RAW files in another format than BST-BIN
        if isRaw
            isOverwrite = 0;
            bst_report('Warning', sProcess, sInput, 'Cannot overwrite continuous files.');
        % Ignore overwrite for links
        elseif strcmpi(fileType, 'link')
            isOverwrite = 0;
            bst_report('Warning', sProcess, sInput, 'Cannot overwrite links.');
        % Ignore share kernels
        elseif strcmpi(fileType, 'results') && ~isempty(strfind(sInput.FileName, '_KERNEL_'))
            isOverwrite = 0;
            bst_report('Warning', sProcess, sInput, 'Cannot overwrite shared inversion kernels.');
        end
    end
    
    % ===== OUTPUT FILENAME =====
    % Protocol folders and processing options
    ProtocolInfo = bst_get('ProtocolInfo');
    ProcessOptions = bst_get('ProcessOptions');
    % If file is a raw link: create new condition
    if isRaw
        % Get input raw path and name
        if ismember(sFileIn.format, {'CTF', 'CTF-CONTINUOUS'})
            [rawPathIn, rawBaseIn] = bst_fileparts(bst_fileparts(sFileIn.filename));
        else
            [rawPathIn, rawBaseIn] = bst_fileparts(sFileIn.filename);
        end
        % Make sure that there are not weird characters in the folder names
        rawBaseIn = file_standardize(rawBaseIn);
        % New folder name
        if isfield(sFileIn, 'condition') && ~isempty(sFileIn.condition)
            newCondition = ['@raw', sFileIn.condition, fileTag];
        else
            newCondition = ['@raw', rawBaseIn, fileTag];
        end
        % Get new condition name
        newStudyPath = file_unique(bst_fullfile(ProtocolInfo.STUDIES, sInput.SubjectName, newCondition));
        % Output file name derives from the condition name
        [tmp, rawBaseOut, rawBaseExt] = bst_fileparts(newStudyPath);
        rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
        % Full output filename
        RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']);
        RawFileFormat = 'BST-BIN';
        % Get input study (to copy the creation date)
        sInputStudy = bst_get('AnyFile', sInput.FileName);

        % Get new condition name
        [tmp, ConditionName] = bst_fileparts(newStudyPath, 1);
        % Create output condition
        iOutputStudy = db_add_condition(sInput.SubjectName, ConditionName, [], sInputStudy.DateOfStudy);
        if isempty(iOutputStudy)
            bst_report('Error', sProcess, sInput, ['Output folder could not be created:' 10 newPath]);
            return;
        end
        % Get output study
        sOutputStudy = bst_get('Study', iOutputStudy);
        % Full file name
        MatFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sOutputStudy.FileName), ['data_0raw_' rawBaseOut '.mat']);
    % Regular files
    else
        % If file is a link
        if strcmpi(fileType, 'link')
            [basekernel, basedata] = file_resolve_link(sInput.FileName);
            if ~isempty(basedata)
                basepath = bst_fileparts(basedata);
                [tmp__, basekernel, basext] = bst_fileparts(basekernel);
                basefile = bst_fullfile(basepath, [basekernel, basext]);
            else
                basefile = basekernel;
            end
        else
            basefile = sInput.FileName;
        end
        % Get output study: same as input
        [sOutputStudy, iOutputStudy, iFile] = bst_get('AnyFile', sInput.FileName);
        % Full output file
        basefile = file_short(basefile);
        MatFile = [strrep(basefile, '.mat', ''), fileTag, '.mat'];
        MatFile = strrep(MatFile, '_KERNEL', '');
        MatFile = file_unique(bst_fullfile(ProtocolInfo.STUDIES, MatFile));
    end
    
    % ===== SPLIT IN BLOCKS =====
    OutMeasure = [];
    OutLeff = [];
    OutputMat = [];
    OutputStd = [];
    OutputTFmask = [];
    % Get maximum size of a data block
    MaxSize = ProcessOptions.MaxBlockSize;
    if isfield(ProcessOptions, 'LastMaxBlockSize') && MaxSize ~= ProcessOptions.LastMaxBlockSize
        bst_report('Warning', sProcess, sInput, ['The memory block size was modified since the last process.' 10 ...
            'If you encounter issues, be sure to revert it to its previous value in the Brainstorm preferences.']);
        ProcessOptions.LastMaxBlockSize = MaxSize;
        bst_set('ProcessOptions', ProcessOptions);
    end
    % Split the block size in rows and columns
    if (nRow * nCol > MaxSize) && ~isempty(sProcess.processDim)
        % Split max block by row blocks
        if ismember(1, sProcess.processDim)
            % Split by row and col blocks
            if (nCol > MaxSize) && ismember(2, sProcess.processDim)
                BlockSizeRow = 1;
                BlockSizeCol = MaxSize;
            % Split only by row blocks
            else
                BlockSizeRow = max(floor(MaxSize / nCol), 1);
                BlockSizeCol = nCol;
            end
        % Split max block by col blocks
        elseif ismember(2, sProcess.processDim)
            BlockSizeRow = nRow;
            BlockSizeCol = max(floor(MaxSize / nRow), 1);
        end
        % Adapt block size to FIF block size
        if (BlockSizeCol < nCol) && isRaw && strcmpi(sFileIn.format, 'FIF') && isfield(sFileIn.header, 'raw') && isfield(sFileIn.header.raw, 'rawdir') && ~isempty(sFileIn.header.raw.rawdir)
            fifBlockSize = double(sFileIn.header.raw.rawdir(1).nsamp);
            BlockSizeCol = fifBlockSize * max(1, round(BlockSizeCol / fifBlockSize));
        end
    else
        BlockSizeRow = nRow;
        BlockSizeCol = nCol;
    end
    % Split data in blocks
    nBlockRow = ceil(nRow / BlockSizeRow);
    nBlockCol = ceil(nCol / BlockSizeCol);
    % Get current progress bar position
    progressPos = bst_progress('get');
    prevPos = 0;
    % Display console message
    if (nBlockRow > 1) && (nBlockCol > 1)
        disp(sprintf('BST> %s: Processing %d blocks of %d signals and %d time points.', sProcess.Comment, nBlockCol * nBlockRow, BlockSizeRow, BlockSizeCol));
    elseif (nBlockRow > 1)
        disp(sprintf('BST> %s: Processing %d blocks of %d signals.', sProcess.Comment, nBlockRow, BlockSizeRow));
    elseif (nBlockCol > 1)
        disp(sprintf('BST> %s: Processing %d blocks of %d time points.', sProcess.Comment, nBlockCol, BlockSizeCol));
    end

    % ===== PROCESS BLOCKS =====
    isFirstLoop = 1;
    % Loop on row blocks
    for iBlockRow = 1:nBlockRow
        % Indices of rows to process
        iRow = 1 + (((iBlockRow-1)*BlockSizeRow) : min(iBlockRow * BlockSizeRow - 1, nRow - 1));
        % Process only the required rows
        if ~isempty(iSelRows)
            [tmp__, iRowProcess] = intersect(iRow, iSelRows);
        end
        % Loop on col blocks
        for iBlockCol = 1:nBlockCol
            % Indices of columns to process
            iCol = 1 + (((iBlockCol-1)*BlockSizeCol) : min(iBlockCol * BlockSizeCol - 1, nCol - 1));
            % Progress bar
            newPos = progressPos + round(((iBlockRow - 1) * nBlockCol + iBlockCol) / (nBlockRow * nBlockCol) * 100);
            if (newPos ~= prevPos)
                bst_progress('set', newPos);
                prevPos = newPos;
            end

            % === GET DATA ===
            % Read values
            if isRaw
                bst_progress('text', [txtProgress, ' [reading]']);
                % Read block
                if isReadAll
                    sInput.A = FullFileMat(iRow, iCol);
                else
                    SamplesBounds = round(sFileIn.prop.times(1) .* sFileIn.prop.sfreq) + iCol([1,end]) - 1;
                    sInput.A = in_fread(sFileIn, ChannelMat, iEpoch, SamplesBounds, iRow, ImportOptions);
                end
                sInput.Std = [];
                % Progress bar: processing
                bst_progress('text', [txtProgress, ' [processing]']);
            else
                sInput.A = matValues(iRow, iCol, :);
                if ~isempty(stdValues)
                    sInput.Std = stdValues(iRow, iCol, :, :);
                else
                    sInput.Std = [];
                end
                if ~isempty(TFmask)
                    sInput.TFmask = TFmask(:, iCol, :);
                else
                    sInput.TFmask = [];
                end
            end
            % Set time vector in input
            sInput.TimeVector = sMat.Time(iCol);

            % === PROCESS ===
            % Send indices to the process
            sInput.iBlockRow = iBlockRow;
            sInput.iBlockCol = iBlockCol;
            % Process all rows
            if isempty(iSelRows) || isequal(iRowProcess, 1:size(sInput.A,1))
                sInput.iRowProcess = (1:size(sInput.A,1))';
                sInput = sProcess.Function('Run', sProcess, sInput);
            % Process only a subset of rows
            elseif ~isempty(iRowProcess)
                sInput.iRowProcess = iRowProcess;
                tmp1 = sInput.A;
                % Main data matrix
                sInput.A = sInput.A(iRowProcess,:,:);
                % Standard error
                if ~isempty(sInput.Std)
                    tmp2 = sInput.Std;
                    sInput.Std = sInput.Std(iRowProcess,:,:,:);
                end
                % Process file
                sInput = sProcess.Function('Run', sProcess, sInput);
                % Get results
                if ~isempty(sInput)
                    % If the number of time points is constant: Keep the non-processed values unchanged
                    if (size(tmp1,2) == size(sInput.A,2)) && (size(tmp1,3) == size(sInput.A,3))
                        tmp1(iRowProcess,:,:) = sInput.A;
                        sInput.A = tmp1;
                    % If the time vector was changed: Set all the non-processed values to zero
                    else
                        tmp1 = zeros(size(tmp1,1), size(sInput.A,2), size(sInput.A,3));
                        tmp1(iRowProcess,:,:) = sInput.A;
                        sInput.A = tmp1;
                    end
                    % Standard error
                    if ~isempty(sInput.Std)
                        tmp2(iRowProcess,:,:,:) = sInput.Std;
                        sInput.Std = tmp2;
                    end
                end
            end

            % If an error occured
            if isempty(sInput)
                return;
            end

            % === INITIALIZE OUTPUT ===
            % Split along columns (time): No support for change in sample numbers (resample)
            if ismember(2, sProcess.processDim)
                nOutTime = nCol;
                iOutTime = iCol;
            % All the other options (split by row, no split): support for resampling
            else
                nOutTime = length(sInput.TimeVector);
                iOutTime = iCol(1) - 1 + (1:length(sInput.TimeVector));
            end

            % Create output variable
            if isFirstLoop
                isFirstLoop = 0;
                bst_progress('text', [txtProgress, ' [creating new file]']);
                if isRaw
                    % Template continuous file (for the output)
                    sFileTemplate = sFileIn;
                end
                % Did time definition change?
                isTimeChange = ~ismember(2, sProcess.processDim) && ~isequal(sInput.TimeVector, sMat.Time) && (isRaw || (~((size(matValues,2) == 1) && (length(sMat.Time) == 2))));
                % Output time vector
                if isTimeChange
                    OldFreq = 1./(sMat.Time(2) - sMat.Time(1));
                    % If there are events: update the time and sample indices
                    if isfield(sMat, 'Events') && ~isempty(sMat.Events)
                        if (length(sInput.TimeVector) >= 2)
                            sMat.Events = panel_record('ChangeTimeVector', sMat.Events, OldFreq, sInput.TimeVector);
                        else
                            sMat.Events = [];
                        end
                    end
                    % Save new time vector
                    OutTime = sInput.TimeVector;
                    % Changing time on a continuous file
                    if isRaw
                        % Update file properties
                        sFileTemplate.prop.sfreq   = 1 / (sInput.TimeVector(2) - sInput.TimeVector(1));
                        sFileTemplate.prop.times   = [OutTime(1), OutTime(end)];
                        % Update events
                        sFileTemplate.events = panel_record('ChangeTimeVector', sFileTemplate.events, OldFreq, sInput.TimeVector);
                    end
                else
                    OutTime = sMat.Time;
                end
                % If reading the entire file: Initialize output matrix
                if isReadAll
                    OutFullFileMat = zeros(size(FullFileMat,1), length(OutTime));
                end
                % Output measure
                if isfield(sInput, 'Measure')
                    OutMeasure = sInput.Measure;                   
                end
                % Output Leff
                if isfield(sInput, 'Leff')
                    OutLeff = sInput.Leff;                   
                end
                % RAW: Create a new raw file to store the results
                if isRaw
                    % Create an empty Brainstorm-binary file
                    [sFileOut, errMsg] = out_fopen(RawFileOut, RawFileFormat, sFileTemplate, ChannelMat);
                    % Error processing
                    if isempty(sFileOut) && ~isempty(errMsg)
                        bst_report('Error', sProcess, sInput, errMsg);
                        return;
                    elseif ~isempty(errMsg)
                        bst_report('Warning', sProcess, sInput, errMsg);
                    end

                    % Output channel file 
                    ChannelMatOut = ChannelMat;
                    % Mark the projectors as already applied to the file
                    if ImportOptions.UseSsp && ~isempty(ChannelMatOut.Projector)
                        for iProj = 1:length(ChannelMatOut.Projector)
                            if (ChannelMatOut.Projector(iProj).Status == 1)
                                ChannelMatOut.Projector(iProj).Status = 2;
                            end
                        end
                    end
                else
                    OutputMat = zeros(nRow, nOutTime, nFreq);
                    if ~isempty(stdValues)
                        OutputStd = zeros(nRow, nOutTime, nFreq);
                    else
                        OutputStd = [];
                    end
                    if ~isempty(TFmask)
                        OutputTFmask = zeros(size(TFmask,1), nOutTime, size(TFmask,3));
                    else
                        OutputTFmask = [];
                    end
                end
            end

            % === SAVE VALUES ===
            if isRaw
                bst_progress('text', [txtProgress, ' [writing]']);
                if isReadAll
                    if isTimeChange
                        OutFullFileMat(iRow,:) = sInput.A;
                    else
                        OutFullFileMat(iRow,iCol) = sInput.A;
                    end
                else
                    % Indices to write
                    SamplesBounds = round(sFileOut.prop.times(1) .* sFileOut.prop.sfreq) + iOutTime([1,end]) - 1;
                    % Write block
                    sFileOut = out_fwrite(sFileOut, ChannelMatOut, iEpoch, SamplesBounds, iRow, sInput.A);
                end
            else
                OutputMat(iRow,iOutTime,:) = sInput.A;
                if ~isempty(stdValues) && ~isempty(sInput.Std)
                    OutputStd(iRow,iOutTime,:,:) = sInput.Std;
                else
                    OutputStd = [];
                end
                if ~isempty(TFmask) && ~isempty(sInput.TFmask)
                    OutputTFmask(:,iOutTime,:) = sInput.TFmask;
                else
                    OutputTFmask = [];
                end
            end
        end
    end % rows
    
    % Save all the RAW file at once
    if isReadAll
        sFileOut = out_fwrite(sFileOut, ChannelMatOut, iEpoch, [], [], OutFullFileMat);
    end
    
    % ===== CREATE OUTPUT STRUCTURE =====
    % If there is a DataFile link, and the time definition changed, and results is not static: remove link
    if isfield(sMat, 'DataFile') && ~isempty(sMat.DataFile)
        if ~isequal(sMat.Time, OutTime) && (length(OutTime) > 2)
            sMat.DataFile = [];
        else
            sMat.DataFile = file_short(sMat.DataFile);
        end
    end
    % Output time vector
    sMat.Time = OutTime;
    % Output measure
    if ~isempty(OutMeasure)
        sMat.Measure = OutMeasure;
    end
    % Output Leff
    if ~isempty(OutLeff)
        sMat.Leff = OutLeff;
    end
    % Set data fields
    if isRaw
        % Remove the string: "Link to raw file"
        sMat.Comment = strrep(sMat.Comment, 'Link to raw file', 'Raw');
        sMat.Time = [sMat.Time(1), sMat.Time(end)];
        sMat.F = sFileOut;
    else
        sMat.(matName) = OutputMat;
        sMat.Std = OutputStd;
    end
    % TFmask
    if isfield(sMat, 'TFmask')
        sMat.TFmask = OutputTFmask;
    end
    % Comment: forced in the options
    if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
        sMat.Comment = sProcess.options.Comment.Value;
    % Modify comment based on modifications in function Run
    elseif ~isRaw && isfield(sInput, 'Comment') && ~isempty(sInput.Comment) && ~isequal(sMat.Comment, sInput.Comment)
        sMat.Comment = sInput.Comment;
    % Add file tag (defined in process Run function)
    elseif isfield(sInput, 'CommentTag') && ~isempty(sInput.CommentTag)
        sMat.Comment = [sMat.Comment, ' | ', sInput.CommentTag];
    % Add file tag (defined in process definition GetDescription)
    elseif ~isempty(processTag)
        sMat.Comment = [sMat.Comment, ' | ', processTag];
    end
    % If data + changed data type
    if isfield(sInput, 'DataType') && ~isempty(sInput.DataType) && isfield(sMat, 'DataType')
        sMat.DataType = sInput.DataType;
    end
    if isfield(sInput, 'ColormapType') && ~isempty(sInput.ColormapType)
        sMat.ColormapType = sInput.ColormapType;
    end
    if isfield(sInput, 'DisplayUnits') && ~isempty(sInput.DisplayUnits)
        sMat.DisplayUnits = sInput.DisplayUnits;
    end
    if isfield(sInput, 'Function') && ~isempty(sInput.Function)
        sMat.Function = sInput.Function;
    end
    % ChannelFlag 
    if isfield(sInput, 'ChannelFlag') && ~isempty(sInput.ChannelFlag)
        sMat.ChannelFlag = sInput.ChannelFlag;
        if isRaw
            sMat.F.channelflag = sInput.ChannelFlag;
        end
    end
    % New events created in the process
    if isfield(sInput, 'Events') && ~isempty(sInput.Events) && ismember(sInput.FileType, {'data', 'raw', 'matrix'})
        % Continuous files: add to descriptor
        if isRaw
            sMat.F = import_events(sMat.F, [], sInput.Events);
        % Import epochs: add to the "Events" structure of the new file
        else
            % Trick import_events() to work for event concatenation
            if isfield(sMat, 'Events') && ~isempty(sMat.Events)
                sFile.events = sMat.Events;
            else
                sFile.events = [];
            end
            sFile.prop.sfreq = 1 / (sInput.TimeVector(2) - sInput.TimeVector(1));
            sFile = import_events(sFile, [], sInput.Events);
            sMat.Events = sFile.events;
        end
    end
    
    % ===== HISTORY =====
    % History: Absolute value
    if isAbsolute
        HistoryComment = [func2str(sProcess.Function) ': Absolute value'];
        sMat = bst_history('add', sMat, 'process', HistoryComment);
    end
    % History: Process name + options
    if isfield(sInput, 'HistoryComment') && ~isempty(sInput.HistoryComment)
        HistoryComment = [func2str(sProcess.Function) ': ' sInput.HistoryComment];
    else
        HistoryComment = [func2str(sProcess.Function) ': ' sProcess.Function('FormatComment', sProcess)];
    end
    sMat = bst_history('add', sMat, 'process', HistoryComment);
    
    % ===== SAVE FILE =====
    % Save new file
    bst_save(MatFile, sMat, 'v6');
    % If no default channel file: create new channel file
    if isRaw && (sSubject.UseDefaultChannel == 0)
        db_set_channel(iOutputStudy, ChannelMatOut, 2, 0);
    end

    % ===== REGISTER IN DATABASE =====
    % Register in database
    if isOverwrite
        db_add_data(iOutputStudy, MatFile, sMat, sInput.iItem);
    else
        db_add_data(iOutputStudy, MatFile, sMat);
    end
    % Return new file
    OutputFile = MatFile;
end


%% ===== PROCESS: FILTER2 =====
function OutputFile = ProcessFilter2(sProcess, sInputA, sInputB)
    % ===== LOAD FILES =====
    fileTag = '';
    % Get data matrix
    [sMatA, matName] = in_bst(sInputA.FileName);
    [sMatB, matName] = in_bst(sInputB.FileName);
    % Absolute values of sources / norm or unconstrained sources
    isAbsolute = strcmpi(matName, 'ImageGridAmp') && (sProcess.isSourceAbsolute >= 1);
    if isAbsolute
        % Unconstrained sources: Norm of the three orientations
        if isfield(sMatA, 'nComponents') && (sMatA.nComponents ~= 1) && isfield(sMatB, 'nComponents') && (sMatB.nComponents ~= 1)
            sMatA = process_source_flat('Compute', sMatA, 'rms');
            sMatB = process_source_flat('Compute', sMatB, 'rms');
            strTag = 'norm';
        % Constrained sources: Absolute values
        else
            strTag = 'abs';
            sMatA.Comment = [sMatA.Comment, ' | ', strTag];
            sMatB.Comment = [sMatB.Comment, ' | ', strTag];
        end
        % Enforce absolute values
        sMatA.(matName) = abs(sMatA.(matName));
        sMatB.(matName) = abs(sMatB.(matName));
        % Add tags
        fileTag = [fileTag, '_', strTag];
    end  
    
    % Values
    sInputA.A = sMatA.(matName);
    sInputB.A = sMatB.(matName);
    % Check size
    if ~isequal(size(sInputA.A), size(sInputB.A)) && ~ismember(func2str(sProcess.Function), {'process_baseline_ab', 'process_zscore_ab', 'process_zscore_dynamic_ab', 'process_baseline_norm2'})
        bst_report('Error', sProcess, [sInputA, sInputB], 'Files in groups A and B do not have the same size.');
        OutputFile = [];
        return;
    end
    % Check time-freq measures
    if isfield(sMatA, 'Measure') && isfield(sMatB, 'Measure') && ~strcmpi(sMatA.Measure, sMatB.Measure)
        bst_report('Error', sProcess, [sInputA, sInputB], 'Files in groups A and B do not have the same measure applied on the time-frequency coefficients.');
        OutputFile = [];
        return;
    end
    % Do not allow TimeBands
    if ((isfield(sMatA, 'TimeBands') && ~isempty(sMatA.TimeBands)) || (isfield(sMatB, 'TimeBands') && ~isempty(sMatB.TimeBands))) ...
            && ismember(func2str(sProcess.Function), {'process_baseline_ab', 'process_zscore_ab', 'process_baseline_norm2'}) 
        % && isfield(sMat, 'Measure') && ~strcmpi(sMat.Measure, 'other') && ~strcmpi(sMat.Measure, 'plv')
        bst_report('Error', sProcess, [sInputA, sInputB], 'Cannot process values averaged by time bands.');
        OutputFile = [];
        return;
    end
    % Copy channel flag information
    if isfield(sMatA, 'ChannelFlag') && isfield(sMatB, 'ChannelFlag')
        sInputA.ChannelFlag = sMatA.ChannelFlag;
        sInputA.ChannelFlag(sMatB.ChannelFlag == -1) = -1;
        sInputB.ChannelFlag = sInputA.ChannelFlag;
    end
    
    % Copy nAvg information
    if isfield(sMatA, 'nAvg') && ~isempty(sMatA.nAvg)
        sInputA.nAvg = sMatA.nAvg;
    else
        sInputA.nAvg = 1;
    end
    if isfield(sMatB, 'nAvg') && ~isempty(sMatB.nAvg)
        sInputB.nAvg = sMatB.nAvg;
    else
        sInputB.nAvg = 1;
    end
    % Copy Leff (effective number of averages)
    if isfield(sMatA, 'Leff') && ~isempty(sMatA.Leff)
        sInputA.Leff = sMatA.Leff;
    else
        sInputA.Leff = 1;
    end
    if isfield(sMatB, 'Leff') && ~isempty(sMatB.Leff)
        sInputB.Leff = sMatB.Leff;
    else
        sInputB.Leff = 1;
    end
    % Copy time information
    sInputA.TimeVector = sMatA.Time;
    sInputB.TimeVector = sMatB.Time;
    % Get process tag
    processTag = [];
    if ~isempty(sProcess.FileTag)
        if ischar(sProcess.FileTag)
            processTag = sProcess.FileTag;
        elseif isa(sProcess.FileTag, 'function_handle')
            processTag = sProcess.FileTag(sProcess);
        end
    end
    % Build output file tag
    if ~isempty(processTag)
        fileTag = [fileTag, '_', processTag];
    end

    % ===== PROCESS =====
    % Apply process function
    sOutput = sProcess.Function('Run', sProcess, sInputA, sInputB);
    % If an error occured
    if isempty(sOutput)
        OutputFile = [];
        return;
    end
    
    % ===== OUTPUT STUDY =====
    % Get output study
    [sStudy, iStudy, Comment, uniqueDataFile] = GetOutputStudy(sProcess, [sInputA, sInputB], sOutput.Condition);
    % Get output file type
    fileType = GetFileTag(sInputA(1).FileName);
    % Build output filename
    OutputFile = GetNewFilename(bst_fileparts(sStudy.FileName), [fileType fileTag]);

    % ===== CREATE OUTPUT STRUCTURE =====
    sMatOut = sMatB;
    sMatOut.(matName) = sOutput.A;
    % Comment: forced in the options
    if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
        sMatOut.Comment = sProcess.options.Comment.Value;
    else
        % Add file tag
        if isfield(sOutput, 'CommentTag') && ~isempty(sOutput.CommentTag)
            sMatOut.Comment = [sMatOut.Comment, ' | ', sOutput.CommentTag];
        elseif ~isempty(processTag)
            sMatOut.Comment = [sMatOut.Comment, ' | ', processTag];
        else
            sMatOut.Comment = sOutput.Comment;
        end
    end
    
    
    % Reset DataFile field
    if isfield(sMatOut, 'DataFile') && (length(uniqueDataFile) > 1) && ~ismember(func2str(sProcess.Function), {'process_zscore_ab', 'process_zscore_dynamic_ab', 'process_baseline_norm2'})
        sMatOut.DataFile = [];
    end
    % If data + changed data type
    if isfield(sOutput, 'DataType') && ~isempty(sOutput.DataType) && isfield(sMatOut, 'DataType')
        sMatOut.DataType = sOutput.DataType;
    end
    if isfield(sOutput, 'ColormapType') && ~isempty(sOutput.ColormapType)
        sMatOut.ColormapType = sOutput.ColormapType;
    end
    if isfield(sOutput, 'DisplayUnits') && ~isempty(sOutput.DisplayUnits)
        sMatOut.DisplayUnits = sOutput.DisplayUnits;
    end
    if isfield(sOutput, 'Function') && ~isempty(sOutput.Function)
        sMatOut.Function = sOutput.Function;
    end
    if isfield(sOutput, 'Measure') && ~isempty(sOutput.Measure)
        sMatOut.Measure = sOutput.Measure;
    end
    if isfield(sOutput, 'nAvg') && ~isempty(sOutput.nAvg)
        sMatOut.nAvg = sOutput.nAvg;
    end
    if isfield(sOutput, 'Leff') && ~isempty(sOutput.Leff)
        sMatOut.Leff = sOutput.Leff;
    end
    % Copy time vector
    sMatOut.Time = sOutput.TimeVector;
    % Fix surface link for warped brains
    if isfield(sMatOut, 'SurfaceFile') && ~isempty(sMatOut.SurfaceFile) && ~isempty(strfind(sMatOut.SurfaceFile, '_warped'))
        sMatOut = process_average('FixWarpedSurfaceFile', sMatOut, sInputA(1), sStudy);
    end
    
    % ===== HISTORY =====
    HistoryComment = [func2str(sProcess.Function) ': ' sProcess.Function('FormatComment', sProcess)];
    sMatOut = bst_history('reset', sMatOut);
    sMatOut = bst_history('add', sMatOut, 'process', HistoryComment);
    sMatOut = bst_history('add', sMatOut, 'process', ['File A: ' sInputA.FileName]);
    if ~isempty(sMatA.History)
        sMatOut = bst_history('add', sMatOut, sMatA.History, ' - ');
    end
    sMatOut = bst_history('add', sMatOut, 'process', ['File B: ' sInputB.FileName]);
    if ~isempty(sMatB.History)
        sMatOut = bst_history('add', sMatOut, sMatB.History, ' - ');
    end
    sMatOut = bst_history('add', sMatOut, 'process', 'Process completed');

    % ===== SAVE FILE =====
    % Save new file
    bst_save(OutputFile, sMatOut, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFile, sMatOut);
end


%% ===== PROCESS: STAT =====
function OutputFiles = ProcessStat(sProcess, sInputA, sInputB)
    % ===== GET OUTPUT STUDY =====
    % Display progress bar
    bst_progress('text', 'Saving results...');
    % Get number of subjects that are involved
    isStat1 = strcmpi(sProcess.Category, 'Stat1') || isempty(sInputB);
    if isStat1
        [sStudy, iStudy] = GetOutputStudy(sProcess, sInputA);
    else
        [sStudy, iStudy] = GetOutputStudy(sProcess, [sInputA, sInputB]);
    end
    % Error
    if isempty(sStudy)
        error('Could not find output folder... Please report this error on the user forum for assistance.');
    end
        
    % Add the output study index in the process options
    sProcess.options.iOutputStudy = iStudy;

    % ===== CALL PROCESS =====
    if isStat1
        sOutput = sProcess.Function('Run', sProcess, sInputA);
    else
        sOutput = sProcess.Function('Run', sProcess, sInputA, sInputB);
    end
    if isempty(sOutput)
        OutputFiles = {};
        return;
    end
    
    % ===== CREATE OUTPUT STRUCTURE =====
    % Template structure for stat files
    if isempty(sOutput.Type)
        sOutput.Type = sInputA(1).FileType;
    end
    % Get process comment
    try
        processComment = sProcess.Function('FormatComment', sProcess);
    catch
        processComment = sProcess.Comment;
    end
    % Comment: forced in the options
    if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
        sOutput.Comment = sProcess.options.Comment.Value;
    % Regular comment
    else
        if isempty(sOutput.Comment)
            sOutput.Comment = processComment;
            % Remove additional comments (separated with more than two spaces)
            iExtra = strfind(sOutput.Comment, '  ');
            if ~isempty(iExtra)
                sOutput.Comment = sOutput.Comment(1:(iExtra(1)-1));
            end
        end
        % Get stat comment
        sOutput.Comment = [sOutput.Comment ': ' GetStatComment(sProcess, sInputA, sInputB)];
    end
    % Results: Get extra infotmation
    if ismember(sInputA(1).FileType, {'results', 'timefreq'})
        % Load extra fields
        if strcmpi(sInputA(1).FileType, 'results')
            ExtraMat = in_bst_results(sInputA(1).FileName, 0, 'HeadModelType', 'SurfaceFile', 'nComponents', 'Atlas', 'SurfaceFile', 'GridLoc', 'GridOrient', 'GridAtlas');
        elseif strcmpi(sInputA(1).FileType, 'timefreq')
            ExtraMat = in_bst_timefreq(sInputA(1).FileName, 0, 'HeadModelType', 'SurfaceFile', 'nComponents', 'Atlas', 'SurfaceFile', 'GridLoc', 'GridOrient', 'GridAtlas', 'DataType', 'TimeBands', 'Freqs', 'RefRowNames', 'RowNames', 'Method', 'Options');
            ExtraMat.Measure = 'other';
        end
        % Keep the nComponents/GridAtlas/RowNames/Freqs if they were modified by the process
        if isfield(sOutput, 'nComponents') && ~isempty(sOutput.nComponents)
            ExtraMat = rmfield(ExtraMat, 'nComponents');
        end
        if isfield(sOutput, 'GridAtlas') && ~isempty(sOutput.GridAtlas)
            ExtraMat = rmfield(ExtraMat, 'GridAtlas');
        end
        if isfield(sOutput, 'RowNames') && ~isempty(sOutput.RowNames)
            ExtraMat = rmfield(ExtraMat, 'RowNames');
        end
        if isfield(sOutput, 'Freqs') && ~isempty(sOutput.Freqs)
            ExtraMat = rmfield(ExtraMat, 'Freqs');
        end
        if isfield(sOutput, 'Options') && ~isempty(sOutput.Options) && isfield(ExtraMat, 'Options') && ~isempty(ExtraMat.Options)
            ExtraMat.OptionsStat = sOutput.Options;
        end
        % Copy fields
        sOutput = struct_copy_fields(sOutput, ExtraMat, 1);
    end
    % Fix surface link for warped brains
    if isfield(sOutput, 'SurfaceFile') && ~isempty(sOutput.SurfaceFile) && ~isempty(strfind(sOutput.SurfaceFile, '_warped'))
        sOutput = process_average('FixWarpedSurfaceFile', sOutput, sInputA(1), sStudy);
    end
    % History
    sOutput = bst_history('add', sOutput, 'stat', sProcess.Comment);
    sOutput = bst_history('add', sOutput, 'stat', [func2str(sProcess.Function) ': ' processComment]);
    % History: List files A
    sOutput = bst_history('add', sOutput, 'stat', 'List of files in group A:');
    for i = 1:length(sInputA)
        sOutput = bst_history('add', sOutput, 'stat', [' - ' sInputA(i).FileName]);
    end
    % History: List files B
    sOutput = bst_history('add', sOutput, 'stat', 'List of files in group B:');
    for i = 1:length(sInputB)
        sOutput = bst_history('add', sOutput, 'stat', [' - ' sInputB(i).FileName]);
    end
    
    % ===== CONVERT BACK TO REGULAR STRUCTURE =====
    % Get the expected output file type from this process
    iType = find(strcmpi(sOutput.Type, sProcess.InputTypes));
    % If input type is found: use the corresponding output type
    if ~isempty(iType)
        OutputFileType = sProcess.OutputTypes{iType};
    % If not available: stat from the original file
    else
        OutputFileType = ['p', sOutput.Type];
    end
    % If the output type is not a stat file: convert structure
    if ismember(OutputFileType, {'data', 'results', 'timefreq', 'matrix'})
        sStat = sOutput;
        switch (OutputFileType)
            case 'data'
                sOutput = db_template('datamat');
                sOutput.F           = sStat.tmap;
                sOutput.ChannelFlag = sStat.ChannelFlag;
            case 'results'
                sOutput = db_template('resultsmat');
                sOutput.ImageGridAmp  = sStat.tmap;
                sOutput.nComponents   = sStat.nComponents;
                sOutput.HeadModelType = sStat.HeadModelType;
                sOutput.SurfaceFile   = sStat.SurfaceFile;
                sOutput.Atlas         = sStat.Atlas;
                sOutput.GridLoc       = sStat.GridLoc;
                sOutput.GridOrient    = sStat.GridOrient;
                sOutput.GridAtlas     = sStat.GridAtlas;
            case 'timefreq'
                sOutput = db_template('timefreqmat');
                sOutput.TF           = sStat.tmap;
                sOutput.DataType     = sStat.DataType;
                sOutput.Freqs        = sStat.Freqs;
                sOutput.RowNames     = sStat.RowNames;
                sOutput.Measure      = sStat.Measure;
                sOutput.Method       = sStat.Method;
                sOutput.TimeBands    = sStat.TimeBands;
                sOutput.nComponents  = sStat.nComponents;
                sOutput.SurfaceFile  = sStat.SurfaceFile;
                sOutput.Atlas        = sStat.Atlas;
                sOutput.GridLoc      = sStat.GridLoc;
                sOutput.GridAtlas    = sStat.GridAtlas;        
            case 'matrix'
                sOutput = db_template('matrixmat');
                sOutput.Value        = sStat.tmap;
                sOutput.Description  = sStat.Description;
                sOutput.SurfaceFile  = sStat.SurfaceFile;
                sOutput.Atlas        = sStat.Atlas;
        end
        % Common fields
        sOutput.Comment      = sStat.Comment;
        sOutput.Time         = sStat.Time;
        sOutput.History      = sStat.History;
        sOutput.DisplayUnits = sStat.DisplayUnits;
        sOutput.ColormapType = sStat.ColormapType;
        sOutput.nAvg         = 1;
        sOutput.Leff         = 1;
        % Output filetype
        if strcmpi(sInputA(1).FileType, sStat.Type)
            fileTag = bst_process('GetFileTag', sInputA(1).FileName);
        else
            fileTag = sStat.Type;
        end
        if strcmpi(sStat.Type, 'matrix') && ~isempty(strfind(fileTag, 'results_'))
            fileTag = strrep(fileTag, 'results', 'matrix');
        end
        
    % === SAVE STAT FILE ===
    else
        % Output filetype
        if ismember(sInputA(1).FileType, {'pdata', 'presults', 'ptimefreq', 'pmatrix'})
            fileTag = [GetFileTag(sInputA(1).FileName), '_', sOutput.Correction];
        elseif strcmpi(sInputA(1).FileType, sOutput.Type)
            fileTag = ['p', GetFileTag(sInputA(1).FileName), '_', sOutput.Correction];
        else
            fileTag = ['p', sOutput.Type, '_', sOutput.Correction];
        end
        if strcmpi(sOutput.Type, 'matrix') && ~isempty(strfind(fileTag, 'presults_'))
            fileTag = strrep(fileTag, 'presults', 'pmatrix');
        end
    end
    
    % ===== SAVE FILE =====
    % Output filename
    OutputFiles{1} = GetNewFilename(bst_fileparts(sStudy.FileName), fileTag);
    % Save on disk
    bst_save(OutputFiles{1}, sOutput, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFiles{1}, sOutput);
end



%% ===== INPUT STRUCTURE =====
function sInputs = GetInputStruct(FileNames)
    % If single filename: convert to a list
    if ischar(FileNames)
        FileNames = {FileNames};
    end
    % Output structure
    sInputs = repmat(db_template('processfile'), 1, length(FileNames));
    % Get file type for the first file
    FileType = file_gettype(FileNames{1});
    % Remove the full path
    ProtocolInfo = bst_get('ProtocolInfo');
    FileNames = cellfun(@(c)strrep(c, [ProtocolInfo.STUDIES, filesep], ''), FileNames, 'UniformOutput', 0);
    % Convert to linux-style file names
    FileNames = cellfun(@file_win2unix, FileNames, 'UniformOutput', 0);
    % Group in studies
    FilePaths = cellfun(@(c)c(1:find(c=='/',1,'last')-1), FileNames, 'UniformOutput', 0);
    [uniquePath,I,J] = unique(FilePaths);
    % Loop on studies
    for iPath = 1:length(uniquePath)
        % Get files in this group
        iGroupFiles = find(J == iPath);
        GroupFileNames = FileNames(iGroupFiles);
        % Get study for the first file
        [sStudy, iStudy] = bst_get('AnyFile', GroupFileNames{1});
        if isempty(sStudy)
            sInputs = [];
            return;
        end
        % Set information for the files in this group
        [sInputs(iGroupFiles).iStudy]      = deal(iStudy);
        [sInputs(iGroupFiles).SubjectFile] = deal(file_win2unix(sStudy.BrainStormSubject));
        % Get channel file
        sChannel = bst_get('ChannelForStudy', iStudy);
        if ~isempty(sChannel)
            [sInputs(iGroupFiles).ChannelFile]  = deal(file_win2unix(sChannel.FileName));
            [sInputs(iGroupFiles).ChannelTypes] = deal(sChannel.Modalities);
        end
        % Condition
        if ~isempty(sStudy.Condition)
            [sInputs(iGroupFiles).Condition] = deal(sStudy.Condition{1});
        end
        % Look for items in database
        switch (FileType)
            case 'data'
                [tmp, iDb, iList] = intersect({sStudy.Data.FileName}, GroupFileNames);
                sItems = sStudy.Data(iDb);
                if ~isempty(sItems) && strcmpi(sItems(1).DataType, 'raw')
                    InputType = 'raw';
                else
                    InputType = 'data';
                end
            case {'results', 'link'}
                [tmp, iDb, iList] = intersect({sStudy.Result.FileName}, GroupFileNames);
                sItems = sStudy.Result(iDb);
                InputType = 'results';
            case {'presults', 'pdata','ptimefreq','pmatrix'}
                [tmp, iDb, iList] = intersect({sStudy.Stat.FileName}, GroupFileNames);
                sItems = sStudy.Stat(iDb);
                InputType = FileType;
            case 'timefreq'
                [tmp, iDb, iList] = intersect({sStudy.Timefreq.FileName}, GroupFileNames);
                sItems = sStudy.Timefreq(iDb);
                InputType = 'timefreq';
            case 'matrix'
                [tmp, iDb, iList] = intersect({sStudy.Matrix.FileName}, GroupFileNames);
                sItems = sStudy.Matrix(iDb);
                InputType = 'matrix';
            case 'dipoles'
                [tmp, iDb, iList] = intersect({sStudy.Dipoles.FileName}, GroupFileNames);
                sItems = sStudy.Dipoles(iDb);
                InputType = 'dipoles';
            otherwise
                error('File format not supported.');
        end
        % Error: not all files were found
        if (length(iList) ~= length(GroupFileNames))
            disp(sprintf('BST> Warning: %d file(s) not found in database.', length(GroupFileNames) - length(iList)));
            continue;
        end
        % Fill structure
        iInputs = iGroupFiles(iList);
        iDb = num2cell(iDb);
        [sInputs(iInputs).iItem]    = deal(iDb{:});
        [sInputs(iInputs).FileType] = deal(InputType);
        [sInputs(iInputs).FileName] = deal(sItems.FileName);
        [sInputs(iInputs).Comment]  = deal(sItems.Comment);
        % Associated data file
        if isfield(sItems, 'DataFile')
            [sInputs(iInputs).DataFile] = deal(sItems.DataFile);
        end
    end
    % Remove entries that were not found in the database
    iEmpty = cellfun(@isempty, {sInputs.FileName});
    if ~isempty(iEmpty)
        sInputs(iEmpty) = [];
    end
    % No files: exit
    if isempty(sInputs)
        return;
    end
    % Get subject names
    [uniqueSubj,I,J] = unique({sInputs.SubjectFile});
    for i = 1:length(uniqueSubj)
        sSubject = bst_get('Subject', uniqueSubj{i});
        [sInputs(J==i).SubjectName] = deal(sSubject.Name);
    end
end

%% ===== GET OUTPUT STUDY =====
% USAGE:  [sStudy, iStudy, Comment, uniqueDataFile] = GetOutputStudy(sProcess, sInputs)    
%         [sStudy, iStudy, Comment, uniqueDataFile] = GetOutputStudy(sProcess, sInputs, intraCondName, isCreateCond=1)  : New condition instead of intra-subject
function [sStudy, iStudy, Comment, uniqueDataFile] = GetOutputStudy(sProcess, sInputs, intraCondName, isCreateCond)
    % Parse inputs
    if (nargin < 4) || isempty(isCreateCond)
        isCreateCond = 1;
    end
    if (nargin < 3) || isempty(intraCondName)
        intraCondName = [];
    end
    
    % === OUTPUT CONDITION ===
    % Get list of subjects / conditions
    uniqueSubj = unique(cellfun(@(c)strrep(c,'\','/'), {sInputs.SubjectFile}, 'UniformOutput', 0));
    uniqueCond = unique({sInputs.Condition});
    uniqueStudy = unique([sInputs.iStudy]);
    % Unique reference data file (results and timefreq only)
    if ~any(cellfun(@isempty, {sInputs.DataFile}))
        DataFiles = {sInputs.DataFile};
        DataFiles = strrep(DataFiles, '/', '');
        DataFiles = strrep(DataFiles, '\', '');
        uniqueDataFile = unique(DataFiles);
    else
        uniqueDataFile = [];
    end
    % One study only
    if (length(uniqueStudy) == 1)
        % Output study: this study
        iStudy = uniqueStudy;
        sStudy = bst_get('Study', iStudy);
        % Comment
        Comment = [];
    % One subject only
    elseif (length(uniqueSubj) == 1)
        % Get subject
        [sSubject, iSubject] = bst_get('Subject', uniqueSubj{1});
        % Create new condition for intra-subject
        if ~isempty(intraCondName)
            % Try to get condition
            [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, intraCondName));
            % Condition does not exist: Create new condition
            if isempty(sStudy) && isCreateCond
                iStudy = db_add_condition(iSubject, intraCondName, 1);
                sStudy = bst_get('Study', iStudy);
            end
        % Else: Output study = "intra" node for this subject
        else
            [sStudy, iStudy] = bst_get('AnalysisIntraStudy', iSubject);
        end
        % Comment
        Comment = [];
    % One condition
    elseif (length(uniqueCond) == 1)
        % Get group analysis subject
        [sSubject, iSubject] = bst_get('NormalizedSubject');
        % Remove the RAW tag if present
        uniqueCond{1} = strrep(uniqueCond{1}, '@raw', '');
        % Try to get condition
        [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, uniqueCond{1}));
        % Condition does not exist: Create new condition
        if isempty(sStudy) && isCreateCond
            iStudy = db_add_condition(iSubject, uniqueCond{1}, 1);
            sStudy = bst_get('Study', iStudy);
        end
        % Comment
        Comment = sprintf('%s (%d)', uniqueCond{1}, length(sInputs));
        
    % No regularities
    else
        % Get group analysis subject
        [sSubject, iSubject] = bst_get('NormalizedSubject');
        % Get intra-subject study for the group subject
        [sStudy, iStudy] = bst_get('AnalysisIntraStudy', iSubject);
        % Comment
        Comment = [];
    end
    % Try to group by comment
    if isempty(Comment)
        % Default comments for each file
        AllComments = {sInputs.Comment};
        % Get files comments: Two levels up
        if ismember(sInputs(1).FileType, {'timefreq','results'}) && ~isempty(sInputs(1).DataFile) && ismember(file_gettype(sInputs(1).DataFile), {'results','link'})
            % Get parent data files for all the files
            for iFile = 1:length(sInputs)
                % Find parent file in the database
                [sStudyComment,tmp__,iRes] = bst_get('ResultsFile', sInputs(1).DataFile);
                % If the file was found, try check if it has a parent too
                if ~isempty(sStudyComment)
                    % Get one level further if possible
                    if ~isempty(sStudyComment.Result(iRes).DataFile)
                        % Find parent of parent in the database
                        [sStudyComment,tmp__,iData] = bst_get('DataFile', sStudyComment.Result(iRes).DataFile);
                        % If the file was found, use its comment
                        if ~isempty(sStudyComment)
                            AllComments{iFile} = sStudyComment.Data(iData).Comment;
                        end
                    else
                        AllComments{iFile} = sStudyComment.Result(iRes).Comment;
                    end
                end
            end
        % Get files comments: One level up
        elseif ismember(sInputs(1).FileType, {'timefreq','results'}) && ~isempty(sInputs(1).DataFile) && ismember(file_gettype(sInputs(1).DataFile), {'data','matrix'})
            % Get parent data files for all the files
            for iFile = 1:length(sInputs)
                % Find parent file in the database
                [sStudyComment,tmp__,iData, ParentType]  = bst_get('AnyFile', sInputs(1).DataFile);
                % If the file was found, get its comment
                if ~isempty(sStudyComment)
                    if strcmpi(ParentType, 'data')
                        AllComments{iFile} = sStudyComment.Data(iData).Comment;
                    elseif strcmpi(ParentType, 'matrix')
                        AllComments{iFile} = sStudyComment.Matrix(iData).Comment;
                    end
                end
            end
        end
        % Get uniformized lists of comments
        listComments = cellfun(@(c)deblank(str_remove_parenth(c)), AllComments, 'UniformOutput', 0);
        uniqueComments = unique(listComments);
        % If averaged list of trials
        if (length(uniqueComments) == 1)
            Comment = sprintf('%s (%d)', uniqueComments{1}, length(sInputs));
        end
    end
    % Try to group by comment of the parent file
    if isempty(Comment)
        % Get uniformized lists of comments
        listComments = cellfun(@(c)deblank(str_remove_parenth(c)), {sInputs.Comment}, 'UniformOutput', 0);
        uniqueComments = unique(listComments);
        % If averaged list of trials
        if (length(uniqueComments) == 1)
            Comment = sprintf('%s (%d)', uniqueComments{1}, length(sInputs));
        end
    end
    % No regularities at all
    if isempty(Comment)
        Comment = sprintf('%d files', length(sInputs));
    end
    
    
    % ===== COMBINE CHANNEL FILES =====
    % If source and target studies are not the same
    if ~isequal(uniqueStudy, iStudy) && isCreateCond
        % Destination study for new channel file
        [tmp__, iChanStudyDest] = bst_get('ChannelForStudy', iStudy);
        % Source channel files studies
        [tmp__, iChanStudySrc] = bst_get('ChannelForStudy', uniqueStudy);
        % If target study has no channel file: create a new one by combination of the others
        %NoWarning   = strcmpi(sInputs(1).FileType, 'results');
        NoWarning   = 1;
        UserConfirm = 0;
        [isNewFile, Message] = db_combine_channel(unique(iChanStudySrc), iChanStudyDest, UserConfirm, NoWarning);
        % Error management
        if ~isempty(Message)
            bst_report('Warning', sProcess, sInputs, Message);
        end
        if isNewFile
            % Refresh study with new channel file info.
            sStudy = bst_get('Study', iStudy);
        end
    end
end


%% ===== GET STAT COMMENT =====
function Comment = GetStatComment(sProcess, sInputA, sInputB)
    if isempty(sInputB)
        % Get comment for files A
        [tmp__, tmp__, Comment] = GetOutputStudy(sProcess, sInputA, [], 0);
    else
        % Get comment for files A and B
        [tmp__, tmp__, CommentA] = GetOutputStudy(sProcess, sInputA, [], 0);
        [tmp__, tmp__, CommentB] = GetOutputStudy(sProcess, sInputB, [], 0);
        if strcmpi(CommentA, CommentB) && ~strcmpi(sInputA(1).Condition, sInputB(1).Condition)
            CommentA = sInputA(1).Condition;
            CommentB = sInputB(1).Condition;
        end
        % Remove parenthesis
        CommentA = str_remove_parenth(CommentA);
        CommentB = str_remove_parenth(CommentB);
        % Get full comment
        if (length(sInputA) > 1) || (length(sInputB) > 1)
            if sProcess.isPaired
                Comment = [CommentA ' vs. ' CommentB ' (' num2str(length(sInputB)) ')'];
            else
                Comment = [CommentA ' (' num2str(length(sInputA)) ') vs. ' CommentB ' (' num2str(length(sInputB)) ')'];
            end
        else
            Comment = [CommentA ' vs. ' CommentB];
        end
    end
end


%% ===== GET NEW FILENAME =====
function filename = GetNewFilename(fPath, fBase)
    % Folder
    ProtocolInfo = bst_get('ProtocolInfo');
    fPath = strrep(fPath, ProtocolInfo.STUDIES, '');
    % Date and time
    c = clock;
    strTime = sprintf('_%02.0f%02.0f%02.0f_%02.0f%02.0f', c(1)-2000, c(2:5));
    % Remove extension
    fBase = strrep(fBase, '.mat', '');
    % Full filename
    filename = bst_fullfile(ProtocolInfo.STUDIES, fPath, [fBase, strTime, '.mat']);
    filename = file_unique(filename);
end


%% ===== GET FILE TAG =====
% Return a file tag that would completely identify the type of data available in the input file
function FileTag = GetFileTag(FileName)
    FileType = file_gettype(FileName);
    switch(FileType)
        case 'data'
            if ~isempty(strfind(FileName, '_0raw'))
                FileTag = 'data_0raw';
            else
                FileTag = 'data';
            end
        case {'results', 'link'}
            FileTag = 'results';
        case {'timefreq', 'ptimefreq'}
            FileTag = FileType;
            listTags = {'_fft', '_psd', '_hilbert', ...
                        '_connect1_corr', '_connect1_cohere', '_connect1_granger', '_connect1_spgranger', '_connect1_plv', '_connect1_plvt', '_connect1', ...
                        '_connectn_corr', '_connectn_cohere', '_connectn_granger', '_connectn_spgranger', '_connectn_plv', '_connectn_plvt', '_connectn', ...
                        '_pac_fullmaps', '_pac', '_dpac_fullmaps', '_dpac'};
            for i = 1:length(listTags)
                if ~isempty(strfind(FileName, listTags{i}))
                    FileTag = [FileType, listTags{i}];
                    break;
                end
            end
        otherwise
            FileTag = FileType;
    end
end


%% ===== LOAD INPUT FILE =====
% USAGE:  [sInput, nSignals, iRows] = bst_process('LoadInputFile', FileName, Target=[], TimeWindow=[], OPTIONS=[])
%                           OPTIONS = bst_process('LoadInputFile');
function [sInput, nSignals, iRows] = LoadInputFile(FileName, Target, TimeWindow, OPTIONS)
    % Default options
    defOPTIONS = struct(...
        'LoadFull',       1, ...
        'IgnoreBad',      0, ...
        'ProcessName',    'process_unknown', ...
        'TargetFunc',     [], ...          % Function to apply to the scouts, if input targe contains scouts
        'isNorm',         0, ...           % Take the norm of three orientations for scouts
        'RemoveBaseline', 'all', ...
        'UseSsp',         1);              % When reading from continuous files: 
    nSignals = 0;
    iRows = [];
    % Return default options structure
    if (nargin == 0)
        sInput = defOPTIONS;
        return;
    elseif (nargin < 4) || isempty(OPTIONS)
        OPTIONS = defOPTIONS;
    else
        OPTIONS = struct_copy_fields(OPTIONS, defOPTIONS, 0);
    end
    % Other defaults
    if (nargin < 3) || isempty(TimeWindow)
        TimeWindow = [];
    end
    if (nargin < 2) || isempty(Target)
        Target = [];
    end
    % Initialize returned variables
    sInput = struct(...
        'Data',          [], ...
        'ImagingKernel', [], ...
        'RowNames',      [], ...
        'Time',          [], ...
        'DataType',      [], ...
        'Comment',       [], ...
        'iStudy',        [], ...
        'Atlas',         [], ...
        'SurfaceFile',   [], ...
        'HeadModelFile', [], ...
        'HeadModelType', [], ...
        'GridLoc',       [], ...
        'GridAtlas',     [], ...
        'nComponents',   [], ...
        'nAvg',          1, ...
        'Leff',          1, ...
        'Freqs',         []);
    % Find file in database
    [sStudy, sInput.iStudy, iFile, sInput.DataType] = bst_get('AnyFile', FileName);
    
    % ===== LOAD SCOUT =====
    % Load scouts time series (Target = scout structure or list)
    if ~isempty(Target) && (isstruct(Target) || iscell(Target))
        % Add row name only when extracting all the scouts
        AddRowComment = ~isempty(OPTIONS.TargetFunc) && strcmpi(OPTIONS.TargetFunc, 'all');
        % Flip sign only for results
        isflip = ismember(sInput.DataType, {'link','results'});
        % Call process
        sMat = CallProcess('process_extract_scout', FileName, [], ...
            'timewindow',     TimeWindow, ...
            'scouts',         Target, ...
            'scoutfunc',      OPTIONS.TargetFunc, ... % If TargetFunc is not defined, use the scout function available in each scout
            'isflip',         isflip, ...            
            'isnorm',         OPTIONS.isNorm, ...
            'concatenate',    0, ...
            'save',           0, ...
            'addrowcomment',  AddRowComment, ...
            'addfilecomment', 0, ...
            'progressbar',    0);
        if isempty(sMat)
            bst_report('Error', OPTIONS.ProcessName, [], 'Could not calculate the clusters time series.');
            sInput.Data = [];
            return;
        end
        sInput.Data        = sMat.Value;
        sInput.DataType    = 'matrix';
        sInput.SurfaceFile = sMat.SurfaceFile;
        sInput.Atlas       = sMat.Atlas;
        sInput.nComponents = sMat.nComponents;
        sInput.nAvg        = sMat.nAvg;
        sInput.Leff        = sMat.Leff;
        % If only non-All scouts: use just the scouts labels, if not use the full description string
        sScouts = sMat.Atlas.Scouts;
        if ~isequal(lower(OPTIONS.TargetFunc), 'all') && ~isempty(sScouts) && all(~strcmpi({sScouts.Function}, 'All'))
            sInput.RowNames = {sScouts.Label}';
        else
            sInput.RowNames = sMat.Description;
            for iRow = 1:length(sInput.RowNames)
                iAt = find(sInput.RowNames{iRow} == '@', 1);
                if ~isempty(iAt)
                    sInput.RowNames{iRow} = strtrim(sInput.RowNames{iRow}(1:iAt-1));
                end
            end
        end
        
    % ===== LOAD FILE =====
    else
        % Load file
        [sMat, matName] = in_bst(FileName, TimeWindow, OPTIONS.LoadFull, OPTIONS.IgnoreBad, OPTIONS.RemoveBaseline, OPTIONS.UseSsp);
        sInput.Data = sMat.(matName);
        % If nothing was read
        if isempty(sInput.Data)
            bst_report('Error', OPTIONS.ProcessName, FileName, 'Nothing could be read from the file. Please check the time window you selected.');
            sInput.Data = [];
            return;
        end
        % Select signal of interest
        switch (sInput.DataType)
            case 'data'
                % Get channel file
                sChannel = bst_get('ChannelForStudy', sInput.iStudy);
                % Load channel file
                ChannelMat = in_bst_channel(sChannel.FileName);
                % If channel specified, use it. If not, use all the channels
                if ~isempty(Target)
                    iRows = channel_find(ChannelMat.Channel, Target);
                    if isempty(iRows)
                        bst_report('Error', OPTIONS.ProcessName, [], ['Channel "' Target '" does not exist.']);
                        sInput.Data = [];
                        return;
                    end
                else
                    iRows = 1:length(ChannelMat.Channel);
                end
                % Ignore bad channels
                if OPTIONS.IgnoreBad && isfield(sMat, 'ChannelFlag') && ~isempty(sMat.ChannelFlag) && any(sMat.ChannelFlag == -1)
                    iGoodChan = find(sMat.ChannelFlag' == 1);
                    iRows = intersect(iRows, iGoodChan);
                end
                % If processing continuous file: reading signals
                if isstruct(sInput.Data)
                    % sFile structure
                    sFile = sInput.Data;
                    % Read required samples
                    SampleBounds = round(TimeWindow .* sFile.prop.sfreq);
                    sInput.Data = in_fread(sFile, ChannelMat, 1, SampleBounds, iRows);
                % Imported data file
                else
                    % Keep only the channels of interest
                    if (length(iRows) ~= length(ChannelMat.Channel))
                        sInput.Data = sInput.Data(iRows,:);
                    end
                end
                % Get the row names
                sInput.RowNames = {ChannelMat.Channel(iRows).Name};

            case {'results', 'link', 'presults'}
                % Norm/absolue values of the sources 
                if OPTIONS.isNorm && isfield(sMat, 'ImageGridAmp') && ~isempty(sMat.ImageGridAmp)
                    sMat = process_source_flat('Compute', sMat, 'rms');
                    sInput.Data = sMat.(matName);
                end
                % Save number of components per vertex
                sInput.nComponents = sMat.nComponents;
                % All the source indices
                if (sMat.nComponents == 0)
                    VertInd = bst_bsxfun(@times, sMat.GridAtlas.Grid2Source, 1:size(sMat.GridAtlas.Grid2Source,2));
                    AllRowNames = full(sum(VertInd,2)');
                else
                    AllRowNames = reshape(repmat(1:size(sInput.Data,1), sMat.nComponents, 1), 1, []);
                end
                % Rows are indicated with integers: indices of the sources
                if ~isempty(Target)
                    % Check Target type
                    if ischar(Target)
                        iRows = str2num(Target);
                    elseif isnumeric(Target)
                        switch (sMat.nComponents)
                            case 0,  iRows = bst_convert_indices(Target, sMat.nComponents, sMat.GridAtlas, 0);
                            case 1,  iRows = Target;
                            case 2,  iRows = 2*Target + [-1 0];
                            case 3,  iRows = 3*Target + [-2 -1 0];
                        end
                    end
                    % Check rows
                    if isempty(iRows) || any(iRows > size(sInput.Data,1))
                        bst_report('Error', OPTIONS.ProcessName, [], 'Invalid sources selection.');
                        sInput.Data = [];
                        return;
                    end
                    % Keep only the sources of interest
                    sInput.Data = sInput.Data(iRows,:);
                else
                    % Keep all the sources
                    iRows = 1:size(sInput.Data,1);
                end
                % Row names = indices
                sInput.DataType = 'results';
                % Copy recordings in case of kernel+recordings file
                if strcmpi(matName, 'ImagingKernel') && isfield(sMat, 'F') && ~isempty(sMat.F)
                    sInput.ImagingKernel = sInput.Data;
                    sInput.Data = sMat.F;
                end
                % Get the associated surface
                sInput.SurfaceFile = sMat.SurfaceFile;
                sInput.GridLoc = sMat.GridLoc;
                sInput.GridAtlas = sMat.GridAtlas;
                % Copy atlas if it exists
                if isfield(sMat, 'Atlas') && ~isempty(sMat.Atlas)
                    sInput.Atlas = sMat.Atlas;
                    sInput.RowNames = {sMat.Atlas.Scouts(iRows).Label};
                else
                    sInput.Atlas = [];
                    sInput.RowNames = AllRowNames(iRows);
                end
                % Copy head model if it exists
                if isfield(sMat, 'HeadModelFile') && ~isempty(sMat.HeadModelFile)
                    sInput.HeadModelFile = sMat.HeadModelFile;
                    sInput.HeadModelType = sMat.HeadModelType;
                else
                    sInput.HeadModelFile = [];
                    sInput.HeadModelType = [];
                end
                
            case 'timefreq'
                % Find target rows
                if ~isempty(Target)
                    RowNames = strtrim(str_split(Target, ',;'));
                    iRows = find(ismember(sMat.RowNames, RowNames));
                    if isempty(iRows)
                        bst_report('Error', OPTIONS.ProcessName, [], 'Invalid rows selection.');
                        sInput.Data = [];
                        return;
                    end
                    sInput.Data = sInput.Data(iRows,:,:);
                else
                    iRows = 1:size(sInput.Data,1);
                end
                % Get the row names
                sInput.RowNames = sMat.RowNames(iRows);
                sInput.DataType = sMat.DataType;
                % Copy surface file
                if isfield(sMat, 'SurfaceFile') && ~isempty(sMat.SurfaceFile)
                    sInput.SurfaceFile = sMat.SurfaceFile;
                end
                if ~isempty(sMat.GridLoc)
                    sInput.GridLoc = sMat.GridLoc;
                end
                if ~isempty(sMat.GridAtlas)
                    sInput.GridAtlas = sMat.GridAtlas;
                end
                if isfield(sMat, 'Freqs') && ~isempty(sMat.Freqs)
                    sInput.Freqs = sMat.Freqs;
                end
                
            case 'matrix'
                % Scouts time series: remove everything after the @
                for iDesc = 1:numel(sMat.Description)
                    iAt = find(sMat.Description{iDesc} == '@', 1);
                    if ~isempty(iAt)
                        sMat.Description{iDesc} = strtrim(sMat.Description{iDesc}(1:iAt-1));
                    end
                end
                % Select target rows
                if ~isempty(Target) && (size(sMat.Description,2) == 1)
                    % Check Target type
                    if ischar(Target)
                        % Look for the row by name
                        iRows = find(strcmpi(sMat.Description, Target));
                        % If nothing found: look for the row by index
                        if isempty(iRows)
                            iRows = str2num(Target);
                        end
                    elseif isnumeric(Target)
                        iRows = Target;
                    end
                    % Nothing found, definitely: error
                    if isempty(iRows) || (max(iRows) > size(sInput.Data,1))
                        bst_report('Error', OPTIONS.ProcessName, [], ['Row "' Target '" does not exist.']);
                        sInput.Data = [];
                        return;
                    end
                    % Keep only the rows of interest
                    sInput.Data = sInput.Data(iRows,:);
                else
                    iRows = 1:size(sMat.Description,1);
                end
                % Get the row names
                sInput.RowNames = sMat.Description(iRows,:);
                sInput.DataType = 'matrix';
                % Copy surface/scout information if it exists
                if isfield(sMat, 'SurfaceFile') && ~isempty(sMat.SurfaceFile)
                    sInput.SurfaceFile = sMat.SurfaceFile;
                end
                if isfield(sMat, 'Atlas') && ~isempty(sMat.Atlas)
                    sInput.Atlas = sMat.Atlas;
                end
                
            otherwise
                error('todo');
        end
    end
    % Other values to return
    sInput.Time    = sMat.Time;
    sInput.Comment = sMat.Comment;
    if isfield(sMat, 'nAvg') && ~isempty(sMat.nAvg)
        sInput.nAvg = sMat.nAvg;
    else
        sInput.nAvg = 1;
    end
    if isfield(sMat, 'Leff') && ~isempty(sMat.Leff)
        sInput.Leff = sMat.Leff;
    else
        sInput.Leff = 1;
    end
    % Count output signals
    if ~isempty(sInput.ImagingKernel) 
        nSignals = size(sInput.ImagingKernel, 1);
    else
        nSignals = size(sInput.Data, 1);
    end
end


%% ===== LOAD SCOUTS =====
% USAGE:  ScoutsStruct = bst_process('LoadScouts', FileNames, ScoutSel, ScoutFunc, TimeWindow=[])
function ScoutsStruct = LoadScouts(FileNames, ScoutSel, ScoutFunc, TimeWindow)
    % Options for LoadInputFile()
    LoadOptions.LoadFull    = 1;    % Load full source results
    LoadOptions.IgnoreBad   = 1;    % Do not read bad segments
    LoadOptions.ProcessName = [];
    LoadOptions.TargetFunc  = ScoutFunc;
    LoadOptions.isNorm      = 1;
    % Initialize list of files
    ScoutsStruct = cell(1,length(FileNames));
    % Read files sequentially
    for i = 1:length(FileNames)
        % Set progress bar
        bst_progress('text', sprintf('Loading scouts...  [%d/%d]', i, length(FileNames)));
        % Load scout values
        sMat = LoadInputFile(FileNames{i}, ScoutSel, TimeWindow, LoadOptions);
        % Prepare structure to return
        sMat.Value = sMat.Data;
        sMat = rmfield(sMat, 'Data');
        ScoutsStruct{i} = sMat;
    end
end


%% ===== CALL PROCESS =====
% USAGE:  OutputFiles = bst_process('CallProcess', sProcess,    sInputs,   sInputs2,   OPTIONS)
%         OutputFiles = bst_process('CallProcess', sProcess,    FileNames, FileNames2, OPTIONS)
%         OutputFiles = bst_process('CallProcess', ProcessName, sInputs,   sInputs2,   OPTIONS)
%         OutputFiles = bst_process('CallProcess', ProcessName, FileNames, FileNames2, OPTIONS)
%         [OutputFiles, OutputFiles2] = bst_process('CallProcess', ...)
function [OutputFiles, OutputFiles2, sInputs, sInputs2] = CallProcess(sProcess, sInputs, sInputs2, varargin)
    % Check if Brainstorm is running
    if ~isappdata(0, 'BrainstormRunning')
        error('Please start Brainstorm before calling bst_process().');
    end
    % Get process
    if ischar(sProcess)
        FunctionName = sProcess;
        sProcess = panel_process_select('GetProcess', FunctionName);
        % Process not found in registered processes
        if isempty(sProcess)
            % Try to look somewhere else in the path
            sProcess = panel_process_select('LoadExternalProcess', FunctionName);
            % Not found
            if isempty(sProcess)
                error('Unknown process.');
            end
        end
    end
    % Get files
    if isempty(sInputs) || isequal(sInputs, {''})
        % If no inputs, but the process requires input files: error
        if (sProcess.nMinFiles > 0)
            bst_report('Error', sProcess, [], 'No input.');
            OutputFiles = [];
            return;
        % Else: input is import
        else
            sInputs = db_template('importfile');
        end
    elseif ~isstruct(sInputs)
        sInputs = GetInputStruct(sInputs);
    end
    % Get files
    if ~isempty(sInputs2) && ~isstruct(sInputs2)
        sInputs2 = GetInputStruct(sInputs2);
    end
    % Remove the options that are not matching the type of the inputs
    if isfield(sProcess, 'options') && ~isempty(sProcess.options) && isstruct(sProcess.options)
        optNames = fieldnames(sProcess.options);
        for iOpt = 1:length(optNames)
            if ~isfield(sProcess.options.(optNames{iOpt}), 'InputTypes')
                continue;
            elseif ismember(sInputs(1).FileType, sProcess.options.(optNames{iOpt}).InputTypes)
                continue;
            elseif ~isempty(sInputs2) && ismember(sInputs2(1).FileType, sProcess.options.(optNames{iOpt}).InputTypes)
                continue;
            else
                sProcess.options = rmfield(sProcess.options, optNames{iOpt});
            end
        end
    end
    % Get options
    for i = 1:2:length(varargin)
        if ~ischar(varargin{i})
            error('Invalid options.');
        end
        % Get default and new values
        if isfield(sProcess.options, varargin{i}) && isfield(sProcess.options.(varargin{i}), 'Value')
            defVal = sProcess.options.(varargin{i}).Value;
        else
            defVal = [];
        end
        if isfield(sProcess.options, varargin{i}) && isfield(sProcess.options.(varargin{i}), 'Type')
            defType = sProcess.options.(varargin{i}).Type;
        else
            defType = '';
        end
        newVal = varargin{i+1};
        updateVal = defVal;
        %  Simple "value" type call: just the value instead of the cell list
        if ~isempty(defVal) && iscell(defVal) && isnumeric(newVal)
            updateVal{1} = newVal;
        elseif ismember(lower(defType), {'timewindow','baseline','poststim','value','range','freqrange','freqrange_static'}) && isempty(defVal) && ~isempty(newVal) && ~iscell(newVal)
            updateVal = {newVal, 's', []};
        elseif ismember(lower(defType), {'timewindow','baseline','poststim','value','range','freqrange','freqrange_static','combobox'}) && iscell(defVal) && ~isempty(defVal) && ~iscell(newVal) && ~isempty(newVal)
            updateVal{1} = newVal;
        % Generic call: just copy the value
        else
            updateVal = newVal;
        end
        % Save the finale value
        sProcess.options.(varargin{i}).Value = updateVal;
    end
    % Absolute values of sources
    if isfield(sProcess.options, 'source_abs') && ~isempty(sProcess.options.source_abs) && ~isempty(sProcess.options.source_abs.Value)
        sProcess.isSourceAbsolute = sProcess.options.source_abs.Value;
    elseif (sProcess.isSourceAbsolute < 0)
        sProcess.isSourceAbsolute = 0;
    elseif (sProcess.isSourceAbsolute > 1)
        sProcess.isSourceAbsolute = 1;
    end
    % Record process
    if ~(isfield(sProcess.options, 'save') && isfield(sProcess.options.save, 'Value') && ~isempty(sProcess.options.save.Value) && ~sProcess.options.save.Value)
        if ~isempty(sInputs2)
            bst_report('Process', sProcess, {sInputs, sInputs2});
        else
            bst_report('Process', sProcess, sInputs);
        end
    end
    % Call process
    if (sProcess.nOutputs == 2)
        [OutputFiles, OutputFiles2] = Run(sProcess, sInputs, sInputs2, 0);
    else
        OutputFiles = Run(sProcess, sInputs, sInputs2, 0);
        OutputFiles2 = [];
    end
end


%% ===== CREATE OUTPUT RAW FILE =====
function [sFileOut, errMsg] = CreateRawOut(sFileIn, RawFileOut, ImportOptions, isForceCopy)
    % Parse inputs
    if (nargin < 4) || isempty(isForceCopy)
        isForceCopy = 0;
    end
    % Copy input file structure
    sFileOut = sFileIn;
    errMsg = [];
    % Switch based on file format
    switch (sFileIn.format)
        case 'FIF'
            % Define output filename
            sFileOut.filename = RawFileOut;
            % Copy in file to out file
            res = file_copy(sFileIn.filename, sFileOut.filename);
            if ~res
                error(['Could not create output file: ' sFileOut.filename]);
            end
            
        case {'CTF', 'CTF-CONTINUOUS'}
            % Output is forced to 3rd order gradient
            if ImportOptions.UseCtfComp
                sFileOut.prop.currCtfComp = 3;
                sFileOut.header.grad_order_no = 3 * ones(size(sFileOut.header.grad_order_no));
            end
            % File output has to be ctf-continuous
            sFileOut.format = 'CTF-CONTINUOUS';
            % Input dataset name
            [dsPath, dsNameIn, dsExt] = bst_fileparts(bst_fileparts(sFileIn.filename));
            pathIn = bst_fullfile(dsPath, [dsNameIn, dsExt]);
            % Output dataset name
            pathOut = RawFileOut;
            [tmp__, dsNameOut, dsExt] = bst_fileparts(pathOut);
            % Make sure that folder does not exist yet
            if isdir(pathOut)
                errMsg = ['Output folder already exists: ' pathOut];
                sFileOut = [];
                return;
            end
            % Create new folder
            res = mkdir(pathOut);
            if ~res
                errMsg = ['Could not create output folder: ' pathOut];
                sFileOut = [];
                return;
            end
            % Copy each file of original ds folder
            dirDs = dir(bst_fullfile(pathIn, '*'));
            for iFile = 1:length(dirDs)
                % Some filenames to skip
                if ismember(dirDs(iFile).name, {'.', '..', 'hz.ds'})
                    continue;
                end
                % Some extensions to process differently
                [tmp__, fName, fExt] = bst_fileparts(dirDs(iFile).name);
                switch (fExt)
                    case '.ds'
                        % Ignore the sub-folders (ex: hz.ds)
                        continue;

                    case {'.meg4','.1_meg4','.2_meg4','.3_meg4','.4_meg4','.5_meg4','.6_meg4','.7_meg4','.8_meg4','.9_meg4'}
                        destfile = bst_fullfile(pathOut, [dsNameOut, fExt]);
                        % If file is the .meg4, set it as the file referenced in the sFileIn structure
                        if strcmpi(fExt, '.meg4')
                            sFileOut.filename = destfile;
                        end
                        % All the other .res4: replace the name in the meg4_files cell array
                        iMeg4 = find(~cellfun(@(c)isempty(strfind(c, fExt)), sFileOut.header.meg4_files));
                        if (length(iMeg4) ~= 1)
                            errMsg = 'Multiple .res4 files in the .ds folder. Cannot process.';
                            sFileOut = [];
                            return;
                        end
                        sFileOut.header.meg4_files{iMeg4} = destfile;
                        % Create empty file (with header), do not copy initial file
                        if ~isForceCopy
                            sfid = fopen(destfile, 'w+');
                            fwrite(sfid, ['MEG41CP' 0], 'char');
                            fclose(sfid);
                            destfile = [];
                        % Make a full copy of the file
                        else
                            % Just keep destfile variable, and the next block will copy the file
                        end
                    case {'.acq','.hc','.hist','.infods','.newds','.res4'}
                        % Copy file, force the name to be the DS name
                        destfile = bst_fullfile(pathOut, [dsNameOut, fExt]);
                        
                    otherwise
                        % Copy file, keep initial filename
                        destfile = bst_fullfile(pathOut, dirDs(iFile).name);
                end
                % Copy file, replacing the name of the DS
                if ~isempty(destfile)
                    res = file_copy(bst_fullfile(pathIn, dirDs(iFile).name), destfile);
                    if ~res
                        errMsg = ['Could not create output file: ' destfile];
                        sFileOut = [];
                        return;
                    end
                end
            end
            % Delete epochs description
            if ~isempty(sFileOut) && isfield(sFileOut, 'epochs')
                sFileOut.epochs = [];
            end
            
        otherwise
            errMsg = 'Unsupported file format (only continuous FIF and CTF files can be processed).';
            sFileOut = [];
            return;
    end
end


%% ===== GET DEFAULT EPOCH SIZE =====
function N = GetDefaultEpochSize(sFile) %#ok<DEFNU>
    % Get the default of the current file
    switch (sFile.format)
        case 'FIF'
            if isfield(sFile.header, 'raw') && isfield(sFile.header.raw, 'rawdir') && ~isempty(sFile.header.raw.rawdir)
                N = double(sFile.header.raw.rawdir(1).nsamp);
            else
                N = round(sFile.prop.sfreq);
            end
        case {'CTF', 'CTF-CONTINUOUS'}
            N = double(sFile.header.gSetUp.no_samples);
        case 'BST-BIN'
            N = double(sFile.header.epochsize);
        otherwise
            N = round(sFile.prop.sfreq);
    end
    % Limit to a maximum epoch size
    N = min(N, 5000);
end


%% ===== OPTIMIZE PIPELINE =====
function sProcesses = OptimizePipeline(sProcesses)
    % Find an import process
    iImport = [];
    for i = 1:length(sProcesses)
        if ismember(func2str(sProcesses(i).Function), {'process_import_data_epoch', 'process_import_data_time', 'process_import_data_event'})
            iImport = i;
            break;
        end
    end
    % If there is no import pipeline: exit
    if isempty(iImport)
        return;
    end
    % Loop on the processes that can be glued to this one
    iRemove = [];
    for iProcess = (iImport+1):length(sProcesses)
        % List of accepted processes: copy options
        switch (func2str(sProcesses(iProcess).Function))
            case 'process_baseline'
                sProcesses(iImport).options.baseline = sProcesses(iProcess).options.baseline;
                % Ignoring sensors selection
                if isfield(sProcesses(iProcess).options, 'sensortypes') && ~isempty(sProcesses(iProcess).options.sensortypes.Value)
                    strWarning = [10 ' - Sensor selection is ignored, baseline is removed from all the data channels.'];
                else
                    strWarning = '';
                end
            case 'process_resample'
                sProcesses(iImport).options.freq = sProcesses(iProcess).options.freq;
                strWarning = '';
            otherwise
                break;
        end
        % Force overwrite
        if isfield(sProcesses(iProcess).options, 'overwrite') && ~sProcesses(iProcess).options.overwrite.Value
            strWarning = [strWarning 10 ' - Forcing overwrite option: Intermediate files are not saved in the database.'];
        end
        % Merge processes
        iRemove(end+1) = iProcess;
        % Issue message in the report
        bst_report('Info', sProcesses(iProcess), [], ['Process "' sProcesses(iProcess).Comment '" has been merged with process "' sProcesses(iImport).Comment '".' strWarning]);
    end
    % Remove the processes that were included somewhere else
    if ~isempty(iRemove)
        sProcesses(iRemove) = [];
    end
end


%% ===== OPTIMIZE PIPELINE: REVERT =====
% Re-expand optimized pipeline to the original list of processes
function sProcesses = OptimizePipelineRevert(sProcesses) %#ok<DEFNU>
    % Find an import process
    iImport = [];
    for i = 1:length(sProcesses)
        if ismember(func2str(sProcesses(i).Function), {'process_import_data_epoch', 'process_import_data_time', 'process_import_data_event'})
            iImport = i;
            break;
        end
    end
    % If there is no import pipeline: exit
    if isempty(iImport)
        return;
    end
    % Check some options to convert to other processes
    sProcAdd = repmat(db_template('processdesc'), 0);
    if isfield(sProcesses(iImport).options, 'baseline') && isfield(sProcesses(iImport).options.baseline, 'Value') && ~isempty(sProcesses(iImport).options.baseline.Value)
        % Get process
        sProcAdd(end+1).Function = @process_baseline;
        sProcAdd(end) = struct_copy_fields(sProcAdd(end), process_baseline('GetDescription'), 1);
        % Set options
        sProcAdd(end).options.sensortypes.Value = '';
        sProcAdd(end).options.baseline.Value = sProcesses(iImport).options.baseline.Value;
        % Remove option from initial process
        sProcesses(iImport).options = rmfield(sProcesses(iImport).options, 'baseline');
    end
    if isfield(sProcesses(iImport).options, 'freq') && isfield(sProcesses(iImport).options.freq, 'Value') && ~isempty(sProcesses(iImport).options.freq.Value)
        % Get process
        sProcAdd(end+1).Function = @process_resample;
        sProcAdd(end) = struct_copy_fields(sProcAdd(end), process_resample('GetDescription'), 1);
        % Set options
        sProcAdd(end).options.freq.Value = sProcesses(iImport).options.freq.Value;
        % Remove option from initial process
        sProcesses(iImport).options = rmfield(sProcesses(iImport).options, 'freq');
    end
    % Add to process list
    sProcesses = [sProcesses(1:iImport), sProcAdd, sProcesses(iImport+1:end)];
end


%% ===== SAVE RAW FILE =====
function [MatFile, errMsg] = SaveRawFile(sFileIn, ChannelMat, studyPath, DateOfStudy, Comment, History) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 4) || isempty(DateOfStudy)
        DateOfStudy = [];
    end
    if (nargin < 5) || isempty(Comment)
        Comment = 'Link to raw file';
    end
    if (nargin < 6) || isempty(History)
        History = [];
    end
    % Initialize returned variables
    MatFile = [];
    errMsg = '';
    
    % ===== OUTPUT FOLDER =====
    % Get new condition name
    [subjPath, ConditionName] = bst_fileparts(studyPath, 1);
    [tmp, SubjectName] = bst_fileparts(subjPath, 1);
    % Create output condition
    iOutputStudy = db_add_condition(SubjectName, ConditionName, [], DateOfStudy);
    if isempty(iOutputStudy)
        errMsg = ['Output folder could not be created:' 10 newPath];
        return;
    end
    % Get output study
    sOutputStudy = bst_get('Study', iOutputStudy);
    
    % ===== OUTPUT LINK .MAT =====
    % Output file name derives from the condition name
    [tmp, rawBaseOut, rawBaseExt] = bst_fileparts(studyPath);
    rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
    % Full file name
    MatFile = bst_fullfile(studyPath, ['data_0raw_' rawBaseOut '.mat']);

    % ===== OUTPUT RAW .BST =====
    % Full output filename
    RawFileOut = bst_fullfile(studyPath, [rawBaseOut '.bst']);
    RawFileFormat = 'BST-BIN';
    % Create an empty Brainstorm-binary file
    [sFileOut, errMsg] = out_fopen(RawFileOut, RawFileFormat, sFileIn, ChannelMat);
    % Error processing
    if isempty(sFileOut)
        MatFile = [];
        return;
    end

    % === COPY FILE CONTENTS ===
    % Get maximum size of a data block
    ProcessOptions = bst_get('ProcessOptions');
    MaxSize = ProcessOptions.MaxBlockSize;
    % Prepare import options (do not apply any modifier)
    ImportOptions = db_template('ImportOptions');
    ImportOptions.ImportMode      = 'Time';
    ImportOptions.DisplayMessages = 0;
    ImportOptions.UseCtfComp      = 0;
    ImportOptions.UseSsp          = 0;
    ImportOptions.RemoveBaseline  = 'no';
    iEpoch = 1;
    % Split in time blocks
    nChannels = length(ChannelMat.Channel);
    nTime     = round((sFileOut.prop.times(2) - sFileOut.prop.times(1)) .* sFileOut.prop.sfreq) + 1;
    BlockSize = max(floor(MaxSize / nChannels), 1);
    nBlocks   = ceil(nTime / BlockSize);
    % Loop on blocks
    for iBlock = 1:nBlocks
        bst_progress('set', round(100*iBlock/nBlocks));
        % Indices of columns to process
        SamplesBounds = round(sFileIn.prop.times(1) * sFileOut.prop.sfreq) + [(iBlock-1)*BlockSize, min(iBlock * BlockSize - 1, nTime - 1)];
        % Read one channel
        F = in_fread(sFileIn, ChannelMat, iEpoch, SamplesBounds, [], ImportOptions);
        % Write block
        sFileOut = out_fwrite(sFileOut, ChannelMat, iEpoch, SamplesBounds, [], F);
    end

    % ===== SAVE RAW LINK =====
    % Build output structure
    DataMat = db_template('DataMat');
    DataMat.F           = sFileOut;
    DataMat.Comment     = Comment;
    DataMat.ChannelFlag = sFileOut.channelflag;
    DataMat.Time        = sFileOut.prop.times;
    DataMat.DataType    = 'raw';
    DataMat.Device      = sFileOut.device;
    DataMat.History     = History;
    % Save raw link to hard drive
    bst_save(MatFile, DataMat, 'v6');
    % Register in database
    db_add_data(iOutputStudy, MatFile, DataMat);
    % Update tree display
    panel_protocols('UpdateNode', 'Study', iOutputStudy);
    
    % === OUTPUT CHANNE FILE ===
    % If no default channel file: create new channel file
    sSubject = bst_get('Subject', SubjectName);
    if (sSubject.UseDefaultChannel == 0)
        % Output channel file 
        ChannelMatOut = ChannelMat;
        % Mark the projectors as already applied to the file
        if ~isempty(ChannelMatOut.Projector)
            for iProj = 1:length(ChannelMatOut.Projector)
                if (ChannelMatOut.Projector(iProj).Status == 1)
                    ChannelMatOut.Projector(iProj).Status = 2;
                end
            end
        end
        db_set_channel(iOutputStudy, ChannelMatOut, 2, 0);
    end
end





