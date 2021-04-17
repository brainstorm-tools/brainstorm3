function tree_set_channelflag(bstNodes, action, strChan)
% TREE_SET_CHANNELFLAG: Updates ChannelFlag for all the data files.
%
% USAGE:  tree_set_channelflag(bstNodes, 'AddBad')      : Add bad channels for all the data files
%         tree_set_channelflag(bstNodes, 'DetectFlat')  : Detect bad channels (values are all zeros)
%         tree_set_channelflag(bstNodes, 'ClearBad')    : Set some the channels as good for all the data files
%         tree_set_channelflag(bstNodes, 'ClearAllBad') : Set all the channels as good for all the data files
%         tree_set_channelflag(bstNodes, 'ShowBad')     : Display all the bad channels (as text)
%         tree_set_channelflag(DataFiles, action, strChan) : Pass the filenames and list of channels in argument (no gui)

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
% Authors: Francois Tadel, 2008-2014

% Parse inputs
if (nargin < 2)
    error('Usage:  tree_set_channelflag(bstNodes, action);');
end

% If processing tree nodes
if isjava(bstNodes)
    % If processing results
    nodeType = char(bstNodes(1).getType());
    isResults = ismember(nodeType, {'results', 'link'});
    isStat    = ismember(nodeType, {'pdata'});
    if isResults
        iStudies = [];
        iResults = [];
        for i = 1:length(bstNodes)
            % Get results filename
            ResultsFile = file_resolve_link(char(bstNodes(i).getFileName()));
            ResultsFile = file_short(ResultsFile);
            % Get results file study and indice
            [sStudy, iStudy, iRes] = bst_get('ResultsFile', ResultsFile);
            if ~isempty(iRes)
                iStudies = [iStudies, iStudy];
                iResults = [iResults, iRes];
            end
        end
    elseif isStat
        [iStudies, iStats] = tree_dependencies(bstNodes, 'pdata');
    else
        % Get selected data files
        [iStudies, iDatas] = tree_dependencies(bstNodes, 'data');
    end
% Else: Processing data files
else
    % Get list of filenames
    if ischar(bstNodes)
        DataFiles = {bstNodes};
    elseif iscell(bstNodes)
        DataFiles = bstNodes;
    else
        error('Invalid call.');
    end
    isResults = 0;
    isStat = 0;
    % Get studies for files in input
    iStudies = [];
    iDatas = [];
    for iFile = 1:length(DataFiles)
        [tmp, iStudies(iFile), iDatas(iFile)] = bst_get('DataFile', DataFiles{iFile});
    end
end

% No files found : return
if isempty(iStudies)
    return;
elseif isequal(iStudies, -10)
    disp('BST> Error in tree_dependencies.');
    return;
end


%% ===== CONFIRMATIONS =====
if (nargin < 3)
    strChan = '';
    switch (lower(action))
        case 'clearallbad'
            % Clearing bad channels: need a confirmation
            isConfirmed = java_dialog('confirm', ['WARNING: If you clear all the bad channels flags, all the channels will ' 10 ...
                                                  'be considered as GOOD. You will not be able to undo the modifications.' 10 10 ...
                                                  'Are you sure you want to mark all the channels as GOOD?'], 'Clear bad channels');
            if ~isConfirmed
                return
            end
        case 'addbad'
            % Setting channels to bad: ask which channels
            strChan = java_dialog('input', ['Enter the channel names or indices to mark as BAD in the selected files,' 10, ...
                                            'separated by commas (example: "MLT41, MRP44" or "12,23"):' 10 10], 'Set bad channels');
            % User canceled
            if isempty(strChan)
                return
            end
        case 'clearbad'
            % Setting channels to bad: ask which channels
            strChan = java_dialog('input', ['Enter the channel names or indices to mark as GOOD in the selected files,' 10, ...
                                            'separated by commas (example: "MLT41, MRP44" or "12,23"):' 10 10], 'Set good channels');
            % User canceled
            if isempty(strChan)
                return
            end
    end
end
isDetectFlat = strcmpi(action, 'detectflat');


