function varargout = process_phase_diff( varargin )
% PROCESS_PHASE_DIFF: Absolute difference of the phase of sets A and B.

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
% Authors: Konstantinos Nasiotis, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Absolute difference of phases';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Phase';
    sProcess.Index       = 120;
    sProcess.Description = 'www.skai.gr';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % === MATCH ROWS WITH NAMES
    sProcess.options.matchrows.Comment    = 'Match signals between files using their names';
    sProcess.options.matchrows.Type       = 'checkbox';
    sProcess.options.matchrows.Value      = 1;
    sProcess.options.matchrows.InputTypes = {'timefreq', 'matrix'};
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    OutputFiles = {};
    % Make sure that file type is indentical for both sets
    if ~isempty(sInputsA) && ~isempty(sInputsB) && ~strcmpi(sInputsA(1).FileType, sInputsB(1).FileType)
        bst_report('Error', sProcess, sInputsA, 'Cannot process inputs from different types.');
        return;
    end
    
    % Read first file of the list
    [sMat, matName] = in_bst(sInputsA.FileName);
    
    
    %% Read the two inputs
    
    
    
    
    
    
    
    
    
    
    
    
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
    if strcmpi(sInputsA(1).FileType, 'timefreq')
        sMat.Measure = 'other';
    end
    
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





