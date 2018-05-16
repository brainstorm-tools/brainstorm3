function [Lf_cortex, Q_cortex] = bst_xyz2lf(Lf_xyz, normals)
%   This program takes a leadfield matix computed for dipole components
%   pointing in the x, y, and z directions, and outputs a new lead field
%   matrix for dipole components pointing in the normal direction of the 
%   cortical surfaces and in the two tangential directions to the cortex
%   (that is on the tangent cortical space). These two tangential dipole
%   components are uniquely determined by the SVD (reduction of variance).
%
%   Usage: [Lf_cortex,Q_cortex]=bst_xyz2lf(Lf_xyz,normals)
% 
%   Inputs:
%
%   Lf_xyz is the leadfield matrix for the dipoles in the x, y, and z
%   orientations.
%
%   normals is a matrix with cortical surface normals.
%
%   Output:
%
%   Lf_cortex is a leadfield matrix for dipoles in rotated orientations, so
%   that the first column is the gain vector for the cortical normal dipole
%   and the following two column vectors are the gain vectors for the 
%   tangential orientations (tangent space of cortical surface).
%
%   Q_cortex is a matrix with rotated dipole orientations.

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
% Copyright (C) 2010 - Rey Rene Ramirez
%
% Authors:  Rey Rene Ramirez, Ph.D.   e-mail: rrramirez at mcw.edu

[szL1,szL2]      = size(Lf_xyz);
Lf_xyz           = reshape(Lf_xyz,[szL1 3 szL2/3]);
[szL1,szL2,szL3] = size(Lf_xyz);
Lf_cortex        = zeros(szL1,szL2,szL3);

isOutQ = (nargout >= 2);
if isOutQ
    Q_cortex = zeros(3,3,szL3);
end

for k = 1:szL3
    lf_normal   = Lf_xyz(:,:,k) * normals(:,k);
    lf_normal_n = lf_normal ./ norm(lf_normal);
    P = eye(szL1,szL1) - (lf_normal_n * lf_normal_n');
    lf_p = P * Lf_xyz(:,:,k);
    [u,s,v] = svd(lf_p,0);
    Lf_cortex(:,1,k) = lf_normal;
    Lf_cortex(:,[2 3],k) = [u(:,1)*s(1,1), u(:,2)*s(2,2)];
    if isOutQ
        Q_cortex(:,:,k) = [normals(:,k), v(:,1), v(:,2)];
    end
end
Lf_cortex = reshape(Lf_cortex, [szL1, szL2*szL3]);

if isOutQ
    Q_cortex = reshape(Q_cortex, [3, szL2*szL3]);
end





