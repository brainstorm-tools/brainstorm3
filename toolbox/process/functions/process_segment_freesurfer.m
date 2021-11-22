function varargout = process_segment_freesurfer( varargin )
% PROCESS_SEGMENT_FREESURFER: Run the segmentation of a T1 MRI with FreeSurfer.
%
% USAGE:     OutputFiles = process_segment_freesurfer('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_segment_freesurfer('Compute', iSubject, iAnatomy=[default], nVertices, isInteractive, param)
%                          process_segment_freesurfer('ComputeInteractive', iSubject, iAnatomy)

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
% Authors: Francois Tadel, 2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Segment MRI with FreeSurfer';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 34;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/LabelFreeSurfer';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Title
    sProcess.options.doc.Comment = ['<HTML><B>FreeSurfer</B> must be installed on the computer:<BR>' ...
                                    'The environment variables <B>FREESURFER_HOME</B> and <B>SUBJECTS_DIR</B> must be set.<BR>' ...
                                    'The command <B>recon-all</B> must be available in the system path.<BR>' ...
                                    'Click "Online tutorial" for installation instructions.<BR><BR>'];
    sProcess.options.doc.Type    = 'label';
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Option: Number of vertices
    sProcess.options.nvertices.Comment = 'Number of vertices (cortex): ';
    sProcess.options.nvertices.Type    = 'value';
    sProcess.options.nvertices.Value   = {15000, '', 0};
    % Option: Extra command-line parameters
    sProcess.options.param.Comment = 'Command-line options:';
    sProcess.options.param.Type    = 'text';
    sProcess.options.param.Value   = '';
    % Option: Delete existing subject
    sProcess.options.delete.Comment = 'Delete FreeSurfer subject if it already exists';
    sProcess.options.delete.Type    = 'checkbox';
    sProcess.options.delete.Value   = 0;
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
    % Get extra parameters
    param = sProcess.options.param.Value;
    isDelete = sProcess.options.delete.Value;
    % Call processing function
    [isOk, errMsg] = Compute(iSubject, [], nVertices, 0, param, isDelete);
    % Handling errors
    if ~isOk
        bst_report('Error', sProcess, [], errMsg);
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== COMPUTE SEGMENTATION =====
function [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, isInteractive, param, isDelete)
    errMsg = '';
    isOk = 0;

    % ===== INSTALL FASTSURFER =====
    bst_progress('text', 'Testing FreeSurfer installation...');
    % Get FreeSurfer path from environment variable
    FreeSurferDir = getenv('FREESURFER_HOME');
    SubjectsDir = getenv('SUBJECTS_DIR');
    if isempty(FreeSurferDir) || ~file_exist(FreeSurferDir) || isempty(SubjectsDir) || ~file_exist(SubjectsDir)
        errMsg = ['FreeSurfer is not installed on your computer.' 10 ...
                  'The environment variables FREESURFER_HOME and SUBJECTS_DIR must be set.' 10 10 ...
                  'See the online Brainstorm tutorial about FreeSurfer for help:' 10 ...
                  'https://neuroimage.usc.edu/brainstorm/Tutorials/LabelFreeSurfer'];
        return
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
    % If subject already exists in FreeSurfer database
    SubjDir = bst_fullfile(SubjectsDir, sSubject.Name);
    if isdir(SubjDir)
        % Delete existing subject
        if isDelete
            isDeleted = file_delete(SubjDir, ~isInteractive, 3);
            if ~isDeleted
                errMsg = ['Could not delete existing subject folder: ' SubjDir];
                return;
            end
        else
            errMsg = ['Subject already exists in FreeSurfer database: ' SubjDir];
            return;
        end
    end
    
    % ===== VERIFY FIDUCIALS IN MRI =====
    bst_progress('text', 'Saving temporary files...');
    % Load MRI file
    T1FileBst = sSubject.Anatomy(iAnatomy).FileName;
    sMri = in_mri_bst(T1FileBst);
    % If the SCS transformation is not defined: compute MNI transformation to get a default one
    if isempty(sMri) || ~isfield(sMri, 'SCS') || ~isfield(sMri.SCS, 'NAS') || ~isfield(sMri.SCS, 'LPA') || ~isfield(sMri.SCS, 'RPA') || (length(sMri.SCS.NAS)~=3) || (length(sMri.SCS.LPA)~=3) || (length(sMri.SCS.RPA)~=3) || ~isfield(sMri.SCS, 'R') || isempty(sMri.SCS.R) || ~isfield(sMri.SCS, 'T') || isempty(sMri.SCS.T)
        % Issue warning
        errMsg = 'Missing NAS/LPA/RPA: Computing the MNI normalization to get default positions.'; 
        % Compute MNI normalization
        [sMri, errNorm] = bst_normalize_mni(T1FileBst);
        % Handle errors
        if ~isempty(errNorm)
            errMsg = [errMsg 10 'Error trying to compute the MNI normalization: ' 10 errNorm 10 ...
                'Missing fiducials: the surfaces cannot be aligned with the MRI.'];
        end
    end

    % ===== SAVE MRI AS NII =====
    % Get temporary folder
    TmpDir = bst_get('BrainstormTmpDir');
    % Save MRI in .nii format
    subjid = strrep(sSubject.Name, '@', '');
    NiiFile = bst_fullfile(TmpDir, [subjid, '.nii']);
    out_mri_nii(sMri, NiiFile);
    % If a "world transformation" was not available in the MRI in the database, it was set to a default when saving to .nii
    % Let's reload this file to get the transformation matrix, it will be used when importing the results
    if ~isfield(sMri, 'InitTransf') || isempty(sMri.InitTransf) || isempty(find(strcmpi(sMri.InitTransf(:,1), 'vox2ras')))
        % Load again the file, with the default vox2ras transformation
        [tmp, vox2ras] = in_mri_nii(NiiFile, 0, 0, 0);
        % Prepare the history of transformations
        if ~isfield(sMri, 'InitTransf') || isempty(sMri.InitTransf)
            sMri.InitTransf = cell(0,2);
        end
        % Add this transformation in the MRI
        sMri.InitTransf(end+1,[1 2]) = {'vox2ras', vox2ras};
        % Save modification on hard drive
        bst_save(file_fullpath(T1FileBst), sMri, 'v7');
    end

    % ===== IMPORT MRI =====
    bst_progress('text', '<HTML>Converting MRI... &nbsp;&nbsp;&nbsp;<FONT COLOR="#707070"><I>(see command window)</I></FONT>');
    strCall = ['recon-all -i "' NiiFile '" -subjid ' subjid];
    disp(['BST> System call: ' strCall]);
    status = system(strCall)
    % Error handling
    if (status ~= 0)
        errMsg = ['FreeSurfer MRI conversion failed.', 10, 'Check the Matlab command window for more information.'];
        return
    end

    % ===== RUN FREESURFER =====
    bst_progress('text', '<HTML>Running FreeSurfer recon-all... &nbsp;&nbsp;&nbsp;<FONT COLOR="#707070"><I>(see command window)</I></FONT>');
    strCall = ['recon-all -all -subjid ' subjid];
    disp(['BST> System call: ' strCall]);
    status = system(strCall)
    % Error handling
    if (status ~= 0)
        errMsg = ['FreeSurfer failed.', 10, 'Check the Matlab command window for more information.'];
        return
    end

    % ===== IMPORT OUTPUT FOLDER =====
    % Import FreeSurfer anatomy folder
    isExtraMaps = 0;
    isKeepMri = 1;
    isVolumeAtlas = 1;
    FsDir = bst_fullfile(procDir, subjid);
    errMsg = import_anatomy_fs(iSubject, FsDir, nVertices, isInteractive, sFid, isExtraMaps, isVolumeAtlas, isKeepMri);
    if ~isempty(errMsg)
        return;
    end
    % Return success
    isOk = 1;
end



%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iAnatomy) %#ok<DEFNU>
    % Get inputs
    if (nargin < 2) || isempty(iAnatomy)
        iAnatomy = [];
    end
    % Ask for number of vertices
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'FreeSurfer segmentation', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
    % Ask for extra processing parameters
    param = java_dialog('input', 'Command-line options:', 'FreeSurfer segmentation', [], '');
    % Open progress bar
    bst_progress('start', 'FreeSurfer', 'FreeSurfer MRI segmentation...');
    % Run FreeSurfer
    isInteractive = 1;
    isDelete = 0;
    [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, isInteractive, param, isDelete);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'FreeSurfer MRI segmentation', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end
