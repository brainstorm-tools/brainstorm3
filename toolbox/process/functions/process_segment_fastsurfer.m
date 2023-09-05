function varargout = process_segment_fastsurfer( varargin )
% PROCESS_SEGMENT_FASTSURFER: Run the segmentation of a T1 MRI with FastSurfer.
%
% USAGE:     OutputFiles = process_segment_fastsurfer('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_segment_fastsurfer('Compute', iSubject, iAnatomy=[default], nVertices, isInteractive)
%                          process_segment_fastsurfer('ComputeInteractive', iSubject, iAnatomy)

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
% Authors: Francois Tadel, 2021-2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Segment MRI with FastSurfer';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 33;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SegFastSurfer';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Title
    sProcess.options.install.Comment = [
        '<HTML><B>FastSurfer</B> must be installed on the computer, the command <BR>' ...
        '<B>run_fastsurfer.sh</B> must be available in the system path.<BR>' ...
        'Click "Online tutorial" for installation instructions.'];
    sProcess.options.install.Type    = 'label';
    % Doc
    sProcess.options.optdoc.Comment = [
        '<HTML><FONT color="#707070" face="monospace"><PRE>' ...
        'Network specific arguments:<BR>' ...
        '--clean_seg : Flag to clean up FastSurferCNN segmentation<BR>' ...
        '--no_cuda   : Flag to disable CUDA usage in FastSurferCNN<BR>' ...
        '--batch     : Batch size for inference. Default: 16.<BR>' ...
        '              Lower this to reduce memory requirement.<BR>' ...
        '--order     : Interp. for mri_convert T1 before segmentation<BR>' ...
        '              (0=nearest, 1=linear(default), 2=quadratic, 3=cubic)<BR><BR>' ...
        'Surface pipeline arguments:<BR>' ...
        '--fstess    : Use mri_tesselate instead of marching cube (default)<BR>' ...
        '--fsqsphere : Use FreeSurfer default instead of novel<BR>' ...
        '              spectral spherical projection for qsphere<BR>' ...
        '--fsaparc   : Use FS aparc segmentations + DL prediction<BR>' ...
        '--surfreg   : sphere.reg registration with FreeSurfer<BR>' ...
        '--parallel  : Run both hemispheres in parallel<BR>' ...
        '--threads   : Set openMP and ITK threads to ...<BR><BR>' ...
        'Other:<BR>' ...
        '--py        : Python version to use. Default: python3.6<BR>' ...
        '--seg_only  : Only run FastSurferCNN<BR>' ...
        '--surf_only : Only run the surface pipeline recon_surf<BR></PRE></FONT>'];
    sProcess.options.optdoc.Type    = 'label';
    % Option: Extra command-line parameters
    sProcess.options.param.Comment = 'Command-line options:';
    sProcess.options.param.Type    = 'text';
    sProcess.options.param.Value   = '--batch 4 --surfreg --parallel --threads 4';
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % File selection options
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Select FastSurfer output folder...', ...     % Window title
        'ExportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'dirs', ...                        % Selection mode: {files,dirs,files_and_dirs}
        {{'.folder'}, 'FastSurfer database folder', 'FastSurfer'}, ... % Available file formats
        []};                               % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    % Option: FastSurfer output folder
    sProcess.options.outdir.Comment = 'Output folder:';
    sProcess.options.outdir.Type    = 'filename';
    sProcess.options.outdir.Value   = SelectOptions;
    % Default outdir
    sProcess.options.defdir.Comment = '<HTML><FONT color="#707070">Default output folder: $HOME/.brainstorm/tmp/fastsurfer</FONT>';
    sProcess.options.defdir.Type    = 'label';
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
    % Get extra parameters
    param = sProcess.options.param.Value;
    outdir = sProcess.options.outdir.Value{1};
    % Call processing function
    [isOk, errMsg] = Compute(iSubject, [], nVertices, 0, param, outdir);
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
function [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, isInteractive, param, outdir)
    errMsg = '';
    isOk = 0;

    % ===== INSTALL FASTSURFER =====
    bst_progress('text', 'Testing FastSurfer installation...');
    % Get FreeSurfer path from environment variable
    FreeSurferDir = getenv('FREESURFER_HOME');
    SubjectsDir = getenv('SUBJECTS_DIR');
    if isempty(FreeSurferDir) || ~file_exist(FreeSurferDir) || isempty(SubjectsDir) || ~file_exist(SubjectsDir)
        errMsg = ['FreeSurfer is not installed on your computer.' 10 ...
                  'The environment variables FREESURFER_HOME and SUBJECTS_DIR must be set.' 10 10 ...
                  'See the online Brainstorm tutorial about FastSurfer for help:' 10 ...
                  'https://neuroimage.usc.edu/brainstorm/Tutorials/SegFastSurfer'];
        return
    end
    % Get FastSurfer path with system call
    [res,FastSurferDir] = system('which run_fastsurfer.sh'); 
    if (res ~= 0) || isempty(FastSurferDir)
        errMsg = ['FastSurfer is not installed on your computer.' 10 ...
                  'The executable run_fastsurfer.sh must be available in the system path.' 10 ...
                  'Click on "Help" in the process options for installation instructions.'];
        return
    end
    FastSurferDir = bst_fileparts(strtrim(FastSurferDir));

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

    % ===== CHECK OUTPUT FOLDER =====
    % Folder for FastSurfer output
    if ~isempty(outdir)
        TmpDir = [];
        procDir = outdir;
    else
        TmpDir = bst_get('BrainstormTmpDir', 0, 'fastsurfer');
        procDir = TmpDir;
    end
    if ~file_exist(procDir)
        mkdir(procDir);
    end
    % Check if subject dir already exists
    subjid = strrep(sSubject.Name, '@', '');
    subjDir = bst_fullfile(procDir, subjid);
    if file_exist(subjDir)
        if isInteractive
            isDelete = java_dialog('confirm', ...
                    ['<HTML>Subject folder already exists: <BR>' subjDir '<BR><BR>' ...
                    'Delete existing folder?<BR><BR>'], 'FastSurfer segmentation');
            if isDelete
                file_delete(subjDir, 1, 3);
            end
        else
            bst_report('Warning', 'process_segment_fastsurfer', [], ['Subject folder already exists: ' subjDir]);
        end
    end
    
    % ===== DELETE EXISTING SURFACES =====
    % Confirm with user that the existing surfaces will be removed
    if isInteractive && ~isempty(sSubject.Surface)
        isDel = java_dialog('confirm', ['Warning: There are already surfaces in this subject.' 10 ...
            'Running FastSurfer will remove all the existing surfaces.' 10 10 ...
            'Delete the existing files?' 10 10], 'FastSurfer segmentation');
        if ~isDel
            errMsg = 'Process aborted by user.';
            % Delete temporary files
            if ~isempty(TmpDir)
                file_delete(TmpDir, 1, 1);
            end
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
    % Save MRI in .nii format
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

    % ===== RUN FASTSURFER =====
    bst_progress('text', '<HTML>Running FastSurfer... &nbsp;&nbsp;&nbsp;<FONT COLOR="#707070"><I>(see command window)</I></FONT>');
    strCall = ['cd ' FastSurferDir '; run_fastsurfer.sh --t1 "' NiiFile '" --sid "' subjid '" --sd "' procDir '" ' param];
    disp(['BST> System call: ' strCall]);
    status = system(strCall)
    % Error handling
    if (status ~= 0)
        errMsg = ['FastSurfer failed.', 10, 'Check the Matlab command window for more information.'];
        return    
    end

    % ===== IMPORT OUTPUT FOLDER =====
    % Import FreeSurfer anatomy folder
    isExtraMaps = 0;
    isKeepMri = 1;
    isVolumeAtlas = 1;
    FsDir = bst_fullfile(procDir, subjid);
    errMsg = import_anatomy_fs(iSubject, FsDir, nVertices, 0, [], isExtraMaps, isVolumeAtlas, isKeepMri);
    if ~isempty(errMsg)
        return;
    end
    % Delete temporary files
    if ~isempty(TmpDir)
        file_delete(TmpDir, 1, 1);
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
    % Get default parameters
    sProcess = GetDescription();
    optdoc = sProcess.options.optdoc.Comment;
    defParam = sProcess.options.param.Value;
    defDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'fastsurfer');
    % Ask for extra processing parameters
    [param, isCancel] = java_dialog('input', optdoc, 'FastSurfer command-line options', [], defParam);
    if isCancel
        return;
    end
    % Ask for output folder
    [outdir, isCancel] = java_dialog('input', 'FastSurfer output folder:', 'FastSurfer MRI segmentation', [], defDir);
    if isCancel
        return;
    end
    % Ask for number of vertices
    [nVertices, isCancel] = java_dialog('input', 'Number of vertices on the cortex surface:', 'FastSurfer segmentation', [], '15000');
    if isempty(nVertices) || isCancel
        return
    end
    nVertices = str2double(nVertices);
    % Open progress bar
    bst_progress('start', 'FastSurfer', 'FastSurfer MRI segmentation...');
    % Run FastSurfer
    isInteractive = 1;
    [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, isInteractive, param, outdir);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'FastSurfer MRI segmentation', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end
