function varargout = process_remove_evoked( varargin )
% PROCESS_REMOVE_EVOKE: Remove evoke response from a set of data trials
%
% USAGE: sProcess = process_remove_evoked('GetDescription')
%          sInput = process_remove_evoked('Run',                 sProcess, sInputs)
%         DataAvg = process_remove_evoked('ComputeEvokeResponse, DataFileNames)
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
% Authors: Raymundo Cassani, 2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Remove evoke response';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 415;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data'};
    % === Overwrite
    sProcess.options.overwrite.Comment = 'Overwrite input files';
    sProcess.options.overwrite.Type    = 'checkbox';
    sProcess.options.overwrite.Value   = 0;
    sProcess.options.overwrite.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function sInputs = Run(sProcess, sInputs) %#ok<DEFNU>
    % Get current progressbar position
    curProgress = [];
    if bst_progress('isVisible')
        curProgress = bst_progress('get');
        bst_progress('text', 'Grouping files...');
    end
    % OPTIONS
    % Sensor types
    sensorTypes = [];
    if isfield(sProcess.options, 'sensortypes') && ~isempty(sProcess.options.sensortypes) && ~isempty(sProcess.options.sensortypes.Value)
        sensorTypes = sProcess.options.sensortypes.Value;
    end
    % Overwrite
    isOverwrite = sProcess.options.overwrite.Value;

    % Files are sorted by trial group (folder average)
    iGroups = process_average('SortFiles', sInputs, 5);
    % Remove evoked response for each group
    for ix = 1 : length(iGroups)
        % Set progress bar at the same level for each loop
        if ~isempty(curProgress)
            bst_progress('set', curProgress);
        end
        sInputsGroup = sInputs(iGroups{ix});
        % Do not process if there is only one input
        if (length(sInputsGroup) == 1)
            bst_report('Warning', sProcess, sInputsGroup(1), 'File is alone in its trial/comment group. Not processed.');
            continue;
        end

        % Compute evoke response
        [DataAvg, Messages] = ComputeEvokeResponse({sInputsGroup.FileName});
        if ~isempty(Messages)
            error(Messages)
            return;
        end

        % Load channel file (for group)
        ChannelFile = sInputsGroup(1).ChannelFile;
        ChannelMat = in_bst_channel(ChannelFile);
        % Select sensors
        if ~isempty(sensorTypes)
            % Channel to remove evoke response
            flagChannelRemove = zeros(size(DataAvg, 1), 1);
            % Find selected channels
            iChannels = channel_find(ChannelMat.Channel, sensorTypes);
            if isempty(iChannels)
                bst_report('Error', sProcess, tmp(1), 'Could not load anything from the input file. Check the sensor selection.');
                return;
            end
            % Keep only selected channels
            flagChannelRemove(iChannels) = 1;
        else
            flagChannelRemove = ones(size(DataAvg, 1), 1);
        end
        % Keep only requested channels
        DataAvg(~flagChannelRemove) = 0;

        % Remove evoke response from each trial
        for jx = 1 : length(sInputsGroup)
            disp(sInputsGroup(jx).FileName);
            % Load data file
            DataMat = in_bst_data(sInputsGroup(jx).FileName);
            % Remove evoke response
            DataMat.F = DataMat.F - DataAvg;
            % Update comment
            DataMat.Comment = [DataMat.Comment, ' | no_erp'];
            % Overwrite the input file
            if isOverwrite
                OutputFile = file_fullpath(sInputsGroup(jx).FileName);
                bst_save(OutputFile, DataMat, 'v6');
            % Save new file
            else
                % Output filename: add file tag
                OutputFile = strrep(file_fullpath(sInputsGroup(jx).FileName), '.mat', '_noerp.mat');
                OutputFile = file_unique(OutputFile);
                % Save file
                bst_save(OutputFile, DataMat, 'v6');
               db_add_data(sInput.iStudy, OutputFile, TimefreqMat);
            end
        end
        % Reload study
        db_reload_studies(sInputsGroup(jx).iStudy);
    end
end

%% ===== COMPUTE EVOKE RESPONSE =====
% USAGE:  DataAvg = process_remove_evoked('ComputeEvokeResponse', DataFileNames)
function [DataAvg, Messages] = ComputeEvokeResponse(FileNames)
    % ===== COMPUTE EVOKED RESPONSE =====
    [Stat, Messages] = bst_avg_files(FileNames, [], 'mean', 0, 0, 0, 0, 1);
    if ~isempty(Messages)
        return;
    end
    DataAvg = Stat.mean;
end
