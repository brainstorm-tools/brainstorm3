function ImaGIN_Epileptogenicity(S)
% Compute epileptogenicity using time-windowed fft
%
% USAGE:   D = ImaGIN_Epileptogenicity(S)

% -=============================================================================
% This function is part of the ImaGIN software: 
% https://f-tract.eu/
%
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
%
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE AUTHORS
% DO NOT ASSUME ANY LIABILITY OR RESPONSIBILITY FOR ITS USE IN ANY CONTEXT.
%
% Copyright (c) 2000-2018 Inserm U1216
% =============================================================================-
%
% Authors: Olivier David
%          Francois Tadel, 2017


%% ===== INPUTS =====
warning off
NameEpileptogenicity='EI';
spm('defaults', 'EEG');

try
    DD = S.D;
catch
    DD = spm_select(inf, '\.mat$', 'Select EEG mat file');
end
try
    BB = S.B;
catch
    BB = spm_select(inf, '\.mat$', 'Select Baseline EEG mat file');
end

try
    latency = S.Latency;
catch
    latency = spm_input('Peri-onset time [s]', 1, 'r', 0:4:20, inf);
end
latency=transpose(latency(:));

try
    FreqBand = S.FreqBand;
catch
    FreqBand = spm_input('Frequency Band [Hz]', '+1', 'r', [60 100], 2);
end

try
    OutputType = S.OutputType;
catch
    OutputType = spm_input('Type of output', '+1', 'Surface|Volume');
end

switch lower(OutputType)
    case 'volume'
        try
            Atlas = S.Atlas;
        catch
            str   = 'Select atlas';
            Atlas = spm_input(str, '+1','Human|Rat|Mouse|PPN');
        end

        try
            CorticalMesh = S.CorticalMesh;
        catch
            str   = 'Use cortical mesh ';
            str=spm_input(str, '+1','Yes|No');
            if strcmp(str,'Yes')
                CorticalMesh = 1;
            else
                CorticalMesh = 0;
            end
        end

        if CorticalMesh
            try
                sMRI = S.sMRI;
            catch
                sMRI = spm_select(Inf, 'image', 'Select MRI');
            end
            % Surface: If not in input, will compute it (SPM canonical)
            try 
                MeshFile = S.MeshFile;
            catch
                MeshFile = [];
            end
        else
            MeshFile = [];
        end
        % Output extension
        outExt = '.nii';
        strSelectVol = ',1';
        SmoothIterations = [];
        
    case 'surface'
        try 
            MeshFile = S.MeshFile;
        catch
            MeshFile = spm_select(1, '\.gii$', 'Select cortex surface');
        end
        try
            SmoothIterations = S.SmoothIterations;
        catch
            SmoothIterations = spm_input('Smoothing parameter', '+1', 'r', 5);
        end
        % Output extension
        outExt = '.gii';
        strSelectVol = '';
end

try
    Horizon = S.HorizonT;
catch
    Horizon = spm_input('Mesoscopic time scale [s]', '+1', 'r', 4, 1);
end

try
    TimeResolution = S.TimeResolution;
catch
    TimeResolution = spm_input('Time resolution [s]', '+1', 'r', 0.2, 1);
end

try
    ThDelay = S.ThDelay;
catch
    ThDelay = spm_input('Propagation threshold (p or T)', '+1', 'r', 0.05, 1);
end

try
    AR = S.AR;
catch
    tmp = spm_input('AR correction', '+1', 'Yes|No');
    if strcmp(tmp,'Yes')
        AR = 1;
    else
        AR = 0;
    end
end

try
    FileName=S.FileName;
catch
    FileName = spm_input('File name', '+1', 's');
end

% Volume resolution
VolRes = 3;
SaveMNI = 0;

% Find common Channels and define as bad the missing ones over files
N = zeros(1,size(DD,1));
Labels = cell(1,size(DD,1));
BadChannel = cell(1,size(DD,1));
for i0 = 1:size(DD,1)
    D = spm_eeg_load(deblank(DD(i0,:)));
    Labels{i0} = chanlabels(D);
    N(i0) = length(Labels{i0});
    BadChannel{i0} = badchannels(D);
