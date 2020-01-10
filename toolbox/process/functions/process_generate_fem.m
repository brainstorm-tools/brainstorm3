function varargout = process_generate_fem( varargin )
% PROCESS_GENERATE_FEM: Generate tetrahedral FEM mesh.
%
% USAGE:     OutputFiles = process_generate_fem('Run',     sProcess, sInputs)
%         [isOk, errMsg] = process_generate_fem('Compute', iSubject, iAnatomy=[default])

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
% Authors: Francois Tadel, Takfarinas Medani, 2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
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
    sProcess.isSeparator = 1;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Option: Maximum volume: Max volume of the tetra element, option used by iso2mesh, in this script it will multiplied by e-6;
    % range from 10 for corse mesh to 1e-4 or less for very fine mesh
    sProcess.options.maxvol.Comment = 'Max tetrahedral volume (10=coarse, 0.0001=fine, default=0.1): ';
    sProcess.options.maxvol.Type    = 'value';
    sProcess.options.maxvol.Value   = {0.1, '', 4};
    % Option: keepratio: Percentage of elements being kept after the simplification
    sProcess.options.keepratio.Comment = 'Percentage of elements kept (default=100%): ';
    sProcess.options.keepratio.Type    = 'value';
    sProcess.options.keepratio.Value   = {100, '%', 0};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    OPTIONS = struct();
    % Maximum tetrahedral volume
    OPTIONS.maxvol = sProcess.options.maxvol.Value{1};
    if isempty(OPTIONS.maxvol) || (OPTIONS.maxvol < 0.000001) || (OPTIONS.maxvol > 20)
        bst_report('Error', sProcess, [], 'Invalid maximum tetrahedral volume.');
        return
    end
    % Keep ratio (percentage 0-1)
    OPTIONS.keepratio = sProcess.options.keepratio.Value{1};
    if isempty(OPTIONS.keepratio) || (OPTIONS.keepratio < 1) || (OPTIONS.keepratio > 100)
        bst_report('Error', sProcess, [], 'Invalid kept element percentage.');
        return
    end
    OPTIONS.keepratio = OPTIONS.keepratio ./ 100;
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


