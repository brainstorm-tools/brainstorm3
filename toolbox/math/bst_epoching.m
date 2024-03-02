function [Xe, epochIxs, R] = bst_epoching(X, epochLength, epochOverlap, dimX, avgEpoch)
% BST_EPOCHING: Divides 'X' in epochs (or windows) using the epoch length 'epochLength'
%               and overlap between consecutive epochs 'epochOverlap' both in samples.
%               Epoching is done on the last dimension of 'X', or dimension `dimX` if indicated.
%               If 'avgEpoch' = 1, the average per epoch is computed
%
% INPUTS:
%    - X            : N dimension array
%    - epochLength  : Number of samples in each epoch
%    - epochOverlap : Number of samples for ovelap between epochs (default 0)
%    - dim          : Dimension to perform epoching (default = last dim)
%    - avgEpoch     : Compute epoch average (default = 0)
%
% OUTUTS:
%    - Xe       : Epoched X array: N+1 dimension or N dimension if avgEpoch = 1
%    - epochIxs : Indices for epochs, shape [nEpochs, 2]
%    - R        : N dimension array of remaining data in X after last complete epoch
%
% nEpochs = floor( (nSamples - epochOverlap) / (epochLength - epochOverlap) )
%
% e.g.
% X = [1:10]; epochLength = 5; epochOverlap = 2;
% [Xe, ixs, R] = bst_epoching(X, epochLength, epochOverlap)
%
% nEpochs = floor( (10 - 2) / (5 - 2) ) = 2
%
%  1 2 3 4 5 6 7 8 9 10       (X array)
% |---E1----|     |-R--|
%       |---E2----|
%
% Xe(:,:,1) = [1 2 3 4 5];
% Xe(:,:,2) = [4 5 6 7 8];
% ixs = [1, 5; 4, 8]
% R = [9, 10]
% ixs_ctr = [3, 6, 9, 12, 15, 18, 21]
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
%
% Authors: Raymundo Cassani, 2023

Xe = [];
epochIxs = [];
R = [];

% Verify the number of Input arguments
if nargin < 5 || isempty(avgEpoch)
    avgEpoch = 0;
end
if nargin < 4 || isempty(dimX)
    dimX = 0;
end
if nargin < 3 || isempty(epochOverlap)
    epochOverlap = 0;
end

% X dimensions
sizeX = size(X);
if dimX == 0
    dimX = length(sizeX);
end
nSamples = sizeX(dimX);

% Epoch shift
nShift = epochLength - epochOverlap;
% Number of epochs
nEpochs = floor( (nSamples - epochOverlap) / (epochLength - epochOverlap) );
% If not enough data
if nEpochs == 0
    R = X;
    return
end
% Epoch Start and End indices
epochIxs = zeros(nEpochs, 2);
epochIxs(:, 1) = ((0 : (nEpochs-1))' * nShift) + 1;
epochIxs(:, 2) = epochIxs(:, 1) + epochLength - 1;

% Initialize Xe
if ~avgEpoch
    % Add extra dimension for indexing epochs
    sizeXe = [sizeX, nEpochs];
    % Resise dimX to number of samples per epoch
    sizeXe(dimX) = epochLength;
else
    % Xe has the same size as X, but nEpochs instead of nSamples
    sizeXe = sizeX;
    sizeXe(dimX) = nEpochs;
end
Xe = zeros(sizeXe, class(X));

% Args to index X
ixX = cell(size(sizeX));
ixX(:) = {':'};
% Args to index Xe
ixXe = cell(size(sizeXe));
ixXe(:) = {':'};

% Epoching
for iEpoch = 1 : nEpochs
    ixX{dimX} = epochIxs(iEpoch, 1) : epochIxs(iEpoch, 2);
    if ~avgEpoch
        % Set epoch data in last dimension of Xe
        dimXe = length(sizeXe);
        ixXe{dimXe} = iEpoch;
        Xe(ixXe{:}) = X(ixX{:});
    else
        % Set mean of epoch data in nEpoch dimension
        dimXe = dimX;
        ixXe{dimXe} = iEpoch;
        Xe(ixXe{:}) = mean(X(ixX{:}), dimX);
    end
end

% If there is remaining in X
if epochIxs(end,2) < nSamples
    ixX{dimX} = epochIxs(iEpoch, 2)+1 : nSamples;
    R = X(ixX{:});
end
