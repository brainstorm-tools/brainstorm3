function errorMsg = import_anatomy_cat_2020(iSubject, CatDir, nVertices, isInteractive, sFid, isExtraMaps, isKeepMri, isVolumeAtlas)
% IMPORT_ANATOMY_CAT_2020: Import a full CAT12 folder as the subject's anatomy (Version >= CAT12.7-RC2)
%
% USAGE:  errorMsg = import_anatomy_cat_2020(iSubject, CatDir=[], nVertices=15000, isInteractive=1, sFid=[], isExtraMaps=0, isKeepMri=0, isVolumeAtlas=1)
%
% INPUT:
%    - iSubject     : Indice of the subject where to import the MRI
%                     If iSubject=0 : import MRI in default subject
%    - CatDir       : Full filename of the CAT12 folder to import
%    - nVertices    : Number of vertices in the file cortex surface
%    - isInteractive: If 0, no input or user interaction
%    - sFid         : Structure with the fiducials coordinates
%    - isExtraMaps  : If 1, create an extra folder "CAT12" to save the thickness maps
%    - isKeepMri    : 0=Delete all existing anatomy files
%                     1=Keep existing MRI volumes (when running segmentation from Brainstorm)
%                     2=Keep existing MRI and surfaces
%    - isVolumeAtlas: If 1, combine the tissue probability maps (/mri/p*.nii) into a "tissue" volume
%                     and import all the volume atlases in folder mri_atlas
%                     
%
% OUTPUT:
%    - errorMsg : String: error message if an error occurs

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
% Authors: Francois Tadel, 2019-2021

%% ===== PARSE INPUTS =====
% Import tissues
if (nargin < 8) || isempty(isVolumeAtlas)
    isVolumeAtlas = 1;
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
bst_plugin('SetProgressLogo', 'cat12');
% Find MRI
T1File = file_find(CatDir, '*.nii', 1, 0);
if isempty(T1File)
    errorMsg = [errorMsg 'Original MRI file was not found: *.nii in top folder' 10];
elseif (length(T1File) > 1)
    errorMsg = [errorMsg 'Multiple .nii found in top folder' 10];
end
% Find central surfaces
GiiLcFile = file_find(CatDir, 'lh.central.*.gii', 2);
GiiRcFile = file_find(CatDir, 'rh.central.*.gii', 2);
GiiCcFile = file_find(CatDir, 'cb.central.*.gii', 2);
if isempty(GiiLcFile)
    errorMsg = [errorMsg 'Surface file was not found: lh.central' 10];
end
if isempty(GiiRcFile)
    errorMsg = [errorMsg 'Surface file was not found: rh.central' 10];
end
% Find pial and white surfaces: only if extra maps are requested
if isExtraMaps
    GiiLpFile = file_find(CatDir, 'lh.pial.*.gii', 2);
    GiiRpFile = file_find(CatDir, 'rh.pial.*.gii', 2);
    GiiCpFile = file_find(CatDir, 'cb.pial.*.gii', 2);
    GiiLwFile = file_find(CatDir, 'lh.white.*.gii', 2);
    GiiRwFile = file_find(CatDir, 'rh.white.*.gii', 2);
    GiiCwFile = file_find(CatDir, 'cb.white.*.gii', 2);
    GiiLsphFile = file_find(CatDir, 'lh.sphere.reg.*.gii', 2);
    GiiRsphFile = file_find(CatDir, 'rh.sphere.reg.*.gii', 2);
    GiiCsphFile = file_find(CatDir, 'cb.sphere.reg.*.gii', 2);
else
    GiiLpFile = [];
    GiiRpFile = [];
    GiiCpFile = [];
    GiiLwFile = [];
    GiiRwFile = [];
    GiiCwFile = [];
    GiiLsphFile = [];
    GiiRsphFile = [];
    GiiCsphFile = [];
