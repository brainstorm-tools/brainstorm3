function [Gxy, pValues, freq, nWin, nFFT, Messages] = bst_cohn(X, Y, Fs, MaxFreqRes, Overlap, CohMeasure, isSymmetric, ImagingKernel, waitMax)
% BST_COHN: Optimized version of bst_coherence function between signals X and Y
%
% USAGE:  [Gxy, freq, pValues, nWin, nFFT, Messages] = bst_cohn(X, Y, Fs, MaxFreqRes=1, Overlap=0.5, CohMeasure='mscohere', isSymmetric=0, ImagingKernel=[], waitMax=100)
%
% INPUTS:
%    - X       : Input signals [Nsignals x Ntimes]
%    - Y       : Input signals [Nsignals x Ntimes]
%    - Fs      : Sampling frequency of X and Y (in Hz)
%    - nFFT    : Length of the window used to estimate the coherence (must be a power of 2 for the efficiency of the FFT)
%    - Overlap       : [0-1], percentage of time overlap between two consecutive estimation windows
%    - CohMeasure    : {'mscohere', 'icohere' , 'icohere2019', 'lcohere2019'}
%    - isSymmetric   : If 1, use an optimized method for symmetrical matrices
%    - ImagingKernel : If not empty, calculate the coherence at the source level
%    - waitMax       : Increase of the progress bar during the execution of this function
%
% CohMeasure (Definitions):
%     In Late 2019, the fft-based coherence functions were updated. The
%     lagged and Imaginary coherence have different definitions among two
%     versions. The recent changes are set as default. Please consider this
%     if you want to reproduce your former analyses. 
%     
%     Gxy:  cross-spectral density between x and y
%     Gxx:  autospectral density of x
%     Gyy:  autospectral density of y
%     Coherence function (C)            : Gxy/sqrt(Gxx*Gyy)
%     Magnitude-squared Coherence (MSC) : |C|^2 = |Gxy|^2/(Gxx*Gyy) = Gxy*conj(Gxy)/(Gxx*Gyy) 
%   
%     ============ 'icohere2019', 'lcohere2019' =============
%     Imaginary Coherence (IC)          : abs(imag(C))               
%     Lagged Coherence (LC)             : abs(imag(C))/sqrt(1-real(C)^2)
%
%     ========= 'icohere' (before 2019) =========
%     Imaginary Coherence (IC)          : imag(C)^2 / (1-real(C)^2)
%
% Parametric significance estimation:  
%     When overlap=0%   [Syed Ashrafulla]
%        Kuramaswamy's CDF using using Goodman's formula from [1], simplified by the null hypothesis as in [2]
%        => pValues = (1 - MSC) .^ floor(signalLength / windowLength)
%     
%     When overlap=50%   [Ester Florin]
%        dof = 2.8 * nSamples * (1.28/(nFFT+1));   % According to Welch 1976
%        pValues = (1 - MSC) .^ ((dof-2)/2);       % Schelter [3] and Bloomfield [4]
%        While Matlab defines the coherence as the square of the cross sepctra divided by the product of the spectra, Bokil (2007)
%        and Schelter (2006) work with the square root within the correction and significance determination
%
% References:
%   [1] Carter GC (1987), Coherence and time delay estimation
%       Proc IEEE, 75(2):236-255, doi:10.1109/PROC.1987.13723
%   [2] Amjad AM, Halliday DM, Rosenberg JR, Conway BA (1997)
%       An extended difference of coherence test for comparing and combining several independent coherence estimates: 
%       theory and application to the study of motor units and physiological tremor.
%       J Neuro Methods, 73(1):69-79
%   [3] Schelter B, Winterhalder M, Eichler M, Peifer M, Hellwig B, Guschlbauer B, Luecking CH, Dahlhaus R, Timmer J (2006)
%       Testing for directed influences among neural signals using partial directed coherence
%       J Neuro Methods, 152(1-2):201-219
%   [4] Bloomfield P, Fourier Analysis of Time Series: An Introduction
%       John Wiley & Sons, New York, 1976.

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
% Authors: Sergul Aydore, Syed Ashrafulla, Guiomar Niso, 2013-2014
%          Francois Tadel, 2013-2019
%          Hossein Shahabi, 2019

