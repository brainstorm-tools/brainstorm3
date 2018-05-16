function varargout = process_evt_detect_movement( varargin )
%

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
% Authors: Elizabeth Bock, Francois Tadel, 2013-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect movement [Experimental]';
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/MovementDetect';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Events';
    sProcess.Index       = 70;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    sProcess.options.warning.Comment = 'Only for CTF MEG recordings with HLC channels recorded.<BR><BR>';
    sProcess.options.warning.Type    = 'label';
    % === Channel names
    %Na = HLC0011,12,13 (meters) fit error = HLC0018
    %Le = HLC0021,22,23 (meters) fit error = HLC0028
    %Re = HLC0031,32,33 (meters) fit error = HLC0038                               
    % === Movement Threshold 
    sProcess.options.thresh.Comment = 'Movement threshold: ';
    sProcess.options.thresh.Type    = 'value';
    sProcess.options.thresh.Value   = {5, 'mm', []};
    % === Movement Threshold 
    sProcess.options.allowance.Comment = 'Threshold allowance: ';
    sProcess.options.allowance.Type    = 'value';
    sProcess.options.allowance.Value   = {5, '%', []};
    % === Fit Error Tolerance 
    sProcess.options.fiterror.Comment = 'Fit error tolerance: ';
    sProcess.options.fiterror.Type    = 'value';
    sProcess.options.fiterror.Value   = {3, '%', []};
    % === Minimum movement segment length
    sProcess.options.minSegLength.Comment  = 'Minimum split length: ';
    sProcess.options.minSegLength.Type     = 'value';
    sProcess.options.minSegLength.Value    = {5, 's', []};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function [OutputFiles] = Run(sProcess, sInputs) %#ok<DEFNU>
OutputFiles = {};
% ===== GET OPTIONS =====
moveThresh      = sProcess.options.thresh.Value{1}/10; % mm->cm
threshAllowance = sProcess.options.allowance.Value{1}/100; % percent to decimal
threshUP        = moveThresh * 1+threshAllowance; % 10% above
threshDOWN      = moveThresh * 1-threshAllowance; % 10% below
fitErrorThresh  = sProcess.options.fiterror.Value{1} / 100;
minSplitLength  = sProcess.options.minSegLength.Value{1}; % seconds

iNa = 1:3;
iLe = 4:6;
iRe = 7:9;
iFitError = 10:12;
chanName = 'HLC';

% Get current progressbar position
progressPos = bst_progress('get');

% Loop on all input files
for iFile = 1:length(sInputs)
    sInput = sInputs(iFile);
    % ===== GET CHANNEL FILE =====
    % Progress bar
    bst_progress('text', 'Reading file...');
    % Load channel file
    ChannelMat = in_bst_channel(sInput.ChannelFile);
    % Only available for CTF
    if isempty(strfind(ChannelMat.Comment, 'CTF'))
        bst_report('Error', sProcess, sInputs(iFile), 'The process is currently available for CTF format files only.'); 
        continue;
    end
    % Get channels to process
    iChannel = find(~cellfun(@isempty,regexp({ChannelMat.Channel.Name}, chanName)));    
    if isempty(iChannel)
        bst_report('Error', sProcess, sInputs(iFile), 'HLC channels not found in this file.');
        continue;
    end
    % ===== LOAD FILE =====
    % Get data matrix
    DataMat = in_bst_data(sInputs(iFile).FileName);
    % Copy channel flag information
    if isfield(DataMat, 'ChannelFlag')
        sInput.ChannelFlag = DataMat.ChannelFlag;
    end
    % Copy nAvg information
    if isfield(DataMat, 'nAvg') && ~isempty(DataMat.nAvg)
        sInput.nAvg = DataMat.nAvg;
    else
        sInput.nAvg = 1;
    end
    % Set time vector in input
    sInput.TimeVector = DataMat.Time;
    sFile = DataMat.F;
    % Process only continuous files
    if ~isempty(sFile.epochs)
        bst_report('Error', sProcess, sInput, 'This function can only process continuous recordings (no epochs).');
        continue;
    end
    
    [FilePath,FileName] = fileparts(sFile.filename);
    % ===== BAD SEGMENTS =====
    % If ignore bad segments
    Fmask = [];
    isIgnoreBad = 1;
    if isIgnoreBad
        % Get list of bad segments in file
        badSeg = panel_record('GetBadSegments', sFile);
        % Adjust with beginning of file
        badSeg = badSeg - sFile.prop.samples(1) + 1;
        % Create file mask
        Fmask = true(1, sFile.prop.samples(2) - sFile.prop.samples(1) + 1);
        if ~isempty(badSeg)            
            % Loop on each segment: mark as bad
            for iSeg = 1:size(badSeg, 2)
                Fmask(badSeg(1,iSeg):badSeg(2,iSeg)) = false;
            end
        end
    end
    
    % ===== Fit Error =====
    % identify fit error values greater than threshold
    fitError = ones(1, sFile.prop.samples(2) - sFile.prop.samples(1) + 1);
    maxError = zeros(1, sFile.prop.samples(2) - sFile.prop.samples(1) + 1);
    
    %% ===== FIND SEGMENTS OF HEAD MOVEMENT =====
    SamplesBounds = sFile.prop.samples;
    minSplitSamps = floor(sFile.prop.sfreq*minSplitLength); % short vs long events 
    checkWinMin = max(30,minSplitLength*2);
    checkWinLen = floor(sFile.prop.sfreq*checkWinMin); % length of window for checking
    minShortSamps = 0.06*sFile.prop.sfreq; % min time to consider a move event (2*30ms samp rate)
    
    bst_progress('text', 'Finding Head Movement...');
    
    % Get original HLC postion measurement from .hc file
    HCfile=fullfile(FilePath,[FileName '.hc']);
    if exist(HCfile,'file') == 2
        Loc = parseHCFile(fullfile(FilePath,[FileName '.hc'])); % in meters
    else
        % Only available for raw .ds CTF files
        bst_report('Error', sProcess, sInputs(iFile), 'The process is currently available for raw .ds CTF format files only.'); 
        continue;
