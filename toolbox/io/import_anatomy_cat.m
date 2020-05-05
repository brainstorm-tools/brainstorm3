function errorMsg = import_anatomy_cat(iSubject, CatDir, nVertices, isInteractive, sFid, isExtraMaps, isKeepMri)
% IMPORT_ANATOMY_CAT: Import a full CAT12 folder as the subject's anatomy.
%
% USAGE:  errorMsg = import_anatomy_cat(iSubject, CatDir=[], nVertices=15000, isInteractive=1, sFid=[], isExtraMaps=0, isKeepMri=0)
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
% Authors: Francois Tadel, 2019

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
MriFile = file_find(CatDir, '*.nii', 1, 0);
if isempty(MriFile)
    errorMsg = [errorMsg 'Original MRI file was not found: *.nii in top folder' 10];
elseif (length(MriFile) > 1)
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

% Find FSAverage surfaces in CAT12 program folder
CatExeDir = bst_fullfile(bst_get('SpmDir'), 'toolbox', 'cat12');
FsAvgLhFile = bst_fullfile(CatExeDir, 'templates_surfaces', 'lh.central.freesurfer.gii');
FsAvgRhFile = bst_fullfile(CatExeDir, 'templates_surfaces', 'rh.central.freesurfer.gii');
Fs32kLhFile = bst_fullfile(CatExeDir, 'templates_surfaces_32k', 'lh.central.freesurfer.gii');
Fs32kRhFile = bst_fullfile(CatExeDir, 'templates_surfaces_32k', 'rh.central.freesurfer.gii');
% Find FSAverage spheres in CAT12 program folder
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

% Find thickness maps
if isExtraMaps
    ThickLhFile = file_find(CatDir, 'lh.thickness.*', 2);
    ThickRhFile = file_find(CatDir, 'rh.thickness.*', 2);
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
    BstMriFile = file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName);
else
    % Read MRI
    [BstMriFile, sMri] = import_mri(iSubject, MriFile);
    if isempty(BstMriFile)
        errorMsg = 'Could not import CAT12 folder: MRI was not imported properly';
        if isInteractive
            bst_error(errorMsg, 'Import CAT12 folder', 0);
        end
        return;
    end
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
if ~isInteractive || ~isempty(FidFile)
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
        warning('BST> Import anatomy: Anatomical fiducials were not defined, using standard MNI positions for NAS/LPA/RPA.');
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
    hFig = view_mri(BstMriFile, 'EditFiducials');
    drawnow;
    bst_progress('stop');
    % Wait for the MRI Viewer to be closed
    waitfor(hFig);
end
% Load SCS and NCS field to make sure that all the points were defined
warning('off','MATLAB:load:variableNotFound');
sMri = load(BstMriFile, 'SCS', 'NCS');
warning('on','MATLAB:load:variableNotFound');
if ~isComputeMni && (~isfield(sMri, 'SCS') || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA) || isempty(sMri.SCS.R))
    errorMsg = ['Could not import CAT12 folder: ' 10 10 'Some fiducial points were not defined properly in the MRI.'];
    if isInteractive
        bst_error(errorMsg, 'Import CAT12 folder', 0);
    end
    return;
end

%% ===== MNI NORMALIZATION =====
if isComputeMni
    % Call normalize function
    [sMri, errCall] = bst_normalize_mni(BstMriFile);
    % Error handling
    errorMsg = [errorMsg errCall];
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

% Left FSAverage
if ~isempty(FsAvgLhFile)
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
% Right FSAverage
if ~isempty(FsAvgRhFile)
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

% Left FSAverage 32k
if ~isempty(Fs32kLhFile)
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
% Right FSAverage 32k
if ~isempty(Fs32kRhFile)
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
if isExtraMaps && ~isempty(CortexHiFile) && ~isempty(ThickLhFile) && ~isempty(ThickLhFile)
    % Create a condition "CAT12"
    iStudy = db_add_condition(iSubject, 'CAT12');
    % Import cortical thickness
    ThickFile = import_sources(iStudy, CortexHiFile, ThickLhFile, ThickRhFile, 'FS');
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
if ~isProgress
    bst_progress('stop');
end



