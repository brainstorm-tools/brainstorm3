function errorMsg = import_anatomy_bv(iSubject, BvDir, nVertices, isInteractive, sFid)
% IMPORT_ANATOMY_BV: Import a full BrainVISA folder as the subject's anatomy.
%
% USAGE:  errorMsg = import_anatomy_bv(iSubject, BvDir=[], nVertices=15000, isInteractive=1)
%
% INPUT:
%    - iSubject  : Indice of the subject where to import the MRI
%                  If iSubject=0 : import MRI in default subject
%    - BvDir     : Full filename of the BrainVISA folder to import
%    - nVertices : Number of vertices in the file cortex surface
%    - isInteractive: If 0, no input or user interaction
%    - sFid      : Structure with the fiducials coordinates
% OUTPUT:
%    - errorMsg : String: error message if an error occurs

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2019

%% ===== PARSE INPUTS =====
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
if (nargin < 2) || isempty(BvDir)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Open file selection dialog
    BvDir = java_getfile( 'open', ...
        'Import BrainVISA folder...', ...     % Window title
        bst_fileparts(LastUsedDirs.ImportAnat, 1), ...           % Last used directory
        'single', 'dirs', ...                  % Selection mode
        {{'.folder'}, 'BrainVISA folder', 'BvDir'}, 0);
    % If no folder was selected: exit
    if isempty(BvDir)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = BvDir;
    bst_set('LastUsedDirs', LastUsedDirs);
end
% Unload everything
bst_memory('UnloadAll', 'Forced');


%% ===== DELETE PREVIOUS ANATOMY =====
% Get subject definition
sSubject = bst_get('Subject', iSubject);
% Check for existing anatomy
if ~isempty(sSubject.Anatomy) || ~isempty(sSubject.Surface)
    % Ask user whether the previous anatomy should be removed
    if isInteractive
        isDel = java_dialog('confirm', ['Warning: There is already an anatomy defined for this subject.' 10 10 ...
            'Are you sure you want to delete the previous MRI and surfaces ?' 10 10], 'Import BrainVISA folder');
    else
        isDel = 1;
    end
    % If user canceled process
    if ~isDel
        bst_progress('stop');
        return;
    end
    % Delete anatomy
    sSubject = db_delete_anatomy(iSubject);
end


%% ===== ASK NB VERTICES =====
if isempty(nVertices)
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import BrainVISA folder', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
end
% Number for each hemisphere
nVertHemi = round(nVertices / 2);


%% ===== PARSE BRAINVISA FOLDER =====
bst_progress('start', 'Import BrainVISA folder', 'Parsing folder...');
% Find MRI
MriFile = {file_find(BvDir, 'nobias_*.nii'), file_find(BvDir, 'nobias_*.nii.gz'), file_find(BvDir, 'nobias_*.ima')};
MriFile(cellfun(@isempty, MriFile)) = [];
if isempty(MriFile)
    errorMsg = [errorMsg 'MRI file was not found: nobias_*.*' 10];
end
% Find surfaces
HeadFile   = {file_find(BvDir, '*head*.mesh'), file_find(BvDir, '*head*.gii')};
TessLhFile = {file_find(BvDir, '*Lhemi*.mesh'), file_find(BvDir, '*Lhemi*.gii')};
TessRhFile = {file_find(BvDir, '*Rhemi*.mesh'), file_find(BvDir, '*Rhemi*.gii')};
TessLwFile = {file_find(BvDir, '*Lwhite*.mesh'), file_find(BvDir, '*Lwhite.gii')};
TessRwFile = {file_find(BvDir, '*Rwhite*.mesh'), file_find(BvDir, '*Rwhite.gii')};
% Find non-empty search results
HeadFile(cellfun(@isempty, HeadFile)) = [];
TessLhFile(cellfun(@isempty, TessLhFile)) = [];
TessRhFile(cellfun(@isempty, TessRhFile)) = [];
TessLwFile(cellfun(@isempty, TessLwFile)) = [];
TessRwFile(cellfun(@isempty, TessRwFile)) = [];
if isempty(TessLhFile) || isempty(TessRhFile)
    errorMsg = [errorMsg 'Surface file was not found: Lhemi or Rhemi' 10];
end
% Find labels
AnnotLwFiles = {file_find(BvDir, '*_Lwhite_parcels_marsAtlas.gii'), ...
                file_find(BvDir, '*_Lwhite_parcels_model.gii'), ...
                file_find(BvDir, '*_Lwhite_pole_cingular.gii'), ...
                file_find(BvDir, '*_Lwhite_pole_insula.gii'), ...
                file_find(BvDir, '*_Lwhite_sulcalines.gii')};
