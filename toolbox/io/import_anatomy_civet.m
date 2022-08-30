function errorMsg = import_anatomy_civet(iSubject, CivetDir, nVertices, isInteractive, sFid, isExtraMaps)
% IMPORT_ANATOMY_CIVET: Import a full CIVET folder as the subject's anatomy.
%
% USAGE:  errorMsg = import_anatomy_civet(iSubject, CivetDir=[], nVertices=15000, isInteractive=1, sFid=[], isExtraMaps=0)
%
% INPUT:
%    - iSubject     : Indice of the subject where to import the MRI
%                     If iSubject=0 : import MRI in default subject
%    - CivetDir     : Full filename of the CIVET folder to import
%    - nVertices    : Number of vertices in the file cortex surface
%    - isInteractive: If 0, no input or user interaction
%    - sFid         : Structure with the fiducials coordinates
%                     Or full MRI structure with fiducials defined in the SCS structure, to be registered with the FS MRI
%    - isExtraMaps  : If 1, create an extra folder "CIVET" to save some of the
%                     CIVET cortical maps (thickness, ...)
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
% Authors: Francois Tadel, 2013-2022


%% ===== PARSE INPUTS =====
% Extrac cortical maps
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
if (nargin < 2) || isempty(CivetDir)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Open file selection dialog
    CivetDir = java_getfile( 'open', ...
        'Import CIVET folder...', ...     % Window title
        bst_fileparts(LastUsedDirs.ImportAnat, 1), ...           % Last used directory
        'single', 'dirs', ...                  % Selection mode
        {{'.folder'}, 'CIVET folder', 'CivetDir'}, 0);
    % If no folder was selected: exit
    if isempty(CivetDir)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = CivetDir;
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
            'Are you sure you want to delete the previous MRI and surfaces ?' 10 10], 'Import CIVET folder');
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
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import CIVET folder', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
end
% Number for each hemisphere
nVertHemi = round(nVertices / 2);


%% ===== PARSE CIVET FOLDER =====
bst_progress('start', 'Import CIVET folder', 'Parsing folder...');
% Find MRI
T1File = file_find(sprintf('%s/native',CivetDir), '*_t1.mnc');
if isempty(T1File)
    errorMsg = [errorMsg 'native MRI file was not found: *_t1.mnc' 10];
    if isInteractive
        bst_error(['Could not import CIVET folder: ' 10 10 errorMsg], 'Import CIVET folder', 0);        
    end
    return;
elseif iscell(T1File)
    T1File = T1File{1};
end
% Get study prefix
[tmp, StudyPrefix] = bst_fileparts(T1File);
StudyPrefix = strrep(StudyPrefix, '_t1', '');
% Find surfaces
TessLhFile = file_find(CivetDir, [StudyPrefix '_gray_surface_left_*.obj']);
TessRhFile = file_find(CivetDir, [StudyPrefix '_gray_surface_right_*.obj']);
TessLwFile = file_find(CivetDir, [StudyPrefix '_white_surface_left_*.obj']);
TessRwFile = file_find(CivetDir, [StudyPrefix '_white_surface_right_*.obj']);
TessLmFile = file_find(CivetDir, [StudyPrefix '_mid_surface_left_*.obj']);
TessRmFile = file_find(CivetDir, [StudyPrefix '_mid_surface_right_*.obj']);
if isempty(TessLmFile)
    errorMsg = [errorMsg 'Surface file was not found: ' StudyPrefix '_mid_surface_left_*.obj' 10];
end
if isempty(TessRmFile)
    errorMsg = [errorMsg 'Surface file was not found: ' StudyPrefix '_mid_surface_right_*.obj' 10];
end
% Find thickness maps
if isExtraMaps
    ThickLhFile = file_find(CivetDir, [StudyPrefix '_native_rms_tlink_30mm_left.txt']);
    ThickRhFile = file_find(CivetDir, [StudyPrefix '_native_rms_tlink_30mm_right.txt']);
end
% Report errors
if ~isempty(errorMsg)
    if isInteractive
        bst_error(['Could not import CIVET folder: ' 10 10 errorMsg], 'Import CIVET folder', 0);        
    end
    return;
end


