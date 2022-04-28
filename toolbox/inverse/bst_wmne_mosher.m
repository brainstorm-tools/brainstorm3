function [Results, OPTIONS, HeadModel] = bst_wmne_mosher(HeadModel,OPTIONS)
% BST_WMNE: Compute the whitened and weighted minimum-norm operator (wMNE imaging kernel)
%
% USAGE:  [Results,OPTIONS] = bst_wmne(HeadModel, OPTIONS) : Compute mininum operator
%                   OPTIONS = bst_wmne()                   : Return default options
%
% DESCRIPTION:
%     This program computes the whitened and weighted minimum-norm operator,
%     (the wMNE imaging kernel), which is used to compute whitened 
%     and weighted minimum-norm estimates (MNE).
%         (e.g., J=wMNEoperator*B; where B is the unwhitened data).
%     It can also compute the whitened and noise-normalized dynamic 
%     statistical parametric mapping (dSPM) inverse operator, and/or the 
%     whitened standardized low resolution brain electromagnetic tomography 
%     (sLORETA) inverse operator, which are used to compute whitened source
%     activity dSPM and sLORETA maps.
%         (e.g., S_dSPM=dSPMoperator*B; where B is the unwhitened data).
%         (e.g., S_sLORETA=sLORETAoperator*B; where B is the unwhitened data).
%
%     The function was written with the goal of providing some of the same
%     functionality of the MNE software written by Matti Hamalainen, but no
%     guarantees are made that it performs all computations in the same
%     exact way. It also provides some functionalities not available in the
%     MNE software.
% 
% INPUTS:
%    - HeadModel: Array of Brainstorm head model structures
%         |- Gain       : Forward field matrix for all the channels (unconstrained source orientations)
%         |- GridOrient : Dipole orientation matrix
%         |- area       : Vector with the areas (or possibly volumes) associated with the vertices of the source space.
%    - OPTIONS: structure    
%         |- NoiseCov      : NoiseCov is the noise covariance matrix. 
%         |- ChannelTypes  : Type of each channel (for each row of the Leadfield and the NoiseCov matrix)
%         |- InverseMethod : {'wmne', 'dspm', 'sloreta'}
%         |- SourceOrient  : String or a cell array of strings specifying the type of orientation constraints for each HeadModel (default: 'fixed')
%         |- SNR        : Signal-to noise ratio defined as in MNE (default: 3). 
%         |- diagnoise  : Flag to discard off-diagonal elements of NoiseCov (assuming heteroscedastic uncorrelated noise) (default: 0)
%         |- loose      : Value that weights the source variances of the dipole components defining the tangent space of the cortical surfaces (default: []).
%         |- depth      : Flag to do depth weighting (default: 1).
%         |- weightexp  : Order of the depth weighting. {0=no, 1=full normalization, default=0.8}
%         |- weightlimit: Maximal amount depth weighting (default: 10).
%         |- magreg     : Amount of regularization of the magnetometer noise covariance matrix
%         |- gradreg    : Amount of regularization of the gradiometer noise covariance matrix.
%         |- eegreg     : Amount of regularization of the EEG noise covariance matrix.
%         |- ecogreg    : Amount of regularization of the ECOG noise covariance matrix.
%         |- seegreg    : Amount of regularization of the SEEG noise covariance matrix.
%         |- fMRI       : Vector of fMRI values are the source points.
%         |- fMRIthresh : fMRI threshold. The source variances of source points with OPTIONS.fMRI smaller 
%         |               than fMRIthresh will be multiplied by OPTIONS.fMRIoff.
%         |- fMRIoff    : Weight assigned to non-active source points according to fMRI and fMRIthresh.
%
% OUTPUTS:
%    - Results : structure with the wMNE inverse operator and possibly the dSPM
%                and/or sLORETA inverse operators, and other information:

