function [x,tracks] = bst_sin_remove(x, fs, Sinusoids)
% Track frequencies with desired RBW: This version directly convolves with the desired frequency.
%
% USAGE: [x,tracks] = bst_sin_remove(x, fs, Sinusoids)
%
% INPUTS:
%     - x    : Signals to process [nChannels x nTime]
%     - fs   : Sampling frequency of the x signal
%     - Sinusoids: Vector of sinusoids to model and extract, returned in tracks 
%
% OUTPUTS:
%     - x      : Filtered signals [nChannels x nTime]
%     - tracks : 3D matrix of frequencies extracted
%
% NOTE: Requires Signal Processing Toolbox

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
% Authors: JC Mosher, 2010-2011
%          Francois Tadel, 2010-2013

[nRows, nTime] = size(x);
% Ensure column vector
Sinusoids = Sinusoids(:); 
% Resolution bandwidth for frequency tracking
RBW = 1;
% Generate the sampling function
nSamps = round(fs / RBW); 
tndx = (1:nSamps) ./ fs; % Time values, start from one(?)
% Make complex match filter, flipped in time for convolving
cexp_match = exp(-sqrt(-1)*2*pi*Sinusoids*tndx(end:-1:1));
tracks = zeros(nRows,nTime,length(Sinusoids));

% Filter data
for i = 1:size(cexp_match,1)
    tracks(:,:,i) = filter(cexp_match(i,:), 1, x, [], 2);
end
% Further unmixing, i.e. least-squares of the frequency fit
% => Using Matlab's /, assumes high stability!
cexp_match_sq = cexp_match * cexp_match';
for iRow = 1:nRows
    tracks(iRow,:,:) = reshape(tracks(iRow,:,:), nTime, length(Sinusoids)) / cexp_match_sq;
end
% Remove extracted frequencies
x = x - 2*real(sum(tracks,3));




