function varargout = panel_channel_editor(varargin)
% PANEL_CHANNEL_EDITOR: Create a panel to edit the channel files.
%
% DESCRIPTION:
%     Can be used in two ways :
%        - To edit a *_channel*.mat file (ChannelFile)
%        - To edit the good/bad channels (ChannelFlag array) in a MEG/EEG file (DataFile)
%
% USAGE:  bstPanelNew = panel_channel_editor('CreatePanel', ChannelFile)           : Edit ChannelFile
%         bstPanelNew = panel_channel_editor('CreatePanel', ChannelFile, DataFile) : Edit ChannelFlag
%                       panel_channel_editor('SaveChannelFile')
%         ChannelFlag = panel_channel_editor('GetTableGoodChannels')
%                       panel_channel_editor('SetChannelSelection', ChannelIndices, isGlobalUpdate)
%                       panel_channel_editor('SetChannelSelection', ChannelIndices)
%                       panel_channel_editor('UpdateChannelFlag', DataFile, ChannelFlag, 'NoChannelEditorUpdate')
%                       panel_channel_editor('UpdateChannelFlag', DataFile, ChannelFlag)
% [colNames, Channel] = panel_channel_editor('LoadChannelFile')

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2015

eval(macro_method);
end



%% ===== CREATE PANEL =====
% USAGE: CreatePanel(ChannelFile)           : Edit ChannelFile
%        CreatePanel(ChannelFile, DataFile) : Edit ChannelFile and ChannelFlag of DataFile
function bstPanelNew = CreatePanel(ChannelFile, DataFile) %#ok<DEFNU>
    panelName = 'ChannelEditor';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.table.*;

    % Parse inputs
    % If there is a DataFile defined : user is edit editing a ChannelFlag array, 
    % there is one more column
    if (nargin == 2)
        isChannelFlag = 1;
    else
        DataFile = [];
        isChannelFlag = 0;
    end

    
    % ===== LOAD CHANNEL_FILE AND CHANNEL_FLAG =====
    global GlobalData;
    GlobalData.ChannelEditor.ChannelFile   = ChannelFile;
    GlobalData.ChannelEditor.DataFile      = DataFile;
    GlobalData.ChannelEditor.LocColumns    = [];
    GlobalData.ChannelEditor.OrientColumns = [];
    % Load Channel File
    [columnNames, channelsData] = LoadChannelFile();
    if isempty(columnNames)
        bst_error('No channels to display.', 'Channel editor', 0);
        bstPanelNew = [];
        return;
    end
    nbColumns = length(columnNames);
    
    % If editing ChannelFlag
    if isChannelFlag
        % Load ChannelFlag of DataFile
        DataMat = in_bst_data(GlobalData.ChannelEditor.DataFile, 'ChannelFlag');
        ChannelFlag = DataMat.ChannelFlag;
        if isempty(columnNames)
            error('Cannot load data file : "%s"', DataFile);
        end
        % If ChannelFlag and ChannelFile numbers of channels do not match
        if (length(ChannelFlag) ~= size(channelsData, 1))
            bst_error(sprintf('Number of channels in ChannelFile (%d) and in DataFile (%d) do not match. Aborting...', size(channelsData, 1), length(ChannelFlag)), 'Edit good/bad channels');
            bstPanelNew = [];
            return;
        end
        % Add a GOOD/BAD column to the channel JTable
        columnNames = cat(2, ' ', columnNames);
        % Add the ChannelFlag column to the channel data
        channelsData = cat(2, num2cell(ChannelFlag(:) >= 0), channelsData);
    end 

    
    % ===== INITIALIZE CHANNEL EDITOR =====
    % Create JTable
    jTableChannel = JTable();
    jTableChannel.setFont(bst_get('Font'));
    jTableChannel.setModel(ChannelTableModel(jTableChannel, channelsData, columnNames));
    jTableChannel.setRowHeight(22);
    jTableChannel.setForeground(Color(.2, .2, .2));
    jTableChannel.setSelectionBackground(Color(.72, 0.81, 0.89));
    jTableChannel.setSelectionForeground(Color(.2, .2, .2));
    jTableChannel.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
    jTableChannel.getTableHeader.setReorderingAllowed(0);
    
    % COLUMN 0 : CHANNEL FLAG (GOOD/BAD)
    if isChannelFlag
        jTableChannel.getColumnModel.getColumn(0).setPreferredWidth(15);
        jTableChannel.getColumnModel.getColumn(0).setCellRenderer(BooleanCellRenderer());
        jTableChannel.getColumnModel.getColumn(0).setCellEditor(BooleanCellEditor());
    end
    % COLUMN 1 : CHANNEL INDEX
    jTableChannel.getColumnModel.getColumn(0 + isChannelFlag).setPreferredWidth(30);
    if isChannelFlag
        jTableChannel.getColumnModel.getColumn(0 + isChannelFlag).setCellEditor(DisabledCellEditor());
    else
        jTableChannel.getColumnModel.getColumn(0 + isChannelFlag).setCellEditor(IntegerCellEditor());
        jTableChannel.getColumnModel.getColumn(0 + isChannelFlag).setCellRenderer(IntegerCellRenderer());
    end
    % COLUMN 2 : CHANNEL NAME
    jTableChannel.getColumnModel.getColumn(1 + isChannelFlag).setPreferredWidth(50);
    % COLUMN 3 : CHANNEL TYPE
    jTableChannel.getColumnModel.getColumn(2 + isChannelFlag).setPreferredWidth(60);
    tableListTypes = {'(Delete)', 'MEG', 'MEG MAG', 'MEG GRAD', 'MEG REF', 'EEG', 'EEG REF', 'ECOG', 'SEEG', 'ECG', 'EOG', 'EMG', 'Stim', 'Misc', 'NIRS'};
    jComboTypes = gui_component('ComboBox', [], [], [], {tableListTypes}, [], [], []);
    jComboTypes.setEditable(true);
    cellEditor = DefaultCellEditor(jComboTypes);
    cellEditor.setClickCountToStart(2);
    jTableChannel.getColumnModel.getColumn(2 + isChannelFlag).setCellEditor(cellEditor);
    % COLUMN 4 : CHANNEL GROUP
    jTableChannel.getColumnModel.getColumn(3 + isChannelFlag).setPreferredWidth(60);
    % COLUMN 5 : COMMENT   
    if ~isChannelFlag
        jTableChannel.getColumnModel.getColumn(4 + isChannelFlag).setPreferredWidth(70);
    else
        jTableChannel.getColumnModel.getColumn(4 + isChannelFlag).setPreferredWidth(150);
    end
    % COLUMN 6-NbColumns : LOC, ORIENTATION
    if ~isChannelFlag
        for iCol = (5+isChannelFlag):nbColumns-1
            jTableChannel.getColumnModel.getColumn(iCol).setCellEditor(ArrayCellEditor());
            jTableChannel.getColumnModel.getColumn(iCol).setCellRenderer(ArrayCellRenderer());
        end     
    end
    % COLUMN NbColumns : WEIGHT
    jTableChannel.getColumnModel.getColumn(nbColumns - 1).setPreferredWidth(40);

    
    % ===== CREATE EDITOR PANEL =====
    % Output panel
    jPanelNew = JScrollPane(jTableChannel);
    jPanelNew.setBorder([]);

    % Set a Callback to track Table modifications
    java_setcb(jTableChannel.getModel(), 'TableChangedCallback', @TableChanged_Callback);
    java_setcb(jTableChannel, 'MouseReleasedCallback', @TableClick_Callback);
    % Set callback to track selection changes
    java_setcb(jTableChannel.getSelectionModel(), 'ValueChangedCallback', @(h,ev)TableSelectionChanged_Callback(ev.getValueIsAdjusting()));
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jTableChannel', jTableChannel));
           
                       
    %% =================================================================================
    %  === LOCAL CALLBACKS  ============================================================
    %  =================================================================================          
    %% ===== TABLE CLICKED =====
    function TableClick_Callback(hObj, ev)
        import org.brainstorm.icon.*;
        if (ev.getButton() > 1)
            % Create popup menu
            jPopup = java_create('javax.swing.JPopupMenu');
            % Add menus
            gui_component('MenuItem', jPopup, [], 'Set channel type', IconLoader.ICON_CHANNEL, [], @(h,ev)SetChannelsField('type'), []);
            gui_component('MenuItem', jPopup, [], 'Set channel group', IconLoader.ICON_CHANNEL, [], @(h,ev)SetChannelsField('group'), []);
            gui_component('MenuItem', jPopup, [], 'Set channel comment', IconLoader.ICON_CHANNEL, [], @(h,ev)SetChannelsField('comment'), []);
            % Show popup menu
            jPopup.pack();
            jPopup.show(jTableChannel, ev.getPoint.getX(), ev.getPoint.getY());
        end
    end