%% ===== INITIALIZATIONS =====
% Default options
if (nargin < 9) || isempty(waitMax)
    waitMax = 100;
end
if (nargin < 8) || isempty(ImagingKernel)
    ImagingKernel = [];
end
if (nargin < 7) || isempty(isSymmetric)
    isSymmetric = 0;
end
if (nargin < 6) || isempty(CohMeasure)
    CohMeasure = 'mscohere';
end
if (nargin < 5) || isempty(Overlap)
    Overlap = 0.5;
end
if (nargin < 4) || isempty(MaxFreqRes)
    MaxFreqRes = 1;
end
if (nargin < 3)
    error('Invalid call.');
end
Messages = [];
Gxy = [];
freq = [];
pValues = [];
% Signal properties
nX = size(X, 1); 
nY = size(Y, 1);
nTimes = size(X, 2);
% Get current progress bar position
waitStart = bst_progress('get');


%% ===== FREQUENCY RESOLUTION =====
% Convert maximum frequency resolution to time length
nFFT = 2^nextpow2( round(Fs / MaxFreqRes) );
% Number of segments
nOverlap = floor(Overlap * nFFT);
nWin = floor((nTimes - nOverlap) / (nFFT - nOverlap));
minWinError = 2;
minWinWarning = 5;
% ERROR: Not enough time points
if (nTimes < nFFT) || (nWin < minWinError)
    minTimes = nFFT + (nFFT - nOverlap) * (minWinError - 1);
    Messages = sprintf(['Input signals are too short (%d samples) for the requested frequency resolution (%1.2fHz).\n' ...
                        'Minimum length for this resolution: %1.3f seconds (%d samples).'], nTimes, MaxFreqRes, minTimes/Fs, minTimes);
    return;
% WARNING: Maybe not enough time points
elseif (nWin < minWinWarning)
    minTimes = nFFT + (nFFT - nOverlap) * (minWinWarning - 1);
    Messages = sprintf(['Input signals may be too short (%d samples) for the requested frequency resolution (%1.2fHz).\n' ...
                        'Recommended length for this resolution: %1.3f seconds (%d samples).'], nTimes, MaxFreqRes, minTimes/Fs, minTimes);
end
% Output frequencies
freq = Fs/2 * linspace(0, 1, nFFT/2 + 1)';
freq(end) = [];


%% ===== ALTERNATE FUNCTIONS =====
% % USC
% [Gxy, freq] = bst_coherence_usc(X, Y, Fs, MaxFreqRes);
% % MATLAB
% [Gxy, freq] = bst_coherence_matlab(X, Y, Fs, nFFT);
% return;


%% ===== WINDOWING =====
% Segment indices - discard final timepoints
iStart = (nFFT - nOverlap) * (0:(nWin-1)) + 1;
iStop  = iStart + (nFFT-1);
if (iStop(end) > nTimes)
    iStart(end) = [];
    iStop(end) = [];
    nWin = nWin - 1;
end
iWin = [iStart; iStop];
% Number of samples that are taken into account in the windowing
nSamples = iWin(end);
% Frequency smoother (represented as time-domain multiplication)
smoother = bst_window('parzen', nFFT) .* bst_window('tukey', nFFT, 0.1);
% smoother = bst_window('parzen', nFFT);
smoother = smoother / sqrt(sum(smoother.^2));
% If overlap 50%: for the parametric estimation of the significance level (According to Welch 1976)
dof = 2.8 * nSamples * (1.28/(nFFT+1)); 


