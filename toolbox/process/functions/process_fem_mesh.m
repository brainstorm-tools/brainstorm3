function varargout = process_fem_mesh( varargin )
% PROCESS_FEM_MESH: Generate tetrahedral/hexahedral FEM mesh.
%
% USAGE:     OutputFiles = process_fem_mesh('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_fem_mesh('Compute', iSubject, iMris=[default], isInteractive, OPTIONS)
%                          process_fem_mesh('ComputeInteractive', iSubject, iMris=[default])
%                OPTIONS = process_fem_mesh('GetDefaultOptions')
%                  label = process_fem_mesh('GetFemLabel', label)
%             NewFemFile = process_fem_mesh('SwitchHexaTetra', FemFile)

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
% Authors: Francois Tadel, Takfarinas Medani, 2019-2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    OPTIONS = GetDefaultOptions();
    % Description the process
    sProcess.Comment     = 'Generate FEM mesh';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 22;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Method
    sProcess.options.method.Comment = {'<B>Iso2mesh</B>:<BR>Call iso2mesh to create a tetrahedral mesh from the <B>BEM surfaces</B><BR>', ...
                                       '<B>Brain2mesh</B>:<BR>Segment the <B>T1</B> (and <B>T2</B>) <B>MRI</B> with SPM12, mesh with Brain2Mesh<BR>', ...
                                       '<B>SimNIBS</B>:<BR>Call SimNIBS to segment and mesh the <B>T1</B> (and <B>T2</B>) <B>MRI</B>.', ...
                                       '<B>FieldTrip</B>:<BR> Call FieldTrip to create hexahedral mesh of the <B>T1 MRI</B>.'; ...
                                       'iso2mesh', 'brain2mesh', 'simnibs', 'fieldtrip'};
    sProcess.options.method.Type    = 'radio_label';
    sProcess.options.method.Value   = 'iso2mesh';
    % Iso2mesh options: 
    sProcess.options.opt1.Comment = '<BR><BR><B>Iso2mesh options</B>: ';
    sProcess.options.opt1.Type    = 'label';
    % Iso2mesh: Merge method
    sProcess.options.mergemethod.Comment = {'mergemesh', 'mergesurf', 'Input surfaces merged with:'; 'mergemesh', 'mergesurf', ''};
    sProcess.options.mergemethod.Type    = 'radio_linelabel';
    sProcess.options.mergemethod.Value   = 'mergemesh';
    % Iso2mesh: Max tetrahedral volume
    sProcess.options.maxvol.Comment = 'Max tetrahedral volume (10=coarse, 0.0001=fine, default=0.1): ';
    sProcess.options.maxvol.Type    = 'value';
    sProcess.options.maxvol.Value   = {OPTIONS.MaxVol, '', 4};
    % Iso2mesh: keepratio: Percentage of elements being kept after the simplification
    sProcess.options.keepratio.Comment = 'Percentage of elements kept (default=100%): ';
    sProcess.options.keepratio.Type    = 'value';
    sProcess.options.keepratio.Value   = {OPTIONS.KeepRatio, '%', 0};
    % SimNIBS options:
    sProcess.options.opt2.Comment = '<BR><B>SimNIBS options</B>: ';
    sProcess.options.opt2.Type    = 'label';
    % SimNIBS: Vertex density
    sProcess.options.vertexdensity.Comment = 'Vertex density: nodes per mm2 (0.1-1.5, default=0.5): ';
    sProcess.options.vertexdensity.Type    = 'value';
    sProcess.options.vertexdensity.Value   = {OPTIONS.VertexDensity, '', 2};
    % SimNIBS: Number of vertices
    sProcess.options.nvertices.Comment = 'Number of vertices (CAT12 cortex): ';
    sProcess.options.nvertices.Type    = 'value';
    sProcess.options.nvertices.Value   = {15000, '', 0};
    % FieldTrip options:
    sProcess.options.opt3.Comment = '<BR><B>FieldTrip options</B>: ';
    sProcess.options.opt3.Type    = 'label';
    % FieldTrip: Downsample volume
    sProcess.options.downsample.Comment = 'Downsample volume (1=no downsampling): ';
    sProcess.options.downsample.Type    = 'value';
    sProcess.options.downsample.Value   = {OPTIONS.Downsample, '', 0};
    % FieldTrip: Node shift
    sProcess.options.nodeshift.Comment = 'Node shift [0 - 0.49]: ';
    sProcess.options.nodeshift.Type    = 'value';
    sProcess.options.nodeshift.Value   = {OPTIONS.NodeShift, '', 2};
    % Volumes options: 
    sProcess.options.opt0.Comment = '<BR><B>Input T1/T2 volumes</B>: <I>(SimNIBS, Brain2mesh)</I>';
    sProcess.options.opt0.Type    = 'label';
    % Volumes: Neck MNI Z-coordinate
    sProcess.options.zneck.Comment = 'Cut neck below MNI Z coordinate (0=disable): ';
    sProcess.options.zneck.Type    = 'value';
    sProcess.options.zneck.Value   = {OPTIONS.Zneck, '', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    OPTIONS = struct();
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
    % Volumes: Neck MNI Z-coordinate
    OPTIONS.Zneck = sProcess.options.zneck.Value{1};
    if isempty(OPTIONS.Zneck) || (OPTIONS.Zneck > 0)
        bst_report('Error', sProcess, [], 'Invalid neck MNI Z coordinate (must be negative or zero).');
        return
    end
    % Method
    OPTIONS.Method = sProcess.options.method.Value;
    if isempty(OPTIONS.Method) || ~ischar(OPTIONS.Method) || ~ismember(OPTIONS.Method, {'iso2mesh','brain2mesh','simnibs','fieldtrip'})
        bst_report('Error', sProcess, [], 'Invalid method.');
        return
    end
    % Iso2mesh: Merge method
    OPTIONS.MergeMethod = sProcess.options.mergemethod.Value;
    if isempty(OPTIONS.MergeMethod) || ~ischar(OPTIONS.MergeMethod) || ~ismember(OPTIONS.MergeMethod, {'mergesurf','mergemesh'})
        bst_report('Error', sProcess, [], 'Invalid merge method.');
        return
    end
    % Iso2mesh: Maximum tetrahedral volume
    OPTIONS.MaxVol = sProcess.options.maxvol.Value{1};
    if isempty(OPTIONS.MaxVol) || (OPTIONS.MaxVol < 0.000001) || (OPTIONS.MaxVol > 20)
        bst_report('Error', sProcess, [], 'Invalid maximum tetrahedral volume.');
        return
    end
    % Iso2mesh: Keep ratio (percentage 0-1)
    OPTIONS.KeepRatio = sProcess.options.keepratio.Value{1};
    if isempty(OPTIONS.KeepRatio) || (OPTIONS.KeepRatio < 1) || (OPTIONS.KeepRatio > 100)
        bst_report('Error', sProcess, [], 'Invalid kept element percentage.');
        return
    end
    OPTIONS.KeepRatio = OPTIONS.KeepRatio ./ 100;
    % SimNIBS: Maximum tetrahedral volume
    OPTIONS.VertexDensity = sProcess.options.vertexdensity.Value{1};
    if isempty(OPTIONS.VertexDensity) || (OPTIONS.VertexDensity < 0.01) || (OPTIONS.VertexDensity > 5)
        bst_report('Error', sProcess, [], 'Invalid vertex density.');
        return
    end
    % SimNIBS: Number of vertices
    OPTIONS.NbVertices = sProcess.options.nvertices.Value{1};
    if isempty(OPTIONS.NbVertices) || (OPTIONS.NbVertices < 20)
        bst_report('Error', sProcess, [], 'Invalid number of vertices.');
        return
    end
    % FieldTrip: Node shift
    OPTIONS.NodeShift = sProcess.options.nodeshift.Value{1};
    if isempty(OPTIONS.NodeShift) || (OPTIONS.NodeShift < 0) || (OPTIONS.NodeShift >= 0.5)
        bst_report('Error', sProcess, [], 'Invalid node shift.');
        return
    end
    % FieldTrip: Downsample volume 
    OPTIONS.Downsample = sProcess.options.downsample.Value{1};
    if isempty(OPTIONS.Downsample) || (OPTIONS.Downsample < 1) || (OPTIONS.Downsample - round(OPTIONS.Downsample) ~= 0)
        bst_report('Error', sProcess, [], 'Invalid downsampling factor.');
        return
    end
    
    % Call processing function
    [isOk, errMsg] = Compute(iSubject, [], 0, OPTIONS);
    % Handling errors
    if ~isOk
        bst_report('Error', sProcess, [], errMsg);
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== DEFAULT OPTIONS =====
function OPTIONS = GetDefaultOptions()
    OPTIONS = struct(...
        'Method',         'iso2mesh', ...      % {'iso2mesh', 'brain2mesh', 'simnibs', 'roast', 'fieldtrip'}
        'MeshType',       'tetrahedral', ...   % iso2mesh: 'tetrahedral';  simnibs: 'tetrahedral';  roast:'hexahedral'/'tetrahedral';  fieldtrip:'hexahedral'/'tetrahedral' 
        'MaxVol',         0.1, ...             % iso2mesh: Max tetrahedral volume (10=coarse, 0.0001=fine)
        'KeepRatio',      100, ...             % iso2mesh: Percentage of elements kept (1-100%)
        'BemFiles',       [], ...              % iso2mesh: List of layers to use for meshing (if not specified, use the files selected in the database 
        'MergeMethod',    'mergemesh', ...     % iso2mesh: {'mergemesh', 'mergesurf'} Function used to merge the meshes
        'VertexDensity',  0.5, ...             % SimNIBS: [0.1 - X] setting the vertex density (nodes per mm2)  of the surface meshes
        'NbVertices',     15000, ...           % SimNIBS: Number of vertices for the cortex surface imported from CAT12 
        'NodeShift',      0.3, ...             % FieldTrip: [0 - 0.49] Improves the geometrical properties of the mesh
        'Downsample',     3, ...               % FieldTrip: Integer, Downsampling factor to apply to the volumes before meshing
        'Zneck',          -115);               % Input T1/T2: Cut volumes below neck (MNI Z-coordinate)
end


%% ===== COMPUTE FEM MESHES =====
function [isOk, errMsg] = Compute(iSubject, iMris, isInteractive, OPTIONS)
    isOk = 0;
    errMsg = '';

    % ===== DEFAULT OPTIONS =====
    Def_OPTIONS = GetDefaultOptions();
    if isempty(OPTIONS)
        OPTIONS = Def_OPTIONS;
    else
        OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);
    end
    % Empty temporary folder, otherwise it reuses previous files in the folder
    gui_brainstorm('EmptyTempFolder');
            
    % ===== GET T1/T2 MRI =====
    % Get subject
    sSubject = bst_get('Subject', iSubject);
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
    if isempty(iMris)
        iMris = 1:length(sSubject.Anatomy);
        tryDefaultT2 = 0;
    else
        tryDefaultT2 = 1;
    end
    % If there are multiple MRIs: order them to put the default one first (probably a T1)
    if (length(iMris) > 1)
        % Select the default MRI as the T1
        if ismember(sSubject.iAnatomy, iMris)
            iT1 = sSubject.iAnatomy;
            iMris = iMris(iMris ~= sSubject.iAnatomy);
        else
            iT1 = [];
        end
        % Find other possible T1
        if isempty(iT1)
            iT1 = find(~cellfun(@(c)isempty(strfind(c,'t1')), lower({sSubject.Anatomy(iMris).Comment})));
            if ~isempty(iT1)
                iT1 = iMris(iT1(1));
                iMris = iMris(iMris ~= iT1);
            end
        end
        % Find any possible T2
        iT2 = find(~cellfun(@(c)isempty(strfind(c,'t2')), lower({sSubject.Anatomy(iMris).Comment})));
        if ~isempty(iT2)
            iT2 = iMris(iT2(1));
            iMris = iMris(iMris ~= iT2);
        else
            iT2 = [];
        end
        % If not identified yet, use first MRI as T1
        if isempty(iT1)
            iT1 = iMris(1);
            iMris = iMris(2:end);
        end
        % If not identified yet, use following MRI as T2
        if isempty(iT2) && tryDefaultT2
            iT2 = iMris(1);
        end
    else
        iT1 = iMris(1);
        iT2 = [];
    end
    % Get full file names
    T1File = file_fullpath(sSubject.Anatomy(iT1).FileName);
    if ~isempty(iT2)
        T2File = file_fullpath(sSubject.Anatomy(iT2).FileName);
    else
        T2File = [];
    end
        
    % ===== LOAD/CUT T1 =====
    if ismember(lower(OPTIONS.Method), {'brain2mesh', 'simnibs', 'roast'})
        sMriT1 = in_mri_bst(T1File);
        % Cut neck (below MNI coordinate below Z=Zneck)
        if (OPTIONS.Zneck < 0)
            [sMriT1tmp, maskCut, errNorm] = process_mri_deface('CutMriPlane', sMriT1, [0, 0, 1, -OPTIONS.Zneck./1000]);
            % Error handling (if MNI normalization failed)
            if ~isempty(errNorm)
                errMsg = ['Error trying to cut the neck from T1 using linear MNI normalization: ' 10 errNorm 10];
                % Do not return: This is only a warning
            elseif ~isempty(sMriT1tmp)
                sMriT1 = sMriT1tmp;
            end
        elseif (OPTIONS.Zneck > 0)
            errMsg = 'Invalid neck MNI Z coordinate (must be negative or zero).';
            return;
        end
    end

    % ===== LOAD/CUT T2 =====
    if ~isempty(T2File) && ismember(lower(OPTIONS.Method), {'brain2mesh', 'simnibs', 'roast'})
        sMriT2 = in_mri_bst(T2File);
        % Cut neck (below MNI coordinate below Z=Zneck)
        if (OPTIONS.Zneck < 0)
            [sMriT2tmp, maskCut, errNorm] = process_mri_deface('CutMriPlane', sMriT2, [0, 0, 1, -OPTIONS.Zneck./1000]);
            % Error handling (if MNI normalization failed)
            if ~isempty(errNorm)
                errMsg = ['Error trying to cut the neck from T1 using linear MNI normalization: ' 10 errNorm 10 10];
                % Do not return: This is only a warning
            elseif ~isempty(sMriT2tmp)
                sMriT2 = sMriT2tmp;
            end
        end
    end
    FemFile = [];
    
    % ===== GENERATE MESH =====
    switch lower(OPTIONS.Method)
        % Compute from OpenMEEG BEM layers: head, outerskull, innerskull
        case 'iso2mesh'
            % Install/load iso2mesh plugin
            [isInstalled, errInstall] = bst_plugin('Install', 'iso2mesh', isInteractive);
            if ~isInstalled
                errMsg = [errMsg, errInstall];
                return;
            end
            bst_plugin('SetProgressLogo', 'iso2mesh');
            % If surfaces are not passed in input: get default surfaces
            if isempty(OPTIONS.BemFiles)
                if ~isempty(sSubject.iScalp) && ~isempty(sSubject.iOuterSkull) && ~isempty(sSubject.iInnerSkull)
                    OPTIONS.BemFiles = {...
                        sSubject.Surface(sSubject.iInnerSkull).FileName, ...
                        sSubject.Surface(sSubject.iOuterSkull).FileName, ...
                        sSubject.Surface(sSubject.iScalp).FileName};
                    TissueLabels = {'brain', 'skull', 'scalp'};
                else
                    errMsg = [errMsg, 'Method "' OPTIONS.Method '" requires three surfaces: head, inner skull and outer skull.' 10 ...
                        'Create them with process "Generate BEM surfaces" first.'];
                    return;
                end
            % If surfaces are given: get their labels and sort from inner to outer
            else
                % Get tissue label
                for iBem = 1:length(OPTIONS.BemFiles)
                    [sSubject, iSubject, iSurface] = bst_get('SurfaceFile', OPTIONS.BemFiles{iBem});
                    if ~strcmpi(sSubject.Surface(iSurface).SurfaceType, 'Other')
                        TissueLabels{iBem} = GetFemLabel(sSubject.Surface(iSurface).SurfaceType);
                    else
                        TissueLabels{iBem} = GetFemLabel(sSubject.Surface(iSurface).Comment);
                    end
                end
                % Sort from inner to outer
                iSort = [];
                iOther = 1:length(OPTIONS.BemFiles);
                for label = {'white', 'gray', 'csf', 'skull', 'scalp'}
                    iLabel = find(strcmpi(label{1}, TissueLabels));
                    iSort = [iSort, iLabel];
                    iOther(iLabel) = NaN;
                end
                iSort = [iSort, iOther(~isnan(iOther))];
                OPTIONS.BemFiles = OPTIONS.BemFiles(iSort);
                TissueLabels = TissueLabels(iSort);
            end
            % Load surfaces
            bst_progress('text', 'Loading surfaces...');
            bemMerge = {};
            disp(' ');
            nBem = length(OPTIONS.BemFiles);
            for iBem = 1:nBem
                disp(sprintf('FEM> %d. %5s: %s', iBem, TissueLabels{iBem}, OPTIONS.BemFiles{iBem}));
                BemMat = in_tess_bst(OPTIONS.BemFiles{iBem});
                bemMerge = cat(2, bemMerge, BemMat.Vertices, BemMat.Faces);
            end
            disp(' ');
            % Merge all the surfaces
            bst_progress('text', ['Merging surfaces (Iso2mesh/' OPTIONS.MergeMethod ')...']);
            switch (OPTIONS.MergeMethod)
                % Faster and simpler: Simple concatenation without intersection checks
                case 'mergemesh'
                    % Concatenate meshes
                    [newnode, newelem] = mergemesh(bemMerge{:});
                    % Remove duplicated elements
                    % newelem = unique(sort(newelem,2),'rows');
                % Slower and more robust: Concatenates and checks for intersections (split intersecting elements)
                case 'mergesurf'
                    try
                        [newnode, newelem] = mergesurf(bemMerge{:});
                    catch
                        errMsg = [errMsg, 'Problem with the function MergeSurf. You can try with MergeMesh.'];
                        bst_progress('stop');
                        return;
                    end
                otherwise
                    error(['Invalid merge method: ' OPTIONS.MergeMethod]);
            end
            % Center of the head = barycenter of the innermost BEM layer (hopefully the inner skull?)
            center_inner = mean(bemMerge{1}, 1);
            % Find the intersection between the vertical axis (from the head center to the vertex) and all the BEM layers
            orig = center_inner;
            v0 = [0 0 1];
            [dist,tmp,tmp,iFace] = raytrace(orig,v0,newnode,newelem);
            dist = dist(iFace);
            % Sort from bottom to top
            [dist,I] = sort(dist);
            iFace = iFace(I);
            % Keep only superior part of the head (less chances of having multiple intersections for one layer)
            iFace = iFace(end-nBem+1:end);
            dist = dist(end-nBem+1:end);
            % Define region seeds for all the BEM regions: head center, then half-way between each layer
            dist = dist(:);
            distSeed = [0; (dist(1:end-1) + dist(2:end)) .* 0.5];
            regions = repmat(orig, nBem, 1) + distSeed * v0;
            
            % Create tetrahedral mesh
            bst_progress('text', 'Creating 3D mesh (Iso2mesh/surf2mesh)...');
            factor_bst = 1.e-6;
            [node,elem] = surf2mesh(newnode, newelem, min(newnode), max(newnode),...
                OPTIONS.KeepRatio, factor_bst .* OPTIONS.MaxVol, regions, [], [], 'tetgen1.5');
            
            % Removing the label 0 (Tetgen 1.4) or higher than number of layers (Tetgen 1.5)
            bst_progress('text', 'Fixing 3D mesh...');
            iOther = find((elem(:,5) == 0) & (elem(:,5) > nBem));
            if ~isempty(iOther) && (length(iOther) < 0.1 * length(elem))
                elem(iOther,:) = [];
            end
            % Check labelling from 1 to nBem
            allLabels = unique(elem(:,5));
            if ~isequal(allLabels(:)', 1:nBem)
                errMsg = [errMsg, 'Problem with Tetget: Brainstorm cannot understand the output labels (' num2str(allLabels(:)') ').'];
                bst_progress('stop');
                return;
            end
            
            % Mesh check and repair
            [no,el] = removeisolatednode(node,elem(:,1:4));
            % Orientation required for the FEM computation (at least with SimBio, maybe not for Duneuro)
            newelem = meshreorient(no, el(:,1:4));
            elem = [newelem elem(:,5)];
            node = no; % need to updates the new list of nodes (it's wiered that it was working before)
            % Only tetra could be generated from this method
            OPTIONS.MeshType = 'tetrahedral';

        case 'brain2mesh'
            disp([10 'FEM> T1 MRI: ' T1File]);
            disp(['FEM> T2 MRI: ' T2File 10]);
            % Install/load brain2mesh plugin
            [isInstalled, errInstall] = bst_plugin('Install', 'brain2mesh', isInteractive);
            if ~isInstalled
                errMsg = [errMsg, errInstall];
                return;
            end
            bst_plugin('SetProgressLogo', 'brain2mesh');
            % Get TPM.nii template
            tpmFile = bst_get('SpmTpmAtlas');
            if isempty(tpmFile) || ~file_exist(tpmFile)
                error('Missing file TPM.nii');
            end
            
            % === SAVE MRI AS NII ===
            bst_progress('text', 'Exporting MRI...');
            % Empty temporary folder, otherwise it may reuse previous files in the folder
            gui_brainstorm('EmptyTempFolder');
            % Create temporary folder for segmentation files
            tempDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'brain2mesh');
            mkdir(tempDir);
            % Save T1 MRI in .nii format
            subjid = strrep(sSubject.Name, '@', '');
            T1Nii = bst_fullfile(tempDir, [subjid 'T1.nii']);
            out_mri_nii(sMriT1, T1Nii);
            % Save T2 MRI in .nii format
            if ~isempty(T2File)
                T2Nii = bst_fullfile(tempDir, [subjid 'T2.nii']);
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
            
            % === CALL SPM SEGMENTATION ===
            bst_progress('text', 'MRI segmentation with SPM12...');
            % SPM batch for segmentation
            matlabbatch{1}.spm.spatial.preproc.channel(1).vols = {[T1Nii ',1']};
            matlabbatch{1}.spm.spatial.preproc.channel(1).biasreg = 0.001;
            matlabbatch{1}.spm.spatial.preproc.channel(1).biasfwhm = 60;
            matlabbatch{1}.spm.spatial.preproc.channel(1).write = [0 0];
            if ~isempty(T2Nii)
                matlabbatch{1}.spm.spatial.preproc.channel(2).vols = {[T2Nii ',1']};
                matlabbatch{1}.spm.spatial.preproc.channel(2).biasreg = 0.001;
                matlabbatch{1}.spm.spatial.preproc.channel(2).biasfwhm = 60;
                matlabbatch{1}.spm.spatial.preproc.channel(2).write = [0 0];
            end
            matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {[tpmFile, ',1']};
            matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
            matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {[tpmFile, ',2']};
            matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
            matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {[tpmFile, ',3']};
            matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
            matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {[tpmFile, ',4']};
            matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
            matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {[tpmFile, ',5']};
            matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
            matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {[tpmFile, ',6']};
            matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
            matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];
            matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
            matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
            matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
            matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
            matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
            matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
            matlabbatch{1}.spm.spatial.preproc.warp.write = [0 0];
            % Call SPM batch
            spm_jobman('run', matlabbatch);
            % Check for success
            testFile = bst_fullfile(tempDir, ['c5' subjid 'T1.nii']);
            if ~file_exist(testFile)
                errMsg = [errMsg, 'SPM12 segmentation failed: missing output file "' testFile '".'];
                return;
            end
            % Read outputs
            sTpm = in_mri_nii(bst_fullfile(tempDir, ['c1' subjid 'T1.nii']), 0, 0, 0);
            seg.gm = sTpm.Cube;
            sTpm = in_mri_nii(bst_fullfile(tempDir, ['c2' subjid 'T1.nii']), 0, 0, 0);
            seg.wm = sTpm.Cube;
            sTpm = in_mri_nii(bst_fullfile(tempDir, ['c3' subjid 'T1.nii']), 0, 0, 0);
            seg.csf = sTpm.Cube;
            sTpm = in_mri_nii(bst_fullfile(tempDir, ['c4' subjid 'T1.nii']), 0, 0, 0);
            seg.skull = sTpm.Cube;
            sTpm = in_mri_nii(bst_fullfile(tempDir, ['c5' subjid 'T1.nii']), 0, 0, 0);
            seg.scalp = sTpm.Cube;

            % ===== CALL BRAIN2MESH =====
            bst_progress('text', 'Meshing with Brain2Mesh...');
            [node,elem] = brain2mesh(seg);
            % Handle errors
            if isempty(elem)
                errMsg = [errMsg, 'Mesh generation with Brain2Mesh/tetgen1.5 failed.'];
                return;
            end
            % Remove unwanted tissues (label <= 0)
            iRemove = find(elem(:,end) <= 0);
            if ~isempty(iRemove)
                elem(iRemove,:) = [];
            end
            % Relabel the tissues in the same order as the other options
            iRelabel = [5 4 3 2 1];
            elem(:,end) = reshape(iRelabel(elem(:,end)), [], 1);
            % Name tissue labels
            TissueLabels = {'white','gray','csf','skull','scalp'};
            
            
        case 'simnibs'
            disp(['FEM> T1 MRI: ' T1File]);
            disp(['FEM> T2 MRI: ' T2File]);
            % Check for SimNIBS installation
            status = system('headreco --version');
            if (status ~= 0)
                errMsg = [errMsg, 'SimNIBS is not installed or not added to the system path:' 10 'the command "headreco" could not be found.' 10 10 'To install SimNIBS, visit: https://simnibs.github.io/simnibs'];
                return;
            end

            % ===== VERIFY FIDUCIALS IN T1 MRI =====
            % If the SCS transformation is not defined: compute MNI transformation to get a default one
            if isempty(sMriT1) || ~isfield(sMriT1, 'SCS') || ~isfield(sMriT1.SCS, 'NAS') || ~isfield(sMriT1.SCS, 'LPA') || ~isfield(sMriT1.SCS, 'RPA') || (length(sMriT1.SCS.NAS)~=3) || (length(sMriT1.SCS.LPA)~=3) || (length(sMriT1.SCS.RPA)~=3) || ~isfield(sMriT1.SCS, 'R') || isempty(sMriT1.SCS.R) || ~isfield(sMriT1.SCS, 'T') || isempty(sMriT1.SCS.T)
                % Issue warning
                bst_report('Warning', 'process_fem_mesh', [], 'Missing NAS/LPA/RPA: Computing the MNI transformation to get default positions.');
                % Compute MNI normalization
                [sMriT1, errNorm] = bst_normalize_mni(sMriT1);
                % Handle errors
                if ~isempty(errNorm)
                    errMsg = [errMsg, 'Error trying to compute the MNI transformation: ' 10 errNorm 10 'Set the NAS/LPA/RPA fiducials manually.'];
                    return;
                end
            end

            % === SAVE T1 MRI AS NII ===
            bst_progress('text', 'Exporting MRI...');
            % Empty temporary folder, otherwise it may reuse previous files in the folder
            gui_brainstorm('EmptyTempFolder');
            % Create temporary folder for segmentation files
            simnibsDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'simnibs');
            mkdir(simnibsDir);
            % Save T1 MRI in .nii format
            subjid = strrep(sSubject.Name, '@', '');
            T1Nii = bst_fullfile(simnibsDir, [subjid 'T1.nii']);
            out_mri_nii(sMriT1, T1Nii);
            % Save T2 MRI in .nii format
            if ~isempty(T2File)
                T2Nii = bst_fullfile(simnibsDir, [subjid 'T2.nii']);
                out_mri_nii(sMriT2, T2Nii);
            else
                T2Nii = [];
            end

            % === CALL SIMNIBS PIPELINE ===
            bst_progress('text', 'Calling SimNIBS/headreco...');
            % Go to simnibs working directory
            curDir = pwd;
            cd(simnibsDir);
            % Call headreco
             if OPTIONS.VertexDensity ~= 0.5
                strCall = ['headreco all --noclean -v ' num2str(OPTIONS.VertexDensity) ' ' subjid ' '  T1Nii ' ' T2Nii];
            else % call the default option, where VertexDensity is fixed to 0.5
                strCall = ['headreco all --noclean  ' subjid ' ' T1Nii ' ' T2Nii];
            end
            status = system(strCall)
            % Restore working directory
            cd(curDir);
            % If SimNIBS returned an error
            if (status ~= 0)
                errMsg = [errMsg, 'SimNIBS call: ', strrep(strCall, ' "', [10 '      "']),  10 10 ...
                          'SimNIBS error #' num2str(status) ': See command window.'];
                return;
            end
                  
            % === IMPORT OUTPUT FOLDER ===
            [errorImport, FemFile] = import_anatomy_simnibs(iSubject, simnibsDir, OPTIONS.NbVertices, isInteractive, [], 0, 1);
            % Handle errors
            if ~isempty(errorImport)
                errMsg = [errMsg, 'Error trying to import the SimNIBS output: ' 10 errorImport];
                return;
            end
            % Only tetra could be generated from this method
            OPTIONS.MeshType = 'tetrahedral';
            
        case 'fieldtrip'
            % Segmentation process
            OPTIONS.layers     = {'white','gray','csf','skull','scalp'};
            OPTIONS.isSaveTess = 0;
            [isOk, errFt, TissueFile] = process_ft_volumesegment('Compute', iSubject, iT1, OPTIONS);
            if ~isOk
                errMsg = [errMsg, errFt];
                return;
            end
            TissueLabels = OPTIONS.layers;
            % Get index of tissue file
            [sSubject, iSubject, iTissue] = bst_get('MriFile', TissueFile);
            % Mesh process
            [isOk, errFt, FemFile] = process_ft_prepare_mesh_hexa('Compute', iSubject, iTissue, OPTIONS);
            if ~isOk
                errMsg = [errMsg, errFt];
                return;
            end

        case 'roast'                      
            disp(['FEM> T1 MRI: ' T1File]);
            disp(['FEM> T2 MRI: ' T2File]);
            % Install/load ROAST plugin
            [isInstalled, errInstall] = bst_plugin('Install', 'roast', isInteractive);
            if ~isInstalled
                errMsg = [errMsg, errInstall];
                return;
            end
            bst_plugin('SetProgressLogo', 'roast');
            
            % ===== VERIFY FIDUCIALS IN T1 MRI =====
            % If the SCS transformation is not defined: compute MNI transformation to get a default one
            if isempty(sMriT1) || ~isfield(sMriT1, 'SCS') || ~isfield(sMriT1.SCS, 'NAS') || ~isfield(sMriT1.SCS, 'LPA') || ~isfield(sMriT1.SCS, 'RPA') || (length(sMriT1.SCS.NAS)~=3) || (length(sMriT1.SCS.LPA)~=3) || (length(sMriT1.SCS.RPA)~=3) || ~isfield(sMriT1.SCS, 'R') || isempty(sMriT1.SCS.R) || ~isfield(sMriT1.SCS, 'T') || isempty(sMriT1.SCS.T)
                % Issue warning
                bst_report('Warning', 'process_fem_mesh', [], 'Missing NAS/LPA/RPA: Computing the MNI transformation to get default positions.');
                % Compute MNI normalization
                [sMriT1, errNorm] = bst_normalize_mni(sMriT1);
                % Handle errors
                if ~isempty(errNorm)
                    errMsg = [errMsg, 'Error trying to compute the MNI transformation: ' 10 errNorm 10 'Set the NAS/LPA/RPA fiducials manually.'];
                    return;
                end
            end            
            % === SAVE T1 MRI AS NII ===
            bst_progress('setimage', 'plugins/roast_logo.gif');
            bst_progress('text', 'Exporting MRI...');
            % Empty temporary folder, otherwise it may reuse previous files in the folder
            gui_brainstorm('EmptyTempFolder');
            % Create temporary folder for fieldtrip segmentation files
            roastDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'roast');
            mkdir(roastDir);
            % Save MRI in .nii format
            subjid = strrep(sSubject.Name, '@', '');
            T1Nii = bst_fullfile(roastDir, [subjid 'T1.nii']);
            out_mri_nii(sMriT1, T1Nii);
            % Save T2 MRI in .nii format
            if ~isempty(T2File)
                T2Nii = bst_fullfile(roastDir, [subjid 'T2.nii']);
                out_mri_nii(sMriT2, T2Nii);
                segTag = '_T1andT2';
            else
                T2Nii = [];
                segTag = '_T1orT2';
            end
            % === ROAST: SEGMENTATION (SPM) ===
            bst_progress('text', 'ROAST: MRI segmentation (SPM)...');
            % Check for segmented images
            segNii = bst_fullfile(roastDir, ['c1' subjid 'T1' segTag '.nii']);
            if file_exist(segNii)
                disp(['ROAST> SPM segmented MRI found: ' segNii]);
            % ROAST: Start MRI segmentation
            else
                start_seg(T1Nii, T2Nii);
                close all;
                % Error handling
                if ~file_exist(segNii)
                    errMsg = [errMsg, 'ROAST: MRI segmentation (SPM) failed.'];
                    return;
                end
            end
            % === ROAST: SEGMENTATION TOUCHUP ===
            bst_progress('text', 'ROAST: MRI segmentation touchup...');
            % Check for segmented images
            touchNii = bst_fullfile(roastDir, [subjid 'T1' segTag '_masks.nii']);
            if file_exist(touchNii)
                disp(['ROAST> Final masks found: ' touchNii]);
            % ROAST: Start MRI segmentation
            else
                segTouchup(T1Nii, T2Nii);
                % Error handling
                if ~file_exist(touchNii)
                    errMsg = [errMsg, 'ROAST: MRI segmentation touchup failed.'];
                    return;
                end
                % Save to the database
                import_mri(iSubject, touchNii, [], 0, 1, 'tissues');
            end
            % === ROAST: MESH GENERATION ===
            bst_progress('text', 'ROAST: Mesh generation (iso2mesh)...');
            % Load segmentation masks
            sMasks = in_mri_nii(touchNii, 0, 0, 0);
            % Call iso2mesh for mesh generation
            meshOpt = struct(...
                'radbound',  5, ...
                'angbound',  30,...
                'distbound', 0.3, ...
                'reratio',   3);
            maxvol = 10;
            [node,elem] = cgalv2m(sMasks.Cube, meshOpt, maxvol);
            % Error handling
            if isempty(elem)
                errMsg = [errMsg, 'Mesh generation failed (iso2mesh/cgalv2m).'];
                return;
            end
            % Fix for voxel space
            node(:,1:3) = node(:,1:3) + 0.5; 

            % Remove unwanted tissues (label <= 0)
            iRemove = find(elem(:,end) <= 0);
            if ~isempty(iRemove)
                elem(iRemove,:) = [];
            end
            % Relabel the air as skin (maybe in the future we may distinguish the aire? to check)
            iAir = find(elem(:,end) > 5);
            elem(iAir,:) = 5; 
            % Name tissue labels
            TissueLabels = {'white','gray','csf','skull','scalp'};
            OPTIONS.MeshType = 'tetrahedral';
            % convert node from VOX to SCS
            [node, Transf] = cs_convert(sMriT1, 'voxel', 'scs', node(:,1:3));     
            % Mesh check and repair
            [no,el] = removeisolatednode(node,elem(:,1:4));
            % Orientation required for the FEM computation (at least with SimBio, maybe not for Duneuro)
            newelem = meshreorient(no, el(:,1:4));
            elem = [newelem elem(:,5)];
            node = no; % need to updates the new list         
            
        otherwise
            errMsg = [errMsg, 'Invalid method "' OPTIONS.Method '".'];
            return;
    end
    % Remove logos
    bst_plugin('SetProgressLogo', []);


    % ===== SAVE FEM MESH =====
    bst_progress('text', 'Saving FEM mesh...');
    % Save FemFile if not already done above
    if isempty(FemFile)
        % Create output structure
        FemMat = db_template('femmat');
        if ~isempty(TissueLabels)
            FemMat.TissueLabels = TissueLabels;
        else
            uniqueLabels = unique(FemMat.Tissue);
            for i = 1:length(uniqueLabels)
                 FemMat.TissueLabels{i} = num2str(uniqueLabels(i));
            end
        end
        FemMat.Comment = sprintf('FEM %dV (%s, %d layers)', length(node), OPTIONS.Method, length(FemMat.TissueLabels));
        FemMat.Vertices = node;
        if strcmp(OPTIONS.MeshType, 'tetrahedral')
            FemMat.Elements = elem(:,1:4);
            FemMat.Tissue = elem(:,5);
        else
            FemMat.Elements = elem(:,1:8);
            FemMat.Tissue = elem(:,9);
        end
        % Add history
        FemMat = bst_history('add', FemMat, 'process_fem_mesh', OPTIONS);
        % Save to database
        FemFile = file_unique(bst_fullfile(bst_fileparts(T1File), sprintf('tess_fem_%s_%dV.mat', OPTIONS.Method, length(FemMat.Vertices))));
        bst_save(FemFile, FemMat, 'v7');
        db_add_surface(iSubject, FemFile, FemMat.Comment);
    % Otherwise: just add the options string to the history
    else
        bst_history('add', FemFile, 'process_fem_mesh', OPTIONS);
    end
    % Return success
    isOk = 1;
end


%% ===== GET FEM LABEL =====
function label = GetFemLabel(label)
    label = lower(label);
    if ~isempty(strfind(label, 'white')) || ~isempty(strfind(label, 'wm'))
        label = 'white';
    elseif ~isempty(strfind(label, 'brain')) || ~isempty(strfind(label, 'grey')) || ~isempty(strfind(label, 'gray')) || ~isempty(strfind(label, 'gm')) || ~isempty(strfind(label, 'cortex'))
        label = 'gray';
    elseif ~isempty(strfind(label, 'csf')) || ~isempty(strfind(label, 'inner'))
        label = 'csf';
    elseif ~isempty(strfind(label, 'bone')) || ~isempty(strfind(label, 'skull')) || ~isempty(strfind(label, 'outer'))
        label = 'skull';
    elseif ~isempty(strfind(label, 'skin')) || ~isempty(strfind(label, 'scalp')) || ~isempty(strfind(label, 'head'))
        label = 'scalp';
    end
end


%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iMris, BemFiles) %#ok<DEFNU>
    % Get inputs
    if (nargin < 3) || isempty(BemFiles)
        BemFiles = [];
    end
    if (nargin < 2) || isempty(iMris)
        iMris = [];
    end
    % Get default options
    OPTIONS = GetDefaultOptions();
    % If BEM surfaces are selected, the only possible method is "iso2mesh"
    if ~isempty(BemFiles) && iscell(BemFiles)
        OPTIONS.Method = 'iso2mesh';
        OPTIONS.BemFiles = BemFiles;
    % Otherwise: Ask for method to use
    else
        res = java_dialog('question', [...
            '<HTML><B>Iso2mesh</B>:<BR>Call iso2mesh to create a tetrahedral mesh from the <B>BEM surfaces</B><BR>' ...
            'generated with Brainstorm (head, inner skull, outer skull).<BR>' ...
            '<FONT COLOR="#707070"><I>Iso2mesh is downloaded and installed automatically when needed.</I></FONT><BR><BR>' ...
            '<B>Brain2mesh</B>:<BR>Segment the <B>T1</B> (and <B>T2</B>) <B>MRI</B> with SPM12, mesh with Brain2Mesh.<BR>' ...
            'Brain2Mesh is downloaded and installed automatically by Brainstorm.<BR>' ...
            '<FONT COLOR="#707070"><I>Brain2mesh and SPM12 are downloaded and installed automatically when needed.</I></FONT><BR><BR>' ...
            '<B>SimNIBS</B>:<BR>Call SimNIBS to segment and mesh the <B>T1</B> (and <B>T2</B>) <B>MRI</B>.<BR>' ...
            '<FONT COLOR="#707070"><I>SimNIBS must be installed on the computer first.<BR>' ...
            'Website: https://simnibs.github.io/simnibs</I></FONT><BR><BR>' ...
             '<B>ROAST</B>:<BR>Call ROAST to segment and mesh the <B>T1</B> (and <B>T2</B>) MRI.<BR>' ...
            '<FONT COLOR="#707070"><I>ROAST is downloaded and installed automatically when needed.</I></FONT><BR><BR>'...
            '<B>FieldTrip</B>:<BR>Call FieldTrip to segment and mesh the <B>T1</B> MRI.<BR>' ...
            '<FONT COLOR="#707070"><I>FieldTrip is downloaded and installed automatically when needed.</I></FONT><BR><BR>' ...
            ], 'FEM mesh generation method', [], {'Iso2mesh','Brain2Mesh','SimNIBS','ROAST','FieldTrip'}, 'Iso2mesh');
        if isempty(res)
            return
        end
        OPTIONS.Method = lower(res);
    end
    
    % Other options: Switch depending on the method
    switch (OPTIONS.Method)
        case 'iso2mesh'
            % Ask merging method
            res = java_dialog('question', [...
                '<HTML>Iso2mesh function used to merge the input surfaces:<BR><BR>', ...
                '<B>MergeMesh</B>: Default option (faster).<BR>' ...
                'Simply concatenates the meshes without any intersection checks.<BR><BR>' ...
                '<B>MergeSurf</B>: Advanced option (slower).<BR>' ...
                'Concatenates and checks for intersections, split intersecting elements.<BR><BR>' ...
                ], 'FEM mesh generation (Iso2mesh)', [], {'MergeMesh','MergeSurf'}, 'MergeMesh');
            if isempty(res)
                return
            end
            OPTIONS.MergeMethod = lower(res);
            % Ask BEM meshing options
            res = java_dialog('input', {'Max tetrahedral volume (10=coarse, 0.0001=fine):', 'Percentage of elements kept (1-100%):'}, ...
                'FEM mesh', [], {num2str(OPTIONS.MaxVol), num2str(OPTIONS.KeepRatio)});
            if isempty(res)
                return
            end
            % Get new values
            OPTIONS.MaxVol    = str2num(res{1});
            OPTIONS.KeepRatio = str2num(res{2}) ./ 100;
            if isempty(OPTIONS.MaxVol) || (OPTIONS.MaxVol < 0.000001) || (OPTIONS.MaxVol > 20) || ...
                    isempty(OPTIONS.KeepRatio) || (OPTIONS.KeepRatio < 0.01) || (OPTIONS.KeepRatio > 1)
                bst_error('Invalid options.', 'FEM mesh', 0);
                return
            end

        case 'brain2mesh'
            % No extra options
            
        case 'simnibs'    
            % Ask for the Vertex density
            res = java_dialog('input', '<HTML>Vertex density:<BR>Number of nodes per mm2 of the surface meshes (0.1 - 1.5)', ...
                'SimNIBS Vertex Density', [], num2str(OPTIONS.VertexDensity));
            if isempty(res) || (length(str2num(res)) ~= 1)
                return
            end
            OPTIONS.VertexDensity = str2num(res);
            % Ask number of vertices
            res = java_dialog('input', 'Number of vertices on the CAT12 cortex surface:', 'Import CAT12 folder', [], '15000');
            if isempty(res)
                return
            end
            OPTIONS.NbVertices = str2double(res);

        case 'fieldtrip'
            % Ask user for the downsampling factor
            [res, isCancel]  = java_dialog('input', ['Downsample volume before meshing:' 10 '(integer, 1=no downsampling)'], ...
                'FieldTrip FEM mesh', [], num2str(OPTIONS.Downsample));
            if isCancel || isempty(str2double(res))
                return
            end
            OPTIONS.Downsample = str2double(res);
            % Ask user for the node shifting
            [res, isCancel]  = java_dialog('input', 'Shift the nodes to fit geometry [0-0.49]:', ...
                'FieldTrip FEM mesh', [], num2str(OPTIONS.NodeShift));
            if isCancel || isempty(str2double(res))
                return
            end
            OPTIONS.NodeShift = str2double(res);
            
        case 'roast'
            % No extra options for now
            OPTIONS.MeshType =  'tetrahedral';
    end

    % Open progress bar
    bst_progress('start', 'Generate FEM mesh', ['Generating FEM mesh (' OPTIONS.Method ')...']);
    % Generate FEM mesh
    try
        [isOk, errMsg] = Compute(iSubject, iMris, 1, OPTIONS);
        % Error handling
        if ~isOk
            bst_error(errMsg, 'FEM mesh', 0);
        elseif ~isempty(errMsg)
            java_dialog('msgbox', ['Warning: ' errMsg]);
        end
    catch
        bst_error();
        bst_error(['The FEM mesh generation failed.' 10 'Check the Matlab command window for additional information.' 10], 'Generate FEM mesh', 0);
    end
    % Close progress bar
    bst_progress('stop');
end


%% ===== HEXA <=> TETRA =====
function NewFemFile = SwitchHexaTetra(FemFile) %#ok<DEFNU>
    % Get file in database
    [sSubject, iSubject] = bst_get('SurfaceFile', FemFile);
    FemFullFile = file_fullpath(FemFile);
    % Get dimensions of the Elements variable
    elemSize = whos('-file', FemFullFile, 'Elements');
    % Check type of the mesh
    if isempty(elemSize) || (length(elemSize.size) ~= 2) || ~ismember(elemSize.size(2), [4 8])
        error(['Invalid FEM mesh file: ' FemFile]);
    elseif (elemSize.size(2) == 8)
        NewFemFile = fem_hexa2tetra(FemFullFile);
    elseif (elemSize.size(2) == 4)
        NewFemFile = fem_tetra2hexa(FemFullFile);
    end
end
