function errorMsg = import_anatomy_fs(iSubject, FsDir, nVertices, isInteractive, sFid, isExtraMaps, isVolumeAtlas, isKeepMri)
% IMPORT_ANATOMY_FS: Import a full FreeSurfer folder as the subject's anatomy, obtained with either 'recon-all' or 'recon-all-clinical'
%
% USAGE:  errorMsg = import_anatomy_fs(iSubject, FsDir=[ask], nVertices=[ask], isInteractive=1, sFid=[], isExtraMaps=0, isVolumeAtlas=1, isKeepMri=0)
%
% INPUT:
%    - iSubject      : Indice of the subject where to import the MRI
%                      If iSubject=0 : import MRI in default subject
%    - FsDir         : Full filename of the FreeSurfer folder to import
%    - nVertices     : Number of vertices in the file cortex surface
%    - isInteractive : If 0, no input or user interaction
%    - sFid          : Structure with the fiducials coordinates (.NAS .LPA .RPA)
%                      Or full MRI structure with fiducials defined in the SCS structure, to be registered with the FS MRI
%    - isExtraMaps   : If 1, create an extra folder "FreeSurfer" to save some of the
%                      FreeSurfer cortical maps (thickness, ...)
%    - isVolumeAtlas : If 1, imports all the volume atlases available
%    - isKeepMri     : 0=Delete all existing anatomy files
%                      1=Keep existing MRI volumes (when running segmentation from Brainstorm)
%                      2=Keep existing MRI and surfaces
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
% Authors: Francois Tadel, 2012-2022

%% ===== PARSE INPUTS =====
% Keep MRI
if (nargin < 8) || isempty(isKeepMri)
    isKeepMri = 0;
end
% Import ASEG atlases
if (nargin < 7) || isempty(isVolumeAtlas)
    isVolumeAtlas = 1;
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
if (nargin < 2) || isempty(FsDir)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Open file selection dialog
    FsDir = java_getfile( 'open', ...
        'Import FreeSurfer folder...', ...     % Window title
        bst_fileparts(LastUsedDirs.ImportAnat, 1), ...           % Last used directory
        'single', 'dirs', ...                  % Selection mode
        {{'.folder'}, 'FreeSurfer folder', 'FsDir'}, 0);
    % If no folder was selected: exit
    if isempty(FsDir)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = FsDir;
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
            'Are you sure you want to delete the previous MRI and surfaces ?' 10 10], 'Import FreeSurfer folder');
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
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import FreeSurfer folder', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
end
% Number for each hemisphere
nVertHemi = round(nVertices / 2);


%% ===== PARSE FREESURFER FOLDER =====
bst_progress('start', 'Import FreeSurfer folder', 'Parsing folder...');
% Find MRI files
isReconAllClinical = ~isempty(file_find(FsDir, 'synthSR.mgz', 2));
isReconAll         = ~isempty(file_find(FsDir, 'T1.mgz', 2)) && ~isReconAllClinical;

mri1File = '';
if isReconAll
    mri1File = file_find(FsDir, 'T1.mgz', 2);
    mri2File = file_find(FsDir, 'T2.mgz', 2);
    mri1Comment = 'MRI T1';
    mri2Comment = 'MRI T2';
elseif isReconAllClinical
    mri1File = file_find(FsDir, 'synthSR.raw.mgz', 2);
    mri2File = file_find(FsDir, 'native.mgz', 2);
    mri1Comment = 'MRI (synthSR)';
    mri2Comment = 'MRI (native)';
end
if isempty(mri1File)
    mri1File = file_find(FsDir, '*.nii.gz', 0);
    if ~isempty(mri1File)
        mri2File    = '';
        mri1Comment = 'MRI';
        mri2Comment = '';
    else
        errorMsg = [errorMsg 'MRI file was not found: T1.mgz' 10];
    end
end
% Find surface: lh.pial (or lh.pial.T1)
TessLhFile = file_find(FsDir, 'lh.pial', 2);
if ~isempty(TessLhFile)
    d = dir(TessLhFile);
    if (length(d) == 1) && (d.bytes < 256)
        TessLhFile = [];
    end
