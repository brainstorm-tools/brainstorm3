function errorMsg = import_anatomy_cat_2020(iSubject, CatDir, nVertices, isInteractive, sFid, isExtraMaps, isKeepMri, isTissues)
% IMPORT_ANATOMY_CAT_2020: Import a full CAT12 folder as the subject's anatomy (Version >= CAT12.7-RC2)
%
% USAGE:  errorMsg = import_anatomy_cat_2020(iSubject, CatDir=[], nVertices=15000, isInteractive=1, sFid=[], isExtraMaps=0, isKeepMri=0, isTissues=1)
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
%    - isTissues     : If 1, combine the tissue probability maps (/mri/p*.nii) into a "tissue" volume
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
% Authors: Francois Tadel, 2019-2020

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
MriFile = file_find(CatDir, '*.nii', 1, 0);
if isempty(MriFile)
    errorMsg = [errorMsg 'Original MRI file was not found: *.nii in top folder' 10];
elseif (length(MriFile) > 1)
    errorMsg = [errorMsg 'Multiple .nii found in top folder' 10];
end
% Find surfaces
TessLhFile = file_find(CatDir, 'lh.central.*.gii', 2);
TessRhFile = file_find(CatDir, 'rh.central.*.gii', 2);
TessCbFile = file_find(CatDir, 'cb.central.*.gii', 2);
TessLsphFile = file_find(CatDir, 'lh.sphere.reg.*.gii', 2);
TessRsphFile = file_find(CatDir, 'rh.sphere.reg.*.gii', 2);
TessCsphFile = file_find(CatDir, 'cb.sphere.reg.*.gii', 2);
if isempty(TessLhFile)
    errorMsg = [errorMsg 'Surface file was not found: lh.central' 10];
end
if isempty(TessRhFile)
    errorMsg = [errorMsg 'Surface file was not found: rh.central' 10];
end
% Find atlases
AnnotLhFiles = {...
    file_find(CatDir, 'lh.aparc_a2009s.freesurfer*.annot', 2), ...
    file_find(CatDir, 'lh.aparc_DK40.freesurfer*.annot', 2), ...
    file_find(CatDir, 'lh.aparc_HCP_MMP1.freesurfer*.annot', 2), ...
    file_find(CatDir, 'lh.Schaefer2018_100Parcels_17Networks_order*.annot', 2), ...
    file_find(CatDir, 'lh.Schaefer2018_200Parcels_17Networks_order*.annot', 2), ...
    file_find(CatDir, 'lh.Schaefer2018_400Parcels_17Networks_order*.annot', 2), ...
    file_find(CatDir, 'lh.Schaefer2018_600Parcels_17Networks_order*.annot', 2)};
AnnotRhFiles = {...
    file_find(CatDir, 'rh.aparc_a2009s.freesurfer*.annot', 2), ...
    file_find(CatDir, 'rh.aparc_DK40.freesurfer*.annot', 2), ...
    file_find(CatDir, 'rh.aparc_HCP_MMP1.freesurfer*.annot', 2), ...
    file_find(CatDir, 'rh.Schaefer2018_100Parcels_17Networks_order*.annot', 2), ...
    file_find(CatDir, 'rh.Schaefer2018_200Parcels_17Networks_order*.annot', 2), ...
    file_find(CatDir, 'rh.Schaefer2018_400Parcels_17Networks_order*.annot', 2), ...
    file_find(CatDir, 'rh.Schaefer2018_600Parcels_17Networks_order*.annot', 2)};
