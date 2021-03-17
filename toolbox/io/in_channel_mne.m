function [ChannelMat, Device, currCtfComp] = in_channel_mne( pyObj, ImportOptions )
% IN_CHANNEL_MNE: Create a Brainstorm channel structure from a MNE-Python object
%
% USAGE:  [ChannelMat, Device] = in_channel_mne( sFile, ImportOptions )
%         [ChannelMat, Device] = in_channel_mne( sFile )
% 
% INPUT:
%     - ImportOptions : Structure that describes how to import the recordings.
%        => Fields used: ChannelAlign, DisplayMessages

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2019
%          Transposition of in_channel_fif.m for MNE-Python objects


%% ===== PARSE INPUTS =====
% Check inputs
pyModules = py.sys.modules;
if ~py.isinstance(pyObj, pyModules{'mne.io'}.BaseRaw)
    error(['Unsupported class: ' class(pyObj)]);
end
if (nargin < 2) || isempty(ImportOptions)
    ImportOptions = db_template('ImportOptions');
end

% Get some fields in the sFile structure
info = pyObj.info;
% Initialize returned structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'FIF channels';
% Get MNE-matlab FIFF constants
global FIFF;
if isempty(FIFF)
   FIFF = fiff_define_constants();
end
% Get py FIFF constants
pyFIFF = py.mne.io.constants.FIFF;


                
%% ===== COORDINATES SYSTEM =====
% Only if measurments were read
% disp([10 'Preprocessing...']);
% If a "DEVICE => CTF" transformation is already defined in the file
if ~isa(info{'dev_ctf_t'}, 'py.NoneType')
    meg_trans = struct(...
        'from',  bst_py2mat(info{'dev_ctf_t'}{'from'}), ...
        'to',    bst_py2mat(info{'dev_ctf_t'}{'to'}), ...
        'trans', bst_py2mat(info{'dev_ctf_t'}{'trans'}));
    meg_trans_label{1} = 'neuromag_device=>ctf_head';
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% ????? WHICH TRANSFORM TO APPLY TO EEG ?????? %%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    ctf_head_t = struct(...
        'from',  bst_py2mat(info{'ctf_head_t'}{'from'}), ...
        'to',    bst_py2mat(info{'ctf_head_t'}{'to'}), ...
        'trans', bst_py2mat(info{'ctf_head_t'}{'trans'}));
    eeg_trans = fiff_invert_transform(ctf_head_t);
    eeg_trans_label{1} = 'inv(neuromag_device=>ctf_head)';
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fprintf(1,'\tEmploying the CTF/4D head coordinate system\n');

