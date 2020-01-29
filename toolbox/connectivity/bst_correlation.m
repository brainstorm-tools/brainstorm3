function [connectivity, pValues, delays] = bst_correlation(X, Y, cfg)
% BST_CORRELATION   Calculate the covariance OR correlation between two multivariate signals, assuming any drift has been removed.
%
% Inputs:
%   X                 - First set of signals, one signal per row
%                       [X: A x N matrix]
%   Y                 - Second set of signals, one signal per row
%                       [Y: B x N matrix]
%                       (default: Y = X)
%   cfg             - Struct of parameters:
%   |-normalize       - If true, output correlation
%   |                   If false (default), output covariance
%   |                   [F: boolean]
%   |-nTrials         - Number of trials in data
%   |                   [T: nonnegative integer]
%   |                   (default: 1)
%   |-maxDelay        - Maximum delay desired in cross-covariance
%   |                   [D: nonnegative integer]
%   |                   (default: 0)
%   |-nDelay          - # of delays to skip in each iteration
%   |                   [T: positive integer]
%   |                   (default: 1)
%   |-flagStatistics  - Type of parametric model to apply to absolute value of correlation
%   |                   0: Use t-statistic and then look up p-value for standard normal (default)
%   |                                                         |correlation|
%   |                           statistic = sqrt(N-2) * ------------------------
%   |                                                   sqrt(1 - correlation.^2)
%   |                   1: Use Fisher's Z transform and then look up p-value for standard normal
%   |                                                   1    1 + |correlation|
%   |                           statistic = sqrt(N-3) * - ln -----------------
%   |                                                   2    1 - |correlation|
%
% Outputs:
%   connectivity      - Matrix of covariance (correlation) values. (i,j) is the covariance (correlation) of X_i & Y_j.
%                       [C: A x B x ND matrix]
%   pValues           - Matrix of p-values for correlation. (i,j) is the p-value of the magnitude of correlation between X_i & Y_j.
%                       [P: A x B x ND matrix in (0.5, 1)]
%   delays            - Delays corresponding to each time-lagged cross-correlation in the previous output. Given D and T, the delays are
%                       [-D -D+T -D+2T ... -2T -T 0 T 2T ... D-2T D-T D]
%                       [V: ND x 1 vector]
%
% Call:
%   connectivity = bst_correlation(X, Y); % default
%   connectivity = bst_correlation(X, Y, cfg); % customized
% Parameter examples:
%   cfg.normalize      = false; % Covariance instead of correlation
%   cfg.maxDelay       = 30; % Get covariances for lags -30, -29, ..., -29, 30
%   cfg.nDelay         = 30; % Get covariances for lags -30, -27, ..., -27, 30
%   cfg.flagStatistics = 0; % Use t-statistic because it better models the Monte Carlo distribution of correlation.

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


%% Setup

if ~exist('cfg','var')
  cfg=[];
end

% Number of timepoints
nTimes = size(X,2);

% Default: 1 trial
if ~isfield(cfg, 'nTrials')
    cfg.nTrials = 1;
end

% Default: no delayed cross-correlation
if ~isfield(cfg, 'maxDelay')
    cfg.maxDelay = 0;
end

% Default: capture every desired delay
if ~isfield(cfg, 'nDelay')
    cfg.nDelay = 1;
end

if ~isfield(cfg, 'flagStatistic')
    cfg.flagStatistic = 0;
end

%% Correlation or covariance?
if isfield(cfg, 'normalize') && cfg.normalize
    X = bst_bsxfun(@minus, X, mean(X, 2)); % Zero mean
    stdX = sqrt(sum(X.*conj(X), 2) / (nTimes - 1));
    X = bst_bsxfun(@rdivide, X(stdX > 0, :), stdX(stdX > 0)); % Unit standard deviation
    
    if ~isempty(Y)
        Y = bst_bsxfun(@minus, Y, mean(Y, 2)); % Zero mean
        stdY = sqrt(sum(Y.*conj(Y), 2) / (nTimes - 1));
        Y = bst_bsxfun(@rdivide, Y(stdY > 0, :), stdY(stdY > 0)); % Same for the other side unless it is X (to reduce computation time)
    end
else
    cfg.normalize = false;
end

%% Connectivity measure

nSteps = floor(cfg.maxDelay/cfg.nDelay);
delays = (-nSteps:nSteps)*cfg.nDelay;

if isempty(Y) % autocovariance so only have to do half the work
    
    % preallocate
    connectivity = zeros(size(X,1), size(X,1), 2*nSteps+1);
    
    % == Delay = 0: E{X[n] Y^H[n]} ==
    connectivity(:, :, nSteps+1) = X*X' / (size(X,2) - 1);
    
    for idxStep = 1:nSteps
        
        % == Delay > 0: E{X[n] X^H[n+k]} ==
        delay = delays(nSteps+1 + idxStep);
        if cfg.nTrials > 1
            % The trials are stacked across horizontally. So, to get timepoints delay+1, ..., N for each trial, we use bst_trial_idx
            % In addition, we only want to use timepoints with no NaNs. So, we remove all trial-specific indices that have NaNs.
            xDelay = X(:, bst_trial_idx(1:(nTimes-delay), nTimes, cfg.nTrials));
            yDelay = X(:, bst_trial_idx((delay+1):nTimes, nTimes, cfg.nTrials));
        else
            % There is only 1 trial, so we just remove timepoints with no NaNs. For many calls, the function overhead is steep without this specific T = 1 case.
            xDelay = X(:, 1:(end-delay));
            yDelay = X(:, (delay+1):end);
        end
        
        % Covariance: at delay -k, we have E{X[n] X^H[n+(-k)]} = E{X[n+k] X^H[n]} = ( E{X[n] X^H[n+k]} )^H to reduce the computation time
        connectivity(:, :, nSteps+1 + idxStep) = xDelay * yDelay'/ (nTimes-delay - 1);
        connectivity(:, :, idxStep) = connectivity(:, :, nSteps+1 + idxStep)';
        
    end
    
