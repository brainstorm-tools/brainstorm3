function [Vertices, Faces, Atlas] = tess_remove_vert(Vertices, Faces, iRemoveVert, Atlas)
% TESS_REMOVE_VERT: Remove some vertices from a tesselation
%
% Usage:  [Vertices, Faces, Atlas] = tess_remove_vert(Vertices, Faces, iRemoveVert, Atlas=[])
%
% INPUTS:
%     - Vertices    : [N,3] matrix
%     - Faces       : [M,3] matrix
%     - iRemoveVert : indices of vertices to remove
%     - Atlas       : Atlas structure

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
% Authors: Francois Tadel, 2008-2013

% Parse inputs
if (nargin < 4) || isempty(Atlas)
    Atlas = [];
end

% Re-numbering matrix
iKeptVert = setdiff(1:size(Vertices,1), iRemoveVert);
iVertMap = zeros(1, size(Vertices,1));
iVertMap(iKeptVert) = 1:length(iKeptVert);
% Remove vertices
Vertices(iRemoveVert,:) = [];

% Find the faces that contain removed vertices
iRemoveFace = find(sum(ismember(Faces, iRemoveVert), 2));
% Remove faces from list
Faces(iRemoveFace, :) = [];
% Renumber indices
Faces = iVertMap(Faces);

% === UPDATE ATLAS ===
% Loop on the atlases
for iAtlas = 1:length(Atlas)
    % Initialize list of scouts to remove for this atlas
    iScoutRm = [];
    % Loop on the scouts
    for iScout = 1:length(Atlas(iAtlas).Scouts)
        % Remove vertices
        Atlas(iAtlas).Scouts(iScout).Vertices = setdiff(Atlas(iAtlas).Scouts(iScout).Vertices, iRemoveVert);
        Atlas(iAtlas).Scouts(iScout).Seed     = setdiff(Atlas(iAtlas).Scouts(iScout).Seed, iRemoveVert);
        % Renumber remaining vertices
        Atlas(iAtlas).Scouts(iScout).Vertices = iVertMap(Atlas(iAtlas).Scouts(iScout).Vertices);
        % Make sure this is a row vector
        Atlas(iAtlas).Scouts(iScout).Vertices = Atlas(iAtlas).Scouts(iScout).Vertices(:)';
        % Remove scout if there are no vertices left
        if isempty(Atlas(iAtlas).Scouts(iScout).Vertices)
            iScoutRm = [iScoutRm, iScout];
        % Set a new seed if necessary
        elseif isempty(Atlas(iAtlas).Scouts(iScout).Seed)
            Atlas(iAtlas).Scouts(iScout) = panel_scout('SetScoutsSeed', Atlas(iAtlas).Scouts(iScout), Vertices);
        % Renumber the seed
        else
            Atlas(iAtlas).Scouts(iScout).Seed = iVertMap(Atlas(iAtlas).Scouts(iScout).Seed);
        end
    end
    % Remove the empty scouts
    if ~isempty(iScoutRm)
        Atlas(iAtlas).Scouts(iScoutRm) = [];
    end
end