% Else, use "DEVICE => NEUROMAG" and "NEUROMAG => CTF" (STANDARD CASE)
else
    % ==== DEVICE => NEUROMAG ====
    % If "DEVICE => NEUROMAG" transformation is not defined (ABNORMAL CASE)
    if isa(info{'dev_head_t'}, 'py.NoneType')
        % Use neutral matrix and display warning
        tDevice2Neuromag = struct('from', FIFF.FIFFV_COORD_DEVICE, ...
                                  'to',   FIFF.FIFFV_COORD_HEAD, ...
                                  'trans', [1   0   0   0; ...
                                            0   1   0   0; ...
                                            0   0   1 .04; ...
                                            0   0   0   1]);
        % Warning
        if ImportOptions.DisplayMessages
            java_dialog('warning', ['The "DEVICE=>HEAD" transformation is missing in FIF file.' 10 ...
                                    'Maybe the HPI coils positions were not acquired correctly.' 10 10 ...
                                    'Using a default transformation instead (4cm translation in Z).' 10 ...
                                    'The head will not be properly aligned...' 10 10], 'Import FIF channel');
        end
    else
        % Get transformation : "DEVICE => NEUROMAG"
        tDevice2Neuromag = struct(...
            'from',  bst_py2mat(info{'dev_head_t'}{'from'}), ...
            'to',    bst_py2mat(info{'dev_head_t'}{'to'}), ...
            'trans', bst_py2mat(info{'dev_head_t'}{'trans'}));
    end

    % ==== NEUROMAG => CTF ====
    if ~isa(info{'dig'}, 'py.NoneType')
        kind = cellfun(@(c)bst_py2mat(c{'kind'}), cell(info{'dig'}));
        ident = cellfun(@(c)bst_py2mat(c{'ident'}), cell(info{'dig'}));
        % Get fiducials (NASION, LPA, RPA)
        iNas = find((kind == bst_py2mat(pyFIFF.FIFFV_POINT_CARDINAL)) & (ident == bst_py2mat(pyFIFF.FIFFV_POINT_NASION)), 1);
        iLpa = find((kind == bst_py2mat(pyFIFF.FIFFV_POINT_CARDINAL)) & (ident == bst_py2mat(pyFIFF.FIFFV_POINT_LPA)), 1);
        iRpa = find((kind == bst_py2mat(pyFIFF.FIFFV_POINT_CARDINAL)) & (ident == bst_py2mat(pyFIFF.FIFFV_POINT_RPA)), 1);
    else
        iNas = [];
        iLpa = [];
        iRpa = [];
    end
    % Compute rotation/translation to convert coordinates system : NEUROMAG => CTF
    if ~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa)
        % Compute transformation
        sMriTmp.SCS.NAS = bst_py2mat(info{'dig'}{iNas}{'r'});
        sMriTmp.SCS.LPA = bst_py2mat(info{'dig'}{iLpa}{'r'});
        sMriTmp.SCS.RPA = bst_py2mat(info{'dig'}{iRpa}{'r'});
        transfTmp = cs_compute(sMriTmp, 'scs');
    % No fiducials are available : default transformation, rotation 90° / Z (ABNORMAL CASE)
    else
        % Ask user whether to use default transformation NEUROMAG=>CTF or not
        if (ImportOptions.ChannelAlign == 1)
            isDefault = java_dialog('confirm', ...
                ['WARNING: ' 10 ...
                 'Fiducial points (NAS,LPA,RPA) are not defined in the FIF file.' 10 10 ...
                 'They are needed to convert the sensors positions from Neuromag' 10 ...
                 'coordinate system to Brainstorm format.' 10 10 ...
                 'However, you can choose to apply a default rotation (90°Z).' 10 ...
                 'The result will be less precise, so consider this option only if' 10 ...
                 'you cannot obtain the positions of the fiducials.' 10 10 ...
                 'Apply this default transformation ?'], 'Import FIF channel');
            if isDefault
                ImportOptions.ChannelAlign = 2;
            else
                ImportOptions.ChannelAlign = 0;
            end
        end
        if (ImportOptions.ChannelAlign >= 1)
            transfTmp = struct('R', [0 1 0; -1 0 0; 0 0 1], ...
                               'T', [0; 0; 0]);
        else
            transfTmp = [];
        end
    end
    % If a Neuromag => SCS transformation was determined
    if ~isempty(transfTmp)
        % Build standard MNE transformation structure
        tNeuromag2Scs = struct('from', FIFF.FIFFV_COORD_HEAD, ...
                               'to',   FIFF.FIFFV_COORD_HEAD, ...
                               'trans', double([transfTmp.R, transfTmp.T; 0 0 0 1]));
        % Final transformations to apply to EEG and MEG sensors locations
        meg_trans = [tDevice2Neuromag, tNeuromag2Scs];  % MEG: DEVICE => HEAD/NEUROMAG => SCS/CTF
        eeg_trans = tNeuromag2Scs;                      % EEG: HEAD/NEUROMAG => SCS/CTF
        meg_trans_label = {'neuromag_device=>neuromag_head', 'neuromag_head=>scs'};
        eeg_trans_label = {'neuromag_head=>scs'};
    else
        meg_trans = tDevice2Neuromag;
        eeg_trans = [];
        meg_trans_label = {'neuromag_device=>neuromag_head'};
        eeg_trans_label = {};
    end
end

% Convert channels to FIFF-style Matlab structure
if ~isa(info{'chs'}, 'py.NoneType')
    nChannels = length(info{'chs'});
    for iChan = 1:nChannels
        pyCh = info{'chs'}{iChan};
        chs(iChan).kind        = bst_py2mat(pyCh{'kind'});
        chs(iChan).coil_type   = bst_py2mat(pyCh{'coil_type'});
        chs(iChan).loc         = bst_py2mat(pyCh{'loc'})';
        chs(iChan).unit        = bst_py2mat(pyCh{'unit'});
        chs(iChan).unit_mul    = bst_py2mat(pyCh{'unit_mul'});
        chs(iChan).ch_name     = bst_py2mat(pyCh{'ch_name'});
        chs(iChan).coord_frame = bst_py2mat(pyCh{'coord_frame'});
        chs(iChan).cal         = bst_py2mat(pyCh{'cal'});
        chs(iChan).eeg_loc     = [];
        % Add extra fields
        if (chs(iChan).kind == FIFF.FIFFV_MEG_CH) || (chs(iChan).kind == FIFF.FIFFV_REF_MEG_CH)
            chs(iChan).coil_trans  = [ [ chs(iChan).loc(4:6), chs(iChan).loc(7:9), chs(iChan).loc(10:12), chs(iChan).loc(1:3) ] ; [ 0 0 0 1 ] ];
        elseif (chs(iChan).kind == FIFF.FIFFV_EEG_CH)
            if norm(chs(iChan).loc(4:6)) > 0
                chs(iChan).eeg_loc = [chs(iChan).loc(1:3), chs(iChan).loc(4:6)];
            else
                chs(iChan).eeg_loc = chs(iChan).loc(1:3);
            end
        end
    end
