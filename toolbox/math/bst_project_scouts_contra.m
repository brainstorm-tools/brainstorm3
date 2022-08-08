function sScoutsNew = bst_project_scouts_contra( srcSurfFile, sAtlas, isSave )
% BST_PROJECT_SCOUTS_CONTRA: Project scouts from left to right hemisphere (need the FreeSurfer contralateral spheres: -contrasurfreg).
%
% USAGE:  sScoutsNew = bst_project_scouts_contra( srcSurfFile, sAtlas, isSave=0)

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

if (nargin < 3) || isempty(isSave)
    isSave = 0;
end

% Load surface
sSurf = in_tess_bst(srcSurfFile);
% Check for contralateral surfaces
if ~isfield(sSurf, 'Reg') || ~isfield(sSurf.Reg, 'SphereLR') || ~isfield(sSurf.Reg.SphereLR, 'Vertices') || ~isempty(sSurf.Reg.SphereLR.Vertices)
    error(['No registered contralateral spheres available for this cortex surface.' 10 'Run FreeSurfer with option "-contrasurfreg" in order to use this option.']);
end
% Identify left and right hemispheres
[rHsrc, lHsrc, isConnected(1)]  = tess_hemisplit(sSurf);

% Pre-compute WMAT
nbNeighbors = 8;
Wmat_RL = bst_shepards(sSurf.Reg.Sphere.Vertices(lHsrc, : ),sSurf.Reg.SphereLR.Vertices(rHsrc, : ),  nbNeighbors, 0);
Wmat_LR = bst_shepards(sSurf.Reg.Sphere.Vertices(rHsrc, : ),sSurf.Reg.SphereLR.Vertices(lHsrc, : ),  nbNeighbors, 0);


% ===== PROCESS ATLAS/SCOUTS =====
sScoutsNew = repmat(sAtlas(1).Scouts(1), 0);
for iAtlas = 1:length(sAtlas)
    for iScout = 1:length(sAtlas(iAtlas).Scouts)

        isLeft = ~isempty(intersect(lHsrc,  sAtlas(iAtlas).Scouts(iScout).Vertices));
        isRight = ~isempty(intersect(rHsrc, sAtlas(iAtlas).Scouts(iScout).Vertices));
    
        if isRight 
            Wmat =  Wmat_RL;
            nSrc = length(rHsrc);

            [~, sScout_Vertices] = intersect(rHsrc,sAtlas(iAtlas).Scouts(iScout).Vertices );
        elseif isLeft 
            Wmat =  Wmat_LR;
            nSrc = length(lHsrc);

            [~, sScout_Vertices] = intersect(lHsrc,sAtlas(iAtlas).Scouts(iScout).Vertices);
        else
            bst_error('The scout should contains only left or right vertices');
            return;
        end
        
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
        ScoutRegion = sAtlas(iAtlas).Scouts(iScout).Region;

        if isRight 
            ScoutVertices = lHsrc(NewIndex);
            ScoutLabel = [ScoutLabel ' L'];
            ScoutRegion = strrep(ScoutRegion, 'R', 'L');
        else
            ScoutVertices = rHsrc(NewIndex);
            ScoutLabel = [ScoutLabel ' R'];
            ScoutRegion = strrep(ScoutRegion, 'L', 'R');
        end
        ScoutLabel = file_unique(ScoutLabel, {sSurf.Atlas(iAtlasDest).Scouts.Label});

        iScoutDest = length(sSurf.Atlas(iAtlasDest).Scouts) + 1;
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest).Vertices = ScoutVertices;
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest).Seed     = ScoutVertices(1);
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest).Color    = sAtlas(iAtlas).Scouts(iScout).Color;
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest).Label    = ScoutLabel;
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest).Function = sAtlas(iAtlas).Scouts(iScout).Function;
        sSurf.Atlas(iAtlasDest).Scouts(iScoutDest).Region   = ScoutRegion;
        sScoutsNew = [sScoutsNew, sSurf.Atlas(iAtlasDest).Scouts(iScoutDest)];    
    end
end
% Save destination surface (append the atlas to existing file)
if isSave && ~isempty(sScoutsNew)
    bst_save(file_fullpath(srcSurfFile), sSurf, 'v7');
end

