function [transfer, err, p, residual, transferFull, errFull, residualFull, fpe, aic, hq, sc] = bst_mvar(signals, order, nTrials, flagFPE)
% BST_MVAR     Estimate multivariate autoregressive coefficients for multiple delays using one of a few chosen algorithms.
%
% INPUTS:
%   signals            - Matrix where each row vector is a timeseries
%                        If 2D, M x N where M = # of signals & N = # of samples
%                        If 3D, M x N x nTrials where nTrials = # of trials
%   order              - Maximum model order
%   nTrials            - Number of trials if sources is a 2D matrix
%   flagFPE            - If true, optimize model order to valley of FPE
%                        If false, go to full order
%
% OUTPUT:
%   transfer           - Estimated transfer matrices
%   err                - remaining error variance as a function of order
%                        If flagFPE = true, err is a stack of the covariances from order = 0 to order = optimal
%   p                  - optimal order after using final prediction error
%   residual           - residuals from MVAR fitting
%   transferFull       - If flagFPE = true, list of transfer estimations for order 1, 2, ..., order
%   errFull            - If flagFPE = true, list of error covariances for order 1, 2, ..., order
%   residualFull       - If flagFPE = true, list of residuals for order 1, 2, ..., order
%   fpe                - Final prediction error [2]
%                        If flagFPE = true, fpe is a vector for the measurement from 0 to order
%   aic                - Akaike information criterion [2]
%                        If flagFPE = true, aic is a vector for the measurement from 0 to order
%   hq                 - Hannan-Quinn criterion [2]
%                        If flagFPE = true, hq is a vector for the measurement from 0 to order
%   sc                 - Schwartz (or Bayesian information) criterion [2]
%                        If flagFPE = true, sc is a vector for the measurement from 0 to order
%
% REFERENCES:
%  [1] de Waele, S., & Broersen, P. M. T. (2003). Order selection for vector autoregressive models. IEEE Transactions on Signal Processing, 51(2), 427-433.
%       doi:10.1109/TSP.2002.806905
%  [2] Franaszczuk, P. J., Blinowska, K. J., & Kowalczyk, M. (1985). The application of parametric multichannel spectral estimates in the study of electrical
%      brain activity. Biological Cybernetics, 51(4), 239-247.
%       doi:10.1007/BF00337149
% 
% Courtesy of Alois Schl\"{o}gl and his Time Series Analysis toolbox now implemented in BioSig (http://biosig.sourceforge.net/)
%
% Call:
%   [transfer, err, p, residual, transferFull, errFull, residualFull, fpe, aic, hq, sc] = bst_mvar(sources, order, nTrials, flagFPE)

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


%% Preprocessing

% Dimension sizes for preallocation
nSignals = size(signals, 1);
nSamples = size(signals, 2);
nTimes = round(nSamples / nTrials);

% Trial indices specific to this instance
flagMultiple = (nTrials > 1);
if flagMultiple
  trial_idx = @(a) bst_trial_idx(a, nTimes, nTrials);
else % Send empty array so bst_mvar_transfer knows not to call a fcn
  trial_idx = [];
end


