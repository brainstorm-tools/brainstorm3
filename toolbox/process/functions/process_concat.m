function varargout = process_concat( varargin )
% PROCESS_CONCAT: Concatenate several data files using the time information from the first file.

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
    sProcess.Comment     = 'Concatenate time';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 305;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'matrix', 'timefreq'};
    sProcess.OutputTypes = {'data', 'matrix', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    % Definition of the options
    % === NOTICE
    sProcess.options.label1.Type    = 'label';
    sProcess.options.label1.Comment = ['The first file in the list is used as the time reference,<BR>' ...
                                       'the time information from the following files is ignored.'];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Process separately the different input types
    switch (sInputs(1).FileType)
        case 'data'
            % Load the first file, as the reference
            fields = fieldnames(db_template('datamat'))';
            NewMat = in_bst_data(sInputs(1).FileName, fields{:});
            sfreq = 1 ./ (NewMat.Time(2) - NewMat.Time(1));
            % Set history field
            NewMat = bst_history('add', NewMat, 'concat', 'Contatenate time from files:');
            NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(1).FileName]);
            % Check all the input files
            for iInput = 2:length(sInputs)
                % Load the next file
                DataMat = in_bst_data(sInputs(iInput).FileName, fields{:});
                % Check consistency with the number of sensors
                if (size(NewMat.F,1) ~= size(DataMat.F,1))
                    bst_report('Error', sProcess, sInputs(iInput), ['This file has a different number of channels than the previous ones: "' sInputs(iInput).FileName '".']);
                    return;
                end
                % Concatenate the events
                if ~isempty(DataMat.Events)
                    % Convert the events timing (the first file is already correct because it's the reference)
                    if (iInput >= 2)
                        for iEvt = 1:length(DataMat.Events)
                            DataMat.Events(iEvt).times   = DataMat.Events(iEvt).times - DataMat.Time(1) + NewMat.Time(1) + size(NewMat.F,2) ./ sfreq;
                            DataMat.Events(iEvt).samples = round(DataMat.Events(iEvt).times .* sfreq);
                        end
                    end
                    % Add the events to the new file
                    if isempty(NewMat.Events)
                        NewMat.Events = DataMat.Events;
                    else
                        % Trick import_events() to work for event concatenation
                        sFile.events = NewMat.Events;
                        sFile.prop.sfreq = sfreq;
                        sFile = import_events(sFile, [], DataMat.Events);
                        NewMat.Events = sFile.events;
                    end
                end
                % Concatenate the F matrices
                NewMat.F = [NewMat.F, DataMat.F];
                % Concatenate the Std matrices
                if isfield(DataMat, 'Std') && ~isempty(DataMat.Std)
                    NewMat.Std = [NewMat.Std, DataMat.Std];
                end
                % Add the bad channels
                NewMat.ChannelFlag(DataMat.ChannelFlag == -1) = -1;
                % History field
                NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(iInput).FileName]);
            end
            % Set the final time vector
            NewMat.Time = NewMat.Time(1) + (0:size(NewMat.F,2)-1) ./ sfreq;
            % Output file tag
            fileTag = 'data_concat';
            
        case 'matrix'
            % Load the first file, as the reference
            fields = fieldnames(db_template('matrixmat'))';
            NewMat = in_bst_matrix(sInputs(1).FileName, fields{:});
            sfreq = 1 ./ (NewMat.Time(2) - NewMat.Time(1));
            % Set history field
            NewMat = bst_history('add', NewMat, 'concat', 'Contatenate time from files:');
            NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(1).FileName]);
            % Check all the input files
            for iInput = 2:length(sInputs)
                % Load the next file
                MatrixMat = in_bst_matrix(sInputs(iInput).FileName, fields{:});
                % Check consistency with the number of signals
                if (size(NewMat.Value,1) ~= size(MatrixMat.Value,1))
                    bst_report('Error', sProcess, sInputs(iInput), ['This file has a different number of signals than the previous ones: "' sInputs(iInput).FileName '".']);
                    return;
                end
                % Concatenate the events
                if ~isempty(MatrixMat.Events) 
                    % Convert the events timing (the first file is already correct because it's the reference)
                    if (iInput >= 2)
                        for iEvt = 1:length(MatrixMat.Events)
                            MatrixMat.Events(iEvt).times   = MatrixMat.Events(iEvt).times - MatrixMat.Time(1) + NewMat.Time(1) + size(NewMat.Value,2) ./ sfreq;
                            MatrixMat.Events(iEvt).samples = round(MatrixMat.Events(iEvt).times .* sfreq);
                        end
                    end
                    % Add the events to the new file
                    if isempty(NewMat.Events)
                        NewMat.Events = MatrixMat.Events;
                    else
                        % Trick import_events() to work for event concatenation
                        sFile.events = NewMat.Events;
                        sFile.prop.sfreq = sfreq;
                        sFile = import_events(sFile, [], MatrixMat.Events);
                        NewMat.Events = sFile.events;
                    end
                end
                % Concatenate the data matrices
                NewMat.Value = [NewMat.Value, MatrixMat.Value];
                % Concatenate the Std matrices
                if isfield(MatrixMat, 'Std') && ~isempty(MatrixMat.Std)
                    NewMat.Std = [NewMat.Std, MatrixMat.Std];
                end
                % History field
                NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(iInput).FileName]);
            end
            % Set the final time vector
            NewMat.Time = NewMat.Time(1) + (0:size(NewMat.Value,2)-1) ./ sfreq;
            % Output file tag
            fileTag = 'matrix_concat';
            
        case 'timefreq'
            % Load the first file, as the reference
            fields = fieldnames(db_template('timefreqmat'))';
            NewMat = in_bst_timefreq(sInputs(1).FileName, 1, fields{:});
            sfreq = 1 ./ (NewMat.Time(2) - NewMat.Time(1));
            % Set history field
            NewMat = bst_history('add', NewMat, 'concat', 'Contatenate time from files:');
            NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(1).FileName]);
            % Check all the input files
            for iInput = 2:length(sInputs)
                % Load the next file
                MatrixMat = in_bst_timefreq(sInputs(iInput).FileName, 1, fields{:});
                % Check consistency with the number of signals
                if (size(NewMat.TF,1) ~= size(MatrixMat.TF,1))
                    bst_report('Error', sProcess, sInputs(iInput), ['This file has a different number of signals than the previous ones: "' sInputs(iInput).FileName '".']);
                    return;
                elseif (size(NewMat.TF,3) ~= size(MatrixMat.TF,3))
                    bst_report('Error', sProcess, sInputs(iInput), ['This file has a different number of frequencies than the previous ones: "' sInputs(iInput).FileName '".']);
                    return;
                end
                % Concatenate the data matrices
                NewMat.TF = cat(2, NewMat.TF, MatrixMat.TF);
                % History field
                NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(iInput).FileName]);
            end
            % Set the final time vector
            NewMat.Time = NewMat.Time(1) + (0:size(NewMat.TF,2)-1) ./ sfreq;
            % Output file tag
            fileTag = 'timefreq_concat';
            
        otherwise
            bst_report('Error', sProcess, sInputs(1), ['Unsupported file type: "' sInputs(1).FileType '".']);
            return;
    end
    
    % Set comment
    if (NewMat.Time(end) > 2)
        timeComment = sprintf('(%1.2fs,%1.2fs)', NewMat.Time(1), NewMat.Time(end));
    else
        timeComment = sprintf('(%dms,%dms)', round(1000 * NewMat.Time(1)), round(1000 * NewMat.Time(end)));
    end
    NewMat.Comment = [str_remove_parenth(NewMat.Comment), ' | concat' timeComment];
    % Get output filename
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sInputs(1).FileName), fileTag);
    % Save file
    bst_save(OutputFiles{1}, NewMat, 'v6');
    % Register in database
    db_add_data(sInputs(1).iStudy, OutputFiles{1}, NewMat);
end


