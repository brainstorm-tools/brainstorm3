function varargout = process_stdchan( varargin )
% PROCESS_STDCHAN: Uniformize the list of channels for a set of datasets.

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
% Authors: Francois Tadel, 2012-2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Uniform list of channels';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Standardize';
    sProcess.Index       = 300;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    % Definition of the options
    % === WARNING
    sProcess.options.warning.Comment = ['<B>Warning</B>: This process will standardize all the recordings<BR>' ...
                                        'in all the selected folders, not only the files you selected<BR>' ...
                                        'in the Process1 tab. Note it cannot process links to raw files.<BR><BR>' ...
                                        'This proces may damage your database if not used properly.<BR>' ...
                                        'Backup your database before running it.<BR><BR>'];
    sProcess.options.warning.Type    = 'label';
    % === TARGET CHANNEL FILE
    sProcess.options.method.Comment = {'Keep only the common channel names<BR>=> Remove all the others', ...
                                       'Keep all the channel names<BR>=> Fill the missing channels with zeros', ...
                                       'Use the first channel file in the list'};
    sProcess.options.method.Type    = 'radio';
    sProcess.options.method.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    switch (sProcess.options.method.Value)
        case 1,   Comment = [sProcess.Comment, ' (remove extra)'];
        case 2,   Comment = [sProcess.Comment, ' (add missing)'];
        case 3,   Comment = [sProcess.Comment, ' (first file)'];
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Options
    Method = sProcess.options.method.Value;
    OutputFiles = {};
    
    % ===== ANALYZE DATABASE =====
    ChannelFiles = {};
    ChannelMats  = {};
    iInputSkip   = [];
    nChannels    = [];
    isEqualChan  = [];
    unionChanNames = {};
    interChanNames = {};
    % Progress bar
    bst_progress('text', 'Analyzing database...');
    % Check all the input files
    for iInput = 1:length(sInputs)
        % No channel file: ignore
        if isempty(sInputs(iInput).ChannelFile)
            bst_report('Error', sProcess, sInputs(iInput), ['File is not associated with a channel file: "' sInputs(iInput).FileName '".']);
            iInputSkip(end+1) = iInput;
            return;
        end
        % Check channel file
        if ~any(file_compare(sInputs(iInput).ChannelFile, ChannelFiles))
            % Get the study definition
            sStudy = bst_get('ChannelFile', sInputs(iInput).ChannelFile);
            % Check that the folders do not contain any source file, head models or noise covariance matrix
            if ~isempty(sStudy.HeadModel) || ~isempty(sStudy.Result) || ~isempty(sStudy.NoiseCov)
                bst_report('Error', sProcess, sInputs(iInput), 'You must delete all the head models, source maps and noise covariance matrices before running this process.');
                return;
            end
            % Read channel file
            chanMat = in_bst_channel(sInputs(iInput).ChannelFile);
            % Add channel file to list
            iNew = length(ChannelFiles) + 1;
            ChannelFiles{iNew} = file_win2unix(sInputs(iInput).ChannelFile);
            ChannelMats{iNew}  = chanMat;
            nChannels(iNew) = length(chanMat.Channel);
            % If list is the same as previous
            if isempty(isEqualChan)
                isEqualChan = 1;
            else
                isEqualChan(iNew) = isequal({chanMat.Channel.Name}, {ChannelMats{1}.Channel.Name});
            end
            % Union of all the channel names
            unionChanNames = union(unionChanNames, {chanMat.Channel.Name});
            % Intersection of all the channel names
            if isempty(interChanNames)
                interChanNames = {chanMat.Channel.Name};
            else
                interChanNames = intersect(interChanNames, {chanMat.Channel.Name});
            end
        end
    end
    % Remove studies that cannot be processed
    if ~isempty(iInputSkip)
        sInputs(iInputSkip) = [];
    end
    % Check that there is something to process
    if isempty(sInputs)
        bst_report('Error', sProcess, [], 'No data files to process.');
        return;
    elseif (length(ChannelFiles) == 1)
        bst_report('Error', sProcess, sInputs, 'All the input files share the same channel file, nothing to register.');
        return;
    end
    % Check if there any difference in the channel names
    if all(isEqualChan)
        bst_report('Error', sProcess, sInputs, 'All the input files have identical channel names.');
        return;
    end
    % Check if there are channels left
    if isempty(interChanNames)
        bst_report('Error', sProcess, sInputs, 'No common channel names in these data sets.');
        return;
    end
    

    %% ===== COMMON CHANNEL LIST =====
    % Get the channel file that has the more/less channels
    switch (Method)
        % Only common channels
        case 1   
            % Get the minimum number of channels
            [nChan, iRef] = min(nChannels);
            % Get channels
            ChanList = {ChannelMats{iRef}.Channel.Name};
            % Remove unecessary channels
            iRemove = find(~ismember(ChanList, interChanNames));
            if ~isempty(iRemove)
                ChanList(iRemove) = [];
            end
        % All channels
        case 2   
            % Get the maximum number of channels
            [nChan, iRef] = max(nChannels);
            % Get channels
            ChanList = {ChannelMats{iRef}.Channel.Name};
            % Add all the other channels
            iAdd = find(~ismember(unionChanNames, ChanList));
            if ~isempty(iAdd)
                ChanList = [ChanList, unionChanNames{iAdd}];
            end
        % First channel file
        case 3   
            ChanList = {ChannelMats{1}.Channel.Name};
    end

    %% ===== GET DATA FILES =====
    % Initialize loop variables
    iStudyChan = [];
    DataFiles = {}; 
    iFileData = [];
    % Get all the data files associated with each channel file
    for iFile = 1:length(ChannelFiles)
        bst_progress('text', sprintf('Identifying files to process... [%d/%d]', iFile, length(ChannelFiles)));
        % Get channel study, for reloading after processing
        [tmo, iStudyChan(end+1)] = bst_get('ChannelFile', ChannelFiles{iFile});
        % Get all the data files related to this channel file
        chanDataFiles = bst_get('DataForChannelFile', ChannelFiles{iFile});
        if ~isempty(chanDataFiles)
            DataFiles = cat(2, DataFiles, chanDataFiles);
            iFileData = cat(2, iFileData, repmat(iFile,1,length(chanDataFiles)));
        end
    end
    % Check if there is any raw file in there
    if ~all(cellfun(@(c)isempty(strfind(c, '_0raw')), DataFiles))
        bst_report('Error', sProcess, sInputs, [...
            'There are raw file links in the selected studies that cannot be modified with this process.' 10 ...
            'You can either delete these links, or re-organize your database with one channel file per folder.']);
        return;
    end

    %% ===== PROCESS CHANNEL FILES =====
    % Process channel files one by one
    iFileToProcess = [];
    strChanHistory = {};
    iChanSrc  = cell(1, length(ChannelFiles));
    iChanDest = cell(1, length(ChannelFiles));
    for iFile = 1:length(ChannelFiles)
        bst_progress('text', sprintf('Standardizing channel files... [%d/%d]', iFile, length(ChannelFiles)));
        % If channel names are identical to the reference: skip
        if isequal({ChannelMats{iFile}.Channel.Name}, ChanList)
            continue;
        end
        % Add to list of files to process
        iFileToProcess(end+1) = iFile;
        % Create list of orders for channels
        for iChan = 1:length(ChanList)
            iTmp = find(strcmpi(ChanList{iChan}, {ChannelMats{iFile}.Channel.Name}));
            iTmp = setdiff(iTmp, iChanSrc{iFile});
            if (length(iTmp) > 1)
                if (length(iTmp) > 1)
                    bst_report('Warning', sProcess, sInputs, 'Several channels with the same name, re-ordering might be inaccurate.');
                    iTmp = iTmp(1);
                end
            end
            if ~isempty(iTmp)
                iChanDest{iFile}(end+1) = iChan;
                iChanSrc{iFile}(end+1)  = iTmp;
            end
        end
        % List of added channels
        iAddedChan = setdiff(1:length(ChanList), iChanDest{iFile});
        iRemChan   = setdiff(1:length(ChannelMats{iFile}.Channel), iChanSrc{iFile});
        % Add a history entry
        strChanHistory{iFile} = 'Uniform list of channels:';
        if ~isempty(iAddedChan)
            strTmp = '';
            for i = 1:length(iAddedChan)
                strTmp = [strTmp, ChanList{iAddedChan(i)}, ','];
            end
            strChanHistory{iFile} = [strChanHistory{iFile}, sprintf(' %d added (%s)', length(iAddedChan), strTmp(1:end-1))];
        end
        if ~isempty(iRemChan)
            strTmp = '';
            for i = 1:length(iRemChan)
                strTmp = [strTmp, ChannelMats{iFile}.Channel(iRemChan(i)).Name, ','];
            end
            strChanHistory{iFile} = [strChanHistory{iFile}, sprintf(' %d removed (%s)', length(iRemChan), strTmp(1:end-1))];
        end
        ChannelMats{iFile} = bst_history('add', ChannelMats{iFile}, 'stdchan', strChanHistory{iFile});
        % Update Channel structure
        tmpChanMat = ChannelMats{iFile};
        tmpChanMat.Channel = tmpChanMat.Channel(1);
        for iChan = 1:length(ChanList)
            tmpChanMat.Channel(iChan).Loc     = [];
            tmpChanMat.Channel(iChan).Orient  = [];
            tmpChanMat.Channel(iChan).Comment = '';
            tmpChanMat.Channel(iChan).Weight  = [];
            tmpChanMat.Channel(iChan).Type    = 'ADDED';
            tmpChanMat.Channel(iChan).Name    = ChanList{iChan};
        end
        tmpChanMat.Channel(iChanDest{iFile}) = ChannelMats{iFile}.Channel(iChanSrc{iFile});
        % Update MegRefCoef
        if isfield(tmpChanMat, 'MegRefCoef') && ~isempty(tmpChanMat.MegRefCoef)
            % Check that number of MEG sensors did not change, if not reset MegRefCoef
            iMegSrc  = good_channel(ChannelMats{iFile}.Channel, [], {'MEG', 'MEG REF'});
            iMegDest = good_channel(tmpChanMat.Channel, [], {'MEG', 'MEG REF'});
            if (length(iMegSrc) ~= length(iMegDest))
                bst_report('Warning', sProcess, sInputs, 'Number of Meg channels changed. Removing CTF compensation matrix from channel file.');
                tmpChanMat.MegRefCoef = [];
            end
        end
        % Update Projectors
        if isfield(tmpChanMat, 'Projector') && ~isempty(tmpChanMat.Projector)
            for iProj = 1:length(tmpChanMat.Projector)
                % New form: decomposed
                if ~isempty(tmpChanMat.Projector(iProj).CompMask)
                    tmpChanMat.Projector(iProj).Components = zeros(length(ChanList), size(ChannelMats{iFile}.Projector(iProj).Components,2));
                    tmpChanMat.Projector(iProj).Components(iChanDest{iFile},:) = ChannelMats{iFile}.Projector(iProj).Components(iChanSrc{iFile},:);
                % Old form: I-UUt
                else
                    tmpChanMat.Projector(iProj).Components = zeros(length(ChanList));
                    tmpChanMat.Projector(iProj).Components(iChanDest{iFile},iChanDest{iFile}) = ChannelMats{iFile}.Projector(iProj).Components(iChanSrc{iFile},iChanSrc{iFile});
                end
            end
        end
        % Update comment (replace channel number)
        tmpChanMat.Comment = [str_remove_parenth(tmpChanMat.Comment) ' (' num2str(length(ChanList)) ')'];
        % Save updated structure
        ChannelMats{iFile} = tmpChanMat;
        bst_save(file_fullpath(ChannelFiles{iFile}), tmpChanMat, 'v7');
    end
    % No files processed: exit
    if isempty(iFileToProcess)
        bst_report('Error', sProcess, sInputs, 'All channel files are similar.');
        return;
    end

    
    %% ===== PROCESS DATA FILES =====
    % Process each input data file
    for iData = 1:length(DataFiles)
        bst_progress('text', sprintf('Standardizing recordings files... [%d/%d]', iData, length(DataFiles)));
        % Get channel file index
        iFile = iFileData(iData);
        % File doesn't need to be processed
        if isempty(iChanDest{iFile})
            continue;
        end
        % Load the data file
        DataMat = in_bst_data(DataFiles{iData});
        newDataMat = DataMat;  
        % Raw file: error
        if isstruct(DataMat.F)
            bst_report('Warning', sProcess, [], 'Link to raw files cannot be processed. Delete the links because they cannot be loaded anymore.');
            continue;
        end
        % Update F field
        newDataMat.F = zeros(length(ChanList), size(DataMat.F,2));
        newDataMat.F(iChanDest{iFile},:) = DataMat.F(iChanSrc{iFile},:);
        % Update Std field
        if isfield(DataMat, 'Std') && ~isempty(DataMat.Std)
            newDataMat.Std = zeros(length(ChanList), size(DataMat.F,2));
            newDataMat.Std(iChanDest{iFile},:) = DataMat.Std(iChanSrc{iFile},:);
        end
        % Update ChannelFlag field
        newDataMat.ChannelFlag = -1 * ones(length(ChanList), 1);
        newDataMat.ChannelFlag(iChanDest{iFile}) = DataMat.ChannelFlag(iChanSrc{iFile});
        % Add comment
        newDataMat.Comment = [DataMat.Comment ' | stdchan'];
        % Add a history entry
        newDataMat = bst_history('add', newDataMat, 'stdchan', strChanHistory{iFile});
        % Save modifications
        bst_save(file_fullpath(DataFiles{iData}), newDataMat, 'v6');
    end
    % Reload all the studies
    db_reload_studies(unique([sInputs.iStudy, iStudyChan]));
    
    % Return in output all the data files that are in input, whatever happens in this process
    OutputFiles = {sInputs.FileName};
end



