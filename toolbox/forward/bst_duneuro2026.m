function [Gain, errMsg] = bst_duneuro2026(cfg)
% BST_DUNEURO: Call Duneuro to compute a FEM solution for Brainstorm.
%
% USAGE:  [Gain, errMsg] = bst_duneuro(cfg)
% NOTE: online viewer of hdf5 files : https://myhdf5.hdfgroup.org/

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
% Authors: Takfarinas Medani, 2019-2026
%          Juan Garcia-Prieto, 2019-2021
%          Francois Tadel 2020-2023

% Initialize returned values
Gain = [];
%% ===== INSTALL AND GET THE EXECUTABLE =====
% ***** ToDo: Define how to check the container *******
% Install/load duneuro container
% Install/load duneuro plugin TODO:
% Note: For the current version of this function, we assume that the appropriate container is installed.
% Three possible runners are possible:  
% - via docker
% - via podman
% - via apptainer
runner =  cfg.containerRunner;
% Get DUNEuro container executable
bst_plugin('SetProgressLogo', 'duneuro');

%% ===== SENSORS =====
% Select modality for DUNEuro
isEeg  = strcmpi(cfg.EEGMethod, 'duneuro2026')  && ~isempty(cfg.iEeg);
isMeg  = strcmpi(cfg.MEGMethod, 'duneuro2026')  && ~isempty(cfg.iMeg);
isEcog = strcmpi(cfg.ECOGMethod, 'duneuro2026') && ~isempty(cfg.iEcog);
isSeeg = strcmpi(cfg.SEEGMethod, 'duneuro2026') && ~isempty(cfg.iSeeg);

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
            MegChannels = [MegChannels; iChan, sChan.Loc(:,iInteg)', sChan.Orient(:,iInteg)', sChan.Weight];
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

% Get temp folder
TmpDir = bst_get('BrainstormTmpDir', 0, 'duneuro');

% Display message
bst_progress('text', 'DUNEuro: Writing temporary files...');
disp(['DUNEURO> Writing temporary files to: ' TmpDir]);

%% ====== SOURCE SPACE =====
% Source space type
switch (cfg.HeadModelType)
    case 'volume'
        % Nothing to do as for now: 
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
        end
    case 'mixed'
        % TODO : not used ?
end

%% ===== SOURCE MODEL =====
bst_progress('text', 'DUNEuro: Writing temporary files...');
bstdn_write_source_space(TmpDir, cfg.GridLoc);

