function W = tess_smooth_sources(SurfaceMat, FWHM, Method)
% TESS_SMOOTH_SOURCES: Gaussian smoothing matrix over a mesh.
%
% USAGE:  W = tess_smooth_sources(SurfaceMat, FWHM=0.010, Method='average')
%
% INPUT:
%    - SurfaceMat : cortical surface matrix
%    - FWHM     : Full width at half maximum, in mm (default=10mm)
%    - Method   : {'euclidian', 'geodesic_edge', 'geodesic_length'}
% OUPUT:
%    - W: smoothing matrix (sparse)
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
    Method = 'geodesic_length';
end
if (nargin < 2) || isempty(FWHM)
    FWHM = 10;
end

Vertices = SurfaceMat.Vertices;
VertConn = SurfaceMat.VertConn;
Faces    = SurfaceMat.Faces;

nv = size(Vertices,1);


% ===== ANALYZE INPUT =====
% Calculate Gaussian kernel properties
Sigma = FWHM / (2 * sqrt(2*log2(2)));

[vi,vj] = find(VertConn);
meanDist = mean(sqrt((Vertices(vi,1) - Vertices(vj,1)).^2 + (Vertices(vi,2) - Vertices(vj,2)).^2 + (Vertices(vi,3) - Vertices(vj,3)).^2));


% ===== COMPUTE DISTANCE =====
switch lower(Method)
    % === METHOD 1: USE EUCLIDIAN DISTANCE ===
    case 'euclidian'
        Dist = bst_tess_distance(SurfaceMat, 1:nv, 1:nv, 'euclidian', 1);
    % === METHOD 2: USE NUMBER OF CONNECTIONS =====
    case {'geodesic_edge'}
        Dist = bst_tess_distance(SurfaceMat, 1:nv, 1:nv, 'geodesic_edge', 1);
        Dist = Dist .* meanDist;
    % ===== METHOD 3: Use geodesic distance  =====
    case {'geodesic_length'}
        Dist = bst_tess_distance(SurfaceMat, 1:nv, 1:nv, 'geodesic_length', 1);
end


% ===== APPLY GAUSSIAN FUNCTION =====
% Gaussian function
fun     = @(x,sigma2) 1 / sqrt(2*pi*sigma2) * exp(-(x.^2/(2*sigma2)));

% Calculate interpolation as a function of distance
[vi,vj] = find(Dist>0);
vind    = sub2ind([nv,nv], vi, vj);
w       = fun(Dist(vind), Sigma^2);

% Build final symmetric matrix
W       = sparse(vi, vj, w, nv, nv);
% Add the diagonal
W       = W + fun(0,Sigma^2) * speye(nv);
% Normalize columns
W       = bst_bsxfun(@rdivide, W, sum(W,1));
% Remove insignificant values
%[vi,vj]     = find(W>0.005);
%vind        = sub2ind([nv,nv], vi, vj);
%W           = sparse(vi, vj, W(vind), nv, nv);


% ===== FIX BAD TRIANGLES =====
% Only for methods including neighbor distance
% Todo: check what this is doing :)
if ismember(lower(Method), {'geodesic_edge','geodesic_length'}) 
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
end