end
if isempty(TessLhFile)
    TessLhFile = file_find(FsDir, 'lh.pial.T1', 2);
    if isempty(TessLhFile)
        errorMsg = [errorMsg 'Surface file was not found: lh.pial/lh.pial.T1' 10];
    end
end
% Find surface: rh.pial (or rh.pial.T1)
TessRhFile = file_find(FsDir, 'rh.pial', 2);
if ~isempty(TessRhFile)
    d = dir(TessRhFile);
    if (length(d) == 1) && (d.bytes < 256)
        TessRhFile = [];
    end
end
if isempty(TessRhFile)
    TessRhFile = file_find(FsDir, 'rh.pial.T1', 2);
    if isempty(TessRhFile)
        errorMsg = [errorMsg 'Surface file was not found: rh.pial/rh.pial.T1' 10];
    end
end
% Find other surfaces
TessLwFile = file_find(FsDir, 'lh.white', 2);
TessRwFile = file_find(FsDir, 'rh.white', 2);
TessLsphFile = file_find(FsDir, 'lh.sphere.reg', 2);
TessRsphFile = file_find(FsDir, 'rh.sphere.reg', 2);
TessLRsphFile = file_find(FsDir, 'lh.rh.sphere.reg', 2);
TessRLsphFile = file_find(FsDir, 'rh.lh.sphere.reg', 2);
TessInnerFile = file_find(FsDir, 'inner_skull-*.surf', 2);
TessOuterFile = file_find(FsDir, 'outer_skull-*.surf', 2);
% Find volume segmentation
AsegFile = file_find(FsDir, 'aseg.mgz', 2);
OtherAsegFiles = file_find(FsDir, '*+aseg.mgz', 2, 0);
% Find labels
AnnotLhFiles = file_find(FsDir, 'lh.*.annot', 2, 0);
AnnotRhFiles = file_find(FsDir, 'rh.*.annot', 2, 0);
% Remove old labels
if ~isempty(AnnotLhFiles) && ~isempty(AnnotRhFiles)
    % Freesurfer 5.3 creates "BA.annot", Freesurfer 6 creates "BA_exvivo.annot" 
	% If the two are available in the same folder, both versions were executed, and the old "BA.annot" is outdated but not replaced: ignore it
    % Left
    iBAold = find(~cellfun(@(c)isempty(strfind(c, 'BA.annot')), AnnotLhFiles));
    iBAnew = find(~cellfun(@(c)isempty(strfind(c, 'BA_exvivo.annot')), AnnotLhFiles));
    if ~isempty(iBAold) && ~isempty(iBAnew)
        AnnotLhFiles(iBAold) = [];
    end
    % Right
    iBAold = find(~cellfun(@(c)isempty(strfind(c, 'BA.annot')), AnnotRhFiles));
    iBAnew = find(~cellfun(@(c)isempty(strfind(c, 'BA_exvivo.annot')), AnnotRhFiles));
    if ~isempty(iBAold) && ~isempty(iBAnew)
        AnnotRhFiles(iBAold) = [];
    end
    % Remove temporary FastSurfer files: ?h.aparc.mapped.prefix.annot
    iTmpL = find(~cellfun(@(c)isempty(strfind(c, 'mapped.prefix')), AnnotLhFiles));
    if ~isempty(iTmpL)
        AnnotLhFiles(iTmpL) = [];
    end
    iTmpR = find(~cellfun(@(c)isempty(strfind(c, 'mapped.prefix')), AnnotRhFiles));
    if ~isempty(iTmpR)
        AnnotRhFiles(iTmpR) = [];
    end
    % Re-order the files so that FreeSurfer atlases are first (for automatic region labelling)
    iDKL = find(~cellfun(@(c)isempty(strfind(c, 'aparc')), AnnotLhFiles));
    iDKR = find(~cellfun(@(c)isempty(strfind(c, 'aparc')), AnnotRhFiles));
    if ~isempty(iDKL) && ~isempty(iDKR)
        AnnotLhFiles = AnnotLhFiles([iDKL, setdiff(1:length(AnnotLhFiles), iDKL)]);
        AnnotRhFiles = AnnotRhFiles([iDKR, setdiff(1:length(AnnotRhFiles), iDKR)]);
    end
end
% Find thickness maps
if isExtraMaps
    ThickLhFile = file_find(FsDir, 'lh.thickness', 2);
    ThickRhFile = file_find(FsDir, 'rh.thickness', 2);
