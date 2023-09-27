function [Output, ChannelFile, FileFormat] = import_channel(iStudies, ChannelFile, FileFormat, ChannelReplace, ChannelAlign, isSave, isFixUnits, isApplyVox2ras, RefMriFile)
% IMPORT_CHANNEL: Imports a channel file (definition of the sensors).
% 
% USAGE:  BstChannelFile = import_channel(iStudies=none, ChannelFile=[ask], FileFormat, ChannelReplace=1, ChannelAlign=[ask], isSave=1, isFixUnits=[ask], isApplyVox2ras=[ask], RefMriFile=[])
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
%    - isApplyVox2ras : If 0, does not use the voxel=>subject transformation
%                       If 1, uses the existing voxel=>subject transformation from the MRI file, if available
%                       If 2, uses the existing voxel=>subject transformation AND the coregistration transformation (see process_import_bids)
%                       If [], ask for user decision
%    - RefMriFile     : Relative file name to a MRI file imported for the current subject
%                       When isApplyVox2ras=1: use this file instead of the reference MRI for getting the vox2ras transformation
%                       When isApplyVox2ras=2: uses this file AND reverts the registration matrix that was possibly 
%                                              applied after the volume was imported (to matche the original .nii)

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
% Authors: Francois Tadel, 2008-2023

%% ===== PARSE INPUTS =====
Output = [];
if (nargin < 9) || isempty(RefMriFile)
    RefMriFile = [];
end
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
    isInteractive = 1;
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
else
    isInteractive = 0;
end


