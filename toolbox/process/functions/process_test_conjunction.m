function varargout = process_test_conjunction( varargin )
% PROCESS_TEST_CONJUCTION: Example file that reads all the data files in input, and saves the average.

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
% Authors: Francois Tadel, Dimitrios Pantazis, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Conjuction inference';
    sProcess.FileTag     = '';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Test';
    sProcess.Index       = 720;
    sProcess.Description = 'https://neuroimage.usc.edu/forums/t/common-source-activation-across-subjects-and-conditions/1152';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    sProcess.isSeparator = 1;
    % Definition of the options
    sProcess.options.label.Comment = ['For each value in the input file (each signal, time, and frequency):<BR>' ...
                                      'Return the statistic that corresponds to the largest p-value (max pmap).<BR><BR>' ...
                                      '<FONT color="#707070">Reference:<BR>' ...
                                      'Nichols T, Brett M, Andersson J, Wager T, Poline J-B<BR>' ...
                                      'Valid conjunction inference with the minimum statistic<BR>', ...
                                      'NeuroImage, 2005</FONT>'];
    sProcess.options.label.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned list of files
    OutputFiles = {};

    % ===== COMPUTE MIN(PMAP) / MAX(TMAP) =====
    ConjMat = [];
    % Reading all the input files in a big matrix
    for i = 1:length(sInputs)
        % Read the file #i
        StatMat = in_bst(sInputs(i).FileName);
        % Only the stat files computed by Brainstorm are supported
        if isempty(StatMat.pmap) || isempty(StatMat.tmap)
            bst_report('Error', sProcess, sInputs, 'Only the stat files computed by Brainstorm are supported (both pmap and tmap must be defined).');
            return;
        end
        % First file: initialize the accumulator
        if (i == 1)
            ConjMat = StatMat;
            ConjMat.df = [];
            ConjMat.SPM = [];
            ConjMat.StatClusters = [];
        % Other files: Check the dimensions of the data matrix
        elseif ~isequal(size(StatMat.pmap), size(ConjMat.pmap)) &&  ~isequal(size(StatMat.tmap), size(ConjMat.tmap))
            bst_report('Error', sProcess, sInputs, 'One file has a different number of values (signals, time samples or frequencies)');
            return;
        % Following files: Get the maximum p-value, and the corresponding t-value
        else
            iUpdate = find(StatMat.pmap > ConjMat.pmap);
            if ~isempty(iUpdate)
                ConjMat.pmap(iUpdate) = StatMat.pmap(iUpdate);
                ConjMat.tmap(iUpdate) = StatMat.tmap(iUpdate);
            end
        end
    end
    
    % ===== SAVE THE RESULTS =====
    % Get output study
    [sStudy, iStudy, Comment, uniqueDataFile] = bst_process('GetOutputStudy', sProcess, sInputs);
    % Comment
    ConjMat.Comment = ['Conjuction: ' Comment];
    
    % History: Average
    if isfield(ConjMat, 'History')
        % Copy the history of the first file (but remove the entries "import_epoch" and "import_time")
        prevHistory = ConjMat.History;
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
        ConjMat = bst_history('reset', ConjMat);
        ConjMat = bst_history('add', ConjMat, 'conjunction', Comment);
        ConjMat = bst_history('add', ConjMat, 'conjunction', 'History of the first file:');
        ConjMat = bst_history('add', ConjMat, prevHistory, ' - ');
    else
        ConjMat = bst_history('add', ConjMat, 'conjunction', Comment);
    end
    % History: List files
    ConjMat = bst_history('add', ConjMat, 'average', 'List of test files:');
    for i = 1:length(sInputs)
        ConjMat = bst_history('add', ConjMat, 'average', [' - ' sInputs(i).FileName]);
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
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [fileTag, '_conjunction']);
    % Save on disk
    bst_save(OutputFiles{1}, ConjMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFiles{1}, ConjMat);
    % Refresh display
    panel_protocols('UpdateNode', 'Study', iStudy);
    panel_protocols('SelectNode', [], OutputFiles{1});
end

