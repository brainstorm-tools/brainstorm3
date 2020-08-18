function varargout = bst_henv(Data,OPTIONS)
% BST_HENV Compute the time-varying COherence and enVELope measures 
%
% INPUTS:
%   - Data         : Input signal (nSignals x nSamples)
%   - OPTIONS: 
%     - SampleRate : Sampling frequency
%     - CohMeasure : Desired measure of connectivity
%                    'coh'  - coherence
%                    'lcoh' - lagged coherence
%                    'penv' - plain envelope correlation (No Orthogonalization)
%                    'oenv' - orthogonalized envelope correlation
%     - WinParam(1): winSize - window size in second for dynamic networks 
%     - WinParam(2): overlap - overlap between windows in percentage 
%     - HStatDyn   : Time scale of the network (Dynamic (1) or Static(2))  
%     - tfSplit    : Number of blocks to split the raw signal for time-frequnecy analysis
%     - isParallel : Parallel Processing option (1 when it is enabled) 
%     - tfMeasure  : Time-frequency transformation method (Hilbert/Morlet)
%
% OUTPUTS:
%   - A            : Four-dimensional connectivity matrix (nSignals x nSignals x nWindows x nfBins)
%   - timePoints   : Time vector Corresponding to the connectivity matrix
%
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
% Author: Hossein Shahabi, 2020.

%% ~~~~~ Checking Input Variables
if (nargin < 2)
    error('Invalid call.');
end

% Options for connectivity analysis
[nSig,N]  = size(Data) ;
Fs        = OPTIONS.SampleRate ;
winSize   = OPTIONS.WinParam(1) * Fs ;
overLap   = OPTIONS.WinParam(2) * winSize ;
numBlocks = OPTIONS.tfSplit ;
parMode   = OPTIONS.isParallel ;

% Time-frequency options
OPTIONS_tf.Method        = OPTIONS.tfMeasure ;
OPTIONS_tf.Output        = 'all' ;
OPTIONS_tf.Comment       = [] ;
OPTIONS_tf.ListFiles     = [] ;
OPTIONS_tf.iTargetStudy  = [] ;
OPTIONS_tf.RowNames      = cell(nSig,1);
OPTIONS_tf.Measure       = 'none' ;
if ~isempty(OPTIONS.WavPar)
    OPTIONS_tf.MorletFc      = OPTIONS.WavPar(1) ;
    OPTIONS_tf.MorletFwhmTc  = OPTIONS.WavPar(2) ;
end

%% ~~~~~~ Constant definition and pre-allocation
% Compute the parameters for window
hopSize    = ceil(winSize-overLap) ;
nWindows   = fix((N-winSize)/hopSize)+1 ;
timePoints = NaN(nWindows,1) ;                   % Pre-define the center of windows 
nfBins     = size(OPTIONS.Freqrange,1) ;         % Number of Frequency bins
A          = zeros(nSig,nSig,nWindows,nfBins) ;  % Pre-define the connectivity matrix
% Data       = bst_bsxfun(@minus, Data, mean(Data,2)) ;  % Removing mean from the data 

%% Block analysis for large files 
if numBlocks>1
    tfBlockRem = rem(N,numBlocks) ;
    % Adding zero to the end of the data (few samples)
    if tfBlockRem ~= 0
        Data(:,end:end+(numBlocks-tfBlockRem)) = 0 ;
    end
    % Total Length of the Data
    [tmp1,N] = size(Data) ;
    actLen   = (N/numBlocks) ; 
    % Consider a fixed 5 sec for transient (filter) effect (each side)
    tranLen  = 5 * Fs ;
    % Compute the length of each block
    blockLen3D = actLen + 2*tranLen ; 
    % Pre-define the data in 3D format (Signals x Samples x Blcoks)
    Data3D = zeros(nSig,blockLen3D,numBlocks) ; 
    % Divide data into a 3D structure with overlapping periods 
    for k = 1:numBlocks
        % First block
        if k == 1
            range2D = 1:(actLen + tranLen) ;
            range3D = (tranLen+1):blockLen3D ;
        % Last block
        elseif k == numBlocks
            range2D = (N-(actLen+tranLen)+1):N ; 
            range3D = 1:(actLen + tranLen) ;
        else % Middle blocks
            range2D = ((k-1)*actLen - tranLen) + (1:blockLen3D) ;
            range3D = 1:blockLen3D ; 
        end
        Data3D(:,range3D,k) = Data(:,range2D) ;
    end
    [tmp1,tfBlockLen,tmp1] = size(Data3D) ;
