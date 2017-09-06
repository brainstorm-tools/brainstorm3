function varargout = process_generate_canonical( varargin )
% PROCESS_GENERATE_CANONICAL: Generate SPM canonical surface.
%
% USAGE:  OutputFiles = process_generate_canonical('Run',     sProcess, sInputs)
%                       process_generate_canonical('Compute', iSubject)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Generate SPM canonical surfaces';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Import anatomy';
    sProcess.Index       = 8;
    sProcess.Description = 'https://github.com/neurodebian/spm12/blob/master/spm_eeg_inv_mesh.m';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, [], 'Subject name is empty.');
        return;
    end
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    if isempty(iSubject)
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" does not exist.']);
        return
    end
    % Call processing function
    Compute(iSubject);
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== COMPUTE CANONICAL SURFACES =====
function isOk = Compute(iSubject, iAnatomy)
    isOk = 0;
    % Parse inputs
    if (nargin < 2) || isempty(iAnatomy)
        iAnatomy = [];
    end
    % Check if SPM is in the path
    if ~exist('spm_eeg_inv_mesh', 'file')
        error('SPM must be in the Matlab path to use this feature.');
    end
    if ~exist('ft_read_headshape', 'file')
        error('SPM subfolders must be in the Matlab path to use this feature (missing: spm12/external/fieldtrip/fileio).');
    end
    
    % ===== GET SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', iSubject);
    if isempty(sSubject)
        bst_report('Error', sProcess, [], 'Subject does not exist.');
        return
    end
    % Check if a MRI is available for the subject
    if isempty(sSubject.Anatomy)
        bst_report('Error', sProcess, [], ['No MRI available for subject "' SubjectName '".']);
        return
    end
    % Get default MRI if not specified
    if isempty(iAnatomy)
        iAnatomy = sSubject.iAnatomy;
    end
    % Progress bar
    isProgress = bst_progress('IsVisible');
    if ~isProgress
        bst_progress('start', 'SPM', 'Generating canonical surfaces...');
    end

    % ===== VERIFY FIDUCIALS IN MRI =====
    % Load MRI file
    MriFileBst = sSubject.Anatomy(iAnatomy).FileName;
    sMri = in_mri_bst(MriFileBst);
    % If the SCS transformation is not defined: compute MNI transformation to get a default one
    if isempty(sMri) || ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'NAS') || ~isfield(sMri.SCS, 'LPA') || ~isfield(sMri.SCS, 'RPA') || (length(sMri.SCS.NAS)~=3) || (length(sMri.SCS.LPA)~=3) || (length(sMri.SCS.RPA)~=3) || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri.SCS, 'T') || isempty(sMri.SCS.T)
        % Issue warning
        bst_report('Warning', 'process_generate_canonical', [], 'Missing NAS/LPA/RPA: Computing the MNI transformation to get default positions.'); 
        % Compute MNI transformation
        [sMri, errMsg] = bst_normalize_mni(MriFileBst);
        % Handle errors
        if ~isempty(errMsg)
            bst_report('Warning', 'process_generate_canonical', [], ['Error trying to compute the MNI transformation: ' 10 errMsg 10 ...
                'The surfaces will not be properly aligned with the MRI.']);
        end
    end
%     % Delete any leftover NIFTI header (we are not trying to save a .nii file with a correct subject transformation)
%     sMri.Header = [];

    % ===== CALL SPM FUNCTIONS =====
    % Save MRI in .nii format
    NiiFile = bst_fullfile(bst_get('BrainstormTmpDir'), 'spm_canonical.nii');
    out_mri_nii(sMri, NiiFile);
    % Call SPM function
    spmMesh = spm_eeg_inv_mesh(NiiFile, 3);

    % ===== READ OUTPUT SURFACES =====
    % Read transformation from temporary .nii
    niiMri = in_mri_nii(NiiFile);
    % Create surfaces
    sHead   = CreateSurface(sMri, niiMri, export(gifti(spmMesh.tess_scalp),'patch'),  'spm_head_');
    sOuter  = CreateSurface(sMri, niiMri, export(gifti(spmMesh.tess_oskull),'patch'), 'spm_outerskull_');
    sInner  = CreateSurface(sMri, niiMri, export(gifti(spmMesh.tess_iskull),'patch'), 'spm_innerskull_');
    sCortex = CreateSurface(sMri, niiMri, export(gifti(spmMesh.tess_ctx),'patch'),    'spm_cortex_');
    
    % ===== SAVE NEW SURFACES =====
    % Create output filenames
    SurfaceDir    = bst_fileparts(file_fullpath(MriFileBst));
    SpmHeadFile   = file_unique(bst_fullfile(SurfaceDir, sprintf('tess_head_spm_%dV.mat', length(sHead.Vertices))));
    SpmOuterFile  = file_unique(bst_fullfile(SurfaceDir, sprintf('tess_outerskull_spm_%dV.mat', length(sOuter.Vertices))));
    SpmInnerFile  = file_unique(bst_fullfile(SurfaceDir, sprintf('tess_innerskull_spm_%dV.mat', length(sInner.Vertices))));
    SpmCortexFile = file_unique(bst_fullfile(SurfaceDir, sprintf('tess_cortex_spm_%dV.mat', length(sCortex.Vertices))));
    % Save head
    bst_save(SpmHeadFile, sHead, 'v7');
    db_add_surface(iSubject, SpmHeadFile, sHead.Comment);
    % Save outerskull
    bst_save(SpmOuterFile, sOuter, 'v7');
    db_add_surface(iSubject, SpmOuterFile, sOuter.Comment);
    % Save innerskull
    bst_save(SpmInnerFile, sInner, 'v7');
    db_add_surface(iSubject, SpmInnerFile, sInner.Comment);
    % Save cortex
    bst_save(SpmCortexFile, sCortex, 'v7');
    db_add_surface(iSubject, SpmCortexFile, sCortex.Comment);
    
    % Empty temporary folder
    gui_brainstorm('EmptyTempFolder');
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
    isOk = 1;
end


%% ===== CREATE SURFACE =====
function sTess = CreateSurface(sMri, niiMri, gii, Comment)
    % Transformation to apply to the surface
    ras2vox = inv(niiMri.Header.nifti.vox2ras);
    % Create surfaces structure
    sTess = db_template('SurfaceMat');
    sTess.Comment  = sprintf('%s_%dV', Comment, length(gii.vertices));
    sTess.Vertices = bst_bsxfun(@plus, ras2vox(1:3,1:3)*gii.vertices', ras2vox(1:3,4))'  ./ 1000;
    sTess.Vertices = sTess.Vertices + [1 1 1] ./ 1000;
    sTess.Vertices = cs_convert(sMri, 'mri', 'scs', sTess.Vertices);
    sTess.Faces    = gii.faces(:,[2 1 3]);
    sTess = bst_history('add', sTess, 'spm', ['Canonical surface generated with: ' spm('version')]);
end


