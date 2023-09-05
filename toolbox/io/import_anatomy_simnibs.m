function [errorMsg, FemFile] = import_anatomy_simnibs(iSubject, SimDir, nVertices, isInteractive, sFid, isExtraMaps, isKeepMri)
% IMPORT_ANATOMY_SIMNIBS: Import a full SimNIBS folder as the subject's anatomy.
%
% USAGE:  [errorMsg, FemFile] = import_anatomy_simnibs(iSubject, SimDir=[], nVertices=15000, isInteractive=1, sFid=[], isExtraMaps=0, isKeepMri=0)
%
% INPUT:
%    - iSubject     : Indice of the subject where to import the MRI
%                     If iSubject=0 : import MRI in default subject
%    - SimDir       : Full filename of the SimNIBS folder to import (must contain one and only one .nii file in the root)
%    - nVertices    : Number of vertices in the file cortex surface (for the CAT12 import)
%    - isInteractive: If 0, no input or user interaction
%    - sFid         : Structure with the fiducials coordinates
%                     Or full MRI structure with fiducials defined in the SCS structure, to be registered with the MRI
%    - isExtraMaps  : If 1, create an extra folder "CAT12" to save the thickness maps (SimNIBS3 only) and import default EEG caps (SimNIBS3 and 4)
%    - isKeepMri    : 0=Delete all existing anatomy files
%                     1=Keep existing MRI volumes (when running segmentation from Brainstorm)
%                     2=Keep existing MRI and surfaces
% OUTPUT:
%    - errorMsg : String: error message if an error occurs
%    - FemFile  : Output FEM mesh filename

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
% Authors: Francois Tadel, 2022-2023


%% ===== PARSE INPUTS =====
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
FemFile = [];
% Ask folder to the user
if (nargin < 2) || isempty(SimDir)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Open file selection dialog
    SimDir = java_getfile( 'open', ...
        'Import SimNIBS folder...', ...     % Window title
        bst_fileparts(LastUsedDirs.ImportAnat, 1), ...           % Last used directory
        'single', 'dirs', ...                  % Selection mode
        {{'.folder'}, 'SimNIBS folder', 'SimDir'}, 0);
    % If no folder was selected: exit
    if isempty(SimDir)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = SimDir;
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
            'Are you sure you want to delete the previous MRI and surfaces ?' 10 10], 'Import SimNIBS folder');
    else
        isDel = 1;
    end
    % If user canceled process
    if ~isDel
        return;
    end
    % Delete anatomy
    sSubject = db_delete_anatomy(iSubject, isKeepMri);
end


%% ===== ASK NB VERTICES =====
if isempty(nVertices)
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import SimNIBS folder', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
end
% Number for each hemisphere
nVertHemi = round(nVertices / 2);


%% ===== PARSE SIMNIBS FOLDER =====
isProgress = bst_progress('isVisible');
bst_progress('start', 'Import SimNIBS folder', 'Parsing folder...');
% Find final mesh
MshFile = file_find(SimDir, '*.msh', 2, 0);
if isempty(MshFile) || isempty(MshFile{1})
    errorMsg = [errorMsg 'Mesh file *.msh not found in top folder.' 10];
elseif (length(MshFile) > 1)
    errorMsg = [errorMsg 'Multiple *.msh found in top folder.' 10];
else
    MshFile = MshFile{1};
    SimDir = bst_fileparts(MshFile);
end
% Find T1 MRI
T1Nii = file_find(SimDir, '*T1.nii*', 0, 0);
if isempty(T1Nii)
    T1Nii = file_find(SimDir, '*T1fs_conform.nii.gz', 0, 0);    % SimNIBS3/headreco
    if isempty(T1Nii)
        errorMsg = [errorMsg 'Original MRI file was not found: *T1.nii or *T1fs_conform.nii.gz in top folder.' 10];
    elseif (length(T1Nii) > 1)
        errorMsg = [errorMsg 'Multiple *_T1fs_conform.nii.gz found in top folder.' 10];
    end
elseif (length(T1Nii) > 1)
    errorMsg = [errorMsg 'Multiple *T1.nii found in top folder.' 10];
end
if ~isempty(T1Nii)
    T1Nii = T1Nii{1};
end
% Find T2 MRI
T2Nii = file_find(SimDir, '*T2.nii*', 0, 1);
if isempty(T2Nii)
    T2Nii = file_find(SimDir, '*T2_conform.nii.gz', 0, 1);    % SimNIBS3/headreco
    if isempty(T2Nii)
        T2Nii = file_find(SimDir, '*T2_reg.nii.gz', 0, 1);    % SimNIBS4/charm
    end