end
L = zeros(size(DD,1),max(N));
for i0=1:size(DD,1)
    tmp=setdiff(1:size(DD,1),i0);
    for i1=1:length(Labels{i0})
        for i2=tmp
            for i3=1:length(Labels{i2})
                if strcmp(Labels{i0}(i1),Labels{i2}(i3))
                    L(i0,i1)=L(i0,i1)+1;
                end
            end
        end
    end
end
M = max(L(:));
for i0=1:size(DD,1)
    BadChannel{i0} = unique([BadChannel{i0} find(L(i0,:)<M)]);
    BadChannel{i0} = BadChannel{i0}(find(BadChannel{i0}<=N(i0)));
end

% Load cortex mesh
if ~isempty(MeshFile)
    giiCortex = gifti(MeshFile);
else
    giiCortex = [];
end


%% ===== EPILEPTOGENICITY MAPS =====
for i00 = 1:size(latency, 2)

    Latency = mean(latency(:,i00));
    
    % ===== PROCESS EACH FILE SEPARATELY =====
    for i0 = 1:size(DD,1)
        if (length(Horizon) == 1)
            TimeWindow = 0 : TimeResolution : Horizon+1+max(latency(:));
        elseif (length(Horizon) > 1)
            TimeWindow = 0 : TimeResolution : Horizon(i0)+1+max(latency(:));
        end
        
        % Load seizure
        D = spm_eeg_load(deblank(DD(i0,:)));
        P = spm_str_manip(deblank(DD(i0,:)),'h');
        cd(P)
        % Load baseline
        B = spm_eeg_load(deblank(BB(i0,:)));
        timebaseline = time(B);
        TimeWindowBaseline = timebaseline(1) : (TimeWindow(2)-TimeWindow(1)) : (timebaseline(end)-1);
        
        % Compute power using multitaper
        try
            DPower = spm_eeg_load(fullfile(D.path,['m1_' SS.Pre '_' D.fname]));
            DPowerBaseline = spm_eeg_load(fullfile(B.path,['m1_' SS.Pre '_' B.fname]));
        catch
            % Compute seizure power
            clear SS
            SS.D               = deblank(DD(i0,:));
            SS.Pre             = ['Epi_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' FileName];
            SS.Method          = 'Multitaper';
            SS.TimeResolution  = TimeResolution;
            SS.frequencies     = min(FreqBand):max(FreqBand);
            SS.TimeWindow      = [min(TimeWindow), max(TimeWindow)];
            SS.TimeWindowWidth = 1;
            SS.channels        = 1:D.nchannels;
            SS.FactMod         = 10;
            SS.NSegments       = 1;
            SS.Taper           = 'hanning';
            ImaGIN_spm_eeg_tf(SS);
            % Load seizure output
            DPower = spm_eeg_load(fullfile(D.path,['m1_' SS.Pre '_' D.fname]));
            % Compute baseline power
            SSB = SS;
            SSB.D = deblank(BB(i0,:));
            SSB.TimeWindow = TimeWindowBaseline;
            ImaGIN_spm_eeg_tf(SSB);
            % Load baseline output
            DPowerBaseline = spm_eeg_load(fullfile(B.path,['m1_' SSB.Pre '_' B.fname]));