end
% Find atlases
AnnotLhFiles = file_find(CatDir, 'lh.*.annot', 2, 0);
AnnotRhFiles = file_find(CatDir, 'rh.*.annot', 2, 0);
% Re-order the files so that FreeSurfer atlases are first (for automatic region labelling)
if ~isempty(AnnotLhFiles) && ~isempty(AnnotRhFiles)
    iDKL = find(~cellfun(@(c)isempty(strfind(c, 'aparc_DK40')), AnnotLhFiles));
    iDKR = find(~cellfun(@(c)isempty(strfind(c, 'aparc_DK40')), AnnotRhFiles));
    if ~isempty(iDKL) && ~isempty(iDKR)
        AnnotLhFiles = AnnotLhFiles([iDKL, setdiff(1:length(AnnotLhFiles), iDKL)]);
        AnnotRhFiles = AnnotRhFiles([iDKR, setdiff(1:length(AnnotRhFiles), iDKR)]);
    end
end

% Find tissue probability maps
if isVolumeAtlas
    TpmFiles = {file_find(CatDir, 'p2*.nii', 2), ...  % White matter
                file_find(CatDir, 'p1*.nii', 2), ...  % Gray matter
                file_find(CatDir, 'p3*.nii', 2), ...  % CSF
                file_find(CatDir, 'p4*.nii', 2), ...  % Skull
                file_find(CatDir, 'p5*.nii', 2), ...  % Scalp
                file_find(CatDir, 'p6*.nii', 2)};     % Background
    % CAT <= 12.7
    if isdir(bst_fullfile(CatDir, 'mri_atlas'))
        VolAtlasFiles = file_find(bst_fullfile(CatDir, 'mri_atlas'), '*.nii', 1, 0);
    % CAT >= 12.8
    else
        VolAtlasFiles = {...
            file_find(bst_fullfile(CatDir, 'mri'), 'aal3_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'anatomy3_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'cobra_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'hammers_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'ibsr_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'julichbrain_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'lpba40_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'mori_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'neuromorphometrics_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'thalamus_*.nii*', 1, 0), ...
            file_find(bst_fullfile(CatDir, 'mri'), 'Schaefer2018_*.nii*', 1, 0)};
        VolAtlasFiles = [VolAtlasFiles{find(~cellfun(@isempty, VolAtlasFiles))}];
    end
end
% Find MNI registration volumes
RegFile = file_find(CatDir, 'y_*.nii', 2);
RegInvFile = file_find(CatDir, 'iy_*.nii', 2);

% Find extra cortical maps
if isExtraMaps
    % Cortical thickness
    ThickLhFile = file_find(CatDir, 'lh.thickness.*', 2);
    ThickRhFile = file_find(CatDir, 'rh.thickness.*', 2);
    % Gyrification maps
    GyriLhFile = file_find(CatDir, 'lh.gyrification.*', 2);
    GyriRhFile = file_find(CatDir, 'rh.gyrification.*', 2);
    % Sulcal maps
    SulcalLhFile = file_find(CatDir, 'lh.depth.*', 2);
    SulcalRhFile = file_find(CatDir, 'rh.depth.*', 2);
    % Cortical complexity maps
    FDLhFile = file_find(CatDir, 'lh.fractaldimension.*', 2);
    FDRhFile = file_find(CatDir, 'rh.fractaldimension.*', 2);
end
% Find fiducials definitions
FidFile = file_find(CatDir, 'fiducials.m');
% Report errors
if ~isempty(errorMsg)
    if isInteractive
        bst_error(['Could not import CAT12 folder: ' 10 10 errorMsg], 'Import CAT12 folder', 0);        
    end
    return;
end


%% ===== IMPORT MRI =====
if isKeepMri && ~isempty(sSubject.Anatomy)
    BstT1File = file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName);
else
    bst_progress('text', 'Loading MRI...');
    % Read MRI
    [BstT1File, sMri] = import_mri(iSubject, T1File);
    if isempty(BstT1File)
        errorMsg = 'Could not import CAT12 folder: MRI was not imported properly';
        if isInteractive
            bst_error(errorMsg, 'Import CAT12 folder', 0);
        end
        return;
    end
    % Enforce it as the permanent default MRI
    sSubject = db_surface_default(iSubject, 'Anatomy', 1, 0);
end


