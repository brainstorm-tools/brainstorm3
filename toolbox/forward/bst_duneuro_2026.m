function [Gain, errMsg] = bst_duneuro_2026(cfg)
% BST_DUNEURO: Call Duneuro to compute a FEM solution for Brainstorm.
%
% USAGE:  [Gain, errMsg] = bst_duneuro(cfg)

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
% Authors: Takfarinas Medani, Juan Garcia-Prieto, 2019-2026
%          Francois Tadel 2020-2023

% Initialize returned values
Gain = [];
% ***** ToDo: Define how to check the container *******
% Install/load duneuro plugin
[isInstalled, errMsg, PlugDesc] = bst_plugin('Install', 'duneuro', cfg.Interactive);
if ~isInstalled
    return;
end
bst_plugin('SetProgressLogo', 'duneuro');

% Get DUNEuro executable
DuneuroExe = bst_fullfile(PlugDesc.Path, PlugDesc.SubFolder, 'bin', ['bst_duneuro_meeg_', bst_get('OsType')]);
if ispc
    DuneuroExe = [DuneuroExe, '.exe'];
else
    DuneuroExe = [DuneuroExe, '.app'];
end



%% ===== SENSORS =====
% Select modality for DUNEuro
isEeg  = strcmpi(cfg.EEGMethod, 'duneuro_2026')  && ~isempty(cfg.iEeg);
isMeg  = strcmpi(cfg.MEGMethod, 'duneuro_2026')  && ~isempty(cfg.iMeg);
isEcog = strcmpi(cfg.ECOGMethod, 'duneuro_2026') && ~isempty(cfg.iEcog);
isSeeg = strcmpi(cfg.SEEGMethod, 'duneuro_2026') && ~isempty(cfg.iSeeg);

% Get the modality
if ((isEeg || isEcog || isSeeg) && isMeg)
    dnModality = 'meeg';  
elseif (isEeg || isEcog || isSeeg)
    dnModality = 'eeg';
elseif  isMeg
    dnModality = 'meg'; % from DUNEuro side, EEG, sEEG, ECOG  uses the same process
else
    errMsg = 'No valid modality available.';
    return;
end

% Get EEG positions
% Combined modalities for EEG/sEEG/EcoG as EEG
if (isEeg || isEcog || isSeeg)
    cfg.iEeg = [cfg.iEeg, cfg.iSeeg, cfg.iEcog];
    EegLoc = cat(2, cfg.Channel(cfg.iEeg).Loc);
end

% Get MEG positions/orientations
if isMeg
    MegChannels = [];
    for iChan = 1:length(cfg.iMeg)
        sChan = cfg.Channel(cfg.iMeg(iChan));
        for iInteg = 1:size(sChan.Loc, 2)
            MegChannels = [MegChannels; iChan, sChan.Loc(:,iInteg)', sChan.Orient(:,iInteg)', sChan.Weight(iInteg)];
        end
    end
    % In the case where the MEG integration points are used
    if cfg.UseIntegrationPoint == 0
        % loop over the integration Points
        % chan_loc = figure_3d('GetChannelPositions', cfg, cfg.iMeg); % <= this function is not sufficient, we need also the weights. 
        MegChannelsTemp = [];
        for iChan = 1 : length(cfg.iMeg)
            group = MegChannels(MegChannels(:,1) == iChan,:);
            groupPositive = group(group(:,end)>0,:);
            groupNegative = group(group(:,end)<0,:);            
            if ~isempty(groupPositive)
                %equivalentPositionPostive = sum(repmat(abs(groupPositive(:,end)),[1 3])  .* groupPositive(:,2:4));
                equivalentPositionPostive = mean(groupPositive(:,2:4));
                MegChannelsTemp = [MegChannelsTemp; iChan  equivalentPositionPostive groupPositive(1,5:7)  sum(groupPositive(:,end))];
            end
            if ~isempty(groupNegative)
                %equivalentPositionNegative = sum(repmat(abs(groupNegative(:,end)),[1 3])  .* groupNegative(:,2:4));
                equivalentPositionNegative = mean(groupNegative(:,2:4));
                MegChannelsTemp = [MegChannelsTemp; iChan  equivalentPositionNegative groupNegative(1,5:7)  sum(groupNegative(:,end))];
            end
        end
        MegChannels = MegChannelsTemp;
    end
end

%% ===== HEAD MODEL =====
% Load FEM mesh
FemMat = load(file_fullpath(cfg.FemFile));
% Get mesh type
switch size(FemMat.Elements,2)
    case 4,  ElementType = 'tetrahedron';
    case 8,  ElementType = 'hexahedron';
end
% Remove unselected tissue from the head model (MEG only), this could be also done for sEEG later
if strcmp(dnModality, 'meg')
    % Remove the elements corresponding to the unselected tissues
    iRemove = find(~ismember(FemMat.Tissue, find(cfg.FemSelect)));
    if ~isempty(iRemove)
        FemMat = fem_remove_elem(FemMat, iRemove);
    end
elseif strcmp(dnModality,'meeg') && (sum(cfg.FemSelect) ~= length(unique(FemMat.Tissue)))
    errMsg = 'Reduced head model cannot be used when computing MEG+EEG simultaneously.';
    return;
