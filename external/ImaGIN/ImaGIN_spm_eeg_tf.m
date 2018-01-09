function D = ImaGIN_spm_eeg_tf(S)
% compute instantaneous power and phase in peri-stimulus time and frequency
% FORMAT D = ImaGIN_spm_eeg_tf(S)
% 
% D		- filename of EEG-data file or EEG data struct
% stored in struct D.events:
% fmin			- minimum frequency
% fmax			- maximum frequency
% rm_baseline	- baseline removal (1/0) yes/no
% Mfactor       - Morlet wavelet factor (can not be accessed by GUI)
% 
% D				- EEG data struct with time-frequency data (also written to files)
%_______________________________________________________________________
%
% ImaGIN_spm_eeg_tf estimates instantaneous power and phase of data using
% the
% continuous Morlet wavelet transform.
%_______________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% Stefan Kiebel
% $Id: spm_eeg_tf.m 341 2005-11-30 18:08:16Z stefan $


[Finter,Fgraph,CmdLine] = spm('FnUIsetup','EEG time-frequency setup',0);

try
    DD = S.D;
catch
    DD = spm_select(inf, '\.mat', 'Select EEG mat file');
end

if size(DD,1)>1
    try
        S.Pre;
    catch
        S.Pre=spm_input('Prefix of new file', '+1', 's');
    end

    try
        S.Method;
    catch
        Ctype = {
            'Morlet wavelet',...
            'Hilbert', ...
            'Mexhat wavelet',...
            'Multitaper',...
            'Coherence'};
        str   = 'Time frequency decomposition';
        Sel   = spm_input(str, 2, 'm', Ctype);
        S.Method = Ctype{Sel};
    end

    if ~strcmp(S.Method,'Multitaper')
        try
            S.Synchro;
        catch
            Ctype = {'Yes', 'No'};
            str   = 'Compute synchrony ';
            Sel   = spm_input(str, 2, 'm', Ctype);
            S.Synchro = Ctype{Sel};
        end
    else
        S.Synchro = 0;
    end

    switch S.Method
        case {'Morlet wavelet', 'Hilbert', 'Multitaper', 'Mexhat wavelet'}
            try
                S.frequencies;
            catch
                S.frequencies = spm_input('Frequencies (Hz)', '+1', 'r', '', [1, inf]);
            end
        case 'Coherence'
            try
                S.FrequencyResolution;
            catch
                S.FrequencyResolution = spm_input('Frequency resolution (Hz)', '+1', 'r', '', [1, inf]);
            end
            try
                S.FrequencyRange;
            catch
                S.FrequencyRange = spm_input('Frequency range [Hz] ([min max])', '+1', 'i','[]');
            end
    end

    switch S.Method
        case{'Morlet wavelet'}
            try
                S.FactMod;
            catch
                tmp = spm_input('Band pass Filter','+1', 'Yes|No');
                switch tmp
                    case 'No',   S.FactMod = 0;
                    case 'Yes',  S.FactMod = spm_input('Factor of modulation', '+1', 'r', '10', 1);
                end
            end

            try
                S.Mfactor;
            catch
                S.Mfactor = spm_input('Morlet wavelet factor', '+1', 'r', '7', 1);
            end

            try
                S.Width;
            catch
                S.Width = spm_input('Number of oscillations for integration', '+1', 'r', '5', 1);
            end

            try
                S.TimeWindow;
            catch
                S.TimeWindow = spm_input('Time window positions [sec]', '+1', 'r','[]');
            end

            if ~isempty(S.TimeWindow)
                try
                    S.TimeWindowWidth;
                catch
                    S.TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r');
                end
            else
                S.TimeWindowWidth=[];
            end

            if (S.Width > 0)
                try
                    S.Coarse;
                catch
                    S.Coarse = spm_input('Downsampling factor for integration', '+1', 'r', '5', 1);
                end
            else
                try
                    S.TimeResolution;
                catch
                    S.TimeResolution = spm_input('Time Resolution [s]', '+1', 'r', '.1', 1);
                end
                S.Coarse = 0;
            end

        case{'Mexhat wavelet'}
            try
                S.FactMod;
            catch
                tmp = spm_input('Band pass Filter','+1','Yes|No');
                switch tmp
                    case 'No',    S.FactMod = 0;
                    case 'Yes',   S.FactMod = spm_input('Factor of modulation', '+1', 'r', '10', 1);
                end
            end

            try
                S.TimeWindow;
            catch
                S.TimeWindow = spm_input('Time window positions [sec]', '+1', 'r','[]');
            end

            if ~isempty(S.TimeWindow)
                try
                    S.TimeWindowWidth;
                catch
                    S.TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r');
                end
            else
                S.TimeWindowWidth = [];
            end

            try
                S.TimeResolution;
            catch
                S.TimeResolution = spm_input('Time Resolution [s]', '+1', 'r', '.1', 1);
            end
            S.Coarse = 0;

        case{'Hilbert'}
            try
                S.FactMod;
            catch
                S.FactMod = spm_input('Factor of modulation', '+1', 'r', '10', 1);
            end

            try
                S.Width;
            catch
                S.Width = spm_input('Number of oscillations for integration', '+1', 'r', '5', 1);
            end

            try
                S.TimeWindow;
            catch
                S.TimeWindow = spm_input('Time window positions [sec]', '+1', 'r','[]');
            end

            if ~isempty(S.TimeWindow)
                try
                    S.TimeWindowWidth;
                catch
                    S.TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r');
                end
            else
                S.TimeWindowWidth=[];
            end

            try
                S.Coarse;
            catch
                S.Coarse = spm_input('Downsampling factor for integration', '+1', 'r', '5', 1);
            end

        case{'Multitaper'}
            try
                S.FactMod;
            catch
                S.FactMod = spm_input('Factor of modulation', '+1', 'r', '10', 1);
            end

            try
                S.TimeWindowWidth;
            catch
                S.TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r', '1', 1);
            end

            try
                S.TimeWindow;
            catch
                S.TimeWindow = spm_input('Time window of analysis [sec]', '+1', 'r','[]');
            end

            try
                S.TimeResolution;
            catch
                S.TimeResolution = spm_input('Time resolution [sec]', '+1', 'r', '0.1');
            end
            
            try
                S.NSegments;
            catch
                S.NSegments = spm_input('Number of segments', '+1', 'i','1', 1);
            end

            try
                S.TimeResolution;
            catch
                S.TimeResolution = spm_input('Time resolution [sec]', '+1', 'r', '0.1');
            end

            try
                S.Taper;
            catch
                Ctype = {'DPSS', 'Hanning'};
                str   = 'Taper ';
                Sel   = spm_input(str, '+1', 'm', Ctype);
                S.Taper = lower(Ctype{Sel});
            end
            S.Synchro=0;
            
        case{'Coherence'}
            try
                S.TimeWindow;
            catch
                S.TimeWindow = spm_input('Time window positions [sec]', '+1', 'r','[]');
            end
            if isempty(S.TimeWindow)
                try
                    D.tf.Coarse = S.Coarse;
                catch
                    D.tf.Coarse = spm_input('Downsampling factor for integration', '+1', 'r', '5', 1);
                end
            end
    end

    % NB: D.tf.channels maps directly into the data. To retrieve the position of the channel, use D.channels.order
    try
        S.channels;
    catch
        S.channels = spm_input('Select channels', '+1', 'i', '[]');
    end
