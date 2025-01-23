function varargout = process_dwi2dti( varargin )
% PROCESS_DWI2DTI: Read DWI images, compute DTI tensors and save them in the database.
%
% USAGE:     OutputFiles = process_dwi2dti('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_dwi2dti('Compute', iSubject, DwiFile, BvalFile, BvecFile)
%                DtiFile = process_dwi2dti('ComputeInteractive', iSubject)

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
% Authors: Francois Tadel, 2020-2023
%          Takfarinas Medani, Anand Joshi, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Convert DWI to DTI (BrainSuite)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 23;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/FemMesh';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % File selection options
    SelectOptionsNii = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Import DWI', ...                  % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'files', ...                       % Selection mode: {files,dirs,files_and_dirs}
        {{'.nii','.gz'}, 'MRI: NIfTI-1 (*.nii;*.nii.gz)', 'DWI-NII'}, ... % File formats       
        1};                                % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    SelectOptionsBval = SelectOptionsNii;
    SelectOptionsBval{8} = {{'.bval'}, 'Raw DWI: b-values (*.bval)', 'DWI-BVAL'};
    SelectOptionsBvec = SelectOptionsNii;
    SelectOptionsBvec{8} = {{'.bvec'}, 'Raw DWI: b-vectors (*.bvec)', 'DWI-BVEC'};
    % Title
    sProcess.options.doc.Comment = ['<HTML><B>BrainSuite</B> must be installed on the computer,<BR>' ...
                                    'the command "bdp" must be available in the system path.<BR>' ...
                                    'Website: http://brainsuite.org<BR><BR>'];
    sProcess.options.doc.Type    = 'label';
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Option: NII file
    sProcess.options.dwifile.Comment = 'DWI nii file:';
    sProcess.options.dwifile.Type    = 'filename';
    sProcess.options.dwifile.Value   = SelectOptionsNii;
    % Option: BVAL file
    sProcess.options.bvalfile.Comment = 'DWI bval file:';
    sProcess.options.bvalfile.Type    = 'filename';
    sProcess.options.bvalfile.Value   = SelectOptionsBval;
    % Option: BVEC file
    sProcess.options.bvecfile.Comment = 'DWI bvec file:';
    sProcess.options.bvecfile.Type    = 'filename';
    sProcess.options.bvecfile.Value   = SelectOptionsBvec;
    % Comment
    sProcess.options.note.Comment = '<I>Selecting .bval/.bvec files is optional if they have the same name</I>';
    sProcess.options.note.Type    = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % ===== GET OPTIONS =====
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, [], 'Subject name is empty.');
        return
    end
    % Get .nii filenames to import
    DwiFile = sProcess.options.dwifile.Value{1};
    if isempty(DwiFile)
        bst_report('Error', sProcess, [], 'DWI file not selected.');
        return
    end
    % Get BVAL file
    if isfield(sProcess.options, 'bvalfile') && isfield(sProcess.options.bvalfile, 'Value') && ~isempty(sProcess.options.bvalfile.Value) && iscell(sProcess.options.bvalfile.Value)
        BvalFile = sProcess.options.bvalfile.Value{1};
    else
        BvalFile = [];
    end
    % Get BVEC file
    if isfield(sProcess.options, 'bvecfile') && isfield(sProcess.options.bvecfile, 'Value') && ~isempty(sProcess.options.bvecfile.Value) && iscell(sProcess.options.bvecfile.Value)
        BvecFile = sProcess.options.bvecfile.Value{1};
    else
        BvecFile = [];
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
    
    % ===== COMPUTE DTI =====
    % Compute DTI tensors
    [DtiFile, errMsg] = Compute(iSubject, [], DwiFile, BvalFile, BvecFile);
    % Error handling
    if ~isempty(errMsg)
        if isempty(DtiFile)
            bst_report('Error', sProcess, [], ['Cannot convert files: ' 10 DwiFile 10 BvalFile 10 BvecFile 10 10 errMsg]);
            return;
        else
            bst_report('Warning', sProcess, [], ['Warning: ' errMsg]);
        end
    end
    OutputFiles = {'import'};
end

