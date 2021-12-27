function [sFile, ChannelMat] = in_fopen_megscan(DataFile)
% IN_FOPEN_MEGSCAN: Open a MEGSCAN file (York-Instruments), and get all the data and channel information.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_megscan(DataFile)

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
% Authors: Elizabeth Bock, 2019
%          Richard Aveyard, 2021

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

% Read information of interest
hdr.format = 'MEGSCAN-HDF5';
hdr.acquisitionname = pAcq;
AcqInfo = h5info(DataFile,pAcq,'TextEncoding','UTF-8');
% Datasets
hdr.channelname = h5read(DataFile,[pAcq '/channel_list/']);
hdr.numberchannels = size(hdr.channelname, 1);
Data = h5read(DataFile,[pAcq '/data/']);
hdr.nTime = size(Data,2);

% Acquisition Attributes: Mandatory
try
hdr.Type = h5readatt(DataFile,pAcq,'acq_type');
hdr.Seq = h5readatt(DataFile,pAcq,'sequence'); % Order of when acquisitions were recorded (ie first acquisition has sequence=1, second has sequence=2)
hdr.SampleRate = h5readatt(DataFile,pAcq,'sample_rate');
hdr.StartTime = h5readatt(DataFile,pAcq,'start_time');
catch
    error('Invalid MEGSCAN HDF5 file: Missing mandatory acquisition attributes');
end
% Acquisition Attributes: Optional
hdr.Desc = '';
hdr.UpbApplied = 0;
hdr.WeightsConfig = [];
hdr.WeightsApplied = [];
hdr.CohActive = [];
hdr.SubjPos = '';
attnames = {AcqInfo.Attributes.Name};
if ismember('description',attnames)
    hdr.Desc = h5readatt(DataFile,pAcq,'description');
end
if ismember('upb_applied',attnames)
    hdr.UpbApplied = h5readatt(DataFile,pAcq,'upb_applied');
end
if ismember('weights_configured',attnames)
    hdr.WeightsConfig = h5readatt(DataFile,pAcq,'weights_configured');
end
if ismember('weights_applied',attnames)
    hdr.WeightsApplied = h5readatt(DataFile,pAcq,'weights_applied');
end
if ismember('coh_active',attnames)
    hdr.CohActive = h5readatt(DataFile,pAcq,'coh_active');
end
if ismember('subject_position',attnames)
    hdr.SubjPos = h5readatt(DataFile,pAcq,'subject_position');
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
% keep track of which device the data was originally scanned
if contains(model,'WHS')
    sFile.device = '4d';
elseif contains(model,'MEGSCAN')
    sFile.device = 'MEGSCAN channels';
else
    sFile.device = model;
end
sFile.byteorder = 'b';

% Properties of the recordings
sFile.prop.samples = [0, hdr.nTime-1] - hdr.pretrigger;
sFile.prop.sfreq   = double(hdr.SampleRate);
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
sFile.channelflag  = ones(hdr.numberchannels,1); % GOOD=1; BAD=-1;
% Epochs, if any
if (hdr.nEpochs > 1)
    for i = 1:hdr.nEpochs
        sFile.epochs(i).label   = sprintf('Trial #%d', i);
        sFile.epochs(i).samples = sFile.prop.samples;
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
    sFile.events(iEvt).samples = hdr.marker(iOcc,1)';
    sFile.events(iEvt).epochs  = hdr.marker(iOcc,2)';
    if ~isempty(sFile.epochs)
        for i = 1:length(sFile.events(iEvt).samples)
            iEpoch =  sFile.events(iEvt).epochs(i);
            sFile.events(iEvt).samples(i) = sFile.events(iEvt).samples(i) + sFile.epochs(iEpoch).samples(1) - 1;
        end
    end
    sFile.events(iEvt).times   = sFile.events(iEvt).samples ./ sFile.prop.sfreq;
    sFile.events(iEvt).select  = 1;
end

%% ===== CHANNELS STRUCTURE =====
% Initialize structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = sFile.device;
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
   
    % If the Units-per-bit has not been applied, then store this value here in the weight field for application later
    if hdr.UpbApplied == 0
        upb = h5readatt(DataFile,['/config/channels/' hdr.channelname{iChan} ],'units_per_bit');
        hdr.ChannelUnitsPerBit(iChan) = upb;
    end

    switch type
        case {'ANALOG'}
            try
                comment = h5readatt(DataFile,['/config/channels/' hdr.channelname{iChan} ],'mode');
                if iscell(comment)
                    comment = char(comment);
                end
                ChannelMat.Channel(iChan).Comment = comment;
            catch
                disp('');
            end
        case {'COH'}
            % coh_active is mandatory
        case {'DIGITAL'}
            try
                comment = h5readatt(DataFile,['/config/channels/' hdr.channelname{iChan} ],'mode');
                if iscell(comment)
                    comment = char(comment);
                end
                ChannelMat.Channel(iChan).Comment = comment;
            catch
                disp('');
            end
        case {'EEG', 'EEGREF'}
            %gain = h5readatt(DataFile,['/config/channels/' hdr.channelname{iChan} ],'gain'); %TODO
            
            try
                points = h5read(DataFile,lower(['/geometry/eeg/' hdr.channelname{iChan} '/location'])) ./1000;
                ChannelMat.Channel(iChan).Loc = points(:,1)';
                comment = hdr.channelname{iChan}
                if iscell(comment)
                    comment = char(comment);
                end

                ChannelMat.Channel(iChan).Comment = comment;

	    catch
                disp('No EEG locations')
            end
            
        case {'MEG', 'MEGREF'}
            try
                ChannelMat.Channel(iChan).Loc = h5read(DataFile,['/config/channels/' hdr.channelname{iChan} '/position']) ./1000; %m
                ChannelMat.Channel(iChan).Orient = h5read(DataFile,['/config/channels/' hdr.channelname{iChan} '/orientation']);

                comment = h5read(DataFile,['/config/channels/' hdr.channelname{iChan} '/loop_shape']);
                if iscell(comment)
                    comment = char(comment);
                end

                ChannelMat.Channel(iChan).Comment = comment;
	    catch
                disp(['no orientation or location for ' hdr.channelname{iChan}])
                ChannelMat.Channel(iChan).Loc = [];
                ChannelMat.Channel(iChan).Orient  = [];
            end

        case {'TEMPERATURE'}

        case {'UNKNOWN'}
    end