end

for i1 = 1:size(DD,1)
    try
        [D,TimeWindow,TimeWindowWidth] = ImaGIN_spm_eeg_tf_main(deblank(DD(i1,:)),S{i1});
    catch
        try
            [D,TimeWindow,TimeWindowWidth] = ImaGIN_spm_eeg_tf_main(deblank(DD(i1,:)),S);
        catch
            [D,TimeWindow,TimeWindowWidth] = ImaGIN_spm_eeg_tf_main(deblank(DD(i1,:)));
        end
    end
    if (i1==1) && ~exist('S', 'var')
        S.Method=D.tf.Method;
        switch D.tf.Method
            case {'Morlet wavelet', 'Hilbert', 'Multitaper', 'Mexhat wavelet'}
                S.frequencies = D.tf.frequencies;
                try
                    S.Coarse = D.tf.Coarse;
                end
            case 'Coherence'
                S.FrequencyResolution = D.tf.FrequencyResolution;
        end
        switch S.Method
            case {'Morlet wavelet'}
                S.FactMod = D.tf.FactMod;
                S.Mfactor = D.tf.Mfactor;
            case {'Hilbert','Mexhat wavelet'}
                S.FactMod = D.tf.FactMod;
        end
        switch S.Method
            case {'Morlet wavelet','Hilbert','Coherence','Mexhat wavelet'}
                S.Width = D.tf.Width;
            case 'Multitaper'
                S.TimeResolution = D.tf.TimeResolution;
                S.FactMod = D.tf.FactMod;
        end
        S.channels = D.tf.channels;
        S.TimeWindow = TimeWindow;
        S.TimeWindowWidth = TimeWindowWidth;
        S.Synchro = D.tf.Synchro;
    end