end
% Report errors
if ~isempty(errorMsg)
    if isInteractive
        bst_error(['Could not import FreeSurfer folder: ' 10 10 errorMsg], 'Import FreeSurfer folder', 0);        
    end
    return;
end


%% ===== IMPORT PRIMARY MRI =====
if isKeepMri && ~isempty(sSubject.Anatomy)
    BstMri1File = file_fullpath(sSubject.Anatomy(sSubject.iAnatomy).FileName);
    in_mri_bst(BstMri1File);
else
    % Read primary MRI
    BstMri1File = import_mri(iSubject, mri1File, 'ALL', 0, [], mri1Comment);
    if isempty(BstMri1File)
        errorMsg = ['Could not import FreeSurfer folder: MRI "' mri1File '" was not imported properly'];
        if isInteractive
            bst_error(errorMsg, 'Import FreeSurfer folder', 0);
        end
        return;
    end
    % Enforce it as the permanent default MRI
    sSubject = db_surface_default(iSubject, 'Anatomy', 1, 0);
end


%% ===== DEFINE FIDUCIALS / MNI NORMALIZATION =====
% Set fiducials and/or compute linear MNI normalization
[isComputeMni, errCall] = process_import_anatomy('SetFiducials', iSubject, FsDir, BstMri1File, sFid, isKeepMri, isInteractive);
% Error handling
if ~isempty(errCall)
    errorMsg = [errorMsg, errCall];
    if isempty(isComputeMni)
        if isInteractive
            bst_error(errorMsg, 'Import FreeSurfer folder', 0);
        end
        return;
    end
end


%% ===== IMPORT SECONDARY MRI =====
% Read secondary MRI (optional)
if ~isempty(mri2File)
    BstMri2File = import_mri(iSubject, mri2File, 'ALL', 0, [], mri2Comment);
    if isempty(BstMri2File)
        disp(['BST> Could not import "' mri2File '" MRI file.']);
    end
end


%% ===== IMPORT SURFACES =====
% Left pial
if ~isempty(TessLhFile)
    % Import file
    [iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, TessLhFile, 'FS', 0);
    BstTessLhFile = BstTessLhFile{1};
    % Load atlases
    if ~isempty(AnnotLhFiles)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading atlases: left pial...');
        [sAllAtlas, err] = import_label(BstTessLhFile, AnnotLhFiles, 1);
        if ~isempty(err)
            disp(['BST> ERROR: ' strrep(err(1:end-1), char(10), [10 'BST> ERROR: '])]);  % Not a blocking error anymore
            errorMsg = [errorMsg err];
        end
    end
    % Load sphere
    if ~isempty(TessLsphFile)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading registered sphere: left pial...');
        [TessMat, err] = tess_addsphere(BstTessLhFile, TessLsphFile, 'FS', 0);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end
    if ~isempty(TessLRsphFile)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading contralateral sphere: left pial...');
        [TessMat, err] = tess_addsphere(BstTessLhFile, TessLRsphFile, 'FS', 1);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end

    % Downsample
    bst_progress('start', 'Import FreeSurfer folder', 'Downsampling: left pial...');
    [BstTessLhLowFile, iLhLow, xLhLow] = tess_downsize(BstTessLhFile, nVertHemi, 'reducepatch');
end
% Right pial
if ~isempty(TessRhFile)
    % Import file
    [iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, TessRhFile, 'FS', 0);
    BstTessRhFile = BstTessRhFile{1};
    % Load atlases
    if ~isempty(AnnotRhFiles)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading atlases: right pial...');
        [sAllAtlas, err] = import_label(BstTessRhFile, AnnotRhFiles, 1);
        if ~isempty(err)
            disp(['BST> ERROR: ' strrep(err(1:end-1), char(10), [10 'BST> ERROR: '])]);  % Not a blocking error anymore
            errorMsg = [errorMsg err];
        end
    end
    % Load sphere
    if ~isempty(TessRsphFile)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading registered sphere: right pial...');
        [TessMat, err] = tess_addsphere(BstTessRhFile, TessRsphFile, 'FS', 0);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end
    
    % Load sphere
    if ~isempty(TessRLsphFile)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading contralateral sphere: right pial...');
        [TessMat, err] = tess_addsphere(BstTessRhFile, TessRLsphFile, 'FS', 1);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end


    % Downsample
    bst_progress('start', 'Import FreeSurfer folder', 'Downsampling: right pial...');
    [BstTessRhLowFile, iRhLow, xRhLow] = tess_downsize(BstTessRhFile, nVertHemi, 'reducepatch');
