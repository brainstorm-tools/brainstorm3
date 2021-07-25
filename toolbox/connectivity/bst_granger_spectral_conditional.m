function [connectivity, pValues, freq] = bst_granger_spectral_conditional(X, Y, Fs, order, inputs)
% BST_GRANGER_SPECTRAL_CONDITIONAL  Granger causality at each frequency between any two
%                                   signals, conditioned on all the remaining signals
%
% Inputs:
%   X                 - first set of signals, one signal per row
%                       [X: A x N or A x N x T matrix]
%   Y                 - second set of signals, one signal per row
%                       [Y: B x N or B x N x T matrix]
%                       (default: Y = X)
%   Fs                - sampling rate (we assume uniform sampling rate)
%                       [FS: scalar, FS > freq(end)*2]
%   order             - maximum order of autogressive model
%                       [p: integer > 1, default 10]
%   inputs            - structure of parameters:
%   |-freq            - frequencies of interest if desired
%   |-freqResolution  - maximum freq resolution in Hz, to limit NFFT
%   |                   [DF: double, default [] (i.e. no limit)]
%   |-nTrials         - # of trials in concantenated signal
%   |-flagFPE         - if true, optimize order for autoregression
%   |                   if false (default), use same order in autoregression
%   |-standardize     - if true (default), remove mean from each signal
%   |                   if false, assume signal has already been detrended
%
% Outputs:
%   connectivity      - A x B matrix of spectral Granger causalities from
%                       source to sink, conditioned on all the other variables. 
%                       If Y is empty, the matrix contains the spectral GC
%                       from each source variable to each sink variable,
%                       conditioned on the remaining variable. 
%                       If Y is not empty the matrix contains the spectral
%                       causalities from each variable in Y to each
%                       variable in X, conditionend on the other variables
%                       in Y.
%                       [C: MX x MY x NF matrix]
%   pValues           - parametric p-value for corresponding spectral Granger
%                       causality in mean estimate (not implemented yet!)
%                       [P: MX x MY x NF matrix]
%   freq              - frequencies corresponding to the previous two metrics
%                       [F: NF x 1 vector]
%
% See also BST_GRANGER_CONDITIONAL.
%

% Spectral causality measures are evaluated from the spectra of the full
% and restricted models as:
%
%                gc(w) = det(S_restricted(w))/det(S_full(w))
%
% see Cohen, Dror, et al. "A general spectral decomposition of causal influences
% applied to integrated information." Journal of neuroscience methods 330 (2020): 108443
% for additional information.
%
% Call:
%   connectivity = bst_granger_spectral_conditional(X, Y, 200, 10, inputs); % general call
%   connectivity = bst_granger_spectral_conditional(X, [], 200, 30, inputs); % every pair in X
% Parameter examples:
%   inputs.freq           = 0:0.1:100; % specify desired frequencies
%   inputs.freqResolution = 0.1; % have a high-point FFT
%   inputs.nTrials        = 9; % use trial-average covariances in AR estimation
%   inputs.flagFPE        = true; % use AR model with best information criteria

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

% reformat to a 2D matrix if necessary, and pull out # of trials
if ndims(X) == 3
  inputs.nTrials = size(X,3);
  X = reshape(X, size(X, 1), []);
  Y = reshape(Y, size(Y, 1), []); 
elseif ~isfield(inputs, 'nTrials')
  inputs.nTrials = 1;
end

% lengths of things
nSamples = size(X, 2);
nTimes = nSamples / inputs.nTrials;

% standardization: zero mean & unit variance, remove linear & quadratic trends as well
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

% number of FFT bins required
if ~isfield(inputs, 'freq') || isempty(inputs.freq) % frequencies of interest are not defined
  if isfield(inputs, 'freqResolution') && ~isempty(inputs.freqResolution) && (size(X,2) > round(Fs / inputs.freqResolution))
    nFFT = 2^nextpow2( round(Fs / inputs.freqResolution) );
  else % use a default frequency resolution of 1Hz to mirror the standard frequency resolution in bst_coherence_welch.m
    nFFT = 2^nextpow2( round(Fs / 1) );
  end
elseif numel(inputs.freq) == 1
  nFFT = inputs.freq;
else
  nFFT = 2^nextpow2(max( length(inputs.freq)-1, (Fs/2) / min(diff( sort(inputs.freq(:)) )) )) * 2;
end

