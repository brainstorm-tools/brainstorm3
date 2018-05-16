function realtime_moviefilter()
% REALTIME_MOVIEFILTER: collects data from the acquisition and updates a file with a display index

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
% Authors: Elizabeth Bock, 2014


%% Configure
global RTConfig
RTConfig = panel_realtime('GetTemplate');
isSendMarkers = 0;          % Send markers to ACQQ
PPTaddress = '2000';        % parallel port address
RTConfig.nBlockSmooth = 5;  % smoothing (number of buffer chunks)
RTConfig.RefLength = 30;    % length of reference period (seconds)
RTConfig.fdbkTrialTime = 300;% time of each feedback trial (seconds)
RTConfig.restTrialTime = 120;% time of each rest trial (seconds)
RTConfig.nTrials = 4;      % number of feedback trials
RTConfig.scoutName = {'Lmotor';'Rmotor'};    % name(s) of source map scout for processing data

%% Initialize the low_latency parallel port driver
if isSendMarkers
    ioObj = io64;                           % Create a parallel port handle
    status = io64(ioObj);                   % If this returns '0' the port driver is loaded & ready
    if status
        warning('I/O drivers for the parallel port were not started correctly');
    end

    % Init PPT
    io64(ioObj,PPTaddress,0);                     % Write 0 in parallel port
    RefStart        = 1;
    FeedbackStart   = 2;
end

%% Initialize measurement parameters
DataTransfer = 1;
ReComputeHeadModel = 1; 

panel_realtime('InitializeRealtimeMeasurement',ReComputeHeadModel);
procTiming = zeros(1,RTConfig.nRefBlocks); % keep track of process timing
count = 0; % count number of buffers processed
measure = zeros(RTConfig.nRefBlocks,1); % keep measurement for ref period 

% initialize display index (-200) in feedback measurement file
user_dir = bst_get('UserDir');
fid=fopen(fullfile(user_dir, 'feedback_displayindex.txt'),'w');
fprintf(fid,'%d\n',-200);
fclose(fid);

%% Reference period
if RTConfig.nRefBlocks > 0
    DisplayMode = 0;
    disp('FEEDBACK> Reference period started');
    if isSendMarkers
        % Send a pulse to LPT2 as stim --> Start
        io64(ioObj,PPTaddress,RefStart);
        WaitSecs(3/RTConfig.SampRate);
        io64(ioObj,LPT2,0);
    end
    for refBlock = 1:RTConfig.nRefBlocks
        tic
        % Get new data
        dat = panel_realtime('GetNextDataBuffer');
        if isempty(dat)
            % data transfer has stopped
            DataTransfer = 0;
            break;
        end
        % update the count (number of buffers collected)
        count = count+1;
        % Extract the measure from the data and update the display
        measure(count,:) = MovieWithFilterDisplay(dat, DisplayMode);
        procTiming(count) = toc; % keep track of process timing during ref
    end

    % ===== Compute stats
    RTConfig.refMean = mean(measure(1:count,:),1);
    RTConfig.refStd = std(measure(1:count,:),1);
    procTimingMean = mean(procTiming(2:end));
    % If the processing time is over 10 mSec more than data
    % recording time, we increase the block size to 1.3 times its
    % former size
    if abs(mean(procTiming(3:end)-RTConfig.BlockSamples/RTConfig.SampRate)) > .010
        MinSize = fix(1.3*(procTimingMean*RTConfig.SampRate)/RTConfig.ChunkSamples);
        RTConfig.nChunks = max(MinSize,RTConfig.nChunks);
        RTConfig.BlockSamples = RTConfig.nChunks*RTConfig.ChunkSamples;
    end
    disp('FEEDBACK> Reference period ended');
    disp(['FEEDBACK>Display will refresh every ',num2str(RTConfig.BlockSamples/RTConfig.SampRate),' Sec'])

        
        
