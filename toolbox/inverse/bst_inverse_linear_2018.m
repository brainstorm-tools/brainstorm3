function [Results, OPTIONS] = bst_inverse_linear_2018(HeadModel,OPTIONS)
% BST_INVERSE_LINEAR_2018: Compute an inverse solution (minimum norm, dipole fitting or beamformer)
% USAGE:  [Results,OPTIONS] = bst_inverse_linear_2018(HeadModel, OPTIONS) : Compute mininum operator
%                   OPTIONS = bst_inverse_linear_2018()                   : Return default options
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
%     The function was originally written with the goal of providing some of the same
%     functionality of the MNE software written by Matti Hamalainen, but no
%     guarantees are made that it performs all computations in the same
%     exact way. It also provides some functionalities not available in the
%     MNE software.
%
%     In March 2015, this function was completely overhauled by John
%     Mosher to create dipole fitting, beamforming, and min norm images all
%     in the same imaging kernel framework. After the imaging kernel is
%     generated, subsequent Process Operations can be applied to further
%     interpret the results, such as finding the optimal dipole in each
%     time slice.
%
%     February 2018 Revisions:
%     In February 2018, the function was expanded by John Mosher to once
%     again allow for DBA, Deep Brain Analysis, which uses a mixed head
%     model characterized by multiple head models that are concatenated
%     together. 
%     The definition of "regularization" in the noise covariance
%     (NoiseMethod 'reg') was also changed to match that of Hamalainen, in which the
%     regularization parameter is used with the average eigenvalue, instead
%     of the strongest (first) eigenvalue. Minor bug in the way the
%     whitener was regularized was also fixed. The only difference now between
%     bst_wmne and this version, for the whitener, is that this whitener is
%     symmetric, for convenience.
%     
%
% INPUTS:
%    - HeadModel: Array of Brainstorm head model structures
%         |- Gain       : Forward field matrix for all the channels (unconstrained source orientations)
%         |- GridLoc    : Dipole locations
%         |- GridOrient : Dipole orientation matrix
%         |- HeadModelType : 'volume', 'surface' or 'mixed'?
%    - OPTIONS: structure
%         |- NoiseCovMat        : Noise covariance structure
%         |   |- NoiseCov       : Noise covariance matrix
%         |   |- FourthMoment   : Fourth moment (F^2 * F^2'/n)
%         |   |- nSamples       : Number of times samples used to compute those measures
%         |- DataCovMat         : Data covariance structure
%         |   |- NoiseCov       : Data covariance matrix  (F*F'/n)
%         |   |- FourthMoment   : Fourth moment (F^2 * F^2'/n)
%         |   |- nSamples       : Number of times samples used to compute those measures
%         |- ChannelTypes   : Type of each channel (for each row of the Leadfield and the NoiseCov matrix)
%         |- InverseMethod  : {'minnorm', 'gls', 'lcmv'}
%         |- InverseMeasure :    | minnorm: {'amplitude',  'dspm2018', 'sloreta'}
%         |                      |     gls: {'performance'}
%         |                      |    lcmv: {'performance'}
%         |- SourceOrient   : String or a cell array of strings specifying the type of orientation constraints for each HeadModel (default: 'fixed')
%         |- Loose          :    | Value that weights the source variances of the dipole components defining the tangent space of the cortical surfaces (default: 0.2).
%         |- UseDepth       : Flag to do depth weighting (default: 1).
%         |- WeightExp      :    | Order of the depth weighting. {0=no, 1=full normalization, default=0.8}
%         |- WeightLimit    :    | Maximal amount depth weighting (default: 10).
%         |- NoiseMethod    : {'shrink', 'median', 'reg', 'diag', 'none'}
%         |- NoiseReg       :    | NoiseMethod='reg' : Amount of regularization
%         |- SnrMethod      : {'rms', 'fixed'}
%         |- SnrRms         :    | SnrMethod='rms'   : RMS source amplitude, in nAm  (Default=1000)
%         |- SnrFixed       :    | SnrMethod='fixed' : Fixed SNR value (Default=3)
%
% OUTPUTS:
%    - Results : Source structure
%       NEW in 2015: if GridOrient is returned empty, the orientation is assumed to be
%       the original grid orientation (usually normal to the surface, or unconstrained in a volume). If
%       it is returned here, then we are returning an optimized orientation
%       that overrides the original orientation.
%    - OPTIONS : Return the modified options


% NOTES (mostly not updated for 2018, see notes below):
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
%         - "loose"     : Source variances of dipole components pointing
%                         tangentially to the cortical surfaces are
%                         multipled by OPTIONS.Loose
%         - "optimal"   : NEW IN 2015: Optimal orientation is returned
%                         in GridOrients for each dipole
%       => OBSOLETE IN 2015: For dealing with multiple source spaces with different types of orientation constraints use for example,
%          OPTION.SourceOrient{1}='fixed';
%          OPTION.SourceOrient{2}='free';
%          This has to correspond with the HeadModel Structure
%
%     - sLORETA: TODO: August 2016, Output values are multiplied by 1e12 for display in
%                Brainstorm (time series and cortical maps). There is a
%                discrepancy in the Pascual-Marqui publications regarding
%                resolution kernels vs data covariance that needs
%                addressing by a sLORETA expert. For now, we leave it as
%                its legacy version since 2011.

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
% Authors:  Rey Rene Ramirez, Ph.D, 2010-2012
%           Francois Tadel, 2010-2016
%           John Mosher, 2014-2018


%% ===== DEFINE DEFAULT OPTIONS =====
Def_OPTIONS.NoiseCovMat    = [];
Def_OPTIONS.DataCovMat     = [];
Def_OPTIONS.ChannelTypes   = {};
Def_OPTIONS.InverseMethod  = 'minnorm';
Def_OPTIONS.InverseMeasure = 'amplitude';
Def_OPTIONS.SourceOrient   = {'fixed'};
Def_OPTIONS.Loose          = 0.2;
Def_OPTIONS.UseDepth       = 1;
Def_OPTIONS.WeightExp      = 0.5;
Def_OPTIONS.WeightLimit    = 10;
Def_OPTIONS.NoiseMethod    = 'reg';
Def_OPTIONS.NoiseReg       = .1;
Def_OPTIONS.SnrMethod      = 'fixed';
Def_OPTIONS.SnrRms         = 1000;
Def_OPTIONS.SnrFixed       = 3;
Def_OPTIONS.FunctionName   = [];

% Return the default options
if (nargin == 0)
    Results = Def_OPTIONS;
    return
end

fprintf('\nBST_INVERSE (2018) > Modified Feb 2018\n\n');

% How many head models have been passed, if greater than 1, then we are
% doing a "DBA" or "Deep Brain Analysis"

numL = size(HeadModel,2);

if numL > 1
    fprintf('\nBST_INVERSE (2018) > Deep Brain Analysis for %.0f submodels\n\n',numL);
    
    % Update the default option for Source Orientations in this case
    Def_OPTIONS.SourceOrient = repmat(Def_OPTIONS.SourceOrient, [1 numL]);   
end

% Copy default options to OPTIONS structure (do not replace defined values)
OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);


% Mosher, Hardwire Feb 2018, consider making it an OPTION
% set true or false for testing
% Conversation between Mosher and Leahy 15 Feb 2018, we will turn this off, since cross components
% for noise regularization across modalities is trying to squeeze too much
% out of each modality. So in multiple modality, each modality is
% regularized and inverted separately from the other modalities.
% Note that bst_wmne (old code), and Hamalainen's code, did allow for cross
% modality between GRADS and MAGS only, but not with others (ECOG, SEEG,
% EEG). Difference should be minor.

CROSS_COVARIANCE_CHANNELTYPES = false; % do allow the cross covariance between modalities, to include GRADS, MAGS, SEEG, ECOG, etc.

if CROSS_COVARIANCE_CHANNELTYPES
    fprintf('\nBST_INVERSE (2018) > NOTE: Cross Covariance between sensor modalities IS CALCULATED in the noise covariance matrix\n\n')
else
    fprintf('\nBST_INVERSE (2018) > NOTE: Cross Covariance between sensor modalities IS NOT CALCULATED in the noise covariance matrix\n\n')
end



%% ===== CHECK FOR INCONSISTENT VALUES =====
if (OPTIONS.UseDepth && strcmpi(OPTIONS.InverseMeasure, 'sloreta'))
    disp('BST_INVERSE > Depth weighting is not necessary when using sLORETA normalization, ignoring option UseDepth=1');
    OPTIONS.UseDepth = 0;
elseif (OPTIONS.UseDepth && ~strcmpi(OPTIONS.InverseMethod, 'minnorm'))
    disp('BST_INVERSE > Depth weighting is only available for minnorm, ignoring option UseDepth=1');
    OPTIONS.UseDepth = 0;
end
if (numL ~= length(OPTIONS.SourceOrient))
    error('BST_INVERSE > The number of elements in the HeadModel structure should equal the length of the cell array OPTIONS.SourceOrient.')
end
if ~isempty(OPTIONS.Loose) && (OPTIONS.Loose>=1 || OPTIONS.Loose<=0)
    error('BST_INVERSE > Loose value should be smaller than 1 and bigger than 0, or empty for no loose orientations.')
end
if (OPTIONS.WeightExp > 1) || (OPTIONS.WeightExp < 0)
    error('BST_INVERSE > WeightExp should be a scalar between 0 and 1')
end

if (OPTIONS.NoiseReg > 1) || (OPTIONS.NoiseReg < 0)
    error('BST_INVERSE > NoiseReg should be a scalar between 0 and 1')
end

% mixed head models don't work with GLS or LCMV
if (numL > 1 && (strcmpi(OPTIONS.InverseMeasure,'gls') || strcmpi(OPTIONS.InverseMeasure,'lcmv')))
    error('BST_INVERSE (2018) > Mixed head models (deep brain analysis) do not work with GLS or LCMV')
end


%% ===== NOISE COVARIANCE REGULARIZATION =====

% Convenient notation
C_noise = OPTIONS.NoiseCovMat.NoiseCov; % all of the channels requested
Var_noise = diag(C_noise); % Diagonal vector of the noise variances per channel
nChannels = length(Var_noise);

% JCM: March 2015, probably don't need this, but will retain
% Detect if the input noise covariance matrix is or should be diagonal
if (norm(C_noise,'fro') - norm(Var_noise,'fro')) < eps(single(norm(Var_noise,'fro')))
    % no difference between the full matrix and the diagonal matrix
    disp(['BST_INVERSE > Detected diagonal noise covariance, ignoring option NoiseMethod="' OPTIONS.NoiseMethod '".']);
    OPTIONS.NoiseMethod = 'diag';
end

if strcmpi('diag',OPTIONS.NoiseMethod)
    C_noise = diag(diag(C_noise)); % force matrix to be diagonal, that's all the user wants
end

% Commentary April 2015: There is a tendency to apply generic scale values to the
% channels to balance them with regards to units, such as Volts and Tesla.
% But we also have a problem with gradiometer channels vs magnetometers. So
% the "natural" way is to use the channel variances themselves to balance
% out the differences between modalities. But we don't want to do each
% channel, since a dead channel has (near) zero variance. So instead we
% calculate a common variance for each modality, to get us in the ball
% park. So we initially treat each modality as Independent and Identically
% Distributed (IID) and pre-whiten by this to bring the modalities into
% closer alignment.

% Because the units can be different, we need to first balance the
% different types of arrays. How many unique array types do we have?

% Updated Commentary August 2016, by John Mosher: The issue of balancing is
% primarily a problem of multi-modal statistics, i.e., across multiple
% channel types. Ideally, we should allow for possible cross-covariances
% between the modalities to assist in the overal spatial correlation of the
% array. The problem is that we simultaneously need to "regularize" the
% covariance matrices to catch bad channels and experimental dependencies
% that creep into measurements, while also calculating cross-dependencies
% between modalities of disparate units.
%
% We have tried numerous "black-box" methods to get, for example, Neuromag
% magnetometers and gradiometers combined in the same covariance matrix.
% Unfortunately, each situation can be unique, such as in a clinical
% setting, where the magnetometers can span an enormous dynamic range,
% while gradiometers span a much tighter range, and these ranges overlap.
%
% In consultation with co-investigator Matti Hamalainen and MNE, we opted
% for now to keep the use of the multimodal calculation simpler by
% eliminating the cross modality terms, then regularizing within each
% modality. This has been the default approach to multimodal noise
% covariance calculations in Brainstorm since 2011, and we retain that
% here.

% So how many channel types do we have:
Unique_ChannelTypes = unique(OPTIONS.ChannelTypes);

% What are their indices
ndx_Channel_Types = cell(1,length(Unique_ChannelTypes)); % index for each channel type
for i = 1:length(Unique_ChannelTypes)
    ndx_Channel_Types{i} = find(strcmpi(Unique_ChannelTypes(i),OPTIONS.ChannelTypes));
end

% not sure if Ledoit's shrinkage method will work across mixed modalities
if length(Unique_ChannelTypes) > 1 && strcmpi('shrink',OPTIONS.NoiseMethod) && CROSS_COVARIANCE_CHANNELTYPES,
    fprintf('NOTE: Noise Regularization ''shrink'' selected with multiple channel types, not sure that will work with cross covariances.\n');
end


% Initialize the modality whitening matrices:
% iPrior_Matrix = eye(nChannels);

% Retain the below code in comments if only to discuss what does and does
% not work in trying to capture cross-modalities. August 2016

%     % calculate the average variance per channel as a prior
%     Prior_IID = zeros(length(Unique_ChannelTypes),1);
%     Prior_Vector = zeros(nChannels,1); % initialize as a vector
%
%     for i = 1:length(Unique_ChannelTypes),
%         ndx = find(strcmpi(Unique_ChannelTypes(i),OPTIONS.ChannelTypes)); % which ones
%         Prior_IID(i) = mean(Var_noise(ndx)); % mean of this type
%         % let's get a bit more sophisticated on calculating this IID value
%         % We wouldn't want a few extreme values distorting our mean
%         % How many channels are there:
%         len_ndx = length(ndx);
%         % let's toss out the upper and lower values
%         ndx_clip = round(len_ndx/10); % 10%
%         Variances_This_Modality = sort(Var_noise(ndx));
%         % trim to central values
%         Variances_This_Modality = Variances_This_Modality((ndx_clip+1):(end-ndx_clip));
%         Prior_IID(i) = median(Variances_This_Modality); % mean of the middle values
%         Prior_Vector(ndx) = sqrt(Prior_IID(i)); % map to this part of the array
%     end
%
%     %TODO: Test for bizarre case of Prior_IID too small
%
%     % build whitener to balance out the different types of channels
%     iPrior_Matrix = spdiags(1./Prior_Vector,0,nChannels,nChannels);
%
%     % Now we can use this iPrior_Matrix to "pre-whiten" the noise covariance
%
%     % Block Whitened noise covariance
%     Cw_noise = iPrior_Matrix * C_noise * iPrior_Matrix;
%
%     % Now the units imbalance between different subarrays is theoretically
%     % balanced.

% January 2018, for consistency with Hamalainen's MNE and with older
% Brainstorm code, Mosher making some changes to how noise covariance is
% calculated and regularized. 

% Now remove the off_diagonal components between modalities, if desired
Cw_noise = zeros(size(C_noise)); % initialize

if CROSS_COVARIANCE_CHANNELTYPES % do allow for cross covariances
    
    ndx = [ndx_Channel_Types{:}]; % all of the channels
    Cw_noise(ndx,ndx) = C_noise(ndx,ndx); % including cross terms
    
else % don't allow for cross covariances
    
    for i = 1:length(Unique_ChannelTypes)
        % for each unique modality
        ndx = ndx_Channel_Types{i}; % which ones
        Cw_noise(ndx,ndx) = C_noise(ndx,ndx);
    end
    % the off diagonal components corresponding to cross-modality
    % covariances have been removed

end

% Mosher, Feb 2018 change, we may want the cross modalities, in order to
% exploit any additional information between them. What we should have is a
% "user flag", but for now I will hard-wire it in and discuss with the
% others. Matti uses the cross information between GRADS and MAGS, but not
% between the other modalities. However, that is the point of the advance
% e-physiological studies, merging modalities.

% By continuing to call it "Cw_noise", the below codes can continue as
% before.

% Before any additional regularizations that may interfere

% Make sure the noise covariance matrix is strictly symmetric
% (the previous operations may cause rounding errors that make the matrix not exactly symmetrical)
Cw_noise = (Cw_noise + Cw_noise')/2;

% So the block whitened noise covariance matrix is Cw_noise.

% If the modalities were truly balanced, we could proceed with
% regularization in one fell swoop; however, the reality is that
% regularization should be applied modality by modality, with the cross
% covariance of the modalities zeroed out.

% initialize inverse whitener for noise covariance matrix
iWw_noise = zeros(size(Cw_noise));

FourthMoment = zeros(size(C_noise)); % initialize
nSamples = [];
if strcmpi(OPTIONS.NoiseMethod, 'shrink')
   % Has the user calculated the Fourth Order moments?
   if ~isfield(OPTIONS.NoiseCovMat,'FourthMoment')
      error('BST_INVERSE > For Method ''shrink'' please recalculate Noise Covariance, to include Fourth Order Moments');
   else
      FourthMoment = OPTIONS.NoiseCovMat.FourthMoment;
   end
   
   % How many samples used to calculate covariance
   if isempty(OPTIONS.NoiseCovMat.nSamples)
      error('BST_INVERSE > No noise samples found. For Method ''shrink'' please recalculate Noise Covariance from actual data samples.');
   else
      nSamples = OPTIONS.NoiseCovMat.nSamples(1);
      % FIX: What if different lengths are used, but only an issue at this
      % point for "shrink" method
   end
end

% Mosher, Feb 2018, now the trick to regularization across modalities is to
% apply the regularization within the modality itself, but not across
% modalites. In other words, calculate the average variance of the MAGS
% separate from the GRADS separate from SEEG.

% First, truncate and regularize each modality separately
for i = 1:length(Unique_ChannelTypes)
   % each modality
    ndx = ndx_Channel_Types{i}; % which ones
   
    % regularize and form whitener for each modality, using local
    % subfunction
    [Cw_noise(ndx,ndx),iWw_noise(ndx,ndx)] = ...
        truncate_and_regularize_covariance(Cw_noise(ndx,ndx),...
        OPTIONS.NoiseMethod,Unique_ChannelTypes{i},...
        OPTIONS.NoiseReg,FourthMoment(ndx,ndx),nSamples);   
end

% So now we have calculated the noise covariance matrix across all
% modalities, but have eliminated the cross covariances between modalities.
% Within each modality, we have checked for rank deficiencies and have
% added possible regularization within the modality.

% now, if cross modality is desired, we need to calculate the overall
% inverse, using the regularized submatrices (all which may have had their
% diagonal terms altered by regularization), but now we don't apply any
% additional regularization to the overall covariance matrix

if length(Unique_ChannelTypes) > 1 && CROSS_COVARIANCE_CHANNELTYPES % we do want the cross terms in the inverse
    ndx = [ndx_Channel_Types{:}]; % all of the channels
    % don't regularize, may still need truncation if deficient
    [Cw_noise(ndx,ndx),iWw_noise(ndx,ndx)] = ...
        truncate_and_regularize_covariance(Cw_noise(ndx,ndx),'none','ALL');  
end

% so Ww * Ww' = Cw, and iWw*iWw' = pinv(Cw)

% so the entire "whitening" process is to first apply the modality
% whitener, then apply the unitless whitener.
% iWw_noise * iPrior_Matrix * d;

% For convenience in the later modeling, let's combine into one whitener

iW_noise = iWw_noise; % * iPrior_Matrix; % August 2016, iPrior is simpy I


%% ======== Data Covariance Manipulation, if there is one =============

% August 2016, we treat Data Covariances in exactly the same manner as
% Noise Covariance matrices. To be done is to explore whitening methods of
% data covariance matrices, such as would be needed in MUSIC, but not there
% yet, part of future work.

% We only calculate the data covariance matrix for LCMV

if isempty(OPTIONS.DataCovMat) || ~strcmpi(OPTIONS.InverseMethod, 'lcmv')  % user may not have calculated
    
    iW_data = [];

else
    % Regularize and invert the data covariance matrix, same as the noise
    % covariance matrix.
    
    % Convenient notation
    C_data = OPTIONS.DataCovMat.NoiseCov; % all of the channels requested
    Var_data = diag(C_data); % Diagonal vector of the noise variances per channel
    
    % quick error check
    if nChannels ~= length(Var_data)
        error('BST_INVERSE > Data covariance is not the same size as noise covariance, something is wrong')
    end
    
    % Zero out any cross covariance between modalities.
    Cw_data =zeros(size(C_data));
    
    if CROSS_COVARIANCE_CHANNELTYPES % do allow for cross covariances
        
        ndx = [ndx_Channel_Types{:}]; % all of the channels
        Cw_data(ndx,ndx) = C_data(ndx,ndx); % including cross terms
        
    else % don't allow for cross covariances
        
        for i = 1:length(Unique_ChannelTypes)
            % for each unique modality
            ndx = ndx_Channel_Types{i}; % which ones
            Cw_data(ndx,ndx) = C_data(ndx,ndx);
        end
        
    end
    
    % ensure symmetry
    
    Cw_data = (Cw_data + Cw_data')/2;
    
    % So the block whitened noise covariance matrix is Cw_noise.
    
    % If the modalities were truly balanced, we could proceed with
    % regularization in one fell swoop; however, the reality is that
    % regularization should be applied modality by modality, with the cross
    % covariance of the modalities zeroed out.
    
    % initialize inverse whitener for noise covariance matrix
    iWw_data = zeros(size(Cw_data));
    

    
    FourthMoment = zeros(size(C_data)); % initialize
    nSamples = [];
    if strcmpi(OPTIONS.NoiseMethod, 'shrink')
       % Has the user calculated the Fourth Order moments?
       if ~isfield(OPTIONS.DataCovMat,'FourthMoment')
          error('BST_INVERSE > For Method ''shrink'' please recalculate Data Covariance, to include Fourth Order Moments');
       else
          FourthMoment = OPTIONS.DataCovMat.FourthMoment;
       end
       
       % How many samples used to calculate covariance
       if isempty(OPTIONS.DataCovMat.nSamples)
          error('BST_INVERSE > No data samples found. For Method ''shrink'' please recalculate Data Covariance from actual data samples.');
       else
          nSamples = OPTIONS.DataCovMat.nSamples(1);
          % FIX: What if different lengths are used, but only an issue at this
          % point for "shrink" method
       end
    end % for method "shrink"
    
    
    % now apply regularization per modality
    for i = 1:length(Unique_ChannelTypes)
       % each modality
       ndx = ndx_Channel_Types{i}; % which ones
               
        % regularize and form whitener for each modality, using local
        % subfunction. Note DataCov still used NoiseMethod and NoiseReg to
        % pass parameters.
        
        [Cw_data(ndx,ndx),iWw_data(ndx,ndx)] = ...
            truncate_and_regularize_covariance(Cw_data(ndx,ndx),...
            OPTIONS.NoiseMethod,Unique_ChannelTypes{i},...
            OPTIONS.NoiseReg,FourthMoment(ndx,ndx),nSamples);
    end
    
    % now truncate and invert the entire cross modality, if desired
    
    if length(Unique_ChannelTypes) > 1 && CROSS_COVARIANCE_CHANNELTYPES % we do want the cross terms in the inverse
        ndx = [ndx_Channel_Types{:}]; % all of the channels
        % don't regularize, may still need truncation if deficient
        [Cw_data(ndx,ndx),iWw_data(ndx,ndx)] = ...
            truncate_and_regularize_covariance(Cw_data(ndx,ndx),'none','ALL');
    end
    
    iW_data = iWw_data; % * iPrior_Matrix; % August 2016, iPrior is simply I
    
    % =============  MAJOR PROGRAMMING SIMPLICITY HERE ==============
    iW_noise_true = iW_noise; % save the true noise whitener
    iW_noise = iW_data; % we replace the noise whitener with the data whitener in the below equations.
    
end % if there is a data covariance matrix


%% ===== Source Model Assumptions ===============
%
% Jan 2018: Now we need to build this for each headmodel, where the orientation
% constraints may be varying in the "deep brain analysis" operations.

L = cell(1,numL); % initialize the leadfield matrix as a blank cell array
NumDipoleComponents = zeros(1,numL); % per head model
NumDipoles = zeros(1,numL); % per head model
Alpha = cell(1,numL);
WQ = cell(1,numL);

for kk = 1:numL % for each headmodel
    
    % Calculated separately from the data and noise covariance considerations
    % number of sources:
    NumDipoles(kk) = size(HeadModel(kk).GridLoc,1); % number of dipoles (source points)
    % (insensitive to the number of components per dipole)
    
    % orientation of each source:
    % Each current dipole has an explicit or implied covariance matrix for its
    % moment, C_q. Let W_q be the matrix square root, C_q = W_q * W_q'.
    
    % If the HeadModel(kk)Type is "surface" then there is an orientation available,
    % if it is "volume" then an orientation is not pre-defined in
    % HeadModel(kk).GridOrient.
    
    Wq = cell(1,NumDipoles(kk)); % source unit orientations
    
    
    % Optional Depth Weighting Scalar (used particularly in Min Norms)
    % Calculate Depth Weighting Scalar
    Alpha{kk} = ones(1,NumDipoles(kk)); % initialize to unity
    
    if OPTIONS.UseDepth
        % See eq. 6.2.10 of MNE Manual version 2.7 (Mar 2010).
        % Original code had some backflips to check for instabilities.
        % Here we take a simpler direct approach.
        
        % We are assuming unconstrained (three source directions) per source
        % point. We form the unconstrained norm of each point
        ColNorms2 = sum(HeadModel(kk).Gain .* HeadModel(kk).Gain); % square of each column
        SourceNorms2 = sum(reshape(ColNorms2,3,[]),1); % Frobenius norm squared of each source
        
        % Now Calculate the *non-inverted* value
        Alpha2 = SourceNorms2 .^ OPTIONS.WeightExp; % note not negative weight (yet)
        AlphaMax2 = max(Alpha2); % largest squared source norm
        % The limit is meant to keep the smallest from getting to small
        Alpha2 = max(Alpha2, AlphaMax2 ./ (OPTIONS.WeightLimit^2)); % sets lower bound on source strengths
        
        % Now invert it
        Alpha2 = AlphaMax2 ./ Alpha2; % goes from WeightLimit^2 to 1, depending on the inverse strength of the source
        
        Alpha{kk} = sqrt(Alpha2);
        % Thus deep weak sources can be amplified up to WeightLimit times greater
        % strength, relative to the stronger shallower sources.
    end
    
    % So, at this point, we have an orientation matrix defined for every source
    % point, and we have a possible weighting scalar to apply to it. Each
    % source has (as yet unknown) source variance of sigma2. The total source
    % covariance we are modeling is
    % Cq = Alpha2 * sigma2 * Wq * Wq'; % where sigma2 is unknown and to be
    % estimated from the data.
    
    % So we now define Wq to include the optional alpha weighting, as
    % calculated above
    
    % So if the HeadModel(kk) is "volume", user should not have been able to select
    % "fixed" (normal to cortex), nor "loose". Francois has controlled this
    % through the GUI interface. Check anyway
    
    if strcmpi('volume', HeadModel(kk).HeadModelType)
        switch OPTIONS.SourceOrient{kk}
            case 'free'
                % do nothing, okay
            otherwise
                error('BST SOURCE ERROR: HeadModel is a volume with no defined orientation. Change Orientation from %s to ''unconstrained''.\n',OPTIONS.SourceOrient{kk})
        end
    end
    
    
    % Initialize each source orientation
    
    fprintf('BST_INVERSE > Using ''%s'' surface orientations\n',OPTIONS.SourceOrient{kk})
    
    for i = 1:NumDipoles(kk)
        
        switch OPTIONS.SourceOrient{kk}
            case 'fixed'
                % fprintf('BST_INVERSE > Using constrained surface orientations\n');
                NumDipoleComponents(kk) = 1;
                tmp = HeadModel(kk).GridOrient(i,:)'; % 3 x 1
                Wq{i} = tmp/norm(tmp); % ensure unity
                
            case 'loose'
                % fprintf('BST_INVERSE > Using loose surface orientations\n');
                NumDipoleComponents(kk) = 3;
                tmp = HeadModel(kk).GridOrient(i,:)'; % preferred direction
                tmp = tmp/norm(tmp); % ensure unity
                tmp_perp = null(tmp'); % orientations perpedicular to preferred
                Wq{i} = [tmp tmp_perp*OPTIONS.Loose]; % weaken the other directions
                
            case 'free'
                % fprintf('BST_INVERSE > Using unconstrained orientations\n');
                NumDipoleComponents(kk) = 3;
                Wq{i} = eye(NumDipoleComponents(kk));
                
            otherwise
                error('BST_INVERSE > Unknown Source Orientation')
        end
        
        % L2norm of Wq in everycase above is 1, (even for loose, since L2 norm
        % of matrix is largest singular value of the matrix).
        
        Wq{i} = Alpha{kk}(i)*Wq{i}; % now weight by desired amplifier
        
        % So L2 norm of Wq is equal to the desired amplifier (if any).
    end
    
    
    
    %% ===== PROCESSING LEAD FIELD MATRICES, WEIGHTS & ORIENTATIONS =====
    
    % put all covariance priors into one big sparse matrix
    WQ{kk} = blkdiag(sparse(Wq{1}),Wq{2:end});
    % (by making first element sparse, we force Matlab to use efficient sparse
    % mex function)
    
    % With the above defined, then the whitened lead field matrix is simply
    
    L{kk} = iW_noise * (HeadModel(kk).Gain * WQ{kk});  % if LCMV, this is data whitened.
    
    % we note that the number of columns of the ith source is found as the number of
    % corresponding columns in WQ{i}. In this version (March 2016), we still
    % assume equal numbers of columns (1 or 3). The Mixed Head Model may
    % contain mixed quantities.
    %
    
    
    % The model at this point is d = {A}{x} + n, where d and n are whitened,
    % and x has a covariance prior of unity times unknown lambda (= sigma q 2)
    
    % Every NumDipoleComponents(kk) columns of L is a source, which we call A
    
    % (We could optimize this to only do when needed, but it's not too
    % expensive in any event, taking less than two seconds for 15000 dipoles)
    
    % Decompose for each source
    
    clear A
    A(1:NumDipoles(kk)) = deal(struct('Ua',[],'Sa',[],'Va',[]));
    
    % Not used in min norm methods
    if strcmpi(OPTIONS.InverseMethod,'gls') || strcmpi(OPTIONS.InverseMethod,'lcmv')
        tic % let's time it
        for i = 1:NumDipoles(kk)
            % index to next source in the lead field matrix
            ndx = ((1-NumDipoleComponents(kk)):0) + i*NumDipoleComponents(kk);
            [Ua,Sa,Va] = svd(L{kk}(:,ndx),'econ');
            Sad = diag(Sa); % strip to vector
            
            tol = length(Sad) * eps(single(Sad(1))); % single precision tolerance
            Rank_Dipole = sum(Sad > tol);
            
            % Trim or not to the rank of the model.
            switch 'notrim'
                case 'trim' % trim each source model to just the non-zero
                    A(i).Ua = Ua(:,1:Rank_Dipole);
                    A(i).Sa = Sad(1:Rank_Dipole);
                    A(i).Va = Va(:,1:Rank_Dipole);
                case 'notrim'
                    % don't trim each source model, but do force small singular values to perfectly zero
                    Sad((Rank_Dipole+1):end) = 0; % force to perfect zeros
                    A(i).Ua = Ua;
                    A(i).Sa = Sad;
                    A(i).Va = Va;
            end % switch
            
        end
        fprintf('BST_INVERSE > Time to decompose is %.1f seconds\n',toc);
        % So L = [A.Ua]*blkdiag(A.Sa)*blkdiag(A.Va)'; % good for any subset too.
    end
    

end % for each headmodel

% So now we have a cell array of leadfield models. Let's concatenate

L = [L{:}];

% Now do a global decomposition for setting SNR and doing min norms
% Won't need the expensive VL of the SVD, and UL is relatively small.

[UL,SL2] = svd((L*L'));
SL2 = diag(SL2);
SL = sqrt(SL2); % the singular values of the lead field matrix
tol = length(SL)*eps(single(SL(1))); % single precision tolerance
Rank_Leadfield = sum(SL > tol);
fprintf('BST_INVERSE > Rank of leadfield matrix is %.0f out of %.0f components\n',Rank_Leadfield,length(SL));
% but don't trim to rank, we use full matrix below



%% =========== SNR METHODS ================

% Recall our source covariance prior is Cx = Lamda * I, where we have already
% factored out the dipolar covariance, Cq = alpha2 * Lambda * Wq * Wq';
%
% We use the SNR settings to establish a prior on the source variance,
% which is in turn used as essentially a regularizer in the inverse
% methods.
%
% This may seem backwards, i.e. the signal variance with respect
% to the noise variance establishes the SNR, but in inverse processing, we
% may do this backwards, setting an SNR in order to regularize, depending
% on the selection below.


% Calculate Lambda multiplier to achieve desired SNR

switch (OPTIONS.SnrMethod)
    case 'rms'
        % user had directly specified the variance
        Lambda =  OPTIONS.SnrRms^2;
        SNR = Lambda * SL2(1); % the assumed SNR for the entire leadfield
    case 'fixed'
        % user had given a desired SNR, set lambda of the Grammian to achieve it
        SNR = OPTIONS.SnrFixed^2;
        
        % several options here. Hamalainen prefers the average eigenvalue
        % of the Grammian. Mosher would prefer the maximum (norm) for other
        % consistency measures, however user's have become accustomed to
        % the Hamalainen measure.
        
        % Maximum (matrix norm):
        % Lambda = SNR/(SL(1)^2); % thus SL2(1)*Lambda = desired SNR.
        
        % Hamalainen definition of SNR in the min norm:
        Lambda = SNR/mean(SL.^2); % should be equalivent to Matti's average eigenvalue definition
        
    otherwise
        error(['BST_INVERSE > Not supported yet: NoiseMethod="' OPTIONS.SnrMethod '"']);
end

fprintf('BST_INVERSE > Confirm units\n')
if exist('engunits', 'file')
    [LambdaY,ignore,LambdaU] = engunits(sqrt(Lambda));
    fprintf('BST_INVERSE > Assumed RMS of the sources is %.3g %sA-m\n',LambdaY,LambdaU);
else
    fprintf('BST_INVERSE > Assumed RMS of the sources is %g A-m\n', sqrt(Lambda));
end
fprintf('BST_INVERSE > Assumed SNR is %.1f (%.1f dB)\n',SNR,10*log10(SNR));


%% ===== INVERSE METHODS =====
% Generate first the inversions (current dipole time series)
switch lower(OPTIONS.InverseMethod) % {minnorm, lcmv, gls}
    case 'minnorm'
        
      % We set a single lambda to achieve desired source variance. In min
      % norm, all dipoles have the same lambda. We already added an
      % optional amplifier weighting into the covariance prior above.

      % So the data covariance model in the MNE is now
      % Cd = Lambda * L * L' + I
      % = Lambda *UL * SL * UL' + I = UL * (LAMBDA*SL + I) * UL'
      % so invert Cd and use for kernel
      % xhat = Lambda * L' * inv(Cd)
      % we reapply all of the covariances to put data back in original
      % space in the last step.

      % as distinct from GLS, all dipoles have a common data covariance,
      % but each has a unique noise covariance.

      % ==== April 2019 ==== Comment by JCM & JGP
      % Next line's 'Kernel' is equal to T of eq.(11) in (PM, 2002).
      % Reference: (PM, 2002) - Standardized low resolution brain electromagnetic
      %             tomography (sLORETA): technical details, Pasqual-Marqui, 2002.
        Kernel = Lambda * L' * (UL * diag(1./(Lambda * SL2 + 1)) * UL');

        switch OPTIONS.InverseMeasure % {'amplitude',  'dspm2018', 'sloreta'}
            case 'amplitude'
                OPTIONS.FunctionName = 'mn';
                % xhat = Lambda * L' * inv(Cd)
                % Kernel = Lambda * L' * inv(Lambda * L * L' + eye(size(L,1))) * iW_noise;
                
                % apply whitener
                Kernel = Kernel * iW_noise;
                
            case 'dspm2018'
                OPTIONS.FunctionName = 'dspm2018';
                % ===== dSPM OPERATOR =====
                % =========== NEEDS REWRITING by JCM ======
                
                
                % xhat = Lambda * L' * inv(Cd)
                % Kernel = Lambda * L' * inv(Lambda * L * L' + eye(size(L,1))) * iW_noise;
                
                
                % now we need to break out each head model with possibly
                % varying numbers of dipole components
                
                
                StartNdx = 0; % initialize
                for kk = 1:numL
                    % Next block of components in the head model
                    StartNdx = StartNdx + 1;
                    EndNdx = StartNdx + (NumDipoleComponents(kk) * NumDipoles(kk)) - 1;
                    Ndx = StartNdx:EndNdx;
                    
                    dspmdiag = sum(Kernel(Ndx,:).^2, 2);
                    
                    if (NumDipoleComponents(kk) == 1)
                        dspmdiag = sqrt(dspmdiag);
                    elseif (NumDipoleComponents(kk)==3 || NumDipoleComponents(kk)==2)
                        dspmdiag = reshape(dspmdiag, NumDipoleComponents(kk),[]);
                        dspmdiag = sqrt(sum(dspmdiag,1)); % Taking trace and sqrt.
                        dspmdiag = repmat(dspmdiag, [NumDipoleComponents(kk), 1]);
                        dspmdiag = dspmdiag(:);
                    end
                    
                    Kernel(Ndx,:) = bst_bsxfun(@rdivide, Kernel(Ndx,:), dspmdiag);
                    
                    StartNdx = EndNdx; % next loop
                    
                end
                
                Kernel = Kernel * iW_noise; % overall whitener
                
                
            case 'sloreta'
                OPTIONS.FunctionName = 'sloreta';
                
                % calculate the standard min norm solution Kernel
                
                % until I fix multiple head models
                
                %                 if (NumDipoleComponents(kk) == 1)
                %                     sloretadiag = sqrt(sum(Kernel(start:endd,:) .* L(:,start:endd)', 2));
                %                     Kernel(start:endd,:) = bst_bsxfun(@rdivide, Kernel(start:endd,:), sloretadiag);
                %                 elseif (NumDipoleComponents(kk)==3 || NumDipoleComponents(kk)==2)
                %                     for spoint = start:NumDipoleComponents(kk):endd
                %                         R = Kernel(spoint:spoint+NumDipoleComponents(kk)-1,:) * L(:,spoint:spoint+NumDipoleComponents(kk)-1);
                %                         SIR = sqrtm(pinv(R));
                %                         Kernel(spoint:spoint+NumDipoleComponents(kk)-1,:) = SIR * Kernel(spoint:spoint+NumDipoleComponents(kk)-1,:);
                %                     end
                %                 end
                
                % now we need to break out each head model with possibly
                % varying numbers of dipole components
                
                StartNdx = 0; % initialize
                for kk = 1:numL
                    % Next block of components in the head model
                    StartNdx = StartNdx + 1;
                    EndNdx = StartNdx + (NumDipoleComponents(kk) * NumDipoles(kk)) - 1;
                    Ndx = StartNdx:EndNdx;
                    
                    if (NumDipoleComponents(kk) == 1)
                        % 'sloretadiag' is the 'Resolution Kernel' for the
                        % scalar case of eq.(17) of the sLORETA paper (PM, 2002)
                        sloretadiag = sqrt(sum(Kernel(Ndx,:) .* L(:,Ndx)', 2));
                      
                        % This results in the modified pseudo-statistic of
                        % eq.(25) of (PM, 2002).
                        Kernel(Ndx,:) = bst_bsxfun(@rdivide, Kernel(Ndx,:), sloretadiag);
                    elseif (NumDipoleComponents(kk)==3 || NumDipoleComponents(kk)==2)
                        for spoint = StartNdx:NumDipoleComponents(kk):EndNdx
                            % For each dipole location 'R' is the matrix
                            % resolution kernel, following eq.(17) in (PM, 2002).
                            R = Kernel(spoint:spoint+NumDipoleComponents(kk)-1,:) * L(:,spoint:spoint+NumDipoleComponents(kk)-1);
                            % SIR = sqrtm(pinv(R)); % Aug 2016 can lead to errors if
                            % singular Use this more explicit form instead
                            [Ur,Sr,Vr] = svd(R); Sr = diag(Sr);
                            RNK = sum(Sr > (length(Sr) * eps(single(Sr(1))))); % single precision Rank
                            % SIR is the square root matrix operator of 
                            % eq.(25) in (PM, 2002).
                            SIR = Vr(:,1:RNK) * diag(1./sqrt(Sr(1:RNK))) * Ur(:,1:RNK)'; % square root of inverse
                            
                            % Kernel is the matrix modified
                            % pseudo-statistic of eq.(25) in (PM,2002).
                            Kernel(spoint:spoint+NumDipoleComponents(kk)-1,:) = SIR * Kernel(spoint:spoint+NumDipoleComponents(kk)-1,:);
                        end
                    end
                    
                    StartNdx = EndNdx; % next loop

                end
                %We here add the overall whitener so Kernel can be applied
                %to RAW data.
                Kernel = Kernel * iW_noise; % overall whitener
                
            otherwise
                error('Unknown Option Inverse Measure: %s',OPTIONS.InverseMeasure)
                
        end
        
        
        
    case {'gls','lcmv'}
        
        % In generalized least-squares, each dipolar source may have a
        % unique lambda, to achieve the desired SNR. So unlike min norm, we
        % may need to set lambda for each and every dipole.
        
        % However, as a prior, this seems counter-intuitive, since it would
        % mean adjusting the variance of deep sources to be much greater
        % (and therefore less reqularized) than shallower sources.
        
        % So in this version, JCM opted to set one global source variance, as in min norm.
        
        % Note that each Wq may already contain a desired amplifier for the
        % gain matrix of that source. That's okay.
        
        % As distinct from minimum norm, every dipole has the exact same
        % noise covariance assumption.
        
        % Neyman-Pearson Performance
        if strcmpi(OPTIONS.InverseMethod, 'gls')
            OPTIONS.FunctionName = 'glsp';
        else
            OPTIONS.FunctionName = 'lcmvp';
        end
        
        Kernel = zeros(size(L')); % preallocate
        
        for i = 1:NumDipoles(kk)
            ndx = ((1-NumDipoleComponents(kk)):0) + i*NumDipoleComponents(kk);
            %Kernel(ndx,:) =  A(i).Va*(Lambda*A(i).Sa)*inv(Lambda*A(i).Sa + I)*A(i).Ua';
            Kernel(ndx,:) =  A(i).Ua';
        end
        Kernel = Kernel * iW_noise; % final noise whitening
        
    otherwise
        error('BST> Unknown inverse method: %s',OPTIONS.InverseMethod)
        
end



%% ===== ASSIGN IMAGING KERNEL =====
% Multiply inverse operator and whitening matrix, so no need to whiten data.
% premultiply by covariance priors to put back into original domain

% Now the Kernel has been designed for the number of dipole components.
% Ordinarily, to convert back to three d, we would use
% Kernel = WQ * Kernel, which puts all one-d answers back in three-d. But
% that's not optimal for storage. We do need, however, to account for the
% possible Alpha increase in the storage.


% Key assumption is that the source prior is norm 1, as designed in the
% beginning of this program.
if strcmpi(OPTIONS.InverseMeasure, 'amplitude')
    StartNdx = 0; % initialize
    for kk = 1:numL
        % Next block of components in the head model
        StartNdx = StartNdx + 1;
        EndNdx = StartNdx + (NumDipoleComponents(kk) * NumDipoles(kk)) - 1;
        Ndx = StartNdx:EndNdx;
        
        % we need to put orientation and weighting back into solution
        if NumDipoleComponents(kk) == 3 % we are in three-d,
            Kernel(Ndx,:) = WQ{kk} * Kernel(Ndx,:); % put the source prior back into the solution
        elseif NumDipoleComponents(kk) == 1
            Kernel(Ndx,:) = spdiags(Alpha{kk}',0,length(Ndx),length(Ndx))*Kernel(Ndx,:);  % put possible alpha weighting back in
        end
        
        StartNdx = EndNdx; % next loop

    end
    

end

% now orient the dipoles, if requested
% Orientation Optimization is now done in the "dipole scanning" process
% applied to the performance measure.
GridOrient = [];

% Return results structure
Results.ImagingKernel = Kernel;
Results.GridOrient    = GridOrient; % either empty or optimized
Results.ImageGridAmp  = [];
Results.Whitener      = iW_noise; % full noise covariance whitener
if strcmpi(OPTIONS.InverseMethod, 'lcmv')
    % in the lcmv case, we used the data covariance as the whitener for
    % programming simplicity
    Results.Whitener = iW_noise_true; % the true noise whitener, unused in the case of LCMV, but may be useful in post processing
end
Results.DataWhitener  = iW_data;  % full data covariance whitener, null unless lcmv

if numL == 1
    Results.nComponents   = NumDipoleComponents(1);
else
    Results.nComponents   = 0; % flag that mixed model is being used
end


% clear SourceDecomp % decomposition products of the sources
% % don't need Ua, it was already included in the ImagingKernel
% % Need the other components for reconstructing the source orientation and
% % amplitude
% [SourceDecomp(1:length(A))] = deal(struct('Sa',[],'Va',[]));
%
% for i =1:length(A),
%     SourceDecomp(i).Sa = diag(A(i).Sa); % let's be efficient and store as vector
%     SourceDecomp(i).Va = A(i).Va;
% end
%
% Results.SourceDecomp = SourceDecomp;

% More storage efficient:
Results.SourceDecompVa = [A.Va];
Results.SourceDecompSa = [A.Sa];


end


%% ==============================================================================
%  ===== HELPER FUNCTIONS =======================================================
%  ==============================================================================

%% =========== Covariance Truncation and Regularization
function [Cov,iW] = truncate_and_regularize_covariance(Cov,Method,Type,NoiseReg,FourthMoment,nSamples)
% Cov is the covariance matrix, to be regularized using Method
% Type is the sensor type for display purposes
% NoiseReg is the regularization fraction, if Method "reg" selected
% FourthMoment and nSamples are used if Method "shrinkage" selected

VERBOSE = true; % be talkative about what's happening

% Ensure symmetry
Cov = (Cov + Cov')/2;

% Note,impossible to be complex by above symmetry check
% Decompose just this covariance.
[Un,Sn2] = svd(Cov,'econ');
Sn = sqrt(diag(Sn2)); % singular values
tol = length(Sn) * eps(single(Sn(1))); % single precision tolerance
Rank_Noise = sum(Sn > tol);

if VERBOSE
    fprintf('BST_INVERSE > Rank of the ''%s'' channels, keeping %.0f noise eigenvalues out of %.0f original set\n',...
        Type,Rank_Noise,length(Sn));
end

Un = Un(:,1:Rank_Noise);
Sn = Sn(1:Rank_Noise);

% now rebuild the noise covariance matrix with just the non-zero
% components
Cov = Un*diag(Sn.^2)*Un'; % possibly deficient matrix now

% With this modality truncated, see if we need any additional
% regularizations, and build the inverse whitener

if VERBOSE
    fprintf('BST_INVERSE > Using the ''%s'' method of covariance regularization.\n',Method);
end

switch(Method) % {'shrink', 'reg', 'diag', 'none', 'median'}
    
    case 'none'
        %  "none" in Regularization means no
        % regularization was applied to the computed Noise Covariance
        % Matrix
        % Do Nothing to Cw_noise
        iW = Un*diag(1./Sn)*Un'; % inverse whitener
        if VERBOSE
            fprintf('BST_INVERSE > No regularization applied to covariance matrix.\n');
        end
        
        
    case 'median'
        if VERBOSE
            fprintf('BST_INVERSE > Covariance regularized by flattening tail of eigenvalues spectrum to the median value of %.1e\n',median(Sn));
        end
        Sn = max(Sn,median(Sn)); % removes deficient small values
        Cov = Un*diag(Sn.^2)*Un'; % rebuild again.
        iW = Un*diag(1./Sn)*Un'; % inverse whitener
        
    case 'diag'
        Cov = diag(diag(Cov)); % strip to diagonal
        iW = diag(1./sqrt(diag(Cov))); % inverse of diagonal
        if VERBOSE
            fprintf('BST_INVERSE > Covariance matrix reduced to diagonal.\n');
        end
        
    case 'reg'
        % The unit of "Regularize Noise Covariance" is as a percentage of
        % the mean variance of the modality.
                
        % Ridge Regression:
        % Commented out Feb 2018 in favor of the mean eigenvalue, to align
        % with Hamalainen.
        % RidgeFactor = Sn2(1) * NoiseReg ; % percentage of max.
        % Use instead this one:
        RidgeFactor = mean(diag(Sn2)) * NoiseReg; % Hamalainen's preferred measure
        %(Note, the mean of the eigenvalues is the mean of the diagonal
        %values).
        
        Cov = Cov + RidgeFactor * eye(size(Cov,1));
        % wrong: iW = Un*diag(1./(Sn + sqrt(RidgeFactor)))*Un'; % inverse whitener
        % Fixed Feb 2018:
        iW = Un*diag(1./sqrt(Sn.^2 + RidgeFactor))*Un'; % inverse whitener, symmetric
        
        if VERBOSE
            fprintf('BST_INVERSE > Diagonal of %.1f%% of the average eigenvalue added to covariance matrix.\n',NoiseReg * 100);
        end
        
        
    case 'shrink'
        % Method of Ledoit, recommended by Alexandre Gramfort
        
        % Need to scale the Fourth Moment for the modalities
       
        % use modified version of cov1para attached to this function
        % TODO, can we adjust this routine to handle different numbers of
        % samples in the generation of the fourth order moments
        % calculation? As of August 2016, still relying on a single scalar
        % number.
        [Cov,shrinkage]=cov1para_local(Cov,FourthMoment,nSamples);
        if VERBOSE
            fprintf('\nShrinkage factor is %f\n\n',shrinkage)
        end
        % we now have the "shrunk" whitened noise covariance
        % Recalculate
        [Un,Sn2] = svd(Cov,'econ');
        Sn = sqrt(diag(Sn2)); % singular values
        tol = length(Sn) * eps(single(Sn(1))); % single precision tolerance
        Rank_Noise = sum(Sn > tol);
        
        if VERBOSE
            fprintf('BST_INVERSE > Ledoit covariance regularization, after shrinkage, rank of the %s channels, keeping %.0f noise eigenvalues out of %.0f original set\n',...
                Type,Rank_Noise,length(Sn));
        end
        
        Un = Un(:,1:Rank_Noise);
        Sn = Sn(1:Rank_Noise);
        
        % now rebuild the noise covariance matrix with just the non-zero
        % components
        Cov = Un*diag(Sn.^2)*Un'; % possibly deficient matrix now
        
        iW = Un*diag(1./Sn)*Un'; % inverse whitener
        
        
    otherwise
        error(['BST_INVERSE > Unknown covariance regularization method: NoiseMethod="' Method '"']);
        
end % method of regularization


% Note the design of full rotating whiteners. We don't expect dramatic reductions in
% rank here, and it's convenient to rotate back to the original space.
% Note that these whitener matrices may not be of full rank.

end
%% ======== Ledoit Shrinkage
% Modified to use the precalculated stats

function [sNoiseCov,shrinkage]=cov1para_local(NoiseCov,FourthMoment,nSamples)
% Based on Ledoit's "cov1para" with some modifications
%   x is t x n, returns
%   sigma n x n
%
% shrinkage is the final computed shrinkage factor, used to weight the
%  i.i.d. prior vs the sample estimate. If shrinkage is specified, it is
%  used on input; else, it's computed.

% Original code from
% http://www.ledoit.net/cov1para.m
% Original Ledoit comments:
% function sigma=cov1para(x)
% x (t*n): t iid observations on n random variables
% sigma (n*n): invertible covariance matrix estimator
%
% Shrinks towards one-parameter matrix:
%    all variances are the same
%    all covariances are zero
% if shrink is specified, then this const. is used for shrinkage

% Based on
% http://www.ledoit.net/ole1_abstract.htm
% http://www.ledoit.net/ole1a.pdf (PDF of paper)
%
% A Well-Conditioned Estimator for Large-Dimensional Covariance Matrices
% Olivier Ledoit and Michael Wolf
% Journal of Multivariate Analysis, Volume 88, Issue 2, February 2004, pages 365-411
%
% Abstract
% Many economic problems require a covariance matrix estimator that is not
% only invertible, but also well-conditioned (that is, inverting it does
% not amplify estimation error). For large-dimensional covariance matrices,
% the usual estimator - the sample covariance matrix - is typically not
% well-conditioned and may not even be invertible. This paper introduces an
% estimator that is both well-conditioned and more accurate than the sample
% covariance matrix asymptotically. This estimator is distribution-free and
% has a simple explicit formula that is easy to compute and interpret. It
% is the asymptotically optimal convex combination of the sample covariance
% matrix with the identity matrix. Optimality is meant with respect to a
% quadratic loss function, asymptotically as the number of observations and
% the number of variables go to infinity together. Extensive Monte-Carlo
% confirm that the asymptotic results tend to hold well in finite sample.


% Original Code Header, updated to be now from (2014)
% http://www.econ.uzh.ch/faculty/wolf/publications/cov1para.m.zip
%
% x (t*n): t iid observations on n random variables
% sigma (n*n): invertible covariance matrix estimator
%
% Shrinks towards constant correlation matrix
% if shrink is specified, then this constant is used for shrinkage
%
% The notation follows Ledoit and Wolf (2003, 2004)
% This version 04/2014
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file is released under the BSD 2-clause license.
%
% Copyright (c) 2014, Olivier Ledoit and Michael Wolf
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
%
% 1. Redistributions of source code must retain the above copyright notice,
% this list of conditions and the following disclaimer.
%
% 2. Redistributions in binary form must reproduce the above copyright
% notice, this list of conditions and the following disclaimer in the
% documentation and/or other materials provided with the distribution.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
% IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
% THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
% PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
% CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
% EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
% PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
% PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
% LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
% SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Wolf's site now,
% http://www.econ.uzh.ch/faculty/wolf/publications/cov1para.m.zip
% some differences from original Ledoit that confirm Mosher's
% original re-coding.

% % de-mean returns
% [t,n]=size(x);
% meanx=mean(x);
% x=x-meanx(ones(t,1),:);

% compute sample covariance matrix
% Provided
% NoiseCov=(1/t).*(x'*x);

% compute prior
n=size(NoiseCov,1); % number of channels
meanvar=mean(diag(NoiseCov));
prior=meanvar*eye(n); % Note, should be near identity by our pre-whitening

% what we call p
%y=x.^2;
%phiMat=y'*y/t - NoiseCov.^2;
phiMat = FourthMoment - NoiseCov.^2;
phi=sum(sum(phiMat));

% what we call r is not needed for this shrinkage target

% what we call c
gamma=norm(NoiseCov-prior,'fro')^2;

% compute shrinkage constant
kappa=phi/gamma;
% ensure bounded between zero and one
shrinkage=max(0,min(1,kappa/nSamples));

% compute shrinkage estimator
sNoiseCov=shrinkage*prior+(1-shrinkage)*NoiseCov;

end