% default: Order 10 used in BrainStorm
if isempty(order)
  order = 10;
end

% default: Single-trial
if ~isfield(inputs, 'nTrials') || isempty(inputs.nTrials)
  inputs.nTrials = 1;
end

% default: do not optimize model order
if ~isfield(inputs, 'flagFPE') || isempty(inputs.flagFPE)
  inputs.flagFPE = false;
end

%% Differentiate between auto-causality and cross-causality for speed

if isempty(Y) % causality between signals in X
  
   % preallocate the spectral causality matrix
   connectivity = zeros(size(X, 1), size(X, 1), nFFT/2); 
  
   % the full model is evaluated only one time
   
   % multivariate model estimation
    [transfers, noiseCovariance, order] = bst_mvar(X, order, inputs.nTrials, inputs.flagFPE);

    % spectra for the full model
    [spectra, freq] = bst_granger_spectral_spectrum(transfers, noiseCovariance, nFFT, Fs);

    % data correlations using Yule-Walker (up to high order 50)
    R = YuleWalker_Inverse(transfers, noiseCovariance, 50);

    % iterate over all pairs of sinks & sources
    for iX = 1:size(X, 1)
        for iY = iX+1 : size(X, 1) % to avoid auto-causality
      
            % restricted model iY -> iX

            % mask for the coefficients of the restricted model
            mask = ones(size(X,1));
            mask(iX,iY) = 0;

            % restricted multivariate model (using masked row-by-row solution of YW equations)
            [transfers_restricted,noiseCovariance_restricted] = YuleWalker_Mask(R, mask);

             % spectra of restricted system
            [spectra_restricted, ~] = bst_granger_spectral_spectrum(transfers_restricted, noiseCovariance_restricted, nFFT, Fs);

            % connectivity at each frequence (see Cohen et al., 2020)
            for n = 1:length(freq)
                connectivity(iX, iY, n) = log(abs(det(spectra_restricted(:,:,n))) ./ abs(det(spectra(:,:,n))));% Geweke-Granger
            end

            % restricted model iX -> iY

            % mask for the coefficients of the restricted model
            mask = ones(size(X,1));
            mask(iY,iX) = 0;

            % restricted multivariate model (using masked row-by-row solution of YW equations)        
            [transfers_restricted,noiseCovariance_restricted] = YuleWalker_Mask(R, mask);

             % spectra of restricted system   
            [spectra_restricted, ~] = bst_granger_spectral_spectrum(transfers_restricted, noiseCovariance_restricted, nFFT, Fs);

            % connectivity at each frequence (see Cohen et al., 2020)
            for n = 1:length(freq)
                connectivity(iY, iX, n) = log(abs(det(spectra_restricted(:,:,n))) ./ abs(det(spectra(:,:,n))));% Geweke-Granger
            end
        end
    
        % diagonal will equal the maximum of all inflows and outflows for iX, specific to each frequency
        connectivity(iX, iX, :) = max( max(connectivity(iX, :, :), [], 2), max(connectivity(:, iX, :), [], 1) );   
    end

