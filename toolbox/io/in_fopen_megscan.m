function [sFile, ChannelMat] = in_fopen_megscan(DataFile)
% IN_FOPEN_MEGSCAN: Open a MEGSCAN file (York-Instruments), and get all the data and channel information.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_megscan(DataFile)

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
% Authors: Elizabeth Bock, 2019


%% ===== Primary acquisition =====
% Mandatory: /config, /subject, /acquisitions
% Optional: /geometry, /apps, /notes

% soft link in /acquisitions points to the primary acquisition
try
    info = h5info(DataFile,'/acquisitions');
catch
    error('Invalid YI HDF5 file: Missing dataset "/acquisitions".');
end

% User selected
for iGroup = 1:length(info.Groups)
    condList{iGroup} = [info.Groups(iGroup).Name ': ' char(h5readatt(DataFile,info.Groups(iGroup).Name,'acq_type'))];
end

% Create a dialog message
if ~isempty(condList)
    jCombo = gui_component('ComboBox', [], [], [], {condList}, [], [], []);
else
    jCombo = gui_component('ComboBox', [], [], [], [], [], [], []);
end

jCombo.setEditable(1);
message = javaArray('java.lang.Object',2);
message(1) = java.lang.String('<HTML>Select an acquisition to import:<BR><BR>');
message(2) = jCombo;
% Show question
res = java_call('javax.swing.JOptionPane', 'showConfirmDialog', 'Ljava.awt.Component;Ljava.lang.Object;Ljava.lang.String;I', [], message, 'Select condition', javax.swing.JOptionPane.OK_CANCEL_OPTION);
if (res ~= javax.swing.JOptionPane.OK_OPTION)
    selCond = [];
    return;
end
% Get new condition name
selObj = jCombo.getSelectedObjects();
selCond = regexp(char(selObj(1)),':','split');
pAcq = selCond{1};

AcqInfo = h5info(DataFile,pAcq,'TextEncoding','UTF-8');
% Datasets
sAcq.Chan = h5read(DataFile,[pAcq '/channel_list/']);
sAcq.Data = h5read(DataFile,[pAcq '/data/']);

% Acquisition Attributes: Mandatory
try
sAcq.Type = h5readatt(DataFile,pAcq,'acq_type');
sAcq.Seq = h5readatt(DataFile,pAcq,'sequence'); % what is this?
sAcq.SampleRate = h5readatt(DataFile,pAcq,'sample_rate');
sAcq.StartTime = h5readatt(DataFile,pAcq,'start_time');
catch
    error('Invalid MEGSCAN HDF5 file: Missing mandatory acquisition attributes');
end
% Acquisition Attributes: Optional
attnames = {AcqInfo.Attributes.Name};
if ismember('description',attnames)
    sAcq.Desc = h5readatt(DataFile,pAcq,'description');
end
if ismember('upb_applied',attnames)
    sAcq.UpbApplied = h5readatt(DataFile,pAcq,'upb_applied');
end
if ismember('upb_applied',attnames)
    sAcq.WeightsConfig = h5readatt(DataFile,pAcq,'weights_configured'); %TODO 
end
if ismember('weights_applied',attnames)
    sAcq.WeightsApplied = h5readatt(DataFile,pAcq,'weights_applied');   %TODO
end
if ismember('coh_active',attnames)
    sAcq.CohActive = h5readatt(DataFile,pAcq,'coh_active');
end
if ismember('subject_position',attnames)
    sAcq.SubjPos = h5readatt(DataFile,pAcq,'subject_position');
end

% Epochs
try
    EpochInfo = h5info(DataFile,[pAcq '/epochs'],'TextEncoding','UTF-8');
    % Mandatory: channel_ids, trigger_codes, sample_indexes
    EpochChanID = h5read(DataFile,[pAcq '/epochs/channel_ids']); % list of trigger channels
    EpochSampIdx = h5read(DataFile,[pAcq '/epochs/sample_indexes']);
    EpochTrigCode = h5read(DataFile,[pAcq '/epochs/trigger_codes']);
    
    % Optional: description, created, trigger_labels, group_codes, response codes
