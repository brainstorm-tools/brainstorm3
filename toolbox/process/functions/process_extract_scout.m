function varargout = process_extract_scout( varargin )
% PROCESS_EXTRACT_SCOUT Extract scouts values.
%
% USAGE:  [sScoutsFinal, AllAtlasNames, sSurf] = process_extract_scout('GetScoutsInfo', sProcess, sInputs, SurfaceFile, AtlasList)

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
% Authors: Francois Tadel, 2010-2022

    eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Scout time series';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Extract';
    sProcess.Index       = 352;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Scouts';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results', 'timefreq'};
    sProcess.OutputTypes = {'matrix',  'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === SCOUTS
    sProcess.options.scouts.Comment = '';
    sProcess.options.scouts.Type    = 'scout';
    sProcess.options.scouts.Value   = {};
    % === UNCONSTRAINED SOURCES ===
    sProcess.options.flatten.Comment    = 'Flatten unconstrained source orientations with PCA first';
    sProcess.options.flatten.Type       = 'checkbox';
    sProcess.options.flatten.Value      = 1;
    sProcess.options.flatten.InputTypes = {'results'};
    % === SCOUT FUNCTION ===
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'; ...
                                             'mean', 'max', 'pca', 'std', 'all', ''};
    sProcess.options.scoutfunc.Type       = 'radio_linelabel';
    sProcess.options.scoutfunc.Value      = 'pca';
    sProcess.options.scoutfunc.Controller = struct('pca', 'pca', 'mean', 'notpca', 'max', 'notpca', 'std', 'notpca', 'all', 'notpca');
    % === PCA Options
    sProcess.options.pcaedit.Comment = {'panel_pca', ' PCA options: '}; 
    sProcess.options.pcaedit.Type    = 'editpref';
    sProcess.options.pcaedit.Value   = bst_get('PcaOptions'); % function that returns defaults.
    sProcess.options.pcaedit.Class   = 'pca';
    % === FLIP SIGN
    sProcess.options.isflip.Comment    = 'Flip the sign of sources with opposite directions';
    sProcess.options.isflip.Type       = 'checkbox';
    sProcess.options.isflip.Value      = 1;
    sProcess.options.isflip.InputTypes = {'results'};
    sProcess.options.isflip.Class   = 'notpca';
    % === NORM XYZ
    sProcess.options.isnorm.Comment = 'Unconstrained sources: Norm of the three orientations (x,y,z)';
    sProcess.options.isnorm.Type    = 'checkbox';
    sProcess.options.isnorm.Value   = 0;
    sProcess.options.isnorm.Hidden  = 1;
    %sProcess.options.isnorm.InputTypes = {'results'};
    %sProcess.options.isnorm.Class   = 'notpca';
    % === CONCATENATE
    sProcess.options.concatenate.Comment = 'Concatenate output in one unique matrix';
    sProcess.options.concatenate.Type    = 'checkbox';
    sProcess.options.concatenate.Value   = 1;
    sProcess.options.concatenate.Class   = 'notpca';
    % === SAVE OUTPUT
    sProcess.options.save.Comment = '';
    sProcess.options.save.Type    = 'ignore';
    sProcess.options.save.Value   = 1;
    % === ADD ROW COMMENT IN THE DESCRIPTION
    sProcess.options.addrowcomment.Comment = '';
    sProcess.options.addrowcomment.Type    = 'ignore';
    sProcess.options.addrowcomment.Value   = 1;
    % === ADD FILE COMMENT IN THE DESCRIPTION
    sProcess.options.addfilecomment.Comment = '';
    sProcess.options.addfilecomment.Type    = 'ignore';
    sProcess.options.addfilecomment.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    % Get type of data
    Comment = [sProcess.Comment, ':'];
    % Get selected scouts
    ScoutsList = sProcess.options.scouts.Value;
    % Get scouts names
    if ~isempty(ScoutsList) && iscell(ScoutsList) && (size(ScoutsList, 2) >= 2) && ~isempty(ScoutsList{1,2}) && iscell(ScoutsList{1,2})
        ScoutsNames = ScoutsList{1,2};
    elseif ~isempty(ScoutsList) && isstruct(ScoutsList)
        ScoutsNames = {ScoutsList.Label};
    else
        ScoutsNames = [];
    end
    % Format comment
    if isempty(ScoutsNames)
        Comment = [Comment, ' [no selection]'];
    else
        if (length(ScoutsNames) > 15)
            Comment = [Comment, ' [', num2str(length(ScoutsNames)), ' scouts]'];
        else
            for i = 1:length(ScoutsNames)
                Comment = [Comment, ' ', ScoutsNames{i}];
            end
        end
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Initialize returned variable
    OutputFiles = {};
    % Get scouts
    AtlasList = sProcess.options.scouts.Value;
    % Convert from older structure (keep for backward compatibility)
    if isstruct(AtlasList) && ~isempty(AtlasList)
        AtlasList = {'User scouts', {AtlasList.Label}};
    end
    % No scouts selected: exit
    if isempty(AtlasList) || ~iscell(AtlasList) || (size(AtlasList,2) < 2) || isempty(AtlasList{1,2})
        bst_report('Error', sProcess, [], 'No scout selected.');
        return;
    end
    % Override scouts function
    if ~isempty(sProcess.options.scoutfunc.Value)
        switch lower(sProcess.options.scoutfunc.Value)
            case {1, 'mean'}, ScoutFunc = 'mean';
            case {2, 'max'},  ScoutFunc = 'max';
            case {3, 'pca'},  ScoutFunc = 'pca';
            case {4, 'std'},  ScoutFunc = 'std';
            case {5, 'all'},  ScoutFunc = 'all';
            otherwise,  bst_report('Error', sProcess, [], 'Invalid scout function.');  return;
        end
    else
        ScoutFunc = [];
    end
    % Get time window
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    % Output options
    isConcatenate = sProcess.options.concatenate.Value && (length(sInputs) > 1);
    isSave = sProcess.options.save.Value;
    % If flip is not set: auto-detect and do not trigger errors
    if ~isfield(sProcess.options, 'isflip') || ~isfield(sProcess.options.isflip, 'Value') || isempty(sProcess.options.isflip.Value)
        isFlip = true;
        isFlipWarning = false;
    else
        isFlip = isequal(sProcess.options.isflip.Value, 1);
        isFlipWarning = true;
    end
    AddRowComment  = sProcess.options.addrowcomment.Value; % only applicable to 'All' scout function
    AddFileComment = sProcess.options.addfilecomment.Value; 
    % No need for file in RowName when only 1 file.
    if isempty(AddFileComment)
        if length(sInputs) == 1 && isSave
            AddFileComment = 0;
        else
            AddFileComment = 1;
        end
    end

    % Unconstrained orientations
    % Only allow norm when called without new pca flattening option.
    if isfield(sProcess.options, 'flatten') && isfield(sProcess.options.flatten, 'Value') 
        if isequal(sProcess.options.flatten.Value, 1)
            UnconstrFunc = 'pca';
        else
            UnconstrFunc = 'none';
        end
    elseif isfield(sProcess.options, 'isnorm') && isfield(sProcess.options.isnorm, 'Value') && isequal(sProcess.options.isnorm.Value, 1)
        UnconstrFunc = 'norm';
    else
        UnconstrFunc = 'none';
    end
    % Check if there actually are sources with unconstrained orientations
    if ~strcmpi(UnconstrFunc, 'none')
        % Check if there are unconstrained sources. The function only checks the first file. Other files
        % would be checked for inconsistent dimensions in bst_pca, and if so there will be an error.
        isUnconstr = ~( isempty(sInputs) || ~isfield(sInputs, 'FileType') || ~ismember(sInputs(1).FileType, {'results', 'timefreq'}) || ...
            ~any(CheckUnconstrained(sProcess, sInputs(1))) ); % any() needed for mixed models
        if isempty(isUnconstr)
            return; % Error already reported;
        end
        % No flattening needed. Avoid confusion.
        if ~isUnconstr
            UnconstrFunc = 'none';
        end
    end

    % ===== PCA =====
    % Flatten unconstrained source orientations with PCA, and save in temp files.
    % Flattening with PCA was not previously an option in this process, so we can apply it as now recommended
    % before the scout function (and with other minor improvements) even for the legacy 'pca'
    % option. Otherwise bst_scout_value as used in this file would flatten after the scout function.
    if isfield(sProcess.options, 'pcaedit') && ~isempty(sProcess.options.pcaedit) && ~isempty(sProcess.options.pcaedit.Value) 
        PcaOptions = sProcess.options.pcaedit.Value;
    else
        PcaOptions = [];
    end
    sInputToDel = [];
    if strcmpi(UnconstrFunc, 'pca')
        if isempty(PcaOptions)
            bst_report('Error', sProcess, [], 'Missing PCA options for flattening unconstrained sources.');
            return;
        end
        % sInputs are replaced by temporary files as needed by RunTempPca.
        [sInputs, isTempFiles] = RunTempPcaFlat(sProcess, PcaOptions, sInputs);
        if isTempFiles
            sInputToDel = sInputs;
        end
        % We no longer have unconstrained sources.
        UnconstrFunc = 'none';
    end

    % Scout PCA
    if strcmpi(ScoutFunc, 'pca')
        % Deprecated legacy PCA, warn. (runs in this function)
        if isSave && isempty(PcaOptions)
            disp('BST> Warning: Running deprecated legacy PCA.');
            bst_report('Warning', sProcess, sInputs, 'Missing PCA options. Running deprecated legacy PCA separately on each file/epoch, with arbitrary signs which can lead to averaging issues. See tutorial linked in PCA options panel.');
        elseif ~isempty(PcaOptions) && strcmpi(PcaOptions.Method, 'pca')
            disp('BST> Warning: Running deprecated legacy PCA.');
            bst_report('Warning', sProcess, sInputs, 'Deprecated legacy PCA selected. Runs separately on each file/epoch, with arbitrary signs which can lead to averaging issues. See tutorial linked in PCA options panel.');
            % Legacy PCA is processed like other scout functions, in this file.
            % Comment this condition to test legacy pca through bst_pca instead of extract_scout.
            % However, in bst_pca, sign and scaling are improved even for legacy 'pca'.

        % Most likely called from bst_process('LoadInputFile'), which is always missing PCA options.
        % Can be legacy pca or temp pca2023 files here.
        elseif ~isSave
            % Verify if the files are already scouts. In that case, go through usual process
            % below, which is appropriate for temporary atlas-based files that only need to be loaded.
            isAtlasBased = false;
            if strcmpi(sInputs(1).FileType, 'results')
                sResults = in_bst_results(sInputs(1).FileName, 0);
                if ~isempty(sResults.Atlas)
                    isAtlasBased = true;
                end
            end
            if ~isAtlasBased
                if ~isempty(PcaOptions) && ~strcmpi(PcaOptions.Method, 'pca')
                    % Not an expected situation through GUI
                    bst_report('Error', sProcess, sInputs, 'PCA for scouts requires saving files.');
                    CleanExit; return;
                elseif isempty(PcaOptions) || strcmpi(PcaOptions.Method, 'pca')
                    % Likely using legacy pca from other processes
                    disp('BST> Warning: Running deprecated legacy PCA.');
                    bst_report('Warning', sProcess, sInputs, 'Running deprecated legacy PCA separately on each file/epoch, with arbitrary signs which can lead to averaging issues. See tutorial linked in PCA options panel.');
                end
            end

        % PCA 2023, now fully treated in separate function
        else % implies isSave && ~isempty(PcaOptions) 
            % Run PCA scout extraction on all files and return.
            % This process always saves matrix outputs: isOutMatrix=true
            % It doesn't allow concatenating, for now. Option disabled in process GUI for PCA.
            % Other parameters fixed for PCA 2023: isFlip=true, AddRowComment=n/a, AddFileComment=true.
            OutputFiles = bst_pca(sProcess, sInputs, PcaOptions, AtlasList, true, TimeWindow);
            % Delete temporary flattened files.
            CleanExit; return;
        end
    end
    % At this stage, we have possibly already flattened temp files, or atlas-based files, or the
    % scout function is not pca or legacy pca.


    % ===== LOOP ON THE FILES =====
    for iInput = 1:length(sInputs)
        % Progress bar
        if (length(sInputs) > 1)
            if iInput == 1
                bst_progress('start', 'Extract scouts', sprintf('Extracting scouts for file: %d/%d...', iInput, length(sInputs)), 0, 100);
            else
                bst_progress('text', sprintf('Extracting scouts for file: %d/%d...', iInput, length(sInputs)));
                bst_progress('set', round(100*(iInput-1)/length(sInputs)));
            end
        end
        isAbs = ~isempty(strfind(sInputs(iInput).FileName, '_abs'));

        % === READ FILES ===
        [sResults, matSourceValues, matDataValues, fileComment] = LoadFile(sProcess, sInputs(iInput), TimeWindow);

        if isempty(sResults)
            if isConcatenate
                CleanExit; return; % Error already reported.
            else
                continue;
            end
        end
        % Check for consistency if concatenating.
        if isConcatenate
            if iInput == 1
                DisplayUnits = sResults.DisplayUnits;
                SurfaceFile = sResults.SurfaceFile;
                initTimeVector = sResults.Time;
                % Check units and surface file
            elseif ~isequal(DisplayUnits, sResults.DisplayUnits) || ~isequal(SurfaceFile, sResults.SurfaceFile)
                bst_report('Error', sProcess, sInputs(iInput), 'When concatenating, units and surface files should be the same for all files.');
                CleanExit; return;
                % Check time vectors
            elseif (length(initTimeVector) ~= length(sResults.Time))
                bst_report('Error', sProcess, sInputs(iInput), 'When concatenating, time should be the same for all files.');
                CleanExit; return;
            end
        end

        [sScoutsFinal, AllAtlasNames, sSurf, isVolumeAtlas] = GetScoutsInfo(sProcess, sInputs(iInput), ...
            sResults.SurfaceFile, AtlasList, sResults.Atlas, ScoutFunc);
        % Selected scout function now applied in GetScoutInfo (overrides the one from the scout panel).
        if isempty(sScoutsFinal)
            if isConcatenate
                CleanExit; return; % Error already reported.
            else
                continue;
            end
        end

        % === LOOP ON SCOUTS ===
        scoutValues  = [];
        scoutStd     = [];
        Description  = {};
        scoutComment = [];
        nComponents = zeros(length(sScoutsFinal), 1);
        for iScout = 1:length(sScoutsFinal)
            % Get scout name
            ScoutName = sScoutsFinal(iScout).Label;

            % === GET ROWS INDICES ===
            [iRows, RowNames, ScoutOrient, nComponents(iScout)] = GetScoutRows(sProcess, sInputs(iInput), ...
                sScoutsFinal(iScout), sResults, sSurf, isVolumeAtlas(iScout), ScoutFunc, AddRowComment);
            if isempty(iRows)
                OutputFiles = {};
                CleanExit; return; % Error already reported.
            end
            if AddFileComment && ~isempty(fileComment)
                RowNames = cellfun(@(c) [c ' @ ' fileComment], RowNames, 'UniformOutput', false);
            end

            % === GET SOURCES ===
            % Get source values for this scout. Works with full or kernel result files, including atlas-based.
            % Get all the sources values
            if ~isempty(matSourceValues)
                ScoutSourceValues = matSourceValues(iRows,:,:);
                if ~isempty(sResults.Std)
                    sourceStd = sResults.Std(iRows,:,:,:);
                else
                    sourceStd = [];
                end
            elseif (size(matDataValues,3) == 1)
                ScoutSourceValues = sResults.ImagingKernel(iRows,:) * matDataValues(sResults.GoodChannel,:);
                sourceStd = [];
            else
                % sourceValues = zeros(length(iRows), size(matDataValues,2), size(matDataValues,3));
                % for iFreq = 1:size(matDataValues,3)
                %     sourceValues(:,:,iFreq) = sResults.ImagingKernel(iRows,:) * matDataValues(:,:, iFreq);
                % end
                bst_report('Error', sProcess, sInputs(iInput), 'Kernel-based time-frequency files are not supported here.');
                OutputFiles = {};
                CleanExit; return;
            end

            % === APPLY DYNAMIC ZSCORE ===
            if isfield(sResults, 'ZScore') && ~isempty(sResults.ZScore)
                ZScore = sResults.ZScore;
                % Keep only the selected vertices
                if ~isempty(iRows) && ~isempty(ZScore.mean)
                    ZScore.mean = ZScore.mean(iRows,:);
                    ZScore.std  = ZScore.std(iRows,:);
                end
                % Calculate mean/std
                if isempty(ZScore.mean)
                    ScoutSourceValues = process_zscore_dynamic('Compute', ScoutSourceValues, ZScore, sResults.Time, sResults.ImagingKernel(iRows,:), matDataValues(sResults.GoodChannel,:,:));
                    if ~isempty(sourceStd)
                        for iBound1 = 1:size(sourceStd,4)
                            sourceStd(:,:,:,iBound1) = process_zscore_dynamic('Compute', sourceStd(:,:,:,iBound1), ZScore, sResults.Time, sResults.ImagingKernel(iRows,:), matDataValues(sResults.GoodChannel,:,:));
                        end
                    end
                    % Apply existing mean/std
                else
                    ScoutSourceValues = process_zscore_dynamic('Compute', ScoutSourceValues, ZScore);
                    if ~isempty(sourceStd)
                        for iBound1 = 1:size(sourceStd,4)
                            sourceStd(:,:,:,iBound1) = process_zscore_dynamic('Compute', sourceStd(:,:,:,iBound1), ZScore);
                        end
                    end
                end
            end

            % === COMPUTE SCOUT VALUES ===
            % For atlas-based files, we already have the scout values. 
            % GetScoutRows already warned if a different scout function was used. 
            if ~isempty(sResults.Atlas)
                scoutValues = cat(1, scoutValues, ScoutSourceValues);
                % Row names, can be multiple rows per scout for unconstrained sources.
                Description = cat(1, Description, RowNames);
                continue;
            end

            % Process differently the unconstrained sources
            isUnconstrained = (nComponents(iScout) ~= 1) && strcmpi(UnconstrFunc, 'none');
            % If the flip was requested but not a good thing to do on this file
            wrnMsg = [];
            if isFlip && isUnconstrained
                % wrnMsg = 'Sign flip was not performed: it is only necessary for constrained orientations.';
                isFlipScout = 0;
            elseif isFlip && strcmpi(sInputs(iInput).FileType, 'timefreq')
                wrnMsg = 'Sign flip was not performed: not applicable for time-frequency files.';
                isFlipScout = 0;
            elseif isFlip && isAbs
                wrnMsg = 'Sign flip was not performed: an absolute value was already applied to the source maps.';
                isFlipScout = 0;
            else
                isFlipScout = isFlip;
            end
            % Warning
            if ~isempty(wrnMsg) && isFlipWarning
                disp(['BST> ' wrnMsg '. File: ' sInputs(iInput).FileName]);
                bst_report('Info', sProcess, sInputs(iInput), wrnMsg);
            end
            % Save the name of the scout
            scoutComment = [scoutComment, ' ', ScoutName];
            % Loop on frequencies
            nFreq = size(ScoutSourceValues,3);
            for iFreq = 1:nFreq
                % Apply scout function
                tmpScout = bst_scout_value(ScoutSourceValues(:,:,iFreq), sScoutsFinal(iScout).Function, ScoutOrient, nComponents(iScout), UnconstrFunc, isFlipScout, ScoutName);
                scoutValues = cat(1, scoutValues, tmpScout);
                if ~isempty(sourceStd)
                    tmpScoutStd = [];
                    for iBound = 1:size(sourceStd,4)
                        tmp = bst_scout_value(sourceStd(:,:,iFreq,iBound), sScoutsFinal(iScout).Function, ScoutOrient, nComponents(iScout), UnconstrFunc, 0);
                        if isempty(tmpScoutStd)
                            tmpScoutStd = tmp;
                        else
                            tmpScoutStd = cat(4, tmpScoutStd, tmp);
                        end
                    end
                    scoutStd = cat(1, scoutStd, tmpScoutStd);
                end
                % Add frequency to row descriptions.
                if (nFreq > 1) && AddFileComment
                    if iscell(sResults.Freqs)
                        freqComment = [' ' sResults.Freqs{iFreq,1}];
                    else
                        freqComment = [' ' num2str(sResults.Freqs(iFreq)), 'Hz'];
                    end
                    RowNames = cellfun(@(c) [c freqComment], RowNames, 'UniformOutput', false);
                end
                Description = cat(1, Description, RowNames);
            end
        end
        % If nothing was found
        if isempty(scoutValues)
            CleanExit; return;
        end

        % === OUTPUT STRUCTURE ===
        if (iInput == 1)
            % Create structure
            newMat = db_template('matrixmat');
            newMat.Value       = [];
            newMat.ChannelFlag = ones(size(sResults.ChannelFlag));
        end
        newMat.Time = sResults.Time;
        % If the number of averaged files is defined: use it
        if isfield(sResults, 'nAvg') && ~isempty(sResults.nAvg)
            newMat.nAvg = sResults.nAvg;
        else
            newMat.nAvg = 1;
        end
        if isfield(sResults, 'Leff') && ~isempty(sResults.Leff)
            newMat.Leff = sResults.Leff;
        else
            newMat.Leff = 1;
        end
        % Concatenate new values to existing ones
        if isConcatenate
            newMat.Value       = cat(1, newMat.Value,       scoutValues);
            newMat.Description = cat(1, newMat.Description, Description);
            newMat.ChannelFlag(sResults.ChannelFlag == -1) = -1;
            if ~isempty(scoutStd)
                newMat.Std = cat(1, newMat.Std, scoutStd);
            end
        else
            newMat.Value       = scoutValues;
            newMat.Description = Description;
            newMat.ChannelFlag = sResults.ChannelFlag;
            if ~isempty(scoutStd)
                newMat.Std = scoutStd;
            end
        end
        % Save original surface file, verified consistent if concatenating
        newMat.SurfaceFile = sResults.SurfaceFile;
        % Save units, verified consistent if concatenating
        newMat.DisplayUnits = sResults.DisplayUnits;
        % Save the atlas in the file
        newMat.Atlas = db_template('atlas');
        if (size(AtlasList,1) == 1)
            newMat.Atlas.Name = AtlasList{1,1};
        else
            newMat.Atlas.Name = 'process_extract_scout';
        end
        newMat.Atlas.Scouts = sScoutsFinal;

        % === HISTORY ===
        if ~isConcatenate || (iInput == 1)
            % Re-use the history of the initial file
            newMat.History = sResults.History;
            % History: process name
            newMat = bst_history('add', newMat, 'process', FormatComment(sProcess));
        end
        % History: File name
        newMat = bst_history('add', newMat, 'process', [' - File: ' sInputs(iInput).FileName]);

        % === SAVE FILE ===
        % One file per input: save one matrix file per input file
        if ~isConcatenate
            % Comment: forced in the options
            if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
                newMat.Comment = sProcess.options.Comment.Value;
            % Comment: Process default (limit size of scout comment)
            elseif (length(sScoutsFinal) > 1) && (length(scoutComment) > 20)
                newMat.Comment = [sResults.Comment, ' | ' num2str(length(sScoutsFinal)) ' scouts'];
            elseif ~isempty(scoutComment)
                newMat.Comment = [sResults.Comment, ' | scouts (' scoutComment(2:end) ')'];
            else
                newMat.Comment = [sResults.Comment, ' | scouts'];
            end
            % Save new file in database
            if isSave
                % Output study = input study
                [sStudy, iStudy] = bst_get('Study', sInputs(iInput).iStudy);
                % Output filename
                OutFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_scout');
                % Save on disk
                bst_save(OutFile, newMat, 'v6');
                % Register in database
                db_add_data(iStudy, OutFile, newMat);
                % Out to list of output files
                OutputFiles{end+1} = OutFile;
            % Just return scout values
            else
                % Add nComponents to indicate how many components per vertex, based on all scouts
                if ~strcmpi(UnconstrFunc, 'none')
                    newMat.nComponents = 1;
                else
                    newMat.nComponents = unique(nComponents);
                    % If multiple values, indicate "mixed model" and include the GridAtlas, even though this is based on a matrix structure.
                    if numel(newMat.nComponents) > 1
                        newMat.nComponents = 0;
                        % Both results and timefreq should have these fields.
                        newMat.GridAtlas = sResults.GridAtlas;
                        newMat.GridLoc = sResults.GridLoc;
                    end
                end
                % Return structure
                if isempty(OutputFiles)
                    OutputFiles = newMat;
                else
                    OutputFiles(end+1) = newMat;
                end
            end
        end
    end

    % === SAVE FILE ===
    % Only one concatenated output matrix
    if isConcatenate
        % Get output study
        [sStudy, iStudy, Comment] = bst_process('GetOutputStudy', sProcess, sInputs);
        % Comment: forced in the options
        if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
            newMat.Comment = sProcess.options.Comment.Value;
        % Comment: Process default
        else
            newMat.Comment = [strrep(FormatComment(sProcess), ' time series', ''), ' (' Comment ')'];
        end
        % Save new file in database
        if isSave
            % Output filename
            OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_scout');
            % Save on disk
            bst_save(OutputFiles{1}, newMat, 'v6');
            % Register in database
            db_add_data(iStudy, OutputFiles{1}, newMat);
            % Just return scout values
        else
            OutputFiles = newMat;
        end
    end

