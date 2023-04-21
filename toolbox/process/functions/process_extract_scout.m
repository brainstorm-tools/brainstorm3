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
    sProcess.Comment     = 'Scouts time series';
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
    % === SCOUT FUNCTION ===
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'; ...
                                             'mean', 'max', 'pca', 'std', 'all', ''};
    sProcess.options.scoutfunc.Type       = 'radio_linelabel';
    sProcess.options.scoutfunc.Value      = 'mean';
    sProcess.options.scoutfunc.Controller = struct('pca', 'pca', 'mean', 'notpca', 'max', 'notpca', 'std', 'notpca', 'all', 'notpca');
    % Options: PCA
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
    sProcess.options.isnorm.InputTypes = {'results'};
    sProcess.options.isnorm.Class   = 'notpca';
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
    sProcess.options.addfilecomment.Value   = 1;
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
    isNorm = isfield(sProcess.options, 'isnorm') && isfield(sProcess.options.isnorm, 'Value') && isequal(sProcess.options.isnorm.Value, 1);
    isFlip = isfield(sProcess.options, 'isflip') && isfield(sProcess.options.isflip, 'Value') && isequal(sProcess.options.isflip.Value, 1);
    AddRowComment  = sProcess.options.addrowcomment.Value; % only applicable to 'All' scout function
    AddFileComment = sProcess.options.addfilecomment.Value; 

    % PCA now treated in separate function, except if called without saving, e.g. through
    % bst_process('LoadInputFile'). In that case, go through usual process below, which is
    % appropriate for old deprecated 'pca' method, or for temporary atlas-based files (already
    % scouts) that only need to be loaded.
    if strcmpi(ScoutFunc, 'pca') && isfield(sProcess.options, 'pcaedit') && ...
            ~isempty(sProcess.options.pcaedit) && ~isempty(sProcess.options.pcaedit.Value)
        PcaOptions = sProcess.options.pcaedit.Value;
        if isSave % && ~strcmpi(PcaOptions.Method, 'pca')
            % Uncomment above to test legacy pca through extract_scout vs bst_pca
            % Don't allow concatenating, for now. Option disabled in panel.
            % The other output options above are not used for PCA: isNorm=false (uses pca for
            % flattening), isFlip=true, AddRowComment n/a, AddFileComment=true.

            % Check if we have to first flatten unconstrained sources. We only check first file. Other
            % files will be checked for inconsistent dimensions in bst_pca, and if so there will be an error.
            isUnconstrained = any(CheckUnconstrained(sProcess, sInputs(1))); % any() needed for mixed models
            if isempty(isUnconstrained)
                return; % Error already reported;
            elseif isUnconstrained
                % Run PCA flattening of unconstrained sources (no scouts yet). Outputs temporary result files.
                FlatOutputFiles = bst_pca(sProcess, sInputs, PcaOptions, [], false);
                if isempty(FlatOutputFiles)
                    return; % Error already reported.
                end
                % Convert flattened files list back to input structure for second call.
                sInputs = bst_process('GetInputStruct', FlatOutputFiles);
                % isUnconstrained = false;
            end
            % Run PCA scout extraction on all files.
            % This process always saves matrix outputs: isOutMatrix=true
            OutputFiles = bst_pca(sProcess, sInputs, PcaOptions, AtlasList, true, TimeWindow);
            % Delete temporary flattened files.
            if isUnconstrained
                DeleteTempResultFiles(sProcess, sInputs);
            end
            return;
        elseif ~strcmpi(PcaOptions.Method, 'pca') % ~isSave
            % With the exception of the old deprecated per-file PCA method, which can be done in
            % this function, files should be already scouts if isSave is false.
            % Verify that the files are atlas-based result files.
            isAtlasBased = false;
            if strcmpi(sInputs(1).FileType, 'results')
                sResults = in_bst_results(sInputs(1).FileName, 0);
                if ~isempty(sResults.Atlas)
                    isAtlasBased = true;
                end
            end
            % Otherwise, PCA requires saving files.
            if ~isAtlasBased
                bst_report('Error', sProcess, sInputs, 'PCA for scouts requires saving files.');
                return;
            % else, proceed below where the atlas-based files will be loaded.
            end
        % else, proceed below with the deprecated pca method, without saving files.
        end
    end

    % If flip is not set: auto-detect and do not trigger errors
    if isempty(isFlip)
        isFlip = 1;
        isFlipWarning = 0;
    else
        isFlipWarning = 1;
    end
    % Unconstrained function
    if isNorm
        XyzFunction = 'norm';
    else
        XyzFunction = 'none';
    end

    % ===== LOOP ON THE FILES =====
    for iInput = 1:length(sInputs)
        % Progress bar
        if (length(sInputs) > 1)
            if iInput == 1
                bst_progress('start', 'Extract scouts', sprintf('Extracting scouts for file: %d/%d...', iInput, length(sInputs)), iInput, length(sInputs));
            else
                bst_progress('text', sprintf('Extracting scouts for file: %d/%d...', iInput, length(sInputs)));
                bst_progress('inc', 1);
            end
        end
        isAbs = ~isempty(strfind(sInputs(iInput).FileName, '_abs'));


        % === READ FILES ===
        [sResults, matSourceValues, matDataValues, fileComment] = LoadFile(sProcess, sInputs(iInput), TimeWindow);
        if isempty(sResults)
            if isConcatenate
                return; % Error already reported.
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
                return;
                % Check time vectors
            elseif (length(initTimeVector) ~= length(sResults.Time))
                bst_report('Error', sProcess, sInputs(iInput), 'When concatenating, time should be the same for all files.');
                return;
            end
        end

        [sScoutsFinal, AllAtlasNames, sSurf, isVolumeAtlas] = GetScoutsInfo(sProcess, sInputs(iInput), ...
            sResults.SurfaceFile, AtlasList, sResults.Atlas, ScoutFunc);
        % Selected scout function now applied in GetScoutInfo (overrides the one from the scout panel).
        if isempty(sScoutsFinal)
            if isConcatenate
                return; % Error already reported.
            else
                continue;
            end
        end

        % === LOOP ON SCOUTS ===
        scoutValues  = [];
        scoutStd     = [];
        Description  = {};
        scoutComment = [];
        for iScout = 1:length(sScoutsFinal)
            % Get scout name
            ScoutName = sScoutsFinal(iScout).Label;

            % === GET ROWS INDICES ===
            [iRows, RowNames, ScoutOrient, nComponents] = GetScoutRows(sProcess, sInputs(iInput), ...
                sScoutsFinal(iScout), sResults, sSurf, isVolumeAtlas(iScout));
            if isempty(iRows)
                OutputFiles = {};
                return; % Error already reported.
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
                return;
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
                Description = cat(1, Description, ScoutName);
                continue;
            end

            % Process differently the unconstrained sources
            isUnconstrained = (nComponents ~= 1) && ~strcmpi(XyzFunction, 'norm');
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
                tmpScout = bst_scout_value(ScoutSourceValues(:,:,iFreq), sScoutsFinal(iScout).Function, ScoutOrient, nComponents, XyzFunction, isFlipScout, ScoutName);
                scoutValues = cat(1, scoutValues, tmpScout);
                if ~isempty(sourceStd)
                    tmpScoutStd = [];
                    for iBound = 1:size(sourceStd,4)
                        tmp = bst_scout_value(sourceStd(:,:,iFreq,iBound), sScoutsFinal(iScout).Function, ScoutOrient, nComponents, XyzFunction, 0);
                        if isempty(tmpScoutStd)
                            tmpScoutStd = tmp;
                        else
                            tmpScoutStd = cat(4, tmpScoutStd, tmp);
                        end
                    end
                    scoutStd = cat(1, scoutStd, tmpScoutStd);
                end
                % Loop on the rows to comment them
                for iRow = 1:size(tmpScout,1)
                    % Start with the scout name
                    scoutDesc = ScoutName;
                    % Add the row name
                    if AddRowComment && ~isempty(RowNames)
                        if isUnconstrained
                            iRowUnconstr = floor((iRow-1) / nComponents + 1);
                            scoutDesc = [scoutDesc '.' RowNames{iRowUnconstr}];
                        else
                            scoutDesc = [scoutDesc '.' RowNames{iRow}];
                        end
                    end
                    % Add the component index (unconstrained sources)
                    if isUnconstrained
                        iComp = mod(iRow-1,nComponents) + 1;
                        scoutDesc = [scoutDesc '.' num2str(iComp)];
                    end
                    % Add file comment
                    if AddFileComment
                        % Frequency comment
                        if (nFreq > 1)
                            if iscell(sResults.Freqs)
                                freqComment = [' ' sResults.Freqs{iFreq,1}];
                            else
                                freqComment = [' ' num2str(sResults.Freqs(iFreq)), 'Hz'];
                            end
                        else
                            freqComment = '';
                        end
                        % Add it to the scout comment
                        scoutDesc = [scoutDesc ' @ ' fileComment freqComment];
                    end
                    % Add the scout description
                    Description = cat(1, Description, scoutDesc);
                end
            end
        end
        % If nothing was found
        if isempty(scoutValues)
            return;
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
                % Add nComponents to indicate how many components per vertex
                if (nComponents == 1) || strcmpi(XyzFunction, 'norm')
                    newMat.nComponents = 1;
                else
                    newMat.nComponents = nComponents;
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

