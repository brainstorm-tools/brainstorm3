function [A, timePoints, nWindows] = bst_henv(X, Y, Time, OPTIONS)
% BST_HENV Compute the time-varying Coherence and Envelope measures
%
% INPUTS:
%   - X            : Input signals [Nsignals x Ntimes]
%   - Y            : Input signals [Nsignals x Ntimes]
%   - Time         : Time values for all the samples of the input signal
%   - OPTIONS:
%     - SampleRate : Sampling frequency
%     - CohMeasure : Desired measure of connectivity
%                    'coh'  - coherence
%                    'lcoh' - lagged coherence
%                    'penv' - plain envelope correlation (No Orthogonalization)
%                    'oenv' - orthogonalized envelope correlation
%     - WinLength  : window size in second for dynamic networks
%     - WinOverlap : overlap between windows in percentage
%     - HStatDyn   : Time scale of the network ('dynamic' or 'static')
%     - tfSplit    : Number of blocks to split the raw signal for time-frequnecy analysis
%     - isParallel : Parallel Processing option (1 when it is enabled)
%     - tfMeasure  : Time-frequency transformation method (Hilbert/Morlet)
%
% OUTPUTS:
%   - A            : Four-dimensional connectivity matrix (nSignals x nSignals x nWindows x nfBins)
%   - timePoints   : Time vector corresponding to the connectivity matrix
%   - nWindows     : Number of estimator windows
%
% REFERENCES:
%   - Comparisons with previous AEC implementation is discussed on the forum: https://neuroimage.usc.edu/forums/t/30358
%
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
% Author: Hossein Shahabi, 2020-2022


%% ~~~~~ Checking Input Variables
if (nargin < 4)
    error('Invalid call.');
end

% Signal properties
nX      = size(X,1);
nY      = size(Y,1);
N       = size(X,2);
% Check if the two inputs are the same 
sameInp = isequal(X,Y);

% Options for connectivity analysis 
Fs        = OPTIONS.SampleRate ;
winSize   = OPTIONS.WinLength * Fs ;
overLap   = OPTIONS.WinOverlap * winSize ;
numBlocks = OPTIONS.tfSplit ;
parMode   = OPTIONS.isParallel ;

% Time-frequency options
OPTIONS_tf.Method        = OPTIONS.tfMeasure;
OPTIONS_tf.Output        = 'all' ;
OPTIONS_tf.Comment       = [] ;
OPTIONS_tf.ListFiles     = [] ;
OPTIONS_tf.iTargetStudy  = [] ;
OPTIONS_tf.RowNames      = cell(nX,1);
OPTIONS_tf.Measure       = 'none' ;

%% ~~~~~~ Constant definition and pre-allocation
% Compute the parameters for window
hopSize    = ceil(winSize-overLap) ;
nWindows   = fix((N-winSize)/hopSize)+1 ;
if (nWindows == 0)
    error('No data to process: the estimator window is maybe larger than the data to process.');
end
timePoints = NaN(nWindows,1) ;                   % Pre-define the center of windows
nfBins     = size(OPTIONS.Freqrange,1) ;         % Number of Frequency bins
A          = zeros(nX,nY,nWindows,nfBins) ;  % Pre-define the connectivity matrix
% Data       = bst_bsxfun(@minus, Data, mean(Data,2)) ;  % Removing mean from the data

%% Block analysis for large files
% Consider a fixed 5 sec for transient (filter) effect (each side)
tranLen = 5 * Fs ;
if numBlocks>1
    [X_Data3D, blockLen3D, actLen] = dataDimTran(X,tranLen,numBlocks) ;
    if ~sameInp
        Y_Data3D = dataDimTran(Y,tranLen,numBlocks) ; 
    end
end