AnnotRwFiles = {file_find(BvDir, '*_Rwhite_parcels_marsAtlas.gii'), ...
                file_find(BvDir, '*_Rwhite_parcels_model.gii'), ...
                file_find(BvDir, '*_Rwhite_pole_cingular.gii'), ...
                file_find(BvDir, '*_Rwhite_pole_insula.gii'), ...
                file_find(BvDir, '*_Rwhite_sulcalines.gii')};
AnnotLwFiles(cellfun(@isempty, AnnotLwFiles)) = [];
AnnotRwFiles(cellfun(@isempty, AnnotRwFiles)) = [];
% Find fiducials definitions
FidFile = file_find(BvDir, 'fiducials.m');
% Find AC-PC file
ApcFile = file_find(BvDir, '*.APC');
bst_progress('stop');
% Report errors
if ~isempty(errorMsg)
    if isInteractive
        bst_error(['Could not import BrainVISA folder: ' 10 10 errorMsg], 'Import BrainVISA folder', 0);  
    end
    return;
end
% Keep only the first files
MriFile    = MriFile{1};
HeadFile   = HeadFile{1};
TessLhFile = TessLhFile{1};
TessRhFile = TessRhFile{1};
if ~isempty(TessLwFile)
    TessLwFile = TessLwFile{1};
end
if ~isempty(TessRwFile)
    TessRwFile = TessRwFile{1};
end


%% ===== IMPORT MRI =====
% Read MRI
[BstMriFile, sMri] = import_mri(iSubject, MriFile);
if isempty(BstMriFile)
    errorMsg = 'Could not import BrainVISA folder: MRI was not imported properly';
    if isInteractive
        bst_error(errorMsg, 'Import BrainVISA folder', 0);
    end
    return;
end
% Size of the volume
cubeSize = (size(sMri.Cube) - 1) .* sMri.Voxsize;


%% ===== READ AC-PC FILE =====
bst_progress('start', 'Import BrainVISA folder', 'Reading AC/PC positions...');
AC = [];
PC = [];
IH = [];
if ~isempty(ApcFile)
    % Read the entire file
    fid = fopen(ApcFile, 'r');
    txt = fread(fid, '*char')';
    fclose(fid);
    % Split by line
    splitTxt = str_split(txt, [10 13]);
    % Look for the AC/PC/IH positions
    for i = 1:length(splitTxt)
        if (length(splitTxt{i}) > 3)
            if strcmpi(splitTxt{i}(1:3),'AC:')
                AC = cubeSize - (str2num(splitTxt{i}(4:end)) - 1) .* sMri.Voxsize;
            elseif strcmpi(splitTxt{i}(1:3),'PC:')
                PC = cubeSize - (str2num(splitTxt{i}(4:end)) - 1) .* sMri.Voxsize;
            elseif strcmpi(splitTxt{i}(1:3),'IH:')
                IH = cubeSize - (str2num(splitTxt{i}(4:end)) - 1) .* sMri.Voxsize;
            end
        end
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
%         NAS = [cubeSize(1)./2,  cubeSize(2),           cubeSize(3)./2];
%         LPA = [1,               cubeSize(2)./2,        cubeSize(3)./2];
%         RPA = [cubeSize(1),     cubeSize(2)./2,        cubeSize(3)./2];
%         if isempty(AC) || isempty(PC) || isempty(IH)
%             AC = [cubeSize(1)./2,  cubeSize(2)./2 + 20,   cubeSize(3)./2];
%             PC  = [cubeSize(1)./2,  cubeSize(2)./2 - 20,   cubeSize(3)./2];
%             IH  = [cubeSize(1)./2,  cubeSize(2)./2,        cubeSize(3)./2 + 50];
%         end
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
        if isempty(AC) || isempty(PC) || isempty(IH) 
            AC = sFid.AC;
            PC = sFid.PC;
            IH = sFid.IH;
        end
    end
    if ~isempty(NAS) || ~isempty(LPA) || ~isempty(RPA) || ~isempty(AC) || ~isempty(PC) || ~isempty(IH)
        figure_mri('SetSubjectFiducials', iSubject, NAS, LPA, RPA, AC, PC, IH);
    end
    % If the NAS/LPA/RPA are defined, but not the others: Compute them
    if ~isempty(NAS) && ~isempty(LPA) && ~isempty(RPA) % && isempty(AC) && isempty(PC) && isempty(IH)
        isComputeMni = 1;
    end
