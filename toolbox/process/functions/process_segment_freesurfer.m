function varargout = process_segment_freesurfer( varargin )
% PROCESS_SEGMENT_FREESURFER: Run the segmentation of a T1/T2 MRI with FreeSurfer.
%
% USAGE:     OutputFiles = process_segment_freesurfer('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_segment_freesurfer('Compute', iSubject, iMris=[default], nVertices, isInteractive, param)
%                          process_segment_freesurfer('ComputeInteractive', iSubject, iMris)

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
                                    'The FreeSurfer environment variables must be set:<BR>' ...
                                    '<B>FREESURFER_HOME</B> and <B>SUBJECTS_DIR</B><BR>' ...
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
    % Option: Asynchronous
    sProcess.options.async.Comment = '<HTML><BR>Run asynchronously<FONT color="#707070"><BR>Start recon-all in a separate process<BR>Output must be imported manually when done</FONT>';
    sProcess.options.async.Type    = 'checkbox';
    sProcess.options.async.Value   = 0;
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
    isAsync = sProcess.options.async.Value;
    % Call processing function
    [isOk, errMsg] = Compute(iSubject, [], nVertices, 0, param, isDelete, isAsync);
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
function [isOk, errMsg] = Compute(iSubject, iMris, nVertices, isInteractive, param, isDelete, isAsync)
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

    % ===== GET T1/T2 MRI =====
    % Get subject 
    [sSubject, T1File, T2File, errMsg] = process_fem_mesh('GetT1T2', iSubject, iMris);
    if ~isempty(errMsg)
        return;
    end
    % Process comment
    if ~isempty(T2File)
        strT1T2 = '(T1+T2)';
    else
        strT1T2 = '(T1 only)';
    end

    % ===== CHECK FREESURFER DATABASE ====
    % If subject already exists in FreeSurfer database
    SubjDir = bst_fullfile(SubjectsDir, sSubject.Name);
    if isdir(SubjDir)
        % Delete existing subject
        if isDelete
            if isInteractive
                isConfirm = java_dialog('confirm', ['Subject already exists in FreeSurfer database: ' 10 SubjDir 10 10 ...
                    'Delete folder and run FreeSurfer again?'], 'FreeSurfer database');
                if ~isConfirm
                    errMsg = ['Subject "' sSubject.Name '" already exists in FreeSurfer database'];
                    return;
                end
            end
            isDeleted = file_delete(SubjDir, ~isInteractive, 3);
            if ~isDeleted
                errMsg = ['Could not delete existing subject folder: ' 10 SubjDir];
                return;
            end
        else
            errMsg = ['Subject already exists in FreeSurfer database: ' 10 SubjDir];
            return;
        end
    end
    
    % ===== VERIFY FIDUCIALS IN MRI =====
    bst_progress('text', ['Saving temporary files ' strT1T2 '...']);
    % Load MRI file
    sMriT1 = in_mri_bst(T1File);
    % If the SCS transformation is not defined: compute MNI transformation to get a default one
    if isempty(sMriT1) || ~isfield(sMriT1, 'SCS') || ~isfield(sMriT1.SCS, 'NAS') || ~isfield(sMriT1.SCS, 'LPA') || ~isfield(sMriT1.SCS, 'RPA') || (length(sMriT1.SCS.NAS)~=3) || (length(sMriT1.SCS.LPA)~=3) || (length(sMriT1.SCS.RPA)~=3) || ~isfield(sMriT1.SCS, 'R') || isempty(sMriT1.SCS.R) || ~isfield(sMriT1.SCS, 'T') || isempty(sMriT1.SCS.T)
        % Issue warning
        errMsg = 'Missing NAS/LPA/RPA: Computing the MNI normalization to get default positions.'; 
        % Compute MNI normalization
        [sMriT1, errNorm] = bst_normalize_mni(T1File);
        % Handle errors
        if ~isempty(errNorm)
            errMsg = [errMsg 10 'Error trying to compute the MNI normalization: ' 10 errNorm 10 ...
                'Missing fiducials: the surfaces cannot be aligned with the MRI.'];
        end
    end

    % ===== SAVE T1 MRI AS NII =====
    % Get temporary folder
    TmpDir = bst_get('BrainstormTmpDir');
    % Save MRI in .nii format
    subjid = strrep(sSubject.Name, '@', '');
    T1Nii = bst_fullfile(TmpDir, [subjid, 'T1.nii']);
    out_mri_nii(sMriT1, T1Nii);
    % If a "world transformation" was not available in the MRI in the database, it was set to a default when saving to .nii
    % Let's reload this file to get the transformation matrix, it will be used when importing the results
    if ~isfield(sMriT1, 'InitTransf') || isempty(sMriT1.InitTransf) || isempty(find(strcmpi(sMriT1.InitTransf(:,1), 'vox2ras')))
        % Load again the file, with the default vox2ras transformation
        [tmp, vox2ras] = in_mri_nii(T1Nii, 0, 0, 0);
        % Prepare the history of transformations
        if ~isfield(sMriT1, 'InitTransf') || isempty(sMriT1.InitTransf)
            sMriT1.InitTransf = cell(0,2);
        end
        % Add this transformation in the MRI
        sMriT1.InitTransf(end+1,[1 2]) = {'vox2ras', vox2ras};
        % Save modification on hard drive
        bst_save(file_fullpath(T1File), sMriT1, 'v7');
    end

    % ===== SAVE T2 MRI AS NII =====
    if ~isempty(T2File)
        % Load T2 file
        sMriT2 = in_mri_bst(T2File);
        % Save T2 .nii
        T2Nii = bst_fullfile(TmpDir, [subjid 'T2.nii']);
        out_mri_nii(sMriT2, T2Nii);
        % Check the size of the volumes
        if ~isequal(size(sMriT1.Cube), size(sMriT2.Cube)) || ~isequal(size(sMriT1.Voxsize), size(sMriT2.Voxsize))
            errMsg = [errMsg, 'Input images have different dimension, you must register and reslice them first.' 10 ...
                      sprintf('T1:(%d x %d x %d),   T2:(%d x %d x %d)', size(sMriT1.Cube), size(sMriT2.Cube))];
            return;
        end
    else
        T2Nii = [];
    end

    % ===== RUN FREESURFER =====
    % T1+T2
    if ~isempty(T2File)
        strCall = ['recon-all -all -subject "' subjid '" -i "' T1Nii '" -T2 "' T2Nii '" -T2pial ' param];
    % T1 only
    else
        strCall = ['recon-all -all -subject "' subjid '" -i "' T1Nii '" ' param];
    end
    % Async call
    if isAsync
        LogFile = bst_fullfile(TmpDir, ['recon-all-' subjid '.log']);
        strCall = [strCall, ' > ' LogFile ' &'];
        disp(['BST> System call: ' strCall]);
        disp([10 'BST> For following the execution of FreeSurfer, open a terminal and run: ' 10 ...
              '     tail -f ' LogFile]);
        disp([10 'BST> For stopping all the executions of FreeSurfer, run one of the following: ' 10 ...
              '     pkill -f recon-all' 10 ...
              '     killall recon-all']);
        disp([10 'BST> For listing the current FreeSurfer processes, run: ' 10 ...
              '     ps -aux | grep recon-all' 10]);
        % Run execution
        status = system(strCall);
    % Sync call
    else
        bst_progress('text', ['<HTML>Running FreeSurfer recon-all ' strT1T2 '...<BR><FONT COLOR="#707070"><I>(see command window)</I></FONT>']);
        disp(['BST> System call: ' strCall]);
        % Run execution
        status = system(strCall)
    end

    % Error handling
    if (status ~= 0)
        errMsg = ['FreeSurfer recon-all failed.', 10, 'Check the Matlab command window for more information.'];
        return
    end

    % ===== IMPORT OUTPUT FOLDER =====
    % Import FreeSurfer anatomy folder (sync call only)
    if ~isAsync
        isExtraMaps = 0;
        isKeepMri = 1;
        isVolumeAtlas = 1;
        errMsg = import_anatomy_fs(iSubject, SubjDir, nVertices, isInteractive, [], isExtraMaps, isVolumeAtlas, isKeepMri);
        if ~isempty(errMsg)
            return;
        end
    end
    % Return success
    isOk = 1;
end



%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iMris) %#ok<DEFNU>
    % Get inputs
    if (nargin < 2) || isempty(iMris)
        iMris = [];
    end
    % Ask for extra processing parameters
    [param, isCancel] = java_dialog('input', '<HTML>Extra command-line options:<BR><BR><FONT color="#707070">See FreeSurfer wiki for help:<BR>https://surfer.nmr.mgh.harvard.edu/fswiki/recon-all</FONT><BR><BR>', 'FreeSurfer segmentation', [], '');
    if isCancel
        return;
    end
    % Ask for number of vertices
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'FreeSurfer segmentation', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
    % Open progress bar
    bst_progress('start', 'FreeSurfer', 'FreeSurfer MRI segmentation...');
    % Run FreeSurfer
    isInteractive = 1;
    isDelete = 1;
    isAsync = 0;
    [isOk, errMsg] = Compute(iSubject, iMris, nVertices, isInteractive, param, isDelete, isAsync);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'FreeSurfer MRI segmentation', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end
