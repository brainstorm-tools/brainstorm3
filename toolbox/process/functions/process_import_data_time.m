function varargout = process_import_data_time( varargin )
% PROCESS_IMPORT_DATA_TIME: Import continuous files in the database, based on absolute time.

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
% Authors: Francois Tadel, 2012-2015
%          Raymundo Cassani, 2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Import MEG/EEG: Time';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = {'Import', 'Import recordings'};
    sProcess.Index       = 23;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Epoching';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import', 'raw',  'data'};
    sProcess.OutputTypes = {'data',   'data', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Option: Condition
    sProcess.options.condition.Comment = 'Condition name:';
    sProcess.options.condition.Type    = 'text';
    sProcess.options.condition.Value   = '';
    % Option: File to import (only if not processing the output of another process)
    sProcess.options.datafile.Comment    = 'Files to import:';
    sProcess.options.datafile.Type       = 'datafile';
    sProcess.options.datafile.InputTypes = {'import'};
    sProcess.options.datafile.Value      = {...
        '', ...                                % Filename
        '', ...                                % FileFormat
        'open', ...                            % Dialog type: {open,save}
        'Import EEG/MEG recordings...', ...    % Window title
        'ImportData', ...                      % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'multiple', ...                        % Selection mode: {single,multiple}
        'files_and_dirs', ...                  % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'raw'), ...    % Get all the available file formats
        'DataIn'};                             % Default file format (field name in DefaultFormats)
    % Separator
    sProcess.options.sep2.Type    = 'separator';
    sProcess.options.sep2.Comment = ' ';
    % Time window
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % Split in time blocks
    sProcess.options.split.Comment = 'Split recordings in time blocks (0=disable): ';
    sProcess.options.split.Type    = 'value';
    sProcess.options.split.Value   = {0, 's', []};
    % Separator
    sProcess.options.separator.Type = 'separator';
    sProcess.options.separator.Comment = ' ';
    % Ignore shorter epochs
    sProcess.options.ignoreshort.Comment = 'Ignore shorter epochs (when using the split option)';
    sProcess.options.ignoreshort.Type    = 'checkbox';
    sProcess.options.ignoreshort.Value   = 1;
    % Align sensors
    sProcess.options.channelalign.Comment = 'Align sensors using headpoints';
    sProcess.options.channelalign.Type    = 'checkbox';
    sProcess.options.channelalign.Value   = 1;
    sProcess.options.channelalign.InputTypes = {'import'};
    % Use CTF Comp
    sProcess.options.usectfcomp.Comment = 'Use CTF compensation';
    sProcess.options.usectfcomp.Type    = 'checkbox';
    sProcess.options.usectfcomp.Value   = 1;
    % Use SSP/ICA
    sProcess.options.usessp.Comment = 'Use SSP/ICA projectors';
    sProcess.options.usessp.Type    = 'checkbox';
    sProcess.options.usessp.Value   = 1;
    % Don't forget DC/resample
    sProcess.options.labeldc.Comment = '<BR><B>Remove DC offset</B> and <B>Resample</B>: add separate processes.<BR><BR>';
    sProcess.options.labeldc.Type    = 'label';
    % Resample (not displayed)
    sProcess.options.freq.Comment = 'Resample: ';
    sProcess.options.freq.Type    = 'Value';
    sProcess.options.freq.Value   = [];
    sProcess.options.freq.Hidden  = 1;
    % Remove DC offset (not displayed)
    sProcess.options.baseline.Comment = 'Remove DC offset: ';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    sProcess.options.baseline.Hidden  = 1;
    % Sensor types to remove DC offset (not displayed)
    sProcess.options.blsensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.blsensortypes.Type    = 'text';
    sProcess.options.blsensortypes.Value   = 'MEG, EEG';
    sProcess.options.blsensortypes.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET FILES TO IMPORT =====
    % Get filename to import
    isDirectImport = isfield(sProcess.options, 'datafile') && ~isempty(sProcess.options.datafile.Value) && ~isempty(sProcess.options.datafile.Value{1});
    if isDirectImport
        FileNames  = sProcess.options.datafile.Value{1};
        FileFormat = sProcess.options.datafile.Value{2};
    elseif ~isempty(sInputs)
        % Error if nothing in input
        if strcmpi(sInputs(1).FileType, 'import')
            bst_report('Error', sProcess, sInputs, 'No file selected.');
            return
        end
        % Get file names
        FileNames = {sInputs.FileName};
    else
        FileNames = {};
    end
    if isempty(FileNames)
        bst_report('Error', sProcess, sInputs, 'No file selected.');
        return
    end
    
    % ===== GET OPTIONS =====
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, sInputs, 'Subject name is empty.');
        return
    end
    % Get condition name
    Condition = file_standardize(sProcess.options.condition.Value);
    % Get time range
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeRange = sProcess.options.timewindow.Value{1};
    else
        TimeRange = [];
    end
    % Get split parameter
    if isfield(sProcess.options, 'split') && isfield(sProcess.options.split, 'Value') && iscell(sProcess.options.split.Value) && ~isempty(sProcess.options.split.Value)
        Split = sProcess.options.split.Value{1};
    else
        Split = 0;
    end
    % Channel align: only if not import from a link to raw file
    if isfield(sProcess.options, 'channelalign') && ~isempty(sProcess.options.channelalign.Value)
        ChannelReplace = 2;
        ChannelAlign = 2 * double(sProcess.options.channelalign.Value);
    else
        ChannelReplace = 0;
        ChannelAlign = 0;
    end
    % Import options
    ImportOptions = db_template('ImportOptions');
    ImportOptions.ImportMode       = 'Time';
    ImportOptions.UseEvents        = 0;
    ImportOptions.TimeRange        = TimeRange;
    ImportOptions.iEpochs          = 1;
    ImportOptions.SplitRaw         = (Split > 0);
    ImportOptions.SplitLength      = Split;
    ImportOptions.UseCtfComp       = sProcess.options.usectfcomp.Value;
    ImportOptions.UseSsp           = sProcess.options.usessp.Value;
    ImportOptions.events           = [];
    ImportOptions.CreateConditions = 1;
    ImportOptions.ChannelReplace   = ChannelReplace;
    ImportOptions.ChannelAlign     = ChannelAlign;
    ImportOptions.IgnoreShortEpochs = 2 * sProcess.options.ignoreshort.Value;
    ImportOptions.EventsMode       = 'ignore';
    ImportOptions.EventsTrackMode  = 'value';
    ImportOptions.DisplayMessages  = 0;
    % Extra options: Remove DC Offset
    if isfield(sProcess.options, 'baseline') && ~isempty(sProcess.options.baseline.Value)
        % BaselineRange
        if isequal(sProcess.options.baseline.Value{1}, 'all')
            ImportOptions.RemoveBaseline = 'all';
            ImportOptions.BaselineRange  = [];
        elseif ~isempty(sProcess.options.baseline.Value{1})
            ImportOptions.RemoveBaseline = 'time';
            ImportOptions.BaselineRange  = sProcess.options.baseline.Value{1};
        end
        % BaselineSensorType
        if isfield(sProcess.options, 'blsensortypes') && ~isempty(sProcess.options.blsensortypes.Value)           
            ImportOptions.BaselineSensorType  = sProcess.options.blsensortypes.Value;
        else
            ImportOptions.BaselineSensorType = '';
        end       
    else
        ImportOptions.RemoveBaseline = 'no';
    end
    % Extra options: Resample
    if isfield(sProcess.options, 'freq') && ~isempty(sProcess.options.freq.Value) && iscell(sProcess.options.freq.Value) && ~isempty(sProcess.options.freq.Value{1})
        ImportOptions.Resample     = 1;
        ImportOptions.ResampleFreq = sProcess.options.freq.Value{1};
    else
        ImportOptions.Resample = 0;
    end
    
    % ===== IMPORT FILES =====
    % Get subject
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % Create subject if it does not exist yet
    if isempty(sSubject)
        [sSubject, iSubject] = db_add_subject(SubjectName);
    end
    % Define output study
    if ~isempty(Condition)
        % Get condition asked by user
        [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(SubjectName, Condition));
        % Condition does not exist: create it
        if isempty(sStudy)
            iStudy = db_add_condition(SubjectName, Condition, 1);
            if isempty(iStudy)
                bst_report('Error', sProcess, sInputs, ['Cannot create condition : "' bst_fullfile(SubjectName, Condition) '"']);
                return;
            end
        end
    else
        iStudy = [];
    end
    % Import files
    if isDirectImport
        OutputFiles = import_data(FileNames, [], FileFormat, iStudy, iSubject, ImportOptions);
    else
        for iFile = 1:length(FileNames)
            isRaw = (length(FileNames{iFile}) > 9) && ~isempty(strfind(FileNames{iFile}, 'data_0raw'));
            if isRaw
                % Get sFile structure
                FileMat = in_bst_data(FileNames{iFile}, 'F');
                sFile = FileMat.F;
                % Read channel file
                ChannelFile = bst_get('ChannelFileForStudy', FileNames{iFile});
                ChannelMat = in_bst_channel(ChannelFile);
            else
                [sFile, ChannelMat] = in_fopen(FileNames{iFile}, 'BST-DATA');
            end
            OutputFiles = import_data(sFile, ChannelMat, sFile.format, iStudy, iSubject, ImportOptions);
        end
    end
    % Report number of files generated
    if ~isempty(OutputFiles)
        bst_report('Info', sProcess, sInputs, sprintf('%d time blocks imported.', length(OutputFiles)));
    else
        bst_report('Error', sProcess, sInputs, 'No good time segments imported from these files.');
    end
end




