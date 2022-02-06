function W = morlet_wavelet(t,fc,sigma_tc)
% MORLET_WAVELET: Returns the complex Morlet wavelet for a specified central frequency and
%
% USAGE:  W = morlet_wavelet(t,fc,sigma_tc)
%
% INPUTS:
%    - t       : timepoints where the wavelet will be calculated
%    - fc      : central frequency
%    - sigma_tc: standard deviation of Gaussian kernel in time at the central
%                frequency. Decreasing sigma_tc improves temporal resolution (because
%                the wavelet has smaller temporal extent) at the expense of frequency
%                resolution
%
% Example values:
%    fc = 1;
%    sigma_tc = 1.5;

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
% Authors: Dimitrios Pantazis, 2010
%          Jian Li (Andrew), 2015

% Complex Morlet wavelet
W = (sigma_tc*sqrt(pi))^(-0.5) * exp( -(t.^2)/(2*sigma_tc^2) ) .* exp(1i*2*pi*fc*t);

%Andrew:  W = (2 * pi * sigma_tc^2)^(-0.5) * exp( -(t.^2)/(2*sigma_tc^2) ) .* exp(1i*2*pi*fc*t);