end



%% =================================================================================
%  === GLOBAL CALLBACKS ============================================================
%  =================================================================================
%% ===== HIDING CALLBACK =====
function isAccepted = PanelHidingCallback() %#ok<DEFNU>
    global GlobalData;
    isAccepted = 1;
    isSaved = 0;
    % Progress bar
    bst_progress('start', 'Channel editor', 'Closing editor...');
    % Only check for modifications if some changing events were recorded
    if GlobalData.ChannelEditor.isModified
        % Get controls handles
        ctrl = bst_get('PanelControls', 'ChannelEditor');
        if isempty(ctrl) || isempty(GlobalData.ChannelEditor) || isempty(GlobalData.ChannelEditor.ChannelMat) || isempty(GlobalData.ChannelEditor.ChannelMat.Channel)
            return
        end
        % Get initial channel structure
        InitChannel = GlobalData.ChannelEditor.ChannelMat.Channel;
        % Get final channel structure
        FinalChannel = GetTableData(ctrl.jTableChannel);
        % Check if there were modifications
        if isempty(GlobalData.ChannelEditor.DataFile)
            isModified = ~isequal({InitChannel.Name}, {FinalChannel.Name}) || ...
                         ~isequal({InitChannel.Type}, {FinalChannel.Type}) || ...
                         ~isequal({InitChannel.Comment}, {FinalChannel.Comment}) || ...
                         ~isequal({InitChannel.Group}, {FinalChannel.Group}) || ...
                         ~isequal([InitChannel.Loc], [FinalChannel.Loc]) || ...
                         ~isequal([InitChannel.Orient], [FinalChannel.Orient]) || ...
                         ~isequal([InitChannel.Weight], [FinalChannel.Weight]);
        else
            % Get the list of enabled and disabled channels
            FinalChannelFlag = GetTableGoodChannels();
            % Get initial list
            DataMat = in_bst_data(GlobalData.ChannelEditor.DataFile, 'ChannelFlag');
            InitChannelFlat = DataMat.ChannelFlag;
            % Check for differences
            isModified = ~isequal(InitChannelFlat, FinalChannelFlag) || ...
                         ~isequal({InitChannel.Name},    {FinalChannel.Name}) || ...
                         ~isequal({InitChannel.Comment}, {FinalChannel.Comment}) || ...
                         ~isequal({InitChannel.Type},    {FinalChannel.Type}) || ...
                         ~isequal({InitChannel.Group},   {FinalChannel.Group});
        end
    else
        isModified = 0;
    end
    
    % Are there some changes
    if ~isempty(GlobalData.ChannelEditor.ChannelFile) && isModified
        if isempty(GlobalData.ChannelEditor.DataFile)
            res = java_dialog('question', ['Save modifications to channel file : ' 10 10 GlobalData.ChannelEditor.ChannelFile], ...
                              'Channel editor', [], {'Yes', 'No', 'Cancel'});
        else
            res = java_dialog('question', ['Save modification to channel and data files : ' 10 10 GlobalData.ChannelEditor.ChannelFile 10 GlobalData.ChannelEditor.DataFile], ...
                              'Channel editor', [], {'Yes', 'No', 'Cancel'});
        end
        if isempty(res) || strcmpi(res, 'Cancel')
            isAccepted = 0;
            bst_progress('stop');
            return
        end
        if strcmpi(res, 'Yes')
            % Save ChannelFile
            SaveChannelFile();
            % Get study associated with channel file
            [sStudy, iStudy] = bst_get('ChannelFile', GlobalData.ChannelEditor.ChannelFile);
            % Reload study file
            db_reload_studies(iStudy);
            % Save ChannelFlag array in DataFile
            if ~isempty(GlobalData.ChannelEditor.DataFile)
                % Update Channel flag in file DataFile, and update all the associated figures
                UpdateChannelFlag(GlobalData.ChannelEditor.DataFile, FinalChannelFlag, 'NoChannelEditorUpdate');
            end
            isSaved = 1;
        else
            % Nothing to do
        end
    end
    % Reset ChannelEditor structure
    GlobalData.ChannelEditor.ChannelFile    = '';
    GlobalData.ChannelEditor.ChannelMat     = [];
    GlobalData.ChannelEditor.DataFile       = '';
    GlobalData.ChannelEditor.LocColumns     = [];
    GlobalData.ChannelEditor.OrientColumns  = [];
    GlobalData.ChannelEditor.isModified     = 0;
    % Unload eveything
    if isSaved
        bst_memory('UnloadAll', 'Forced', 'KeepChanEditor');
    end
    % Progress bar
    bst_progress('stop');
