function varargout = process_select_subset( varargin )
% PROCESS_SELECT_SUBSET: Select a subset of files from a list.
%
% USAGE:     sProcess = process_select_subset('GetDescription')
%         OutputFiles = process_select_subset('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Select files: Subset';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1015;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === TARGET
    sProcess.options.nfiles.Comment = 'Number of files to select: ';
    sProcess.options.nfiles.Type    = 'value';
    sProcess.options.nfiles.Value   = {1, ' files', 0};
    % === FILENAME / COMMENT
    sProcess.options.label1.Comment = 'How to pick the files:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.method.Comment = {'Random selection', 'First in the list', 'Last in the list', 'Uniformly distributed'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Number of files
    nFiles = sProcess.options.nfiles.Value{1};
    Comment = ['Select ' num2str(nFiles) ' files '];
    % How to select the files
    switch (sProcess.options.method.Value)
        case 1,  Comment = [Comment, '(random)'];
        case 2,  Comment = [Comment, '(first)'];
        case 3,  Comment = [Comment, '(last)'];
        case 4,  Comment = [Comment, '(uniform)'];
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Number of files
    nFiles = sProcess.options.nfiles.Value{1};
    if (nFiles < 1)
        bst_report('Error', sProcess, [], 'No files selected.');
        return;
    elseif (nFiles > length(sInputs))
        bst_report('Warning', sProcess, [], 'The number of files to select is larger than the number of input files.');
        OutputFiles = {sInputs.FileName};
        return;
    end
    % How to select the files
    switch (sProcess.options.method.Value)
        case 1,  iFiles = sort(randperm(length(sInputs), nFiles));
        case 2,  iFiles = (1:nFiles);
        case 3,  iFiles = ((length(sInputs)-nFiles+1):length(sInputs));
        case 4,  iFiles = round(linspace(1, length(sInputs), nFiles));
    end
    % Return the selected filenames
    OutputFiles = {sInputs(iFiles).FileName};
end



