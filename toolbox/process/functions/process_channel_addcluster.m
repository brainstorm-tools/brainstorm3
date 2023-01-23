function varargout = process_channel_addcluster( varargin )
% PROCESS_CHANNEL_ADDCLUSTER: Import clusters in the selected channel files.

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

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Import clusters of channels';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 90;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ChannelClusters';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % File selection options
    SelectOptions = {...
        '', ...                               % Filename
        '', ...                               % FileFormat
        'open', ...                           % Dialog type: {open,save}
        'Import clusters...', ...             % Window title
        'ImportChannel', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                         % Selection mode: {single,multiple}
        'files', ...                          % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'clusterin'), ... % Available file formats
        'ClusterIn'};                         % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
    % Option: Event file
    sProcess.options.clusterfile.Comment = 'Cluster file:';
    sProcess.options.clusterfile.Type    = 'filename';
    sProcess.options.clusterfile.Value   = SelectOptions;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Get options
    ClusterFile = sProcess.options.clusterfile.Value{1};
    FileFormat  = sProcess.options.clusterfile.Value{2};
    % Load input cluster file
    sClusters = in_clusters(ClusterFile, FileFormat);
    % Get unique channel files
    AllChannelFiles = unique({sInputs.ChannelFile});
    % Process each channel file
    for iFile = 1:length(AllChannelFiles)
        Compute(AllChannelFiles{iFile}, sClusters);
    end
    % Return all the files in input
    OutputFiles = {sInputs.FileName};
end


%% ===== ADD CLUSTERS TO CHANNEL FILE =====
function Compute(ChannelFile, sClusters)
    % Load file
    ChannelFile = file_fullpath(ChannelFile);
    ChannelMat = in_bst_channel(ChannelFile);
    % Add or replace clusters
    for i = 1:length(sClusters)
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
    bst_save(ChannelFile, ChannelMat, 'v7');
end

