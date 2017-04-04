function sMri = mri_downsample( sMri, n )
% MRI_DOWNSAMPLE: Downsample the volume size by a factor n (integer)
%
% USAGE:  sMri = mri_downsample( sMri, n )
%         Cube = mri_downsample( Cube, n )

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013

% If input is a structure: Get cube
if isstruct(sMri)
    Cube = sMri.Cube;
else
    Cube = sMri;
end
% If volume is too small: error
if any(size(Cube) < 3) || (n <= 1)
    return
end

% Get current size
oldSize = size(Cube);
% Create smoothing kernel for uniform smoothing
K = ones(n,n,n) ./ n^3;
% Apply convolution kernel
Cube = convn(Cube, K ,'same');
% Take 1 voxel every n in each direction
Cube = Cube(1:n:end, 1:n:end, 1:n:end);

% Update full MRI structure
if isstruct(sMri)
    sMri.Cube = Cube;
    % Update voxel size
    fscale = oldSize ./ size(sMri.Cube);
    sMri.Voxsize = fscale .* sMri.Voxsize;
else
    sMri = Cube;
end




