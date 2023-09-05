function errorMsg = import_anatomy_cat_2019(iSubject, CatDir, nVertices, isInteractive, sFid, isExtraMaps, isKeepMri, isTissues)
% IMPORT_ANATOMY_CAT_2019: Import a full CAT12 folder as the subject's anatomy (CAT12, 2019 version).
%
% USAGE:  errorMsg = import_anatomy_cat_2019(iSubject, CatDir=[], nVertices=15000, isInteractive=1, sFid=[], isExtraMaps=0, isKeepMri=0, isTissues=1)
%
% INPUT:
%    - iSubject     : Indice of the subject where to import the MRI
%                     If iSubject=0 : import MRI in default subject
%    - CatDir       : Full filename of the CAT12 folder to import
%    - nVertices    : Number of vertices in the file cortex surface
%    - isInteractive: If 0, no input or user interaction
%    - sFid         : Structure with the fiducials coordinates
%                     Or full MRI structure with fiducials defined in the SCS structure, to be registered with the FS MRI
%    - isExtraMaps  : If 1, create an extra folder "CAT12" to save the thickness maps
%    - isKeepMri    : 0=Delete all existing anatomy files (when importing a segmentation folder generated without Brainstorm into an empty subject)
%                     1=Keep existing MRI volumes (when running segmentation from Brainstorm)
%                     2=Keep existing MRI and surfaces
%    - isTissues     : If 1, combine the tissue probability maps (/mri/p*.nii) into a "tissue" volume
%
% OUTPUT:
%    - errorMsg : String: error message if an error occurs

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
% Authors: Francois Tadel, 2019-2022

%% ===== PARSE INPUTS =====
% Import tissues
if (nargin < 8) || isempty(isTissues)
    isTissues = 1;
end
% Keep MRI
if (nargin < 7) || isempty(isKeepMri)
    isKeepMri = 0;
end
% Extract cortical maps
if (nargin < 6) || isempty(isExtraMaps)
    isExtraMaps = 0;
end
% Fiducials
if (nargin < 5) || isempty(sFid)
    sFid = [];
end
% Interactive / silent
if (nargin < 4) || isempty(isInteractive)
    isInteractive = 1;
end
% Ask number of vertices for the cortex surface
if (nargin < 3) || isempty(nVertices)
    nVertices = [];
end
% Initialize returned variable
errorMsg = [];
% Ask folder to the user
if (nargin < 2) || isempty(CatDir)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Open file selection dialog
    CatDir = java_getfile( 'open', ...
        'Import CAT12 folder...', ...     % Window title
        bst_fileparts(LastUsedDirs.ImportAnat, 1), ...           % Last used directory
        'single', 'dirs', ...                  % Selection mode
        {{'.folder'}, 'CAT12 folder', 'CatDir'}, 0);
    % If no folder was selected: exit
    if isempty(CatDir)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = CatDir;
    bst_set('LastUsedDirs', LastUsedDirs);
end
% Unload everything
bst_memory('UnloadAll', 'Forced');



%% ===== DELETE PREVIOUS ANATOMY =====
% Get subject definition
sSubject = bst_get('Subject', iSubject);
% Check for existing anatomy
if (~isempty(sSubject.Anatomy) && (isKeepMri == 0)) || (~isempty(sSubject.Surface) && (isKeepMri < 2))
    % Ask user whether the previous anatomy should be removed
    if isInteractive
        isDel = java_dialog('confirm', ['Warning: There is already an anatomy defined for this subject.' 10 10 ...
            'Are you sure you want to delete the previous MRI and surfaces ?' 10 10], 'Import CAT12 folder');
    else
        isDel = 1;
    end
    % If user canceled process
    if ~isDel
        bst_progress('stop');
        return;
    end
    % Delete anatomy
    sSubject = db_delete_anatomy(iSubject, isKeepMri);
end


%% ===== ASK NB VERTICES =====
if isempty(nVertices)
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import CAT12 folder', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
end
% Number for each hemisphere
nVertHemi = round(nVertices / 2);


