function varargout = process_montage_apply( varargin )
% PROCESS_MONTAGE_APPLY: Applies a montage to recordings (creates new data and channel files).
%
% USAGE:  OutputFiles = process_montage_apply('Run', sProcess, sInputs)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Apply montage';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 307;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/MontageEditor';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === MONTAGE NAME
    sProcess.options.montage.Comment = 'Montage name: ';
    sProcess.options.montage.Type    = 'montage';
    sProcess.options.montage.Value   = '';
    % === NEW CHANNEL FILE
    sProcess.options.createchan.Comment = 'Create new folders';
    sProcess.options.createchan.Type    = 'checkbox';
    sProcess.options.createchan.Value   = 1;
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
    isCreateChan = (sProcess.options.createchan.Value == 1);
    MontageName  = sProcess.options.montage.Value;
    % Get loaded montage
    sMontage = panel_montage('GetMontage',MontageName);
    if isempty(sMontage) || (length(sMontage) > 1)
        bst_report('Error', sProcess, sInputs, ['Invalid montage name "' MontageName '".']);
        return;
    end
    % If not creating a new channel file: montage output has to be compatible with curent channel structure
    isCompatibleChan = ~strcmpi(sMontage.Type, 'selection') && (~strcmpi(sMontage.Type, 'text') || all(sum(sMontage.Matrix,2) == 0));
    if ~isCreateChan && ~isCompatibleChan
        bst_report('Error', sProcess, [], ['The montage "' sMontage.Name '" cannot be applied without writing a new folders.']);
        return;
    end

    % Get all the channel files from the list of files
    allChanFiles = unique({sInputs.ChannelFile});
    for iChan = 1:length(allChanFiles)
        % Process each data file
        iDataFile = find(strcmpi(allChanFiles{iChan}, {sInputs.ChannelFile}));
        for ik = 1:length(iDataFile)
            iInput = iDataFile(ik);
            % Get subject for the channel file
            sSubject = bst_get('Subject', sInputs(iInput).SubjectFile, 1);
            % Load channel file 
            ChannelMat = in_bst_channel(allChanFiles{iChan});
        
            % Load input file 
            DataMat = in_bst_data(sInputs(iInput).FileName);
            % Build average reference
            if (strcmpi(sMontage.Name, 'Average reference'));
                sMontage = panel_montage('GetMontageAvgRef', ChannelMat.Channel, DataMat.ChannelFlag, 1);
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
            % Apply montage
            if isCreateChan
                DataMat.F = sMontage.Matrix(iMatrixDisp,iMatrixChan) * DataMat.F(iChannels,:);
                % Compute channel flag
                ChannelFlag = ones(size(DataMat.F,1),1);
                isChanBad = (double(sMontage.Matrix(iMatrixDisp,iMatrixChan) ~= 0) * double(DataMat.ChannelFlag(iChannels) == -1) > 0);
                ChannelFlag(isChanBad) = -1;
            else
                DataMat.F(iChannels,:) = sMontage.Matrix(iMatrixDisp,iMatrixChan) * DataMat.F(iChannels,:);
                ChannelFlag = DataMat.ChannelFlag;
            end

            % Get output study
            if isCreateChan
                % If the subject has default channel: Create new subject
                if (sSubject.UseDefaultChannel > 0)
                    % Output subject name
                    SubjectNameOut = file_standardize([sSubject.Name '_' sMontage.Name]);
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
                    % Output condition name
                    ConditionOut = file_standardize([sInputs(iInput).Condition, '_', sMontage.Name]);
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
                    ChannelMatOut.Comment = [ChannelMatOut.Comment ' | ' sMontage.Name];
                    ChannelMatOut.Channel = repmat(db_template('channeldesc'), 0);
                    % Create list of output channels
                    for iChanOut = 1:length(iMatrixDisp)
                        % Name of the output channel
                        ChanNameOut = sMontage.DispNames{iMatrixDisp(iChanOut)};
                        % Try to look for it directly in the input file names
                        iInputChan = find(strcmpi({ChannelMat.Channel.Name}, ChanNameOut));
                        % If not: get the first sensor involved
                        if isempty(iInputChan)
                            iTmp = find(sMontage.Matrix(iMatrixDisp(iChanOut),:) > 0);
                            if ~isempty(iTmp)
                                iInputChan = find(strcmpi({ChannelMat.Channel.Name}, sMontage.ChanNames{iTmp}));
                            end
                        end
                        % Channel still not found: set to defaults
                        if isempty(iInputChan)
                            bst_report('Warning', sProcess, sInputs, ['Could not find a sensor definition for output channel #' num2str(iChanOut)]);
                            ChannelMatOut.Channel(iChanOut).Name = sprintf('M%03d', iChanOut);
                            ChannelMatOut.Channel(iChanOut).Type = 'Montage';
                        % Else: copy input channel info
                        else
                            ChannelMatOut.Channel(iChanOut).Name    = ChanNameOut;
                            ChannelMatOut.Channel(iChanOut).Comment = ChannelMat.Channel(iInputChan).Comment;
                            ChannelMatOut.Channel(iChanOut).Type    = ChannelMat.Channel(iInputChan).Type;
                            ChannelMatOut.Channel(iChanOut).Group   = ChannelMat.Channel(iInputChan).Group;
                            ChannelMatOut.Channel(iChanOut).Loc     = ChannelMat.Channel(iInputChan).Loc;
                            ChannelMatOut.Channel(iChanOut).Orient  = ChannelMat.Channel(iInputChan).Orient;
                            ChannelMatOut.Channel(iChanOut).Weight  = ChannelMat.Channel(iInputChan).Weight;
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
            
            % Edit data strcture
            DataMat.Comment     = [DataMat.Comment ' | ' sMontage.Name];
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
    end
end