% NOTES:
%     - More leadfield matrices can be used: the solution will combine all
%       leadfield matrices appropriately.
%
%     - This leadfield structure allows to combine surface and volume
%       source spaces with and without dipole orientation constraints,and
%       with and without area or volumetric current density computations.
%       If using a single sphere headmodel, the silent radial
%       component could be eliminated using the SVD (e.g., use
%       bst_remove_silent.m).
%
%     - NoisCov: This should be computed from the pre-stimulus period for 
%       averaged ERF data (e.g., using MNE), or from an empty room recording 
%       for unaveraged spontaneous or induced data.
%
%     - Orientation constrains for dipoles (.SourceOrient field)
%         - "fixed"     : Dipoles constrained to point normal to cortical surfaces
%         - "free"      : No constraints, dipoles point in x,y,z directions
%         - "loose"     : Source variances of dipole components pointing tangentially to the cortical surfaces are multipled by OPTIONS.loose
%         - "truncated" : An SVD of the gain matrix for each source point is 
%                         used to remove the dipole component with least variance, which for
%                         the Single Sphere Head Model, corresponds to the radialsilent component).
%       => For dealing with multiple source spaces with different types of orientation constraints use for example, 
%          OPTION.SourceOrient{1}='fixed';
%          OPTION.SourceOrient{2}='free';
%          This has to correspond with the HeadModel Structure 
%
%     - The output HeadModel param is used here in return to save LOTS of memory in the bst_wmne function,
%       event if it seems to be absolutely useless. Having a parameter in both input and output have the
%       effect in Matlab of passing them "by referece". So please, do NOT remove it from the function description
%
%     - sLORETA: Output values are multiplied by 1e12 for display in Brainstorm (time series and cortical maps).

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
% Copyright (C) 2010 - Rey Rene Ramirez
%
% Authors:  Rey Rene Ramirez, Ph.D.   e-mail: rrramirez at mcw.edu
%           Francois Tadel, 2010-2013
%           John Mosher, 2013


%% ===== DEFINE DEFAULT OPTIONS =====
Def_OPTIONS.NoiseCov    = [];
Def_OPTIONS.InverseMethod = 'wmne';
Def_OPTIONS.SNR         = 3;
Def_OPTIONS.diagnoise   = 0;
%Def_OPTIONS.SourceOrient= {'free'};
Def_OPTIONS.SourceOrient= {'fixed'};
Def_OPTIONS.loose       = 0.2;
Def_OPTIONS.depth       = 1;
Def_OPTIONS.weightexp   = 0.5;
Def_OPTIONS.weightlimit = 10;
Def_OPTIONS.regnoise    = 1;
Def_OPTIONS.magreg      = .1;
Def_OPTIONS.gradreg     = .1;
Def_OPTIONS.eegreg      = .1;
Def_OPTIONS.ecogreg     = .1;
Def_OPTIONS.seegreg     = .1;
Def_OPTIONS.fMRI        = [];
Def_OPTIONS.fMRIthresh  = [];
Def_OPTIONS.fMRIoff     = 0.1;
Def_OPTIONS.pca         = 1;
% Return the default options
if (nargin == 0)
    Results = Def_OPTIONS;
    return
end
% Make the default for all the leadfields
numL = size(HeadModel,2);
Def_OPTIONS.SourceOrient = repmat(Def_OPTIONS.SourceOrient, [1 numL]);
% Copy default options to OPTIONS structure (do not replace defined values)
OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);


%% ===== CHECK FOR INVALID VALUES =====
disp(' ');
% Detect if the input noise covariance matrix is or should be diagonal
C_noise = OPTIONS.NoiseCov;
variances = diag(C_noise);
if isequal(C_noise, diag(variances))
    OPTIONS.diagnoise = 1;
    disp('wMNE> Detected diagonal noise covariance: setting diagnoise to 1');
end
% If OPTIONS.diagnoise is 1, then OPTIONS.pca=0
if OPTIONS.diagnoise
    OPTIONS.pca=0;
    disp('wMNE> If using diagonal noise covariance, PCA option should be off. Setting PCA option off.')
end
if isempty(OPTIONS.NoiseCov)
    error('You need to input the noise covariance in the NoiseCov field of OPTIONS.')