%% ===== DELETE TEMP PCA FILES before exiting =====
function CleanExit
    % Delete temp PCA files.
    if ~isempty(sInputToDel)
        DeleteTempResultFiles(sProcess, sInputToDel);
    end
end

end % Run function


%% ===== LOAD INPUT FILE =====
% Accepts results (full or kernel, atlas-based ok) or timefreq of type result (not kernel, not atlas-based)
% For kernels, matSourceValues stays empty, but matDataValue is loaded.
% TimeWindow is optional and is applied to both Values matrices, and sResults.Time. 
% sResults is empty if an error occurs, after logging the error in the report.
function [sResults, matSourceValues, matDataValues, fileComment] = LoadFile(sProcess, sInputs, TimeWindow)
    % Function meant for 1 input file.
    iInput = 1;
    sResults = [];
    matDataValues = [];
    matSourceValues = [];
    fileComment = [];

    if nargin < 3 || isempty(TimeWindow)
        TimeWindow = [];
    end

    switch (sInputs(iInput).FileType)
        case 'results'
            % Load results
            sResults = in_bst_results(sInputs(iInput).FileName, 0);
            % Always load data file to recover its comment. Necessary for matrix to be identifiable in tree.
            if ~isempty(sResults.DataFile)
                sMat = in_bst(sResults.DataFile, TimeWindow);
            else
                sMat = [];
            end
            if ~isempty(sMat) && ~isempty(sMat.Comment)
                sResults.Comment = sMat.Comment;
            end
            % FULL RESULTS
            if isfield(sResults, 'ImageGridAmp') && ~isempty(sResults.ImageGridAmp)
                if nargout > 1
                    matSourceValues = sResults.ImageGridAmp;
                end
                % Drop large data field.
                sResults = rmfield(sResults, 'ImageGridAmp');
            % KERNEL ONLY
            elseif isfield(sResults, 'ImagingKernel') && ~isempty(sResults.ImagingKernel) && nargout > 1
                if isempty(sMat)
                    bst_report('Warning', sProcess, sInputs(iInput), 'Inverse kernel without associated data file.');
                else
                    matDataValues = sMat.F;
                end
                % sResults already has a copy of the sMat (data file) fields: Time, nAvg, Leff, ChannelFlag.
                matSourceValues = [];
            end
            % Keep both data file and inverse model histories, but only if not previously done, e.g. with temporary flattened result files.
            if ~isempty(sMat) && ~isempty(sMat.History) && (isempty(sResults.History) || ~isequal(sMat.History{1}, sResults.History{1}))
                sResults.History = cat(1, sMat.History, sResults.History);
            end
            % Input filename
            if isfield(sResults, 'DataFile') && ~isempty(sResults.DataFile)
                fileComment = [file_short(sResults.DataFile) '/' sInputs(iInput).Comment];
            else
                fileComment = sInputs(iInput).FileName;
            end

        case 'timefreq'
            % Load file
            sResults = in_bst_timefreq(sInputs(iInput).FileName, 0);
            if ~strcmpi(sResults.DataType, 'results')
                bst_report('Error', sProcess, sInputs(iInput), 'This file does not contain any valid cortical maps.');
                sResults = [];
                return;
            end
            % Do not accept complex values
            if strcmpi(sResults.Measure, 'none')
                bst_report('Error', sProcess, sInputs(iInput), 'Please apply a measure on these complex values first.');
                sResults = [];
                return;
            end
            % This could work if we ensure it finds all the rows correctly.
            % Error: cannot process atlas-based files
            if isfield(sResults, 'Atlas') && ~isempty(sResults.Atlas)
                bst_report('Error', sProcess, sInputs(iInput), 'Time-frequency file is already based on an atlas.');
                sResults = [];
                return;
            end
            % If this is a kernel-based result: need to load the kernel as well
            if ~isempty(strfind(sInputs(iInput).FileName, '_KERNEL_'))
                % sResults = in_bst_results(sResults.DataFile, 0);
                % matSourceValues = [];
                % matDataValues = sMat.TF;
                bst_report('Error', sProcess, sInputs(iInput), 'Kernel-based time-frequency files are not supported in this process. Please apply a measure on them first.');
                sResults = [];
                return;
            elseif nargout > 1
                matSourceValues = sResults.TF;
            end
            % Drop large data field.
            sResults = rmfield(sResults, 'TF');
            % Input filename
            fileComment = sInputs(iInput).FileName;

        otherwise
            bst_report('Error', sProcess, sInputs(iInput), 'Unsupported file type.');
            return;
    end
    % Nothing loaded
    if isempty(sResults) || (nargout > 1 && isempty(matSourceValues) && (isempty(matDataValues) || ~isfield(sResults, 'ImagingKernel') || isempty(sResults.ImagingKernel)))
        bst_report('Error', sProcess, sInputs(iInput), 'Could not load anything from the input file. Check the requested time window.');
        sResults = [];
        return;
    end
    % Do not accept time bands (unless there is only one)
    if isfield(sResults, 'TimeBands') && ~isempty(sResults.TimeBands) && ~((size(matSourceValues,2)==1) && (size(sResults.TimeBands,1)==1))
        bst_report('Error', sProcess, sInputs(iInput), 'Time bands are not supported yet by this process.');
        sResults = [];
        return;
    end
    % Add possibly missing fields
    if ~isfield(sResults, 'SurfaceFile')
        sResults.SurfaceFile = [];
    end
    if ~isfield(sResults, 'DisplayUnits')
        sResults.DisplayUnits = [];
    end
    if ~isfield(sResults, 'ChannelFlag')
        sResults.ChannelFlag = [];
    end
    if ~isfield(sResults, 'History')
        sResults.History = {};
    end
    % Atlas-based files, add field if missing for later check.
    if ~isfield(sResults, 'Atlas')
        sResults.Atlas = [];
    end
    % Replicate if no time
    if (length(sResults.Time) == 1)
        sResults.Time = [0,1];
    elseif isempty(sResults.Time)
        bst_report('Error', sProcess, sInputs(iInput), 'Invalid time selection.');
        sResults = [];
        return;
    end
    if ~isempty(matSourceValues) && (size(matSourceValues,2) == 1)
        matSourceValues = [matSourceValues, matSourceValues];
        if ~isempty(sResults.Std)
            sResults.Std = [sResults.Std, sResults.Std];
        end
    elseif ~isempty(matDataValues) && (size(matDataValues,2) == 1)
        matDataValues = [matDataValues, matDataValues];
    end
    % Option: Time window
    if ~isempty(TimeWindow)
        % Get time indices
        if (length(sResults.Time) <= 2) % can only be ==2 at this point
            iTime = 1:length(sResults.Time);
        else
            iTime = panel_time('GetTimeIndices', sResults.Time, TimeWindow);
            if isempty(iTime)
                bst_report('Error', sProcess, sInputs(iInput), 'Invalid time window option.');
                sResults = [];
                return;
            end
        end
        % If only one time point selected: double it
        if (length(iTime) == 1)
            iTime = [iTime, iTime];
        end
        % Keep only the requested time window
        if ~isempty(matSourceValues)
            matSourceValues = matSourceValues(:,iTime,:);
            if ~isempty(sResults.Std)
                sResults.Std = sResults.Std(:,iTime,:,:);
            end
        % else % matDataValues already had TimeWindow applied when loading.
        end
        sResults.Time = sResults.Time(iTime);
        % If there are only two time points, make sure they are not identical
        if (length(sResults.Time) == 2) && sResults.Time(2) == sResults.Time(1)
            sResults.Time(2) = sResults.Time(1) + 0.001;
        end
    end
