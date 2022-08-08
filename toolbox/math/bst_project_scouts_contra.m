function nScoutProj = bst_project_scouts_contra( srcSurfFile, sAtlas )
% BST_PROJECT_SCOUTS_CONTRA: Project scouts from left to right hemisphere (need the FreeSurfer contralateral spheres: -contrasurfreg).
%
% USAGE:  nScoutProj = bst_project_scouts_contra( srcSurfFile, sAtlas)

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
% Authors: Edouard Delaire, 2022
%          Francois Tadel, 2022    


nScoutProj = 0;

% Load surfaces
sSurf = in_tess_bst(srcSurfFile);
[rHsrc, lHsrc, isConnected(1)]  = tess_hemisplit(sSurf);

% ===== PROCESS ATLAS/SCOUTS =====
for iAtlas = 1:length(sAtlas)
    for iScout = 1:length(sAtlas(iAtlas).Scouts)

        isLeft = ~isempty(intersect(lHsrc,  sAtlas(iAtlas).Scouts(iScout).Vertices));
        isRight = ~isempty(intersect(rHsrc, sAtlas(iAtlas).Scouts(iScout).Vertices));
    
        if isRight 
            vertSphLsrc = sSurf.Reg.SphereLR.Vertices(rHsrc, : );
            vertSphLdest = sSurf.Reg.Sphere.Vertices(lHsrc, : );
            
            nSrc = length(rHsrc);
            [~, sScout_Vertices] = intersect(rHsrc,sAtlas(iAtlas).Scouts(iScout).Vertices );
        elseif isLeft 
            vertSphLsrc = sSurf.Reg.SphereLR.Vertices(lHsrc, : );
            vertSphLdest = sSurf.Reg.Sphere.Vertices(rHsrc, : );
        
            nSrc = length(lHsrc);
            [~, sScout_Vertices] = intersect(lHsrc,sAtlas(iAtlas).Scouts(iScout).Vertices);
        else
            bst_error('The scout should contains only left or right vertices');
            return;
        end
        
        nbNeighbors = 8;
        Wmat = bst_shepards(vertSphLdest, vertSphLsrc, nbNeighbors, 0);
        
        
        % Project scouts one by one and keep for each vertex only the maximum probability
        % Vertex map on the original surface
        vMap                    = zeros(nSrc,1);
        vMap(sScout_Vertices)   = 1;
        
        % Project to destination surface
        vMapProj = full(Wmat * vMap);
        NewIndex = find(vMapProj > 0.5);

        % Get destination atlas
        iAtlasDest = find(strcmpi({sSurf.Atlas.Name}, sAtlas(iAtlas).Name));
        ScoutLabel = sAtlas(iAtlas).Scouts(iScout).Label;

        if isRight 
            ScoutVertices = lHsrc(NewIndex);
            ScoutLabel = [ScoutLabel '_left'];
        else
            ScoutVertices = rHsrc(NewIndex);
            ScoutLabel = [ScoutLabel '_right'];
        end
        ScoutLabel = file_unique(ScoutLabel, {sSurf.Atlas(iAtlasDest).Scouts.Label});

        iScoutDest = length(sSurf.Atlas(iAtlasDest).Scouts) + 1;
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest)          = sAtlas(iAtlas).Scouts(iScout);
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest).Vertices     = ScoutVertices;
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest).Seed     = ScoutVertices(1);
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest).Label    = ScoutLabel;
        nScoutProj = nScoutProj + 1;    
    end
end
% Save destination surface (append the atlas to existing file)
if (nScoutProj > 0)
    s.Atlas = sSurf.Atlas;
    bst_save(file_fullpath(srcSurfFile), s, 'v7', 1);
end