%% ===== CHECK FOR BRAINSUITE INSTALLATION =====
function [bdp_exe, errMsg] = CheckBrainSuiteInstall()
    errMsg = [];
    if ~ispc
        bdp_exe = 'bdp.sh';
    else
        bdp_exe = 'bdp';
    end

    % ===== INSTALL BRAINSUITE =====
    bst_progress('text', 'Testing BrainSuite installation...');
    % Check BrainSuite installation
    status = system([bdp_exe ' --version']);
    if (status ~= 0)
        % Get BrainSuite path from Brainstorm preferences
        BsDir = bst_get('BrainSuiteDir');
        BsBinDir = bst_fullfile(BsDir, 'bin');
        BsBdpDir = bst_fullfile(BsDir, 'bdp');
        % Add BrainSuite path to system path
        if ~isempty(BsDir) && file_exist(BsBinDir) && file_exist(BsBdpDir)
            disp(['BST> Adding to system path: ' BsBinDir]);
            disp(['BST> Adding to system path: ' BsBdpDir]);
            setenv('PATH', [getenv('PATH'), pathsep, BsBinDir, pathsep, BsBdpDir]);
            % Check again
            status = system([bdp_exe  ' --version']);
        end
        % Brainsuite is not installed
        if (status ~= 0)
            errMsg = ['BrainSuite is not installed on your computer.' 10 ...
                      'Download it from http://brainsuite.org and install it.' 10 ...
                      'Then set its installation folder in the Brainstorm options (File > Edit preferences)'];
            return
        end
    end
end

%% ===== COMPUTE DTI =====
function [DtiFile, errMsg] = Compute(iSubject, T1BstFile, DwiFile, BvalFile, BvecFile)
    DtiFile = [];
    errMsg = '';
    
    % ===== INPUTS =====
    % Try to find the bval/bvec files in the same folder
    [fPath, fBase, fExt] = bst_fileparts(DwiFile);
    if isequal(fExt, '.gz')
        [fPath, fBase, fExt] = bst_fileparts(bst_fullfile(fPath, fBase));
    end
    if isempty(BvalFile) || ~file_exist(BvalFile)
        BvalFile = bst_fullfile(fPath, [fBase, '.bval']);
        if ~file_exist(BvalFile)
            errMsg = ['Could not find b-values file: ' BvalFile];
            return;
        end
    end
    if isempty(BvecFile) || ~file_exist(BvecFile)
        BvecFile = bst_fullfile(fPath, [fBase, '.bvec']);
        if ~file_exist(BvecFile)
            errMsg = ['Could not find b-vectors file: ' BvecFile];
            return;
        end
    end
    % Check dimensions
    bval = load(BvalFile);
    bvec = load(BvecFile);
    if (length(bval) ~= length(bvec))
        errMsg = 'Error: bval and bvec have different lengths.';
        return
    end
    % Get subject
    sSubject = bst_get('Subject', iSubject);
    % Get default MRI as T1
    if isempty(T1BstFile)
        if isempty(sSubject) || isempty(sSubject.iAnatomy)
            errMsg = 'No T1 MRI loaded for selected subject.';
            return
        end
        T1BstFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    
    % ===== CHECK FOR BRAINSUITE INSTALLATION =====
    [bdp_exe, errMsg] = CheckBrainSuiteInstall();

    % ===== TEMPORARY FOLDER =====
    bst_progress('text', 'Preparing temporary folder...');
    % Create temporary folder for segmentation files
    TmpDir = bst_get('BrainstormTmpDir', 0, 'brainsuite');
    % Save MRI in .nii format
    subjid = strrep(sSubject.Name, '@', '');
    T1Nii = bst_fullfile(TmpDir, [subjid 'T1.nii']);
    out_mri_nii(T1BstFile, T1Nii);
    
    % ===== 1. BRAIN SURFACE EXTRACTOR (BSE) =====
    bst_progress('text', '1/3: Brain surface extractor...');
    strCall = [...
        'bse -i "' T1Nii '" --auto' ...
        ' -o "' fullfile(TmpDir, 'skull_stripped_mri.nii.gz"') ...
        ' --mask "' fullfile(TmpDir, 'bse_smooth_brain.mask.nii.gz"') ...
        ' --hires "' fullfile(TmpDir, 'bse_detailled_brain.mask.nii.gz"') ...
        ' --cortex "' fullfile(TmpDir, 'bse_cortex_file.nii.gz"')];
    disp(['BST> System call: ' strCall]);
    status = system(strCall)
    % Error handling
    if (status ~= 0)
        errMsg = ['BrainSuite failed at step 1/3 (BSE).', 10, 'Check the Matlab command window for more information.'];
        return    
    end

    % ===== 2. BIAS FIELD CORRECTION (BFC) =====
    bst_progress('text', '2/3: Bias field correction...');
    strCall = [...
        'bfc -i "' fullfile(TmpDir, 'skull_stripped_mri.nii.gz"') ...
        ' -o "' fullfile(TmpDir, 'output_mri.bfc.nii.gz"') ...
        ' -L 0.5 -U 1.5'];
    disp(['BST> System call: ' strCall]);
    status = system(strCall)
    % Error handling
    if (status ~= 0)
        errMsg = ['BrainSuite failed at step 2/3 (BFC).', 10, 'Check the Matlab command window for more information.'];
        return
    end

    % ===== 3. BRAINSUITE DIFFUSION PIPELINE (BDP) =====
    bst_progress('text', '3/3: BrainSuite Diffusion Pipeline...');
    strCall = [...
        bdp_exe ' "' fullfile(TmpDir,'output_mri.bfc.nii.gz"') ...
        ' --tensor --nii "' DwiFile '"' ...
        ' --t1-mask "' fullfile(TmpDir, 'bse_smooth_brain.mask.nii.gz"')...
        ' -g "' BvecFile '" -b "' BvalFile '"'];
    disp(['BST> System call: ' strCall]);
    % Error handling
    status = system(strCall)
    if (status ~= 0)
        errMsg = ['BrainSuite failed at step 3/3 (BDP).', 10, 'Check the Matlab command window for more information.'];
        return
    end
    % Check output file: output_mri.dwi.RAS.correct.T1_coord.eig.nii.gz
    dirEig = dir(fullfile(TmpDir,'*.eig.nii.gz'));
    if isempty(dirEig)
        errMsg = ['BrainSuite failed at step 3/3 (BDP).', 10, 'Missing *.eig.nii.gz in output folder.', 10, 'Check the Matlab command window for more information.'];
        return
    end
    DtiNii = fullfile(TmpDir, dirEig.name);

    % ===== 4. EIG2NIFTI =====
    bst_progress('text', 'Saving output data...');
    % Reading volumes
    DtiFile = import_mri(iSubject, DtiNii, 'Nifti1', 0, 0, 'DTI-EIG');

    % Delete the temporary files
    file_delete(TmpDir, 1, 1);
