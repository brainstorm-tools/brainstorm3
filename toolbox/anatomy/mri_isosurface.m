function [Faces, Vertices] = mri_isosurface(mrimask, tol)
% MRI_COREGISTER: Same as Matlab's isosurface, with a workaround for a bug in Matlab 2017b.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2017

% Workaround for bug in Matlab 2017b
if (bst_get('MatlabVersion') == 903)
    % Run a simplied version of the isosurface algorithm, that does not collapse the shared vertices
    [Faces, Vertices] = isosurface(mrimask, tol, 'noshare');
    % Share the vertices manually
    relative_tolerance = 1e-12;
    sz = size(Vertices);
    [C, ~, IC] = uniquetol(Vertices, relative_tolerance);
    Vertices = reshape(C(IC),sz);
    % Collapse duplicate vertices.
    [Vertices, ~, IC] = unique(Vertices, 'rows', 'stable');
    Faces = IC(Faces);
else
    [Faces, Vertices] = isosurface(mrimask, tol);
end


