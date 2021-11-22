function errorMsg = import_anatomy_bs(iSubject, BsDir, nVertices, isInteractive, sFid, isVolumeAtlas, isKeepMri)
% IMPORT_ANATOMY_BS: Import a full BrainSuite folder as the subject's anatomy.
%
% USAGE:  errorMsg = import_anatomy_bs(iSubject, BsDir=[ask], nVertices=[ask], isInteractive=1, sFid=[], isVolumeAtlas=1, isKeepMri=0)
%
% INPUT:
%    - iSubject      : Indice of the subject where to import the MRI
%                      If iSubject=0 : import MRI in default subject
%    - BsDir         : Full filename of the BrainSuite folder to import
%    - nVertices     : Number of vertices in the file cortex surface
%    - isInteractive : If 0, no input or user interaction
%    - sFid          : Structure with the fiducials coordinates
%    - isVolumeAtlas : If 1, imports the svreg atlas as a set of surfaces
%    - isKeepMri     : 0=Delete all existing anatomy files
%                      1=Keep existing MRI volumes (when running segmentation from Brainstorm)
%                      2=Keep existing MRI and surfaces
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
% Author   : Francois Tadel, 2012-2021
% Modified : Andrew Krause, 2013

%% ===== PARSE INPUTS =====
% Keep MRI
if (nargin < 7) || isempty(isKeepMri)
    isKeepMri = 0;
end
% Import volume atlas
if (nargin < 6) || isempty(isVolumeAtlas)
    isVolumeAtlas = 1;
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
% Initialize returned variables
errorMsg = [];
% Ask folder to the user
if (nargin < 2) || isempty(BsDir)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Open file selection dialog
    BsDir = java_getfile( 'open', ...
        'Import BrainSuite folder...', ...     % Window title
        bst_fileparts(LastUsedDirs.ImportAnat, 1), ...           % Last used directory
        'single', 'dirs', ...                  % Selection mode
        {{'.folder'}, 'BrainSuite folder', 'BsDir'}, 0);
    % If no folder was selected: exit
    if isempty(BsDir)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = BsDir;
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
            'Are you sure you want to delete the previous MRI and surfaces ?' 10 10], 'Import BrainSuite folder');
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
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import BrainSuite folder', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
end
% Number for each hemisphere
nVertHemi = round(nVertices / 2);


%% ===== PARSE BRAINSUITE FOLDER =====
% Find MRI
FilePrefix = get_fileprefix(BsDir);
if isempty(FilePrefix)
    errorMsg = [errorMsg 'Could not determine file prefix from BFC file' 10 10 ...
        'Make sure SVREG was executed in BrainSuite before importing the data in Brainstorm.'];
    if isInteractive
        bst_error(['Could not import BrainSuite folder: ' 10 10 errorMsg], 'Import BrainSuite folder', 0);        
    end
    return;
end
T1File = {file_find(BsDir, [FilePrefix '.nii.gz']), ...
           file_find(BsDir, [FilePrefix '.nii']), ...
           file_find(BsDir, [FilePrefix '.img.gz']),...
           file_find(BsDir, [FilePrefix '.img'])};
T1File = [T1File{find(~cellfun(@isempty, T1File))}];
if isempty(T1File)
    errorMsg = [errorMsg 'MRI file was not found: ' FilePrefix '.*' 10];
end

% Find volume segmentation file
BsDirMultiParc = fullfile(BsDir,'multiparc');

SvregFile = file_find(BsDir, [FilePrefix '.svreg.label.nii.gz']);
OtherSvregFiles = file_find(BsDirMultiParc, [FilePrefix '.svreg.*.label.nii.gz'], 2, 0);