end


%% ===== TABLE MODEL MODIFICATION CALLBACK =====
function TableChanged_Callback(hObject, ev)
    global GlobalData;
    % Set that the structure was modified
    GlobalData.ChannelEditor.isModified = 1;
    % Get controls handles
    ctrl = bst_get('PanelControls', 'ChannelEditor');
    if isempty(ctrl)
        return
    end
    % Sort again channel file (if indice of channels was changed)
    isChannelFlag = ~isempty(GlobalData.ChannelEditor.DataFile);
    if ~isChannelFlag
        ctrl = bst_get('PanelControls', 'ChannelEditor');
        ctrl.jTableChannel.getModel().sortIndices(0, 1);
        ctrl.jTableChannel.repaint();
    end
end


%% ===== SELECTION CHANGED CALLBACK =====
function TableSelectionChanged_Callback(isAdjusting)
    global GlobalData;
    % If User is still adjusting the selection : do not process event
    if (nargin > 0) && isAdjusting
        return
    end
    % Get controls handles
    ctrl = bst_get('PanelControls', 'ChannelEditor');
    % Get selected sensor 
    iSelChan = ctrl.jTableChannel.getSelectedRows()' + 1;
    SelChan = {GlobalData.ChannelEditor.ChannelMat.Channel(iSelChan).Name};
    % Select sensor 
    bst_figures('SetSelectedRows', SelChan);
