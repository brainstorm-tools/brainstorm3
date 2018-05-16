function varargout = process_concat_rows( varargin )
% PROCESS_CONCAT_ROW: Concatenate the signals from multiple matrix or timefreq files.

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
% Authors: Francois Tadel, 2016-2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Concatenate signals';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 305;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'matrix', 'timefreq'};
    sProcess.OutputTypes = {'matrix', 'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    % Definition of the options
    % === NOTICE
    sProcess.options.label1.Type    = 'label';
    sProcess.options.label1.Comment = ['Copies the signals from multiple files into a single file.<BR>' ...
                                       'All the input files must have the same time definition.'];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Process separately the different input types
    switch (sInputs(1).FileType)
        case 'matrix'
            % Load the first file, as the reference
            fields = fieldnames(db_template('matrixmat'))';
            NewMat = in_bst_matrix(sInputs(1).FileName, fields{:});
            sfreq = 1 ./ (NewMat.Time(2) - NewMat.Time(1));
            % Set history field
            NewMat = bst_history('add', NewMat, 'concat', 'Contatenate rows from files:');
            NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(1).FileName]);
            % Check all the input files
            for iInput = 2:length(sInputs)
                % Load the next file
                MatrixMat = in_bst_matrix(sInputs(iInput).FileName, fields{:});
                % Check consistency with the number of signals
                if (size(NewMat.Value,2) ~= size(MatrixMat.Value,2))
                    bst_report('Error', sProcess, sInputs(iInput), ['This file has a different number of time samples than the previous ones: "' sInputs(iInput).FileName '".']);
                    return;
                end
                % Concatenate the events
                if ~isempty(MatrixMat.Events) 
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
                NewMat.Value       = cat(1, NewMat.Value, MatrixMat.Value);
                NewMat.Description = cat(1, NewMat.Description, MatrixMat.Description);
                if isfield(MatrixMat, 'Std') && ~isempty(MatrixMat.Std)
                    NewMat.Std = cat(1, NewMat.Std, MatrixMat.Std);
                end
                % History field
                NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(iInput).FileName]);
            end
            nRows = size(NewMat.Value, 1);
            % Output file tag
            fileTag = 'matrix_concat';
            
        case 'timefreq'
            % Load the first file, as the reference
            fields = fieldnames(db_template('timefreqmat'))';
            NewMat = in_bst_timefreq(sInputs(1).FileName, 1, fields{:});
            % Set history field
            NewMat = bst_history('add', NewMat, 'concat', 'Contatenate rows from files:');
            NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(1).FileName]);
            % Check all the input files
            for iInput = 2:length(sInputs)
                % Load the next file
                MatrixMat = in_bst_timefreq(sInputs(iInput).FileName, 1, fields{:});
                % Check consistency with the number of signals
                if (size(NewMat.TF,2) ~= size(MatrixMat.TF,2))
                    bst_report('Error', sProcess, sInputs(iInput), ['This file has a different number of time samples than the previous ones: "' sInputs(iInput).FileName '".']);
                    return;
                elseif (size(NewMat.TF,3) ~= size(MatrixMat.TF,3))
                    bst_report('Error', sProcess, sInputs(iInput), ['This file has a different number of frequencies than the previous ones: "' sInputs(iInput).FileName '".']);
                    return;
                end
                % Concatenate the data matrices
                NewMat.TF       = cat(1, NewMat.TF, MatrixMat.TF);
                NewMat.RowNames = cat(1, NewMat.RowNames, MatrixMat.RowNames);
                if isfield(NewMat, 'RefRowNames') && ~isempty(NewMat.RefRowNames)
                    NewMat.RefRowNames = cat(1, NewMat.RefRowNames, MatrixMat.RefRowNames);
                end
                % History field
                NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(iInput).FileName]);
            end
            nRows = size(NewMat.TF, 1);
            % Output file tag
            fileTag = 'timefreq_concat';
            
        otherwise
            bst_report('Error', sProcess, sInputs(1), ['Unsupported file type: "' sInputs(1).FileType '".']);
            return;
    end
    
    % Set comment
    NewMat.Comment = [str_remove_parenth(NewMat.Comment), ' | concat(' num2str(nRows) ' rows)'];
    % Get output filename
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sInputs(1).FileName), fileTag);
    % Save file
    bst_save(OutputFiles{1}, NewMat, 'v6');
    % Register in database
    db_add_data(sInputs(1).iStudy, OutputFiles{1}, NewMat);
end


