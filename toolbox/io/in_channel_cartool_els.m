function ChannelMat = in_channel_cartool_els(ChannelFile)
% IN_CHANNEL_ELS: Reads a .els file : cartesian coordinates of a set of electrodes, divided in various clusters
% 
% USAGE:  ChannelMat = in_channel_els(ChannelFile)
%
% INPUT: 
%    - ChannelFile : name of file to open, WITH .ELS EXTENSION
% OUTPUT:
%    - ChannelMat  : Brainstorm channel structure
%
% FORMAT: (.ELS)
%     ASCII file :
%     Format : "ES01<RETURN>"
%              "<nb_electrodes> <RETURN>"
%              "<nb_clusters> <RETURN>"
%              Repeat for each cluster :
%                  "<Cluster_name> <RETURN>"
%                  "<Cluster_number_of_electrodes> <RETURN>"
%                  "<Cluster_type> <RETURN>"
%              End of repeat
%              Repeat for each electrode :
%                  "<X1> <Y1> <Z1> ?<electrode_label>? ?<optional_flag>?<RETURN>"
%              End.
%     Notes :
%     - Cluster_type : could be seen as the dimensionality of the cluster :
%           - 0 for separated electrodes (like auxiliaries), or "points"
%           - 1 for a strip of electrodes, or "line"
%           - 2 for a grid of electrodes, or "array"
%           - 3 for a 3D set of electrodes, usually on the scalp
%     - optional_flag : ignored in this program

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
% Authors: Francois Tadel, 2006-2015


% Initialize output variable
ChannelMat = [];


%% ===== READ ELS FILE =====
% Open file
[fid, message] = fopen(ChannelFile, 'r');
if (fid == -1)
    disp(['BST> Error: Could not open file: ' message]);
    return;
end
% Read magic number
readData = fgetl(fid);
if ~strcmp(readData, 'ES01')
    error('Invalid ELS file.');
end
% Read number of electrodes
Ne = str2num(fgetl(fid));
% Read number of clusters
Nclust = str2num(fgetl(fid));
% Read all clusters
clusterNames  = cell(1,Nclust);
allLoc      = zeros(0,3);
allLabels   = {};
allClusters = {};
allTypes    = {};
for iClust = 1:Nclust
    clusterNames{iClust} = fgetl(fid);
    clusterNchan = str2num(fgetl(fid));
    clusterType  = str2num(fgetl(fid));
    % Skip electrode positions and move to next cluster
    for iChan = 1:clusterNchan
        chanLine = fgetl(fid);
        readData = textscan(chanLine, '%n %n %n %s', 1);
        allLoc(end+1,:) = [readData{1:3}];
        allClusters{end+1} = clusterNames{iClust};
        if isempty(readData{4}) || isempty(readData{4}{1})
            allLabels{end+1} = sprintf('%s%02d', clusterNames{iClust}, iChan);
        else
            allLabels{end+1} = readData{4}{1};
        end
        % Channel type
        switch clusterType
            case 0,    allTypes{end+1} = 'Misc';
            case 1,    allTypes{end+1} = 'SEEG';
            case 2,    allTypes{end+1} = 'ECOG';
            case 3,    allTypes{end+1} = 'EEG';
            otherwise, allTypes{end+1} = 'EEG';
        end
    end
end
% Close file
fclose(fid);

% Verify the expected number of electrodes
% If too many electrodes were read, only keep the first 'Ne' electrodes
readNe = size(allLoc,1);
if (readNe < Ne)
    disp('BST> Warning: Incorrect number of electrodes in file.');
elseif (readNe > Ne)
    allLoc(Ne+1:readNe, :) = [];
    allLabels(Ne+1:readNe, :) = [];
    allClusters(Ne+1:readNe, :) = [];
    allTypes(Ne+1:readNe, :) = [];
end


%% ===== SELECT CLUSTERS =====
% If there are multiple clusters
if (Nclust > 1)
    % Ask user to select clusters
    isSelected = java_dialog('checkbox', 'Select the clusters to import:', 'Import ELS file', [], clusterNames, ones(size(clusterNames)));
    if isempty(isSelected) || ~any(isSelected)
        return;
    end
    % Select only the required sensors
    iChannels = find(ismember(allClusters, clusterNames(isSelected==1)));
else
    iChannels = 1:readNe;
end



%% ===== CONVERT IN BRAINSTORM FORMAT =====
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Cartool ELS';
ChannelMat.Channel = repmat(db_template('channeldesc'), 1, length(iChannels));
for i = 1:length(iChannels)
    ChannelMat.Channel(i).Name    = allLabels{iChannels(i)};
    ChannelMat.Channel(i).Comment = '';
    ChannelMat.Channel(i).Type    = allTypes{iChannels(i)};
    ChannelMat.Channel(i).Group   = allClusters{iChannels(i)};
    ChannelMat.Channel(i).Loc     = allLoc(iChannels(i),:)';
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Weight  = 1;
end