end


%% ===== GET SCOUTS INFO =====
% USAGE:  [sScoutsFinal, AllAtlasNames, sSurf, isVolumeAtlas] = process_extract_scout('GetScoutsInfo', sProcess, sInput, SurfaceFile, AtlasList, ResultsAtlas)
% sProcess can be empty or the process name, only used for bst_report.
% sInput is only needed if SurfaceFile is missing. We assume all inputs use the same surface.
% ResultsAtlas is only used for (deprecated or temporary) atlas-based result files.
% AllAtlasNames and isVolumeAtlas have the same length as the scout list sScoutFinal.
% sScoutsFinal is empty if an error occurs, after logging the error in the report.
function [sScoutsFinal, AllAtlasNames, sSurf, isVolumeAtlas] = GetScoutsInfo(sProcess, sInputs, SurfaceFile, AtlasList, ResultsAtlas, ScoutFunc)

    sScoutsFinal  = [];
    AllAtlasNames = {};
    isVolumeAtlas = [];
    sSurf = [];

    if nargin < 6 || isempty(ScoutFunc)
        ScoutFunc = [];
    end
    if nargin < 5 || isempty(ResultsAtlas)
        ResultsAtlas = [];
    end
    % Convert from older structure (keep for backward compatibility)
    if isstruct(AtlasList) && ~isempty(AtlasList)
        AtlasList = {'User scouts', {AtlasList.Label}};
    end
    % No scouts selected: exit
    if isempty(AtlasList) || ~iscell(AtlasList) || (size(AtlasList,2) < 2) || isempty(AtlasList{1,2})
        bst_report('Error', sProcess, [], 'No scout selected.');
        return;
    end

    % === LOAD SURFACE ===
    % Surface file not defined in the file
    if isempty(SurfaceFile)
        % Get input subject
        if isempty(sInputs)
            bst_report('Error', sProcess, sInputs, 'sInputs or SurfaceFile are required.');
            return;
        end
        sSubject = bst_get('Subject', sInputs(1).SubjectFile);
        % Error: no default cortex
        if isempty(sSubject.iCortex) || (sSubject.iCortex > length(sSubject.Surface))
            bst_report('Error', sProcess, sInputs, ['Invalid surface file: ' SurfaceFile]);
            return;
        else
            bst_report('Warning', sProcess, sInputs, 'Surface file not specified, using the default cortex for this subject.');
        end
        % Get default cortex surface
        SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
    end
    % Load surface
    sSurf = in_tess_bst(SurfaceFile);
    if isempty(sSurf) || ~isfield(sSurf, 'Atlas')
        bst_report('Error', sProcess, sInputs, ['Invalid surface file: ' SurfaceFile]);
        return;
    end

    % === LOOP ON SCOUTS ===
    sScoutsFinal = [];
    % Loop on all the atlases in the list
    for iAtlas = 1:size(AtlasList, 1)
        % Get the index of the atlas in the surface
        AtlasName = AtlasList{iAtlas,1};
        % Is this a volume atlas?
        isVolume = panel_scout('ParseVolumeAtlas', AtlasName);
        iAtlasSurf = find(strcmpi(AtlasList{iAtlas,1}, {sSurf.Atlas.Name}));
        % Loop on the scouts selected for this atlas
        for iScout = 1:length(AtlasList{iAtlas,2})
            sScout = [];
            % Get scout name
            ScoutName = AtlasList{iAtlas,2}{iScout};

            % === ATLAS-BASED FILES ===
            % Optionally check for these types of files.  From deprecated process or temporary files from scout PCA
            if ~isempty(ResultsAtlas)
                % Try to find the requested scout in the file
                iScoutRes = find(strcmpi(ScoutName, {ResultsAtlas(1).Scouts.Label}));
                % Multiple scouts with the same name in an atlas: Error
                if (length(iScoutRes) > 1)
                    bst_report('Error', sProcess, sInputs, ['File is already based on an atlas, but multiple scouts with name "' ScoutName '" found.']);
                    sScoutsFinal = [];
                    return;
                % If the scout names cannot be found: error
                elseif isempty(iScoutRes)
                    bst_report('Error', sProcess, sInputs, ['File is already based on an atlas, but scout "' ScoutName '" not found.']);
                    sScoutsFinal = [];
                    return;
                else
                    sScout = ResultsAtlas(1).Scouts(iScoutRes);
                end
            end

            % === FIND SCOUT NAMES IN SURFACE ATLASES ===
            % Search in selected atlas
            if isempty(sScout) && ~isempty(iAtlasSurf)
                % Search for scout name
                iScoutSurf = find(strcmpi(ScoutName, {sSurf.Atlas(iAtlasSurf).Scouts.Label}));
                % Multiple scouts with the same name in an atlas: Error
                if (length(iScoutSurf) > 1)
                    bst_report('Error', sProcess, sInputs, ['Multiple scouts have the name "' ScoutName '" in atlas "' AtlasName '", please fix this error.']);
                    sScoutsFinal = [];
                    return;
                % Scout was found
                elseif ~isempty(iScoutSurf)
                    sScout = sSurf.Atlas(iAtlasSurf).Scouts(iScoutSurf);
                end
            end
            % If either the selected atlas or the selected scout was not found: search in all the atlases
            if isempty(sScout)
                iAllAtlas = [];
                iAllScout = [];
                % Search all the other atlases
                for ia = 1:length(sSurf.Atlas)
                    if isempty(sSurf.Atlas(ia).Scouts)
                        continue;
                    end
                    % Search for scout name
                    iScoutSurf = find(strcmpi(ScoutName, {sSurf.Atlas(ia).Scouts.Label}));
                    % Multiple scouts with the same name in an atlas: Error
                    if (length(iScoutSurf) > 1)
                        bst_report('Error', sProcess, sInputs, ['Multiple scouts have the same name in atlas "' sSurf.Atlas(iAtlasSurf).Name '", please fix this error.']);
                        sScoutsFinal = [];
                        return;
                        % Scout was found
                    elseif ~isempty(iScoutSurf)
                        iAllAtlas(end+1) = ia;
                        iAllScout(end+1) = iScoutSurf;
                    end
                end
                % If the scout name was found in multiple atlases: Error
                if (length(iAllAtlas) > 1)
                    bst_report('Error', sProcess, sInputs, ['Scout "' ScoutName '" was not found in selected atlas "' AtlasName '", but exists in multiple other atlases. Please select the atlas you want to use.']);
                    sScoutsFinal = [];
                    return;
                    % Scout name was found in only one atlas: Use it with a warning
                elseif ~isempty(iAllAtlas)
                    bst_report('Warning', sProcess, sInputs, ['Scout "' ScoutName '" was not found in selected atlas "' AtlasName '". Using the one that was found in atlas "' sSurf.Atlas(iAllAtlas).Name '".']);
                    sScout = sSurf.Atlas(iAllAtlas).Scouts(iAllScout);
                end
            end
            % Scout was not found: Error
            if isempty(sScout)
                bst_report('Error', sProcess, sInputs, ['Scout "' ScoutName '" was not found in any atlas saved in the surface.']);
                sScoutsFinal = [];
                return;
            end
            % If provided, overwrite scout function from scout panel by process selection.
            if ~isempty(ScoutFunc)
                sScout.Function = ScoutFunc;
            end
            % Add to the list of selected scouts
            if isempty(sScoutsFinal)
                sScoutsFinal = sScout;
            else
                sScoutsFinal(end+1) = sScout;
            end
            AllAtlasNames{end+1} = AtlasName;
            isVolumeAtlas(end+1) = isVolume;
        end
    end
