function varargout = process_split_raw_file( varargin )
% PROCESS_SPLIT_RAW_FILE: Splits a raw file around specific time segments.

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
% Authors: Martin Cousineau, Marc Lalancette, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Split raw file';
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/HeadMotion#Split_the_recording';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import recordings'};
    sProcess.Index       = 70;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Event name to read samples from
    sProcess.options.eventname.Comment = 'Event name: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = '';
    % Whether to keep segments outside of continuous events
    sProcess.options.keepbadsegments.Comment = 'Keep segments outside of continuous event?';
    sProcess.options.keepbadsegments.Type    = 'checkbox';
    sProcess.options.keepbadsegments.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sOutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    sOutputFiles = {};
    bst_progress('start', 'Split raw file', 'Preparing file...');
    % Extract event
    evtName = strtrim(sProcess.options.eventname.Value);
    if isempty(evtName)
        bst_report('Error', sProcess, sInput, 'No event selected.');
        return;
    end
    DataMat = in_bst_data(sInput.FileName, 'F');
    sFile = DataMat.F;
    % Get selected event
    iEvt = find(strcmpi({sFile.events.label}, evtName));
    if isempty(iEvt)
        bst_report('Error', sProcess, sInput, ['Event "' evtName '" does not exist in file.']);
        return;
    end
    keepBadSegments = sProcess.options.keepbadsegments.Value;
    % Get maximum size of a data block
    ProcessOptions = bst_get('ProcessOptions');
    MaxSize = ProcessOptions.MaxBlockSize;
    % Get size of input data
    [sMat, matName] = in_bst(sInput.FileName, [], 0);
    nRow = length(sMat.ChannelFlag);
    nCol = length(sMat.Time);
    % Get data matrix
    sFileIn = sMat.(matName);
    sEvent = sFile.events(iEvt);
    % Reconstruct removed field "samples" (this event structure should not be added again to the sFile structure)
    sEvent.samples = round(sEvent.times .* sFile.prop.sfreq);
    % Make sure required samples are within range
    fileSamplesIn = round(sFileIn.prop.times .* sFileIn.prop.sfreq);
    if any(or(sEvent.samples(:) < fileSamplesIn(1), sEvent.samples(:) > fileSamplesIn(2)))
        bst_report('Error', sProcess, sInput, ['Event time(s) are not all within the range of the input file: ' ...
            '[' num2str(sFileIn.prop.times(1)) 's - ' num2str(sFileIn.prop.times(2)) 's].']);
        return;
    end
    [SampleTargets, SegmentNames, BadSegments] = GetSamplesFromEvent(sEvent, ...
        fileSamplesIn, sFileIn.prop.times, keepBadSegments);
    % SampleTargets are "file/event samples", often starting at 0, not 1.
    numTargets = length(SampleTargets);
    % Read the channel file
    if ~isempty(sInput.ChannelFile)
        ChannelMat = in_bst_channel(sInput.ChannelFile);
    else
        ChannelMat = [];
    end
    % Get input raw path and name
    if ismember(sFileIn.format, {'CTF', 'CTF-CONTINUOUS'})
        [rawPathIn, rawBaseIn] = bst_fileparts(bst_fileparts(sFileIn.filename));
    else
        [rawPathIn, rawBaseIn] = bst_fileparts(sFileIn.filename);
    end
    % Make sure that there are not weird characters in the folder names
    rawBaseIn = file_standardize(rawBaseIn);
    % New folder name
    if isfield(sFileIn, 'condition') && ~isempty(sFileIn.condition)
        newCondition = ['@raw', sFileIn.condition];
    else
        newCondition = ['@raw', rawBaseIn];
    end
    % Split the block size in rows and columns
    if (nRow * nCol > MaxSize)
        BlockSizeCol = max(floor(MaxSize / nRow), 1);
    else
        BlockSizeCol = nCol;
    end
    % Split data in blocks
    nBlockCol = ceil(nCol / BlockSizeCol);
    % Loop on samples
    iFile = 1;
    iNextSample = 1;
    newFile = 1;
    sFileOut = [];
    bst_progress('start', 'Split raw file', 'Splitting file...', 0, nBlockCol);
    
    for iBlockCol = 1:nBlockCol
        % Indices of columns to process
        SamplesBounds = fileSamplesIn(1) + [(iBlockCol-1) * BlockSizeCol + 1, min(iBlockCol * BlockSizeCol, nCol)] - 1;
        % SamplesBounds are now also "file/event samples".
        % Check whether current block contains a sample of interest
        iFirstChunkSample = SamplesBounds(1);
        while iNextSample <= numTargets && SampleTargets(iNextSample) <= SamplesBounds(2) + 1
            % Get chunk before sample of interest
            [sFileOut, iFile, sOutputFiles] = SaveBlock([iFirstChunkSample, SampleTargets(iNextSample)-1], ...
                sInput, sFileIn, sFileOut, ChannelMat, newCondition, sMat, iFile, newFile, ...
                sOutputFiles, iNextSample, SampleTargets, SegmentNames, BadSegments, keepBadSegments);
            iFirstChunkSample = SampleTargets(iNextSample);
            newFile = 1;
            iNextSample = iNextSample + 1;
        end
        % Get chunk after sample of interest
        if iFirstChunkSample <= SamplesBounds(2)
            [sFileOut, iFile, sOutputFiles] = SaveBlock([iFirstChunkSample, SamplesBounds(2)], ...
                sInput, sFileIn, sFileOut, ChannelMat, newCondition, sMat, iFile, newFile, ...
                sOutputFiles, iNextSample, SampleTargets, SegmentNames, BadSegments, keepBadSegments);
        end
        newFile = 0;
        bst_progress('inc', 1);
    end