%% ===== DEFINE FIDUCIALS =====
% If fiducials file exist: read it
isComputeMni = 0;
if ~isempty(FidFile)
    % Execute script
    fid = fopen(FidFile, 'rt');
    FidScript = fread(fid, [1 Inf], '*char');
    fclose(fid);
    % Execute script
    eval(FidScript);    
    % If not all the fiducials were loaded: ignore the file
    if ~exist('NAS', 'var') || ~exist('LPA', 'var') || ~exist('RPA', 'var') || isempty(NAS) || isempty(LPA) || isempty(RPA)
        FidFile = [];
    end
    % If the normalized points were not defined: too bad...
    if ~exist('AC', 'var')
        AC = [];
    end
    if ~exist('PC', 'var')
        PC = [];
    end
    if ~exist('IH', 'var')
        IH = [];
    end
    % NOTE THAT THIS FIDUCIALS FILE CAN CONTAIN A LINE: "isComputeMni = 1;"
end
% Random or predefined points
if ~isKeepMri && (~isInteractive || ~isempty(FidFile))
    % Use fiducials from file
    if ~isempty(FidFile)
        % Already loaded
    % Compute them from MNI transformation
    elseif isempty(sFid)
        NAS = [];
        LPA = [];
        RPA = [];
        AC  = [];
        PC  = [];
        IH  = [];
        isComputeMni = 1;
        disp(['BST> Import anatomy: Anatomical fiducials were not defined, using standard MNI positions for NAS/LPA/RPA.' 10]);
    % Else: use the defined ones
    else
        NAS = sFid.NAS;
        LPA = sFid.LPA;
        RPA = sFid.RPA;
        AC = sFid.AC;
        PC = sFid.PC;
        IH = sFid.IH;
        % If the NAS/LPA/RPA are defined, but not the others: Compute them
        if ~isempty(NAS) && ~isempty(LPA) && ~isempty(RPA) && isempty(AC) && isempty(PC) && isempty(IH)
            isComputeMni = 1;
        end
    end
    if ~isempty(NAS) || ~isempty(LPA) || ~isempty(RPA) || ~isempty(AC) || ~isempty(PC) || ~isempty(IH)
        figure_mri('SetSubjectFiducials', iSubject, NAS, LPA, RPA, AC, PC, IH);
    end
% Define with the MRI Viewer
elseif ~isKeepMri
    % MRI Visualization and selection of fiducials (in order to align surfaces/MRI)
    hFig = view_mri(BstT1File, 'EditFiducials');
    drawnow;
    bst_progress('stop');
    % Wait for the MRI Viewer to be closed
    waitfor(hFig);
end
% Load SCS and NCS field to make sure that all the points were defined
sMri = in_mri_bst(BstT1File);
if ~isComputeMni && (~isfield(sMri, 'SCS') || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA) || isempty(sMri.SCS.R))
    errorMsg = ['Could not import CAT12 folder: ' 10 10 'Some fiducial points were not defined properly in the MRI.'];
    if isInteractive
        bst_error(errorMsg, 'Import CAT12 folder', 0);
    end
    return;
end


%% ===== MNI NORMALIZATION =====
% Load y_.mat/iy_.mat (SPM deformation fields for MNI normalization)
if ~isempty(RegFile) && ~isempty(RegInvFile)
    bst_progress('text', 'Loading non-linear MNI transformation...');
    sMri = import_mnireg(sMri, RegFile, RegInvFile, 'cat12');
    % Save modified file
    bst_save(file_fullpath(BstT1File), sMri, 'v7');
% Compute linear MNI registration (spm_maff8)
elseif isComputeMni
    % Call normalize function
    [sMri, errCall] = bst_normalize_mni(BstT1File);
    errorMsg = [errorMsg errCall];
end


%% ===== IMPORT SURFACES =====
% Restore CAT12 icon
bst_plugin('SetProgressLogo', 'cat12');
% === CENTRAL ===
% Left central
if ~isempty(GiiLcFile)
    [TessLcFile, TessLcLowFile, nVertOrigLc, xLcLow, err] = ImportCatSurf(iSubject, GiiLcFile, AnnotLhFiles, GiiLsphFile, nVertHemi, 'left central');
    errorMsg = [errorMsg err];
