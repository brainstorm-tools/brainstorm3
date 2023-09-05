function [sFile, ChannelMat] = in_fopen_4d(DataFile, ImportOptions)
% IN_FOPEN_4D: Open a 4D-neuroimaging/BTi file, and get all the data and channel information.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_4d(DataFile, ImportOptions)
%         [sFile, ChannelMat] = in_fopen_4d(DataFile)
%
% INPUTS:
%     - DataFile   : Full path to file to open
%     - ImportOptions : Structure that describes how to import the recordings.
%       => Fields used: EventsMode, EventsTrackMode

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
% Authors: Francois Tadel, 2009-2016

%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end

%% ===== GET FILES =====
[dir4d, fBase, fExt] = bst_fileparts(DataFile);
% Look for headshape file (hs_file)
if file_exist(bst_fullfile(dir4d, 'hs_file'))
    HeadshapeFile = bst_fullfile(dir4d, 'hs_file');
else
    HeadshapeFile = '';
end
% Look for header file (config)
if file_exist(bst_fullfile(dir4d, 'config'))
    ConfigFile = bst_fullfile(dir4d, 'config');
else
    ConfigFile = '';
    error(['Error reading 4D/Bti recordings: No config file.' 10 10 ...
           'If you are trying to read recordings from another acquisition system,' 10 ...
           'please select the appropriate file format in the "Open file" dialog window.']);
end


%% ===== FOLDER NAME ====
% Get a meaningful folder name for the database explorer
[dirParent, name4d] = bst_fileparts(dir4d);
if ~isequal(name4d, '4D')
    Condition = name4d;
else
    [dirParent, Condition] = bst_fileparts(dirParent);
end
% Add the file name if there are multiple in the same category
baseName = [fBase, fExt];
% dirOthers = dir(bst_fullfile(dir4d, [baseName(1:2) '*']));
% if (length(dirOthers) > 1)
    Condition = [Condition, '_', file_standardize(baseName)];
% end

%% ===== READ HEADERS =====
% Read config file
header = read_4d_hdr(DataFile, ConfigFile);
% Read headshape file
if ~isempty(HeadshapeFile)
    hs = read_4d_hs(HeadshapeFile);
else
    hs = [];
end
header.hs = hs;


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.filename   = DataFile;
sFile.condition  = Condition;
sFile.format     = '4D';
sFile.device     = '4D';
sFile.comment    = '';
sFile.byteorder = 'b';
sFile.header     = header;
% Time and samples indices
nSamplesPre = double(round(header.header_data.FirstLatency * header.header_data.SampleFrequency));
nSamples    = double(header.epoch_data(1).pts_in_epoch);
sFile.prop.sfreq   = header.header_data.SampleFrequency;
sFile.prop.times   = double([-nSamplesPre, nSamples - nSamplesPre - 1]) ./ sFile.prop.sfreq;
sFile.prop.nAvg    = header.header_data.TotalEpochs;

%% ===== CHANNELS =====
% Initialize channels structure
nChannels = length(header.channel_data);
ChannelMat = db_template('channelmat');
ChannelMat.Comment = '4D channels';
% Get EEG channel definitions
if isfield(header, 'block_eeg_loc') && ~isempty(header.block_eeg_loc)
    eeg_def = header.user_block_data{header.block_eeg_loc};
else
    eeg_def = [];
