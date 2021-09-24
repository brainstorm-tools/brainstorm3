function varargout = process_generate_canonical( varargin )
% PROCESS_GENERATE_CANONICAL: Generate SPM canonical surface.
%
% USAGE:     OutputFiles = process_generate_canonical('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_generate_canonical('Compute', iSubject, iAnatomy=[default], Resolution)
%                          process_generate_canonical('ComputeInteractive', iSubject, iAnatomy=[default], Resolution)

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
% Authors: Francois Tadel, 2017-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Generate SPM canonical surfaces';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 12;
    sProcess.Description = 'https://github.com/neurodebian/spm12/blob/master/spm_eeg_inv_mesh.m';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Option: Cortex resolution
    sProcess.options.resolution.Comment = {'5124', '8196', '20484', 'Cortex surface resolution:'};
    sProcess.options.resolution.Type    = 'radio_line';
    sProcess.options.resolution.Value   = 3;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get resolution
    Resolution = sProcess.options.resolution.Value;
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
    [isOk, errMsg] = Compute(iSubject, [], Resolution, 0);
    % Handling errors
    if ~isOk
        bst_report('Error', sProcess, [], errMsg);
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== COMPUTE CANONICAL SURFACES =====
function [isOk, errMsg] = Compute(iSubject, iAnatomy, Resolution, isInteractive)
    isOk = 0;
    % Initialize SPM
    [isInstalled, errMsg] = bst_plugin('Install', 'spm12', isInteractive);
    if ~isInstalled
        return;
    end
    bst_plugin('SetProgressLogo', 'spm12');

    % ===== GET SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', iSubject);
    if isempty(sSubject)
        errMsg = 'Subject does not exist.';
        return
    end
    % Check if a MRI is available for the subject
    if isempty(sSubject.Anatomy)
        errMsg = ['No MRI available for subject "' SubjectName '".'];
        return
    end
    % Get default MRI if not specified
    if isempty(iAnatomy)
        iAnatomy = sSubject.iAnatomy;
    end

    % ===== VERIFY FIDUCIALS IN MRI =====
    % Load MRI file
    MriFileBst = sSubject.Anatomy(iAnatomy).FileName;
    sMri = in_mri_bst(MriFileBst);
    % If the SCS transformation is not defined: compute MNI transformation to get a default one
    if isempty(sMri) || ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'NAS') || ~isfield(sMri.SCS, 'LPA') || ~isfield(sMri.SCS, 'RPA') || (length(sMri.SCS.NAS)~=3) || (length(sMri.SCS.LPA)~=3) || (length(sMri.SCS.RPA)~=3) || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri.SCS, 'T') || isempty(sMri.SCS.T)
        % Issue warning
        errMsg = 'Missing NAS/LPA/RPA: Computing the MNI transformation to get default positions.'; 
        % Compute MNI normalization
        [sMri, errNorm] = bst_normalize_mni(MriFileBst);
        % Handle errors
        if ~isempty(errNorm)
            errMsg = [errMsg 10 'Error trying to compute the MNI transformation: ' 10 errNorm 10 ...
                'The surfaces will not be properly aligned with the MRI.'];
        end
    end

    % ===== CALL SPM FUNCTIONS =====
    % Empty temporary folder, otherwise it reuses previous files in the folder
    gui_brainstorm('EmptyTempFolder');
    % Save MRI in .nii format
    NiiFile = bst_fullfile(bst_get('BrainstormTmpDir'), 'spm_canonical.nii');
    out_mri_nii(sMri, NiiFile);
    % Call SPM function
    switch (Resolution)
        case {1,2,3}
            spmMesh = spm_eeg_inv_mesh(NiiFile, Resolution);
        case 4
            spmMesh = ImaGIN_spm_eeg_inv_mesh(NiiFile, Resolution);
        otherwise
            error('Unsupported resolution.');
    end
    % ===== READ OUTPUT SURFACES =====
    % Read transformation from temporary .nii
    niiMri = in_mri_nii(NiiFile, 0, 0, 0);
    % Create surfaces
    sHead   = CreateSurface(sMri, niiMri, export(gifti(spmMesh.tess_scalp),'patch'),  'spm_head');
    sOuter  = CreateSurface(sMri, niiMri, export(gifti(spmMesh.tess_oskull),'patch'), 'spm_outerskull');
    sInner  = CreateSurface(sMri, niiMri, export(gifti(spmMesh.tess_iskull),'patch'), 'spm_innerskull');
    sCortex = CreateSurface(sMri, niiMri, export(gifti(spmMesh.tess_ctx),'patch'),    'spm_cortex');
    
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
    
    % Remove logo
    bst_plugin('SetProgressLogo', []);
    isOk = 1;
end


%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iAnatomy, Resolution) %#ok<DEFNU>
    % Get inputs
    if (nargin < 2) || isempty(iAnatomy)
        iAnatomy = [];
    end
    if (nargin < 3) || isempty(Resolution)
        strRes = java_dialog('question', 'Cortex surface resolution:', 'SPM canonical mesh', [], {'5124', '8196', '20484'}, '20484');
        if isempty(strRes)
            return;
        end
        switch (strRes)
            case '5124',  Resolution = 1;
            case '8196',  Resolution = 2;
            case '20484', Resolution = 3;
        end
    end
    % Open progress bar
    bst_progress('start', 'SPM', 'Generating canonical surfaces...');
    % Compute surfaces
    [isOk, errMsg] = Compute(iSubject, iAnatomy, Resolution, 1);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'SPM canonical surfaces', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end


%% ===== CREATE SURFACE =====
function sTess = CreateSurface(sMri, niiMri, gii, Comment)
    % Transformation to apply to the surface
    ras2vox = inv(niiMri.Header.nifti.vox2ras);
    % Create surfaces structure
    sTess = db_template('SurfaceMat');
    sTess.Comment  = sprintf('%s_%dV', Comment, length(gii.vertices));
    sTess.Vertices = bst_bsxfun(@plus, ras2vox(1:3,1:3)*gii.vertices', ras2vox(1:3,4))';
    sTess.Vertices = bst_bsxfun(@plus, sTess.Vertices, [1 1 1]);
    sTess.Vertices = cs_convert(sMri, 'voxel', 'scs', sTess.Vertices);
    sTess.Faces    = gii.faces(:,[2 1 3]);
    sTess = bst_history('add', sTess, 'spm', ['Canonical surface generated with: ' spm('version')]);
end