end
% Right central
if ~isempty(GiiRcFile)
    [TessRcFile, TessRcLowFile, nVertOrigRc, xRcLow, err] = ImportCatSurf(iSubject, GiiRcFile, AnnotRhFiles, GiiRsphFile, nVertHemi, 'right central');
    errorMsg = [errorMsg err];
end
% Cerebellum central
if ~isempty(GiiCcFile)
    [TessCcFile, TessCcLowFile, nVertOrigCc, xCcLow, err] = ImportCatSurf(iSubject, GiiCcFile, [], GiiCsphFile, nVertHemi, 'cerebellum central');
    errorMsg = [errorMsg err];
end
% === PIAL ===
% Left pial
if ~isempty(GiiLpFile)
    [TessLpFile, TessLpLowFile, nVertOrigLp, xLpLow, err] = ImportCatSurf(iSubject, GiiLpFile, AnnotLhFiles, GiiLsphFile, nVertHemi, 'left pial');
    errorMsg = [errorMsg err];
end
% Right pial
if ~isempty(GiiRpFile)
    [TessRpFile, TessRpLowFile, nVertOrigRp, xRpLow, err] = ImportCatSurf(iSubject, GiiRpFile, AnnotRhFiles, GiiRsphFile, nVertHemi, 'right pial');
    errorMsg = [errorMsg err];
end
% Cerebellum pial
if ~isempty(GiiCpFile)
    [TessCpFile, TessCpLowFile, nVertOrigCp, xCpLow, err] = ImportCatSurf(iSubject, GiiCpFile, [], GiiCsphFile, nVertHemi, 'cerebellum pial');
    errorMsg = [errorMsg err];
end
% === WHITE ===
% Left white
if ~isempty(GiiLwFile)
    [TessLwFile, TessLwLowFile, nVertOrigLw, xLwLow, err] = ImportCatSurf(iSubject, GiiLwFile, AnnotLhFiles, GiiLsphFile, nVertHemi, 'left white');
    errorMsg = [errorMsg err];
end
% Right white
if ~isempty(GiiRwFile)
    [TessRwFile, TessRwLowFile, nVertOrigRw, xRwLow, err] = ImportCatSurf(iSubject, GiiRwFile, AnnotRhFiles, GiiRsphFile, nVertHemi, 'right white');
    errorMsg = [errorMsg err];
end
% Cerebellum white
if ~isempty(GiiCwFile)
    [TessCwFile, TessCwLowFile, nVertOrigCw, xCwLow, err] = ImportCatSurf(iSubject, GiiCwFile, [], GiiCsphFile, nVertHemi, 'cerebellum white');
    errorMsg = [errorMsg err];
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


%% ===== MERGE SURFACES =====
% === CENTRAL ===
CentralHiFile = [];
CentralLowFile = [];
CentralCbHiFile = [];
CentralCbLowFile = [];
rmFiles = {};
% Merge hemispheres
if ~isempty(GiiLcFile) && ~isempty(GiiRcFile)
    % Tag: "cortex" if it is the only surface, "mid" if pial and white are present
    if ~isempty(GiiLpFile) && ~isempty(GiiRpFile) && ~isempty(GiiLwFile) && ~isempty(GiiRwFile)
        tagCentral = 'mid';
    else
        tagCentral = 'cortex';
    end
    % Merge left+right+cerebellum
    if ~isempty(GiiCcFile)
        CentralCbHiFile  = tess_concatenate({TessLcFile,    TessRcFile,    TessCcFile},    sprintf([tagCentral '_cereb_%dV'], nVertOrigLc + nVertOrigRc + nVertOrigCc), 'Cortex');
        CentralCbLowFile = tess_concatenate({TessLcLowFile, TessRcLowFile, TessCcLowFile}, sprintf([tagCentral '_cereb_%dV'], length(xLcLow) + length(xRcLow) + length(xCcLow)), 'Cortex');
        rmFiles = cat(2, rmFiles, {TessCcFile, TessCcLowFile});
    end
    % Merge left+right
    CentralHiFile  = tess_concatenate({TessLcFile,    TessRcFile},    sprintf([tagCentral '_%dV'], nVertOrigLc + nVertOrigRc), 'Cortex');
    CentralLowFile = tess_concatenate({TessLcLowFile, TessRcLowFile}, sprintf([tagCentral '_%dV'], length(xLcLow) + length(xRcLow)), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {TessLcFile, TessRcFile, TessLcLowFile, TessRcLowFile});
