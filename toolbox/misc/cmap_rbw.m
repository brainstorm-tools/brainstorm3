function CMap = cmap_rbw(N)
% CMAP_RBW: Red-blue-white colormap.

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
% Authors: Sylvain Baillet

if (nargin < 1)
    N = 128; % Number of color levels
end

Wwidth = 0;  % Width of the white zero level
Cmin = 0;
Cmax = 1;

Half = floor(N/2);

R1  = linspace(Cmin,Cmax,Half-Wwidth);
R2  = ones(1,Wwidth*2);
R3  = ones(1,Half-Wwidth)*Cmax;
R   = [R1 R2 R3];
B   = fliplr(R);
G3  = fliplr(R1);
G   = [R1 R2 G3];
CMap = [R' G' B'];

