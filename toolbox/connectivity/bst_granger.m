function [connectivity, pValue, connectivityV, pValueV, X, Y] = bst_granger(X, Y, order, inputs)
% BST_GRANGER       Granger causality in mean and variance between any two
%                   signals, using two Wald statistics
%                   in mean: regular log-GC from Geweke1982
%                   in variance: information statistic from Hafner2007
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
%   |-lag         - maximum lag in ARCH model for causality in variance
%   |               [S: nonnegative integer]
%   |-flagELM     - if true, optimize order for ARCH model
%   |               if false (default), force same order in all ARCH models
%   |               [L: default false]
%   |-rho         - ADMM parameter from augmented Lagrangian
%   |               --> lower means faster but at cost of stability
%   |               --> higher means convergence but at cost of speed
%   |               --> 50 is a good starting point
%   |               [R: nonnegative number, default = 50]
%
% Outputs:
%   connectivity  - A x B matrix of causalities in mean from source to sink
%                   [C: MX x MY matrix]
%   pValue        - parametric p-value for corresponding Granger causality in
%                   mean estimate
%                   [P: MX x MY matrix]
%   connectivityV - A x B matrix of causalities in variance from source to sink
%                   [CV: MX x MY matrix]
%   pValueV       - parametric p-value for corresponding Granger causality in
%                   variance estimate
%                   [PV: MX x MY matrix]
%
% See also BST_MVAR, BST_VGARCH.
%
% For each signal pair (a,b) we calculate the Granger causality in mean GC(a,b):
%                        Var(x_a[t] | x_a[t-1, ..., t-k])         
%              ----------------------------------------------------
%              Var(x_a[t] | x_a[t-1, ..., t-k], y_b[t-1, ..., t-k])
% If Y is empty or Y = X, we set element GC(a,a) to be zero.
% 
% If inputs.lag is set, then for each signal pair (a,b) we calculate the Wald
% statistic EC(a,b) testing whether C_{a,b} = 0 where
%       x[n] = A[1] x[n-1] + ... + A[P] x[n-P] + e[n]
%       e[n] ~ normal with mean 0 and covariance H[n]
%       H[n] = W*W' + sum_{r=1}^{inputs.lag} C_r' * e[n-r] * e[n-r]' * C_r
% If Y is empty or Y = X, we set element EC(a,a) to be zero.
% 
% Call:
%   [inMean, inVariance] = bst_granger(X, Y, 5, inputs);
%   [inMean, inVariance] = bst_granger(X, [], 5, inputs); % every pair in X
%   [inMean, inVariance] = bst_granger(X, [], 20, inputs); % more delays in AR
%   inputs.nTrials = 10; % use trial-averaged covariances in AR estimation
%   inputs.standardize = true; % zero mean and unit variance
%   inputs.flagFPE = true; % allow different orders for each pair of signals
%   inputs.lag = 3; % estimate causality in variance using lag-3 ARCH model
%   inputs.flagELM = true; % find the optimal lag rather than always given lag
%   inputs.rho = 50; % parameter to tune estimation of ARCH model
%                    % higher -> more stability, much slower
%                    % lower -> might not converge, much faster
%                    % go in multiples of 5 up or down as desired
%                    % 50 is a good start for rho

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
% Authors: Sergul Aydore & Syed Ashrafulla, 2012

% default: 1 trial
if ~isfield(inputs, 'nTrials') || isempty(inputs.nTrials)
  inputs.nTrials = 1;
end

% default: do not optimize order in MVAR modeling
if ~isfield(inputs, 'flagFPE') || isempty(inputs.flagFPE)
  inputs.flagFPE = false;
end

% default: do not optimize order in MVAR modeling
if ~isfield(inputs, 'flagELM') || isempty(inputs.flagELM)
  inputs.flagELM = false;
end

% default: ADMM works well with rho = 50
if ~isfield(inputs, 'rho') || isempty(inputs.rho)
  inputs.rho = 50;
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

% for causality in mean we need the restricted variance
restOrder = zeros(nX, 1); restCovFull = zeros(nX, order+1);
for iX = 1:nX
  [syed, syed, restOrder(iX), syed, syed, restCovFull(iX, :)] = bst_mvar(X(iX, :), order, inputs.nTrials, inputs.flagFPE); %#ok<ASGLU>
end