%% ===== IMPORT MRI =====
% Read MRI
[BstT1File, sMri] = import_mri(iSubject, T1File);
if isempty(BstT1File)
    errorMsg = 'Could not import CIVET folder: MRI was not imported properly';
    if isInteractive
        bst_error(errorMsg, 'Import CIVET folder', 0);
    end
    return;
end


%% ===== DEFINE FIDUCIALS / MNI NORMALIZATION =====
% Set fiducials and/or compute linear MNI normalization
[isComputeMni, errCall] = process_import_anatomy('SetFiducials', iSubject, CivetDir, BstT1File, sFid, 0, isInteractive);
% Error handling
if ~isempty(errCall)
    errorMsg = [errorMsg, errCall];
    if isempty(isComputeMni)
        if isInteractive
            bst_error(errorMsg, 'Import CIVET folder', 0);
        end
        return;
    end
end


%% ===== IMPORT SURFACES =====
% Left pial
if ~isempty(TessLhFile)
    % Import file
    [iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, TessLhFile, 'MNIOBJ', 0);
    BstTessLhFile = BstTessLhFile{1};
    % Downsample
    bst_progress('start', 'Import CIVET folder', 'Downsampling: left pial...');
    [BstTessLhLowFile, iLhLow, xLhLow] = tess_downsize(BstTessLhFile, nVertHemi, 'reducepatch');
end
% Right pial
if ~isempty(TessRhFile)
    % Import file
    [iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, TessRhFile, 'MNIOBJ', 0);
    BstTessRhFile = BstTessRhFile{1};
    % Downsample
    bst_progress('start', 'Import CIVET folder', 'Downsampling: right pial...');
    [BstTessRhLowFile, iRhLow, xRhLow] = tess_downsize(BstTessRhFile, nVertHemi, 'reducepatch');
end

% Left white matter
if ~isempty(TessLwFile)
    % Import file
    [iLw, BstTessLwFile] = import_surfaces(iSubject, TessLwFile, 'MNIOBJ', 0);
    BstTessLwFile = BstTessLwFile{1};
    % Downsample
    bst_progress('start', 'Import CIVET folder', 'Downsampling: left white...');
    [BstTessLwLowFile, iLwLow, xLwLow] = tess_downsize(BstTessLwFile, nVertHemi, 'reducepatch');
end
% Right white matter
if ~isempty(TessRwFile)
    % Import file
    [iRw, BstTessRwFile] = import_surfaces(iSubject, TessRwFile, 'MNIOBJ', 0);
    BstTessRwFile = BstTessRwFile{1};
    % Downsample
    bst_progress('start', 'Import CIVET folder', 'Downsampling: right white...');
    [BstTessRwLowFile, iRwLow, xRwLow] = tess_downsize(BstTessRwFile, nVertHemi, 'reducepatch');
end

% Left mid-surface
if ~isempty(TessLmFile)
    % Import file
    [iLm, BstTessLmFile] = import_surfaces(iSubject, TessLmFile, 'MNIOBJ', 0);
    BstTessLmFile = BstTessLmFile{1};
    % Downsample
    bst_progress('start', 'Import CIVET folder', 'Downsampling: left mid-surface...');
    [BstTessLmLowFile, iLmLow, xLmLow] = tess_downsize(BstTessLmFile, nVertHemi, 'reducepatch');
end
% Right mid-surface
if ~isempty(TessRmFile)
    % Import file
    [iRm, BstTessRmFile] = import_surfaces(iSubject, TessRmFile, 'MNIOBJ', 0);
    BstTessRmFile = BstTessRmFile{1};
    % Downsample
    bst_progress('start', 'Import CIVET folder', 'Downsampling: right mid-surface...');
    [BstTessRmLowFile, iRmLow, xRmLow] = tess_downsize(BstTessRmFile, nVertHemi, 'reducepatch');
end
% Process error messages
if ~isempty(errorMsg)
    if isInteractive
        bst_error(errorMsg, 'Import CIVET folder', 0);
    end
    return;
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
end

