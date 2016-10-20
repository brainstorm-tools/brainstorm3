function coord_w = minc_voxel2world(coord_v,mat,opt);
% Convert coordinates in the voxel space into coordinates in the world
% space. 
%
% SYNTAX:
% COORD_W = MINC_VOXEL2WORLD(COORD_V,MAT,OPT)
%
% _________________________________________________________________________
% INPUTS:
%
% COORD_V
%       (matrix N*3) each row is a vector of 3D coordinates in voxel space.
%
% MAT
%       (matrix 4*4) an affine transformation from voxel to world
%       coordinates. See the help of NIAK_READ_VOL for more infos. It is 
%       generally the HDR.INFO.MAT field of the header of a volume file.
%
% OPT
%       (structure, optional) with the following fields :
%
%       FLAG_ZERO
%           (boolean, default false) if FLAG_ZERO is true, voxel 
%           coordinates start from 1 (default behaviour in matlab), 
%           otherwise they start from 0 (default behaviour in C/C++ or 
%           MINC).
%
% _________________________________________________________________________
% OUTPUTS:
%
% COORD_W
%       (matrix N*3) each row is a vector of 3D coordinates in world space.
%
% _________________________________________________________________________
% SEE ALSO:
% MINC_READ, MINC_WRITE, MINC_VOXEL2WORLD, MINC_WORLD2VOXEL
%
% _________________________________________________________________________
% COMMENTS:
%
% Copyright (c) Pierre Bellec, Centre de recherche de l'institut de
% gériatrie de Montréal, Département d'informatique et de recherche
% opérationnelle, Université de Montréal, 2013.
% See licensing information in the code.
% Keywords : affine transformation, coordinates

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.
if nargin < 3
    flag_zero = false;
else
    if isfield(opt,'flag_zero')
        flag_zero = opt.flag_zero;
    else
        flag_zero = false;
    end
end
if flag_zero
    coord_w = [coord_v ones([size(coord_v,1) 1])]*(mat');
else
    coord_w = [coord_v-1 ones([size(coord_v,1) 1])]*(mat');
end
coord_w = coord_w(:,1:3);