end
% Loop on all the channels
for i = 1:nChannels
    % Get channel indice in full list of channels
    iChan = header.channel_data(i).chan_no;
    sChan = header.config.channel_data(iChan);
    % Get channel type
    switch (sChan.type)
        case 1,    ChannelMat.Channel(i).Type = 'MEG';
        case 2,    ChannelMat.Channel(i).Type = 'EEG';
        case 3,    ChannelMat.Channel(i).Type = 'MEG REF';
        case 4,    ChannelMat.Channel(i).Type = 'EXTERNAL';
        case 5,    ChannelMat.Channel(i).Type = 'Stim';
        case 6,    ChannelMat.Channel(i).Type = 'UTILITY';
        case 7,    ChannelMat.Channel(i).Type = 'DERIVED';
        case 8,    ChannelMat.Channel(i).Type = 'SHORTED';
        otherwise, ChannelMat.Channel(i).Type = 'Misc';
    end

    % === MEG ===
    if ismember(ChannelMat.Channel(i).Type, {'MEG','MEG REF'}) && isfield(sChan.device_data, 'total_loops') && (sChan.device_data.total_loops >= 1)
        % Get channel name
        ChannelMat.Channel(i).Name = sChan.name;
        % Position and orientation
        nCoils = sChan.device_data.total_loops;
        for iCoil = 1:nCoils
            ChannelMat.Channel(i).Loc(:,iCoil)    = sChan.device_data.loop_data(iCoil).position;
            ChannelMat.Channel(i).Orient(:,iCoil) = sChan.device_data.loop_data(iCoil).direction;
        end

        % Detect sensor type (reference in coil_def.dat)
        switch round(sChan.device_data.loop_data(1).radius * 2 * 1000)
            % MEG MAG: Magnes WH2500 magnetometer size = 23.00  mm
            case 23
                ChannelMat.Channel(i).Comment = '4001';
            % MEG: Magnes WH3600 gradiometer size = 18.00  mm base = 50.00  mm  / MAGNETOMETER
            case 18
                if (sChan.device_data.total_loops == 1)
                    ChannelMat.Channel(i).Comment = '4001';
                else
                    ChannelMat.Channel(i).Comment = '4002';
                end
            % REF MAG: Magnes reference magnetometer size = 30.00  mm
            case 30
                if ~strcmpi(ChannelMat.Channel(i).Type, 'MEG')
                    ChannelMat.Channel(i).Type = 'MEG REF';
                end
                ChannelMat.Channel(i).Comment = '4003';
            % REG GRAD AXIAL:  Magnes reference gradiometer (diag) size = 80.00  mm base = 135.00 mm
            % REG GRAD PLANAR: Magnes reference gradiometer (offdiag) size = 80.00  mm base = 135.00 mm.
            % 
            % WARNING: THESE SENSORS ARE NOT HANDLED WELL BY THE COIL_DEF.DAT: IGNORING ACCURATE MODELING
            case 80  
                % Vector between the two coils of the gradiometer
                c1c2 = ChannelMat.Channel(i).Loc(:,2) - ChannelMat.Channel(i).Loc(:,1);
                % Reference gradiometers (offdiag):  c1c2 perpendicular to coil orientation (ez)
                if (abs(sum(c1c2 .* ChannelMat.Channel(i).Orient(:,1))) < 1e-3)
                    ChannelMat.Channel(i).Comment = 'REF gradiometer (offdiag)';
                    %ChannelMat.Channel(i).Comment = '4005';                        %%%%%%%%%%%%%%%%%%%%%%%%%% THIS LINE SHOULD BE ENABLED FOR ACCURATE MODELING OF THE SENSOR
                % Reference gradiometers (diag):  c1c2 parallel to coil orientation (ez)
                else
                    ChannelMat.Channel(i).Comment = 'REF gradiometer (diag)';
                    %ChannelMat.Channel(i).Comment = '4004';                        %%%%%%%%%%%%%%%%%%%%%%%%%% THIS LINE SHOULD BE ENABLED FOR ACCURATE MODELING OF THE SENSOR
                end
        end
        
        % Weight
        if (nCoils == 1)
            ChannelMat.Channel(i).Weight = 1;
        elseif (nCoils == 2)
            ChannelMat.Channel(i).Weight  = [1 -1];
            % Keep only the orientation of the first coil (to match the weights: the original orientation of the 2nd coil is opposed)
            ChannelMat.Channel(i).Orient(:,2) = ChannelMat.Channel(i).Orient(:,1);        %%%%%%%%%%%%%%%%%%%%%%%%%% TRUSTING THE ORIENTATION GIVEN IN THE FILE
        else
            error('CTF sensors are not supposed to have more than two coils');
        end
        
    % === EEG ===
    elseif strcmpi(ChannelMat.Channel(i).Type, 'EEG')
        % Get channel name
        chname = strrep(header.channel_data(i).chan_label, '-1', '');
        ChannelMat.Channel(i).Name = chname;        
        % Get channel location
        if ~isempty(eeg_def)
            % Look for channel name in EEG sensors definitions
            iChanDef = find(cellfun(@(c)strcmpi(c,chname), eeg_def.label));
            % If channel defined, get location
            if ~isempty(iChanDef)
                ChannelMat.Channel(i).Loc = eeg_def.pnt(iChanDef,:)';
            end
        end
        
    % === OTHER CHANNELS ===
    else
        % Get channel name
        ChannelMat.Channel(i).Name = sChan.name;
    end