end


%% ===== LOAD CHANNEL FILE =====
function [columnNames, channelsData] = LoadChannelFile()
    global GlobalData;
    % Initialize returned variables
    columnNames    = {};
    channelsData   = {};
    % Get channel file name
    ChannelFile = GlobalData.ChannelEditor.ChannelFile;
    if isempty(ChannelFile)
        return
    end
    % Is it needed to load the numeric part (Location, Orientation, Weight) ?
    % => If DataFile is defined : user is editing ChannelFlag : no need to display Loc,Orient,Weight
    if ~isempty(GlobalData.ChannelEditor.DataFile)
        isNumericPartNeeded = 0;
    else
        isNumericPartNeeded = 1;
    end
    % Load file
    ChannelMat = in_bst_channel(ChannelFile);
    % Store intial Channel structure in GlobalData
    GlobalData.ChannelEditor.ChannelMat = ChannelMat;
    GlobalData.ChannelEditor.isModified = 0;
    % Get number of channels in this file
    nbChannels = length(ChannelMat.Channel);
    if (nbChannels < 1)
        return
    end
    
    if isNumericPartNeeded
        % Get the number of different locations (for each channel) recorded in file 
        nbLoc = max(cellfun(@(x)size(x,2), {ChannelMat.Channel.Loc}));
        % Get the number of different orientations (for each channel) recorded in file
        nbOrient = max(cellfun(@(x)size(x,2), {ChannelMat.Channel.Orient}));    
    end
    
    % ==== Define table column names ====
    columnNames = {' ', 'Name', 'Type', 'Group', 'Comment'};
    % Numeric columns
    if isNumericPartNeeded
        % Location columns
        if (nbLoc == 1)
            columnNames{end + 1} = 'Loc';
            GlobalData.ChannelEditor.LocColumns = length(columnNames);
        else 
            for iLoc = 1:nbLoc
                columnNames{end + 1} = sprintf('Loc(%d)', iLoc);
                GlobalData.ChannelEditor.LocColumns = [GlobalData.ChannelEditor.LocColumns, length(columnNames)];
            end
        end
        % Orientation columns
        if (nbOrient == 1)
            columnNames{end + 1} = 'Orient';
            GlobalData.ChannelEditor.OrientColumns = length(columnNames);
        else 
            for iOrient = 1:nbOrient
                columnNames{end + 1} = sprintf('Orient(%d)', iOrient);
                GlobalData.ChannelEditor.OrientColumns = [GlobalData.ChannelEditor.OrientColumns, length(columnNames)];
            end
        end
        % Last column : "Weight"
        columnNames{end + 1} = 'Weight';
    end
    % Get number of columns
    nbColumns = length(columnNames);        
    
    % ==== Create table data model ====
    % Initialize table data
    channelsData = cell(nbChannels, nbColumns);
    % Process all the channels
    for iChannel = 1:nbChannels
        Channel = ChannelMat.Channel(iChannel);
        % Channel indice
        channelsData{iChannel, 1} = uint32(iChannel);
        % Channel Name
        if ischar(Channel.Name)
            channelsData{iChannel, 2} = java.lang.String(Channel.Name);
        else
            channelsData{iChannel, 2} = java.lang.String('');
        end
        % Channel Type
        if ischar(Channel.Type)
            channelsData{iChannel, 3} = java.lang.String(Channel.Type);
        else
            channelsData{iChannel, 3} = java.lang.String('');
        end
        % Channel Group
        if ischar(Channel.Group)
            channelsData{iChannel, 4} = java.lang.String(Channel.Group);
        else
            channelsData{iChannel, 4} = java.lang.String('');
        end
        % Channel Comment
        if ischar(Channel.Comment)
            channelsData{iChannel, 5} = java.lang.String(Channel.Comment);
        elseif isempty(Channel.Comment)
            channelsData{iChannel, 5} = java.lang.String('');
        elseif isnumeric(Channel.Comment)
            channelsData{iChannel, 5} = java.lang.String('[DATA]');
        end
        % Numeric columns
        if isNumericPartNeeded
            % Channel location
            iColumn = 6;
            for iLoc = 1:nbLoc
                channelsData{iChannel, iColumn} = num2cell(getLoc(Channel.Loc, iLoc));
                iColumn = iColumn + 1;
            end
            % Channel orientation
            for iOrient = 1:nbOrient
                channelsData{iChannel, iColumn} = num2cell(getLoc(Channel.Orient, iOrient));
                iColumn = iColumn + 1;
            end
            % Channel weight
            channelsData{iChannel, iColumn} = num2cell(Channel.Weight);
        end
    end

    % ===== GET LOC =====
    function nLoc = getLoc(Loc, n)
        % If information does not exist
        if (n > size(Loc, 2))
            nLoc = [];
        else
            nLoc = Loc(:, n);
        end
    end