end
%% Compensation
% ===== Weights =====
%Find and store the reference coefficients (de-noising weights)
%/config/weights/ are interpreted as weighting factors to apply to a
%channel's samples to remove background noise from the data. The number of
%rows is the same as the number of strings in tgt_chans, and the number of
%columns is the same as the number of strings in ref_chans.

try
    tgt_chans = h5read(DataFile,['/config/weights/' hdr.WeightsApplied{1} '/tgt_chans']); 
    ref_chans = h5read(DataFile,['/config/weights/' hdr.WeightsApplied{1} '/ref_chans']);;
    weights   = h5read(DataFile,['/config/weights/' hdr.WeightsApplied{1} '/weights']);


    % Get MEG and MEG REF channels indices in ChannelMat
    iMeg = good_channel(ChannelMat.Channel, [], 'MEG');
    iRef = good_channel(ChannelMat.Channel, [], 'MEGREF');

    % Get each MEG channel indice in the weights matrix
    iMegBst = [];
    iMegW  = [];
    for i = 1:length(iMeg)
        % Find sensor name
        iTmp = find(strcmpi(ChannelMat.Channel(iMeg(i)).Name, tgt_chans));
        % If sensor found in compensation matrix
        if ~isempty(iTmp)
            iMegBst(end+1) = i;
            iMegW(end+1)  = iTmp;
        end
    end

    % Get each REF channel indice in the weights matrix
    iRefBst = [];
    iRefW  = [];
    for i = 1:length(iRef)
        % Find sensor name
        iTmp = find(strcmpi(ChannelMat.Channel(iRef(i)).Name, ref_chans));
        % If sensor found in compensation matrix
        if ~isempty(iTmp)
            iRefBst(end+1) = i;
            iRefW(end+1)  = iTmp;
        end
    end

    % Initialize returned matrix
    ChannelMat.MegRefCoef = zeros(length(iMeg), length(iRef));
    % Copy values in final compensation matrix
    ChannelMat.MegRefCoef(iMegBst, iRefBst) = weights(iMegW, iRefW);
catch
    disp('No de-noising weights available');
    weights = [];
end

% Code for compensation (already applied): 101 (from MNE) %TODO, how to handle this?

if isempty(hdr.WeightsApplied) && ~isempty(weights)
    % weights are available and have not been applied
    sFile.prop.destCtfComp = 101;
    sFile.prop.currCtfComp = 0;
elseif ~isempty(hdr.WeightsApplied) && ~isempty(weights)
    % weights are availabe and have been previously applied    
    sFile.prop.destCtfComp = 101;
    sFile.prop.currCtfComp = 101;
else
    % No compensation available
    sFile.prop.destCtfComp = 0;
    sFile.prop.currCtfComp = 0;
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
        ChannelMat.HeadPoints.Loc(:,npoints) =  mean(points(:,1),2) ./1000; %(m) % Mean position over all digizations for the session
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
    isFIDs = true;
catch
    isFIDs = false;
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

try
    info = h5info(DataFile,'/geometry/eeg','TextEncoding','UTF-8');
    for iPt = 1:size(info.Groups,1)
        name = info.Groups(iPt).Name;
        spl = regexp(name,'/','split');
        points = h5read(DataFile,[info.Groups(iPt).Name '/location']);
        npoints = npoints+1;
        % Store headpoints in meters
        ChannelMat.HeadPoints.Loc(:,npoints) = points ./1000;
        ChannelMat.HeadPoints.Label{npoints} = spl{end};
        ChannelMat.HeadPoints.Type{npoints} = 'EEG';
    end
catch
    disp('No digitized EEG locations')
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
iNas = [];
iLpa = [];
iRpa = [];
if isFIDs
    iNas = find(~cellfun(@isempty,regexp(ChannelMat.HeadPoints.Label,'nas')));
    iLpa = find(~cellfun(@isempty,regexp(ChannelMat.HeadPoints.Label,'lpa')));
    iRpa = find(~cellfun(@isempty,regexp(ChannelMat.HeadPoints.Label,'rpa')));
end
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
    ChannelMat.SCS.R      = transfSCS.R;
    ChannelMat.SCS.T      = transfSCS.T;
    ChannelMat.SCS.Origin = [0,0,0];
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
% Store the header info in the file
sFile.header = hdr;
end
