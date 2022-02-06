function [connectivity, pValues, freq] = bst_granger_spectral(X, Y, Fs, order, inputs)
% BST_GRANGER_SPECTRAL  Granger causality at each frequency between any two
%                       signals.
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
%                       source to sink. For each signal pair (a,b) we calculate
%
%                                        S_{sink} (f)
%                  ------------------------------------------------------------
%                  S_{sink}(f) - |H_{sink, source} (f)|^2 sigma_{source | sink}
%
%                       with S_{sink}(f) as the power spectral density of a @ f
%                            H_{sink, source}(f) as the transfer function @ f
%                            sigma_{source | sink} as the conditional variance
%                             of the residual at b given the residual at a,
%                             calculated using the residual covariance.
%                       By default, GC(a,a) = 0 if Y is empty.
%                       [C: MX x MY x NF matrix]
%   pValues           - parametric p-value for corresponding spectral Granger
%                       causality in mean estimate
%                       [P: MX x MY x NF matrix]
%   freq              - frequencies corresponding to the previous two metrics
%                       [F: NF x 1 vector]
%
% See also BST_GRANGER, BST_COHERENCE_MVAR.
%
% Call:
%   connectivity = bst_granger_spectral(X, Y, 200, 10, inputs); % general call
%   connectivity = bst_granger_spectral(X, [], 200, 30, inputs); % every pair
%   connectivity = bst_granger_spectral(X, [], 200, 30, inputs); % more variance
% Parameter examples:
%   inputs.freq           = 0:0.1:100; % specify desired frequencies
%   inputs.freqResolution = 0.1; % have a high-point FFT
%   inputs.nTrials        = 9; % use trial-average covariances in AR estimation
%   inputs.flagFPE        = true; % use AR model with best information criteria

% Note: for those following Chicharro2012, I have used the equivalence
%                       sigma_{xx}^(xy) |H_{xx}^(xy) (w)|^2
%                                       =
%                S_{xx}(w) - sigma_{yy}^(xy) |H_{xy}^(xy) (w)|^2
% which follows Geweke1982 instead. As Chicharro notes, it may be better to use his
% formulation because it separates out instantaneous causality I think.

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

% reformat to a 2D matrix if necessary, and pull out # of trials
if ndims(X) == 3
  inputs.nTrials = size(X,3);
  X = reshape(X, size(X, 1), []);
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
    Y = reshape(Y, size(Y, 1), []); % reshape to 2D matrix first
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