if isempty(Y) % auto-causality
  
  % setup
  connectivity = zeros(nX);
  connectivityV = zeros(nX);
  
  % only iterate over one triangle
  for iX = 1:nX
    
    % iterate over all the pairs after iX
    for iY = (iX+1):nX
      
      % bivariate autoregressive model with sink_a and sink_b
      [syed, syed, unOrder, syed, syed, unCovFull, residual] = bst_mvar([X(iX, :); X(iY, :)], order, inputs.nTrials, inputs.flagFPE); %#ok<ASGLU>
      
      % causality in mean: Geweke-Granger, i.e. restricted variance / unrestricted variance - 1
      if inputs.flagFPE % get the minimum order of the two models estimated
        
        % source = iY, sink = iX
        minOrder = min([restOrder(iX) unOrder]); 
        connectivity(iX, iY) = restCovFull(iX, minOrder+1) / unCovFull(1, 1, minOrder+1) - 1;
        
        % source = iX, sink = iY
        minOrder = min([restOrder(iY) unOrder]);
        connectivity(iY, iX) = restCovFull(iY, minOrder+1) / unCovFull(2, 2, minOrder+1) - 1;
        
      else % by default, bst_mvar sends the result of the single model of given order into the "Full" variables
        
        connectivity(iX, iY) = restCovFull(iX) / unCovFull(1, 1) - 1; % source = iY, sink = iX
        connectivity(iY, iX) = restCovFull(iY) / unCovFull(2, 2) - 1; % source = iX, sink = iY
        
      end
      
      % causality in variance
      if isfield(inputs, 'lag') && inputs.lag > 0 && any(abs(residual(1, :) - residual(2, :)) > eps)

        % preprocess the residual first
        residual = bst_bsxfun(@rdivide, residual, std(residual, [], 2));
          
        % bivariate ARCH estimation
        [W, C, D, R, S, information, rhoBest] = ... % bivariate ARCH modeling
          bst_vgarch('vec', residual, inputs.nTrials, inputs.lag, 0, inputs.flagELM, 3, 'on', 999, [], inputs.rho, false, [], [], [], []); %#ok<ASGLU>

        % use SQP if ADMM failed (found by an exploding augmentation parameter rho)
        if rhoBest > 10 * inputs.rho || any(isinf(information(:)))
          try % SQP may fail too because the data is nonstationary; rho will be -1 if it succeeds, indicating ADMM did not work
            [W, C, D, R, S, information] = ... % bivariate ARCH modeling
              bst_vgarch('vec', residual, inputs.nTrials, inputs.lag, 0, inputs.flagELM, 2, 'off', 999, [], [], false, [], [], [], []); %#ok<ASGLU>
          catch ME %#ok<NASGU> % this data kills ADMM & SQP so we assume no causality in variance
            W = bst_correlation(residual, [], struct('normalize', false, 'nTrials', 1, 'maxDelay', 0, 'nDelay', 1, 'flagStatistics', false)); % W is covariance
            C = zeros(2*(2+1)/2, 2*(2+1)/2*inputs.lag); information = eye(2*2 + 2*(2+1)/2*2*(2+1)/2*inputs.lag); % and all the vARCH parameters are zero
          end
        end

        % Wald statistic
        theta = [W(:); C(:); D(:)]; % stack into parameter vector
        covariance = inv(information); % estimated covariance matrix
        J = sort([7 + 9*(0:inputs.lag-1) 10 + 9*(0:inputs.lag-1)]); % indices corresponding to elements C_{r,12} and C_{r,13} for all lags r in vARCH model
        connectivityV(iX, iY) =   theta(J)' / covariance(  J,  J) *   theta(J); % source -> sink: use C_{12}=7, C_{13}=10 & add 9 for the other lags
        connectivityV(iY, iX) = theta(J-1)' / covariance(J-1,J-1) * theta(J-1); % sink -> source: use C_{32}=9, C_{31}=6 & add 9 for the other lags

      end
      
    end
    
    % diagonal will equal the maximum of all inflows and outflows for iX
    connectivity(iX, iX) = max([connectivity(iX, :) connectivity(:, iX)']);
    
  end
  
else % cross-causality
  
  % setup
  connectivity = zeros(nX, nY);
  connectivityV = zeros(nX, nY);
  duplicates = zeros(0, 2);
  
  for iX = 1:nX
    for iY = 1:nY
      
      if any(abs(X(iX, :) - Y(iY, :)) > eps) % avoid duplicates
      
        % bivariate autoregressive model with sink_a and source_b
        [syed, syed, unOrder, syed, syed, unCovFull, residual] = bst_mvar([X(iX, :); Y(iY, :)], order, inputs.nTrials, inputs.flagFPE); %#ok<ASGLU>

        % causality in mean: Geweke-Granger, i.e. restricted variance / unrestricted variance - 1
        if inputs.flagFPE % get the minimum order of the two models estimated
          minOrder = min([restOrder(iX) unOrder]); 
          connectivity(iX, iY) = restCovFull(iX, minOrder+1) / unCovFull(1, 1, minOrder+1) - 1;
        else % by default, bst_mvar sends the result of the single model of given order into the "Full" variables
          connectivity(iX, iY) = restCovFull(iX) / unCovFull(1, 1) - 1;
        end

        % causality in variance
        if isfield(inputs, 'lag') && inputs.lag > 0 && any(abs(residual(1, :) - residual(2, :)) > eps)
          
          % preprocess the residual first
          residual = bst_bsxfun(@rdivide, residual, std(residual, [], 2));

          % bivariate ARCH estimation
          [W, C, D, R, S, information, rhoBest] = ... % bivariate ARCH modeling
            bst_vgarch('vec', residual, inputs.nTrials, inputs.lag, 0, inputs.flagELM, 3, 'on', 999, [], inputs.rho, false, [], [], [], []); %#ok<ASGLU>

          % use SQP if ADMM failed (found by an exploding augmentation parameter rho)
          if rhoBest > 10 * inputs.rho || any(isinf(information(:)))
            try % SQP may fail too because the data is nonstationary; rho will be -1 if it succeeds, indicating ADMM did not work
              [W, C, D, R, S, information] = ... % bivariate ARCH modeling
                bst_vgarch('vec', residual, inputs.nTrials, inputs.lag, 0, inputs.flagELM, 2, 'off', 999, [], [], false, [], [], [], []); %#ok<ASGLU>
            catch ME %#ok<NASGU> % this data kills ADMM & SQP so we assume no causality in variance
              W = bst_correlation(residual, [], struct('normalize', false, 'nTrials', 1, 'maxDelay', 0, 'nDelay', 1, 'flagStatistics', false)); % W is covariance
              C = zeros(2*(2+1)/2, 2*(2+1)/2*inputs.lag); information = eye(2*2 + 2*(2+1)/2*2*(2+1)/2*inputs.lag); % and all the vARCH parameters are zero
            end
          end

          % Wald statistic
          theta = [W(:); C(:); D(:)]; % stack into parameter vector
          covariance = inv(information); % estimated covariance matrix
          J = sort([7 + 9*(0:R-1) 10 + 9*(0:R-1)]); % indices corresponding to elements C_{r,12} and C_{r,13} for all lags r in vARCH model
          connectivityV(iX, iY) =   theta(J)' / covariance(  J,  J) *   theta(J); % source -> sink: use C_{12}=7, C_{13}=10 & add 9 for the other lags
          
        end
        
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

% causality in mean: F statistic of connectivity when multiplied by number of regressors
pValue = 1 - betainc(connectivity ./ (1 + connectivity), order / 2, (nSamples - order * inputs.nTrials - 2 * order - 1) / 2, 'lower');
% here we assume we have many more samples than the order of the MVAR model so that in all cases we use the second condition below to compute the p-value
% note: if connectivity = 0 (auto-causality or two of the same signals) then this formula evalutes pValue = 1 which is desired (no significant causality)
  
% causality in mean: F statistic of connectivity when multiplied by number of regressors
% tic
% iFlip = nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1 > connectivity * order;
% pValue = zeros(size(connectivity));
% pValue(~iFlip) = 1 - betainc(1 ./ (1 + connectivity(~iFlip)), (nSamples - order(~iFlip) * inputs.nTrials - 2 * order(~iFlip) - 1) / 2, order(~iFlip) / 2, 'upper');
% pValue(iFlip) = 1 - betainc(connectivity(iFlip) ./ (1 + connectivity(iFlip)), order(iFlip) / 2, (nSamples - order(iFlip) * inputs.nTrials - 2 * order(iFlip) - 1) / 2, 'lower');
% toc
% % fcdf(connectivity .* (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) ./ order, order, nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1)
% % which for nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1 <= connectivity * order is
% % = betainc((nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) ./ (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1 + connectivity * (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) / order * order), (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) / 2, order/2, 'upper')
% % = betainc((nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) ./ ((nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) .* (1 + connectivity)), (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) / 2, order/2, 'upper')
% % = betainc(1 ./ (1 + connectivity), (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) / 2, order/2, 'upper')
% % and for nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1 >= connectivity * order is
% % = betainc(connectivity .* (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) ./ order .* order ./ (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1 + connectivity .* (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) ./ order .* order), order/2, (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) / 2, 'lower')
% % = betainc(connectivity .* (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) ./ ((nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) .* (1 + connectivity)), order/2, (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) / 2, 'lower')
% % = betainc(connectivity ./ (1 + connectivity), order/2, (nSamples - order(~iFlip) * inputs.nTrials - 2 * order - 1) / 2, 'lower')

% causality in mean: chi-square statistic of connectivity when multiplied by the number of samples
% tic
% pValue = 1 - gammainc(connectivity * (nSamples - order * inputs.nTrials) / 2, order / 2);
% toc
% % chi2cdf(connectivity * (nSamples - order * inputs.nTrials), order)
% % = gamcdf(connectivity * (nSamples - order * inputs.nTrials), order/2, 2)
% % = gammainc(connectivity * (nSamples - order * inputs.nTrials) / 2, order / 2)

% causality in variance: chi-square statistic of connectivity when multiplied by number of samples (minus lag minus 1) to get chi-square statistic
pValueV = 1 - gammainc(connectivityV .* (nSamples - order * inputs.nTrials - inputs.lag - 1) / 2, inputs.lag);
% chi2cdf(connectivityV .* (nSamples - order * inputs.nTrials - inputs.lag - 1), 2 * inputs.lag)
% = gamcdf(connectivityV .* (nSamples - order * inputs.nTrials - inputs.lag - 1), (2 * inputs.lag)/2 = inputs.lag, 2)
% = gammainc(connectivityV .* (nSamples - order * inputs.nTrials - inputs.lag - 1) / 2, inputs.lag)
% note: if connectivityV = 0 (auto-causality or two of the same signals) then this formula evalutes pValueV = 1 which is desired (no significant causality)