end
% Find labelled tissues volume
TissuesNii = file_find(SimDir, '*final_contr.nii.gz', 1, 1);    % SimNIBS3/headreco
if isempty(TissuesNii)
    TissuesNii = file_find(SimDir, '*final_tissues.nii.gz', 1, 1);    % SimNIBS4/charm
    Version = 'simnibs4';
else
    Version = 'simnibs3';
end
% Find cortical segmentation
SegNii = file_find(SimDir, 'labeling.nii.gz', 2, 1);    % SimNIBS4/charm
% Find cortex surfaces  (SimNIBS4/charm)
TessLhFile = file_find(SimDir, 'lh.pial.gii', 2, 1);
TessRhFile = file_find(SimDir, 'rh.pial.gii', 2, 1);
TessLcFile = file_find(SimDir, 'lh.central.gii', 2, 1);
TessRcFile = file_find(SimDir, 'rh.central.gii', 2, 1);
TessLsphFile = file_find(SimDir, 'lh.sphere.reg.gii', 2, 1);
TessRsphFile = file_find(SimDir, 'rh.sphere.reg.gii', 2, 1);
% Report errors
if ~isempty(errorMsg)
    if isInteractive
        bst_error(['Could not import SimNIBS folder: ' 10 10 errorMsg], 'Import SimNIBS folder', 0);        
    end
    return;
end
% Get subject id from msh file
[fPath, subjid] = bst_fileparts(MshFile);


%% ===== IMPORT T1 MRI =====
if isKeepMri && ~isempty(sSubject.Anatomy)
    T1File = file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName);
else
    bst_progress('start', 'Import SimNIBS folder', 'Importing T1 mri...');
    % Read T1 MRI
    [T1File, sMriT1] = import_mri(iSubject, T1Nii, [], 0, 1, 'T1');
    if isempty(T1File)
        errorMsg = 'Could not import SimNIBS folder: MRI was not imported properly';
        if isInteractive
            bst_error(errorMsg, 'Import SimNIBS folder', 0);
        end
        return;
    end
end


%% ===== DEFINE FIDUCIALS / MNI NORMALIZATION =====
% Set fiducials and/or compute linear MNI normalization
[isComputeMni, errCall] = process_import_anatomy('SetFiducials', iSubject, SimDir, T1File, sFid, isKeepMri, isInteractive);
% Error handling
if ~isempty(errCall)
    errorMsg = [errorMsg, errCall];
    if isempty(isComputeMni)
        if isInteractive
            bst_error(errorMsg, 'Import SimNIBS folder', 0);
        end
        return;
    end
end


%% ===== IMPORT OTHER VOLUMES =====
bst_progress('start', 'Import SimNIBS folder', 'Importing other volumes...');
% Read T2 MRI
if ~isKeepMri && ~isempty(T2Nii)
    [T2File, sMriT2] = import_mri(iSubject, T2Nii, 'ALL', 0, 1, 'T2');
end
% Read tissues labels
if ~isempty(TissuesNii)
    TissuesFile = import_mri(iSubject, TissuesNii, 'ALL-ATLAS', 0, 1, 'tissues');
end
% Read cortical segmentation
if ~isempty(SegNii)
    SegFile = import_mri(iSubject, SegNii, 'ALL-ATLAS', 0, 1, 'segmentation');
end


%% ===== IMPORT FEM MESH =====
bst_progress('start', 'Import SimNIBS folder', 'Importing FEM mesh...');
% Reload updated T1
sMriT1 = in_mri_bst(T1File);
% Import FEM mesh
FemMat = in_tess(MshFile, upper(Version), sMriT1); %  this could be loaded to bst as it is
FemMat.Comment = sprintf('FEM %dV (simnibs, %d layers)', length(FemMat.Vertices), length(FemMat.TissueLabels));
% Save to database
FemFile = file_unique(bst_fullfile(bst_fileparts(T1File), sprintf('tess_fem_simnibs_%dV.mat', length(FemMat.Vertices))));
bst_save(FemFile, FemMat, 'v7');
db_add_surface(iSubject, FemFile, FemMat.Comment);


%% ===== IMPORT SURFACES ======
% Left pial
if ~isempty(TessLhFile)
    % Import file
    [iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, TessLhFile, 'GII-WORLD', 0);
    BstTessLhFile = BstTessLhFile{1};
    % Load sphere
    if ~isempty(TessLsphFile)
        bst_progress('start', 'Import SimNIBS folder', 'Loading registered sphere: left pial...');
        [TessMat, err] = tess_addsphere(BstTessLhFile, TessLsphFile, 'GII-CAT', 0);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end
    % Downsample
    bst_progress('start', 'Import SimNIBS folder', 'Downsampling: left pial...');
    [BstTessLhLowFile, iLhLow, xLhLow] = tess_downsize(BstTessLhFile, nVertHemi, 'reducepatch');