catch
    disp('Missing or incomplete epoch info')
end
% Head coils
try
    HdCoilInfo = h5info(DataFile,[pAcq '/fitted_coils'],'TextEncoding','UTF-8');
catch
    disp('No head coil info')
end

% ===== Config =====
try
    ChannelInfo = h5info(DataFile,'/config/channels','TextEncoding','UTF-8');
    model = h5readatt(DataFile,'/config/','model');
catch
    error('Invalid MEGSCAN HDF5 file: Missing dataset "/config".');
end

% ===== Subject =====
try
    SubjectInfo = h5info(DataFile,'/subject','TextEncoding','UTF-8');
catch
    error('Invalid MEGSCAN HDF5 file: Missing dataset "/subject".');
end

% Read information of interest
hdr.format = 'MEGSCAN-HDF5';
hdr.acquisitionname = pAcq;
hdr.numberchannels = size(sAcq.Chan, 1);
hdr.samplingfrequency = sAcq.SampleRate;
hdr.channelname = sAcq.Chan;
hdr.nTime = size(sAcq.Data,2);
if isfield(sAcq,'UpbApplied')
    hdr.UpbApplied = sAcq.UpbApplied;
else
    hdr.UpbApplied = [];
end

% Information not found (yet)
hdr.amplifiername = '';
hdr.nEpochs       = 1;
hdr.pretrigger    = 0;
hdr.markername    = [];
hdr.marker        = [];

%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.filename = DataFile;
sFile.fid = [];
sFile.format = 'MEGSCAN-HDF5';
sFile.device = model;
sFile.byteorder = 'b';
sFile.header = hdr;
% Properties of the recordings
sFile.prop.sfreq  = double(hdr.samplingfrequency);
sFile.prop.times  = ([0, hdr.nTime-1] - hdr.pretrigger) ./ sFile.prop.sfreq;
sFile.prop.nAvg   = 1;
sFile.channelflag = ones(hdr.numberchannels,1); % GOOD=1; BAD=-1;
% Epochs, if any
if (hdr.nEpochs > 1)
    for i = 1:hdr.nEpochs
        sFile.epochs(i).label   = sprintf('Trial #%d', i);
        sFile.epochs(i).times   = sFile.prop.times;
        sFile.epochs(i).nAvg    = 1;
        sFile.epochs(i).select  = 1;
        sFile.epochs(i).bad         = 0;
        sFile.epochs(i).channelflag = [];
    end
end

%% ===== EVENTS =====
for iEvt = 1:length(hdr.markername)
    % Get all the occurrences
    iOcc = find(hdr.marker(:,3) == iEvt);
    % Create event structure
    sFile.events(iEvt).label   = hdr.markername{iEvt};
    samples = hdr.marker(iOcc,1)';
    sFile.events(iEvt).epochs  = hdr.marker(iOcc,2)';
    if ~isempty(sFile.epochs)
        for i = 1:length(samples)
            iEpoch =  sFile.events(iEvt).epochs(i);
            samples(i) = samples(i) + round(sFile.epochs(iEpoch).times(1) * sFile.prop.sfreq) - 1;
        end
    end
    sFile.events(iEvt).times    = samples ./ sFile.prop.sfreq;
    sFile.events(iEvt).select   = 1;
    sFile.events(iEvt).channels = cell(1, size(sFile.events(iEvt).times, 2));
    sFile.events(iEvt).notes    = cell(1, size(sFile.events(iEvt).times, 2));
end

%% ===== CHANNELS STRUCTURE =====
% Initialize structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'MEGSCAN channels';
% Compensation
ChannelMat.MegRefCoef = [];
% projectors
ChannelMat.Projector = [];

% Channels information
ChannelMat.Channel = repmat(db_template('channeldesc'), 1, hdr.numberchannels);

