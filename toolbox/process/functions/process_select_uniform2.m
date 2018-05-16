function varargout = process_select_uniform2( varargin )
% PROCESS_SELECT_UNIFORM2: Select the same number of files in FilesA and FilesB.
%
% USAGE:                      sProcess = process_select_subset2('GetDescription')
%         [OutputFilesA, OutputFilesB] = process_select_subset2('Run', sProcess, sInputsA, sInputsB)

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
% Authors: Francois Tadel, 2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Select uniform number of files';
    sProcess.Category    = 'Custom2';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1015;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 2;
    sProcess.nOutputs    = 2;
    sProcess.nMinFiles   = 2;
    % Definition of the options
    sProcess.options.label1.Comment = ['This process selects the same number of files from the two <BR>' ...
                                       'lists FilesA and FilesB.<BR><BR>' ...
                                       '<U><B>How many files to select per list</B></U>:'];
    sProcess.options.label1.Type    = 'label';
    % === NUMBER OF FILES
    sProcess.options.label2.Comment = ['You can enter the number of trials to use for each list,<BR>'  ...
                                       'or use the maximum number of files common to A and B.'];
    sProcess.options.label2.Type    = 'label';
    sProcess.options.nfiles.Comment = 'Number of files per list (0=maximum): ';
    sProcess.options.nfiles.Type    = 'value';
    sProcess.options.nfiles.Value   = {0, '', 0};
    % === SELECTION METHOD
    sProcess.options.label3.Comment = '<BR><U><B>How to select files in each list</B></U>:';
    sProcess.options.label3.Type    = 'label';
    sProcess.options.method.Comment = {'Random selection', 'First in the list', 'Last in the list', 'Uniformly distributed'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 4;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Number of files
    Comment = 'Select uniform number of files ';
    % How to select the files
    switch (sProcess.options.method.Value)
        case 1,  Comment = [Comment, ' [random]'];
        case 2,  Comment = [Comment, ' [first]'];
        case 3,  Comment = [Comment, ' [last]'];
        case 4,  Comment = [Comment, ' [uniform]'];
    end
end


%% ===== RUN =====
function [sInputsA, sInputsB] = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    % Get number of files per list requested
    if isfield(sProcess.options, 'nfiles') && isfield(sProcess.options.nfiles, 'Value') && ~isempty(sProcess.options.nfiles.Value)
        nFiles = sProcess.options.nfiles.Value{1};
    else
        nFiles = 0;
    end
    % Actual numbers of files
    nFilesA = length(sInputsA);
    nFilesB = length(sInputsB);
    nFilesMin = min(nFilesA, nFilesB);
    % Use default value
    if isempty(nFiles) || (nFiles == 0)
        nFiles = nFilesMin;
    % Error if too many requested
    elseif (nFiles > nFilesMin)
        bst_report('Error', sProcess, sInputsA, sprintf('Error: %d trials requested, while only %d are available.', nFiles, nFilesMin));
        sInputsA = [];
        sInputsB = [];
        return;
    end

    % Select the same number of trials for both lists
    if (nFilesA > nFiles)
        switch (sProcess.options.method.Value)
            case 1,  iFilesA = randperm(nFilesA, nFiles);
            case 2,  iFilesA = 1:nFiles;
            case 3,  iFilesA = (nFilesA-nFiles+1):nFilesA;
            case 4,  iFilesA = round(linspace(1, nFilesA, nFiles));
        end
        sInputsA = sInputsA(iFilesA);
    end
    if (nFilesB > nFiles)
        switch (sProcess.options.method.Value)
            case 1,  iFilesB = randperm(nFilesB, nFiles);
            case 2,  iFilesB = 1:nFiles;
            case 3,  iFilesB = (nFilesB-nFiles+1):nFilesB;
            case 4,  iFilesB = round(linspace(1, nFilesB, nFiles));
        end
        sInputsB = sInputsB(iFilesB);
    end
    % Add number of selected files in the report
    bst_report('Info', sProcess, sInputsA, sprintf('Selecting %d files in each list.', nFiles));
end



