function varargout = process_montage_apply( varargin )
% PROCESS_MONTAGE_APPLY: Applies a montage to recordings (creates new data and channel files).
%
% USAGE:  OutputFiles = process_montage_apply('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2014-2019
%          Raymundo Cassani, 2025

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Apply montage';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 307;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/MontageEditor';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === MONTAGE NAME
    sProcess.options.montage.Comment = 'Montage name: ';
    sProcess.options.montage.Type    = 'montage';
    sProcess.options.montage.Value   = '';
    % === NEW CHANNEL FILE
    sProcess.options.createchan.Comment    = 'Create new folders';
    sProcess.options.createchan.Type       = 'checkbox';
    sProcess.options.createchan.Value      = 1;
    sProcess.options.createchan.InputTypes = {'data'};
    % === APPLY CTF COMPENSATION
    sProcess.options.usectfcomp.Comment    = 'Use CTF compensation';
    sProcess.options.usectfcomp.Type       = 'checkbox';
    sProcess.options.usectfcomp.Value      = 1;
    sProcess.options.usectfcomp.InputTypes = {'raw'};
    % === APPLY SSP/ICA PROJECTORS
    sProcess.options.usessp.Comment    = 'Use SSP/ICA projectors';
    sProcess.options.usessp.Type       = 'checkbox';
    sProcess.options.usessp.Value      = 1;
    sProcess.options.usessp.InputTypes = {'raw'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Returned variables
    OutputFiles = {};
    % Options
    isCreateChan = ~isfield('createchan', sProcess.options) || (sProcess.options.createchan.Value == 1);
    isUseCtfComp =  isfield('usectfcomp', sProcess.options) && (sProcess.options.usectfcomp.Value == 1);
    isUseSsp     =  isfield('usessp', sProcess.options) && (sProcess.options.usessp.Value == 1);
    MontageName  = sProcess.options.montage.Value;
    % Get a simpler montage name (for automatic SEEG montages)
    strMontage = MontageName;
    strMontage = strrep(strMontage, '[tmp]', '');
    strMontage = strrep(strMontage, 'SEEG (', '');
    iColon = find(strMontage == ':');
    if ~isempty(iColon)
        strMontage = strMontage(iColon+1:end);
    end
    strMontage((strMontage == '(') | (strMontage == ')')) = [];
    strMontage = strtrim(strrep(strMontage, '  ', ' '));
    % Bipolar montage?
    isBipolar = ~isempty(strfind(strMontage, 'bipolar'));

    % Get all the channel files from the list of files
    allChanFiles = unique({sInputs.ChannelFile});
    for iChan = 1:length(allChanFiles)
        % Get subject for the channel file
        sStudyChan = bst_get('ChannelFile', allChanFiles{iChan});
        sSubject = bst_get('Subject', sStudyChan.BrainStormSubject, 1);
        isRaw = strncmp(sStudyChan.Name, '@raw', 4);
        % Load channel file 
        ChannelMat = in_bst_channel(allChanFiles{iChan});
        % Update automatic montages
        panel_montage('UnloadAutoMontages');
        if any(ismember({'ECOG', 'SEEG'}, {ChannelMat.Channel.Type}))
            panel_montage('AddAutoMontagesSeeg', sSubject.Name, ChannelMat);
        end
        if ismember('NIRS', {ChannelMat.Channel.Type})
            panel_montage('AddAutoMontagesNirs', ChannelMat);
        end
        if ~isempty(ChannelMat.Projector)
            panel_montage('AddAutoMontagesProj', ChannelMat);
        end
        
        % Get montage
        sMontage = panel_montage('GetMontage', MontageName);
        if isempty(sMontage) || (length(sMontage) > 1)
            bst_report('Error', sProcess, sInputs, ['Invalid montage name "' MontageName '".']);
            return;
        end
        % If not creating a new channel file: montage output has to be compatible with curent channel structure
        isCompatibleChan = ~strcmpi(sMontage.Type, 'selection') && (~strcmpi(sMontage.Type, 'text') || all(sum(sMontage.Matrix,2) == 0));
        if ~isCreateChan && (~isCompatibleChan || isRaw)
            bst_report('Error', sProcess, [], ['The montage "' sMontage.Name '" cannot be applied without writing a new folders.']);
            return;
        end
        
        % Process each data file
        iDataFile = find(strcmpi(allChanFiles{iChan}, {sInputs.ChannelFile}));
        for ik = 1:length(iDataFile)
            iInput = iDataFile(ik);
            % Load input file 
            DataMat = in_bst_data(sInputs(iInput).FileName);
            iStudyIn = sInputs(iInput).iStudy;
            sStudyIn = bst_get('Study', iStudyIn);
            % Build average reference
            if ~isempty(strfind(sMontage.Name, 'Average reference'))
                sMontage = panel_montage('GetMontageAvgRef', sMontage, ChannelMat.Channel, DataMat.ChannelFlag, 0);
            elseif ~isempty(strfind(sMontage.Name, '(local average ref)'))
                sMontage = panel_montage('GetMontageAvgRef', sMontage, ChannelMat.Channel, DataMat.ChannelFlag, 1);
            elseif ~isempty(strfind(sMontage.Name, 'Scalp current density'))
                sMontage = panel_montage('GetMontageScd', sMontage, ChannelMat.Channel, DataMat.ChannelFlag);
            elseif strcmpi(sMontage.Name, 'Head distance')
                sMontage = panel_montage('GetMontageHeadDistance', sMontage, ChannelMat.Channel, DataMat.ChannelFlag);
            end
            % Get channels indices for the montage
            [iChannels, iMatrixChan, iMatrixDisp] = panel_montage('GetMontageChannels', sMontage, {ChannelMat.Channel.Name});
            % Check that some channels where selected
            if isempty(iChannels)
                bst_report('Error', sProcess, sInputs, ['The montage "' sMontage.Name '" does not contain of the channels of the input recordings.']);
                return;
            % Cannot have the number of channels that change without writing a new channel file
            elseif ~isCreateChan && ((length(iMatrixDisp) ~= length(iMatrixChan)) || ~isequal(sMontage.DispNames(iMatrixDisp), sMontage.ChanNames(iMatrixChan)))
                bst_report('Error', sProcess, sInputs, ['The montage "' sMontage.Name '" changes the names of the channels, it requires the creation of new folders.']);
                return;
            end

            % Get output study
            if isCreateChan
                % If the subject has default channel: Create new subject
                if (sSubject.UseDefaultChannel > 0)
                    % Output subject name
                    SubjectNameOut = [sSubject.Name '_' file_standardize(strrep(strMontage, '''', 'p'))];
                    % Get output subject
                    sSubjectOut = bst_get('Subject', SubjectNameOut, 1);
                    % Create new output subject
                    if isempty(sSubjectOut)
                        [sSubjectOut, iSubjectOut, Messages] = process_duplicate('CopySubjectAnat', sSubject.Name, SubjectNameOut);
                        if ~isempty(Messages)
                            bst_report('Error', sProcess, sInputs, Messages);
                            return;
                        end
                    end
                    % Update subject from global to local default channel file
                    if (sSubjectOut.UseDefaultChannel ~= 1)
                        sSubjectOut.UseDefaultChannel = 1;
                        sSubjectOut = db_add_subject(sSubjectOut, iSubjectOut);
                    end
                    % Create condition
                    iStudyOut = db_add_condition(sSubjectOut.Name, sInputs(iInput).Condition, 1);
                else
                    % Output Condition name must be unique for raw files
                    ConditionOut = [sInputs(iInput).Condition, '_', file_standardize(strrep(strMontage, '''', 'p'))];
                    if isRaw
                        % Get conditions for this subject
                        sSubjStudies = bst_get('StudyWithSubject', sStudyChan.BrainStormSubject, 'intra_subject', 'default_study');
                        ConditionOut = file_unique(ConditionOut, [sSubjStudies.Condition]);
                    end
                    % Get output condition
                    [sStudyOut, iStudyOut] = bst_get('StudyWithCondition', [sSubject.Name '/' ConditionOut]);
                    % Create condition
                    if isempty(sStudyOut)
                        iStudyOut = db_add_condition(sSubject.Name, ConditionOut, 1);
                    end
                end
                % Check that new study was correctly created
                if isempty(iStudyOut)
                    bst_report('Error', sProcess, sInputs, 'Could not create output condition.');
                    return;
                end

                % Copy this channel file to the new study (if not done yet)
                [sChannelOut, iChanStudyOut] = bst_get('ChannelForStudy', iStudyOut);
                if isempty(sChannelOut)
                    % Create new channel file
                    ChannelMatOut = ChannelMat;
                    ChannelMatOut.Comment = [ChannelMatOut.Comment ' | ' strMontage];
                    ChannelMatOut.Channel = repmat(db_template('channeldesc'), 0);
                    % Create list of output channels
                    for iChanOut = 1:length(iMatrixDisp)
                        Loc = [];
                        % Name of the output channel
                        ChanNameOut = sMontage.DispNames{iMatrixDisp(iChanOut)};
                        % Try to look for it directly in the input file names
                        iInputChan = find(strcmpi({ChannelMat.Channel.Name}, ChanNameOut));
                        % If not: get the first sensor involved
                        if isempty(iInputChan)
                            iTmpPos = find(sMontage.Matrix(iMatrixDisp(iChanOut),:) > 0);
                            if (length(iTmpPos) == 1)
                                iInputChan = find(strcmpi({ChannelMat.Channel.Name}, sMontage.ChanNames{iTmpPos}));
                            end
                            % For bipolar montages: Compute average position between the two contacts
                            if isBipolar 
                                iTmpNeg = find(sMontage.Matrix(iMatrixDisp(iChanOut),:) < 0);
                                if (length(iTmpNeg) == 1)
                                    iInputRef = find(strcmpi({ChannelMat.Channel.Name}, sMontage.ChanNames{iTmpNeg}));
                                    if ~isempty(iInputRef)
                                        Loc = (ChannelMat.Channel(iInputChan).Loc + ChannelMat.Channel(iInputRef).Loc) ./ 2;
                                    end
                                end
                            end
                        end
                        % Channel still not found: set to defaults
                        if isempty(iInputChan)
                            %bst_report('Warning', sProcess, sInputs, ['Could not find a sensor definition for output channel #' num2str(iChanOut)]);
                            %ChannelMatOut.Channel(iChanOut).Name = sprintf('M%03d', iChanOut);
                            ChannelMatOut.Channel(iChanOut).Name = ChanNameOut;
                            ChannelMatOut.Channel(iChanOut).Type = 'Montage';
                        % Else: copy input channel info
                        else
                            ChannelMatOut.Channel(iChanOut).Name    = ChanNameOut;
                            ChannelMatOut.Channel(iChanOut).Comment = ChannelMat.Channel(iInputChan).Comment;
                            ChannelMatOut.Channel(iChanOut).Type    = ChannelMat.Channel(iInputChan).Type;
                            ChannelMatOut.Channel(iChanOut).Group   = ChannelMat.Channel(iInputChan).Group;
                            ChannelMatOut.Channel(iChanOut).Orient  = ChannelMat.Channel(iInputChan).Orient;
                            ChannelMatOut.Channel(iChanOut).Weight  = ChannelMat.Channel(iInputChan).Weight;
                            % Set location (one channel, or average of two SEEG contacts)
                            if ~isempty(Loc)
                                ChannelMatOut.Channel(iChanOut).Loc = Loc;
                            else
                                ChannelMatOut.Channel(iChanOut).Loc = ChannelMat.Channel(iInputChan).Loc;
                            end
                        end
                    end
                    % Save to channel study
                    db_set_channel(iChanStudyOut, ChannelMatOut, 1, 0);
                end
            else
                iStudyOut = sInputs(iInput).iStudy;
            end
            % Get output study
            sStudyOut = bst_get('Study', iStudyOut);

            % Apply montage
            if isRaw
                % Channel file in new Study
                sChannelOut = bst_get('ChannelForStudy', iStudyOut);
                ChannelMatOut = in_bst_channel(sChannelOut.FileName);
                % Full output filename derives from the condition name
                studyOutPath = bst_fileparts(file_fullpath(sStudyOut.FileName));
                [~, rawBaseOut] = bst_fileparts(studyOutPath);
                rawBaseOut = strrep(rawBaseOut, '@raw', '');
                RawFileOut = bst_fullfile(studyOutPath, [rawBaseOut '.bst']);
                % Full mat file name
                MatFile = bst_fullfile(studyOutPath, ['data_0raw_' rawBaseOut '.mat']);
                % Load data file
                DataMat = in_bst_data(sInputs(1).FileName, 'F', 'ChannelFlag', 'Time');
                sFileIn = DataMat.F;
                % Get all good channels
                iGoodChannels = DataMat.ChannelFlag;
                nChannels = length(iGoodChannels);
                % Get maximum size of a data block
                ProcessOptions = bst_get('ProcessOptions');
                blockLengthSamples = max(floor(ProcessOptions.MaxBlockSize / nChannels), 1);
                % Indices for each block
                [~, iTimesBlocks, R] = bst_epoching(1:length(DataMat.Time), blockLengthSamples);
                if ~isempty(R)
                    if ~isempty(iTimesBlocks)
                        lastTime = iTimesBlocks(end, 2);
                    else
                        lastTime = 0;
                    end
                    % Add the times for the remaining block
                    iTimesBlocks = [iTimesBlocks; lastTime+1, lastTime+size(R,2)];
                end

                % Process each block
                ImportOptions = db_template('ImportOptions');
                ImportOptions.ImportMode      = 'Time';
                ImportOptions.DisplayMessages = 0;
                ImportOptions.UseCtfComp      = isUseCtfComp;
                ImportOptions.UseSsp          = isUseSsp;
                ImportOptions.RemoveBaseline  = 'no';
                for iBlock = 1 : size(iTimesBlocks, 1)
                    SamplesBounds = iTimesBlocks(iBlock, :) - 1;
                    % Load data from link to raw data
                    F = in_fread(sFileIn, ChannelMat, 1, SamplesBounds, [], ImportOptions);
                    RawDataMat = in_bst_data(sInputs(1).FileName, 'ChannelFlag');
                    RawDataMat.F = F;
                    % Apply montage
                    RawDataMat.F = panel_montage('ApplyMontage', sMontage, RawDataMat.F(iChannels,:), sInputs(iInput).FileName, iMatrixDisp, iMatrixChan);
                    if iBlock == 1
                        % Compute channel flag and update it
                        ChannelFlag = ones(size(RawDataMat.F,1),1);
                        isChanBad = (double(sMontage.Matrix(iMatrixDisp,iMatrixChan) ~= 0) * reshape(double(RawDataMat.ChannelFlag(iChannels) == -1), [], 1) > 0);
                        ChannelFlag(isChanBad) = -1;
                        sFileIn.channelflag = ChannelFlag;
                        % Create an empty Brainstorm-binary file
                        sFileOut = out_fopen(RawFileOut, 'BST-BIN', sFileIn, ChannelMatOut);
                    end
                    % Write block
                    out_fwrite(sFileOut, ChannelMatOut, 1, iTimesBlocks(iBlock, :)-1, [], RawDataMat.F);
                end
                % Update projectors data
                if isUseSsp
                    % Mark the projectors as already applied to the file
                    if ~isempty(ChannelMatOut.Projector)
                        for iProj = 1:length(ChannelMatOut.Projector)
                            if (ChannelMatOut.Projector(iProj).Status == 1)
                                ChannelMatOut.Projector(iProj).Status = 2;
                            end
                        end
                    end
                else
                    % Clear old projectors
                    if ~isempty(ChannelMatOut.Projector)
                        ChannelMatOut.Projector = repmat(db_template('projector'), 0);
                    end
                end
                bst_save(file_fullpath(sChannelOut.FileName), ChannelMatOut);
                % Set and save output sFile structure (link to raw, a .mat file)
                sInMat = in_bst(sInputs(1).FileName, [], 1);
                sOutMat = sInMat;
                sOutMat.ChannelFlag = sFileOut.channelflag;
                sOutMat.F = sFileOut;
                % Update History
                if isUseCtfComp && strcmp(sOutMat.F.device, 'CTF')
                    sOutMat = bst_history('add', sOutMat, 'process', [func2str(sProcess.Function), ': Applied CTF compensation']);
                end
                if isUseSsp && ~isempty(ChannelMatOut.Projector)
                    sOutMat = bst_history('add', sOutMat, 'process', [func2str(sProcess.Function), ': Applied SSP/ICA projectors']);
                end
                sOutMat = bst_history('add', sOutMat, 'montage', ['Applied montage: ' sMontage.Name]);
                bst_save(MatFile, sOutMat, 'v6');
                % Register in BST database
                db_add_data(iStudyOut, MatFile, sOutMat);
                OutputFiles{end+1} = MatFile;

            else
                if isCreateChan
                    DataMat.F = panel_montage('ApplyMontage', sMontage, DataMat.F(iChannels,:), sInputs(iInput).FileName, iMatrixDisp, iMatrixChan);
                    % Compute channel flag
                    ChannelFlag = ones(size(DataMat.F,1),1);
                    isChanBad = (double(sMontage.Matrix(iMatrixDisp,iMatrixChan) ~= 0) * reshape(double(DataMat.ChannelFlag(iChannels) == -1), [], 1) > 0);
                    ChannelFlag(isChanBad) = -1;
                else
                    DataMat.F(iChannels,:) = panel_montage('ApplyMontage', sMontage, DataMat.F(iChannels,:), sInputs(iInput).FileName, iMatrixDisp, iMatrixChan);
                    ChannelFlag = DataMat.ChannelFlag;
                end
                % Edit data structure
                DataMat.Comment     = [DataMat.Comment ' | ' strMontage];
                DataMat.ChannelFlag = ChannelFlag;
                DataMat = bst_history('add', DataMat, 'montage', ['Applied montage: ' sMontage.Name]);
                % New filename
                [fPath, fBase, fExt] = bst_fileparts(sInputs(iInput).FileName);
                NewDataFile = bst_fullfile(bst_fileparts(file_fullpath(sStudyOut.FileName)), [fBase '_montage.mat']);
                NewDataFile = file_unique(NewDataFile);
                % Save new data file
                bst_save(NewDataFile, DataMat, 'v6');
                % Add file to database
                db_add_data(iStudyOut, NewDataFile, DataMat);
                % Add file to list of returned files
                OutputFiles{end+1} = NewDataFile;
            end
            
            % Copy video links
            if ~isequal(iStudyIn, iStudyOut) && ~isempty(sStudyIn.Image) && isempty(sStudyOut.Image)
                sStudyOut = process_import_data_event('CopyVideoLinks', NewDataFile, sStudyIn);
            end
        end

        % === PROCESS HEAD MODELS ===
        if isCreateChan && (sSubject.UseDefaultChannel == 0) && ~isempty(sStudyChan.HeadModel)
            % Info message about the list of bad channels used for the head models
            bst_report('Info', sProcess, sInputs, ['The montage applied on the head model and noise covariance used the list of bad channels from data file: ' sInputs(iInput).FileName]);
            % Loop through all the head models
            for iFile = 1:length(sStudyChan.HeadModel)
                % Load head model file
                HeadModelMat = in_bst_headmodel(sStudyChan.HeadModel(iFile).FileName);
                % Ignore the channels that have NaN values, otherwise everything in output is NaN
                HeadModelMat.Gain(isnan(HeadModelMat.Gain)) = 0;
                % Apply montage to it
                HeadModelMat.Gain = panel_montage('ApplyMontage', sMontage, HeadModelMat.Gain(iChannels,:), sInputs(iInput).FileName, iMatrixDisp, iMatrixChan);
                HeadModelMat = bst_history('add', HeadModelMat, 'montage', ['Applied montage: ' sMontage.Name]);
                % Output filename
                [fPath, fBase, fExt] = bst_fileparts(sStudyChan.HeadModel(iFile).FileName);
                HeadModelFile = bst_fullfile(bst_fileparts(file_fullpath(sStudyOut.FileName)), [fBase, fExt]);
                % Save new file
                bst_save(HeadModelFile, HeadModelMat, 'v7');
                % Register in database
                sStudyOut = db_add_data(iStudyOut, HeadModelFile, HeadModelMat, []);
            end
        end
    end
end