end
% Hexa mesh: detect whether the geometry was adapted
if strcmpi(ElementType, 'hexahedron')
    GeometryAdapted = [];
    % Detect using the options of the Brainstorm process that created the file
    if isfield(FemMat, 'History') && ~isempty(FemMat.History) && ~isempty(strfind([FemMat.History{:,3}], 'NodeShift'))
        strOptions = [FemMat.History{:,3}];
        iTag = strfind(strOptions, 'NodeShift');
        val = sscanf(strOptions(iTag:end), 'NodeShift=%f');
        if ~isempty(val)
            GeometryAdapted = (val > 0);
        end
    end
    % Otherwise, try to guess based on the geometry
    if isempty(GeometryAdapted)
        % Compute the distance between the first two nodes of each element
        dist = sqrt(sum([FemMat.Vertices(FemMat.Elements(:,1),1) - FemMat.Vertices(FemMat.Elements(:,2),1), ...
         FemMat.Vertices(FemMat.Elements(:,2),2) - FemMat.Vertices(FemMat.Elements(:,2),2), ...
         FemMat.Vertices(FemMat.Elements(:,2),3) - FemMat.Vertices(FemMat.Elements(:,2),3)] .^ 2, 2));
        % If the distance is not constant: then the geomtry is adapted
        GeometryAdapted = (max(abs(dist - dist(1))) > 1e-9);
    end
    % Copy value in DUNEuro options
    if ~isempty(GeometryAdapted)
        cfg.GeometryAdapted = GeometryAdapted;
        disp(['DUNEURO> Detected parameter: GeometryAdapted=', bool2str(GeometryAdapted)]);
    end
end
% % Isotropic
% if (cfg.Isotropic)
%     % Isotropic without tensor
%     if ~cfg.UseTensor
%         if strcmp(ElementType,'hexahedron')
%             MeshFile = 'head_model.dgf';
%         else
%             MeshFile = 'head_model.msh';
%         end
%     % Isotropic with tensor
%     else    
%         if strcmp(ElementType,'hexahedron')
%             errMsg = 'Using the tensor model with hexahedral mesh is not supported for now.';
%             return;
%         end
%         MeshFile = 'head_model.geo';
%     end
% % Anisotropic (with tensor)
% else
%     if strcmp(ElementType,'hexahedron')
%         errMsg = 'Using the anisotropy model with hexahedral mesh is not supported for now.';
%         return;
%     end
%     MeshFile = 'head_model.geo';
%     cfg.UseTensor = true;
% end

% Get temp folder
TmpDir = bst_get('BrainstormTmpDir', 0, 'duneuro');
% Display message
bst_progress('text', 'DUNEuro: Writing temporary files...');
disp(['DUNEURO> Writing temporary files to: ' TmpDir]);