%% ===== PARSE CAT12 FOLDER =====
isProgress = bst_progress('isVisible');
bst_progress('start', 'Import CAT12 folder', 'Parsing folder...');
% Find MRI
T1File = file_find(CatDir, '*.nii', 1, 0);
if isempty(T1File)
    errorMsg = [errorMsg 'Original MRI file was not found: *.nii in top folder' 10];
elseif (length(T1File) > 1)
    errorMsg = [errorMsg 'Multiple .nii found in top folder' 10];
end
% Find surfaces
TessLhFile = file_find(CatDir, 'lh.central.*.gii', 2);
TessRhFile = file_find(CatDir, 'rh.central.*.gii', 2);
TessLsphFile = file_find(CatDir, 'lh.sphere.reg.*.gii', 2);
TessRsphFile = file_find(CatDir, 'rh.sphere.reg.*.gii', 2);
if isempty(TessLhFile)
    errorMsg = [errorMsg 'Surface file was not found: lh.central' 10];
end
if isempty(TessRhFile)
    errorMsg = [errorMsg 'Surface file was not found: rh.central' 10];
end

% Initialize SPM12+CAT12
[isInstalled, errorMsg, PlugCat] = bst_plugin('Install', 'cat12', isInteractive, 1728);
if ~isInstalled
    return;
end
bst_plugin('SetProgressLogo', 'cat12');
% CAT path
CatExeDir = bst_fullfile(PlugCat.Path, PlugCat.SubFolder);
% FSAverage surfaces in CAT12 program folder
FsAvgLhFile = bst_fullfile(CatExeDir, 'templates_surfaces', 'lh.central.freesurfer.gii');
FsAvgRhFile = bst_fullfile(CatExeDir, 'templates_surfaces', 'rh.central.freesurfer.gii');
Fs32kLhFile = bst_fullfile(CatExeDir, 'templates_surfaces_32k', 'lh.central.freesurfer.gii');
Fs32kRhFile = bst_fullfile(CatExeDir, 'templates_surfaces_32k', 'rh.central.freesurfer.gii');
% FSAverage spheres in CAT12 program folder
FsAvgLsphFile = bst_fullfile(CatExeDir, 'templates_surfaces', 'lh.sphere.freesurfer.gii');
FsAvgRsphFile = bst_fullfile(CatExeDir, 'templates_surfaces', 'rh.sphere.freesurfer.gii');
Fs32kLsphFile = bst_fullfile(CatExeDir, 'templates_surfaces_32k', 'lh.sphere.freesurfer.gii');
Fs32kRsphFile = bst_fullfile(CatExeDir, 'templates_surfaces_32k', 'rh.sphere.freesurfer.gii');
% Find FSAverage labels in CAT12 program folder
AnnotAvgLhFiles = {file_find(bst_fullfile(CatExeDir, 'atlases_surfaces'), 'lh.aparc_a2009s.freesurfer.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces'), 'lh.aparc_DK40.freesurfer.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces'), 'lh.aparc_HCP_MMP1.freesurfer.annot', 2)};
AnnotAvgRhFiles = {file_find(bst_fullfile(CatExeDir, 'atlases_surfaces'), 'rh.aparc_a2009s.freesurfer.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces'), 'rh.aparc_DK40.freesurfer.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces'), 'rh.aparc_HCP_MMP1.freesurfer.annot', 2)};
Annot32kLhFiles = {file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_100Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_100Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_200Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_200Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_400Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_400Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_600Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_600Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_800Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_800Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_1000Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'lh.Schaefer2018_1000Parcels_17Networks_order.annot', 2)};
Annot32kRhFiles = {file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_100Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_100Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_200Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_200Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_400Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_400Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_600Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_600Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_800Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_800Parcels_17Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_1000Parcels_7Networks_order.annot', 2), ...
                   file_find(bst_fullfile(CatExeDir, 'atlases_surfaces_32k'), 'rh.Schaefer2018_1000Parcels_17Networks_order.annot', 2)};
AnnotAvgLhFiles(cellfun(@isempty, AnnotAvgLhFiles)) = [];
AnnotAvgRhFiles(cellfun(@isempty, AnnotAvgRhFiles)) = [];
Annot32kLhFiles(cellfun(@isempty, Annot32kLhFiles)) = [];
Annot32kRhFiles(cellfun(@isempty, Annot32kRhFiles)) = [];

