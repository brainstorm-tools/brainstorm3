function varargout = process_diff_mean( varargin )
% PROCESS_DIFF_MEAN: Difference of means of sets A and B.

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
% Authors: Francois Tadel, 2010-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Difference of means';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 100;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Difference';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    
    % === Absolue values: legend
    sProcess.options.labelavg.Type = 'label';
    sProcess.options.labelavg.Comment = 'Function to estimate the average across the files:';
    sProcess.options.labelavg.InputTypes = {'data', 'results', 'matrix'};
    % === Absolue values: type
    sProcess.options.avg_func.Comment = {'<B>Arithmetic average</B> <BR>mean(A) - mean(B)', ...
                                         '<B>Absolute value of average</B> <BR>abs(mean(A)) - abs(mean(B))', ...
                                         '<B>Average of absolute values</B> <BR>mean(abs(A)) - mean(abs(B))', ...
                                         '<B>Power</B> <BR>mean(A^2) - mean(B^2)'};
    sProcess.options.avg_func.Type    = 'radio';
    sProcess.options.avg_func.Value   = 2;
    sProcess.options.avg_func.InputTypes = {'data', 'results', 'matrix'};
    % === WEIGHTED AVERAGE
    sProcess.options.weighted.Comment    = 'Weighted average:  <FONT color="#777777">mean(x) = sum(Leff_i * x(i)) / sum(Leff_i)</FONT>';
    sProcess.options.weighted.Type       = 'checkbox';
    sProcess.options.weighted.Value      = 0;
    sProcess.options.weightedlabel.Comment    = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<FONT color="#777777">Leff_i = Effective number of averages for file #i</FONT>';
    sProcess.options.weightedlabel.Type       = 'label';
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
    
    % === UNCONSTRAINED SOURCES
    sProcess.options.label_norm.Comment    = ['<FONT color="#777777">Note: For unconstrained sources, "absolute value" refers to the norm<BR>' ...
                                              'of the three orientations: abs(F) = sqrt(Fx^2 + Fy^2 + Fz^2)</FONT>'];
    sProcess.options.label_norm.Type       = 'label';
    sProcess.options.label_norm.InputTypes = {'results'};
end