end


%% ===== FIND MATCHING RESULT ROWS FOR GIVEN SCOUT =====
% USAGE:  [iRows, RowNames, ScoutOrient, nComponents] = process_extract_scout('GetScoutRows', sProcess, sInput, sScout, sResults, sSurf, isVolumeAtlas, ScoutFunc, AddRowVertices)
% ScoutOrient is only used for "sign flipping" (based on anatomy) when combining sources with constrained orientations.
% iRows: indices into the result array (full or kernel) BEFORE applying the scout function. It is empty if an error occurs, after logging the error in the report.
% nComponents: always 1 or 3. If a scout spans multiple regions, an error is returned.
% RowNames: (nx1) cell array of strings of the form 'ScoutName[.Vert][.Comp]' depending on the options. 
%          Its length matches the number of rows AFTER scout extraction, so only = length(iRows) for ScoutFunc='All', otherwise 1 or 3.
% ScoutFunc: used for RowNames and to warn if a scout in an atlas-based result file was computed with a different function.
% AddRowVertices: adds vertex index to RowNames but only for 'All' scout function, default true.
%
% This function supports atlas-based mixed-model result files, now possibly created in bst_pca.
function [iRows, RowNames, ScoutOrient, nComponents] = GetScoutRows(sProcess, sInput, sScout, sResults, sSurf, isVolumeAtlas, ScoutFunc, AddRowVertices)
    % Add potentially missing fields.
    if ~isfield(sResults, 'GridAtlas')
        sResults.GridAtlas = [];
    end
    if ~isfield(sResults, 'GridLoc')
        sResults.GridLoc = [];
    end
    if ~isfield(sResults, 'GridOrient')
        sResults.GridOrient = [];
    end
    if nargin < 8 || isempty(AddRowVertices)
        AddRowVertices = true;
    end
    if nargin < 7 || isempty(ScoutFunc)
        ScoutFunc = [];
    end
    RowNames = {};
    ScoutOrient = [];

    % === GET ROWS INDICES ===
    % Get the number of components per vertex
    if strcmpi(sInput.FileType, 'results')
        nComponents = sResults.nComponents;
    elseif ~isempty(sResults.GridAtlas)
        nComponents = 0;
    else
        nComponents = 1;
    end

    % Atlas-based result files: find matching scout
    if ~isempty(sResults.Atlas)
        % Atlas-based timefreq not supported for now (error when loading).
        % Find the requested scout in the file
        iScoutRes = find(strcmpi(sScout.Label, {sResults.Atlas(1).Scouts.Label}));
        % Multiple scouts with the same name in an atlas: Error
        if (length(iScoutRes) > 1)
            bst_report('Error', sProcess, sInputs, ['File is already based on an atlas, but multiple scouts with name "' sScout.Label '" found.']);
            return;
        % If the scout names cannot be found: error
        elseif isempty(iScoutRes)
            bst_report('Error', sProcess, sInputs, ['File is already based on an atlas, but scout "' sScout.Label '" not found.']);
            return;
        end
        switch nComponents 
            case 1
                iRows = iScoutRes;
            case 3
                iRows = 3 * (iScoutRes - 1) + (1:3);
            case 0
                % Get number of rows for each scout up to the requested one.
                nComp = zeros(iScoutRes,1);
                for iScout = 1:iScoutRes
                    % Find mixed-model region (GridAtlas.Scout) that overlap this scout's vertices.
                    % Volume atlases have grid indices instead of vertices.
                    if isVolumeAtlas
                        iRegionScouts = find(cellfun(@(iVert) any(ismember(sResults.Atlas(1).Scouts(iScout).Vertices, iVert)), {sResults.GridAtlas.Scouts.GridRows}));
                    else
                        iRegionScouts = find(cellfun(@(iVert) any(ismember(sResults.Atlas(1).Scouts(iScout).Vertices, iVert)), {sResults.GridAtlas.Scouts.Vertices}));
                    end
                    % Do not accept scouts that span over multiple regions
                    if isempty(iRegionScouts)
                        bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" is not included in the source model.'  10 'If you use this region as a volume, create a volume scout instead (menu Atlas > New atlas > Volume scouts).']);
                        iRows = [];
                        return;
                    elseif (length(iRegionScouts) > 1)
                        bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" spans over multiple regions of the "Source model" atlas.']);
                        iRows = [];
                        return;
                    end
                    if strcmpi(sResults.GridAtlas.Scouts(iRegionScouts).Region(3), 'C')
                        nComp(iScout) = 1;
                    else
                        nComp(iScout) = 3;
                    end
                end
                % Rows for the requested scout.
                iRows = sum(nComp(1:end-1)) + (1:nComp(end));
                % Actual components for the requested scout.
                nComponents = nComp(end);
        end
        if isempty(iRows)
            bst_report('Error', sProcess, sInputs, 'Error finding scout rows in atlas-based result file.');
            return;
        end
        % Warn if the scout function used doesn't match the one requested.
        if ~isempty(ScoutFunc) && ~strcmpi(sScout.Function, ScoutFunc)
            bst_report('Warning', sProcess, sInput, ['File is already based on an atlas, but ' sScout.Label ' was computed with scout function ' sScout.Function ' instead of ' ScoutFunc '.']);
        end
        % Still need row names.

    else
    % Sort vertex indices
    iVertices = sort(unique(sScout.Vertices));
    % Make sure this is a row vector
    iVertices = iVertices(:)';
    % Get the row and vertex or grid indices of the scout in ImageGridAmp/ImagingKernel
    % iRows includes each component for unconstrained sources (e.g. 3* number of iVertices)
    [iRows, iRegionScouts, iGrid] = bst_convert_indices(iVertices, nComponents, sResults.GridAtlas, ~isVolumeAtlas);
    % Mixed headmodel results
    if (nComponents == 0)
        % Do not accept scouts that span over multiple regions
        if isempty(iRegionScouts)
            bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" is not included in the source model.'  10 'If you use this region as a volume, create a volume scout instead (menu Atlas > New atlas > Volume scouts).']);
            iRows = [];
            return;
        elseif (length(iRegionScouts) > 1)
            bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" spans over multiple regions of the "Source model" atlas.']);
            iRows = [];
            return;
        end
        % Do not accept volume atlases with non-volume head models
        if ~isVolumeAtlas && strcmpi(sResults.GridAtlas.Scouts(iRegionScouts).Region(2), 'V')
            bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" is a surface scout but region "' sResults.GridAtlas.Scouts(iRegionScouts).Label '" is a volume region.']);
            iRows = [];
            return;
        elseif isVolumeAtlas && strcmpi(sResults.GridAtlas.Scouts(iRegionScouts).Region(2), 'S')
            bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" is a volume scout but region "' sResults.GridAtlas.Scouts(iRegionScouts).Label '" is a surface region.']);
            iRows = [];
            return;
        end
        % Set the scout computation properties based on the information in the "Source model" atlas
        if strcmpi(sResults.GridAtlas.Scouts(iRegionScouts).Region(3), 'C')
            nComponents = 1;
            if ~isempty(sResults.GridOrient)
                ScoutOrient = sResults.GridOrient(iGrid,:);
            end
        else
            nComponents = 3;
            ScoutOrient = [];
        end
    % Simple head models
    else
        % Do not accept volume atlases with non-volume head models
        if ~isVolumeAtlas && ~isempty(sResults.GridLoc)
            bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" is a surface scout but the sources are calculated on a volume grid.']);
            iRows = [];
            return;
        elseif isVolumeAtlas && isempty(sResults.GridLoc)
            bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" is a volume scout but the sources are calculated on a surface.']);
            iRows = [];
            return;
        end
        % Get the scout orientation
        if ~isVolumeAtlas && isfield(sSurf, 'VertNormals') && ~isempty(sSurf.VertNormals)
            ScoutOrient = sSurf.VertNormals(iVertices,:);
        end
    end
    end

    % Row names: cell array of 'ScoutName[.Vert][.Comp]' strings, for rows AFTER applying the scout
    % function. Add vertex index only for 'all' scout function, and component index only if
    % unconstrained.
    if strcmpi(ScoutFunc, 'All')
        nRows = numel(iRows);
        if numel(iVertices) * nComponents ~= nRows
            bst_report('Error', sProcess, sInput, sprintf('Scout "%s": %d vertices * %d components does not match %d rows.', sScout.Label, numel(iVertices), nComponents, nRows));
        end
    else
        nRows = nComponents;
    end
    RowNames = cell(nRows, 1);
    for i = 1:nRows
        RowNames{i} = sScout.Label;
        if strcmpi(ScoutFunc, 'All') && AddRowVertices
            % Add vertex index
            iVert = floor((i-1) / nComponents + 1);
            RowNames{i} = [RowNames{i} '.' num2str(iVertices(iVert))];
        end
        if nComponents > 1
            % Add unconstrained component index
            iComp = mod(i-1, nComponents) + 1;
            RowNames{i} = [RowNames{i} '.' num2str(iComp)];
        end
    end
