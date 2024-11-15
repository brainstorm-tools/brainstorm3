function errorMsg = import_anatomy_besa(iSubject, BesaMriDir, nVertices, isInteractive, sFid)
% IMPORT_ANATOMY_BESA: Import results from the BESA MRI folder
%
% USAGE:  errorMsg = import_anatomy_besa(iSubject, BesaMriDir=[ask], nVertices=[ask], isInteractive=1, sFid=[])
%
% INPUT:
%    - iSubject      : Indice of the subject where to import the MRI
%                      If iSubject=0 : import MRI in default subject
%    - BesaMriDir    : Full filename of the BESA MRI folder to import
%    - nVertices     : Number of vertices in the file cortex surface
%    - isInteractive : If 0, no input or user interaction
%    - sFid          : Structure with the fiducials coordinates (.NAS .LPA .RPA)

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
% Authors: Raymundo Cassani, 2024

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
if (nargin < 2) || isempty(BesaMriDir)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Open file selection dialog
    BesaMriDir = java_getfile( 'open', ...
                               'Import FreeSurfer folder...', ...               % Window title
                                bst_fileparts(LastUsedDirs.ImportAnat, 1), ...  % Last used directory
                                'single', 'dirs', ...                           % Selection mode
                                {{'.folder'}, 'BESA MRI folder', 'BesaMriDir'}, 0);
    % If no folder was selected: exit
    if isempty(BesaMriDir)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = BesaMriDir;
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
            'Are you sure you want to delete the previous MRI and surfaces ?' 10 10], 'Import BESA MRI folder');
    else
        isDel = 1;
    end
    % If user canceled process
    if ~isDel
        bst_progress('stop');
        return;
    end
    % Delete anatomy
    db_delete_anatomy(iSubject);
end


%% ===== ASK NB VERTICES =====
if isempty(nVertices)
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import BESA MRI folder', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
end


%% ===== PARSE BESA MRI FOLDER =====
% https://wiki.besa.de/index.php?title=Integration_with_MRI_and_fMRI
% Find MRI volume, search for T1 in name _ACPC.vmr 
% Find surfaces
bst_progress('start', 'Import BESA MRI folder', 'Parsing folder...');
% Find directory for MRI files
mriDir = file_find(BesaMriDir, 'VMRFiles');
if isempty(mriDir)
    errorMsg = [errorMsg 'The folder with MRI .vmr files ("/VMRFiles/") cannot be located ' 10];
end
srfDir = file_find(BesaMriDir, 'SurfaceFiles');
if isempty(srfDir)
    errorMsg = [errorMsg 'The folder with Surfaces .srf files ("/SurfaceFiles/") cannot be located ' 10];
end
% Find the T1 AC-PC MRI file name
MriFile = file_find(mriDir, '*_ACPC.vmr', [], 0);
if isempty(MriFile)
    errorMsg = [errorMsg 'The AC-PC MRI file was not found: *_ACPC.vmr' 10];
end
if length(MriFile) > 1
    errorMsg = [errorMsg 'More than one AC-PC MRI file has been found: *_ACPC.vmr' 10];
end
MriFile = MriFile{1};
% Find surfaces
[~, basename] = bst_fileparts(MriFile);
% Surfaces: {Head, WhiteMatter}
srfFilenames = {[basename, '.srf'], [basename, '_WM.srf']};
HeadFile   = file_find(srfDir, srfFilenames{1});
TessWmFile = file_find(srfDir, srfFilenames{2});
srfFiles = {HeadFile, TessWmFile};
% Error message
for iSrf = 1 : length(srfFiles)
    if isempty(srfFiles{iSrf})
        errorMsg = [errorMsg  sprintf('Surface file %s was not found', srfFilenames{iSrf}) 10];
    end
end
bst_progress('stop');
% Report errors
if ~isempty(errorMsg)
    if isInteractive
        bst_error(['Could not import BESA MRI folder: ' 10 10 errorMsg], 'Import BESA MRI folder', 0);  
    end
    return;
end


%% ===== IMPORT PRIMARY MRI =====
% Read MRI
BstMri1File = import_mri(iSubject, MriFile);
if isempty(BstMri1File)
    errorMsg = 'Could not import BESA MRI folder: MRI was not imported properly';
    if isInteractive
        bst_error(errorMsg, 'Import BESA MRI folder', 0);
    end
    return;
end
% Enforce it as the permanent default MRI
db_surface_default(iSubject, 'Anatomy', 1, 0);


%% ===== DEFINE FIDUCIALS / MNI NORMALIZATION =====
% Set fiducials and/or compute linear MNI normalization
[isComputeMni, errCall] = process_import_anatomy('SetFiducials', iSubject, BesaMriDir, BstMri1File, sFid, 0, isInteractive);
% Error handling
if ~isempty(errCall)
    errorMsg = [errorMsg, errCall];
    if isempty(isComputeMni)
        if isInteractive
            bst_error(errorMsg, 'Import BESA MRI folder', 0);
        end
        return;
    end
end

%% ===== IMPORT SURFACES =====
% Head
if ~isempty(HeadFile)
    % Import file
    [~, BstHeadFile] = import_surfaces(iSubject, HeadFile, 'BESA-SRF', 0, [], [], 'head');
    BstHeadFile = BstHeadFile{1};
    % Update type
    BstHeadFile = db_surface_type(BstHeadFile, 'Scalp');
end
% White matter
if ~isempty(TessWmFile)
    % Import file
    [~, BstTessWmFile, nVerticesOrg] = import_surfaces(iSubject, TessWmFile, 'BESA-SRF', 0);
    BstTessWmFile = BstTessWmFile{1};
    % Update comment
    newComment = sprintf('white_%dV', nVerticesOrg);
    file_update(bst_fullfile(BstTessWmFile), 'Field', 'Comment', newComment);        
    [sSubject, iSubject, iSurface] = bst_get('SurfaceFile', BstTessWmFile);
    sSubject.Surface(iSurface).Comment = newComment;
    bst_set('Subject', iSubject, sSubject);        
    % Update type
    BstTessWmFile = db_surface_type(BstTessWmFile, 'Cortex');    
    % Downsample
    BstTessWmLwFile = tess_downsize(BstTessWmFile, nVertices, 'reducepatch');
end


%% ===== UPDATE GUI =====
% Set default cortex
if ~isempty(BstTessWmLwFile)
    [~, iSubject, iSurface] = bst_get('SurfaceFile', BstTessWmLwFile);
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
    hFig = view_surface(BstHeadFile);
    % Display cortex
    if ~isempty(BstTessWmLwFile)
        view_surface(BstTessWmLwFile);
    end
    % Set orientation
    figure_3d('SetStandardView', hFig, 'left');
end
% Close progress bar
bst_progress('stop');