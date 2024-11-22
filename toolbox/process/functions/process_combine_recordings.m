function varargout = process_combine_recordings(varargin)
% process_combine_recordings: Combine multiple synchronized signals into
% one recording (resampling the signals to the highest sampling frequency)

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
% Authors: Edouard Delaire, 2024
%          Raymundo Cassani, 2024

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Combine files';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Synchronize';
    sProcess.Index       = 682;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    
    % Option: Condition
    sProcess.options.condition.Comment = 'Condition name:';
    sProcess.options.condition.Type    = 'text';
    sProcess.options.condition.Value   = 'Combined';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles = {};

    nInputs   = length(sInputs);
    sIdxChNew = cell(1, nInputs); % Channel indices for each input in new channel file
    sProjNew  = cell(1, nInputs); % Projectors for each input in new channel file

    % Check for same Subject
    if length(unique({sInputs.SubjectFile})) > 1
        bst_report('Error', sProcess, sInputs, 'All raw recordings must belong to the same Subject.');
        return
    end
    % Get unique comment for new condition
    NewComment = sProcess.options.condition.Value;
    if isempty(NewComment)
        bst_report('Error', sProcess, sInputs, 'Condition name was not defined.');
        return
    end
    NewCondition = ['@raw', file_standardize(NewComment)];
    sStudies = bst_get('StudyWithSubject', sInputs(1).SubjectFile);
    NewCondition = file_unique(NewCondition, [sStudies.Condition]);


    % ===== GET METADATA FOR RECORDINGS =====
    bst_progress('start', 'Combining recordings', 'Loading metadata...', 0, 3 * nInputs); % 3 steps per input file
    % Get Time and F structure
    for iInput = 1 : nInputs
        sMetaData(iInput) = in_bst_data(sInputs(iInput).FileName, 'Time', 'F');
        bst_progress('inc', 1);
    end
    % Check that the limits are close enough, same duration, and same start
    all_times = [arrayfun(@(x) x.F.prop.times(1), sMetaData)', arrayfun(@(x) x.F.prop.times(2), sMetaData)'];
    max_diffs = max(all_times,[], 1) - min(all_times,[], 1);
    if any(max_diffs > 1) % Tolerance of 1 second for maximum differences
        bst_report('Error', sProcess, sInputs, 'Recordings to merge must have the same start and end time.');
        return
    end


    % ===== COMBINE METADATA =====
    bst_progress('text', 'Combining metadata...');
    % Recordings file with higher sampling frequency is used as seed for time
    [~, iRefRec] = max(arrayfun(@(x) x.F.prop.sfreq, sMetaData));
    % New sampling frequency
    NewFs = sMetaData(iRefRec).F.prop.sfreq;
    % Study for combined recordings
    iNewStudy = db_add_condition(sInputs(iRefRec).SubjectName,  NewCondition);
    sNewStudy = bst_get('Study', iNewStudy);
    % New time vector
    NewTime = sMetaData(iRefRec).Time;
    % New channel definition
    NewChannelsN  = 0;
    NewChannelMat = db_template('ChannelMat');
    NewChannelMat.Channel = repmat(db_template('channeldesc'), NewChannelsN);
    % New channel flag
    NewChannelFlag = [];
    % New events
    NewEvents = repmat(db_template('event'), 0);

    % Events to be merged in combined raw file
    poolEvents   = NewEvents; % Empty sEvents
    poolEventsIx = [];        % Index of file associated with the event
    poolEventsFx = [];        % Fixing channel-wise data is needed
    for iInput = 1 : nInputs
        poolEvents   = [poolEvents, sMetaData(iInput).F.events];
        poolEventsIx = [poolEventsIx, repmat(iInput, 1, length(sMetaData(iInput).F.events))];
        poolEventsFx = [poolEventsFx, ones(1, length(sMetaData(iInput).F.events))];
    end
    % Handle duplicated names and identify events do not need their channel field updated
    [uniqueLabels, ~, iUnique] = unique({poolEvents.label});
    iDel = [];
    for iu = 1 : length(uniqueLabels)
        % Instances of unique events
        ixUnique = find(iUnique == iu)';
        % Do nothing if event is not duplicated
        if length(ixUnique) == 1
            continue
        % Keep only one copy, set to not be channel-wise fixed
        elseif all(cellfun(@isempty, {poolEvents(ixUnique).channels})) && isequal(poolEvents(ixUnique).times)
            poolEventsFx(ixUnique) = 0;
            iDel = [iDel, ixUnique(2:end)];
        % Create unique names
        else
            baseLabel = poolEvents(ixUnique(1)).label;
            for id = 1 : length(ixUnique)
                % Update their names to make unique
                poolEvents(ixUnique(id)).label = sprintf([baseLabel '_%02d'], id);
            end
        end
    end
    poolEvents(iDel) = [];
    poolEventsIx(iDel) = [];
    poolEventsFx(iDel) = [];

    for iInput = 1 : nInputs
        % Get channel file
        tmpChannelMat = in_bst_channel(sInputs(iInput).ChannelFile);
        tmpChannelNames = {tmpChannelMat.Channel.Name};
        % Concatenate channels
        % Ensure unique names for channels
        ixChannelDup = find(ismember({tmpChannelMat.Channel.Name}, {NewChannelMat.Channel.Name}));
        for iDup = 1 : length(ixChannelDup)
            tmpChannelMat.Channel(ixChannelDup(iDup)).Name = file_unique(tmpChannelMat.Channel(ixChannelDup(iDup)).Name, {NewChannelMat.Channel.Name});
        end
        sIdxChNew{iInput} =  NewChannelsN + [1 : length(tmpChannelMat.Channel)];
        NewChannelMat.Channel = [NewChannelMat.Channel, tmpChannelMat.Channel];

        % Concatenate channel flag
        NewChannelFlag = [NewChannelFlag; sMetaData(iInput).ChannelFlag];

        % Store projectors to concatenate later
        sProjNew{iInput} = tmpChannelMat.Projector;

        % Add channel information if needed
        tmpEvents = poolEvents(poolEventsIx == iInput);
        for iEvent = 1 : length(tmpEvents)
            tmpEvent = tmpEvents(iEvent);
            if poolEventsFx(iEvent)
                % Add channel info
                addedChannelNames = {NewChannelMat.Channel(sIdxChNew{iInput}).Name};
                nOccurences = size(tmpEvent.times, 2);
                % Make a channel-wise event with all channels in Input file
                if isempty(tmpEvent.channels)
                    tmpEvent.channels = repmat({addedChannelNames}, 1, nOccurences);
                else
                    for iOccurence = 1 : nOccurences
                        % Make a channel-wise event with all channels in Input file
                        if isempty(tmpEvent.channels{iOccurence})
                            tmpEvent.channels{iOccurence} = addedChannelNames;
                        % Update channel names to names that were added in combined file
                        else
                            [~, iLoc] = ismember(tmpEvent.channels{iOccurence}, tmpChannelNames);
                            tmpEvent.channels{iOccurence} = addedChannelNames(iLoc);
                        end
                    end
                end
            end
            NewEvents = [NewEvents, tmpEvent];
        end

        % Copy videos
        tmpStudy = bst_get('Study', sInputs(iInput).iStudy);
        if isfield(tmpStudy,'Image') && ~isempty(tmpStudy.Image)
            for iTmpVideo = 1 : length(tmpStudy.Image)
                sTmpVideo = load(file_fullpath(tmpStudy.Image(iTmpVideo).FileName));
                if isempty(sTmpVideo.VideoStart)
                    sTmpVideo.VideoStart = 0;
                end
                [~, outVideoFile] = import_video(iNewStudy, sTmpVideo.LinkTo);
                figure_video('SetVideoStart', outVideoFile{1}, sprintf('%.3f', sTmpVideo.VideoStart));
            end
        end

        % Concat NIRS wavelengths
        if isfield(tmpChannelMat, 'Nirs')
            if ~isfield(NewChannelMat, 'Nirs')
                NewChannelMat.Nirs = tmpChannelMat.Nirs;
            else
                NewChannelMat.Nirs = sort(union(tmpChannelMat.Nirs, NewChannelMat.Nirs));
            end
        end

        % New channel count
        NewChannelsN = length(NewChannelMat.Channel);
        % Progress
        bst_progress('inc', 1);
    end

    % Concatenate Projectors
    for iInput = 1 : nInputs
        for iProj = 1 : length(sProjNew{iInput})
            % Adjust Nchan in Projector
            sizeComp = size(sProjNew{iInput}(iProj).Components);
            newSizeComp = sizeComp;
            ixs = cell(1, length(newSizeComp));
            for iDim = 1 : length(sizeComp)
                if sizeComp(iDim) == length(sIdxChNew{iInput})
                    newSizeComp(iDim) = NewChannelsN;
                    ixs{iDim} = sIdxChNew{iInput};
                else
                    newSizeComp(iDim) = sizeComp(iDim);
                    ixs{iDim} = 1:sizeComp(iDim);
                end
            end
            newComponents = zeros(newSizeComp);
            newComponents(ixs{1}, ixs{2}) = sProjNew{iInput}(iProj).Components;
            sProjNew{iInput}(iProj).Components = newComponents;
        end
    end
    NewChannelMat.Projector = [sProjNew{:}];

    % Save channel file
    db_set_channel(iNewStudy, NewChannelMat, 0, 0);


    % ===== COMBINE DATA =====
    bst_progress('text', 'Combining data...');
    % Link to combined raw file
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sNewStudy.FileName), 'data_0raw_combined');
    % Combined raw file
    [rawDirOut, rawBaseOut] = bst_fileparts(OutputFile);
    rawBaseOut = regexprep(rawBaseOut, '^data_0raw_', '');
    RawFileOut = bst_fullfile(rawDirOut, [rawBaseOut, '.bst']);

    % Create a header structure for combined recordings
    sFileIn = db_template('sfile');
    sFileIn.header.nsamples = length(NewTime);
    sFileIn.prop.times      = [NewTime(1), NewTime(end)];
    sFileIn.prop.sfreq      = NewFs;
    sFileIn.events          = NewEvents;
    sFileIn.channelflag     = NewChannelFlag;
    sFileOut = out_fopen(RawFileOut, 'BST-BIN', sFileIn, NewChannelMat);

    % Build output structure for combined recordings
    sOutMat = db_template('DataMat');
    sOutMat.Comment     = 'Link to raw file | Combined';
    sOutMat.F           = sFileOut;
    sOutMat.format      = 'BST-BIN';
    sOutMat.DataType    = 'raw';
    sOutMat.ChannelFlag = NewChannelFlag;
    sOutMat.Time        = sFileIn.prop.times;
    sOutMat.Device      = 'Brainstorm';
    bst_save(OutputFile, sOutMat, 'v6');

    % Save all data to combined file
    for iInput = 1 : nInputs
        % Load raw data
        sDataToCombine = in_bst(sInputs(iInput).FileName, [], 1, 1, 'no', 0);
        % Update raw data to new time vector
        if iInput ~= iRefRec
            sDataToCombine.F = interp1(sDataToCombine.Time, sDataToCombine.F', NewTime)';
        end
        % Write these channels
        out_fwrite(sFileOut, NewChannelMat, 1, [], sIdxChNew{iInput}, sDataToCombine.F);
        bst_progress('inc', 1);
    end
    
    % Register in BST database
    db_add_data(iNewStudy, OutputFile, sOutMat);
    OutputFiles{iInput} = OutputFile;
    bst_progress('stop');
end