else
    chs = [];
end
    
% Apply transformations
if ~isempty(chs)
    % Save initial EEG electrodes positions          
    oldEegLoc = {chs.eeg_loc};
    % Transform coil and electrode locations to the desired coordinate frame
    for i = 1:length(meg_trans)
        chs = fiff_transform_meg_chs(chs, meg_trans(i));
    end
    for i = 1:length(eeg_trans)
        chs = fiff_transform_eeg_chs(chs, eeg_trans(i));
    end
end
% Store the transformations in the output file
if ~isempty(meg_trans)
    ChannelMat.TransfMeg = {meg_trans.trans};
    ChannelMat.TransfMegLabels = meg_trans_label;
else
    ChannelMat.TransfMeg = [];
    ChannelMat.TransfMegLabels = [];
end
if ~isempty(eeg_trans)
    ChannelMat.TransfEeg = {eeg_trans.trans};
    ChannelMat.TransfEegLabels = eeg_trans_label;
else
    ChannelMat.TransfEeg = [];
    ChannelMat.TransfEegLabels = [];
end

% Localize coils definition file
coil_def_file = which('coil_def.dat');
if isempty(coil_def_file)
    error('Coils definition file was not found in path: coil_def.dat');
end
% Load coils definition file
templates = mne_load_coil_def(coil_def_file);
Accuracy = 1;
chs = mne_add_coil_defs(chs,Accuracy,templates);
% fprintf(1,'\nReady.\n\n');


