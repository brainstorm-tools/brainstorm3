function nScoutProj = bst_project_scouts( srcSurfFile, destSurfFile, sAtlas )
% BST_PROJECT_SCOUTS: Project scouts on a different surface (need the FreeSurfer registered spheres).
%
% USAGE:  nScoutProj = bst_project_scouts( srcSurfFile, destSurfFile, sAtlas=[all] )

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
% Authors: Francois Tadel, 2015

% ===== PARSE INPUTS ======
if (nargin < 3) || isempty(sAtlas)
    sAtlas = [];
end
nScoutProj = 0;

% ===== GET INTERPOLATION =====
% Make sure files are different
if file_compare(srcSurfFile, destSurfFile)
    disp('BST> Error: Source and destination surfaces are the same.');
    return;
end
% Compute interpolation  
[Wmat, sSrcSubj, sDestSubj, srcSurfMat, destSurfMat] = tess_interp_tess2tess(srcSurfFile, destSurfFile, 1);
% Source subject and destination subject are the same
isSameSubject = file_compare(sSrcSubj.FileName, sDestSubj.FileName);
% If no scouts in input, copy all the scouts in the first atlas
if isempty(sAtlas) && ~isempty(srcSurfMat.Atlas) && ~isempty(srcSurfMat.Atlas(1).Scouts)
    sAtlas = srcSurfMat.Atlas(1);
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
    for iScout = 1:length(sAtlas(iAtlas).Scouts)
        % Current scout
        sScout = sAtlas(iAtlas).Scouts(iScout);
        % Vertex map on the original surface
        vMap = zeros(size(srcSurfMat.Vertices,1),1);
        vMap(sScout.Vertices) = 1;
        % Project to destination surface
        vMapProj = full(Wmat * vMap);
        % Consider the projected vertex maps as a probability of being part of the projected scout
        % Sort the projected values and keep the highest ones, up to desired number of vertices
        iVertPossible = find(vMapProj > 0);
        [tmp,I] = sort(vMapProj(iVertPossible), 1, 'descend');
        % Keep the highest values
        nVertices = round(ratio * length(sScout.Vertices));
        iVertices = iVertPossible(I(1:min(nVertices,length(I))));
        % Nothing found...
        if isempty(iVertices)
            continue;
        end
        
        % Identify seed (closest point to the center of mass of the scout)
        c = mean(destSurfMat.Vertices(iVertices,:),1);
        distC = sqrt((destSurfMat.Vertices(iVertices,1)-c(1)).^2 + (destSurfMat.Vertices(iVertices,2)-c(2)).^2 + (destSurfMat.Vertices(iVertices,3)-c(3)).^2);
        [distMin,iMin] = min(distC);
        iSeed = iVertices(iMin);
        
        % Get destination atlas
        iAtlasDest = find(strcmpi({destSurfMat.Atlas.Name}, sAtlas.Name));
        if isempty(iAtlasDest)
            iAtlasDest = length(destSurfMat.Atlas) + 1;
            destSurfMat.Atlas(iAtlasDest).Name = sAtlas.Name;
        end
        % Destination scout name
        if isSameSubject
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
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Vertices = iVertices;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Seed     = iSeed;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Color    = sScout.Color;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Label    = ScoutLabel;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Function = sScout.Function;
        destSurfMat.Atlas(iAtlasDest).Scouts(iScoutDest).Region   = sScout.Region;
        nScoutProj = nScoutProj + 1;
    end
end

% Save destination surface (append the atlas to existing file)
if (nScoutProj > 0)
    s.Atlas = destSurfMat.Atlas;
    bst_save(file_fullpath(destSurfFile), s, 'v7', 1);
end






