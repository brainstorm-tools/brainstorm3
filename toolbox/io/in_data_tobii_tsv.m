function [DataMat, ChannelMat] = in_data_tobii_tsv(DataFile, isInteractive, sfreq)
% IN_DATA_TOBII_TSV: Imports a Tobii Pro Glasses export TSV file.
%    
% USAGE: [DataMat, ChannelMat] = in_data_tobii_tsv(DataFile, isInteractive=0, sfreq=[ask]);

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
% Authors: Francois Tadel, 2021


% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(sfreq)
    sfreq = [];
end
if (nargin < 2) || isempty(isInteractive)
    isInteractive = 0;
end
if ~exist('readtable', 'file')
    error('Reading Tobii files is available only with Matlab >= 2013b.');
end


%% ===== READ TSV =====
bst_progress('text', 'Reading tsv file...');
% File structure: {'Column name', 'Data format', 'Channel type'}
ColDesc = {...
    'Recording timestamp',     '%d', []; ...
    'Participant name',        '%s', []; ...
    'Recording name',          '%s', []; ...
    'Recording date',          '%s', []; ...
    'Recording start time',    '%s', []; ...
    'Event',                   '%s', []; ...
    'Gaze point X',            '%f', 'GAZE'; ... 
    'Gaze point Y',            '%f', 'GAZE'; ... 
    'Gaze point 3D X',         '%f', 'GAZE'; ... 
    'Gaze point 3D Y',         '%f', 'GAZE'; ... 
    'Gaze point 3D Z',         '%f', 'GAZE'; ... 
    'Gaze direction left X',   '%f', 'GDIR'; ... 
    'Gaze direction left Y',   '%f', 'GDIR'; ... 
    'Gaze direction left Z',   '%f', 'GDIR'; ... 
    'Gaze direction right X',  '%f', 'GDIR'; ... 
    'Gaze direction right Y',  '%f', 'GDIR'; ... 
    'Gaze direction right Z',  '%f', 'GDIR'; ... 
    'Pupil position left X',   '%f', 'PUPIL'; ... 
    'Pupil position left Y',   '%f', 'PUPIL'; ... 
    'Pupil position left Z',   '%f', 'PUPIL'; ... 
    'Pupil position right X',  '%f', 'PUPIL'; ... 
    'Pupil position right Y',  '%f', 'PUPIL'; ... 
    'Pupil position right Z',  '%f', 'PUPIL'; ... 
    'Pupil diameter left',     '%f', 'PUPIL'; ... 
    'Pupil diameter right',    '%f', 'PUPIL'; ... 
    'Validity left',           '%s', []; ... 
    'Validity right',          '%s', []; ... 
    'Eye movement type',       '%s', []; ... 
    'Gaze event duration',     '%d', []; ... 
    'Fixation point X',        '%d', []; ... 
    'Fixation point Y',        '%d', []; ... 
    'Gyro X',                  '%f', 'HEAD'; ... 
    'Gyro Y',                  '%f', 'HEAD'; ... 
    'Gyro Z',                  '%f', 'HEAD'; ... 
    'Accelerometer X',         '%f', 'HEAD'; ... 
    'Accelerometer Y',         '%f', 'HEAD'; ...  
    'Accelerometer Z',         '%f', 'HEAD'};
