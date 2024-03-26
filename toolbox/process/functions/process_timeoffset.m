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
    sProcess.InputTypes  = {'data', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'raw', 'matrix'};
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
        % Reload study
        db_reload_studies(sInput.iStudy);
    % Save new file
    else
        % Create new raw condition
        if isRaw
            newCondition = [sInput.Condition '_' sProcess.FileTag];
            iStudy = db_add_condition(sInput.SubjectName, newCondition);
            sNewStudy = bst_get('Study', iStudy);
            newStudyPath = bst_fileparts(file_fullpath(sNewStudy.FileName));
            [~, base, ext] = bst_fileparts(sInput.FileName);
            OutputFile = bst_fullfile(newStudyPath, [base '.' ext]);
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
    end
end