% Define with the MRI Viewer
else
    % Save the fiducials read from the APC file in the MRI
    if ~isempty(ApcFile) && (~isempty(AC) || ~isempty(PC) || ~isempty(IH))
        figure_mri('SetSubjectFiducials', iSubject, [], [], [], AC, PC, IH);
    end
    % MRI Visualization and selection of fiducials (in order to align surfaces/MRI)
    hFig = view_mri(BstMriFile, 'EditFiducials');
    drawnow;
    bst_progress('stop');
    % Display help message: ask user to select fiducial points
    % jHelp = bst_help('MriSetup.html', 0);
    % Wait for the MRI Viewer to be closed
    waitfor(hFig);
    % Close help window
    % jHelp.close();
end
% Load SCS and NCS field to make sure that all the points were defined
sMri = load(BstMriFile);
if ~isComputeMni && (~isfield(sMri, 'SCS') || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA) || isempty(sMri.SCS.R))
    errorMsg = ['Could not import BrainVISA folder: ' 10 10 'Some fiducial points were not defined properly in the MRI.'];
    if isInteractive
        bst_error(errorMsg, 'Import BrainVISA folder', 0);
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
    [iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, TessLhFile, 'ALL', 0);
    BstTessLhFile = BstTessLhFile{1};
    % Downsample
    [BstTessLhLowFile, iLhLow] = tess_downsize(BstTessLhFile, nVertHemi, 'reducepatch');
end
% Right pial
if ~isempty(TessRhFile)
    % Import file
    [iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, TessRhFile, 'ALL', 0);
    BstTessRhFile = BstTessRhFile{1};
    % Downsample
    [BstTessRhLowFile, iRhLow] = tess_downsize(BstTessRhFile, nVertHemi, 'reducepatch');
end
% Left white matter
if ~isempty(TessLwFile)
    % Import file
    [iLw, BstTessLwFile] = import_surfaces(iSubject, TessLwFile, 'ALL', 0);
    BstTessLwFile = BstTessLwFile{1};
    % Load atlases
    if ~isempty(AnnotLwFiles)
        bst_progress('start', 'Import BrainVISA folder', 'Loading atlases: left...');
        [sAllAtlas, err] = import_label(BstTessLwFile, AnnotLwFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Downsample
    [BstTessLwLowFile, iLwLow] = tess_downsize(BstTessLwFile, nVertHemi, 'reducepatch');
end
% Right white matter
if ~isempty(TessRwFile)
    % Import file
    [iRw, BstTessRwFile] = import_surfaces(iSubject, TessRwFile, 'ALL', 0);
    BstTessRwFile = BstTessRwFile{1};
    % Load atlases
    if ~isempty(AnnotRwFiles)
        bst_progress('start', 'Import BrainVISA folder', 'Loading atlases: right...');
        [sAllAtlas, err] = import_label(BstTessRwFile, AnnotRwFiles, 1);
        errorMsg = [errorMsg err];
    end
    % Downsample
    [BstTessRwLowFile, iRwLow] = tess_downsize(BstTessRwFile, nVertHemi, 'reducepatch');
end
% Process error messages
if ~isempty(errorMsg)
    if isInteractive
        bst_error(errorMsg, 'Import BrainVISA folder', 0);
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


%% ===== HEAD SURFACE =====
% Head surface: Take the one from BrainVISA and fill it
if ~isempty(HeadFile)
    % Import file
    [iHead, BstHeadHiFile] = import_surfaces(iSubject, HeadFile, 'ALL', 0);
    BstHeadHiFile = BstHeadHiFile{1};
    % Load MRI
    bst_progress('start', 'Import BrainVISA folder', 'Filling holes in the head surface...');
    % Load head surface
    sHead = load(BstHeadHiFile, 'Vertices', 'Faces', 'Comment');
    % Remove holes
    [sHead.Vertices, sHead.Faces] = tess_fillholes(sMri, sHead.Vertices, sHead.Faces, 2, 2);
    % Save back to file
    bst_save(BstHeadHiFile, sHead, 'v7');
    % Downsample
    BstHeadFile = tess_downsize( BstHeadHiFile, 8000, 'reducepatch' );
    % Delete initial file
    rmFiles = cat(2, rmFiles, BstHeadHiFile);
    rmInd   = [rmInd, iHead];
% Or generate one from Brainstorm
else
    % Generate head surface
    BstHeadFile = tess_isohead(iSubject, 10000, 0, 2);
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


%% ===== UPDATE GUI =====
% Set default cortex
if ~isempty(TessLhFile) && ~isempty(TessRhFile)
    [sSubject, iSubject, iCortex] = bst_get('SurfaceFile', CortexLowFile);
    db_surface_default(iSubject, 'Cortex', iCortex);
end
% Set the default head
db_surface_default(iSubject, 'Scalp');
% Redraw the tree
panel_protocols('UpdateTree');
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



