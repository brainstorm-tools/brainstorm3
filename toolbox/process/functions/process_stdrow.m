function varargout = process_stdrow( varargin )
% PROCESS_STDROW: Uniformize the list of rows for a set of time-frequency files.
%
% USAGE: OutputFiles = process_stdrow('Run', sProcess, sInputs)
%        [DestRowNames, AllRowNames, iRowsSrc, iRowsDest, msgError] = process_stdrow('GetUniformRows', FileNames, Method)
%        [DestRowNames, AllRowNames, iRowsSrc, iRowsDest, msgError] = process_stdrow('GetUniformRows', LoadedFiles, Method)

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
% Authors: Francois Tadel, 2013-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Uniform signal names';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 301;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq', 'matrix'};
    sProcess.OutputTypes = {'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    % Definition of the options
    % === TARGET LIST OF ROW NAMES
    sProcess.options.method.Comment = {'Keep only the common row names<BR>=> Remove all the others', ...
                                       'Keep all the row names<BR>=> Fill the missing signals with zeros', ...
                                       'Use the first file in the list as a template'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
    % === OVERWRITE
    sProcess.options.overwrite.Comment = 'Overwrite input files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    switch (sProcess.options.method.Value) 
        case 1,    Comment = [sProcess.Comment, ' (remove extra)'];
        case 2,    Comment = [sProcess.Comment, ' (add missing)'];
        case 3,    Comment = [sProcess.Comment, ' (use first)'];
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Options
    switch (sProcess.options.method.Value)
        case 1,  Method = 'common';
        case 2,  Method = 'all';
        case 3,  Method = 'first';
    end
    isOverwrite = sProcess.options.overwrite.Value;
    OutputFiles = {};
    
    % ===== GET TARGET LIST OF SIGNALS =====
    % Get list of common signals
    [DestRowNames, AllRowNames, iRowsSrc, iRowsDest, msgError] = GetUniformRows({sInputs.FileName}, Method);
    % Report errors and warnings
    if ~isempty(msgError)
        if isempty(DestRowNames)
            bst_report('Error', sProcess, sInputs, msgError);
            return;
        else
            bst_report('Warning', sProcess, sInputs, msgError);
        end
    end   
    % Check if there are any difference in the row names
    if all(cellfun(@(c)isequal(c,DestRowNames), AllRowNames))
        bst_report('Error', sProcess, sInputs, 'All the input files have identical row names.');
        return;
    end
    
    % ===== PROCESS FILES =====
    % Process each input file
    for iInput = 1:length(sInputs)
        % If it's a file that was not changed: skip to next file
        if isequal(DestRowNames, AllRowNames{iInput})
            OutputFiles{iInput} = file_fullpath(sInputs(iInput).FileName);
            continue;
        end
        
        % List of added rows
        iAddedRows = setdiff(1:length(DestRowNames), iRowsDest{iInput});
        iRemRows   = setdiff(1:length(AllRowNames{iInput}), iRowsSrc{iInput});
        % Add a history entry
        strHistory = 'Uniform list of signals:';
        if ~isempty(iAddedRows)
            strTmp = '';
            for i = 1:length(iAddedRows)
                strTmp = [strTmp, DestRowNames{iAddedRows(i)}, ','];
            end
            strHistory = [strHistory, sprintf(' %d added (%s)', length(iAddedRows), strTmp(1:end-1))];
        end
        if ~isempty(iRemRows)
            strTmp = '';
            for i = 1:length(iRemRows)
                strTmp = [strTmp, AllRowNames{iInput}{iRemRows(i)}, ','];
            end
            strHistory = [strHistory, sprintf(' %d removed (%s)', length(iRemRows), strTmp(1:end-1))];
        end
        
        % Load the data file
        fileMat = load(file_fullpath(sInputs(iInput).FileName));
        newFileMat = fileMat;
        % Saved structure depends on the file type
        switch lower(sInputs(iInput).FileType)
            case 'timefreq'
                newFileMat.TF = zeros(length(DestRowNames), size(fileMat.TF,2), size(fileMat.TF,3));
                newFileMat.TF(iRowsDest{iInput},:) = fileMat.TF(iRowsSrc{iInput},:);
                newFileMat.RowNames = DestRowNames;
                % Do not keep the Std field in the output
                if isfield(newFileMat, 'Std') && ~isempty(newFileMat.Std)
                    newFileMat.Std = [];
                end
            case 'matrix'
                newFileMat.Value = zeros(length(DestRowNames), size(fileMat.Value,2));
                newFileMat.Value(iRowsDest{iInput},:) = fileMat.Value(iRowsSrc{iInput},:);
                newFileMat.Description = DestRowNames;
        end
        % Add comment
        newFileMat.Comment = [newFileMat.Comment ' | stdrow'];
        % Add a history entry
        newFileMat = bst_history('add', newFileMat, 'stdrow', strHistory);
        
        % Overwrite the input file
        if isOverwrite
            OutputFiles{iInput} = file_fullpath(sInputs(iInput).FileName);
            bst_save(OutputFiles{iInput}, newFileMat, 'v6');
        % Create a new file
        else
            % Output filename: add file tag
            OutputFiles{iInput} = strrep(file_fullpath(sInputs(iInput).FileName), '.mat', '_stdrow.mat');
            OutputFiles{iInput} = file_unique(OutputFiles{iInput});
            % Save file
            bst_save(OutputFiles{iInput}, newFileMat, 'v6');
            % Add file to database structure
            db_add_data(sInputs(iInput).iStudy, OutputFiles{iInput}, newFileMat);
        end
    end
end



%% ===== GET UNIFORM ROWS =====
function [DestRowNames, AllRowNames, iRowsSrc, iRowsDest, msgError] = GetUniformRows(FileNames, Method)
    AllRowNames   = cell(1,length(FileNames));
    nRows         = zeros(1,length(FileNames));
    iRowsSrc      = cell(1,length(FileNames));
    iRowsDest     = cell(1,length(FileNames));
    unionRowNames = {};
    interRowNames = {};
    DestRowNames  = [];
    msgError      = [];
    % Check all the input files
    for iInput = 1:length(FileNames)
        % Cannot process connectivity files
        if ischar(FileNames{iInput}) && ~isempty(strfind(FileNames{iInput}, '_connectn'))
            msgError = 'STDROW> Cannot process connectivity [NxN] results.';
            return;
        end
        % Load row names
        switch (file_gettype(FileNames{iInput}))
            case 'timefreq'
                if ischar(FileNames{iInput})
                    fileMat = in_bst_timefreq(FileNames{iInput}, 0, 'DataType', 'RowNames', 'RefRowNames');
                else
                    fileMat = FileNames{iInput};
                end
                % Check file type: Cannot process source files
                if strcmpi(fileMat.DataType, 'results') || ~iscell(fileMat.RowNames)
                    msgError = 'STDROW> Cannot process source maps, or any file that does not have explicit row names.';
                    return;
                elseif (length(fileMat.RefRowNames) > 1)
                    msgError = 'STDROW> Cannot process connectivity [NxN] results.';
                    return;
                end
                % Add row names to the list
                AllRowNames{iInput} = fileMat.RowNames;
            case 'matrix'
                if ischar(FileNames{iInput})
                    fileMat = in_bst_matrix(FileNames{iInput}, 'Description');
                else
                    fileMat = FileNames{iInput};
                end
                % Check file type
                if (size(fileMat.Description,2) > 1)
                    msgError = 'Cannot process a matrix file in which the "Description" fields has more than one column.';
                    return;
                end
                % Add row names to the list
                AllRowNames{iInput} = fileMat.Description;
            otherwise
                error('Unsupported file format.');
        end
        
        % Remove the @filename at the end of the row names
        for iRow = 1:length(AllRowNames{iInput})
            iAt = find(AllRowNames{iInput}{iRow} == '@', 1);
            if ~isempty(iAt) && any(AllRowNames{iInput}{iRow}(iAt+1:end) == '/')
                AllRowNames{iInput}{iRow} = strtrim(AllRowNames{iInput}{iRow}(1:iAt-1));
            end
        end
        
        % Keep track of row numbers
        nRows(iInput) = length(AllRowNames{iInput});
        % Union of all the row names
        unionRowNames = union(unionRowNames, AllRowNames{iInput});
        % Intersection of all the row names
        if isempty(interRowNames)
            interRowNames = AllRowNames{iInput};
        else
            interRowNames = intersect(interRowNames, AllRowNames{iInput});
        end
    end
    % Check if there are rowns left
    if isempty(interRowNames) && strcmpi(Method, 'common')
        msgError = 'No common row names in these data sets.';
        return;
    end
    
    
    % ===== COMMON ROW LIST =====
    % Get the row list that has the more/less rows
    switch (Method)
        % Only common rows
        case 'common'  
            % Get the minimum number of rows
            [tmp, iRef] = min(nRows);
            % Get rows
            DestRowNames = AllRowNames{iRef};
            % Remove unecessary rows
            iRemove = find(~ismember(DestRowNames, interRowNames));
            if ~isempty(iRemove)
                DestRowNames(iRemove) = [];
            end
        % All rows
        case 'all'
            % Get the maximum number of rows
            [tmp, iRef] = max(nRows);
            % Get rows
            DestRowNames = AllRowNames{iRef};
            % Add all the other rows
            iAdd = find(~ismember(unionRowNames, DestRowNames));
            if ~isempty(iAdd)
                if (size(DestRowNames,1) == 1)
                    DestRowNames = [DestRowNames, unionRowNames{iAdd}];
                else
                    DestRowNames = [DestRowNames; unionRowNames{iAdd}];
                end
            end
        % First file
        case 'first'  
            DestRowNames = AllRowNames{1};
    end
    
    % ===== GET INDICES FOR EACH FILE =====
    % Process each input file
    for iInput = 1:length(FileNames)
        % If it's a file that was not changed: skip to next file
        if isequal(DestRowNames, AllRowNames{iInput})
            iRowsSrc{iInput}  = 1:length(DestRowNames);
            iRowsDest{iInput} = 1:length(DestRowNames);
            continue;
        end
        % Create list of orders for rows
        for iChan = 1:length(DestRowNames)
            iTmp = find(strcmpi(DestRowNames{iChan}, AllRowNames{iInput}));
            iTmp = setdiff(iTmp, iRowsSrc{iInput});
            if (length(iTmp) > 1)
                if (length(iTmp) > 1)
                    msgError = 'Several signals with the same name, re-ordering might be inaccurate.';
                    iTmp = iTmp(1);
                end
            end
            if ~isempty(iTmp)
                iRowsDest{iInput}(end+1) = iChan;
                iRowsSrc{iInput}(end+1)  = iTmp;
            end
        end
    end
end