% Find tissue probability maps
if isTissues
    TpmFiles = {file_find(CatDir, 'p2*.nii', 2), ...  % White matter
                file_find(CatDir, 'p1*.nii', 2), ...  % Gray matter
                file_find(CatDir, 'p3*.nii', 2), ...  % CSF
                file_find(CatDir, 'p4*.nii', 2), ...  % Skull
                file_find(CatDir, 'p5*.nii', 2), ...  % Scalp
                file_find(CatDir, 'p6*.nii', 2)};     % Background
end
% Find extra cortical maps
if isExtraMaps
    % Cortical thickness
    ThickLhFile = file_find(CatDir, 'lh.thickness.*', 2);
    ThickRhFile = file_find(CatDir, 'rh.thickness.*', 2);
    % Gyrification maps
    GyriLhFile = file_find(CatDir, 'lh.gyrification.*', 2);
    GyriRhFile = file_find(CatDir, 'rh.gyrification.*', 2);
    % Sulcal maps
    SulcalLhFile = file_find(CatDir, 'lh.sqrtsulc.*', 2);
    if isempty(SulcalLhFile)
        SulcalLhFile = file_find(CatDir, 'lh.depth.*', 2);
    end
    SulcalRhFile = file_find(CatDir, 'rh.sqrtsulc.*', 2);
    if isempty(SulcalRhFile)
        SulcalRhFile = file_find(CatDir, 'rh.depth.*', 2);
    end
    % Cortical complexity maps
    FDLhFile = file_find(CatDir, 'lh.fractaldimension.*', 2);
    FDRhFile = file_find(CatDir, 'rh.fractaldimension.*', 2);
end
% Report errors
if ~isempty(errorMsg)
    if isInteractive
        bst_error(['Could not import CAT12 folder: ' 10 10 errorMsg], 'Import CAT12 folder', 0);        
    end
    return;
end


%% ===== IMPORT MRI =====
% Context: Execution of CAT12 from an MRI already imported in the Brainstorm database
if isKeepMri && ~isempty(sSubject.Anatomy)
    BstT1File = file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName);
    sMri = in_mri_bst(BstT1File);
% Context: CAT12 was executed independently from Brainstorm, now importing the output folder in an empty subject
else
    % Read MRI
    [BstT1File, sMri] = import_mri(iSubject, T1File);
    if isempty(BstT1File)
        errorMsg = 'Could not import CAT12 folder: MRI was not imported properly';
        if isInteractive
            bst_error(errorMsg, 'Import CAT12 folder', 0);
        end
        return;
    end
end


%% ===== DEFINE FIDUCIALS / MNI NORMALIZATION =====
% Set fiducials and/or compute linear MNI normalization
[isComputeMni, errCall] = process_import_anatomy('SetFiducials', iSubject, CatDir, BstT1File, sFid, isKeepMri, isInteractive);
% Error handling
if ~isempty(errCall)
    errorMsg = [errorMsg, errCall];
    if isempty(isComputeMni)
        if isInteractive
            bst_error(errorMsg, 'Import CAT12 folder', 0);
        end
        return;
    end
end


%% ===== IMPORT SURFACES =====
% Left pial
if ~isempty(TessLhFile)
    % Import file
    [iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, TessLhFile, 'GII-WORLD', 0);
    BstTessLhFile = BstTessLhFile{1};
    % Load sphere
    if ~isempty(TessLsphFile)
        bst_progress('start', 'Import CAT12 folder', 'Loading registered sphere: left pial...');
        [TessMat, err] = tess_addsphere(BstTessLhFile, TessLsphFile, 'GII-CAT');
        errorMsg = [errorMsg err];
    end
end
% Right pial
if ~isempty(TessRhFile)
    % Import file
    [iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, TessRhFile, 'GII-WORLD', 0);
    BstTessRhFile = BstTessRhFile{1};
    % Load sphere
    if ~isempty(TessRsphFile)
        bst_progress('start', 'Import CAT12 folder', 'Loading registered sphere: right pial...');
        [TessMat, err] = tess_addsphere(BstTessRhFile, TessRsphFile, 'GII-CAT');
        errorMsg = [errorMsg err];
    end
end

