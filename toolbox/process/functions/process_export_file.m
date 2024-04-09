function varargout = process_export_file( varargin )
% PROCESS_FILE_EXPORT: Exports RawData, Data, Results, TimeFreq or Matrix files
%
% USAGE:     sProcess = process_export_file('GetDescription')
%                       process_export_file('Run', sProcess, sInputs)

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
% Authors: Raymundo Cassani, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Export to file';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 982;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Scripting';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Instructions label
    sProcess.options.label1.Comment = ['<B>One file: </B>Provide filename and format<BR><BR>' ...
                                       '<B>Multiple files: </B>Provide directory and format<BR>' ...
                                       '<I><FONT color="#777777">(filenames are obtained from database)</FONT></I><BR><BR>'];
    sProcess.options.label1.Type    = 'label';
    % File selection options
    SelectOptions = {...
        '', ...              % Filename
        '', ...              % FileFormat
        'save', ...          % Dialog type: {open,save}
        '', ...              % Window title
        '', ...              % DefaultFile
        'single', ...        % Selection mode: {single,multiple}
        'files', ...         % Selection mode: {files,dirs,files_and_dirs}
        '', ...              % Available file formats
        ''};                 % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    exportComment = 'Output file:';
    windowTitle   = 'Export: %s...';
    % === TARGET RAW DATA FILENAME
    SelectOptions{4} = sprintf(windowTitle, 'raw data');
    SelectOptions{8} = bst_get('FileFilters', 'rawout');
    SelectOptions{9} = 'DataOut';
    sProcess.options.exportraw.Comment    = exportComment;
    sProcess.options.exportraw.Type       = 'filename';
    sProcess.options.exportraw.Value      = SelectOptions;
    sProcess.options.exportraw.InputTypes = {'raw'};

    % === TARGET DATA FILENAME
    SelectOptions{4} = sprintf(windowTitle, 'data');
    SelectOptions{8} = bst_get('FileFilters', 'dataout');
    SelectOptions{9} = 'DataOut';
    sProcess.options.exportdata.Comment    = exportComment;
    sProcess.options.exportdata.Type       = 'filename';
    sProcess.options.exportdata.Value      = SelectOptions;
    sProcess.options.exportdata.InputTypes = {'data'};

    % === TARGET RESULTS FILENAME
    SelectOptions{4} = sprintf(windowTitle, 'sources');
    SelectOptions{8} = bst_get('FileFilters', 'resultsout');
    SelectOptions{9} = 'ResultsOut';
    sProcess.options.exportresults.Comment    = exportComment;
    sProcess.options.exportresults.Type       = 'filename';
    sProcess.options.exportresults.Value      = SelectOptions;
    sProcess.options.exportresults.InputTypes = {'results'};

    % === TARGET TIMEFREQ FILENAME
    SelectOptions{4} = sprintf(windowTitle, 'time-freq');
    SelectOptions{8} = bst_get('FileFilters', 'timefreqout');
    SelectOptions{9} = 'TimefreqOut';
    sProcess.options.exporttimefreq.Comment    = exportComment;
    sProcess.options.exporttimefreq.Type       = 'filename';
    sProcess.options.exporttimefreq.Value      = SelectOptions;
    sProcess.options.exporttimefreq.InputTypes = {'timefreq'};

    % === TARGET MATRIX FILENAME
    SelectOptions{4} = sprintf(windowTitle, 'matrix');
    SelectOptions{8} = bst_get('FileFilters', 'matrixout');
    SelectOptions{9} = 'MatrixOut';
    sProcess.options.exportmatrix.Comment    = exportComment;
    sProcess.options.exportmatrix.Type       = 'filename';
    sProcess.options.exportmatrix.Value      = SelectOptions;
    sProcess.options.exportmatrix.InputTypes = {'matrix'};
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    inputType = InputTypeFromFields(sProcess);
    if ~isempty(inputType)
        inputType(1) = upper(inputType(1));
    end
    Comment = ['Export to file: ' inputType];
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Returned files: same as input
    OutputFiles = {sInputs.FileName};
    % Get options
    inputType      = InputTypeFromFields(sProcess);
    outFileOptions = sProcess.options.(['export' inputType]).Value;
    isExportDir = isdir(outFileOptions{1});
    % If dir (export multiple files), find extension for filter
    if isExportDir
        % Get dir path
        fPath = outFileOptions{1};
        % Get extension for filter
        Filters = bst_get('FileFilters', [inputType, 'out']);
        iFilter = find(ismember(Filters(:,3), outFileOptions{2}), 1, 'first');
        if isempty(iFilter)
            bst_error(sprintf('Format "%s" is not valid for files of type "%s"', outFileOptions{2}, inputType), 'Export to file');
            return
        end
        fExt = Filters{iFilter, 1}{1};
    end
    % Export files
    for iInput = 1 : length(sInputs)
        % Name for one file is already clean of tags
        if isExportDir
            % Base name from Brainstorm database
            fileName = sInputs(iInput).FileName;
            fileType = file_gettype(fileName);
            if strcmp(fileType, 'link')
                [kernelFile, dataFile] = file_resolve_link(sInputs(iInput).FileName);
                [~, kBase] = bst_fileparts(kernelFile);
                [~, fBase] = bst_fileparts(dataFile);
                fBase = [kBase, '_' ,fBase];
            else
                [~, fBase] = bst_fileparts(fileName);
            end
            % Remove fit type tagsn from fBase
            switch(fileType)
                case 'data' % includes 'raw' files
                    tagsToRemove = {'_data', 'data_', '0raw_'};
                case {'results', 'link'}
                    tagsToRemove = {'_results', 'results_'};
                case 'timefreq'
                    tagsToRemove = {'_timefreq', 'timefreq_'};
                case 'matrix'
                    tagsToRemove = {'_matrix', 'matrix_'};
            end
            for iTag = 1 : length(tagsToRemove)
                fBase = strrep(fBase, tagsToRemove{iTag}, '');
            end
            outFileOptions{1} = bst_fullfile(fPath, [fBase, fExt]);
            % Verify that extension for BST format ends in '.ext'
            if strcmp(outFileOptions{2}, 'BST') && isempty(regexp(outFileOptions{1}, '\.\w+$', 'once'))
                % Add prefix for Brainstorm files
                prefix = '';
                if strcmp(fExt(1), '_')
                    prefix = [fExt(2:end), '_'];
                end
                outFileOptions{1} = bst_fullfile(fPath, [prefix, fBase, '.mat']);
            end
        end
        % Export files according their input type
        switch inputType
            case {'data', 'raw'}
                export_data(sInputs(iInput).FileName, [], outFileOptions{1}, outFileOptions{2});
            case 'results'
                export_result(sInputs(iInput).FileName, outFileOptions{1}, outFileOptions{2});
            case 'timefreq'
                export_timefreq(sInputs(iInput).FileName, outFileOptions{1}, outFileOptions{2});
            case 'matrix'
                export_matrix(sInputs(iInput).FileName, outFileOptions{1}, outFileOptions{2});
        end
        % Info of where the file was saved (console and report)
        bst_report('Info', sProcess, sInputs(iInput), sprintf('File exported as %s', outFileOptions{1}));
        fprintf(['BST: File "%s" exported as "%s"' 10], sInputs(iInput).FileName, outFileOptions{1});
    end
end

function inputType = InputTypeFromFields(sProcess)
    % Find InputType from first option field named 'exportINPUTTYPE'
    % FileTypes: 'raw', 'data', 'results', 'timefreq' or 'matrix'
    optFields = fieldnames(sProcess.options);
    iField = find(~cellfun(@isempty, regexp(optFields, '^export')), 1, 'first');
    if ~isempty(iField)
        inputType = regexprep(optFields{iField}, '^export', '');
    else
        inputType = '';
    end
end