%% ===== VERSION 1: for loops, full matrix =====
if ~isSymmetric
    isCalcAuto = ~isequal(X,Y);
    % Initialize variables
    Gxy = zeros(nX, nY, length(freq));
    if isCalcAuto
        Gxx = zeros(nX, 1, length(freq));
        Gyy = zeros(1, nY, length(freq));
    end
    % Cross-spectrum
    for i = 1:nWin
        bst_progress('set', round(waitStart + i/nWin * 0.7 * waitMax));
        % Get time indices for this segment
        iTime = iWin(1,i):iWin(2,i);
        % Frequency domain spectrum after smoothing and tapering
        fourierX = fft(bst_bsxfun(@times, X(:,iTime), smoother'), nFFT, 2);
        fourierY = fft(bst_bsxfun(@times, Y(:,iTime), smoother'), nFFT, 2);
        % Calculate for each frequency: fourierX * fourierY'
        for f = 1:length(freq)
            Gxy(:,:,f) = Gxy(:,:,f) + fourierX(:,f) * fourierY(:,f)';
        end
        % Calculate auto-spectra if needed
        if isCalcAuto
            Gxx = Gxx + reshape(abs(fourierX(:,1:(nFFT/2)) .^ 2), nX, 1, length(freq));
            Gyy = Gyy + reshape(abs(fourierY(:,1:(nFFT/2)) .^ 2), 1, nY, length(freq));
        end
    end
    bst_progress('set', round(waitStart + 0.75 * waitMax));
    % Normalize for segments and sampling rate
    Gxy = Gxy / (nWin * Fs);
    if isCalcAuto
        Gxx = Gxx / (nWin * Fs);
        Gyy = Gyy / (nWin * Fs);
    end
    
    % Project in source space
    if ~isempty(ImagingKernel)
        % Initialize output matrix
        nX = size(ImagingKernel,1);
        nY = size(ImagingKernel,1);
        Gsources = zeros(nX, nY, length(freq));
        % Loop on the frequencies to make the multiplication
        for iFreq = 1:length(freq)
            Gsources(:,:,iFreq) = ImagingKernel * Gxy(:,:,iFreq) * ImagingKernel';
        end
        Gxy = Gsources;
        clear Rs;
    end
    
    % [NxN]: Auto spectrum for X is contained within cross-spectral estimation
    bst_progress('set', round(waitStart + 0.9 * waitMax));
    if ~isCalcAuto
        iAuto = sub2ind(size(Gxy), ...
            repmat((1:nX)', length(freq), 1), ... 
            repmat((1:nY)', length(freq), 1), ... 
            reshape(repmat(1:length(freq), nX, 1),[],1));
        Gxx = reshape(Gxy(iAuto), nX, 1, length(freq));
        Gyy = reshape(Gxy(iAuto), 1, nY, length(freq));
    end
    
    % Divide by the corresponding autospectra for each frequency
    % C = Gxy/sqrt(Gxx*Gxy)
    switch CohMeasure
        % Magnitude-squared Coherence 
        case 'mscohere'
            % Coherence = |C|^2 = |Gxy|^2/(Gxx*Gyy) = Gxy*conj(Gxy)/(Gxx*Gyy)
            % Gxy = Gxy .* conj(Gxy);    % SLOWER
            Gxy = abs(Gxy) .^ 2;
            Gxy = bst_bsxfun(@rdivide, Gxy, Gxx);
            Gxy = bst_bsxfun(@rdivide, Gxy, Gyy);
            % Parametric estimation of the significance level
            if (Overlap == 0.5)
                pValues = max(0, 1 - Gxy) .^ ((dof-2)/2);    % Schelter 2006 and Bloomfield 1976
            else
                pValues = max(0, 1 - Gxy) .^ floor(nSamples / nFFT);    % Max makes sure numerical error is taken care of that may result in -e-15 errors
            end
        
        % Imaginary/Lagged Coherence (2019)
        case {'icohere2019','lcohere2019'} % (No pValues for the new version)
            Gxy = bst_bsxfun(@rdivide, Gxy, sqrt(Gxx));
            Gxy = bst_bsxfun(@rdivide, Gxy, sqrt(Gyy));
            if strcmpi(CohMeasure,'icohere2019') % Imaginary Coherence
                Gxy = abs(imag(Gxy)) ;
            else % Lagged Coherence
                Gxy = abs(imag(Gxy))./sqrt(1-real(Gxy).^2) ;
            end
        
        % Imaginary Coherence ( before 2019)
        case 'icohere' % (We only have Imaginary coherence)
            % Coherence function: C = Gxy/sqrt(Gxx*Gyy)
            Gxy = bst_bsxfun(@rdivide, Gxy, sqrt(Gxx));
            Gxy = bst_bsxfun(@rdivide, Gxy, sqrt(Gyy));
            % Parametric estimation of the significance level
            if (Overlap == 0.5)
                pValues = max(0, 1 - abs(Gxy).^2) .^ ((dof-2)/2);  % Schelter 2006 and Bloomfield 1976
            else
                pValues = max(0, 1 - abs(Gxy).^2) .^ floor(nSamples / nFFT);
            end
            % Imaginary Coherence = imag(C)^2 / (1-real(C)^2)
            Gxy = imag(Gxy).^2 ./ (1-real(Gxy).^2);
            
    end
    % In the symmetric case
    if ~isCalcAuto
%         % Save the auto-spectra as the diagonal
%         Gxy(iAuto) = Gxx(:);
%         % Set the diagonals to zero
%         Gxy(iAuto) = 0;
    end
    
    
%% ===== VERSION 2: Vectorized + Symetrical =====
else
    % Indices for the multiplication
    [iY,iX] = meshgrid(1:nX,1:nY);
    % Find the values above the diagonal
    indSym = find(iX <= iY);
    % Cross-spectrum
    Gxy = zeros(length(indSym), length(freq));
    for i = 1:nWin
        bst_progress('set', round(waitStart + i/nWin * 0.7 * waitMax));
        % Get time indices for this segment
        iTime = iWin(1,i):iWin(2,i);
        % Frequency domain spectrum after smoothing and tapering
        fourierX = fft(bst_bsxfun(@times, X(:,iTime), smoother'), nFFT, 2);
        fourierY = conj(fft(bst_bsxfun(@times, Y(:,iTime), smoother'), nFFT, 2));
        % Calculate for each frequency: fourierX * fourierY'
        Gxy = Gxy + fourierX(iX(indSym),1:(nFFT/2)) .* fourierY(iY(indSym),1:(nFFT/2));
    end
    % Normalize for segments and sampling rate
    Gxy = Gxy / (nWin * Fs);

    % Project in source space
    if ~isempty(ImagingKernel)
        bst_progress('text', sprintf('Projecting to source domain [%d>%d]...', nX, size(ImagingKernel,1)));
        % Expand matrix
        Gxy = process_compress_sym('Expand', Gxy, nX, 1);
        bst_progress('set', round(waitStart + 0.75 * waitMax));
        % Reshape [nX x nY]
        Gxy = reshape(Gxy, nX, nY, length(freq));
        % Initialize output matrix
        nX = size(ImagingKernel,1);
        nY = size(ImagingKernel,1);
        Gsources = zeros(nX, nY, length(freq));
        % Loop on the frequencies to make the multiplication
        for iFreq = 1:length(freq)
            Gsources(:,:,iFreq) = ImagingKernel * Gxy(:,:,iFreq) * ImagingKernel';
        end
        bst_progress('set', round(waitStart + 0.85 * waitMax));
        % Reshape
        Gsources = reshape(Gsources, nX * nY, length(freq));
        % Compress matrix again
        Gxy = process_compress_sym('Compress', Gsources);
        clear Gsources;
        % Re-estimate indices
        [iY,iX] = meshgrid(1:nX,1:nY);
        indSym = find(iX <= iY);
    end
        
    bst_progress('text', sprintf('Normalizing: Coherence [%dx%d]...', nX, nX));
    bst_progress('set', round(waitStart + 0.90 * waitMax));
    % Find auto-spectrum in the list
    indDiag = (iX(indSym) == iY(indSym));
    Gxx = Gxy(indDiag,:);
    % Divide by the corresponding autospectra for each frequency
    
    switch CohMeasure
        % Magnitude-squared Coherence
        case 'mscohere'
             % Coherence = |C|^2 = |Gxy|^2/(Gxx*Gyy) = Gxy*conj(Gxy)/(Gxx*Gyy)
            % Gxy = Gxy .* conj(Gxy);   % SLOWER
            Gxy = abs(Gxy) .^ 2;
            Gxy = Gxy ./ (Gxx(iX(indSym),:) .* Gxx(iY(indSym),:));
            % Parametric estimation of the significance level
            if (Overlap == 0.5)
                pValues = max(0, 1 - Gxy) .^ ((dof-2)/2);    % Schelter 2006 and Bloomfield 1976
            else
                pValues = max(0, 1 - Gxy) .^ floor(nSamples / nFFT);   % Max makes sure numerical error is taken care of that may result in -e-15 errors
            end
            
        % Imaginary/Lagged Coherence (2019)
        case {'icohere2019','lcohere2019'} % (No pValues for the new version)
            Gxy = Gxy ./ sqrt(Gxx(iX(indSym),:) .* Gxx(iY(indSym),:));
            if strcmpi(CohMeasure,'icohere2019') % Imaginary Coherence
                Gxy = abs(imag(Gxy)) ;
            else % Lagged Coherence
                Gxy = abs(imag(Gxy))./sqrt(1-real(Gxy).^2) ;
            end
            % pValues = max(0, 1 - abs(Gxy)) .^ floor(nSamples / nFFT);
            
        % Imaginary Coherence ( before 2019)
        case 'icohere'  % (We only have Imaginary coherence)
            % Coherence function: C = Gxy/sqrt(Gxx*Gyy)
            Gxy = Gxy ./ sqrt(Gxx(iX(indSym),:) .* Gxx(iY(indSym),:));
            % Parametric estimation of the significance level
            if (Overlap == 0.5)
                pValues = max(0, 1 - abs(Gxy).^2) .^ ((dof-2)/2);  % Schelter 2006 and Bloomfield 1976
            else
                pValues = max(0, 1 - abs(Gxy).^2) .^ floor(nSamples / nFFT);
            end
            % Imaginary Coherence = imag(C)^2 / (1-real(C)^2)
            Gxy = imag(Gxy).^2 ./ (1-real(Gxy).^2);
            
    end
    
%     % Save the auto-Gxy as the diagonal
%     Gxy(indDiag,:) = Gxx;
%     % Set the diagonals to zero
%     Gxy(indDiag,:) = 0;
    % Reshape to have the frequencies in third dimension
    Gxy = reshape(Gxy,     length(indSym), 1, length(freq));
    if ~isempty(pValues)
        pValues = reshape(pValues, length(indSym), 1, length(freq));
    end
end

% Make sure that there are no residual imaginary parts due to numerical errors
if ~isreal(Gxy)
    Gxy = abs(Gxy);
end

bst_progress('set', round(waitStart + 0.95 * waitMax));
end


%% ===============================================================================================
%  ===== EQUIVALENT CODE =========================================================================
%  ===============================================================================================
% %% ===== USC: BST_COHERENCE =====
% function [R, freq] = bst_coherence_usc(X, Y, Fs, MaxFreqRes)
%     inputs.Fs   = Fs;
%     inputs.freq = [];
%     inputs.maxfreqres = MaxFreqRes;
%     [R, freq] = bst_coherence(X, Y, inputs);
%     R = abs(R);
% end

% %% ===== MATLAB: MSCOHERE =====
% function [R, freq] = bst_coherence_matlab(X, Y, Fs, nFFT)
%     % Get the default output size of mscohere
%     [C, freq] = mscohere(X(1,:), Y(1,:), [], [], nFFT, Fs);
%     % Initialize returned value
%     R = zeros(size(X,1), size(Y,1), nFFT/2+1);
%     % Compute the coherence for each couple
%     for iA = 1:size(sInputA.Data,1)
%         for iB = 1:size(sInputB.Data,1)
%             % Default options
%             % R(iA,iB,:) = mscohere(sInputA.Data(iA,:), sInputB.Data(iB,:), [], [], [], Fs);
%             % Options that match the results of the bst_coherence function
%             R(iA,iB,:) = mscohere(sInputA.Data(iA, :), sInputB.Data(iB, :), parzenwin(nFFT), [], nFFT, Fs);
%         end
%     end
%     % Cut the last frequency bin
%     freq(end) = [];
%     R(:,:,end) = [];
% end