end

% === PIAL ===
PialHiFile = [];
PialLowFile = [];
PialCbHiFile = [];
PialCbLowFile = [];
% Merge hemispheres
if ~isempty(GiiLpFile) && ~isempty(GiiRpFile)
    % Merge left+right+cerebellum
    if ~isempty(GiiCpFile)
        PialCbHiFile  = tess_concatenate({TessLpFile,    TessRpFile,    TessCpFile},    sprintf('pial_cereb_%dV', nVertOrigLp + nVertOrigRp + nVertOrigCp), 'Cortex');
        PialCbLowFile = tess_concatenate({TessLpLowFile, TessRpLowFile, TessCpLowFile}, sprintf('pial_cereb_%dV', length(xLpLow) + length(xRpLow) + length(xCpLow)), 'Cortex');
        rmFiles = cat(2, rmFiles, {TessCpFile, TessCpLowFile});
    end
    % Merge left+right
    PialHiFile  = tess_concatenate({TessLpFile,    TessRpFile},    sprintf('pial_%dV', nVertOrigLp + nVertOrigRp), 'Cortex');
    PialLowFile = tess_concatenate({TessLpLowFile, TessRpLowFile}, sprintf('pial_%dV', length(xLpLow) + length(xRpLow)), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {TessLpFile, TessRpFile, TessLpLowFile, TessRpLowFile});
end

% === WHITE ===
WhiteHiFile = [];
WhiteLowFile = [];
WhiteCbHiFile = [];
WhiteCbLowFile = [];
% Merge hemispheres
if ~isempty(GiiLwFile) && ~isempty(GiiRwFile)
    % Merge left+right+cerebellum
    if ~isempty(GiiCwFile)
        WhiteCbHiFile  = tess_concatenate({TessLwFile,    TessRwFile,    TessCwFile},    sprintf('white_cereb_%dV', nVertOrigLw + nVertOrigRw + nVertOrigCw), 'Cortex');
        WhiteCbLowFile = tess_concatenate({TessLwLowFile, TessRwLowFile, TessCwLowFile}, sprintf('white_cereb_%dV', length(xLwLow) + length(xRwLow) + length(xCwLow)), 'Cortex');
        rmFiles = cat(2, rmFiles, {TessCwFile, TessCwLowFile});
    end
    % Merge left+right
    WhiteHiFile  = tess_concatenate({TessLwFile,    TessRwFile},    sprintf('white_%dV', nVertOrigLw + nVertOrigRw), 'Cortex');
    WhiteLowFile = tess_concatenate({TessLwLowFile, TessRwLowFile}, sprintf('white_%dV', length(xLwLow) + length(xRwLow)), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {TessLwFile, TessRwFile, TessLwLowFile, TessRwLowFile});
end


%% ===== RE-ORGANIZE FILES =====
% Delete intermediate files
if ~isempty(rmFiles)
    file_delete(file_fullpath(rmFiles), 1);
end
% === CENTRAL ===
% Rename final file: central
if ~isempty(GiiLcFile) && ~isempty(GiiRcFile)
    % Rename high-res file
    oldCentralHiFile = file_fullpath(CentralHiFile);
    CentralHiFile    = bst_fullfile(bst_fileparts(oldCentralHiFile), 'tess_cortex_central_high.mat');
    file_move(oldCentralHiFile, CentralHiFile);
    CentralHiFile = file_short(CentralHiFile);
    % Rename low-res file
    oldCentralLowFile = file_fullpath(CentralLowFile);
    CentralLowFile    = bst_fullfile(bst_fileparts(oldCentralLowFile), 'tess_cortex_central_low.mat');
    file_move(oldCentralLowFile, CentralLowFile);
    CentralHiFile = file_short(CentralHiFile);
