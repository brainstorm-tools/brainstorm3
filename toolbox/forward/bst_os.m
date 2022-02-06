function Sphere = bst_os(Channel, Vertices, Faces)
% BST_OS: Create overlapping spheres for EEG/MEG channels.
%
% USAGE:  Sphere = bst_os(Channel, Vertices, Faces)
% 
% INPUT: 
%     - Channel[]:  an array of structures.
%         |- Loc     : a matrix of locations of the sensor coil centers, one column per coil
%         |- Orient  : corresponding matrix of orientations, null in the case of EEG
%         |- Weight  : relative weights to each coil. Used here in the least-squares (default is 1).
%         |- Type    : 'MEG','MEG MAG','MEG GRAD','EEG'
%         |- Comment : unused here.
%     - Vertices   : Mx3 double matrix
%     - Faces      : Nx3 double matrix
%
% OUTPUT:
%    - Sphere[]: array of structures (one per channel)
%         |- Center : a 3 x 1 center location and 
%         |- Radius : the corresponding radius.
%         |- Weight : a weighting vector for coloring the vertices to indicate
%         |           the relative surface weights.
%         |- Approx : the identified surface weights on the sphere.
%
% NOTES: - Sphere.Center and Sphere.Radius should be transferred to fields in the 
%          structure HeadModel.Param

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
% Authors: John C. Mosher, Sylvain Baillet, 2001-2004
%          Francois Tadel, 2008-2010

% Check matrices orientation
if (size(Vertices, 2) ~= 3) || (size(Faces, 2) ~= 3)
    error('Faces and Vertices must have 3 columns (X,Y,Z).');
end
Nc = length(Channel);
% Start progress bar
isBarVisible = bst_progress('isVisible');
if ~isBarVisible
    bst_progress('start', 'Head modeler', 'Overlapping spheres...', 0, Nc);
end
    
% Compute vertex normals
VertConn = tess_vertconn(Vertices, Faces);
VertNormals = tess_normals(Vertices, Faces, VertConn);

% Allocate return matrix
[Sphere(1:Nc)] = deal(struct('Center',[],'Radius',[],'Weight',[],'Approx',[]));

% Loop for each channel
for i = 1:Nc
    bst_progress('inc', 1);
    bst_progress('text', sprintf('Overlapping spheres: %d/%d', i, Nc));
    % Calculate the surface weight for the true shape
    if isempty(Channel(i).Weight) || all(Channel(i).Weight == 0)
        % channel weights (i.e. gain) are undefined or all weights are badly set to zero 
        Channel(i).Weight = 1;    
    end
    Sphere(i).Weight = double(weighting_scalar(Channel(i).Loc,Channel(i).Orient, Channel(i).Weight, Vertices, VertNormals));
    
    % Initialize the guess of a sphere center as the average of the vertices
    tempCenter = mean(Vertices,1)';
    % Distance from sensor to center
    tempD = double(sqrt(sum((Channel(i).Loc(:,1) - tempCenter) .^ 2)));
    % Initialize radius (3 cm, handle pathological cases)
    tempR = min(.9*tempD, abs(tempD - 0.03));
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% ??? %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Grid something comparable
    testL = source_grid(tempD, tempR, 1/1000, .3)'; % sparse sampling
    testL = [testL [testL(1:2,:);-testL(3,:)]]; % upper and lower hemispheres
    testL = testL + tempCenter(:,ones(1,size(testL,2)));
    
    % Scan over this grid for weighting scalars, find the best match
    BestGridPt = 1; % assume first
    best_err = bst_os_fmins([testL(:,1);tempR], Sphere(i).Weight, Vertices);
    for iGrid = 2:size(testL,2), % for each additional grid point
        test_err = bst_os_fmins([testL(:,iGrid);tempR], Sphere(i).Weight, Vertices);
        if(test_err < best_err),
            BestGridPt = iGrid;
        end
    end
    % Set start of search here.
    tempCenter = testL(:, BestGridPt);
    tempR = mean(sqrt(sum(bst_bsxfun(@minus, Vertices, tempCenter') .^ 2, 2)));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    [X,fval,exitflag] = fminsearch(@bst_os_fmins, [tempCenter;tempR], [], Sphere(i).Weight, Vertices);
    
    % Define error message
    errMsg = ['Unexpected error. Possible workarounds:' 10 ...
             '1) Check scalp/sensors alignement.' 10 ...
             '2) Make sure that the scalp and the cortex surfaces are clean (use transparency).' 10 ...
             '3) Try again using spherical models.'];
    % Check return status: (Added by FT: 26-Jan-2009)
    if (exitflag < 1)
        error(errMsg);
    end
    Sphere(i).Center = X(1:3);
    [err, Sphere(i).Approx, Sphere(i).Radius] = bst_os_fmins(X, Sphere(i).Weight, Vertices);
    % Test added by KND (2010)
    if (sqrt(sum((tempCenter-Sphere(i).Center).^2)) > 2*tempR) || (Sphere(i).Radius > 2*tempR)
        error(errMsg);
    end
end

% Close progress bar
if ~isBarVisible
    bst_progress('stop');
end
end


%% ===== FMINS FUNCTION =====
% Calculate the error between true and estimated weighting scalars
% Fits a sphere to the vertices, but uses the Scalar function to weight the least-squares fit.
function [err,SphereSc,Radius] = bst_os_fmins(X, TrueSc, Vertices)
    %Center = X(1:3)';
    %Radius = X(4);
    % Scale the true scalar to be a weighting function
    Weights = abs(TrueSc) / sum(abs(TrueSc)); % don't care about sign.
    % Distance between the vertices and the center
    %b = sqrt(sum(bst_bsxfun(@minus, Vertices, X(1:3)').^2, 2));
    b = sqrt((Vertices(:,1)-X(1)).^2 + (Vertices(:,2)-X(2)).^2 + (Vertices(:,3)-X(3)).^2);
    % Average distance weighted by scalar
    r = sum(b .* Weights);
    % Squared error between distances and sphere, weighted by scalars
    err = ((b-r) .* Weights) .^ 2;
    % Map for informative purposes
    SphereSc = err;
    err = sum(err); % sum squared error
    Radius = r; % overrides what the user sent
end