end
% Left white matter
if ~isempty(TessLwFile)
    % Import file
    [iLw, BstTessLwFile] = import_surfaces(iSubject, TessLwFile, 'FS', 0);
    BstTessLwFile = BstTessLwFile{1};
    % Load atlases
    if ~isempty(AnnotLhFiles)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading atlases: left white...');
        [sAllAtlas, err] = import_label(BstTessLwFile, AnnotLhFiles, 1);
        if ~isempty(err)
            disp(['BST> ERROR: ' strrep(err(1:end-1), char(10), [10 'BST> ERROR: '])]);  % Not a blocking error anymore
            errorMsg = [errorMsg err];
        end
    end
    if ~isempty(TessLsphFile)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading registered sphere: left pial...');
        [TessMat, err] = tess_addsphere(BstTessLwFile, TessLsphFile, 'FS', 0);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end
    if ~isempty(TessLRsphFile)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading contralateral sphere: left pial...');
        [TessMat, err] = tess_addsphere(BstTessLwFile, TessLRsphFile, 'FS', 1);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end

    % Downsample
    bst_progress('start', 'Import FreeSurfer folder', 'Downsampling: left white...');
    [BstTessLwLowFile, iLwLow, xLwLow] = tess_downsize(BstTessLwFile, nVertHemi, 'reducepatch');
end
% Right white matter
if ~isempty(TessRwFile)
    % Import file
    [iRw, BstTessRwFile] = import_surfaces(iSubject, TessRwFile, 'FS', 0);
    BstTessRwFile = BstTessRwFile{1};
    % Load atlases
    if ~isempty(AnnotRhFiles)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading atlases: right white...');
        [sAllAtlas, err] = import_label(BstTessRwFile, AnnotRhFiles, 1);
        if ~isempty(err)
            disp(['BST> ERROR: ' strrep(err(1:end-1), char(10), [10 'BST> ERROR: '])]);  % Not a blocking error anymore
            errorMsg = [errorMsg err];
        end
    end
    % Load sphere
    if ~isempty(TessRsphFile)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading registered sphere: right pial...');
        [TessMat, err] = tess_addsphere(BstTessRwFile, TessRsphFile, 'FS', 0);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end
    
    % Load sphere
    if ~isempty(TessRLsphFile)
        bst_progress('start', 'Import FreeSurfer folder', 'Loading contralateral sphere: right pial...');
        [TessMat, err] = tess_addsphere(BstTessRwFile, TessRLsphFile, 'FS', 1);
        if ~isempty(err)
            errorMsg = [errorMsg err];
        end
    end

    % Downsample
    bst_progress('start', 'Import FreeSurfer folder', 'Downsampling: right white...');
    [BstTessRwLowFile, iRwLow, xRwLow] = tess_downsize(BstTessRwFile, nVertHemi, 'reducepatch');
end
% Process error messages
if ~isempty(errorMsg)
    if isInteractive
        bst_error(errorMsg, 'Import FreeSurfer folder', 0);
    else
        disp(['ERROR: ' errorMsg]);
    end
    % Keep importing, as missing atlases or spheres do not block the rest of the process
    % return;
end
% Inner skull
if ~isempty(TessInnerFile)
    import_surfaces(iSubject, TessInnerFile, 'FS', 0);
end
% Outer skull
if ~isempty(TessOuterFile)
    import_surfaces(iSubject, TessOuterFile, 'FS', 0);
end


