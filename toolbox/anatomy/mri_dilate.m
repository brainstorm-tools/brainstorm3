function dilateVol = mri_dilate( vol, n )
% MRI_DILATE: Morphological dilatation of a 3D mask.
% 
% USAGE:  dilateVol = mri_dilate( vol, n )
%         dilateVol = mri_dilate( vol )
%
% INPUT:
%    - vol : 3D volume
%    - n   : Number or times to call the algorithm

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
% Authors: Francois Tadel, 2008-2011

% Parse inputs
if (nargin < 2) || isempty(n)
    n = 1;
end
% Initialize returned volume
dilateVol = vol;
% If volume is too small, cannot perform dilatation
if any(size(vol) < 3)
    return
end

% Call function n times
for i = 1:n
    % Center
    dilateVol(2:end-1, 2:end-1, 2:end-1) = ...
        ... % BASE
        vol(2:end-1, 2:end-1, 2:end-1) | ... 
        ... % X
        vol(1:end-2, 2:end-1, 2:end-1) | ...
        vol(3:end,   2:end-1, 2:end-1) | ...
        ... % Y
        vol(2:end-1, 1:end-2, 2:end-1) | ...
        vol(2:end-1, 3:end,   2:end-1) | ...
        ... % Z
        vol(2:end-1, 2:end-1, 1:end-2) | ...
        vol(2:end-1, 2:end-1, 3:end);
    % Border X
    dilateVol(1, :, :)   = vol(2, :, :);
    dilateVol(end, :, :) = vol(end-1, :, :);
    % Border Y
    dilateVol(:, 1, :)   = vol(:, 2, :);
    dilateVol(:, end, :) = vol(:, end-1, :);
    % Border Z
    dilateVol(:, :, 1)   = vol(:, :, 2);
    dilateVol(:, :, end) = vol(:, :, end-1);
    % Copy previous volume
    if (n > 1)
        vol = dilateVol;
    end
end




