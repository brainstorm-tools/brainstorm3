function [Output, ChannelFile, FileFormat] = import_channel(iStudies, ChannelFile, FileFormat, ChannelReplace, ChannelAlign, isSave, isFixUnits, isApplyVox2ras)
% IMPORT_CHANNEL: Imports a channel file (definition of the sensors).
% 
% USAGE:  BstChannelFile = import_channel(iStudies=none, ChannelFile=[ask], FileFormat, ChannelReplace=1, ChannelAlign=[ask], isSave=1, isFixUnits=[ask], isApplyVox2ras=[ask])
%
% INPUT:
%    - iStudies       : Indices of the studies where to import the ChannelFile
%    - ChannelFile    : Full filename of the channels list to import (default: asked to the user)
%    - FileFormat     : Format of the input file ChannelFile
%    - ChannelReplace : 0, do not replace if channel file already exist
%                       1, replace old channel file after user confirmation  (default)
%                       2, replace old channel file without user confirmation
%    - ChannelAlign   : 0, do not perform automatic headpoints-based alignment
%                       1, perform automatic alignment after user confirmation  (default)
%                       2, perform automatic alignment without user confirmation
%    - isSave         : If 1, save the new channel file in the target study
%    - isFixUnits     : If 1, tries to convert the distance units to meters automatically
%                       If 0, does not fix the distance units
%                       If [], ask for the scaling to apply
%    - isApplyVox2ras : If 1, uses the existing voxel=>subject transformation from the MRI file, if available
%                       If 0, does not use the voxel=>subject transformation
%                       If [], ask for user decision

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
% Authors: Francois Tadel, 2008-2019

%% ===== PARSE INPUTS =====
Output = [];
if (nargin < 8) || isempty(isApplyVox2ras)
    isApplyVox2ras = [];
end
if (nargin < 7) || isempty(isFixUnits)
    isFixUnits = [];
end
if (nargin < 6) || isempty(isSave)
    isSave = 1;
end
if (nargin < 5) || isempty(ChannelAlign)
    ChannelAlign = [];
end
if (nargin < 4) || isempty(ChannelReplace)
    ChannelReplace = 1;
end
if (nargin < 3) || isempty(ChannelFile) || isempty(FileFormat)
    ChannelFile = [];
end
if (nargin < 1) || isempty(iStudies)
    iStudies = [];
end

