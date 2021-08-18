function [connectivity, pValue] = bst_granger(X, Y, order, inputs)
% BST_GRANGER       Granger causality  between any two signals, 
%                   using two Wald statistics
%
% Inputs:
%   sinks         - first set of signals, one signal per row
%                   [X: MX x N or MX x N x T matrix]
%   sources       - second set of signals, one signal per row
%                   [Y: MY x N or MY x N x T matrix]
%                   (default: Y = X)
%   order         - maximum lag in AR model for causality in mean
%                   [p: nonnegative integer]
%   inputs        - structure of parameters:
%   |-nTrials     - # of trials in concantenated signal
%   |               [T: positive integer]
%   |-standardize - if true (default), remove mean from each signal.
%   |               if false, assume signal has already been detrended
%   |-flagFPE     - if true, optimize order for AR model
%   |               if false (default), force same order in all AR models
%   |               [E: default false]
%
% Outputs:
%   connectivity  - A x B matrix of causalities from source to sink
%                   [C: MX x MY matrix]
%   pValue        - parametric p-value for corresponding Granger causality estimate
%                   [P: MX x MY matrix]
% 
% See also BST_MVAR
%
% For each signal pair (a,b) we calculate the Granger causality:
% 
%                       det(restricted_residuals_cov_matrix)        
%         gc =   ----------------------------------------------------
%                             det(full_cov_matrix)
%
% see Cohen, Dror, et al. "A general spectral decomposition of causal influences
% applied to integrated information." and Barret, Barnett and Seth "Multivariate 
% Granger causality and generalized variance".
%
% Call:
%   connectivity = bst_granger(X, Y, 5, inputs);
%   connectivity = bst_granger(X, [], 5, inputs); % every pair in X
%   connectivity = bst_granger(X, [], 20, inputs); % more delays in AR
%   inputs.nTrials = 10; % use trial-averaged covariances in AR estimation
%   inputs.standardize = true; % zero mean and unit variance
%   inputs.flagFPE = true; % allow different orders for each pair of signals

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
% Authors: Sergul Aydore & Syed Ashrafulla, 2012
% Modified by: Davide Nuzzi, 2021

% default: 1 trial
if ~isfield(inputs, 'nTrials') || isempty(inputs.nTrials)
  inputs.nTrials = 1;
end

% default: do not optimize order in MVAR modeling
if ~isfield(inputs, 'flagFPE') || isempty(inputs.flagFPE)
  inputs.flagFPE = false;
end

% dimensions of the signals
nX = size(X, 1);
if ndims(X) == 3
  inputs.nTrials = size(X,3);
  X = reshape(X, nX, []);
end
nSamples = size(X, 2);
nTimes = nSamples / inputs.nTrials;

% if we are doing auto-causality, empty Y so that we only look at X
if ~isempty(Y)
  nY = size(Y, 1);
  Y = reshape(Y, nY, []);
end

% remove linear effects if desired
if isfield(inputs, 'standardize') && inputs.standardize
  detrender = [ ...
    ones(1, nTimes); ... % constant trend in data
    linspace(-1, 1, nTimes); ... % linear trend in data
    3/2 * linspace(-1, 1, nTimes).^2 - 1/2 ... % quadratic trend in data
  ];
  
  % detrend X
  for iTrial = 1:inputs.nTrials
    X(:, (iTrial-1)*nTimes + (1:nTimes)) = X(:, (iTrial-1)*nTimes + (1:nTimes)) - ( X(:, (iTrial-1)*nTimes + (1:nTimes)) / detrender ) * detrender;
    X(:, (iTrial-1)*nTimes + (1:nTimes)) = diag( sqrt(sum(X(:, (iTrial-1)*nTimes + (1:nTimes)).^2, 2)) ) \ X(:, (iTrial-1)*nTimes + (1:nTimes));
  end
  
  % detrend Y only if it is not empty
  if ~isempty(Y)
    for iTrial = 1:inputs.nTrials
      Y(:, (iTrial-1)*nTimes + (1:nTimes)) = Y(:, (iTrial-1)*nTimes + (1:nTimes)) - ( Y(:, (iTrial-1)*nTimes + (1:nTimes)) / detrender ) * detrender;
      Y(:, (iTrial-1)*nTimes + (1:nTimes)) = diag( sqrt(sum(Y(:, (iTrial-1)*nTimes + (1:nTimes)).^2, 2)) ) \ Y(:, (iTrial-1)*nTimes + (1:nTimes));
    end
  end