for iChan = 1:hdr.numberchannels
    type = char(h5readatt(DataFile,['/config/channels/' hdr.channelname{iChan} ],'chan_type'));
    
    ChannelMat.Channel(iChan).Name    = hdr.channelname{iChan};
    ChannelMat.Channel(iChan).Type    = type;
    ChannelMat.Channel(iChan).Weight  = 1;
    
    switch type
        case {'ANALOG'}
            comment = h5readatt(DataFile,['/config/channels/' hdr.channelname{iChan} ],'mode');
            ChannelMat.Channel(iChan).Comment = comment;
        case {'COH'}
            % coh_active is mandatory
        case {'DIGITAL'}
            comment = h5readatt(DataFile,['/config/channels/' hdr.channelname{iChan} ],'mode');
            ChannelMat.Channel(iChan).Comment = comment;
        case {'EEG', 'EEGREF'}
            %gain = h5readatt(DataFile,['/config/channels/' hdr.channelname{iChan} ],'gain'); %TODO
            
            try
                info = h5info(DataFile,'/geometry/eeg','TextEncoding','UTF-8');
                aliases = h5read(DataFile,['/config/channels/' hdr.channelname{iChan} '/aliases']);
                for iPt = 1:size(info.Groups,1)
                    [~,label] = fileparts(info.Groups(iPt).Name);
                    idx = find(~cellfun(@isempty,regexp(aliases,label)));
                    if ~isempty(idx)
                        points = h5read(DataFile,[info.Groups(iPt).Name '/location']);
                        ChannelMat.Channel(iChan).Loc = points(:,1)';
                        ChannelMat.Channel(iChan).Comment = label;
                    end
                end
            catch
                disp('No EEG locations')
            end
            
        case {'MEG', 'MEGREF'}
            %upb_applied, weights_configured (MEG only), weights_applied (MEG only); %TODO
            %gain = h5readatt(DataFile,['/config/channels/' hdr.channelname{iChan} ],'gain'); %TODO

            try
                ChannelMat.Channel(iChan).Loc = h5read(DataFile,['/config/channels/' hdr.channelname{iChan} '/position']) ./1000; %m
                ChannelMat.Channel(iChan).Orient = h5read(DataFile,['/config/channels/' hdr.channelname{iChan} '/orientation']);
                ChannelMat.Channel(iChan).Comment = h5read(DataFile,['/config/channels/' hdr.channelname{iChan} '/loop_shape']);
            catch
                disp(['no orientation or location for ' hdr.channelname{iChan}])
                ChannelMat.Channel(iChan).Loc = [];
                ChannelMat.Channel(iChan).Orient  = [];
            end
            
            if sAcq.UpbApplied
                %TODO
            end
            
            %weights
%             tgt_chans = h5read(DataFile,'/config/weights/Etable/tgt_chans');
%             chNum = hdr.channelname{iChan};
%             cellfind = @(chNum)(@(tgt_chans)(strcmp(chNum,tgt_chans)));
%             idx = find(cellfun(cellfind(chNum),tgt_chans));
%             if ~isempty(idx)
%                 weights = h5read(DataFile,'/config/weights/Etable/weights')';
%                 ChannelMat.Channel(iChan).Weight = weights(idx,:);
%             end
%             ref_chans = h5read(DataFile,'/config/weights/Etable/ref_chans');
%
            
        case {'TEMPERATURE'}
            
        case {'UNKNOWN'}
    end
    
end

%% HPI (coils) , Fiducials and headshape (MEGSCAN-SCS)
npoints = 0;
try
    info = h5info(DataFile,'/geometry/coils','TextEncoding','UTF-8');
    for iPt = 1:size(info.Groups,1)
        npoints = npoints + 1;
        [~,label] = fileparts(info.Groups(iPt).Name);
        points = h5read(DataFile,[info.Groups(iPt).Name '/location']);
        % Store coil locations in meters
        ChannelMat.HeadPoints.Loc(:,npoints) =  points(:,1) ./1000; %(m)
        ChannelMat.HeadPoints.Label{npoints} = label;
        ChannelMat.HeadPoints.Type{npoints} = 'HPI';
    end