end
% Rename final file: central + cerebellum
if ~isempty(GiiCcFile) && ~isempty(GiiLcFile) && ~isempty(GiiRcFile)
    % Rename high-res file
    oldCentralCbHiFile = file_fullpath(CentralCbHiFile);
    CentralCbHiFile    = bst_fullfile(bst_fileparts(oldCentralCbHiFile), 'tess_cortex_cereb_central_high.mat');
    file_move(oldCentralCbHiFile, CentralCbHiFile);
    CentralCbHiFile = file_short(CentralCbHiFile);
    % Rename low-res file
    oldCentralCbLowFile = file_fullpath(CentralCbLowFile);
    CentralCbLowFile    = bst_fullfile(bst_fileparts(oldCentralCbLowFile), 'tess_cortex_cereb_central_low.mat');
    file_move(oldCentralCbLowFile, CentralCbLowFile);
    CentralCbHiFile = file_short(CentralCbHiFile);
end
% === PIAL ===
% Rename final file: pial
if ~isempty(GiiLpFile) && ~isempty(GiiRpFile)
    % Rename high-res file
    oldPialHiFile = file_fullpath(PialHiFile);
    PialHiFile    = bst_fullfile(bst_fileparts(oldPialHiFile), 'tess_cortex_pial_high.mat');
    file_move(oldPialHiFile, PialHiFile);
    PialHiFile = file_short(PialHiFile);
    % Rename low-res file
    oldPialLowFile = file_fullpath(PialLowFile);
    PialLowFile    = bst_fullfile(bst_fileparts(oldPialLowFile), 'tess_cortex_pial_low.mat');
    file_move(oldPialLowFile, PialLowFile);
    PialHiFile = file_short(PialHiFile);
end
% Rename final file: pial + cerebellum
if ~isempty(GiiCpFile) && ~isempty(GiiLpFile) && ~isempty(GiiRpFile)
    % Rename high-res file
    oldPialCbHiFile = file_fullpath(PialCbHiFile);
    PialCbHiFile    = bst_fullfile(bst_fileparts(oldPialCbHiFile), 'tess_cortex_cereb_pial_high.mat');
    file_move(oldPialCbHiFile, PialCbHiFile);
    PialCbHiFile = file_short(PialCbHiFile);
    % Rename low-res file
    oldPialCbLowFile = file_fullpath(PialCbLowFile);
    PialCbLowFile    = bst_fullfile(bst_fileparts(oldPialCbLowFile), 'tess_cortex_cereb_pial_low.mat');
    file_move(oldPialCbLowFile, PialCbLowFile);
    PialCbHiFile = file_short(PialCbHiFile);
end
% === WHITE ===
% Rename final file: white
if ~isempty(GiiLwFile) && ~isempty(GiiRwFile)
    % Rename high-res file
    oldWhiteHiFile = file_fullpath(WhiteHiFile);
    WhiteHiFile    = bst_fullfile(bst_fileparts(oldWhiteHiFile), 'tess_cortex_white_high.mat');
    file_move(oldWhiteHiFile, WhiteHiFile);
    WhiteHiFile = file_short(WhiteHiFile);
    % Rename low-res file
    oldWhiteLowFile = file_fullpath(WhiteLowFile);
    WhiteLowFile    = bst_fullfile(bst_fileparts(oldWhiteLowFile), 'tess_cortex_white_low.mat');
    file_move(oldWhiteLowFile, WhiteLowFile);
    WhiteHiFile = file_short(WhiteHiFile);
end
% Rename final file: white + cerebellum
if ~isempty(GiiCwFile) && ~isempty(GiiLwFile) && ~isempty(GiiRwFile)
    % Rename high-res file
    oldWhiteCbHiFile = file_fullpath(WhiteCbHiFile);
    WhiteCbHiFile    = bst_fullfile(bst_fileparts(oldWhiteCbHiFile), 'tess_cortex_cereb_white_high.mat');
    file_move(oldWhiteCbHiFile, WhiteCbHiFile);
    WhiteCbHiFile = file_short(WhiteCbHiFile);
    % Rename low-res file
    oldWhiteCbLowFile = file_fullpath(WhiteCbLowFile);
    WhiteCbLowFile    = bst_fullfile(bst_fileparts(oldWhiteCbLowFile), 'tess_cortex_cereb_white_low.mat');
    file_move(oldWhiteCbLowFile, WhiteCbLowFile);
    WhiteCbHiFile = file_short(WhiteCbHiFile);
