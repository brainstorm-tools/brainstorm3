function varargout = process_mri_deface( varargin )
% PROCESS_MRI_DEFACE: Remove the facial features from an MRI.

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
%          Inspired from SPM12 function spm_deface

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Deface MRI volumes';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 41;
    sProcess.Description = 'https://surfer.nmr.mgh.harvard.edu/fswiki/mri_deface';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Option: Method
    sProcess.options.method_title.Comment = '<BR>Defacing method:';
    sProcess.options.method_title.Type    = 'label';
    sProcess.options.method.Comment = {'SPM: MNI coordinates (cut below a plane)', 'FreeSurfer: mri_deface'; ...
                                       'spm', 'freesurfer'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'spm';
    % Option: Recompute head surface
    sProcess.options.defacehead.Comment = 'Recompute head surface';
    sProcess.options.defacehead.Type    = 'checkbox';
    sProcess.options.defacehead.Value   = 1;
    sProcess.options.defacehead.Group   = 'output';
    % Option: Overwrite
    sProcess.options.overwrite.Comment = 'Overwrite existing files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    OPTIONS.isOverwrite = sProcess.options.overwrite.Value;
    OPTIONS.Method = sProcess.options.method.Value;
    OPTIONS.isInteractive = 0;
    OPTIONS.isDefaceHead = sProcess.options.defacehead.Value;
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, [], 'Subject name is empty.');
        return;
    end
      
    % ===== GET SUBJECT =====
    % Get subject 
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    if isempty(iSubject)
        bst_report('Error', sProcess, [], ['Subject "' SubjectName '" does not exist.']);
        return
    end
    % Check if a MRI is available for the subject
    if isempty(sSubject.Anatomy)
        bst_report('Error', sProcess, [], ['No MRI available for subject "' SubjectName '".']);
        return
    end
    
    % ===== DEFACE ALL VOLUMES =====
    % Deface volumes
    [DefacedMri, errMsg] = Compute(iSubject, OPTIONS);
    % Error handling
    if isempty(DefacedMri)
        bst_report('Error', sProcess, [], errMsg);
        return;
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    
    OutputFiles = {'import'};
end



