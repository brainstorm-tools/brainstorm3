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
        error('todo');
%         % === INTERPOLATE DTI TENSORS ===
%         % Load T1 MRI (for SCS coordinates)
%         sMri = in_mri_bst(MriFile);
%         % Load DTI-EIG volumes
%         sEigDti = in_mri_bst(DtiFile);
%         % Convert coordinates of element centroids to voxel coordinates
%         [C, Transf] = cs_convert(sMri, 'scs', 'voxel', ElemCenter);
%         
% %         %%%%%%% WRONG!!!!!!!! Index can't be guessed like this!!
% %         % Get the WM only   
% %         C = C(FemMat.Tissue == 1, :);  
% 
%         % Interpolate the eigen vectors
%         V1a = [interpn(sEigDti.Cube(:,:,:,1), C(:,1), C(:,2), C(:,3)), ...
%                interpn(sEigDti.Cube(:,:,:,2), C(:,1), C(:,2), C(:,3)), ...
%                interpn(sEigDti.Cube(:,:,:,3), C(:,1), C(:,2), C(:,3))];
%         V2a = [interpn(sEigDti.Cube(:,:,:,4), C(:,1), C(:,2), C(:,3)), ...
%                interpn(sEigDti.Cube(:,:,:,5), C(:,1), C(:,2), C(:,3)), ...
%                interpn(sEigDti.Cube(:,:,:,6), C(:,1), C(:,2), C(:,3))];
%         V3a = [interpn(sEigDti.Cube(:,:,:,7), C(:,1), C(:,2), C(:,3)), ...
%                interpn(sEigDti.Cube(:,:,:,8), C(:,1), C(:,2), C(:,3)), ...
%                interpn(sEigDti.Cube(:,:,:,9), C(:,1), C(:,2), C(:,3))];
%         L1a = interpn(sEigDti.Cube(:,:,:,10), C(:,1), C(:,2), C(:,3));
%         L2a = interpn(sEigDti.Cube(:,:,:,11), C(:,1), C(:,2), C(:,3));
%         L3a = interpn(sEigDti.Cube(:,:,:,12), C(:,1), C(:,2), C(:,3));
% 
%         % Anand's code
%         La = inv(Transf(1:3,1:3) / Transf(4,4));
%         % Rotate the eigen vectors
%         [V1rot,V2rot,V3rot] = PPD_linear(V1a,V2a,V3a,La);
%         
%         
%         % Call the main function : bst_compute_anisotropy_tensors
%         % METHOD 2 : 'ema': direct transformation approcah with volume constraint  [Güllmar et al NeuroImage 2010]
%         % METHOD 7 : 'ema+vc': As SimBio toolbox  [Rullmann et al 2008 / Vorwerk et al 2014 ]
%         options.AnisoMethod = OPTIONS.AnisoMethod;
%         options.iTissueAniso = iTissueAniso;
%         [tmp, options.iTissueRef] = max(OPTIONS.FemCond);
% 
%         [aniso_conductivity, Tensors, param] = ...
%             bst_compute_anisotropy_tensors(FemMat, OPTIONS.FemCond, Tensors, L1a,L2a,L3a,V1rot,V2rot,V3rot,options);

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