else % we have to use all pairs of signals
  
    % preallocate the spectral causality matrix
    connectivity = zeros(size(X, 1), size(Y, 1), nFFT/2); 
    duplicates = zeros(0, 2);
  
    % iterate over all pairs of sinks & sources
    for iX = 1:size(X, 1)
        for iY = 1:size(Y, 1)
     
            % X(iX,:) = sink, Y(iY,:) = source, Y(~iY,:) = conditional
            % I have to check that the sink is different form all the other
            % variables in Y
            sink = X(iX,:);
            source = Y(iY,:);
            other_vars = Y(setdiff( 1:size(Y, 1), iY),:);
            
            % If sink and source are duplicates there's a correction
            % 
            if max(abs(sink - source)) > eps % by default, if X(sink) = Y(source), the causality is 0 everywhere
                
                % If the target is equal to one of the conditioning
                % variables, remove it
                remove_inds = [];
                for k = 1:size(other_vars,1)
                     if max(abs(sink - other_vars(k,:))) < eps
                          remove_inds = [remove_inds, k];
                     end
                end
                other_vars(remove_inds,:) = [];
                
                
                % multivariate model estimation (one sink, all sources)
                [transfers, noiseCovariance, order] = bst_mvar([sink; source; other_vars], order, inputs.nTrials, inputs.flagFPE);

                % spectra for the full model
                [spectra, freq] = bst_granger_spectral_spectrum(transfers, noiseCovariance, nFFT, Fs);

                % data correlations using Yule-Walker (up to high order 50)
                R = YuleWalker_Inverse(transfers, noiseCovariance, 50);
                
                % mask for the coefficients of the restricted model
                mask = ones(2 + size(other_vars,1)); % size(other vars) + one source + one sink
                mask(1,2) = 0; % Cut only the source -> sink coupling

                % restricted multivariate model (using masked row-by-row solution of YW equations)
                [transfers_restricted,noiseCovariance_restricted] = YuleWalker_Mask(R, mask);

                 % spectra of restricted system
                [spectra_restricted, ~] = bst_granger_spectral_spectrum(transfers_restricted, noiseCovariance_restricted, nFFT, Fs);

                % connectivity at each frequence (see Cohen et al., 2020)
                for n = 1:length(freq)
                    connectivity(iX, iY, n) = log(abs(det(spectra_restricted(:,:,n))) ./ abs(det(spectra(:,:,n))));% Geweke-Granger
                end

            else % save duplicates to modify later
        
                duplicates(end+1, :) = [iX iY]; %#ok<AGROW>
        
            end
      
        end
    end
  
    % for duplicate indices, set the causality value to the maximum of all inflows for iX and outflows for iY
    for iDuplicate = 1:size(duplicates, 1)
        connectivity(duplicates(iDuplicate, 1), duplicates(iDuplicate, 2), :) = max( ...
        max(connectivity(duplicates(iDuplicate, 1), :, :), [], 2), ...
        max(connectivity(:, duplicates(iDuplicate, 2), :), [], 1) ...
        );
    end
   
end

%% Interpolate to desired frequencies & perform statistics if desired
if isfield(inputs, 'freq') && ~isempty(inputs.freq) && numel(inputs.freq) > 1
  connectivity = permute(interp1(freq, permute(connectivity, [3 1 2]), inputs.freq), [2 3 1]);
  % pValues = permute(interp1(freq, permute(pValues, [3 1 2]), inputs.freq), [2 3 1]);
  freq = inputs.freq;
end

pValues = NaN; % no parametric p-values for now

end

%% ======================================================== spectra estimation  ========================================================
function [spectra, freq] = bst_granger_spectral_spectrum(A, Sigma, nFFT, Fs)
% BST_GRANGER_SPECTRAL_SPECTRUM     Calculate the parametric spectra of a multivariate system
%                                   with given MVAR coefficients and an estimate of the
%                                   covariance matrix of the innovation (i.e. noise)
%                                   process.
%
% Inputs:
%   transfers         - transfer matrices in AR process
%                       [A: N x NP matrix, P = order]
%   noiseCovariance   - variance of residuals
%                       [C: N x N matrix]
%   nFFT              - number of FFT bins to calculate spectra
%                       [NF: positive number, usually power of 2]
%   Fs                - sampling frequency of data
%                       [FS: double, FS > freq(end)*2]
%
% Outputs:
%   spectra           - cross-spectrum between each pair of variables
%                       [S: N x N x NF/2 matrix]
%   freq              - frequencies used based on # of FFT bins
%                       [F: NF/2 x 1 matrix]
%   --> all outputs have length NF/2, ignoring frequenices past Fs/2
% Call:
%   spectra = bst_mvar_spectrum(transfers, C, 512, 200); % basic
%   spectra = bst_mvar_spectrum(transfers, C, 2048, 200); % add FFT interp

% frequencies to estimate cross-spectra
freq = Fs/2*linspace(0, 1, nFFT/2 + 1);
freq(end) = [];

% get number of variables, fft bins and order of the model
M = nFFT/2;
[N,pN] = size(A);
p = pN/N;

% evaluate the trasfer function and the spectra
H = complex(zeros(N,N,M));
spectra = complex(zeros(N,N,M));

A_r = reshape(A,[N,N,p]);
w_vec = 0:pi/(nFFT/2-1):pi;

for n = 1:M
    e = zeros(p,1);
    for k = 1:p
        e(k) = exp(-1i * w_vec(n) * k);
    end
    e = permute(repmat(e,[1,N,N]),[2,3,1]);
    A_w = eye(N) - sum(A_r .* e,3);
    H(:,:,n) = inv(A_w);
    spectra(:,:,n) = H(:,:,n) * Sigma * ctranspose(H(:,:,n));   
end


end %% <== FUNCTION END