%% ===== COMPUTE FEM MESHES =====
function [isOk, errMsg] = Compute(iSubject, iAnatomy, isInteractive, OPTIONS)
    isOk = 0;
    errMsg = '';

    % ===== DEFAULT OPTIONS =====
    Def_OPTIONS = struct(...
        'Method',    'bemsurf', ...
        'MaxVol',    0.1, ...
        'KeepRatio', 1);
    if isempty(OPTIONS)
        OPTIONS = Def_OPTIONS;
    else
        OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);
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
    MriFile = file_fullpath(sSubject.Anatomy(iAnatomy).FileName);

    % Get default surfaces
    if ~isempty(sSubject.iScalp)
        HeadFile = sSubject.Surface(sSubject.iScalp).FileName;
    else
        HeadFile = [];
    end
    if ~isempty(sSubject.iOuterSkull)
        OuterFile = sSubject.Surface(sSubject.iOuterSkull).FileName;
    else
        OuterFile = [];
    end
    if ~isempty(sSubject.iInnerSkull)
        InnerFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
    else
        InnerFile = [];
    end
    % Empty output structure
    FemMat = db_template('femmat');
    
    % ===== GENERATE TETRAHEDRAL MESH =====
    switch lower(OPTIONS.Method)
        % Compute from OpenMEEG BEM layers: head, outerskull, innerskull
        case 'bemsurf'
            % Check if iso2mesh is in the path
            if ~exist('iso2meshver', 'file') || ~isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
                errMsg = InstallIso2mesh(isInteractive);
                if ~isempty(errMsg) || ~exist('iso2meshver', 'file') || ~isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
                    return;
                end
            end
            % Check surfaces
            if isempty(HeadFile) || isempty(OuterFile) || isempty(InnerFile)
                errMsg = ['Method "' OPTIONS.Method '" requires three surfaces: head, inner skull and outer skull.' 10 ...
                    'Create them with process "Generate BEM surfaces" first.'];
                return;
            end
            % Load surfaces
            HeadMat  = in_tess_bst(HeadFile);
            OuterMat = in_tess_bst(OuterFile);
            InnerMat = in_tess_bst(InnerFile);

            % Merge all the surfaces
            if OPTIONS.NumberOfbLayers == 3
                [newnode, newelem] = mergemesh(HeadMat.Vertices,  HeadMat.Faces,...
                    OuterMat.Vertices, OuterMat.Faces,...
                    InnerMat.Vertices, InnerMat.Faces);
                OPTIONS.TissueLabels = {'brain','skull','scalp'};
            elseif OPTIONS.NumberOfbLayers == 4
                depth = -OPTIONS.skullThikness/1000;  % thickness of the new layer that should be the skull
                [NewVertices, NewFaces] = inflateORdeflate_surface(OuterMat.Vertices, OuterMat.Faces, depth);
                % Merge the surfaces
                [newnode,newelem]=mergemesh(HeadMat.Vertices,  HeadMat.Faces,...
                    NewVertices, NewFaces,...
                    OuterMat.Vertices, OuterMat.Faces,...
                    InnerMat.Vertices, InnerMat.Faces);
                OPTIONS.TissueLabels = {'brain','csf','skull','scalp'};
            end
            % PREVIOUS VERSION
            %            % Find the seed point for each region
            %             center_inner = mean(InnerMat.Vertices);
            %             [tmp_,tmp_,tmp_,tmp_,seedRegion1] = raysurf(center_inner, [0 0 1], InnerMat.Vertices, InnerMat.Faces);
            %             [tmp_,tmp_,tmp_,tmp_,seedRegion2] = raysurf(center_inner, [0 0 1], OuterMat.Vertices, OuterMat.Faces);
            %             [tmp_,tmp_,tmp_,tmp_,seedRegion3] = raysurf(center_inner, [0 0 1], HeadMat.Vertices, HeadMat.Faces);
            %             regions = [seedRegion1; seedRegion2; seedRegion3];

            % NEW VERSION
            % Find the seed point for each region
            center_inner = mean(InnerMat.Vertices);
            % define seeds along the electrode axis
            orig = center_inner; 
            v0= [0 0 1];
            [t,tmp,tmp,faceidx] = raytrace(orig,v0,newnode,newelem);
            t = sort(t(faceidx)); 
            t=(t(1:end-1)+t(2:end))*0.5; 
            seedlen=length(t);
            regions = repmat(orig(:)',seedlen,1) + repmat(v0(:)',seedlen,1) .* repmat(t(:),1,3);

            % Create tetrahedral mesh
            factor_bst = 1.e-6;
            [node,elem] = surf2mesh(newnode, newelem, min(newnode), max(newnode),...
                OPTIONS.KeepRatio, factor_bst .* OPTIONS.MaxVol, regions, []);
            % Sorting compartments from the center of the head
            allLabels = unique(elem(:,5));
            dist = zeros(1, length(allLabels));
            for iLabel = 1:length(allLabels)
                iElem = find(elem(:,5) == allLabels(iLabel));
                iVert = unique(reshape(elem(iElem,1:4), [], 1));
                dist(iLabel) = min(sum(node(iVert,:) .^ 2,2));
            end
            [tmp, I] = sort(dist);
            allLabels = allLabels(I);
            % Relabelling
            elemLabel = ones(size(elem,1),1);
            for iLabel = 1:length(allLabels)
                elemLabel((elem(:,5) == allLabels(iLabel))) = iLabel;
            end
            elem(:,5) = elemLabel;
            % Mesh check and repair
            [no,el] = removeisolatednode(node,elem(:,1:4));
            % Orientation required for the FEM computation (at least with SimBio, may be not for Duneuro)
            newelem = meshreorient(no, el(:,1:4));
            elem = [newelem elem(:,5)];
            % Only tetra could be generated from this method
            OPTIONS.meshType = 'Tetrahedral';


        case 'simnibs'
            % TODO : Check if SIMNIBS is installed otherwise, download and
            % install
            %         if ~exist('simnibs', 'file')
            %             errMsg = InstallSimNibs(isInteractive);
            %             if ~isempty(errMsg) || ~exist('simnibs', 'file')
            %                 return;
            %             end
            %         end

            % === SAVE MRI AS NII ===
            % Empty temporary folder, otherwise it reuses previous files in the folder
            gui_brainstorm('EmptyTempFolder');
            % Create temporary folder for fieldtrip segmentation files
            simnibsDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'simnibs');
            mkdir(simnibsDir);
            % Save MRI in .nii format
            NiiFile = bst_fullfile(simnibsDir, 'simnibsT1.nii');
            out_mri_nii(bst_fullfile(MriFile, NiiFile));
            % TODO : Add the T2 if exists

            % === CALL SIMNIBS PIPELINE ===
            pathToT1 = NiiFile;
            pathToT2 = []; % TODO : ask user if there is any T2 image  and ask for the path
            outputMeshFilename = 'SimNibsMesh';
            commandLine = ['headreco all --noclean  ' MriFile ' ' outputMeshFilename ' ' pathToT1 ' ' pathToT2];
            system(commandLine)
            % === IMPORT OUTPUT FOLDER ===
            % Import FEM mesh
            % load the mesh and change to bst coordinates :
            mshfilename = bst_fullfile(simnibsDir,[outputMeshFilename '.msh']);
            femhead = bst_msh2bst(mshfilename); %  this could be load to bst as it is.

            % Set to the bst coordinates
            % Call Jaun process
            sMri = load(MriFile);

            T1 = diag([sMri.Voxsize(:) ./1000; 1]); % scale trans from mm to meters
            T2 = [sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1]; % rotate and translate from vox to scs.
            if ~isempty(sMri.InitTransf)
                T = T2 * T1 * inv(sMri.InitTransf{1,2}) * [1 0 0 1; 0 1 0 1; 0 0 1 1; 0 0 0 1];
            else
                T = T2 * T1 * [1 0 0 1; 0 1 0 1; 0 0 1 1; 0 0 0 1];
            end
            %we add a voxel because there is a mismatch between origins,
            %then transform from world to vox, then apply from vox to scs
            clear T1 T2 sMri

            Vertices = femhead.Vertices;
            % Transform the coordinates
            temp = [Vertices ones(size(Vertices,1),1)]; clear Vertices
            temp = (T * temp')';
            temp(:,4)=[];
            % final mesh to save to bst
            node = temp; clear temp;

            % replace the eyes per the scalp (not used for now)
            femhead.Tissue(femhead.Tissue==6) = 5;

            % Get the number of layers
            if OPTIONS.NumberOfbLayers == 4 % {'brain'  'csf'  'skull'  'scalp'}
                % replace the GM by WM and use unique label
                femhead.Tissue(femhead.Tissue== 2) = 1; % gm to wm and all form brain with label 1
                % relabel
                femhead.Tissue(femhead.Tissue== 3) = 2; % csf label 2
                femhead.Tissue(femhead.Tissue== 4) = 3; % skull label 3
                femhead.Tissue(femhead.Tissue== 5) = 4; % scalp label 4
            end
            if OPTIONS.NumberOfbLayers == 3 % {'brain'  'skull'  'scalp'}
                % replace the SCF, GM by WM and use unique label
                femhead.Tissue(femhead.Tissue== 2) = 1; % gm to wm and all form brain label 1
                femhead.Tissue(femhead.Tissue== 3) = 1; % csf to wm and all form brain label 1
                % relabel
                femhead.Tissue(femhead.Tissue== 4) = 2; % skull label 2
                femhead.Tissue(femhead.Tissue== 5) = 3; % scalp label 3
            end
            elem = [femhead.Elements femhead.Tissue];
            clear femhead

            % If Hexa ==> Convert the tetra to hexa or use the fieldtrip
            % pipline to mesh as hexa
            % Load all the masks from simnibs folder and hen run the hexa
            % generation

            % Update the OPTIONS
            OPTIONS.NumberOfbLayers  = length(OPTIONS.TissueLabels) ;
            OPTIONS.TissueLabels = OPTIONS.TissueLabels;
            % Delete temporary folder
            file_delete(simnibsDir, 1, 3);
            
            
        case 'roast'
            % Check if ROAST is in the path
            if ~exist('roast', 'file')
                errMsg = InstallRoast(isInteractive);
                if ~isempty(errMsg) || ~exist('roast', 'file')
                    return;
                end
            end
            % === SAVE MRI AS NII ===
            % Empty temporary folder, otherwise it reuses previous files in the folder
            gui_brainstorm('EmptyTempFolder');
            % Create temporary folder for fieldtrip segmentation files
            roastDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'roast');
            mkdir(roastDir);
            % Save MRI in .nii format
            NiiFile = bst_fullfile(roastDir, 'roast.nii');
            out_mri_nii(MriFile, NiiFile);

            % === CALL ROAST PIPELINE ===
            % TODO : add the roast toolbox to the path
            % Segmentation
            bst_progress('text', 'MRI Segmentation...');
            fullPathToT1 = NiiFile;
            fullPathToT2 = [];
            segment_by_roast(fullPathToT1,fullPathToT2)

            % convert the roats output to fieltrip in order to use prepare mesh
            baseFilename = 'roast_T1orT2';
            % Load the masks
            data = load_untouch_nii([roastDir filesep baseFilename '_masks.nii']);
            allMask = data.img; 
            % Getting the MRI data
            ft_defaults
            mri = ft_read_mri(NiiFile);
            % assign labels to tissues in this order: white,gray,csf,bone,skin,air
            if length(OPTIONS.TissueLabels) == 5
                white_mask = zeros(size(allMask)); white_mask(allMask == 1) = true;
                grey_mask  = zeros(size(allMask)); grey_mask(allMask == 2) = true;
                csf_mask   = zeros(size(allMask)); csf_mask(allMask == 3) = true;
                bone_mask  = zeros(size(allMask)); bone_mask(allMask== 4) = true;
                skin_mask  = zeros(size(allMask)); skin_mask(allMask == 5) = true;
                segmentedmri.dim = size(skin_mask);
                segmentedmri.transform = [];
                segmentedmri.coordsys = 'ctf';
                segmentedmri.unit = 'mm';
                segmentedmri.gray = grey_mask;
                segmentedmri.white = white_mask;
                segmentedmri.csf = csf_mask;
                segmentedmri.skull = bone_mask;
                segmentedmri.scalp = skin_mask;
                segmentedmri.transform = mri.transform;
                clear grey_mask white_mask csf_mask bone_mask skin_mask
            end

            if length(OPTIONS.TissueLabels) == 3
                white_mask = zeros(size(allMask)); white_mask(allMask == 1) = true;
                grey_mask  = zeros(size(allMask)); grey_mask(allMask == 2) = true;
                csf_mask   = zeros(size(allMask)); csf_mask(allMask == 3) = true;
                brain_mask = white_mask + grey_mask + csf_mask;
                bone_mask  = zeros(size(allMask)); bone_mask(allMask == 4) = true;
                skin_mask  = zeros(size(allMask)); skin_mask(allMask == 5) = true;
                clear white_mask  grey_mask csf_mask
                segmentedmri.dim = size(skin_mask);
                segmentedmri.transform = [];
                segmentedmri.coordsys = 'ctf';
                segmentedmri.unit = 'mm';
                segmentedmri.brain = brain_mask;
                segmentedmri.skull = bone_mask;
                segmentedmri.scalp = skin_mask;
                clear brain_mask  bone_mask skin_mask;
                segmentedmri.transform = mri.transform;
            end
            clear mri;

            if strcmp(OPTIONS.meshType,'Hexahedral')
                % Mesh using fieldtrip tools
                cfg        = [];
                cfg.shift  = OPTIONS.meshNodeShift ;
                cfg.method = 'hexahedral';
                mesh = ft_prepare_mesh(cfg,segmentedmri);
                %% Visualisation : not for brainstorm ...
                %TODO : work on brainstom function to display the mesh better than the current version
                % convert the mesh to tetra in order to use plotmesh
                [el,pos,id] = hex2tet(mesh.hex,mesh.pos,mesh.tissue,2);
                elem = [el id];        clear el id
                figure;
                plotmesh(pos,elem,'x<50')
                title('Mesh hexa with vox2hexa')
                clear pos elem
                % save as hexa ...
                node = mesh.pos;
                elem = [mesh.hex mesh.tissue];
                %             %% convert the hexa to tetra (add the function hex2tet to the toolbox)
                %             [el, node, id]=hex2tet(mesh.hex,mesh.pos,mesh.tissue,2);
                %             elem = [el id];
                %             clear el id
            elseif strcmp(OPTIONS.meshType,'Tetrahedral')
                % Mesh by iso2mesh
                bst_progress('text', 'Mesh Generation...'); %
                %TODO ... Load the mask and apply Johannes process to generate the cubic Mesh
                % TODO : Add the T2 images to the segmenttion process.
                [node,elem] = mesh_by_iso2mesh(fullPathToT1,fullPathToT2);
                figure;
                plotmesh(node,elem,'x<90')
                title('Mesh tetra  with iso2mesh ')
            end
            % Update the OPTIONS
            OPTIONS.NumberOfbLayers = length(OPTIONS.TissueLabels); % minus the aire
            OPTIONS.TissueLabels = OPTIONS.TissueLabels;
            % Delete temporary folder
            file_delete(roastDir, 1, 3);
            
        case 'spm-fieldtrip'
            % If installed, remove the Rost toolbox from the path in order to
            % avoid the error related to spm ...
            % === SAVE MRI AS NII ===
            % Empty temporary folder, otherwise it reuses previous files in the folder
            gui_brainstorm('EmptyTempFolder');
            % Create temporary folder for fieldtrip segmentation files
            fieldtripDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'fieldtripSegmentation');
            mkdir(fieldtripDir);
            % Save MRI in .nii format
            NiiFile = bst_fullfile(fieldtripDir, 'fieldtrip.nii');
            out_mri_nii(MriFile, NiiFile);

            % === CALL Fieltrip PIPELINE ===
            % remove roast toolbox ==> confusion with spm path
            str = which('roast','-all');
            if ~isempty(str)
                filepath = fileparts(str{1});
                rmpath(filepath)
            end
            ft_defaults
            mri = ft_read_mri(NiiFile);
            % Segmentation
            cfg = [];
            cfg.output = OPTIONS.TissueLabels;
            mri.coordsys = 'ctf'; % always ctf ==> check the output if it fits with the MRI
            segmentedmri  = ft_volumesegment(cfg, mri);

            % Mesh
            cfg        = [];
            cfg.shift  = OPTIONS.meshNodeShift;
            cfg.method = 'hexahedral';
            mesh = ft_prepare_mesh(cfg,segmentedmri);

            %% Visualisation : not for brainstorm ...
            %TODO : work on brainstom function to display the mesh better than the current version
            % convert the mesh to tetr in order to use plotmesh
            [el,pos,id] = hex2tet(mesh.hex,mesh.pos,mesh.tissue,2);
            elem = [el id];
            clear el id
            figure;
            plotmesh(pos,elem,'x<50')
            clear pos elem
            % === IMPORT OUTPUT FOLDER ===
            % Import FEM mesh
            % use the TETRA or the HEXA
            if strcmp(OPTIONS.meshType,'Hexahedral')
                % save as hexa ...
                node = mesh.pos;
                elem = [mesh.hex mesh.tissue];
            elseif strcmp(OPTIONS.meshType,'Tetrahedral')
                % convert the hexa to tetra (add the function hex2tet to the toolbox)
                [el, node, id]=hex2tet(mesh.hex,mesh.pos,mesh.tissue,2);
                elem = [el id];
                clear el id
            end

            % Update the OPTIONS
            OPTIONS.NumberOfbLayers  = length(OPTIONS.TissueLabels) ; % minus the aire
            OPTIONS.TissueLabels = OPTIONS.TissueLabels;
            % Delete temporary folder
            file_delete(fieldtripDir, 1, 3);

            
        case 'icbm-template' % Load the ICBM template
            % Get default FEM mesh // TODO : Download or load from default database
            FemTemplateFile = 'five_layer_icbm152_simnibs.mat'; % TODO : ADD THIS FILE TO THE DEFAULT DIR
            DefaultsDir = bst_get('BrainstormDefaultsDir') ;
            FemTemplateFile = fullfile(DefaultsDir,'anatomy','ICBM152',FemTemplateFile);
            % Load model
            femhead = [];
            load(FemTemplateFile,'femhead') %  The model has 6 layers per default
            % replace the eyes per the scalp (not used for now)
            femhead.Tissue(femhead.Tissue==6) = 5;
            % Get the number of layers
            if OPTIONS.NumberOfbLayers == 4 % {'brain'  'csf'  'skull'  'scalp'}
                % replace the GM by WM and use unique label
                femhead.Tissue(femhead.Tissue== 2) = 1; % gm to wm and all form brain with label 1
                % relabel
                femhead.Tissue(femhead.Tissue== 3) = 2; % csf label 2
                femhead.Tissue(femhead.Tissue== 4) = 3; % skull label 3
                femhead.Tissue(femhead.Tissue== 5) = 4; % scalp label 4
            end
            if OPTIONS.NumberOfbLayers == 3 % {'brain'  'skull'  'scalp'}
                % replace the SCF, GM by WM and use unique label
                femhead.Tissue(femhead.Tissue== 2) = 1; % gm to wm and all form brain label 1
                femhead.Tissue(femhead.Tissue== 3) = 1; % csf to wm and all form brain label 1
                % relabel
                femhead.Tissue(femhead.Tissue== 4) = 2; % skull label 2
                femhead.Tissue(femhead.Tissue== 5) = 3; % scalp label 3
            end
            node = femhead.Vertices;
            elem = [femhead.Elements femhead.Tissue];
            clear femhead
            % Only tetra could be generated from this method at this time
            OPTIONS.meshType = 'Tetrahedral';
            % Update the OPTIONS
            OPTIONS.NumberOfbLayers  = length(OPTIONS.TissueLabels) ;

            % TODO : load the cortex or recompute a new cortex

        otherwise
            errMsg = ['Invalid method "' OPTIONS.Method '".'];
            return;
    end

    % ===== SAVE FEM MESH =====
    % Create output structure
    FemMat.Comment = sprintf('FEM %dV (%s , %d layers)', length(node), OPTIONS.Method, OPTIONS.NumberOfbLayers);
    FemMat.Vertices = node;

    if ~isfield(OPTIONS,'TissueLabels')
        if OPTIONS.NumberOfbLayers == 3
            FemMat.TissueLabels = {'Inner','Outer','Scalp'}; % or {'csf','Skull','Scalp'};
        elseif OPTIONS.NumberOfbLayers == 4
            FemMat.TissueLabels = {'brain','csf','Skull','Scalp'};
        elseif OPTIONS.NumberOfbLayers == 5
            FemMat.TissueLabels =  {'gray','white','csf','skull','scalp'};
        end
    end

    if strcmp(OPTIONS.meshType, 'Tetrahedral')
        FemMat.Elements = elem(:,1:4);
        FemMat.Tissue = elem(:,5);
    else
        FemMat.Elements = elem(:,1:8);
        FemMat.Tissue = elem(:,9);
    end
    FemMat.TissueLabels = OPTIONS.TissueLabels;

    % Add history
    FemMat = bst_history('add', FemMat, 'process_generate_fem', [...
        'Method=',    OPTIONS.Method, '|', ...
        'Mesh type =',    OPTIONS.meshType, '|', ...
        'Number of layer= ',  num2str(OPTIONS.NumberOfbLayers), '|', ...
        'MaxVol=',    num2str(OPTIONS.MaxVol),  '|', ...
        'KeepRatio=', num2str(OPTIONS.KeepRatio)]);
    % Save to database
    FemFile = file_unique(bst_fullfile(bst_fileparts(MriFile), sprintf('tess_fem_%s_%dV.mat', OPTIONS.Method, length(FemMat.Vertices))));
    bst_save(FemFile, FemMat, 'v7');
    db_add_surface(iSubject, FemFile, FemMat.Comment);
    % Return success
    isOk = 1;
