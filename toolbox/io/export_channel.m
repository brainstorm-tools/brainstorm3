function export_channel( BstChannelFile, OutputChannelFile )
% EXPORT_CHANNEL: Export a Channel file to one of the supported file formats.
%
% USAGE:  export_channel( BstChannelFile, OutputChannelFile )
%         export_channel( BstChannelFile )                 : OutputChannelFile is asked to the user
%
% INPUT: 
%     - BstChannelFile    : Full path to input Brainstorm MRI file to be exported
%     - OutputChannelFile : Full path to target file (extension will determine the format)

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
% Authors: Francois Tadel, 2008-2019

% ===== PASRSE INPUTS =====
if (nargin < 1) || isempty(BstChannelFile)
    error('Brainstorm:InvalidCall', 'Invalid use of export_channel()');
end
if (nargin < 2)
    OutputChannelFile = [];
end

% ===== SELECT OUTPUT FILE =====
if isempty(OutputChannelFile)
    % === Build a default filename ===
    % Get default directories and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get default extension
    switch (DefaultFormats.ChannelOut)
        case 'POLHEMUS',       DefaultExt = '.pos';
        case 'MEGDRAW',        DefaultExt = '.eeg';
        case 'POLHEMUS-HS',    DefaultExt = '.pos';
        case 'CARTOOL-XYZ',    DefaultExt = '.xyz';
        case 'BESA-SFP',       DefaultExt = '.sfp';
        case 'BESA-ELP',       DefaultExt = '.elp';
        case 'CURRY-RES',      DefaultExt = '.res';
        case 'EEGLAB-XYZ',     DefaultExt = '.xyz';
        case 'EGI',            DefaultExt = '.sfp';
        case 'BRAINSIGHT-TXT', DefaultExt = '.txt';
        otherwise,             DefaultExt = '.txt';
    end
    % Build default output filename
    [BstPath, BstBase, BstExt] = bst_fileparts(BstChannelFile);
    DefaultOutputFile = bst_fullfile(LastUsedDirs.ExportChannel, [BstBase, DefaultExt]);
    DefaultOutputFile = strrep(DefaultOutputFile, '_channel', '');
    DefaultOutputFile = strrep(DefaultOutputFile, 'channel_', '');
    
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
isMniTransf = ismember(FileFormat, {'ASCII_XYZ_MNI-EEG', 'ASCII_NXYZ_MNI-EEG', 'ASCII_XYZN_MNI-EEG'});
isWorldTransf = ismember(FileFormat, {'ASCII_XYZ_WORLD-EEG', 'ASCII_NXYZ_WORLD-EEG', 'ASCII_XYZN_WORLD-EEG', 'ASCII_XYZ_WORLD-HS', 'ASCII_NXYZ_WORLD-HS', 'ASCII_XYZN_WORLD-HS'});
% Get patient MRI (if needed)
if isMniTransf || isWorldTransf
    % Get channel file
    sStudy = bst_get('ChannelFile', BstChannelFile);
    % Get subject
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % Get the subject's MRI
    if isempty(sSubject.Anatomy) || isempty(sSubject.Anatomy(1).FileName)
        error('You need the subject anatomy in order to export the sensor positions to MNI or world coordinates.');
    end
    % Load the MRI
    MriFile = file_fullpath(sSubject.Anatomy(1).FileName);
    sMri = load(MriFile, 'SCS', 'NCS', 'InitTransf', 'Voxsize');
end
% MNI transformation
if isMniTransf
    % Check that the transformation is available
    if ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri, 'NCS') || ~isfield(sMri.NCS, 'R') || isempty(sMri.NCS.R)
        error(['The SCS and MNI transformations must be defined for this subject' 10 'in order to load sensor positions in MNI coordinates.']);
    end
    % Compute the transformation SCS => MNI
    Transf = cs_convert(sMri, 'scs', 'mni');
    
    RTscs2mri = inv([sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1]);
    RTmri2mni = [sMri.NCS.R, sMri.NCS.T./1000; 0 0 0 1];
    Transf = RTmri2mni * RTscs2mri;
% World transformation (vox2ras/nii)
elseif isWorldTransf
    % Check that the transformation is available
    if ~isfield(sMri, 'InitTransf') || isempty(sMri.InitTransf) || ~ismember('vox2ras', sMri.InitTransf(:,1))
        error(['The world/vox2ras transformations must be defined for this subject' 10 'in order to export sensor positions in world coordinates.']);
    end
    % Compute the transformation SCS => WORLD
    Transf = cs_convert(sMri, 'scs', 'world');
    
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
    
    % === NIRS ===
    case 'BRAINSIGHT-TXT'
        sSubject = bst_get('Subject');
        if sSubject.iAnatomy > 0
            out_channel_nirs_brainsight(BstChannelFile, OutputChannelFile, sSubject.Anatomy(sSubject.iAnatomy).FileName); %ADDTV
        else
            out_channel_nirs_brainsight(BstChannelFile, OutputChannelFile);
        end
    otherwise
        error(['Unsupported file format : "' FileFormat '"']);
        
end
% Hide progress bar
bst_progress('stop');






