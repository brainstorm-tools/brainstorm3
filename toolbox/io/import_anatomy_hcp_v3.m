function errorMsg = import_anatomy_hcp_v3(iSubject, MegAnatDir, isInteractive)
% IMPORT_ANATOMY_HCP_V3: Import the information from a HCP-MEG folder as the subject's anatomy (SubjId/MEG/anatomy, pipeline v3).
%
% REFERENCE: http://www.humanconnectome.org/about/project/MEG-and-EEG.html
%
% USAGE:  errorMsg = import_anatomy_hcp_v3(iSubject, MegAnatDir=[], isInteractive=1)
%
% INPUT:
%    - iSubject   : Indice of the subject where to import the MRI (if iSubject=0, import MRI in default anatomy)
%    - MegAnatDir : Full filename of the HCP folder to import (SubjId/MEG/anatomy)

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
% Authors: Francois Tadel, 2016

%% ===== GET FOLDER =====
% Initialize returned variable
errorMsg = [];
% Interactive by default
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 1;
end
% Ask folder to the user
if (nargin < 2) || isempty(MegAnatDir)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    % Open file selection dialog
    MegAnatDir = java_getfile( 'open', ...
        'Import HCP MEG/anatomy folder...', ...     % Window title
        bst_fileparts(LastUsedDirs.ImportAnat, 1), ...           % Last used directory
        'single', 'dirs', ...                  % Selection mode
        {{'.folder'}, 'HCP MEG/anatomy folder (pipeline v3)', 'HCPv3'}, 0);
    % If no folder was selected: exit
    if isempty(MegAnatDir)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = MegAnatDir;
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
            'Are you sure you want to delete the previous MRI and surfaces ?' 10 10], 'Import HCP folder');
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


%% ===== PARSE HCP FOLDER =====
bst_progress('start', 'Import HCP MEG/anatomy folder', 'Parsing folder...');
% Find files
mriDir   = dir(bst_fullfile(MegAnatDir, 'T1w*.nii.gz'));
lTessDir = dir(bst_fullfile(MegAnatDir, '*L.mid*.gii'));
rTessDir = dir(bst_fullfile(MegAnatDir, '*R.mid*.gii'));
transDir = dir(bst_fullfile(MegAnatDir, '*anatomy_transform.txt'));
% Check that all the files exist
if isempty(mriDir) || isempty(lTessDir) || isempty(rTessDir) || isempty(transDir)
    errorMsg = [errorMsg ...
        'Invalid HCP MEG/anatomy folder (megconnectome pipeline v3.0).' 10 10 ...
        'The folder must include the following files:' 10 ...
        ' - MRI: *anatomy_transform.txt' 10 ...
        ' - Transformations: T1w*.nii.gz' 10 ...
        ' - Left hemisphere: *L.mid*.gii' 10 ...
        ' - Right hemisphere: *R.mid*.gii'];
    if isInteractive
        bst_error(['Could not import anatomy folder: ' 10 10 errorMsg], 'Import HCP folder', 0);        
    end
    return;
end
% Get full file names
MriFile    = bst_fullfile(MegAnatDir, mriDir(1).name);
TessLhFile = bst_fullfile(MegAnatDir, lTessDir(1).name);
TessRhFile = bst_fullfile(MegAnatDir, rTessDir(1).name);
TransFile  = bst_fullfile(MegAnatDir, transDir(1).name);


%% ===== IMPORT MRI =====
% Read MRI
[BstMriFile, sMri] = import_mri(iSubject, MriFile, 'ALL-MNI', 0);
if isempty(BstMriFile)
    errorMsg = 'Could not import HCP folder: MRI was not imported properly';
    if isInteractive
        bst_error(errorMsg, 'Import HCP folder', 0);
    end
    return;
end