%% ===== FORMAT COMMENT =====
function [Comment, strAbs] = FormatComment(sProcess)
    % Weighted
    if isfield(sProcess.options, 'weighted') && isfield(sProcess.options.weighted, 'Value') && ~isempty(sProcess.options.weighted.Value) && sProcess.options.weighted.Value
        Comment = 'Difference of weighted means';
    else
        Comment = 'Difference of means';
    end
    % If sources: averaging option
    if isfield(sProcess.options, 'avg_func')
        switch(sProcess.options.avg_func.Value)
            case 1,  strAbs = '[mean]';
            case 2,  strAbs = '[abs(mean)]';
            case 3,  strAbs = '[mean(abs)]';
            case 4,  Comment = 'Difference of power';    strAbs = '';
        end
    else
        strAbs = '[mean]';
    end
    if ~isempty(strAbs)
        Comment = [Comment, ' ', strAbs];
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    OutputFiles = {};
    % Make sure that file type is indentical for both sets
    if ~isempty(sInputsA) && ~isempty(sInputsB) && ~strcmpi(sInputsA(1).FileType, sInputsB(1).FileType)
        bst_report('Error', sProcess, sInputsA, 'Cannot process inputs from different types.');
        return;
    end
    % === GET OPTIONS ===
    isResults = strcmpi(sInputsA(1).FileType, 'results');
    if isfield(sProcess.options, 'avg_func')
        switch (sProcess.options.avg_func.Value)
            case 1,  Function = 'mean'; isAbsDiff = 0; strComment = '';
            case 2,  Function = 'mean'; isAbsDiff = 1; strComment = ' [abs(avg)]';
            case 3,  Function = 'norm'; isAbsDiff = 0; strComment = ' [avg(abs)]';
            case 4,  Function = 'rms';  isAbsDiff = 0; strComment = ' [power]';
        end
    else
        strComment = '';
        Function = 'mean';
        isAbsDiff = 0;
    end
    % Weighted
    if isfield(sProcess.options, 'weighted') && isfield(sProcess.options.weighted, 'Value') && ~isempty(sProcess.options.weighted.Value)
        isWeighted = sProcess.options.weighted.Value;
    else
        isWeighted = 0;
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
    % Read first file of the list
    [sMat, matName] = in_bst(sInputsA(1).FileName);
    
    % === COMPUTE DIFFERENCE OF AVG ===
    % Compute average of the two sets of files
    isVariance = 0;
    [StatA, MessagesA, iAvgFileA] = bst_avg_files({sInputsA.FileName}, [], Function, isVariance, isWeighted, isMatchRows, isZeroBad);
    [StatB, MessagesB, iAvgFileB] = bst_avg_files({sInputsB.FileName}, [], Function, isVariance, isWeighted, isMatchRows, isZeroBad);
    % Add messages to report
    if ~isempty(MessagesA)
        if isempty(StatA)
            bst_report('Error', sProcess, sInputsA, MessagesA);
            return;
        else
            bst_report('Warning', sProcess, sInputsA, MessagesA);
        end
    end
    if ~isempty(MessagesB)
        if isempty(StatB)
            bst_report('Error', sProcess, sInputsB, MessagesB);
            return;
        else
            bst_report('Warning', sProcess, sInputsB, MessagesB);
        end
    end
    % Absolute values before difference
    if isAbsDiff
        % Unconstrained sources: Convert to flat map (norm of the three orientations)
        if isResults && isfield(sMat, 'nComponents') && (sMat.nComponents ~= 1)
            % Average A
            sMatTmp = sMat;
            sMat.(matName) = StatA.mean;
            sMat = process_source_flat('Compute', sMat, 'rms');
            StatA.mean = sMat.(matName);
            % Average B
            sMat = sMatTmp;
            sMat.(matName) = StatB.mean;
            sMat = process_source_flat('Compute', sMat, 'rms');
            StatB.mean = sMat.(matName);
            % Edit the comment field to indicate we used a norm
            strComment = strrep(strComment, 'abs', 'norm');
        end
        % Enforce absolute values
        StatA.mean = abs(StatA.mean);
        StatB.mean = abs(StatB.mean);
    % Unconstrained or mixed sources: source maps have been flattened by bst_avg_files
    elseif isResults && ismember(Function, {'norm', 'rms'}) && (sMat.nComponents ~= 1)
        sMat = process_source_flat('Compute', sMat, 'rms');
    end
    % Difference of power: square the rms that is returned by the averaging function
    if strcmpi(Function, 'rms')
        StatA.mean = StatA.mean .^ 2;
        StatB.mean = StatB.mean .^ 2;
    end
    % Check timefreq measures
    if ~isempty(StatA.Measure) && ~strcmpi(StatA.Measure, StatB.Measure)
        bst_report('Error', sProcess, [sInputsA(:)',sInputsB(:)'], 'The two sets of files have different measures applied to the time-frequency coefficients.');
        return
    end
    % Compute difference of averages
    StatA.mean = StatA.mean - StatB.mean;
    
    % === CREATE OUTPUT STRUCTURE ===
    bst_progress('start', 'Difference of means', 'Saving result...');
    [processComment, strAbs] = FormatComment(sProcess);
    % Get output study
    [sStudy, iStudy] = bst_process('GetOutputStudy', sProcess, [sInputsA, sInputsB]);
    % Comment: forced in the options
    if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
        Comment = sProcess.options.Comment.Value;
    % Comment: process default
    else
        % Get comment for files A and B
        [tmp__, tmp__, CommentA] = bst_process('GetOutputStudy', sProcess, sInputsA, [], 0);
        [tmp__, tmp__, CommentB] = bst_process('GetOutputStudy', sProcess, sInputsB, [], 0);
        if strcmpi(CommentA, CommentB) && ~strcmpi(sInputsA(1).Condition, sInputsB(1).Condition)
            CommentA = sInputsA(1).Condition;
            CommentB = sInputsB(1).Condition;
            % Add file number
            if (length(sInputsA) > 1) || (length(sInputsB) > 1)
                CommentA = [CommentA ' (' num2str(length(sInputsA)) ')'];
                CommentB = [CommentB ' (' num2str(length(sInputsB))  ')'];
            end
        end
        % Comment: difference A-B
        Comment = [CommentA ' - ' CommentB];
        if ~isempty(strAbs)
           Comment = [Comment ' ' strAbs];
        end
    end
    % Copy fields from StatA structure
    sMat.(matName)   = StatA.mean;
    sMat.Comment     = Comment;
    sMat.ChannelFlag = StatA.ChannelFlag;
    sMat.Time        = StatA.Time;
    sMat.nAvg        = StatA.nAvg + StatB.nAvg;
    % Effective number of averages
    % Leff = 1 / sum_i(w_i^2 / Leff_i),  with w1=1 and w2=-1
    %      = 1 / (1/Leff_A + 1/Leff_B))
    sMat.Leff = 1 / (1/StatA.Leff + 1/StatB.Leff);
    
    % Colormap for recordings: keep the original
    % Colormap for sources, timefreq... : difference (stat2)
    if ~strcmpi(sInputsA(1).FileType, 'data')
        sMat.ColormapType = 'stat2';
    end
    % Time-frequency: Change the measure type
    % if strcmpi(sInputsA(1).FileType, 'timefreq')
    %     sMat.Measure = 'other';
    % end
    
    % History: Average
    if isfield(sMat, 'History')
        prevHistory = sMat.History;
        sMat = bst_history('reset', sMat);
        sMat = bst_history('add', sMat, 'diff_mean', processComment);
        sMat = bst_history('add', sMat, 'diff_mean', 'History of the first file:');
        sMat = bst_history('add', sMat, prevHistory, ' - ');
    else
        sMat = bst_history('add', sMat, 'diff_mean', Comment);
    end
    % History: Number of files averaged for each channel
    if any(StatA.nGoodSamples(1) ~= StatA.nGoodSamples) && isfield(StatA, 'RowNames') && ~isempty(StatA.RowNames) && iscell(StatA.RowNames) && (length(StatA.RefRowNames) <= 1)
        strInfo = 'Number of files that were averaged, for each signal (FilesA):';
        sMat = bst_history('add', sMat, 'average', strInfo);
        uniqueGood = unique(StatA.nGoodSamples);
        for i = length(uniqueGood):-1:1
            strHistoryGood = [sprintf(' - %d files: ', uniqueGood(i)), sprintf('%s ', StatA.RowNames{StatA.nGoodSamples == uniqueGood(i)})];
            sMat = bst_history('add', sMat, 'average', strHistoryGood);
            strInfo = [strInfo, 10, strHistoryGood];
        end
        % Generate process warning
        bst_report('Warning', sProcess, sInputsA, strInfo);
    end
    % History: List files A
    sMat = bst_history('add', sMat, 'diff_mean', 'List of files in group A:');
    for i = 1:length(iAvgFileA)
        sMat = bst_history('add', sMat, 'diff_mean', [' - ' sInputsA(iAvgFileA(i)).FileName]);
    end
    % History: List files B
    sMat = bst_history('add', sMat, 'diff_mean', 'List of files in group B:');
    for i = 1:length(iAvgFileB)
        sMat = bst_history('add', sMat, 'diff_mean', [' - ' sInputsB(iAvgFileB(i)).FileName]);
    end
    
    % Averaging results from the different data file: reset the "DataFile" field
    if isfield(sMat, 'DataFile')
        sMat.DataFile = [];
    end
    % Do not keep the events
    if isfield(sMat, 'Events') && ~isempty(sMat.Events)
        sMat.Events = [];
    end
    % Fix surface link for warped brains
    if isfield(sMat, 'SurfaceFile') && ~isempty(sMat.SurfaceFile) && ~isempty(strfind(sMat.SurfaceFile, '_warped'))
        sMat = process_average('FixWarpedSurfaceFile', sMat, sInputsA(1), sStudy);
    end
    % Rownames
    if isfield(StatA, 'RowNames') && ~isempty(StatA.RowNames)
        if strcmpi(matName, 'TF')
            sMat.RowNames = StatA.RowNames;
        elseif strcmpi(matName, 'Value')
            sMat.Description = StatA.RowNames;
        end
    end
    
    % === SAVE FILE ===
    % Output filename
    fileTag = bst_process('GetFileTag', sInputsA(1).FileName);
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [fileTag, '_diff_mean']);
    % Save on disk
    bst_save(OutputFiles{1}, sMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFiles{1}, sMat);
end





