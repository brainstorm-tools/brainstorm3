function [vert, faces] = tess_disc(h0)
% TESS_CIRCLE: Create a meshed disc.
%
% USAGE:  [vert, faces] = tess_disc(h0);
%
% INPUTS:
%    - h0 : Initial edge length

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
% Authors: Francois Tadel, 2016

% Parse inputs
if (nargin < 1) || isempty(h0)
    h0 = 0.07;
end

% Distance and edge length function
fd = @(p) sqrt(sum(p.^2,2))-1;
fh = @(p) ones(size(p,1),1);
bbox = [-1,-1;1,1];
pfix = [];

% Use distmesh toolbox
[vert, faces] = distmesh2d(fd, fh, h0, bbox, pfix);




