function [Labels,err] = tess_cluster_functional(sSurf, ImagingKernel, Leadfield, Atlas)
% TESS_CLUSTER_FUNCTIONAL: 
%
% USAGE:  Labels = tess_cluster_functional(Surface, Results.ImagingKernel, HeadModel.Gain(Results.GoodChannel,:))
%
% INPUTS: 
%    - sSurf           : tesselation structure (Faces,Vertices,VertConn)
%    - ImagingKernel   : N-source x N-channel sensor to source projection matrix
%    - Leadfield       : N-source gain matrix from the head model
%
% OUTPUTS:
%    - Labels : N-source vector with each number corresponding to an
%    agregation of source (0 means not assigned).
%
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
% Authors: Sebastien Dery, 2013
%
% Init varout
Labels = [];
err = [];

% Making sure we have all we need
if isempty(sSurf)
    err = 'Surface structure is empty';
    return;
end
if isempty(ImagingKernel)
    err = 'ImagingKernel matrix is empty';
    return;
end
if isempty(Leadfield)
    err = 'Leadfield vector is empty';
    return;
end

Labels = zeros(size(sSurf.Vertices,1),1);
% Could be assigned as an eventual option. Not recommended at the moment.
absolute = 0;
% In case we come up with different method
Method = 'maxcorr';
% Incremental index
Region = 1;

% Split hemispheres
if isempty(Atlas)
    [H{1}, H{2}] = tess_hemisplit(sSurf);
% Get vertices in cells
else
    H = {Atlas.Scouts(:).Vertices};
end

% For each hemispheres or scouts
for y=1:length(H)
    % Get Imaging Kernel
    gIK = ImagingKernel(H{y}, :);
    % Normalise IK
    gIK_Norm = sqrt(sum(abs(gIK).^2,2));
    gIK = gIK ./ repmat(gIK_Norm, 1, size(gIK,2));
    % Get Resolution Map
    gIK = gIK * Leadfield(:, H{y});
    % Compute Resolution Correlation
    gCorrIK = gIK * gIK';
    if (absolute)
        gCorrIK = abs(gCorrIK);
    end
    % Easier on the memory...
    clear gIK;
    clear gIK_Norm;
    % Get surface connection
    Conn = sSurf.VertConn(H{y}, H{y});
    Conn(eye(size(Conn)) == 1) = 0;
    N = size(gCorrIK,1);
    switch lower(Method)
        case 'maxcorr'
            iteVert = 1:N;
            while ~isempty(iteVert)
                i = iteVert(1);
                iV = H{y}(i);
                % If the node has a connection, than he has a maximum
                ConnId = find(Conn(i,:) == 1);
                if (isempty(ConnId))
                    % Pop node
                    iteVert(1) = [];
                else
                    % Get maximum
                    [tmp,idx] = max(gCorrIK(i,Conn(i,:) == 1));
                    % Get proper index
                    idx = ConnId(idx);
                    % If no vertex has been assigned yet
                    if (Labels(iV) == 0 && sum(Labels(H{y}(idx))) == 0)
                        % Assign current vertex a new region
                        Labels(iV) = Region;
                        % Reassign neighbhours to front of iteration
                        iteVert(1) = [];
                        iteVert(ismember(iteVert,idx)) = [];
                        iteVert = [ConnId(Labels(H{y}(ConnId)) == 0) iteVert];
                        % Assign neighbhours
                        Labels(H{y}(idx)) = Region;
                        Region = Region + 1;
                    else
                        % 
                        iteVert(1) = [];
                        iteVert(ismember(iteVert,idx)) = [];
                        iteVert = [ConnId(Labels(H{y}(ConnId)) == 0) iteVert];
                        % 
                        if (Labels(iV) == 0)
                            cLabel = Labels(H{y}(idx));
                            cLabel(cLabel == 0) = [];
                            Labels(iV) = cLabel(1);
                        end
                        Labels(H{y}(idx)) = Labels(iV);
                    end
                end
            end
            % Leave each lonely source in its own region
            UnassignedVertex = H{y}(Labels(H{y}) == 0);
            Labels(UnassignedVertex) = Region:(Region+length(UnassignedVertex)-1);
            Region = Region + length(UnassignedVertex);

        case 'otherwise'
            disp('Unsupported method. Sorry for the inconvenience');
    end        
    clear gCorrIK;
end