%% ===== EXTERNAL CALL =====
% USAGE:  [DefacedFiles, errMsg] = Compute(MriFiles, OPTIONS=[])
%         [DefacedFiles, errMsg] = Compute(iSubject, OPTIONS=[])
function [DefacedFiles, errMsg] = Compute(MriFiles, OPTIONS)
    % Parse inputs
    if ischar(MriFiles)
        MriFiles = {MriFiles};
    elseif isnumeric(MriFiles)
        iSubject = MriFiles;
        % Get volumes to deface
        sSubject = bst_get('Subject', iSubject);
        MriFiles = {sSubject.Anatomy.FileName};
        % Put the default volume first
        if ~isempty(sSubject.iAnatomy)
            iOrder = [sSubject.iAnatomy, setdiff(1:length(sSubject.Anatomy), sSubject.iAnatomy)];
            MriFiles = MriFiles(iOrder);
        end
    end
    if (nargin < 2) || isempty(OPTIONS)
        OPTIONS = struct();
    end
    % Ask method to user in interactive mode
    if (~isfield(OPTIONS, 'Method') || isempty(OPTIONS.Method)) && (~isfield(OPTIONS, 'isInteractive') || OPTIONS.isInteractive)
        % Windows: no options anyway (FreeSurfer's mri_deface not available)
        if ismember(bst_get('OsType',0), {'win32', 'win64'})
            OPTIONS.Method = 'spm';
        % Other OS: Ask for choice
        else
            res = java_dialog('combo', '<HTML>Select the defacing method:<BR>', 'Deface volume', [], {'spm', 'freesurfer'}, 'freesurfer');
            if isempty(res)
                errMsg = 'Aborted by user.';
                return;
            end
            OPTIONS.Method = res;
        end
    end
    % Default options
    Def_OPTIONS = struct(...
        'Method',        'spm', ...
        'MNIplane',      [-0.00036476, -0.01128325, 0.00980049, 0.001025580777], ...
        'isOverwrite',   0, ...
        'isInteractive', 1, ...
        'isDefaceHead',  1);
    OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);
    % Initialize returned variables
    DefacedFiles = {};
    errMsg = [];
    fileTag = ' | deface';
        
    % Progress bar
    isProgress = bst_progress('isVisible');
    if ~isProgress
        bst_progress('start', 'Deface MRI', 'Initialization...');
    end
    % Process each input file separately
    MriHead = [];
    for iFile = 1:length(MriFiles)
        bst_progress('text', 'Loading input MRI...');
        % Get subject index
        [sSubject, iSubject, iAnatomy] = bst_get('MriFile', MriFiles{iFile});
        % If MRI was already defaced: skip
        if (length(MriFiles) > 1) && ~isempty(strfind(sSubject.Anatomy(iAnatomy).Comment, fileTag))
            continue;
        end
        % Check if it is loaded in memory
        sMri = bst_memory('GetMri', MriFiles{iFile});
        % If not: load it from the file
        if isempty(sMri)
            sMri = in_mri_bst(MriFiles{iFile});
        end
        
        % Switch depending on the method
        switch (OPTIONS.Method)
            case 'spm'
                % Compute MNI transformation if not available (first volume only)
                if (iFile == 1) && (~isfield(sMri, 'NCS') || isempty(sMri.NCS) || ~isfield(sMri.NCS, 'R') || ~isfield(sMri.NCS, 'T') || isempty(sMri.NCS.R) || isempty(sMri.NCS.T))
                    [sMri, errMsg] = bst_normalize_mni(MriFiles{iFile});
                    if ~isempty(errMsg)
                        if ~isProgress
                            bst_progress('stop');
                        end
                        return;
                    end
                end
                % Compute cut mask on first volume only
                if (iFile == 1)
                    % Get MNI transformation
                    vox2mni = cs_convert(sMri, 'voxel', 'mni');
                    % Get cut plane in MRI coordinates
                    cutPlane = OPTIONS.MNIplane * vox2mni;
                    % Get voxel indices under the MNI plane defined in input
                    [i,j,k] = ndgrid(1:size(sMri.Cube,1), 1:size(sMri.Cube,2), 1:size(sMri.Cube,3));
                    iCut = cutPlane(1)*i + cutPlane(2)*j + cutPlane(3)*k + cutPlane(4) < 0;
                end
                % Set to zero the voxels below the plane
                sMri.Cube(iCut) = 0;
                
            case 'freesurfer'
                % Get path to mri_deface (download if necessary)
                [exePath, talFile, faceFile, errMsg] = InstallMriDeface(OPTIONS.isInteractive);
                if ~isempty(errMsg)
                    if ~isProgress
                        bst_progress('stop');
                    end
                    return;
                end
                disp(['BST> Deface: Using ' exePath]);
                % Save temporary MRI file
                bst_progress('text', 'Saving temporary nii file...');
                fileNii = bst_fullfile(bst_get('BrainstormTmpDir'), 'orig.nii');
                out_mri_nii(sMri, fileNii, 'int16');
                % Change current folder to .brainstorm/tmp, because mri_deface saves a useless log in the current folder
                curdir = pwd;
                cd(bst_get('BrainstormTmpDir'));
                % Call mri_deface
                bst_progress('text', 'Running mri_deface...');
                fileNiiDefaced = bst_fullfile(bst_get('BrainstormTmpDir'), 'orig_defaced.nii');
                cmdDeface = [exePath ' ' fileNii ' ' talFile ' ' faceFile ' ' fileNiiDefaced];
                status = system(cmdDeface);
                if (status ~= 0)
                    errMsg = 'Error calling mri_deface (see console for details).';
                    if ~isProgress
                        bst_progress('stop');
                    end
                    return;
                end
                % Restore initial folder
                cd(curdir);
                % Read defaced file
                bst_progress('text', 'Reading defaced file...');
                sMriDefaced = in_mri_nii(fileNiiDefaced);
                % Saves defaced volume
                sMri.Cube = sMriDefaced.Cube;
                
            otherwise
                errMsg = ['Invalid defacing method: ' OPTIONS.Method];
                if ~isProgress
                    bst_progress('stop');
                end
                return;
        end
        % Add comment tag
        sMri.Comment = [sMri.Comment, fileTag];

        % Save defaced MRI
        bst_progress('text', 'Saving results to database...');
        if OPTIONS.isOverwrite
            % Update file structure
            bst_save(file_fullpath(MriFile), sMri, 'v6');
            DefacedFiles{end+1} = MriFile;
            % Unload from memory to force reloading
            bst_memory('UnloadMri', MriFile);
        % Add new file
        else
            DefacedFiles{end+1} = db_add(iSubject, sMri, 0);
            iAnatomy = length(sSubject.Anatomy) + 1;
        end
        % Update database registration
        sSubject.Anatomy(iAnatomy).FileName = DefacedFiles{end};
        sSubject.Anatomy(iAnatomy).Comment = sMri.Comment;
        bst_set('Subject', iSubject, sSubject);
        % Refresh tree
        panel_protocols('UpdateNode', 'Subject', iSubject);
        panel_protocols('SelectNode', [], 'subject', iSubject, -1);
        % If we recompute the head, it is on the defaced version of the first MRI in the list
        if (iFile == 1)
            MriHead = DefacedFiles{end};
        end
    end
    
    
    % ===== RECOMPUTE HEAD SURFACES =====
    if OPTIONS.isDefaceHead && ~isempty(MriHead)
        % Get subject
        [sSubject, iSubject] = bst_get('MriFile', MriHead);
        % Get all head surfaces
        [sSurfaces, iSurfaces] = bst_get('SurfaceFileByType', iSubject, 'Scalp');
        % Remove the BEM surfaces (too smooth to be problematic)
        if ~isempty(sSurfaces)
            iBem = find(~cellfun(@(c)isempty(strfind(c, '_bem_')), {sSurfaces.FileName}));
            if ~isempty(iBem)
                sSurfaces(iBem) = [];
                iSurfaces(iBem) = [];
            end
        end
        % If there are surfaces to delete
        if ~isempty(sSurfaces)
            % Delete head surfaces
            file_delete(file_fullpath({sSurfaces.FileName}), 1);
            % Update database structure
            HeadComment = [sSurfaces(1).Comment, fileTag];
            sSubject.Surface(iSurfaces) = [];
            bst_set('Subject', iSubject, sSubject);
            % Compute new head surface
            sSubject.Anatomy(sSubject.iAnatomy).FileName;
            tess_isohead(MriHead, 10000, 0, 2, HeadComment);
        end
    end
    
    % Close progress bar
    if ~isProgress
        bst_progress('stop');
    end