%% ====== SOURCE SPACE =====
% Source space type
switch (cfg.HeadModelType)
    case 'volume'
        % TODO or keep it as it's now....
    case 'surface'
        bst_progress('text', 'DUNEuro: Fixing source space...');
        % Read cortex file
        sCortex = bst_memory('LoadSurface', cfg.CortexFile);
        cfg.GridLoc = sCortex.Vertices;
        % Shrink the cortex surface by XX mm
        if (cfg.SrcShrink > 0)
            % Get spherical coordinates of the surface normals
            [azimuth, elevation] = cart2sph(sCortex.VertNormals(:,1), sCortex.VertNormals(:,2), sCortex.VertNormals(:,3));
            % Find components to shrink the surface in the three dimensions
            depth = cfg.SrcShrink ./ 1000 .* [cos(elevation) .* cos(azimuth), cos(elevation) .* sin(azimuth), sin(elevation)];
            % Apply to the cortex surface
            cfg.GridLoc = cfg.GridLoc - depth;
        end
        % Force all the dipoles within the GM layer
        iGM = find(panel_duneuro('CheckType', FemMat.TissueLabels, 'gray'), 1);
        iWM = find(panel_duneuro('CheckType', FemMat.TissueLabels, 'white'), 1);
        if cfg.SrcForceInGM && ~isempty(iGM)
            % Install/load iso2mesh plugin
            [isInstalled, errMsg] = bst_plugin('Install', 'iso2mesh', cfg.Interactive);
            if ~isInstalled
                % Delete the temporary files
                file_delete(TmpDir, 1, 1);
                return;
            end
            % Extract GM vertices and elements
            [gmVert, gmElem] = removeisolatednode(FemMat.Vertices, FemMat.Elements(FemMat.Tissue == iGM,:));
            % Compute the centroid of the GM elements
            nElem = size(gmElem, 1);
            nMesh = size(gmElem, 2);
            ElemCenter = zeros(nElem, 3);
            for i = 1:3
                ElemCenter(:,i) = sum(reshape(gmVert(gmElem,i), nElem, nMesh)')' / nMesh;
            end

            % Extract GM envelope
            envFaces = volface(FemMat.Elements(FemMat.Tissue <= iGM,:));
            [envVert, envFaces] = removeisolatednode(FemMat.Vertices, envFaces);
            % Find the dipoles outside of the GM envelope
            iVertOut = find(~inpolyhedron(envFaces, envVert, cfg.GridLoc));
            if ~isempty(iVertOut)
                disp(['DUNEURO> Warning: ' num2str(length(iVertOut)) ' dipole(s) outside of the GM.']);
            end
            
            % If there is a white matter layer: find the dipoles inside the WM and move them outside to the GM
            if ~isempty(iWM)
                % Extract GM envelope
                wmFaces = volface(FemMat.Elements(FemMat.Tissue == iWM,:));
                [wmVert, wmFaces] = removeisolatednode(FemMat.Vertices, wmFaces);
                % Find the dipoles outside of the GM envelope
                iVertWM = find(inpolyhedron(wmFaces, wmVert, cfg.GridLoc));
                if ~isempty(iVertWM)
                    disp(['DUNEURO> Warning: ' num2str(length(iVertWM)) ' dipole(s) inside the WM.']);
                    iVertOut = union(iVertOut, iVertWM);
                end
            end
            
            % Move each vertex towards the centroid of the closest GM element
            % view_surface_matrix(cfg.GridLoc, sCortex.Faces)
            for i = 1:length(iVertOut)
                bst_progress('text', sprintf('DUNEuro: Fixing dipole %d/%d...', i, length(iVertOut)));
                % Find the closest GM centroid
                iTarget = dsearchn(ElemCenter, cfg.GridLoc(iVertOut(i),:));
                targetFaces = volface(gmElem(iTarget,:));
                
                % OPTION #1: Replace the vertex position directly with the centroid.
                % => Problem: might project multiple vertices on the same centroid...
                % cfg.GridLoc(iVertOut ,:) = ElemCenter(iTarget,:);
                
                % OPTION #2: Gradually move the vertex towards the center of the centroid, until it is located inside the element
                % Move the vertex towards the center until it is inside the element
                %nFix = 10;
                %for iFix = 1:nFix
                %    tmpVert = (nFix - iFix)/nFix * cfg.GridLoc(iVertOut(i),:) + iFix/nFix * ElemCenter(iTarget,:);
                %   if inpolyhedron(targetFaces, gmVert, tmpVert)
                %        distMove = sqrt(sum((cfg.GridLoc(iVertOut(i),:) - tmpVert) .^ 2)) * 1000;
                %        disp(sprintf('DUNEURO> Dipole #%d moved inside the GM (%1.2fmm)', iVertOut(i), distMove));
                %        cfg.GridLoc(iVertOut(i),:) = tmpVert;
                %        break;
                %    end
                %end
                
                % OPTION #3: move the vertex towards the centroid of the element, and then place the final dipole 
                % in the symetric point to the center, as the image of the computed vertex
                % x-----o-----x'
                % ^      ^      ^____ : x' the image of x, or the final dipole position 
                % |       |_________ : o is the center of the elem, and middle of [x,x']
                % |_____________ : the point inside the element determined by the tmpVert in the following equation                
                nFix = 10; % divid into 10 segments
                iFix = 7; % ratio of the distance tmpVert from the centroid
                tmpVert = (nFix - iFix)/nFix * cfg.GridLoc(iVertOut(i),:) + iFix/nFix * ElemCenter(iTarget,:);
                distPoint = ElemCenter(iTarget,:) - tmpVert;
                newPoint = ElemCenter(iTarget,:) + (distPoint);
                distMove = sqrt(sum((cfg.GridLoc(iVertOut(i),:) - newPoint) .^ 2)) * 1000;
                % use the image/symeric point if it's inside GM
                if inpolyhedron(targetFaces, gmVert, newPoint) 
                    disp(sprintf('DUNEURO> iDipole %d/%d : Dipole #%d moved inside the GM (%1.2fmm) (option 3 :as image)',i,length(iVertOut), iVertOut(i), distMove));
                    cfg.GridLoc(iVertOut(i),:) = newPoint;
                elseif inpolyhedron(targetFaces, gmVert, tmpVert) % use the original point if it's inside GM
                    disp(sprintf('DUNEURO> iDipole %d/%d : Warning Dipole #%d moved outside the GM (%1.2fmm) (option 3 :as image)', i,length(iVertOut),iVertOut(i), distMove));
                    % use the original distance unstead of the image
                    distMove = sqrt(sum((cfg.GridLoc(iVertOut(i),:) - tmpVert) .^ 2)) * 1000;
                    disp(sprintf('DUNEURO> iDipole %d/%d : Correction 1: Dipole #%d moved inside the GM (%1.2fmm) (option 3: not image)', i,length(iVertOut),iVertOut(i), distMove));
                    cfg.GridLoc(iVertOut(i),:) = tmpVert;               
                else % Use the option 2 defined by Francois
                    disp(sprintf('DUNEURO> iDipole %d/%d : Warning Dipole #%d moved outside the GM (%1.2fmm) (option 3 :as image)', i,length(iVertOut),iVertOut(i), distMove));
                    nFix = 20; % with 10 it's not working for some extrem case, then I upgrade it to 20
                    for iFix = 1: nFix
                       tmpVert = (nFix - iFix)/nFix * cfg.GridLoc(iVertOut(i),:) + iFix/nFix * ElemCenter(iTarget,:);
                      if inpolyhedron(targetFaces, gmVert, tmpVert)
                           distMove = sqrt(sum((cfg.GridLoc(iVertOut(i),:) - tmpVert) .^ 2)) * 1000;
                           disp(sprintf('DUNEURO> iDipole %d/%d : Correction 2: Dipole #%d moved inside the GM (%1.2fmm) (option2)', i,length(iVertOut),iVertOut(i), distMove));
                           cfg.GridLoc(iVertOut(i),:) = tmpVert;
                           break;
                       end
                    end
                end
            end
            % view_surface_matrix(cfg.GridLoc, sCortex.Faces)

%             %%%% =============================================
%             % Now similar process for the WM with an extra and unexpedted step ...
%             if ~isempty(iWM)
%                 disp('Checking the the WM ...');
%                 %Extract WM surface
%                 wm_tetra = FemMat.Elements(FemMat.Tissue <= iWM,:);
%                 wm_face = volface(wm_tetra);
%                 [nwmf, ewmf] = removeisolatednode(FemMat.Vertices,wm_face);
%                 % check if any dipoles is inside the WM
%                 wMfv.vertices = nwmf;
%                 wMfv.faces = ewmf;
%                 tic
%                 wMin = inpolyhedron(wMfv, sCortex.Vertices);
%                 wMindex_in = find(wMin);
%                 disp(['There are ' num2str(sum(wMin)) ' dipoles inside the WM']);
%                 disp('Moving these dipoles to the GM tissues ...');
%                 twm = toc;
%                 if ~isempty(wMindex_in)
%                     % 1- move the dipole from inside the WM to the GM surface
%                     % ==> this is for testing, when we use the centroide
%                     % directely, some dipole remains within the WM ...
%                     GMcentroide = 0; % just for testing, to use directely the GM centroides
%                     if GMcentroide == 1
%                         k = dsearchn(elem_centroide,sCortex.Vertices(wMindex_in,:));
%                         NewVertices(wMindex_in ,:) = ElemCenter(k,:);
%                         wMoutFinal = inpolyhedron(wMfv, NewVertices);
%                         disp(['Now, there are ' num2str(sum(wMoutFinal)) ' dipoles inside  the WM']);
%                     else
%                         k = dsearchn(gMfv.vertices,sCortex.Vertices(wMindex_in,:));
%                         NewVertices(wMindex_in ,:) = gMfv.vertices(k,:);
%                         wMoutFinal = inpolyhedron(wMfv, NewVertices);
%                         disp(['There are ' num2str(sum(wMoutFinal)) ' dipoles inside  the WM']);
%                         disp(['These dipoles are moved to the GM outer surface nodes']);
%                         disp(['Moving these dipoles to the nearest centroide of the GM element...']);
%                         % Now, we move these same dipole from the surface to the
%                         % nearest centroide ==> to be sure it's inside the GM
%                         % ==> fill partially the FEM condition
%                         % move again  to the centoide
%                         k = dsearchn(ElemCenter,NewVertices(wMindex_in,:));
%                         NewVertices(wMindex_in ,:) = ElemCenter(k,:);
%                         % just to check
%                         wMoutFinal = inpolyhedron(wMfv, NewVertices);
%                         disp(['Now, there are ' num2str(sum(wMoutFinal)) ' dipoles inside  the WM']);
%                         disp(['All the dipoles are moved to nearest centroid of the GM']);
%                     end
%                 end
%             end

        end
    case 'mixed'
        % TODO : not used ?
end


%% ===== SOURCE MODEL =====
bst_progress('text', 'DUNEuro: Writing temporary files...');
% Write the source/dipole file
% DipoleFile = fullfile(TmpDir, 'dipole_model.txt');
% Unconstrained orientation for each dipole. ie the output file have 3*N dipoles (3 directions for each)
%     [x1,y1,z1, 1, 0, 0,;
%      x1,y1,z1, 0, 1, 0;
%      x1,y1,z1, 0, 0, 1;
%      x2,y2,z2, 1, 0, 0;
%      .... ];
% dipoles = [kron(cfg.GridLoc, ones(3,1)), kron(ones(size(cfg.GridLoc,1), 1), eye(3))];
% fid = fopen(DipoleFile, 'wt+');
% fprintf(fid, '%d %d %d %d %d %d \n', dipoles');
% fclose(fid);
[iOk, errMsg] = bstdn_write_source_space(TmpDir, cfg.GridLoc);

%% ===== SENSOR MODEL =====
% Write the EEG electrode file
if isEeg || isEcog || isSeeg 
    bstdn_write_pem_electrodes(TmpDir, EegLoc', 'measurement');
end
% Write the MEG sensors data 
if isMeg
    % Write coil data
    % ********* TODO ***********
    % Get the correct weigh from the original channel file
    coil_to_channel_transform = eye(length(MegChannels));
    coil_to_channel_transform = coil_to_channel_transform.* MegChannels(:,end);
    dnbst_write_magnetometers(TmpDir, MegChannels(:,2:4), MegChannels(:,5:7), coil_to_channel_transform);
end

%% ===== CONDUCTIVITY MODEL =====
% % Isotropic without tensor
% if ~cfg.UseTensor
%     CondFile = fullfile(TmpDir, 'conductivity_model.con');
%     fid = fopen(CondFile, 'w');
%     fprintf(fid, '%d\t', cfg.FemCond);
%     fclose(fid);
% % With tensor (isotropic or anisotropic)
% else
%     CondFile = fullfile(TmpDir, 'conductivity_model.knw'); 
%     % Transformation matrix  and tensor mapping on each direction
%     CondTensor = zeros(length(FemMat.Elements),6) ;
%     for ind =1 : length(FemMat.Elements)
%         temp0 = reshape(FemMat.Tensors(ind,:),3,[]);
%         T1 = temp0(:,1:3); % get the 3 eigen vectors
%         l =  diag(temp0(:,4)); % get the eigen value as 3x3
%         temp = T1 * l * T1'; % reconstruct the tensors
%         CondTensor(ind,:) = [temp(1) temp(5) temp(9) temp(4) temp(8) temp(7)]; % this is the right order       
%     end
%     % write the tensors 
%     out_fem_knw(FemMat, CondTensor, CondFile);
% end
% % Write mesh model
% MeshFile = fullfile(TmpDir, MeshFile);
% out_fem(FemMat, MeshFile);
%% DN2026
% export volume conductor model
% write_volume_conductor(TmpDir, nodes, elements, labels, tensors);
% write hdf5 files : 
% online viewer of hdf5 files : https://myhdf5.hdfgroup.org/
dnbst_write_volume_conductor(TmpDir, FemMat,  cfg.FemCond);


% run DUNEuro container
% Source Space configuration
sourcespace_config = [];
sourcespace_config.name = 'create_sourcespace';
% sourcespace_config.sourcecompartment = '1';
% sourcespace_config.gridsize = '2.0';
% sourcespace_config.enforceDistanceCondition = 'True';
% sourcespace_config.distanceThreshold = '0.5';
sourcespace_config.enforceVenantCondition = 'True';
% sourcespace_config.visualizeSourceSpace = 'True';

 
% Transfer Matrix configuration
transfer_matrix_config = [];
transfer_matrix_config.name = 'compute_transfer_matrix';
if strcmp(dnModality, 'eeg')
    transfer_matrix_config.do_eeg = 'True';
    transfer_matrix_config.do_meg = 'False';
end
if strcmp(dnModality, 'meg')
    transfer_matrix_config.do_meg = 'True';
    transfer_matrix_config.do_eeg = 'False';
end
if strcmp(dnModality, 'meeg')
    transfer_matrix_config.do_meg = 'True';
    transfer_matrix_config.do_eeg = 'True';
end
transfer_matrix_config.residual_reduction = '1e-16';
transfer_matrix_config.nr_threads = '-1';

% Leadfield configuration
leadfield_config = [];
leadfield_config.name = 'compute_leadfield';
if strcmp(dnModality, 'eeg')
    leadfield_config.do_meg = 'False';
    leadfield_config.do_eeg = 'True';
    leadfield_config.eeg_scaling = '1e0';
    leadfield_config.meg_scaling = '1e5';
end
if strcmp(dnModality, 'meg')
    leadfield_config.do_meg = 'True';
    leadfield_config.do_eeg = 'False';
    leadfield_config.eeg_scaling = '1e0';
    leadfield_config.meg_scaling = '1e5';
end
if strcmp(dnModality, 'meeg')
    leadfield_config.do_meg = 'True';
    leadfield_config.do_eeg = 'True';
    leadfield_config.eeg_scaling = '1e0';
    leadfield_config.meg_scaling = '1e5';
end
leadfield_config.sourcemodel = cfg.SrcModel2026; % [select from the interface: 'multipolar_venant', 'local_subtraction', 'partial_integration']
leadfield_config.nr_threads = '-1';

%% ===== RUN DUNEURO ======
% Assemble command line
% callStr = ['"' DuneuroExe '"' ' ' '"' IniFile '"'];
bst_progress('text', 'DUNEuro: Computing leadfield...');
runner = 'docker';
% disp(['DUNEURO> System call: ' callStr]);
tic;
% Call DUNEuro
if 0
    [status, errMsg ] = bst_run_duneuro_task(TmpDir, sourcespace_config, runner); % wheew is the outputs?
end 
% Compute transfer matrix
[status, errMsg ] = bst_run_duneuro_task(TmpDir, transfer_matrix_config, runner);
% Compute the Leadfield
[status, errMsg ] = bst_run_duneuro_task(TmpDir, leadfield_config, runner);

if (status ~= 0)
    errMsg = 'Error during the DUNEuro computation, see logs in the command window.';
    return;
end
disp(['DUNEURO> FEM computation completed in: ' num2str(toc) 's']);

%% ===== READ LEADFIELD ======
bst_progress('text', 'DUNEuro: Reading leadfield...');
% % EEG
% if (isEeg || isEcog || isSeeg) 
%     GainEeg = in_duneuro_bin(fullfile(TmpDir, cfg.BstEegLfFile))';
% end
% read data
% source_positions = transpose(h5read(fullfile(TmpDir, 'duneuro_io.hdf5'), '/measurement/source_space/positions'));
% EEG
if (isEeg || isEcog || isSeeg) 
    GainEeg = transpose(h5read(fullfile(TmpDir, 'duneuro_io.hdf5'), '/measurement/source_space/leadfield/EEG'));
end
if (isMeg) 
    GainMeg = transpose(h5read(fullfile(TmpDir, 'duneuro_io.hdf5'), '/measurement/source_space/leadfield/MEG'));
end

% Fill the unused channels with NaN
Gain = NaN * zeros(length(cfg.Channel), 3 * length(cfg.GridLoc));
if isMeg
    Gain(cfg.iMeg,:) = GainMeg; 
    % scaling the MEG Gain matrix 
    Gain(cfg.iMeg,:) = GainMeg/1000; 
end 
if (isEeg || isEcog || isSeeg) 
    Gain(cfg.iEeg,:) = GainEeg; 
end

% Delete the temporary files
% file_delete(TmpDir, 1, 1);


%% ===== SAVE TRANSFER MATRIX ======
disp('DUNEURO> TODO: Save transferOut.dat to database.')

% Remove logo
bst_plugin('SetProgressLogo', []);


% %% ===== WRITE MINI FILE =====
% % Open the mini file
% IniFile = fullfile(TmpDir, 'duneuro_minifile.mini');
% fid = fopen(IniFile, 'wt+');
% % General setting
% fprintf(fid, '__name = %s\n\n', IniFile);
% if strcmp(cfg.SolverType, 'cg')
%     fprintf(fid, 'type = %s\n', cfg.FemType);
% end
% fprintf(fid, 'element_type = %s\n', ElementType);
% fprintf(fid, 'solver_type = %s\n', cfg.SolverType);
% fprintf(fid, 'geometry_adapted = %s\n', bool2str(cfg.GeometryAdapted));
% fprintf(fid, 'tolerance = %d\n', cfg.Tolerance);
% % [electrodes]
% if isEcog || isSeeg 
%     % Instead of selecting the electrode on the outer surface,
%     % uses the nearest FEM node as the electrode location
%     cfg.ElecType = 'closest_subentity_center';
% end
% if strcmp(dnModality, 'eeg') || strcmp(dnModality, 'meeg')
%     fprintf(fid, '[electrodes]\n');
%     fprintf(fid, 'filename = %s\n', fullfile(TmpDir, ElecFile));
%     fprintf(fid, 'type = %s\n', cfg.ElecType);
%     fprintf(fid, 'codims = %s\n', '3');
% end
% % [meg]
% if strcmp(dnModality, 'meg') || strcmp(dnModality, 'meeg')
%     fprintf(fid, '[meg]\n');
%     fprintf(fid, 'intorderadd = %d\n', cfg.MegIntorderadd);
%     fprintf(fid, 'type = %s\n', cfg.MegType);
%     fprintf(fid, 'cache.enable = %s\n',bool2str(cfg.EnableCacheMemory) );
%     % [coils]
%     fprintf(fid, '[coils]\n');
%     fprintf(fid, 'filename = %s\n', CoilFile);
%     % [projections]
%     fprintf(fid, '[projections]\n');
%     fprintf(fid, 'filename = %s\n', ProjFile);
% end
% % [dipoles]
% fprintf(fid, '[dipoles]\n');
% fprintf(fid, 'filename = %s\n', DipoleFile);
% % [volume_conductor.grid]
% fprintf(fid, '[volume_conductor.grid]\n');
% fprintf(fid, 'filename = %s\n', MeshFile);
% % [volume_conductor.tensors]
% fprintf(fid, '[volume_conductor.tensors]\n');
% fprintf(fid, 'filename = %s\n', CondFile);
% % [solver]
% fprintf(fid, '[solver]\n');
% fprintf(fid, 'solver_type = %s\n', cfg.SolvSolverType);
% fprintf(fid, 'preconditioner_type = %s\n', cfg.SolvPrecond);
% if strcmp(cfg.SolverType, 'cg')
%     fprintf(fid, 'cg_smoother_type = %s\n', cfg.SolvSmootherType);
% end
% fprintf(fid, 'intorderadd = %d\n', cfg.SolvIntorderadd);
% % Discontinuous Galerkin
% if strcmp(cfg.SolverType, 'dg')
%     fprintf(fid, 'dg_smoother_type = %s\n', cfg.DgSmootherType);
%     fprintf(fid, 'scheme = %s\n', cfg.DgScheme);
%     fprintf(fid, 'penalty = %d\n', cfg.DgPenalty);
%     fprintf(fid, 'edge_norm_type = %s\n', cfg.DgEdgeNormType);
%     fprintf(fid, 'weights = %s\n', bool2str(cfg.DgWeights));
%     fprintf(fid, 'reduction = %s\n', bool2str(cfg.DgReduction));
% end
% % [solution]
% fprintf(fid, '[solution]\n');
% fprintf(fid, 'post_process = %s\n', bool2str(cfg.SolPostProcess)); % true/false
% fprintf(fid, 'subtract_mean = %s\n', bool2str(cfg.SolSubstractMean)); % boolean
% % [solution.solver]
% fprintf(fid, '[solution.solver]\n');
% fprintf(fid, 'reduction = %d\n', cfg.SolSolverReduction);
% % [solution.source_model]
% fprintf(fid, '[solution.source_model]\n');
% fprintf(fid, 'type = %s\n', cfg.SrcModel);
% fprintf(fid, 'intorderadd = %d\n', cfg.SrcIntorderadd);
% fprintf(fid, 'intorderadd_lb = %d\n', cfg.SrcIntorderadd_lb);
% fprintf(fid, 'numberOfMoments = %d\n', cfg.SrcNbMoments);
% fprintf(fid, 'referenceLength = %d\n', cfg.SrcRefLen);
% fprintf(fid, 'weightingExponent = %d\n', cfg.SrcWeightExp);
% fprintf(fid, 'relaxationFactor = %e\n', 10^(-cfg.SrcRelaxFactor));
% fprintf(fid, 'mixedMoments = %s\n', bool2str(cfg.SrcMixedMoments));
% fprintf(fid, 'restrict = %s\n', bool2str(cfg.SrcRestrict));
% fprintf(fid, 'initialization = %s\n', cfg.SrcInit);
% % [brainstorm]
% fprintf(fid, '[brainstorm]\n');
% fprintf(fid, 'modality = %s\n', dnModality);
% fprintf(fid, 'output_folder = %s\n', [TmpDir, filesep]);
% fprintf(fid, 'save_eeg_transfer_file = %s\n', bool2str(cfg.BstSaveTransfer));
% fprintf(fid, 'save_meg_transfer_file = %s\n', bool2str(cfg.BstSaveTransfer));
% fprintf(fid, 'save_meeg_transfer_file = %s\n', bool2str(cfg.BstSaveTransfer));
% fprintf(fid, 'eeg_transfer_filename = %s\n', cfg.BstEegTransferFile);
% fprintf(fid, 'meg_transfer_filename = %s\n', cfg.BstMegTransferFile);
% fprintf(fid, 'eeg_leadfield_filename = %s\n', cfg.BstEegLfFile);
% fprintf(fid, 'meg_leadfield_filename = %s\n', cfg.BstMegLfFile);
% % Close file
% fclose(fid);


% %% ===== RUN DUNEURO ======
% % Assemble command line
% callStr = ['"' DuneuroExe '"' ' ' '"' IniFile '"'];
% bst_progress('text', 'DUNEuro: Computing leadfield...');
% disp(['DUNEURO> System call: ' callStr]);
% tic;
% % Call DUNEuro
% status = system(callStr)
% if (status ~= 0)
%     errMsg = 'Error during the DUNEuro computation, see logs in the command window.';
%     return;
% end
% disp(['DUNEURO> FEM computation completed in: ' num2str(toc) 's']);


% %% ===== READ LEADFIELD ======
% bst_progress('text', 'DUNEuro: Reading leadfield...');
% % EEG
% if (isEeg || isEcog || isSeeg) 
%     GainEeg = in_duneuro_bin(fullfile(TmpDir, cfg.BstEegLfFile))';
% end
% 
% %MEG
% To check with Malte: is the MEG leadfield is the finla or just the
% % seconday?
% if isMeg
%     GainMeg = in_duneuro_bin(fullfile(TmpDir, cfg.BstMegLfFile))';
%     % === POST-PROCESS MEG LEADFIELD ===
%     % Compute the total magnetic field 
%     dipoles_pos_orie = [kron(cfg.GridLoc,ones(3,1)), kron(ones(length(cfg.GridLoc),1), eye(3))];
% 
%     % a- Compute the MEG Primary Magnetic B-field analytically (formula of Sarvas)
%     dip_pos = dipoles_pos_orie(:,1:3);
%     dip_mom = dipoles_pos_orie(:,4:6);
%     Bp = zeros(size(MegChannels,1), size(dip_pos,1));
%     for i = 1:size(CoilsLoc,1)
%         for j = 1 : size(dip_pos,1)
%             R = CoilsLoc(i,:);
%             R_0 = dip_pos(j,:);
%             A = R - R_0;
%             a = norm(A);
%             aa = A./(a^3);
%             BpHelp = cross(dip_mom(j,:),aa);
%             Bp(i,j) = BpHelp * CoilsOrient(i, :)'; % projection of the primary B-field along the coil orientations
%         end
%     end
% 
%     % b- The total magnetic field B = Bp + Bs;
%     %  full B-field
%     Bs = GainMeg;
%     mu = 4*pi*1e-4; % check the value of the units maybe it needs to be mu = 4*pi*1e-7
%     Bfull = (mu/(4*pi)) * (Bp - Bs);
% 
%     % c- Apply the weight :
%     [channelIndex] = unique(MegChannels(:,1));
%     nbChannel = length(channelIndex);
%     weighted_B = zeros(nbChannel,size(Bfull,2));
%     for iCh = 1 : nbChannel
%         communChannel = find(iCh==MegChannels(:,1));
%         BcommunChannel = Bfull(communChannel(:),:);
%         WcommunChannel =  MegChannels(communChannel(:), 8: end);
%         weighted_B(iCh,:) = sum (BcommunChannel.*WcommunChannel,1);
%     end    
%     GainMeg = weighted_B;
% end

% % Fill the unused channels with NaN
% Gain = NaN * zeros(length(cfg.Channel), 3 * length(cfg.GridLoc));
% if isMeg
%     Gain(cfg.iMeg,:) = GainMeg; 
%     % scaling the MEG Gain matrix 
%     Gain(cfg.iMeg,:) = GainMeg/1000; 
% end 
% if (isEeg || isEcog || isSeeg) 
%     Gain(cfg.iEeg,:) = GainEeg; 
% end
% 
% % Delete the temporary files
% file_delete(TmpDir, 1, 1);
% 
% 
% %% ===== SAVE TRANSFER MATRIX ======
% disp('DUNEURO> TODO: Save transferOut.dat to database.')
% 
% % Remove logo
% bst_plugin('SetProgressLogo', []);

end




%% =================================================================================
%  === SUPPORT FUNCTIONS  =========================================================
%  =================================================================================

%% ===== BOOL => STR =====
function str = bool2str(bool)
    if bool
        str = 'true';
    else
        str = 'false';
    end
end


function [iOk, errMsg] = dnbst_write_volume_conductor(duneuro_io_dir, FemMat, isoCond)
    iOk = 0; errMsg = '';
    
    nodes = FemMat.Vertices; 
    elements = FemMat.Elements - 1; 
    labels = FemMat.Tissue - 1; 

    io_file_path = fullfile(duneuro_io_dir, 'duneuro_io.hdf5');
    
    % % we assume that this function create the IO file. We abort the execution
    % % if the file already exists
    % if isfile(io_file_path)
    %     errMsg = ['There already exists a file at the location ', io_file_path];
    % end
    
    % get information about the input data
    nr_nodes = size(nodes, 1);
    nr_elements = size(elements, 1);
    nr_labels = size(labels, 1);
    nr_unique_tensors = length(isoCond);
    
    dim = 3;
    nr_nodes_per_tetrahedron = 4;
    
    if nr_elements ~= nr_labels
        errMsg = 'Number of elements does not match number of labels';  return;
    end
    
    if size(nodes, 2) ~= dim
        errMsg = 'Number of columns of nodes array must be 3';  return;
    end
    
    if size(elements, 2) ~= nr_nodes_per_tetrahedron
        errMsg = 'The DUNEuro container interface currently only supports tetrahedral meshes (or the number of column of the elements array is wrong)';  return;
    end    
    % Create tensor format from the isoconductivity
    tensors = zeros(length(isoCond), 3, 3);
    for iTissue = 1 : length(FemMat.TissueLabels)
        tensors(iTissue,1,1) = isoCond(iTissue);
        tensors(iTissue,2,2) = isoCond(iTissue);
        tensors(iTissue,3,3) = isoCond(iTissue);
    end
    if (size(tensors, 2) ~= dim) || (size(tensors, 3) ~= dim)
       errMsg = 'The shape of the tensors array must be (K, 3, 3)';  return;
    end
    % create output file
    % DUNEuro is a C++ toolbox, it utilizes row-major ordering. Matlab, on the other hand,
    % uses colum-major ordering. For a consistent array shape, we thus need to transpose
    % the arrays (resp. apply a permutation for the tensor array)
    h5create(io_file_path, "/volume_conductor/nodes", [dim nr_nodes ], Datatype="double");
    h5create(io_file_path, "/volume_conductor/elements", [nr_nodes_per_tetrahedron nr_elements], Datatype="int32");
    h5create(io_file_path, "/volume_conductor/labels", nr_elements, Datatype="int32");
    h5create(io_file_path, "/volume_conductor/tensors", [dim dim nr_unique_tensors], Datatype="double");
    
    h5write(io_file_path, "/volume_conductor/nodes", nodes');
    h5write(io_file_path, "/volume_conductor/elements", elements');
    h5write(io_file_path, "/volume_conductor/labels", labels');
    h5write(io_file_path, "/volume_conductor/tensors", permute(tensors, [3 2 1]));
    
    h5writeatt(io_file_path, "/volume_conductor", 'type', 'fitted');
    h5writeatt(io_file_path, "/volume_conductor", 'element_type', 'tetrahedron');
    
    % if all goes well, return 1
    iOk = 1;
end

function [iOk, errMsg] = dnbst_write_magnetometers(duneuro_io_dir, coil_positions, coil_orientations, coil_to_channel_transform)
    iOk = 0; errMsg = '';

    io_file_path = fullfile(duneuro_io_dir, 'duneuro_io.hdf5');
    
    % % we assume that the output file already exists
    % if ~isfile(io_file_path)
    %     error('The DUNEuro IO file does not exist, please call write_volume_conductor first');
    % end
    
    nr_magnetometers = size(coil_positions, 1);
    nr_channels = size(coil_to_channel_transform, 1);
    
    dim = 3;
    
    if size(coil_positions, 2) ~= dim
        errMsg = 'Number of columns of coil position array must be 3';  return;
    end
    
    if size(coil_orientations, 2) ~= dim
        errMsg = 'Number of columns of coil orientation array must be 3';  return;
    end
    
    if size(coil_orientations, 1) ~= nr_magnetometers
        error('Position and orientation arrays must have matching number of rows');  return;
    end
    
    if size(coil_to_channel_transform, 2) ~= nr_magnetometers
        errMsg = 'Number of columns of transformation matrix must match number of coils';  return;
    end
    
    h5create(io_file_path, "/measurement/sensors/magnetometers/positions", [dim nr_magnetometers], Datatype="double");
    h5create(io_file_path, "/measurement/sensors/magnetometers/orientations", [dim nr_magnetometers], Datatype="double");
    h5create(io_file_path, "/measurement/sensors/magnetometers/coil_to_channel_transform", [nr_magnetometers, nr_channels], Datatype="double");
    
    h5write(io_file_path, "/measurement/sensors/magnetometers/positions", coil_positions');
    h5write(io_file_path, "/measurement/sensors/magnetometers/orientations", coil_orientations');
    h5write(io_file_path, "/measurement/sensors/magnetometers/coil_to_channel_transform", coil_to_channel_transform');

    % if all goes well, return 1
    iOk = 1;
end

function [iOk, errMsg] = bstdn_write_pem_electrodes(duneuro_io_dir, electrode_positions, electrode_type_flag)
    iOk = 0; errMsg = '';

    io_file_path = fullfile(duneuro_io_dir, 'duneuro_io.hdf5');
    
    % % we assume that the output file already exists
    % if ~isfile(io_file_path)
    %   error('The DUNEuro IO file does not exist, please call write_volume_conductor first');
    % end
    
    nr_electrodes = size(electrode_positions, 1);
    dim = 3;
    
    if size(electrode_positions, 2) ~= dim
      errMsg = 'The electrode array must have 3 columns'; return;
    end
    
    if strcmp(electrode_type_flag, 'measurement')
      h5create(io_file_path, "/measurement/sensors/electrodes/positions", [dim nr_electrodes], Datatype="double");
      h5write(io_file_path, "/measurement/sensors/electrodes/positions", electrode_positions');
      h5writeatt(io_file_path, "/measurement/sensors/electrodes", 'mode', 'PEM');
    elseif strcmp(electrode_type_flag, 'stimulation')
      h5create(io_file_path, "/stimulation/TDCS/electrodes/positions", [dim nr_electrodes], Datatype="double");
      h5write(io_file_path, "/stimulation/TDCS/electrodes/positions", electrode_positions');
      h5writeatt(io_file_path, "/stimulation/TDCS/electrodes", 'mode', 'PEM');
    else
       errMsg = 'Electrode type flag needs to be either "measurement" or "stimulation"';  return;
    end
    iOk = 1;
end

function [iOk, errMsg] = bstdn_write_source_space(duneuro_io_dir, dipole_positions)
    iOk = 0; errMsg = '';

    io_file_path = fullfile(duneuro_io_dir, 'duneuro_io.hdf5');    
    
    nr_dipoles = size(dipole_positions, 1);
    % no_dipoles = size(dipole_orientations, 1);
    dim = 3;
    
    if size(dipole_positions, 2) ~= dim
      errMsg = 'The dipole position array must have 3 columns';  return;
    end
    % if size(electrode_positions, 2) ~= dim
    %     errMsg = 'The dipole orientation array must have 3 columns';
    % end
    
    % if strcmp(electrode_type_flag, 'measurement')
      h5create(io_file_path, "/measurement/source_space/positions", [dim nr_dipoles], Datatype="double");
      h5write(io_file_path, "/measurement/source_space/positions", dipole_positions');
 
    % else
    %    errMsg = 'Dipole flag needs to be either "measurement"';  return;
    % end
    iOk = 1;
end



function [status, errMsg ] = bst_run_duneuro_task(duneuro_io_dir, config, runner)
status = 0; errMsg  = '';
task_name = config.name;

config_file_path = fullfile(duneuro_io_dir, 'config.ini');
io_file_path = fullfile(duneuro_io_dir, 'duneuro_io.hdf5');

% first write config file
file_handle = fopen(config_file_path, 'wt');

fprintf(file_handle, ['[task_info]\ntask_list=' task_name '\n\n[' task_name '_config]\n']);

config_keys = fieldnames(config);
for i = 1:length(config_keys)
  current_key = config_keys{i};
  current_value = config.(current_key);
  
  % write everything except the task name 
  if ~strcmp(current_key, 'name')
    fprintf(file_handle, [current_key '=' current_value '\n']);
  end
end

fclose(file_handle);

% now execute system call to start the container
if strcmp(runner, 'docker')
  runner_system_call = ['docker run -t --rm -v ' duneuro_io_dir ':/duneuro/external_mount ghcr.io/maltehoel/duneuro_in_docker_testing:wip'];
elseif strcmp(runner, 'podman')
  % if we run podman in rootless mode, we need to make the IO directory writable 
  % for the container user
  duneuro_container_uid = '50000'; % this uid is explicitely set in the Dockerfile
  change_ownership_in_container_command = ['podman unshare chown ' duneuro_container_uid ':' duneuro_container_uid ' -R ' duneuro_io_dir];
  container_command = ['podman run -t --rm -v ' duneuro_io_dir ':/duneuro/external_mount ghcr.io/maltehoel/duneuro_in_docker_testing:wip'];
  change_ownership_back_command = ['podman unshare chown 0:0 -R ' duneuro_io_dir];
  runner_system_call = [change_ownership_in_container_command ' && ' container_command ' && ' change_ownership_back_command];
elseif strcmp(runner, 'apptainer')
  runner_system_call = ['apptainer run --bind ' duneuro_io_dir ':/duneuro/external_mount docker://ghcr.io/maltehoel/duneuro_in_docker_testing:wip'];
else
  errMsg = 'unknown runner';
   return;
end

status = system(runner_system_call)
end