function mneInfo = out_mne_channel(ChannelFile, iChannels)
% OUT_MNE_CHANNEL: Converts a channel file into a MNE-Python Info object
% 
% USAGE:  mneInfo = out_mne_channel(ChannelFile, iChannels=[all])
%         mneInfo = out_mne_channel(ChannelMat,  iChannels=[all])
%
% REFERENCE:
%     https://www.nmr.mgh.harvard.edu/mne/stable/generated/mne.Info.html

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
% Authors: Francois Tadel, 2021-2022


%% ===== PARSE INPUT =====
if (nargin < 2) || isempty(iChannels)
    iChannels = [];
end
if isstruct(ChannelFile)
    ChannelMat  = ChannelFile;
    ChannelFile = [];
else
    ChannelMat = [];
end

% ===== MNE CONSTANTS =====
% Get MNE constants
FIFF = py.mne.io.constants.FIFF;
CTF = py.mne.io.ctf.constants.CTF;
% Load coils definition file
coil_def_file = which('coil_def.dat');
if ~isempty(coil_def_file)
    templates = mne_load_coil_def(coil_def_file);
else
    templates = [];
end


%% ===== LOAD CHANNEL FILE =====
% Load channel file
if ~isempty(ChannelFile) && isempty(ChannelMat)
    ChannelMat = in_bst_channel(ChannelFile);
end
% Make sure that the channel file is defined
if isempty(ChannelMat)
    error('No channel file available.');
end
% Channel selection: all by default
if isempty(iChannels)
    iChannels = 1:length(ChannelMat.Channel);
end
% If coils positions not available in channel file: convert from MRI
if ~isempty(ChannelFile) && (isempty(ChannelMat.SCS) || isempty(ChannelMat.SCS.NAS) || isempty(ChannelMat.SCS.LPA) || isempty(ChannelMat.SCS.RPA))
    % Get subject
    sStudy = bst_get('ChannelFile', ChannelFile);
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % Get coordinates from MRI
    if ~isempty(sSubject.iAnatomy)
        % Load MRI
        sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
        % Get positions
        ChannelMat.SCS.NAS = cs_convert(sMri, 'mri', 'scs', sMri.SCS.NAS ./ 1000);
        ChannelMat.SCS.LPA = cs_convert(sMri, 'mri', 'scs', sMri.SCS.LPA ./ 1000);
        ChannelMat.SCS.RPA = cs_convert(sMri, 'mri', 'scs', sMri.SCS.RPA ./ 1000);
    end
end

% ===== LIST OF CHANNELS =====
% Get channel names
ch_names = {ChannelMat.Channel(iChannels).Name};
% Convert channel types
ch_types = cell(1, length(iChannels));
ch_frame = cell(1, length(iChannels));
for iChan = 1:length(iChannels)
    switch upper(ChannelMat.Channel(iChannels(iChan)).Type)
        case {'MEG', 'MEG MAG'}
            ch_types{iChan} = 'mag';
            ch_frame{iChan} = FIFF.FIFFV_COORD_DEVICE;
        case {'MEG GRAD'}
            ch_types{iChan} = 'grad';
            ch_frame{iChan} = FIFF.FIFFV_COORD_DEVICE;
        case 'MEG REF'
            ch_types{iChan} = 'ref_meg';
            ch_frame{iChan} = FIFF.FIFFV_COORD_DEVICE;
        case {'ECG', 'BIO', 'STIM', 'EOG', 'MISC', 'SEEG', 'ECOG', 'MAG', 'EEG', 'GRAD', 'EMG', 'HBR', 'HBO'} % Types supported by MNE-Python
            ch_types{iChan} = lower(ChannelMat.Channel(iChannels(iChan)).Type);
            ch_frame{iChan} = FIFF.FIFFV_COORD_HEAD;
        otherwise
            ch_types{iChan} = 'misc';
            ch_frame{iChan} = FIFF.FIFFV_COORD_UNKNOWN;
    end