%% Iterate over order
if flagFPE
  
  % Pre-allocate
  transferFull = zeros(nSignals, nSignals*order, order+1);
  errFull = zeros(nSignals, nSignals, order+1); 
  residualFull = zeros(nSignals, (nTimes-order)*nTrials, order+1);
  fpe = zeros(order+1, 1); % Final prediction error
  aic = zeros(order+1, 1); % Akaike information criterion
  hq = zeros(order+1, 1); % Hannan-Quinn criterion
  sc = zeros(order+1, 1); % Schwarz criterion (also known as Bayesian information criterion)
  covarianceInputs = struct('normalize', false, 'nTrials', nTrials, 'maxDelay', 0, 'nDelay', 1, 'flagStatistics', false); % to calculate residual covariances

  % Initialize
  % transferFull(:,:,1) = 0; % Start: order zero AR -> no AR matrices
  errFull(:,:,1)      = bst_correlation(signals, signals, covarianceInputs); % Start: order zero AR -> error is covariance of sources
  errSize             = log(det(errFull(:,:,1)));
  fpe(1)              = errSize + log((nTimes + 1)/(nTimes - 1)) * nSignals; % Start: order zero AR -> total sources variance with bias correction
  aic(1)              = errSize; % Start: order zero AR -> total sources variance
  hq(1)               = errSize; % Start: order zero AR -> total sources variance
  sc(1)               = errSize; % Start: order zero AR -> total sources variance
  
  % Components of Yule-Walker estimation
  if flagMultiple % Multiple trials
    
    % Present
    present = signals(:, trial_idx((order+1):nTimes));
    
    % Past
    past = zeros(nSignals*order, size(present,2));
    for p = 1:order % Concatenated the lags along ROWS
      past((p-1)*nSignals + (1:nSignals), :) = signals(:, trial_idx(((order+1):nTimes)-p));
    end
    
  else % Single trial
    
    % Present
    present = signals(:, (order+1):nTimes);
    
    % Past
    past = zeros(nSignals*order, nTimes-order);
    for p = 1:order % Concatenated the lags along ROWS
      past((p-1)*nSignals + (1:nSignals), :) = signals(:, ((order+1):nTimes)-p);
    end
    
  end
  
  % Estimate for each order
  residualFull(:,:,1) = present; % Start: order zero AR -> residual is the signal itself
  for p = 1:order

    % Yule-Walker
    transferFull(:, 1:(nSignals*p), p+1) = present / past(1:(nSignals*p), :); % Coefficients
    residualFull(:, :, p+1) = present - transferFull(:, 1:(nSignals*p), p+1)*past(1:(nSignals*p), :);
    errFull(:, :, p+1) = bst_correlation(residualFull(:, :, p+1), residualFull(:, :, p+1), covarianceInputs); % Error in fit
      
    % Different order selection criteria
    T = nTimes - p;
    errSize   = log(det(errFull(:, :, p+1)));
    fpe(p+1)  = errSize + log((T + nSignals * p + 1)/(T - nSignals * p - 1)) * nSignals; % Final prediction error: Akaike1969, Lutkepohl2006(p. 147) -- I took the log of the formula to look consistent with everything else
    aic(p+1)  = errSize + 2 / T * p * nSignals^2; % Akaike information criterion: Akaike1973, Akaike1974, Lutkepohl2006(p.147)
    hq(p+1)   = errSize + 2 * log(log(T))/T * p * nSignals^2; % Hannan-Quinn criterion: Hannan1979, Quinn1980, Lutkepohl2006(p.150)
    sc(p+1)   = errSize + log(T)/T * p * nSignals^2; % Schwarz criterion (also Bayesian information criterion): Schwarz1978, Lutkepohl2006(p. 150)
    
  end
  
  % Find optimal order as minimum of final prediction error
  % I find the optimal order as the point at which the change in the curve is small (that is, the curve levels off) with respect to the first, large change.
  p = find(diff(fpe) ./ min(diff(fpe)) < 0.01, 1, 'first');
%   p = find(abs((fpe - min(fpe)) ./ fpe) < 0.01, 1, 'first');
  if isempty(p)
    p = order;
  end
  transfer = transferFull(:, (1:(nSignals*p)), p+1);
  err = errFull(:, :, p+1);
  residual = residualFull(:, :, p+1);
  
%% Optimal order known
else
  
  % Components of Yule-Walker estimation
  if flagMultiple % Multiple trials

    % Present
    present = signals(:, trial_idx((order+1):nTimes));
    
    % Past
    past = zeros(nSignals*order, size(present,2));
    for p = 1:order % Concatenated the lags along ROWS
      past((p-1)*nSignals + (1:nSignals), :) = signals(:, trial_idx(((order+1):nTimes)-p));
    end
    
  else % Single trial
    
    % Present
    present = signals(:, (order+1):nTimes);
    
    % Past
    past = zeros(nSignals*order, nTimes-order);
    for p = 1:order % Concatenated the lags along ROWS
      past((p-1)*nSignals + (1:nSignals), :) = signals(:, ((order+1):nTimes)-p);
    end
    
  end

  % Yule-Walker
  transfer = present / past;
  residual = present - transfer*past;
  err = bst_correlation(residual, residual, struct('normalize', false, 'nTrials', nTrials, 'maxDelay', 0, 'nDelay', 1, 'flagStatistics', false)); % Error in fit
  
  % Different order selection criteria
  p = order;
  T = nTimes - p;
  fpe = log(det(err)) + log((T + nSignals * p + 1)/(T - nSignals * p - 1)) * nSignals; % Final prediction error: Akaike1969, Lutkepohl2006(p. 147) -- I took the log of the formula to look consistent with everything else
  aic = log(det(err)) + 2 / T * p * nSignals^2; % Akaike information criterion: Akaike1973, Akaike1974, Lutkepohl2006(p.147)
  hq = log(det(err)) + 2 * log(log(T))/T * p * nSignals^2; % Hannan-Quinn criterion: Hannan1979, Quinn1980, Lutkepohl2006(p.150)
  sc = log(det(err)) + log(T)/T * p * nSignals^2; % Schwarz criterion (also Bayesian information criterion): Schwarz1978, Lutkepohl2006(p. 150)
  
  % Last argument
  transferFull = transfer;
  errFull = err;
  residualFull = residual;
  
