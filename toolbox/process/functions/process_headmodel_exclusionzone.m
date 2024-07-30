function varargout = process_headmodel_exclusionzone( varargin )
% PROCESS_HEADMODEL_EXCLUSIONZONE: Remove leadfields and sources within the exclusion zone.
%
% USAGE:   OutputFiles       = process_headmodel_exclusionzone('Run', sProcess, sInputs)
%         [newHMMat, errMsg] = process_headmodel_exclusionzone('Compute',            HMMat,  ChannelMat, Modality, ExclusionRadius)
%                              process_headmodel_exclusionzone('ComputeInteractive', HMFile, Modality, iStudy)

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
% Authors: Takfarinas Medani, Yash Shashank Vakilna, Raymundo Cassani 2024

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Head model exclusion zone';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 321;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutVolSource#Exclusion_zone';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % === Usage label
    sProcess.options.usage.Comment = GetUsageText();
    sProcess.options.usage.Type    = 'label';
    sProcess.options.usage.Value   = '';
    % === Modality
    sProcess.options.modality.Comment    = 'Modality of sensors: ';
    sProcess.options.modality.Type       = 'text';
    sProcess.options.modality.Value      = 'SEEG';
    sProcess.options.modality.InputTypes = {'data', 'raw'};     
    % === Exclusion radius
    sProcess.options.exclusionradius.Comment = 'Exclusion distance: ';
    sProcess.options.exclusionradius.Type    = 'value';
    sProcess.options.exclusionradius.Value   = {3,'mm',2};    
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % ===== GET OPTIONS =====       
    % Modality
    Modality = [];
    if isfield(sProcess.options, 'modality') && ~isempty(sProcess.options.modality) && ~isempty(sProcess.options.modality.Value)
        Modality = sProcess.options.modality.Value;
    end
    % Exclusion radius
    ExclusionRadius = sProcess.options.exclusionradius.Value{1} ./ 1000;
    if ExclusionRadius <= 0
        bst_report('Error', sProcess, [], 'You must define an exclusion distance greater than zero.');
        return;
    end
    OutputFiles = sInputs;
    % Get unique channel files
    [sChannels, iChanStudies] = bst_get('ChannelForStudy', unique([sInputs.iStudy]));
    % Check if there are channel files everywhere
    if (length(sChannels) ~= length(iChanStudies))
        bst_report('Error', sProcess, sInputs, ['Some of the input files are not associated with a channel file.' 10 'Please import the channel files first.']);
        return;
    end
    % Keep only once each channel file
    iChanStudies = unique(iChanStudies);
    newDefaultHM = {}; % Pairs [iStudy, newHeadmodelFileName]

    % ===== COMPUTE EXCLUSION ZONE =====    
    % Start the progress bar
    bst_progress('start', 'Leadfield exclusion zone', 'Computing leadfield exclusion zone...', 0, 100);
    barStep = 100 ./ length(iChanStudies);   
    for ix = 1 : length(iChanStudies)        
        bst_progress('set', barStep * ix);
        iStudy = iChanStudies(ix);
        % Get default headmodel for study
        sHeadmodel = bst_get('HeadModelForStudy', iStudy);
        HeadmodelMat = in_bst_headmodel(sHeadmodel.FileName);
        % Check that is volumetric
        if ~strcmpi(HeadmodelMat.HeadModelType, 'volume')
            bst_report('Error', sProcess, [], 'Head model must be volumetric');
            continue
        end  
        % Load Channel file
        sChannel = bst_get('ChannelForStudy', iStudy);
        ChannelMat = in_bst_channel(sChannel.FileName, 'Channel');             
        % Compute exclusion zone
        [newHeadmodelMat, errMsg] = Compute(HeadmodelMat, ChannelMat, Modality, ExclusionRadius);
        if ~isempty(errMsg)
            bst_report('Error', sProcess, [], errMsg);
            continue;
        end
        % Add to database
        newHeadmodelFileName = db_add(iStudy, newHeadmodelMat);
        newDefaultHM{end+1, 1} = iStudy;
        newDefaultHM{end,   2} = newHeadmodelFileName;
    end
    % Set exclusion-zone headmodel as default in study
    for ix = 1 : size(newDefaultHM, 1)
        iStudy = newDefaultHM{ix, 1};
        newHeadmodelFileName = newDefaultHM{ix, 2};
        sStudy = bst_get('Study', iStudy);
        iHeadModel = find(strcmpi({sStudy.HeadModel.FileName}, newHeadmodelFileName));
        sStudy.iHeadModel = iHeadModel;
        bst_set('Study', iStudy, sStudy);        
    end    
    % Close progress bar
    bst_progress('stop');
    panel_protocols('UpdateTree');
end