end
% No list of bad channels in 4D files => all good
ChannelFlag = ones(length(ChannelMat.Channel), 1);
sFile.channelflag = ChannelFlag;


%% ===== TEMPLATE COILS DEFINITION =====
% Add definition of sensors
ChannelMat.Channel = ctf_add_coil_defs(ChannelMat.Channel, '4D');


%% ===== HEAD POINTS =====
if ~isempty(header.hs)
    nPoints = size(header.hs.points,1);
    ChannelMat.HeadPoints.Loc   = header.hs.points';
    ChannelMat.HeadPoints.Type  = repmat({'EXTRA'}, 1, nPoints);
    ChannelMat.HeadPoints.Label = repmat({''}, 1, nPoints);
% If head points were not acquired
else
    % Get all the positions of the MEG channels
    iMeg = channel_find(ChannelMat.Channel, 'MEG');
    allLoc = [ChannelMat.Channel(iMeg).Loc];
    % Check if most of the MEG channels are below z=0
    if (nnz(allLoc(3,:)<0) / size(allLoc,2) > 0.70)
        % Apply default translation towards CTF coordinates system
        DefaultT = [-.02; 0; .17];
        disp(sprintf('BST> Warning: Head points were not acquired. Using a default transformation: translation [%1.2f, %1.2f, %1.2f]', DefaultT));
        % Process all the locations
        for i = 1:length(ChannelMat.Channel)
            if ~isempty(ChannelMat.Channel(i).Loc)
                ChannelMat.Channel(i).Loc = bst_bsxfun(@plus, ChannelMat.Channel(i).Loc, DefaultT);
            end
        end
    else
        disp('BST> Warning: Head points were not acquired. Head position might be wrong.');
    end
end


%% ===== COMPENSATION MATRIX =====
% Code based on bti2grad function from FieldTrip, written by Jan-Mathijs Schoffelen (2008)
% Get compensation block
iCompBlock = find(cellfun(@(c)strcmpi(c.type,'B_weights_used'), header.user_block_data));
if ~isempty(iCompBlock)
    % Display warning
    disp([10 '******************************************************************************************' 10 ...
          '******************************************************************************************' 10 ...
          '*** WARNING: The support for the 4D MEG system might be incomplete. Pending issues:    ***' 10 ...
          '***  - The orientation of the reference gradiometers is not clearly understood         ***' 10 ...
          '***  - The accurate sensor modeling from the file coil_def.dat is not used             ***' 10 ...
          '***  - The references positions are commonly wrong because bugs in the 4D calibration  ***' 10 ...
          '***  - The noise compensation is considered to be already applied on the recordings    ***' 10 ...
          '***  => Most of these issues may impact the quality of the source reconstruction       ***' 10 ...
          '***  => Please contact us on the forum if you would like to help us debug these issues ***' 10 ...
          '***  => Similar issues are to be expected in MNE, MNE-Python and FieldTrip.            ***' 10 ...
          '******************************************************************************************' 10 ...
          '******************************************************************************************' 10]);
    % Get data block
    block = header.user_block_data{iCompBlock};
    % Different versions of this block (maybe for different 4D machines)
    if (block.version == 1)
        % Old version: the user_block does not contain labels to the channels and references
        % Assuming the channel order as they occur in the header and the refchannel order M.A M.aA G.A');
        iMeg = good_channel(ChannelMat.Channel, [], {'MEG'});
        block.channames = {ChannelMat.Channel(iMeg).Name}';
        block.dweights = block.dweights(iMeg,:);
        block.aweights = block.aweights(iMeg,:);
        block.drefnames = {'MxA';'MyA';'MzA';'MxaA';'MyaA';'MzaA';'GxxA';'GyyA';'GyxA';'GzxA';'GzyA'};
        block.arefnames = {'MCxA';'MCyA';'MCzA'};
    end
    % Get MEG and MEG REF channels indices in ChannelMat
    iMeg = good_channel(ChannelMat.Channel, [], 'MEG');
    iRef = good_channel(ChannelMat.Channel, [], 'MEG REF');
    
    % Get each MEG channel indice in the dweights matrix
    iMegBst = [];
    iMeg4D  = [];
    for i = 1:length(iMeg)
        % Find sensor name
        iTmp = find(strcmpi(ChannelMat.Channel(iMeg(i)).Name, block.channames));
        % If sensor found in compensation matrix
        if ~isempty(iTmp)
            iMegBst(end+1) = i;
            iMeg4D(end+1)  = iTmp;
        end
    end
    
    % Get each REF channel indice in the dweights matrix
    iRefBst = [];
    iRef4D  = [];
    for i = 1:length(iRef)
        % Find sensor name
        iTmp = find(strcmpi(ChannelMat.Channel(iRef(i)).Name, block.drefnames));
        % If sensor found in compensation matrix
        if ~isempty(iTmp)
            iRefBst(end+1) = i;
            iRef4D(end+1)  = iTmp;
        end
    end
    
    % Initialize returned matrix
    ChannelMat.MegRefCoef = zeros(length(iMeg), length(iRef));
    % Copy values in final compensation matrix
    ChannelMat.MegRefCoef(iMegBst, iRefBst) = block.dweights(iMeg4D, iRef4D);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % TODO: Analog weights? Are we supposed to ignore them in forward model computation ?
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Code for 4D compensation (already applied): 101 (from MNE)
    sFile.prop.destCtfComp = 101;
    sFile.prop.currCtfComp = 101;