end
% Right pial
if ~isempty(TessRhFile)
    % Import file
    [iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, TessRhFile, 'GII-WORLD', 0);
    BstTessRhFile = BstTessRhFile{1};
    % Load sphere
    if ~isempty(TessRsphFile)
        bst_progress('start', 'Import SimNIBS folder', 'Loading registered sphere: right pial...');
        [TessMat, err] = tess_addsphere(BstTessRhFile, TessRsphFile, 'GII-CAT', 0);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end
    % Downsample
    bst_progress('start', 'Import SimNIBS folder', 'Downsampling: right pial...');
    [BstTessRhLowFile, iRhLow, xRhLow] = tess_downsize(BstTessRhFile, nVertHemi, 'reducepatch');
end
% Left central
if ~isempty(TessLcFile)
    % Import file
    [iLc, BstTessLcFile, nVertOrigLc] = import_surfaces(iSubject, TessLcFile, 'GII-WORLD', 0);
    BstTessLcFile = BstTessLcFile{1};
    % Load sphere
    if ~isempty(TessLsphFile)
        bst_progress('start', 'Import SimNIBS folder', 'Loading registered sphere: left central...');
        [TessMat, err] = tess_addsphere(BstTessLcFile, TessLsphFile, 'GII-CAT', 0);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end
    % Downsample
    bst_progress('start', 'Import SimNIBS folder', 'Downsampling: left central...');
    [BstTessLcLowFile, iLcLow, xLcLow] = tess_downsize(BstTessLcFile, nVertHemi, 'reducepatch');
else
    BstTessLcFile = [];
end
% Right central
if ~isempty(TessRcFile)
    % Import file
    [iRc, BstTessRcFile, nVertOrigRc] = import_surfaces(iSubject, TessRcFile, 'GII-WORLD', 0);
    BstTessRcFile = BstTessRcFile{1};
    % Load sphere
    if ~isempty(TessRsphFile)
        bst_progress('start', 'Import SimNIBS folder', 'Loading registered sphere: right central...');
        [TessMat, err] = tess_addsphere(BstTessRcFile, TessRsphFile, 'GII-CAT', 0);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end
    % Downsample
    bst_progress('start', 'Import SimNIBS folder', 'Downsampling: right central...');
    [BstTessRcLowFile, iRcLow, xRcLow] = tess_downsize(BstTessRcFile, nVertHemi, 'reducepatch');
else
    BstTessRcFile = [];
end


%% ===== MERGE SURFACES =====
rmFiles = {};
% Merge hemispheres: pial
if ~isempty(TessLhFile) && ~isempty(TessRhFile)
    % Hi-resolution surface
    CortexHiFile  = tess_concatenate({BstTessLhFile,    BstTessRhFile},    sprintf('cortex_%dV', nVertOrigL + nVertOrigR), 'Cortex');
    CortexLowFile = tess_concatenate({BstTessLhLowFile, BstTessRhLowFile}, sprintf('cortex_%dV', length(xLhLow) + length(xRhLow)), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {BstTessLhFile, BstTessRhFile, BstTessLhLowFile, BstTessRhLowFile});
    % Rename high-res file
    oldCortexHiFile = file_fullpath(CortexHiFile);
    CortexHiFile    = bst_fullfile(bst_fileparts(oldCortexHiFile), 'tess_cortex_pial_high.mat');
    file_move(oldCortexHiFile, CortexHiFile);
    CortexHiFile = file_short(CortexHiFile);
    % Rename high-res file
    oldCortexLowFile = file_fullpath(CortexLowFile);
    CortexLowFile    = bst_fullfile(bst_fileparts(oldCortexLowFile), 'tess_cortex_pial_low.mat');
    file_move(oldCortexLowFile, CortexLowFile);
    CortexLowFile = file_short(CortexLowFile);
else
    CortexHiFile = [];
    CortexLowFile = [];
end
% Merge hemispheres: central surface
if ~isempty(BstTessLcFile) && ~isempty(BstTessRcFile)
    % Hi-resolution surface
    MidHiFile  = tess_concatenate({BstTessLcFile,    BstTessRcFile},    sprintf('mid_%dV', nVertOrigLc + nVertOrigRc), 'Cortex');
    MidLowFile = tess_concatenate({BstTessLcLowFile, BstTessRcLowFile}, sprintf('mid_%dV', length(xLcLow) + length(xRcLow)), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {BstTessLcFile, BstTessRcFile, BstTessLcLowFile, BstTessRcLowFile});
    % Rename high-res file
    oldMidHiFile = file_fullpath(MidHiFile);
    MidHiFile    = bst_fullfile(bst_fileparts(oldMidHiFile), 'tess_cortex_mid_high.mat');
    file_move(oldMidHiFile, MidHiFile);
    MidHiFile = file_short(MidHiFile);
    % Rename high-res file
    oldMidLowFile = file_fullpath(MidLowFile);
    MidLowFile    = bst_fullfile(bst_fileparts(oldMidLowFile), 'tess_cortex_mid_low.mat');
    file_move(oldMidLowFile, MidLowFile);
    MidLowFile = file_short(MidLowFile);