end % Run function


%% ===== Check if any unconstrained sources =====
% isUnconstrained is true/false, or a list for mixed models.
function [isUnconstrained, nComponents] = CheckUnconstrained(sProcess, sInputs, sResults)
    % Function meant for 1 input file, but runs ok if list.
    isUnconstrained = [];
    nComponents = [];
    if nargin < 3 || isempty(sResults)
        % Load first file, without data.
        sResults = LoadFile(sProcess, sInputs);
        if isempty(sResults)
            return; % Error already reported.
        end
    end
    % Get the number of source orientations (components) per vertex
    if strcmpi(sInputs(1).FileType, 'results')
        nComponents = sResults.nComponents;
    elseif ~isempty(sResults.GridAtlas)
        nComponents = 0;
    else % treat as constrained, though maybe components still possible, "hidden" in timefreq.RowNames?
        nComponents = 1;
    end
    % Check each region if mixed model.
    if nComponents == 0
        if isempty(sResults.GridAtlas) || ~isfield(sResults.GridAtlas, 'Scouts') || isempty(sResults.GridAtlas.Scouts)
            Message = 'Missing mixed source model region description (GridAtlas).';
            bst_report('Error', sProcess, sInputs, Message);
            return;
        end
        isUnconstrained = ~arrayfun(@(Scout) ~strcmpi('C', Scout.Region(3)), sResults.GridAtlas.Scouts); % 'U' or 'L'
    else
        isUnconstrained = nComponents > 1;
    end