%%
for f = 1:nfBins
    %% Time-frequency transformation
    switch OPTIONS.tfMeasure
        case 'hilbert'
            OPTIONS_tf.Freqs        = OPTIONS.Freqrange(f,:);
        case 'morlet'
            OPTIONS_tf.Freqs        = OPTIONS.Freqrange(f) ;
            OPTIONS_tf.MorletFc     = OPTIONS.MorletFc ;
            OPTIONS_tf.MorletFwhmTc = OPTIONS.MorletFwhmTc ;
    end
    
    % Predefine the complex frequency domain signal
    Xh = zeros(N,nX) ;
    if ~sameInp
        Yh = zeros(N,nY) ;
    end
    if numBlocks>1
        OPTIONS_tf.TimeVector = linspace(Time(1),blockLen3D/Fs,blockLen3D) ;
        for bl = 1:numBlocks
            % Compute Frequency Transform for X
            tfOut_tmp = bst_timefreq(X_Data3D(:,:,bl), OPTIONS_tf) ;
            tfOut_tmp = tfOut_tmp{1}.TF ;
            % We select the middle part of each block and drop "tranLen" on each side
            Xh((bl-1)*actLen+(1:actLen),:) = transpose(tfOut_tmp(:,(1:actLen)+tranLen)) ;
            if ~sameInp
                % Compute Frequency Transform for Y
                tfOut_tmp = bst_timefreq(Y_Data3D(:,:,bl), OPTIONS_tf) ;
                tfOut_tmp = tfOut_tmp{1}.TF ;
                % We select the middle part of each block and drop "tranLen" on each side
                Yh((bl-1)*actLen+(1:actLen),:) = transpose(tfOut_tmp(:,(1:actLen)+tranLen)) ;
            end
        end
    else
        OPTIONS_tf.TimeVector = Time;
        % Compute Frequency Transform for X
        tfOut_tmp = bst_timefreq(X, OPTIONS_tf) ;
        tfOut_tmp = tfOut_tmp{1}.TF ;
        Xh        = transpose(tfOut_tmp) ;
        if ~sameInp
            % Compute Frequency Transform for X
            tfOut_tmp = bst_timefreq(Y, OPTIONS_tf) ;
            tfOut_tmp = tfOut_tmp{1}.TF ;
            Yh        = transpose(tfOut_tmp) ;
        end
    end
    
    %% Connectivity computation
    for t = 1:nWindows
        % Display progress in command window
        strProgress = sprintf('HENV> Connectivity analysis: win%4d/%d, freq%4d/%d', t, nWindows, f, nfBins);
        if (t > 1) || (f > 1)
            strProgress = [repmat('\b', 1, length(strProgress)), strProgress];
        end
        fprintf(1, strProgress);
        % Selecting the appropriate time points
        tRange = (t-1)*hopSize+(1:winSize) ;
        % Center of the window
        timePoints(t) = median(tRange(1:end-1)) ;
        % Complex signals in the current window range
        tXh = Xh(tRange,:) ;
        tYh = tXh ; 
        if ~sameInp
            tYh = Yh(tRange,:) ;
        end
        % Computing auto and cross Spectrums
        Sxy     = (transpose(tXh)*conj(tYh))/winSize ;
        Sxx     = real(diag((transpose(tXh)*conj(tXh))/winSize)) ;
        Syy     = real(diag((transpose(tYh)*conj(tYh))/winSize)) ;
        SxxSyy  = Sxx*Syy' ;
        % Pre-define the connectivity matrix for the current freq and window
        CorrMat = zeros(nX,nY) ;
        % Compute the desired measure
        switch OPTIONS.CohMeasure
            case 'coh'  % Coherence
                CorrMat = Sxy./sqrt(SxxSyy) ;
            case 'lcoh' % Lagged-Coherence
                CorrMat = (imag(Sxy)./sqrt(SxxSyy-(real(Sxy).^2))) ;
            case 'penv' % Envelope Correlation (Plain - No Orthogonalization)
                CorrMat = HMatCorr(abs(tXh),abs(tYh)) ;
            case 'oenv' % Envelope Correlation (Orthogonalized)
                if parMode     % Using parallel processing
                    parfor k = 1:nX
                        CorrMat(k,:) = HOrthCorr(tXh(:,k),tYh) ;
                    end
                else 
                    for k = 1:nX
                        CorrMat(k,:) = HOrthCorr(tXh(:,k),tYh) ; 
                    end
                end
        end
        if sameInp
            % No auto-correlation
%            CorrMat(logical(eye(nX))) = 0 ;
            % We assume all measures are real, non-negative, and symmetric
%             A(:,:,t,f) = (abs(CorrMat) + abs(CorrMat'))/2 ;
        else
        end
        A(:,:,t,f) = abs(CorrMat) ;

    end
end
fprintf(1, '\n');

%% Outputs
switch (OPTIONS.HStatDyn)
    case 'dynamic'  % Time-varying networks
        timePoints = timePoints/Fs ;
    case 'static'   % Average among all networks
        A = bst_nanmean(A,3);
        timePoints = median(timePoints/Fs) ;
end
end

function [Data3D,blockLen3D,actLen] = dataDimTran(Data2D,tranLen,numBlocks)
% Total Length of the Data
[nSig,N] = size(Data2D) ;
actLen   = ceil(N/numBlocks) ;
tfBlockRem = rem(N,numBlocks) ;

% If transition length is longer than block length, then the block #2 crashes in the for loop below
% Exclude this case asking the user to use less blocks (FT 11-NOV-2022)
% Reference: https://neuroimage.usc.edu/forums/t/error-using-envelope-correlation-2022/37624
if (actLen <= tranLen)
    error(['When splitting large data in multiple blocks, the function bst_henv.m adds' 10 ...
           'a hard-coded transition of 5s before and after each block.' 10 ...
           'Decrease the number of blocks to obtain individual blocks longer than 5s.']);
end

% Adding zero to the end of the data (few samples)
% WARNING (FT 11-NOV-2022): If tfBlockRem=1, then it adds a completely empty block. 
% Shouldn't this last block be discarded instead?
if tfBlockRem ~= 0
    Data2D(:,end:end+(actLen-tfBlockRem)) = 0;
end

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
    Data3D(:,range3D,k) = Data2D(:,range2D) ;
end
end

function ConVec = HOrthCorr(tXh,tYh)
Xh_p   = imag(bsxfun(@times, tXh, conj(tYh)./abs(tYh)));
Yh_p   = imag(bsxfun(@times, tYh, conj(tXh)./abs(tXh)));
r1     = HMatCorr(abs(tXh),abs(Yh_p)) ;
r2     = diag(HMatCorr(abs(Xh_p),abs(tYh)))' ;
ConVec = (abs(r1)+abs(r2))/2 ;
end

function At = HMatCorr(U,V)
% Implementation H.Shahabi (2021)
% % Number of channels 
% n1 = size(U,2) ; 
% n2 = size(V,2) ; 
% At = zeros(n1,n2) ; 
% for k = 1:n1
%     for m = 1:n2
%         tmp1    = corrcoef(U(:,k),V(:,m)) ;
%         At(k,m) = tmp1(1,2) ; 
%     end
% end

% Equivalent implementation F.TADEL (14-11-2022)
Uc = U - mean(U,1);  % Remove mean
Vc = V - mean(V,1);  % Remove mean
At = (Uc' * Vc) ./ sqrt(sum(Uc.*Uc,1) .* sum(Vc.*Vc,1));

end