end
if (numL ~= length(OPTIONS.SourceOrient))
    error('The number of elements in the HeadModel structure should equal the length of the cell array OPTIONS.SourceOrient.')
end
if ~isempty(OPTIONS.loose) && (OPTIONS.loose>=1 || OPTIONS.loose<=0)
    error('loose value should be smaller than 1 and bigger than 0, or empty for no loose orientations.')
end
if OPTIONS.weightexp>1 || OPTIONS.weightexp<0
    error('weightexp should be a scalar between 0 and 1')
end
if OPTIONS.magreg>1 || OPTIONS.magreg<0
    error('magreg should be a scalar between 0 and 1')
end
if OPTIONS.eegreg>1 || OPTIONS.eegreg<0
    error('eegreg should be a scalar between 0 and 1')
end
if OPTIONS.ecogreg>1 || OPTIONS.ecogreg<0
    error('ecogreg should be a scalar between 0 and 1')
end
if OPTIONS.seegreg>1 || OPTIONS.seegreg<0
    error('seegreg should be a scalar between 0 and 1')
end

%% ===== NOISE COVARIANCE RANK =====
% Get indices of MEG and EEG channels
iMeg  = find(strncmpi(OPTIONS.ChannelTypes,'MEG',3));
iEeg  = find(strncmpi(OPTIONS.ChannelTypes,'EEG',3));
iEcog = find(strncmpi(OPTIONS.ChannelTypes,'ECOG',3));
iSeeg = find(strncmpi(OPTIONS.ChannelTypes,'SEEG',3));
% Diagonal noisecov
if OPTIONS.diagnoise
    C_noise = diag(variances);
    rnkC_noise_meg = length(iMeg);
    rnkC_noise_eeg = length(iEeg);
    rnkC_noise_ecog = length(iEcog);
    rnkC_noise_seeg = length(iSeeg);
    disp('wMNE> Setting off diagonal elements of the noise covariance to zero.');
    disp(['wMNE> Rank of noise covariance is ' num2str(size(C_noise,1))]);
% Full noisecov
else
    % Estimate noise covariance matrix rank separately for sensor types
    if ~isempty(iMeg)       
        rnkC_noise_meg = rank(single(C_noise(iMeg,iMeg))); % Rey added this. Separate rank of MEG. 3/23/11
        disp(['wMNE> Rank of MEG part of noise covariance is ' num2str(rnkC_noise_meg)]);
    end
    if ~isempty(iEeg)       
        rnkC_noise_eeg = rank(single(C_noise(iEeg,iEeg))); % Rey added this. Separate rank of EEG. 3/23/11
        disp(['wMNE> Rank of EEG part of noise covariance is ' num2str(rnkC_noise_eeg)]);
    end
    if ~isempty(iEcog)       
        rnkC_noise_ecog = rank(single(C_noise(iEcog,iEcog)));  % FT added 21-Feb-13
        disp(['wMNE> Rank of ECOG part of noise covariance is ' num2str(rnkC_noise_ecog)]);
    end
    if ~isempty(iSeeg)       
        rnkC_noise_seeg = rank(single(C_noise(iSeeg,iSeeg)));  % FT added 21-Feb-13
        disp(['wMNE> Rank of SEEG part of noise covariance is ' num2str(rnkC_noise_seeg)]);
    end
    % Sets off-diagonal terms to zero. Rey added this. 3/23/11
    C_noise_new = 0 * C_noise;
    if ~isempty(iMeg)
        C_noise_new(iMeg,iMeg) = C_noise(iMeg,iMeg);
    end 
    if ~isempty(iEeg)
        C_noise_new(iEeg,iEeg) = C_noise(iEeg,iEeg);
    end 
    if ~isempty(iEcog)
        C_noise_new(iEcog,iEcog) = C_noise(iEcog,iEcog);
    end 
    if ~isempty(iSeeg)
        C_noise_new(iSeeg,iSeeg) = C_noise(iSeeg,iSeeg);
    end
    C_noise = C_noise_new;
end