end

function [sFileOut, iFile, sOutputFiles] = SaveBlock(SamplesBounds, ...
    sInput, sFileIn, sFileOut, ChannelMat, newCondition, sMat, iFile, newFile, ...
    sOutputFiles, iNextSample, SampleTargets, SegmentNames, BadSegments, keepBadSegments)
    % If this is a bad segment, skip when appropriate
    iSegmentFile = min(iNextSample, length(BadSegments));
    if BadSegments(iSegmentFile) && ~keepBadSegments
        if newFile
            iFile = iFile + 1;
        end
        return;
    end
    fileSamplesIn = round(sFileIn.prop.times .* sFileIn.prop.sfreq);
    
    % Read block (no need to read bad blocks if we skip them).
    sInput.A = in_fread(sFileIn, ChannelMat, 1, SamplesBounds);

    if newFile
        ProtocolInfo = bst_get('ProtocolInfo');
        % Get new condition name
        newStudyPath = file_unique(bst_fullfile(ProtocolInfo.STUDIES, sInput.SubjectName, [newCondition '_' SegmentNames{iFile}]));
        % Output file name derives from the condition name
        [tmp, rawBaseOut, rawBaseExt] = bst_fileparts(newStudyPath);
        rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
        % Full output filename
        RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']);
        % Get input study (to copy the creation date)
        sInputStudy = bst_get('AnyFile', sInput.FileName);
        % Get new condition name
        [tmp, ConditionName] = bst_fileparts(newStudyPath, 1);
        % Create output condition
        iOutputStudy = db_add_condition(sInput.SubjectName, ConditionName, [], sInputStudy.DateOfStudy);
        % Get output study
        sOutputStudy = bst_get('Study', iOutputStudy);
        % Full file name
        MatFile = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sOutputStudy.FileName), ['data_0raw_' rawBaseOut '.mat']);

        % Figure out time sample of next block
        if iNextSample <= length(SampleTargets)
            iNextTime = SampleTargets(iNextSample);
        else
            iNextTime = length(sMat.Time);
        end        
        % Template continuous file (for the output)
        sFileTemplate = sFileIn;
        sFileTemplate.prop.times   = [sMat.Time(SamplesBounds(1)-fileSamplesIn(1)+1), ...
          sMat.Time(iNextTime-1-fileSamplesIn(1)+1)];
        % Create an empty Brainstorm-binary file
        [sFileOut, errMsg] = out_fopen(RawFileOut, 'BST-BIN', sFileTemplate, ChannelMat);

        % Output structure
        sOutMat = sMat;
        sOutMat.Time = sFileTemplate.prop.times;
        sOutMat.F = sFileOut;
        fileSamplesOut = round(sOutMat.F.prop.times .* sOutMat.F.prop.sfreq);
        % Remove events out of bounds
        for iEvent = 1:length(sOutMat.F.events)
            if isempty(sOutMat.F.events(iEvent).times)
                continue
            end
            % Compare with samples to avoid precision errors on times.
            iKeepEvents = find(and(round(sOutMat.F.events(iEvent).times(1,:) * sOutMat.F.prop.sfreq) >= fileSamplesOut(1), ...
                round(sOutMat.F.events(iEvent).times(end,:) * sOutMat.F.prop.sfreq) <= fileSamplesOut(2)));
            sOutMat.F.events(iEvent).epochs = sOutMat.F.events(iEvent).epochs(iKeepEvents);
            sOutMat.F.events(iEvent).times = sOutMat.F.events(iEvent).times(:,iKeepEvents);
            if ~isempty(sOutMat.F.events(iEvent).reactTimes)
                sOutMat.F.events(iEvent).reactTimes = sOutMat.F.events(iEvent).reactTimes(iKeepEvents);
            end
            sOutMat.F.events(iEvent).channels = sOutMat.F.events(iEvent).channels(iKeepEvents);
            sOutMat.F.events(iEvent).notes    = sOutMat.F.events(iEvent).notes(iKeepEvents);
        end

        % Save new file
        bst_save(MatFile, sOutMat, 'v6');
        % If no default channel file: create new channel file
        if ~isempty(ChannelMat)
            db_set_channel(iOutputStudy, ChannelMat, 2, 0);
        end
         % Register in database
        db_add_data(iOutputStudy, MatFile, sOutMat);
        sOutputFiles{end+1} = MatFile;        
        iFile = iFile + 1;
    end
    % Output channel file
    ChannelMatOut = ChannelMat;
    % Write block
    sFileOut = out_fwrite(sFileOut, ChannelMatOut, 1, SamplesBounds, [], sInput.A);