%% ===== LOOP ON FILES =====
% Progress bar
bst_progress('start', 'Update ChannelFlag', 'Initialization...', 0, length(iStudies));
strReportTitle = '';
strReport = '';
isFirstError = 1;
prevChanFile = [];
iChan = [];
% Process all the data files
for i = 1:length(iStudies)
    % Get data file
    iStudy = iStudies(i);
    sStudy = bst_get('Study', iStudy);
    if isStat
        sData = sStudy.Stat(iStats(i));
        isRaw = 0;
    elseif isResults
        sData = sStudy.Result(iResults(i));
        isRaw = 0;
    else
        sData = sStudy.Data(iDatas(i));
        isRaw = strcmpi(sData.DataType, 'raw');
        if isRaw && isDetectFlat
            if isFirstError
                bst_error('This process can only be applied on imported recordings.', 'Detect flat channels', 0);
                isFirstError = 0;              
            end
            continue;
        end
    end
    DataFile = sData.FileName;
    DataFileFull = file_fullpath(DataFile);
    
    % Get channel file
    ChannelFile = bst_get('ChannelFileForStudy', sStudy.FileName);
    if isempty(ChannelFile)
        bst_error('No channel file available.', 'Set channel flag', 0);
        return;
    end
    % Load channel file
    if ~isequal(prevChanFile, ChannelFile)
        ChannelMat = in_bst_channel(ChannelFile);
        prevChanFile = ChannelFile;
        % Convert new GOOD channels to indices
        if ~isempty(strChan)
            % Try to read as sensor names
            iChan = channel_find(ChannelMat.Channel, strChan);
            % If nothing is found: read as indices
            if isempty(iChan)
                iChan = str2num(strChan);
            end
            if isempty(iChan)
                bst_error('Selected channel names were not found in the target channel file.', 'Update ChannelFlag', 0);
                return
            end
            if (any(iChan <= 0) || any(round(iChan) ~= iChan))
                error('Invalid channel indices.');
            end
        end
    end
    
    % Progress bar
    bst_progress('inc', 1);
    bst_progress('text', ['Processing: ', DataFile]);
    % Get subject
    sSubject = bst_get('Subject', sStudy.BrainStormSubject);
    % Load data from file (ChannelFlag and/or data)
    if isDetectFlat
        DataMat = in_bst_data(DataFile, 'ChannelFlag', 'F', 'History');
        % Detect bad channels
        iChan = find(sum(abs(DataMat.F),2) < 1e-20);
        % Remove F field
        DataMat = rmfield(DataMat, 'F');
    elseif isRaw
        DataMat = in_bst_data(DataFile, 'ChannelFlag', 'F', 'History');
    else
        DataMat = in_bst_data(DataFile, 'ChannelFlag', 'History');
    end
    warning on MATLAB:load:variableNotFound
    
    % Build information string
    strCond = [' - ' sSubject.Name];
    if ~isempty(sStudy.Condition)
        strCond = [strCond '/' sStudy.Condition{1}];
    end
    strCond = [strCond '/' sData.Comment ': '];

    % Find bad channels
    iBad = find(DataMat.ChannelFlag == -1);
    % Add bad channels to string
    if ~isempty(iBad)
        strBad = strCond;
        for ic = 1:length(iBad)
            %strBad = [strBad ChannelMat.Channel(iBad(ic)).Name, '(', num2str(iBad(ic)), ') '];
            strBad = [strBad, ChannelMat.Channel(iBad(ic)).Name];
            if (ic ~= length(iBad))
                 strBad = [strBad ', '];
            end
        end
    else
        strBad = '';
    end
    
    % Switch
    switch lower(action)
        case {'addbad', 'detectflat'}
            % Check indices
            if (max(iChan) > length(DataMat.ChannelFlag))
                bst_error('Invalid channel indices.', 'Set good/bad channels', 0);
                return;
            end
            % Message: first file
            if (i == 1)
                if isDetectFlat
                    strReportTitle = 'Detected bad channels (Subject/Condition/File):';
                else
                    strMsg = ['Added bad channels: ' sprintf('%d ', iChan)];
                end
            end
            % If all new bad channels are already marked as bad: nothing to do
            if isempty(iChan) || all(ismember(iChan, iBad))
                continue;
            end
            % Message: Detected bad channels
            if isDetectFlat
                strReport = [strReport 10 strCond ': ' sprintf('%d ', iChan)];
                strMsg = ['Detected bad channels: ' sprintf('%d ', iChan)];
            end
            % History: bad channels
            DataMat = bst_history('add', DataMat, 'bad_channels', strMsg);
            % Update ChannelFlag
            DataMat.ChannelFlag(iChan) = -1;
            % Update the RAW header
            if isRaw
                DataMat.F.channelflag = DataMat.ChannelFlag;
            end
            % Save file
            bst_save(DataFileFull, DataMat, 'v6', 1);
           
        case 'clearbad'
            % Check indices
            if (max(iChan) > length(DataMat.ChannelFlag))
                bst_error('Invalid channel indices.', 'Set good/bad channels', 0);
                return;
            end
            % Message
            if (i == 1)
                strMsg = ['Add good channels: ' sprintf('%d ', iChan)];
            end
            % Check all new good channels were already marked as good
            if isempty(iChan) || all(~ismember(iChan, iBad))
                continue;
            end
            % History: bad channels
            DataMat = bst_history('add', DataMat, 'bad_channels', strMsg);
            % Update ChannelFlag
            DataMat.ChannelFlag(iChan) = 1;
            % Update the RAW header
            if isRaw
                DataMat.F.channelflag = DataMat.ChannelFlag;
            end
            % Save file
            bst_save(DataFileFull, DataMat, 'v6', 1);
            
        case 'clearallbad'
            if (i == 1)
                strReportTitle = 'Cleared bad channels (Subject/Condition/File):';
            end
            % Bad channels cleared
            if ~isempty(iBad)
                % Display in message window
                %strReport = [strReport 10 strBad];
                % History: bad channels
                DataMat = bst_history('add', DataMat, 'bad_channels', 'Marked all channels as good');
                % Reset ChannelFlag
                DataMat.ChannelFlag = ones(size(DataMat.ChannelFlag));
                % Update the RAW header
                if isRaw
                    DataMat.F.channelflag = DataMat.ChannelFlag;
                end
                % Save file
                bst_save(DataFileFull, DataMat, 'v6', 1);
            end
            
        case 'showbad'
            if (i == 1)
                strReportTitle = 'List of bad channels (Subject/Condition/File):';
            end
            % Display in message window
            if ~isempty(iBad)
                strReport = [strReport 10 strBad];
            end
    end
    
    % Unload DataSets linked to this this DataFile
    iDSUnload = bst_memory('GetDataSetData', DataFile);
    if ~isempty(iDSUnload)
        bst_memory('UnloadDataSets', iDSUnload);
    end
end
% Hide progress bar
bst_progress('stop');
% Show report
if ~isempty(strReport)
    view_text( [strReportTitle 10 strReport], 'Report' );
end








