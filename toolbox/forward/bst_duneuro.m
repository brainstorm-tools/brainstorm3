function [Gain, errMsg] = bst_duneuro(cfg)
% BST_DUNEURO: Call Duneuro to compute a FEM solution for Brainstorm.
%
% USAGE:  [Gain, errMsg] = bst_duneuro(cfg)

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
% Authors: Takfarinas Medani, Juan Garcia-Prieto, 2019-2020
%          Francois Tadel 2020

% Initialize returned values
Gain = [];
errMsg = '';
% Empty temp folder
gui_brainstorm('EmptyTempFolder');
% Install bst_duneuro if needed
[DuneuroExe, errMsg] = duneuro_install();
if ~isempty(errMsg) || isempty(DuneuroExe)
    return;
end
disp([10, 'DUNEURO> Installation path: ', DuneuroExe]);
% Get temp folder
TmpDir = bst_get('BrainstormTmpDir');
% Display message
bst_progress('text', 'DUNEuro: Writing temporary files...');
disp(['DUNEURO> Writing temporary files to: ' TmpDir]);


%% ===== SENSORS =====
% Select modality for DUNEuro
isEeg  = strcmpi(cfg.EEGMethod, 'duneuro')  && ~isempty(cfg.iEeg);
isMeg  = strcmpi(cfg.MEGMethod, 'duneuro')  && ~isempty(cfg.iMeg);
isEcog = strcmpi(cfg.ECOGMethod, 'duneuro') && ~isempty(cfg.iEcog);
isSeeg = strcmpi(cfg.SEEGMethod, 'duneuro') && ~isempty(cfg.iSeeg);
% Error: cannot combine modalities other than MEG+EEG
if (nnz([isEeg, isMeg, isEcog, isSeeg]) > 2) || ((nnz([isEeg, isMeg, isEcog, isSeeg]) == 2) && (isEcog || isSeeg))
    errMsg = 'DUNEuro cannot combine modalities other than MEG+EEG.';
    return;
end
% Get the modality
if isEeg && isMeg
    dnModality = 'meeg';
elseif isEeg
    dnModality = 'eeg';
elseif isMeg
    dnModality = 'meg';
elseif isEcog
    dnModality = 'ecog';
elseif isSeeg
    dnModality = 'seeg';
end
% Get EEG positions
if isEeg
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
end


%% ====== SOURCE SPACE =====
% Source space type
switch (cfg.HeadModelType)
    case 'volume'
        % TODO or keep it as it's now....
    case 'surface'
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
            cfg.GridLoc = sCortex.Vertices - depth;
        end
    case 'mixed'
        % TODO : not used ?
end


%% ===== HEAD MODEL =====
% Load FEM mesh
FemMat = load(cfg.FemFile);
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
        FemMat.Elements(iRemove,:) = [];
        FemMat.Tissue(iRemove,:) = [];
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
% Isotropic
if (cfg.Isotropic)
    % Isotropic without tensor
    if ~cfg.UseTensor
        if strcmp(ElementType,'hexahedron')
            MeshFile = 'head_model.dgf';
        else
            MeshFile = 'head_model.msh';
        end
    % Isotropic with tensor
    else    
        if strcmp(ElementType,'hexahedron')
            errMsg = 'Using the tensor model with hexahedral mesh is not supported for now.';
            return;
        end
        MeshFile = 'head_model.geo';
    end
% Anisotropic (with tensor)
else
    if strcmp(ElementType,'hexahedron')
        errMsg = 'Using the anisotropy model with hexahedral mesh is not supported for now.';
        return;
    end
    MeshFile = 'head_model.geo';
    cfg.UseTensor = true;
end
% Write mesh model
MeshFile = fullfile(TmpDir, MeshFile);
out_fem(FemMat, MeshFile);


