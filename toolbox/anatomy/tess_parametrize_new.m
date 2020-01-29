function [fr,th_val,phi_val] = tess_parametrize_new(vert, th_val, phi_val, p)
% TESS_PARAMETRIZE_NEW: Get a parametric representation of a closed and non-overlapping surface.
%
% USAGE:  tess_parametrize_new(vert, th_val, phi_val, p)
%         tess_parametrize_new(vert, th_val, phi_val)
% 
% INPUTS: 
%    - vert    : x,y,z coordinates of the surface to parametrize
%    - th_val  : Row array of theta values
%    - phi_val : Row array of phi values
%    - p       : Pad the function of p values in both direction with circular values

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
% Authors: Francois Tadel, 2011

% Parse inputs
if (nargin < 4) || isempty(p)
    p = 0;
end

% Convert surface to spherical coordinates
[th,phi,r] = cart2sph(vert(:,1), vert(:,2), vert(:,3));
% Replicate the values to get a full coverage at the edges
th  = [th;  th;        th;        th+2*pi;  th+2*pi;  th+2*pi;   th-2*pi;  th-2*pi;  th-2*pi  ];
phi = [phi; phi+2*pi;  phi-2*pi;  phi;      phi+2*pi; phi-2*pi;  phi;      phi+2*pi; phi-2*pi ];
r   = [r;   r;         r;         r;        r;        r;         r;        r;        r        ];

% Build grid of (theta,phi) values
[fth, fphi] = meshgrid(th_val, phi_val);
% Estimate radius values for all those points
fr = griddata(th, phi, r, fth, fphi);

% Pad function with circular values, to avoid edge irregularities
if (p > 0)
    fr_pad  = bst_pad(fr, [0  p], 'circular');
    fr_pad  = bst_pad(fr_pad, [p  0], 'mirror');
    fr = fr_pad;
    th_val  = [th_val(end-p+1:end)-2*pi,  th_val,  th_val(1:p)+2*pi];
    phi_val = [phi_val(end-p+1:end)-2*pi, phi_val, phi_val(1:p)+2*pi];
end


