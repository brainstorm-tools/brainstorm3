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
AnnotLhFiles = file_find(CatDir, 'lh.*.annot', 2, 0);
AnnotRhFiles = file_find(CatDir, 'rh.*.annot', 2, 0);

% Find tissue probability maps
if isVolumeAtlas
    TpmFiles = {file_find(CatDir, 'p2*.nii', 2), ...  % White matter
                file_find(CatDir, 'p1*.nii', 2), ...  % Gray matter
                file_find(CatDir, 'p3*.nii', 2), ...  % CSF
                file_find(CatDir, 'p4*.nii', 2), ...  % Skull
                file_find(CatDir, 'p5*.nii', 2), ...  % Scalp
                file_find(CatDir, 'p6*.nii', 2)};     % Background
    VolAtlasFiles = file_find(bst_fullfile(CatDir, 'mri_atlas'), '*.nii', 1, 0);
end
% % Find MNI registration volumes
% RegFile = file_find(CatDir, 'y_*.nii', 2);
% RegInvFile = file_find(CatDir, 'iy_*.nii', 2);

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
% % Load y_.mat/iy_.mat (SPM deformation fields for MNI normalization)
% if ~isempty(RegFile) && ~isempty(RegInvFile)
%     bst_progress('text', 'Loading non-linear MNI transformation...');
%     sMri = import_mnireg(sMri, RegFile, RegInvFile, 'cat12');
%     % Save modified file
%     bst_save(file_fullpath(BstT1File), sMri, 'v7');
% Compute linear MNI registration (spm_maff8)
if isComputeMni
    % Call normalize function
    [sMri, errCall] = bst_normalize_mni(BstT1File);
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


%% ===== IMPORT VOLUME ATLASES =====
if isVolumeAtlas && ~isempty(VolAtlasFiles)
    % Get subject tag
    [fPath, SubjectTag] = bst_fileparts(T1File{1});
    % Import all the volumes
    for iFile = 1:length(VolAtlasFiles)
        % Strip the subject tag from the atlas name
        [fPath, AtlasName] = bst_fileparts(VolAtlasFiles{iFile});
        AtlasName = strrep(AtlasName, ['_' SubjectTag], '');
        % Get the labels
        switch (AtlasName)
            case 'aal3',               Labels = mri_getlabels_cat12_aal3();                % AAL3 - Automated Anatomical Labeling (Tzourio-Mazoyer 2002)
            case 'anatomy3',           Labels = mri_getlabels_cat12_anatomy3();
            case 'cobra',              Labels = mri_getlabels_cat12_cobra();
            case 'hammers',            Labels = mri_getlabels_cat12_hammers();             % HAMMERS - Hammersmith atlas (Hammers 2003, Gousias 2008, Faillenot 2017, Wild 2017)
            case 'ibsr',               Labels = mri_getlabels_cat12_ibsr();
            case 'julichbrain',        Labels = mri_getlabels_cat12_julichbrain();         % Julich-Brain 2.0
            case 'lpba40',             Labels = mri_getlabels_cat12_lpba40();              % LONI lpba40
            case 'mori',               Labels = mri_getlabels_cat12_mori();                % Mori 2009
            case 'neuromorphometrics', Labels = mri_getlabels_cat12_neuromorphometrics();  % MICCAI 2012 Multi-Atlas Labeling Workshop and Challenge (Neuromorphometrics)
            case 'Schaefer2018_100Parcels_17Networks_order', Labels = mri_getlabels_cat12_schaefer17_100();
            case 'Schaefer2018_200Parcels_17Networks_order', Labels = mri_getlabels_cat12_schaefer17_200();
            case 'Schaefer2018_400Parcels_17Networks_order', Labels = mri_getlabels_cat12_schaefer17_400();
            case 'Schaefer2018_600Parcels_17Networks_order', Labels = mri_getlabels_cat12_schaefer17_600();
            otherwise,                 Labels = [];
        end
        % Import volume
        import_mri(iSubject, VolAtlasFiles{iFile}, 'ALL-ATLAS', 0, 1, AtlasName, Labels);
    end
end

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
if isVolumeAtlas && ~isempty(TpmFiles)
    bst_progress('start', 'Import CAT12 folder', 'Importing tissue probability maps...');
    import_mri(iSubject, TpmFiles, 'SPM-TPM', 0, 1, 'tissues_cat12');
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