%% ===== BUILD CHANNEL STRUCTURE =====
Device = '';
if ~isempty(chs)
    nRef = 0; %number of reference sensors
    nMEG = 0; %number of MEG channels
    for i = 1:nChannels  
        ch_kind = chs(i).kind;
        % === LOCATION / ORIENTATION ===
        if (ch_kind == FIFF.FIFFV_EEG_CH) && ~isempty(chs(i).eeg_loc)
            Channel(i).Loc = chs(i).eeg_loc(:,1);
            Channel(i).Orient = [];
            Channel(i).Weight = 1;
            Channel(i).Comment = chs(i).coil_def.description;
        elseif ~isempty(chs(i).coil_def)
            X = chs(i).coil_def.coildefs;
            Channel(i).Loc = X(:,2:4)';
            Channel(i).Orient = X(:,5:7)';
            Channel(i).Weight = X(:,1)';
            Channel(i).Comment = chs(i).coil_def.description;
        else
            Channel(i).Loc = [];
            Channel(i).Orient = [];
            Channel(i).Weight = [];
            Channel(i).Comment = [];
        end
        % === TYPE ===
        switch ch_kind
            % === MEG ===
            case FIFF.FIFFV_MEG_CH
                if ~isempty(strfind(lower(Channel(i).Comment), 'vectorview planar gradiometer'))
                    Channel(i).Type = 'MEG GRAD';
                elseif ~isempty(strfind(lower(Channel(i).Comment), 'vectorview magnetometer'))
                    Channel(i).Type = 'MEG MAG';
                elseif ~isempty(strfind(lower(Channel(i).Comment), 'compensation magnetometer'))
                    Channel(i).Type = 'MEG REF';
                else
                    Channel(i).Type = 'MEG';
                end
                % Detect machine type
                if isempty(Device)
                    if ~isempty(strfind(lower(Channel(i).Comment), 'magnes'))
                        Device = '4D';
                    elseif ~isempty(strfind(lower(Channel(i).Comment), 'ctf'))
                        Device = 'CTF';
                    elseif ~isempty(strfind(lower(Channel(i).Comment), 'kit'))
                        Device = 'KIT';
                    elseif ~isempty(strfind(lower(Channel(i).Comment), 'babysquid'))
                        Device = 'BabySQUID';
                    elseif ~isempty(strfind(lower(Channel(i).Comment), 'babymeg'))
                        Device = 'BabyMEG';
                    elseif ~isempty(strfind(lower(Channel(i).Comment), 'ricoh'))
                        Device = 'RICOH';
                    else
                        Device = 'Neuromag';
                    end
                end
                nMEG = nMEG + 1;
            % === MEG REF ===
            case FIFF.FIFFV_REF_MEG_CH 
                Channel(i).Type = 'MEG REF';
                nRef = nRef + 1;
            % === EEG ===
            case FIFF.FIFFV_EEG_CH
                if ~all(Channel(i).Loc(:,1) == 0) && ~all(oldEegLoc{i}(:,1) == 0)
                    Channel(i).Type = 'EEG';
                else
                    Channel(i).Type = 'EEG BAD LOC';
                end 
            % === OTHER CHANNELS ===
            case FIFF.FIFFV_STIM_CH,  Channel(i).Type = 'Stim';
            case FIFF.FIFFV_MCG_CH,   Channel(i).Type = 'MCG';
            case FIFF.FIFFV_EOG_CH,   Channel(i).Type = 'EOG';
            case FIFF.FIFFV_EMG_CH,   Channel(i).Type = 'EMG';   
            case FIFF.FIFFV_ECG_CH,   Channel(i).Type = 'ECG'; 
            case FIFF.FIFFV_MISC_CH,  Channel(i).Type = 'Misc'; 
            case FIFF.FIFFV_RESP_CH,  Channel(i).Type = 'RESP'; 
            otherwise,  Channel(i).Type = 'Misc';
        end
        
        % === NAME ===
        ch_name = chs(i).ch_name;
        % Remove everything that is after a '-'
        iTiret = strfind(ch_name, '-');
        if ~isempty(iTiret) && (iTiret ~= 1)
            Channel(i).Name = ch_name(1:iTiret-1);
        else
            Channel(i).Name = ch_name;
        end
    end
    % If device was not detected: Neuromag by default
    if isempty(Device)
        Device = 'Neuromag';
    end
    % Returned Channel structure
    ChannelMat.Channel = Channel;
    ChannelMat.Comment = [Device ' channels'];
else
    ChannelMat.Channel = repmat(struct('Name','','Type','','Loc',[],'Orient',[],'Comment','','Weight',[]), 0);
    ChannelMat.Comment = 'FIF head points';
end

%% ===== COMPENSATION MATRIX =====
% Get CTF compensation
if (length(info{'comps'}) > 0)
    % Get indices of MEG and REF sensors
    iMeg = good_channel(ChannelMat.Channel, [], 'MEG');
    iRef = good_channel(ChannelMat.Channel, [], 'MEG REF');
    
    % Get the current CTF compensation order
    currentComp = bitshift(double([chs(iMeg).coil_type]), -16);
    % If not all the same value: error
    if ~all(currentComp == currentComp(1))
        error('CTF compensation is not set equally on all MEG channels');
    end
    % Current compensation order
    currCtfComp = currentComp(1);
    
    % Get the corresponding coefficients for this order
    iCompValid = [];
    for iComp = 1:length(info{'comps'})
        if (bst_py2mat(info{'comps'}{iComp}{'kind'}) == currCtfComp)
            iCompValid = [iCompValid, iComp];
        end
    end
    % Initialize returned matrix
    MegRefCoef = zeros(length(iMeg), length(iRef));
    % Process all the valid compensations fiels
    for i = 1:length(iCompValid)
        iComp = iCompValid(i);
        % Find reference sensor indices
        refNames = cellfun(@char, cell(info{'comps'}{iComp}{'data'}{'col_names'}.tolist()), 'UniformOutput', 0);
        iRefDest = [];
        iRefSrc  = [];
        for ich = 1:length(refNames)
            iTmp = find(strcmpi({chs(iRef).ch_name}, refNames{ich}));
            if ~isempty(iTmp)
                iRefSrc = [iRefSrc, ich];
                iRefDest = [iRefDest, iTmp];
            end
        end
        % Find data sensors indices
        megNames = cellfun(@char, cell(info{'comps'}{iComp}{'data'}{'row_names'}), 'UniformOutput', 0);
        iMegDest = [];
        iMegSrc  = [];
        for ich = 1:length(megNames)
            iTmp = find(strcmpi({chs(iMeg).ch_name}, megNames{ich}));
            if ~isempty(iTmp)
                iMegSrc = [iMegSrc, ich];
                iMegDest = [iMegDest, iTmp];
            end
        end
        % Brainstorm reference sensor index
        data = bst_py2mat(info{'comps'}{iComp}{'data'}{'data'});
        MegRefCoef(iMegDest,iRefDest) = data(iMegSrc,iRefSrc);
    end
