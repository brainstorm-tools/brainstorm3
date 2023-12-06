function varargout = process_export_file( varargin )
% PROCESS_FILE_EXPORT: Exports a RawData, Data, Results, TimeFreq or Matrix file
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
    % File selection options
    SelectOptions = {...
        '', ...              % Filename
        '', ...              % FileFormat
        'save', ...          % Dialog type: {open,save}
        '', ...              % Window title
        '', ...              % DefaultFile (Suggested if empty AND 'save' & 'files')
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
    Comment = sProcess.Comment;
    fileType = FileTypeFromFields(sProcess);
    if ~isempty(fileType)
        fileType(1) = upper(fileType(1));
    end
    Comment = ['Export to file: ' fileType];
end

%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Returned files: same as input
    OutputFiles = {sInputs.FileName};
    % Get options
    fileType       = FileTypeFromFields(sProcess);
    outFileOptions = sProcess.options.(['export' fileType]).Value;
    % Export file according its type
    switch fileType
        case {'data', 'raw'}
            export_data(sInputs(1).FileName, [], outFileOptions{1}, outFileOptions{2});
        case 'results'
            export_result(sInputs(1).FileName, outFileOptions{1}, outFileOptions{2});
        case 'timefreq'
            export_timefreq(sInputs(1).FileName, outFileOptions{1}, outFileOptions{2});
        case 'matrix'
            export_matrix(sInputs(1).FileName, outFileOptions{1}, outFileOptions{2});
    end
    % Infor of where the file was saved (console and report)
    bst_report('Info', sProcess, sInputs(1), sprintf('File exported as %s', outFileOptions{1}));
    fprintf(['BST: File "%s" exported as "%s"' 10], sInputs(1).FileName, outFileOptions{1});
end

function fileType = FileTypeFromFields(sProcess)
    % Find InputType from first option field named 'exportINPUTTYPE'
    % FileTypes: 'raw', 'data', 'results', 'timefreq' or 'matrix'
    optFields = fieldnames(sProcess.options);
    iField = find(~cellfun(@isempty, regexp(optFields, '^export')), 1, 'first');
    if ~isempty(iField)
        fileType = regexprep(optFields{iField}, '^export', '');
    else
        fileType = '';
    end
end