end


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
            sMat = in_bst(sResults.DataFile, TimeWindow);
            if ~isempty(sMat.Comment)
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
                matDataValues = sMat.F;
                % sResults already has a copy of the sMat (data file) fields: Time, nAvg, Leff, ChannelFlag.
                matSourceValues = [];
            end
            % Keep both data file and inverse model histories. 
            sResults.History = cat(1, sMat.History, sResults.History);
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
% sProcess can be empty, only used for bst_report.
% sInput is only needed if SurfaceFile is missing. We assume all inputs use the same surface.
% ResultsAtlas is only used for (deprecated or temporary) atlas-based result files.
% AllAtlasNames and isVolumeAtlas have the same length as the scout list sScoutFinal.
% sScoutsFinal is empty if an error occurs, after logging the error in the report.
function [sScoutsFinal, AllAtlasNames, sSurf, isVolumeAtlas] = GetScoutsInfo(sProcess, sInputs, SurfaceFile, AtlasList, ResultsAtlas, ScoutFunc)

    sScoutsFinal  = [];
    AllAtlasNames = {};
    isVolumeAtlas = [];
    sSurf = [];

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
            sScout.Function = ScoutFunc;
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
% USAGE:  [iRows, RowNames, ScoutOrient, nComponents] = process_extract_scout('GetScoutRows', sProcess, sInput, sScout, sResults, sSurf, isVolumeAtlas, ScoutFunc)
% ScoutOrient is only used for "sign flipping" (based on anatomy) when combining sources with constrained orientations.
% iRows is empty if an error occurs, after logging the error in the report.
% nComponents is always 1 or 3. If a scout spans multiple regions, an error is returned.
% RowNames is empty or vertex numbers (cell array of str) only for 'All' scout function.
% ScoutFunc is only used to warn if a scout in an atlas-based result file was computed with a different function.
function [iRows, RowNames, ScoutOrient, nComponents] = GetScoutRows(sProcess, sInput, sScout, sResults, sSurf, isVolumeAtlas, ScoutFunc)
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
        % Confirm this is not a mixed model: there should not be any process that create such files (mixed & atlas-based)
        if nComponents == 0
            error('Detected unsupported file type: mixed model and atlas-based result.');
        end
        % Atlas-based timefreq also not supported for now (error when loading).
        % Find the requested scout in the file
        iScoutRes = find(strcmpi(sScout.Label, {sResults.Atlas(1).Scouts.Label}));
        % Multiple scouts with the same name in an atlas: Error
        if (length(iScoutRes) > 1)
            bst_report('Error', sProcess, sInputs, ['File is already based on an atlas, but multiple scouts with name "' sScout.Label '" found.']);
            % If the scout names cannot be found: error
        elseif isempty(iScoutRes)
            bst_report('Error', sProcess, sInputs, ['File is already based on an atlas, but scout "' sScout.Label '" not found.']);
        elseif nComponents == 1
            iRows = iScoutRes;
        elseif nComponents == 3
            iRows = 3 * iScoutRes - [2, 1, 0];
        end
        % Warn if the scout function used doesn't match the one requested.
        if ~isempty(ScoutFunc) && ~strcmpi(sScout.Function, ScoutFunc)
            bst_report('Warning', sProcess, sInput, ['File is already based on an atlas, but ' sScout.Label ' was computed with scout function ' sScout.Function ' instead of ' ScoutFunc '.']);
        end
        return;
    end

    % Sort vertices indices
    iVertices = sort(unique(sScout.Vertices));
    % Make sure this is a row vector
    iVertices = iVertices(:)';
    % Get row names
    if strcmpi(sScout.Function, 'All')
        RowNames = cellfun(@num2str, num2cell(iVertices), 'UniformOutput', 0);
    else
        RowNames = [];
    end
    % Get the row and vertex or grid indices of the scout in ImageGridAmp/ImagingKernel
    [iRows, iRegionScouts, iVertices] = bst_convert_indices(iVertices, nComponents, sResults.GridAtlas, ~isVolumeAtlas);
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
                ScoutOrient = sResults.GridOrient(iVertices,:);
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


