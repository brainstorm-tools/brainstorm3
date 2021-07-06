function [epX, r, ixs_ctr] = bst_epoching(X, nEpoch, nOverlap)
% BST_EPOCHING: Divides the `X` provided as [nSignals, nSamples] using the 
%               window length `nWinLen` indicated in samples, with an overlap of 
%               `nOverlap` samples  between consecutive epochs.
%
% INPUTS:
%    - X        : 2D array with shape [nSignals, nSamples]
%    - nEpoch   : Number of samples in each epoch
%    - nOverlap : Number of samples for ovelap between epochs (Default 0)
%
% OUTUTS:
%    - epX     : 3D array [nSignals, nEpoch, nEpochs]
%    - r       : 2D array [nSignals, nR] remaining data after last complete epoch
%    - ixs_ctr : 1D array [nEpochs] the sample index to the center of each epoch
%
% Number of epochs, nEpochs = floor((nSamples-nOverlap)/(nEpoch-nOverlap))
%
% e.g 
% Data = 24, nEpoch = 5, nOverlap = 0                   (samples)
% nEpochs = floor (23 / 5) = 4
%
%  |1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4     (Data array)
%  |E1-------|E2-------|E3-------|E4-------|Remainder
%       *         *         *         *                 (* = center of the epoch)      
% ixs_ctr = [3, 8, 13, 18]
% r       = [1, 2, 3, 4]
%
% e.g 
% Data = 24, nEpopch = 5, nOverlap = 2                   (samples)
% nEpochs = floor( (24 - 2) / (5 - 2) ) = 7
%
%  1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4       (Data array)
% |E1-------| |E3-------| |E5-------| |E7-------|
%       |E2-------| |E4-------| |E6-------|     |R| 
%      *           *           *           *           
%            *           *           *                   (* = center of the epoch) 
% ixs_ctr = [3, 6, 9, 12, 15, 18, 21]
% r       = [4]
%
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
%
% Authors: Raymundo Cassani 2021

epX = [];
r = [];
ixs_ctr = [];

% Verify the number of Input arguments
if nargin < 3
    nOverlap = 0;
end

% Obtain parameters of the data
nSignals = size(X,1);
nSamples = size(X,2);

% Size of half epoch
halfEpoch = ceil(nEpoch / 2);
% Epoch shift
nShift = nEpoch - nOverlap;
% Number of epochs
nEpochs = floor( (nSamples - nOverlap) / (nEpoch - nOverlap) );
% If not enough data
if nEpochs == 0
    r = X;
    return
end

% markers indicate where the epochs start
markers = ((0 : (nEpochs-1)) * nShift) + 1;
% Divide data in epochs
epX = zeros(nSignals, nEpoch, nEpochs, class(X));
ixs_ctr = zeros(nEpochs,1);
% Epoching
for iEpoch = 1 : nEpochs
    epX(:,:,iEpoch) = X(:, markers(iEpoch) : markers(iEpoch) + nEpoch - 1);
    ixs_ctr(iEpoch) = markers(iEpoch) -1 + halfEpoch;
end
% If there is remaining
if (markers(end) + nEpoch - 1 < nSamples) 
    r = X(:, markers(end) + nEpoch : nSamples);
end