% Find surfaces
HeadFile        = file_find(BsDir, [FilePrefix '.scalp.dfs']);
InnerSkullFile  = file_find(BsDir, [FilePrefix '.inner_skull.dfs']);
OuterSkullFile  = file_find(BsDir, [FilePrefix '.outer_skull.dfs']);
TessLhFile      = file_find(BsDir, [FilePrefix '.left.pial.cortex.svreg.dfs']);
TessRhFile      = file_find(BsDir, [FilePrefix '.right.pial.cortex.svreg.dfs']);
TessLwFile      = file_find(BsDir, [FilePrefix '.left.inner.cortex.svreg.dfs']);
TessRwFile      = file_find(BsDir, [FilePrefix '.right.inner.cortex.svreg.dfs']);
TessLsphFile    = file_find(BsDir, [FilePrefix '.left.mid.cortex.svreg.dfs']);
TessRsphFile    = file_find(BsDir, [FilePrefix '.right.mid.cortex.svreg.dfs']);
TessLAtlsphFile = file_find(BsDir, 'atlas.left.mid.cortex.svreg.dfs');
TessRAtlsphFile = file_find(BsDir, 'atlas.right.mid.cortex.svreg.dfs');

% Find labels
AnnotLhFiles = file_find(BsDirMultiParc, [FilePrefix '.left.mid.cortex.svreg.*.dfs'], 2, 0);
AnnotRhFiles = file_find(BsDirMultiParc, [FilePrefix '.right.mid.cortex.svreg.*.dfs'], 2, 0);

if isempty(AnnotLhFiles)
    AnnotLhFiles = TessLhFile;
end

if isempty(AnnotRhFiles)
    AnnotRhFiles = TessRhFile;
end

if isempty(HeadFile)
    %errorMsg = [errorMsg 'Scalp file was not found: ' FilePrefix '.scalp.dfs' 10];
    disp(['BST> Warning: Scalp file was not found: ' FilePrefix '.scalp.dfs']);
end
if isempty(InnerSkullFile) && isempty(OuterSkullFile)
    %errorMsg = [errorMsg 'Inner or Outer Skull File not found' 10];
    disp('BST> Warning: Inner or Outer Skull File not found.');
end
if isempty(TessLhFile) 
    errorMsg = [errorMsg 'Surface file was not found: ' FilePrefix '.left.pial.cortex.svreg.dfs' 10];
end
if isempty(TessRhFile)
    errorMsg = [errorMsg 'Surface file was not found: ' FilePrefix '.right.pial.cortex.svreg.dfs' 10];
end
% Find fiducials definitions
FidFile = file_find(BsDir, 'fiducials.m');

% Report errors
if ~isempty(errorMsg)
    if isInteractive
        bst_error(['Could not import BrainSuite folder: ' 10 10 errorMsg], 'Import BrainSuite folder', 0);        
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
        errorMsg = 'Could not import BrainSuite folder: MRI was not imported properly';
        if isInteractive
            bst_error(errorMsg, 'Import BrainSuite folder', 0);
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
    % Open MRI Viewer for the user to select NAS/LPA/RPA fiducials
    hFig = view_mri(BstT1File, 'EditFiducials');
    drawnow;
    bst_progress('stop');
    % Wait for the MRI Viewer to be closed
    waitfor(hFig);
end
% Load SCS and NCS field to make sure that all the points were defined
warning('off','MATLAB:load:variableNotFound');
sMri = load(BstT1File, 'SCS', 'NCS');
warning('on','MATLAB:load:variableNotFound');
if ~isComputeMni && (~isfield(sMri, 'SCS') || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA) || isempty(sMri.SCS.R))
    errorMsg = ['Could not import BrainSuite folder: ' 10 10 'Some fiducial points were not defined properly in the MRI.'];
    if isInteractive
        bst_error(errorMsg, 'Import BrainSuite folder', 0);
    end
    return;
end


%% ===== MNI NORMALIZATION =====
if isComputeMni
    % Call normalize function
    [sMri, errCall] = bst_normalize_mni(BstT1File);
    % Error handling
    errorMsg = [errorMsg errCall];
end


