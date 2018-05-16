function varargout = process_select_uniform( varargin )
% PROCESS_SELECT_UNIFORM: Select a uniform number of trials across two lists.
%
% USAGE:     sProcess = process_select_subset('GetDescription')
%         OutputFiles = process_select_subset('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2015-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Select uniform number of trials';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1015;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Definition of the options
    % === AVERAGE TYPE
    sProcess.options.label1.Comment = ['This process sorts the trials in different groups, then<BR>' ...
                                       'selects the same number of trials from each group.<BR><BR>' ...
                                       '<U><B>How to group the trials</B></U>:'];
    sProcess.options.label1.Type    = 'label';
    sProcess.options.group.Comment = {'By folder', 'By trial group (folder)', 'By trial group (subject)'};
    sProcess.options.group.Type    = 'radio';
    sProcess.options.group.Value   = 2;
    % === NUMBER OF FILES
    sProcess.options.label2.Comment = '<BR><U><B>How many trials to select per group</B></U>:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.label3.Comment = ['You can enter the number of trials to use for each group,<BR>'  ...
                                       'or detect the maximum number of good trials that can be <BR>'  ...
                                       'selected in all the groups (enter zero below).'];
    sProcess.options.label3.Type    = 'label';
    sProcess.options.nfiles.Comment = 'Number of trials per group (0=detect): ';
    sProcess.options.nfiles.Type    = 'value';
    sProcess.options.nfiles.Value   = {0, '', 0};
    % === FILENAME / COMMENT
    sProcess.options.label4.Comment = '<BR><U><B>How to select trials in a group</B></U>:';
    sProcess.options.label4.Type    = 'label';
    sProcess.options.method.Comment = {'Random selection', 'First in the list', 'Last in the list', 'Uniformly distributed'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 4;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Number of files
    Comment = ['Select uniform number of trials: ' sProcess.options.group.Comment{sProcess.options.group.Value}];
    % How to select the files
    switch (sProcess.options.method.Value)
        case 1,  Comment = [Comment, ' [random]'];
        case 2,  Comment = [Comment, ' [first]'];
        case 3,  Comment = [Comment, ' [last]'];
        case 4,  Comment = [Comment, ' [uniform]'];
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Convert to method index in the average proces
    switch sProcess.options.group.Value 
        case 1,  avgtype = 3;   % By folder (subject average)
        case 2,  avgtype = 5;   % By trial group (folder average)
        case 3,  avgtype = 6;   % By trial group (subject average)
    end
    % Group files by condition
    [iGroups, GroupComments, GroupNames] = process_average('SortFiles', sInputs, avgtype);
    % Get number of trials per group
    if isfield(sProcess.options, 'nfiles') && isfield(sProcess.options.nfiles, 'Value') && ~isempty(sProcess.options.nfiles.Value)
        nFiles = sProcess.options.nfiles.Value{1};
    else
        nFiles = 0;
    end
    % Detect minimum number of good trials in a group
    nFilesMin = min(cellfun(@length, iGroups));
    % Use this minimum
    if isempty(nFiles) || (nFiles == 0)
        nFiles = nFilesMin;
    elseif (nFiles > nFilesMin)
        bst_report('Error', sProcess, sInputs, sprintf('Error: %d trials requested, while only %d are available.', nFiles, nFilesMin));
        return;
    end
    % Error management
    if (length(iGroups) == 1)
        bst_report('Error', sProcess, sInputs, 'All the input files are in the same group.');
        return;
    elseif (nFiles == 1)
        bst_report('Error', sProcess, sInputs, 'The smallest group contains only one file. Maybe you included averages in the input list.');
        return;
    end
    
    % Select the same number of trials for all the groups
    strInfo = sprintf('Using %d trials in each group out of:\n', nFiles);
    for i = 1:length(iGroups)
        % Add process info  
        strInfo = [strInfo, sprintf(' - %s: %d trials\n', GroupNames{i}, length(iGroups{i}))];
        % If the group already contains the correct number of trials: skip
        if (length(iGroups{i}) == nFiles)
            continue;
        end
        % Select a subset
        switch (sProcess.options.method.Value)
            case 1,  iGroups{i} = iGroups{i}(randperm(length(iGroups{i}), nFiles));
            case 2,  iGroups{i} = iGroups{i}(1:nFiles);
            case 3,  iGroups{i} = iGroups{i}((length(iGroups{i})-nFiles+1):length(iGroups{i}));
            case 4,  iGroups{i} = iGroups{i}(round(linspace(1, length(iGroups{i}), nFiles)));
        end
    end
    % Add number of selected files in the report
    if (nFiles <= 10)
        bst_report('Warning', sProcess, sInputs, strInfo);
    else
        bst_report('Info', sProcess, sInputs, strInfo);
    end
    % Return the selected filenames
    OutputFiles = {sInputs(sort([iGroups{:}])).FileName};
end