%% ===== SAVE PCA TO TEMPORARY RESULT FILES - FOR OTHER PROCESSES =====
% Run PCA ('pcaa' or 'pcai') on group of inputs as a preliminary step in some processes (e.g.
% connectivity), instead of file-by-file through bst_process('LoadInputFile') for other scout
% methods (including deprecated 'pca', for efficiency). This saves temporary result files which are
% then substituted as inputs to the calling process.  These temporary files should be deleted at the
% very end of the process with DeleteTempResultFiles, defined below.  sProcess should NOT be
% modified, because the temporary atlas-based files need to be loaded with process_extract_scout,
% through bst_process('LoadInputFile'), so they are still treated as if scouts need to be extracted.

% function [sInputA, sInputB, isTempPcaA, isTempPcaB] = RunTempPca(sProcess, sInputA, sInputB)
%     if nargin < 3
%         sInputB = [];
%     elseif nargin < 2
%         error('Missing input arguments.');
%     end
%     isTempPcaA = false;
%     isTempPcaB = false;
%     % Verify PCA options were provided.
%     if ~strcmpi(sProcess.options.scoutfunc.Value, 'pca') || ~isfield(sProcess.options, 'pcaedit') || isempty(sProcess.options.pcaedit.Value)
%         error('Incorrect process options for running PCA with temporary files.');
%     end
% 
%     % Get scout selection.
%     % If both groups of files use the same scouts, concatenate inputs (A and B) and compute PCA across all files together.
%     isSameScouts = false;
%     if isfield(sProcess.options, 'scouts') && ~isempty(sProcess.options.scouts.Value)
%         isTempPcaA = true;
%         AtlasListA = sProcess.options.scouts.Value;
%         if ~isempty(sInputB) && ~isfield(sProcess.options, 'dest_scouts')
%             % Assume the single scout selection applies to both groups of files - though this case probably not expected with standard processes.
%             isTempPcaB = true;
%             % A and B, call together with same scouts: common PCA
%             isSameScouts = true;
%             nA = numel(sInputA);
%             sInputA = [sInputA, sInputB];
%         end
%     elseif ~isempty(sInputA) && isfield(sProcess.options, 'src_scouts') && ~isempty(sProcess.options.src_scouts.Value)
%         sProcess.options.scouts = sProcess.options.src_scouts;
%         isTempPcaA = true;
%         AtlasListA = sProcess.options.scouts.Value;
%         if ~isempty(sInputB) && isfield(sProcess.options, 'dest_scouts') && ~isempty(sProcess.options.dest_scouts.Value)
%             isTempPcaB = true;
%             AtlasListB = sProcess.options.dest_scouts.Value;
%             if iscell(AtlasListA) && iscell(AtlasListB) && numel([AtlasListA{:,2}]) == numel([AtlasListB{:,2}]) && ...
%                     all(ismember([AtlasListA{:,2}], [AtlasListB{:,2}]))
%                 % A and B, call together with same scouts: common PCA
%                 isSameScouts = true;
%                 nA = numel(sInputA);
%                 sInputA = [sInputA, sInputB];
%             else
%                 % Different scouts, run B separately.
%                 sProcessB = sProcess;
%                 sProcessB.options.scouts = sProcessB.options.dest_scouts;
%                 sInputB = RunTempPca(sProcessB, sInputB);
%             end
%         end
%     elseif ~isempty(sInputB) && isfield(sProcess.options, 'dest_scouts') && ~isempty(sProcess.options.dest_scouts.Value)
%         % B only: call again without A for simplicity.
%         sProcess.options.scouts = sProcess.options.dest_scouts;
%         isTempPcaB = true;
%         sInputB = RunTempPca(sProcess, sInputB);
%         return;
%     else
%         error('No scout selection found.');
%     end
% 
%     % Avoid duplicate files, e.g. if A = B.  GetInputStruct doesn't work in that case.  Also faster.
%     [~, iIn, iUniq] = unique({sInputA.FileName});
%     sInputA = sInputA(iIn);
% 
%     PcaOptions = sProcess.options.pcaedit.Value;
%     %% Decide vs history
%     if strcmpi(PcaOptions.Method, 'pca')
%         warning('Deprecated ''pca'' method should not be run with RunTempPca, for efficiency.');
%     end
%     % Check if we have to first flatten unconstrained sources. We only check first file. Other
%     % files will be checked for inconsistent dimensions in bst_pca, and if so there will be an error.
%     isUnconstrained = any(CheckUnconstrained(sProcess, sInputA(1))); % any() needed for mixed models
%     if isempty(isUnconstrained)
%         return; % Error already reported;
%     elseif isUnconstrained
%         % Run PCA flattening of unconstrained sources (no scouts yet). Outputs temporary result files.
%         FlatOutputFiles = bst_pca(sProcess, sInputA, PcaOptions, [], false);
%         if isempty(FlatOutputFiles)
%             return; % Error already reported.
%         end
%         % Convert flattened files list back to input structure for second call.
%         sInputA = bst_process('GetInputStruct', FlatOutputFiles);
%         % isUnconstrained = false;
%     end
%     % Run PCA scout extraction on all files.  Again, outputs temporary result files.
%     % This process always saves matrix outputs: isOutMatrix=true
%     ScoutOutputFiles = bst_pca(sProcess, sInputA, PcaOptions, AtlasListA, false);
%     % Delete temporary flattened files.
%     if isUnconstrained
%         DeleteTempResultFiles(sProcess, sInputA);
%     end
%     % Convert scout result file list back to input structure for calling process.
%     sInputA = bst_process('GetInputStruct', ScoutOutputFiles);
% 
%     % Recover full list with duplicates.
%     sInputA = sInputA(iUniq);
% 
%     % Split back into A and B lists.
%     if isSameScouts 
%         sInputB = sInputA(nA+1:end);
%         sInputA(nA+1:end) = [];
%     end
% end