%% ===== LOAD CHANNEL FILE =====
ChannelMat = [];
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
            bst_progress('stop');
            return;
        end
        FileUnits = 'm';
    case 'BST'
        ChannelMat = in_bst_channel(ChannelFile);
        FileUnits = 'm';
        
    % ===== EEG ONLY =====
    case {'BIDS-SCANRAS-MM', 'BIDS-MNI-MM', 'BIDS-ACPC-MM', 'BIDS-ALS-MM', 'BIDS-CAPTRAK-MM'}
        ChannelMat = in_channel_bids(ChannelFile, 0.001);
        FileUnits = 'mm';
    case {'BIDS-SCANRAS-CM', 'BIDS-MNI-CM', 'BIDS-ACPC-CM', 'BIDS-ALS-CM', 'BIDS-CAPTRAK-CM'}
        ChannelMat = in_channel_bids(ChannelFile, 0.01);
        FileUnits = 'cm';
    case {'BIDS-SCANRAS-M', 'BIDS-MNI-M', 'BIDS-ACPC-M', 'BIDS-ALS-M', 'BIDS-CAPTRAK-M'}
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

    case 'EMSE'  % (*.elp)
        ChannelMat = in_channel_emse_elp(ChannelFile);
        FileUnits = 'm';

    case 'FREESURFER-TSV'
        % Read file
        ChannelMat = in_channel_bids(ChannelFile, 0.001);
        FileUnits = 'm';
        % If we know the destination study: convert from FreeSurfer/Surface coordinates to SCS coordinates
        if ~isempty(iStudies)
            % Get the subject for the first study
            sStudy = bst_get('Study', iStudies(1));
            sSubject = bst_get('Subject', sStudy.BrainStormSubject);
            % Get the subject's MRI
            if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
                error('You need to import the FreeSurfer anatomy before.');
            end
            % Load the MRI
            MriFile = file_fullpath(sSubject.Anatomy(1).FileName);
            sMri = in_mri_bst(MriFile);
            if isempty(sMri) || ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'NAS') || isempty(sMri.SCS.NAS)
                error('Missing fiducials.');
            end
            % Convert coordinates: FreeSurfer surface => MRI
            fcnTransf = @(Loc)bst_bsxfun(@plus, Loc', (size(sMri.Cube(:,:,:,1))/2 + [0 1 0]) .* sMri.Voxsize / 1000)';
            AllChannelMats = channel_apply_transf(ChannelMat, fcnTransf, [], 1);
            ChannelMat = AllChannelMats{1};
            % Convert coordinates: MRI => SCS
            fcnTransf = @(Loc)cs_convert(sMri, 'mri', 'scs', Loc')';
            AllChannelMats = channel_apply_transf(ChannelMat, fcnTransf, [], 1);
            ChannelMat = AllChannelMats{1};
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
        
    case 'MEGDRAW'
        ChannelMat = in_channel_megdraw(ChannelFile);
        FileUnits = 'cm';
        
    case 'LOCALITE'
        ChannelMat = in_channel_ascii(ChannelFile, {'%d','name','X','Y','Z'}, 1, .001);
        ChannelMat.Comment = 'Localite channels';
        FileUnits = 'mm';

    case 'MFF'  % (coordinates.xml)
        [tmp, ChannelMat] = in_fopen_mff(ChannelFile, ImportOptions, 1);
        FileUnits = 'mm';
        
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
        
    case 'SIMNIBS'
        ChannelMat = in_channel_ascii(ChannelFile, {'%s','X','Y','Z','name'}, 0, .001);
        ChannelMat.Comment = '10-10 electrodes';
        FileUnits = 'mm';
        
    case 'TVB'
        ChannelMat = in_channel_tvb(ChannelFile);
        FileUnits = 'm';       
        
    case 'XENSOR' % ANT Xensor (*.elc)
        ChannelMat = in_channel_ant_xensor(ChannelFile);
        FileUnits = 'mm';
        
    case {'ASCII_XYZ', 'ASCII_XYZ_MNI', 'ASCII_XYZ_WORLD'}  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y','Z'}, 0, .001);
        ChannelMat.Comment = 'Channels';
        FileUnits = 'mm';
    case {'ASCII_NXYZ', 'ASCII_NXYZ_MNI', 'ASCII_NXYZ_WORLD'}  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'Name','X','Y','Z'}, 0, .001);
        ChannelMat.Comment = 'Channels';
        FileUnits = 'mm';
    case {'ASCII_XYZN', 'ASCII_XYZN_MNI', 'ASCII_XYZN_WORLD'}  % (*.*)
        ChannelMat = in_channel_ascii(ChannelFile, {'X','Y','Z','Name'}, 0, .001);
        ChannelMat.Comment = 'Channels';
        FileUnits = 'mm';
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
    otherwise
        error(['File format is not supported: ' FileFormat]);
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
% Use world coordinates by defaults for some specific file formats
if isempty(isApplyVox2ras)
    if ismember(FileFormat, {'ASCII_XYZ_WORLD', 'ASCII_NXYZ_WORLD', 'ASCII_XYZN_WORLD', 'SIMNIBS'})
        isApplyVox2ras = 1;   % Use the current vox2ras matrix in the MRI file
    elseif ismember(FileFormat, {'ASCII_XYZ', 'ASCII_NXYZ', 'ASCII_XYZN', 'BIDS-ALS-MM', 'BIDS-ALS-CM', 'BIDS-ALS-M'})
        isApplyVox2ras = 0;   % Disable vox2ras for ASCII formats that are explicitly in SCS
    elseif ismember(FileFormat, {'BIDS-SCANRAS-MM', 'BIDS-SCANRAS-CM', 'BIDS-SCANRAS-M'})
        isApplyVox2ras = 2;   % Use the vox2ras matrix AND reverts the registration done in Brainstorm, to match the original file
    end
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
        sMri = in_mri_bst(MriFile);
        if ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri, 'NCS') || ((~isfield(sMri.NCS, 'R') || isempty(sMri.NCS.R)) && (~isfield(sMri.NCS, 'y') || isempty(sMri.NCS.y)))
            error(['The SCS and MNI transformations must be defined for this subject' 10 'in order to load sensor positions in MNI coordinates.']);
        end
        % Convert all the coordinates: MNI => SCS
        fcnTransf = @(Loc)cs_convert(sMri, 'mni', 'scs', Loc')';
        AllChannelMats = channel_apply_transf(ChannelMat, fcnTransf, [], 1);
        ChannelMat = AllChannelMats{1};
    end
    % Do not convert the positions to SCS
    isAlignScs = 0;
    
%% ===== ACPC TRANSFORMATION =====
elseif ismember(FileFormat, {'BIDS-ACPC-MM', 'BIDS-ACPC-CM', 'BIDS-ACPC-M'})
    % Warning for multiple studies
    if (length(iStudies) > 1)
        warning(['WARNING: When importing ACPC positions for multiple subjects: the ACPC transformation from the first subject is used for all of them.' 10 ...
                 'Please consider importing your subjects seprately.']);
    end
    % If we know the destination study: convert from ACPC to SCS coordinates
    if ~isempty(iStudies)
        % Get the subject for the first study
        sStudy = bst_get('Study', iStudies(1));
        sSubject = bst_get('Subject', sStudy.BrainStormSubject);
        % Get the subject's MRI
        if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
            error('You need the subject anatomy in order to load sensor positions in ACPC coordinates.');
        end
        % Load the MRI
        MriFile = file_fullpath(sSubject.Anatomy(1).FileName);
        sMri = in_mri_bst(MriFile);
        if ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri.NCS, 'AC') || isempty(sMri.NCS.AC) || ~isfield(sMri.NCS, 'PC') || isempty(sMri.NCS.PC) || ~isfield(sMri.NCS, 'IH') || isempty(sMri.NCS.IH)
            error(['All fiducials must be defined for this subject (NAS,LPA,RPA,AC,PC,IH)' 10 'in order to load sensor positions in ACPC coordinates.']);
        end
        % Convert all the coordinates: ACPC => SCS
        fcnTransf = @(Loc)cs_convert(sMri, 'acpc', 'scs', Loc')';
        AllChannelMats = channel_apply_transf(ChannelMat, fcnTransf, [], 1);
        ChannelMat = AllChannelMats{1};
    end
    % Do not convert the positions to SCS
    isAlignScs = 0;

%% ===== CAPTRAK TRANSFORMATION =====
elseif ismember(FileFormat, {'BIDS-CAPTRAK-MM', 'BIDS-CAPTRAK-CM', 'BIDS-CAPTRAK-M'})
    % Warning for multiple studies
    if (length(iStudies) > 1)
        warning(['WARNING: When importing CapTrak positions for multiple subjects: the CapTrak transformation from the first subject is used for all of them.' 10 ...
                 'Please consider importing your subjects seprately.']);
    end
    % If we know the destination study: convert from CapTrak to SCS coordinates
    if ~isempty(iStudies)
        % Get the subject for the first study
        sStudy = bst_get('Study', iStudies(1));
        sSubject = bst_get('Subject', sStudy.BrainStormSubject);
        % Get the subject's MRI
        if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
            error('You need the subject anatomy in order to load sensor positions in CapTrak coordinates.');
        end
        % Load the MRI
        MriFile = file_fullpath(sSubject.Anatomy(1).FileName);
        sMri = in_mri_bst(MriFile);
        if ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri.SCS, 'NAS') || isempty(sMri.SCS.NAS) || ~isfield(sMri.SCS, 'LPA') || isempty(sMri.SCS.LPA) || ~isfield(sMri.SCS, 'RPA') || isempty(sMri.SCS.RPA)
            error(['All fiducials must be defined for this subject (NAS,LPA,RPA)' 10 'in order to load sensor positions in CapTrak coordinates.']);
        end
        % Convert all the coordinates: CapTrak => SCS
        fcnTransf = @(Loc)cs_convert(sMri, 'captrak', 'scs', Loc')';
        AllChannelMats = channel_apply_transf(ChannelMat, fcnTransf, [], 1);
        ChannelMat = AllChannelMats{1};
    end
    % Do not convert the positions to SCS
    isAlignScs = 0;

%% ===== MRI/NII TRANSFORMATION =====
% If the SCS coordinates are not defined (NAS/LPA/RPA fiducials), try to use the MRI=>subject transformation available in the MRI (eg. NIfTI sform/qform)
% Only available if there is one study in output
elseif ~isScsDefined && ~isequal(isApplyVox2ras, 0) && ~isempty(iStudies)
    % Get the folders
    sStudies = bst_get('Study', iStudies);
    if (length(sStudies) > 1) && ~all(strcmpi(sStudies(1).BrainStormSubject, {sStudies.BrainStormSubject}))
        warning(['WARNING: When importing sensor positions for multiple subjects: the SCS transformation from the first subject is used for all of them.' 10 ...
                 'Please consider importing your subjects seprately.']);
    end
    % Get subject for first file only
    sSubject = bst_get('Subject', sStudies(1).BrainStormSubject);

    % SIMNIBS: Disable auto-alignment based on fiducials 
    if strcmpi(FileFormat, 'SIMNIBS')
        isAlignScs = 0;
    else
        isAlignScs = 1;
    end
    % If there is a MRI for this subject
    if ~isempty(sSubject.Anatomy) && ~isempty(sSubject.Anatomy(1).FileName)
        % Get the reference MRI (specified in input, or selected in the database)
        if isempty(RefMriFile) || ~file_exist(file_fullpath(RefMriFile))
            % If there are multiple MRIs
            if (length(sSubject.Anatomy) > 1)
                % Consider only the volumes that are not volume atlases
                iNoAtlas = find(cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject.Anatomy.FileName}));
                if (length(iNoAtlas) == 1)
                    iMri = iNoAtlas;
                % Interactive: Ask which MRI volume to use
                elseif isInteractive
                    mriComment = java_dialog('combo', '<HTML>Select the reference MRI:<BR><BR>', 'Import as MRI scanner coordinates', [], {sSubject.Anatomy(iNoAtlas).Comment});
                    if isempty(mriComment)
                        bst_progress('stop');
                        return
                    end
                    iMri = iNoAtlas(find(strcmp({sSubject.Anatomy(iNoAtlas).Comment}, mriComment), 1));
                % Non-interactive: Use the default MRI
                else
                    iMri = sSubject.iAnatomy;
                end
            else
                iMri = 1;
            end
            RefMriFile = file_fullpath(sSubject.Anatomy(iMri).FileName);
        end
        % Load the reference MRI (which contains the vox2mri transformation that should be used to interpret the coordinates)
        sMri = load(file_fullpath(RefMriFile), 'InitTransf', 'SCS', 'Voxsize');
        % If there is a valid transformation
        if isfield(sMri, 'InitTransf') && ~isempty(sMri.InitTransf) && ismember('vox2ras', sMri.InitTransf(:,1))
            % Ask user if necessary
            if isempty(isApplyVox2ras)
                isApplyVox2ras = java_dialog('confirm', [...
                    'There is a transformation to subject coordinates available in the MRI.' 10 ...
                    'Would you like to use it to align the sensors with the MRI?' 10 10 ...
                    'Answer NO to use the NAS/LPA/RPA fiducials from the input file.' 10], 'Apply MRI transformation');
            end
            % Apply transformation
            if isApplyVox2ras
                % Get the transformation WORLD=>MRI (in meters)
                Transf = cs_convert(sMri, 'world', 'mri');
                % Applies the coregistration transformation to the sensor positions, if requested
                if (isApplyVox2ras == 2)
                    iTransfReg = find(strcmpi(sMri.InitTransf(:,1), 'reg'), 1);
                    if ~isempty(iTransfReg)
                        Transf = Transf * sMri.InitTransf{iTransfReg,2};
                    end
                end
                % Add the transformation MRI=>SCS
                if isfield(sMri,'SCS') && isfield(sMri.SCS,'R') && ~isempty(sMri.SCS.R) && isfield(sMri.SCS,'T') && ~isempty(sMri.SCS.T)
                    Transf = [sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1] * Transf;
                else
                    error(['The SCS coordinates are not defined for this subject, the sensors will not be aligned on the anatomy. ' 10 'Consider defining the NAS/LPA/RPA fiducials before importing the sensors positions.']);
                end
                % Convert all the coordinates
                AllChannelMats = channel_apply_transf(ChannelMat, Transf, [], 1);
                ChannelMat = AllChannelMats{1};
                % Disable alignment based on SCS fiducials
                isAlignScs = 0;
            end
        end
    end
    
elseif isfield(ChannelMat, 'TransfMegLabels') && iscell(ChannelMat.TransfMegLabels) && ismember('Native=>Brainstorm/CTF', ChannelMat.TransfMegLabels)
    % No need to duplicate this transformation if it was previously
    % computed, e.g. in in_channel_ctf. (It would be identity the second
    % time.)
    isAlignScs = 0;
else
    isAlignScs = 1;
end


%% ===== DETECT CHANNEL TYPES =====
% Remove fiducials (expect for BIDS files)
isRemoveFid = isempty(strfind(FileFormat, 'BIDS-'));
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