end
% Create info object
mneInfo = py.mne.create_info(ch_names, 1000, ch_types);
% Unlocking Info object
mneSetStatus = py.getattr(mneInfo, '__setstate__');
mneSetStatus(py.dict(pyargs('_unlocked', true)));
% % Add Brainstorm version
% bstver = bst_get('Version');
% mneInfo{'hpi_meas'} = py.list(py.dict(pyargs('creator', ['Brainstorm ', bstver.Version, ' (', bstver.Date ')'])));

% ===== TRANSFORMATIONS =====
% Get existing transformation
tNeuromagHead2Bst = [];
tDev2NeuromagHead = [];
% tBst2CtfHead = [];
tCtfHead2Dev = [];
if ~isempty(ChannelMat.TransfMeg) && ~isempty(ChannelMat.TransfMegLabels)
    % NEUROMAG=>BST
    iNeuromagHead2Bst = find(strcmpi(ChannelMat.TransfMegLabels, 'neuromag_head=>scs'));
    if ~isempty(iNeuromagHead2Bst)
        tNeuromagHead2Bst = ChannelMat.TransfMeg{iNeuromagHead2Bst};
    end
    % DEVICE=>NEUROMAG HEAD ('dev_head_t')
    iDev2NeuromagHead = find(strcmpi(ChannelMat.TransfMegLabels, 'neuromag_device=>neuromag_head'));
    if ~isempty(iDev2NeuromagHead)
        tDev2NeuromagHead = ChannelMat.TransfMeg{iDev2NeuromagHead};
        % Warning: We should NOT export 'dev_head_t', if it was not present initially in the dataset
        %          In the FIF-reading function (in_channel_fif, in_channel_name, in_fopenmegscan), when the device=>head transformation 
        %          transformation is missing (e.g. noise recordings), Brainstorm adds a default +4cm translation for display purproses.
        %          This should not be exported, because it messes up the behavior of specific MNE functions (e.g. maxwell_filter)
        isDefaultDev2head = isequal(tDev2NeuromagHead, ...
            [1   0   0   0; ...
             0   1   0   0; ...
             0   0   1 .04; ...
             0   0   0   1]);
    end
