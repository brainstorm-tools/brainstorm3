function [MriFileMni, sMriMni] = import_mniatlas(iSubject, sTemplate, isInteractive)
% IMPORT_MNIATLAS: Add a MNI parcellation to the selected subject.
%
% USAGE:  [MriFileMni, sMriMni] = import_mniatlas(iSubject, sTemplate, isInteractive=1);
%         [MriFileMni, sMriMni] = import_mniatlas(iSubject);     % Import MNI parcellation from file on the hard drive
%
% INPUT: 
%    - iSubject      : Subject indice in protocol definition (default anatomy: iSubject=0)
%    - sTemplate     : Reference to the MNI parcellation (zip file or URL)
%    - isInteractive : If 1, asks for confirmation and open the MRI Viewer for fiducials verification (default is 1)

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
% Authors: Francois Tadel, 2020


%% ===== PARSE INPUTS =====
% Initialize returned values
MriFileMni = [];
sMriMni = [];
% Parse inputs
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 1;
end
if (nargin < 2) || isempty(sTemplate)
    sTemplate = [];
end


%% ===== GET INPUT FILE =====
if isempty(sTemplate)
    % Get last used directories
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get MRI file
    [AtlasFile, FileFormat, FileFilter] = java_getfile( 'open', ...
        'Import MRI...', ...              % Window title
        LastUsedDirs.ImportAnat, ...      % Default directory
        'single', 'files', ...            % Selection mode
        {{'.nii', '.gz'}, 'Volume parcellation (MNI space)', 'ALL-MNI-ATLAS'}, 'ALL-MNI-ATLAS');
    % If no file was selected: exit
    if isempty(AtlasFile)
        return
    end
    % Save default import directory
    [fPath,fBase,fExt] = bst_fileparts(AtlasFile);
    LastUsedDirs.ImportAnat = fPath;
    bst_set('LastUsedDirs', LastUsedDirs);
    % For .nii.gz files, remove also the .nii
    fBase = strrep(fBase, '.nii', '');
    % Files for this template
    LicenseFile = bst_fullfile(fPath, [fBase '.txt']);
    AtlasName = fBase;
    AtlasUrl = [];
    
%% ===== GET TEMPLATE =====
else
    % Get MNI parcellation directory
    atlasDir = bst_fullfile(bst_get('UserDefaultsDir'), 'mniatlas');
    if ~file_exist(atlasDir)
        mkdir(atlasDir);
    end
    % URL: Download zip file
    if ~isempty(strfind(sTemplate.FilePath, 'http://')) || ~isempty(strfind(sTemplate.FilePath, 'https://')) || ~isempty(strfind(sTemplate.FilePath, 'ftp://'))
        tmpDir = bst_get('BrainstormTmpDir');
        % Output file
        ZipFile = bst_fullfile(tmpDir, [sTemplate.Name '.zip']);
        % Download file
        errMsg = gui_brainstorm('DownloadFile', sTemplate.FilePath, ZipFile, 'Download MNI parcellation');
        if ~isempty(errMsg)
            error(['Impossible to download parcellation:' 10 errMsg]);
        end
        % Progress bar
        bst_progress('start', 'Download parcellation', 'Unzipping file...');
        % URL: Download zip file
        try
            UnzippedFiles = unzip(ZipFile, atlasDir);
        catch
            error(['Could not unzip parcellation: ' 10 10 lasterr]);
        end
        if (length(UnzippedFiles) > 3)
            error('Multiple parcellations were downloaded, please select one of them.');
        end
        % Look for parcellation volume
        sTemplate.FilePath = bst_fullfile(atlasDir, [sTemplate.Name '.nii.gz']);
    end
    % Check the existence of MNI volume
    if ~file_exist(sTemplate.FilePath)
        error(['Could not find file: ' sTemplate.FilePath]);
    end
    % Files for this template
    LicenseFile = bst_fullfile(atlasDir, [lower(sTemplate.Name) '.txt']);
    AtlasFile = sTemplate.FilePath;
    AtlasName = sTemplate.Name;
    AtlasUrl = sTemplate.Info;
end


%% ===== TARGET SUBJECT =====
% Get subject
sSubject = bst_get('Subject', iSubject);
% Check existing anatomy
if isempty(sSubject.Anatomy)
    error('You must import a reference MRI or anatomy template before adding extra parcellations.');
end
% Compute linear MNI registration if not available
MriFileRef = sSubject.Anatomy(sSubject.iAnatomy).FileName;
sMriRef = in_mri_bst(MriFileRef);
if ~isfield(sMriRef, 'NCS') || ...
        ((~isfield(sMriRef.NCS, 'R') || ~isfield(sMriRef.NCS, 'T') || isempty(sMriRef.NCS.R) || isempty(sMriRef.NCS.T)) && ... 
         (~isfield(sMriRef.NCS, 'iy') || isempty(sMriRef.NCS.iy)))
     error('The subject anatomy must be normalized to MNI space first.');
end


%% ===== IMPORT ATLAS =====
% Display license
if file_exist(LicenseFile)
    view_text(LicenseFile, AtlasName, 1, 1);
end
% Import
[MriFileMni, sMriMni] = import_mri(iSubject, AtlasFile, 'ALL-MNI-ATLAS', isInteractive);
if isempty(MriFileMni)
    error(['Could not import file: ' AtlasFile]);
end
% Open website
if ~isempty(AtlasUrl)
    web(AtlasUrl, '-browser');
end
% Close process bar
bst_progress('stop');