%         % Use the first measurement from the HLC channels
%         [F, TimeVector] = in_fread(sFile, ChannelMat, 1, [0 1], iChannel(1:12));
%         Loc = reshape(F(:,1),[3,4])';
    end
    
    nLongEvents = 0;
    nShortEvents = 0;
    longStart = [];
    shortStart = [];
    shortStop = [];
    fileOffset = 0;
    sampleIndex = max(1,SamplesBounds(1));
    totalWindows = ceil((SamplesBounds(2)-SamplesBounds(1)) / checkWinLen);
    
    % Only load 1Gb into memory: (12 HLU and 1 Time channel)
    % 1Gb = 13chan * samprate * seconds * 8bytes => seconds = 1Gb / (104 * samprate)
    GbSamples = (floor( 1e9 / (104*sFile.prop.sfreq) ) * sFile.prop.sfreq);
    LoadSamples = [SamplesBounds(1) min(SamplesBounds(2),GbSamples)];
    [ChanData, TimeVector] = in_fread(sFile, ChannelMat, 1, LoadSamples, iChannel(1:12));
    nWindows = 0;
    % Loop through recording using short windows
    while sampleIndex < SamplesBounds(2)
        nWindows = nWindows+1;
        bst_progress('set', min(progressPos + round(nWindows/totalWindows * 100),100));
        
        % load the window of interest
        endCheck = min(sampleIndex+checkWinLen-1, SamplesBounds(2));
        if endCheck > LoadSamples(2)
            % load more samples
            fileOffset = sampleIndex-1;
            LoadSamples = [fileOffset+1 min(SamplesBounds(2),fileOffset+1+GbSamples)];
            [ChanData, TimeVector] = in_fread(sFile, ChannelMat, 1, LoadSamples, iChannel(1:12));
        end
        startCheck = sampleIndex - fileOffset;
        win = [startCheck endCheck - fileOffset];
        F = ChanData(:,win(1):win(2));
        
        % reset variables
        currentWindowLength = length(win(1):win(2));
        iThresh = zeros(1,currentWindowLength);
        glbChange = zeros(1,currentWindowLength);
        fitMask = ones(1,currentWindowLength);
        
        % find head movement
        Na1 = sqrt(sum((F(iNa,:) - repmat(Loc(1,:)',1,length(F))) .^2))*100;
        Le1 = sqrt(sum((F(iLe,:) - repmat(Loc(2,:)',1,length(F))) .^2))*100;
        Re1 = sqrt(sum((F(iRe,:) - repmat(Loc(3,:)',1,length(F))) .^2))*100;
        [mChange1, iCoil1] = max([Na1;Le1;Re1]);
        
        nextChange = find(mChange1);
        if ~isempty(nextChange)
            if nextChange(1) > 1
                sampleIndex = sampleIndex + nextChange(1) - 1;
                continue
            end
        end
        
        iThresh1 = mChange1 < threshDOWN;
        iThresh2 = mChange1 > threshUP;
        
        diffiThresh1 = diff(iThresh1);
        diffiThresh1(diffiThresh1 < 0) = 0;
        diffiThresh2 = diff(iThresh2);
        diffiThresh2(diffiThresh2 < 0) = 0;
        crossIndUP = find(diffiThresh2);
        crossIndDOWN = find(diffiThresh1);
        if isempty(crossIndUP)
            iThresh = iThresh2;
        else
            for iCross = 1:length(crossIndUP)
                endInd = find(crossIndDOWN > crossIndUP(iCross));
                if ~isempty(endInd)
                    iThresh2(crossIndUP(iCross):crossIndDOWN(endInd(1))) = 1;
                else
                    iThresh2(crossIndUP(iCross):end) = 1;
                end
            end
            iThresh = iThresh2;
        end
            glbChange = mChange1;

        
        if isIgnoreBad
            iThresh = iThresh & Fmask(win(1):win(2));
        end
        
        
        % Check fit error
        maxError(win(1):win(2)) = max(F(iFitError,:),[],1);
        fitMask(maxError(win(1):win(2))>fitErrorThresh) = 0;
        fitError(win(1):win(2)) = fitMask;

        % check for first segment above thresh (subject moved between the
        % head localization and start of recording)
        if sampleIndex==1 && iThresh(1)
            ind = 1;
            Loc(1,:) = F(iNa,ind);
            Loc(2,:) = F(iLe,ind);
            Loc(3,:) = F(iRe,ind);

            nLongEvents = nLongEvents + 1;
            longStart(nLongEvents) = ind;
            longChange(nLongEvents) = glbChange(ind);
            longLoc(nLongEvents,:,:) = Loc;
            disp(['event at ' num2str(longStart(nLongEvents)) ' movement of ' num2str(glbChange(1)) ' cm'])
            sampleIndex = 2;
            
        else
            disp(['window starts at ' num2str(round(sampleIndex/sFile.prop.sfreq)) ' sec']);
            stMove = [];
            enMove = [];
            
            % find transitions
            iAbove = find(diff([0 iThresh]) == 1);
            if sampleIndex + checkWinLen > SamplesBounds(2)
                % this is at the end of the file
                iBelow = find(diff([0 iThresh 0]) == -1) - 1;
            else
                iBelow = find(diff([0 iThresh]) == -1);
            end


            if isempty(iAbove)
               sampleIndex = sampleIndex + checkWinLen;
               continue;
            end
            
            % Get the start/end of the movement
            stMove = iAbove;
            enMove = iBelow;
            
            startNewSearch = 0;
            for jj = 1:length(stMove)
                en = find(enMove > stMove(jj), 1,'first');
                if ~isempty(en)
                    moveLength = enMove(en) - stMove(jj);
                    % check for movement events that are short
                    if moveLength < minSplitSamps  && moveLength > minShortSamps
                        nShortEvents = nShortEvents + 1;
                        shortStart(nShortEvents) = sampleIndex + stMove(jj)-1;
                        shortStop(nShortEvents) = sampleIndex + enMove(jj)-1;
                        disp(['short event at ' num2str(shortStart(nShortEvents)) ' movement of ' num2str(glbChange(stMove(jj))) ' cm'])
                        
                    % check for movement events that are long and record the 
                    % time and headposition for splitting the data
                    elseif moveLength > minSplitSamps
                        % sampleIndex is the beginning of this section
                        % st(jj) is relative to the beginning of the section
                        ind = sampleIndex + stMove(jj)-1; % this index is relative to the beginning of the file

                        Loc(1,:) = F(iNa,stMove(jj));
                        Loc(2,:) = F(iLe,stMove(jj));
                        Loc(3,:) = F(iRe,stMove(jj));

                        nLongEvents = nLongEvents + 1;
                        longStart(nLongEvents) = ind;
                        longChange(nLongEvents) = glbChange(stMove(jj));
                        longLoc(nLongEvents,:,:) = Loc;
                        disp(['event at ' num2str(longStart(nLongEvents)) ' movement of ' num2str(glbChange(stMove(jj))) ' cm'])
                        sampleIndex = ind;
                        startNewSearch = 1;
                        break;
                    end
                else
                    moveLength = length(stMove(jj):currentWindowLength);
                    if moveLength > minSplitSamps
                        % sampleIndex is the beginning of this section
                        % st(jj) is relative to the beginning of the section
                        ind = sampleIndex + stMove(jj)-1; % this index is relative to the beginning of the file

                        Loc(1,:) = F(iNa,stMove(jj));
                        Loc(2,:) = F(iLe,stMove(jj));
                        Loc(3,:) = F(iRe,stMove(jj));

                        nLongEvents = nLongEvents + 1;
                        longStart(nLongEvents) = ind;
                        longChange(nLongEvents) = glbChange(stMove(jj));
                        longLoc(nLongEvents,:,:) = Loc;
                        disp(['long event at ' num2str(longStart(nLongEvents)) ' movement of ' num2str(glbChange(stMove(jj))) ' cm'])
                        sampleIndex = ind;
                        startNewSearch = 1;
                    else
                        sampleIndex = sampleIndex + stMove(jj);
                        startNewSearch = 1;
                    end
                    break;
                end
            end
            % if only short movements or no movements were found, start the
            % next check in the next segment
            if ~startNewSearch
               sampleIndex = sampleIndex + checkWinLen;
            end
        end
    end
    
    %% ===== Check and save events =====
    bst_progress('text', 'Saving events...');
    % check for long events that should be short (this can happen when the
    % subject moves over 2 x threshold during the min split time)
    indShortSeg = find(diff(longStart)<minSplitSamps);
    if ~isempty(indShortSeg)
        % add short events
        for ii = 1:length(indShortSeg)
            nShortEvents = nShortEvents + 1;
            shortStart(nShortEvents) = longStart(indShortSeg(ii));
            shortStop(nShortEvents) = longStart(indShortSeg(ii)+1)-1;
        end
        % remove these short events from the list
        nLongEvents = nLongEvents - length(indShortSeg);
        longStart(indShortSeg) = [];
        longChange(indShortSeg) = [];
        longLoc(indShortSeg,:,:) = [];
    end
    
    % find fit error events
    if isIgnoreBad
        fitError=Fmask & fitError;
    end
    dFitError = diff([1 fitError]);
    stError = find(dFitError == -1);
    dFitError = diff([fitError 1]);
    enError = find(dFitError == 1)-1;
    % keep only those errors that are > minShortSamps
    errorSamps = [stError;enError];
    errorSamps(:,abs(diff(errorSamps)) < minShortSamps) = [];
      
    % save time events for long segments of movement
    sEvent = DataMat.F.events;
    
    if ~isempty(longStart)
        fid = fopen(fullfile(FilePath,'headpositions.txt'), 'w');
        % write long events to a text file
        for ii = 1:nLongEvents
            fprintf(fid, '%d\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\n', longStart(ii), longChange(ii), longLoc(ii,1,:), longLoc(ii,2,:), longLoc(ii,3,:));
        end
        fclose(fid);
        n = length(sEvent);
        sEvent(n+1).label = 'longStart';
        sEvent(n+1).color = [0 1 0];
        sEvent(n+1).epochs = ones(1,nLongEvents);
        sEvent(n+1).samples = longStart;
        sEvent(n+1).times = longStart ./ sFile.prop.sfreq;
    end

    if ~isempty(shortStart)
        n = length(sEvent);       
        samps = [shortStart;shortStop];
        sEvent(n+1).label = 'move_BAD';
        sEvent(n+1).color = [1 0 0];
        sEvent(n+1).epochs = ones(1,nShortEvents);
        sEvent(n+1).samples = samps;
        sEvent(n+1).times = samps ./ sFile.prop.sfreq;
    end
    
    if ~isempty(stError)
        n = length(sEvent);       
        samps = errorSamps;
        sEvent(n+1).label = 'move_fit_BAD';
        sEvent(n+1).color = [1 0 0];
        sEvent(n+1).epochs = ones(1,size(samps,2));
        sEvent(n+1).samples = samps;
        sEvent(n+1).times = samps ./ sFile.prop.sfreq;
    end
    
    DataMat.F.events = sEvent;
    
    % ===== SAVE FILE =====
    % Save new file
    save(file_fullpath(sInputs(iFile).FileName), '-struct', 'DataMat');
    disp('done');
end
    % Close progress bar
    bst_progress('stop');
    
    % Reload all the studies
    db_reload_studies(unique([sInputs.iStudy]));
end

%% Get HLC original locations from .hc file
function OrigLocations = parseHCFile(filename)
nPositions = 0;
fid=fopen(filename);
locations = zeros(9,3);
while 1
    tline = fgetl(fid);
    if ~ischar(tline), break, end
    if strfind(tline, 'coil')
        nPositions = nPositions + 1;
        % get the coil coordinates
        for ii = 1:3
            tline = fgetl(fid);
            splstr = regexp(tline, ' ', 'split');
            locations(nPositions,ii) = str2num(splstr{end});
        end
    end
end
fclose(fid);
% measured coil positions relative to the dewar
OrigLocations = locations(4:6,:) ./100; % meters
end

