function tutorial_fem_tensors(tutorial_dir)
% TUTORIAL_FEM_TENSORS: Script that runs the Brainstorm FEM tensots tutorial.
%
% REFERENCE: https://neuroimage.usc.edu/brainstorm/Tutorials/FemTensors
%
% INPUTS: 
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
% Author: Francois Tadel, 2022


% ===== FILES TO IMPORT =====
% You have to specify the folder in which the tutorial datasets were unzipped (BrainSuiteTutorialSVReg and DWI)
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial dataset folder.');
end
% Build the path of the files to import
T1Nii  = fullfile(tutorial_dir, 'BrainSuiteTutorialSVReg', '2523412.nii.gz');
DwiNii  = fullfile(tutorial_dir, 'DWI', '2523412.dwi.nii.gz');

% Check if the folder contains the required files
if ~file_exist(T1Nii) || ~file_exist(DwiNii)
    error(['The folder ' tutorial_dir ' does not contain the files downloaded from the online tutorial.']);
end
% Subject name
SubjectName = 'Subject01';


% ===== CHECK SOFTWARE DEPENDENCIES =====
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% BrainSuite
if ~file_exist(bst_fullfile(bst_get('BrainSuiteDir'), 'bin'))
    error('BrainSuite is not configured in the Brainstorm preferences.');
end


%% ===== CREATE PROTOCOL  =====
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Create Protocol
ProtocolName = 'TutorialTensors';
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);


%% ===== IMPORT ANATOMY =====
% Process: Import MRI
bst_process('CallProcess', 'process_import_mri', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {T1Nii, 'ALL'});

% Process: MNI normalization
bst_process('CallProcess', 'process_mni_normalize', [], [], ...
    'subjectname', SubjectName, ...
    'method',      'maff8', ...  % maff8:Affine registration using SPM mutual information algorithm.Estimates a simple 4x4 linear transformation to the MNI space.Included in Brainstorm.
    'uset2',       0);

% Process: Convert DWI to DTI (BrainSuite)
bst_process('CallProcess', 'process_dwi2dti', [], [], ...
    'subjectname', SubjectName, ...
    'dwifile',     {DwiNii, 'DWI-NII'});

% Process: Generate FEM mesh
bst_process('CallProcess', 'process_fem_mesh', [], [], ...
    'subjectname',   SubjectName, ...
    'method',        'brain2mesh', ...  % Brain2mesh:Segment the T1 (and T2) MRI with SPM12, mesh with Brain2mesh
    'zneck',         -115);


%% ===== COMPUTE CONDUCTIVITY TENSORS =====
% Process: Compute FEM tensors
bst_process('CallProcess', 'process_fem_tensors', [], [], ...
    'subjectname', SubjectName, ...
    'femcond',     struct(...
         'FemCond',         [0.14, 0.33, 1.79, 0.008, 0.43], ...
         'isIsotropic',     [0, 1, 1, 1, 1], ...
         'AnisoMethod',     'ema+vc', ...
         'SimRatio',        10, ...
         'SimConstrMethod', 'wolters'));


%% ===== SAVE REPORT =====
% Save and display report
ReportFile = bst_report('Save', []);
bst_report('Open', ReportFile);