end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [D, TimeWindow, TimeWindowWidth] = ImaGIN_spm_eeg_tf_main(D,S)
    TimeWindow=[];
    TimeWindowWidth=[];

    D = spm_eeg_load(D);

    % Check for arguments in D
    if ~isfield(D, 'tf')
        D.tf = [];
    end

    try
        Pre = S.Pre;
    catch
        Pre = spm_input('Prefix of new file', '+1', 's');
    end

    try
        D.tf.Method = S.Method;
    catch
        Ctype = {
            'Morlet wavelet',...
            'Mexhat wavelet',...
            'Multitaper',...
            'Coherence'};
        str  = 'Time frequency decomposition';
        Sel  = spm_input(str, 2, 'm', Ctype);
        D.tf.Method = Ctype{Sel};
    end

    if strcmp(D.tf.Method,'Multitaper')
        S.Synchro=0;
    end
    if strcmp(D.tf.Method,'Mexhat wavelet')
        S.Synchro=0;
    end

    try
        FlagSynchro=S.Synchro;
    catch
        Ctype = {'Yes', 'No'};
        str   = 'Compute synchrony ';
        Sel   = spm_input(str, 2, 'm', Ctype);
        FlagSynchro = Ctype{Sel};
    end
    D.tf.Synchro = FlagSynchro;
    switch FlagSynchro
        case 'Yes'
            FlagSynchro=1;
        otherwise
            FlagSynchro=0;
    end

    switch D.tf.Method
        case {'Morlet wavelet','Hilbert','Multitaper', 'Mexhat wavelet'}
            try
                D.tf.frequencies = S.frequencies;
            catch
                D.tf.frequencies = spm_input('Frequencies (Hz)', '+1', 'r', '', [1, inf]);
            end
        case 'Coherence'
            try
                D.tf.FrequencyResolution = S.FrequencyResolution;
            catch
                D.tf.FrequencyResolution = spm_input('Frequency resolution (Hz)', '+1', 'r', '', [1, inf]);
            end
            try
                D.tf.FrequencyRange = S.FrequencyRange;
            catch
                D.tf.FrequencyRange = spm_input('Frequency range [Hz] ([min max])', '+1', 'r','[]');
            end
            D.tf.nfft = D.fsample / D.tf.FrequencyResolution;
            D.tf.nfft = 2^floor(log2(D.tf.nfft));
            D.tf.FrequencyResolution = D.fsample / D.tf.nfft;
            D.tf.frequencies = 0 : D.tf.FrequencyResolution : D.fsample/2;
            if ~isempty(D.tf.FrequencyRange)
                D.tf.frequenciesIndex = find((D.tf.frequencies >= D.tf.FrequencyRange(1)) & (D.tf.frequencies <= D.tf.FrequencyRange(2)));
                D.tf.frequencies = D.tf.frequencies(D.tf.frequenciesIndex);
            else
                D.tf.frequenciesIndex = 1:length(D.tf.frequencies);
            end
    end

    D.tf.rm_baseline = 0;

    switch D.tf.Method
        case 'Morlet wavelet'
            try
                D.tf.FactMod = S.FactMod;
            catch
                tmp=spm_input('Band pass Filter','+1','Yes|No');
                switch tmp
                    case 'No',   D.tf.FactMod = 0;
                    case 'Yes',  D.tf.FactMod = spm_input('Factor of modulation', '+1', 'r', '10', 1);
                end
            end

            try
                D.tf.Mfactor = S.Mfactor;
            catch
                D.tf.Mfactor = spm_input('Morlet wavelet factor', '+1', 'r', '7', 1);
            end

            try
                D.tf.Width = S.Width;
            catch
                D.tf.Width = spm_input('Number of oscillations for integration', '+1', 'r', '5', 1);
            end

            try
                TimeWindow = S.TimeWindow;
            catch
                TimeWindow = spm_input('Time window positions [sec]', '+1', 'r','[]');
            end

            if ~isempty(TimeWindow)
                try
                    TimeWindowWidth = S.TimeWindowWidth;
                catch
                    TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r');
                end
            else
                TimeWindowWidth=[];
            end

            if D.tf.Width>0
                try
                    D.tf.Coarse = S.Coarse;
                catch
                    D.tf.Coarse = spm_input('Downsampling factor for integration', '+1', 'r', '5', 1);
                end
            else
                try
                    D.tf.TimeResolution=S.TimeResolution;
                catch
                    D.tf.TimeResolution = spm_input('Time Resolution [s]', '+1', 'r', '.1', 1);
                end
                try
                    D.tf.Coarse = S.Coarse;
                catch
                    D.tf.Coarse = spm_input('Downsampling factor for integration', '+1', 'r', '5', 1);
                end
            end

        case 'Mexhat wavelet'
            try
                D.tf.FactMod = S.FactMod;
            catch
                tmp=spm_input('Band pass Filter','+1','Yes|No');
                switch tmp
                    case 'No',    D.tf.FactMod = 0;
                    case 'Yes',   D.tf.FactMod = spm_input('Factor of modulation', '+1', 'r', '10', 1);
                end
            end

            try
                TimeWindow = S.TimeWindow;
            catch
                TimeWindow = spm_input('Time window positions [sec]', '+1', 'r','[]');
            end
            try
                TimeWindowWidth = S.TimeWindowWidth;
            catch
                TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r');
            end

            try
                D.tf.Width = S.Width;
            catch
                D.tf.Width = spm_input('Number of oscillations for integration?', '+1', 'r', '5', 1);
            end
            
            try
                D.tf.TimeResolution=S.TimeResolution;
            catch
                D.tf.TimeResolution = spm_input('Time Resolution [s]', '+1', 'r', '.1', 1);
            end
            try
                D.tf.Coarse = S.Coarse;
            catch
                D.tf.Coarse = spm_input('Downsampling factor for integration?', '+1', 'r', '5', 1);
            end

        case 'Multitaper'
            try
                D.tf.FactMod = S.FactMod;
            catch
                D.tf.FactMod = spm_input('Factor of modulation', '+1', 'r', '10', 1);
            end

            try
                TimeWindowWidth = S.TimeWindowWidth;
            catch
                TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r', '1', 1);
            end

            try
                TimeWindow = S.TimeWindow;
            catch
                TimeWindow = spm_input('Time window of analysis [sec]', '+1', 'r','[]');
            end

            try
                D.tf.TimeResolution = S.TimeResolution;
            catch
                D.tf.TimeResolution = spm_input('Time resolution [sec]', '+1', 'r', '0.1');
            end

            try
                D.tf.NSegments = S.NSegments;
            catch
                D.tf.NSegments = spm_input('Number of segments', '+1', 'i','1',1);
            end

            try
                D.tf.Taper = S.Taper;
            catch
                Ctype = {'DPSS', 'Hanning'};
                str   = 'Taper ';
                Sel   = spm_input(str, '+1', 'm', Ctype);
                D.tf.Taper = lower(Ctype{Sel});
            end

        case 'Hilbert'
            try
                D.tf.FactMod = S.FactMod;
            catch
                D.tf.FactMod = spm_input('Factor of modulation', '+1', 'r', '10', 1);
            end

            try
                D.tf.Width = S.Width;
            catch
                D.tf.Width = spm_input('Number of oscillations for integration?', '+1', 'r', '5', 1);
            end

            try
                TimeWindow = S.TimeWindow;
            catch
                TimeWindow = spm_input('Time window positions [sec]', '+1', 'r','[]');
            end

            if ~isempty(TimeWindow)
                try
                    TimeWindowWidth = S.TimeWindowWidth;
                catch
                    TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r');
                end
            else
                TimeWindowWidth = [];
            end

            try
                D.tf.Coarse = S.Coarse;
            catch
                D.tf.Coarse = spm_input('Downsampling factor for integration?', '+1', 'r', '5', 1);
            end


        case 'Coherence'
            D.tf.Width = 2*D.tf.nfft / D.fsample;
            TimeWindowWidth = D.tf.Width;

            try
                TimeWindow = S.TimeWindow;
            catch
                TimeWindow = spm_input('Time window positions [sec]', '+1', 'r','[]');
            end

            if isempty(TimeWindow)
                try
                    D.tf.Coarse = S.Coarse;
                catch
                    D.tf.Coarse = spm_input('Downsampling factor for integration', '+1', 'r', '5', 1);
                end
            end
    end

    % NB: D.tf.channels maps directly into the data. To retrieve the position of the channel, use D.channels.order
    try
        D.tf.channels = S.channels;
    catch
        D.tf.channels = spm_input('Select channels', '+1', 'i', sprintf('1:%d',D.nchannels));
    end
    if isempty(D.tf.channels)
        D.tf.channels = 1:D.nchannels;
    end

    spm('Pointer', 'Watch'); drawnow;

    D.tf.CM = ConnectivityMatrix(length(D.tf.channels));

    D.Nfrequencies = length(D.tf.frequencies);

    switch D.tf.Method
        case {'Morlet wavelet', 'Hilbert', 'Mexhat wavelet'}
            D2 = D;
            Dint = D;
            D2int = D;
        case {'Coherence', 'Multitaper'}
            D2 = D;
    end

    switch D.tf.Method
        case 'Multitaper'
            D.datatype = 'float32-le';
            D.tf.Label = 'Power';

        case {'Morlet wavelet', 'Hilbert', 'Mexhat wavelet'}
            D.datatype = 'float32-le';
            D2.datatype = 'float32-le';
            Dint.datatype = 'float32-le';
            D2int.tf.channels = 1:size(D.tf.CM,2);         
            D2int.datatype = 'float32-le';
            D.tf.Label = 'Power';
            D2.tf.Label = 'Phase';
            Dint.tf.Label = 'Power';
            D2int.tf.Label = 'Synchrony';

        case 'Coherence'
            D.datatype = 'float32-le';
            D2.datatype = 'float32-le';
            D2.tf.channels = 1:size(D.tf.CM,2);
            if ~isempty(TimeWindow)
                D.futurSample = length(TimeWindow);
                D2.futurSample = D.futurSample;
            elseif (D.tf.Coarse > 1)
                D.futurSample = 1 + floor(D.nsamples/D.tf.Coarse);
                D2.futurSample = D.futurSample;
            end
            D.tf.Label = 'Power';
            D2.tf.Label = 'Coherence';
    end


    if (length(D.tf.channels) == 1)
        D.tf.CM = 1;
    end

    for k = 1 : D.ntrials
        try
            evt=D.events{k};
            evt2=D2.events{k};
            try
                Evt=Dint.events{k};
                Evt2=Dint.events{k};
            end
        catch
            evt=D.events;
            evt2=D2.events;
            try
                Evt=Dint.events;
                Evt2=Dint.events;
            end
        end
        switch D.tf.Method
            case 'Multitaper'
                D = ComputeMultitaper(D,k,TimeWindow,TimeWindowWidth,Pre);
            case 'Morlet wavelet'
                [D,D2,Dint,D2int] = ComputeMorlet(D,D2,Dint,D2int,k,TimeWindow,TimeWindowWidth,FlagSynchro,Pre);
            case 'Mexhat wavelet'
                D = ComputeMexhat(D,k,TimeWindow,TimeWindowWidth,Pre);
                Dint=D;
            case 'Hilbert'
                [D,D2,Dint,D2int] = ComputeHilbert(D,D2,Dint,D2int,k,TimeWindow,TimeWindowWidth,Pre);
            case 'Coherence'
                [D,D2] = ComputeCoherence(D,D2,k,TimeWindow,FlagSynchro,Pre);
        end

        D=events(D,k,evt);
        try
            D2=events(D2,k,evt2);
        end
        try
            Dint=events(Dint,k,Evt);
            D2int=events(D2int,k,Evt2);
        end
    end

    switch D.tf.Method
        case {'Morlet wavelet', 'Hilbert', 'Mexhat wavelet'}
            try
                Dint.fsample = D.fsample / D.tf.Coarse;
            end
            if isfield(Dint.tf, 'time')
                time = Dint.tf.time;
            else
                time = 0 : 1/D.fsample : (D.nsamples-1)/D.fsample;
                time = time - time(D.timeonset);
                time = time(1:D.tf.Coarse:end);
            end
            [tmp t] = min(abs(time));
            Dint = timeonset(Dint,t);

            if FlagSynchro
                try
                    D2int.fsample=D.fsample/D.tf.Coarse;
                end 
                [tmp t]=min(abs(time));
                D2int=timeonset(D2int,t);
            end
        case 'Coherence'
            if isfield(D.tf, 'time')
                time = D.tf.time;
            else
                D = fsample(D, 1 + floor(D.fsample / D.tf.Coarse));
                time = 0 : 1/D.fsample : (size(D,3)-1)/D.fsample;
                time = time-D.timeonset;
                D.tf.time = time;
            end
            [tmp t] = min(abs(time));
            D = timeonset(D,t);
            if FlagSynchro
                D2 = fsample(D2, D.fsample);
                D2 = timeonset(D2, D.timeonset);
            end
        case 'Multitaper'
            D = fsample(D,1/D.tf.TimeResolution);
            D = timeonset(D,D.tf.time(1));
    end

    
    switch D.tf.Method
        case {'Morlet wavelet', 'Hilbert'}
            save(Dint);
            if FlagSynchro
                save(D2int);
            end
        case {'Coherence','Multitaper','Mexhat wavelet'}
            save(D);
            if FlagSynchro
                save(D2);
            end
    end
    spm('Pointer', 'Arrow');
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [D,D2,Dint,D2int] = ComputeMorlet(D, D2, Dint, D2int, k, TimeWindow, TimeWindowWidth, FlagSynchro, Pre)
    try
        time = D.time;
    catch
        time = 0:1/D.fsample:(D.nsamples-1)/D.fsample;
        if (D.timeonset <= time(end))
            time = time-tD.timeonset;
        end
    end

    Coarse = 1;

    if (D.tf.FactMod > 0)
        while D.fsample/Coarse>4*max(D.tf.frequencies)*(1+1/(2*D.tf.FactMod))
            Coarse=Coarse+1;
        end
    else
        while D.fsample/Coarse>4*max(D.tf.frequencies)
            Coarse=Coarse+1;
        end
    end
    if Coarse>1
        Coarse=Coarse-1;
    end
    % Coarse=4;
    if ~isempty(TimeWindow)
        Index=find(time>=min(TimeWindow)-2&time<=max(TimeWindow)+2);
        d=D(:,Index,:);
        d=d(:,1:Coarse:end,:);
        Dsupr = clone(D, ['fichier a supprimer' D.fname], [D.nchannels size(d,2) D.ntrials]);
        Dsupr(:,:,:)=d;
        time=time(Index);
    else
        d=D(:,1:Coarse:D.nsamples,:);
        Dsupr = clone(D, ['fichier a supprimer' D.fname], [D.nchannels length(1:Coarse:D.nsamples) D.ntrials]);
        Dsupr(:,:,:)=d;
    end
    Dsupr=fsample(Dsupr,Dsupr.fsample/Coarse);
    time=time(1:Coarse:end);

    M = spm_eeg_morlet(Dsupr.tf.Mfactor, 1000/Dsupr.fsample, Dsupr.tf.frequencies);

    if FlagSynchro
        d = zeros(length(Dsupr.tf.channels), Dsupr.Nfrequencies, Dsupr.nsamples);
        try
            d2 = zeros(length(Dsupr.tf.channels), Dsupr.Nfrequencies, Dsupr.nsamples);
        end
        for j = 1 : length(Dsupr.tf.channels)
            for i = 1 : Dsupr.Nfrequencies
                tmp1=squeeze(Dsupr(Dsupr.tf.channels(j),:,k));

                if Dsupr.tf.FactMod~=0
                    FrequencyMin = Dsupr.tf.frequencies(i)*(1-1/(2*Dsupr.tf.FactMod));
                    FrequencyMax = Dsupr.tf.frequencies(i)*(1+1/(2*Dsupr.tf.FactMod));
                    tmp1 = ImaGIN_bandpass(tmp1,Dsupr.fsample,FrequencyMin,FrequencyMax);
                end

                tmp = conv(tmp1, M{i});
                % time shift to remove delay
                tmp = tmp([1:Dsupr.nsamples] + (length(M{i})-1)/2);

                % power
                d(j, i, :) = abs(tmp);

                if FlagSynchro
                    % phase
                    try
                        d2(j, i, :) = atan2(imag(tmp), real(tmp));
                    end
                end

            end
        end
        %Integration over sliding time window
        if isempty(TimeWindow)
            Dint.tf.time=time(1: Dsupr.tf.Coarse: Dsupr.nsamples);
            if FlagSynchro
                D2int.tf.time=time(1: Dsupr.tf.Coarse: Dsupr.nsamples);
            end
            if Dsupr.tf.Coarse>1
                dint=zeros(size(d,1),size(d,2),1+floor(Dsupr.nsamples/Dsupr.tf.Coarse));
                if FlagSynchro
                    d2int=zeros(size(Dsupr.tf.CM,2),size(d2,2),1+floor(Dsupr.nsamples/Dsupr.tf.Coarse));
                end
            else
                dint=zeros(size(d));
                if FlagSynchro
                    d2int=zeros(size(Dsupr.tf.CM,2),size(d2,2),size(d2,3));
                end
            end
            for i1 = 1 : Dsupr.Nfrequencies
                NBin=round(((Dsupr.tf.Width/Dsupr.tf.frequencies(i1))*Dsupr.fsample)/2);

                n=0;
                for i2 = 1 : Dsupr.tf.Coarse: Dsupr.nsamples
                    n=n+1;
                    win=max([1 i2-NBin]):min([Dsupr.nsamples i2+NBin]);

                    % power
                    dint(:, i1, n) = mean(d(:,i1,win),3);

                    if FlagSynchro
                        % synchrony
                        try
                            if ~isempty(d2int)
                                phase=squeeze(d2(Dsupr.tf.CM(1,:),i1,win)-d2(Dsupr.tf.CM(2,:),i1,win));
                                if size(phase,2)==1
                                    phase=phase';
                                end
                                d2int(:, i1, n) =  abs(mean(exp(1i*phase),2));
                            end
                        end
                    end

                end
            end
        else
            Dint.tf.time=TimeWindow;
            if FlagSynchro
                D2int.tf.time=TimeWindow;
            end
            dint=zeros(size(d,1),size(d,2),length(TimeWindow));
            if FlagSynchro
                try
                    d2int=zeros(size(Dsupr.tf.CM,2),size(d2,2),length(TimeWindow));
                catch
                    d2int=[];
                end
            end
            for i1 = 1 : Dsupr.Nfrequencies
                NBin=round(((Dsupr.tf.Width/Dsupr.tf.frequencies(i1))*Dsupr.fsample)/2);

                for i2 = 1:length(TimeWindow)

                    index=find(time>=(TimeWindow(i2)-TimeWindowWidth/2)&time<=(TimeWindow(i2)+TimeWindowWidth/2));
                    index=index(1:Dsupr.tf.Coarse:end);
                    indexphase=min(find(abs(time(index)-TimeWindow(i2))==min(abs(time(index)-TimeWindow(i2)))));

                    tmpd=zeros(size(dint,1),length(index));
                    if FlagSynchro
                        tmpd2=zeros(size(d2int,1),length(index));
                    end
                    for i3=1:length(index)
                        win=max([1 index(i3)-NBin]):min([Dsupr.nsamples index(i3)+NBin]);
                        % power
                        tmpd(:,i3)=mean(d(:,i1,win),3);
                    end
                    % power
                    dint(:, i1, i2) = mean(tmpd,2);
                    if FlagSynchro
                        % synchrony
                        if ~isempty(d2int)
                            if length(D.tf.channels)==1
                                phase=squeeze(d2(Dsupr.tf.CM,i1,index(indexphase)));
                                d2int(:, i1, i2) =  mean(phase,2);
                            else
                                for i3=1:length(index)
                                    win=max([1 index(i3)-NBin]):min([Dsupr.nsamples index(i3)+NBin]);
                                    phase=squeeze(d2(Dsupr.tf.CM(1,:),i1,win)-d2(Dsupr.tf.CM(2,:),i1,win));
                                    if size(phase,2)==1
                                        phase=phase';
                                    end
                                    tmpd2(:, i3) =  abs(mean(exp(1i*phase),2));
                                end
                                d2int(:, i1, i2) =  mean(tmpd2,2);
                            end
                        end
                    end
                end
            end
        end
    else
        d2int=[];
        if isempty(TimeWindow)
            Dint.tf.time=time(1: Dsupr.tf.Coarse: Dsupr.nsamples);
            if Dsupr.tf.Coarse>1
                dint=zeros(length(Dsupr.tf.channels),Dsupr.Nfrequencies,1+floor(Dsupr.nsamples/Dsupr.tf.Coarse));
            else
                dint=zeros(length(Dsupr.tf.channels),Dsupr.Nfrequencies, Dsupr.nsamples);
            end
        else
            if Dsupr.tf.Width>0
                Dint.tf.time=TimeWindow;
                dint=zeros(length(Dsupr.tf.channels),Dsupr.Nfrequencies,length(TimeWindow));
            else
                win=find(time>=min(TimeWindow)&time<=max(TimeWindow));
                CoarseTime=1;
                while time(win(1+CoarseTime))-time(win(1))<Dsupr.tf.TimeResolution
                    CoarseTime=CoarseTime+1;
                end
                CoarseTime=CoarseTime-1;
                win=win(1:CoarseTime:end);
                Dint.tf.time=time(win);
                dint=zeros(length(Dsupr.tf.channels),Dsupr.Nfrequencies,length(win));            
            end
        end
        for j = 1 : length(Dsupr.tf.channels)
            for i = 1 : Dsupr.Nfrequencies
                NBin=round(((Dsupr.tf.Width/Dsupr.tf.frequencies(i))*Dsupr.fsample)/2);

                tmp1=squeeze(Dsupr(Dsupr.tf.channels(j),:,k));

                Edge=round(0.5*Dsupr.fsample);
                Fen1=hanning(Edge*2);
                Fen=[Fen1(1:Edge)' ones(1,length(tmp1)-Edge*2) Fen1(Edge+1:2*Edge)'];
                tmp1=tmp1.*Fen; 

                if Dsupr.tf.FactMod~=0
                    FrequencyMin = Dsupr.tf.frequencies(i)*(1-1/(2*Dsupr.tf.FactMod));
                    FrequencyMax = Dsupr.tf.frequencies(i)*(1+1/(2*Dsupr.tf.FactMod));
                    tmp1=ImaGIN_bandpass(tmp1,Dsupr.fsample,FrequencyMin,FrequencyMax);
                end

                tmp = conv(tmp1, M{i});
                % time shift to remove delay
                tmp = tmp((1:Dsupr.nsamples) + (length(M{i})-1)/2);

                d = abs(tmp);

                if isempty(TimeWindow)
                    n=0;
                    for i2 = 1 : Dsupr.tf.Coarse: Dsupr.nsamples
                        n=n+1;
                        win=max([1 i2-NBin]):min([Dsupr.nsamples i2+NBin]);

                        % power
                        dint(j, i, n) = mean(d(win));
                    end
                else
                    if Dsupr.tf.Width>0
                        for i2 = 1:length(TimeWindow)
                            win=find(time>=(TimeWindow(i2)-TimeWindowWidth/2)&time<=(TimeWindow(i2)+TimeWindowWidth/2));
                            win=win(1:Dsupr.tf.Coarse:end);

                            % power
                            dint(j, i, i2) = mean(d(win));
                        end
                    else
                        dint(j, i, :)=d(win);
                    end
                end
            end
        end
    end

    % Remove baseline over frequencies and trials
    if Dsupr.tf.rm_baseline == 1
        if Dsupr.tf.Coarse>1
            Dint.tf.Sbaseline=1+floor(Dsupr.tf.Sbaseline/Dsupr.tf.Coarse);
            if FlagSynchro
                D2int.tf.Sbaseline=1+floor(Dsupr.tf.Sbaseline/Dsupr.tf.Coarse);
            end
        end
        d = ImaGIN_spm_eeg_bc(D, d);
        dint = ImaGIN_spm_eeg_bc(Dint, dint);
        if FlagSynchro
            if ~isempty(d2int)
                d2int = ImaGIN_spm_eeg_bc(D2int, d2int);
            end
        end
    end

    if k==1
        fnamedat=['w1_' Pre '_' Dint.fname];
    else
        fnamedat=Dint.fname;
    end
    Dint=clone(Dint,  fnamedat, [length(Dint.tf.channels) size(dint,2) size(dint,3) Dint.ntrials]);
    Dint(:,:,:,k)=dint;
    Dint= Dint.frequencies(:, Dint.tf.frequencies);

    if FlagSynchro
        if isempty(D2int.tf.channels)
            D2int.tf.channels=1:size(d2int,1)
        end
        if ~isempty(d2int)
            if k==1
                fnamedat=['w2_' Pre '_' D2int.fname];
            else
                fnamedat=D2int.fname;
            end
            D2int=clone(D2int, fnamedat, [length(D2int.tf.channels) size(d2int,2) size(d2int,3) D2int.ntrials]);
            D2int(:,:,:,k)=d2int;
            D2int = D2int.frequencies(:, D2int.tf.frequencies);
        end
    end
    try
        delete(Dsupr);
    end
    spm('Pointer', 'Arrow'); drawnow;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Dint = ComputeMexhat(D,k,TimeWindow,TimeWindowWidth,Pre)
    try
        time=D.time;
    catch
        time=0:1/D.fsample:(D.nsamples-1)/D.fsample;
        if D.timeonset<=time(end)
            time=time-tD.timeonset;
        end
    end

    Coarse=1;
    if D.tf.FactMod>0
        while D.fsample/Coarse>4*max(D.tf.frequencies)*(1+1/(2*D.tf.FactMod))
            Coarse = Coarse+1;
        end
    else
        while D.fsample/Coarse>4*max(D.tf.frequencies)
            Coarse = Coarse+1;
        end
    end
    if Coarse>1
        Coarse = Coarse-1;
    end
    if ~isempty(TimeWindow)
        Index = find(time>=min(TimeWindow)-2&time<=max(TimeWindow)+2);
        d = D(:,Index,:);
        d = d(:,1:Coarse:end,:);
        time = time(Index);
    else
        d = D(:,1:Coarse:D.nsamples,:);
    end
    fsamplenew = fsample(D)/Coarse;
    nsamplenew = size(d,2);
    time = time(1:Coarse:end);

    M = ImaGIN_mexhat(fsamplenew, D.tf.frequencies);

    if isempty(TimeWindow)
        Dint.tf.time = time(1: D.tf.Coarse: nsamplenew);
        if D.tf.Coarse>1
            dint = zeros(length(D.tf.channels),D.Nfrequencies,1+floor(nsamplenew/D.tf.Coarse));
        else
            dint = zeros(length(D.tf.channels),D.Nfrequencies, nsamplenew);
        end
    else
        if D.tf.Width>0
            Dint.tf.time = TimeWindow;
            dint = zeros(length(D.tf.channels),D.Nfrequencies,length(TimeWindow));
        else
            win=find(time>=min(TimeWindow)&time<=max(TimeWindow));
            CoarseTime=1;
            while time(win(1+CoarseTime))-time(win(1))<D.tf.TimeResolution
                CoarseTime=CoarseTime+1;
            end
            CoarseTime=CoarseTime-1;
            win=win(1:CoarseTime:end);
            Dint.tf.time=time(win);
            dint=zeros(length(D.tf.channels),D.Nfrequencies,length(win));
        end
    end
    for j = 1 : length(D.tf.channels)
        for i = 1 : D.Nfrequencies
            tmp1=squeeze(D(D.tf.channels(j),:,k));

            Edge=round(0.5*fsamplenew);
            Fen1=hanning(Edge*2);
            Fen=[Fen1(1:Edge)' ones(1,length(tmp1)-Edge*2) Fen1(Edge+1:2*Edge)'];
            tmp1=tmp1.*Fen;

            if D.tf.FactMod~=0
                FrequencyMin = D.tf.frequencies(i)*(1-1/(2*D.tf.FactMod));
                FrequencyMax = D.tf.frequencies(i)*(1+1/(2*D.tf.FactMod));
                tmp1=ImaGIN_bandpass(tmp1,fsamplenew,FrequencyMin,FrequencyMax);
            end

            tmp = conv(tmp1, M{i});
            % time shift to remove delay
            tmp = tmp((1:nsamplenew) + (length(M{i})-1)/2);

            d = abs(hilbert(tmp));

            if isempty(TimeWindow)
                NBin=floor(TimeWindowWidth/(time(D.tf.Coarse+1)-time(1)))+1;
                n=0;
                for i2 = 1 : D.tf.Coarse: nsamplenew
                    n=n+1;
                    win=max([1 i2-NBin]):min([nsamplenew i2+NBin]);

                    % power
                    dint(j, i, n) = mean(d(win));
                end
            else
                if D.tf.Width>0
                    for i2 = 1:length(TimeWindow)
                        win=find(time>=(TimeWindow(i2)-TimeWindowWidth/2)&time<=(TimeWindow(i2)+TimeWindowWidth/2));
                        win=win(1:D.tf.Coarse:end);

                        % power
                        dint(j, i, i2) = mean(d(win));
                    end
                else
                    dint(j, i, :)=d(win);
                end
            end
        end
    end

    if (k == 1)
        fnamedat = ['x1_' Pre '_' D.fname];
    else
        fnamedat = D.fname;
    end
    Dint = clone(D,  fnamedat, [length(D.tf.channels) size(dint,2) size(dint,3) D.ntrials]);
    Dint(:,:,:,k) = dint;
    Dint = Dint.frequencies(:, Dint.tf.frequencies);
    Dint.tf.time = time(1: D.tf.Coarse: nsamplenew);

    spm('Pointer', 'Arrow'); drawnow;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function D = ComputeMultitaper(D, k, TimeWindow, TimeWindowWidth, Pre)
    try
        time=D.time;
    catch
        time=0:1/D.fsample:(D.nsamples-1)/D.fsample;
        if D.timeonset<=time(end)
            time=time-D.timeonset;
        end
    end

    Coarse=1;
    if D.tf.FactMod>0
        while D.fsample/Coarse>4*max(D.tf.frequencies)*(1+1/(2*D.tf.FactMod))
            Coarse=Coarse+1;
        end
    else
        while D.fsample/Coarse>4*max(D.tf.frequencies)
            Coarse=Coarse+1;
        end
    end
    if Coarse>1
        Coarse=Coarse-1;
    end
    if ~isempty(TimeWindow)
        Index=find(time>=min(TimeWindow)-TimeWindowWidth/2&time<=max(TimeWindow)+TimeWindowWidth/2);
        d=D(:,Index,:);
        d=d(:,1:Coarse:end,:);
        time=time(Index);
    else
        d=D(:,1:Coarse:D.nsamples,:);
    end
    time=time(1:Coarse:end);

    clear S
    S.taper='dpss';
    S.taper='hanning';
    S.taper=lower(D.tf.Taper);
    S.timeres=1e3*TimeWindowWidth;
    S.frequencies=D.tf.frequencies;
    S.freqres=D.tf.frequencies/D.tf.FactMod;
    S.freqres(find(S.freqres<1/TimeWindowWidth))=1/TimeWindowWidth;
    S.timestep=1000*D.tf.TimeResolution;

    % Correct the time step to the closest multiple of the sampling interval to keep the time axis uniform
    fsampletrue = 1./diff(time(1:2));
    timesteptrue = 1e3*round(fsampletrue*S.timestep*1e-3)/fsampletrue;

    timeoi=(1e3*time(1)+(S.timeres/2)):timesteptrue:(1e3*time(end)-(S.timeres/2)-1e3/fsample(D)); % Time axis
    timeoi=1e3*unique(round(1e-3*timeoi .* fsampletrue) ./ fsampletrue);
    Nt=ceil(length(timeoi)/D.tf.NSegments);
    for i1=1:D.tf.NSegments
        win=find(abs(time+(1e-3*S.timeres/2)-1e-3*timeoi((i1-1)*Nt+1))==min(abs(time+(1e-3*S.timeres/2)-1e-3*timeoi((i1-1)*Nt+1)))):...
            find(abs(time-(1e-3*S.timeres/2)-1/fsample(D)-1e-3*timeoi(min([Nt*i1 length(timeoi)])))==min(abs(time-(1e-3*S.timeres/2)-1/fsample(D)-1e-3*timeoi(min([Nt*i1 length(timeoi)])))));
        tmp = spm_eeg_specest_mtmconvol(S, d(D.tf.channels,win), time(win));
        if i1==1
            res = tmp;
        else
            res.fourier=cat(3,res.fourier,tmp.fourier);
            res.time=[res.time tmp.time];
        end
    end

    try
        d=res.pow;
    catch
        d=abs(res.fourier);
    end
    D.tf.time=1e-3*timeoi;

    % interpolate in case of several segments (just to be sure)
    if D.tf.NSegments>1
        dinit=d;
        d=zeros(length(D.tf.channels),length(D.tf.frequencies),length(D.tf.time),D.ntrials);
        [x,y]=meshgrid(res.time,D.tf.frequencies);
        [xi,yi]=meshgrid(D.tf.time,D.tf.frequencies);

        for i1=1:length(D.tf.channels)
            for k=1:D.ntrials
                d(i1,:,:,k)=interp2(x,y,squeeze(dinit(i1,:,:,k)),xi,yi);
                tmp=find(isnan(sum(squeeze(d(i1,:,:,k)),1)));
                for i2=1:length(tmp)
                    try
                        d(i1,:,tmp(i2),k)=d(i1,:,tmp(i2)-1,k);
                    catch
                        d(i1,:,tmp(i2),k)=d(i1,:,tmp(i2)+1,k);
                    end
                end
            end
        end
    end

    % Remove baseline over frequencies and trials
    if D.tf.rm_baseline == 1
        d = ImaGIN_spm_eeg_bc(D, d);
    end

    if (k == 1)
        fnamedat = ['m1_' Pre '_' D.fname];
    else
        fnamedat = D.fname;
    end
    D = clone(D, fnamedat, [length(D.tf.channels) D.Nfrequencies size(d,3) D.ntrials]);
    D(:,:,:,k) = d;
    D = D.frequencies(:, D.tf.frequencies);

    spm('Pointer', 'Arrow');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [D,D2,Dint,D2int] = ComputeHilbert(D, D2, Dint, D2int, k, TimeWindow, TimeWindowWidth, Pre)
    d = zeros(length(D.tf.channels), D.Nfrequencies, D.nsamples);
    d2 = zeros(length(D.tf.channels), D.Nfrequencies, D.nsamples);

    for j = 1 : length(D.tf.channels)
        for i = 1 : D.Nfrequencies
            tmp1=squeeze(D(D.tf.channels(j),:,k));

            if D.tf.FactMod~=0
                FrequencyMin = D.tf.frequencies(i)*(1-1/(2*D.tf.FactMod));
                FrequencyMax = min([D.fsample/2 D.tf.frequencies(i)*(1+1/(2*D.tf.FactMod))]);
                tmp1=ImaGIN_bandpass(tmp1,D.fsample,FrequencyMin,FrequencyMax);
            end

            tmp=hilbert(tmp1);

            % power
            d(j, i, :) = abs(tmp);
            % phase
            d2(j, i, :) = atan2(imag(tmp), real(tmp));
        end
    end

    % Integration over sliding time window
    if isempty(TimeWindow)
        if D.tf.Coarse>1
            dint=zeros(size(d,1),size(d,2),1+floor(D.nsamples/D.tf.Coarse));
            d2int=zeros(size(D.tf.CM,2),size(d2,2),1+floor(D.nsamples/D.tf.Coarse));
        else
            dint=zeros(size(d));
            d2int=zeros(size(D.tf.CM,2),size(d2,2),size(d2,3));
        end
        for i1 = 1 : D.Nfrequencies

            disp([i1 D.Nfrequencies])

            NBin=round(((D.tf.Width/D.tf.frequencies(i1))*D.fsample)/2);

            n=0;
            for i2 = 1 : D.tf.Coarse: D.nsamples
                n=n+1;
                win=max([1 i2-NBin]):min([D.nsamples i2+NBin]);

                % power
                dint(:, i1, n) = mean(d(:,i1,win),3);

                % synchrony
                phase=squeeze(d2(D.tf.CM(1,:),i1,win)-d2(D.tf.CM(2,:),i1,win));
                if size(phase,2)==1
                    phase=phase';
                end
                d2int(:, i1, n) =  abs(mean(exp(1i*phase),2));
            end
        end
    else
        time=0:1/D.fsample:(D.nsamples-1)/D.fsample;
        time=time-time(D.TimeZero);
        Dint.tf.time=TimeWindow;
        D2int.tf.time=TimeWindow;
        dint=zeros(size(d,1),size(d,2),length(TimeWindow));
        d2int=zeros(size(D.tf.CM,2),size(d2,2),length(TimeWindow));
        for i1 = 1 : D.Nfrequencies

            NBin=round(((D.tf.Width/D.tf.frequencies(i1))*D.fsample)/2);

            for i2 = 1:length(TimeWindow)

                index=find(time>=(TimeWindow(i2)-TimeWindowWidth/2)&time<=(TimeWindow(i2)+TimeWindowWidth/2));
                index=index(1:D.tf.Coarse:end);

                tmpd=zeros(size(dint,1),length(index));
                tmpd2=zeros(size(d2int,1),length(index));
                for i3=1:length(index)
                    win=max([1 index(i3)-NBin]):min([D.nsamples index(i3)+NBin]);
                    % power
                    tmpd(:,i3)=mean(d(:,i1,win),3);
                    % synchrony
                    phase=squeeze(d2(D.tf.CM(1,:),i1,win)-d2(D.tf.CM(2,:),i1,win));
                    if size(phase,2)==1
                        phase=phase';
                    end
                    tmpd2(:, i3) =  abs(mean(exp(1i*phase),2));
                end

                % power
                dint(:, i1, i2) = mean(tmpd,2);
                % synchrony
                d2int(:, i1, i2) =  mean(tmpd2,2);

            end
        end
    end
    Dint.nsamples=size(dint,3);
    D2int.nsamples=size(d2int,3);

    % Remove baseline over frequencies and trials
    if (D.tf.rm_baseline == 1)
        if D.tf.Coarse>1
            Dint.tf.Sbaseline=1+floor(D.tf.Sbaseline/D.tf.Coarse);
            D2int.tf.Sbaseline=1+floor(D.tf.Sbaseline/D.tf.Coarse);
        end
        dint = ImaGIN_spm_eeg_bc(Dint, dint);
        d2int = ImaGIN_spm_eeg_bc(D2int, d2int);
    end

    Dint = clone(Dint,  ['h1_' Pre sprintf('trial %d ',k) Dint.fname], [length(Dint.tf.channels) Dint.Nfrequencies size(dint,3)]);
    Dint(:,:,:) = dint;

    if FlagSynchro
        if isempty(D2int.tf.channels)
            D2int.tf.channels = 1:size(d2int,1);
        end
        if ~isempty(d2int)
            D2int=clone(D2int, ['h2_' Pre sprintf('trial %d ',k) D2int.fname], [length(D2int.tf.channels) D2int.Nfrequencies size(d2int,3)]);
            D2int(:,:,:)=d2int;

        end
    end

    spm('Pointer', 'Arrow'); drawnow;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [D, D2] = ComputeCoherence(D, D2, k, TimeWindow, FlagSynchro, Pre)
    %Integration over sliding time window
    d=zeros(length(D.tf.channels),D.Nfrequencies,D.futurSample);
    if FlagSynchro
        try
            d2=zeros(size(D.tf.CM,2),D.Nfrequencies,D.futurSample);
        end
    end

    NBin = round(D.tf.Width*D.fsample);
    Ntime = D.nsamples;

    % power
    if isempty(TimeWindow)
        time=1:D.tf.Coarse:Ntime;
        for j = 1 : length(D.tf.channels)
            tmp1=squeeze(D(D.tf.channels(j),:,k));
            for i2 = 1 : 1+floor(D.tf.Coarse/D.fsample): 1+floor(Ntime/D.tf.Coarse)
                win=max([1 i2-NBin]):min([Ntime i2+NBin]);
                if length(win)~=NBin
                    if win(1)==1
                        win=1:NBin;
                    elseif win(end)==length(time)
                        win=1:NBin-NBin+length(time);
                    else
                        wintmp=[win [win(end)+1:win(end)+NBin-length(win)]];
                        if wintmp(end)>length(time)
                            wintmp=[[win(1)-(NBin-length(win)):win(1)-1] win];
                        end
                        win=wintmp;
                    end
                end
                tmp = sqrt(pwelch(tmp1(win).*hanning(length(win))',D.tf.nfft,D.fsample,[],[],0,'squared'));
                tmp=tmp(D.tf.frequenciesIndex);
                d(j, :, i2) = tmp;
            end
        end
        if FlagSynchro
            for j = 1 : length(D2.tf.channels)
                tmp1=D(D.tf.CM(1,j),:);
                tmp2=D(D.tf.CM(2,j),:);
                n=0;
                for i2 = 1 : 1+floor(D.tf.Coarse/D.fsample): 1+floor(Ntime/D.tf.Coarse)
                    n = n+1;
                    win = max([1 i2-NBin]):min([Ntime i2+NBin]);
                    if length(win)~=NBin
                        if win(1)==1
                            win = 1:NBin;
                        elseif win(end)==length(time)
                            win = 1:NBin-NBin+length(time);
                        else
                            wintmp = [win, win(end)+1:win(end)+NBin-length(win)];
                            if wintmp(end)>length(time)
                                wintmp = [win(1)-(NBin-length(win)):win(1)-1, win];
                            end
                            win=wintmp;
                        end
                    end
                    tmp = cohere(tmp1(win).*hanning(length(win))',tmp2(win).*hanning(length(win))',D.tf.nfft,D.fsample,[],[],0,'squared');
                    tmp = tmp(D.tf.frequenciesIndex);
                    d2(j, :, n) = tmp;
                end
            end
        end
    else
        time=0:1/D.fsample:(Ntime-1)/D.fsample;
        time=time+D.timeonset;
        for j = 1 : length(D.tf.channels)
            tmp1=squeeze(D(D.tf.channels(j),:,k));
            for i2 = 1:length(TimeWindow)
                win=find(time>=(TimeWindow(i2)-D.tf.Width/2)&time<=(TimeWindow(i2)+D.tf.Width/2));
                if length(win)~=NBin
                    if win(1)==1
                        win=1:NBin;
                    elseif win(end)==length(time)
                        win=1:NBin-NBin+length(time);
                    else
                        wintmp=[win, win(end)+1:win(end)+NBin-length(win)];
                        if wintmp(end)>length(time)
                            wintmp=[win(1)-(NBin-length(win)):win(1)-1, win];
                        end
                        win=wintmp;
                    end
                end          
                tmp = sqrt(pwelch(tmp1(win).*hanning(length(win))',D.tf.nfft,D.fsample,[],[],0,'squared'));
                tmp = tmp(D.tf.frequenciesIndex);
                d(j, :, i2) = tmp;
            end
        end
        D.tf.time = TimeWindow;
        if FlagSynchro
            for j = 1 : length(D2.tf.channels)
                tmp1=D(D.tf.CM(1,j),:);
                tmp2=D(D.tf.CM(2,j),:);
                for i2 = 1:length(TimeWindow)
                    win=find(time>=(TimeWindow(i2)-D.tf.Width/2)&time<=(TimeWindow(i2)+D.tf.Width/2));
                    if length(win)~=NBin
                        if win(1)==1
                            win=1:NBin;
                        elseif win(end)==length(time)
                            win=1:NBin-NBin+length(time);
                        else
                            wintmp=[win [win(end)+1:win(end)+NBin-length(win)]];
                            if wintmp(end)>length(time)
                                wintmp=[[win(1)-(NBin-length(win)):win(1)-1] win];
                            end
                            win=wintmp;
                        end
                    end
                    tmp = cohere(tmp1(win).*hanning(length(win))',tmp2(win).*hanning(length(win))',D.tf.nfft,D.fsample,[],[],0,'squared');
                    tmp = tmp(D.tf.frequenciesIndex);
                    d2(j, :, i2) = tmp;
                end
            end
            D2.tf.time=TimeWindow;
        end
    end

    % Remove baseline over frequencies and trials
    if D.tf.rm_baseline == 1
        d = ImaGIN_spm_eeg_bc(D, d);
        if FlagSynchro
            d2 = ImaGIN_spm_eeg_bc(D2, d2);
        end
    end

    if (k == 1)
        fnamedat=['c1_' Pre '_' D.fname];
    else
        fnamedat=D.fname;
    end
    D = clone(D, fnamedat, [length(D.tf.channels) D.Nfrequencies size(d,3) D.ntrials]);
    D(:,:,:,k) = d;
    D = D.frequencies(:, D.tf.frequencies);

    if FlagSynchro
        if k==1
            fnamedat=['c2_' Pre '_' D2.fname];
        else
            fnamedat=D2.fname;
        end
        D2 = clone(D2, fnamedat, [length(D2.tf.channels) D2.Nfrequencies size(d2,3) D2.ntrials]);
        D2(:,:,:,k)=d2;
        D2 = D2.frequencies(:, D2.tf.frequencies);
    end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function CM = ConnectivityMatrix(N)
    ncouple	= N*(N-1)/2;
    if ncouple>0
        CM	= zeros(2,ncouple);
        cou	= 0;
        for ii	= 1:N-1
            j	= ii+1;
            cou	= cou+1;
            CM(1,cou)	= ii;
            CM(2,cou)	= j;
            while j < N
                j	= j+1;
                cou	= cou+1;
                CM(1,cou)	= ii;
                CM(2,cou)	= j;
            end
        end
    else
        CM=[];
    end
end