%% ===== SELECT CHANNEL FILE =====
% If file to load was not defined : open a dialog box to select it
if isempty(ChannelFile)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get MRI file
    [ChannelFile, FileFormat] = java_getfile('open', ...
            'Import channel file...', ...              % Window title
            LastUsedDirs.ImportChannel, ...        % Last used directory
            'single', 'files_and_dirs', ...        % Selection mode
            bst_get('FileFilters', 'channel'), ... % File filters
            DefaultFormats.ChannelIn);             % Default ASCII XYZ
    % If no file was selected: exit
    if isempty(ChannelFile)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportChannel = bst_fileparts(ChannelFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.ChannelIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end


%% ===== LOAD CHANNEL FILE =====
ChannelMat = [];
FileUnits = 1;
% Progress bar
isProgressBar = bst_progress('isVisible');
if ~isProgressBar
    bst_progress('start', 'Import channel file', ['Loading file "' ChannelFile '"...']);
end
% Get the file extenstion
[fPath, fBase, fExt] = bst_fileparts(ChannelFile);
if ~isempty(fExt)
    fExt = lower(fExt(2:end));
end
% Import options
ImportOptions = db_template('ImportOptions');
ImportOptions.EventsMode = 'ignore';
ImportOptions.DisplayMessages = 0;
% Load file
switch (FileFormat)
    % ===== MEG/EEG =====
    case 'CTF'
        ChannelMat = in_channel_ctf(ChannelFile);
        FileUnits = 'm';
    case {'FIF', '4D', 'KIT', 'BST-BIN', 'KDF', 'RICOH', 'ITAB', 'MEGSCAN-HDF5'}
        [sFile, ChannelMat] = in_fopen(ChannelFile, FileFormat, ImportOptions);
        if isempty(ChannelMat)
            return;
        end
        FileUnits = 'm';
    case 'BST'
        ChannelMat = in_bst_channel(ChannelFile);
        FileUnits = 'm';
        
    % ===== EEG ONLY =====
    case {'BIDS-ORIG-MM', 'BIDS-MNI-MM'}
        ChannelMat = in_channel_bids(ChannelFile, 0.001);
        FileUnits = 'm';
    case {'BIDS-ORIG-CM', 'BIDS-MNI-CM'}
        ChannelMat = in_channel_bids(ChannelFile, 0.01);
        FileUnits = 'm';
    case {'BIDS-ORIG-M', 'BIDS-MNI-M'}
        ChannelMat = in_channel_bids(ChannelFile, 1);
        FileUnits = 'm';
        
    case 'BESA' % (*.sfp;*.elp;*.eps/*.ela)
        switch (fExt)
            case 'sfp'
                ChannelMat = in_channel_ascii(ChannelFile, {'Name','-Y','X','Z'}, 0, .01);
                ChannelMat.Comment = 'BESA channels';
            case 'elp'
                ChannelMat = in_channel_ascii(ChannelFile, {'Name','Y','X','Z'}, 0, .01);
                ChannelMat.Comment = 'BESA channels';
            case {'eps','ela'}
                ChannelMat = in_channel_besa_eps(ChannelFile);
        end
        FileUnits = 'cm';
        
    case 'BRAINVISION'
        ChannelMat = in_channel_brainvision(ChannelFile);
        FileUnits = 'm';
        
    case 'CARTOOL' % (*.els;*.xyz)
        switch (fExt)
            case 'els'
                ChannelMat = in_channel_cartool_els(ChannelFile);
                FileUnits = 'mm';
            case 'xyz'
                ChannelMat = in_channel_ascii(ChannelFile, {'-Y','X','Z','Name'}, 1, .001);
                ChannelMat.Comment = 'Cartool channels';
                FileUnits = 'cm';
        end

    case 'MEGDRAW'
        ChannelMat = in_channel_megdraw(ChannelFile);
        FileUnits = 'cm';
        
    case 'CURRY' % (*.res;*.rs3;*.pom)
        switch (fExt)
            case 'res'
                ChannelMat = in_channel_ascii(ChannelFile, {'%d','-Y','X','Z','%d','Name'}, 0, .001);
                ChannelMat.Comment = 'Curry channels';
            case 'rs3'
                ChannelMat = in_channel_curry_rs3(ChannelFile);
            case 'pom'
                ChannelMat = in_channel_curry_pom(ChannelFile);
        end
        FileUnits = 'mm';
        
    case 'XENSOR' % ANT Xensor (*.elc)
        ChannelMat = in_channel_ant_xensor(ChannelFile);
        FileUnits = 'mm';

    case 'EEGLAB' % (*.ced;*.xyz)
        switch (fExt)
            case 'ced'
                ChannelMat = in_channel_ascii(ChannelFile, {'indice','Name','%f','%f','X','Y','Z','%f','%f','%f'}, 1, .0875); % Convert normalized coord => average head radius
                ChannelMat.Comment = 'EEGLAB channels';
            case 'xyz'
                ChannelMat = in_channel_ascii(ChannelFile, {'indice','-Y','X','Z','Name'}, 0, .01);
                ChannelMat.Comment = 'EEGLAB channels';
            case 'set'
                ChannelMat = in_channel_eeglab_set(ChannelFile, isFixUnits);
        end
        FileUnits = 'cm';
        
    case 'EETRAK' % (*.elc)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y','Z'}, 3, .001);
        ChannelMat.Comment = 'EETRAK channels';
        FileUnits = 'mm';
        
    case 'EGI'  % (*.sfp)
        ChannelMat = in_channel_ascii(ChannelFile, {'Name','-Y','X','Z'}, 0, .01);
        ChannelMat.Comment = 'EGI channels';
        FileUnits = 'cm';
    
    case 'MFF'  % (coordinates.xml)
        [tmp, ChannelMat] = in_fopen_mff(ChannelFile, ImportOptions, 1);
        FileUnits = 'mm';
        
    case 'EMSE'  % (*.elp)
        ChannelMat = in_channel_emse_elp(ChannelFile);
        FileUnits = 'm';
        
    case 'NEUROSCAN'  % (*.dat;*.tri;*.txt;*.asc)
        switch (fExt)
            case {'dat', 'txt'}
                ChannelMat = in_channel_neuroscan_dat(ChannelFile);
                FileUnits = 'cm';
            case 'tri'
                ChannelMat = in_channel_neuroscan_tri(ChannelFile);
                FileUnits = 'cm';
            case 'asc'
                ChannelMat = in_channel_neuroscan_asc(ChannelFile);
                FileUnits = 'mm';
        end
        
    case 'POLHEMUS'  % (*.pos;*.elp)
        switch (fExt)
            case 'pos'
                ChannelMat = in_channel_pos(ChannelFile);
                FileUnits = 'cm';
            case {'pol','txt'}
                ChannelMat = in_channel_ascii(ChannelFile, {'name','X','Y','Z'}, 1, .01);
                ChannelMat.Comment = 'Polhemus';
                FileUnits = 'cm';
            case 'elp'
                ChannelMat = in_channel_emse_elp(ChannelFile);
                FileUnits = 'mm';
        end
        
    case {'INTRANAT', 'INTRANAT_MNI'}
        switch (fExt)
            case 'pts'
                ChannelMat = in_channel_ascii(ChannelFile, {'name','X','Y','Z'}, 3, .001);
            case 'csv'
                if strcmpi(FileFormat, 'INTRANAT_MNI')
                    ChannelMat = in_channel_tsv(ChannelFile, 'contact', 'MNI', .001);
                else
                    ChannelMat = in_channel_tsv(ChannelFile, 'contact', 'T1pre Scanner Based', .001);
                end
        end
        ChannelMat.Comment = 'Contacts';
        FileUnits = 'mm';
        [ChannelMat.Channel.Type] = deal('SEEG');
    case {'ASCII_XYZ', 'ASCII_XYZ_MNI', 'ASCII_XYZ_WORLD'}  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y','Z'}, 0, .01);
        ChannelMat.Comment = 'Channels';
        FileUnits = 'cm';
    case {'ASCII_NXYZ', 'ASCII_NXYZ_MNI', 'ASCII_NXYZ_WORLD'}  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'Name','X','Y','Z'}, 0, .01);
        ChannelMat.Comment = 'Channels';
        FileUnits = 'cm';
    case {'ASCII_XYZN', 'ASCII_XYZN_MNI', 'ASCII_XYZN_WORLD'}  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y','Z','Name'}, 0, .01);
        ChannelMat.Comment = 'Channels';
        FileUnits = 'cm';
    case 'ASCII_NXY'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'Name','X','Y'}, 0, .000875);
        ChannelMat.Comment = 'Channels';
        FileUnits = 'mm';
    case 'ASCII_XY'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y'}, 0, .000875);
        ChannelMat.Comment = 'Channels';
        FileUnits = '';
    case 'ASCII_NTP'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'Name','TH','PHI'}, 0, .0875);
        ChannelMat.Comment = 'Channels';
        FileUnits = '';
    case 'ASCII_TP'  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'TH','PHI'}, 0, .0875);
        ChannelMat.Comment = 'Channels';
        FileUnits = '';
end
% No data imported
isHeadPoints = isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints.Loc);
if isempty(ChannelMat) || ((~isfield(ChannelMat, 'Channel') || isempty(ChannelMat.Channel)) && ~isHeadPoints)
    disp('BST> Warning: No channel information was read from the file.');
    bst_progress('stop');
    return
end
% Are the SCS coordinates defined for this file?
isScsDefined = isfield(ChannelMat, 'SCS') && all(isfield(ChannelMat.SCS, {'NAS','LPA','RPA'})) && (length(ChannelMat.SCS.NAS) == 3) && (length(ChannelMat.SCS.LPA) == 3) && (length(ChannelMat.SCS.RPA) == 3);
if ismember(FileFormat, {'ASCII_XYZ_WORLD', 'ASCII_NXYZ_WORLD', 'ASCII_XYZN_WORLD'})
    isApplyVox2ras = 1;
end



%% ===== CHECK DISTANCE UNITS =====
if ~isempty(FileUnits) && ~isequal(isFixUnits, 0)
    if isempty(isFixUnits)
        isConfirmFix = 1;
    else
        isConfirmFix = 0;
    end
    ChannelMat = channel_fixunits(ChannelMat, FileUnits, isConfirmFix);
end


%% ===== MNI TRANSFORMATION =====
if ismember(FileFormat, {'ASCII_XYZ_MNI', 'ASCII_NXYZ_MNI', 'ASCII_XYZN_MNI', 'INTRANAT_MNI', 'BIDS-MNI-MM', 'BIDS-MNI-CM', 'BIDS-MNI-M'})
    % Warning for multiple studies
    if (length(iStudies) > 1)
        warning(['WARNING: When importing MNI positions for multiple subjects: the MNI transformation from the first subject is used for all of them.' 10 ...
                 'Please consider importing your subjects seprately.']);
    end
    % If we know the destination study: convert from MNI to SCS coordinates
    if ~isempty(iStudies)
        % Get the subject for the first study
        sStudy = bst_get('Study', iStudies(1));
        sSubject = bst_get('Subject', sStudy.BrainStormSubject);
        % Get the subject's MRI
        if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
            error('You need the subject anatomy in order to load sensor positions in MNI coordinates.');
        end
        % Load the MRI
        MriFile = file_fullpath(sSubject.Anatomy(1).FileName);
        sMri = load(MriFile, 'SCS', 'NCS');
        if ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri, 'NCS') || ~isfield(sMri.NCS, 'R') || isempty(sMri.NCS.R)
            error(['The SCS and MNI transformations must be defined for this subject' 10 'in order to load sensor positions in MNI coordinates.']);
        end
        % Compute the transformation MNI => SCS
        RTmni2mri = inv([sMri.NCS.R, sMri.NCS.T./1000; 0 0 0 1]);
        RTmri2scs = [sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1];
        RTmni2scs = RTmri2scs * RTmni2mri;
        % Convert all the coordinates
        AllChannelMats = channel_apply_transf(ChannelMat, RTmni2scs, [], 1);
        ChannelMat = AllChannelMats{1};
    end
    % Do not convert the positions to SCS
    isAlignScs = 0;
    
%% ===== MRI/NII TRANSFORMATION =====
% If the SCS coordinates are not defined (NAS/LPA/RPA fiducials), try to use the MRI=>subject transformation available in the MRI (eg. NIfTI sform/qform)
% Only available if there is one study in output
elseif ~isScsDefined && ~isequal(isApplyVox2ras, 0)
    % Get the folders
    sStudies = bst_get('Study', iStudies);
    if (length(sStudies) > 1) && ~all(strcmpi(sStudies(1).BrainStormSubject, {sStudies.BrainStormSubject}))
        warning(['WARNING: When importing sensor positions for multiple subjects: the SCS transformation from the first subject is used for all of them.' 10 ...
                 'Please consider importing your subjects seprately.']);
    end
    % Get subject for first file only
    sSubject = bst_get('Subject', sStudies(1).BrainStormSubject);

    % If there is a MRI for this subject
    if ~isempty(sSubject.Anatomy) && ~isempty(sSubject.Anatomy(1).FileName)
        % Load the MRI
        MriFile = file_fullpath(sSubject.Anatomy(1).FileName);
        sMri = load(MriFile, 'InitTransf', 'SCS', 'Voxsize');
        % If there is a valid transformation
        if isfield(sMri, 'InitTransf') && ~isempty(sMri.InitTransf) && ismember('vox2ras', sMri.InitTransf(:,1))
            % Ask user if necessary
            if isempty(isApplyVox2ras)
                isApplyVox2ras = java_dialog('confirm', ['There is a transformation to subject coordinates available in the MRI.' 10 'Would you like to use it to align the sensors with the MRI?'], 'Apply MRI transformation');
            end
            % Apply transformation
            if isApplyVox2ras
                % Get the transformation WORLD=>MRI (in meters)
                Transf = cs_convert(sMri, 'world', 'mri');
                % Add the transformation MRI=>SCS
                if isfield(sMri,'SCS') && isfield(sMri.SCS,'R') && ~isempty(sMri.SCS.R) && isfield(sMri.SCS,'T') && ~isempty(sMri.SCS.T)
                    Transf = [sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1] * Transf;
                else
                    error(['The SCS coordinates are not defined for this subject, the sensors will not be aligned on the anatomy. ' 10 'Consider defining the NAS/LPA/RPA fiducials before importing the sensors positions.']);
                end
                % Convert all the coordinates
                AllChannelMats = channel_apply_transf(ChannelMat, Transf, [], 1);
                ChannelMat = AllChannelMats{1};
            end
        end
    end
    isAlignScs = 1;
elseif isfield(ChannelMat, 'TransfMegLabels') && iscell(ChannelMat.TransfMegLabels) && ismember('Native=>Brainstorm/CTF', ChannelMat.TransfMegLabels)
    % No need to duplicate this transformation if it was previously
    % computed, e.g. in in_channel_ctf. (It would be identity the second
    % time.)
    isAlignScs = 0;
else
    isAlignScs = 1;
end


%% ===== DETECT CHANNEL TYPES =====
% Remove fiducials only from polhemus and ascii files
%isRemoveFid = ismember(FileFormat, {'MEGDRAW', 'POLHEMUS', 'ASCII_XYZ', 'ASCII_NXYZ', 'ASCII_XYZN', 'ASCII_NXY', 'ASCII_XY', 'ASCII_NTP', 'ASCII_TP'});
isRemoveFid = 1;
% Detect auxiliary EEG channels + align channel
ChannelMat = channel_detect_type(ChannelMat, isAlignScs, isRemoveFid);


%% ===== APPLY NEW CHANNEL FILE =====
% If some studies were defined
if isSave && ~isempty(iStudies)
    if isempty(ChannelAlign)
        iMEG = good_channel(ChannelMat.Channel, [], 'MEG');
        ChannelAlign = ~isempty(iMEG);
    end
    % History: Import channel file
    ChannelMat = bst_history('add', ChannelMat, 'import', ['Import from: ' ChannelFile ' (Format: ' FileFormat ')']);
    % Add channel file to all the target studies
    for i = 1:length(iStudies)
        ChannelFile = db_set_channel(iStudies(i), ChannelMat, ChannelReplace, ChannelAlign);
    end
    % Returned value
    Output = ChannelFile;
else
    Output = ChannelMat;
end

% Progress bar
if ~isProgressBar
    bst_progress('stop');
end