end
%% Feedback trials
for trial = 1:RTConfig.nTrials
    % ===== feedback 
    DisplayMode = 1;
    disp(['FEEDBACK> Feedback trial ' num2str(trial)]);
    if isSendMarkers
        io64(ioObj,PPTaddres,FeedbackStart);
        WaitSecs(3/RTConfig.SampRate);
        io64(ioObj,PPTaddress,0);
    end
    for fblock = 1:RTConfig.nFeedbackBlocks
        % Get new data
        dat = panel_realtime('GetNextDataBuffer');
        if isempty(dat)
            % data transfer has stopped
            DataTransfer = 0;
            break;
        end
        % update the count (number of buffers collected)
        count = count+1;
        % Extract the measure from the data and update the display
        MovieWithFilterDisplay(dat, DisplayMode);
    end
    
    % ===== Feedback performance stats
    measures = RTConfig.LastMeasures(end:-1:RTConfig.nBlockSmooth-1);
    t = (1:length(measures))*RTConfig.BlockSamples/RTConfig.SampRate;
    minMeasure = prctile(measures(RTConfig.nRefBlocks+1:end),10);      % 10th percentile of the measures
    maxMeasure = prctile(measures(RTConfig.nRefBlocks+1:end),90);      % 90th percentile of the measures
    disp('  ')
    disp(['*** Range for the value: [',num2str(minMeasure),', ', num2str(maxMeasure),'] ***']);
    disp('  ')
    m = conv(measures,.1*ones(20,1),'same');
    figure,plot(t, m),xlabel('time (sec)'),ylabel('measure'),
    title('Average progress of subject during the training')               
      
    
    % ===== Rest
    DisplayMode = 2;
    disp(['FEEDBACK> Rest trial ' num2str(trial)]);
    if isSendMarkers
        io64(ioObj,PPTaddres,RestStart);
        WaitSecs(3/RTConfig.SampRate);
        io64(ioObj,PPTaddress,0);
    end
    for rblock = 1:RTConfig.nRestBlocks
        % Get new data
        dat = panel_realtime('GetNextDataBuffer');
        if isempty(dat)
            % data transfer has stopped
            DataTransfer = 0;
            break;
        end
        MovieWithFilterDisplay(dat, DisplayMode);
    end

end

% Display an 'end' screen for the user
disp('FEEDBACK> End');
fid=fopen(fullfile(user_dir, 'feedback_displayindex.txt'),'w');
fprintf(fid,'%d\n',-300);
fclose(fid);
end


%% Movie with filter display
% MOVIEWITHFILTERDISPLAY: Display the cortical sources filtered in a freq band
% of interest
function measure = MovieWithFilterDisplay(dat, DisplayMode)
    global RTConfig
    smoothed_measure = 0;
    % In this case we show the sources directly
    Cmegdat = dat(RTConfig.iMEG,:);
    % Optimal number of fft samples is a power of 2
    NFFT = 2^nextpow2(RTConfig.BlockSamples);
    % Frequency bins onto which the FFT will be computed
    freqVec = RTConfig.SampRate/2*linspace(0,1,NFFT/2+1);
    % Compute the FFT of the data array
    Fdat = fft(Cmegdat,NFFT,2)/RTConfig.BlockSamples;
    % Find the frequency bins of the FFT that best match the frequency
    % limits of the frequency range of interest
    VecInd = bst_closest(RTConfig.FilterFreq, freqVec);  
    
    % Extract Sources
    sourceMap = sum( 2*abs ( RTConfig.ImagingKernel *...
        Fdat(:, VecInd(1):VecInd(2))),2)...
        /length(VecInd(1):VecInd(2));
    
    % Extract scout values
    measure = mean(sourceMap(RTConfig.ScoutVertices));

    % Normalize and smooth after reference period is complete
    if ~isempty(RTConfig.refMean) && ~isempty(RTConfig.refStd)
        measure = (measure - RTConfig.refMean') ./ RTConfig.refStd';
 
        % Smoothing using last sources
        if ~isempty(RTConfig.SmoothingFilter)
            Len = length(RTConfig.SmoothingFilter);
            if isempty(RTConfig.LastMeasures)
                RTConfig.LastMeasures = [measure';zeros(Len-1,1)+.4];              
            end
            % Update the last measures
            RTConfig.LastMeasures = [measure';RTConfig.LastMeasures];
            smoothed_measure = sum(repmat(RTConfig.SmoothingFilter, 1, length(measure)).*RTConfig.LastMeasures(1:Len),1)';
        end
    end
    
    user_dir = bst_get('UserDir');
    fid=fopen(fullfile(user_dir, 'feedback_displayindex.txt'),'w');
    if DisplayMode ~= 1
        fprintf(fid,'%d\n',-200);
    else
        fprintf(fid,'%d\n',smoothed_measure); 
    end
    fclose(fid);

end    % end of function