function varargout = process_select_search( varargin )
% PROCESS_SELECT_SEARCH: Keep only the files within the current selection that pass a given database search query.
%
% USAGE:  sProcess = process_select_search('GetDescription')
%                    process_select_search('Run', sProcess, sInputs)

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
% Authors: Martin Cousineau, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Select files: Search query';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1014;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % Definition of the options
    % === TARGET
    sProcess.options.search.Comment = 'Search query: ';
    sProcess.options.search.Type    = 'text';
    sProcess.options.search.Value   = '';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Option: Search
    search = strtrim(sProcess.options.search.Value);
    if isempty(search)
        search = 'Not defined';
    end
    Comment = ['Select files using search query: ' search];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get search
    search = sProcess.options.search.Value;
    if isempty(search)
        bst_report('Error', sProcess, [], 'Search query is not defined.');
        return
    end
    % Error: no input files
    if isempty(sInputs)
        bst_report('Error', sProcess, [], 'No input files.');
        return;
    end
    
    % Convert search string to search structure
    try
        searchRoot = panel_search_database('StringToSearch', search);
    catch e
        bst_report('Error', sProcess, [], ['Invalid search syntax: ' e.message]);
        return;
    end
    % Apply search
    iFiles = find(node_apply_search(searchRoot, {sInputs.FileType}, {sInputs.Comment}, {sInputs.FileName}, [sInputs.iStudy]));
    
    % Warning: nothing found
    if isempty(iFiles)
        bst_report('Error', sProcess, [], ['No files found for search: ' search]);
        return;
    end
    % Report information
    strReport = sprintf('Files selected for search "%s": %d/%d', search, length(iFiles), length(sInputs));
    bst_report('Info', sProcess, [], strReport);
    % Return only the filenames that passed the search
    OutputFiles = {sInputs(iFiles).FileName};
end