else
    MegRefCoef = [];
    currCtfComp = [];
end
ChannelMat.MegRefCoef = MegRefCoef;


%% ===== SSP =====
% Signal Space Projectors
if (length(info{'projs'}) > 0)
    % Convert to MNE-Matlab structure
    projs = struct();
    for iProj = 1:length(info{'projs'})
        projs(iProj).kind   = bst_py2mat(info{'projs'}{iProj}{'kind'});
        projs(iProj).active = bst_py2mat(info{'projs'}{iProj}{'active'});
        projs(iProj).desc   = bst_py2mat(info{'projs'}{iProj}{'desc'});
        projs(iProj).data.nrow = bst_py2mat(info{'projs'}{iProj}{'data'}{'nrow'});
        projs(iProj).data.ncol = bst_py2mat(info{'projs'}{iProj}{'data'}{'ncol'});
        projs(iProj).data.data = bst_py2mat(info{'projs'}{iProj}{'data'}{'data'});
        if ~isa(info{'projs'}{iProj}{'data'}{'row_names'}, 'py.NoneType')
            projs(iProj).data.row_names = cellfun(@char, cell(info{'projs'}{iProj}{'data'}{'row_names'}), 'UniformOutput', 0);
        else
            projs(iProj).data.row_names = {};
        end
        if ~isa(info{'projs'}{iProj}{'data'}{'col_names'}, 'py.NoneType')
            projs(iProj).data.col_names = cellfun(@char, cell(info{'projs'}{iProj}{'data'}{'col_names'}), 'UniformOutput', 0);
        else
            projs(iProj).data.col_names = {};
        end
    end
    % Import with function
    ChannelMat.Projector = in_projector_fif(projs, {ChannelMat.Channel.Name});
    % Disable projectors by default
    if ~isempty(ChannelMat.Projector)
        iProjNotApplied = find([ChannelMat.Projector.Status] == 1);
        if ~isempty(iProjNotApplied)
            [ChannelMat.Projector(iProjNotApplied).Status] = deal(0);
        end
    end
end


%% ===== OTHER DIGITALIZED POINTS =====
if (length(info{'dig'}) > 0) && ~isa(info{'dig'}, 'py.NoneType')
    nbhs = length(info{'dig'});
    dk = cell(1, nbhs);
    di = cell(1, nbhs);
    r = zeros(3, nbhs);
    for i = 1:nbhs
        dig = info{'dig'}{i};
        switch double(dig{'kind'}.real)
            case FIFF.FIFFV_POINT_CARDINAL
                dk{i} = 'CARDINAL';
                switch bst_py2mat(dig{'ident'})
                    case FIFF.FIFFV_POINT_LPA
                        di{i} = 'LPA';
                    case FIFF.FIFFV_POINT_NASION
                        di{i} = 'NAS';
                    case FIFF.FIFFV_POINT_RPA
                        di{i} = 'RPA';
                end
            case FIFF.FIFFV_POINT_HPI
                dk{i} = 'HPI';
                di{i} = bst_py2mat(dig{'ident'});
            case FIFF.FIFFV_POINT_EEG
                dk{i} = 'EEG';
                di{i} = bst_py2mat(dig{'ident'});
            case FIFF.FIFFV_POINT_EXTRA
                dk{i} = 'EXTRA';
                di{i} = bst_py2mat(dig{'ident'});
        end
        r(:,i) = bst_py2mat(dig{'r'})';
    end
    % Store them in the returned structure
    ChannelMat.HeadPoints.Loc   = r;
    ChannelMat.HeadPoints.Type  = dk;
    ChannelMat.HeadPoints.Label = di;
    % Apply same coodinates transforms than for EEG channels
    for i = 1:length(eeg_trans)
        T = eeg_trans(i).trans(1:3,:);
        % Apply transform
        nbPoints = size(ChannelMat.HeadPoints.Loc, 2);
        ChannelMat.HeadPoints.Loc = T * [ChannelMat.HeadPoints.Loc; ones(1,nbPoints)];
    end
end



