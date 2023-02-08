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
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type       = 'radio_line';
    sProcess.options.scoutfunc.Value      = 1;
    % === FLIP SIGN
    sProcess.options.isflip.Comment    = 'Flip the sign of sources with opposite directions';
    sProcess.options.isflip.Type       = 'checkbox';
    sProcess.options.isflip.Value      = 1;
    sProcess.options.isflip.InputTypes = {'results'};
    % === NORM XYZ
    sProcess.options.isnorm.Comment = 'Unconstrained sources: Norm of the three orientations (x,y,z)';
    sProcess.options.isnorm.Type    = 'checkbox';
    sProcess.options.isnorm.Value   = 0;
    sProcess.options.isnorm.InputTypes = {'results'};
    % === CONCATENATE
    sProcess.options.concatenate.Comment = 'Concatenate output in one unique matrix';
    sProcess.options.concatenate.Type    = 'checkbox';
    sProcess.options.concatenate.Value   = 1;
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
    AddRowComment  = sProcess.options.addrowcomment.Value;
    AddFileComment = sProcess.options.addfilecomment.Value;
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
        nComponents = [];
        % Progress bar
        if (length(sInputs) > 1)
            bst_progress('text', sprintf('Extracting scouts for file: %d/%d...', iInput, length(sInputs)));
        end
        isAbs = ~isempty(strfind(sInputs(iInput).FileName, '_abs'));


        % === READ FILES ===
        [sResults, matSourceValues, matDataValues, fileComment] = LoadFile(sProcess, sInputs, TimeWindow);
        if isempty(sResults)
            % Error already reported.
            if isConcatenate
                return;
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
            sResults.SurfaceFile, AtlasList, sResults.Atlas);
        if isempty(sScoutsFinal)
            % Error already reported.
            if isConcatenate
                return;
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
            ScoutName = AtlasList{iAtlas,2}{iScout};


            % Apply selected scout function
            if ~isempty(ScoutFunc)
                sScoutsFinal(iScout).Function = ScoutFunc;
            end
            % === GET ROWS INDICES ===
            [iRows, RowNames, ScoutOrient, nComponents] = GetScoutRows(sProcess, sInputs(iInput), ...
                sScoutsFinal(iScout), sResults, sSurf, isVolumeAtlas);
            if isempty(iRows)
                % Error already reported.
                return;
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
            % Can we check if the same function was used?  Need to parse history?
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


%% ===== LOAD INPUT FILE =====
% Accepts results (full or kernel, atlas-based ok) or timefreq of type result (not kernel, not atlas-based)
% For kernels, matSourceValues stays empty, but matDataValue is loaded and Time is added to sResults.
% TimeWindow is optional and is applied to both Values matrices, and sResults.Time. 
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
            % FULL RESULTS
            if isfield(sResults, 'ImageGridAmp') && ~isempty(sResults.ImageGridAmp)
                matSourceValues = sResults.ImageGridAmp;
                % Drop large data field.
                sResults = rmfield(sResults, 'ImageGridAmp');
                % KERNEL ONLY
            elseif isfield(sResults, 'ImagingKernel') && ~isempty(sResults.ImagingKernel)
                sMat = in_bst(sResults.DataFile, TimeWindow);
                matDataValues = sMat.F;
                % Keep time.
                sResults.Time = sMat.Time;
                %% ? Are there other fields needed from data file, different in result file, to save in output: ChannelFlag, nLeff, Comment?
                matSourceValues = [];
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
            else
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
    if isempty(sResults) || (isempty(matSourceValues) && (isempty(matDataValues) || ~isfield(sResults, 'ImagingKernel') || isempty(sResults.ImagingKernel)))
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
        else
            matDataValues = matDataValues(:,iTime,:);
        end
        sResults.Time = sResults.Time(iTime);
        % If there are only two time points, make sure they are not identical
        if (length(sResults.Time) == 2) && sResults.Time(2) == sResults.Time(1)
            sResults.Time(2) = sResults.Time(1) + 0.001;
        end
    end
end


