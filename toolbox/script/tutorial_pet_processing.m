function tutorial_pet_processing(tutorial_dir, reports_dir)
% TUTORIAL_INTRODUCTION: Script that run the PET processing tutorial
%
% INPUTS: 
%    - tutorial_dir : Directory where the tutorial_pet_processing.zip file has been unzipped
%    - reports_dir  : Directory where to save the execution report (instead of displaying it)

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
% Authors: Raymundo Cassani, 2025
%          Diellor Basha, 2025


% ===== FILES TO IMPORT =====
% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the dataset folder.');
end
% Subject name
SubjectName = 'Subject01';
% Build the path of the files to import
AnatDir    = fullfile(tutorial_dir, 'tutorial_pet_processing', 'anatomy');
Pet1File   = fullfile(tutorial_dir, 'tutorial_pet_processing', 'pet', '18FNAV4694.nii.gz');
Pet2File   = fullfile(tutorial_dir, 'tutorial_pet_processing', 'pet', '18Fflortaucipir.nii.gz');
% Check if the folder contains the required files
if ~file_exist(Pet1File) || ~file_exist(Pet2File)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file tutorial_pet_processing.zip.']);
end
% Re-inialize random number generator
if (bst_get('MatlabVersion') >= 712)
    rng('default');
end


%% ===== 1. CREATE PROTOCOL ====================================================
%  =============================================================================
disp([10 'DEMO> 1. Create protocol' 10]);
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialPET';
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
% Start a new report
bst_report('Start');


%% ===== 2. IMPORT ANATOMY =====================================================
%  =============================================================================
disp([10 'DEMO> 2. Import anatomy' 10]);
% Process: Import FreeSurfer folder
bst_process('CallProcess', 'process_import_anatomy', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {AnatDir, 'FreeSurfer+Thick'}, ...
    'nvertices',   15000);
[sSubject, iSubject] = bst_get('Subject', SubjectName);
MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
hFigMri = view_mri(MriFile);
bst_report('Snapshot', hFigMri);
pause(0.5);
close(hFigMri);


%% ===== 3. IMPORT AND PROCESS PET VOLUMES =================================
%  =============================================================================
disp([10 'DEMO> 2. Import and process PET volumes' 10]);
PetFiles = {Pet1File, Pet2File};
for iPet = 1 : length(PetFiles)
    % Process: Import PET
    bst_process('CallProcess', 'process_import_mri', [], [], ...
        'subjectname', SubjectName, ...
        'voltype',     'pet', ...  % PET
        'comment',     '', ...
        'mrifile',     {PetFiles{iPet}, 'Nifti1'});
    % Imported PET (last volume)
    sSubject = bst_get('Subject', SubjectName);
    impPetFile = sSubject.Anatomy(end).FileName;
    % Align and aggregate PET volume
    PetAggFile = mri_realign(impPetFile, 'spm_realign', 0, 'mean');
    % Co-register and reslice PET volume
    PetAggCoregFile = mri_coregister(PetAggFile, MriFile, 'spm', 1);
    % Compute SUVR, and project to surface
    [PetSuvrFile, ~, suvrSurfFile] = pet_process(PetAggCoregFile, 'ASEG', 'Cortex', 'Brainmask', 1, 1);

    % Figure: Aligned, aggregated, co-registered PET overlayed on MRI
    hFigPetOvr = view_mri(MriFile, PetAggCoregFile);
    bst_report('Snapshot', hFigPetOvr);
    pause(0.5);
    close(hFigPetOvr);
    % Figure: SUVR volume
    hFigPetSuvr = view_mri(MriFile, PetSuvrFile);
    bst_report('Snapshot', hFigPetSuvr);
    pause(0.5);
    close(hFigPetSuvr);
    % Figure: SUVR projected to surface
    hFigSurfSuvr = view_surface_data([], suvrSurfFile);
    bst_report('Snapshot', hFigSurfSuvr);
    pause(0.5);
    close(hFigSurfSuvr);
end


%% ===== SAVE REPORT =====
% Save and display report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end
