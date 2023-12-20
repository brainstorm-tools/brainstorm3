function W = tess_smooth_sources(SurfaceMat, FWHM, Method)
% TESS_SMOOTH_SOURCES: Gaussian smoothing matrix over a mesh.
%
% USAGE:  W = tess_smooth_sources(SurfaceMat, FWHM=0.010, Method='geodesic_dist')
%
% INPUT:
%    - SurfaceMat : Cortical surface matrix
%    - FWHM       : Full Width at Half Maximum, in m (default = 0.010m = 10mm)
%    - Method     : {'euclidian', 'geodesic_edge', 'geodesic_dist' (default)}
% OUPUT:
%    - W          : Smoothing matrix (sparse)
%
% DESCRIPTION: 
%    - Gaussian smoothing function on the euclidian distance:
%      f(r) = 1 / sqrt(2*pi*sigma^2) * exp(-(r.^2/(2*sigma^2)))
%    - Full Width at Half Maximum (FWHM) is related to sigma by:
%      FWHM = 2 * sqrt(2*log2(2)) * sigma

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
% Authors: Francois Tadel, 2010-2013
%          Edouard Delaire, 2023


% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(Method)
    Method = 'geodesic_dist';
end
if (nargin < 2) || isempty(FWHM)
    FWHM = 0.010;
end

Method    = lower(Method);
Vertices  = SurfaceMat.Vertices;
VertConn  = SurfaceMat.VertConn;
Faces     = SurfaceMat.Faces;
Dist      = SurfaceMat.VertDist; 
nVertices = size(Vertices,1);


% Calculate Gaussian kernel properties
if strcmp(Method,'geodesic_edge') % Sigma given in (integer) number of edges
    [vi, vj] = find(VertConn);
    meanDist = mean(sqrt((Vertices(vi,1) - Vertices(vj,1)).^2 + (Vertices(vi,2) - Vertices(vj,2)).^2 + (Vertices(vi,3) - Vertices(vj,3)).^2));
    Sigma = ceil(ceil(FWHM./ meanDist) / (2 * sqrt(2*log2(2))));
else  % Sigma given in meters
    Sigma = FWHM / (2 * sqrt(2*log2(2)));
end

% Ignore long distances
Dist(Dist > 10 * Sigma) = 0;
% Calculate interpolation as a function of distance
[vi, vj, x] = find(Dist);
W           = sparse(vi, vj, GaussianKernel(x,Sigma^2), nVertices, nVertices) + ...
              speye (nVertices) .* GaussianKernel(0,Sigma^2);
% Normalize columns
W           = bst_bsxfun(@rdivide, W, sum(W,1));

% ===== FIX BAD TRIANGLES =====
% Only for methods including neighbor distance
% Todo: check what this is doing :)
if contains(Method, 'geodesic')
    % Configurations to detect: 
    %    - One face divided in 3 with a point in the middle of the face
    %    - Square divided into 4 triangles with one point in the middle
    % Calculate face-vertex connectivity
    VertFacesConn = tess_faceconn(Faces);
    % Find vertices connected to three or four faces
    sumVert  = sum(VertConn,2);
    sumFaces = sum(VertFacesConn,2);
    % Three/Four vertices: average the values of their neighbors
    iVert = find(((sumVert == 3) & (sumFaces == 3)) | ((sumVert == 4) & (sumFaces == 4)));
    AvgConn = bst_bsxfun(@rdivide, W * VertConn(:,iVert), sumVert(iVert)');
    W(iVert,:) = AvgConn';
    W(:,iVert) = AvgConn;
end

% ===== APPLY GAUSSIAN FUNCTION =====
% Gaussian function
function y = GaussianKernel(x,sigma2)
    y = 1 / sqrt(2*pi*sigma2);
    y = y .* exp(-(x.^2/(2*sigma2)));
end
end