end


%% ===== SAVE CHANNEL FILE =====
function SaveChannelFile()
    global GlobalData;
    if isempty(GlobalData.ChannelEditor.ChannelFile)
        return
    end
    % Get controls handles
    ctrl = bst_get('PanelControls', 'ChannelEditor');
    if isempty(ctrl)
        return
    end
    
    % Progress bar
    bst_progress('start', 'Channel editor', 'Saving channel file...');
    % Get initial ChannelFile structure
    ChannelMat = GlobalData.ChannelEditor.ChannelMat;
    % Get table data
    TableData = GetTableData(ctrl.jTableChannel);
    % Copy table information in original structure
    if isempty(GlobalData.ChannelEditor.DataFile)
        % Edit only channel file => all the information is in the table
        ChannelMat.Channel = TableData;
    else
        % Edit ChannelFlag + part of the channel file => only the following information is in the table
        [ChannelMat.Channel.Name]    = deal(TableData.Name);
        [ChannelMat.Channel.Comment] = deal(TableData.Comment);
        [ChannelMat.Channel.Type]    = deal(TableData.Type);
        [ChannelMat.Channel.Group]   = deal(TableData.Group);
    end
    % Delete marked channels
    iDel = good_channel(ChannelMat.Channel, [], '(Delete)');
    if ~isempty(iDel)
        ChannelMat.Channel(iDel) = [];
    end
    % Check that the type of iEEG channels matches the type of IntraElectrodes
    if ~isempty(ChannelMat.IntraElectrodes)
        for iElec = 1:length(ChannelMat.IntraElectrodes)
            % Get channels associated to this electrode
            iChan = find(strcmpi({ChannelMat.Channel.Group}, ChannelMat.IntraElectrodes(iElec).Name));
            if isempty(iChan)
                continue;
            end
            % Check if the type of the electrode is not assigned correctly
            if strcmpi(ChannelMat.IntraElectrodes(iElec).Type, 'SEEG') && ~any(strcmpi({ChannelMat.Channel(iChan).Type}, 'SEEG')) && any(strcmpi({ChannelMat.Channel(iChan).Type}, 'ECOG'))
                ChannelMat.IntraElectrodes(iElec) = struct_copy_fields(ChannelMat.IntraElectrodes(iElec), bst_get('ElectrodeConfig', 'ECOG'), 1);
                ChannelMat.IntraElectrodes(iElec).Type = 'ECOG-mid';
                disp(['BST> Changed the type of electrode "' ChannelMat.IntraElectrodes(iElec).Name '"  to "' ChannelMat.IntraElectrodes(iElec).Type '"']);
            elseif ismember(ChannelMat.IntraElectrodes(iElec).Type, {'ECOG','ECOG+SEEG'}) && ~any(strcmpi({ChannelMat.Channel(iChan).Type}, 'ECOG')) && any(strcmpi({ChannelMat.Channel(iChan).Type}, 'SEEG'))
                ChannelMat.IntraElectrodes(iElec) = struct_copy_fields(ChannelMat.IntraElectrodes(iElec), bst_get('ElectrodeConfig', 'SEEG'), 1);
                ChannelMat.IntraElectrodes(iElec).Type = 'SEEG';
                disp(['BST> Changed the type of electrode "' ChannelMat.IntraElectrodes(iElec).Name '"  to "' ChannelMat.IntraElectrodes(iElec).Type '"']);
            end
        end
    end
    % Add number of channels to the comment
    ChannelMat.Comment = str_remove_parenth(ChannelMat.Comment, '(');
    ChannelMat.Comment = [ChannelMat.Comment, sprintf(' (%d)', length(ChannelMat.Channel))];
    % History: Edit channel file
    ChannelMat = bst_history('add', ChannelMat, 'edit', 'Edited with the channel editor');
    % Save file
    bst_save(file_fullpath(GlobalData.ChannelEditor.ChannelFile), ChannelMat, 'v7');
