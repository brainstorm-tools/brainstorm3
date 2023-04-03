function varargout = process_extract_cluster( varargin )
% PROCESS_EXTRACT_CLUSTER: Extract clusters values.
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
% Authors: Francois Tadel, 2010-2023

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Clusters time series';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Extract';
    sProcess.Index       = 351;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ChannelClusters';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'matrix', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === CLUSTERS
    sProcess.options.clusters.Comment = '';
    sProcess.options.clusters.Type    = 'cluster';
    sProcess.options.clusters.Value   = [];
    % === CONCATENATE
    sProcess.options.concatenate.Comment = 'Concatenate output in one unique matrix';
    sProcess.options.concatenate.Type    = 'checkbox';
    sProcess.options.concatenate.Value   = 1;
    % === SAVE OUTPUT
    sProcess.options.save.Comment = '';
    sProcess.options.save.Type    = 'ignore';
    sProcess.options.save.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    % Only accept data files in input
    Comment = 'Extract clusters: ';
    % Get selected clusters
    if isstruct(sProcess.options.clusters.Value)
        ClusterLabels = {sProcess.options.clusters.Value.Label};
    else
        ClusterLabels = sProcess.options.clusters.Value;
    end
    % Format comment
    if isempty(ClusterLabels)
        Comment = [Comment, '[no selection]'];
    elseif (length(ClusterLabels) > 15)
        Comment = [Comment, sprintf('[%d clusters]', length(ClusterLabels))];
    else
        Comment = [Comment, sprintf('%s ', ClusterLabels{:})];
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Initialize returned variable
    OutputFiles = {};
    % REDIRECTING SCOUT CALLS TO PROCESS_EXTRACT_SCOUTS
    if ismember(sInputs(1).FileType, {'results', 'timefreq'})
        % Issue redirection warning
        bst_report('Warning', sProcess, [], ['The use of process_extract_cluster is not recommended for processing scouts anymore.' 10 'Redirecting to process_extract_scout...']);
        % Add missing options
        sProcess.options.scouts.Value = sProcess.options.clusters.Value;
        sProcess.options.scoutfunc.Value = [];
        sProcess.options.isflip.Value = 1;
        sProcess.options.addrowcomment.Value = 1;
        sProcess.options.addfilecomment.Value = 1;
        % Call process_extract_scout
        OutputFiles = process_extract_scout('Run', sProcess, sInputs);
        return;
    end
    
    % Get clusters: Old version (full structures) or new version (cell list of strings)
    if isempty(sProcess.options.clusters.Value)
        bst_report('Error', sProcess, [], 'No cluster selected.');
        return;
    elseif isstruct(sProcess.options.clusters.Value)
        sClusters = sProcess.options.clusters.Value;
        ClusterLabels = [];
    % New version: passing only the name of the clusters
    else
        ClusterLabels = sProcess.options.clusters.Value;
    end

    % Concatenate values ?
    isConcatenate = sProcess.options.concatenate.Value && (length(sInputs) > 1);
    isSave = sProcess.options.save.Value;
    % If a time window was specified
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    
    % ===== LOOP ON THE FILES =====
    for iInput = 1:length(sInputs)
        % === READ CHANNEL FILE ===
        % Check for channel file
        if isempty(sInputs(iInput).ChannelFile)
            bst_report('Error', sProcess, sInputs(iInput), 'This process requires a channel file.');
            continue;
        end
        % Get channel file
        ChannelMat = in_bst_channel(sInputs(iInput).ChannelFile);
        if ~isfield(ChannelMat, 'Clusters') || isempty(ChannelMat.Clusters)
            bst_report('Error', sProcess, [], ['No clusters available in channel file: ' sInputs(iInput).ChannelFile]);
            return;
        end

        % === READ RECORDINGS ===
        % Load data file
        sMat = in_bst_data(sInputs(iInput).FileName);
        % Raw file
        isRaw = strcmpi(sInputs(iInput).FileType, 'raw');
        if isRaw
            % Convert time bounds into samples
            sFile = sMat.F;
            if ~isempty(TimeWindow)
                SamplesBounds = round(sFile.prop.times(1) .* sFile.prop.sfreq) + bst_closest(TimeWindow, sMat.Time) - 1;
            else
                SamplesBounds = [];
            end
            % Read data
            [matValues, sMat.Time] = in_fread(sFile, ChannelMat, 1, SamplesBounds, []);
            stdValues = [];
            % Remember that time selection is already applied
            TimeWindow = [];
        % Epoched data file
        else
            matValues = sMat.F;
            stdValues = sMat.Std;
        end
        % Nothing loaded
        if isempty(sMat) || isempty(matValues)
            bst_report('Error', sProcess, sInputs(iInput), 'Could not load anything from the input file. Check the requested time window.');
            return;
        end
        % Add possibly missing fields
        if ~isfield(sMat, 'ChannelFlag')
            sMat.ChannelFlag = [];
        end
        if ~isfield(sMat, 'History')
            sMat.History = {};
        end
        % Replicate if no time
        if (size(matValues,2) == 1)
            matValues = cat(2, matValues, matValues);
            if ~isempty(stdValues)
                stdValues = cat(2, stdValues, stdValues);
            end
        end
        if (length(sMat.Time) == 1)
            sMat.Time = [0,1];
        end
        if ~isempty(matValues) && (size(matValues,2) == 1)
            matValues = [matValues, matValues];
            if ~isempty(stdValues)
                stdValues = [stdValues, stdValues];
            end
        elseif isfield(sMat, 'F') && (size(sMat.F,2) == 1)
            sMat.F = [sMat.F, sMat.F];
        end
        % Do not accecpt time bands
        if isfield(sMat, 'TimeBands') && ~isempty(sMat.TimeBands)
            bst_report('Error', sProcess, sInputs(iInput), 'Time bands are not supported yet by this process.');
            continue;
        end

        % === GET CLUSTERS ===
        if ~isempty(ClusterLabels)
            iClusters = zeros(1, length(ClusterLabels));
            for iClust = 1:length(ClusterLabels)
                iFound = find(strcmp(ClusterLabels{iClust}, {ChannelMat.Clusters.Label}));
                if isempty(iFound)
                    bst_report('Error', sProcess, [], ['Requested cluster is not available in channel file: ' ClusterLabels{iClust}]);
                    return;
                end
                iClusters(iClust) = iFound(1);
            end
            sClusters = ChannelMat.Clusters(iClusters);
        end

        % === TIME ===
        % Check time vectors
        if (iInput == 1)
            initTimeVector = sMat.Time;
        elseif (length(initTimeVector) ~= length(sMat.Time)) && isConcatenate
            bst_report('Error', sProcess, sInputs(iInput), 'Time definition should be the same for all the files.');
            continue;
        end
        % Option: Time window
        if ~isempty(TimeWindow)
            % Get time indices
            if (length(sMat.Time) <= 2)
                iTime = 1:length(sMat.Time);
            else
                iTime = panel_time('GetTimeIndices', sMat.Time, TimeWindow);
                if isempty(iTime)
                    bst_report('Error', sProcess, sInputs(iInput), 'Invalid time window option.');
                    continue;
                end
            end
            % Keep only the requested time window
            if ~isempty(matValues)
                matValues = matValues(:,iTime,:);
                if ~isempty(stdValues)
                    stdValues = stdValues(:,iTime,:,:);
                end
            else
                sMat.F = sMat.F(:,iTime);
            end
            sMat.Time = sMat.Time(iTime);
        end
        
        % === LOOP ON CLUSTERS ===
        scoutValues  = [];
        scoutStds    = [];
        Description  = {};
        clustComment = [];
        hasStds      = 0;
        for iClust = 1:length(sClusters)
            % === GET ROWS INDICES ===
            iRows = panel_cluster('GetChannelsInCluster', sClusters(iClust), ChannelMat.Channel, sMat.ChannelFlag);
            if strcmpi(sClusters(iClust).Function, 'All')
                if isfield(sClusters(iClust), 'Sensors')
                    RowNames = sClusters(iClust).Sensors;
                else
                    RowNames = cellfun(@num2str, num2cell(sClusters(iClust).Vertices), 'UniformOutput', 0);
                end
            else
                RowNames = [];
            end

            % Split cluster function if applicable
            separator = strfind(sClusters(iClust).Function, '+');
            if ~isempty(separator)
                ClusterFunction = sClusters(iClust).Function(1:separator-1);
                StdFunction     = sClusters(iClust).Function(separator+1:end);
                hasStds         = 1;
            else
                ClusterFunction = sClusters(iClust).Function;
                StdFunction = [];
            end
            
            % === COMPUTE CLUSTER VALUES ===
            % Save the name of the scout/cluster
            clustComment = [clustComment, ' ', sClusters(iClust).Label];
            % Apply scout function
            tmpScout = bst_scout_value(matValues(iRows,:,:), ClusterFunction, [], 1, [], 0);
            if ~isempty(StdFunction)
                tmpStd = bst_scout_value(matValues(iRows,:,:), StdFunction, [], 1, [], 0);
            elseif ~isempty(stdValues) && (length(iRows) == 1)
                tmpStd = stdValues(iRows,:,:,:);
            else
                tmpStd = [];
            end
            % Add to previous files
            scoutValues = cat(1, scoutValues, tmpScout);
            scoutStds = cat(1, scoutStds, tmpStd);
            for iRow = 1:size(tmpScout,1)
                if ~isempty(RowNames)
                    Description = cat(1, Description, [sClusters(iClust).Label '.' RowNames{iRow} ' @ ' sInputs(iInput).FileName]);
                else
                    Description = cat(1, Description, [sClusters(iClust).Label ' @ ' sInputs(iInput).FileName]);
                end
            end
        end
        
        % === OUTPUT STRUCTURE ===
        if (iInput == 1)
            % Create structure
            newMat = db_template('matrixmat');
            newMat.Value       = [];
            newMat.ChannelFlag = ones(size(sMat.ChannelFlag));
            newMat.Time = sMat.Time;
            newMat.nAvg = sMat.nAvg;
            newMat.Leff = sMat.Leff;
        end
        % Concatenate new values to existing ones
        if isConcatenate
            newMat.Value       = cat(1, newMat.Value,       scoutValues);
            newMat.Description = cat(1, newMat.Description, Description);
            newMat.ChannelFlag(sMat.ChannelFlag == -1) = -1;
            if hasStds || isequal(size(scoutStds), size(scoutValues))
                newMat.Std = cat(1, newMat.Std, scoutStds);
            end
        else
            newMat.Value       = scoutValues;
            newMat.Description = Description;
            newMat.ChannelFlag = sMat.ChannelFlag;
            if hasStds || isequal(size(scoutStds), size(scoutValues))
                newMat.Std = scoutStds;
            end
        end
        
        % === HISTORY ===
        if ~isConcatenate || (iInput == 1)
            % Re-use the history of the initial file
            newMat.History = sMat.History;
            % History: process name
            newMat = bst_history('add', newMat, 'process', FormatComment(sProcess));
        end
        % History: File name
        newMat = bst_history('add', newMat, 'process', [' - File: ' sInputs(iInput).FileName]);
                
        % === SAVE FILE ===
        % One file per input: save one matrix file per input file
        if ~isConcatenate
            % Comment: forced in the options
            if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
                newMat.Comment = sProcess.options.Comment.Value;
            % Comment: Process default (limit size of cluster comment)
            elseif (length(sClusters) > 1) && (length(clustComment) > 20)
                newMat.Comment = [sMat.Comment, ' | ' num2str(length(sClusters)) ' clusters'];
            elseif ~isempty(clustComment)
                newMat.Comment = [sMat.Comment, ' | clusters (' clustComment(2:end) ')'];
            else
                newMat.Comment = [sMat.Comment, ' | clusters'];
            end
            % Save new file in database
            if isSave
                % Output study = input study
                [sStudy, iStudy] = bst_get('Study', sInputs(iInput).iStudy);
                % Output filename
                OutFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_cluster');
                % Save on disk
                bst_save(OutFile, newMat, 'v6');
                % Register in database
                db_add_data(iStudy, OutFile, newMat);
                % Out to list of output files
                OutputFiles{end+1} = OutFile;
            % Just return scout values
            else
                newMat.nComponents = 1;
                % Return structure
                if isempty(OutputFiles)
                    OutputFiles = newMat;
                else
                    OutputFiles(end+1) = newMat;
                end
            end
        end
    end
    
    % === SAVE FILE ===
    % Only one concatenated output matrix
    if isConcatenate
        % Get output study
        [sStudy, iStudy, Comment] = bst_process('GetOutputStudy', sProcess, sInputs);
        % Comment: forced in the options
        if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
            newMat.Comment = sProcess.options.Comment.Value;
        % Comment: Process default
        else
            newMat.Comment = [strrep(FormatComment(sProcess), ' time series', ''), ' (' Comment ')'];
        end
        % Save new file in database
        if isSave
            % Output filename
            OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_cluster');
            % Save on disk
            bst_save(OutputFiles{1}, newMat, 'v6');
            % Register in database
            db_add_data(iStudy, OutputFiles{1}, newMat);
        % Just return scout values
        else
            OutputFiles = newMat;
        end
    end
end




