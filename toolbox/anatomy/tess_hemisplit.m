function [rH, lH, isConnected, iStruct, iRightScout, iLeftScout] = tess_hemisplit(sSurf)
% HEMISPLIT: Find the right and left hemisphere indexes
% 
% INPUT:
%     - sSurf: Brainstorm surface structure with fields: Vertices, VertConn, Atlas
%
% OUTPUT:
%     - rH          : right hemisphere indexes
%     - lH          : left hemisphere indexes
%     - isConnected : 1 if the two hemispheres are connected, else 0
%     - iStruct     : Index of the atlas "Structures"
%     - iLeftScout  : Index of the scout "lh" in the atlas "Structures"
%     - iRightScout : Index of the scout "rh" in the atlas "Structures"

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Author: Guillaume Dumas, Francois Tadel, 2009-2013

% Initialize returned values
rH          = [];
lH          = [];
isConnected = 0;
iLeftScout  = [];
iRightScout = [];


%% ===== USE STRUCTURES ATLAS =====
% If there is a Structures atlas with left and right hemispheres: split in two spheres
iStruct = find(strcmpi({sSurf.Atlas.Name}, 'Structures'));
if ~isempty(iStruct)
    % === Method 1: Find the left and right hemispheres ===
    % Find left and right hemispheres
    iRightScout = [find(strcmpi({sSurf.Atlas(iStruct).Scouts.Label}, 'rh')), find(strcmpi({sSurf.Atlas(iStruct).Scouts.Label}, 'Cortex') & strcmpi({sSurf.Atlas(iStruct).Scouts.Region}, 'RU'))];
    iLeftScout  = [find(strcmpi({sSurf.Atlas(iStruct).Scouts.Label}, 'lh')), find(strcmpi({sSurf.Atlas(iStruct).Scouts.Label}, 'Cortex') & strcmpi({sSurf.Atlas(iStruct).Scouts.Region}, 'LU'))];
    % If both hemispheres are described here: get the indices
    if ~isempty(iRightScout) && ~isempty(iLeftScout)
        rH = sSurf.Atlas(iStruct).Scouts(iRightScout).Vertices;
        lH = sSurf.Atlas(iStruct).Scouts(iLeftScout).Vertices;
        return;
    end
    % === Method 2: Sum all the L/R scouts ===
    % Find all the L/R scouts
    scoutHemi = cellfun(@(c)c(1), {sSurf.Atlas(iStruct).Scouts.Region}, 'UniformOutput', 0);
    iRightScouts = find(strcmpi(scoutHemi, 'R'));
    iLeftScouts  = find(strcmpi(scoutHemi, 'L'));
    % If both hemispheres are described here: get the indices
    if ~isempty(iRightScouts) && ~isempty(iLeftScouts)
        rH = unique([sSurf.Atlas(iStruct).Scouts(iRightScouts).Vertices]);
        lH = unique([sSurf.Atlas(iStruct).Scouts(iLeftScouts).Vertices]);
        return;
    end
end


%% ===== GROW FROM EACH SIDE =====
% Perform detection only in dimension 2
dim = 2;
% Consider that all the 30% extremes on the left-right axis belong only to one hemisphere 
START_PERCENT = 0.3;
% Right
if ~isConnected 
    % Get maximal y value
    [yMin, rH] = min(sSurf.Vertices(:,dim));
    % Get all the vertices that are at more than START_PERCENT of the maximum
    iNewR = find(sSurf.Vertices(:,dim) < START_PERCENT * yMin)';
    iNewR = setdiff(iNewR, rH);
    % If not displaying the whole brain
    if ~isempty(rH)
        % Grow region until getting all the hemisphere
        while ~isConnected && ~isempty(iNewR)
            rH = union(rH, iNewR);
            iNewR = tess_scout_swell(rH, sSurf.VertConn);
            % If it's including more than 80% of the surface: connected...
            if (length(rH) >= .8 * length(sSurf.Vertices))
                isConnected = 1;
            end
        end
    end
end
% Left
if ~isConnected 
    % Get minimal y value
    [yMax, lH] = max(sSurf.Vertices(:,dim));
    % Get all the vertices that are at < than START_PERCENT of the minimum
    iNewL = find(sSurf.Vertices(:,dim) > START_PERCENT * yMax)';
    iNewL = setdiff(iNewL, lH);
    % If not displaying the whole brain
    if ~isempty(lH)
        % Grow region until getting all the hemisphere
        while ~isConnected && ~isempty(iNewL)
            lH = union(lH, iNewL);
            iNewL = tess_scout_swell(lH, sSurf.VertConn);
            % If it's including more than 80% of the surface: connected...
            if (length(lH) >= .8 * length(sSurf.Vertices))
                isConnected = 1;
            end
        end
    end
end


%% ===== SPLIT AT Y=0 =====
if isConnected
    lH = find(sSurf.Vertices(:,dim) < 0);
    rH = find(sSurf.Vertices(:,dim) >= 0);
end