%             SS2.D = fullfile(D.path,['m1_' SS.Pre '_' D.fname]);
%             SS2.B = fullfile(B.path,['m1_' SSB.Pre '_' B.fname]);
%             ImaGIN_NormaliseTF(SS2);
        end

        % Find frequency band
        IndexFreq1 = min(find(DPower.frequencies>=min(FreqBand))):max(find(DPower.frequencies<=max(FreqBand)));
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
% OD-Nov 2017: Attempt to select only the frequencies with the highest power.
% Issues: - Different latencies are processed with different frequency bands
%         - Frequency selection is different from what is explored in the time-frequency maps
%
%         % Compute power within frequencies of interest
%         [Epitmp,order] = sort(mean(DPower(:,IndexFreq1,:),3),2);
%         Epileptogenicity = squeeze(mean(DPower(:,IndexFreq1,:),2));
%         for i1 = 1:size(Epileptogenicity,1)
%             Epileptogenicity(i1,:) = squeeze(mean(DPower(i1,order(i1,floor(0.75*size(order,2)):end),:),2));
%         end
%         EpileptogenicityBaseline = squeeze(mean(DPowerBaseline(:,IndexFreq1,:),2));
%         for i1 = 1:size(EpileptogenicityBaseline,1)
%             EpileptogenicityBaseline(i1,:) = squeeze(mean(DPowerBaseline(i1,order(i1,floor(0.75*size(order,2)):end),:),2));
%         end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ORIGINAL BLOCK
        % Get power for seizure and baselines
        Power = DPower(:,IndexFreq1,:);
        PowerBaseline = DPowerBaseline(:,IndexFreq1,:);
        % Compute average power within frequencies of interest
        Epileptogenicity = squeeze(mean(Power,2));
        EpileptogenicityBaseline = squeeze(mean(PowerBaseline,2));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Replace bad channels with NaN
        if ~isempty(BadChannel{i0})
            Epileptogenicity(BadChannel{i0},:) = NaN;
            EpileptogenicityBaseline(BadChannel{i0},:) = NaN;
        end
        Epileptogenicity = log(Epileptogenicity);
        EpileptogenicityBaseline = log(EpileptogenicityBaseline);
        % Add offset to have only positive values as for fMRI (otherwise problem with globals calculation)
        tmp = min([Epileptogenicity(:);EpileptogenicityBaseline(:)]);
        Epileptogenicity = Epileptogenicity-tmp;
        EpileptogenicityBaseline = EpileptogenicityBaseline-tmp;

        % Save Log Power: Seizure
        D1 = clone(D, [FileName spm_str_manip(D.fname,'s') '_' NameEpileptogenicity '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency))) '.mat'],[D.nchannels size(Epileptogenicity,2) 1]);
        D1(:,:,:) = Epileptogenicity;
        D1 = fsample(D1,1/(DPower.tf.time(2)-DPower.tf.time(1)));
        D1 = timeonset(D1,min(DPower.tf.time));
        save(D1);
        % Save Log Power: Baseline
        D1 = clone(B, [FileName spm_str_manip(D.fname,'s') '_' NameEpileptogenicity 'Baseline_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency))) '.mat'],[B.nchannels size(EpileptogenicityBaseline,2) 1]);
        D1(:,:,:) = EpileptogenicityBaseline;
        D1 = fsample(D1,1/(DPowerBaseline.tf.time(2)-DPowerBaseline.tf.time(1)));
        D1 = timeonset(D1,min(DPowerBaseline.tf.time));
        save(D1);
        
        % Write 3D images of log power for statistics
        clear SS
        try
            SS.TimeWindow = latency(i0,i00) + (0:TimeResolution:Horizon);
        catch
            SS.TimeWindow = Latency + (0:TimeResolution:Horizon);
        end
        SS.MeshFile = MeshFile;
        SS.TimeWindowWidth = 0;
        SS.SizeHorizon = 10;
        dirSeizure  = fullfile(P,[FileName spm_str_manip(D.fname,'s') '_' NameEpileptogenicity '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]);
        dirBaseline = fullfile(P,[FileName spm_str_manip(D.fname,'s') '_' NameEpileptogenicity 'Baseline_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]);
        % Save volume (.nii) or surface (.gii)
        switch lower(OutputType)
            case 'volume'
                % Define volume options
                SS.n = VolRes;
                SS.interpolate_bad = 0;
                SS.SizeSphere = 5;
                SS.CorticalMesh = CorticalMesh;
                if CorticalMesh
                    SS.sMRI = sMRI;
                end
                SS.Atlas = Atlas;
                SS.SaveMNI = 0;
                % Save seizure files
                if isdir(dirSeizure)
                    cd(P)
                    rmdir(dirSeizure,'s')
                end
                SS.Fname = dirSeizure;
                ImaGIN_spm_eeg_convertmat2ana_3D(SS);
                % Save baseline files
                SS.TimeWindow = min(DPowerBaseline.tf.time):TimeResolution:max(DPowerBaseline.tf.time);
                if isdir(dirBaseline)
                    cd(P)
                    rmdir(dirBaseline,'s')
                end
                SS.Fname = dirBaseline;
                ImaGIN_spm_eeg_convertmat2ana_3D(SS);
                
                % Smooth images to get Gaussian fields
                [files,dirs] = spm_select('List', dirSeizure, outExt);
                for i1=1:size(files,1)
                    tmp=deblank(files(i1,:));
                    Q = fullfile(dirSeizure, tmp);
                    clear matlabbatch
                    matlabbatch{1}.spm.spatial.smooth.data = {[Q ',1']};
                    matlabbatch{1}.spm.spatial.smooth.fwhm = [5 5 5];
                    matlabbatch{1}.spm.spatial.smooth.dtype = 0;
                    matlabbatch{1}.spm.spatial.smooth.im = 1;
                    matlabbatch{1}.spm.spatial.smooth.prefix = 's';
                    % spm('defaults', 'EEG');
                    spm_jobman('run', matlabbatch);
                    movefile(fullfile(dirSeizure, ['s' tmp]), fullfile(dirSeizure,tmp));
                end
                [files,dirs] = spm_select('List', dirBaseline, outExt);
                for i1=1:size(files,1)
                    tmp=deblank(files(i1,:));
                    Q = fullfile(dirBaseline, tmp);
                    clear matlabbatch
                    matlabbatch{1}.spm.spatial.smooth.data = {[Q ',1']};
                    matlabbatch{1}.spm.spatial.smooth.fwhm = [5 5 5];
                    matlabbatch{1}.spm.spatial.smooth.dtype = 0;
                    matlabbatch{1}.spm.spatial.smooth.im = 1;
                    matlabbatch{1}.spm.spatial.smooth.prefix = 's';
                    % spm('defaults', 'EEG');
                    spm_jobman('run', matlabbatch);
                    movefile(fullfile(dirBaseline, ['s' tmp]), fullfile(dirBaseline,tmp));
                end
                
            case 'surface'
                % Copy surface options
                SS.SmoothIterations = SmoothIterations;
                % Save seizure files
                if isdir(dirSeizure)
                    cd(P)
                    rmdir(dirSeizure,'s')
                end
                SS.Fname = dirSeizure;
                ImaGIN_spm_eeg_convertmat2ana_mesh(SS);
                % Save baseline files
                SS.TimeWindow = min(DPowerBaseline.tf.time):TimeResolution:max(DPowerBaseline.tf.time);
                if isdir(dirBaseline)
                    cd(P)
                    rmdir(dirBaseline,'s')
                end
                SS.Fname = dirBaseline;
                ImaGIN_spm_eeg_convertmat2ana_mesh(SS);        
                
                % SMOOTHING
                % Smoothing of results on the surface is handled in ImaGIN_spm_eeg_convertmat2ana_mesh
        end

        % SPMs
        spmDir = fullfile(P,['SPM_' NameEpileptogenicity '_' FileName spm_str_manip(D.fname,'s') '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]);
        if isdir(spmDir)
            cd(P)
            rmdir(spmDir,'s')
        end
        mkdir(spmDir);
        clear matlabbatch
        matlabbatch{1}.spm.stats.fmri_spec.dir = {spmDir};
        matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'scans';
        matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TimeResolution;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 1;
        [files,dirs] = spm_select('List', dirSeizure, outExt);
        ntmp = size(files,1);
        for i1 = 1:size(files,1)
            matlabbatch{1}.spm.stats.fmri_spec.sess.scans{i1,1} = fullfile(dirSeizure, [files(i1,:) strSelectVol]);
        end
        [files,dirs] = spm_select('List', dirBaseline, outExt);
        for i1 = 1:size(files,1)
            matlabbatch{1}.spm.stats.fmri_spec.sess.scans{ntmp+i1,1} = fullfile(dirBaseline, [files(i1,:) strSelectVol]);
        end
        matlabbatch{1}.spm.stats.fmri_spec.sess.cond = struct('name',{},'onset',{},'duration',{},'tmod',{},'pmod',{});
        matlabbatch{1}.spm.stats.fmri_spec.sess.multi{1} = '';
        matlabbatch{1}.spm.stats.fmri_spec.sess.regress.name = 'Seizure';
        matlabbatch{1}.spm.stats.fmri_spec.sess.regress.val = [ones(ntmp,1);zeros(size(files,1),1)];
        matlabbatch{1}.spm.stats.fmri_spec.sess.multireg{1} = '';
        matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = Inf;
        matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
        matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
        matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
        matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
        if AR
            matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';
        else
            matlabbatch{1}.spm.stats.fmri_spec.cvi = 'none';
        end
        matlabbatch{2}.spm.stats.fmri_est.spmmat = {fullfile(matlabbatch{1}.spm.stats.fmri_spec.dir{1}, 'SPM.mat')};
        matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
        matlabbatch{3}.spm.stats.con.spmmat = {fullfile(matlabbatch{1}.spm.stats.fmri_spec.dir{1}, 'SPM.mat')};
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = '+';
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.convec = 1;
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
        matlabbatch{3}.spm.stats.con.delete = 0;
        spm_get_defaults('mask.thresh', 0) %no implicit masking of SPM-Ts
        spm_jobman('run',matlabbatch)

        % Write T-values for each electrode
        WriteTvalues(deblank(DD(i0,:)), ...  % Reference recordings
                     fullfile(matlabbatch{1}.spm.stats.fmri_spec.dir{1}, ['spmT_0001' outExt]), ...  % T-values
                     fullfile(P, [NameEpileptogenicity '_' spm_str_manip(D.fname,'s') '_' FileName '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]), ... % Output file name (without the extension)
                     OutputType, giiCortex, SaveMNI, VolRes);   % 'volume' or 'surface'
    end
    
    % ===== GROUP ANALYSIS =====
    % If there are multiple files in input
    if (size(DD,1) > 1)
        % SPM of GI
        spmDir = fullfile(P,['SPM_' NameEpileptogenicity '_Group_' FileName '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]);
        if isdir(spmDir)
            cd(P);
            rmdir(spmDir,'s');
        end
        mkdir(spmDir);
        clear matlabbatch
        matlabbatch{1}.spm.stats.fmri_spec.dir = {spmDir};
        matlabbatch{1}.spm.stats.fmri_spec.timing.units='scans';
        matlabbatch{1}.spm.stats.fmri_spec.timing.RT=TimeResolution;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t=16;
        matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0=1;
        for i0=1:size(DD,1)
            D = spm_eeg_load(deblank(DD(i0,:)));
            P = spm_str_manip(deblank(DD(i0,:)),'h');
            % Get seizure files
            dirSeizure = fullfile(P,[FileName spm_str_manip(D.fname,'s') '_' NameEpileptogenicity '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]);
            [files,dirs] = spm_select('List', dirSeizure, outExt);
            ntmp = size(files,1);
            for i1 = 1:size(files,1)
                matlabbatch{1}.spm.stats.fmri_spec.sess(i0).scans{i1,1} = fullfile(dirSeizure, [files(i1,:) strSelectVol]);
            end
            % Get baseline files
            dirBaseline = fullfile(P,[FileName spm_str_manip(D.fname,'s') '_' NameEpileptogenicity 'Baseline_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]);
            [files,dirs] = spm_select('List', dirBaseline, outExt);
            for i1=1:size(files,1)
                matlabbatch{1}.spm.stats.fmri_spec.sess(i0).scans{ntmp+i1,1} = fullfile(dirBaseline, [files(i1,:) strSelectVol]);
            end
            matlabbatch{1}.spm.stats.fmri_spec.sess(i0).cond         = struct('name',{},'onset',{},'duration',{},'tmod',{},'pmod',{});
            matlabbatch{1}.spm.stats.fmri_spec.sess(i0).multi{1}     = '';
            matlabbatch{1}.spm.stats.fmri_spec.sess(i0).regress.name = 'Seizure';
            matlabbatch{1}.spm.stats.fmri_spec.sess(i0).regress.val  = [ones(ntmp,1);zeros(size(files,1),1)];
            matlabbatch{1}.spm.stats.fmri_spec.sess(i0).multireg{1}  = '';
            matlabbatch{1}.spm.stats.fmri_spec.sess(i0).hpf          = Inf;
            matlabbatch{1}.spm.stats.fmri_spec.sess(i0).fact         = struct('name',{},'levels',{});
        end
        matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
        matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
        matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
        matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
        if AR
            matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';
        else
            matlabbatch{1}.spm.stats.fmri_spec.cvi = 'none';
        end
        matlabbatch{2}.spm.stats.fmri_est.spmmat = {fullfile(matlabbatch{1}.spm.stats.fmri_spec.dir{1}, 'SPM.mat')};
        matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
        matlabbatch{3}.spm.stats.con.spmmat = {fullfile(matlabbatch{1}.spm.stats.fmri_spec.dir{1}, 'SPM.mat')};
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = '+';
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.convec = ones(1,size(DD,1));
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
        matlabbatch{3}.spm.stats.con.delete = 0;
        spm_get_defaults('mask.thresh', 0) % No implicit masking of SPM-Ts
        spm_jobman('run',matlabbatch);

        % Write T-values for each electrode
        WriteTvalues(deblank(DD(1,:)), ...  % Reference recordings
                     fullfile(matlabbatch{1}.spm.stats.fmri_spec.dir{1}, ['spmT_0001' outExt]), ...  % T-values
                     fullfile(P, [NameEpileptogenicity '_Group_' FileName '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]), ... % Output file name (without the extension)
                     OutputType, giiCortex, SaveMNI, VolRes);   % 'volume' or 'surface'
    end
    
    % ===== DELETE TEMP FILES =====
    for i0 = 1:size(DD,1)
        D = spm_eeg_load(deblank(DD(i0,:)));
        P = spm_str_manip(deblank(DD(i0,:)),'h');
        rmdir(fullfile(P,[FileName spm_str_manip(D.fname,'s') '_' NameEpileptogenicity '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]),'s')
        rmdir(fullfile(P,[FileName spm_str_manip(D.fname,'s') '_' NameEpileptogenicity 'Baseline_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(round(mean(Latency)))]),'s')
    end
end


%% ===== DELAY MAPS =====
% Compute map of propagation delay (only if more than one latency)
if (length(latency) > 1)
    % Single recordings
    for i0 = 1:size(DD,1)
        D = spm_eeg_load(deblank(DD(i0,:)));
        P = spm_str_manip(deblank(DD(i0,:)),'h');
        % Write delay map for each file
        WriteDelay(fullfile(P, ['SPM_' NameEpileptogenicity '_' FileName spm_str_manip(D.fname,'s') '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon)))]), ...  % SPM folder without the latency
                   latency, ThDelay, SmoothIterations, ...
                   fullfile(P, ['Delay_' NameEpileptogenicity '_' FileName spm_str_manip(D.fname,'s')  '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(1000*ThDelay) outExt]), ...
                   OutputType, MeshFile);
    end
    
    % Write delay map for the group
    if (size(DD,1) > 1)
        WriteDelay(fullfile(P, ['SPM_' NameEpileptogenicity '_Group_' FileName '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon)))]), ...  % SPM folder without the latency
                   latency, ThDelay, SmoothIterations, ...
                   fullfile(P, ['Delay_' NameEpileptogenicity '_Group_' FileName '_' num2str(min(FreqBand)) '_' num2str(max(FreqBand)) '_' num2str(round(mean(Horizon))) '_' num2str(1000*ThDelay) outExt]), ...
                   OutputType, MeshFile);
    end
end
end



%% ===================================================================================================
%  ===== HELPER FUNCTIONS ============================================================================
%  ===================================================================================================

%% ===== WRITE T-VALUES FOR EACH ELECTRODE =====
function WriteTvalues(RecFile, TvalueFile, OutputFile, OutputType, giiCortex, SaveMNI, VolRes)
    NameEpileptogenicity = 'EI';
    % Load reference recordings
    D = spm_eeg_load(RecFile);
    % Read output T values
    switch lower(OutputType)
        case 'volume'
            V = spm_vol(TvalueFile);
            VV = spm_read_vols(V);
            % Use standard positions from SPM template
            if SaveMNI
                tmp = spm('Defaults','EEG');
                bb = tmp.normalise.write.bb;
                [x,y,z] = meshgrid(bb(1,1):VolRes:bb(2,1),...
                    bb(1,2):VolRes:bb(2,2),...
                    bb(1,3):VolRes:bb(2,3));
                P = [x(:),y(:),z(:)];
            % Use real coordinates from volume (considering first voxel is (1,1,1))
            else
                [x,y,z] = meshgrid(1:V.dim(1), 1:V.dim(2), 1:V.dim(3));
                P = bsxfun(@plus, V.mat(1:3,1:3) * [x(:),y(:),z(:)]', V.mat(1:3,4))';
            end
            Tvalues = permute(VV,[2 1 3]);
        case 'surface'
            giiT = gifti(TvalueFile);
            Tvalues = giiT.cdata(:,:,:);
            P = giiCortex.vertices;
    end
    
    % Get sensor positions
    Dsensors = sensors(D,'EEG');
    try
        PosElec = Dsensors.elecpos';
    catch
        PosElec = Dsensors.pnt';
    end
    BadChannels = badchannels(D);
    % Average the T values in a neighborhood of 10 mm around each contact (SizeHorizon when creating images)
    EIGamma = zeros(size(PosElec,2),1);
    for i1 = 1:size(PosElec,2)
        % Bad channels: force the value to be NaN
        if ~isempty(BadChannels) && ismember(i1, BadChannels)
            EIGamma(i1) = NaN;
        else
            dist = (P(:,1)-PosElec(1,i1)).^2+(P(:,2)-PosElec(2,i1)).^2+(P(:,3)-PosElec(3,i1)).^2;
            tmp1 = Tvalues((dist < 100) & (Tvalues(:) ~= 0));
            if ~isempty(tmp1)
                EIGamma(i1) = mean(tmp1);
            end
        end
    end
    % Save T values as a .mat/.dat file
    D1 = clone(D, [OutputFile, '.mat'], [size(PosElec,2) 1 1]);
    D1(:,:,:) = EIGamma;
    D1 = timeonset(D1,0);
    save(D1);

    % Write T values in a text file
    fid = fopen([OutputFile, '.txt'], 'wt');
    fprintf(fid,[' Electrode /  ' NameEpileptogenicity '     \n']);
    fprintf(fid,'\n');
    for i1=1:length(Dsensors.label)
        try
            if ~isnan(EIGamma(i1))
                fprintf(fid,'%s %10.2f \n', cell2mat(Dsensors.label{i1}), EIGamma(i1));
            else
                fprintf(fid,'%s NaN \n', cell2mat(Dsensors.label{i1}));
            end
        catch
            if ~isnan(EIGamma(i1))
                fprintf(fid,'%s %10.2f \n', cell2mat(Dsensors.label(i1)), EIGamma(i1));
            else
                fprintf(fid,'%s NaN \n', cell2mat(Dsensors.label(i1)));
            end
        end
    end
    fclose(fid);
end


%% ===== WRITE DELAY MAPS =====
function WriteDelay(dirStat, latency, ThDelay, SmoothIterations, OutputFile, OutputType, MeshFile)
    Delay = [];

    % Process all the latencies
    for i2 = 1:size(latency,2)
        Latency = mean(latency(:,i2));

        % Load SPM.mat
        dirSPM = [dirStat '_' num2str(round(mean(Latency)))];
        load(fullfile(dirSPM, 'SPM.mat'));
        % Calcule threshold for statistical map
        df = [SPM.xCon(1).eidf, SPM.xX.erdf];
        S = SPM.xVol.S;    %-search Volume {voxels}
        R = SPM.xVol.R;    %-search Volume {resels}
        % u = spm_uc_FDR(0.001,df,'T',1,P1);
        % ThDelay is a p-value
        if (ThDelay < 1)
            u = spm_uc(ThDelay, df, 'T', R, 1, S);
        % ThDelay is a t-value
        else
            u = ThDelay;
        end

        % Load spmT map
        switch lower(OutputType)
            case 'volume'
                P1 = spm_vol(fullfile(dirSPM, 'spmT_0001.nii'));
                Tvalues = spm_read_vols(P1);
            case 'surface'
                giiT = gifti(fullfile(dirSPM, 'spmT_0001.gii'));
                Tvalues = giiT.cdata(:,:,:);
        end

        % Initialize delay map
        if isempty(Delay)
            Delay = NaN * Tvalues;
        end
        % Activated voxels
        Q1 = find(Tvalues >= u);
        % Remove if isolated peak
        Q4 = find(Tvalues < u);
        if (i2 > 1)
            Q5 = find(Delay == mean(latency(:,i2-1)));
            Q6 = intersect(Q5, Q4);
            Delay(Q6) = NaN;
        end
        Q2 = find(isnan(Delay));
        Q3 = intersect(Q2, Q1);
        Delay(Q3) = mean(latency(:,i2));
    end

    % Save delay maps
    switch lower(OutputType)
        case 'volume'
            % Write delay map
            P0 = P1;
            P0.fname = OutputFile;
            P0 = spm_write_vol(P0,Delay);
            % Smooth delay map
            clear matlabbatch
            matlabbatch{1}.spm.spatial.smooth.data = {[P0.fname ',1']};
            matlabbatch{1}.spm.spatial.smooth.fwhm = [5 5 5];
            matlabbatch{1}.spm.spatial.smooth.dtype = 0;
            matlabbatch{1}.spm.spatial.smooth.im = 1;
            matlabbatch{1}.spm.spatial.smooth.prefix = 's';
            % spm('defaults', 'EEG');
            spm_jobman('run', matlabbatch);
            % Remove all the voxels for which there is no value
            Q = strrep(OutputFile, 'Delay_', 'sDelay_');
            M = spm_vol(Q);
            I = spm_read_vols(M);
            I(isnan(Delay)) = NaN;
            I = (max(Delay(:))./max(I(:))) * I;
            spm_write_vol(M,I);
            
        case 'surface'
            % Replace NaN values with 0 before smoothing
            iNan = isnan(Delay);
            Delay(Delay==0) = eps('single');
            Delay(iNan) = 0;
            % Write delay map
            out_spm_gii(MeshFile, OutputFile, Delay);
            
%             % Smooth delay map
%             sDelay = spm_mesh_smooth(gifti(MeshFile), Delay, SmoothIterations);
%             % Set non-defined values to 0
%             sDelay(iNan) = 0;
%             % Write smoothed map
%             out_spm_gii(MeshFile, strrep(OutputFile, 'Delay_', 'sDelay_'), sDelay);
    end 
end
