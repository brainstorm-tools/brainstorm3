function varargout = process_split_raw_file( varargin )
% PROCESS_ABSOLUTE: Splits a raw file around specific time segments.

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
% Authors: Martin Cousineau, 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Split Raw File';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 72;
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
    sEvent = sFile.events(iEvt);
    keepBadSegments = sProcess.options.keepbadsegments.Value;
    [SampleTargets, SegmentNames, BadSegments] = GetSamplesFromEvent(sEvent);
    numTargets = length(SampleTargets);
    % Get maximum size of a data block
    ProcessOptions = bst_get('ProcessOptions');
    MaxSize = ProcessOptions.MaxBlockSize;
    % Get size of input data
    [sMat, matName] = in_bst(sInput.FileName, [], 0);
    nRow = length(sMat.ChannelFlag);
    nCol = length(sMat.Time);
    % Get data matrix
    sFileIn = sMat.(matName);
    % Make sure required samples are within range
    if any(or(SampleTargets < sFileIn.prop.samples(1)+1, SampleTargets > sFileIn.prop.samples(2)+1))
        bst_report('Error', sProcess, sInput, ['Event sample(s) are not all within the range of the input file: ' ...
            '[' num2str(sFileIn.prop.samples(1)+1) ' - ' num2str(sFileIn.prop.samples(2)+1) '].']);
        return;
    end
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
    newFile = ~BadSegments(1) || keepBadSegments;
    sFileOut = [];
    
    for iBlockCol = 1:nBlockCol
        % Indices of columns to process
        iCol = 1 + (((iBlockCol-1)*BlockSizeCol) : min(iBlockCol * BlockSizeCol - 1, nCol - 1));
        SamplesBounds = sFileIn.prop.samples(1) + iCol([1,end]);
        % Read block
        sInput.A = in_fread(sFileIn, ChannelMat, 1, SamplesBounds-1);
        % Check whether current block contains a sample of interest
        iBeforeSample = SamplesBounds(1);
        while iNextSample <= numTargets && SampleTargets(iNextSample) < SamplesBounds(2)
            % Get chunk before sample of interest
            [sFileOut, iFile, sOutputFiles] = SaveBlock([iBeforeSample, SampleTargets(iNextSample)-1], ...
                sInput, sFileIn, sFileOut, ChannelMat, newCondition, sMat, iFile, newFile, sOutputFiles, iNextSample, SampleTargets, SegmentNames, BadSegments, keepBadSegments);
            iBeforeSample = SampleTargets(iNextSample);
            newFile = 1;
            iNextSample = iNextSample + 1;
        end
        % Get chunk after sample of interest
        if iBeforeSample < SamplesBounds(2)
            [sFileOut, iFile, sOutputFiles] = SaveBlock([iBeforeSample, SamplesBounds(2)], ...
                sInput, sFileIn, sFileOut, ChannelMat, newCondition, sMat, iFile, newFile, sOutputFiles, iNextSample, SampleTargets, SegmentNames, BadSegments, keepBadSegments);
        end
        newFile = 0;
    end
end

