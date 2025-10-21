function varargout = process_resection_identification( varargin )
% PROCESS_RESECTION_IDENTIFICATION: Deliniate surgical resection mask using pre- and post-op MRIs.
%
% USAGE:                                                           OutputFiles = process_resection_identification('Run',     sProcess, sInputs)
%         [ResecMaskFilePreOp, ResecMaskFilePostOp, MriFilePost2PreOp, errMsg] = process_resection_identification('Compute', MriFilePreOp, MriFilePostOp)

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
% Authors: Chinmay Chinara, 2025
%          Anand A. Joshi, 2025

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Resection identifcation';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 42;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SegBrainSuite#Resection_labeling';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Option: Post-op MRI name
    sProcess.options.postopmriname.Comment = 'Post-op MRI name:';
    sProcess.options.postopmriname.Type    = 'text';
    sProcess.options.postopmriname.Value   = '';
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
    if isempty(sSubject)
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" does not exist.']);
        return
    end
    if isempty(sSubject.iAnatomy)
        bst_report('Error', sProcess, [], 'Pre-op (default) MRI does not exist. Import it and define the fiducials.');
        return
    end
    % The subject can't be using the default anatomy
    if (iSubject ~= 0) && sSubject.UseDefaultAnat
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" is using the default anatomy (read-only).']);
        return
    end
    % Get post-op MRI
    PostOpMriName = sProcess.options.postopmriname.Value;
    iPostOpMri = find(strcmp({sSubject.Anatomy.Comment},  PostOpMriName) | ...
                      strcmp({sSubject.Anatomy.FileName}, PostOpMriName));
    if isempty(iPostOpMri)
        bst_report('Error', sProcess, [], 'Post-op MRI is either missing or its name is incorrect.');
        return
    end
    % Make sure the post-op MRI name entered is not the pre-op (default) MRI
    if strcmp(sSubject.Anatomy(iPostOpMri).FileName, sSubject.Anatomy(sSubject.iAnatomy).FileName)
        bst_report('Error', sProcess, [], 'The post-op MRI should cannot be the pre-op (default) MRI. Enter the correct name.');
        return
    end

    % Call processing function
    [isOk, errMsg] = Compute(sSubject.Anatomy(sSubject.iAnatomy).FileName, sSubject.Anatomy(iPostOpMri).FileName, 0);
    % Handling errors
    if ~isOk
        bst_report('Error', sProcess, [], errMsg);
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== COMPUTE RESECTION-IDENTIFICATION =====
function [isOk, errMsg, ResecMaskFilePreOp, ResecMaskFilePostOp, MriFilePost2PreOp] = Compute(MriFilePreOp, MriFilePostOp, isInteractive)
    isOk = 0;
    errMsg = '';
    ResecMaskFilePreOp  = [];
    ResecMaskFilePostOp = [];
    MriFilePost2PreOp   = [];
    
    disp(['RESEC_ID> pre-op MRI:  ' MriFilePreOp]);
    disp(['RESEC_ID> post-op MRI: ' MriFilePostOp]);
    
    % Verify fiducials in pre-op MRI
    sMriPreOp = in_mri_bst(MriFilePreOp);
    if isempty(sMriPreOp) || ~isfield(sMriPreOp, 'SCS') || ...
       ~isfield(sMriPreOp.SCS, 'NAS') || ~isfield(sMriPreOp.SCS, 'LPA') || ~isfield(sMriPreOp.SCS, 'RPA') || ...
       (length(sMriPreOp.SCS.NAS)~=3) || (length(sMriPreOp.SCS.LPA)~=3) || (length(sMriPreOp.SCS.RPA)~=3) || ...
       ~isfield(sMriPreOp.SCS, 'R') || isempty(sMriPreOp.SCS.R) || ~isfield(sMriPreOp.SCS, 'T') || isempty(sMriPreOp.SCS.T)
        errMsg = 'The fiducials (NAS, LPA, RPA) are missing in the pre-op (default) MRI. Set them first before proceeding.';
        return;
    end

    % Install/load resection-identification plugin
    [isOk, errInstall, PlugDesc] = bst_plugin('Install', 'resection-identification', isInteractive);
    if ~isOk
        errMsg = [errMsg, errInstall];
        return;
    end

    % === SAVE BOTH MRI AS NIfTI ===
    bst_progress('text', 'Exporting pre- and post-op MRI...');
    % Create temporary folder
    TmpDir = bst_get('BrainstormTmpDir', 0, 'resection_identification');
    % Save pre-op MRI
    preOpNii = bst_fullfile(TmpDir, 'preop.nii');
    out_mri_nii(sMriPreOp, preOpNii);
    % Save post-op MRI
    postOpNii = bst_fullfile(TmpDir, 'postop.nii');
    sMriPostOp = in_mri_bst(MriFilePostOp);
    out_mri_nii(sMriPostOp, postOpNii);
    
    % === CALL RESECTION-IDENTIFICATION PIPELINE ===
    bst_progress('text', 'Calling resection-identification...');
    % Get resection-identification executable
    ResecExe = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, PlugDesc.TestFile);
    % Call resection-identification
    strCall = ['"' ResecExe '"' ' ' '"' preOpNii '"' ' ' '"' postOpNii '"' ' ' '"' TmpDir '"'];
    disp(['RESEC_ID > System call: ' strCall]);
    tic;
    status = system(strCall);
    if (status ~= 0)
        errMsg = 'Error during resection-identification, see logs in the command window.';
        bst_progress('stop');
        return;
    end
    disp(['RESEC_ID > Computation completed in: ' num2str(round(toc)) ' s']);

    % === SAVE OUTPUTS ===
    bst_progress('text', 'Saving outputs...');
    % Get subjects
    [~, iSubject]  = bst_get('MriFile', MriFilePreOp);
    % Post-op MRI surgical resection mask warped in pre-op space
    ResecMaskPreOpNii   = bst_fullfile(TmpDir, 'preop.resection.mask.nii.gz');
    ResecMaskFilePreOp  = import_mri(iSubject, ResecMaskPreOpNii,  'ALL-ATLAS', 0, 1, 'preop_resection_mask');
    import_surfaces(iSubject, ResecMaskFilePreOp,  'MRI-MASK', 0, [], [], 'preop_resection');
    % Post-op MRI surgical resection mask
    ResecMaskPostOpNii  = bst_fullfile(TmpDir, 'postop.resection.mask.nii.gz');
    ResecMaskFilePostOp = import_mri(iSubject, ResecMaskPostOpNii, 'ALL-ATLAS', 0, 1, 'postop_resection_mask');
    import_surfaces(iSubject, ResecMaskFilePostOp, 'MRI-MASK', 0, [], [], 'postop_resection'); 
    % Post-op MRI non-linearly coregisterd to pre-op MRI
    Post2PreOpNii  = bst_fullfile(TmpDir, 'postop.nonlin.post2pre.nii.gz');
    MriFilePost2PreOp = import_mri(iSubject, Post2PreOpNii, 'Nifti1', 0, 1, 'postop_coreg_preop');
    
    % Delete the temporary files
    file_delete(TmpDir, 1, 1);
    % Return success
    isOk = 1;
end

%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(MriFilePreOp, MriFilePostOp) %#ok<DEFNU>
    % Open progress bar
    bst_progress('start', 'Resection identification', 'Starting resection-identification...');
    % Run resection identification
    [isOk, errMsg] = Compute(MriFilePreOp, MriFilePostOp, 1);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'Resection identification', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end