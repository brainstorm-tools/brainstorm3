function varargout = process_megreg( varargin )
% PROCESS_MEGREG: Co-register different datasets (runs/subjects/conditions) to the same channel file.
%
% DESCRIPTION:
%     MEG runs acquired at different moments typically have different sensor positions, 
%     they cannot be averaged or compared with each other.
%     This process computes one common head position and interpolates the magnetic fields of all the
%     input files, so that they all share the same channel file at the end.
%
% USAGE:            OutputFiles = process_megreg('Run', sProcess, sInputs)
%                       maxDist = process_megreg('Compute', sInputs, isShareChan, isAvgChan, epsilon, isDebug)
%       [maxDist,ErrAvg,ErrStd] = process_megreg('Test', epsilon)


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
% Authors: Sylvain Baillet 2002-2006
%          Francois Tadel, 2012

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Co-register MEG runs';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 304;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ChannelFile#Multiple_runs_and_head_positions';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    sProcess.isSeparator = 0;
    % Definition of the options
    % === TARGET CHANNEL FILE
    sProcess.options.label1.Type    = 'label';
    sProcess.options.label1.Comment = 'Target sensors positions :';
    sProcess.options.targetchan.Comment = {'Average of all the runs', 'First channel file in the list'};
    sProcess.options.targetchan.Type    = 'radio';
    sProcess.options.targetchan.Value   = 1;
    % === SHARE CHANNEL FILE
    sProcess.options.label2.Type    = 'label';
    sProcess.options.label2.Comment = '<BR>Use default channel file :';
    sProcess.options.sharechan.Comment = {'Yes, share the same channel file between runs', 'No, do not modify the database organization (recommended)'};
    sProcess.options.sharechan.Type    = 'radio';
    sProcess.options.sharechan.Value   = 2;
    % === EPSILON 
    sProcess.options.label3.Type    = 'label';
    sProcess.options.label3.Comment = ' ';
    sProcess.options.epsilon.Comment = 'Smoothing parameter: ';
    sProcess.options.epsilon.Type    = 'value';
    sProcess.options.epsilon.Value   = {.0001, '', 6};
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function [OutputFiles, maxDist] = Run(sProcess, sInputs) %#ok<DEFNU>
    % Options
    isShareChan = (sProcess.options.sharechan.Value == 1);
    isAvgChan   = (sProcess.options.targetchan.Value == 1);
    epsilon     = sProcess.options.epsilon.Value{1};
    isDebug     = isfield(sProcess.options, 'debug') && sProcess.options.debug.Value;
    
    % ===== ANALYZE DATABASE =====
    ChannelFiles = {};
    ChannelMats  = {};
    MegInterp    = {};
    isChanEqual  = [];
    iInputSkip   = [];
    OutputFiles  = {};
    maxDist      = 0;
    
    % Check all the input files
    for iInput = 1:length(sInputs)
        % No channel file: ignore
        if isempty(sInputs(iInput).ChannelFile)
            bst_report('Error', sProcess, sInputs(iInput), ['File is not associated with a channel file: "' sInputs(iInput).FileName '".']);
            iInputSkip(end+1) = iInput;
            continue;
        end
        % Check channel file
        if ~any(file_compare(sInputs(iInput).ChannelFile, ChannelFiles))
            % Read channel file
            chanMat = in_bst_channel(sInputs(iInput).ChannelFile);
            % Check that same number of sensors
            nChan = length(chanMat.Channel);
            if ~isempty(ChannelMats) && (nChan ~= length(ChannelMats{1}.Channel))
                bst_report('Error', sProcess, sInputs(iInput), ['File has a different number of channels than previous ones: "' sInputs(iInput).ChannelFile '".']);
                iInputSkip(end+1) = iInput;
                continue;
            end
            % Check that for all the channel files have the same sizes for the Loc fields
            if ~isempty(ChannelMats) && ~isequal(cellfun(@(c)size(c),{chanMat.Channel.Loc},'UniformOutput',0), cellfun(@(c)size(c),{ChannelMats{1}.Channel.Loc},'UniformOutput',0))
                bst_report('Error', sProcess, sInputs(iInput), ['Channels Loc fiels have a different structure in this file than the previous ones: "' sInputs(iInput).ChannelFile '".']);
                iInputSkip(end+1) = iInput;
                continue;
            end
            % Check file types
            if ~any(ismember({'MEG','MEG GRAD','MEG MAG'}, unique({chanMat.Channel.Type})))
                bst_report('Warning', sProcess, sInputs(iInput), ['No MEG sensors available in channel file: "' sInputs(iInput).ChannelFile '".']);
                %iInputSkip(end+1) = iInput;
                %continue;
            end
            % Remove head points
            if isfield(chanMat, 'HeadPoints')
                chanMat = rmfield(chanMat, 'HeadPoints');
            end
            % Add a history entry
            if isAvgChan
                historyMsg = sprintf('New channels positions: average of %d channel files', length(chanMat));
            else
                historyMsg = ['Using first channel file: ', sInputs(1).ChannelFile];
            end
            chanMat = bst_history('add', chanMat, 'meg_register', historyMsg);
            % Add channel file to list
            ChannelFiles{end+1} = file_win2unix(sInputs(iInput).ChannelFile);
            ChannelMats{end+1}  = chanMat;
            % Check if channel description is the same as the first one
            if isempty(isChanEqual)
                isChanEqual = 1;
            else
                isChanEqual(end+1) = isequal({chanMat.Channel.Loc}, {ChannelMats{1}.Channel.Loc});
            end
        end
    end
    % Remove studies that cannot be processed
    if ~isempty(iInputSkip)
        sInputs(iInputSkip) = [];
    end
    % Check that there is something to process
    if isempty(sInputs)
        bst_report('Error', sProcess, [], 'No data files to process');
        return;
    elseif (length(ChannelFiles) == 1)
        bst_report('Info', sProcess, sInputs, 'All the input files share the same channel file, nothing to register.');
        return;
    end
    % If all same channels loc, and just need to change subject
    isModifData = ~all(isChanEqual);
    % If no subject changes to perform: exit
    if ~isShareChan && ~isModifData
        bst_report('Info', sProcess, sInputs, 'All the channel files are equivalent. Subjects should not be modified, so there is nothing to do.');
        return;
    elseif ~isModifData
        bst_report('Info', sProcess, sInputs, 'All the channel files are equivalent. No modification will be performed on the data files.');
    end
    
    
    %% ===== COMPUTE TRANSFORMATION =====
    % Base: first channel file in the list
    AvgChannelMat = ChannelMats{1};
    % Compute average channel structure (include ALL the sensor types)
    if isAvgChan && ~all(isChanEqual)
        [AvgChannelMat, Message] = channel_average(ChannelMats);
        if isempty(AvgChannelMat)
            bst_report('Error', sProcess, sInputs, Message);
            return;
        end
        % Consider that channel files  are all different from the average
        isChanEqual = 0 * isChanEqual;
    end   
    % Get MEG channels
    iMeg = good_channel(AvgChannelMat.Channel, [], 'MEG');
    % Get single-point channel locations for average channel file
    chanlocsAvg = figure_3d('GetChannelPositions', AvgChannelMat, iMeg);
    % For each channel file: compute an interpolation matrix
    maxDist = 0;
    for iFile = 1:length(ChannelMats)
        % If positions of sensors changed
        if ~isChanEqual(iFile) || isDebug
            % Find the best-fitting sphere to source sensor locations
            chanlocs = figure_3d('GetChannelPositions', ChannelMats{iFile}, iMeg);
            [bfs_center, bfs_radius] = bst_bfs(chanlocs);
            % Compute interpolation
            [MegInterp{iFile}, src_xyz] = channel_extrapm('ComputeInterp', ChannelMats{iFile}.Channel(iMeg), AvgChannelMat.Channel(iMeg), bfs_center, bfs_radius, [], epsilon);
            % Compute maximum displacement
            maxDistLocal = max(sqrt(sum((chanlocs - chanlocsAvg) .^ 2, 2)));
            maxDist = max(maxDist, maxDistLocal);
            
            % Save interpolation as an SSP projection
            tmpInterp = eye(nChan);
            tmpInterp(iMeg,iMeg) = MegInterp{iFile};
            interpProj = process_ssp2('ConvertOldFormat', tmpInterp);
            interpProj.Comment = 'MEG runs co-registration';
            if ~isfield(ChannelMats{iFile}, 'Projector') || isempty(ChannelMats{iFile}.Projector)
                ChannelMats{iFile}.Projector = interpProj;
            else
                ChannelMats{iFile}.Projector = [ChannelMats{iFile}.Projector, interpProj];
            end
            % Copy average position in each channel file
            ChannelMats{iFile}.Channel = AvgChannelMat.Channel;
            % Debug displays