end


%% ===== COMPUTE DTI INTERACTIVE =====
function DtiFile = ComputeInteractive(iSubject) %#ok<DEFNU>
    DtiFile = [];
    % Get last used directories
    LastUsedDirs = bst_get('LastUsedDirs');
    % Get MRI file
    DwiFile = java_getfile('open', 'Import DWI', LastUsedDirs.ImportAnat, 'single', 'files', ...
        {{'.nii','.gz'}, 'MRI: NIfTI-1 (*.nii;*.nii.gz)', 'DWI-NII'}, 1);

    if isempty(DwiFile)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportAnat = bst_fileparts(DwiFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Try to find the bval/bvec files in the same folder
    [fPath, fBase, fExt] = bst_fileparts(DwiFile);
    if strcmp(fExt,'.gz')
    	[tmp, fBase, fExt] = bst_fileparts(fBase);
    end
    BvalFile = bst_fullfile(fPath, [fBase, '.bval']);
    BvecFile = bst_fullfile(fPath, [fBase, '.bvec']);
    % Validate or ask bval
    if ~file_exist(BvalFile)
        BvalFile = java_getfile('open', 'Import DWI', LastUsedDirs.ImportAnat, 'single', 'files', ...
            {{'.bval'}, 'Raw DWI: b-values (*.bval)', 'DWI-BVAL'}, 1);
        if isempty(BvalFile)
            return
        end
    end
    % Validate or ask bvec
    if ~file_exist(BvecFile)
        BvecFile = java_getfile('open', 'Import DWI', LastUsedDirs.ImportAnat, 'single', 'files', ...
            {{'.bvec'}, 'Raw DWI: b-vectors (*.bvec)', 'DWI-BVEC'}, 1);
        if isempty(BvecFile)
            return
        end
    end
    
    % Open progress bar
    bst_progress('start', 'DWI2DTI', 'Computing DTI tensors (BrainSuite)...');
    % Compute DTI
    try
        [DtiFile, errMsg] = Compute(iSubject, [], DwiFile, BvalFile, BvecFile);
        % Error handling
        if isempty(DtiFile) || ~isempty(errMsg)
            bst_error(['Cannot convert files: ' 10 DwiFile 10 BvalFile 10 BvecFile 10 10 errMsg], 'Convert DWI to DTI', 0);
        end
    catch
        bst_error();
        bst_error(['DTI tensors computation failed.' 10 'Check the Matlab command window for additional information.' 10], 'DWI2DTI', 0);
    end
    % Close progress bar
    bst_progress('stop');
end

