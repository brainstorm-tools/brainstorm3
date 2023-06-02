function export_channel(BstChannelFile, OutputChannelFile, FileFormat, isInteractive)
% EXPORT_CHANNEL: Export a Channel file to one of the supported file formats.
%
% USAGE:  export_channel(BstChannelFile, OutputChannelFile=[ask], FileFormat=[ask], isInteractive=1)
%
% INPUTS: 
%     - BstChannelFile    : Full path to input Brainstorm MRI file to be exported
%     - OutputChannelFile : Full path to target file (extension will determine the format)
%     - FileFormat        : String, format of the exported channel file
%     - isInteractive     : If 1, the function is allowed to ask questions interactively to the user
%                           If 0, the function makes default choices with no interaction

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
% Authors: Francois Tadel, 2008-2022

% ===== PASRSE INPUTS =====
if (nargin < 4) || isempty(isInteractive)
    isInteractive = 1;
end
if (nargin < 2)
    OutputChannelFile = [];
    FileFormat = [];
end
if (nargin < 1) || isempty(BstChannelFile)
    error('Brainstorm:InvalidCall', 'Invalid use of export_channel()');
end

% ===== SELECT OUTPUT FILE =====
if isempty(OutputChannelFile)
    % === Build a default filename ===
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get default extension
    switch (DefaultFormats.ChannelOut)
        case 'POLHEMUS',            DefaultExt = '.pos';
        case 'MEGDRAW',             DefaultExt = '.eeg';
        case 'POLHEMUS-HS',         DefaultExt = '.pos';
        case 'CARTOOL-XYZ',         DefaultExt = '.xyz';
        case 'BESA-SFP',            DefaultExt = '.sfp';
        case 'BESA-ELP',            DefaultExt = '.elp';
        case 'BIDS-SCANRAS-MM',     DefaultExt = '_electrodes.tsv';
        case 'BIDS-MNI-MM',         DefaultExt = '_electrodes.tsv';
        case 'BIDS-ALS-MM',         DefaultExt = '_electrodes.tsv';
        case 'CURRY-RES',           DefaultExt = '.res';
        case 'EEGLAB-XYZ',          DefaultExt = '.xyz';
        case 'EGI',                 DefaultExt = '.sfp';
        case 'BRAINSIGHT-TXT',      DefaultExt = '.txt';
        case 'BIDS-NIRS-SCANRAS-MM',DefaultExt = '_optodes.tsv';
        case 'BIDS-NIRS-MNI-MM',    DefaultExt = '_optodes.tsv';
        case 'BIDS-NIRS-ALS-MM',    DefaultExt = '_optodes.tsv';
        otherwise,                  DefaultExt = '.pos';
    end

    % Get input study/subject
    sStudy = bst_get('ChannelFile', BstChannelFile);
    [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
    % Default output filename
    if (iSubject == 0) || isequal(sSubject.UseDefaultChannel, 2)
        baseFile = 'channel';
    else
        baseFile = sSubject.Name;
    end
    DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportChannel, [baseFile, DefaultExt]);
    
    % === Ask user filename ===
    [OutputChannelFile, FileFormat, FileFilter] = java_getfile( 'save', ...
        'Export channels...', ...    % Window title
        DefaultOutputFile, ...       % Default directory
        'single', 'files', ...       % Selection mode
        bst_get('FileFilters', 'channelout'), ...
        DefaultFormats.ChannelOut);
    % If no file was selected: exit
    if isempty(OutputChannelFile)
        return
    end
    % Save new default export path
    LastUsedDirs.ExportChannel = bst_fileparts(OutputChannelFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.ChannelOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end


% ===== TRANSFORMATIONS =====
isMniTransf = ismember(FileFormat, {'ASCII_XYZ_MNI-EEG', 'ASCII_NXYZ_MNI-EEG', 'ASCII_XYZN_MNI-EEG', 'BIDS-MNI-MM', 'BIDS-NIRS-MNI-MM'});
isWorldTransf = ismember(FileFormat, {'ASCII_XYZ_WORLD-EEG', 'ASCII_NXYZ_WORLD-EEG', 'ASCII_XYZN_WORLD-EEG', 'ASCII_XYZ_WORLD-HS', 'ASCII_NXYZ_WORLD-HS', 'ASCII_XYZN_WORLD-HS', 'BIDS-SCANRAS-MM', 'BIDS-NIRS-SCANRAS-MM', 'BRAINSIGHT-TXT'});
isRevertReg = ismember(FileFormat, {'BIDS-SCANRAS-MM', 'BIDS-NIRS-SCANRAS-MM'});
% Get patient MRI (if needed)
if isMniTransf || isWorldTransf
    % Get channel file
    sStudy = bst_get('ChannelFile', BstChannelFile);
    % Get subject
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % Get the subject's MRI
    if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
        error('You need the subject anatomy in order to export the sensor positions to MNI or world coordinates.');
    % MNI coordinates: always use the default MRI
    elseif isMniTransf
        iMri = sSubject.iAnatomy;
    % If there are multiple MRIs
    elseif (length(sSubject.Anatomy) > 1)
        % Consider only the volumes that are not volume atlases
        iNoAtlas = find(cellfun(@(c)isempty(strfind(c, '_volatlas')), {sSubject.Anatomy.FileName}));
        if (length(iNoAtlas) == 1)
            iMri = iNoAtlas;
        % Interactive: Ask which MRI volume to use
        elseif isInteractive
            mriComment = java_dialog('combo', '<HTML>Select the reference MRI:<BR><BR>', 'Export to MRI scanner coordinates', [], {sSubject.Anatomy(iNoAtlas).Comment});
            if isempty(mriComment)
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
    % Load the MRI transformations
    MriFile = file_fullpath(sSubject.Anatomy(iMri).FileName);
    sMri = load(MriFile, 'SCS', 'NCS', 'InitTransf', 'Voxsize');
else
    sMri = [];
end
% MNI transformation
if isMniTransf
    % Check that the transformation is available
    if ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri, 'NCS') || ((~isfield(sMri.NCS, 'R') || isempty(sMri.NCS.R)) && (~isfield(sMri.NCS, 'y') || isempty(sMri.NCS.y)))
        error(['The SCS and MNI transformations must be defined for this subject' 10 'in order to load sensor positions in MNI coordinates.']);
    end
    % Pass the entire MRI structure for conversions to MNI space
    Transf = sMri;
