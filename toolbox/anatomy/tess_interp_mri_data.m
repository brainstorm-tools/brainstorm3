function OverlayCube = tess_interp_mri_data( tess2mri_interp, cubeSize, dataToProject, isVolumeGrid )
% TESS_INTER_MRI_DATA: Create a 3D volume with the values interpolated from a surface or a grid.

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
% Authors: Francois Tadel, 2008-2016

% Parse inputs
if (nargin < 4)
    isVolumeGrid = 0;
end

% Build new OverlayCube
[iMri,iVert,Val] = find(tess2mri_interp);
iMri = int32(iMri);
VertVal = single(dataToProject(iVert) .* Val); clear Val

% Create overlay cube (same size than the MRI, displayed as indexed color)
OverlayCube = zeros(cubeSize, 'single');
% iMriInitial = iMri;
% Add non-zero values
while ~isempty(iMri)
    % Add lasting unique values
    [iMriUnique, I] = unique(iMri);
    OverlayCube(iMriUnique) = OverlayCube(iMriUnique) + VertVal(I);
    
    % Remove these unique values
    iMri(I)    = [];
    VertVal(I) = [];
end

% === VOLUME GRID: FILL HOLES ===
if isVolumeGrid
    % Copy non-zero lines to zero lines
    Xfull = 2:cubeSize(1)-1;
    Yfull = 2:cubeSize(2)-1;
    Zfull = 2:cubeSize(3)-1;
    Xdata = 3 .* floor((Xfull+2) ./ 3) - 1;
    Ydata = 3 .* floor((Yfull+2) ./ 3) - 1;
    Zdata = 3 .* floor((Zfull+2) ./ 3) - 1;
    OverlayCube(Xfull, Yfull, Zfull) = OverlayCube(Xfull, Yfull, Zfull) + (OverlayCube(Xfull, Yfull, Zfull) == 0) .* OverlayCube(Xdata, Ydata, Zdata);
end





