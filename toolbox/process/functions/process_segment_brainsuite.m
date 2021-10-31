function varargout = process_segment_brainsuite( varargin )
% PROCESS_SEGMENT_BRAINSUITE: Run the segmentation of a T1 MRI with BrainSuite.
%
% USAGE:     OutputFiles = process_segment_brainsuite('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_segment_brainsuite('Compute', iSubject, iAnatomy=[default], nVertices, isInteractive)
%                          process_segment_brainsuite('ComputeInteractive', iSubject, iAnatomy)

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
    sProcess.Comment     = 'Segment MRI with BrainSuite';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 32;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SegBrainSuite';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Title
    sProcess.options.doc.Comment = ['<HTML><B>BrainSuite</B> must be installed on the computer,<BR>' ...
                                    'the command "bse" must be available in the system path.<BR>' ...
                                    'Website: http://brainsuite.org<BR><BR>'];
    sProcess.options.doc.Type    = 'label';
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


%% ===== COMPUTE BRAINSUITE SEGMENTATION =====
function [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, isInteractive)
    errMsg = '';
    isOk = 0;

    % ===== INSTALL BRAINSUITE =====
    bst_progress('text', 'Testing BrainSuite installation...');
    % Get BrainSuite path from Brainstorm preferences
    BsDir = bst_get('BrainSuiteDir');
    % Get executable names
    if ispc
        cse_exe = fullfile(BsDir, 'bin', 'cortical_extraction.cmd');
        svreg_exe = fullfile(BsDir, 'svreg', 'bin', 'svreg.exe');
    else
        cse_exe = fullfile(BsDir, 'bin', 'cortical_extraction.sh');
        svreg_exe = fullfile(BsDir, 'svreg', 'bin', 'svreg.sh');
    end
    % Check BrainSuite installation
    if isempty(BsDir) || ~file_exist(cse_exe)
        errMsg = ['BrainSuite is not installed on your computer.' 10 ...
                      'Download it from http://brainsuite.org and install it.' 10 ...
                      'Then set its installation folder in the Brainstorm options (File > Edit preferences)'];
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
    
    % ===== VERIFY FIDUCIALS IN MRI =====
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
    bst_progress('text', 'Saving temporary files...');
    % Empty temporary folder, otherwise it reuses previous files in the folder
    gui_brainstorm('EmptyTempFolder');
    % Create temporay folder for BrainSuite output
    procDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'brainsuite');
    if file_exist(procDir)
        file_delete(procDir, 1, 3);
    end
    mkdir(procDir);
    % Save MRI in .nii format
    subjid = strrep(sSubject.Name, '@', '');
    NiiFile = bst_fullfile(procDir, [subjid, '.nii']);
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

    % ===== 1. CORTICATL EXTRACTION =====
    bst_progress('text', '<HTML>1/2: Cortical extraction... &nbsp;&nbsp;&nbsp;<FONT COLOR="#707070"><I>(see command window)</I></FONT>');
    strCall = ['"' cse_exe '" "' NiiFile(1:end-4) '"'];
    disp(['BST> System call: ' strCall]);
    status = system(strCall)
    % Error handling
    if (status ~= 0)
        errMsg = ['BrainSuite failed at step 1/2 (Cortical extraction).', 10, 'Check the Matlab command window for more information.'];
        return    
    end

    % ===== 2. SVREG =====
    bst_progress('text', '<HTML>2/2: SVREG... &nbsp;&nbsp;&nbsp;<FONT COLOR="#707070"><I>(see command window)</I></FONT>');
    AtlasPath = fullfile(BsDir, 'svreg', 'BrainSuiteAtlas1', 'mri');
    strCall = ['"' svreg_exe '" "' NiiFile(1:end-4) '" "' AtlasPath '"'];
    disp(['BST> System call: ' strCall]);
    status = system(strCall)
    % Error handling
    if (status ~= 0)
        errMsg = ['BrainSuite failed at step 2/2 (SVREG).', 10, 'Check the Matlab command window for more information.'];
        return
    end

    % ===== 3. SKULL EXTRACTION =====
    % cmd=[skullfinder_exe,' -i ', subbasename,'.nii.gz -o ',subbasename,'.skull.label.nii.gz -m ',subbasename,'.mask.nii.gz --scalplabel ',subbasename,'.scalp.label.nii.gz -s ',subbasename];
    % '$HOME/BrainSuite21a/bin/skullfinder' -i subject.nii.gz -o subject.skull.label.nii.gz -m subject.mask.nii.gz -s subject
    % 
    % Anand 28-Oct-2022: There is a caveat. It seems that due to a bug in the executable, outer skull and scalp surfaces are swapped.
    % For now, we can write a code that swaps subject.scalp.dfs and subject.outer_skull.dfs

    % ===== IMPORT OUTPUT FOLDER =====
    % Import BrainSuite anatomy folder
    isKeepMri = 1;
    isVolumeAtlas = 1;
    errMsg = import_anatomy_bs(iSubject, procDir, nVertices, isInteractive, [], isVolumeAtlas, isKeepMri);
    if ~isempty(errMsg)
        return;
    end
    % Delete temporary folder
    % file_delete(procDir, 1, 3);
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
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'BrainSuite segmentation', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
    % Open progress bar
    bst_progress('start', 'BrainSuite', 'BrainSuite MRI segmentation...');
    % Run BrainSuite
    isInteractive = 1;
    [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, isInteractive);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'BrainSuite MRI segmentation', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end