end


%% ===== GET TABLE DATA =====
function Channel = GetTableData(jTableChannel)
    global GlobalData;
    % Get table size
    nbChannels = jTableChannel.getRowCount();
    nbColumns  = jTableChannel.getColumnCount();
    % If user is edit editing a ChannelFlag array
    isChannelFlag = ~isempty(GlobalData.ChannelEditor.DataFile);
    Channel = repmat(db_template('ChannelDesc'), [1,nbChannels]);
    % Process all the table entries
    for iChannel = 1:nbChannels
        % Name, Type, Group, Comment
        Channel(iChannel).Name  = char(jTableChannel.getValueAt(iChannel - 1, 1 + isChannelFlag));
        Channel(iChannel).Type  = upper(char(jTableChannel.getValueAt(iChannel - 1, 2 + isChannelFlag)));
        Channel(iChannel).Group = char(jTableChannel.getValueAt(iChannel - 1, 3 + isChannelFlag));
        % Do not update comment if it initially contains data
        if isempty(Channel(iChannel).Comment) || ischar(Channel(iChannel).Comment)
            Channel(iChannel).Comment = char(jTableChannel.getValueAt(iChannel - 1, 4 + isChannelFlag));
        end
        % Numeric values
        if ~isChannelFlag
            % Location
            Channel(iChannel).Loc = [];
            for iLoc = GlobalData.ChannelEditor.LocColumns
                jLoc = jTableChannel.getValueAt(iChannel - 1, iLoc - 1);
                if ~isempty(jLoc)
                    Channel(iChannel).Loc = [Channel(iChannel).Loc, [double(jLoc(1)); double(jLoc(2)); double(jLoc(3))]];
                end
            end
            % Orientation
            Channel(iChannel).Orient = [];
            for iOrient = GlobalData.ChannelEditor.OrientColumns
                jOrient = jTableChannel.getValueAt(iChannel - 1, iOrient - 1);
                if ~isempty(jOrient)
                    Channel(iChannel).Orient = [Channel(iChannel).Orient, [double(jOrient(1));double(jOrient(2));double(jOrient(3))] ];
                end
            end
            % Weight
            Channel(iChannel).Weight = [];
            jWeight = jTableChannel.getValueAt(iChannel - 1, nbColumns - 1);
            for i = 1:length(jWeight)
                Channel(iChannel).Weight(i) = double(jWeight(i));
            end
        end
    end
    bst_progress('stop');
end


%% ===== GET CHANNEL FLAG =====
function ChannelFlag = GetTableGoodChannels()
    global GlobalData;
    ChannelFlag = [];
    if isempty(GlobalData.ChannelEditor.DataFile)
        return
    end
    % Get controls handles
    ctrl = bst_get('PanelControls', 'ChannelEditor');
    if isempty(ctrl)
        return
    end
    % Get table size
    nbChannels = ctrl.jTableChannel.getRowCount();
    % Get channel flag (Column 0)
    ChannelFlag = zeros(nbChannels, 1);
    for iChannel = 1:nbChannels
        isGood = ctrl.jTableChannel.getValueAt(iChannel - 1, 0);
        % Good:1; Bad:-1
        if isGood
            ChannelFlag(iChannel) = 1;
        else
            ChannelFlag(iChannel) = -1;
        end
    end    