end

% Reload subject
db_reload_subjects(iSubject);


%% ===== GENERATE HEAD =====
% Generate head surface
HeadFile = tess_isohead(iSubject, 10000, 0, 2);


%% ===== IMPORT VOLUME ATLASES =====
if isVolumeAtlas && ~isempty(VolAtlasFiles)
    % Get subject tag
    [fPath, SubjectTag] = bst_fileparts(T1File{1});
    % Import all the volumes
    for iFile = 1:length(VolAtlasFiles)
        % Strip the subject tag from the atlas name
        [fPath, AtlasName] = bst_fileparts(VolAtlasFiles{iFile});
        AtlasName = strrep(AtlasName, ['_' SubjectTag], '');
        % Import volume (attached csv labels read with mri_getlabels.m from import_mri.m)
        import_mri(iSubject, VolAtlasFiles{iFile}, 'ALL-ATLAS', 0, 1, AtlasName);
    end
end

%% ===== IMPORT THICKNESS MAPS =====
if isExtraMaps && ~isempty(CentralHiFile)
    % Create a condition "CAT12"
    iStudy = db_add_condition(iSubject, 'CAT12');
    % Import cortical thickness
    if ~isempty(ThickLhFile) && ~isempty(ThickLhFile)
        import_sources(iStudy, CentralHiFile, ThickLhFile, ThickRhFile, 'FS', 'thickness');
    end
    % Import gyrification
    if ~isempty(GyriLhFile) && ~isempty(GyriRhFile)
        import_sources(iStudy, CentralHiFile, GyriLhFile, GyriRhFile, 'FS', 'gyrification');
    end
    % Import sulcal depth
    if ~isempty(SulcalLhFile) && ~isempty(SulcalRhFile)
        import_sources(iStudy, CentralHiFile, SulcalLhFile, SulcalRhFile, 'FS', 'depth');
    end
    % Import cortex complexity
    if ~isempty(FDLhFile) && ~isempty(FDRhFile)
        import_sources(iStudy, CentralHiFile, FDLhFile, FDRhFile, 'FS', 'fractaldimension');
    end
end


%% ===== IMPORT TISSUE LABELS =====
if isVolumeAtlas && ~isempty(TpmFiles)
    bst_progress('start', 'Import CAT12 folder', 'Importing tissue probability maps...');
    import_mri(iSubject, TpmFiles, 'SPM-TPM', 0, 1, 'tissues_cat12');
end


%% ===== UPDATE GUI =====
% Set default cortex
if ~isempty(GiiLcFile) && ~isempty(GiiRcFile)
    [sSubject, iSubject, iSurface] = bst_get('SurfaceFile', CentralLowFile);
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
    if ~isempty(CentralLowFile)
        view_surface(CentralLowFile);
    end
    % Set orientation
    figure_3d('SetStandardView', hFig, 'left');
end
% Close progress bar
bst_plugin('SetProgressLogo', []);
if ~isProgress
    bst_progress('stop');
end


end



%% ===== IMPORT SURFACE+ATLASES =====
function [TessFile, TessLowFile, nVert, xLow, errorMsg] = ImportCatSurf(iSubject, GiiFile, AnnotFiles, SphFile, nVertHemi, Comment)
    errorMsg = '';
    % Import file
    [iVert, TessFile, nVert] = import_surfaces(iSubject, GiiFile, 'GII-WORLD', 0);
    TessFile = TessFile{1};
    % Load atlases
    if ~isempty(AnnotFiles)
        bst_progress('start', 'Import CAT12 folder', ['Loading atlases: ' Comment '...']);
        [sAllAtlas, err] = import_label(TessFile, AnnotFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load sphere
    if ~isempty(SphFile)
        bst_progress('start', 'Import CAT12 folder', ['Loading registered sphere: ' Comment '...']);
        [TessMat, err] = tess_addsphere(TessFile, SphFile, 'GII-CAT');
        errorMsg = [errorMsg err];
    end
    % Downsample
    bst_progress('start', 'Import CAT12 folder', ['Downsampling: ' Comment '...']);
    [TessLowFile, iLow, xLow] = tess_downsize(TessFile, nVertHemi, 'reducepatch');
end

