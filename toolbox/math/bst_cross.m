function p = bst_cross(x,y,dim)
% BST_CROSS: Cross product between two sets, each set with three columns
% 
% USAGE:  p = bst_cross(x,y)
%         p = bst_cross(x,y,dim)
%
% INPUT:
%     - x   : [1,3] double or single
%     - y   : [1,3] double or single
%     - dim : dimension along which to compute the cross product
%
% NOTE:
%     - Does exactly then same as the Matlab 'cross' function, but much faster.

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

% Default: dim=1
if (nargin < 3) || isempty(dim)
    dim = 1;
end
% Check size
if (size(x,dim)~=3) || (size(y,dim)~=3)
    error(' Must have three columns ');
end
% Compute cross product
if (dim == 2)
    p = [x(:,2).*y(:,3) - x(:,3).*y(:,2),...
         x(:,3).*y(:,1) - x(:,1).*y(:,3),...
         x(:,1).*y(:,2) - x(:,2).*y(:,1)];
else
    p = [x(2,:).*y(3,:) - x(3,:).*y(2,:);...
         x(3,:).*y(1,:) - x(1,:).*y(3,:);...
         x(1,:).*y(2,:) - x(2,:).*y(1,:)];
end


   