%% ===== REGULARIZE NOISE COVARIANCE MATRIX =====   
% Only if option is selected
if OPTIONS.regnoise
    listTypes = unique(OPTIONS.ChannelTypes);
    % Loop on all the required data types (MEG MAG, MEG GRAD, EEG)
    for iType = 1:length(listTypes)
        % Get channel indices
        iChan = find(strcmpi(OPTIONS.ChannelTypes, listTypes{iType}));
        % Regularize noise covariance matrix
        switch listTypes{iType}
            case 'MEG GRAD', reg = OPTIONS.gradreg; 
            case 'MEG MAG',  reg = OPTIONS.magreg;       
            case 'MEG',      reg = OPTIONS.gradreg;
            case 'EEG',      reg = OPTIONS.eegreg;
            case 'ECOG',     reg = OPTIONS.ecogreg;
            case 'SEEG',     reg = OPTIONS.seegreg;        
        end
        % Original Line 4/5/13:
        % C_noise(iChan,iChan) = C_noise(iChan,iChan) + (reg * mean(variances(iChan)) * eye(length(iChan)));          
        % JCM 4/5/13, mods just to be clear
        % mean of the diagonal variances
        % Options could be median, maximum, minimum, etc. Note, this is
        % not the eigenspectrum, but the homoskedastic spectrum.
        % TODO try other forms of matrix norms for noise regualarization
        LAMBDA_REGULARIZER = reg * mean(variances(iChan)); 
        % Now add this Tikhonov regularizer to the noise diagonal.
        C_noise(iChan,iChan) = C_noise(iChan,iChan) + diag(zeros(length(iChan),1) + LAMBDA_REGULARIZER);

    end
end


%% ===== WHITENING OPERATOR =====
% Rey added all of this, 3/23/11
% Modified FT 21-Feb-2013
% Whitening of each modality separately (MEG,EEG,ECOG,SEEG), which assumes 
% zero covariance between them (i.e., a block diagonal noise covariance). This
% was recommended by Matti as EEG does not measure all the signals from the same
% environmental noise sources as MEG.
nChan = size(C_noise,2);
W = zeros(0, nChan);
if ~isempty(iMeg)
    W_meg = CalculateWhitener('MEG', C_noise, iMeg, rnkC_noise_meg, OPTIONS.pca);
    W_tmp = zeros(size(W_meg,1), nChan);
    W_tmp(:,iMeg) = W_meg;
    W = [W; W_tmp];
end
if ~isempty(iEeg)
    W_eeg = CalculateWhitener('EEG', C_noise, iEeg, rnkC_noise_eeg, OPTIONS.pca);
    W_tmp = zeros(size(W_eeg,1), nChan);
    W_tmp(:,iEeg) = W_eeg;
    W = [W; W_tmp];
end
if ~isempty(iEcog)  
    W_ecog = CalculateWhitener('ECOG', C_noise, iEcog, rnkC_noise_ecog, OPTIONS.pca);
    W_tmp = zeros(size(W_ecog,1), nChan);
    W_tmp(:,iEcog) = W_ecog;
    W = [W; W_tmp];
end
if ~isempty(iSeeg)
    W_seeg = CalculateWhitener('SEEG', C_noise, iSeeg, rnkC_noise_seeg, OPTIONS.pca);
    W_tmp = zeros(size(W_seeg,1), nChan);
    W_tmp(:,iSeeg) = W_seeg;
    W = [W; W_tmp];
end
% Check for whitener integrity
if any(isnan(W(:))) || any(isinf(W(:)))
    error('Invalid noise covariance matrix.')
end
% Display rank of the whitener
rnkC_noise = size(W,1);
display(['wMNE> Total rank is ' num2str(rnkC_noise) '.'])


%% ===== PROCESSING LEAD FIELD MATRICES, WEIGHTS, AREAS & ORIENTATIONS =====
% Initializing.
spl = zeros(numL,1);
numdipcomp = spl;
for k = 1:numL
    sL = size(HeadModel(k).Gain, 2);
    switch OPTIONS.SourceOrient{k}
        case 'fixed',      numdipcomp(k)=1;
        case 'free',       numdipcomp(k)=3;
        case 'loose',      numdipcomp(k)=3;
        case 'truncated',  numdipcomp(k)=2;
    end
    spl(k) = (sL / 3) * numdipcomp(k); % This is a vector with the total number of dipole components per source space.