%% ===== GENERATE MID-SURFACE =====
BstTessLmFile = [];
BstTessRmFile = [];
% Do not compute without volume atlases, to make a very light default import
if isVolumeAtlas && ~isempty(TessLhFile) && ~isempty(TessRhFile) && ~isempty(TessLwFile) && ~isempty(TessRwFile)
    bst_progress('start', 'Import FreeSurfer folder', 'Generating mid-surface...');
    % Average pial and white surfaces
    [BstTessLmFile, ~, errMsgL] = tess_average({BstTessLhFile, BstTessLwFile});
    [BstTessRmFile, ~, errMsgR] = tess_average({BstTessRhFile, BstTessRwFile});
    % If computed: downsample the surfaces
    if ~isempty(BstTessLmFile) && ~isempty(BstTessRmFile)
        bst_progress('start', 'Import FreeSurfer folder', 'Downsampling: mid-surface...');
        [BstTessLmLowFile, iLmLow, xLmLow] = tess_downsize(BstTessLmFile, nVertHemi, 'reducepatch');
        [BstTessRmLowFile, iRmLow, xRmLow] = tess_downsize(BstTessRmFile, nVertHemi, 'reducepatch');
    else
        errorMsg = [errorMsg 10 'Could not compute mid-surfaces: ' 10 errMsgL 10 errMsgR];
        if isInteractive
            bst_error(errorMsg, 'Import FreeSurfer folder', 0);
        else
            disp(['ERROR: ' errorMsg]);
        end
        % Not a blocking error: No need to have the mid-surface to keep going
    end
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
% Merge hemispheres: mid-surface (do not compute without volume atlases, to make a very light default import)
if ~isempty(BstTessLmFile) && ~isempty(BstTessRmFile)
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
end

%% ===== DELETE INTERMEDIATE FILES =====
if ~isempty(rmFiles)
    % Delete files
    file_delete(file_fullpath(rmFiles), 1);
    % Reload subject
    db_reload_subjects(iSubject);
end

%% ===== GENERATE HEAD =====
% Generate head surface
HeadFile = tess_isohead(iSubject, 10000, 0, 2);

%% ===== IMPORT ASEG ATLAS =====
if isVolumeAtlas && ~isempty(AsegFile)
    BstMriFiles = {};
    % Import atlas as volume
    BstMriFiles{end+1} = import_mri(iSubject, AsegFile);
    % Import other ASEG volumes
    for iFile = 1:length(OtherAsegFiles)
        BstMriFiles{end+1} = import_mri(iSubject, OtherAsegFiles{iFile});
    end
    % Remove padding introduced in every direction by 'mri_synth_surf.py' call in 'recon-all-clinical.sh'
    if isReconAllClinical
        for iAtlas = 1 : length(BstMriFiles)
            sMriAtlas = in_mri_bst(BstMriFiles{iAtlas});
            if iAtlas == 1
                sMri1 = in_mri_bst(BstMri1File);
                nPad = unique((size(sMriAtlas.Cube) - size(sMri1.Cube)) / 2);
            end
            if length(nPad) == 1 && nPad > 0 && round(nPad) == nPad
                sMriAtlas.Cube = sMriAtlas.Cube(1+nPad:end-nPad, 1+nPad:end-nPad, 1+nPad:end-nPad);
                bst_save(BstMriFiles{iAtlas}, sMriAtlas, 'v7');
            end
        end
    end
    % Import atlas as surfaces
    SelLabels = {...
        'Cerebellum L', 'Accumbens L', 'Amygdala L', 'Caudate L', 'Hippocampus L', 'Pallidum L', 'Putamen L', 'Thalamus L', 'Thalamus R', ...
        'Cerebellum R', 'Accumbens R', 'Amygdala R', 'Caudate R', 'Hippocampus R', 'Pallidum R', 'Putamen R', 'Thalamus L', 'Thalamus R', ...
        'Brainstem'};
    [iAseg, BstAsegFile] = import_surfaces(iSubject, AsegFile, 'MRI-MASK', 0, [], SelLabels, 'subcortical');
    % Extract cerebellum only
    try
        BstCerebFile = tess_extract_struct(BstAsegFile{1}, {'Cerebellum L', 'Cerebellum R'}, 'aseg | cerebellum');
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


%% ===== IMPORT THICKNESS MAPS =====
if isExtraMaps && ~isempty(CortexHiFile) && ~isempty(ThickLhFile) && ~isempty(ThickLhFile)
    % Create a condition "FreeSurfer"
    iStudy = db_add_condition(iSubject, 'FreeSurfer');
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
bst_progress('stop');



