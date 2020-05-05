function varargout = process_concat( varargin )
% PROCESS_CONCAT: Concatenate several data files using the time information from the first file.

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
% Authors: Francois Tadel, 2013-2019
%          Marc Lalancette, 2018

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
    sProcess.InputTypes  = {'raw', 'data', 'matrix', 'timefreq'};
    sProcess.OutputTypes = {'raw', 'data', 'matrix', 'timefreq'};
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
    OutputFiles = {};
    % Process separately the different input types
    switch (sInputs(1).FileType)
        case 'raw'
            
            % Load the first file, as the reference
            fields = fieldnames(db_template('datamat'))'; % and F here is an 'sfile'
            NewMat = in_bst_data(sInputs(1).FileName, fields{:});
            
            
            % Get input raw path and name
            if ismember(NewMat.F.format, {'CTF', 'CTF-CONTINUOUS'})
                [rawPathIn, rawBaseIn] = bst_fileparts(bst_fileparts(NewMat.F.filename));
            else
                [rawPathIn, rawBaseIn] = bst_fileparts(NewMat.F.filename);
            end
            % Make sure that there are not weird characters in the folder names
            rawBaseIn = file_standardize(rawBaseIn);
            % New folder name
            % Output file tag
            fileTag = '_concat';
            if isfield(NewMat.F, 'condition') && ~isempty(NewMat.F.condition)
                newCondition = ['@raw', NewMat.F.condition, fileTag];
            else
                newCondition = ['@raw', rawBaseIn, fileTag];
            end
            % Get new condition name
            ProtocolInfo = bst_get('ProtocolInfo');
            newStudyPath = file_unique(bst_fullfile(ProtocolInfo.STUDIES, sInputs(1).SubjectName, newCondition));
            % Output file name derives from the condition name
            [tmp, rawBaseOut, rawBaseExt] = bst_fileparts(newStudyPath);
            rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
            % Full output filename
            RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']);
            % Get input study (to copy the creation date)
            sInputStudy = bst_get('AnyFile', sInputs(1).FileName);
            
            % Get new condition name
            [tmp, ConditionName] = bst_fileparts(newStudyPath, 1);
            % Create output condition
            iOutputStudy = db_add_condition(sInputs(1).SubjectName, ConditionName, [], sInputStudy.DateOfStudy);
            if isempty(iOutputStudy)
                bst_report('Error', sProcess, sInputs(1), ['Output folder could not be created:' 10 newPath]);
                return;
            end
            % Get output study
            sOutputStudy = bst_get('Study', iOutputStudy);
            % Full file name
            OutputFiles{1} = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sOutputStudy.FileName), ['data_0raw_' rawBaseOut '.mat']);
            
            % Check all the input files.  We need the total data length first to create the output file.
            nSamplesTotal = 0;
            nChannels = numel(NewMat.ChannelFlag);
            for iInput = 1:numel(sInputs)
                % Load the next file
                DataMat = in_bst_data(sInputs(iInput).FileName, {'F'});
                dataSamples = round(DataMat.F.prop.times .* DataMat.F.prop.sfreq);
                nSamplesTotal = nSamplesTotal + dataSamples(2) - dataSamples(1) + 1;
                % Only accept continuous files
                if ~isempty(DataMat.F.epochs) && (numel(DataMat.F.epochs) > 1)
                    if strcmpi(DataMat.F.format, 'CTF')
                        % Convert to continuous first.
                        [DataMat.F, Messages] = process_ctf_convert('Compute', DataMat.F);
                        if isempty(DataMat.F) && ~isempty(Messages)
                            bst_report('Error', sProcess, sInputs(iInput), Messages);
                            return;
                        elseif ~isempty(Messages)
                            bst_report('Warning', sProcess, sInputs(iInput), Messages);
                        end
                    else
                        bst_report('Error', sProcess, sInputs(iInput), 'Only continuous raw files can be concatenated.');
                        return;
                    end
                end
                % Check consistency with the number of sensors
                if nChannels ~= numel(DataMat.ChannelFlag)
                    bst_report('Error', sProcess, sInputs(iInput), ['This file has a different number of channels than the previous ones: "' sInputs(iInput).FileName '".']);
                    return;
                end
            end
            
            % Create the empty binary file.
            sfreq = NewMat.F.prop.sfreq;
            NewMat.F.prop.times =  NewMat.F.prop.times(1) + ([1, nSamplesTotal] - 1) ./ sfreq;
            NewChannelMat = in_bst_channel(sInputs(1).ChannelFile);
            [NewMat.F, errMsg] = out_fopen(RawFileOut, 'BST-BIN', NewMat.F, NewChannelMat);
            % Error processing
            if isempty(NewMat.F) && ~isempty(errMsg)
                bst_report('Error', sProcess, sInputs(1), errMsg);
                return;
            elseif ~isempty(errMsg)
                bst_report('Warning', sProcess, sInputs(1), errMsg);
            end
            
            % Set the final time vector
            NewMat.Time = NewMat.F.prop.times;
            newSamples = round(NewMat.F.prop.times .* NewMat.F.prop.sfreq);

            % Set history field
            NewMat = bst_history('add', NewMat, 'concat', 'Contatenate time from files:');
            
            ProcessOptions = bst_get('ProcessOptions'); % for block size.
            MaxSize = ProcessOptions.MaxBlockSize;
            
            BlockSizeCol = max(floor(MaxSize / nChannels), 1);
            nBlockCol = ceil(nSamplesTotal / BlockSizeCol);
            bst_progress('start', 'Concatenate raw files', 'Joining files...', 0, nBlockCol);

            % Go through all the input files again to copy the data.
            nSamplesTotal = 0;
            for iInput = 1:numel(sInputs)
                % Load the next file
                DataMat = in_bst_data(sInputs(iInput).FileName, fields{:});
                ChannelMat = in_bst_channel(sInputs(iInput).ChannelFile);
                dataSamples = round(DataMat.F.prop.times .* DataMat.F.prop.sfreq);
                
                if (iInput > 1)
                    % Concatenate the events.
                    if ~isempty(DataMat.F.events)
                        % Convert the events timing
                        for iEvt = 1:numel(DataMat.F.events)
                            DataMat.F.events(iEvt).times   = DataMat.F.events(iEvt).times - DataMat.Time(1) + NewMat.Time(1) + nSamplesTotal ./ sfreq;
                            DataMat.F.events(iEvt).times   = round(DataMat.F.events(iEvt).times .* sfreq) ./ sfreq;
                        end
                        % Add the events to the new file
                        if isempty(NewMat.F.events)
                            NewMat.F.events = DataMat.F.events;
                        else
                            % Trick import_events() to work for event concatenation
                            sFile.events = NewMat.F.events;
                            sFile.prop.sfreq = sfreq;
                            sFile = import_events(sFile, [], DataMat.F.events);
                            NewMat.F.events = sFile.events;
                        end
                    end
                    
                    % Add the bad channels.
                    NewMat.ChannelFlag(DataMat.ChannelFlag == -1) = -1;
                end
                % History field
                NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(iInput).FileName]);
                
                % Concatenate the actual data.
                nCol = numel(DataMat.Time);
                if (nChannels * nCol > MaxSize)
                    BlockSizeCol = max(floor(MaxSize / nChannels), 1);
                else
                    BlockSizeCol = nCol;
                end
                % Split data in blocks
                nBlockCol = ceil(nCol / BlockSizeCol);
                for iBlockCol = 1:nBlockCol
                    % Indices of columns to process
                    SamplesBounds = dataSamples(1) - 1 + [(iBlockCol-1) * BlockSizeCol + 1, min(iBlockCol * BlockSizeCol, nCol)];
                    % Read block.
                    A = in_fread(DataMat.F, ChannelMat, 1, SamplesBounds);
                    % Write block.
                    NewMat.F = out_fwrite(NewMat.F, NewChannelMat, 1, ...
                        SamplesBounds - dataSamples(1) + newSamples(1) + nSamplesTotal, [], A);
                    bst_progress('inc', 1);
                end
                nSamplesTotal = nSamplesTotal + dataSamples(2) - dataSamples(1) + 1;
            end

            % If no default channel file: create new channel file
            if ~isempty(NewChannelMat)
                db_set_channel(iOutputStudy, NewChannelMat, 2, 0);
            end
            
            % Trick the last line of this function to register in the output study.
            sInputs(1).iStudy = iOutputStudy;
            
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
                            DataMat.Events(iEvt).times = DataMat.Events(iEvt).times - DataMat.Time(1) + NewMat.Time(1) + size(NewMat.F,2) ./ sfreq;
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
                            MatrixMat.Events(iEvt).times = MatrixMat.Events(iEvt).times - MatrixMat.Time(1) + NewMat.Time(1) + size(NewMat.Value,2) ./ sfreq;
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
            % Removing time bands, because they would conflict with the display
            NewMat.TimeBands = [];
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
                % REMOVING TIME BANDS BECAUSE IT MAKES OUTPUT FILES DIFFICULT TO VIEW
                % % Concatenate time bands
                % if ~isempty(NewMat.TimeBands) && ~isempty(MatrixMat.TimeBands)
                %     NewMat.TimeBands = cat(1, NewMat.TimeBands, MatrixMat.TimeBands);
                % end
                % History field
                NewMat = bst_history('add', NewMat, 'concat', [' - ' sInputs(iInput).FileName]);
            end
            % Set the final time vector
            NewMat.Time = NewMat.Time(1) + (0:size(NewMat.TF,2)-1) ./ sfreq;
            % Output file tag
            fileTag = [bst_process('GetFileTag', sInputs(1).FileName), '_concat'];
            
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
    % Get output filename, but already have it if 'raw'.
    if isempty(OutputFiles)
        OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sInputs(1).FileName), fileTag);
    end
    % Save file
    bst_save(OutputFiles{1}, NewMat, 'v6');
    % Register in database
    db_add_data(sInputs(1).iStudy, OutputFiles{1}, NewMat);
    
end