end
sspl = sum(spl); % This is the total number of dipole components across all source spaces.
L = zeros(rnkC_noise,sspl);
w = ones(sspl,1);
if isfield(HeadModel, 'area')
    areas = w;
else
    areas = [];
end
itangential = [];
start = 0;
Q_Cortex = [];
for k = 1:numL
    start = start + 1;
    endd = start + spl(k) - 1;
    Lk = HeadModel(k).Gain;    
    HeadModel(k).Gain = [];
    %% ===== COMPUTE POWER =====
    szL = size(Lk); 
    if OPTIONS.depth
        display(['wMNE> Computing power of gain matrices at each source point for source space ' num2str(k) '.'])
        % Computing power
        % JCM 4/5/2013, this is squared Frobenius norm of the source
        % Options would be the matrix norm (largest singular value, or
        % squared).
        wk = squeeze(sum(sum((reshape(Lk,[szL(1) 3 szL(2)/3])) .^2,1),2)); 
        wk = repmat(wk',[numdipcomp(k) 1]);
        wk = reshape(wk,[spl(k) 1]);
        w(start:endd) = wk;
        clear wk
    end    
    switch OPTIONS.SourceOrient{k}
        case 'fixed'
            display('wMNE> Appying fixed dipole orientations.')
            Lk = bst_gain_orient(Lk,HeadModel(k).GridOrient);
        case 'free'
            display('wMNE> Using free dipole orientations. No constraints.')        
        case 'loose'
            display('wMNE> Transforming lead field matrix to cortical coordinate system.')
            [Lk, Q_Cortex] = bst_xyz2lf(Lk, HeadModel(k).GridOrient');
            % Getting indices for tangential dipoles.
            itangentialtmp = start:endd; 
            itangentialtmp(1:3:end) = []; 
            itangential = [itangential itangentialtmp];  %#ok<AGROW>
        case 'truncated'
            display('wMNE> Truncating the dipole component pointing in the direction with least variance (i.e., silent component for single sphere head model.')
            [Lk, Q_Cortex] = bst_remove_silent(Lk);         
    end
    %% ===== WHITEN LEAD FIELD MATRIX =====
    % Whiten lead field.
    display(['wMNE> Whitening lead field matrix for source space ' num2str(k) '.'])
    Lk = W * Lk;
    if isfield(HeadModel(k),'area') && ~isempty(HeadModel(k).area)
        areav = HeadModel(k).area;
        areav = repmat(areav', [numdipcomp(k) 1]);
        areav = reshape(areav, [spl(k) 1]);
        areas(start:endd) = areav; 
    end
    L(:,start:endd) = Lk; 
    start = endd;
end
% Computing reciprocal of power.
w = 1 ./ w; 
% Clear memory
clear Lk endd start itangentialtmp sL szL

%% ===== APPLY AREAS =====
if ~isempty(areas)
    display('wMNE> Applying areas to compute current source density.')
    areas = areas.^2;
    w = w .* areas;
end
clear areas 

%% ===== APPLY DEPTH WEIGHTHING =====
if OPTIONS.depth
    % ===== APPLY WEIGHT LIMIT =====
    % Applying weight limit.
    display('wMNE> Applying weight limit.')
    weightlimit2 = OPTIONS.weightlimit .^ 2;
    %limit=min(w(w>min(w)*weightlimit2));  % This is the Matti way.
    limit = min(w) * weightlimit2;  % This is the Rey way (robust to possible weight discontinuity).
    w(w>limit) = limit; %JCM note, 4/5/2013, w = min(w,limit);

    % ===== APPLY WEIGHT EXPONENT =====
    % Applying weight exponent.
    display('wMNE> Applying weight exponent.')
    w = w .^ OPTIONS.weightexp;
    clear limit weightlimit2
end

%% ===== APPLY LOOSE ORIENTATIONS =====
if ~isempty(itangential)
    display(['wMNE> Applying loose dipole orientations. Loose value of ' num2str(OPTIONS.loose) '.'])   
    w(itangential) = w(itangential) * (OPTIONS.loose);
end

%% ===== APPLY fMRI PRIORS =====
% Apply fMRI Priors
if ~isempty(OPTIONS.fMRI)
    display('wMNE> Applying fMRI priors.')
    ifmri = (OPTIONS.fMRI < OPTIONS.fMRIthresh); 
    w(ifmri) = w(ifmri) * OPTIONS.fMRIoff;
end

%% ===== ADJUSTING SOURCE COVARIANCE MATRIX =====
% Adjusting Source Covariance matrix to make trace of L*C_J*L' equal to number of sensors.
% JCM 4/5/2013, i.e. average signal covariance is one, so trace is number
% of sensors.
display('wMNE> Adjusting source covariance matrix.')
C_J = speye(sspl, sspl);
C_J = spdiags(w, 0, C_J);
trclcl = trace(L * C_J * L');
C_J = C_J * (rnkC_noise / trclcl);
Rc = chol(C_J);
LW = L * Rc;
clear C_J trclcl sspl itangential rnkC_noise


%% BEGIN SOURCE MODELING ROUTINES

%% JCM 4/5/2013 GLS and other routines, using above setup

if any(strcmpi(OPTIONS.InverseMethod, {'gls','gls_p','glsr','glsr_p'})),
   
   start = 0;
   Kernel = zeros(size(LW,2),size(LW,1)); % note transpose of LW
   lambda2 = OPTIONS.SNR^(-2); % for regularizing the GLS
   
   for k = 1:numL,
      start = start + 1;
      endd = start + spl(k) - 1;
      Lk = LW(:,start:endd); % this whitened gain matrix
      Rck = Rc(start:endd,start:endd); % covariance priors
      % Now process each source in the gain matrix for it's own inversion
      NumSources = size(Lk,2)/numdipcomp(k); % total number of sources
      
      for i = 1:NumSources,
         ndx = ((1-numdipcomp(k)):0)+i*numdipcomp(k); % next index
         % SVD the source
         [Ua,Sa,Va] = svd(Lk(:,ndx),0); % svd of this source
         Sa = diag(Sa);
         Tolerance_Source = size(Lk,1)*eps(single(Sa(1)));
         Rank_Source = sum(Sa > Tolerance_Source);
         % Trim decomposition
         Ua = Ua(:,1:Rank_Source);
         Sa = Sa(1:Rank_Source);
         Va = Va(:,1:Rank_Source);
         
         % calculate the weighted subspace
         Reg_Weights_Source = Sa.^2 ./ (Sa.^2 + lambda2*Sa(1)^2); % regularizer
         % now write the pseudoinverse results back into this same matrix
         
         switch OPTIONS.InverseMethod
            case 'gls'
               % The true pseudo-inverse
               Lk(:,ndx) = Ua * diag(1./Sa) * Va'*Rck(ndx,ndx);
            case 'gls_p'
               % The model performance
               % Model may be reduced rank
               Lk(:,ndx) = 0; % zero out
               Lk(:,ndx(1:size(Ua,2))) = Ua; % model performance
            case 'glsr'
               % Regularized
               Lk(:,ndx) = Ua * diag(Reg_Weights_Source./Sa) * Va'*Rck(ndx,ndx);
            case 'glsr_p'
               % Regularized model performance
               % Model may be reduced rank
               Lk(:,ndx) = 0; % zero out
               Lk(:,ndx(1:size(Ua,2))) = Ua * diag(sqrt(Reg_Weights_Source)); % model performance
            otherwise
               error('Bad Options String %s',OPTIONS.InverseMethod)
         end
      end
      
      % Now we have a matrix almost ready for use as an imaging kernel
      % Later, below, the whitener will be added
      
      Kernel(start:endd,:) = Lk';
      start = endd;
   end
   
end % JCM GLS routine

if any(strcmpi(OPTIONS.InverseMethod, {'mnej','mnej_p'})), %JCM Min Norm
   % mnej should be identical to Rey, but mnej_p is novel
   
   start = 0;
   Kernel = zeros(size(LW,2),size(LW,1)); % note transpose of LW
   lambda2 = OPTIONS.SNR^(-2); % for regularizing the MN
   
   for k = 1:numL,
      start = start + 1;
      endd = start + spl(k) - 1;
      Lk = LW(:,start:endd); % this whitened gain matrix
      Rck = Rc(start:endd,start:endd); % covariance priors
      
      % Setup the Min Norm
      % First, generate the population data covariance
      wCD = LW*LW' + (diag(zeros(size(LW,1),1) + lambda2)); % whitened data covariance
      
      % Decompose
      [Ud,Sd] = svd(wCD);
      
      % Data Whitener
      iWd = Ud*diag(1./sqrt(diag(Sd)))*Ud';
      
      % Now process each source in the gain matrix for it's own inversion
      NumSources = size(Lk,2)/numdipcomp(k); % total number of sources
      
      for i = 1:NumSources,
         ndx = ((1-numdipcomp(k)):0)+i*numdipcomp(k); % next index
         % SVD the data whitened source
         [Ua,Sa,Va] = svd(iWd*Lk(:,ndx),0); % svd of this source
         Sa = diag(Sa);
         Tolerance_Source = size(Lk,1)*eps(single(Sa(1)));
         Rank_Source = sum(Sa > Tolerance_Source);
         if Rank_Source < length(Sa),
            fprintf('%.0f ',i);
         end
         % Trim decomposition
         Ua = Ua(:,1:Rank_Source);
         Sa = Sa(1:Rank_Source);
         Va = Va(:,1:Rank_Source);
         
         SNR_Weights_Source = Sa.^2 ./ (1 - Sa.^2); % SNR
         % now write the pseudoinverse results back into this same matrix
         
         switch OPTIONS.InverseMethod
            case 'mnej'
               % The true solution
               Lk(:,ndx) = iWd * Ua * diag(Sa) * Va' * Rck(ndx,ndx);
            case 'mnej_p'
               % The model performance
               %Lk(:,ndx) = iWd * Ua * diag(sqrt(SNR_Weights_Source)); % model performance
               Lk(:,ndx) = iWd * Ua; % CHEAT model performance

            otherwise
               error('Bad Options String %s',OPTIONS.InverseMethod)
         end
      end
      
      % Now we have a matrix almost ready for use as an imaging kernel
      % Later, below, the whitener will be added
      
      Kernel(start:endd,:) = Lk';
      start = endd;
   end 
   
end %JCM Min norms


%% The dSPM and sLORETA functions rely on 'wmne' being calculated

if any(strcmpi(OPTIONS.InverseMethod, {'wmne','dspm','sloreta'}))
   
   %% ===== SINGULAR VALUE DECOMPOSITION =====
   % Set regularization parameter based on SNR
   lambda2 = OPTIONS.SNR ^ (-2);
   % Compute SVD.
   display('wMNE> Computing SVD of whitened and weighted lead field matrix.')
   [V,S,U] = svd(LW','econ'); % JCM 4/5/2013 transpose for greater speed
   s = diag(S);
   ss = s ./ (s.^2 + lambda2);
   clear LW lambda2 s
   
   %% ===== WHITENED MNE IMAGING KERNEL =====
   % Compute whitened MNE operator.
   Kernel = Rc * V * diag(ss) * U';
   clear Rc V ss U
end


%% ===== WHITENED dSPM IMAGING KERNEL =====
% Compute dSPM operator.
if strcmpi(OPTIONS.InverseMethod, 'dspm')
   display('wMNE> Computing dSPM inverse operator.')
   start = 0;
   for k = 1:numL
      start = start+1;
      endd = start + spl(k) - 1;
      dspmdiag = sum(Kernel(start:endd,:) .^2, 2);
      if (numdipcomp(k) == 1)
         dspmdiag = sqrt(dspmdiag);
      elseif (numdipcomp(k)==3 || numdipcomp(k)==2)
         dspmdiag = reshape(dspmdiag, [numdipcomp(k), spl(k)/numdipcomp(k)]);
         dspmdiag = sqrt(sum(dspmdiag)); % Taking trace and sqrt.
         dspmdiag = repmat(dspmdiag, [numdipcomp(k), 1]);
         dspmdiag = reshape(dspmdiag, [spl(k), 1]);
      end
      Kernel(start:endd,:) = bst_bsxfun(@rdivide, Kernel(start:endd,:), dspmdiag);
      start = endd;
   end
   
   %% ===== WHITENED sLORETA IMAGING KERNEL =====
   % Compute sLORETA operator.
elseif strcmpi(OPTIONS.InverseMethod, 'sloreta')
   display('wMNE> Computing sLORETA inverse operator.')
   start=0;
   for k = 1:numL
      start = start + 1;
      endd = start + spl(k) - 1;
      if (numdipcomp(k) == 1)
         sloretadiag = sqrt(sum(Kernel(start:endd,:) .* L(:,start:endd)', 2));
         Kernel(start:endd,:) = bst_bsxfun(@rdivide, Kernel(start:endd,:), sloretadiag);
      elseif (numdipcomp(k)==3 || numdipcomp(k)==2)
         for spoint = start:numdipcomp(k):endd
            R = Kernel(spoint:spoint+numdipcomp(k)-1,:) * L(:,spoint:spoint+numdipcomp(k)-1);
            SIR = sqrtm(pinv(R));
            Kernel(spoint:spoint+numdipcomp(k)-1,:) = SIR * Kernel(spoint:spoint+numdipcomp(k)-1,:);
         end
      end
      start=endd;
   end
end
disp(' ');

%% JCM, 4/5/2013, this loose orientation may be compatible with GLS and others

%% ===== LOOSE ORIENTATION: RE-ORIENT COMPONENTS =====
% WARNING: Changing the orientations of the dipoles from MNE to Brainstorm
% => Make "Unconstrained" and "loose"/"truncated" models directly comparable
if ~isempty(Q_Cortex)
   % Creating a block diagonal matrix
   N = size(Kernel,1);
   Nout = N / numdipcomp * 3;
   iRow = reshape(repmat(reshape(1:Nout,3,[]), numdipcomp, 1), 1, []);
   iCol = reshape(repmat(1:N,3,[]), 1, []);
   Q_Cortex = sparse(iRow, iCol, Q_Cortex(:));
   % Applying orientations
   Kernel = Q_Cortex * Kernel;
end


%% ===== ASSIGN IMAGING KERNEL =====
% Multiply inverse operator and whitening matrix, so no need to whiten data.
Kernel = Kernel * W;
% Return results structure
Results.ImagingKernel = Kernel;
Results.ImageGridAmp  = [];
Results.Whitener      = W;
if (length(numdipcomp) > 1)
    Results.nComponents = 0;
else
    Results.nComponents = numdipcomp;
end

end


%% ==============================================================================
%  ===== HELPER FUNCTIONS =======================================================
%  ==============================================================================
% TODO JCM 4/5/2013: Cleanup the whitener to use SVD, reduced rank. isPCA
% is actually for truncated SVD of the matrix for small values.
function W = CalculateWhitener(Modality, C_noise, iChannel, rnkC_noise, isPca)
    [V,D] = eig(C_noise(iChannel,iChannel)); 
    D = diag(D); 
    [D,I] = sort(D,'descend'); 
    V = V(:,I);
    % No PCA case.
    if ~isPca
        display(['wMNE> Not doing PCA for ' Modality '.'])
        D = 1./D;
        W = diag(sqrt(D)) * V';
    % Rey's approach. MNE has been changed to implement this.
    else
        display(['wMNE> Setting small ' Modality ' eigenvalues to zero.'])
        D = 1 ./ D; 
        D(rnkC_noise+1:end) = 0;
        W = diag(sqrt(D)) * V';
        W = W(1:rnkC_noise,:); % This line will reduce the actual number of variables in data and leadfield to the true rank. This was not done in the original MNE C code.
    end
end


