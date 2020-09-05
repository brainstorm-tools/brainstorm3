function varargout = process_fem_tensors(varargin)
% PROCESS_FEM_TENSORS: Compute conductivity tensors from DTI.

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
% Authors: Francois Tadel, Takfarinas Medani, Anand Joshi, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Compute FEM tensors';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 24;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Get default FEM conductivities from DUNEuro options
    dndef = bst_get('DuneuroOptions');
    defFem.FemCond = dndef.FemCond;
    % Options: FEM conductivities
    sProcess.options.femcond.Comment = {'panel_femcond', 'Tissue conductivities: '};
    sProcess.options.femcond.Type    = 'editpref';
    sProcess.options.femcond.Value   = defFem;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get conductivities
    OPTIONS = sProcess.options.femcond.Value;
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
    [isOk, errMsg] = Compute(iSubject, [], [], 0, OPTIONS);
    % Handling errors
    if ~isOk
        bst_report('Error', sProcess, [], errMsg);
    elseif ~isempty(errMsg)
        bst_report('Warning', sProcess, [], errMsg);
    end
    % Return an empty structure
    OutputFiles = {'import'};
end


%% ===== COMPUTE FEM TENSORS =====
function [isOk, errMsg] = Compute(iSubject, DtiFile, FemFile, isInteractive, OPTIONS)
    isOk = 0;
    errMsg = '';
            
    % ===== GET INPUT FILES =====
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
    % Get the T1 MRI (for SCS coordinates)
    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    % Get DTI-EIG file
    if isempty(DtiFile) && ~all(OPTIONS.isIsotropic) && ~strcmpi(OPTIONS.AnisoMethod, 'simulated')
        iAnatDti = find(strcmpi({sSubject.Anatomy.Comment}, 'DTI-EIG'), 1);
        if isempty(iAnatDti)
            iAnatDti = find(~cellfun(@(c)isempty(strfind(upper(c), 'DTI-EIG')), {sSubject.Anatomy.Comment}), 1);
            % Interactive mode: Ask to load DWI+convert to DTI
            if isempty(iAnatDti) && isInteractive
                isConfirm = java_dialog('confirm', [...
                    'Computing the conductivity tensors for this head model requires the ' 10 ...
                    'diffusion tensors (DTI-EIG) to be available in the subject anatomy folder.' 10 10 ...
                    'Import DWI images and compute DTI-EIG now (process "Convert DWI to DTI")?'], 'Missing DTI-EIG');
                if isConfirm
                    DtiFile = process_dwi2dti('ComputeInteractive', iSubject);
                end
            end
            % File still not available: error
            if isempty(DtiFile) && isempty(iAnatDti)
                errMsg = 'DTI-EIG file not available.';
                return;
            end
        end
        if isempty(DtiFile)
            DtiFile = file_fullpath(sSubject.Anatomy(iAnatDti).FileName);
        end
    end
    % Get tissue segmentation
    if isempty(FemFile)
        if isempty(sSubject.iFEM)
            errMsg = 'No available FEM mesh file for this subject.';
            return;
        end
        FemFile = file_fullpath(sSubject.Surface(sSubject.iFEM).FileName);
    end
    % Get anisotropic tissues
    if any(~OPTIONS.isIsotropic)
        iTissueAniso = find(~OPTIONS.isIsotropic);
    else
        OPTIONS.AnisoMethod = 'none';
    end
    
    % ===== COMPUTE ISOTROPIC TENSORS ======
    % Load the mesh
    bst_progress('text', 'Loading FEM mesh...');
    FemMat = load(FemFile);
    % Compute centroids of each element
    bst_progress('text', 'Computing elements centroids...');
    nElem = size(FemMat.Elements, 1);
    nMesh = size(FemMat.Elements, 2);
    ElemCenter = zeros(nElem, 3);
    for i = 1:3
        ElemCenter(:,i) = sum(reshape(FemMat.Vertices(FemMat.Elements,i), nElem, nMesh)')' / nMesh;
    end
    % Generate triedre on each point (normalized vectors)
    vElemCenter = bst_bsxfun(@minus, ElemCenter, mean(FemMat.Vertices));
    vElemCenter = vElemCenter ./ sqrt(sum(vElemCenter.^2, 2));
%     % Compute the tangential vectors
%     vector_t1 = zeros(nNodes,3);
%     vector_t2 = zeros(nNodes,3);
%     for iNode = 1:nElem
%         r = null(vElemCenter(iNode,:));
%         vector_t1(iNode,:) = r(:,1)';
%         vector_t2(iNode,:) = r(:,2)';
%     end
%     
%     % Generate the local tensor according to the golobal coordinates X,Y,Z
%     A = bst_bsxfun(@times, repmat(eye(3,3), [1,1,nTissues]), reshape(OPTIONS.FemCond,1,1,nTissues));
%     % Transformation matrix and tensor mapping on each direction
%     for iElem = 1:length(FemMat.Tissue)
%         cfg.eigen.eigen_vector{iElem} = [vElemCenter(iElem,:)', vector_t1(iElem,:)', vector_t2(iElem,:)'];
%         cfg.eigen.eigen_value{iElem} = A(:,:,FemMat.Tissue(iElem));    
%     end
%     Tensors = cfg.eigen;

    % Compute the tangential vectors
    bst_progress('text', 'Computing tengential vectors... 0%%');
    r = zeros(nElem,6);
    p = 0;
    for iElem = 1:nElem
        r(iElem,:) = reshape(null(vElemCenter(iElem,:)), 1, 6);
        % Increment waitbar
        if (round(100 * iElem / nElem) > p)
            p = round(100 * iElem / nElem);
            bst_progress('text', sprintf('Computing tengential vectors... %d%%', p));
        end
    end
    % Tensors matrix: [nNodes x 12] => [V1(1:3) V2(1:3) V3(1:3) L1 L2 L3]
    Tensors = [vElemCenter, r, repmat(reshape(OPTIONS.FemCond(FemMat.Tissue),nElem,1),1,3)];

    % ===== SIMULATE CONDUCTIVITY TENSORS =====
    if strcmpi(OPTIONS.AnisoMethod, 'simulated')
        bst_progress('text', 'Simulated eigen values...');
        % Compute the new eigen values
        switch (OPTIONS.SimConstrMethod)
            case 'wang'
                lm1 = (OPTIONS.FemCond.^2 .* OPTIONS.SimRatio) .^ (1/2); % sigma longitidunal
                lm2 = (OPTIONS.FemCond.^2 ./ OPTIONS.SimRatio) .^ (1/2); % sigma transversal
                lm3 = lm2;
            case 'wolters'   % Volume is preserved
                lm1 = (OPTIONS.FemCond.^3 .* OPTIONS.SimRatio.^2) .^ (1/3); % sigma longitidunal
                lm2 = (OPTIONS.FemCond.^3 ./ OPTIONS.SimRatio) .^ (1/3);    % sigma transversal
                lm3 = lm2;
        end
        % Replace eigen values in final tensor matrix
        for iTissue = iTissueAniso
            isElem = (FemMat.Tissue == iTissue);
            Tensors(isElem,10:12) = repmat([lm1(iTissue), lm2(iTissue), lm3(iTissue)], nnz(isElem), 1);
        end

    % ===== COMPUTE DTI CONDUCTIVITY TENSORS =====
    % Convert the DTI-EIG tensors from voxel to scs + interpolate on centroids of mesh elements
    elseif ismember(OPTIONS.AnisoMethod, {'ema', 'ema+vc'})
        % === LOAD DTI TENSORS ===
        bst_progress('text', 'Loading volumes: T1 and DTI-EIG...');
        % Load T1 MRI (for SCS coordinates)
        sMri = in_mri_bst(MriFile);
        % Load DTI-EIG volumes
        sDti = in_mri_bst(DtiFile);
        
        % === INTERPOLATE DTI TENSORS ===
        bst_progress('text', 'Interpolating DTI tensors...');
        % Get indices of anisotropic elements
        iElemAniso = find(ismember(FemMat.Tissue, iTissueAniso));
        % Convert coordinates of element centroids to voxel coordinates
        [C, Transf] = cs_convert(sMri, 'scs', 'voxel', ElemCenter(iElemAniso,:));
        % Interpolate all the DTI values on the centroids of the FEM elements
        % V1,V2,V3: Eigen vectors, L1,L2,L3: Eigen values
        V1a = [interpn(sDti.Cube(:,:,:,1), C(:,1), C(:,2), C(:,3)), ...
               interpn(sDti.Cube(:,:,:,2), C(:,1), C(:,2), C(:,3)), ...
               interpn(sDti.Cube(:,:,:,3), C(:,1), C(:,2), C(:,3))];
        V2a = [interpn(sDti.Cube(:,:,:,4), C(:,1), C(:,2), C(:,3)), ...
               interpn(sDti.Cube(:,:,:,5), C(:,1), C(:,2), C(:,3)), ...
               interpn(sDti.Cube(:,:,:,6), C(:,1), C(:,2), C(:,3))];
        V3a = [interpn(sDti.Cube(:,:,:,7), C(:,1), C(:,2), C(:,3)), ...
               interpn(sDti.Cube(:,:,:,8), C(:,1), C(:,2), C(:,3)), ...
               interpn(sDti.Cube(:,:,:,9), C(:,1), C(:,2), C(:,3))];
        L1a = interpn(sDti.Cube(:,:,:,10), C(:,1), C(:,2), C(:,3));
        L2a = interpn(sDti.Cube(:,:,:,11), C(:,1), C(:,2), C(:,3));
        L3a = interpn(sDti.Cube(:,:,:,12), C(:,1), C(:,2), C(:,3));
        % Ensure that all the eigen values are positives
        L1a = abs(L1a); 
        L2a = abs(L2a); 
        L3a = abs(L3a);
        
        % === DETECT INVALID EIGENVALUES ===
        % Ensure maximal ratio of 10 between the largest and smallest conductivity eigenvalues
        maxRatio = 10;
        L = [L1a, L2a, L3a];
        [minL, iMinL] = min(L, [], 2);
        [maxL, iMaxL] = max(L, [], 2);
        iElemFix = find((maxL > 0) & (maxL ./ minL >= maxRatio));
        if ~isempty(iElemFix)
            disp(['BST> Warning: ' num2str(length(iElemFix)) ' element(s) have max/min eigenvalue ratios > ' num2str(maxRatio) '.']);
            for iElem = iElemFix
                L(iElem,iMinL(iElem)) = L(iElem,iMaxL(iElem)) ./ maxRatio;
            end
            L1a = L(:,1);
            L2a = L(:,2);
            L3a = L(:,3);
        end
        % Replace zero L2 and L3
        L2a(L2a == 0) = L1a(L2a == 0) ./ maxRatio;
        L3a(L3a == 0) = L2a(L3a == 0);
        % Detect invalid: All eigenvalues are zero, or L1<L2 or L1<L3 (cases where BDP fails or is not part of the wm mask)
        iElemInvalid = find((maxL == 0) | (L1a < L2a) | (L1a < L3a));
        % Remove all elements with invalid eigenvalues: we'll keep the isotropic tensors
        V1a(iElemInvalid,:) = [];
        V2a(iElemInvalid,:) = [];
        V3a(iElemInvalid,:) = [];
        L1a(iElemInvalid) = [];
        L2a(iElemInvalid) = [];
        L3a(iElemInvalid) = [];
        iElemAniso(iElemInvalid) = [];
        
        
        % === COMPUTE CONDUCTIVITY TENSORS ===
        bst_progress('text', ['Computing conductivity tensors (' OPTIONS.AnisoMethod ')...']);
        % Anand's code
        La = inv(Transf(1:3,1:3) / Transf(4,4));
        % Rotate the eigen vectors
        [V1rot,V2rot,V3rot] = PPD_linear_local(V1a,V2a,V3a,La);
        % Isotropic conductivity for all the elements
        tissueCond = reshape(OPTIONS.FemCond(FemMat.Tissue(iElemAniso)), [], 1);

        % Switch different methods
        switch (OPTIONS.AnisoMethod)
            % METHOD 2 : direct transformation approcah with volume constraint  [Güllmar et al NeuroImage 2010]
            case 'ema'
                % Apply the volume approach
                % Tuch parameters
                k = 0.844;  % +/- 0.0545
                de = 0.124;
                lm1 = k .* (L1a - de);
                lm2 = k .* (L2a - de);
                lm3 = k .* (L3a - de);
                % Apply the normalized volume
                lm1n = tissueCond .* lm1 ./ (lm1.*lm2.*lm3).^(1/3);
                lm2n = tissueCond .* lm2 ./ (lm1.*lm2.*lm3).^(1/3);
                lm3n = tissueCond .* lm3 ./ (lm1.*lm2.*lm3).^(1/3);

            % METHOD 7 : As SimBio toolbox  [Rullmann et al 2008 / Vorwerk et al 2014 ]
            case 'ema+vc'
                % 1 - Apply the Tuch process Sigm = sD
                % Compute sacling factor
                meanDiffusity = (sum(L1a .* L2a .* L3a) ./ length(iElemAniso)) .^ (1/3);
                scalingFactor = tissueCond ./ meanDiffusity;
                disp(['BST> EMA+VC: meanDiffusity = ', num2str(meanDiffusity)]);
                % Scale eigen values
                lm1 = scalingFactor .* L1a;
                lm2 = scalingFactor .* L2a;
                lm3 = scalingFactor .* L3a;
                % Apply the normalized volume
                lm1n = tissueCond .* lm1 ./ (lm1.*lm2.*lm3).^(1/3);
                lm2n = tissueCond .* lm2 ./ (lm1.*lm2.*lm3).^(1/3);
                lm3n = tissueCond .* lm3 ./ (lm1.*lm2.*lm3).^(1/3);
                % Max value of the conductivity should not be larger than the reference value (eg. CSF) 
                lm1n = min(lm1n, max(OPTIONS.FemCond));
                lm2n = min(lm2n, max(OPTIONS.FemCond));
                lm3n = min(lm3n, max(OPTIONS.FemCond));
        end
        % Set the anisotropic conductivity tensors
        Tensors(iElemAniso, 1:12) = [V1rot, V2rot, V3rot, lm1n, lm2n, lm3n];
                
        % Scale the isotropic WM(others) tensors within the anisotropic tissue 
        % by the mean of the computed value from the Wolter approach
        meanCond = mean(Tensors(iElemAniso, 10:12), 2);
        meanMeanCond = mean(meanCond);
        stdMeanCond = std(meanCond);
        Tensors(iElemInvalid, 10:12) = repmat(meanMeanCond, length(iElemInvalid), 3);
        % Display some statistics in the command window
        disp(['BST> Anistropic conductivity (mean) = ' num2str(meanMeanCond)]);
        disp(['BST> Anistropic conductivity (std)  = ' num2str(stdMeanCond)]);
    end

    % ===== SAVE TENSORS =====
    bst_progress('text', 'Saving tensors...');
    % Add history entry
    FemMat = bst_history('add', FemMat, 'process_fem_tensors', OPTIONS);
    % Save tensors to the FemFile
    FemMat.Tensors = Tensors;
    bst_save(FemFile, FemMat, 'v7');
    % Return success
    isOk = 1;
end



%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(iSubject, FemFile) %#ok<DEFNU>
    % Ask conductivities with panel_femcond
    OPTIONS.FemFile = FemFile;
    TensorOptions = gui_show_dialog('FEM conducitivities', @panel_femcond, 1, [], OPTIONS);
    if isempty(TensorOptions)
        return;
    end
    TensorOptions.FemFile = FemFile;
    % Open progress bar
    bst_progress('start', 'FEM tensors', 'Computing conductivity tensors...');
    % Compute conductivity tensors
    try
        [isOk, errMsg] = Compute(iSubject, [], FemFile, 1, TensorOptions);
        % Error handling
        if ~isOk
            bst_error(errMsg, 'FEM tensors', 0);
        elseif ~isempty(errMsg)
            java_dialog('msgbox', ['Warning: ' errMsg]);
        end
    catch
        bst_error();
        bst_error(['The FEM tensors computation failed.' 10 'Check the Matlab command window for additional information.' 10], 'FEM tensors', 0);
    end
    % Close progress bar
    bst_progress('stop');
end



%% =================================================================================
%  === HELPER FUNCTIONS ============================================================
%  =================================================================================

%% ===== SVRREG: PPD_LINEAR =====
% SVReg: Surface-Constrained Volumetric Registration
% Created by Anand A. Joshi, Chitresh Bhushan, David W. Shattuck, Richard M. Leahy
%
% PPD Rotates the eigenvectors of the diffusion matrix with Preservation of
% Principle component(PPD) algorithm & generates new eigenvectors.
%
% INPUTS:
%    - V1 : Principal eigenvector (corresponding to eigenvalue L1)
%    - V2 : Second eigenvector (corresponding to eigenvalue L2)
%    - V3 : Third eigenvector (corresponding to eigenvalue L3) such that L1>L2>L3
%
% OUTPUTS:
%    - W1 : Rotated principal eigenvector
%    - W2 : Rotated second eigenvector
%    - W3 : Rotated third eigenvector
function [W1, W2, W3] = PPD_linear_local(V1, V2, V3, L)
    % Convert to double for higher precision
    V1 = double(V1);
    V2 = double(V2);
    V3 = double(V3);
    % Normalizing V1, V2, V3
    V1 = norm_vector(V1);
    V2 = norm_vector(V2);
    V3 = norm_vector(V3);
    % Applying Jacobian to V1
    n1 = (L*V1')';
    n1 = norm_vector(n1);
    % Applying Jacobian to V2
    n2 = (L*V2')';
    n2 = norm_vector(n2);

    cosTheta1 = sum(V1.*n1, 2);
    axis1 = cross(V1', n1')';

    % Projection of n2 perpendicular to n1
    temp = zeros(size(n1));
    n1_dot_n2 = sum(n1.*n2, 2);
    temp(:,1) = n1(:,1).*n1_dot_n2;
    temp(:,2) = n1(:,2).*n1_dot_n2;
    temp(:,3) = n1(:,3).*n1_dot_n2;
    proj_n2 = n2 - temp;
    proj_n2 = norm_vector(proj_n2);

    V2rot = rot_vector(V2, axis1, cosTheta1);
    V3rot = rot_vector(V3, axis1, cosTheta1);

    cosTheta2 = sum(V2rot.*proj_n2, 2);
    axis2 = cross(V2rot, proj_n2);
    % Outputs
    W1 = n1;
    W2 = rot_vector(V2rot, axis2, cosTheta2);
    W3 = rot_vector(V3rot, axis2, cosTheta2);
end


%% ===== SVRREG: NORM_VECTOR =====
% Returns normalized vectors
function v_out = norm_vector(v)
    v_norm = sqrt(sum(v.^2, 2));
    v_out = v ./ v_norm;
    v_out(isnan(v_out)) = 0;
end

%% ===== SVRREG: NORM_VECTOR =====
% Rotates vector v about axis by angle theta. Function takes cosine of
% theta as argument. axis may not be a unit vector. Here vectors are stored
% in 4th dimesion of matrix a & b (usually the eigenvectors).
% Uses Rodrigues' rotation formula.
function v_rot = rot_vector(v, axis, cosTheta)
    axis = norm_vector(axis);

    term1 = zeros(size(v));
    term1(:,1) = v(:,1).*cosTheta;
    term1(:,2) = v(:,2).*cosTheta;
    term1(:,3) = v(:,3).*cosTheta;

    term2 = zeros(size(v));
    sinTheta = sqrt(1 - (cosTheta.^2));
    temp = cross(axis, v);
    term2(:,1) = temp(:,1).*sinTheta;
    term2(:,2) = temp(:,2).*sinTheta;
    term2(:,3) = temp(:,3).*sinTheta;

    term3 = zeros(size(v));
    temp = sum(axis.*v, 2).*(1-cosTheta);
    term3(:,1) = axis(:,1).*temp;
    term3(:,2) = axis(:,2).*temp;
    term3(:,3) = axis(:,3).*temp;

    v_rot = term1 + term2 + term3;
end