% Open file
Tsv = in_tsv(DataFile, ColDesc(:,1:2)', 1, [], 1);
% Error reading file
if isempty(Tsv)
    error('Invalid TSV file.');
end


%% ===== REMOVE BAD TIME POINTS =====
bst_progress('text', 'Removing bad time points...');
% Find timestamp column
iColTime = find(strcmpi(ColDesc(:,1), 'Recording timestamp'));
if isempty(iColTime)
    error('Timestamp column not found in TSV.');
end
% Remove entries with empty timestamps
iEmpty = find(isnan([Tsv{:,iColTime}]));
if (length(iEmpty) == size(Tsv,1))
    error('Timestamp column is empty or invalid.');
elseif ~isempty(iEmpty)
    Tsv(iEmpty,:) = [];
end
% Find validity columns
iValidL = find(strcmpi(ColDesc(:,1), 'Validity left'));
iValidR = find(strcmpi(ColDesc(:,1), 'Validity right'));
if ~isempty(iValidL) && ~isempty(iValidR)
    iInvalid = find(strcmpi(Tsv(:,iValidL), 'Invalid') & strcmpi(Tsv(:,iValidR), 'Invalid'));
    if ~isempty(iInvalid)
        Tsv(iInvalid,:) = [];
    end
end


%% ===== CHANNEL FILE =====
bst_progress('text', 'Creating channel file...');
% Create empty channel structures
ChannelMat = db_template('channelmat');
% Create one channel for each valid data column that should be considered as signals
iDataCol = [];
iDataChan = [];
for iCol = 1:size(ColDesc,1)
    % If no channel type or no valid values: skip column
    if isempty(ColDesc{iCol,3}) || all(cellfun(@(c)or(isnan(c), isempty(c)), Tsv(:,iCol)))
        continue;
    end
    % Create channel
    iChan = length(ChannelMat.Channel) + 1;
    ChannelMat.Channel(iChan).Type = ColDesc{iCol,3};
    ChannelMat.Channel(iChan).Name = ColDesc{iCol,1};
    ChannelMat.Channel(iChan).Loc     = [];
    ChannelMat.Channel(iChan).Orient  = [];
    ChannelMat.Channel(iChan).Comment = '';
    ChannelMat.Channel(iChan).Weight  = 1;
    % Save indices
    iDataCol(end+1) = iCol;
    iDataChan(end+1) = iChan;
end


%% ===== LOOP BY SESSION =====
bst_progress('text', 'Identifying sessions...');
% One .tsv file can contain multiple recording sessions, that must be handled separately.
% Unicity of session is defined by columns: {'Participant name', 'Recording name', 'Recording date', 'Recording start time'}
iColSub = find(strcmpi(ColDesc(:,1), 'Participant name'));
iColRec = find(strcmpi(ColDesc(:,1), 'Recording name'));
iColDate = find(strcmpi(ColDesc(:,1), 'Recording date'));
iColStart = find(strcmpi(ColDesc(:,1), 'Recording start time'));
% Session ID: concatenation of everything
sesId = cellfun(@(c1,c2,c3,c4)horzcat(c1,c2,c3,c4), Tsv(:,iColSub), Tsv(:,iColRec), Tsv(:,iColDate), Tsv(:,iColStart), 'UniformOutput', 0);
uniqueSesId = unique(sesId);


%% ===== LOOP BY SESSION =====
% Create empty structures
DataMat = repmat(db_template('DataMat'), 0);
iFile = 0;
% Create one data structure per session ID
for iSes = 1:length(uniqueSesId)
    bst_progress('text', sprintf('Processing session: %d / %d...', iSes, length(uniqueSesId)));
    % Table with all information for the session
    sesTsv = Tsv(cellfun(@(c)isequal(c,uniqueSesId{iSes}), sesId), :);
    % Loop on channels: extract raw signals
    ColData = cell(1, length(iDataCol));
    ColDiff = zeros(1, length(iDataCol));
    ColBlockStart = cell(1, length(iDataCol));
    ColBlockStop = cell(1, length(iDataCol));
    for i = 1:length(iDataCol)
        % Find valid time points
        iRows = find(~cellfun(@(c)or(isnan(c), isempty(c)), sesTsv(:,iDataCol(i))));
        % Get valid timestamps and data for selected column
        ColData{i} = cat(2, cat(1, sesTsv{iRows,iColTime}), cat(1, sesTsv{iRows,iDataCol(i)}));
        % Get time increment
        timestmp = ColData{i}(:,1);
        timeDiff = diff(timestmp);
        % Delete duplicated time points
        iDup = find(timeDiff == 0);
        if ~isempty(iDup)
            disp(sprintf('TOBII> Warning: %d duplicated time points for column "%s"', length(iDup), ColDesc{iDataCol(1),1}));
            ColData{i}(iDup+1,:) = [];
            timeDiff = diff(ColData{i}(:,1));
        end
        % Guess sampling frequency: Most frequent time increment
        ColDiff(i) = mode(timeDiff);
        % Detect jumps in the time vector (100 skipped samples): possible pauses in the data
        ColBlockStart{i} = [min(timestmp), timestmp(find(timeDiff > 100 * ColDiff(i)) + 1)];
        ColBlockStop{i} = [timestmp(timeDiff > 100 * ColDiff(i)), max(timestmp)];
    end
    % Align all the channels to the minimum period between two samples
    T = double(min(ColDiff));
    % Detect milliseconds or microseconds
    if (T > 1000)
        tFactor = 1e-6;  % Timestamps in microsec
    else
        tFactor = 1e-3;  % Timestamps in millisec
    end
    T = T .* tFactor;

    % Get the minimum number of time blocks observed on all the columns
    nBlocks = min(cellfun(@length, ColBlockStart));
    % Loop on each block
    for iBlock = 1:nBlocks
        % Get time stamps corresponding to this block
        blockBounds = [min(cellfun(@(c)c(iBlock), ColBlockStart)), max(cellfun(@(c)c(iBlock), ColBlockStop))];
        timeBounds = double(blockBounds) .* tFactor;
        % Get final time vector for all columns
        Time = timeBounds(1):T:timeBounds(2);
        F = zeros(length(iDataCol), length(Time));
    
        % ===== INTERPOLATE DATA =====
        for i = 1:length(iDataCol)
            timestmp = ColData{i}(:,1);
            iTime = find((timestmp >= blockBounds(1)) & (timestmp <= blockBounds(2)));
            F(i,:) = interp1(double(ColData{i}(iTime,1)) .* tFactor, double(ColData{i}(iTime,2)), Time, 'previous', 0);
        end
    
        % ===== BRAINSTORM DATA STRUCTURE =====
        % Get file name
        [fPath, fBase, fExt] = bst_fileparts(DataFile);
        % File comment (depends if there are multiple sessions)
        if (length(uniqueSesId) > 1)
            if ~isempty(sesTsv{iRows(1),iColSub}) && ~isempty(sesTsv{iRows(1),iColRec})
                Comment = [sesTsv{iRows(1),iColSub}, '-', sesTsv{iRows(1),iColRec}];
            else
                Comment = [fBase, sprintf('-ses%02d', iSes)];
            end
        else
            Comment = fBase;
        end
        % If there are multiple blocks: add the block number
        if (nBlocks > 1)
            Comment = [Comment, sprintf('-block%02d', iBlock)];
        end
        % Initialize data structure
        iFile = iFile + 1;
        DataMat(iFile) = db_template('DataMat');
        % Fill structure
        DataMat(iFile).F           = F;
        DataMat(iFile).Time        = Time;
        DataMat(iFile).Comment     = Comment;
        DataMat(iFile).ChannelFlag = ones(size(F, 1), 1);
        DataMat(iFile).nAvg        = 1;
        DataMat(iFile).Device      = 'Tobii';
    
        % ===== PROCESS EVENTS =====
        % Find columns
        iColEvt = find(strcmpi(ColDesc(:,1), 'Eye movement type'));
        iColFixX = find(strcmpi(ColDesc(:,1), 'Fixation point X'));
        iColFixY = find(strcmpi(ColDesc(:,1), 'Fixation point Y'));
        % Find time points with event info
        iRows = find(~cellfun(@isempty, sesTsv(:,iColEvt)));
        % Get changes of event
        t = double([sesTsv{iRows,iColTime}]) .* tFactor;
        val = cellfun(@sum, sesTsv(iRows,iColEvt))';
        iNew = find([1, diff(val)]);
        tNew = [t(iNew), t(end)+T];
        % If there are different types of events: process events
        if (length(iNew) > 2)
            % Initialize events list
            uniqueVal = unique(val(iNew));
            DataMat(iFile).Events = repmat(db_template('event'), 1, length(uniqueVal));
            % Process each event type
            sfreq = 1 ./ T;
            for iEvt = 1:length(uniqueVal)
                % Find all the occurrences of this event
                iOcc = find(uniqueVal(iEvt) == val(iNew));
                % Set event
                iFirstOcc = iRows(find(val == uniqueVal(iEvt), 1));
                DataMat(iFile).Events(iEvt).label    = strtrim(sesTsv{iFirstOcc, iColEvt});
                % DataMat(iFile).Events(iEvt).times    = round(tNew(iOcc) .* sfreq) ./ sfreq;
                DataMat(iFile).Events(iEvt).times    = round([tNew(iOcc) ; tNew(iOcc+1)-T] .* sfreq) ./ sfreq;   % Extended events
                DataMat(iFile).Events(iEvt).epochs   = ones(1, length(iOcc));
                DataMat(iFile).Events(iEvt).select   = 1;
                DataMat(iFile).Events(iEvt).channels = [];
                % Fixation event: Save fixation point
                if (uniqueVal(iEvt) == sum('Fixation'))
                    DataMat(iFile).Events(iEvt).notes = cellfun(@(c1,c2)sprintf('%dx%d', c1, c2), sesTsv(iRows(iNew(iOcc)), iColFixX), sesTsv(iRows(iNew(iOcc)), iColFixY), 'UniformOutput', 0)';
                else
                    DataMat(iFile).Events(iEvt).notes = [];
                end
            end
        end
    end
end