end


%% ===== SET SELECTION =====
% USAGE:  SetChannelSelection(ChannelIndices, isGlobalUpdate)
%         SetChannelSelection(ChannelIndices)
% INPUT:
%     - SelChan        : cell array of channel names
%     - isGlobalUpdate : if 0, perform only the update of the selection in table
%                        if 1, update of the selection in table AND all the dependent figures
function SetChannelSelection(SelChan, isGlobalUpdate) %#ok<DEFNU>
    global GlobalData;
    if (nargin < 2)
        isGlobalUpdate = 0;
    end
    % Get panel handles
    ctrl = bst_get('PanelControls', 'ChannelEditor');
    if isempty(ctrl) || isempty(ctrl.jTableChannel)
        return;
    end
    % Get selected indices
    iSelChan = [];
    AllChan = {GlobalData.ChannelEditor.ChannelMat.Channel.Name};
    for i = 1:length(SelChan)
        iSelChan = [iSelChan, find(strcmpi(SelChan{i}, AllChan))];
    end
    
    % Get selection model
    jSelectionModel = ctrl.jTableChannel.getSelectionModel();
    % Suspend Table SelectionChanged callback while updating the selection
    oldCbk = java_getcb(jSelectionModel, 'ValueChangedCallback');
    java_setcb(jSelectionModel, 'ValueChangedCallback', []);

    % Select rows coresponding to the selected channels
    jSelectionModel.clearSelection();
    for i = 1:length(iSelChan)
        jSelectionModel.addSelectionInterval(iSelChan(i) - 1, iSelChan(i) - 1);
    end

    % Restore callback
    java_setcb(jSelectionModel, 'ValueChangedCallback', oldCbk);

    % Run the routine to update all the figures
    if isGlobalUpdate
        TableSelectionChanged_Callback();
    end
end


%% ===== SET CHANNELS FIELD =====
function SetChannelsField(target)
    global GlobalData;
    % Get controls handles
    ctrl = bst_get('PanelControls', 'ChannelEditor');
    if isempty(ctrl)
        return
    end
    % Switch target
    switch lower(target)
        case 'type'
            field = 'Type';
            iColumn = 2;
            isUpper = 1;
        case 'group'
            field = 'Group';
            iColumn = 3;
            isUpper = 0;
        case 'comment'
            field = 'Comment';
            iColumn = 4; 
            isUpper = 0;
        otherwise
            error(['Invalid target: ' target]);
    end
    % Get selected channel
    iSelChan = ctrl.jTableChannel.getSelectedRows()' + 1;
    if isempty(iSelChan)
        return;
    end
    % Get the old type
    selType = GlobalData.ChannelEditor.ChannelMat.Channel(iSelChan(1)).(field);
    if isempty(selType)
        selType = '';
    end
    % Ask the user the new channel type
    newType = java_dialog('input', ['Please enter the channel ' lower(field) ':'], ['Set channel ' lower(field)], [], selType);
    if ~ischar(newType)
        return
    end
    % Force upper case
    if isUpper
        newType = upper(newType);
    end
    % Set the new type for each of the selected rows
    isChannelFlag = ~isempty(GlobalData.ChannelEditor.DataFile);
    for i = 1:length(iSelChan)
        ctrl.jTableChannel.setValueAt(java.lang.String(newType), iSelChan(i) - 1, iColumn + isChannelFlag);
    end
    % Repaint table
    ctrl.jTableChannel.repaint();
end


