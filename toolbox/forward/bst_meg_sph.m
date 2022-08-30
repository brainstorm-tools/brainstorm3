function G = bst_meg_sph(L, Channel, Param)
% BST_MEG_SPH: Calculate the (overlapping) sphere models for MEG
% 
% USAGE:  G = bst_meg_sph(L, Channel, Param);
%
% INPUT:
%    - L        : a 3 x nL array, each column a source location (x y z coordinates); nL sources
%    - Channel  : a Brainstorm channel structure
%    - Param[]  : array of structures (one per channel)
%        |- Center  : a vector of the x, y, z locations for the sphere model 
%        |            (assume the same center for every sphere for the classical spherical head model)
%
% OUTPUT:
%    - G  : the gain matrix: each column is the forward field of each source

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

%% ===== PARSE INPUTS =====
% Sources locations should be 3 x m
if(size(L,1)~=3)
    error('Matrix not given as 3 x n. Correct calling code');
end
% Check that the number of coils is the same for all the channels
chanCoils = cellfun(@(c)size(c,2), {Channel.Loc});
grpCoils = unique(chanCoils);
% If there are multiple sensor sensor types (different numbres of coils)
if (length(grpCoils) > 1)
    % This function can only accept calls to groups of sensors with the same number of coils
    % => Group the sensors by number of coils and call os_meg as many times as needed
    G = NaN * zeros(length(Channel), 3 * size(L,2));
    for iGrp = 1:length(grpCoils)
        % Get all the sensors with this amount of coils
        iMegGrp = find(chanCoils == grpCoils(iGrp));
        % Compute (os_meg)
        G(iMegGrp,:) = bst_meg_sph(L, Channel(iMegGrp), Param(iMegGrp));
    end
    return;
end
% Number of coils for this call
NumCoils = chanCoils(1);


%% ===== COMPUTATION ===== 
% Get locations
AllLocs = [Channel.Loc]; 
AllLocs = reshape(AllLocs, NumCoils*3, size(AllLocs,2)/NumCoils);
% Get orientations
AllOrient = [Channel.Orient];
AllOrient = AllOrient * bst_inorcol(AllOrient);
AllOrient = reshape(AllOrient, NumCoils*3, size(AllOrient,2)/NumCoils);
% Get weights
AllWeight = [Channel.Weight];
AllWeight = reshape(AllWeight(:), NumCoils, length(AllWeight(:))/NumCoils);

% Process each group of coils
G = 0;
for j = 1:NumCoils
    % P.sensor is 3 x nR,each column a sensor location
    % P.orient is 3 x nR, the sensor orientation
    % P.center is 3 x nR, the sphere center for each sensor
    P.sensor = AllLocs((-2:0) + j*3, :);
    P.orient = AllOrient((-2:0) + j*3, :);
    P.weight = AllWeight(j,:);
    P.center = [Param.Center];
    % Local call below
    G = G + sarvas(L, P); 
end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%  Local Sarvas functions %%%%%%%%%%%%%%%%%%%%%%%%
function G = sarvas(L, P)
% Bronzan Sarvas forward model, spherical head
% P.sensor is 3 x nR,each column a sensor location
% P.orient is 3 x nR, the sensor orientation
% P.center is 3 x nR, the sphere center for each sensor

if(~isfield(P,'center')), % user did not provide
   P.center = []; % initialize to null
end
if(isempty(P.center)), % user gave as null
   P.center = zeros(size(P.sensor));  % set to coordinate origin
end

P.sensor = P.sensor - P.center; % shift sensor coordinates

iMag = find(sum(P.sensor.^2,1) == 0); % Indices of channels located at P.center.
if ~isempty(iMag)
    P.sensor(:,iMag) = repmat([1 1 1]',1,length(iMag)); % Move them away (arbitrary location).
end

nR = size(P.sensor,2); % number of sensors
nL = size(L,2);  % number of source points

Rn2 = sum(P.sensor.^2,1); % distance to sensor squared
Rn = sqrt(Rn2); % distance

if (nR >= nL), % more sensors than dipoles
   G = zeros(nR,3*nL);  % gain matrix
   for Li = 1:nL,
      Lmat = L(:,Li+zeros(1,nR)); % matrix of location repeated
      Lmat = Lmat - P.center; % each center shifted relative to its center
      D = P.sensor - Lmat;  % distance from souce to sensors
      Dn2 = sum(D.^2,1); % distance squared
      Dn = sqrt(Dn2);  % distance
      R_dot_D = sum(P.sensor .* D);  % dot product of sensor and distance
      R_dot_Dhat = R_dot_D ./ Dn;  % dot product of sensor and distance
      
      F = Dn2 .* Rn + Dn .* R_dot_D;  % Sarvas' function F
      
      GF_dot_o = Dn2 .* sum(P.sensor.*P.orient) ./ Rn + ...
         (2 * Rn + R_dot_Dhat) .* sum(D.*P.orient) + ...
         Dn .* sum((D+P.sensor).*P.orient);
      
      tempF = GF_dot_o ./ F.^2;
      
      temp = bst_cross(Lmat,P.orient) ./ F([1 1 1],:) - ...
             bst_cross(Lmat,P.sensor) .* tempF([1 1 1],:);
      G(:,Li*3+[-2 -1 0]) = temp';

   end
   
else  % more dipoles than sensors nL > nR
   G = zeros(3*nL,nR);  % gain matrix transposed
   
   for Ri = 1:nR,
      Rmat = P.sensor(:,Ri+zeros(1,nL)); % matrix of sensor repeated
      Omat = P.orient(:,Ri+zeros(1,nL)); % orientations
      Lmat = L - P.center(:,Ri+zeros(1,nL)); % shift centers to this coordinate
      
      D = Rmat - Lmat;
      Dn2 = sum(D.^2,1); % distance squared
      Dn = sqrt(Dn2);  % distance
      R_dot_D = sum(Rmat .* D);  % dot product of sensor and distance
      R_dot_Dhat = R_dot_D ./ Dn;  % dot product of sensor and distance
      
      F = Dn2 * Rn(Ri) + Dn .* R_dot_D;  % Sarvas' function F
      
      GF_dot_o = Dn2 * sum(P.sensor(:,Ri).*P.orient(:,Ri)) / Rn(Ri) + ...
         (2 * Rn(Ri) + R_dot_D ./ Dn) .* sum(D.*Omat) + ...
         Dn .* sum((D+Rmat).*Omat);
      
      tempF = GF_dot_o ./ F.^2;
      
      temp = bst_cross(Lmat,Omat) ./ F([1 1 1],:) - ...
             bst_cross(Lmat,Rmat) .* tempF([1 1 1],:);
      
      G(:,Ri) = temp(:);
   end
   
   G = G';
end

if(isfield(P,'weight')),
   Weights = P.weight(:); %make sure column
   % scale each row by its appropriate weight
   G = Weights(:,ones(1,size(G,2))) .* G;
end

G = G * 1e-7; % mu_o over 4 pi