end




%% ===== INSTALL MRI_DEFACE =====
function [exePath, talFile, faceFile, errMsg] = InstallMriDeface(isInteractive)
    exePath = [];
    errMsg = [];
    talFile = [];
    faceFile = [];
    curdir = pwd;
    % Test if FreeSurfer is installed
    fsHome = getenv('FREESURFER_HOME');
    if ~isempty(fsHome)
        exePath = bst_fullfile(fsHome, 'bin', 'mri_deface');
        talFile = bst_fullfile(fsHome, 'average', 'talairach_mixed_with_skull.gca');
        faceFile = bst_fullfile(fsHome, 'average', 'face.gca');
        if file_exist(exePath) && file_exist(talFile) && file_exist(faceFile)
            disp(['BST> mri_deface found in FreeSurfer folder: ' fsHome]);
            return;
        end
        exePath = [];
    end
    % Executable mri_deface not found: Trying to install locally
    disp('BST> Deface: Variable FREESURFER_HOME not set. Trying to install mri_deface locally...');
    % Get download url
    osType = bst_get('OsType', 0);
    switch(osType)
        case 'linux32',  url = 'https://surfer.nmr.mgh.harvard.edu/pub/dist/mri_deface/mri_deface-v1.22-Linux.gz';
        case 'linux64',  url = 'https://surfer.nmr.mgh.harvard.edu/pub/dist/mri_deface/mri_deface-v1.22-Linux64.gz';
        case 'mac32',    url = 'https://surfer.nmr.mgh.harvard.edu/pub/dist/mri_deface/mri_deface-v1.22-MacOS-Leopard-intel.gz';
        case 'mac64',    url = 'https://surfer.nmr.mgh.harvard.edu/pub/dist/mri_deface/mri_deface-v1.22-MacOS-Leopard-intel.gz';
        otherwise,       errMsg = 'The program mri_deface is not available for your operating system.'; return;
    end
    talUrl = 'https://surfer.nmr.mgh.harvard.edu/pub/dist/mri_deface/talairach_mixed_with_skull.gca.gz';
    faceUrl = 'https://surfer.nmr.mgh.harvard.edu/pub/dist/mri_deface/face.gca.gz';
    
    % Local folder where to install mri_deface
    mriDefaceDir = bst_fullfile(bst_get('BrainstormUserDir'), 'mri_deface', osType);
    % If dir doesn't exist in user folder, try to look for it in the Brainstorm folder
    if ~isdir(mriDefaceDir)
        mriDefaceDirMaster = bst_fullfile(bst_get('BrainstormHomeDir'), 'mri_deface', osType);
        if isdir(mriDefaceDirMaster)
            mriDefaceDir = mriDefaceDirMaster;
        end
    end
    % URL file defines the current version
    urlFile = bst_fullfile(mriDefaceDir, 'url');
    
    % Read the previous download url information
    if isdir(mriDefaceDir) && file_exist(urlFile)
        fid = fopen(urlFile, 'r');
        prevUrl = fread(fid, [1 Inf], '*char');
        fclose(fid);
    else
        prevUrl = '';
    end

    % Local installation
    exePath = bst_fullfile(mriDefaceDir, 'mri_deface');
    talFile = bst_fullfile(mriDefaceDir, 'talairach_mixed_with_skull.gca');
    faceFile = bst_fullfile(mriDefaceDir, 'face.gca');
    % If binary file doesnt exist: download
    if ~isdir(mriDefaceDir) || ~file_exist(exePath) || ~strcmpi(prevUrl, url)
        % If folder exists: delete
        if isdir(mriDefaceDir)
            file_delete(mriDefaceDir, 1, 3);
        end
        % Create folder
        res = mkdir(mriDefaceDir);
        if ~res
            errMsg = ['Error: Cannot create folder' 10 mriDefaceDir];
            return
        end
        % Message
        if isInteractive
            isOk = java_dialog('confirm', ...
                ['FreeSurfer or mri_deface are not installed on your computer (or out-of-date).' 10 10 ...
                 'Download and the latest version of mri_deface?'], 'mri_deface');
            if ~isOk
                errMsg = 'Download aborted by user';
                return;
            end
        end
        % Download file
        errMsg1 = gui_brainstorm('DownloadFile', url, [exePath '.gz'], 'Download mri_deface');
        errMsg2 = gui_brainstorm('DownloadFile', talUrl, [talFile '.gz'], 'mri_deface template (1)');
        errMsg3 = gui_brainstorm('DownloadFile', faceUrl, [faceFile '.gz'], 'mri_deface template (2)');
        % If file was not downloaded correctly
        if ~isempty(errMsg1) || ~isempty(errMsg2) || ~isempty(errMsg3)
            errMsg = ['Impossible to download mri_deface:' 10 errMsg1];
            return;
        end
        % Display again progress bar
        bst_progress('text', 'Installing mri_deface...');
        % Unzip file
        cd(mriDefaceDir);
        system(['gunzip ' exePath '.gz']);
        system(['gunzip ' talFile '.gz']);
        system(['gunzip ' faceFile '.gz']);
        system(['chmod a+x ' exePath]);
        cd(curdir);
        % Save download URL in folder
        fid = fopen(urlFile, 'w');
        fwrite(fid, url);
        fclose(fid);
    end
    % If the executable is still not accessible
    if ~file_exist(exePath)
        errMsg = ['mri_convert could not be installed in: ' mriDefaceDir];
    end
end



