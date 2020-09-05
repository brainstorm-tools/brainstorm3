function varargout = process_import_data_raw( varargin )
% PROCESS_IMPORT_DATA_RAW: Import a raw file in the database.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Create link to raw file';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import recordings'};
    sProcess.Index       = 11;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ChannelFile#Link_the_raw_files_to_the_database';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Option: File to import
    sProcess.options.datafile.Comment = 'File to import:';
    sProcess.options.datafile.Type    = 'datafile';
    sProcess.options.datafile.Value   = {...
        '', ...                                % Filename
        '', ...                                % FileFormat
        'open', ...                            % Dialog type: {open,save}
        'Open raw EEG/MEG recordings...', ...  % Window title
        'ImportData', ...                      % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                          % Selection mode: {single,multiple}
        'files_and_dirs', ...                  % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'raw'), ...    % Get all the available file formats
        'DataIn'};                             % DefaultFormats
    % Separator
    sProcess.options.separator.Type = 'separator';
    sProcess.options.separator.Comment = ' ';
    % Replace channel files
    sProcess.options.channelreplace.Comment = 'Replace existing channel file';
    sProcess.options.channelreplace.Type    = 'checkbox';
    sProcess.options.channelreplace.Value   = 1;
    % Align sensors
    sProcess.options.channelalign.Comment = 'Align sensors using headpoints';
    sProcess.options.channelalign.Type    = 'checkbox';
    sProcess.options.channelalign.Value   = 1;
    % Align sensors
    sProcess.options.evtmode.Comment = 'Reading mode (value, bit, ttl, rttl):';
    sProcess.options.evtmode.Type    = 'text';
    sProcess.options.evtmode.Value   = 'value';
    sProcess.options.evtmode.Hidden  = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, [], 'Subject name is empty.');
        return
    end
    % Get filename to import
    FileName   = sProcess.options.datafile.Value{1};
    FileFormat = sProcess.options.datafile.Value{2};
    if isempty(FileName)
        bst_report('Error', sProcess, [], 'No file selected.');
        return
    end
    % Channel replace
    if sProcess.options.channelreplace.Value
        ChannelReplace = 2;
    else
        ChannelReplace = 0;
    end
    % Channels align
    ChannelAlign = 2 * double(sProcess.options.channelalign.Value);
    % Events reading mode
    if isfield(sProcess.options, 'evtmode') && isfield(sProcess.options.evtmode, 'Value') && ~isempty(sProcess.options.evtmode.Value) && ismember(sProcess.options.evtmode.Value, {'value', 'bit', 'ttl', 'rttl'})
        EventsTrackMode = sProcess.options.evtmode.Value;
    else
        EventsTrackMode = 'value';
    end
    
    % ===== IMPORT FILES =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % Create subject is it does not exist yet
    if isempty(sSubject)
        [sSubject, iSubject] = db_add_subject(SubjectName);
    end
    % Import options
    ImportOptions = db_template('ImportOptions');
    ImportOptions.ChannelReplace  = ChannelReplace;
    ImportOptions.ChannelAlign    = ChannelAlign;
    ImportOptions.DisplayMessages = 0;
    ImportOptions.EventsMode      = 'ignore';
    ImportOptions.EventsTrackMode = EventsTrackMode;
    % Import link to raw
    OutputFiles = import_raw(FileName, FileFormat, iSubject, ImportOptions);
end