%% ===== UPDATE CHANNEL FLAG (DataSet and DataFile) =====
% USAGE:  UpdateChannelFlag(DataFile, ChannelFlag, 'NoChannelEditorUpdate')
%         UpdateChannelFlag(DataFile, ChannelFlag)
% NOTES:
%   - Update DataFile
%   - Get the DataSets that are based upon this DataFile
%   - Set the DataSet.Measures.ChannelFlag, 
%   - Reload all the figures that uses ChannelFlag
function UpdateChannelFlag(DataFile, ChannelFlag, varargin)
    global GlobalData;
    if (nargin >= 3) && strcmpi(varargin{1}, 'NoChannelEditorUpdate')
        NoChannelEditorUpdate = 1;
    elseif (nargin < 2)
        error('Usage : UpdateChannelFlag(DataFile, ChannelFlag)');
    else
        NoChannelEditorUpdate = 0;
    end
    % Progress bar
    bst_progress('start', 'Channel editor', 'Updating good/bad channels...');
    % Reset sensor selection
    bst_figures('SetSelectedRows', []);
    
    % ===== Save ChannelFlag in DataFile =====
    % Detect if it's a RAW file
    isRaw = (length(DataFile) > 9) && ~isempty(strfind(DataFile, 'data_0raw'));
    % Load data
    if isRaw
        DataMat = in_bst_data(DataFile, 'ChannelFlag', 'History', 'F');
    else
        DataMat = in_bst_data(DataFile, 'ChannelFlag', 'History');
    end
    % Update channel flags
    DataMat.ChannelFlag = ChannelFlag;
    if isRaw
        DataMat.F.channelflag = ChannelFlag;
    end
    % History: Set bad channels
    DataMat = bst_history('add', DataMat, 'bad_channels', ['Set bad channels: ' sprintf('%d ', find(ChannelFlag == -1))]);
    % Save file
    bst_save(file_fullpath(DataFile), DataMat, 'v6', 1);
    
    % ===== Get DataSet for this DataFile =====
    % Get current DataSet index
    iDataSets = bst_memory('GetDataSetData', DataFile);
    % Loop on all the found datasets
    for i = 1:length(iDataSets)
        iDS = iDataSets(i);
        % Update channel flag in the loaded raw file
        if isRaw && ~isempty(GlobalData.DataSet(iDS).Measures.sFile) && ~isempty(GlobalData.DataSet(iDS).Measures.sFile.channelflag) 
            GlobalData.DataSet(iDS).Measures.sFile.channelflag = ChannelFlag;
        end
        % If recordings are loaded: reload them
        if ~isempty(GlobalData.DataSet(iDS).Measures.F)
            bst_memory('LoadRecordingsMatrix', iDS);
        end
        % Update ChannelFlag of current DataSet
        GlobalData.DataSet(iDS).Measures.ChannelFlag = ChannelFlag;

        % ===== RELOAD ALL FIGURES =====
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            % Get figure handles
            Figure = GlobalData.DataSet(iDS).Figure(iFig);
            % Process only the figures that involve the channel selection
            if ~ismember(Figure.Id.Type, {'DataTimeSeries', 'Topography', '3DViz'})
                continue;
            end
            % Update sensors selected in the figure
            GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = bst_figures('GetChannelsForFigure', iDS, iFig);
            % Reload figure
            bst_figures('ReloadFigures', Figure.hFigure, 0);
            
            % === REDRAW SENSORS ===
            % Figure types: 3DViz, Topography
            if isfield(Figure, 'Handles') && isfield(Figure.Handles, 'hSensorMarkers') && isfield(Figure.Handles, 'hSensorLabels')
                % Get if the sensors (markers and labels) are displayed
                isMarkers = ~isempty(Figure.Handles.hSensorMarkers);
                isLabels  = ~isempty(Figure.Handles.hSensorLabels);
                % Use 'ViewSensors' function to update the figure
                if (isMarkers || isLabels)
                    if ~isempty(GlobalData.DataSet(iDS).DataFile)
                        % Restore sensors display
                        figure_3d('ViewSensors', Figure.hFigure, isMarkers, isLabels);
                    end
                end
            end
        end
    end
    % Hide progress bar
    bst_progress('stop');
    
    % ===== TRACK CHANGES FOR AUTO-PILOT =====
    if (GlobalData.Program.GuiLevel == 2)
        global BstAutoPilot;
        BstAutoPilot.isBadModified = 1;
    end
    
    % ===== Update ChannelFlag in ChannelEditor panel =====
    if ~NoChannelEditorUpdate
        % Get panel handles
        ctrl = bst_get('PanelControls', 'ChannelEditor');
        if isempty(ctrl) || isempty(ctrl.jTableChannel)
            return;
        end
        % If ChannelEditor is not editing a ChannelFlag array (ie. if ChannelEditor.DataFile is empty)
        if isempty(GlobalData.ChannelEditor.DataFile)
            return;
        end
        % Loop to update all the first column of Table data
        for iChannel = 1:length(GlobalData.ChannelEditor.ChannelMat.Channel)
            ctrl.jTableChannel.setValueAt((ChannelFlag(iChannel) >= 1), iChannel - 1, 0);
        end
        GlobalData.ChannelEditor.ChannelFlag = ChannelFlag;
    end
end




                   