function [sFileOut, iFile, sOutputFiles] = SaveBlock(SamplesBounds, sInput, sFileIn, sFileOut, ChannelMat, newCondition, sMat, iFile, newFile, sOutputFiles, iNextSample, SampleTargets, SegmentNames, BadSegments, keepBadSegments)
    % If this is a bad segment, skip when appropriate
    iSegmentFile = min(iFile, length(BadSegments));
    if BadSegments(iSegmentFile) && ~keepBadSegments
        if newFile
            iFile = iFile + 1;
        end
        return;
    end
    
    if newFile
        % Make sure we're not creating more segments than expected
        if iSegmentFile ~= iFile
            error('Incoherent number of segments.');
        end
        ProtocolInfo = bst_get('ProtocolInfo');
        % Get new condition name
        newStudyPath = file_unique(bst_fullfile(ProtocolInfo.STUDIES, sInput.SubjectName, [newCondition '_' SegmentNames{iFile}]));
        % Output file name derives from the condition name
        [tmp, rawBaseOut] = bst_fileparts(newStudyPath);
        rawBaseOut = strrep(rawBaseOut, '@raw', '');
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
        sFileTemplate.prop.times   = [sMat.Time(SamplesBounds(1)), sMat.Time(iNextTime)];
        sFileTemplate.prop.samples = round(sFileTemplate.prop.times .* sFileTemplate.prop.sfreq);
        % Create an empty Brainstorm-binary file
        [sFileOut, errMsg] = out_fopen(RawFileOut, 'BST-BIN', sFileTemplate, ChannelMat);

        % Output structure
        sOutMat = sMat;
        sOutMat.Time = sFileTemplate.prop.times;
        sOutMat.F = sFileOut;
        % Remove events out of bounds
        for iEvent = 1:length(sOutMat.F.events)
            iKeepEvents = find(and(sOutMat.F.events(iEvent).times(1,:) >= sOutMat.Time(1), sOutMat.F.events(iEvent).times(end,:) <= sOutMat.Time(2)));
            sOutMat.F.events(iEvent).epochs = sOutMat.F.events(iEvent).epochs(iKeepEvents);
            sOutMat.F.events(iEvent).samples = sOutMat.F.events(iEvent).samples(:,iKeepEvents);
            sOutMat.F.events(iEvent).times = sOutMat.F.events(iEvent).times(:,iKeepEvents);
            if ~isempty(sOutMat.F.events(iEvent).reactTimes)
                sOutMat.F.events(iEvent).reactTimes = sOutMat.F.events(iEvent).reactTimes(:,iKeepEvents);
            end
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
    sFileOut = out_fwrite(sFileOut, ChannelMatOut, 1, SamplesBounds - 1, [], sInput.A);
end

function [SampleTargets, SegmentNames, BadSegments] = GetSamplesFromEvent(sEvent, badSegmentPrefix)
    if nargin < 2 || isempty(badSegmentPrefix)
        badSegmentPrefix = 'bad_';
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
    % Convert continuous events to periodic events
    if dimSamples == 2
        samples = sEvent.samples(:,indices);
        times   = round(sEvent.times(:,indices));
        current = samples(1:2,1);
        SegmentNames = {};
        BadSegments = [];
        iGood = 1;
        % First segment is bad if events doesn't start at 0
        if current(1) > 0
            SegmentNames{end + 1} = [badSegmentPrefix '1_' GetTimeSuffix([0, times(1,1)])];
            BadSegments(end + 1) = 1;
            skipFirst = 0;
        else
            skipFirst = 1;
        end
        for iSample = 1:numSamples
            if samples(1,iSample) <= current(2)
                % Contains previous event, skip
                current(2) = max(samples(2,iSample), current(2));
            else
                % Separate from previous event, save boundaries
                SampleTargets(end + 1:end + 2) = current(:);
                SegmentNames{end + 1} = [sEvent.label '_' num2str(iGood) '_' GetTimeSuffix(times(:,iSample-1))];
                SegmentNames{end + 1} = [badSegmentPrefix num2str(iGood) '-' num2str(iGood + 1) '_' GetTimeSuffix([times(2,iSample-1), times(2,iSample)])];
                BadSegments(end + 1:end + 2) = [0, 1];
                iGood = iGood + 1;
                current = samples(1:2,iSample);
            end
        end
        % Save last event
        SampleTargets(end + 1:end + 2) = current(:);
        SegmentNames{end + 1} = [sEvent.label '_' num2str(iGood) '_' GetTimeSuffix(times(:,numSamples))];
        SegmentNames{end + 1} = [badSegmentPrefix num2str(iGood) '_' GetTimeSuffix({times(2,numSamples), 'end'})];
        BadSegments(end + 1:end + 2) = [0, 1];
        % Remove zero if included in first segment
        if skipFirst
            SampleTargets = SampleTargets(2:end);
        end
    else
        SampleTargets = samples;
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