end

end

%% ======================================================================== Yule-Walker ========================================================================
% function [transfer, err] = bst_mvar_yule(sources, order, nTimes, trial_idx, iterative)
% % BST_MVAR_YULE         Estimate multivariate autoregressive coefficients for multiple delays using the Yule-Walker estimation.
% %
% % INPUTS:
% %   sources           - Matrix where each row vector is a timeseries
% %                       If 2D, M x N where M = # of signals & N = # of samples
% %                       If 3D, M x N x nTrials where nTrials = # of trials
% %   order             - Maximum model order
% %   nTimes            - Number of timepoints in each trial
% %   trial_idx         - Function for trial indices (default: empty - 1 trial)
% %   iterative         - If true, find estimates for all orders up to order
% %                       If false (default), only find estimate for order
% %
% % OUTPUT:
% %   transfer          - Estimated transfer matrices
% %   err               - remaining error variance as a function of order
% %                       If flagFPE = true, err is a vector for the variance from order = 0 to order = optimal
% %
% % Call:
% %   [transfer, err] = bst_mvar(sources, order, nTrials)
% 
% %% Setup
% nSignals = size(sources,1);
% flagMultiple = ~isempty(trial_idx);
% 
% %% Estimation
% 
% if iterative % Find all orders
%   
%   % Initialize
%   transfer = cell(order+1, 1);
%   err = cell(order+2, 1); err{1} = bst_correlation(sources);
%   
%   % Estimate for each order
%   for p = 1:(order+1)
%     
%     % Present
%     if flagMultiple
%       present = sources(:, trial_idx((order+1):nTimes));
%     else
%       present = sources(:, (order+1):nTimes);
%     end
% 
%     % Past
%     if flagMultiple
%       past = zeros(nSignals*order, size(present,2));
%       for p = 1:order % Concatenated the lags along ROWS
%         past((p-1)*nSignals + (1:nSignals), :) = sources(:, trial_idx(((order+1):nTimes)-p));
%       end
%     else
%       past = zeros(nSignals*order, nTimes-order);
%       for p = 1:order % Concatenated the lags along ROWS
%         past((p-1)*nSignals + (1:nSignals), :) = sources(:, ((order+1):nTimes)-p);
%       end
%     end
% 
%     % Yule-Walker
%     transfer{p} = present / past;
%     err{p+1} = bst_correlation(present - transfer*past); % Error in fit
%       
%   end
% 
% else % Find only order desired
%   
%   % Present
%   if flagMultiple
%     present = sources(:, trial_idx((order+1):nTimes));
%   else
%     present = sources(:, (order+1):nTimes);
%   end
% 
%   % Past
%   if flagMultiple
%     past = zeros(nSignals*order, size(present,2));
%     for p = 1:order % Concatenated the lags along ROWS
%       past((p-1)*nSignals + (1:nSignals), :) = sources(:, trial_idx(((order+1):nTimes)-p));
%     end
%   else
%     past = zeros(nSignals*order, nTimes-order);
%     for p = 1:order % Concatenated the lags along ROWS
%       past((p-1)*nSignals + (1:nSignals), :) = sources(:, ((order+1):nTimes)-p);
%     end
%   end
% 
%   % Yule-Walker
%   transfer = present / past;
%   err = bst_correlation(present - transfer*past); % Error in fit
%   
% end
% 
% end

