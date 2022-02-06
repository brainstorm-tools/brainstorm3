function mask = mri_fillholes(mask, dim)
% MRI_FILLHOLES: Detect background, then fill everything that is not background

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
% Authors: Francois Tadel, 2011

% Initialize two accumulators, for the two directions
acc1 = false(size(mask));
acc2 = false(size(mask));
n = size(mask,dim);
% Process in required direction
switch dim
    case 1
        for i = 2:n
            acc1(i,:,:) = acc1(i-1,:,:) | mask(i,:,:);
        end
        for i = n-1:-1:1
            acc2(i,:,:) = acc2(i+1,:,:) | mask(i,:,:);
        end
    case 2
        for i = 2:n
            acc1(:,i,:) = acc1(:,i-1,:) | mask(:,i,:);
        end
        for i = n-1:-1:1
            acc2(:,i,:) = acc2(:,i+1,:) | mask(:,i,:);
        end
    case 3
        for i = 2:n
            acc1(:,:,i) = acc1(:,:,i-1) | mask(:,:,i);
        end
        for i = n-1:-1:1
            acc2(:,:,i) = acc2(:,:,i+1) | mask(:,:,i);
        end
end
% Combine two accumulators
mask = acc1 & acc2;