end

function [SampleTargets, SegmentNames, BadSegments] = GetSamplesFromEvent(...
    sEvent, InputSamples, InputTimes, keepBadSegments, badSegmentPrefix)
  % The samples returned by this function are "file/event samples", based
  % on sFileIn.prop.times.  E.g. most times the first sample is 0, not 1.
    if nargin < 5 || isempty(badSegmentPrefix)
        badSegmentPrefix = 'bad';
    end

    SampleTargets = [];
    SegmentNames = [];
    BadSegments = [];
    [dimSamples, numSamples] = size(sEvent.samples);
    if numSamples < 1
        return;
    end
    % Sort samples
    [samples, indices] = sort(sEvent.samples(1,:));
    % Convert extended events to a list of samples representing the sample
    % after the end of each event.  Overlap is not permitted, and the
    % entire recording is included in the final list.
    if dimSamples == 2
        samples = sEvent.samples(:,indices);
        times   = round(sEvent.times(:,indices));
        SegmentNames = {};
        numZeros = length(num2str(numSamples));
        BadSegments = [];
        
        % Add "start" event, just before the first recording sample.
        samples = [[InputSamples(1)-1; InputSamples(1)-1], samples];
        times = [round([InputTimes(1); InputTimes(1)]), times];
        % Add "end" event, right after last recording sample.
        samples(:, end + 1) = [InputSamples(2)+1; InputSamples(2)+1];
        times(:, end + 1) = round([InputTimes(2); InputTimes(2)]);
        
        isOverlap = false;
        iSeg = 0;
        for iSample = 2:size(samples, 2)
          if samples(1, iSample) <= samples(2, iSample-1)
            % This extended event overlaps with the previous one. There will be a warning later.
            isOverlap = true;
            if samples(2, iSample) > samples(1, iSample-1)
              % Keep the non-overlapping part. 
              samples(1, iSample) = samples(2, iSample-1) + 1;
              times(1, iSample) = times(2, iSample-1);
            else % entirely contained in previous event.
              continue;
            end
          elseif samples(1, iSample) > samples(2, iSample-1) + 1 % +1 because end sample of extended event boundaries are inclusive
            % There are samples between the two events, add them as bad.
            SampleTargets(end + 1) = samples(2, iSample-1) + 1;
            BadSegments(end + 1) = 1;
            if keepBadSegments
                iSeg = iSeg + 1;
            end
            SegmentNames{end + 1} = [zeroPrefix(iSeg, numZeros) '_' badSegmentPrefix '_' ...
                GetTimeSuffix([times(2,iSample-1), times(1,iSample)])];
          end
          % Add the event current event.
          SampleTargets(end + 1) = samples(1, iSample);
          BadSegments(end + 1) = 0;
          iSeg = iSeg + 1;
          SegmentNames{end + 1} = [zeroPrefix(iSeg, numZeros) '_' sEvent.label '_' GetTimeSuffix(times(:,iSample))];
        end
        
        if isOverlap
          fprintf('BST> Split raw file does not allow overlaping events.  Some events were truncated.\n');
        end

        % We don't need the first start sample, which is the first sample of the recording.
        SampleTargets(1) = [];
        % Also remove the "end" event name and bad flag.
        BadSegments(end) = [];
        SegmentNames(end) = [];
    else
        samples(end+1) = InputSamples(2)+1;
        SampleTargets = samples;
        if SampleTargets(1) == InputSamples(1)
          SampleTargets(1) = [];
        end
        SegmentNames = CreateCellNumberList(numSamples + 1);
        BadSegments = zeros(1, numSamples + 1);
    end
end

function CellNumberList = CreateCellNumberList(n)
    numDigits = floor(log(n) / log(10));
    CellNumberList = cell(1,n);
    for i=1:n
        d = floor(log(n) / log(10));
        CellNumberList{i} = [repmat('0', 1, numDigits - d), num2str(i)];
    end
end

function Suffix = GetTimeSuffix(time)
    if ~iscell(time)
        time = num2cell(time);
    end
    Suffix = [num2str(time{1}) 's'];
    if length(time) > 1 && any(time{1} ~= time{2})
        if isnumeric(time{2})
            Suffix = [Suffix '-' num2str(time{2}) 's'];
        else
            Suffix = [Suffix '-' time{2}];
        end
    end
end

function str = zeroPrefix(n, numZeros)
    str = num2str(n);
    while length(str) < numZeros
        str = ['0' str];
    end
end
