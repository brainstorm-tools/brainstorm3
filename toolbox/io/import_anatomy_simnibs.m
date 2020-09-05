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
%    - isExtraMaps  : If 1, create an extra folder "CAT12" to save the thickness maps
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
% Authors: Francois Tadel, 2020


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


%% ===== PARSE SIMNIBS FOLDER =====
isProgress = bst_progress('isVisible');
bst_progress('start', 'Import SimNIBS folder', 'Parsing folder...');
% Find T1 MRI
T1Nii = file_find(SimDir, '*T1.nii', 1, 0);
if isempty(T1Nii)
    T1Nii = file_find(SimDir, '*_T1fs_conform.nii.gz', 1, 0);
    if isempty(T1Nii)
        errorMsg = [errorMsg 'Original MRI file was not found: *T1.nii or *_T1fs_conform.nii.gz in top folder.' 10];
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
T2Nii = file_find(SimDir, '*T2.nii', 1, 1);
if isempty(T2Nii)
    T2Nii = file_find(SimDir, '*_T2fs_conform.nii.gz', 1, 1);
end
% Find Masks MRI
MaskNii = file_find(SimDir, '*_final_contr.nii.gz', 2, 1);
% Find final mesh
MshFile = file_find(SimDir, '*.msh', 1, 0);
if isempty(MshFile) || isempty(MshFile{1})
    errorMsg = [errorMsg 'Mesh file *.msh found in top folder.' 10];
elseif (length(MshFile) > 1)
    errorMsg = [errorMsg 'Multiple *.msh found in top folder.' 10];
else
    MshFile = MshFile{1};
end
% Report errors
if ~isempty(errorMsg)
    if isInteractive
        bst_error(['Could not import SimNIBS folder: ' 10 10 errorMsg], 'Import SimNIBS folder', 0);        
    end
    return;
end
% Get subject id from msh file
[fPath, subjid] = bst_fileparts(MshFile);
% Find fiducials definitions
FidFile = file_find(SimDir, 'fiducials.m');


%% ===== IMPORT T1 MRI =====
if isKeepMri && ~isempty(sSubject.Anatomy)
    T1File = file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName);
else
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
    hFig = view_mri(T1File, 'EditFiducials');
    drawnow;
    bst_progress('stop');
    % Wait for the MRI Viewer to be closed
    waitfor(hFig);
end
% Load SCS and NCS field to make sure that all the points were defined
sMriT1 = in_mri_bst(T1File);
if ~isComputeMni && (~isfield(sMriT1, 'SCS') || isempty(sMriT1.SCS) || isempty(sMriT1.SCS.NAS) || isempty(sMriT1.SCS.LPA) || isempty(sMriT1.SCS.RPA) || isempty(sMriT1.SCS.R))
    errorMsg = ['Could not import SimNIBS folder: ' 10 10 'Some fiducial points were not defined properly in the MRI.'];
    if isInteractive
        bst_error(errorMsg, 'Import SimNIBS folder', 0);
    end
    return;
end

%% ===== MNI NORMALIZATION =====
if isComputeMni
    % Call normalize function
    [sMriT1, errCall] = bst_normalize_mni(T1File);
    % Error handling
    if ~isempty(errCall)
        if isInteractive
            bst_error(errorMsg, 'Import SimNIBS folder', 0);
        end
        return;
    end
end

%% ===== IMPORT OTHER VOLUMES =====
% Read T2 MRI
if ~isKeepMri && ~isempty(T2Nii)
    [T2File, sMriT2] = import_mri(iSubject, T2Nii, [], 0, 1, 'T2');
end
% Read masks
if ~isempty(MaskNii)
    MaskFile = import_mri(iSubject, MaskNii, [], 0, 1, 'tissues');
end


%% ===== IMPORT FEM MESH =====
bst_progress('start', 'Import SimNIBS folder', 'Importing FEM mesh...');
% Import FEM mesh
FemMat = in_tess(MshFile, 'SIMNIBS', sMriT1); %  this could be loaded to bst as it is
FemMat.Comment = sprintf('FEM %dV (simnibs, %d layers)', length(FemMat.Vertices), length(FemMat.TissueLabels));
% Save to database
FemFile = file_unique(bst_fullfile(bst_fileparts(T1File), sprintf('tess_fem_simnibs_%dV.mat', length(FemMat.Vertices))));
bst_save(FemFile, FemMat, 'v7');
db_add_surface(iSubject, FemFile, FemMat.Comment);


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


%% ===== IMPORT 10-10 POSITIONS =====
PosFile = bst_fullfile(SimDir, ['m2m_' subjid], 'eeg_positions', 'EEG10-10_UI_Jurak_2007.csv');
if file_exist(PosFile)
    % Create a condition "eeg_positions"
    iStudy = db_add_condition(iSubject, 'eeg_positions');
    % Import channel file
    import_channel(iStudy, PosFile, 'SIMNIBS', 2);
end
            

%% ===== UPDATE GUI =====
% Update subject node
panel_protocols('UpdateNode', 'Subject', iSubject);
panel_protocols('SelectNode', [], 'subject', iSubject, -1 );
% Save database
db_save();
% Close progress bar
if ~isProgress
    bst_progress('stop');
end



