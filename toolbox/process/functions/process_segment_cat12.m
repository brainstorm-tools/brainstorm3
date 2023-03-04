function varargout = process_segment_cat12( varargin )
% PROCESS_SEGMENT_CAT12: Run the segmentation of a T1 MRI with SPM12/CAT12.
%
% USAGE:     OutputFiles = process_segment_cat12('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_segment_cat12('Compute', iSubject, iAnatomy=[default], nVertices, isSphReg, isExtraMaps, isInteractive)
%                          process_segment_cat12('ComputeInteractive', iSubject, iAnatomy)

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
% Authors: Francois Tadel, 2019-2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Segment MRI with CAT12';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 31;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/SegCAT12';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Option: Number of vertices
    sProcess.options.nvertices.Comment = 'Number of vertices (cortex): ';
    sProcess.options.nvertices.Type    = 'value';
    sProcess.options.nvertices.Value   = {15000, '', 0};
    % Option: TPM atlas
    SelectOptions = {...
        '', ...                            % Filename
        'Nifti1', ...                      % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Select TPM atlas...', ...         % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'files', ...                       % Selection mode: {files,dirs,files_and_dirs}
        {{'.nii','.gz'}, 'MRI: NIfTI-1 (*.nii;*.nii.gz)', 'Nifti1'}, ... % Get all the available file formats
        'MriIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    sProcess.options.tpmnii.Comment = 'TPM atlas: ';
    sProcess.options.tpmnii.Type    = 'filename';
    sProcess.options.tpmnii.Value   = SelectOptions;
    % Option: Spherical registration
    sProcess.options.sphreg.Comment = 'Use spherical registration<BR><I><FONT color="#777777">Required for atlases, group analysis and thickness maps</FONT></I>';
    sProcess.options.sphreg.Type    = 'checkbox';
    sProcess.options.sphreg.Value   = 1;
    % Option: Volume atlases
    sProcess.options.vol.Comment = 'Compute volume parcellations';
    sProcess.options.vol.Type    = 'checkbox';
    sProcess.options.vol.Value   = 1;
    % Option: Import extra map
    sProcess.options.extramaps.Comment = 'Import additional cortical maps<BR><I><FONT color="#777777">Cortical thickness, gyrification index, sulcal depth</FONT></I>';
    sProcess.options.extramaps.Type    = 'checkbox';
    sProcess.options.extramaps.Value   = 0;
    % Option: Compute cerebellum surfaces
    sProcess.options.cerebellum.Comment = '<FONT color="#777777">Compute cerebellum surfaces [Experimental]</FONT>';
    sProcess.options.cerebellum.Type    = 'checkbox';
    sProcess.options.cerebellum.Value   = 0;
    sProcess.options.cerebellum.Hidden  = 1;
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
    % Spherical registration?
    if isfield(sProcess.options, 'sphreg') && isfield(sProcess.options.sphreg, 'Value') && ~isempty(sProcess.options.sphreg.Value)
        isSphReg = sProcess.options.sphreg.Value;
    else
        isSphReg = 1;
    end
    % Volume atlases?
    if isfield(sProcess.options, 'vol') && isfield(sProcess.options.vol, 'Value') && ~isempty(sProcess.options.vol.Value)
        isVolumeAtlases = sProcess.options.vol.Value;
    else
        isVolumeAtlases = 0;
    end
    % Cerebellum?
    if isfield(sProcess.options, 'cerebellum') && isfield(sProcess.options.cerebellum, 'Value') && ~isempty(sProcess.options.cerebellum.Value)
        isCerebellum = sProcess.options.cerebellum.Value;
    else
        isCerebellum = 1;
    end
    % TPM atlas
    if isfield(sProcess.options, 'tpmnii') && isfield(sProcess.options.tpmnii, 'Value') && ~isempty(sProcess.options.tpmnii.Value) && ~isempty(sProcess.options.tpmnii.Value{1})
        TpmNii = sProcess.options.tpmnii.Value{1};
    else
        TpmNii = bst_get('SpmTpmAtlas');
    end
    % Thickness maps
    if isfield(sProcess.options, 'extramaps') && isfield(sProcess.options.extramaps, 'Value') && ~isempty(sProcess.options.extramaps.Value)
        isExtraMaps = sProcess.options.extramaps.Value;
    else
        isExtraMaps = 0;
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
    [isOk, errMsg] = Compute(iSubject, [], nVertices, 0, TpmNii, isSphReg, isVolumeAtlases, isExtraMaps, isCerebellum);
    % Handling errors
    if ~isOk
        bst_report('Error', sProcess, [], errMsg);
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== COMPUTE CAT12 SEGMENTATION =====
function [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, isInteractive, TpmNii, isSphReg, isVolumeAtlases, isExtraMaps, isCerebellum)
    errMsg = '';
    isOk = 0;
    % Initialize SPM12+CAT12
    [isInstalled, errMsg, PlugCat] = bst_plugin('Install', 'cat12', isInteractive, 1728);
    if ~isInstalled
        return;
    end
    bst_plugin('SetProgressLogo', 'cat12');
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
    % Check CAT version
    [catName, catVer] = cat_version;
    if isempty(catVer)
        errMsg = 'Cannot identify CAT12 version: please re-install it.';
        return;
    end
    catVer = str2num(catVer);
    if (catVer < 1728)
        errMsg = [...
            'Please update CAT12.' 10 ...
            ' - Version of CAT installed on this computer: ' num2str(catVer) 10 ...
            ' - Minimum version of CAT supported by Brainstorm: 1728' 10 ...
            ' - http://www.neuro.uni-jena.de/cat/index.html#DOWNLOAD'];
        return;
    end
    % Get default TPM.nii template
    if isempty(TpmNii)
        TpmNii = bst_get('SpmTpmAtlas');
    end
    if isempty(TpmNii) || ~file_exist(TpmNii)
        error('Missing file TPM.nii');
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
        errMsg = ['No MRI available for subject "' sSubject.Name '".'];
        return
    end
    % Get default MRI if not specified
    if isempty(iAnatomy)
        iAnatomy = sSubject.iAnatomy;
    end

    % ===== DELETE EXISTING SURFACES =====
    % Confirm with user that the existing surfaces will be removed
    if isInteractive && ~isempty(sSubject.Surface)
        isDel = java_dialog('confirm', ['Warning: There are already surfaces in this subject.' 10 ...
            'Running CAT12 will remove all the existing surfaces.' 10 10 ...
            'Delete the existing files?' 10 10], 'CAT12 segmentation');
        if ~isDel
            errMsg = 'Process aborted by user.';
            return;
        end
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
    % A vox2ras matrix must be present in the MRI for running CAT12
    sMri = mri_add_world(T1FileBst, sMri);

    % ===== SAVE MRI AS NII =====
    bst_progress('text', 'Saving temporary files...');
    % Create temporay folder for CAT12 output
    TmpDir = bst_get('BrainstormTmpDir', 0, 'cat12');
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
    
    % ===== INITIALIZE SPM+CAT =====
    % Switch to CAT12 expert mode
    cat12('expert');
    % Hide CAT12 figures
    set([findall(0, 'Type', 'Figure', 'Tag', 'Interactive'), ...
         findall(0, 'Type', 'Figure', 'Tag', 'CAT'), ...
         findall(0, 'Type', 'Figure', 'Tag', 'Graphics')], 'Visible', 'off');
    % Initialize SPM job manager
    spm_jobman('initcfg');

    % ===== CALL CAT12 SEGMENTATION =====
    bst_progress('text', '<HTML>Starting SPM batch... &nbsp;&nbsp;&nbsp;<FONT COLOR="#707070"><I>(see command window)</I></FONT>');
    % Create SPM batch
    matlabbatch{1}.spm.tools.cat.estwrite.data = {NiiFile};
    matlabbatch{1}.spm.tools.cat.estwrite.nproc = 0;                % Blocking call to CAT12
    matlabbatch{1}.spm.tools.cat.estwrite.opts.tpm = {TpmNii};      % User-defined TPM atlas
    matlabbatch{1}.spm.tools.cat.estwrite.output.bias.warped = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.GM.native   = 1;   % GM tissue maps
    matlabbatch{1}.spm.tools.cat.estwrite.output.GM.warped   = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.GM.mod      = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.GM.dartel   = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.WM.native   = 1;   % WM tissue maps
    matlabbatch{1}.spm.tools.cat.estwrite.output.WM.warped   = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.WM.mod      = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.WM.dartel   = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.native = 1;   % Tissue classes 4-6 to create own TPMs
    matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.warped = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.mod    = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.dartel = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.native  = 1;   % CSF tissue maps
    matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.warped  = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.mod     = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.dartel  = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.label.native = 1;  % Label: background=0, CSF=1, GM=2, WM=3, WMH=4
    matlabbatch{1}.spm.tools.cat.estwrite.output.label.warped = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.label.dartel = 0;
    matlabbatch{1}.spm.tools.cat.estwrite.output.labelnative = 1;  % Confirmed useful by CGaser in CAT12.8
    % CAT12.8 now saves everything in ICBM152NLinAsym09 space: we can use directly the MNI deformation fields
    matlabbatch{1}.spm.tools.cat.estwrite.output.warps = [1 1];  % Non-linear MNI normalization deformation fields: [forward inverse]
    % Volume atlases
    if isVolumeAtlases
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.neuromorphometrics = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.lpba40             = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.cobra              = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.aal3               = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.anatomy3           = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.ibsr               = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.julichbrain        = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.hammers            = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.mori               = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.thalamus           = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.Schaefer2018_100Parcels_17Networks_order = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.Schaefer2018_200Parcels_17Networks_order = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.Schaefer2018_400Parcels_17Networks_order = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.Schaefer2018_600Parcels_17Networks_order = 1;
        matlabbatch{1}.spm.tools.cat.estwrite.output.atlas.native = 1;  % Save atlases in native space
        matlabbatch{1}.spm.tools.cat.estwrite.output.atlas.warped = 0;
        matlabbatch{1}.spm.tools.cat.estwrite.output.atlas.dartel = 0;
    else
        % No ROIs
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.noROI = struct([]);   % CGaser comment: Correct syntax to disable ROI processing for volumes   
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.neuromorphometrics = 0;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.lpba40             = 0;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.cobra              = 0;
        matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.atlases.hammers            = 0;
    end
    % Spherical registration (much slower)
    if isSphReg && ~isCerebellum    % CGaser comment: Cerebellum extraction is experimental, not to be used routinely
        matlabbatch{1}.spm.tools.cat.estwrite.output.surface = 1;   % 1: lh+rh
    elseif isSphReg && isCerebellum
        matlabbatch{1}.spm.tools.cat.estwrite.output.surface = 2;   % 2: lh+rh+cerebellum
    elseif ~isSphReg && ~isCerebellum
        matlabbatch{1}.spm.tools.cat.estwrite.output.surface = 5;   % 5: lh+rh (fast, no registration, quick review only)
    elseif ~isSphReg && isCerebellum
        matlabbatch{1}.spm.tools.cat.estwrite.output.surface = 6;   % 6: lh+rh+cerebellum  (fast, no registration, quick review only)
    end
    % Extract additional surface parameters: Cortical thickness, Gyrification index, Sulcal depth (can't be imported for default anatomy)
    if isExtraMaps && (iSubject > 0)
        matlabbatch{1}.spm.tools.cat.estwrite.output.surf_measures = 1;  % Thickness maps
        % Separate SPM process (second element in the batch)
        matlabbatch{2}.spm.tools.cat.stools.surfextract.data_surf(1) = cfg_dep('CAT12: Segmentation (current release): Left Central Surface', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','lhcentral', '()',{':'}));
        matlabbatch{2}.spm.tools.cat.stools.surfextract.GI = 1;     % Gyrification index
        matlabbatch{2}.spm.tools.cat.stools.surfextract.SD = 1;     % Sulcal depth
        matlabbatch{2}.spm.tools.cat.stools.surfextract.nproc = 0;  % Blocking call to CAT12
    end

    % Run batch
    spm_jobman('run',matlabbatch);
    % Close CAT12 figures
    close([findall(0, 'Type', 'Figure', 'Tag', 'Interactive'), ...
           findall(0, 'Type', 'Figure', 'Tag', 'CAT')]);

    % ===== PROJECT ATLASES =====
    TessLhFile = file_find(TmpDir, 'lh.central.*.gii', 2);
    if exist('cat_surf_map_atlas', 'file') && file_exist(TessLhFile)
        % Get CAT12 dir
        CatDir = bst_fullfile(PlugCat.Path, PlugCat.SubFolder);
        % List of parcellations to project
        AnnotLhFiles = file_find(bst_fullfile(CatDir, 'atlases_surfaces'), 'lh.*.annot', 2, 0);
        % Import atlases (cat_surf_map_atlas calls both hemispheres at once)
        for iAnnot = 1:length(AnnotLhFiles)
            [fAnnotPath, fAnnotName] = bst_fileparts(AnnotLhFiles{iAnnot});
            bst_progress('text', ['Interpolating atlas: ' fAnnotName '...']);
            cat_surf_map_atlas(TessLhFile, AnnotLhFiles{iAnnot});
        end
    end
    
    % ===== IMPORT OUTPUT FOLDER =====
    % Import CAT12 anatomy folder
    isKeepMri = 1;
    errMsg = import_anatomy_cat(iSubject, TmpDir, nVertices, 0, [], isExtraMaps, isKeepMri);
    if ~isempty(errMsg)
        return;
    end
    % Delete temporary folder
    file_delete(TmpDir, 1, 1);
    % Remove logo
    bst_plugin('SetProgressLogo', []);
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
    nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'CAT12 segmentation', [], '15000');
    if isempty(nVertices)
        return
    end
    nVertices = str2double(nVertices);
    % Ask for volume atlases
    [isVolumeAtlases, isCancel] = java_dialog('confirm', ['Compute anatomical parcellations?' 10 10 ...
        ' - AAL3', 10 ...
        ' - Anatomy v3', 10 ...
        ' - CoBrALab' 10 ...
        ' - Hammers' 10 ... 
        ' - IBSR', 10 ...
        ' - JulichBrain v2', 10 ...
        ' - LPBA40' 10 ...
        ' - Mori', 10 ...
        ' - Neuromorphometrics' 10 ...
        ' - Schaefer2018', 10 10], 'CAT12 MRI segmentation');
    if isCancel
        return
    end
    % Ask for cortical maps (not for default anatomy)
    if (iSubject > 0)
        [isExtraMaps, isCancel] = java_dialog('confirm', ['Compute cortical maps?' 10 10 ...
            ' - Cortical thickness', 10 ...
            ' - Gyrification index', 10 ...
            ' - Sulcal depth', 10 10], 'CAT12 MRI segmentation');
        if isCancel
            return
        end
    else
        isExtraMaps = 0;
    end
    % Open progress bar
    bst_progress('start', 'CAT12', 'CAT12 MRI segmentation...');
    % Run CAT12
    TpmNii = bst_get('SpmTpmAtlas');
    isInteractive = 1;
    isSphReg = 1;
    isCerebellum = 0;
    [isOk, errMsg] = Compute(iSubject, iAnatomy, nVertices, isInteractive, TpmNii, isSphReg, isVolumeAtlases, isExtraMaps, isCerebellum);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'CAT12 MRI segmentation', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end
