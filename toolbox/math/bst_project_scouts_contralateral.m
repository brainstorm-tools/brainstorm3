function nScoutProj = bst_project_scouts_contralateral( srcSurfFile, sAtlas )
% BST_PROJECT_SCOUTS: Project scouts from left to right hemisphere(need the FreeSurfer registered spheres).
%
% USAGE:  nScoutProj = bst_project_scouts_contralateral( srcSurfFile, sAtlas=[all])

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
% Authors: Francois Tadel, 2015-2019
%          Edouard Delaire, 2022

% ===== PARSE INPUTS ======
if (nargin < 2) || isempty(sAtlas)
    sAtlas = [];
end
nScoutProj = 0;
% ===== GET INTERPOLATION =====

sSurf = in_tess_bst(srcSurfFile);


%% Get Spheres

[rHsrc, lHsrc, isConnected(1)]  = tess_hemisplit(sSurf);




isLeft = ~isempty(intersect(lHsrc,  sAtlas.Scouts.Vertices));
isRight = ~isempty(intersect(rHsrc,  sAtlas.Scouts.Vertices));

if isRight 
    vertSphLsrc = sSurf.Reg.SphereLR.Vertices(rHsrc, : );
    vertSphLdest = sSurf.Reg.Sphere.Vertices(lHsrc, : );
    
    nDest = length(lHsrc);
    nSrc = length(rHsrc);

    [~, sScout_Vertices] = intersect(rHsrc,sAtlas.Scouts.Vertices );


elseif isLeft 
    vertSphLsrc = sSurf.Reg.SphereLR.Vertices(lHsrc, : );
    vertSphLdest = sSurf.Reg.Sphere.Vertices(rHsrc, : );

    nDest = length(rHsrc);
    nSrc = length(lHsrc);
    
    [~, sScout_Vertices] = intersect(lHsrc,sAtlas.Scouts.Vertices);

else
    bst_error('The scout should contains only left or right vertices');
    return;
end

nbNeighbors = 8;
Wmat = bst_shepards(vertSphLdest, vertSphLsrc, nbNeighbors, 0);


% Project scouts one by one and keep for each vertex only the maximum probability
% Vertex map on the original surface
vMap = zeros(nSrc,1);
vMap(sScout_Vertices) = 1;

% Project to destination surface
vMapProj = full(Wmat * vMap);

NewIndex = find(vMapProj > 0.5);

new_scout = sAtlas.Scouts;
new_scout.Label = [new_scout.Label 'projection2'];

if isRight 
    new_scout.Vertices = lHsrc(NewIndex);
else
    new_scout.Vertices = rHsrc(NewIndex);
end
new_scout.Seed = new_scout.Vertices(1);
sSurf.Atlas(1).Scouts(end+1) = new_scout;
bst_save(file_fullpath(srcSurfFile), sSurf, 'v7', 1);

nScoutProj = 1;
end