else
    % No compensation available
    sFile.prop.destCtfComp = 0;
    sFile.prop.currCtfComp = 0;
end


%% ===== EPOCHS FILE =====
if strcmpi(header.file_type, 'average')
    nEpochs = header.header_data.TotalEpochs;
else
    nEpochs = 0;
end
if (nEpochs > 1)
    % Build epochs structure
    for i = 1:nEpochs
        sFile.epochs(i).label = sprintf('Epoch (#%d)', i);
        sFile.epochs(i).times   = sFile.prop.times;
        sFile.epochs(i).nAvg    = 1;
        sFile.epochs(i).select  = 1;
        sFile.epochs(i).bad         = 0;
        sFile.epochs(i).channelflag = [];
    end
end

     
%% ===== EVENTS: TRIGGER TRACK =====
% Read markers file
if strcmpi(header.file_type, 'raw') && (iscell(ImportOptions.EventsMode) || (~strcmpi(ImportOptions.EventsMode, 'ignore') && ~file_exist(ImportOptions.EventsMode)))
    % Read file
    sFile.events = process_evt_read('Compute', sFile, ChannelMat, ImportOptions.EventsMode, ImportOptions.EventsTrackMode);
    % Operation cancelled by user
    if isequal(sFile.events, -1)
        sFile = [];
        ChannelMat = [];
        return;
    end
end


%% ===== EVENTS: USER DEFINED =====
% Convert 'BTi_selection' process into brainstorm events
if isfield(header, 'process') && isfield(header.process, 'type')
    % Look for 'BTi_selection' process in processes lists
    iProcs = find(strcmpi({header.process.type}, 'BTi_selection'));
    % Loop over the processes found
    for i = 1:length(iProcs)
        proc = header.process(iProcs(i));
        if isfield(proc, 'step') && ~isempty(proc.step) && isfield(proc.step, 'type')
            % Look for 'b_selection' steps in process
            iSteps = find(strcmpi({proc.step.type}, 'b_selection'));
            % Loop over all the steps found (each step represent a marker)
            for j = 1:length(iSteps)
                step = proc.step(iSteps(j));
                
                % === GET EVENT ===
                % Get event label (remove the occurrence number, after the #)
                iPound = strfind(step.uservalue2,'#');
                if ~isempty(iPound) && (iPound(1) > 1)
                    evtLabel = step.uservalue2(1:iPound(1)-1);
                else
                    evtLabel = step.uservalue2;
                end
                % Get event time
                evtTime = step.uservalue1(1);
                
                % === ADD EVENT ===
                % Find this event in list of events
                if ~isempty(sFile.events)
                    iEvent = find(strcmpi({sFile.events.label}, evtLabel));
                else
                    iEvent = [];
                end
                % If event does not exist yet: add it
                if isempty(iEvent)
                    if isempty(sFile.events)
                        iEvent = 1;
                        sFile.events = db_template('event');
                    else
                        iEvent = length(sFile.events) + 1;
                        sFile.events(iEvent) = db_template('event');
                    end
                    sFile.events(iEvent).label = evtLabel;
                end
                % Add occurrence of this event
                iOcc = length(sFile.events(iEvent).times) + 1;
                sFile.events(iEvent).epochs(iOcc)   = 1;
                sFile.events(iEvent).times(iOcc)    = round(evtTime .* sFile.prop.sfreq) ./ sFile.prop.sfreq;
            end
        end
    end
end