%% ===== SOURCE MODEL =====
% Write the source/dipole file
DipoleFile = fullfile(TmpDir, 'dipole_model.txt');
% Unconstrained orientation for each dipole. ie the output file have 3*N dipoles (3 directions for each)
%     [x1,y1,z1, 1, 0, 0,;
%      x1,y1,z1, 0, 1, 0;
%      x1,y1,z1, 0, 0, 1;
%      x2,y2,z2, 1, 0, 0;
%      .... ];
dipoles = [kron(cfg.GridLoc, ones(3,1)), kron(ones(size(cfg.GridLoc,1), 1), eye(3))];
fid = fopen(DipoleFile, 'wt+');
fprintf(fid, '%d %d %d %d %d %d \n', dipoles');
fclose(fid);


%% ===== SENSOR MODEL =====
% Write the EEG electrode file
ElecFile = 'electrode_model.txt';
if isEeg
    fid = fopen(fullfile(TmpDir, ElecFile), 'wt+');
    fprintf(fid, '%d %d %d  \n', EegLoc);
    fclose(fid); 
end
% Write the MEG sensors file
CoilFile = fullfile(TmpDir, 'coil_model.txt');
ProjFile = fullfile(TmpDir, 'projection_model.txt');
if isMeg
    % Write coil file
    CoilsLoc = MegChannels(:,2:4);
    fid = fopen(CoilFile, 'wt+');
    fprintf(fid, '%d %d %d  \n', CoilsLoc');
    fclose(fid);
    % Write projection file
    CoilsOrient = MegChannels(:,5:7);
    fid = fopen(ProjFile, 'wt+');
    fprintf(fid, '%d %d %d  \n', CoilsOrient');
    fclose(fid);
end


%% ===== CONDUCTIVITY MODEL =====
% Isotropic without tensor
if ~cfg.UseTensor
    CondFile = fullfile(TmpDir, 'conductivity_model.con');
    fid = fopen(CondFile, 'w');
    fprintf(fid, '%d\t', cfg.FemCond);
    fclose(fid);
% With tensor (isotropic or anisotropic)
else
    CondFile = fullfile(TmpDir, 'conductivity_model.knw');
    out_fem_knw(cfg.elem, cfg.CondTensor, CondFile);
end


%% ===== WRITE MINI FILE =====
% Open the mini file
IniFile = fullfile(TmpDir, 'duneuro_minifile.mini');
fid = fopen(IniFile, 'wt+');
% General setting
fprintf(fid, '__name = %s\n\n', IniFile);
if strcmp(cfg.SolverType, 'cg')
    fprintf(fid, 'type = %s\n', cfg.FemType);
end
fprintf(fid, 'element_type = %s\n', ElementType);
fprintf(fid, 'solver_type = %s\n', cfg.SolverType);
fprintf(fid, 'geometry_adapted = %s\n', bool2str(cfg.GeometryAdapted));
fprintf(fid, 'tolerance = %d\n', cfg.Tolerance);
% [electrodes]
if strcmp(dnModality, 'eeg') || strcmp(dnModality, 'meeg')
    fprintf(fid, '[electrodes]\n');
    fprintf(fid, 'filename = %s\n', fullfile(TmpDir, ElecFile));
    fprintf(fid, 'type = %s\n', cfg.ElecType);
end
% [meg]
if strcmp(dnModality, 'meg') || strcmp(dnModality, 'meeg')
    fprintf(fid, '[meg]\n');
    fprintf(fid, 'intorderadd = %d\n', cfg.MegIntorderadd);
    fprintf(fid, 'type = %s\n', cfg.MegType);
    % [coils]
    fprintf(fid, '[coils]\n');
    fprintf(fid, 'filename = %s\n', CoilFile);
    % [projections]
    fprintf(fid, '[projections]\n');
    fprintf(fid, 'filename = %s\n', ProjFile);
end
% [dipoles]
fprintf(fid, '[dipoles]\n');
fprintf(fid, 'filename = %s\n', DipoleFile);
% [volume_conductor.grid]
fprintf(fid, '[volume_conductor.grid]\n');
fprintf(fid, 'filename = %s\n', MeshFile);
% [volume_conductor.tensors]
fprintf(fid, '[volume_conductor.tensors]\n');
fprintf(fid, 'filename = %s\n', CondFile);
% [solver]
fprintf(fid, '[solver]\n');
fprintf(fid, 'solver_type = %s\n', cfg.SolvSolverType);
fprintf(fid, 'preconditioner_type = %s\n', cfg.SolvPrecond);
if strcmp(cfg.SolverType, 'cg')
    fprintf(fid, 'cg_smoother_type = %s\n', cfg.SolvSmootherType);
end
fprintf(fid, 'intorderadd = %d\n', cfg.SolvIntorderadd);
% Discontinuous Galerkin
if strcmp(cfg.SolverType, 'dg')
    fprintf(fid, 'dg_smoother_type = %s\n', cfg.DgSmootherType);
    fprintf(fid, 'scheme = %s\n', cfg.DgScheme);
    fprintf(fid, 'penalty = %d\n', cfg.DgPenalty);
    fprintf(fid, 'edge_norm_type = %s\n', cfg.DgEdgeNormType);
    fprintf(fid, 'weights = %s\n', bool2str(cfg.DgWeights));
    fprintf(fid, 'reduction = %s\n', bool2str(cfg.DgReduction));
end
% [solution]
fprintf(fid, '[solution]\n');
fprintf(fid, 'post_process = %s\n', bool2str(cfg.SolPostProcess)); % true/false
fprintf(fid, 'subtract_mean = %s\n', bool2str(cfg.SolSubstractMean)); % boolean
% [solution.solver]
fprintf(fid, '[solution.solver]\n');
fprintf(fid, 'reduction = %d\n', cfg.SolSolverReduction);
% [solution.source_model]
fprintf(fid, '[solution.source_model]\n');
fprintf(fid, 'type = %s\n', cfg.SrcModel);
fprintf(fid, 'intorderadd = %d\n', cfg.SrcIntorderadd);
fprintf(fid, 'intorderadd_lb = %d\n', cfg.SrcIntorderadd_lb);
fprintf(fid, 'numberOfMoments = %d\n', cfg.SrcNbMoments);
fprintf(fid, 'referenceLength = %d\n', cfg.SrcRefLen);
fprintf(fid, 'weightingExponent = %d\n', cfg.SrcWeightExp);
fprintf(fid, 'relaxationFactor = %e\n', 10^(-cfg.SrcRelaxFactor));
fprintf(fid, 'mixedMoments = %s\n', bool2str(cfg.SrcMixedMoments));
fprintf(fid, 'restrict = %s\n', bool2str(cfg.SrcRestrict));
fprintf(fid, 'initialization = %s\n', cfg.SrcInit);
% [brainstorm]
fprintf(fid, '[brainstorm]\n');
fprintf(fid, 'modality = %s\n', dnModality);
fprintf(fid, 'output_folder = %s\n', [TmpDir, filesep]);
fprintf(fid, 'save_eeg_transfer_file = %s\n', bool2str(cfg.BstSaveTransfer));
fprintf(fid, 'save_meg_transfer_file = %s\n', bool2str(cfg.BstSaveTransfer));
fprintf(fid, 'save_meeg_transfer_file = %s\n', bool2str(cfg.BstSaveTransfer));
fprintf(fid, 'eeg_transfer_filename = %s\n', cfg.BstEegTransferFile);
fprintf(fid, 'meg_transfer_filename = %s\n', cfg.BstMegTransferFile);
fprintf(fid, 'eeg_leadfield_filename = %s\n', cfg.BstEegLfFile);
fprintf(fid, 'meg_leadfield_filename = %s\n', cfg.BstMegLfFile);
% Close file
fclose(fid);


%% ===== RUN DUNEURO ======
% Assemble command line
callStr = ['"' DuneuroExe '"' ' ' '"' IniFile '"'];
bst_progress('text', 'DUNEuro: Computing leadfield...');
disp(['DUNEURO> System call: ' callStr]);
tic;
% Call DUNEuro
[status,cmdout] = system(callStr);
if (status ~= 0)
    disp('DUNEURO> Error log:');
    disp(cmdout);
    errMsg = 'Error during the DUNEuro computation, see logs in the command window.';
    return;
end
disp(['DUNEURO> FEM computation completed in: ' num2str(toc) 's']);


%% ===== READ LEADFIELD ======
bst_progress('text', 'DUNEuro: Reading leadfield...');
% EEG
if isEeg
    GainEeg = in_duneuro_bin(fullfile(TmpDir, cfg.BstEegLfFile))';
end
% MEG
if isMeg
    GainMeg = in_duneuro_bin(fullfile(TmpDir, cfg.BstMegLfFile))';
    
    % === POST-PROCESS MEG LEADFIELD ===
    % Compute the total magnetic field 
    dipoles_pos_orie = [kron(cfg.GridLoc,ones(3,1)), kron(ones(length(cfg.GridLoc),1), eye(3))];

    % a- Compute the MEG Primary Magnetic B-field analytically (formula of Sarvas)
    dip_pos = dipoles_pos_orie(:,1:3);
    dip_mom = dipoles_pos_orie(:,4:6);
    Bp = zeros(size(MegChannels,1), size(dip_pos,1));
    for i = 1:size(CoilsLoc,1)
        for j = 1 : size(dip_pos,1)
            R = CoilsLoc(i,:);
            R_0 = dip_pos(j,:);
            A = R - R_0;
            a = norm(A);
            aa = A./(a^3);
            BpHelp = cross(dip_mom(j,:),aa);
            Bp(i,j) = BpHelp * CoilsOrient(i, :)'; % projection of the primary B-field along the coil orientations
        end
    end

    % b- The total magnetic field B = Bp + Bs;
    %  full B-field
    Bs = GainMeg;
    mu = 4*pi*1e-4; % check the value of the units maybe it needs to be mu = 4*pi*1e-7
    Bfull = (mu/(4*pi)) * (Bp - Bs);

    % c- Apply the weight :
    [channelIndex] = unique(MegChannels(:,1));
    nbChannel = length(channelIndex);
    weighted_B = zeros(nbChannel,size(Bfull,2));
    for iCh = 1 : nbChannel
        communChannel = find(iCh==MegChannels);
        BcommunChannel = Bfull(communChannel(:),:);
        WcommunChannel =  MegChannels(communChannel(:), 8: end);
        weighted_B(iCh,:) = sum (BcommunChannel.*WcommunChannel,1);
    end    
    GainMeg = weighted_B;
end

% Fill the unused channels with NaN
Gain = NaN * zeros(length(cfg.Channel), 3 * length(cfg.GridLoc));
if isMeg
    Gain(cfg.iMeg,:) = GainMeg; 
end 
if isEeg
    Gain(cfg.iEeg,:) = GainEeg; 
end


%% ===== SAVE TRANSFER MATRIX ======
disp('DUNEURO> TODO: Save transferOut.dat to database.')



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