else
    [tmp1,tfBlockLen] = size(Data) ;
end

%%
for f = 1:nfBins
    %% Time-frequency transformation
    switch OPTIONS.tfMeasure
        case 'hilbert'
            tf_tmp1 = cell2table(OPTIONS.Freqrange) ;
            OPTIONS_tf.Freqs = table2cell(tf_tmp1(f,:)) ;
        case 'morlet'
            OPTIONS_tf.Freqs = OPTIONS.Freqrange(f) ;
    end 
 
    % Predefine the complex frequency domain signal
    Xh = zeros(N,nSig) ;
    if numBlocks>1
        OPTIONS_tf.TimeVector = linspace(OPTIONS.TimeWindow(1),blockLen3D/Fs,blockLen3D) ;
        for bl = 1:numBlocks
            tfOut_tmp = bst_timefreq(Data3D(:,:,bl), OPTIONS_tf) ;
            tfOut_tmp = tfOut_tmp{1}.TF ;
            % We select the middle part of each block and drop "tranLen" on each side 
            Xh((bl-1)*actLen+(1:actLen),:) = transpose(tfOut_tmp(:,(1:actLen)+tranLen)) ;
        end
    else
        OPTIONS_tf.TimeVector = linspace(OPTIONS.TimeWindow(1),OPTIONS.TimeWindow(2),N) ;
        tfOut_tmp = bst_timefreq(Data, OPTIONS_tf) ;
        tfOut_tmp = tfOut_tmp{1}.TF ;
        Xh = transpose(tfOut_tmp) ;
    end
    
    %% Connectivity computation
    bst_progress('start', 'Connectivity analysis', sprintf('Connectivity Analysis %d Windows %d Freq Bins'...
        ,nWindows,nfBins), 0, 100)
    
    for t = 1:nWindows
        progPer1 = round( ((t + (f-1)*nWindows)/(nWindows*nfBins)) * 100) ; 
        bst_progress('set',progPer1)
        % Selecting the appropriate time points 
        tRange = (t-1)*hopSize+(1:winSize) ;
        % Center of the window
        timePoints(t) = median(tRange(1:end-1)) ;
        % Complex signals in the current window range
        tXh = Xh(tRange,:) ;
        % Computing auto and cross Spectrums
        Sxy     = (transpose(tXh)*conj(tXh))/winSize ;
        Sxx     = real(diag(Sxy)) ;
        SxxSyy  = Sxx*Sxx' ;
        % Pre-define the connectivity matrix for the current freq and window
        CorrMat = zeros(nSig) ;  
        % Compute the desired measure 
        switch OPTIONS.CohMeasure
            case 'coh'  % Coherence
                CorrMat = Sxy./sqrt(SxxSyy) ;
            case 'lcoh' % Lagged-Coherence
                CorrMat = (imag(Sxy)./sqrt(SxxSyy-(real(Sxy).^2))) ;
            case 'penv' % Envelope Correlation (Plain - No Orthogonalization)
                CorrMat = corrcoef(abs(tXh)) ;
            case 'oenv'  % Envelope Correlation (Orthogonalized) 
                if ~parMode
                    Xext    = repmat(tXh,1,nSig) ;
                    Yext    = repelem(tXh,1,nSig) ;    
                    Yext_p  = imag(bsxfun(@times, Yext, conj(Xext)./abs(Xext)));
                    CorrMat = reshape(diag(corr(abs(Xext),abs(Yext_p))),nSig,nSig) ;
                else % Using parallel processing
                    parfor k = 1:nSig
                        Xext    = tXh(:,k) ;
                        Yext    = tXh ;
                        Yext_p  = imag(bsxfun(@times, Yext, conj(Xext)./abs(Xext)));
                        CorrMat(k,:) = corr(abs(Xext),abs(Yext_p)) ;
                    end
                end
        end
        % No auto-correlation 
        CorrMat(logical(eye(nSig))) = 0 ;
        % We assume all measures are real, non-negative, and symmetric
        A(:,:,t,f) = (abs(CorrMat) + abs(CorrMat'))/2 ;      
    end
end

%% Outputs
if OPTIONS.HStatDyn == 1   % Dynamic (Time-varying networks)
    varargout{1} = A ;
    varargout{2} = timePoints/Fs ;
else                       % Static (Average among all networks)
    varargout{1} = nanmean(A,3) ;
    varargout{2} = median(timePoints/Fs) ;
end
end