AnnotLhFiles(cellfun(@isempty, AnnotLhFiles)) = [];
AnnotRhFiles(cellfun(@isempty, AnnotRhFiles)) = [];

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
sMri = in_mri_bst(BstMriFile);
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
    % Load atlases
    if ~isempty(AnnotLhFiles)
        bst_progress('start', 'Import CAT12 folder', 'Loading atlases: left pial...');
        [sAllAtlas, err] = import_label(BstTessLhFile, AnnotLhFiles, 1);
        errorMsg = [errorMsg err];
    end
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
    % Load atlases
    if ~isempty(AnnotRhFiles)
        bst_progress('start', 'Import CAT12 folder', 'Loading atlases: right pial...');
        [sAllAtlas, err] = import_label(BstTessRhFile, AnnotRhFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load sphere
    if ~isempty(TessRsphFile)
        bst_progress('start', 'Import CAT12 folder', 'Loading registered sphere: right pial...');
        [TessMat, err] = tess_addsphere(BstTessRhFile, TessRsphFile, 'GII-CAT');
        errorMsg = [errorMsg err];
    end
end
% Cerebellum
if ~isempty(TessCbFile)
    % Import file
    [iCb, BstTessCbFile, nVertOrigC] = import_surfaces(iSubject, TessCbFile, 'GII-WORLD', 0);
    BstTessCbFile = BstTessCbFile{1};
    % Load sphere
    if ~isempty(TessCsphFile)
        bst_progress('start', 'Import CAT12 folder', 'Loading registered sphere: cerebellum...');
        [TessMat, err] = tess_addsphere(BstTessCbFile, TessCsphFile, 'GII-CAT');
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
if ~isempty(TessCbFile)
    bst_progress('start', 'Import CAT12 folder', 'Downsampling: cerebellum...');
    [BstTessCbLowFile, iCbLow, xCbLow] = tess_downsize(BstTessCbFile, nVertHemi, 'reducepatch');
end


%% ===== MERGE SURFACES =====
CortexHiFile = [];
CortexLowFile = [];
CortexCbHiFile = [];
CortexCbLowFile = [];
rmFiles = {};
% Merge hemispheres
if ~isempty(TessLhFile) && ~isempty(TessRhFile)
    % Merge left+right+cerebellum
    if ~isempty(TessCbFile)
        CortexCbHiFile  = tess_concatenate({BstTessLhFile,    BstTessRhFile,    BstTessCbFile},    sprintf('cortex_cereb_%dV', nVertOrigL + nVertOrigR + nVertOrigC), 'Cortex');
        CortexCbLowFile = tess_concatenate({BstTessLhLowFile, BstTessRhLowFile, BstTessCbLowFile}, sprintf('cortex_cereb_%dV', length(xLhLow) + length(xRhLow) + length(xCbLow)), 'Cortex');
        rmFiles = cat(2, rmFiles, {BstTessCbFile, BstTessCbLowFile});
    end
    % Merge left+right
    CortexHiFile  = tess_concatenate({BstTessLhFile,    BstTessRhFile},    sprintf('cortex_%dV', nVertOrigL + nVertOrigR), 'Cortex');
    CortexLowFile = tess_concatenate({BstTessLhLowFile, BstTessRhLowFile}, sprintf('cortex_%dV', length(xLhLow) + length(xRhLow)), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {BstTessLhFile, BstTessRhFile, BstTessLhLowFile, BstTessRhLowFile});
end


%% ===== RE-ORGANIZE FILES =====
% Delete intermediate files
if ~isempty(rmFiles)
    file_delete(file_fullpath(rmFiles), 1);
end
% Rename final file: cortex
if ~isempty(TessLhFile) && ~isempty(TessRhFile)
    % Rename high-res file
    oldCortexHiFile = file_fullpath(CortexHiFile);
    CortexHiFile    = bst_fullfile(bst_fileparts(oldCortexHiFile), 'tess_cortex_pial_high.mat');
    file_move(oldCortexHiFile, CortexHiFile);
    CortexHiFile = file_short(CortexHiFile);
    % Rename low-res file
    oldCortexLowFile = file_fullpath(CortexLowFile);
    CortexLowFile    = bst_fullfile(bst_fileparts(oldCortexLowFile), 'tess_cortex_pial_low.mat');
    file_move(oldCortexLowFile, CortexLowFile);
    CortexHiFile = file_short(CortexHiFile);
end
% Rename final file: cortex + cerebellum
if ~isempty(TessCbFile) && ~isempty(TessLhFile) && ~isempty(TessRhFile)
    % Rename high-res file
    oldCortexCbHiFile = file_fullpath(CortexCbHiFile);
    CortexCbHiFile    = bst_fullfile(bst_fileparts(oldCortexCbHiFile), 'tess_cortex_cereb_pial_high.mat');
    file_move(oldCortexCbHiFile, CortexCbHiFile);
    CortexCbHiFile = file_short(CortexCbHiFile);
    % Rename low-res file
    oldCortexCbLowFile = file_fullpath(CortexCbLowFile);
    CortexCbLowFile    = bst_fullfile(bst_fileparts(oldCortexCbLowFile), 'tess_cortex_cereb_pial_low.mat');
    file_move(oldCortexCbLowFile, CortexCbLowFile);
    CortexCbHiFile = file_short(CortexCbHiFile);
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
    if ~isempty(ThickLhFile) && ~isempty(ThickLhFile)
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
        sMriProb = in_mri_nii(TpmFiles{iTissue});
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
        TissueFile = file_unique(strrep(file_fullpath(BstMriFile), '.mat', '_tissues.mat'));
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
if ~isProgress
    bst_progress('stop');
end