else
    MidHiFile = [];
    MidLowFile = [];
end


%% ===== DELETE INTERMEDIATE FILES =====
if ~isempty(rmFiles)
    % Delete files
    file_delete(file_fullpath(rmFiles), 1);
    % Reload subject
    db_reload_subjects(iSubject);
end


%% ===== EXTRACT THE FEM CORTEX SURFACE =====
bst_progress('start', 'Import SimNIBS folder', 'Saving cortex envelope...');
% Create a surface for the outside surface of this tissue
cortexElem = FemMat.Elements(FemMat.Tissue <= 2, :);
cortexFaces = tess_voledge(FemMat.Vertices, cortexElem);
% Remove all the unused vertices
cortexVertices = FemMat.Vertices;
iRemoveVert = setdiff((1:size(cortexVertices,1))', unique(cortexFaces(:)));
if ~isempty(iRemoveVert)
    [cortexVertices, cortexFaces] = tess_remove_vert(cortexVertices, cortexFaces, iRemoveVert);
end
% Remove small elements
[cortexVertices, cortexFaces] = tess_remove_small(cortexVertices, cortexFaces);
% New surface structure
NewTess = db_template('surfacemat');
NewTess.Comment  = 'cortex_fem';
NewTess.Vertices = cortexVertices;
NewTess.Faces    = cortexFaces;
% History: File name
NewTess = bst_history('add', NewTess, 'create', 'Cortex extracted from SimNIBS FEM model');
% Produce a default surface filename &   Make this filename unique
CortexFile = file_unique(bst_fullfile(bst_fileparts(T1File), ...
                sprintf('tess_cortex_simnibs_%dV.mat', length(NewTess.Vertices))));
% Save new surface in Brainstorm format
bst_save(CortexFile, NewTess, 'v7'); 
db_add_surface(iSubject, CortexFile, NewTess.Comment);


%% ===== IMPORT CAT12 OUTPUT =====
if strcmpi(Version, 'simnibs3')
    CatDir = bst_fullfile(SimDir, ['m2m_' subjid], 'segment', 'cat');
    if isdir(CatDir)
        % Import CAT12 folder
        catErrMsg = import_anatomy_cat(iSubject, CatDir, nVertices, isInteractive, sFid, isExtraMaps, 2, 0);
        % Error handling
        if ~isempty(catErrMsg)
            if isInteractive
                bst_error(catErrMsg, 'Import SimNIBS folder', 0);
            else
                warning(['Could not import CAT12 segmentation: ' 10 catErrMsg]);
            end
        end
    else
        warning(['CAT12 segmentation not found in SimNIBS folder: ' 10 CatDir]);
    end
end


%% ===== GENERATE HEAD =====
if strcmpi(Version, 'simnibs4')
    HeadFile = tess_isohead(iSubject, 10000, 0, 2);
end


%% ===== IMPORT 10-10 POSITIONS =====
% List EEG position files
dirPos = dir(bst_fullfile(SimDir, 'eeg_positions', '*.csv'));
% If any and if not using a default channel file or default anatomy
if isExtraMaps && ~isempty(dirPos) && (iSubject > 0) && ~sSubject.UseDefaultChannel
    % Create one folder for each channel file
    for iFile = 1:length(dirPos)
        % Skip fiducials
        if strcmpi(dirPos(iFile).name, 'Fiducials.csv')
            continue;
        end
        % Create a new folder
        [~, folderName] = bst_fileparts(dirPos(iFile).name);
        iStudy = db_add_condition(iSubject, folderName);
        % Import channel file
        PosFile = bst_fullfile(SimDir, 'eeg_positions', dirPos(iFile).name);
        import_channel(iStudy, PosFile, 'SIMNIBS', 2);
    end
end


%% ===== UPDATE GUI =====
% Set default cortex
if ~isempty(MidLowFile)
    [sSubject, iSubject, iSurface] = bst_get('SurfaceFile', MidLowFile);
    db_surface_default(iSubject, 'Cortex', iSurface);
end
% Update subject node
panel_protocols('UpdateNode', 'Subject', iSubject);
panel_protocols('SelectNode', [], 'subject', iSubject, -1 );
% Save database
db_save();
% Close progress bar
if ~isProgress
    bst_progress('stop');
end