catch
    disp('No digitized coil info')
end
% Fiducials
try
    info = h5info(DataFile,'/geometry/fiducials','TextEncoding','UTF-8');
    for iPt = 1:size(info.Groups,1)
        npoints = npoints + 1;
        [~,label] = fileparts(info.Groups(iPt).Name);
        points = h5read(DataFile,[info.Groups(iPt).Name '/location']);
        % Store cardinal points in meters
        ChannelMat.HeadPoints.Loc(:,npoints) =  points(:,1) ./1000; 
        ChannelMat.HeadPoints.Label{npoints} = label;
        ChannelMat.HeadPoints.Type{npoints} = 'CARDINAL';
    end
catch
    disp('No digitized fiducial info')
end
try
    info = h5info(DataFile,'/geometry/head_shape','TextEncoding','UTF-8');
    points = h5read(DataFile,'/geometry/head_shape/head_shape');
    for iPt = 1:size(points,2)
        npoints = npoints+1;
        % Store headpoints in meters
        ChannelMat.HeadPoints.Loc(:,npoints) = points(:,iPt) ./1000;
        ChannelMat.HeadPoints.Label{npoints} = num2str(iPt);
        ChannelMat.HeadPoints.Type{npoints} = 'EXTRA';
    end
catch
    disp('No digitized head-shape points')
end

%% Apply transformation to MEG/EEG channels
% Get sensor types
iMeg  = sort([good_channel(ChannelMat.Channel, [], 'MEG'), good_channel(ChannelMat.Channel, [], 'MEG REF')]);
iEeg  = sort([good_channel(ChannelMat.Channel, [], 'EEG'), good_channel(ChannelMat.Channel, [], 'SEEG'), good_channel(ChannelMat.Channel, [], 'ECOG')]);

% ==== CCS => MEGSCAN_SCS (MEG only) ====
try
    tCCStoMegscanScs = h5read(DataFile,[pAcq '/ccs_to_scs_transform'])'; %(mm)
catch
    tCCStoMegscanScs = [];
    disp('No ccs to scs transform')
end

% Apply the transformation to the MEG channels
if ~isempty(tCCStoMegscanScs)
    R = tCCStoMegscanScs(1:3,1:3); %(mm)
    T = tCCStoMegscanScs(1:3,4);   %(mm)
    
    for i = 1:length(iMeg)
        % The channel locations are in m, but the transform is in mm.
        % Therefore convert the location to mm, but then store result in meters
        if ~isempty(ChannelMat.Channel(iMeg(i)).Loc)
            ChannelMat.Channel(iMeg(i)).Loc = (R * (ChannelMat.Channel(iMeg(i)).Loc .*1000) + T) ./1000;
        end
        % Update orientation
        if ~isempty(ChannelMat.Channel(iMeg(i)).Orient)
            ChannelMat.Channel(iMeg(i)).Orient = R * ChannelMat.Channel(iMeg(i)).Orient;
        end
    end
    ChannelMat.TransfMegLabels{end+1} = 'MegscanCCS=>MegscanSCS';
    ChannelMat.TransfMeg{end+1} = tCCStoMegscanScs;
else
    % If "CCS => MEGSCAN_SCS" transformation is not defined
    % TODO - compute the transformation from a COH acquisition?
end

