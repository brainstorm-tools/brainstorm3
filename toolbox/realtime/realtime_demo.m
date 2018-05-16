function realtime_demo()
% REALTIME_DEMO: collects data from the acquisition and displays the cortical sources in a figure

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
% RTConfig.fdbkTrialTime = [];% time of each feedback trial
% RTConfig.restTrialTime = [];% time of each rest trial
% RTConfig.nTrials = [];      % number of feedback trials
% RTConfig.scoutName = [];    % name of source map scout for processing data

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

% This is a continuous loop to catch when the acq has stopped and allow the
% user to start again without computing a new head model
while 1
    if DataTransfer == 0
        % Data transfer has stopped.  Ask the user to resume or quit the
        % realtime collection
        button = questdlg(['Data transfer has stopped. ' 10 ...
            'To continue, restart the data transfer from ACQ workstation and THEN press "Resume"'], ...
            'Data transfer stopped','Resume','Quit','Quit');
        if button(1)=='Q'
            break
        end
        % User wants to resume using the same headmodel
        ReComputeHeadModel = 0;
        % reset acquisition
        nBlockSmooth = RTConfig.nBlockSmooth;
        RefLength = RTConfig.RefLength;
        RTConfig = panel_realtime('GetTemplate');
        RTConfig.nBlockSmooth = nBlockSmooth;
        RTConfig.RefLength = RefLength;
    end

    panel_realtime('InitializeRealtimeMeasurement',ReComputeHeadModel);
    procTiming = zeros(1,RTConfig.nRefBlocks); % keep track of process timing
    count = 0; % count number of buffers processed
    measure = zeros(RTConfig.nRefBlocks, size(RTConfig.ImagingKernel,1)); % keep sources for ref period 
    RTConfig.refMean = [];
    RTConfig.refStd = [];
    %% Start Feedback loop
    if isSendMarkers
        % Send a pulse to LPT2 as stim --> Start
        io64(ioObj,PPTaddress,RefStart);
        WaitSecs(3/RTConfig.SampRate);
        io64(ioObj,LPT2,0);
    end
    
    while 1
        tic
        % If reference period has ended get the reference mean and std and
        % compute the mean processing time.
        if count == RTConfig.nRefBlocks
            % Get the mean and std over the first n seconds as a reference
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
            disp('Reference period ended, starting experiment')
            disp(['Display will refresh every ',num2str(RTConfig.BlockSamples/RTConfig.SampRate),' Sec'])
            
            % Send a pulse to PPT as stim --> Start Providing Feedback to
            if isSendMarkers
                io64(ioObj,PPTaddres,FeedbackStart);
                WaitSecs(3/RTConfig.SampRate);
                io64(ioObj,PPTaddress,0);
            end
            
        end
        
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
        if count <= RTConfig.nRefBlocks && count > 0
            measure(count,:) = CortexDisplayDemo(dat);
            procTiming(count) = toc; % keep track of process timing during ref
        else
            CortexDisplayDemo(dat);
        end
    end
end
end

%% Cortex display for demo
% CORTEXDISPLAYDEMO: Display the cortical sources filtered in a freq band
% of interest
function sourceMap = CortexDisplayDemo(dat)
    global RTConfig
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
    VecInd = bst_closest(RTConfig.FilterFreq, freqVec);         %[8 12]
    % Extract Sources
    sourceMap = sum( 2*abs ( RTConfig.ImagingKernel *...
        Fdat(:, VecInd(1):VecInd(2))),2)...
        /length(VecInd(1):VecInd(2));

    if ~isempty(RTConfig.refMean) && ~isempty(RTConfig.refStd)
        sourceMap = (sourceMap - RTConfig.refMean') ./ RTConfig.refStd';

        % Filtering using last sources
        if ~isempty(RTConfig.SmoothingFilter)
            if isempty(RTConfig.LastMeasures)
                RTConfig.LastMeasures = repmat(sourceMap', length(RTConfig.SmoothingFilter), 1);
            end
            % Update the last sources
            RTConfig.LastMeasures(2:end,:) = RTConfig.LastMeasures(1:end-1,:);
            RTConfig.LastMeasures(1,:) = sourceMap';
            sourceMap = sum(repmat(RTConfig.SmoothingFilter, 1, length(sourceMap)).*RTConfig.LastMeasures,1)';
        end

        % Display the Max
        disp(['Max: ',num2str(max(abs(sourceMap(:))))]);    

        % Apply threshold for display
        sourceMap(abs(sourceMap)<.15) = 0;  % Default: 0.3
    end
    % Update the display
    TessInfo = getappdata(RTConfig.hFig, 'Surface');
    set(TessInfo(1).hPatch, 'FaceVertexCData',sourceMap);

    drawnow

end    % end of function

