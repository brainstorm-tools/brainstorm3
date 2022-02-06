function mrimask = tess_mrimask(cubeSize, tess2mri_interp)
% TESS_MRIMASK: Compute the brain mask for the input MRI.

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
% Authors: Francois Tadel, 2010-2011

% === INITIALIZE ==
% Initialize mask
mrimask = false(cubeSize);
% Copy cortex border in mask
mrimask(any(tess2mri_interp,2)) = 1;

% === CROP MASK ===
% Get the coordinates of the edge voxels
iEdge = find(any(tess2mri_interp,2));
[xEdge,yEdge,zEdge] = ind2sub(cubeSize, iEdge);
% Get bounding box
xBounds = [max(min(xEdge)-1, 1), min(max(xEdge)+1, cubeSize(1))];
yBounds = [max(min(yEdge)-1, 1), min(max(yEdge)+1, cubeSize(2))];
zBounds = [max(min(zEdge)-1, 1), min(max(zEdge)+1, cubeSize(3))];
% If the bottom of the surface is not closed (ICBM152 head surface template for instance): Close it
if (zBounds(1) == 1)
    for i = xBounds(1):xBounds(2)
        yedge = find(mrimask(i,:,1));
        mrimask(i,min(yedge):max(yedge),1) = 1;
    end
end
% Get cropped cube size
cropSize = [xBounds(2)-xBounds(1), yBounds(2)-yBounds(1), zBounds(2)-zBounds(1)] + 1;
% Crop brain mask
cropMask = mrimask(xBounds(1):xBounds(2), yBounds(1):yBounds(2), zBounds(1):zBounds(2));
% Dilate border
cropMask = mri_dilate(cropMask);


% === CREATE INITIAL OUTSIDE MASK ===
% Create an initial mask of outside 
% outMask = repmat(~any(cropMask,1), [cropSize(1),1,1]) & ...
%           repmat(~any(cropMask,2), [1,cropSize(2),1]) & ...
%           repmat(~any(cropMask,3), [1,1,cropSize(3)]);

% Create a volume where value = z
zVol(1,1,:) = 1:cropSize(3);
zVol = repmat(zVol, [cropSize(1),cropSize(2),1]);
zVol(~cropMask) = NaN;
% Get min and max value (starting and ending of the mask)
zMin = min(zVol,[],3);
zMax = max(zVol,[],3);
% Get all the detected outside vertices
iOutside = cell(cropSize(1),cropSize(2));
for i = 1:cropSize(1)
    for j = 1:cropSize(2)
        if ~isnan(zMin(i,j))
            lenVect = ones(1, zMax(i,j) - zMin(i,j) + 1);
            iOutside{i,j} = sub2ind(cropSize, i .* lenVect, j .* lenVect, zMin(i,j):zMax(i,j));
        end
    end
end
iOutside = [iOutside{:}];
% Report the detected outside voxels
outMask = true(cropSize);
outMask(iOutside) = 0;

% === EXPAND OUTSIDE MASK ===
added = 1;
% Dilate as long as there are still voxels added to the outside mask
while (added > 0)
    nBefore = nnz(outMask);
    outMask = mri_dilate(outMask) & ~cropMask;
    nAfter = nnz(outMask);
    added = nAfter - nBefore;
end

% === RETURN BRAIN MASK ===
% Copy back the complement of outside mask in the full volume
mrimask(xBounds(1):xBounds(2), yBounds(1):yBounds(2), zBounds(1):zBounds(2)) = ~outMask;