else % covariance between X and Y requires two data changes for each delay
    
    % preallocate
    connectivity = zeros(size(X,1), size(Y,1), 2*nSteps+1);
    
    % == Delay = 0: E{X[n] Y^H[n]} ==
    connectivity(:, :, nSteps+1) = X*Y' / (size(X,2) - 1);
    
    for idxStep = 1:nSteps
        
        % == Delay < 0: E{X[n] Y[n+(-k)]^H} = E{X[n+k] Y^H[n]} ==
        delay = -delays(idxStep);
        if cfg.nTrials > 1
            % The trials are stacked across horizontally. So, to get timepoints delay+1, ..., N for each trial, we use bst_trial_idx
            % In addition, we only want to use timepoints with no NaNs. So, we remove all trial-specific indices that have NaNs.
            xDelay = X(:, bst_trial_idx((delay+1):nTimes, nTimes, cfg.nTrials));
            yDelay = Y(:, bst_trial_idx(1:(nTimes-delay), nTimes, cfg.nTrials));
        else
            % There is only 1 trial, so we just remove timepoints with no NaNs. For many calls, the function overhead is steep without this specific T = 1 case.
            xDelay = X(:, (delay+1):nTimes);
            yDelay = Y(:, 1:(end-delay));
        end
        
        % zero mean and normalize xDelay and yDelay        
        
        xDelay = bst_bsxfun(@minus, xDelay, mean(xDelay, 2)); % Zero mean
        stdXdelay = sqrt(sum(xDelay.*conj(xDelay), 2) / (nTimes-delay - 1));
        xDelay = bst_bsxfun(@rdivide, xDelay(stdXdelay > 0, :), stdXdelay(stdXdelay > 0)); % Unit standard deviation
        
        yDelay = bst_bsxfun(@minus, yDelay, mean(yDelay, 2)); % Zero mean
        stdYdelay = sqrt(sum(yDelay.*conj(yDelay), 2) / (nTimes-delay - 1));
        yDelay = bst_bsxfun(@rdivide, yDelay(stdYdelay > 0, :), stdYdelay(stdYdelay > 0)); % Unit standard deviation
        
        
        % Covariance
        connectivity(:, :, idxStep) = xDelay * yDelay'/ (nTimes-delay - 1);
        
        % == Delay > 0: E{X[n] Y^H[n+k]} ==
        delay = delays(nSteps+1 + idxStep);
        if cfg.nTrials > 1
            % The trials are stacked across horizontally. So, to get timepoints delay+1, ..., N for each trial, we use bst_trial_idx
            % In addition, we only want to use timepoints with no NaNs. So, we remove all trial-specific indices that have NaNs.
            xDelay = X(:, bst_trial_idx(1:(nTimes-delay), nTimes, cfg.nTrials));
            yDelay = Y(:, bst_trial_idx((delay+1):nTimes, nTimes, cfg.nTrials));
        else
            % There is only 1 trial, so we just remove timepoints with no NaNs. For many calls, the function overhead is steep without this specific T = 1 case.
            xDelay = X(:, 1:(end-delay));
            yDelay = Y(:, (delay+1):end);
        end
        
        % zero mean and normalize xDelay and yDelay        
        
        xDelay = bst_bsxfun(@minus, xDelay, mean(xDelay, 2)); % Zero mean
        stdXdelay = sqrt(sum(xDelay.*conj(xDelay), 2) / (nTimes-delay - 1));
        xDelay = bst_bsxfun(@rdivide, xDelay(stdXdelay > 0, :), stdXdelay(stdXdelay > 0)); % Unit standard deviation
        
        yDelay = bst_bsxfun(@minus, yDelay, mean(yDelay, 2)); % Zero mean
        stdYdelay = sqrt(sum(yDelay.*conj(yDelay), 2) / (nTimes-delay - 1));
        yDelay = bst_bsxfun(@rdivide, yDelay(stdYdelay > 0, :), stdYdelay(stdYdelay > 0)); % Unit standard deviation
        
        % Covariance
        connectivity(:, :, nSteps+1 + idxStep) = xDelay * yDelay'/ (nTimes-delay - 1);
        
    end
    
end

%% Statistics
pValues = zeros(size(connectivity));
if cfg.normalize && cfg.flagStatistics % If true, use Fisher's Z transform and Gaussian with zero mean, variance N-3
    pValues(abs(connectivity) < 1-eps) = 1 - 1/2 * erfc( -1 * ...
        (1/2 * log((1 + abs(connectivity(abs(connectivity) < 1-eps))) ./ (1 - abs(connectivity(abs(connectivity) < 1-eps))))) ... % test statistic
        * sqrt(nTimes - 3) ... % standard deviation
        / sqrt(2));
elseif cfg.normalize % If false, use t-test and standard Gaussian
    pValues(abs(connectivity) < 1-eps) = 1 - 1/2 * erfc( -1 * ...
        (abs(connectivity(abs(connectivity) < 1-eps)) ./ sqrt(1 - abs(connectivity(abs(connectivity) < 1-eps)).^2) * sqrt(nTimes - 2)) ... % test statistic
        / sqrt(2)); % the stdev is 1 so no need to add it
else
    pValues = NaN;
end

end %% <== FUNCTION END
