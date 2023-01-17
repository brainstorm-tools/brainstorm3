function [nScoutProj, destSurfMat, sAtlasProj] = bst_project_scouts( srcSurfFile, destSurfFile, sAtlas, isSingleHemi, isSave )
% BST_PROJECT_SCOUTS: Project scouts on a different surface (need the FreeSurfer registered spheres).
%
% USAGE:  [nScoutProj, destSurfMat, sAtlasProj] = bst_project_scouts( srcSurfFile, destSurfFile, sAtlas=[all], isSingleHemi=0, isSave=1 )

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
% Authors: Francois Tadel, 2015-2023

% ===== PARSE INPUTS ======
if (nargin < 5) || isempty(isSave)
    isSave = 1;
end
if (nargin < 4) || isempty(isSingleHemi)
    isSingleHemi = 0;
end
if (nargin < 3) || isempty(sAtlas)
    sAtlas = [];
end
nScoutProj = 0;
destSurfMat = [];
sAtlasProj = sAtlas;

% ===== GET INTERPOLATION =====
% Make sure files are different
if file_compare(srcSurfFile, destSurfFile)
    disp('BST> Error: Source and destination surfaces are the same.');
    return;
end
% Compute interpolation  
[Wmat, sSrcSubj, sDestSubj, srcSurfMat, destSurfMat] = tess_interp_tess2tess(srcSurfFile, destSurfFile, 1, [], isSingleHemi);
% Source subject and destination subject are the same
isSameSubject = file_compare(sSrcSubj.FileName, sDestSubj.FileName);
% If no scouts in input, project everything
if isempty(sAtlas)
    sAtlas = srcSurfMat.Atlas;
end
% Check if there are things to project
if isempty(sAtlas)
    disp('BST> Error: No scouts to project.');
    return;
end
% Ratio of vertex number
ratio = size(destSurfMat.Vertices,1) ./ size(srcSurfMat.Vertices,1);

% ===== PROCESS ATLAS/SCOUTS =====
for iAtlas = 1:length(sAtlas)
    % Initialize probability maps
    scoutIndex = zeros(size(destSurfMat.Vertices,1),1);
    scoutProba = zeros(size(destSurfMat.Vertices,1),1);
    % Project scouts one by one and keep for each vertex only the maximum probability
    for iScout = 1:length(sAtlas(iAtlas).Scouts)
        % Vertex map on the original surface
        vMap = zeros(size(srcSurfMat.Vertices,1),1);
        vMap(sAtlas(iAtlas).Scouts(iScout).Vertices) = 1;
        % Project to destination surface
        vMapProj = full(Wmat * vMap);
        % Keep only the projections that have a higher probability than the previous scouts
        isHigherProba = vMapProj > scoutProba;
        scoutProba(isHigherProba) = vMapProj(isHigherProba);
        scoutIndex(isHigherProba) = iScout;
    end
        
% DISABLED 2018
%         % If the number of vertices does not decrease: force the selection of the closest vertex to each input vertex
%         if (ratio > 0.9)
%             for iVert = 1:length(sScout.Vertices)
%                 % Get the closest projected vertex for iVert
%                 [tmp, iVertClosest] = max(Wmat(:, sScout.Vertices(iVert)));
%                 % Force the selection by setting the interpolated value higher than 1
%                 vMapProj(iVertClosest) = 2;
%             end
%         end
    
    % Create all the scouts in the destination surface
    for iScout = 1:length(sAtlas(iAtlas).Scouts)
        % Current scout
        sScout = sAtlas(iAtlas).Scouts(iScout);
        
        % Get vertices identified in this scout
        iVertices = find(scoutIndex == iScout);
        if isempty(iVertices)
            sAtlasProj(iAtlas).Scouts(iScout).Vertices = [];
            sAtlasProj(iAtlas).Scouts(iScout).Seed     = [];
            continue;
        end
        % Limit the growth to extra vertices when not projecting an entire atlas
        if (length(sAtlas(iAtlas).Scouts) < 10)
            % Sort the projected values and keep the highest ones, up to desired number of vertices
            [tmp,I] = sort(scoutProba(iVertices), 1, 'descend');
            % Keep the highest values
            nVertices = round(ratio * length(sScout.Vertices));
            iVertices = iVertices(I(1:min(nVertices,length(I))));
        end
        
        % Identify seed (closest point to the center of mass of the scout)
        c = mean(destSurfMat.Vertices(iVertices,:),1);
        distC = sqrt((destSurfMat.Vertices(iVertices,1)-c(1)).^2 + (destSurfMat.Vertices(iVertices,2)-c(2)).^2 + (destSurfMat.Vertices(iVertices,3)-c(3)).^2);
        [distMin,iMin] = min(distC);
        iSeed = iVertices(iMin);
        
        % Get destination atlas
        iAtlasDest = find(strcmpi({destSurfMat.Atlas.Name}, sAtlas(iAtlas).Name));
        if isempty(iAtlasDest)
            iAtlasDest = length(destSurfMat.Atlas) + 1;
            destSurfMat.Atlas(iAtlasDest).Name = sAtlas(iAtlas).Name;
        end
        % Destination scout name
        if ~isSave
            ScoutLabel = sScout.Label;
        elseif isSameSubject
            ScoutLabel = sScout.Label;
        else
            ScoutLabel = [sSrcSubj.Name '_' sScout.Label];
            ScoutLabel = strrep(ScoutLabel, '@default_subject', 'Default');
        end
        if ~isempty(destSurfMat.Atlas(iAtlasDest).Scouts)
            ScoutLabel = file_unique(ScoutLabel, {destSurfMat.Atlas(iAtlasDest).Scouts.Label});
        end
        % Create new scout
        iScoutDest = length(destSurfMat.Atlas(iAtlasDest).Scouts) + 1;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Vertices = iVertices(:)';
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Seed     = iSeed;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Color    = sScout.Color;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Label    = ScoutLabel;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Function = sScout.Function;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Region   = sScout.Region;
        % Report projected scouts
        nScoutProj = nScoutProj + 1;
        sAtlasProj(iAtlas).Scouts(iScout).Vertices = iVertices(:)';
        sAtlasProj(iAtlas).Scouts(iScout).Seed     = iSeed;
    end
end

% Save destination surface (append the atlas to existing file)
if isSave && (nScoutProj > 0)
    s.Atlas = destSurfMat.Atlas;
    bst_save(file_fullpath(destSurfFile), s, 'v7', 1);
end