%             if isDebug
%                 % Display the interpolation matrix as an image
%                 figure('Name', bst_fileparts(ChannelFiles{iFile}));
%                 imagesc(MegInterp{iFile});
%                 % Display source space
%                 hFig = channel_extrapm('PlotSourceSpace', ChannelMats{iFile}.Channel(iMeg), AvgChannelMat.Channel(iMeg), src_xyz);
%                 set(hFig, 'Name', bst_fileparts(ChannelFiles{iFile}));
%             end
        else
            MegInterp{iFile} = [];
        end
    end
    % Check displacement
    if (maxDist > .02)
        msgType = 'Error';
    else
        msgType = 'Info';
    end
    bst_report(msgType, sProcess, sInputs, sprintf('Maximum displacement %d mm', round(maxDist * 1000)));
    
    %% ===== COMBINE OTHER CHANNEL INFORMATION =====
    % Check that all the MegRefCoef are equivalent
    if isfield(ChannelMats{1}, 'MegRefCoef') && (any(~cellfun(@(c)isequal(numel(c.MegRefCoef), numel(ChannelMats{1}.MegRefCoef)), ChannelMats)) || ...
                                                 any(cellfun(@(c)any(abs(c.MegRefCoef(:) - ChannelMats{1}.MegRefCoef(:)) > 0.001), ChannelMats)))
        bst_report('Warning', sProcess, sInputs, ['Channel files have different CTF compensation matrices (MegRefCoef).' 10 'Keeping the one from the first file.']);
        % return;
    end
    % Combine SSP from all the files
    if isShareChan
        Projector = [];
        for iFile = 1:length(ChannelMats)
            if isfield(ChannelMats{iFile}, 'Projector') && ~isempty(ChannelMats{iFile}.Projector)
                if isempty(Projector)
                    Projector = ChannelMats{iFile};
                else
                    bst_report('Warning', sProcess, sInputs, 'Ignoring Projector matrix (SSP and ICA). Using only the one from the first channel file.');
                end
            end
        end
    end
    
    
    %% ===== UPDATE CHANNEL FILES =====
    % Group all channels into one shared channel file
    if isShareChan
        % Single subject
        if all(file_compare({sInputs.SubjectFile}, sInputs(1).SubjectFile))
            UseDefaultChannel = 1;
        else
            UseDefaultChannel = 2;
        end
        % Get the list of subjects to update
        allSubj = unique({sInputs.SubjectFile});
        % Process each subject
        for iSubj = 1:length(allSubj)
            % Get subject 
            [sSubject, iSubject] = bst_get('Subject', allSubj{iSubj}, 1);
            % Update subject
            sSubject.UseDefaultChannel = UseDefaultChannel;
            sSubject = db_add_subject(sSubject, iSubject);
            % If one channel per subject: set channel file
            if (UseDefaultChannel == 1)
                % Get default study for this subject
                [sStudy, iStudy] = bst_get('DefaultStudy', iSubject);
                % Set channel file
                newChannelFile = db_set_channel(iStudy, AvgChannelMat, 2, 0);
            end
        end
        % If one channel per protocol: set channel file
        if (UseDefaultChannel == 2)
            % Get default study for this subject
            [sStudy, iStudy] = bst_get('DefaultStudy');
            % Set channel file
            newChannelFile = db_set_channel(iStudy, AvgChannelMat, 2, 0);
        end
        
    % Do not modify the database structure
    else
        % Overwrite each channel file separately
        for iFile = 1:length(ChannelFiles)
            chanMat = ChannelMats{iFile};
            bst_save(file_fullpath(ChannelFiles{iFile}), chanMat, 'v7');
        end
    end

    %% ===== UPDATE DATA FILES =====
    % Process each input data file
    for iInput = 1:length(sInputs)
        % Get channel file that corresponds to this data file
        iFile = find(file_compare(sInputs(iInput).ChannelFile, ChannelFiles));
        % Only process data file if there were modification to this channel file
        if ~isempty(MegInterp{iFile})
            % Load the data file
            DataMat = in_bst_data(sInputs(iInput).FileName);
            % Raw file: Update the channel file
            if isstruct(DataMat.F)
                DataMat.Time = DataMat.Time([1, end]);
            % Imported recordings: Apply interpolation matrix
            else
                Proj = MegInterp{iFile};
                % Get bad channels
                iBadChan = find(DataMat.ChannelFlag == -1);
                % Remove bad channels from the projector (similar as in in_fread)
                if ~isempty(iBadChan)
                    Proj(iBadChan,:) = 0;
                    Proj(:,iBadChan) = 0;
                    Proj(iBadChan,iBadChan) = eye(length(iBadChan));
                end
                % Get good channels
                DataMat.F(iMeg,:) = Proj * DataMat.F(iMeg,:);
            end
            % Add comment
            DataMat.Comment = [DataMat.Comment ' | reg'];
            % Add a history entry
            if isAvgChan
                DataMat = bst_history('add', DataMat, 'meg_register', sprintf('New channels positions: average of %d channel files', length(ChannelMats)));
            else
                DataMat = bst_history('add', DataMat, 'meg_register', ['Using first channel file: ', ChannelFiles{1}]);
            end
            % Save modifications
            bst_save(file_fullpath(sInputs(iInput).FileName), DataMat, 'v6');
        end
    end
    % Reload all the studies
    db_reload_studies(unique([sInputs.iStudy]));

    % Return in output all the data files that are in input, whatever happens in this process
    OutputFiles = {sInputs.FileName};
end