% ==== MEGSCAN_SCS => CTF (MEG and EEG) ====
% Compute rotation/translation to convert coordinates system : MEGSCAN_SCS => CTF
% Get fiducials (NASION, LPA, RPA)
iNas = find(~cellfun(@isempty,regexp(ChannelMat.HeadPoints.Label,'Nasion')));
iLpa = find(~cellfun(@isempty,regexp(ChannelMat.HeadPoints.Label,'LPA')));
iRpa = find(~cellfun(@isempty,regexp(ChannelMat.HeadPoints.Label,'RPA')));
if ~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa)
    ChannelMat.SCS.NAS = double(ChannelMat.HeadPoints.Loc(:,iNas))'; %(m)
    ChannelMat.SCS.LPA = double(ChannelMat.HeadPoints.Loc(:,iLpa))'; %(m)
    ChannelMat.SCS.RPA = double(ChannelMat.HeadPoints.Loc(:,iRpa))'; %(m)
    % Compute transformation
    transfSCS = cs_compute(ChannelMat, 'scs'); %(meters go in, transform comes out as mm)
    ChannelMat.SCS.R      = transfSCS.R;
    ChannelMat.SCS.T      = transfSCS.T;
    ChannelMat.SCS.Origin = transfSCS.Origin;
    % Convert the fiducials positions
    % The ChannelMat.SCS.NAS, LPA, RPA are in m, but the transform (R/T/Origin) is in mm.
    % Therefore convert the location to mm, but then store result in meters
    ChannelMat.SCS.NAS = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.NAS ./ 1000) .* 1000;
    ChannelMat.SCS.LPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.LPA ./ 1000) .* 1000;
    ChannelMat.SCS.RPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.RPA ./ 1000) .* 1000;

else
    % No fiducials are available : default transformation, rotation 90° / Z (ABNORMAL CASE)
    % Ask user whether to use default transformation MEGSCAN_SCS=>CTF or not
    isDefault = java_dialog('confirm', ...
        ['WARNING: ' 10 ...
        'Fiducial points (NAS,LPA,RPA) are not defined in the file.' 10 10 ...
        'They are needed to convert the sensors positions from MEGSCAN_SCS' 10 ...
        'coordinate system to Brainstorm format.' 10 10 ...
        'However, you can choose to apply a default rotation (90°Z).' 10 ...
        'The result will be less precise, so consider this option only if' 10 ...
        'you cannot obtain the positions of the fiducials.' 10 10 ...
        'Apply this default transformation ?'], 'Import FIF channel');
    if isDefault
        transfSCS = struct('R', [0 1 0; -1 0 0; 0 0 1], ...
            'T', [0; 0; 0]);
    else
        transfSCS = [];
    end
end
% If a MEGSCAN_SCS => SCS transformation was determined
if ~isempty(transfSCS)
    tMegscanScs2BstScs = double([transfSCS.R, transfSCS.T; 0 0 0 1]);
else
    tMegscanScs2BstScs = [];
end

if ~isempty(tMegscanScs2BstScs)  
    % Apply the translation to each MEG/EEG channel. Again, convert locations to mm
    % for the conversion, but then store the result in meters
    allChans = sort([iMeg iEeg]);
    for i = 1:length(allChans)
        % Converts the electrodes locations to SCS (subject coordinates system)
        if ~isempty(ChannelMat.Channel(allChans(i)).Loc)
            ChannelMat.Channel(allChans(i)).Loc = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.Channel(allChans(i)).Loc' ./ 1000)' .* 1000;
        end
        if ~isempty(ChannelMat.Channel(allChans(i)).Orient)
            ChannelMat.Channel(allChans(i)).Orient = ChannelMat.SCS.R * ChannelMat.Channel(allChans(i)).Orient;
        end
    end
    % Apply to coils, fiducials and headshape points
    if ~isempty(ChannelMat.HeadPoints) && ~isempty(ChannelMat.HeadPoints.Type) && ~isempty(ChannelMat.HeadPoints.Loc)
        ChannelMat.HeadPoints.Loc = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.HeadPoints.Loc' ./ 1000)' .* 1000;
    end

    % Store the transformations and the labels in the channel file
    ChannelMat.TransfMegLabels{end+1} = 'MegscanSCS=>Brainstorm/CTF';
    ChannelMat.TransfMeg{end+1} = tMegscanScs2BstScs;
    if ~isempty(iEeg)
        ChannelMat.TransfEegLabels{end+1} = 'MegscanSCS=>Brainstorm/CTF';
        ChannelMat.TransfEeg{end+1} = tMegscanScs2BstScs;
    end
end

end
