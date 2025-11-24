function varargout = process_timeoffset( varargin )
% PROCESS_TIMEOFFSET: Add/subtract a time offset to the Time vector.

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
% Authors: Francois Tadel, 2010-2016
%          Raymundo Cassani, 2024

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Add time offset';
    sProcess.FileTag     = 'timeoffset';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Pre-process';
    sProcess.Index       = 76;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw', 'matrix', 'results'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix', 'results'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % Description
    sProcess.options.info.Comment = ['Adds a given time offset (in milliseconds) to the time vector.<BR>' ... 
                                     'The offset can be positive or negative: add a minus sign to remove this offset.<BR><BR>' ...
                                     'Example: The time definition of the input file is [-100ms, +300ms]<BR>' ...
                                     ' - Time offset =&nbsp;&nbsp;100.0ms => New timing will be [0ms, +400ms]<BR>' ...
                                     ' - Time offset = -100.0ms => New timing will be [-200ms, +200ms]<BR><BR>'];
    sProcess.options.info.Type    = 'label';
    sProcess.options.info.Value   = [];
    % === Info: For 'data' and 'raw' time offset is also applied to derived results
    sProcess.options.infodata.Comment   = ['The time offset will <B>also be applied</B> to results (source) files <BR>' ...
                                           'derived from the data file.<BR><BR>'];
    sProcess.options.infodata.Type       = 'label';
    sProcess.options.infodata.Value      = [];
    sProcess.options.infodata.InputTypes = {'data', 'raw'};
    % === Info, For 'results', time offset is applied only to standalone results
    sProcess.options.inforesults.Comment    = 'The time offset will <B>be applied only</B> to results files without related data file .<BR><BR>';
    sProcess.options.inforesults.Type       = 'label';
    sProcess.options.inforesults.Value      = [];
    sProcess.options.inforesults.InputTypes = {'results'};
    % === Time offset
    sProcess.options.offset.Comment = 'Time offset:';
    sProcess.options.offset.Type    = 'value';
    sProcess.options.offset.Value   = {0, 'ms', []};
    % === Overwrite
    sProcess.options.overwrite.Comment = 'Overwrite input files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sprintf('%s: %1.2fms', sProcess.Comment, sProcess.options.offset.Value{1} * 1000);
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFile = {};

    % Get inputs
    OffsetTime = sProcess.options.offset.Value{1};
    isOverwrite = sProcess.options.overwrite.Value;

    switch sInput.FileType
        case {'data', 'raw'}
            % ===== LOAD FILE =====
            % Get file descriptor
            isRaw = strcmpi(sInput.FileType, 'raw');
            % Load file
            DataMat = in_bst_data(sInput.FileName);
            if isRaw
                sEvents = DataMat.F.events;
                sFreq = DataMat.F.prop.sfreq;
                DataMat.Time = [DataMat.Time(1), DataMat.Time(end)];
            else
                sEvents = DataMat.Events;
                sFreq = 1 ./ (DataMat.Time(2) - DataMat.Time(1));
            end

            % ===== PROCESS =====
            % Apply offset to time
            DataMat.Time = DataMat.Time + OffsetTime;
            if isRaw
                DataMat.F.prop.times = DataMat.Time;
                if isfield(DataMat.F, 'epochs') && ~isempty(DataMat.F.epochs)
                    [DataMat.F.epochs(:).times] = deal(DataMat.Time);
                end
            end

            % Add offset to all events
            for iEvt = 1:length(sEvents)
                sEvents(iEvt).times = round((sEvents(iEvt).times + OffsetTime) .* sFreq) ./ sFreq;
            end
            if isRaw
                DataMat.F.events = sEvents;
            else
                DataMat.Events = sEvents;
            end

            % ===== SAVE FILE =====
            % Add history entry
            DataMat = bst_history('add', DataMat, 'timeoffset', sprintf('Added time offset %1.4fs', OffsetTime));
            DataMat.Comment = [DataMat.Comment ' | ' sProcess.FileTag];

            % Overwrite the input file
            if isOverwrite
                OutputFile = file_fullpath(sInput.FileName);
                bst_save(OutputFile, DataMat, 'v6');
                % Apply time offset to non-link result files dependent of this data file
                [sStudy, ~, iResults] = bst_get('ResultsForDataFile', sInput.FileName, sInput.iStudy);
                for ix = 1 : length(iResults)
                    if ~sStudy.Result(iResults(ix)).isLink
                        ResultsMat = load(file_fullpath(sStudy.Result(iResults(ix)).FileName), 'Time', 'History', 'Comment', 'ImageGridAmp');
                        % Source file for raw files is saved as kernel (but it is not a link)
                        if isRaw && isempty(ResultsMat.ImageGridAmp) && isempty(ResultsMat.Time)
                            % Nothing to change in ResultsMat
                        else
                            % Apply offset to time to results file
                            ResultsMat.Time = DataMat.Time;
                        end
                        % Add history entry
                        ResultsMat = bst_history('add', ResultsMat, 'timeoffset', sprintf('Added time offset %1.4fs to related data file %s', OffsetTime, sInput.FileName));
                        ResultsMat.Comment = [ResultsMat.Comment ' | ' sProcess.FileTag];
                        % Save updated file
                        bst_save(file_fullpath(sStudy.Result(iResults(ix)).FileName), ResultsMat, [], 1);
                    end
                end
                % Reload study
                db_reload_studies(sInput.iStudy);
            % Save new file
            else
                % Create new raw condition
                if isRaw
                    ChannelFile = sInput.ChannelFile;
                    newCondition = [sInput.Condition '_' sProcess.FileTag];
                    % Unique new condition name
                    sSubjStudies = bst_get('StudyWithSubject', sInput.SubjectFile);
                    newCondition = file_unique(newCondition, [sSubjStudies.Condition]);
                    iStudy = db_add_condition(sInput.SubjectName, newCondition);
                    sNewStudy = bst_get('Study', iStudy);
                    db_set_channel(iStudy, ChannelFile, 0, 0);
                    newStudyPath = bst_fileparts(file_fullpath(sNewStudy.FileName));
                    [~, base, ext] = bst_fileparts(sInput.FileName);
                    OutputFile = bst_fullfile(newStudyPath, [base, ext]);
                else
                    OutputFile = file_fullpath(sInput.FileName);
                    iStudy = sInput.iStudy;
                end
                % Unique output filename
                OutputFile = file_unique(strrep(OutputFile, '.mat', ['_' sProcess.FileTag '.mat']));
                % Save file
                bst_save(OutputFile, DataMat, 'v6');
                % Add file to database structure
                db_add_data(iStudy, OutputFile, DataMat);
                % Copy non-link result files dependent of this data file and apply offset
                [sStudy, ~, iResults] = bst_get('ResultsForDataFile', sInput.FileName, sInput.iStudy);
                for ix = 1 : length(iResults)
                    if ~sStudy.Result(iResults(ix)).isLink
                        ResultsMat = load(file_fullpath(sStudy.Result(iResults(ix)).FileName));
                        % Update DataFile
                        ResultsMat.DataFile = file_short(OutputFile);
                        % Source file for raw files is saved as kernel (but it is not a link)
                        if isRaw && isempty(ResultsMat.ImageGridAmp)
                            % Nothing else to change in ResultsMat
                        else
                            % Apply offset to time to ResultsMat
                            ResultsMat.Time = ResultsMat.Time + OffsetTime;
                        end
                        % Add history entry
                        ResultsMat = bst_history('add', ResultsMat, 'timeoffset', sprintf('Added time offset %1.4fs to related data file %s', OffsetTime, sInput.FileName));                            
                        ResultsMat.Comment = [ResultsMat.Comment ' | ' sProcess.FileTag];
                        % Save new results file
                        if isRaw
                            % Save in new condition
                            [~, base, ext] = bst_fileparts(sStudy.Result(iResults(ix)).FileName);
                            OutputFileResult = bst_fullfile(newStudyPath, [base, ext]);
                        else
                            % Save in same condition
                            OutputFileResult = file_fullpath(sStudy.Result(iResults(ix)).FileName);
                        end
                        OutputFileResult = file_unique(strrep(OutputFileResult, '.mat', ['_' sProcess.FileTag '.mat']));
                        bst_save(OutputFileResult, ResultsMat);
                        % Add file to database structure
                        db_add_data(iStudy, OutputFileResult, ResultsMat);
                    end
                end
            end

        case 'results'
            % Skip applying time offset if the input is not a stand-alone results file
            relDataFile = bst_get('RelatedDataFile', sInput.FileName, sInput.iStudy);
            if ~isempty(relDataFile)
                bst_report('Warning', sProcess, sInput, ['Time offset was not applied, Results file has a related (parent) DataFile.' 10 ...
                                                         'Apply time offset to parent DataFile instead: ', 10, relDataFile]);
                return
            end

            % ===== LOAD FILE =====
            if isOverwrite
                % Load fields to be modified
                ResultsMat = load(file_fullpath(sInput.FileName), 'Time', 'History', 'Comment');
            else
                % Load full results
                ResultsMat = in_bst_results(file_fullpath(sInput.FileName));
            end

            % ===== PROCESS =====
            % Apply offset to time
            ResultsMat.Time = ResultsMat.Time + OffsetTime;

            % ===== SAVE FILE =====
            ResultsMat = bst_history('add', ResultsMat, 'timeoffset', sprintf('Added time offset %1.4fs', OffsetTime));
            ResultsMat.Comment = [ResultsMat.Comment ' | ' sProcess.FileTag];

            OutputFile = file_fullpath(sInput.FileName);
            if isOverwrite
                bst_save(OutputFile, ResultsMat, [], 1);
            else
                % Unique output filename
                OutputFile = file_unique(strrep(OutputFile, '.mat', ['_' sProcess.FileTag '.mat']));
                % Save file
                bst_save(OutputFile, ResultsMat);
                % Add file to database structure
                db_add_data(sInput.iStudy, OutputFile, ResultsMat);
            end
    end
end