% sProcess is optional: only used for bst_report and can be the process name only.
function [sInputA, sInputB, isTempPcaA, isTempPcaB] = RunTempPca(sProcess, sInputA, AtlasListA, PcaOptions, sInputB, AtlasListB)
    if nargin < 4
        error('Missing input arguments.');
    elseif nargin < 6
        sInputB = [];
        AtlasListB = [];
    end
    % Verify PCA options were provided.
    if isempty(PcaOptions)
        error('Incorrect process options for running PCA with temporary files.');
    end

    isTempPcaA = false;
    isTempPcaB = false;
    % Get scout selection.
    if ~isempty(sInputA) && ~isempty(AtlasListA)
        isTempPcaA = true;
    end
    if ~isempty(sInputB) && ~isempty(AtlasListB)
        isTempPcaB = true;
    end
    % If both groups of files use the same scouts, concatenate inputs (A and B) and compute PCA across all files together.
    isSameScouts = false;
    if isTempPcaA && isTempPcaB
        if iscell(AtlasListA) && iscell(AtlasListB) && numel([AtlasListA{:,2}]) == numel([AtlasListB{:,2}]) && ...
                all(ismember([AtlasListA{:,2}], [AtlasListB{:,2}]))
            % A and B, call together with same scouts: common PCA
            isSameScouts = true;
            nA = numel(sInputA);
            sInputA = [sInputA, sInputB];
        else
            % Different scouts, run B separately.
            sInputB = RunTempPca(sProcess, sInputB, AtlasListB, PcaOptions);
        end
    elseif isTempPcaB
        % B only: call again without A for simplicity.
        sInputB = RunTempPca(sProcess, sInputB, AtlasListB, PcaOptions);
        return;
    elseif ~isTempPcaA
        error('No scout selection found.');
    end

    % Avoid duplicate files, e.g. if A = B.  GetInputStruct doesn't work in that case.  Also faster.
    [~, iIn, iUniq] = unique({sInputA.FileName});
    sInputA = sInputA(iIn);

    %% Decide vs history
    if strcmpi(PcaOptions.Method, 'pca')
        warning('Deprecated ''pca'' method should not be run with RunTempPca, for efficiency.');
    end
    % Check if we have to first flatten unconstrained sources. We only check first file. Other
    % files will be checked for inconsistent dimensions in bst_pca, and if so there will be an error.
    isUnconstrained = any(CheckUnconstrained(sProcess, sInputA(1))); % any() needed for mixed models
    if isempty(isUnconstrained)
        return; % Error already reported;
    elseif isUnconstrained
        % Run PCA flattening of unconstrained sources (no scouts yet). Outputs temporary result files.
        FlatOutputFiles = bst_pca(sProcess, sInputA, PcaOptions, [], false);
        if isempty(FlatOutputFiles)
            return; % Error already reported.
        end
        % Convert flattened files list back to input structure for second call.
        sInputA = bst_process('GetInputStruct', FlatOutputFiles);
        % isUnconstrained = false;
    end
    % Run PCA scout extraction on all files.  Again, outputs temporary result files.
    % This process always saves matrix outputs: isOutMatrix=true
    ScoutOutputFiles = bst_pca(sProcess, sInputA, PcaOptions, AtlasListA, false);
    % Delete temporary flattened files.
    if isUnconstrained
        DeleteTempResultFiles(sProcess, sInputA);
    end
    % Convert scout result file list back to input structure for calling process.
    sInputA = bst_process('GetInputStruct', ScoutOutputFiles);

    % Recover full list with duplicates.
    sInputA = sInputA(iUniq);

    % Split back into A and B lists.
    if isSameScouts 
        sInputB = sInputA(nA+1:end);
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
    % Remove duplicates of shared kernels.
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

