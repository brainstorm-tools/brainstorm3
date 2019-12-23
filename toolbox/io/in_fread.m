function [F, TimeVector] = in_fread(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels, ImportOptions)
% IN_FREAD: Read a block a data in any recordings file previously opened with in_fopen().
%
% USAGE:  [F, TimeVector] = in_fread(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels, ImportOptions);
%         [F, TimeVector] = in_fread(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels);                 : Do not apply any pre-preprocessings
%         [F, TimeVector] = in_fread(sFile, ChannelMat, iEpoch, SamplesBounds);                            : Read all channels
%
% INPUTS:
%     - sFile         : Structure for importing files in Brainstorm. Created by in_fopen()
%     - iEpoch        : Indice of the epoch to read (only one value allowed)
%     - SamplesBounds : [smpStart smpStop], First and last sample to read in epoch #iEpoch
%     - iChannels     : Array of indices of the channels to import
%     - ImportOptions : Structure created by interface window panel_import_data.m  (look in db_template.m for a description of all the fields).
%
% OUTPUTS:
%     - F          : [nChannels x nTimes], block of recordings
%     - TimeVector : [1 x nTime], time values in seconds

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2019

%% ===== PARSE INPUTS =====
if (nargin < 6)
    ImportOptions = [];
end
if (nargin < 5)
    iChannels = [];
end
TimeVector = [];
% Read channel ranges for faster access
isChanRange = ismember(sFile.format, {'CTF', 'CTF-CONTINUOUS', 'KDF', 'EEG-EDF', 'EEG-BDF', 'BST-BIN', 'EEG-CURRY', 'EEG-DELTAMED', 'EEG-COMPUMEDICS-PFS', 'EEG-MICROMED', 'EEG-NEURONE', 'EEG-NK'});
if isChanRange
    if isempty(iChannels)
        ChannelRange = [];
        iChanRemove = [];
    else
        if ~isequal(iChannels, sort(iChannels))
            error('You need to sort the channels indices before calling in_fread().');
        end
        ChannelRange = [iChannels(1), iChannels(end)];
        iChanRemove = setdiff(ChannelRange(1):ChannelRange(2), iChannels) - ChannelRange(1) + 1;
    end
end


%% ===== OPEN FILE =====
% Open file (for some formats, it is open in the low-level function)
if ismember(sFile.format, {'FIF', 'CTF', 'KIT', 'RICOH', 'BST-DATA', 'SPM-DAT', 'EEG-ANT-CNT', 'EEG-EEGLAB', 'EEG-GTEC', 'EEG-NEURONE', 'EEG-NEURALYNX', 'EEG-NICOLET', 'EEG-BLACKROCK', 'EEG-RIPPLE', 'EYELINK', 'NIRS-BRS', 'EEG-EGI-MFF', 'MNE-PYTHON'}) 
    sfid = [];
else
    sfid = fopen(sFile.filename, 'r', sFile.byteorder);
end

% Check whether optional field precision is available
if ~isempty(ImportOptions) && isfield(ImportOptions, 'Precision')
    precision = ImportOptions.Precision;
else
    precision = [];
end