%% ===== SENSOR MODEL =====
% Write the EEG electrode file
if isEeg || isEcog || isSeeg 
    bstdn_write_pem_electrodes(TmpDir, EegLoc', 'measurement');
end
% Write the MEG sensors data 
if isMeg 
    % Write coil data
    % coil_to_channel_transform = eye(length(MegChannels));
    coil_to_channel_transform = MegChannels(:,8:end);
    dnbst_write_magnetometers(TmpDir, MegChannels(:,2:4), MegChannels(:,5:7), coil_to_channel_transform);
    coil_to_channel_transform = build_coil_to_channel_transform_matrix(MegChannels);

end

%% ===== CONDUCTIVITY MODEL =====
% Isotropic without tensor
if ~cfg.UseTensor
    % Create tensor per tissue format from the isoconductivity
    tensors = zeros(length(isoCond), 3, 3);
    for iTissue = 1 : length(FemMat.TissueLabels)
        tensors(iTissue,1,1) = Cond(iTissue);
        tensors(iTissue,2,2) = Cond(iTissue);
        tensors(iTissue,3,3) = Cond(iTissue);
    end
% NOTE: online viewer of hdf5 files : https://myhdf5.hdfgroup.org/
else % With tensor (isotropic or anisotropic)
    % Transformation matrix  and tensor mapping on each direction
    tensors = zeros(length(FemMat.Elements), 3,3);
    for iElem = 1 : length(FemMat.Elements)
        temp0 = reshape(FemMat.Tensors(iElem,:),3,[]);
        T1 = temp0(:,1:3); % get the 3 eigen vectors
        l =  diag(temp0(:,4)); % get the eigen value as 3x3
        temp = T1 * l * T1'; % reconstruct the tensors
        tensors(iElem,:,:) = temp;
    end
    % write the tensors 
    % TODO: Need to double check if it is correct with Malte. 
    % I use all the size of the elem == size of the tensors
    % it seems that we can squeeze it down to set only one value for the
    % iso tissues ==> smaller I/O file
end
dnbst_write_volume_conductor(TmpDir, FemMat,  tensors);

%%  ===== TRANSFER MATRIX CONFIGURATION =====
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
transfer_matrix_config.residual_reduction = cfg.residual_reduction;
transfer_matrix_config.nr_threads = num2str(cfg.NbOfThread); 

%%  ===== LEADFIELD MATRIX CONFIGURATION =====
leadfield_config = [];
leadfield_config.name = 'compute_leadfield';
if strcmp(dnModality, 'eeg')
    leadfield_config.do_meg = 'False';
    leadfield_config.do_eeg = 'True';
end
if strcmp(dnModality, 'meg')
    leadfield_config.do_meg = 'True';
    leadfield_config.do_eeg = 'False';
end
if strcmp(dnModality, 'meeg')
    leadfield_config.do_meg = 'True';
    leadfield_config.do_eeg = 'True';
end
% set final hard code value 
leadfield_config.eeg_scaling = cfg.eeg_scaling; % check with Malte if those value are optimised
leadfield_config.meg_scaling = cfg.meg_scaling; % Malte to check and get final value for MKSA system. 
leadfield_config.sourcemodel = cfg.SrcModel2026; % [select from the interface: 'multipolar_venant', 'local_subtraction', 'partial_integration']
leadfield_config.nr_threads = num2str(cfg.NbOfThread); % same as above
%% ===== RUN DUNEURO ======
bst_progress('text', 'DUNEuro: Computing leadfield...');
% disp(['DUNEURO> System call: ' callStr]);
tic;
% Call DUNEuro and Compute transfer matrix
[status, errMsg ] = bst_run_duneuro_task(TmpDir, transfer_matrix_config, runner);
transferMatrix_time = toc;

tic;
% Call DUNEuro and Compute the Leadfield
[status, errMsg ] = bst_run_duneuro_task(TmpDir, leadfield_config, runner);
leadField_time = toc;

if (status ~= 0)
    errMsg = 'Error during the DUNEuro computation, see logs in the command window.';
    return;
end
disp(['DUNEURO> FEM computation completed in: ' num2str(toc) 's']);

%% ===== READ LEADFIELD ======
bst_progress('text', 'DUNEuro: Reading leadfield...');
% For checking: read the used source space
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
if (isEeg || isEcog || isSeeg) 
    Gain(cfg.iEeg,:) = GainEeg; 
    % ToDo: add ref electrode / identify the reference from the channel
    % file and post process the final Leadfield
end

if isMeg % The MEG is not fully tested as we need to convert from integration points to final position
    Gain(cfg.iMeg,:) = GainMeg; 
end 

% Remove logo
bst_plugin('SetProgressLogo', []);
end

%% =================================================================================
%  === SUPPORT FUNCTIONS  =========================================================
%  =================================================================================
function [iOk, errMsg] = dnbst_write_volume_conductor(duneuro_io_dir, FemMat, Tensors)
    iOk = 0; errMsg = '';
    nodes = FemMat.Vertices; 
    elements = FemMat.Elements - 1; 
    labels = FemMat.Tissue - 1; 
    io_file_path = fullfile(duneuro_io_dir, 'duneuro_io.hdf5');

    % get information about the input data
    nr_nodes = size(nodes, 1);
    nr_elements = size(elements, 1);
    nr_labels = size(labels, 1);
    nr_unique_tensors = length(Cond);
    
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
    h5write(io_file_path, "/volume_conductor/tensors", permute(Tensors, [3 2 1]));
    
    h5writeatt(io_file_path, "/volume_conductor", 'type', 'fitted');
    h5writeatt(io_file_path, "/volume_conductor", 'element_type', 'tetrahedron');
    
    % if all goes well, return 1
    iOk = 1;
end

function [iOk, errMsg] = dnbst_write_magnetometers(duneuro_io_dir, coil_positions, coil_orientations, coil_to_channel_transform)
    iOk = 0; errMsg = '';

    io_file_path = fullfile(duneuro_io_dir, 'duneuro_io.hdf5');
    
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
    
    % if size(coil_to_channel_transform, 2) ~= nr_magnetometers
    %     errMsg = 'Number of columns of transformation matrix must match number of coils';  return;
    % end
    
    h5create(io_file_path, "/measurement/sensors/magnetometers/positions", [dim nr_magnetometers], Datatype="double");
    h5create(io_file_path, "/measurement/sensors/magnetometers/orientations", [dim nr_magnetometers], Datatype="double");
    % h5create(io_file_path, "/measurement/sensors/magnetometers/coil_to_channel_transform", [nr_magnetometers, nr_channels], Datatype="double");
    
    h5write(io_file_path, "/measurement/sensors/magnetometers/positions", coil_positions');
    h5write(io_file_path, "/measurement/sensors/magnetometers/orientations", coil_orientations');
    % h5write(io_file_path, "/measurement/sensors/magnetometers/coil_to_channel_transform", coil_to_channel_transform);

    % if all goes well, return 1
    iOk = 1;
end

function coil_to_channel_transform = build_coil_to_channel_transform_matrix(MegChannels)
    % Extract channel indices and weights
    chan_idx = MegChannels(:,1);
    w        = MegChannels(:,end);
    % Find unique channels
    channels = unique(chan_idx);
    nb_chan  = length(channels);
    % Count coils per channel (should be 4)
    nCoil = sum(chan_idx == channels(1));
    % Total size
    N = nb_chan * nCoil;
    % Preallocate sparse matrix
    Wbig = sparse(N, N);
    % Build matrix
    for k = 1:nb_chan        
        % Get rows corresponding to this channel
        rows_k = find(chan_idx == channels(k));        
        % Extract weights for this channel
        weights_k = w(rows_k);        
        % Define block columns
        cols = (k-1)*nCoil + (1:nCoil);        
        % Place weights in row k
        Wbig(k, cols) = weights_k(:)';   
    end

    coil_to_channel_transform = Wbig;
    % not sure about this
    h5create(io_file_path, "/measurement/sensors/magnetometers/coil_to_channel_transform", [nb_chan, nb_chan], Datatype="double");
    h5write(io_file_path, "/measurement/sensors/magnetometers/coil_to_channel_transform", coil_to_channel_transform);
end

function [iOk, errMsg] = bstdn_write_pem_electrodes(duneuro_io_dir, electrode_positions, electrode_type_flag)
    iOk = 0; errMsg = '';

    io_file_path = fullfile(duneuro_io_dir, 'duneuro_io.hdf5');
       
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
    
      h5create(io_file_path, "/measurement/source_space/positions", [dim nr_dipoles], Datatype="double");
      h5write(io_file_path, "/measurement/source_space/positions", dipole_positions');

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
      % runner_system_call = ['apptainer run --bind ' duneuro_io_dir ':/duneuro/external_mount docker://ghcr.io/maltehoel/duneuro_in_docker_testing:wip'];
      %runner_system_call = ['apptainer run --bind ' duneuro_io_dir ':/duneuro/external_mount duneuro_testing.sif'];
       
      %system('bash -lc "module load apptainer && which apptainer"')
        runner_system_call = ...
    ['bash -lc "module load apptainer && apptainer run --bind ' ...
     duneuro_io_dir ':/duneuro/external_mount duneuro_testing.sif"'];

% status = system(runner_system_call);

    else
      errMsg = 'unknown runner';
       return;
    end
    
    status = system(runner_system_call);
end