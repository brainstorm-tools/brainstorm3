function varargout = process_channel_cluter_auto( varargin )
% process_channel_cluter_auto: Automatically create channel cluster based
% on the distance to anatomical atlas. 

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
% Authors: Edouard Delaire, 2026

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Clusters channels (auto)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 91;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ChannelClusters';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;

    % === SCOUTS SELECTION
    sProcess.options.scouts.Comment    = 'Use scouts';
    sProcess.options.scouts.Type       = 'scout';
    sProcess.options.scouts.Value      = {};

    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    
    % Load channel informations
    ChannelMat = in_bst_channel(sInputs.ChannelFile);
    iChannels = channel_find(ChannelMat.Channel, sProcess.options.sensortypes.Value);
    if isempty(iChannels)
        bst_error(sprintf('Unable to find channel type %s',   sProcess.options.sensortypes.Value))
        return;
    end
    sChannel        = ChannelMat.Channel(iChannels);
    channels_groups = unique({sChannel.Group});
    nChannel        = length(sChannel);
    nGroup          = max(length(channels_groups), 1);
    
    % Load Cortex and Scout informations
    sSubject = bst_get('Subject', sInputs.SubjectName);
    sCortex  = in_tess_bst(sSubject.Surface(sSubject.iCortex).FileName);
    

    iAtlas = find(strcmp({sCortex.Atlas.Name}, sProcess.options.scouts.Value{1}));
    if isempty(iAtlas)
        bst_error(sprintf('Unable to find atlas %s',  sProcess.options.scouts.Value{1}))
        return;
    end
    iScouts = cellfun(@(x) find(strcmp({sCortex.Atlas(iAtlas).Scouts.Label}, x)), sProcess.options.scouts.Value{2});
    sScout = sCortex.Atlas(iAtlas).Scouts(iScouts);
    nScouts = length(sScout);


    % Create clusters
    sClusters = repmat(db_template('cluster'), 1, nGroup * nScouts);
    k = 1;
    for iScout = 1:nScouts
        for iGroup = 1:nGroup
            if ~isempty(channels_groups(iGroup))
                sClusters(k).Label = sprintf('%s - %s', sScout(iScout).Label, channels_groups{iGroup});
            else
                sClusters(k).Label = sprintf('%s', sScout(iScout).Label);
            end

            sClusters(k).Color = sScout(iScout).Color;
            sClusters(k).Function = sScout(iScout).Function;
            sClusters(k).Sensors = {};
            k = k +1;

        end
    end
    
    idx_roi  = ClusterChannelUsingDistance(sCortex, sChannel, sScout);
    for iChannel = 1:nChannel
        group_name = sChannel(iChannel).Group;
        roi_name   = sScout(idx_roi(iChannel)).Label;
            
        if isempty(group_name)
            cluster_name = sprintf('%s', roi_name);
        else
            cluster_name = sprintf('%s - %s', roi_name, group_name);
        end

        sClusters(strcmp({sClusters.Label}, cluster_name ) ).Sensors{end+1} = sChannel(iChannel).Name;
    end
    
    % Add or replace clusters
    for i = 1:length(sClusters)
        
        if isempty(sClusters(i).Sensors)
            % do not create empty cluster
            continue
        end

        % If cluster already exists, update it, otherwise create a new entry
        if ~isfield(ChannelMat, 'Clusters') || isempty(ChannelMat.Clusters)
            ChannelMat.Clusters = repmat(db_template('cluster'), 0, 1);
            iCluster = 1;
        else
            iCluster = find(strcmp(sClusters(i).Label, {ChannelMat.Clusters.Label}));
            if isempty(iCluster)
                iCluster = length(ChannelMat.Clusters) + 1;
            end
        end
        % Copy all the fields
        ChannelMat.Clusters(iCluster).Sensors  = sClusters(i).Sensors;
        ChannelMat.Clusters(iCluster).Label    = sClusters(i).Label;
        ChannelMat.Clusters(iCluster).Function = sClusters(i).Function;
        % Add color if not defined yet
        if ~isempty(sClusters(i).Color)
            ChannelMat.Clusters(iCluster).Color = sClusters(i).Color;
        else
            ColorTable = panel_scout('GetScoutsColorTable');
            iColor = mod(iCluster-1, length(ColorTable)) + 1;
            ChannelMat.Clusters(i).Color = ColorTable(iColor,:);
        end
    end

    % Save modified file
    bst_save(file_fullpath(sInputs.ChannelFile), ChannelMat, 'v7');

    OutputFiles = {sInputs.FileName};
end



function [idx_roi, dist] = ClusterChannelUsingDistance(sCortex, sChannels, sScouts)
    % For each channel, return the index of the closest ROI: sScout(idx_roi)
    % and the distance of the channel to that scout. 
    
    % Initialize output
    dist = zeros(length(sChannels), length(sScouts));

    % Compute distances
    for iChannel = 1:length(sChannels)

        if size(sChannels(iChannel).Loc, 2) == 2
            channel_loc =  mean(sChannels(iChannel).Loc, 2);
        else
            channel_loc =  sChannels(iChannel).Loc;
        end

        for iScout = 1:length(sScouts)

            y =  sCortex.Vertices(sScouts(iScout).Vertices, :);
            x =  repmat(channel_loc', size(y, 1), 1);

            distance_channel_ROI = sqrt(sum( (x  - y).^2, 2));
            dist(iChannel, iScout) = min(distance_channel_ROI);
        end
    end

    [dist, idx_roi] = min(dist, [], 2);
end

