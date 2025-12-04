function [pacStr, phaseFreq, ampFreq, prefPhase] = bst_apc(sMatrix, matName, OPTIONS)

  
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Generated to solve the problem of APC with averaging the epochs at bursts
    % First Solution applied is to flip the sign of trough in the origianl dataiSrc
    % to average all of the peaks
    % Version Sep 2, 2023
    % Authors: Niloofar Gharesi, Sylvain Baillet
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % Version Feb 02, 2024: fine tune the location of peaks and troughs in the
    % burst detection algorihtm for each epoch and flip the sign of trough,
    % keep the sign of peak and store the values of burstType into burstInfoMatrix
    % Using RefinedID makes sharp peaks which can't be decomposed the signal
    % very well, so I use the default ID, detected for burst detection to
    % average epochs but use the Refined ID for detection of peaks and troughs
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % Version January 19, 2024: fine tune the location of peaks and troughs in the
    % burst detection algorihtm for each epoch and flip the sign of trough,
    % keep the sign of peak and store the values of burstType into burstInfoMatrix
    % ?????? Should we have this condition: 
    % Check if the difference is greater than 2 times fP
    %     if ~(fA(2) - fA(1) > 2 * fP)
    %         % Display a comment indicating the calculated expression and condition
    %         disp(['Pick a new fA range that satisfies this condition: fA(2) - fA(1) >'  num2str(2*fP)]);
    %         return
    %     end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    data = sMatrix.(matName); % Extract ImageGridAmp
    t = sMatrix.Time;
    % Parameters 
    isMirror = 0; 
    isRelax = 40;
    Method = 'bst-hfilter-2016';
    fArolloff = [];
    targetMin = -1; % normalization of dataiSrc and extracted envelope to compare them for flipping
    targetMax = 1;
    OPTIONS.dataiSrcLength = [5, 100];
    num_trials = 1;


    
    % Initialization of matrices
    ampFreq = []; % store frequency for amplitude for all sources
    phaseFreq = []; % store frequency for phase for all sources
    pacStr = []; % store PAC strength for all sources
    prefPhase = []; % store preffered phase for all sources
    fP_Nan = zeros(size(data, 1) , 1); % Store sources that
    % don't have any fP values
    
    % Prompt the user to enter the SubID
    % SubID = input('Enter the SubID: ', 's');
    
    
    for  iSrc = 200%4266:size(in_bst_results(sFiles{1}, 0).ImagingKernel,1) %1855%6420 %1855%8172%6420%8172 % Testing different sources to make sure they show PAC
        sprintf('Source Number %d', iSrc)

        % Extract the time vector 't' from sensor dataiSrc 
        dataiSrc = data(iSrc,:);

    
        % Extract sampling rate
        fs = ceil(1/(t(3)-t(2)));
    
        %% Step 1: detect high-frequency bursts    
        % Wavelet decomposition of signal time series
        fb = cwtfilterbank('SignalLength',numel(dataiSrc),'SamplingFrequency',fs,...
             'FrequencyLimits',OPTIONS.fA, 'TimeBandwidth',5); % TimeBandwidth controls the frequency resolution. Here, less localization over frequency
        [cfs, fc_h] = cwt(dataiSrc,'FilterBank',fb); % cfs is continuous wavelet coefficients which represent the signal in the time-frequency domain
                                                 % fc_h is center frequencies of the wavelets corresponding to the scales of the transform
    
        % Extract phase from complex CWT coefficients
        phi_cfs = angle(cfs); % Phase information to detect if bursts happening at the peaks or troughs
        Amp_cfs = rms(abs(cfs)); % rms(abs(cfs)); % Signal magnitude in the range of fA (this is different from envelope of the signal)
        
      
        % Detect peaks in spectrogram
        [pks_p, locs_p, ~, ~] = findpeaks(Amp_cfs, 'SortStr','descend', 'MinPeakDistance', .9/(OPTIONS.fA(1)*(t(2)-t(1)))); % Extract peaks and their locations
        tevent = t(locs_p); % time values corresponding to detected peaks
        meanCycle = mean(diff(locs_p)); % mean cycle duration by taking the mean of the differences between consecutive peak locations.
        cfs = abs(cfs); % keep modulus of wavelet coefs (we're only interested in magnitude effects and discard the phase information)
    
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        burstInfoMatrix = zeros(length(locs_p), 3);  % Burst type
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        nEpochs = 0;
        for k = 1:length(locs_p)
            %random control event
            ctrlID = floor(1+length(t)*rand(1));
            ctrlID = round([ctrlID(1), ctrlID(1)+diff(OPTIONS.epoch)*fs]);
            while ctrlID(end)>length(t) % % make sure control epoch is within dataiSrc time range
                ctrlID = floor(1+length(t)*rand(1));
                ctrlID = round([ctrlID(1), ctrlID(1)+diff(OPTIONS.epoch)*fs]);
            end
            
            ID = locs_p(k) + OPTIONS.epoch * fs; % ID of start and end of epoch
            epochTime = tevent(k)+OPTIONS.epoch; % epoch around each burst
            
            % If peak time +/- window is outside of the total timning (t)
            if epochTime(1)<t(1) || epochTime(2)>t(end) % epoch outside time range
                % do nothing
            else
                % Finding the similar peak in the orignial signal without filtering
                nEpochs = nEpochs+1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % check if the detected burst is a peak, or a trough, or nor-peak and nor-trough 
                BurstTime = tevent(k); % time at the burst point
                BurstID = round((BurstTime - t(1)) / (t(2) - t(1))); % Calculate Burst ID index
                epochdataiSrc  = dataiSrc(ID(1):ID(2)); % (ID(2) - ID(1))/2 + 1
                epochTimedataiSrc = t(ID(1):ID(2));
                
    
                % Define a window of neighboring points
                window_size = 3;  % Adjust as needed
                start_index = max(1, (length(epochdataiSrc)-1)/2 + 1 - floor(window_size/2));
                end_index = min(length(epochdataiSrc), (length(epochdataiSrc)-1)/2 + 1 + floor(window_size/2));
                
                % Extract the values of the neighboring points
                neighbor_values = epochdataiSrc(start_index:end_index);
                
                % Check if the specific point is a peak or trough
                BurstPoint = epochdataiSrc(round((length(epochdataiSrc)-1)/2) + 1); % value of the signal at burst
    
                % Find the max and min values in neighbor_values
                [peak_val, peak_idx] = max(neighbor_values);
                [trough_val, trough_idx] = min(neighbor_values);
                peak_idx_global = start_index - 1 + peak_idx;
                trough_idx_global = start_index - 1 + trough_idx;
                
                % Fine-tune BurstTime based on the larger of the max and min values
                if abs(peak_val) >= abs(trough_val)
                    BurstPoint = peak_val;    
                    BurstTime = epochTimedataiSrc(peak_idx_global); % update BurstTime for peak
                else
                    BurstPoint = trough_val;
                    BurstTime = epochTimedataiSrc(trough_idx_global); % update TroughTime for trough
                end
                
                RefinedBurstID = round((BurstTime - t(1)) / (t(2) - t(1))); % Refined Burst ID index
                DBurstID = RefinedBurstID - BurstID;
                RefinedID = ID + DBurstID; % update the ID number after fine-tuning of epoch dataiSrc for new peaks
    
                if BurstPoint == max(neighbor_values)
                    burstInfoMatrix(k, 2) = 1; % 1 represents a peak
                    epochSignalini = dataiSrc(ID(1):ID(2)); 
                elseif BurstPoint == min(neighbor_values)
                    burstInfoMatrix(k, 2) = 2; % 2 represents a trough
                    epochSignalini = -dataiSrc(ID(1):ID(2));
                else
                    burstInfoMatrix(k, 2) = 0; % 0 represents neither peak nor trough
                end
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                             
                if nEpochs==1
    
                    epochSignal = epochSignalini;
                    epochControl = dataiSrc(ctrlID(1):ctrlID(2));
                  
                    wltSignal = cfs(:,ID(1):ID(2)); % TFD 
                    wltControl = cfs(:,ctrlID(1):ctrlID(2)); 
           
                else
                    epochSignal = epochSignal + epochSignalini;
                    
                    epochControl= epochControl + dataiSrc(ctrlID(1):ctrlID(2));
                    
                    wltSignal = wltSignal + cfs(:,ID(1):ID(2)); % TFD 
                    wltControl = wltControl + cfs(:,ctrlID(1):ctrlID(2));       
                end
            end
        end
    
        sprintf('%d fA-bursts registered', nEpochs)
     
        % Average around peaks based on the number of fA registered 
        epochSignal = epochSignal/nEpochs;
        timeEpoch = linspace(OPTIONS.epoch(1), OPTIONS.epoch(2), length(epochSignal));
        timeEpochZero = linspace(OPTIONS.epoch(1), OPTIONS.epoch(2), length(epochSignal) + 1); % Adding time zero to the time vector
        epochSignalZero = interp1(timeEpoch, epochSignal, timeEpochZero, 'linear'); % Corresponding value at time zero
        
        epochControl = epochControl/nEpochs;
        % wltSignal = (wltSignal)/nEpochs;
        % wltControl = (wltControl)/nEpochs;
        % spectrumSignal = spectrumSignal/nEpochs
    
    
        
        %% Plotting
        if strcmp(OPTIONS.diagm, 'yes')
            fig = figure;
            fepochAVG = plot(timeEpoch,epochSignal , 'LineWidth', 4, 'Color' , 'k');
            ylim([-0.1 0.2])
            % fepochAVG = plot(Time(1:1000),Value(1:1000) , 'LineWidth', 1, 'Color' , 'k'); 
            title('Avg signal around bursts'); xlabel('Time (S)')
            xlim([-0.75 0.75])
            yline(0)
            % Specify common font to all subplots
            set(findobj(gcf,'type','axes'),'FontSize',14, 'LineWidth', 2);
            set(gca,'YColor','none'); %Remove numbers and axis
            % Give common xlabel, ylabel and title to your figure
            han=axes(fig,'visible','off'); 
            han.Title.Visible='on';
            han.XLabel.Visible='on';
            han.YLabel.Visible='on';
        end
    
        %% Step 2: extract fP candidate    
        fP = calc_fP(epochSignal, fs, timeEpoch, OPTIONS.diagm, OPTIONS.decomposition);
    
    
        if fP< 1 || isnan(fP) % the deteced fP should be above= 1
            sprintf('No fP candidate detected (min fP value ~%3.1f Hz)', fP)
            ampFreq = [ampFreq NaN];
            phaseFreq = [phaseFreq NaN];
            pacStr = [pacStr NaN];
            prefPhase = [prefPhase NaN];
            megPAC(iSrc) = struct('megPAC_interp_resample', NaN, 'time_interp_resample', NaN);
            fP_Nan(iSrc) = fP;
            continue;
        end
    
    
        if fP>=OPTIONS.fA(1) % the detected fP should be less than min fA
            sprintf('No fP candidate detected below fA range (min fA value ~%3.1f Hz)', OPTIONS.fA(1))
            ampFreq = [ampFreq NaN];
            phaseFreq = [phaseFreq NaN];
            pacStr = [pacStr NaN];
            prefPhase = [prefPhase NaN];
            megPAC(iSrc) = struct('megPAC_interp_resample', NaN, 'time_interp_resample', NaN);
            fP_Nan(iSrc) = fP;
            continue;
        end
    
     
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Check if the difference is greater than 2 times fP
        % if ~(fA(2) - fA(1) > 2 * fP)
        %     % Display a comment indicating the calculated expression and condition
        %     disp(['Pick a new fA range that satisfies this condition: fA(2) - fA(1) >'  num2str(2*fP)]);
        %     return
        % end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
    
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %=================Finding amplitude of fA arounf fp troughs 
        % (fiding amplitude in specific phase)
        % Step 3: Chop signal into epochs and average signal around troughs
        % Finding amplitude of fA around fp troughs (fiding amplitude in specific phase)
        % Goal: whether the phase and amplitude envelope are related
        % 1. produce canolty maps by considering PAC happens around troughs 
        % 2. detect troughs and then amplitude of high frequency component around
        % troughs
        % 3. cross-corrlation b/w amplitude of high-frequncy component and low frequncy signal to see in which lag the correlation b/w trough of
        % fP and max of fA amplitude is maximum
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Now that we have some idea about fP, produce Canolty maps
        % Filter dataiSrc around fP
        
        bpFP_filter = designfilt('bandpassfir', ...
                    'SampleRate', fs,...
                    'PassbandRipple', 1,...
                    'DesignMethod','equiripple',...
        'PassbandFrequency1', fP-.25, 'StopbandFrequency2', fP+1,'StopbandAttenuation1', 20,...
        'StopbandAttenuation2', 20, 'StopbandFrequency1', fP-1, 'PassbandFrequency2', fP +.25);
        % fvtool(bpFP_filter)
        
        margin = max(OPTIONS.epoch);
        nMargin = fix(margin*fs);
        dataiSrc_pad = [zeros(size(dataiSrc,1),nMargin), dataiSrc-mean(dataiSrc), zeros(size(dataiSrc,1),nMargin)];
        % tstart= linspace(t(1) + min(epoch), t(1)- 1/fs , nMargin);
        % tstop = linspace(t(end) + 1/fs, t(end)+max(epoch), nMargin);
        % t = [tstart, t, tstop];
        
        fPSignal = filtfilt(bpFP_filter,dataiSrc_pad);
        fPSignal = fPSignal(:,nMargin+1:end-nMargin); % Removing Margin
        
       
        % Detect troughs
        [pks_fp,locs_fp,~,~] = findpeaks(-fPSignal, 'SortStr','descend','MinPeakDistance', fs/(fP+.25)); % -fPSignal: detect troughs, fP+.25 is faster cutoff of fPSignal bandpass
        
    
        
        % Time of troughs in the original signal 
        % I = 1:round(1*numel(locs_fp));  
        % tevent = t(locs_fp(I)); 
        tevent = t(locs_fp); 
        nEpochs = 0;
            
        fb = cwtfilterbank('SignalLength',numel(dataiSrc),'SamplingFrequency',fs,...
            'FrequencyLimits',OPTIONS.fA, 'TimeBandwidth',60); % Higher frequency resolution than when detecting bursts above.
        [cfs_h,fc] = cwt(dataiSrc,'FilterBank',fb);
        cfs_h = abs(cfs_h);
        % A
        muC = mean(cfs_h,2);
        sigmaC = std(cfs_h,[],2); 
        cfs_h = bst_bsxfun(@minus, cfs_h, muC);
        cfs_h = bst_bsxfun(@rdivide, cfs_h, sigmaC);
        
        %Epoch length adapted to fP cycle length (5 fP cycles on both sides of t=0)
        epoch_fp = 3*[-1/fP, 1/fP]; %TODO= 2 used instead of 5
        
        for k = 1:length(locs_fp)%length(I)
            
            epochTime_fp = tevent(k)+epoch_fp;%(tevent(k)+0*rand(1))+epoch;
        
            if epochTime_fp(1)<t(1) || epochTime_fp(2)>t(end) % epoch outside time range
        
                % do nothing
            else
                nEpochs = nEpochs+1;
        %         ID = dsearchn(t',epochTime_fp'); % find sample IDs for epochTime in original dataiSrc   
                  ID = locs_fp(k) + epoch_fp * fs; %I(k) + epoch_fp * fs
        
                if nEpochs == 1
                    epochSignal_fp = dataiSrc(ID(1):ID(2));     
                    wltSignal_fp = cfs_h(:,ID(1):ID(2)); % TFD 
                else
                    epochSignal_fp = epochSignal_fp + dataiSrc(ID(1):ID(2));
                    wltSignal_fp = wltSignal_fp + cfs_h(:,ID(1):ID(2)); % TFD 
                end
            end
        end
        
        wltControl_perm = [];
        epochControl_perm = [];
        nEpochsCtrl = 0;
        % Control event (deprecated)
        for num_perm_ctrl = 10
            for k = 1:1*length(locs_fp)
                
                %random control event
                ctrlID = floor(1+length(t)*rand(1));
                ctrlID = [ctrlID(1), ctrlID(1)+length(epochSignal_fp)-1];
                while ctrlID(end)>length(t) % % make sure control epoch is within dataiSrc time range
                    ctrlID = floor(1+length(t)*rand(1));
                    ctrlID = [ctrlID(1), ctrlID(1)+length(epochSignal_fp)-1];
                end
                
                nEpochsCtrl = nEpochsCtrl+1;
                
                if nEpochsCtrl==1
                    epochControl_fp = dataiSrc(ctrlID(1):ctrlID(2));    
                    wltControl_fp = cfs_h(:,ctrlID(1):ctrlID(2));
                else
                    epochControl_fp = epochControl_fp + dataiSrc(ctrlID(1):ctrlID(2));
                    wltControl_fp = wltControl_fp + cfs_h(:,ctrlID(1):ctrlID(2));
                end
            
               
            end
             epochControl_perm = [epochControl_perm ;epochControl_fp];
             wltControl_perm = [wltControl_perm ;  wltControl_fp];
            
        end
        epochControl_fP = mean(epochControl_perm);
        wltControl_fP = mean(wltControl_perm);
        
        sprintf('%d fP-cycles registered', nEpochs)
        
        epochSignal_fp = epochSignal_fp/nEpochs; % Original signal around troughs
        epochControl_fp = epochControl_fp/nEpochsCtrl;
        wltSignal_fp = (wltSignal_fp)/nEpochs; % Filtered signal in fA range around troughs
        wltControl_fp = (wltControl_fp)/(nEpochsCtrl);
        
        timeEpoch_fp = linspace(OPTIONS.epoch(1), OPTIONS.epoch(2), length(epochSignal_fp));
        timeEpoch_fp_ctrl = linspace(OPTIONS.epoch(1), OPTIONS.epoch(2), length(epochControl_fp));
        % Plot original and ctrl signal around troughs
        if strcmp(OPTIONS.diagm, 'yes')
            figure;
            % yyaxis left
            fepochAVG = plot(timeEpoch_fp,epochSignal_fp , 'LineWidth', 3, 'Color' , 'k'); %hold on
            title('Avg signal around troughs'); xlabel('Time (S)')
            % Specify common font to all subplots
            set(findobj(gcf,'type','axes'),'FontSize',14, 'LineWidth', 2);
            xlim([min(timeEpoch_fp) max(timeEpoch_fp)])
    %         yline(0);
            set(gca,'YColor','none'); %Remove numbers and axis
            % Give common xlabel, ylabel and title to your figure
            han=axes(fig,'visible','off'); 
            han.Title.Visible='on';
            han.XLabel.Visible='on';
            han.YLabel.Visible='on';
            % fctrlAVG = plot(timeEpoch_fp_ctrl, epochControl_fp, 'LineWidth', 1, 'Color' , 'm');
            % legend('EpochSignal', 'ControlSignal')
        end
        %====================================================================================
        % Filter the sudden drop
        epochSignalClean = medfilt1(epochSignal_fp);
        epochSignalClean  = epochSignalClean - mean(epochSignalClean); % mra2(:,end);
        fP = medfreq(epochSignalClean, fs); % frequency for phase (updated)
        phaseFreq = [phaseFreq fP];
        %----------------------------------------------PAC around epochedSignal----------------------------------------------------------
        
        % Standardize amplitude per frequency bin
        % muC = mean(wltSignal_fp,2);
        % sigmaC = std(wltSignal_fp,[],2); 
        % zwltSignal = bst_bsxfun(@minus, wltSignal_fp, muC);
        % zwltSignal = bst_bsxfun(@rdivide, zwltSignal, sigmaC);
        zwltSignal = wltSignal_fp;
        % Control component
        % muC = mean(wltControl_fp,2);
        % sigmaC = std(wltControl_fp,[],2); 
        % zwltControl= bst_bsxfun(@minus, wltControl_fp, muC);
        % zwltControl= bst_bsxfun(@rdivide, zwltControl, sigmaC);
        zwltControl = wltControl_fp;
        
        
        % Correlation between spectrogram and signal averaged around troughs of the
        % low frequncy oscillation with the highest PAC to find the delay respect
        % to trough
        clear xCorr lagCorr xCorrControl lagCorrControl
        
        for k = 1:size(zwltSignal,1)
            [xCorr(:,k),lagCorr(:,k)] = xcorr(zwltSignal(k,:),epochSignalClean,...
                round(0.8* fs/fP));
            
            [xCorrControl(:,k),lagCorrControl(:,k)] = xcorr(zwltControl(k,:),epochControl_fp,...
                round(0.8* fs/fP)); % it should be epochControl_fp?????????
        end
        
        [MxCorr,I_xCorr] = max(-xCorr, [], 1); % minus sign (-xCorr) because the lag is measured b/w trough of fP and max of fA amplitude
        [~,J_xCorr] = max(MxCorr);
        % Plot correaltion b/w, TF map and low frequncy component 
        if strcmp(OPTIONS.diagm, 'yes')
            figure;
            % Create a vertical layout with 3 rows
            t = tiledlayout(3,1);
            t.TileSpacing = 'compact';      % Remove extra space between tiles
            t.Padding = 'compact';          % Remove outer padding
            
            % Top 2 rows merged for the time-frequency plot
            nexttile([2 1]);  % Occupies 2 rows
            hp = pcolor(timeEpoch_fp, fc, zwltSignal);
            hp.EdgeColor = 'none';
            hp.FaceColor = 'interp';
            title('[smoothed:] z-scored induced signal');
            xlabel('Time (s)');
            ylabel('Frequency (Hz)');
            colormap('jet')
            cb = colorbar;
            cb.Layout.Tile = 'east';  % Puts the colorbar to the right of the time-frequency plot
            % Optional: Set caxis range
            % caxis([-.6*max(abs(zwltSignal(:))), .6*max(abs(zwltSignal(:)))])
            set(gca, 'FontSize', 14, 'LineWidth', 1, 'color', 'k');
            
            % Bottom row for time-series signal
            nexttile;
            plot(timeEpoch_fp, epochSignalClean, 'LineWidth', 1.25, 'Color', 'k');
            ylabel('Amplitude');
            xlabel('Time (s)');
            set(gca, 'FontSize', 14, 'LineWidth', 1);
            box off;
            axis off;
                
            figure;
            subplot(3,1,[1 2]);
            % yyaxis left 
            hp = pcolor(timeEpoch_fp_ctrl,fc,zwltControl);
            hp.EdgeColor = 'none'; hp.FaceColor = 'interp'; %set(gca,'YScale', 'log')
            title('[smoothed: ] z-scored control signal');
            xlabel('Time (S)'); ylabel('Frequency (Hz)');
            colorbar, colormap('jet'), 
            % caxis([-.6*max(abs(zwltControl(:))), .6*max(abs(zwltControl(:)))])
            % yyaxis right
            set(findobj(gcf,'type','axes'),'FontSize',14,'LineWidth', 1, 'color', 'k');
            subplot(3,1,[3]);
            plot(timeEpoch_fp_ctrl, epochControl_fp, 'LineWidth', 1, 'Color' , 'k');
            set(findobj(gcf,'type','axes'),'FontSize',14); ylabel('Amplitude');
            xlim([-.75 .75])
            xlabel('Time (S)')
        end
        
     
        fAfPlags = fP*lagCorr/fs;
        %find modes in fA/fP cross-correlation (to see if phase and amplitude envelope are related):
        xCorrTrace = sum(abs(xCorr),1); % Sum the corr at each frequency 
        % Detect peaks 
        xCorrTrace = fliplr(xCorrTrace);
        freqs = fliplr(fc');
        [pks,locs,w,p] = findpeaks(xCorrTrace,freqs,'WidthReference','halfheight', 'SortStr','descend');
        
        % Pick the most prominent peaks
        p = p/max(p);
        ipeaks = find(p > 0.1);
        
        fAWidth = w(ipeaks);
        fAFreq = locs(ipeaks);
        
        fAA = fAFreq(1); % Frequency for amplitude
        ampFreq = [ampFreq fAA];
        fAAWidth = fAWidth(1);
    
        % Plot corr plot b/w TF map and low frequncy 
        if strcmp(OPTIONS.diagm, 'yes')
            figure
            hp = pcolor(lagCorr(:,1)/fs, fc, xCorr');
            hp.EdgeColor = 'none'; hp.FaceColor = 'interp';set(gca,'YScale', 'log')
            colorbar, colormap('jet')
            ylabel('Frequency for amplitude (Hz)')
            xlabel('Cross-correlation delay (ms)')
            title(sprintf('slow cycle (%3.1f Hz) vs. envelope of fast components', fP, fc(J_xCorr)))
            set(findobj(gcf,'type','axes'),'FontSize',14,'LineWidth', 1);
            
            
            figure;
            [psor,lsor] = findpeaks(xCorrTrace,freqs,'WidthReference','halfheight', 'SortStr','descend');
            findpeaks(xCorrTrace,freqs,'WidthReference','halfheight', 'SortStr','descend');
            h = findpeaks(xCorrTrace, freqs, ...
            'WidthReference', 'halfheight', 'SortStr', 'descend');
            % Change line color and width
            hLines = findobj(gca, 'Type', 'Line', '-and', 'Tag', 'Peak');  % Find the peak markers
            set(hLines, 'Color', 'k', 'LineWidth', 2)
            % title(sprintf('fP=%3.1f Hz / fA=%3.1f Hz / fP-fA time shift = %3.2f x fP cycle', fP, fAA , fP*lagCorr(I(J_xCorr),J_xCorr)/fs))
            title(sprintf('fP=%3.1f Hz / fA=%3.1f Hz', fP, fAA))
            text(lsor+.02,psor,num2str((1:numel(psor))'))
            xlabel('Frequency (Hz)')
            grid off
            set(findobj(gcf,'type','axes'),'FontSize',14, 'LineWidth', 1);
        end
        
        %% TODO: Refine the filter design (fAA+fAAwidth was replaced with min([fAA+fAAWidth/2 fs/2.001]) because fAA+fAAWidth if is higher than fs/2, we only can have frequency <=fs/2)
        % PassbandFrequency2 should be less than StopbandFrequency2
        bpFA_filter = designfilt('bandpassfir', ...
                      'SampleRate', fs,...
                      'PassbandRipple', 1,...
                        'DesignMethod','equiripple',...
            'StopbandFrequency1', max([eps, fAA-fAAWidth]),'PassbandFrequency1', fAA-fAAWidth/2, 'StopbandAttenuation1', 20,...
            'StopbandAttenuation2', 20, 'PassbandFrequency2', min([fAA+fAAWidth/2 fs/2.005]), 'StopbandFrequency2', min([fAA+fAAWidth, fs/2]));
        
        dataiSrc_pad = [zeros(size(dataiSrc,1),nMargin), dataiSrc, zeros(size(dataiSrc,1),nMargin)];
        fASignal = filtfilt(bpFA_filter,dataiSrc_pad);
        fASignal = fASignal(:,nMargin+1:end-nMargin); % Removing Margin
        
        phi = angle(hilbert(fPSignal)); % Compute phase of low-freq signal 
        amp = abs(hilbert(fASignal)); % Compute amplitude of high-freq signal
       
        
        % Measure coupling strength using different methods
        [PAC_circle,Pref_phase] = calc_MI_all_methods(phi, amp, 'canolty', 'no', OPTIONS.num_perm, num_trials, OPTIONS.diagm, OPTIONS.numPhaseBins)
        pacStr = [pacStr PAC_circle];
        prefPhase = [prefPhase Pref_phase];
    
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % MEGPAC analysis
        % Step 1: The troughs and peaks of the optimal low-frequency phase were
        % detemined from original signal
        % Step 2: the amplitude of same source signal in high-frequncy range 
        % Step 3: Linearly interpolate the hight-frequncy amplitude at the troughs and peaks
        % of the low-frequency
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        [VPeaks,tPeaks,~,~] = findpeaks(phi, 'MinPeakDistance', .9*fs/fP);
        difftPeaks = diff(tPeaks); % tPeaks is for specifying cycles
        period = mean(difftPeaks);
        ncycles = numel(difftPeaks); % total number of fP cycles
        Preferred_phase = deg2rad(Pref_phase);%angle(PAC);
        
        for icycle = 1:ncycles
            EachCycle_phase = phi(tPeaks(icycle):tPeaks(icycle+1))'; % Break down the phaseAngle to several cycles
            [~, closestIndex] = min(abs(EachCycle_phase - Preferred_phase)); % Find the point close to preffered phase in each cycle
            closeestValue(icycle) = EachCycle_phase(closestIndex);
            EachCycle_amp = amp(tPeaks(icycle):tPeaks(icycle+1))';
            % EachCycle_amp = EachCycle_amp - min(EachCycle_amp); % this is applied if
            % ampSignal is the whole signal and not its amplitude
            % muC = mean(EachCycle_amp); % comment for LFP dataiSrc
            % sigmaC = std(EachCycle_amp); % COmment for LFP dataiSrc
            % zscore fA activity over that cycle
            % cycfAwlt= bst_bsxfun(@minus, EachCycle_amp, muC); % zscore
            % cycfAwlt= bst_bsxfun(@rdivide, EachCycle_amp, sigmaC); %zscore
            % amp_preffered_phase(icycle) = cycfAwlt(closestIndex); %zscore
            amp_preffered_phase(icycle) = EachCycle_amp(closestIndex); %zscore
            EachCycle_t = t(tPeaks(icycle):tPeaks(icycle+1))'; % Similar for time
            t_preffered_phase(icycle) = EachCycle_t(closestIndex);
            
            % Preffered_phase + pi degree
            [~, closestIndex_pi] = min(abs(EachCycle_phase - (Preferred_phase + pi))); % Find the point close to Preferred phase in each cycle
            closeestValue_phase_pi(icycle) = EachCycle_phase(closestIndex_pi);
            amp_preffered_phase_pi(icycle) = amp(closestIndex_pi);
            
            % Orginal PAC at all phases
            % amp_new(tPeaks(icycle):tPeaks(icycle+1)) = amp;
        end
        
        
        
        %% Polar plot for preferred phase and opposite phase
        signalPAC_Preffered_Phase = amp_preffered_phase .* exp (1i * closeestValue);
        signalPAC_pi = amp_preffered_phase_pi .* exp (1i * closeestValue_phase_pi);
        
        if strcmp(OPTIONS.diagm, 'yes')
            figure,
            polarplot(signalPAC_Preffered_Phase,'.r', 'MarkerSize',25)
            hold on
            polarplot(signalPAC_pi,'.b','MarkerSize',25)
            pax = gca
            pax.FontSize = 16;
            pax.FontWeight = 'Bold'
            pax.ThetaColor = 'k'
            pax.GridColor = 'k'
            pax.GridAlpha = 0.6;
        end
        %% megPAC 
        x_inter = t_preffered_phase; % Time of each preffered phase in each source
        v_megPAC = amp_preffered_phase; % Amplitude of envelop at each preffered phase in each source
        [dataiSrc_resmaple, t_sampling] = resample_Brainstorm(dataiSrc, t, min(OPTIONS.fA));
        xq_inter = t_sampling; % time of signal source, How to intrpolate with the low fA: relation of fA and number of time samples
        % xq_inter = t;
        %% Interpolation to t samples, downsample, filtering
        [time_u_megPAC unique_indeces_megPAC] = unique(x_inter);
        dataiSrc_u_megPAC = v_megPAC(unique_indeces_megPAC);
        clear unique_indeces_megPAC;
        vq_inter = interp1(time_u_megPAC,dataiSrc_u_megPAC,xq_inter, 'linear');
        [interp_Nan,~] = fillmissing(vq_inter,'linear'); % for now don't fill the missing values
        xmegPAC = [];
        xmegPAC = [xmegPAC ; interp_Nan];
        
        % Resampling to 10Hz
        fss_megPAC = 1/(t_sampling(2) - t_sampling(1)); % Sampling frequncy
        % fss_megPAC = fs; % Sampling frequncy 
        % [P_tenHz,Q_tenHz] = rat(10/fss_megPAC);
        % megPAC_interp_resample = resample(xmegPAC, P_tenHz,Q_tenHz); % Resample to 10 Hz, no components with Nyquist frequency
        % time_interp_resample = resample(xq_inter, P_tenHz,Q_tenHz); % Resample to 10 Hz, no components with Nyquist frequency
        [megPAC_interp_resample, time_interp_resample] = resample_Brainstorm(xmegPAC, xq_inter, 10);
        
        megPAC(iSrc) = struct('megPAC_interp_resample', megPAC_interp_resample, 'time_interp_resample', time_interp_resample);
    
    
        % Create a struct to store the variables
%         dataiSrc = struct('megPAC_sig', megPAC, ...
%                       'megPAC_time', time_interp_resample, ...
%                       'pacStr', pacStr, ...
%                       'ampFreq', ampFreq, ...
%                       'phaseFreq', phaseFreq, ...
%                       'prefPhase', prefPhase, ...
%                       'fP_Nan' , fP_Nan);
%         
%         
%         % Save the struct with the SubID as part of the filename
%         filename = sprintf('RestingState_megPAC_%s.mat', SubID);
%         save(filename, 'dataiSrc');
    %     save(filename, '-append')
        
%         iSrc = iSrc + 1;
    end
    
    
    % STEP2: look at the result for different value of K and see how can we
    % filter (choose the right bandwidth for filter)




end