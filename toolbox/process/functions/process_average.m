function varargout = process_average( varargin )
% PROCESS_AVERAGE: Average files, by subject, by condition, or all at once.
%
% USAGE:                    OutputFiles = process_average('Run', sProcess, sInputs)
%                            OutputFile = process_average('AverageFiles', sProcess, sInputs, KeepEvents, isScaleDspm, isWeighted, isMatchRows, isZeroBad)
%                        [sMat,isFixed] = process_average('FixWarpedSurfaceFile', sMat, sInput, sStudyDest)
%  [iGroups, GroupComments, GroupNames] = process_average('SortFiles', sInputs, avgtype)

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
% Authors: Francois Tadel, 2010-2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Average files';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Average';
    sProcess.Index       = 301;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Averaging#Averaging';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    sProcess.isSeparator = 1;
    % Definition of the options
    % === AVERAGE TYPE
    sProcess.options.label1.Comment = '<U><B>Group files</B></U>:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.avgtype.Comment = {'Everything', 'By subject', 'By folder (subject average)', 'By folder (grand average)', 'By trial group (folder average)', 'By trial group (subject average)', 'By trial group (grand average)'};
    sProcess.options.avgtype.Type    = 'radio';
    sProcess.options.avgtype.Value   = 1;
    % === FUNCTION
    sProcess.options.label2.Comment = '<U><B>Function</B></U>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.avg_func.Comment = {'Arithmetic average:  <FONT color="#777777">mean(x)</FONT>', ...
                                         'Average absolute values:  <FONT color="#777777">mean(abs(x))</FONT>', ...
                                         'Root mean square (RMS):  <FONT color="#777777">sqrt(sum(x.^2)/N)</FONT>', ...
                                         'Standard deviation:  <FONT color="#777777">sqrt(var(x))</FONT>', ...
                                         'Standard error:  <FONT color="#777777">sqrt(var(x)/N)</FONT>', ...
                                         'Arithmetic average + Standard deviation', ...
                                         'Arithmetic average + Standard error', ...
                                         'Median:  <FONT color="#777777">median(x)</FONT>'};
    sProcess.options.avg_func.Type    = 'radio';
    sProcess.options.avg_func.Value   = 1;
    % === WEIGHTED AVERAGE
    sProcess.options.weighted.Comment    = 'Weighted average:  <FONT color="#777777">mean(x) = sum(Leff_i * x(i)) / sum(Leff_i)</FONT>';
    sProcess.options.weighted.Type       = 'checkbox';
    sProcess.options.weighted.Value      = 0;
    sProcess.options.weightedlabel.Comment    = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<FONT color="#777777">Leff_i = Effective number of averages for file #i</FONT>';
    sProcess.options.weightedlabel.Type       = 'label';
    % === KEEP EVENTS
    sProcess.options.keepevents.Comment    = 'Keep all the event markers from the individual epochs';
    sProcess.options.keepevents.Type       = 'checkbox';
    sProcess.options.keepevents.Value      = 0;
    sProcess.options.keepevents.InputTypes = {'data', 'matrix'};
    % === SCALE NORMALIZE SOURCE MAPS (DEPRECATED OPTION AFTER INVERSE 2018)
    sProcess.options.scalenormalized.Comment    = 'Adjust normalized source maps for SNR increase.<BR><FONT color="#777777"><I>Example: dSPM(Average) = sqrt(Navg) * Average(dSPM)</I></FONT>';
    sProcess.options.scalenormalized.Type       = 'checkbox';
    sProcess.options.scalenormalized.Value      = 0;
    sProcess.options.scalenormalized.InputTypes = {'results'};
    sProcess.options.scalenormalized.Hidden     = 1;
    % === MATCH ROWS WITH NAMES
    sProcess.options.matchrows.Comment    = 'Match signals between files using their names';
    sProcess.options.matchrows.Type       = 'checkbox';
    sProcess.options.matchrows.Value      = 1;
    sProcess.options.matchrows.InputTypes = {'timefreq', 'matrix'};
    % === EXCLUDE ZEROS FROM THE AVERAGE
    sProcess.options.iszerobad.Comment    = 'Exclude the flat signals from the average (zero at all times)';
    sProcess.options.iszerobad.Type       = 'checkbox';
    sProcess.options.iszerobad.Value      = 1;
    sProcess.options.iszerobad.InputTypes = {'timefreq', 'matrix'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    % Function
    if isfield(sProcess.options, 'avg_func')
        switch(sProcess.options.avg_func.Value)
            case 1,  Comment = 'Average: ';
            case 2,  Comment = 'Average/abs: ';
            case 3,  Comment = 'RMS: ';
            case 4,  Comment = 'Standard deviation: ';
            case 5,  Comment = 'Standard error: ';
            case 6,  Comment = 'Average+Std: ';
            case 7,  Comment = 'Average+Stderr: ';
            case 8,  Comment = 'Median: ';    
        end
    else
        Comment = 'Average: ';
    end
    % Weighted
    if isfield(sProcess.options, 'weighted') && isfield(sProcess.options.weighted, 'Value') && ~isempty(sProcess.options.weighted.Value) && sProcess.options.weighted.Value
        Comment = ['Weighted ' Comment];
    end
    % Average type
    iAvgType = sProcess.options.avgtype.Value;
    Comment = [Comment, sProcess.options.avgtype.Comment{iAvgType}];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned list
    OutputFiles = {};
    % Get current progressbar position
    if bst_progress('isVisible')
        curProgress = bst_progress('get');
        bst_progress('text', 'Grouping files...');
    else
        curProgress = [];
    end
    % Weighted
    if isfield(sProcess.options, 'weighted') && isfield(sProcess.options.weighted, 'Value') && ~isempty(sProcess.options.weighted.Value)
        isWeighted = sProcess.options.weighted.Value;
    else
        isWeighted = 0;
    end
    % Keep events
    if isfield(sProcess.options, 'keepevents') && isfield(sProcess.options.keepevents, 'Value') && ~isempty(sProcess.options.keepevents.Value)
        KeepEvents = sProcess.options.keepevents.Value;
    else
        KeepEvents = 0;
    end
    % Scale normalized source maps (DEPRECATED AFTER INVERSE 2018) 
    if isfield(sProcess.options, 'scalenormalized') && isfield(sProcess.options.scalenormalized, 'Value') && ~isempty(sProcess.options.scalenormalized.Value)
        isScaleDspm = sProcess.options.scalenormalized.Value;
    else
        isScaleDspm = 0;
    end
    % Match signals between files using their names
    if isfield(sProcess.options, 'matchrows') && isfield(sProcess.options.matchrows, 'Value') && ~isempty(sProcess.options.matchrows.Value)
        isMatchRows = sProcess.options.matchrows.Value;
    else
        isMatchRows = 1;
    end
    % Exclude zero values
    if isfield(sProcess.options, 'iszerobad') && isfield(sProcess.options.iszerobad, 'Value') && ~isempty(sProcess.options.iszerobad.Value)
        isZeroBad = sProcess.options.iszerobad.Value;
    else
        isZeroBad = 1;
    end
    
    % Check type of input files
    if ~isempty(strfind(sInputs(1).FileName, 'timefreq_pac')) || ~isempty(strfind(sInputs(1).FileName, 'timefreq_dpac'))
        bst_report('Error', sProcess, [], ['Cannot average PAC maps after their computation.' 10 'Please use the process option "Save average PAC across trials" instead.']);
        return;
    end
    
    % Group files
    [iGroups, GroupComments] = SortFiles(sInputs, sProcess.options.avgtype.Value);
    % Average each group
    for i = 1:length(iGroups)
        % Set progress bar at the same level for each loop
        if ~isempty(curProgress)
            bst_progress('set', curProgress);
        end
        % Do not process if there is only one input
        if (length(iGroups{i}) == 1)
            bst_report('Warning', sProcess, sInputs(iGroups{i}(1)), 'File is alone in its trial/comment group. Not processed.');
            continue;
        end
        % Set the comment of the output file
        if ~isempty(GroupComments)
            sProcess.options.Comment.Value = GroupComments{i};
        end
        % Compute group average
        OutputFiles{end+1} = AverageFiles(sProcess, sInputs(iGroups{i}), KeepEvents, isScaleDspm, isWeighted, isMatchRows, isZeroBad);
    end
end



%% ===== SORT FILES =====
function [iGroups, GroupComments, GroupNames] = SortFiles(sInputs, avgtype)
    GroupComments = [];
    GroupNames = {};
    % Group files in different ways: by subject, by condition, or all together
    switch (avgtype)
        % === EVERYTHING ===
        case 1
            iGroups = {1:length(sInputs)};
            GroupNames{1} = 'All';
            
        % === BY SUBJECT ===
        case 2
            [uniqueSubj,I,J] = unique({sInputs.SubjectFile});
            iGroups = cell(1, length(uniqueSubj));
            for i = 1:length(uniqueSubj)
                iGroups{i} = find(J == i)';
                GroupNames{i} = sInputs(iGroups{i}(1)).SubjectName;
            end
            
        % === BY CONDITION ===
        case {3,4}
            % Subject average
            if (avgtype == 3)
                inputCondPath = cell(1,length(sInputs));
                for iInput = 1:length(sInputs)
                    inputCondPath{iInput} = [sInputs(iInput).SubjectName, '/', sInputs(iInput).Condition];
                end
            % Grand average
            else
                inputCondPath = {sInputs.Condition};
            end
            % Process each condition independently
            [uniqueCond,I,J] = unique(inputCondPath);
            iGroups = cell(1, length(uniqueCond));
            GroupComments = cell(1, length(uniqueCond));
            for i = 1:length(uniqueCond)
                iGroups{i} = find(J == i)';
                GroupComments{i} = sInputs(iGroups{i}(1)).Condition;
            end
            GroupNames = uniqueCond;
                    
        % === BY TRIAL GROUPS ===
        case {5,6,7}
            % Get the condition path (SubjectName/Condition/CommentBase) or (Condition/CommentBase) for each input file
            CondPath = cell(1, length(sInputs));
            trialComment = cell(1, length(sInputs));
            for iInput = 1:length(sInputs)
                % Default comment
                trialComment{iInput} = sInputs(iInput).Comment;
                % If results/timefreq and attached to a data file
                if any(strcmpi(sInputs(iInput).FileType, {'results','timefreq'})) && ~isempty(sInputs(iInput).DataFile)
                    switch (file_gettype(sInputs(iInput).DataFile))
                        case 'data'
                            [sStudyAssoc, iStudyAssoc, iFileAssoc] = bst_get('DataFile', sInputs(iInput).DataFile);
                            if ~isempty(sStudyAssoc)
                                trialComment{iInput} = sStudyAssoc.Data(iFileAssoc).Comment;
                            else
                                bst_report('Warning', 'process_average', sInputs(iInput), ['File skipped, the parent node has been deleted:' 10 sInputs(iInput).DataFile]);
                            end
                            
                        case {'results', 'link'}
                            [sStudyAssoc, iStudyAssoc, iFileAssoc] = bst_get('ResultsFile', sInputs(iInput).DataFile);
                            if ~isempty(sStudyAssoc)
                                [sStudyAssoc2, iStudyAssoc2, iFileAssoc2] = bst_get('DataFile', sStudyAssoc.Result(iFileAssoc).DataFile);
                                if ~isempty(sStudyAssoc2)
                                    trialComment{iInput} = sStudyAssoc2.Data(iFileAssoc2).Comment;
                                else
                                    bst_report('Warning', 'process_average', sInputs(iInput), ['File skipped, the parent node has been deleted:' 10 sStudyAssoc.Result(iFileAssoc).DataFile]);
                                end
                            else
                                bst_report('Warning', 'process_average', sInputs(iInput), ['File skipped, the parent node has been deleted:' 10 sInputs(iInput).DataFile]);
                            end
                            
                        case 'matrix'
                            [sStudyAssoc, iStudyAssoc, iFileAssoc] = bst_get('MatrixFile', sInputs(iInput).DataFile);
                            if ~isempty(sStudyAssoc)
                                trialComment{iInput} = sStudyAssoc.Matrix(iFileAssoc).Comment;
                            else
                                bst_report('Warning', 'process_average', sInputs(iInput), ['File skipped, the parent node has been deleted:' 10 sInputs(iInput).DataFile]);
                            end
                    end
                end
                % Condition average
                if (avgtype == 5)
                    CondPath{iInput} = [sInputs(iInput).SubjectName, '/', sInputs(iInput).Condition, '/', str_remove_parenth(trialComment{iInput})];
                % Subject average
                elseif (avgtype == 6)
                    CondPath{iInput} = [sInputs(iInput).SubjectName, '/', str_remove_parenth(trialComment{iInput})];
                % Grand average
                else
                    CondPath{iInput} = str_remove_parenth(trialComment{iInput});
                end
            end
            
            % Process each condition independently
            [uniquePath,I,J] = unique(CondPath);
            iGroups = cell(1, length(uniquePath));
            GroupComments = cell(1, length(uniquePath));
            for i = 1:length(uniquePath)
                % Skip empty paths
                if isempty(uniquePath{i})
                    continue;
                end
                % Find files in this condition
                iGroups{i} = find(J == i)';
                GroupComments{i} = str_remove_parenth(trialComment{iGroups{i}(1)});
            end
            GroupNames = uniquePath;
    end
end


%% ===== AVERAGE FILES =====
function OutputFile = AverageFiles(sProcess, sInputs, KeepEvents, isScaleDspm, isWeighted, isMatchRows, isZeroBad)
    OutputFile = [];
    % Parse inputs
    if (nargin < 7) || isempty(isZeroBad)
        isZeroBad = 1;
    end
    if (nargin < 6) || isempty(isMatchRows)
        isMatchRows = 1;
    end
    if (nargin < 5) || isempty(isWeighted)
        isWeighted = 0;
    end
    if (nargin < 4) || isempty(isScaleDspm)
        isScaleDspm = 0;
    end
    if (nargin < 3) || isempty(KeepEvents)
        KeepEvents = 0;
    end
    
    % === PROCESS AVERAGE ===
    % Get function
    isResults = strcmpi(sInputs(1).FileType, 'results');
    % if isResults && isfield(sProcess.options, 'avg_func')
    if isfield(sProcess.options, 'avg_func') && isfield(sProcess.options.avg_func, 'Value') && ~isempty(sProcess.options.avg_func.Value)
        switch (sProcess.options.avg_func.Value)
            case 1,  Function = 'mean';   isVariance = 0;   strComment = 'Avg';
            case 2,  Function = 'abs';    isVariance = 0;   strComment = 'Avg(abs)';
            case 3,  Function = 'rms';    isVariance = 0;   strComment = 'RMS';
            case 4,  Function = 'mean';   isVariance = 1;   strComment = 'Std';
            case 5,  Function = 'mean';   isVariance = 1;   strComment = 'StdError';
            case 6,  Function = 'mean';   isVariance = 1;   strComment = 'AvgStd';
            case 7,  Function = 'mean';   isVariance = 1;   strComment = 'AvgStderr';
            case 8,  Function = 'median'; isVariance = 0;   strComment = 'Median';
        end
    else
        Function = 'mean';   isVariance = 0;   strComment = 'Avg';
    end
    % Compute average
    [Stat, Messages, iAvgFile, Events] = bst_avg_files({sInputs.FileName}, [], Function, isVariance, isWeighted, isMatchRows, isZeroBad, 1);
  
    % Apply corrections on the variance value
    if strcmpi(strComment, 'Std') || strcmpi(strComment, 'AvgStd')
        Stat.var = sqrt(Stat.var);
    elseif strcmpi(strComment, 'StdError') ||  strcmpi(strComment, 'AvgStderr')
        Stat.var = sqrt(Stat.var / length(sInputs));
    end
    % Add messages to report
    if ~isempty(Messages)
        if isempty(Stat)
            bst_report('Error', sProcess, sInputs, Messages);
            return;
        else
            bst_report('Warning', sProcess, sInputs, Messages);
        end
    end
    
    % Load first file of the list
    [sMat, matName] = in_bst(sInputs(iAvgFile(1)).FileName);
    
    % === SCALE dSPM VALUES (DEPRECATED AFTER INVERSE 2018) ===
    % Apply a scaling to the dSPM functions, to compensate for the fact that the scaling applied to the NoiseCov was not correct
    if isScaleDspm && isResults && isfield(sMat, 'Function') && ismember(sMat.Function, {'dspm','mnp','glsp','lcmvp'}) && isfield(sMat, 'ImageGridAmp')
        if ~isWeighted
            bst_report('Warning', sProcess, [], 'You cannot scale the normalized maps if you do not compute a weighted average. Select the option "Weighted" to enable this option.');
        elseif (sMat.nAvg ~= Stat.nAvg)
            Factor = sqrt(Stat.nAvg) / sqrt(sMat.nAvg);
            bst_report('Warning', sProcess, [], sprintf('Averaging normalized maps (%s): scaling the values by %1.3f to match the number of trials averaged (%d => %d)', sMat.Function, Factor, sMat.nAvg, Stat.nAvg));
            % Apply on both .var and .mean fields
            if isfield(Stat, 'mean') && ~isempty(Stat.mean)
                Stat.mean = Factor * Stat.mean;
            end
            if isfield(Stat, 'var') && ~isempty(Stat.var)
                Stat.var = (Factor ^ 2) * Stat.var;
            end
        end
        % disp('BST> Warning: Averaging dSPM maps is different from computing the dSPM of the average. ');
        % disp('BST>          => dSPM(Average) = sqrt(N) * Average(dSPM)');
    end
    
    % === CREATE OUTPUT STRUCTURE ===
    % Get output study
    [sStudy, iStudy, Comment, uniqueDataFile] = bst_process('GetOutputStudy', sProcess, sInputs);
    % Comment: forced in the options
    if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
        Comment = [strComment ': ' sProcess.options.Comment.Value, ' (' num2str(length(sInputs)) ' files)'];
    % Comment: Process default
    else
        % % Replace the number of files
        % Comment = strrep(Comment, [num2str(length(sInputs)) ' '], [num2str(length(iAvgFile)) ' ']);
        % % Add file name
        % Comment = [strComment ': ' Comment, ' (' num2str(length(sInputs)) ' files)'];
        Comment = [strComment ': ' Comment];
    end
    % Weighted
    if isWeighted && ~strcmpi(strComment, 'Median')
        Comment = ['W' Comment];
    end
    % Copy fields from Stat structure
    switch (strComment)
        case {'Avg', 'Avg(abs)', 'RMS', 'Median'}
            sMat.(matName) = Stat.mean;
        case {'Std', 'StdError'}
            sMat.(matName) = Stat.var;
        case {'AvgStd', 'AvgStderr'}
            sMat.(matName) = Stat.mean;
            sMat.Std = Stat.var;
    end
    sMat.ChannelFlag = Stat.ChannelFlag;
    sMat.Time        = Stat.Time;
    sMat.nAvg        = Stat.nAvg;
    sMat.Leff        = Stat.Leff;
    sMat.Comment     = Comment;
    
    % History: Average
    if isfield(sMat, 'History')
        % Copy the history of the first file (but remove the entries "import_epoch" and "import_time")
        prevHistory = sMat.History;
        if ~isempty(prevHistory)
            % Remove entry 'import_epoch'
            iLineEpoch = find(strcmpi(prevHistory(:,2), 'import_epoch'));
            if ~isempty(iLineEpoch)
                prevHistory(iLineEpoch,:) = [];
            end
            % Remove entry 'import_time'
            iLineTime  = find(strcmpi(prevHistory(:,2), 'import_time'));
            if ~isempty(iLineTime)
                prevHistory(iLineTime,:) = [];
            end
        end
        % History for the new average file
        sMat = bst_history('reset', sMat);
        sMat = bst_history('add', sMat, 'average', FormatComment(sProcess));
        sMat = bst_history('add', sMat, 'average', 'History of the first file:');
        sMat = bst_history('add', sMat, prevHistory, ' - ');
    else
        sMat = bst_history('add', sMat, 'average', Comment);
    end
    % History: Number of files averaged for each channel
    if any(Stat.nGoodSamples(1) ~= Stat.nGoodSamples) && isfield(Stat, 'RowNames') && ~isempty(Stat.RowNames) && iscell(Stat.RowNames) && (length(Stat.RefRowNames) <= 1)
        strInfo = 'Number of files that were averaged, for each signal:';
        sMat = bst_history('add', sMat, 'average', strInfo);
        uniqueGood = unique(Stat.nGoodSamples);
        for i = length(uniqueGood):-1:1
            strHistoryGood = [sprintf(' - %d files: ', uniqueGood(i)), sprintf('%s ', Stat.RowNames{Stat.nGoodSamples == uniqueGood(i)})];
            sMat = bst_history('add', sMat, 'average', strHistoryGood);
            strInfo = [strInfo, 10, strHistoryGood];
        end
        % Generate process warning
        bst_report('Warning', sProcess, sInputs, strInfo);
    end
    % History: List files
    sMat = bst_history('add', sMat, 'average', 'List of averaged files:');
    for i = 1:length(iAvgFile)
        sMat = bst_history('add', sMat, 'average', [' - ' sInputs(iAvgFile(i)).FileName]);
    end
    
    % Averaging results from the different data file: reset the "DataFile" field
    if isfield(sMat, 'DataFile') && ~isempty(sMat.DataFile) && (length(uniqueDataFile) ~= 1)
        sMat.DataFile = [];
    end
    % Copy all the events found in the input files
    if KeepEvents && ~isempty(Events)
        sMat.Events = Events;
    else
        sMat.Events = [];
    end
    % Rownames
    if isfield(Stat, 'RowNames') && ~isempty(Stat.RowNames)
        if strcmpi(matName, 'TF')
            sMat.RowNames = Stat.RowNames;
        elseif strcmpi(matName, 'Value')
            sMat.Description = Stat.RowNames;
        end
    end

    % === AVERAGE WARPED BRAINS ===
    if isResults
        sMat = FixWarpedSurfaceFile(sMat, sInputs(1), sStudy);
    end
    
    % === SAVE FILE ===
    % Output filename
    if strcmpi(sInputs(1).FileType, 'data')
        allFiles = {};
        for i = 1:length(sInputs)
            [tmp, allFiles{end+1}, tmp] = bst_fileparts(sInputs(i).FileName);
        end
        fileTag = str_common_path(allFiles, '_');
    else
        fileTag = bst_process('GetFileTag', sInputs(1).FileName);
    end
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [fileTag, '_average']);
    % Save on disk
    bst_save(OutputFile, sMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFile, sMat);