% Left FSAverage (only if the spheres are available)
if ~isempty(FsAvgLhFile) && ~isempty(TessLsphFile)
    % Import file
    [iAvgLh, BstFsAvgLhFile, nVertOrigAvgL] = import_surfaces(iSubject, FsAvgLhFile, 'GII-WORLD', 0);
    BstFsAvgLhFile = BstFsAvgLhFile{1};
    % Load atlases
    if ~isempty(AnnotAvgLhFiles)
        bst_progress('start', 'Import CAT12 folder', 'Loading atlases: left FSAverage...');
        [sAllAtlas, err] = import_label(BstFsAvgLhFile, AnnotAvgLhFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load sphere
    if ~isempty(FsAvgLsphFile)
        bst_progress('start', 'Import CAT12 folder', 'Loading registered sphere: left FSAverage...');
        [TessMat, err] = tess_addsphere(BstFsAvgLhFile, FsAvgLsphFile, 'GII-CAT');
        errorMsg = [errorMsg err];
    end
end
% Right FSAverage (only if the spheres are available)
if ~isempty(FsAvgRhFile) && ~isempty(TessRsphFile)
    % Import file
    [iAvgRh, BstFsAvgRhFile, nVertOrigAvgR] = import_surfaces(iSubject, FsAvgRhFile, 'GII-WORLD', 0);
    BstFsAvgRhFile = BstFsAvgRhFile{1};
    % Load atlases
    if ~isempty(AnnotAvgRhFiles)
        bst_progress('start', 'Import CAT12 folder', 'Loading atlases: right FSAverage...');
        [sAllAtlas, err] = import_label(BstFsAvgRhFile, AnnotAvgRhFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load sphere
    if ~isempty(FsAvgRsphFile)
        bst_progress('start', 'Import CAT12 folder', 'Loading registered sphere: right FSAverage...');
        [TessMat, err] = tess_addsphere(BstFsAvgRhFile, FsAvgRsphFile, 'GII-CAT');
        errorMsg = [errorMsg err];
    end
end

% Left FSAverage 32k (only if the spheres are available)
if ~isempty(Fs32kLhFile) && ~isempty(TessLsphFile)
    % Import file
    [i32kLh, BstFs32kLhFile, nVertOrig32kL] = import_surfaces(iSubject, Fs32kLhFile, 'GII-WORLD', 0);
    BstFs32kLhFile = BstFs32kLhFile{1};
    % Load atlases
    if ~isempty(Annot32kLhFiles)
        bst_progress('start', 'Import CAT12 folder', 'Loading atlases: left FSAverage 32k...');
        [sAllAtlas, err] = import_label(BstFs32kLhFile, Annot32kLhFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load sphere
    if ~isempty(Fs32kLsphFile)
        bst_progress('start', 'Import CAT12 folder', 'Loading registered sphere: left FSAverage 32k...');
        [TessMat, err] = tess_addsphere(BstFs32kLhFile, Fs32kLsphFile, 'GII-CAT');
        errorMsg = [errorMsg err];
    end
end
% Right FSAverage 32k (only if the spheres are available)
if ~isempty(Fs32kRhFile) && ~isempty(TessRsphFile)
    % Import file
    [i32kRh, BstFs32kRhFile, nVertOrig32kR] = import_surfaces(iSubject, Fs32kRhFile, 'GII-WORLD', 0);
    BstFs32kRhFile = BstFs32kRhFile{1};
    % Load atlases
    if ~isempty(Annot32kRhFiles)
        bst_progress('start', 'Import CAT12 folder', 'Loading atlases: right FSAverage 32k...');
        [sAllAtlas, err] = import_label(BstFs32kRhFile, Annot32kRhFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load sphere
    if ~isempty(Fs32kRsphFile)
        bst_progress('start', 'Import CAT12 folder', 'Loading registered sphere: right FSAverage 32k...');
        [TessMat, err] = tess_addsphere(BstFs32kRhFile, Fs32kRsphFile, 'GII-CAT');
        errorMsg = [errorMsg err];
    end
end

% Process error messages
if ~isempty(errorMsg)
    if isInteractive
        bst_error(errorMsg, 'Import CAT12 folder', 0);
    else
        disp(['ERROR: ' errorMsg]);
    end
    return;
end


%% ===== PROJECT ATLASES =====
rmFiles = {};
% If the registered spheres are available
if ~isempty(TessLsphFile) && ~isempty(TessRsphFile)
    % Project FSAverage atlases
    if ~isempty(FsAvgLhFile) && ~isempty(FsAvgRhFile)
        bst_project_scouts(BstFsAvgLhFile, BstTessLhFile, [], 1);
        bst_project_scouts(BstFsAvgRhFile, BstTessRhFile, [], 1);
        rmFiles = cat(2, rmFiles, {BstFsAvgLhFile, BstFsAvgRhFile});
    end
    % Project FSAverage 32k atlases
    if ~isempty(Fs32kLhFile) && ~isempty(Fs32kRhFile)
        bst_project_scouts(BstFs32kLhFile, BstTessLhFile, [], 1);
        bst_project_scouts(BstFs32kRhFile, BstTessRhFile, [], 1);
        rmFiles = cat(2, rmFiles, {BstFs32kLhFile, BstFs32kRhFile});
    end
end


%% ===== DOWNSAMPLE =====
% Downsample left and right hemispheres
if ~isempty(TessRhFile)
    bst_progress('start', 'Import CAT12 folder', 'Downsampling: right pial...');
    [BstTessRhLowFile, iRhLow, xRhLow] = tess_downsize(BstTessRhFile, nVertHemi, 'reducepatch');
end
if ~isempty(TessLhFile)
    bst_progress('start', 'Import CAT12 folder', 'Downsampling: left pial...');
    [BstTessLhLowFile, iLhLow, xLhLow] = tess_downsize(BstTessLhFile, nVertHemi, 'reducepatch');
end


%% ===== MERGE SURFACES =====
% Merge hemispheres
if ~isempty(TessLhFile) && ~isempty(TessRhFile)
    % Hi-resolution surface
    CortexHiFile  = tess_concatenate({BstTessLhFile,    BstTessRhFile},    sprintf('cortex_%dV', nVertOrigL + nVertOrigR), 'Cortex');
    CortexLowFile = tess_concatenate({BstTessLhLowFile, BstTessRhLowFile}, sprintf('cortex_%dV', length(xLhLow) + length(xRhLow)), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {BstTessLhFile, BstTessRhFile, BstTessLhLowFile, BstTessRhLowFile});
else
    CortexHiFile = [];
    CortexLowFile = [];
end


%% ===== RE-ORGANIZE FILES =====
% Delete intermediate files
if ~isempty(rmFiles)
    file_delete(file_fullpath(rmFiles), 1);
end
% Rename final files
if ~isempty(TessLhFile) && ~isempty(TessRhFile)
    % Rename high-res file
    oldCortexHiFile = file_fullpath(CortexHiFile);
    CortexHiFile    = bst_fullfile(bst_fileparts(oldCortexHiFile), 'tess_cortex_pial_high.mat');
    file_move(oldCortexHiFile, CortexHiFile);
    CortexHiFile = file_short(CortexHiFile);
    % Rename high-res file
    oldCortexLowFile = file_fullpath(CortexLowFile);
    CortexLowFile    = bst_fullfile(bst_fileparts(oldCortexLowFile), 'tess_cortex_pial_low.mat');
    file_move(oldCortexLowFile, CortexLowFile);
    CortexHiFile = file_short(CortexHiFile);
end
% Reload subject
db_reload_subjects(iSubject);


%% ===== GENERATE HEAD =====
% Generate head surface
HeadFile = tess_isohead(iSubject, 10000, 0, 2);


%% ===== IMPORT THICKNESS MAPS =====
if isExtraMaps && ~isempty(CortexHiFile)
    % Create a condition "CAT12"
    iStudy = db_add_condition(iSubject, 'CAT12');
    % Import cortical thickness
    if ~isempty(ThickLhFile) && ~isempty(ThickRhFile)
        import_sources(iStudy, CortexHiFile, ThickLhFile, ThickRhFile, 'FS', 'thickness');
    end
    % Import gyrification
    if ~isempty(GyriLhFile) && ~isempty(GyriRhFile)
        import_sources(iStudy, CortexHiFile, GyriLhFile, GyriRhFile, 'FS', 'gyrification');
    end
    % Import sulcal depth
    if ~isempty(SulcalLhFile) && ~isempty(SulcalRhFile)
        import_sources(iStudy, CortexHiFile, SulcalLhFile, SulcalRhFile, 'FS', 'depth');
    end
    % Import cortex complexity
    if ~isempty(FDLhFile) && ~isempty(FDRhFile)
        import_sources(iStudy, CortexHiFile, FDLhFile, FDRhFile, 'FS', 'fractaldimension');
    end
end


%% ===== IMPORT TISSUE LABELS =====
if isTissues && ~isempty(TpmFiles)
    bst_progress('start', 'Import CAT12 folder', 'Importing tissue probability maps...');
    sMriTissue = [];
    pCube = [];
    % Find for each voxel in which tissue there is the highest probability
    for iTissue = 1:length(TpmFiles)
        % Skip missing tissue
        if isempty(TpmFiles{iTissue})
            continue;
        end
        % Load probability map
        sMriProb = in_mri_nii(TpmFiles{iTissue}, 0, 0, 0);
        % First volume: Copy structure
        if isempty(sMriTissue)
            sMriTissue = sMriProb;
            sMriTissue.Cube = 0 .* sMriTissue.Cube;
            pCube = sMriTissue.Cube;
        end
        % Set label for the voxels that have a probability higher than the previous volumes
        maskLabel = ((sMriProb.Cube > pCube) & (sMriProb.Cube > 0));
        sMriTissue.Cube(maskLabel) = iTissue;
        pCube(maskLabel) = sMriProb.Cube(maskLabel);
    end
    % Save tissues atlas
    if ~isempty(sMriTissue)
        % Get updated subject definition
        sSubject = bst_get('Subject', iSubject);
        % Replace background with zeros
        sMriTissue.Cube(sMriTissue.Cube == 6) = 0;
        % Add basic labels
        sMriTissue.Labels = mri_getlabels('tissues5');
        % Set comment
        sMriTissue.Comment = file_unique('tissues', {sSubject.Surface.Comment});
        % Copy some fields from the original MRI
        if isfield(sMri, 'SCS') 
            sMriTissue.SCS = sMri.SCS;
        end
        if isfield(sMri, 'NCS') 
            sMriTissue.NCS = sMri.NCS;
        end
        if isfield(sMri, 'History') 
            sMriTissue.History = sMri.History;
        end
        % Add history tag
        sMriTissue = bst_history('add', sMriTissue, 'segment', 'Tissues segmentation generated with CAT12.');
        % Output file name
        TissueFile = file_unique(strrep(file_fullpath(BstT1File), '.mat', '_tissues.mat'));
        % Save new MRI in Brainstorm format
        sMriTissue = out_mri_bst(sMriTissue, TissueFile);
        % Add to subject
        iAnatomy = length(sSubject.Anatomy) + 1;
        sSubject.Anatomy(iAnatomy).Comment  = sMriTissue.Comment;
        sSubject.Anatomy(iAnatomy).FileName = file_short(TissueFile);
        % Save subject
        bst_set('Subject', iSubject, sSubject);
    end
end


%% ===== UPDATE GUI =====
% Set default cortex
if ~isempty(TessLhFile) && ~isempty(TessRhFile)
    [sSubject, iSubject, iSurface] = bst_get('SurfaceFile', CortexLowFile);
    db_surface_default(iSubject, 'Cortex', iSurface);
end
% Update subject node
panel_protocols('UpdateNode', 'Subject', iSubject);
panel_protocols('SelectNode', [], 'subject', iSubject, -1 );
% Save database
db_save();
% Unload everything
bst_memory('UnloadAll', 'Forced');
% Give a graphical output for user validation
if isInteractive
    % Display the downsampled cortex + head + ASEG
    hFig = view_surface(HeadFile);
    % Display cortex
    if ~isempty(CortexLowFile)
        view_surface(CortexLowFile);
    end
    % Set orientation
    figure_3d('SetStandardView', hFig, 'left');
end
% Close progress bar
bst_plugin('SetProgressLogo', []);
if ~isProgress
    bst_progress('stop');
end



