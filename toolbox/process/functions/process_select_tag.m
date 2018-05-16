function varargout = process_select_tag( varargin )
% PROCESS_SELECT_TAG: Keep only the files within the current selection that have the specified tag in their filename.
%
% USAGE:  sProcess = process_select_tag('GetDescription')
%                    process_select_tag('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2012-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Select files: By tag';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1013;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % Definition of the options
    % === TARGET
    sProcess.options.tag.Comment = 'Search: ';
    sProcess.options.tag.Type    = 'text';
    sProcess.options.tag.Value   = '';
    % === FILENAME / COMMENT
    sProcess.options.label1.Comment = 'Where to look for:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.search.Comment = {'Search the file names', 'Search the file comments', 'Search the comments of the parent file'};
    sProcess.options.search.Type    = 'radio';
    sProcess.options.search.Value   = 2;
    % === SELECT / IGNORE
    sProcess.options.label2.Comment = 'What to do with these files:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.select.Comment = {'Select only the files with the tag', 'Ignore the files with the tag'};
    sProcess.options.select.Type    = 'radio';
    sProcess.options.select.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    % Option: Tag
    tag = strtrim(sProcess.options.tag.Value);
    if isempty(tag)
        tag = 'Not defined';
    end
    % Option: Filename/comment
    if isfield(sProcess.options, 'search') && isfield(sProcess.options.search, 'Value') && ~isempty(sProcess.options.search.Value)
        switch (sProcess.options.search.Value)
            case 1,  Method = 'filename';
            case 2,  Method = 'comment';
            case 3,  Method = 'parent';
        end
    else
        Method = 'comment';
    end
    % Option: Ignore/select
    if isfield(sProcess.options, 'select') && isfield(sProcess.options.select, 'Value') && ~isempty(sProcess.options.select.Value)
        isSelect = isequal(sProcess.options.select.Value, 1);
    else
        isSelect = 1;
    end
    % Assemble comment
    if isSelect
        Comment = 'Select';
    else
        Comment = 'Ignore';
    end
    switch (Method)
        case 'filename',  Comment = [Comment ' file names with tag: ' tag];
        case 'comment',   Comment = [Comment ' file comments with tag: ' tag];
        case 'parent',    Comment = [Comment ' parent comment with tag: ' tag];   
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Get new tag
    tag = sProcess.options.tag.Value;
    if isempty(tag)
        bst_report('Error', sProcess, [], 'Tag is not defined.');
        OutputFiles = {};
        return
    end
    % Error: no input files
    if isempty(sInputs)
        bst_report('Error', sProcess, [], 'No input files.');
        OutputFiles = {};
        return;
    end
    % Option: Filename/comment
    if isfield(sProcess.options, 'search') && isfield(sProcess.options.search, 'Value') && ~isempty(sProcess.options.search.Value)
        switch (sProcess.options.search.Value)
            case 1,  Method = 'filename';
            case 2,  Method = 'comment';
            case 3,  Method = 'parent';
        end
    else
        Method = 'comment';
    end
    % Option: Ignore/select
    if isfield(sProcess.options, 'select') && isfield(sProcess.options.select, 'Value') && ~isempty(sProcess.options.select.Value)
        isSelect = isequal(sProcess.options.select.Value, 1);
    else
        isSelect = 0;
    end
    
    % Search filenames/comments
    switch (Method)
        case 'filename'
            isTag = ~cellfun(@(c)isempty(strfind(upper(c),upper(tag))), {sInputs.FileName});
        case 'comment'
            isTag = ~cellfun(@(c)isempty(strfind(upper(c),upper(tag))), {sInputs.Comment});
        case 'parent'
            isTag = zeros(1, length(sInputs));
            upTag = upper(tag);
            % Search all the parent files one by one
            for i = 1:length(sInputs)
                % Do not go further if there is no parent
                if isempty(sInputs(i).DataFile)
                    continue;
                end
                % What to check depends on the file type
                switch (file_gettype(sInputs(i).DataFile))
                    case 'data'
                        % Find the file in database
                        [sStudy, iStudy, iData] = bst_get('DataFile', sInputs(i).DataFile, sInputs(i).iStudy);
                        % Check the comment
                        isTag(i) = ~isempty(strfind(upper(sStudy.Data(iData).Comment), upTag));
                    case {'results', 'link'}
                        % Find the file in database
                        [sStudy, iStudy, iResult] = bst_get('ResultsFile', sInputs(i).DataFile, sInputs(i).iStudy);
                        % Check the comment
                        isTag(i) = ~isempty(strfind(upper(sStudy.Result(iResult).Comment), upTag));
                        % If the file is not found but there is another parent level
                        if ~isTag(i) && ~isempty(sStudy.Result(iResult).DataFile) && strcmpi(file_gettype(sStudy.Result(iResult).DataFile), 'data')
                            [sStudy, iStudy, iData] = bst_get('DataFile', sStudy.Result(iResult).DataFile, sInputs(i).iStudy);
                            isTag(i) = ~isempty(strfind(upper(sStudy.Data(iData).Comment), upTag));
                        end
                    case 'matrix'
                        % Find the file in database
                        [sStudy, iStudy, iMatrix] = bst_get('MatrixFile', sInputs(i).DataFile, sInputs(i).iStudy);
                        % Check the comment
                        isTag(i) = ~isempty(strfind(upper(sStudy.Matrix(iMatrix).Comment), upTag));
                end
            end
    end
    % Ignore or select
    if isSelect
        iFiles = find(isTag);
    else
        iFiles = find(~isTag);
    end
    % Warning: nothing found
    if isempty(iFiles)
        bst_report('Error', sProcess, [], ['No files found for tag: ' tag]);
        OutputFiles = {};
        return;
    end
    % Report information
    strReport = sprintf('Files selected for tag "%s": %d/%d', tag, length(iFiles), length(sInputs));
    bst_report('Info', sProcess, [], strReport);
    % Return only the filenames that have the specific tag
    OutputFiles = {sInputs(iFiles).FileName};
end



