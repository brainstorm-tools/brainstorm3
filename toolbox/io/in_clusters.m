function sClusters = in_clusters(ClusterFile, FileFormat)
% IN_CLUSTERS: Read clusters of channels from a file

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
% Authors: Francois Tadel, 2023

% Read file
switch (FileFormat)
    case 'BST'
        ClusterMat = load(ClusterFile);
        if ~isfield(ClusterMat, 'Clusters')
            error('Invalid Brainstorm clusters file: missing field "Clusters".');
        end
    case 'MNE'
        sMontage = in_montage_mne(FileName);
        for i = 1:length(sMontage)
            ClusterMat.Clusters(i).Label   = sMontage(i).Name;
            ClusterMat.Clusters(i).Sensors = sMontage(i).ChanNames;
        end
    otherwise
        error('Invalid file format.');
end
if isempty(ClusterMat.Clusters)
    error(['No clusters available in file: ' FileName]);
end

% Create standardized Brainstorm structure
sClusters = repmat(db_template('cluster'), 1, length(ClusterMat.Clusters));
% Loop on all the new clusters
for i = 1:length(ClusterMat.Clusters)
    sClusters(i).Sensors = ClusterMat.Clusters(i).Sensors;
    if isfield(ClusterMat.Clusters(i), 'Label') && ~isempty(ClusterMat.Clusters(i).Label)
        sClusters(i).Label = ClusterMat.Clusters(i).Label;
    end
    if isfield(ClusterMat.Clusters(i), 'Color') && ~isempty(ClusterMat.Clusters(i).Color)
        sClusters(i).Color = ClusterMat.Clusters(i).Color;
    end
    if isfield(ClusterMat.Clusters(i), 'Function') && ~isempty(ClusterMat.Clusters(i).Function)
        sClusters(i).Function = ClusterMat.Clusters(i).Function;
    end
end