%% ===== IMPORT SURFACES =====
% Left pial
if ~isempty(TessLhFile)
    % Import file
    [iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, TessLhFile, 'DFS', 0);
    BstTessLhFile = BstTessLhFile{1};
    % Load atlas
    if ~isempty(AnnotLhFiles)
        bst_progress('start', 'Import BrainSuite folder', 'Loading atlas: left pial...');
        [sAllAtlas, err] = import_label(BstTessLhFile, AnnotLhFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load registration square
    if ~isempty(TessLsphFile)
        bst_progress('start', 'Import BrainSuite folder', 'Loading registered square: left pial...');
        [TessMat, err] = tess_addsquare(BstTessLhFile, TessLsphFile, TessLAtlsphFile);
        errorMsg = [errorMsg err];
    end    
    % Downsample
    bst_progress('start', 'Import BrainSuite folder', 'Downsampling: left pial...');
    [BstTessLhLowFile, iLhLow, xLhLow] = tess_downsize(BstTessLhFile, nVertHemi, 'reducepatch');
end
% Right pial
if ~isempty(TessRhFile)
    % Import file
    [iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, TessRhFile, 'DFS', 0);
    BstTessRhFile = BstTessRhFile{1};
    % Load atlas
    if ~isempty(AnnotRhFiles)
        bst_progress('start', 'Import BrainSuite folder', 'Loading atlas: right pial...');
        [sAllAtlas, err] = import_label(BstTessRhFile, AnnotRhFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load registration square
    if ~isempty(TessRsphFile)
        bst_progress('start', 'Import BrainSuite folder', 'Loading registered square: right pial...');
        [TessMat, err] = tess_addsquare(BstTessRhFile, TessRsphFile, TessRAtlsphFile);
        errorMsg = [errorMsg err];
    end
    % Downsample
    bst_progress('start', 'Import BrainSuite folder', 'Downsampling: right pial...');
    [BstTessRhLowFile, iRhLow, xRhLow] = tess_downsize(BstTessRhFile, nVertHemi, 'reducepatch');
end
% Left white matter
if ~isempty(TessLwFile)
    % Import file
    [iLw, BstTessLwFile] = import_surfaces(iSubject, TessLwFile, 'DFS', 0);
    BstTessLwFile = BstTessLwFile{1};
    % Load atlas
    if ~isempty(AnnotLhFiles)
        bst_progress('start', 'Import BrainSuite folder', 'Loading atlas: left white...');
        [sAllAtlas, err] = import_label(BstTessLwFile, AnnotLhFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load registration square
    if ~isempty(TessLsphFile)
        bst_progress('start', 'Import BrainSuite folder', 'Loading registered square: left white...');
        [TessMat, err] = tess_addsquare(BstTessLwFile, TessLsphFile, TessLAtlsphFile);
        errorMsg = [errorMsg err];
    end
    % Downsample
    bst_progress('start', 'Import BrainSuite folder', 'Downsampling: left white...');
    [BstTessLwLowFile, iLwLow] = tess_downsize(BstTessLwFile, nVertHemi, 'reducepatch');
end
% Right white matter
if ~isempty(TessRwFile)
    % Import file
    [iRw, BstTessRwFile] = import_surfaces(iSubject, TessRwFile, 'DFS', 0);
    BstTessRwFile = BstTessRwFile{1};
     % Load atlas
    if ~isempty(AnnotRhFiles)
        bst_progress('start', 'Import BrainSuite folder', 'Loading atlas: right inner...');
        [sAllAtlas, err] = import_label(BstTessRwFile, AnnotRhFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Load registration square
    if ~isempty(TessRsphFile)
        bst_progress('start', 'Import BrainSuite folder', 'Loading registered square: right white...');
        [TessMat, err] = tess_addsquare(BstTessRwFile, TessRsphFile, TessRAtlsphFile);
        errorMsg = [errorMsg err];
    end
    % Downsample
    bst_progress('start', 'Import BrainSuite folder', 'Downsampling: right white...');
    [BstTessRwLowFile, iRwLow] = tess_downsize(BstTessRwFile, nVertHemi, 'reducepatch');
end
% Process error messages
if ~isempty(errorMsg)
    if isInteractive
        bst_error(errorMsg, 'Import BrainSuite folder', 0);
    end
    return;
end

%% ===== MERGE SURFACES =====
rmFiles = {};
rmInd   = [];
% Merge hemispheres: pial
if ~isempty(TessLhFile) && ~isempty(TessRhFile)
    % Hi-resolution surface
    CortexHiFile  = tess_concatenate({BstTessLhFile,    BstTessRhFile},    sprintf('cortex_%dV', nVertOrigL + nVertOrigR), 'Cortex');
    CortexLowFile = tess_concatenate({BstTessLhLowFile, BstTessRhLowFile}, sprintf('cortex_%dV', nVertices), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {BstTessLhFile, BstTessRhFile, BstTessLhLowFile, BstTessRhLowFile});
    rmInd   = [rmInd, iLh, iRh, iLhLow, iRhLow];
end
% Merge hemispheres: white
if ~isempty(TessLwFile) && ~isempty(TessRwFile)
    % Hi-resolution surface
    WhiteHiFile  = tess_concatenate({BstTessLwFile,    BstTessRwFile},    sprintf('white_%dV', nVertOrigL + nVertOrigR), 'Cortex');
    WhiteLowFile = tess_concatenate({BstTessLwLowFile, BstTessRwLowFile}, sprintf('white_%dV', nVertices), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {BstTessLwFile, BstTessRwFile, BstTessLwLowFile, BstTessRwLowFile});
    rmInd   = [rmInd, iLw, iRw, iLwLow, iRwLow];
end

%% ===== HEAD AND SKULL SURFACES =====
bst_progress('start', 'Import BrainSuite folder', 'Importing scalp and skull surfaces...');
% Head
if ~isempty(HeadFile)
    % Import file
    bst_progress('start', 'Import BrainSuite folder', 'Imported scalp surface...');
    [iHead, BstHeadHiFile] = import_surfaces(iSubject, HeadFile, 'DFS', 0);
    BstHeadHiFile = BstHeadHiFile{1};
    % Downsample
    bst_progress('start', 'Import BrainSuite folder', 'Downsampling: scalp...');
    BstHeadFile = tess_downsize( BstHeadHiFile, 1082, 'reducepatch' );
    % Load MRI
    bst_progress('start', 'Import BrainSuite folder', 'Filling holes in the head surface...');
    sMri = in_mri_bst(BstT1File);
    % Load head surface
    sHead = in_tess_bst(BstHeadFile);
    % Remove holes
    [sHead.Vertices, sHead.Faces] = tess_fillholes(sMri, sHead.Vertices, sHead.Faces, 2, 2);
    % Save back to file
    sHeadNew.Vertices = sHead.Vertices;
    sHeadNew.Faces = sHead.Faces;
    sHeadNew.Comment = sHead.Comment;
    bst_save(file_fullpath(BstHeadFile), sHeadNew, 'v7');
    % Delete initial file
    rmFiles = cat(2, rmFiles, BstHeadHiFile);
    rmInd   = [rmInd, iHead];
% Or generate one from Brainstorm
else
    % Generate head surface
    BstHeadFile = tess_isohead(iSubject, 10000, 0, 2);
end

% Inner Skull
if ~isempty(InnerSkullFile)
    % Import file
    [iIs, BstInnerSkullHiFile] = import_surfaces(iSubject, InnerSkullFile, 'DFS', 0);
    BstInnerSkullHiFile = BstInnerSkullHiFile{1};
    % Downsample
    bst_progress('start', 'Import BrainSuite folder', 'Downsampling: inner skull...');
    BstInnerSkullFile = tess_downsize(BstInnerSkullHiFile, 1000, 'reducepatch');
    % Delete initial file
    rmFiles = cat(2, rmFiles, BstInnerSkullHiFile);
    rmInd   = [rmInd, iIs];
end
if ~isempty(OuterSkullFile)
    % Import file
    [iOs, BstOuterSkullHiFile] = import_surfaces(iSubject, OuterSkullFile, 'DFS', 0);
    BstOuterSkullHiFile = BstOuterSkullHiFile{1};
    % Downsample
    bst_progress('start', 'Import BrainSuite folder', 'Downsampling: outer skull...');
    BstOuterSkullFile = tess_downsize(BstOuterSkullHiFile, 1000, 'reducepatch');
    % Delete initial file
    rmFiles = cat(2, rmFiles, BstOuterSkullHiFile);
    rmInd   = [rmInd, iOs];
end


% Delete intermediary files
if ~isempty(rmFiles)
    % Delete files
    file_delete(file_fullpath(rmFiles), 1);
    % Update subject definition
    sSubject = bst_get('Subject', iSubject);
    sSubject.Surface(rmInd) = [];
    bst_set('Subject', iSubject, sSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'subject', iSubject, -1 );
end

%% ===== IMPORT SVREG ATLAS =====
if isVolumeAtlas && ~isempty(SvregFile)
    % Import atlas as volume
    [BstSvregFile, sMriSvreg] = import_mri(iSubject, SvregFile, 'ALL-ATLAS', 0, 1, 'svreg');
    % Import other label volumes
    for iFile = 1:length(OtherSvregFiles)
        st=strfind(OtherSvregFiles{iFile},'.svreg.');
        ed=strfind(OtherSvregFiles{iFile},'.label.nii.gz');
        AtlasName = OtherSvregFiles{iFile}(st+7:ed-1);
        import_mri(iSubject, OtherSvregFiles{iFile}, 'ALL-ATLAS', 0, 1, AtlasName);
    end
    % Import atlas
    SelLabels = {...
        'Accumbens L', 'Hippocampus L', 'Pallidum L', 'Putamen L', 'Thalamus L', ...
        'Accumbens R', 'Hippocampus R', 'Pallidum R', 'Putamen R', 'Thalamus R', ...
        'Brainstem', 'Cerebellum'};
    [iSvreg, BstSvregFile] = import_surfaces(iSubject, SvregFile, 'MRI-MASK', 0, [], SelLabels, 'subcortical');
    % Extract cerebellum only
    try
        BstCerebFile = tess_extract_struct(BstSvregFile{1}, {'Cerebellum'}, 'svreg | cerebellum');
    catch
        BstCerebFile = [];
    end
    % If the cerebellum surface can be reconstructed
    if ~isempty(BstCerebFile)
        % Downsample cerebllum
        [BstCerebLowFile, iCerLow, xCerLow] = tess_downsize(BstCerebFile, 2000, 'reducepatch');
        % Merge with low-resolution pial
        BstMixedLowFile = tess_concatenate({CortexLowFile, BstCerebLowFile}, sprintf('cortex_cereb_%dV', length(xLhLow) + length(xRhLow) + length(xCerLow)), 'Cortex');
        % Rename mixed file
        oldBstMixedLowFile = file_fullpath(BstMixedLowFile);
        BstMixedLowFile    = bst_fullfile(bst_fileparts(oldBstMixedLowFile), 'tess_cortex_pialcereb_low.mat');
        file_move(oldBstMixedLowFile, BstMixedLowFile);
        % Delete intermediate files
        file_delete({file_fullpath(BstCerebFile), file_fullpath(BstCerebLowFile)}, 1);
        db_reload_subjects(iSubject);
    end
end


%% ===== UPDATE GUI =====
% Set default cortex
if ~isempty(TessLhFile) && ~isempty(TessRhFile)
    [sSubject, iSubject, iSurface] = bst_get('SurfaceFile', CortexLowFile);
    db_surface_default(iSubject, 'Cortex', iSurface);
end
% Set default scalp
db_surface_default(iSubject, 'Scalp');
% Set default skulls
db_surface_default(iSubject, 'OuterSkull');
db_surface_default(iSubject, 'InnerSkull');
% Update subject node
panel_protocols('UpdateNode', 'Subject', iSubject);
% Save database
db_save();
% Unload everything
bst_memory('UnloadAll', 'Forced');
% Give a graphical output for user validation
if isInteractive
    % Display the downsampled cortex and the head
    hFig = view_surface(BstHeadFile);
    view_surface(CortexLowFile);
    % Set orientation
    figure_3d('SetStandardView', hFig, 'left');
end
% Close progress bar
bst_progress('stop');

end



%% ======================================================================================
%  ===== HELPER FUNCTIONS ===============================================================
%  ======================================================================================
%% ===== GET PREFIX OF FILENAMES =====
function FilePrefix = get_fileprefix(BsDir)
    % Determine file prefix based on left cortex file
    TestFile = file_find(BsDir, '*.left.pial.cortex.svreg.dfs');
    if ~isempty(TestFile)
        [tmp, FilePrefix] = bst_fileparts(TestFile(1:end-27));
    else
        FilePrefix = [];
    end
end