%     % CTF=>BST
%     iCtfHead2Bst = find(strcmpi(ChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF'));
%     if ~isempty(iCtfHead2Bst)
%         tBst2CtfHead = inv(ChannelMat.TransfMeg{iCtfHead2Bst});
%     end
    % DEVICE=>CTF HEAD
    iDev2CtfHead = find(strcmpi(ChannelMat.TransfMegLabels, 'Dewar=>Native'));
    if ~isempty(iDev2CtfHead)
        tCtfHead2Dev = inv(ChannelMat.TransfMeg{iDev2CtfHead});
    else
        tCtfHead2Dev = [...
            0.7071   -0.7071         0   -0.0000
            0.7071    0.7071         0   -0.0000
                 0         0         1   -0.1900
                 0         0         0    1.0000];
    end
end

% ===== NEUROMAG COORDINATES AVAILABLE =====
if ~isempty(tNeuromagHead2Bst) && ~isempty(tDev2NeuromagHead)
    % BST => NEUROMAG HEAD (all data)
    ChannelMat = ApplyTransformation(ChannelMat, inv(tNeuromagHead2Bst), [], 1);
    % NEUROMAG HEAD => NEUROMAG DEVICE (MEG ONLY)
    ChannelMat = ApplyTransformation(ChannelMat, inv(tDev2NeuromagHead), {'MEG', 'MEG REF', 'MEG GRAD', 'MEG MAG'}, 0);
    % If there is a Neuromag head transformation available: add it to the file
    if ~isDefaultDev2head
        mneInfo{'dev_head_t'}{'trans'}.put(int16(0:15), bst_mat2py(tDev2NeuromagHead));
    % Otherwise: Brainstorm added a transformation that did not exist initially 
    % => do not add it to the python object + remove the default identity transformation in mneInfo
    else
        mneInfo{'dev_head_t'} = py.None;
    end
    
% ===== USE CTF/BRAINSTORM COORDINATES =====
else
    disp('MNE> Fix CTF/Brainstorm=>Neuromag transformations');
%     % Invert CTF refined transformation
%     if ~isempty(tBst2CtfHead)
%         ChannelMat = ApplyTransformation(ChannelMat, tBst2CtfHead, [], 1);
%     end
    
    % === Compute transformations from CTF to Neuromag ===
    if ~isempty(ChannelMat.SCS.NAS) && ~isempty(ChannelMat.SCS.LPA) && ~isempty(ChannelMat.SCS.RPA)
        % Create list of coils
        coils = py.list();
        % NAS (head coordinates)
        coils.append(py.dict(struct(...
            'coord_frame', FIFF.FIFFV_MNE_COORD_CTF_HEAD, ...
            'kind',        CTF.CTFV_COIL_NAS, ...
            'valid',       py.True, ...
            'r',           py.numpy.array(ChannelMat.SCS.NAS))));
        % LPA (head coordinates)
        coils.append(py.dict(struct(...
            'coord_frame', FIFF.FIFFV_MNE_COORD_CTF_HEAD, ...
            'kind',        CTF.CTFV_COIL_LPA, ...
            'valid',       py.True, ...
            'r',           py.numpy.array(ChannelMat.SCS.LPA))));
        % RPA (head coordinates)
        coils.append(py.dict(struct(...
            'coord_frame', FIFF.FIFFV_MNE_COORD_CTF_HEAD, ...
            'kind',        CTF.CTFV_COIL_RPA, ...
            'valid',       py.True, ...
            'r',           py.numpy.array(ChannelMat.SCS.RPA))));
        % NAS (device coordinates)
        coils.append(py.dict(struct(...
            'coord_frame', FIFF.FIFFV_MNE_COORD_CTF_DEVICE, ...
            'kind',        CTF.CTFV_COIL_NAS, ...
            'valid',       py.True, ...
            'r',           py.numpy.array(Tmult(ChannelMat.SCS.NAS', tCtfHead2Dev)'))));
        % LPA (device coordinates)
        coils.append(py.dict(struct(...
            'coord_frame', FIFF.FIFFV_MNE_COORD_CTF_DEVICE, ...
            'kind',        CTF.CTFV_COIL_LPA, ...
            'valid',       py.True, ...
            'r',           py.numpy.array(Tmult(ChannelMat.SCS.LPA', tCtfHead2Dev)'))));
        % RPA (device coordinates)
        coils.append(py.dict(struct(...
            'coord_frame', FIFF.FIFFV_MNE_COORD_CTF_DEVICE, ...
            'kind',        CTF.CTFV_COIL_RPA, ...
            'valid',       py.True, ...
            'r',           py.numpy.array(Tmult(ChannelMat.SCS.RPA', tCtfHead2Dev)'))));
        % Compute transformations
        workspace = py.dict(struct('coils', coils));
        py.exec('import mne', workspace);
        py.exec('coord_trans = mne.io.ctf.trans._make_ctf_coord_trans_set(None,coils)', workspace);
        % Save transformations
        coord_trans = workspace{'coord_trans'};
        mneInfo{'ctf_head_t'} = coord_trans{'t_ctf_head_head'};
        mneInfo{'dev_head_t'} = coord_trans{'t_dev_head'};
        mneInfo{'dev_ctf_t'} = py.mne.transforms.combine_transforms(...
                coord_trans{'t_dev_head'}, ...
                py.mne.transforms.invert_transform(coord_trans{'t_ctf_head_head'}), ...
                FIFF.FIFFV_COORD_DEVICE, FIFF.FIFFV_MNE_COORD_CTF_HEAD);
        % CTF HEAD => NEUROMAG HEAD (all data)
        ChannelMat = ApplyTransformation(ChannelMat, bst_py2mat(mneInfo{'ctf_head_t'}{'trans'}), [], 1);
        % NEUROMAG HEAD => NEUROMAG DEVICE (MEG ONLY)
        ChannelMat = ApplyTransformation(ChannelMat, inv(bst_py2mat(mneInfo{'dev_head_t'}{'trans'})), {'MEG', 'MEG REF', 'MEG GRAD', 'MEG MAG'}, 0);
    end
end


% ===== POSITIONS =====
% Get channels positions
chPos = figure_3d('GetChannelPositions', ChannelMat, iChannels);
% Add positions
for iChan = 1:length(iChannels)
    % Initialize 12 values: 3 loc + 3x3 transformation matrix to give the orientation
    loc = nan(1,12);
    % Location / Orientation
    if ~isequal(chPos(iChan,:), [0 0 0])
        % MEG or EEG sensor location
        loc(1:3) = chPos(iChan,:);
        % Orientation
        if ismember(ChannelMat.Channel(iChannels(iChan)).Type, {'MEG', 'MEG REF', 'MEG GRAD', 'MEG MAG'}) && (size(ChannelMat.Channel(iChannels(iChan)).Loc, 2) >= 4)
            L = ChannelMat.Channel(iChannels(iChan)).Loc';
            loc(4:6) = (L(1,:) - L(3,:)) ./ sqrt(sum((L(1,:) - L(3,:)).^2))';
            loc(7:9) = (L(1,:) - L(2,:)) ./ sqrt(sum((L(1,:) - L(2,:)).^2))';
            loc(10:12) = cross(loc(4:6),  loc(7:9));
        else
            loc(4:6) = [0,0,0];    % EEG reference position
        end
    end
    mneInfo{'chs'}{iChan}{'loc'}.put(int16(0:11), loc);
    
    % Coordinate frame
    mneInfo{'chs'}{iChan}{'coord_frame'} = ch_frame{iChan};
    % Try to get coil type from channel comment
    comment = ChannelMat.Channel(iChannels(iChan)).Comment;
    if ~isempty(comment) && ~isempty(templates)
        iEntry = find(strcmpi({templates.description}, comment));
        if ~isempty(iEntry)
            mneInfo{'chs'}{iChan}{'coil_type'} = py.numpy.int32(templates(iEntry(1)).id);
        end
    end
end


% ===== DIGITIZED HEAD POINTS =====
if ~isempty(ChannelMat.HeadPoints) && ~isempty(ChannelMat.HeadPoints.Type)
    % Initialize list of digitized points
    mneInfo{'dig'} = py.list();
    % Fill with DigPoints
    for iDig = 1:length(ChannelMat.HeadPoints.Type)
        P = struct();
        P.coord_frame = FIFF.FIFFV_COORD_HEAD;
        nHpi = 0;
        nEeg = 0;
        nExtra = 0;
        nHead = 0;
        % Kind
        switch upper(ChannelMat.HeadPoints.Type{iDig})
            case 'CARDINAL'
                P.kind = FIFF.FIFFV_POINT_CARDINAL;
            case 'HPI'
                P.kind = FIFF.FIFFV_POINT_HPI;
                nHpi = nHpi + 1;
                ident = nHpi;
            case 'EEG'
                P.kind = FIFF.FIFFV_POINT_EEG;
                nEeg = nEeg + 1;
                ident = nEeg;
            case 'EXTRA'
                P.kind = FIFF.FIFFV_POINT_EXTRA;
                nExtra = nExtra + 1;
                ident = nExtra;
            case 'HEAD'
                P.kind = FIFF.FIFFV_POINT_HEAD;
                nHead = nHead + 1;
                ident = nHead;
            otherwise
                P.kind = FIFF.FIFFV_POINT_EXTRA;
                ident = 0;
        end
        % Ident
        if strcmpi(ChannelMat.HeadPoints.Type{iDig}, 'CARDINAL')
            switch upper(ChannelMat.HeadPoints.Label{iDig})
                case 'LPA',             P.ident = FIFF.FIFFV_POINT_LPA;
                case {'NAS', 'NASION'}, P.ident = FIFF.FIFFV_POINT_NASION;
                case 'RPA',             P.ident = FIFF.FIFFV_POINT_RPA;
                case 'INION',           P.ident = FIFF.FIFFV_POINT_INION;
                otherwise,              P.ident = FIFF.FIFFV_POINT_EXTRA;
            end
        elseif isnumeric(ChannelMat.HeadPoints.Label{iDig})
            P.ident = py.int(int32(ChannelMat.HeadPoints.Label{iDig}));
        else
            P.ident = py.int(int32(ident));
        end
        % Position
        P.r = py.numpy.array(ChannelMat.HeadPoints.Loc(:,iDig)');
        % Append to list
        mneInfo{'dig'}.append(py.dict(P));
    end
end


% ===== PROJECTORS =====
if ~isempty(ChannelMat.Projector)
    % Initialize list of projectors
    mneInfo{'projs'} = py.list();
    % Loop on projectors
    for iProj = 1:length(ChannelMat.Projector)
        % If projector is not selected: skip completely
        if (ChannelMat.Projector(iProj).Status == 0)
            continue;
        end
        % Get selected components
        selComp = find(ChannelMat.Projector(iProj).CompMask);
        % Create one projector for each selected component
        for iComp = 1:length(selComp)
            % Find channels that are used in this projector
            iChannels = find(any(ChannelMat.Projector(iProj).Components,2));
            % Create data dictionnary
            projData = py.dict(pyargs(...
                'nrow', py.int(1), ...
                'ncol', py.int(length(iChannels)), ...
                'row_names', py.None, ...
                'col_names', py.list({ChannelMat.Channel(iChannels).Name}), ...
                'data',      py.numpy.array(ChannelMat.Projector(iProj).Components(iChannels,selComp(iComp))', pyargs('ndmin', py.int(2)))));
            % Create Projection object
            pyProj = py.mne.Projection(pyargs(...
                'data', projData, ...
                'kind', FIFF.FIFFV_PROJ_ITEM_FIELD, ...
                'desc', py.str(ChannelMat.Projector(iProj).Comment), ...
                'active', py.bool(ChannelMat.Projector(iProj).Status == 2)));
            % Add to list of projectors
            mneInfo{'projs'}.append(pyProj);
        end
    end
end


% ===== CTF COMPENSATORS =====
if ~isempty(ChannelMat.MegRefCoef)
    disp('TODO: Export CTF compensators');
%     comps : list of dict
%         CTF software gradient compensation data.
%         ctfkind : int
%             CTF compensation grade.
%         colcals : ndarray
%             Column calibrations.
%         mat : dict
%             A named matrix dictionary (with entries "data", "col_names", etc.)
%             containing the compensation matrix.
%         rowcals : ndarray
%             Row calibrations.
%         save_calibrated : bool
%             Were the compensation data saved in calibrated form.
end

% Locking Info object again
mneSetStatus(py.dict(pyargs('_unlocked', false)));


end



%% ===== APPLY TRANSFORMATION =====
function ChannelMat = ApplyTransformation(ChannelMat, transf, SensorTypes, isHeadPoints)
    % Nothing to do
    if isempty(transf)
        return;
    end
    % Channel selection
    if ~isempty(SensorTypes)
        iChannels = channel_find(ChannelMat.Channel, SensorTypes);
    else
        iChannels = 1:length(ChannelMat.Channel);
    end
    % Update sensor positions/orientations
    if ~isempty(iChannels)
        for iChan = iChannels
            ChannelMat.Channel(iChan).Loc    = Tmult(ChannelMat.Channel(iChan).Loc, transf);
            ChannelMat.Channel(iChan).Orient = Tmult(ChannelMat.Channel(iChan).Orient, transf);
        end
    end
    % Update head points
    if isHeadPoints && ~isempty(ChannelMat.HeadPoints)
       ChannelMat.HeadPoints.Loc = Tmult(ChannelMat.HeadPoints.Loc, transf);
    end
%     % Update fiducials
%     if isFid
%         ChannelMat.SCS.NAS = Tmult(ChannelMat.SCS.NAS', transf)';
%         ChannelMat.SCS.LPA = Tmult(ChannelMat.SCS.LPA', transf)';
%         ChannelMat.SCS.RPA = Tmult(ChannelMat.SCS.RPA', transf)';
%     end
end

function P = Tmult(P, transf)
    if ~isempty(transf) && ~isempty(P) && ~all(P(:) == 0)
        tmp = [P', ones(size(P,2),1)] * transf';
        P = tmp(:,1:3)';
    end
end