% World transformation (vox2ras/nii)
elseif isWorldTransf
    % Check that the transformation is available
    if ~isfield(sMri, 'InitTransf') || isempty(sMri.InitTransf) || ~ismember('vox2ras', sMri.InitTransf(:,1))
        error(['The world/vox2ras transformations must be defined for this subject' 10 'in order to export sensor positions in world coordinates.']);
    end
    % Compute the transformation SCS => WORLD
    Transf = cs_convert(sMri, 'scs', 'world');
    % If exporting to BIDS format AND there are transformations that were applied to MRI after it was imported to Brainstorm
    iTransfReg = find(strcmpi(sMri.InitTransf(:,1), 'reg'), 1);
    if ~isempty(iTransfReg) && isRevertReg
        Transf = inv(sMri.InitTransf{iTransfReg,2}) * Transf;
    end
else
    Transf = [];
end


% ===== SAVE CHANNEL FILE =====
[OutputPath, OutputBase, OutputExt] = bst_fileparts(OutputChannelFile);
% Show progress bar
bst_progress('start', 'Export channels', ['Export channels to file "' [OutputBase, OutputExt] '"...']);
% Switch between file formats
switch FileFormat
    % === HEADSHAPE + EEG ===
    case 'POLHEMUS'
        out_channel_pos(BstChannelFile, OutputChannelFile);
        
    % === HEAD SHAPE ONLY ===
    case 'MEGDRAW'
        out_channel_megdraw(BstChannelFile, OutputChannelFile);
    case 'POLHEMUS-HS'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'name','X','Y','Z'}, 0, 1, 1, .01);
    case 'ASCII_XYZ-HS'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'X','Y','Z'}, 0, 1, 0, .001, Transf);
    case 'ASCII_NXYZ-HS'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'Name','X','Y','Z'}, 0, 1, 0, .001, Transf);
    case 'ASCII_XYZN-HS'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'X','Y','Z','Name'}, 0, 1, 0, .001, Transf);
        
    % === EEG ONLY ===
    case 'CARTOOL-XYZ'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'-Y','X','Z','Name'}, 1, 0, 1, .01);
    case 'BESA-SFP'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'Name','-Y','X','Z'}, 1, 0, 0, .01);
    case 'BESA-ELP'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'Name','Y','X','Z'}, 1, 0, 0, .01);
    case 'BIDS-SCANRAS-MM'
        % Transf is a 4x4 transformation matrix
        out_channel_bids(BstChannelFile, OutputChannelFile, .001, Transf);
    case 'BIDS-MNI-MM'
        % Transf is a MRI structure with the definition of MNI normalization
        out_channel_bids(BstChannelFile, OutputChannelFile, .001, Transf);
    case 'BIDS-ALS-MM'
        % No transformation: export unchanged SCS/CTF space
        out_channel_bids(BstChannelFile, OutputChannelFile, .001, []);        
    case 'CURRY-RES'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'indice','-Y','X','Z','indice','name'}, 1, 0, 0, .001);
    case 'EEGLAB-XYZ'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'indice','-Y','X','Z','name'}, 1, 0, 0, .01);
    case 'EGI'
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'name','-Y','X','Z'}, 1, 0, 0, .01);
    case {'ASCII_XYZ-EEG', 'ASCII_XYZ_MNI-EEG', 'ASCII_XYZ_WORLD-EEG'}
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'X','Y','Z'}, 1, 0, 0, .001, Transf);
    case {'ASCII_NXYZ-EEG', 'ASCII_NXYZ_MNI-EEG', 'ASCII_NXYZ_WORLD-EEG'}
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'Name','X','Y','Z'}, 1, 0, 0, .001, Transf);
    case {'ASCII_XYZN-EEG', 'ASCII_XYZN_MNI-EEG', 'ASCII_XYZN_WORLD-EEG'}
        out_channel_ascii(BstChannelFile, OutputChannelFile, {'X','Y','Z','Name'}, 1, 0, 0, .001, Transf);

    % === NIRS ONLY ===
    case 'BIDS-NIRS-SCANRAS-MM'
        % Transf is a 4x4 transformation matrix
        out_channel_bids(BstChannelFile, OutputChannelFile, .001, Transf, 1);
    case 'BIDS-NIRS-MNI-MM'
        % Transf is a MRI structure with the definition of MNI normalization
        out_channel_bids(BstChannelFile, OutputChannelFile, .001, Transf, 1);
    case 'BIDS-NIRS-ALS-MM'
        % No transformation: export unchanged SCS/CTF space
        out_channel_bids(BstChannelFile, OutputChannelFile, .001, [], 1);
    case 'BRAINSIGHT-TXT'
        out_channel_nirs_brainsight(BstChannelFile, OutputChannelFile, .001, Transf); 

    otherwise
        error(['Unsupported file format : "' FileFormat '"']);
        
end
% Hide progress bar
bst_progress('stop');