end



%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, iAnatomy) %#ok<DEFNU>
    % Get inputs
    if (nargin < 2) || isempty(iAnatomy)
        iAnatomy = [];
    end
    % Ask for method
    Method = java_dialog('question', [...
        '<HTML><B>BEM</B>:<BR>Calls iso2mesh to create a tetrahedral mesh from the BEM layers<BR>' ...
        'generated with Brainstorm (head, inner skull, outer skull).<BR><BR>' ...
        '<B>ROAST</B>:<BR>Calls the ROAST pipeline to segment and mesh the T1 (and T2) MRI.<BR><BR>'...
        '<B>SIMNIBS</B>:<BR>Calls the SIMNIBS pipeline to segment and mesh the T1 (and T2) MRI.<BR><BR>'...
        '<B>BRAINSUITE</B>:<BR>Calls the BRAINSUITE pipeline to segment and mesh the T1 (and T2) MRI.<BR><BR>'...
        '<B>SPM-FIELDTRIP</B>:<BR>Calls the FieldTrip pipeline to segment and mesh the T1 MRI.<BR><BR>', ...
        '<B>ICBM-TEMPLATE</B>:<BR>Load the ICBM head model (FEM tetrahedral mesh).<BR><BR>'], ...
        'FEM mesh generation method', [], {'BEM','BRAINSUITE','ROAST','SIMNIBS','SPM-FIELDTRIP','ICBM-TEMPLATE'}, 'BEM');
    if isempty(Method)
        return
    end

    % Other options: Switch depending on the method
    switch (Method)
        case 'BRAINSUITE'
            bst_error('Not implemented yet', 'FEM mesh', 0);
            return;
        case 'BEM'
            % Ask for method
            res = java_dialog('question', [...
                '<HTML><B>Three Layers</B>:<BR> Generates the volume mesh from the inner skull, <BR>' ...
                'outer skull and the scalp surfaces<BR>' ...
                '<B>Four Layers</B>:<BR> Generates the volume mesh from the inner skull, <BR>' ...
                'outer skull and the scalp surfaces and adds <BR>' ...
                'the CSF  (experimental).<BR><BR>'], ...
                'Number of layers', [], {'3 Layers','4 Layers'}, '3 Layers');
            if isempty(res)
                return
            end
            % convert to integer :
            if strcmp(res,'3 Layers')
                NumberOfbLayers = 3;
            end
            if strcmp(res,'4 Layers')
                NumberOfbLayers = 4;
                skullThikness = 2; % This value will be the thickness of the new skull layer, the previous skull will be CSF ... to discuss and validate
            end
            % Ask BEM meshing options
            res = java_dialog('input : iso2mesh options', {'Max tetrahedral volume (10=coarse, 0.0001=fine):', 'Percentage of elements kept (1-100%):'}, ...
                'FEM mesh', [], {'0.1', '100'});
            % If user cancelled: return
            if isempty(res)
                return
            end
            % Get new values
            OPTIONS.NumberOfbLayers = NumberOfbLayers;
            if  OPTIONS.NumberOfbLayers == 4
                OPTIONS.skullThikness = skullThikness;
            end
            OPTIONS.MaxVol    = str2num(res{1});
            OPTIONS.KeepRatio = str2num(res{2}) ./ 100;
            if isempty(OPTIONS.MaxVol) || (OPTIONS.MaxVol < 0.000001) || (OPTIONS.MaxVol > 20) || ...
                    isempty(OPTIONS.KeepRatio) || (OPTIONS.KeepRatio < 0.01) || (OPTIONS.KeepRatio > 1)
                bst_error('Invalid options.', 'FEM mesh', 0);
                return
            end
            OPTIONS.Method = 'bemsurf';
            % Open progress bar
            bst_progress('start', 'FEM mesh', 'FEM mesh generation (iso2mesh)...');

        case 'SIMNIBS'
            % TODO : ask user if there is any T2 is availabele for the subject
            % ==> better with T2 following simnibs recommendations
            OPTIONS.Method = 'simnibs';
            % Open progress bar
            bst_progress('start', 'SIMNIBS', 'FEM mesh generation (SIMNIBS)...');
            % bst_progress('setimage', 'logo_splash_roast.gif');
            % Set parameters
            % Ask user for the the tissu to segment :
            opts = {...
                '5 Layers : gray, white, csf, skull, scalp',...
                '4 Layers : brain, csf, skull, scalp', ...
                '3 Layers : brain, skull, scalp'};
            display_text = '<HTML> Select the model to segment  <BR>';
            [res, isCancel] = java_dialog('radio', display_text, 'Select Model',[],opts, 1);
            if isCancel
                return
            end
            if res == 1
                OPTIONS.TissueLabels    = {'gray','white','csf','skull','scalp'};
            end
            if res == 2
                OPTIONS.TissueLabels    = { 'brain', 'csf', 'skull', 'scalp'};
            end
            if res == 3
                OPTIONS.TissueLabels    = {'brain', 'skull', 'scalp'};
            end
            OPTIONS.NumberOfbLayers = length(OPTIONS.TissueLabels);

            % Ask user for the mesh element type :
            [res, isCancel]  = java_dialog('question', [...
                '<HTML><B>Hexahedral Mesh</B>:<BR> Use the hexa element for the mesh , <BR>' ...
                '<B>Tetrahedral Mesh</B>:<BR> Use the tetra element for the mesh <BR>(experimental : converts the hexa to tetra)<BR>' ], ...
                'Mesh type', [], {'Hexahedral','Tetrahedral'}, 'Tetrahedral');
            if isCancel
                return
            end
            OPTIONS.meshType = res;
            % Ask user for the node shifting :
            if strcmp(OPTIONS.meshType,'Hexahedral')
                [res, isCancel]  = java_dialog('question', ...
                    '<HTML><B>Node Shifting </B>:<BR> Use the shifting option to move the node on the mesh <BR>' , ...
                    'Node Shifting', [], {'Yes','No'}, 'Yes');
                if isCancel
                    return
                end
                if strcmp(res,'Yes')
                    [res, isCancel]  = java_dialog('input', 'Shift the nodes (fitting to the geometry):', ...
                        'FEM Node Shift', [], '0.3');
                    if isCancel
                        return
                    end
                else
                    res = [];
                end
            else
                res = [];
            end
            OPTIONS.meshNodeShift = str2double(res);

        case 'ROAST'
            %         bst_error('Not implemented yet', 'FEM mesh', 0);
            %         return;
            OPTIONS.Method = 'roast';
            % Open progress bar
            bst_progress('start', 'ROAST', 'FEM mesh generation (ROAST)...');
            bst_progress('setimage', 'logo_splash_roast.gif');

            % Set parameters
            % Ask user for the the tissu to segment :
            opts = {['5 Layers : gray, white, csf, skull, scalp'],...
                ['3 Layers : brain, skull, scalp'] };
            display_text = ['<HTML> Select the model to segment  <BR> '];
            [res, isCancel] = java_dialog('radio', display_text, 'Select Model',[],opts, 1);
            if isCancel
                return
            end
            if res == 1
                OPTIONS.TissueLabels    = {'gray','white','csf','skull','scalp'};
            end
            if res == 2
                OPTIONS.TissueLabels    = {'brain', 'skull', 'scalp'};
            end
            OPTIONS.NumberOfbLayers = length(OPTIONS.TissueLabels);
            % Ask user for the mesh element type :
            [res, isCancel]  = java_dialog('question', [...
                '<HTML><B>Hexahedral Mesh</B>:<BR> Use the hexa element for the mesh , <BR>' ...
                '<B>Tetrahedral Mesh</B>:<BR> Use the tetra element for the mesh <BR>(experimental : converts the hexa to tetra)<BR>' ], ...
                'Mesh type', [], {'Hexahedral','Tetrahedral'}, 'Tetrahedral');
            if isCancel
                return
            end
            OPTIONS.meshType = res;
            % Ask user for the node shifting :
            [res, isCancel]  = java_dialog('question', ...
                '<HTML><B>Node Shifting </B>:<BR> Use the shifting option to move the node on the mesh <BR>' , ...
                'Node Shifting', [], {'Yes','No'}, 'Yes');
            if isCancel
                return
            end
            if strcmp(res,'Yes')
                [res, isCancel]  = java_dialog('input', 'Shift the nodes (fitting to the geometry):', ...
                    'FEM Node Shift', [], '0.3');
                if isCancel
                    return
                end
            else
                res = [];
            end
            OPTIONS.meshNodeShift = str2double(res);

        case 'SPM-FIELDTRIP'
            OPTIONS.Method = 'Spm-FieldTrip';
            % Open progress bar
            bst_progress('start', 'Spm-FieldTrip', 'FEM mesh generation (Spm-FieldTrip)...');
            %bst_progress('setimage', 'logo_splash_roast.gif');

            % Ask user for the the tissu to segment :
            opts = {...
                '5 Layers : gray, white, csf, skull, scalp',...
                '3 Layers : brain, skull, scalp'};
            display_text = '<HTML> Select the model to segment  <BR> ';
            [res, isCancel] = java_dialog('radio', display_text, 'Select Model',[],opts, 1);
            if isCancel
                return
            end
            if res == 1
                OPTIONS.TissueLabels = {'gray','white','csf','skull','scalp'};
            end
            if res == 2
                OPTIONS.TissueLabels = {'brain', 'skull', 'scalp'};
            end
            OPTIONS.NumberOfbLayers = length(OPTIONS.TissueLabels);

            % Ask user for the mesh element type :
            [res, isCancel]  = java_dialog('question', [...
                '<HTML><B>Hexahedral Mesh</B>:<BR> Use the hexa element for the mesh , <BR>' ...
                '<B>Tetrahedral Mesh</B>:<BR> Use the tetra element for the mesh <BR>(experimental : converts the hexa to tetra)<BR>' ], ...
                'Mesh type', [], {'Hexahedral','Tetrahedral'}, 'Tetrahedral');
            if isCancel
                return
            end
            OPTIONS.meshType = res;

            % Ask user for the node shifting :
            [res, isCancel]  = java_dialog('question', ...
                '<HTML><B>Node Shifting </B>:<BR> Use the shifting option to move the node on the mesh <BR>' , ...
                'Node Shifting', [], {'Yes','No'}, 'Yes');
            if isCancel
                return
            end
            if strcmp(res,'Yes')
                [res, isCancel]  = java_dialog('input', 'Shift the nodes (fitting to the geometry):', ...
                    'FEM Node Shift', [], '0.3');
                if isCancel
                    return
                end
            else
                res = [];
            end
            OPTIONS.meshNodeShift = str2double(res);

            
        case 'ICBM-TEMPLATE'
            OPTIONS.Method = 'icbm-Template';
            % Open progress bar
            bst_progress('start', 'icbm-Template', 'FEM mesh loading (icbm-Template)...');

            % Ask user for the the tissu to segment :
            opts = {...
                '5 Layers : gray, white, csf, skull, scalp',...
                '4 Layers : brain, csf, skull, scalp',...
                '3 Layers : brain, skull, scalp'};
            display_text = '<HTML> Select the model to load  <BR>';
            [res, isCancel] = java_dialog('radio', display_text, 'Select Model',[],opts, 1);
            if isCancel
                return
            end
            if res == 1
                OPTIONS.TissueLabels = {'gray','white','csf','skull','scalp'};
            end
            if res == 2
                OPTIONS.TissueLabels = {'brain', 'csf', 'skull', 'scalp'};
            end
            if res == 3
                OPTIONS.TissueLabels = {'brain', 'skull', 'scalp'};
            end
            OPTIONS.NumberOfbLayers = length(OPTIONS.TissueLabels);

            % Ask user for the mesh element type : (ONLY TETRA ARE AVAILABLE FOR NOW)
            %         [res, isCancel]  = java_dialog('question', [...
            %             '<HTML><B>Hexahedral Mesh</B>:<BR> Use the hexa element for the mesh , <BR>' ...
            %             '<B>Tetrahedral Mesh</B>:<BR> Use the tetra element for the mesh <BR>(experimental : converts the hexa to tetra)<BR>' ], ...
            %             'Mesh type', [], {'Hexahedral','Tetrahedral'}, 'Tetrahedral');
            %         if isCancel
            %             return
            %         end
            % TODO : GENRATE HEXA MESH FROM THE MASKS
            res = 'Tetrahedral';
            OPTIONS.meshType = res;

            %         % Ask user for the node shifting :
            %         [res, isCancel]  = java_dialog('question', ...
            %             '<HTML><B>Node Shifting </B>:<BR> Use the shifting option to move the node on the mesh <BR>' , ...
            %             'Node Shifting', [], {'Yes','No'}, 'Yes');
            %         if isCancel
            %             return
            %         end
            %         if strcmp(res,'Yes')
            %             [res, isCancel]  = java_dialog('input', 'Shift the nodes (fitting to the geometry):', ...
            %                 'FEM Node Shift', [], '0.3');
            %             if isCancel
            %                 return
            %             end
            %         else
            %             res = [];
            %         end
            res = [];
            OPTIONS.meshNodeShift = str2double(res);
    end

    % Compute surfaces
    [isOk, errMsg] = Compute(iSubject, iAnatomy, 1, OPTIONS);
    % Error handling
    if ~isOk
        bst_error(errMsg, 'FEM mesh', 0);
    elseif ~isempty(errMsg)
        java_dialog('msgbox', ['Warning: ' errMsg]);
    end
    % Close progress bar
    bst_progress('stop');
