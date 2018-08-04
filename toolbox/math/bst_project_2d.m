function [X,Y] = bst_project_2d(x, y, z, Method)
% BST_PROJECT_2D: Project a set of 3D points (EEG or MEG sensors) on a 2D surface.
%
% USAGE:  [X,Y] = bst_project_2d(x, y, z, Method='2dcap');

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: François Tadel, 2009-2016

% Parse inputs
if (nargin < 4) || isempty(Method)
    Method = '2dcap';
end

% Different projection methods
switch (Method)
    case '2dcap'
        % Spherical coordinates
        [TH,PHI,R] = cart2sph(x, y, z);
        % Flat projection
        R = 1 - PHI ./ pi*2;
        % Convert back to cartesian coordinates
        [X,Y] = pol2cart(TH,R);

    case '2dlayout'
        % Spherical coordinates
        z = z - max(z);
        [TH,PHI,R] = cart2sph(x, y, z);
        % Remove the too smal values for PHI
        PHI(PHI < 0.001) = 0.001;
        % Flat projection
        R2 = R ./ cos(PHI) .^ .2;
        [X,Y] = pol2cart(TH,R2);

    case 'circle'
        %     figure; 
        %     plot3(x, y, 1 + 0.2 .* (z ./ param.minZ).^2, 'Marker', '+', 'LineStyle', 'none', 'Color', [0 1 0]); axis equal; rotate3d

            % Spherical coordinates
            [TH,PHI,R] = cart2sph(x, y, z);
            % Flat projection
            R = 1 - PHI ./ pi*2;
            % Convert back to cartesian coordinates
            [X,Y] = pol2cart(TH,R);

            % Convert back to cartesian coordinates
            [TH,R] = cart2pol(X,Y);
            % Convex hull
            facesBorder = convhull(X,Y);
            iBorder = unique(facesBorder);

        %     % EXPAND BORDED, OPTION #1
        %     % Compute the length of each edge
        %     d = sqrt((X(facesBorder(1:end-1)) - X(facesBorder(2:end))).^2 + ...
        %              (Y(facesBorder(1:end-1)) - Y(facesBorder(2:end))).^2);
        %     % Find edges that are too long
        %     iSplit = find(d > .2);
        %     % For each of these long edges: adds the vertex connecting them (if any)
        %     for i = 1:length(iSplit)
        %         iAdd = find(sum((tri == facesBorder(iSplit(i))) | (tri == facesBorder(iSplit(i)+1)), 2) >= 2);
        %         if ~isempty(iAdd)
        %             iBorder = union(iBorder, setdiff(tri(iAdd,:), [facesBorder(iSplit(i)), facesBorder(iSplit(i)+1)]));
        %         end
        %     end

        %     % EXPAND BORDED, OPTION #2
        %     % Compute border again without this first layer of convex hull
        %     iInside = setdiff(1:length(X), iBorder);
        %     facesBorder = convhull(X(iInside),Y(iInside));
        %     iBorder2 = iInside(unique(facesBorder));

            % Deformation field in radius computed from the border sensors, projected onto the circle
            Rcircle = 1;
            Dborder = Rcircle ./ R(iBorder);
            % Compute the radius deformation to apply to all the sensors
            funcTh = [TH(iBorder)-2*pi; TH(iBorder); TH(iBorder)+2*pi];
            funcD  = [Dborder; Dborder; Dborder];
            D = interp1(funcTh, funcD, TH, 'linear', 0);

            % Remove the possible zero values
            D(D == 0) = 1;
            % Compute new radius: the closer to the center, the less transformed
            R = min(R .* D, Rcircle);
            % Convert back to cartesian coordinates
            [X,Y] = pol2cart(TH, R);

        %     % Plot final positions
        %     hold on;
        %     plot(Y, X, 'Marker', 'o', 'LineStyle', 'none', 'Color', [1 0 0]);
end