%% ============================================================ Modified Vieira-Morf (deWaele2003) =============================================================
% function [transfer, PE] = bst_mvar_vieira(sources, order, nTimes, trial_idx, iterative)
% % BST_MVAR_VIEIRA   Estimate multivariate autoregressive coefficients for multiple delays using the Vieira-Morf algorithm [1] with biased covariance estimation.
% %
% % INPUTS:
% %   sources       - Matrix where each row vector is a timeseries
% %                   If 2D, M x N where M = # of signals & N = # of samples
% %                   If 3D, M x N x nTrials where nTrials = # of trials
% %   order       - Maximum model order
% %   nTimes        - Number of timepoints in each trial
% %   trial_idx     - Function for trial indices (default: empty - 1 trial)
% %   iterative     - If true, find estimates for all orders up to order
% %                   If false (default), only find estimate for order
% %
% % OUTPUT:
% %   transfer      - Estimated transfer matrices
% %   err           - remaining error variance as a function of order
% %                   If flagFPE = true, err is a vector for the variance from order = 0 to order = optimal
% %   aic           - Akaike Information Criterion measurement
% %                   If flagFPE = true, aic is a vector for the measurement from order = 0 to order = optimal
% %
% % REFERENCES:
% %  [1] de Waele, S., & Broersen, P. M. T. (2003). Order selection for vector autoregressive models. IEEE Transactions on Signal Processing, 51(2), 427-433.
% %       doi:10.1109/TSP.2002.806905
% % 
% % Courtesy of Alois Schl\"{o}gl and his Time Series Analysis toolbox now implemented in BioSig (http://biosig.sourceforge.net/)
% %
% % Call:
% %   [transfer, err] = bst_mvar(sources, order, nTrials) 
% 
% %% Setup
% nSignals = size(sources,1);
% 
% % Default: 1 trial so # of timepoints is length of segment
% if ~exist('nTimes', 'var') || isempty(nTimes)
%   nTimes = size(sources,2);
% end
% 
% % Default: 1 trial so trial_idx fcn is empty
% if ~exist('trial_idx', 'var') || isempty(trial_idx)
%   trial_idx = [];
%   flagMultiple = false;
% else
%   flagMultiple = true;
% end
% 
% % Default: only want the coefficients at the maximum order
% if ~exist('iterative', 'var') || isempty(iterative)
%   iterative = false;
% end
% 
% if iterative
%   transfer = cell(order,1);
% end
% 
% ARF = zeros(nSignals, order*nSignals);
% ARB = zeros(nSignals, order*nSignals);
% RCF = zeros(nSignals, order*nSignals);
% RCB = zeros(nSignals, order*nSignals);
% PE = zeros(nSignals, (order+1)*nSignals);
% PE(:, 1:nSignals) = bst_correlation(sources);
% 
% F = sources; B = sources;
% if flagMultiple
%   PEF = bst_correlation(sources(:, trial_idx(2:nTimes)));
%   PEB = bst_correlation(sources(:, trial_idx(1:nTimes-1)));
% else
%   PEF = bst_correlation(sources(:, 2:nTimes));
%   PEB = bst_correlation(sources(:, 1:nTimes-1));
% end
% 
% %% Iteration
% for p = 1:order
% 
%   % Indices for blocks and delayed time windows
%   block = p * nSignals + (1-nSignals:0);
%   if flagMultiple
%     timeF = trial_idx(p+1:nTimes); timeB = trial_idx(1:(nTimes-p));
%   else
%     timeF = p+1:nTimes; timeB = 1:(nTimes-p);
%   end
% 
%   % Update the estimated error covariances ((15.89) in [1])
%   PEFhat = bst_correlation(F(:, timeF));
%   PEBhat = bst_correlation(B(:, timeB));
%   PEFBhat = bst_correlation(F(:, timeF), B(:, timeB));
% 
%   % Compute estimated normalized partial correlation matrix ((15.88) in [1])
%   Rho = (chol(PEFhat)') \ (PEFBhat / chol(PEBhat));
% 
%   % Update forward and backward reflection coefficients ((15.82) and (15.83) in [1])
%   ARF(:, block) = chol(PEF)' * (Rho / (chol(PEB)'));
%   ARB(:, block) = chol(PEB)' * (Rho' / (chol(PEF)'));
% 
%   % Update forward and backward residuals
%   syed        = F(:, timeF) - ARF(:, block) * B(:, timeB);
%   B(:, timeB) = B(:, timeB) - ARB(:, block) * F(:, timeF);
%   F(:, timeF) = syed;
% 
%   % Update previous-order AR coefficients
%   for q = 1:p-1
% 
%     blockLF = q*nSignals+(1-nSignals:0);
%     blockLB = (p-q)*nSignals+(1-nSignals:0);
% 
%     syed            = ARF(:, blockLF) - ARF(:, block) * ARB(:, blockLB);
%     ARB(:, blockLB) = ARB(:, blockLB) - ARB(:, block) * ARF(:, blockLF);
%     ARF(:, blockLF) = syed;
% 
%   end
% 
%   % New reflection coefficients
%   RCF(:, block) = ARF(:, block);
%   RCB(:, block) = ARB(:, block);
% 
%   % Update forward and backward error covariances ((15.75) and (15.76) in [1])
%   PEF = (eye(nSignals) - ARF(:, block) * ARB(:, block)) * PEF;
%   PEB = (eye(nSignals) - ARB(:, block) * ARF(:, block)) * PEB;
% 
%   % Store latest error covariance estiamte
%   PE(:, p*nSignals + (1:nSignals)) = PEF;
% 
%   % If we want coefficients for each order, save them!
%   if iterative
%     transfer{p} = ARF(:, 1:(p*nSignals));
%   end
% 
% end
% 
% %% If we only want the end coefficients, send those back
% if ~iterative
%   transfer = ARF;
% end
%   
% end