end



%% ===== INSTALL ROAST =====
function errMsg = InstallRoast(isInteractive)
    % Initialize variables
    errMsg = [];
    curdir = pwd;
    % Download URL
    url = 'https://www.parralab.org/roast/roast-3.0.zip';

    % Check if already available in path
    if exist('roast', 'file')
        disp([10, 'ROAST path: ', bst_fileparts(which('roast')), 10]);
        return;
    end
    % Local folder where to install ROAST
    roastDir = bst_fullfile(bst_get('BrainstormUserDir'), 'roast');
    exePath = bst_fullfile(roastDir, 'roast-3.0', 'roast.m');
    % If dir doesn't exist in user folder, try to look for it in the Brainstorm folder
    if ~isdir(roastDir)
        roastDirMaster = bst_fullfile(bst_get('BrainstormHomeDir'), 'roast');
        if isdir(roastDirMaster)
            roastDir = roastDirMaster;
        end
    end

    % URL file defines the current version
    urlFile = bst_fullfile(roastDir, 'url');
    % Read the previous download url information
    if isdir(roastDir) && file_exist(urlFile)
        fid = fopen(urlFile, 'r');
        prevUrl = fread(fid, [1 Inf], '*char');
        fclose(fid);
    else
        prevUrl = '';
    end
    % If file doesnt exist: download
    if ~isdir(roastDir) || ~file_exist(exePath) || ~strcmpi(prevUrl, url)
        % If folder exists: delete
        if isdir(roastDir)
            file_delete(roastDir, 1, 3);
        end
        % Create folder
        res = mkdir(roastDir);
        if ~res
            errMsg = ['Error: Cannot create folder' 10 roastDir];
            return
        end
        % Message
        if isInteractive
            isOk = java_dialog('confirm', ...
                ['ROAST is not installed on your computer (or out-of-date).' 10 10 ...
                'Download and the latest version of ROAST?'], 'ROAST');
            if ~isOk
                errMsg = 'Download aborted by user';
                return;
            end
        end
        % Download file
        zipFile = bst_fullfile(roastDir, 'roast.zip');
        errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'Download ROAST');
        % If file was not downloaded correctly
        if ~isempty(errMsg)
            errMsg = ['Impossible to download ROAST:' 10 errMsg1];
            return;
        end
        % Display again progress bar
        bst_progress('text', 'Installing ROAST...');
        % Unzip file
        cd(roastDir);
        unzip(zipFile);
        file_delete(zipFile, 1, 3);
        cd(curdir);
        % Save download URL in folder
        fid = fopen(urlFile, 'w');
        fwrite(fid, url);
        fclose(fid);
    end
    % If installed but not in path: add roast to path
    if ~exist('roast', 'file')
        addpath(bst_fileparts(exePath));
        disp([10, 'ROAST path: ', bst_fileparts(roastDir), 10]);
        % If the executable is still not accessible
    else
        errMsg = ['ROAST could not be installed in: ' roastDir];
    end
