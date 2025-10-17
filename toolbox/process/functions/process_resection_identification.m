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
    % File selection options
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Import MRI...', ...               % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'files', ...                       % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'mri'), ... % Get all the available file formats
        'MriIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Option: Pre-op MRI file
    sProcess.options.preopmrifile.Comment = 'Pre-op MRI filename:';
    sProcess.options.preopmrifile.Type    = 'filename';
    sProcess.options.preopmrifile.Value   = SelectOptions;
    % Option: Post-op MRI file
    sProcess.options.postopmrifile.Comment = 'Post-op MRI filename:';
    sProcess.options.postopmrifile.Type    = 'filename';
    sProcess.options.postopmrifile.Value   = SelectOptions;
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
    % Get pre-op MRI filename to import
    MriFilePreOp = sProcess.options.preopmrifile.Value{1};
    if (length(sProcess.options.preopmrifile.Value) < 2) || isempty(sProcess.options.preopmrifile.Value{2})
        FileFormatPreOp = 'All';
    else
        FileFormatPreOp = sProcess.options.preopmrifile.Value{2};
    end
    if isempty(MriFilePreOp)
        bst_report('Error', sProcess, [], 'Pre-op MRI file not selected.');
        return
    end
    % Get post-op MRI filename to import
    MriFilePostOp = sProcess.options.postopmrifile.Value{1};
    if (length(sProcess.options.postopmrifile.Value) < 2) || isempty(sProcess.options.postopmrifile.Value{2})
        FileFormatPostOp = 'All';
    else
        FileFormatPostOp = sProcess.options.postopmrifile.Value{2};
    end
    if isempty(MriFilePostOp)
        bst_report('Error', sProcess, [], 'Post-op MRI file not selected.');
        return
    end

    % ===== GET/CREATE SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % Create subject is it does not exist yet
    if isempty(sSubject)
        [sSubject, iSubject] = db_add_subject(SubjectName);
    end
    if isempty(iSubject)
        bst_report('Error', sProcess, [], ['Cannot create subject "' SubjectName '".']);
        return
    end
    % The subject can't be using the default anatomy
    if (iSubject ~= 0) && sSubject.UseDefaultAnat
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" is using the default anatomy (read-only).']);
        return
    end
    % Import pre-op MRI volume
    DbMriFilePreOp  = import_mri(iSubject, MriFilePreOp, FileFormatPreOp, 0, 1, 'preop_mri');
    if isempty(sSubject.Anatomy)
        % MNI normalization (affine)
        bst_normalize_mni(DbMriFilePreOp, 'maff8');
    end
    % Import post-op MRI volume
    DbMriFilePostOp = import_mri(iSubject, MriFilePostOp, FileFormatPostOp, 0, 1, 'postop_mri');

    % Call processing function
    [isOk, errMsg] = Compute(DbMriFilePreOp, DbMriFilePostOp);
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
function [ResecMaskFilePreOp, ResecMaskFilePostOp, MriFilePost2PreOp, errMsg] = Compute(MriFilePreOp, MriFilePostOp)
    ResecMaskFilePreOp  = [];
    ResecMaskFilePostOp = [];
    MriFilePost2PreOp   = [];
    errMsg = '';
    
    disp(['RESEC_ID> pre-op MRI:  ' MriFilePreOp]);
    disp(['RESEC_ID> post-op MRI: ' MriFilePostOp]);

    % Install/load resection-identification plugin
    [isOk, errInstall, PlugDesc] = bst_plugin('Install', 'resection-identification');
    if ~isOk
        errMsg = [errMsg, errInstall];
        return;
    end

    % === SAVE BOTH MRI AS NIfTI ===
    bst_progress('start', 'Resection identification', 'Exporting pre- and post-op MRI...');
    % Create temporary folder
    TmpDir = bst_get('BrainstormTmpDir', 0, 'resection_identification');
    % Save pre-op MRI
    preOpNii = bst_fullfile(TmpDir, 'preop.nii');
    out_mri_nii(sMriPreOp, preOpNii);
    % Save post-op MRI
    postOpNii = bst_fullfile(TmpDir, 'postop.nii');
    out_mri_nii(sMriPostOp, postOpNii);
    
    % === CALL RESECTION-IDENTIFICATION PIPELINE ===
    bst_progress('text', 'Calling resection-identification...');
    % Get resection-identification executable
    ResecExe = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, 'resection_identification');
    if ispc
        ResecExe = [ResecExe, '.bat'];
    end
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
    disp(['RESEC_ID > Computation completed in: ' num2str(toc) 's']);

    % === SAVE OUTPUTS ===
    bst_progress('text', 'Saving outputs...');
    % Get subject
    [~, iSubject] = bst_get('MriFile', MriFilePreOp);
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
    % Close progress bar
    bst_progress('stop');
end