% Merge hemispheres: white
if ~isempty(TessLwFile) && ~isempty(TessRwFile)
    % Hi-resolution surface
    WhiteHiFile  = tess_concatenate({BstTessLwFile,    BstTessRwFile},    sprintf('white_%dV', nVertOrigL + nVertOrigR), 'Cortex');
    WhiteLowFile = tess_concatenate({BstTessLwLowFile, BstTessRwLowFile}, sprintf('white_%dV', length(xLwLow) + length(xRwLow)), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {BstTessLwFile, BstTessRwFile, BstTessLwLowFile, BstTessRwLowFile});
    % Rename high-res file
    oldWhiteHiFile = file_fullpath(WhiteHiFile);
    WhiteHiFile    = bst_fullfile(bst_fileparts(oldWhiteHiFile), 'tess_cortex_white_high.mat');
    file_move(oldWhiteHiFile, WhiteHiFile);
    % Rename high-res file
    oldWhiteLowFile = file_fullpath(WhiteLowFile);
    WhiteLowFile    = bst_fullfile(bst_fileparts(oldWhiteLowFile), 'tess_cortex_white_low.mat');
    file_move(oldWhiteLowFile, WhiteLowFile);
end
% Merge hemispheres: mid-surface
if ~isempty(TessLmFile) && ~isempty(TessRmFile)
    % Hi-resolution surface
    MidHiFile  = tess_concatenate({BstTessLmFile,    BstTessRmFile},    sprintf('mid_%dV', nVertOrigL + nVertOrigR), 'Cortex');
    MidLowFile = tess_concatenate({BstTessLmLowFile, BstTessRmLowFile}, sprintf('mid_%dV', length(xLmLow) + length(xRmLow)), 'Cortex');
    % Delete separate hemispheres
    rmFiles = cat(2, rmFiles, {BstTessLmFile, BstTessRmFile, BstTessLmLowFile, BstTessRmLowFile});
    % Rename high-res file
    oldMidHiFile = file_fullpath(MidHiFile);
    MidHiFile    = bst_fullfile(bst_fileparts(oldMidHiFile), 'tess_cortex_mid_high.mat');
    file_move(oldMidHiFile, MidHiFile);
    % Rename high-res file
    oldMidLowFile = file_fullpath(MidLowFile);
    MidLowFile    = bst_fullfile(bst_fileparts(oldMidLowFile), 'tess_cortex_mid_low.mat');
    file_move(oldMidLowFile, MidLowFile);
    MidHiFile = file_short(MidHiFile);
else
    MidHiFile = [];
    MidLowFile = [];
end

% Delete intermediary files
if ~isempty(rmFiles)
    % Delete files
    file_delete(file_fullpath(rmFiles), 1);
    % Reload subject
    db_reload_subjects(iSubject);
    % Refresh tree
    panel_protocols('UpdateNode', 'Subject', iSubject);
    panel_protocols('SelectNode', [], 'subject', iSubject, -1 );
end


%% ===== GENERATE HEAD =====
% Generate head surface
HeadFile = tess_isohead(iSubject, 10000, 0, 2);


%% ===== IMPORT THICKNESS MAPS =====
if isExtraMaps && ~isempty(MidHiFile) && ~isempty(ThickLhFile) && ~isempty(ThickLhFile)
    % Create a condition "CIVET"
    iStudy = db_add_condition(iSubject, 'CIVET');
    % Import cortical thickness
    ThickFile = import_sources(iStudy, MidHiFile, ThickLhFile, ThickRhFile, 'CIVET');
end


%% ===== UPDATE GUI =====
% Set default cortex
if ~isempty(TessLmFile) && ~isempty(TessRmFile)
    [sSubject, iSubject, iSurface] = bst_get('SurfaceFile', MidLowFile);
    db_surface_default(iSubject, 'Cortex', iSurface);
end
% Update subject node
panel_protocols('UpdateNode', 'Subject', iSubject);
% Save database
db_save();
% Unload everything
bst_memory('UnloadAll', 'Forced');
% Give a graphical output for user validation
if isInteractive
    % Display the downsampled cortex + head + ASEG
    hFig = view_surface(HeadFile);
    % Display cortex
    if ~isempty(MidLowFile)
        view_surface(MidLowFile);
    end
    % Set orientation
    figure_3d('SetStandardView', hFig, 'left');
end
% Close progress bar
bst_progress('stop');




