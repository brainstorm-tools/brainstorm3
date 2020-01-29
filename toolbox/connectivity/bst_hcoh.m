function varargout = bst_hcoh(Data,OPTIONS)
%% Inputs and Outputs Definition:
%
% INPUTS:
%   - Data                   : Input signals (nSignals x nSamples)
%   - OPTIONS: 
%     - Fs                   : Sampling frequency
%     - Method               : Desired measure of correlation
%                              'coh' - coherence
%                              'lcoh'- lagged coherence
%                              'env' - envelope correlation
%     - Windowing parameters : winSize:  window size in second for dynamic network reconstruction
%           noverlap: overlap between windows in second, should be smaller
%           than winSize.
%
% OUTPUTS:
%
% ------------------------------------------
% Example:
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
[nSig,N]     = size(Data) ;
Fs           = OPTIONS.SampleRate ;
winSize      = OPTIONS.WinParam(1) * Fs ;
overLap      = OPTIONS.WinParam(2) * winSize ;
numBlocks    = OPTIONS.tfSplit ;
parMode      = OPTIONS.parMode ;
numPool      = OPTIONS.numParPool ;
ExtraInf     = OPTIONS.ExtraInf ;

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
hopSize    = fix(winSize-overLap) ;
nWindows   = fix((N-winSize)/hopSize)+1 ;
timePoints = NaN(nWindows,1) ;            % Pre-define the center of windows 

% Removing mean from the data 
Data = bst_bsxfun(@minus, Data, mean(Data,2)) ;

% Block analysis for large files 
if numBlocks>1
    tfBlockRem = rem(N,numBlocks) ;
    % Adding zero to the end of the data (few samples)
    if tfBlockRem ~= 0
        Data(:,end:end+(numBlocks-tfBlockRem)) = 0 ;
    end
    [~,N]  = size(Data) ;
    actLen = (N/numBlocks) ; 
    % Consider a fixed 2 sec for transient (filter) effect (each side)
    tranLen  = 4 * Fs ;
    % Compute the length of each block
    blockLen3D = actLen + tranLen ; 
    % Pre-define the data in 3D format (Signals x Samples x Blcoks)
    Data3D = zeros(nSig,blockLen3D,numBlocks) ; 
    % Divide data into a 3D structure with overlapping periods 
    for k = 1:numBlocks
        % First block
        if k == 1
            range2D = 1:(blockLen3D-(tranLen/2)) ;
            range3D = ((tranLen/2)+1):blockLen3D ;
        % Last block
        elseif k == numBlocks
            range2D = (N-blockLen3D+(tranLen/2)+1):N ; 
            range3D = 1:(blockLen3D-(tranLen/2)) ;
        else
            range2D = ((k-1)*actLen -(tranLen/2) ) + (1:blockLen3D) ;
            range3D = 1:blockLen3D ; 
        end
        Data3D(:,range3D,k) = Data(:,range2D) ;
    end
    [~,tfBlockLen,~] = size(Data3D) ;
else
    [~,tfBlockLen] = size(Data) ;
end

%% Time-frequency and Connectivity 
% Number of Frequency bins
nfBins = size(OPTIONS.Freqrange,1) ;
% Pre-define the connectivity matrix
A = zeros(nSig,nSig,nWindows,nfBins) ;

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
            Xh((bl-1)*actLen+(1:actLen),:) = transpose(tfOut_tmp(:,(1:actLen)+(tranLen/2))) ;
        end
    else
        OPTIONS_tf.TimeVector = linspace(OPTIONS.TimeWindow(1),OPTIONS.TimeWindow(2),N) ;
        tfOut_tmp = bst_timefreq(Data, OPTIONS_tf) ;
        tfOut_tmp = tfOut_tmp{1}.TF ;
        Xh = transpose(tfOut_tmp) ;
    end
    % Progress bar
    %         bst_progress('stop')  ;
    %         bst_progress('start','Connectivity Analysis', sprintf('Calculating: %s [%dx%d]...',OPTIONS.CohMeasure, nSig, nSig),0,100 );
    %         timePoints = NaN(nWindows,1) ;
    
    %% 
    for t = 1:nWindows
        %             bst_progress('set' , round( ( ((f-1)*nWindows + t)*ExtraInf.trialNum*itr )/(nWindows*nfBins*ExtraInf.nTrials*nIt)*100));
        
        % Selecting the appropriate time points 
        tRange = (t-1)*hopSize+(1:winSize) ;
        % Center of the window
        timePoints(t) = median(tRange(1:end-1)) ;
        % Complex signals 
        tXh = Xh(tRange,:) ;
        %         tXh = bst_bsxfun(@minus, tXh, mean(tXh)) ;
        
        % Computing auto and cross Spectrums
        Sxy     = (transpose(tXh)*conj(tXh))/winSize ;
        Sxx     = real(diag(Sxy)) ;
        SxxSyy  = Sxx*Sxx' ;
        % Pre-define the connectivity matrix for the current freq and window
        CorrMat = zeros(nSig) ;  
        
        switch OPTIONS.CohMeasure
            case 'coh'  % Coherence
                CorrMat = Sxy./sqrt(SxxSyy) ;
            case 'lcoh' % Lagged-Coherence
                CorrMat = (imag(Sxy)./sqrt(SxxSyy-(real(Sxy).^2))) ;
            case 'penv' 
                CorrMat = corrcoef(abs(tXh)) ;
            case 'env'  % Envelope Correlation (Orthogonalized) 
                if ~parMode
                    Xext     = repmat(tXh,1,nSig) ;
                    Yext     = repelem(tXh,1,nSig) ;
                    Yext_p   = bst_bsxfun(@times,Xext,(real(Sxy(:))./repmat(Sxx,nSig,1))') ;
                    Yext     = Yext - Yext_p ;
                    Xext_env = envFunction(Xext) ;
                    Yext_env = envFunction(Yext) ;
                    CorrMat  = reshape(diag(corr(Xext_env, Yext_env)),nSig,nSig) ;
                else % Using parallel processing
                    HParaStart(numPool) ;
                    parfor i = 1:nSig
                        Xext         = repmat(tXh(:,i),1,nSig) ;
                        Yext         = tXh ;
                        Yext_p       = bst_bsxfun(@times,Xext,(real(Sxy(:,i))./repmat(Sxx(i),nSig,1))') ;
                        Yext         = Yext - Yext_p ;
                        Xext_env     = envFunction(Xext) ;
                        Yext_env     = envFunction(Yext) ;
                        CorrMat(:,i) = reshape(diag(corr(Xext_env,Yext_env)),nSig,1) ;
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
if OPTIONS.HStatDyn   % Time-varying networks (Dynamic)
    varargout{1} = A ;
    varargout{2} = timePoints/Fs ;
else % Static network (Average among all time windows)
    varargout{1} = nanmean(A,3) ;
    varargout{2} = median(timePoints/Fs) ;
end

end

%% Envelope function
function y = envFunction(x)
y = abs(x) ;
% y = 2*log10(y) ;
end

%% Parallel Processing 
function HParaStart(parMode)
g1 = gcp('nocreate') ;
if isempty(g1) || (~isempty(g1) && g1.NumWorkers ~= parMode)
    if ~isempty(g1)
        delete(gcp) ;
    end
    myCluster = parcluster('local') ;
    myCluster.NumWorkers = parMode ;
    parpool(parMode)
end
end