%% ===== GET SCOUTS INFO =====
% USAGE:  [sScoutsFinal, AllAtlasNames, sSurf, isVolumeAtlas] = process_extract_scout('GetScoutsInfo', sProcess, sInput, SurfaceFile, AtlasList)
% AllAtlasNames and isVolumeAtlas have the same length as the scout list sScoutFinal.
function [sScoutsFinal, AllAtlasNames, sSurf, isVolumeAtlas] = GetScoutsInfo(sProcess, sInputs, SurfaceFile, AtlasList, ResultsAtlas)
    % We assume all input files are compatible and only use the first one.
    iInput = 1;

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
        sSubject = bst_get('Subject', sInputs(iInput).SubjectFile);
        % Error: no default cortex
        if isempty(sSubject.iCortex) || (sSubject.iCortex > length(sSubject.Surface))
            bst_report('Error', sProcess, sInputs(iInput), ['Invalid surface file: ' SurfaceFile]);
        else
            bst_report('Warning', sProcess, sInputs(iInput), 'Surface file is not defined for the input file, using the default cortex.');
        end
        % Get default cortex surface
        SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
    end
    % Load surface
    sSurf = in_tess_bst(SurfaceFile);
    if isempty(sSurf) || ~isfield(sSurf, 'Atlas')
        bst_report('Error', sProcess, sInputs(iInput), ['Invalid surface file: ' SurfaceFile]);
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
                % Try to find the requested scouts in the file
                iRow = find(strcmpi(ScoutName, {ResultsAtlas(1).Scouts.Label}));
                if ~isempty(iRow)
                    sScout = ResultsAtlas(1).Scouts(iRow);
                    % If the scout names cannot be found: error
                else
                    bst_report('Error', sProcess, sInputs(iInput), ['File is already based on an atlas, but scout "' sScout.Label '" not found.']);
                    return;
                end
            end

            % === FIND SCOUT NAMES IN SURFACE ATLASES ===
            % Search in selected atlas
            if isempty(sScout) && ~isempty(iAtlasSurf)
                % Search for scout name
                iScoutSurf = find(strcmpi(ScoutName, {sSurf.Atlas(iAtlasSurf).Scouts.Label}));
                % Multiple scouts with the same name in an atlas: Error
                if (length(iScoutSurf) > 1)
                    bst_report('Error', sProcess, sInputs(iInput), ['Multiple scouts have the same name in atlas "' AtlasName '", please fix this error.']);
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
                        bst_report('Error', sProcess, sInputs(iInput), ['Multiple scouts have the same name in atlas "' sSurf.Atlas(iAtlasSurf).Name '", please fix this error.']);
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
                    bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" was not found in selected atlas "' AtlasName '", but exists in multiple other atlases. Please select the atlas you want to use.']);
                    sScoutsFinal = [];
                    return;
                    % Scout name was found in only one atlas: Use it with a warning
                elseif ~isempty(iAllAtlas)
                    bst_report('Warning', sProcess, sInputs(iInput), ['Scout "' ScoutName '" was not found in selected atlas "' AtlasName '". Using the one that was found in atlas "' sSurf.Atlas(iAllAtlas).Name '".']);
                    sScout = sSurf.Atlas(iAllAtlas).Scouts(iAllScout);
                end
            end
            % Scout was not found: Error
            if isempty(sScout)
                bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" was not found in any atlas saved in the surface.']);
                sScoutsFinal = [];
                return;
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
% USAGE:  [iRows, RowNames, ScoutOrient, nComponents] = process_extract_scout('GetScoutRows', sProcess, sInput, sScout, sResults, sSurf, isVolumeAtlas)
% ScoutOrient is only used for "sign flipping" (based on anatomy) when combining sources with constrained orientations.
function [iRows, RowNames, ScoutOrient, nComponents] = GetScoutRows(sProcess, sInput, sScout, sResults, sSurf, isVolumeAtlas)
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
    RowNames = {};
    ScoutOrient = [];
    % Atlas-based result files: find matching scout
    if ~isempty(sResults.Atlas)
        % Try to find the requested scout in the file
        % Probably would need changing for finding multiple timefreq rows? But atlas-based timefreq not supported for now (error when loading).
        iRows = find(strcmpi(sScout.Label, {sResults.Atlas(1).Scouts.Label}));
        if isempty(iRows)
            bst_report('Error', sProcess, sInput, ['File is already based on an atlas, but scout "' sScout.Label '" not found.']);
        end
        nComponents = 1;
        return;
    end

    % === GET ROWS INDICES ===
    % Sort vertices indices
    iVertices = sort(unique(sScout.Vertices));
    % Make sure this is a row vector
    iVertices = iVertices(:)';
    % Get the number of components per vertex
    if strcmpi(sInput.FileType, 'results')
        nComponents = sResults.nComponents;
    elseif ~isempty(sResults.GridAtlas)
        nComponents = 0;
    else
        nComponents = 1;
    end
    % Get row names
    if strcmpi(sScout.Function, 'All')
        RowNames = cellfun(@num2str, num2cell(iVertices), 'UniformOutput', 0);
    else
        RowNames = [];
    end
    % Get the vertex indices of the scout in ImageGridAmp/ImagingKernel
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