end


%% ===== INSTALL ISO2MESH =====
function errMsg = InstallIso2mesh(isInteractive)
    % Initialize variables
    errMsg = [];
    curdir = pwd;
    % Check if already available in path
    if exist('iso2meshver', 'file') && isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
        disp([10, 'Iso2mesh path: ', bst_fileparts(which('iso2meshver')), 10]);
        return;
    end

    % Get default url
    osType = bst_get('OsType', 0);
    switch(osType)
        case 'linux32',  url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-linux32.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-linux32.zip%2Fdownload&ts=1568212532';
        case 'linux64',  url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-linux64.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-linux64.zip%2Fdownload&ts=1568212566';
        case 'mac32',    error('MacOS 32bit systems are not supported');
        case 'mac64',    url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-osx64.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-osx64.zip%2Fdownload&ts=1568212596';
        case 'sol64',    error('Solaris system is not supported');
        case 'win32',    url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-win32.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-win32.zip%2Fdownload%3Fuse_mirror%3Diweb%26r%3Dhttps%253A%252F%252Fsourceforge.net%252Fprojects%252Fiso2mesh%252Ffiles%252Fiso2mesh%252F1.9.0-1%252520%252528Iso2Mesh%2525202018%252529%252Fiso2mesh-2018-win32.zip&ts=1568212385';
        case 'win64',    url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-win32.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-win32.zip%2Fdownload%3Fuse_mirror%3Diweb%26r%3Dhttps%253A%252F%252Fsourceforge.net%252Fprojects%252Fiso2mesh%252Ffiles%252Fiso2mesh%252F1.9.0-1%252520%252528Iso2Mesh%2525202018%252529%252Fiso2mesh-2018-win32.zip&ts=1568212385';
        otherwise,       error('OpenMEEG software does not exist for your operating system.');
    end

    % Local folder where to install iso2mesh
    isoDir = bst_fullfile(bst_get('BrainstormUserDir'), 'iso2mesh', osType);
    exePath = bst_fullfile(isoDir, 'iso2mesh', 'iso2meshver.m');
    % If dir doesn't exist in user folder, try to look for it in the Brainstorm folder
    if ~isdir(isoDir)
        isoDirMaster = bst_fullfile(bst_get('BrainstormHomeDir'), 'iso2mesh');
        if isdir(isoDirMaster)
            isoDir = isoDirMaster;
        end
    end

    % URL file defines the current version
    urlFile = bst_fullfile(isoDir, 'url');
    % Read the previous download url information
    if isdir(isoDir) && file_exist(urlFile)
        fid = fopen(urlFile, 'r');
        prevUrl = fread(fid, [1 Inf], '*char');
        fclose(fid);
    else
        prevUrl = '';
    end
    % If file doesnt exist: download
    if ~isdir(isoDir) || ~file_exist(exePath) || ~strcmpi(prevUrl, url)
        % If folder exists: delete
        if isdir(isoDir)
            file_delete(isoDir, 1, 3);
        end
        % Create folder
        res = mkdir(isoDir);
        if ~res
            errMsg = ['Error: Cannot create folder' 10 isoDir];
            return
        end
        % Message
        if isInteractive
            isOk = java_dialog('confirm', ...
                ['Iso2mesh is not installed on your computer (or out-of-date).' 10 10 ...
                'Download and the latest version of Iso2mesh?'], 'Iso2mesh');
            if ~isOk
                errMsg = 'Download aborted by user';
                return;
            end
        end
        % Download file
        zipFile = bst_fullfile(isoDir, 'iso2mesh.zip');
        errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'Download Iso2mesh');
        % If file was not downloaded correctly
        if ~isempty(errMsg)
            errMsg = ['Impossible to download Iso2mesh:' 10 errMsg1];
            return;
        end
        % Display again progress bar
        bst_progress('text', 'Installing Iso2mesh...');
        % Unzip file
        cd(isoDir);
        unzip(zipFile);
        file_delete(zipFile, 1, 3);
        cd(curdir);
        % Save download URL in folder
        fid = fopen(urlFile, 'w');
        fwrite(fid, url);
        fclose(fid);
    end
    % If installed but not in path: add to path
    if ~exist('iso2meshver', 'file') && isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
        addpath(bst_fileparts(exePath));
        disp([10, 'Iso2mesh path: ', bst_fileparts(isoDir), 10]);
        % If the executable is still not accessible
    else
        errMsg = ['Iso2mesh could not be installed in: ' isoDir];
    end