if isempty(Y) % auto-causality between signals in X, so we can halve the number of models to estimate
  
  % preallocate the spectral causality matrix
  connectivity = zeros(size(X, 1), size(X, 1), nFFT/2); 
  
  % iterate over all pairs of sinks & sources
  for iX = 1:size(X, 1)
    for iY = iX+1 : size(X, 1) % to avoid auto-causality
      
        % two-variate model for given source
        [transfers, noiseCovariance, order] = bst_mvar([X(iX, :); X(iY, :)], order, inputs.nTrials, inputs.flagFPE);
        
        % spectra and power of forward system
        [spectra, freq, forward] = bst_granger_spectral_spectrum(transfers, noiseCovariance, nFFT, Fs);

        % Geweke-Granger spectral causality from source to sink
        unrestricted = abs(spectra(1, 1, :)); restriction = forward(1, 2, :); % S_{sink}(f) and |H_{sink, source} (f)|^2, w/ abs to get rid of 1e-16 imag part
        residualVariance = noiseCovariance(2,2) - noiseCovariance(2, 1) / noiseCovariance(1, 1) * noiseCovariance(1, 2); % partial variance of source
        restricted = abs(unrestricted) - abs(restriction).^2 * residualVariance; % S_{sink} (f) - |H_{sink, source} (f)|^2 sigma_{source | sink}
        connectivity(iX, iY, abs(restricted) > 1e-60) = unrestricted(abs(restricted) > 1e-60) ./ restricted(abs(restricted) > 1e-60) - 1;% Geweke-Granger
        % sigma_{source | sink} = partial covariance which is the formula above (sigma_{source} - rho_{source, sink} / sigma_{sink} * rho_{sink, source})

        % Geweke-Granger spectral causality from sink back to source (to halve the # of MVAR fittings)
        unrestricted = abs(spectra(2, 2, :)); restriction = forward(2, 1, :); % S_{source}(f) and |H_{source, sink} (f)|^2, w/ abs to get rid of 1e-16 imag part
        residualVariance = noiseCovariance(1,1) - noiseCovariance(1, 2) / noiseCovariance(2, 2) * noiseCovariance(2, 1); % partial variance of sink
        restricted = abs(unrestricted) - abs(restriction).^2 * residualVariance; % S_{source} (f) - |H_{source, sink} (f)|^2 sigma_{sink | source}
        connectivity(iY, iX, abs(restricted) > 1e-60) = unrestricted(abs(restricted) > 1e-60) ./ restricted(abs(restricted) > 1e-60) - 1; % Geweke-Granger
        % sigma_{sink | source} = partial covariance which is the formula above (sigma_{sink} - rho_{sink, source} / sigma_{source} * rho_{source, sink})
        
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
      
      if max(abs(X(iX, :) - Y(iY, :))) > eps % by default, if X(sink) = Y(source), the causality is 0 everywhere

        % 2-variate model for given source
        [transfers, noiseCovariance, order] = bst_mvar([X(iX, :); Y(iY, :)], order, inputs.nTrials, inputs.flagFPE);

        % spectra and power of forward system
        [spectra, freq, forward] = bst_granger_spectral_spectrum(transfers, noiseCovariance, nFFT, Fs);
        spectra = abs(spectra(1, 1, :)); % limit to the autospectrum of the sink S_{sink} (f) and take absolute value to rid the 1e-16 imaginary part
        forward = forward(1, 2, :); % limit to the cross-transfer from source to sink H_{sink, source} (f)
        
        % partial covariance of residual
        residualVariance = noiseCovariance(2,2) - noiseCovariance(2,1) / noiseCovariance(1, 1) * noiseCovariance(1, 2);
        % sigma_{source | sink} = partial covariance which is the formula above (sigma_{source} - rho_{source, sink} / sigma_{sink} * rho_{sink, source})

        % Geweke-Granger spectral causality from source to sink
        restricted = spectra - abs(forward).^2 * residualVariance; % S_{sink} (f) - |H_{sink, source} (f)|^2 sigma_{source | sink}
        connectivity(iX, iY, abs(restricted) > 1e-60) = spectra(abs(restricted) > 1e-60) ./ restricted(abs(restricted) > 1e-60) - 1; % Geweke-Granger

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

%% ======================================================== estimation for multivariate autoregression ========================================================
function [spectra, freq, forward] = bst_granger_spectral_spectrum(transfers, noiseCovariance, nFFT, Fs)
% BST_MVAR_SPECTRUM     Calculate the parametric spectra of a bivariate system
%                       with given MVAR coefficients & an estimate of the
%                       covariance matrix of the innovation (i.e. noise)
%                       process.
%
% Inputs:
%   transfers         - transfer matrices in AR process
%                       [A: 2 x 2P matrix, P = order]
%   noiseCovariance   - variance of residuals
%                       [C: 2 x 2 matrix]
%   nFFT              - number of FFT bins to calculate spectra
%                       [NF: positive number, usually power of 2]
%   Fs                - sampling frequency of data
%                       [FS: double, FS > freq(end)*2]
%
% Outputs:
%   spectra           - cross-spectrum between each pair of variables
%                       [S: 2 x 2 x NF/2 matrix]
%   freq              - frequencies used based on # of FFT bins
%                       [F: NF/2 x 1 matrix]
%   forward           - forward transform in frequency from source to sink
%                       [H: 2 x 2 x NF/2 matrix]
%   --> all outputs have length NF/2, ignoring frequenices past Fs/2
%
% Call:
%   spectra = bst_mvar_spectrum(transfers, C, 512, 200); % basic
%   spectra = bst_mvar_spectrum(transfers, C, 2048, 200); % add FFT interp
%   [spectra, freq] = bst_mvar_spectrum(transfers, C, 512, 200); % grab freqs
%   [~, ~, forward] = bst_mvar_spectrum(transfers, C, 64, 200); % causality

% Notes:
% The DTFT we want is
% H = I - sum_p C_p e^{-j 2 pi f/Fs p} = sum_p D_p e^{-j 2 pi f/Fs (p-1)} where D_1 = 1 and D_p = -C_{p-1} for p > 1
% MatLab's FFT provides
% G = sum_n x_n e^{-j 2 pi (k-1)/N (n-1)}
% so the matching is p = n and (k-1)/N = f/Fs, after vectorizing H.

% frequencies to estimate cross-spectra
freq = Fs/2*linspace(0, 1, nFFT/2 + 1);
freq(end) = [];

%% Inverse of transfer function in frequency
% Inverse transfer means the transfer function from the sources to the innovations. We calculate this at each frequency.
% The inverse transfer from source a to innovation b is
%                1 - \sum_{n=1}^N a_{ab} [n] e^{-j2pi * f * n}

inverse = fft(reshape([eye(2) -transfers], 4, [])', nFFT); % reshape so we can do a vector FFT quickly
inverse = inverse(1:nFFT/2, :); % restrict to the first symmetric half of the spectrum

%% Forward transfer in autoregressive model

% pieces of 2x2 inverse
forward = zeros(2, 2, nFFT/2); % an important caveat is that I did not reshape inverse earlier;
forward(1,1,:) = inverse(:,4); forward(1,2,:) = -inverse(:,3); % as a result, we have a column-wise index mapping: 4 = (2,2) and 3 = (1,2)
forward(2,1,:) = -inverse(:,2); forward(2,2,:) = inverse(:,1); % in addition, 2 = (2,1) and 1 = (1,1). then these elements fit the 2x2 matrix inverse
detInverse = inverse(:,1).*inverse(:,4) - inverse(:,3).*inverse(:,2); % the same thing happens here, using the indexing to avoid a reshape() call

% normalization by determinant to get inverse
forward = bst_bsxfun(@rdivide, forward, reshape(detInverse, [1 1 length(freq)])); % complete the inversion by dividing by frequency-dependent determinant

%% Cross-spectrum from forward model
% The forward transfer is the inverse of the inverse transfer at each frequency f. Denoted H(f), the power spectral density is then HH' at each frequency.

% the loop that we won't use
% for idxFreq = 1:nFFT
%   spectra(:, :, idxFreq) = H(:,:,idxFreq) * noiseCovariance * H(:,:,idxFreq)';
% end

% formula for the matrix multiplication
spectra(1,1,:) = ... % 1,1 element is H_11 C_11 H_11^* + H_12 C_12 H_11^* + H_11 C_12 H_12^* + H_12 C_22 H_12^* (and I combine the middle two into 2 Re{.})
  noiseCovariance(1,1) * forward(1,1,:) .* conj(forward(1,1,:)) ...
  + noiseCovariance(1,2) * real(forward(1,2,:) .* conj(forward(1,1,:))) * 2 ...
  + noiseCovariance(2,2) * forward(1,2,:) .* conj(forward(1,2,:));
spectra(1,2,:) = ... % 1,2 element is H_11 C_11 H_21^* + H_12 C_12 H_21^* + H_11 C_12 H_22^* + H_12 C_22 H_22^*
  noiseCovariance(1,1) * forward(2,1,:) .* conj(forward(1,1,:)) ...
  + noiseCovariance(1,2) * forward(2,2,:) .* conj(forward(1,1,:)) ...
  + noiseCovariance(1,2) * forward(2,1,:) .* conj(forward(1,2,:)) ...
  + noiseCovariance(2,2) * forward(1,2,:) .* conj(forward(1,2,:));
spectra(2,1,:) = conj(spectra(1,2,:)); % for speed, force the 2,1 element to be the conjugate of the 1,2 element so we have conjugate symmetry
spectra(2,2,:) = ... % 2,2 element is H_21 C_11 H_21^* + H_22 C_12 H_21^* + H_21 C_12 H_22^* + H_22 C_22 H_22^* (and I combine the middle two into 2 Re{.})
  noiseCovariance(1,1) * forward(2,1,:) .* conj(forward(2,1,:)) ...
  + noiseCovariance(1,2) * real(forward(2,2,:) .* conj(forward(2,1,:))) * 2 ...
  + noiseCovariance(2,2) * forward(2,2,:) .* conj(forward(2,2,:));

%% Normalize for sampling rate, and truncate if necessary

% normalization
forward = forward / sqrt(Fs);
spectra = spectra / Fs;

%% Confidence intervals
% taken from Kay, pp 194-195
% alpha = 1 - ci;
% original = -sqrt(2) * erfcinv( 2 * ( 1 - alpha/2) );
% lower = abs(spectra) * (1 - sqrt(2 * order / nTimes) * original);
% upper = abs(spectra) * (1 + sqrt(2 * order / nTimes) * original);

end %% <== FUNCTION END