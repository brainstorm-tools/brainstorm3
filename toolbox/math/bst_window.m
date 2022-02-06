function F = bst_window( Method, L, R )
% BST_WINDOW: Generate a window of length L, ot the given type: hann, hamming, blackman, parzen, tukey
% 
% USAGE:  F = bst_window( Method, L, R )
% 
% References:
%    Formulas documented on Wikipedia: http://en.wikipedia.org/wiki/Window_function

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
% Authors: Francois Tadel, 2013-2014

% Parse inputs
if (nargin < 3) || isempty(R)
    R = [];
end
if (nargin < 2) || isempty(L)
    L = 64;
end
if (nargin < 1) || isempty(Method)
    Method = 'hann';
end
% Calculate normalized time vector
t = (0:L-1)' ./ (L-1);
% Switch according to windowing method 
switch (lower(Method))
    case 'hann'
        F = 0.5 - 0.5 * cos(2*pi*t);
    case 'hamming'
        F = 0.54 - 0.46 * cos(2*pi*t);
    case 'blackman'
        F = 0.42 - 0.5 * cos(2*pi*t) + 0.08 * cos(4*pi*t);
    case 'tukey'
        % Tukey window = tapered cosine window, cosine lobe of width aL/2 
        if isempty(R)
            R = 0.5;
        end
        a = R;
        % If a=0: square function
        if (a <= 0)
            F = ones(L,1);
        % If a=1: Hann window
        elseif (a >= 1)
            F = bst_window('hann', L);
        % Else: Function in three blocks
        else
            % Define three blocks
            len = floor(a*(L-1)/2) + 1;
            t1 = t(1:len);
            t3 = t(L-len+1:end);
            % Window is defined in three sections: taper, constant, taper
            F = [ 0.5 * (1 + cos(pi * (2*t1/a - 1)));  ...
                  ones(L-2*len,1); ...
                  0.5 * (1 + cos(pi * (2*t3/a - 2/a + 1)))];
        end
    case 'parzen'
        % Reference:
        % Harris FJ, On the Use of Windows for Harmonic Analysis with the Discrete Fourier Transform, 
        % Proceedings of IEEE, Vol. 66, No. 1, January 1978   [Equation 37]
        
        % Time indices
        t = -(L-1)/2 : (L-1)/2;
        i1 = find(abs(t) <= (L-1)/4);  %   0 <= |n| <= N/4
        i2 = find(abs(t) >  (L-1)/4);  % N/4 <  |n| <  N/2
        
        % Definition of the Parzen window: 2 parts
        F = zeros(length(t), 1);
        F(i1) = 1 - 6 .* (t(i1)/L*2).^2 .* (1 - abs(t(i1))/L*2);
        F(i2) = 2 .* (1 - abs(t(i2))/L*2) .^3;
        
    otherwise
        error(['Unsupported windowing method: "' Method '".']);
end


