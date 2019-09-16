function varargout = process_segment_cat12( varargin )
% PROCESS_SEGMENT_CAT12: Run the segmentation of a T1 MRI with SPM12/CAT12.
%
% USAGE:     OutputFiles = process_segment_cat12('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_segment_cat12('Compute', iSubject, iAnatomy=[default])

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
% Authors: Francois Tadel, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Segment MRI with SPM12/CAT12';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 32;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SegCAT12';
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
    % Option: Number of vertices
    sProcess.options.nvertices.Comment = 'Number of vertices (cortex): ';
    sProcess.options.nvertices.Type    = 'value';
    sProcess.options.nvertices.Value   = {15000, '', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Number of vertices
    nVertices = sProcess.options.nvertices.Value{1};
    if isempty(nVertices) || (nVertices < 50)
        bst_report('Error', sProcess, [], 'Invalid number of vertices.');
        return
    end
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
    [isOk, errMsg] = Compute(iSubject, [], nVertices, 0);
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
function [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, isInteractive)
    isOk = 0;
    errMsg = '';
    % Initialize SPM
    bst_spm_init(isInteractive, 'cat12');
    % Check if SPM is in the path
    if ~exist('spm_jobman', 'file')
        errMsg = 'SPM must be in the Matlab path to use this feature.';
        return;
    end
    % Check if CAT12 is in the path
    if ~exist('cat12', 'file')
        errMsg = 'SPM subfolders must be in the Matlab path to use this feature (missing: spm12/toolbox/cat12).';
        return;
    end
    % Check DARTEL template
    dartelTpm = bst_fullfile(bst_get('SpmDir'), 'toolbox', 'cat12', 'templates_1.50mm', 'Template_1_IXI555_MNI152.nii');
    if ~file_exist(dartelTpm)
        errMsg = ['Missing CAT12 template: ' 10 dartelTpm];
        return;
    end
    
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

    % ===== DELETE EXISTING SURFACES =====
    if ~isempty(sSubject.Surface)
        % Ask user whether the previous anatomy should be removed
        if isInteractive
            isDel = java_dialog('confirm', ['Warning: There are already surfaces available for this subject.' 10 10 ...
                'Delete the existing surfaces?' 10 10], 'CAT12 segmentation');
        else
            isDel = 1;
        end
        % If user canceled process
        if ~isDel
            errMsg = 'Process aborted by user.';
            return;
        end
        % Delete anatomy
        isKeepMri = 1;
        sSubject = db_delete_anatomy(iSubject, isKeepMri);
    end
    
    % ===== VERIFY FIDUCIALS IN MRI =====
    % Load MRI file
    MriFileBst = sSubject.Anatomy(iAnatomy).FileName;
    sMri = in_mri_bst(MriFileBst);
    % If the SCS transformation is not defined: compute MNI transformation to get a default one
    if isempty(sMri) || ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'NAS') || ~isfield(sMri.SCS, 'LPA') || ~isfield(sMri.SCS, 'RPA') || (length(sMri.SCS.NAS)~=3) || (length(sMri.SCS.LPA)~=3) || (length(sMri.SCS.RPA)~=3) || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri.SCS, 'T') || isempty(sMri.SCS.T)
        % Issue warning
        errMsg = 'Missing NAS/LPA/RPA: Computing the MNI transformation to get default positions.'; 
        % Compute MNI transformation
        [sMri, errNorm] = bst_normalize_mni(MriFileBst);
        % Handle errors
        if ~isempty(errNorm)
            errMsg = [errMsg 10 'Error trying to compute the MNI transformation: ' 10 errNorm 10 ...
                'The surfaces will not be properly aligned with the MRI.'];
        end
    end

    % ===== SAVE MRI AS NII =====
    % Empty temporary folder, otherwise it reuses previous files in the folder
    gui_brainstorm('EmptyTempFolder');
    % Save MRI in .nii format
    catDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'cat12');
    mkdir(catDir);
    NiiFile = bst_fullfile(catDir, 'spm_cat12.nii');
    out_mri_nii(sMri, NiiFile);

    % ===== CALL CAT12 SEGMENTATION =====
    % Get TPM.nii template
    tpmFile = bst_get('SpmTpmAtlas');
    if isempty(tpmFile) || ~file_exist(tpmFile)
        error('Missing file TPM.nii');
    end
    % Create SPM batch
    matlabbatch{1}.spm.tools.cat.estwrite.data = {[NiiFile ',1']};
    matlabbatch{1}.spm.tools.cat.estwrite.nproc = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.opts.tpm = {tpmFile};
    matlabbatch{1}.spm.tools.cat.estwrite.opts.affreg = 'mni';
    matlabbatch{1}.spm.tools.cat.estwrite.opts.biasstr = 0.5;
    matlabbatch{1}.spm.tools.cat.estwrite.opts.accstr = 0.5;
    matlabbatch{1}.spm.tools.cat.estwrite.extopts.APP = 1070;
    matlabbatch{1}.spm.tools.cat.estwrite.extopts.LASstr = 0.5;
    matlabbatch{1}.spm.tools.cat.estwrite.extopts.gcutstr = 2;
    matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.dartel.darteltpm = {dartelTpm};
    matlabbatch{1}.spm.tools.cat.estwrite.extopts.vox = 1.5;
    matlabbatch{1}.spm.tools.cat.estwrite.extopts.restypes.fixed = [1 0.1];
    matlabbatch{1}.spm.tools.cat.estwrite.output.surface = 1;
    matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.neuromorphometrics = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.lpba40 = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.cobra = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.hammers = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.GM.native = 1;
    matlabbatch{1}.spm.tools.cat.estwrite.output.GM.mod = 1;
    matlabbatch{1}.spm.tools.cat.estwrite.output.GM.dartel = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.WM.native = 1;
    matlabbatch{1}.spm.tools.cat.estwrite.output.WM.mod = 1;
    matlabbatch{1}.spm.tools.cat.estwrite.output.WM.dartel = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.labelnative = 1;
    matlabbatch{1}.spm.tools.cat.estwrite.output.bias.warped = 1;
    matlabbatch{1}.spm.tools.cat.estwrite.output.jacobianwarped = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.warps = [0 0];
    % Run SPM batch
    spm_jobman('initcfg');
    spm_jobman('run',matlabbatch);
        
    % ===== IMPORT OUTPUT FOLDER =====
    % Import CAT12 anatomy folder
    isExtraMaps = 0;
    isKeepMri = 1;
    errorMsg = import_anatomy_cat(iSubject, catDir, nVertices, isInteractive, [], isExtraMaps, isKeepMri);
    if ~isempty(errorMsg)
        return;
    end
    % Delete temporary folder
    file_delete(catDir, 1, 3);
    
    isOk = 1;
end



%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iAnatomy) %#ok<DEFNU>
    % Get inputs
    if (nargin < 2) || isempty(iAnatomy)
        iAnatomy = [];
    end
    % Open progress bar
    bst_progress('start', 'CAT12', 'CAT12 MRI segmentation...');
    bst_progress('setimage', 'logo_splash_cat.gif');
    % Ask for number of vertices
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'CAT12 segmentation', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
    % Compute surfaces
    [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, 1);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'CAT12 MRI segmentation', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end