%% ===== READ TRANSFORMATIONS =====
bst_progress('start', 'Import HCP MEG/anatomy folder', 'Reading transformations...');
% Read file
fid = fopen(TransFile, 'rt');
strFid = fread(fid, [1 Inf], '*char');
fclose(fid);
% Evaluate the file (.m file syntax)
eval(strFid);
% Check that the variables were defined
if ~exist('transform', 'var') || ~isfield(transform, 'vox07mm2spm') || ~isfield(transform, 'vox07mm2bti')
    errorMsg = [errorMsg ...
        'Invalid HCP MEG/anatomy folder (megconnectome pipeline v3.0).' 10 10 ...
        'The transformation file must define the following variables in Matlab syntax:' 10 ...
        ' - transform.vox07mm2spm' 10 ...
        ' - transform.vox07mm2bti' 10];
    if isInteractive
        bst_error(['Could not import anatomy folder: ' 10 10 errorMsg], 'Import HCP folder', 0);        
    end
    return;
end


%% ===== MRI=>MNI TRANSFORMATION =====
% Convert transformations from "Brainstorm MRI" to "FieldTrip voxel"
Tbst2ft = [diag([-1, 1, 1] ./ sMri.Voxsize), [size(sMri.Cube,1); 0; 0]; 0 0 0 1];
% Set the MNI=>SCS transformation in the MRI
Tmni = transform.vox07mm2spm * Tbst2ft;
sMri.NCS.R = Tmni(1:3,1:3);
sMri.NCS.T = Tmni(1:3,4);
% Compute default fiducials positions based on MNI coordinates
sMri = mri_set_default_fid(sMri);


%% ===== MRI=>SCS TRANSFORMATION =====
% Set the MRI=>SCS transformation in the MRI
Tscs = transform.vox07mm2bti * Tbst2ft;
sMri.SCS.R = Tscs(1:3,1:3);
sMri.SCS.T = Tscs(1:3,4);
% Standard positions for the SCS fiducials
NAS = [90,   0, 0] ./ 1000;
LPA = [ 0,  75, 0] ./ 1000;
RPA = [ 0, -75, 0] ./ 1000;
Origin = [0, 0, 0];
% Convert: SCS (meters) => MRI (millimeters)
sMri.SCS.NAS    = cs_convert(sMri, 'scs', 'mri', NAS) .* 1000;
sMri.SCS.LPA    = cs_convert(sMri, 'scs', 'mri', LPA) .* 1000;
sMri.SCS.RPA    = cs_convert(sMri, 'scs', 'mri', RPA) .* 1000;
sMri.SCS.Origin = cs_convert(sMri, 'scs', 'mri', Origin) .* 1000;
% Save MRI structure (with fiducials)
bst_save(BstMriFile, sMri, 'v7'); 


%% ===== IMPORT SURFACES =====
bst_progress('start', 'Import HCP MEG/anatomy folder', 'Importing surfaces...');
% Left pial
[iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, TessLhFile, 'GII-MNI', 0);
BstTessLhFile = BstTessLhFile{1};
% Right pial
[iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, TessRhFile, 'GII-MNI', 0);
BstTessRhFile = BstTessRhFile{1};


%% ===== MERGE SURFACES =====
% Merge surfaces
origCortexFile = tess_concatenate({BstTessLhFile, BstTessRhFile}, sprintf('cortex_%dV', nVertOrigL + nVertOrigR), 'Cortex');
% Rename high-res file
origCortexFile = file_fullpath(origCortexFile);
CortexFile     = bst_fullfile(bst_fileparts(origCortexFile), 'tess_cortex_mid.mat');
file_move(origCortexFile, CortexFile);
% Keep relative path only
CortexFile = file_short(CortexFile);
% Delete original files
file_delete(file_fullpath({BstTessLhFile, BstTessRhFile}), 1);
% Reload subject
db_reload_subjects(iSubject);


%% ===== GENERATE HEAD =====
% Generate head surface
HeadFile = tess_isohead(iSubject, 10000, 0, 2);


%% ===== UPDATE GUI =====
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
    view_surface(CortexFile);
    % Set orientation
    figure_3d('SetStandardView', hFig, 'left');
end
% Close progress bar
bst_progress('stop');