%% ===== READ RECORDINGS BLOCK =====
switch (sFile.format)
    case 'FIF'
        [F,TimeVector] = in_fread_fif(sFile, iEpoch, SamplesBounds, iChannels);
    case {'CTF', 'CTF-CONTINUOUS'}
        isContinuous = strcmpi(sFile.format, 'CTF-CONTINUOUS');
        F = in_fread_ctf(sFile, iEpoch, SamplesBounds, ChannelRange, isContinuous);
    case '4D'
        F = in_fread_4d(sFile, sfid, iEpoch, SamplesBounds, iChannels);
    case 'KIT'
        F = in_fread_kit(sFile, iEpoch, SamplesBounds, iChannels);
    case 'RICOH'
        F = in_fread_ricoh(sFile, iEpoch, SamplesBounds, iChannels);
    case 'KDF'
        F = in_fread_kdf(sFile, sfid, SamplesBounds, ChannelRange);
    case 'ITAB'
        F = in_fread_itab(sFile, sfid, SamplesBounds, iChannels);
    case 'MEGSCAN-HDF5'
        F = in_fread_megscan(sFile, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-ANT-CNT'
        F = in_fread_ant(sFile, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-ANT-MSR'
        F = in_fread_msr(sFile, sfid, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case {'EEG-BLACKROCK', 'EEG-RIPPLE'}
        F = in_fread_blackrock(sFile, SamplesBounds, iChannels, precision);
    case 'EEG-BRAINAMP'
        F = in_fread_brainamp(sFile, sfid, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-CURRY'
        F = in_fread_curry(sFile, sfid, iEpoch, SamplesBounds, ChannelRange);
    case 'EEG-DELTAMED'
        F = in_fread_deltamed(sFile, sfid, SamplesBounds, ChannelRange);
    case 'EEG-COMPUMEDICS-PFS'
        F = in_fread_compumedics_pfs(sFile, sfid, SamplesBounds, ChannelRange);
    case {'EEG-EDF', 'EEG-BDF'}
        F = in_fread_edf(sFile, sfid, SamplesBounds, ChannelRange);
    case 'EEG-EEGLAB'
        F = in_fread_eeglab(sFile, iEpoch, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-EGI-RAW'
        F = in_fread_egi(sFile, sfid, iEpoch, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-GTEC'
        F = in_fread_gtec(sFile, iEpoch, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-MANSCAN'
        F = in_fread_manscan(sFile, sfid, iEpoch, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-EGI-MFF'
        F = in_fread_mff(sFile, iEpoch, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-MICROMED'
        F = in_fread_micromed(sFile, sfid, SamplesBounds, ChannelRange);
    case 'EEG-NEURALYNX'
        F = in_fread_neuralynx(sFile, SamplesBounds, iChannels);
    case 'EEG-NEURONE'
        F = in_fread_neurone(sFile, SamplesBounds, ChannelRange);
    case 'EEG-NEUROSCAN-CNT'
        F = in_fread_cnt(sFile, sfid, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-NEUROSCAN-EEG'
        F = in_fread_eeg(sFile, sfid, iEpoch, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-NEUROSCAN-AVG'
        F = in_fread_avg(sFile, sfid, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-NEUROSCOPE'
        F = in_fread_neuroscope(sFile, sfid, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'EEG-NICOLET'
        F = in_fread_nicolet(sFile, iEpoch, SamplesBounds, iChannels);
    case 'EEG-NK'
        F = in_fread_nk(sFile, sfid, iEpoch, SamplesBounds, ChannelRange);
    case 'EEG-SMR'
        F = in_fread_smr(sFile, sfid, SamplesBounds, iChannels);
    case 'EYELINK'
        [F, TimeVector] = in_fread_eyelink(sFile, iEpoch, SamplesBounds, iChannels);
    case 'NIRS-BRS'
        F = in_fread_nirs_brs(sFile, SamplesBounds);
        if ~isempty(iChannels)
            F = F(iChannels,:);
        end
    case 'SPM-DAT'
        F = in_fread_spm(sFile, SamplesBounds, iChannels);
    case 'BST-BIN'
        F = in_fread_bst(sFile, sfid, SamplesBounds, ChannelRange);
    case 'BST-DATA'
        if ~isempty(SamplesBounds)
            fileSamples = round(sFile.prop.times * sFile.prop.sfreq);
            iTimes = (SamplesBounds(1):SamplesBounds(2)) - fileSamples(1) + 1;
        else
            iTimes = 1:size(sFile.header.F,2);
        end
        if isempty(iChannels)
            iChannels = 1:size(sFile.header.F,1);
        end
        F = sFile.header.F(iChannels, iTimes);
    case 'EEG-INTAN'
        F = in_fread_intan(sFile, SamplesBounds, iChannels, precision);
    case 'EEG-PLEXON'
        F = in_fread_plexon(sFile, SamplesBounds, iChannels, precision);
    case 'EEG-TDT'
        F = in_fread_tdt(sFile, SamplesBounds, iChannels);
    case {'NWB', 'NWB-CONTINUOUS'}
        isContinuous = strcmpi(sFile.format, 'NWB-CONTINUOUS');
        F = in_fread_nwb(sFile, iEpoch, SamplesBounds, iChannels, isContinuous);
    case 'MNE-PYTHON'
        [F, TimeVector] = in_fread_mne(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels);
    otherwise
        error('Cannot read data from this file');
end

% Force the recordings to be in double precision
if ~isempty(precision) && strcmp(precision, 'single')
    F = single(F);
else
    F = double(F);
end
% Remove channels that were not supposed to be read
if isChanRange && ~isempty(iChanRemove)
    F(iChanRemove,:) = [];
end


%% ===== CLOSE FILE =====
if ~isempty(sfid) && ~isempty(fopen(sfid))
    fclose(sfid);
end


%% ===== TIME =====
% If TimeVector was not defined by the reading functions
if isempty(TimeVector)
    if ~isempty(SamplesBounds)
        TimeVector = (SamplesBounds(1) : SamplesBounds(2)) ./ sFile.prop.sfreq;
    elseif ~isempty(iEpoch) && ~isempty(ImportOptions) && strcmpi(ImportOptions.ImportMode, 'Epoch') && ~isempty(sFile.epochs)
        epochSamples = round(sFile.epochs(iEpoch).times * sFile.prop.sfreq);
        TimeVector = (epochSamples(1) : epochSamples(2)) / sFile.prop.sfreq;
    else
        fileSamples = round(sFile.prop.times * sFile.prop.sfreq);
        TimeVector = (fileSamples(1) : fileSamples(2)) / sFile.prop.sfreq;
    end
end
% If epoching the recordings (ie. reading by events): Use imported time window
if ~isempty(ImportOptions) && strcmpi(ImportOptions.ImportMode, 'Event')
    % TimeVector = TimeVector - TimeVector(1) + ImportOptions.EventsTimeRange(1);
    evtOffset = round(ImportOptions.EventsTimeRange(1) * sFile.prop.sfreq) / sFile.prop.sfreq;
    TimeVector = TimeVector - TimeVector(1) + evtOffset;
end


%% ===== GRADIENT CORRECTION =====
% 3rd-order gradient correction
if ~isempty(ImportOptions) && ImportOptions.UseCtfComp && ~strcmpi(sFile.format, 'BST-DATA') && ~isempty(ChannelMat) && ~isempty(ChannelMat.MegRefCoef) && ~isempty(sFile.prop.currCtfComp) && ~isequal(sFile.prop.currCtfComp, sFile.prop.destCtfComp)
    iMeg = good_channel(ChannelMat.Channel,[],'MEG');
    iRef = good_channel(ChannelMat.Channel,[],'MEG REF');
    if ~isempty(iChannels) && (length(iChannels) ~= length(ChannelMat.Channel))
        error('CTF compensators require that you read all the channels at the same time.');
    else
        F(iMeg,:) = F(iMeg,:) - ChannelMat.MegRefCoef * F(iRef,:);
    end
end

%% ===== SSP PROJECTORS =====
if ~isempty(ImportOptions) && ImportOptions.UseSsp && ~strcmpi(sFile.format, 'BST-DATA') && ~isempty(ChannelMat) && ~isempty(ChannelMat.Projector)
    % Build projector matrix
    Projector = process_ssp2('BuildProjector', ChannelMat.Projector, 1);
    % Get bad channels
    iBadChan = find(sFile.channelflag == -1);
    % Apply projector
    if ~isempty(Projector)
        % Remove bad channels from the projector (similar as in process_megreg)
        if ~isempty(iBadChan)
            Projector(iBadChan,:) = 0;
            Projector(:,iBadChan) = 0;
            Projector(iBadChan,iBadChan) = eye(length(iBadChan));
        end
        % Apply projector
        if ~isempty(iChannels)
            % If there are projectors involved and only subselection of channels: 
            % We must have all data needed to apply the projector, otherwise it doesn't make sense
            missingChannels = setdiff(find(any(Projector(iChannels,:), 1)), iChannels);
            if ~isempty(missingChannels)
                bst_report('Warning', 'process_import_data_raw', [], ['Missing channels in order to apply existing SSP/ICA projectors. To read the corrected values for channel "' ChannelMat.Channel(iChannels(1)).Name '", first apply the existing projectors with the process Artifacts > Apply SSP and CTF compensation']); 
            else
                F = Projector(iChannels, iChannels) * F;
            end
        else
            F = Projector * F;
        end
    end
end


%% ===== REMOVE BASELINE ======
if ~isempty(ImportOptions) && ~isempty(ImportOptions.RemoveBaseline)
    % Get times to compute the baseline
    switch (ImportOptions.RemoveBaseline)
        case 'all'
            iTimesBl = 1:length(TimeVector);
        case 'time'
            iTimesBl = find((TimeVector >= ImportOptions.BaselineRange(1)) & (TimeVector <= ImportOptions.BaselineRange(2)));
        case 'no'
            iTimesBl = [];
    end
    % Remove baseline
    if ~isempty(iTimesBl)
        % Exclude system channels from the baseline correction
        if ~isempty(ChannelMat) && ~isempty(ChannelMat.Channel)
            iChanBl = find(~ismember(lower({ChannelMat.Channel.Type}), {'stim','video','sysclock'}));
        else
            iChanBl = 1:size(F,1);
        end
        % Compute baseline
        blValue = mean(F(iChanBl,iTimesBl), 2);
        % Remove from recordings
        % F(iChanBl,:) = F(iChanBl,:) - repmat(blValue, [1,size(F,2)]);
        F(iChanBl,:) = bst_bsxfun(@minus, F(iChanBl,:), blValue);
    end
end


%% ===== RESAMPLE =====
if ~isempty(ImportOptions) && ImportOptions.Resample && (size(F,2) > 1) && (abs(ImportOptions.ResampleFreq - sFile.prop.sfreq) > 0.05)
    [F, TimeVector] = process_resample('Compute', F, TimeVector, ImportOptions.ResampleFreq);
end