end


%% ===== Check if any unconstrained sources =====
% isUnconstrained is true/false, or a list for mixed models.
% Only needed fields from sResults: nComponents, GridAtlas
% Provide either sInput structure (to load a file), or the already loaded sResults structure.
function [isUnconstrained, nComponents] = CheckUnconstrained(sProcess, sInputs, sResults)
    % Function meant for 1 input file, but runs ok if list.
    isUnconstrained = [];
    nComponents = [];
    if nargin < 3 || isempty(sResults)
        if isempty(sInputs)
            Message = 'CheckUnconstrained: no input file or structure provided.';
            bst_report('Error', sProcess, sInputs, Message);
            return;
        end
        if ~isfield(sInputs, 'FileType') || ~ismember(sInputs(1).FileType, {'results', 'timefreq'})
            isUnconstrained = false;
            nComponents = 1;
            Message = 'CheckUnconstrained function is only meant for results and timefreq files.';
            bst_report('Warning', sProcess, sInputs, Message);
            return;
        end
        % Load first file, without data.
        sResults = LoadFile(sProcess, sInputs(1));
        if isempty(sResults)
            return; % Error already reported.
        end
    end
    % Get the number of source orientations (components) per vertex
    if isfield(sResults, 'nComponents') && ~isempty(sResults.nComponents)
        nComponents = sResults.nComponents;
    elseif isfield(sResults, 'GridAtlas') && ~isempty(sResults.GridAtlas)
        nComponents = 0;
    else % treat as constrained, though maybe components still possible, "hidden" in timefreq.RowNames?
        nComponents = 1;
    end
    % Check each region if mixed model.
    if nComponents == 0
        if ~isfield(sResults, 'GridAtlas') || isempty(sResults.GridAtlas) || ~isfield(sResults.GridAtlas, 'Scouts') || isempty(sResults.GridAtlas.Scouts)
            Message = 'Missing mixed source model region description (GridAtlas).';
            bst_report('Error', sProcess, sInputs, Message);
            return;
        end
        isUnconstrained = arrayfun(@(Scout) ~strcmpi('C', Scout.Region(3)), sResults.GridAtlas.Scouts); % 'U' or 'L'
    else
        isUnconstrained = nComponents > 1;
    end