end



%% ===== FIX SURFACE FOR WARPED BRAINS =====
% Average source files coming from different subjects that are all different deformations of the default brain: 
% should re-use the initial cortex surface instead of the first cortex surface available
function [sMat, isFixed] = FixWarpedSurfaceFile(sMat, sInput, sStudyDest)
    isFixed = 0;
    % Not a warped surface: skip
    if ~isfield(sMat, 'SurfaceFile') || isempty(sMat.SurfaceFile) || isempty(strfind(sMat.SurfaceFile, '_warped'))
        return;
    end
    % Must be from non-default to default anatomy
    isDestDefaultSubj = ismember(bst_fileparts(sStudyDest.BrainStormSubject), {bst_get('DirDefaultSubject'), bst_get('NormalizedSubjectName')});
    isSrcDefaultSubj  = ismember(bst_fileparts(sInput.SubjectFile),           {bst_get('DirDefaultSubject'), bst_get('NormalizedSubjectName')});
    if isSrcDefaultSubj || ~isDestDefaultSubj
        return;
    end
    % Rebuild possible target surface
    [tmp, fBase, fExt] = bst_fileparts(sMat.SurfaceFile);
    SurfaceFileDest = [bst_get('DirDefaultSubject'), '/', strrep([fBase, fExt], '_warped', '')];
    % Find destination file in database
    [sSubjectDest, iSubjectDes, iSurfDest] = bst_get('SurfaceFile', SurfaceFileDest);
    if isempty(iSurfDest)
        return;
    end
    % If this surface exists: use it if it has the same number of vertices as the source surface
    % Get the vertices number from source and destination surface files
    VarInfoSrc  = whos('-file', file_fullpath(sMat.SurfaceFile), 'Vertices');
    VarInfoDest = whos('-file', file_fullpath(SurfaceFileDest), 'Vertices');
    % Number of vertices match: change the surface
    if (VarInfoSrc.size(1) == VarInfoDest.size(1))
        sMat.SurfaceFile = SurfaceFileDest;
        isFixed = 1;
    end
end