end



%% ===== INFLATE/DEFLATE SURFACE =====
% deflate a surface mesh on the normal direction (outward==> infalte, inward ==> deflate)
function [NewVertices, NewFaces, NormalOnVertices] = inflateORdeflate_surface(Vertices, Faces, depth)
    % I: Reorientation des surfaces
    [Vertices,Faces]=surfreorient(Vertices,Faces);

    % II : Compute the normal at each centroide of face and/or the normal at each node
    TR = triangulation(Faces,Vertices(:,1),Vertices(:,2),Vertices(:,3));
    nrm_sur_nodes = vertexNormal(TR);
    % I- Trouver les composante spherique de chaque normale à la surface:
    [azimuth,elevation,r_norm] = cart2sph(nrm_sur_nodes(:,1),nrm_sur_nodes(:,2),nrm_sur_nodes(:,3));
    % figure_title = [ figure_title ' defined on '  num2str(length(Vertices)) ' nodes' ];

    % II - Choisir la profondeur de la postion de l'espace des sources dans la couche du cortex :
    profondeur_sources=depth; % en mm
    % This function can either inflate or deflate a closed surface by a distance depth
    % distance of the inflate<0 or deflate >0 

    % III- Trouver les composantes dans les trois directions à partir du point centroide de chaque facette:
    profondeur_x = profondeur_sources .* cos(elevation) .* cos(azimuth);
    profondeur_y = profondeur_sources .* cos(elevation) .* sin(azimuth);
    profondeur_z = profondeur_sources .* sin(elevation);
    % verif=sqrt(profondeur_x.^2+profondeur_y.^2+profondeur_z.^2);

    % IV- Appliquer cette profondeur dans chque direction à partir du centroide de chaque feacette:
    pos_source_x=Vertices(:,1)-profondeur_x;
    pos_source_y=Vertices(:,2)-profondeur_y;
    pos_source_z=Vertices(:,3)-profondeur_z;

    % V- Espace de source avec une profondeur définit par la variable : profondeur_sources
    NewVertices=[pos_source_x pos_source_y pos_source_z];
    [ori_source_x, ori_source_y, ori_source_z] =  sph2cart(azimuth,elevation,r_norm);
    NormalOnVertices = [ori_source_x, ori_source_y, ori_source_z] ;
    NewFaces = Faces;

    % The outputs are the same nodes shifted in the normal direction inside (deflate) or
    % outside (inflate) depending on the signe of depth. It computes also the
    % normal to each vertices.
end