%% ===== COMPUTE =====
function [newHeadmodelMat, errMsg] = Compute(HeadmodelMat, ChannelMat, Modality, ExclusionRadius)
    % Computes the exclusion zone in the HeadmodelMat based on the sensor locations, and ExclusionRadius. Only for volumetric grids
    
    newHeadmodelMat = [];
    errMsg = '';
    % Check that is volumetric
    if ~strcmpi(HeadmodelMat.HeadModelType, 'volume')
        errMsg = 'Head model must be volumetric';
        return
    end
    % Find selected channels
    iChannels = channel_find(ChannelMat.Channel, Modality);
   if isempty(iChannels)
        errMsg = ['Could not load any sensor for modality: ' Modality];
        return;
   end
    % Get channel locations
    channelLocs = [ChannelMat.Channel(iChannels).Loc]';
    % Indices of grid points in exclusion zone
    iBadVertices = [];
    for iLocation = 1 : size(channelLocs, 1)
        iBadVerticesLoc = find(sqrt(sum(bst_bsxfun(@minus, HeadmodelMat.GridLoc, channelLocs(iLocation, :)) .^ 2, 2)) <= ExclusionRadius);
        iBadVertices = [iBadVertices, iBadVerticesLoc'];
    end    
    if isempty(iBadVertices)
        errMsg = 'There is no grid points to remove in the exclusion zone.';
        return
    end
    iBadVertices = unique(iBadVertices); 
    % Indices to gain indices
    iBadGains = sort([3*iBadVertices, 3*iBadVertices - 1, 3*iBadVertices - 2]);
    % New head model with exclusion zone
    newHeadmodelMat = HeadmodelMat;
    newHeadmodelMat.GridLoc(iBadVertices, :) = [];
    newHeadmodelMat.Gain(:, iBadGains)       = [];
    exclusionZoneComment = sprintf('exclusion_zone %.2f mm', ExclusionRadius * 1000);
    newHeadmodelMat.Comment = [HeadmodelMat.Comment, ' | ' exclusionZoneComment];
    newHeadmodelMat = bst_history('add', newHeadmodelMat, ['Apply ' exclusionZoneComment]);
end


%% ===== COMPUTE/INTERACTIVE =====
function ComputeInteractive(HeadmodelFileName, Modality, iStudy)
    windowTitle = 'Leadfield exclusion zone';
    HeadmodelMat = in_bst_headmodel(HeadmodelFileName);
    % Check that is volumetric
    if ~strcmpi(HeadmodelMat.HeadModelType, 'volume')
        bst_error('Head model must be volumetric', windowTitle, 0);
        return
    end        
    % Ask user the distance of the exclusion zone
    [res, isCancel] = java_dialog('input', ['<HTML>' GetUsageText(Modality) '<BR><BR>' ... 
                                            'Exclusion distance (mm):'], ...
                                             windowTitle, [], sprintf('%.2f', 1));
    if isCancel || isempty(res)
        return
    end
    % Exclusion radius in m
    ExclusionRadius = str2double(res) ./ 1000;
    if ExclusionRadius <= 0
        bst_error('You must define an exclusion distance greater than zero.', 'Leadfield exclusion zone', 0);
        return;
    end
    % Start the progress bar
    bst_progress('start', windowTitle, 'Computing leadfield exclusion zone...');
    % Load Channel file
    sChannel = bst_get('ChannelForStudy', iStudy);
    ChannelMat = in_bst_channel(sChannel.FileName, 'Channel');             
    % Compute exclusion zone
    [newHeadmodelMat, errMsg] = Compute(HeadmodelMat, ChannelMat, Modality, ExclusionRadius);
    if ~isempty(errMsg)
        bst_progress('stop');
        bst_error(errMsg, windowTitle, 0);
        return;        
    end
    % Add to database
    newHeadmodelFileName = db_add(iStudy, newHeadmodelMat);
    % Set as default headmodel
    sStudy = bst_get('Study', iStudy);
    iHeadModel = find(strcmpi({sStudy.HeadModel.FileName}, newHeadmodelFileName));
    sStudy.iHeadModel = iHeadModel;
    bst_set('Study', iStudy, sStudy);    
    panel_protocols('UpdateTree');
    % Close progress bar
    bst_progress('stop');
end 


%% ===== GET USAGE TEXT =====
function usageHtmlText = GetUsageText(Modality)
    if nargin < 1 || isempty(Modality)
        Modality = '';
    end
    usageHtmlText = ['Define the exclusion zone around the ' Modality ' sensors. <BR><BR>'  ...
                     '<B>Warning</B> This approach will remove the leadfield vectors located near the sensors. <BR>' ...
                     'This method also remove the sources located in the exlusion zone <BR>'...
                     'The exclusion zone is defined by the distance from the sensors to the sources.'];
end