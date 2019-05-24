function varargout = process_decoding_maxcorr( varargin )
% PROCESS_DECODING_MAXCORR: Decoding of multiple conditions using max-correlation

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Martin Cousineau, 2019; Dimitrios Pantazis, 2019

eval(macro_method);
end

%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Pairwise max-correlation decoding';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Decoding';
    sProcess.Index       = 702;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Decoding';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;

    % Definition of the options
    sProcess.options.description.Comment = ['Apply max-correlation classifier on MEG trials.<BR>' ...
                                            'Uses trial subaverages and permutations. <BR><BR>'];
    sProcess.options.description.Type    = 'label';
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG';
    % === lowpass filtering
    sProcess.options.lowpass.Comment = 'Low-pass cutoff frequency (0=disabled): ';
    sProcess.options.lowpass.Type    = 'value';
    sProcess.options.lowpass.Value   = {30,'Hz',2};
    % === number of permutations
    sProcess.options.num_permutations.Comment = 'Number of permutations: ';
    sProcess.options.num_permutations.Type    = 'value';
    sProcess.options.num_permutations.Value   = {10,'',0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned variables
    OutputFiles = {};

    % Not available in the compiled version
    if exist('isdeployed', 'builtin') && isdeployed
        bst_report('Error', sProcess, sInputs, 'This function is not available in the compiled version of Brainstorm.');
    end
    % Check the number of files in input
    if length(sInputs) < 2
        bst_report('Error', sProcess, sInputs, 'Not enough files in input.');
        return;
    end
    % Check for the Signal Processing toolbox
    if ~bst_get('UseSigProcToolbox')
        bst_report('Error', sProcess, [], 'This process requires the Signal Processing Toolbox.');
        return;
    end
    % Check for the LibSVM toolbox
    if ~exist('svmpredict')
        bst_report('Error', sProcess, [], ['This process requires the LibSVM Toolbox:' 10 'http://www.csie.ntu.edu.tw/~cjlin/libsvm/#download']);
        return;
    end
    
    % Get options
    SensorTypes     = sProcess.options.sensortypes.Value;
    LowPass         = sProcess.options.lowpass.Value{1};
    numPermutations = sProcess.options.num_permutations.Value{1};
    
    % Summarize trials and conditions to process
    allConditions = {sInputs.Condition};
    [uniqueConditions, tmp, conditionMapping] = unique(allConditions);
    numConditions = length(uniqueConditions);
    fprintf('BST> Found %d different conditions across %d trials:%c', numConditions, length(sInputs), char(10));
    for iCondition = 1:numConditions
        numOccurences = sum(conditionMapping == iCondition);
        fprintf(' %d. Condition "%s" with %d associated trials%c', iCondition, uniqueConditions{iCondition}, numOccurences, char(10));
    end

    % ============
    % Load trials
    [trial,Time] = process_decoding_svm('load_trials_bs', sInputs, LowPass, SensorTypes);
    % Run max-correlation decoding
    bst_progress('start', 'Decoding', 'Training max-correlation model...');
    d = sll_decodemaxcorr(trial, allConditions, 'numpermutation', numPermutations, 'verbose', 1);

    % ===== CREATE OUTPUT FILE =====
    % Create file structure
    FileMat = db_template('matrixmat');
    FileMat.Comment     = sprintf('Max-correlation decoding on %d classes', numConditions);
    FileMat.Value       = mean(d.d, 2)';
    FileMat.Std         = std(d.d, 0, 2)';
    FileMat.Description = {'Accuracy'};  % Document the rows and/or the columns of the field "Value"
    FileMat.Time        = Time;

    % ===== OUTPUT CONDITION =====
    % Default condition name
    SubjectName = sInputs(1).SubjectName;
    Condition = 'decoding';
    % Get condition asked by user
    [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(SubjectName, Condition));
    % Condition does not exist: create it
    if isempty(sStudy)
        iStudy = db_add_condition(SubjectName, Condition, 1);
        sStudy = bst_get('Study', iStudy);
    end

    % ===== SAVE FILE =====
    % Output filename
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_decoding_max_correlation');
    % Save file
    bst_save(OutputFiles{1}, FileMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFiles{1}, FileMat);
end