end


%% ===== Atlas-based result files: fix GridAtlas for reduced sources =====
% Keep one grid point per Atlas.Scout in the corresponding GridAtlas.Scouts.GridRows, and only the
% corresponding rows of GridAtlas.Grid2Source.
% sProcess, sInput optional: only for reporting errors.
function [sResults, iRegionScouts, nComp, iRows] = FixAtlasBasedGrid(sProcess, sInput, sResults)
    if nargin < 3
        error('Invalid call');
    end
    iRegionScouts = [];
    nComp = [];
    iRows = {};
    % Checks
    if isempty(sResults.Atlas)
        Message = 'FixAtlasBasedGrid only meant for atlas-based result files, but Atlas is empty.';
        bst_report('Warning', sProcess, sInput, Message);
        return;
    elseif isempty(sResults.GridAtlas)
        % Only mixed-models need fixing.
        return;
    elseif isempty(sResults.GridLoc)
        % Missing GridLoc, we'll use a reasonable number for nGrid based on kept grid rows.
        Message = 'Unexpected result structure, mixed model with GridAtlas, but missing GridLoc.';
        bst_report('Warning', sProcess, sInput, Message);
    elseif sResults.nComponents ~= 0
        % Unexpected: has GridAtlas but not a mixed model?  Fix anyway.
        Message = 'Unexpected result structure, unclear if mixed model (nComponents not 0, but GridAtlas).';
        bst_report('Warning', sProcess, sInput, Message);
    elseif numel(sResults.Atlas) > 1
        Message = 'Unexpected atlas-based result file with multiple atlases.  Converting to single atlas.';
        bst_report('Warning', sProcess, sInput, Message);
        sResults.Atlas(1).Scouts = [sResults.Atlas.Scouts];
        % Keep atlas of correct surface of volume type.
        [isVolumeAtlas, nGrid] = panel_scout('ParseVolumeAtlas', sResults.Atlas(1).Name);
        if isVolumeAtlas
            sResults.Atlas(1).Name = sprintf('Volume %d: process_extract_scout', nGrid);
        else
            sResults.Atlas(1).Name = 'process_extract_scout';
        end
        sResults.Atlas(2:end) = [];
    end
    nScout = numel(sResults.Atlas.Scouts);
    nGridRows = numel([sResults.GridAtlas.Scouts.GridRows]);
    nSource = size(sResults.GridAtlas.Grid2Source, 1);
    % Check if already fixed (first condition) and sanity check (no more source rows than 3 comp per grid rows)
    isFixed = false;
    if nGridRows == nScout && 3*nGridRows >= nSource
        % Already fixed.
        if nargout < 2
            return;
        else
            isFixed = true;
        end
    end

    % Find source model regions and the number of components (rows) for each scout.
    iRegionScouts = zeros(nScout,1);
    nComp = zeros(nScout,1);
    iRows = cell(nScout,1);
    for iScout = 1:nScout
        % Find mixed-model region (GridAtlas.Scout) that overlap this scout's vertices.
        % Volume atlases have grid indices instead of vertices.
        isVolumeAtlas = panel_scout('ParseVolumeAtlas', sResults.Atlas(1).Name);
        if isVolumeAtlas
            iRegionTmp = find(cellfun(@(iVert) any(ismember(sResults.Atlas(1).Scouts(iScout).Vertices, iVert)), {sResults.GridAtlas.Scouts.GridRows}));
        else
            iRegionTmp = find(cellfun(@(iVert) any(ismember(sResults.Atlas(1).Scouts(iScout).Vertices, iVert)), {sResults.GridAtlas.Scouts.Vertices}));
        end
        % Do not accept scouts that span over multiple regions
        if isempty(iRegionTmp)
            bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" is not included in the source model.'  10 'If you use this region as a volume, create a volume scout instead (menu Atlas > New atlas > Volume scouts).']);
            return;
        elseif (length(iRegionTmp) > 1)
            bst_report('Error', sProcess, sInput, ['Scout "' sScout.Label '" spans over multiple regions of the "Source model" atlas.']);
            return;
        else
            iRegionScouts(iScout) = iRegionTmp;
        end
        if strcmpi(sResults.GridAtlas.Scouts(iRegionScouts(iScout)).Region(3), 'C')
            nComp(iScout) = 1;
        else
            nComp(iScout) = 3;
        end
        % Rows for the requested scout.
        iRows{iScout} = sum(nComp(1:iScout-1)) + (1:nComp(iScout));
    end

    if ~isFixed
        nSource = sum(nComp);
        % Only keep one grid row per scout in the GridAtlas.
        % (But we're keeping the full grid definition in GridLoc and GridOrient.)
        iGridScouts = zeros(nScout,1);
        for iReg = 1:numel(sResults.GridAtlas.Scouts)
            % Which scouts are part of that region.
            iScout = find(iRegionScouts == iReg);
            % The actual row we keep is not meaningful.
            sResults.GridAtlas.Scouts(iReg).GridRows = sResults.GridAtlas.Scouts(iReg).GridRows(1:numel(iScout));
            iGridScouts(iScout) = sResults.GridAtlas.Scouts(iReg).GridRows;
        end
        % Recreate grid to source indicator matrix.
        nGrid = size(sResults.GridLoc, 1);
        if nGrid == 0
            % Unexpected, but use max grid row we kept.
            nGrid = max([sResults.GridAtlas.Scouts.GridRows]);
        end
        % We keep the full grid, but only one source row per scout component.
        sResults.GridAtlas.Grid2Source = logical(sparse(nSource, nGrid));
        for iScout = 1:nScout
            % For these rows, indicate the chosen grid index for that scout.
            sResults.GridAtlas.Grid2Source(iRows{iScout}, iGridScouts(iScout)) = true;
        end
    end

    % Also readjust Vert2Grid grid size which could be missing (all false) rows before.
    if size(sResults.GridAtlas.Vert2Grid, 1) < size(sResults.GridLoc, 1)
        sResults.GridAtlas.Vert2Grid(size(sResults.GridLoc, 1), end) = false;
    end
end


%% ===== SAVE PCA TO TEMPORARY RESULT FILES - FOR OTHER PROCESSES =====
% Run PCA, for unconstrained source flattening or scouts, on group of inputs as a preliminary step
% in some processes (e.g. connectivity), instead of file-by-file through bst_process('LoadInputFile')
% for other scout methods. This saves temporary result files which are then substituted as inputs to
% the calling process. These temporary files should be deleted at the very end of the process with
% DeleteTempResultFiles, defined below. Scout and PCA options should NOT be modified after using
% this function, because the temporary atlas-based files need to be loaded with
% process_extract_scout, through bst_process('LoadInputFile'), so they should still be treated as if
% scouts need to be extracted.
%
% sProcess is optional: only used for errors and can be the process name only.

% PCA flattening only
function [sInputA, isTempPcaA, sInputB, isTempPcaB] = RunTempPcaFlat(sProcess, PcaOptions, sInputA, sInputB)
    if nargin < 3
        error('Missing input arguments.');
    end
    if nargin < 4
        sInputB = [];
    end
    % Verify PCA options were provided.
    if isempty(PcaOptions)
        error('Incorrect process options for running PCA with temporary files.');
    end
    % Only set these to true after successfully creating the temp files.
    isTempPcaA = false;
    isTempPcaB = false;
    % Use these to indicate we will try to create the temp files.
    isPcaA = ~isempty(sInputA) && ismember(sInputA(1).FileType, {'results', 'timefreq'});
    isPcaB = ~isempty(sInputB) && ismember(sInputB(1).FileType, {'results', 'timefreq'});
    % If both groups of files use the same scouts (or flattening only), concatenate inputs (A and B)
    % and compute PCA across all files together.
    if isPcaA && isPcaB
        % A and B, call together: common PCA
        nA = numel(sInputA);
        sInputA = [sInputA, sInputB];
    elseif isPcaB
        % B only: Call with B in first spot, for convenience.
        [sInputB, isTempPcaB] = RunTempPcaFlat(sProcess, PcaOptions, sInputB);
        return;
    elseif ~isPcaA
        % No A or B inputs
        return;
    end

    % Avoid duplicate files, e.g. if A = B.  GetInputStruct doesn't work in that case.  Also faster.
    [~, iIn, iUniq] = unique({sInputA.FileName});
    sInputA = sInputA(iIn);

    % Check if we have to first flatten unconstrained sources. We only check first file. Other
    % files will be checked for inconsistent dimensions in bst_pca, and if so there will be an error.
    isUnconstrained = any(CheckUnconstrained(sProcess, sInputA(1))); % any() needed for mixed models
    if isempty(isUnconstrained)
        sInputA = [];
        return; % Error already reported;
    elseif isUnconstrained
        % Run PCA flattening of unconstrained sources (no scouts yet). Outputs temporary result files: isOutMatrix=false
        FlatOutputFiles = bst_pca(sProcess, sInputA, PcaOptions, [], false);
        if isempty(FlatOutputFiles)
            sInputA = [];
            return; % Error already reported.
        elseif ~any(ismember(FlatOutputFiles, {sInputA.FileName}))
            % Convert flattened files list back to input structure.
            sInputA = bst_process('GetInputStruct', FlatOutputFiles);
            % All new files, safe to flag as temporary.
            isTempPcaA = true;
        elseif ~all(ismember(FlatOutputFiles, {sInputA.FileName}))
            % Some, but not all new files.  Something went wrong, but this should not happen.
            bst_report('Error', sProcess, sInputA, 'PCA was only applied to some files. Verify inputs are all consistent (e.g. all same atlas or all unconstrained sources). Aborting.');
            sInputA = [];
            return;
        else
            % All unchanged files. This can happen if no scout or asking to flatten already flat
            % sources. Return inputs unchanged and DON'T mark them as temporary.
        end
    end

    % Recover full list with duplicates.
    sInputA = sInputA(iUniq);
    % Split back into A and B lists.
    if isPcaA && isPcaB
        sInputB = sInputA(nA+1:end);
        isTempPcaB = isTempPcaA;
        sInputA(nA+1:end) = [];
    end
end

% PCA scouts only
% AtlasListA/B: if empty, that group of files is completely ignored. Otherwise it should be a cell
% array from process option of type 'scout'.
function [sInputA, isTempPcaA, sInputB, isTempPcaB] = RunTempPcaScout(sProcess, PcaOptions, sInputA, AtlasListA, sInputB, AtlasListB)
    if nargin < 4
        error('Missing input arguments.');
    end
    if nargin < 5
        sInputB = [];
    end
    if nargin < 6
        AtlasListB = [];
    end
    % Verify PCA options were provided.
    if isempty(PcaOptions)
        error('Incorrect process options for running PCA with temporary files.');
    end
    % Only set these to true after successfully creating the temp files.
    isTempPcaA = false;
    isTempPcaB = false;
    % Use these to indicate we will try to create the temp files.
    isPcaA = ~isempty(sInputA) && ismember(sInputA(1).FileType, {'results', 'timefreq'}) && ...
        ~isempty(AtlasListA) && (isstruct(AtlasListA) || iscell(AtlasListA));
    isPcaB = ~isempty(sInputB) && ismember(sInputB(1).FileType, {'results', 'timefreq'}) && ...
        ~isempty(AtlasListB) && (isstruct(AtlasListB) || iscell(AtlasListB));
    % If both groups of files use the same scouts, concatenate inputs (A and B) and compute PCA
    % across all files together.
    isSameScouts = false;
    if isPcaA && isPcaB && ...
            ( iscell(AtlasListA) && iscell(AtlasListB) && numel([AtlasListA{:,2}]) == numel([AtlasListB{:,2}]) && ...
            all(ismember([AtlasListA{:,2}], [AtlasListB{:,2}])) ) 
        % A and B, call together with same scouts (or no scouts): common PCA
        isSameScouts = true;
        nA = numel(sInputA);
        sInputA = [sInputA, sInputB];
    elseif isPcaB 
        % Different scouts, run B separately.
        [sInputB, isTempPcaB] = RunTempPcaScout(sProcess, PcaOptions, sInputB, AtlasListB);
        % Don't return yet, may still have A to process with different scouts.
    end
    if ~isPcaA
        return;
    end

    % Avoid duplicate files, e.g. if A = B.  GetInputStruct doesn't work in that case.  Also faster.
    [~, iIn, iUniq] = unique({sInputA.FileName});
    sInputA = sInputA(iIn);

    if ~iscell(AtlasListA)
        bst_report('Error', sProcess, sInputA, 'Unexpected scout definition for running PCA with temporary files.');
        sInputA = []; sInputB = [];
        return;
    end
    % Run PCA scout extraction on all files.  Outputs temporary result files: isOutMatrix=false
    ScoutOutputFiles = bst_pca(sProcess, sInputA, PcaOptions, AtlasListA, false);
    % Verify the files are different.
    if isempty(ScoutOutputFiles) % something went wrong
        sInputA = []; sInputB = [];
        return; % Error already reported.
    elseif ~any(ismember(ScoutOutputFiles, {sInputA.FileName}))
        % All new files, safe to flag as temporary.
        % Convert scout result file list back to input structure for calling process.
        sInputA = bst_process('GetInputStruct', ScoutOutputFiles);
        % All new files, safe to flag as temporary.
        isTempPcaA = true;
    elseif ~all(ismember(ScoutOutputFiles, {sInputA.FileName}))
        % Some, but not all new files.  Something went wrong, but this should not happen.
        bst_report('Error', sProcess, sInputA, 'PCA was only applied to some files. Verify inputs are all consistent (e.g. all same atlas or all unconstrained sources). Aborting.');
        sInputA = []; sInputB = [];
        return;
    else
        % All unchanged files. This can happen if no scouts. Return inputs unchanged and DON'T mark them as temporary.
    end

    % Recover full list with duplicates.
    sInputA = sInputA(iUniq);
    % Split back into A and B lists.
    if isSameScouts 
        sInputB = sInputA(nA+1:end);
        isTempPcaB = isTempPcaA;
        sInputA(nA+1:end) = [];
    end
end


%% ===== DELETE TEMPORARY RESULT FILES =====
% Here, we are deleting result files that were created temporarily by bst_pca, and the tree was not
% updated to show them. 
function isError = DeleteTempResultFiles(sProcess, sInputs)
    isError = false;
    % Sanity check that we're dealing with result files.
    if any(~strcmpi({sInputs.FileType}, 'results'))
        error('Unexpected file type.');
    end
    Files = {sInputs.FileName};
    iFileStudies = [sInputs.iStudy];
    iFileResults = [sInputs.iItem];

    % Get unique list of studies
    [uniqueStudies, ~, iUS] = unique(iFileStudies);
    sUStudies = bst_get('Study', uniqueStudies);

    % Check for kernel links. Replace with kernel.
    for iInput = 1:numel(sInputs)
        isLink = strcmpi(file_gettype(Files{iInput}), 'link');
        if isLink
            SharedKernelFile = file_resolve_link(Files{iInput});
            Files{iInput} = SharedKernelFile;
            % Also replace the result index of links with index of kernel.
            iResKer = find(strcmp(file_short(SharedKernelFile), {sUStudies(iUS(iInput)).Result.FileName}), 1);
            if isempty(iResKer)
                isError = true;
                bst_report('Error', sProcess, sInputs, ['Error finding kernel in database: ' SharedKernelFile]);
                return;
            end
            iFileResults(iInput) = iResKer;
        end
    end
    % Remove duplicates of shared kernels, or in input.
    [Files, iUF] = unique(Files);
    iFileStudies = iFileStudies(iUF);
    iFileResults = iFileResults(iUF);

    % Delete files.
    isDeleted = file_delete(file_fullpath(Files), 1);
    if isDeleted < 0
        isError = true;
        bst_report('Error', sProcess, sInputs, 'Error deleting temporary scout PCA result files.');
    end

    % Remove database entries.
    % Code adapted from node_delete, simplified since there are no dependent timefreq or dipoles.
    for i = 1:length(uniqueStudies)
        iStudy = uniqueStudies(i);
        sStudy = sUStudies(i);
        iResultsDel = iFileResults(iFileStudies == iStudy);
        % Remove file description from database
        sStudy.Result(iResultsDel) = [];
        % Study was modified
        bst_set('Study', iStudy, sStudy);
        % If result deleted from a 'default_study' node
        isDefaultStudy = strcmpi(sStudy.Name, bst_get('DirDefaultStudy'));
        if isDefaultStudy
            db_links('Subject', sStudy.BrainStormSubject);
            %             isTreeUpdateModel = true;
        else
            db_links('Study', iStudy);
            %             isTreeUpdateModel = false;
        end
    end
    % We're skipping updating the tree on purpose: those temp files should not have been added to the tree.
    %     if isTreeUpdateModel
    %         panel_protocols('UpdateTree');
    %     else
    %         panel_protocols('UpdateNode', 'Study', iStudies);
    %     end
    % Save database
    db_save();
end