end

%% Iterate over all pairs of sinks & sources

if isempty(Y) % auto-causality
  
  % setup
  connectivity = zeros(nX);
  
  % only iterate over one triangle
  for iX = 1:nX
    
    % iterate over all the pairs after iX
    for iY = (iX+1):nX
      
        % two-variate model
        [transfers, noiseCovariance, order] = bst_mvar([X(iX, :); X(iY, :)], order, inputs.nTrials, inputs.flagFPE);

        % data correlations using Yule-Walker (up to high order 50)
        R = yule_walker_inverse(transfers, noiseCovariance, 50);

        % restricted model iY -> iX
        
        % mask for the coefficients of the restricted model
        mask = ones(2);
        mask(1,2) = 0;
        
        % restricted bivariate model (using masked row-by-row solution of
        % YW equations)
        [transfers_restricted,noiseCovariance_restricted] = yule_walker_mask(R, mask);
      
        % connectivity
        connectivity(iX, iY) = log(det(noiseCovariance_restricted) ./ det(noiseCovariance));
        
        % restricted model iX -> iY

        % mask for the coefficients of the restricted model
        mask = ones(2);
        mask(2,1) = 0;
        
        % restricted bivariate model (using masked row-by-row solution of
        % YW equations)
        [transfers_restricted,noiseCovariance_restricted] = yule_walker_mask(R, mask);
      
        % connectivity
        connectivity(iY, iX) = log(det(noiseCovariance_restricted) ./ det(noiseCovariance));    
    end
    
    % diagonal will equal the maximum of all inflows and outflows for iX
    connectivity(iX, iX) = max([connectivity(iX, :) connectivity(:, iX)']);
    
  end
  
else % cross-causality
  
  % setup
  connectivity = zeros(nX, nY);
  duplicates = zeros(0, 2);
  
  for iX = 1:nX
    for iY = 1:nY
      
      if any(abs(X(iX, :) - Y(iY, :)) > eps) % avoid duplicates
      
        % two-variate model 
        [transfers, noiseCovariance, order] = bst_mvar([X(iX, :); Y(iY, :)], order, inputs.nTrials, inputs.flagFPE);
              
        % data correlations using Yule-Walker (up to high order 50)
        R = yule_walker_inverse(transfers, noiseCovariance, 50);

        % mask for the coefficients of the restricted model
        mask = ones(2);
        mask(1,2) = 0;
        
        % restricted bivariate model (using masked row-by-row solution of YW equations)
        [transfers_restricted,noiseCovariance_restricted] = yule_walker_mask(R, mask);
       
        % connectivity   
        connectivity(iX, iY) = log(det(noiseCovariance_restricted) ./ det(noiseCovariance));       
        
      else % save duplicates to modify later
        
        duplicates(end+1, :) = [iX iY]; %#ok<AGROW>
        
      end
      
    end
  end
  
  % for duplicate indices, set the causality value to the maximum over all inflows for iX and outflows for iY
  for iDuplicate = 1:size(duplicates, 1)
    connectivity(duplicates(iDuplicate, 1), duplicates(iDuplicate, 2)) = ...
      max([connectivity(duplicates(iDuplicate, 1), :) connectivity(:, duplicates(iDuplicate, 2))']);
  end
  
end

%% Statistics: parametric p-values for causality in mean (based on regression coefficients) and variance (based on Wald statistics)

% F statistic of connectivity when multiplied by number of regressors
pValue = 1 - betainc(connectivity ./ (1 + connectivity), order / 2, (nSamples - order * inputs.nTrials - 2 * order - 1) / 2, 'lower');
% here we assume we have many more samples than the order of the MVAR model so that in all cases we use the second condition below to compute the p-value
% note: if connectivity = 0 (auto-causality or two of the same signals) then this formula evalutes pValue = 1 which is desired (no significant causality)
  