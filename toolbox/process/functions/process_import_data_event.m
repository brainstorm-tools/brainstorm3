function varargout = process_import_data_event( varargin )
% PROCESS_IMPORT_DATA_EVENT: Import continuous files in the database, based on event markers.

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
% Authors: Francois Tadel, 2012-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Import MEG/EEG: Events';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = {'Import', 'Import recordings'};
    sProcess.Index       = 22;
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
    sProcess.options.condition.Comment = 'Folder name:';
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
    % Event name
    sProcess.options.eventname.Comment = 'Event names: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    % Time window
    sProcess.options.timewindow.Comment = 'Time window: ';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % Epoch time
    sProcess.options.epochtime.Comment = 'Epoch time: ';
    sProcess.options.epochtime.Type    = 'range';
    sProcess.options.epochtime.Value   = {[-0.100, 0.300], 'ms', []};
    % Separator
    sProcess.options.separator.Type = 'separator';
    sProcess.options.separator.Comment = ' ';
    % Create conditions
    sProcess.options.createcond.Comment = 'Create one condition for each event type';
    sProcess.options.createcond.Type    = 'checkbox';
    sProcess.options.createcond.Value   = 1;
    % Ignore shorter epochs
    sProcess.options.ignoreshort.Comment = 'Ignore shorter epochs';
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
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET FILES TO IMPORT =====
    % Get filename to import
    isDirectImport = isfield(sProcess.options, 'datafile') && ~isempty(sProcess.options.datafile.Value) && ~isempty(sProcess.options.datafile.Value{1});
    if isDirectImport
        FileNames  = sProcess.options.datafile.Value{1};
        FileFormat = sProcess.options.datafile.Value{2};
    elseif ~isempty(sInput)
        isRaw = strcmpi(sInput(1).FileType, 'raw');
        FileNames = {sInput.FileName};
        if isRaw
            FileMat    = in_bst_data(FileNames{1}, 'F');
            sFile      = FileMat.F;
            FileFormat = sFile.format;
            % Read channel file
            ChannelFile = bst_get('ChannelFileForStudy', FileNames{1});
            ChannelMat = in_bst_channel(ChannelFile);
        else
            FileFormat = 'BST-DATA';
            [sFile, ChannelMat] = in_fopen(FileNames{1}, FileFormat);
        end
    else
        FileNames = {};
    end
    % No files in input
    if isempty(FileNames)
        bst_report('Error', sProcess, sInput, 'No file selected.');
        return
    end

    % ===== GET OPTIONS =====
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName) && ~isempty(sInput.SubjectName)
        SubjectName = sInput.SubjectName;
    elseif isempty(SubjectName)
        bst_report('Error', sProcess, sInput, 'Subject name is empty.');
        return
    end
    % Get condition name
    CreateConditions = sProcess.options.createcond.Value;
    if CreateConditions
        Condition = [];
    else
        Condition = file_standardize(sProcess.options.condition.Value);
    end
    % Get time range
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeRange = sProcess.options.timewindow.Value{1};
    else
        TimeRange = [];
    end
    % Event names
    EvtNames = strtrim(str_split(sProcess.options.eventname.Value, ',;'));
    if isempty(EvtNames)
        bst_report('Error', sProcess, [], 'No events to import.');
        return;
    end
    % Channel align: only if not import from a link to raw file
    if isfield(sProcess.options, 'channelalign') && ~isempty(sProcess.options.channelalign.Value)
        ChannelReplace = 2;
        ChannelAlign = 2 * double(sProcess.options.channelalign.Value);
    else
        ChannelReplace = 0;
        ChannelAlign = 0;
    end
    % Epoch time: time units
    EventsTimeRange = sProcess.options.epochtime.Value{1};
    % Import options
    ImportOptions = db_template('ImportOptions');
    ImportOptions.ImportMode        = 'Event';
    ImportOptions.TimeRange         = TimeRange;
    ImportOptions.UseEvents         = 1;
    ImportOptions.EventsTimeRange   = EventsTimeRange;
    ImportOptions.iEpochs           = 1;
    ImportOptions.SplitRaw          = 0;
    ImportOptions.UseCtfComp        = sProcess.options.usectfcomp.Value;
    ImportOptions.UseSsp            = sProcess.options.usessp.Value;
    ImportOptions.CreateConditions  = CreateConditions;
    ImportOptions.ChannelReplace    = ChannelReplace;
    ImportOptions.ChannelAlign      = ChannelAlign;
    ImportOptions.IgnoreShortEpochs = 2 * sProcess.options.ignoreshort.Value;
    ImportOptions.EventsMode        = 'ignore';
    ImportOptions.EventsTrackMode   = 'value';
    ImportOptions.DisplayMessages   = 0;
    % Extra options: Remove DC Offset
    if isfield(sProcess.options, 'baseline') && ~isempty(sProcess.options.baseline.Value)
        if ~isempty(sProcess.options.baseline.Value{1})
            ImportOptions.RemoveBaseline = 'time';
            ImportOptions.BaselineRange  = sProcess.options.baseline.Value{1};
        else
            ImportOptions.RemoveBaseline = 'all';
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
                bst_report('Error', sProcess, sInput, ['Cannot create condition : "' bst_fullfile(SubjectName, Condition) '"']);
                return;
            end
        end
    else
        iStudy = [];
    end
    % Import files
    for iFile = 1:length(FileNames)
        % If file is not linked yet in the database: open the file to get the events
        if ~isempty(sInput) && (iFile >= 2)
            isRaw = ~isempty(strfind(FileNames{iFile}, '_0raw'));
            if isRaw
                % Get sFile structure
                FileMat = in_bst_data(FileNames{iFile}, 'F');
                sFile   = FileMat.F;
                % Read channel file
                ChannelFile = bst_get('ChannelFileForStudy', FileNames{iFile});
                ChannelMat = in_bst_channel(ChannelFile);
            else
                [sFile, ChannelMat] = in_fopen(FileNames{iFile}, FileFormat, ImportOptions);
            end
        elseif isempty(sInput) || strcmpi(sInput(1).FileType, 'import')
            [sFile, ChannelMat] = in_fopen(FileNames{iFile}, FileFormat, ImportOptions);
        end
        % No events in file
        if isempty(sFile.events)
            bst_report('Error', sProcess, [], ['No events in file: ' 10 FileNames{iFile}]);
            continue;
        end
        % Initialize events structure
        events = repmat(sFile.events, 0);
        % Get selected events
        for iSelEvt = 1:length(EvtNames)
            % Find input event in file
            iEvt = find(strcmpi(EvtNames{iSelEvt}, {sFile.events.label}));
            if isempty(iEvt)
                bst_report('Warning', sProcess, [], ['Event "' EvtNames{iSelEvt} '" does not exist in file: ' 10 FileNames{iFile}]);
                continue;
            end
            newEvt = sFile.events(iEvt);
            % Find events that are in time window
            if ~isempty(ImportOptions.TimeRange)
                selTime = ImportOptions.TimeRange + [-1,1] ./ sFile.prop.sfreq;
                iOcc = find(all(newEvt.times >= selTime(1), 1) & all(newEvt.times <= selTime(2), 1));
            else
                iOcc = 1:size(newEvt.times,2);
            end
            % No occurrence for this event: skip to next event
            if isempty(iOcc)
                continue;
            end
            % Get the selected occurrences
            newEvt.epochs  = newEvt.epochs(iOcc);
            newEvt.samples = newEvt.samples(:, iOcc);
            newEvt.times   = newEvt.times(:, iOcc);
            % Add to the list of events to import
            events(end+1) = newEvt;
        end
        % No events to import found in the file
        if isempty(events)
            bst_report('Error', sProcess, [], ['No events to import found in file: ' 10 FileNames{iFile}]);
            continue;
        end
        % Copy into events options
        ImportOptions.events = events;
        % Import file
        OutputFiles = cat(2, OutputFiles, import_data(sFile, ChannelMat, FileFormat, iStudy, iSubject, ImportOptions));
    end
    % Report number of files generated
    if ~isempty(OutputFiles)
        bst_report('Info', sProcess, sInput, sprintf('%d epochs imported.', length(OutputFiles)));
    else
        bst_report('Error', sProcess, sInput, 'No good trials imported from these files.');
    end
end




