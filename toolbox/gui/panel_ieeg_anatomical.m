function varargout = panel_ieeg_anatomical(varargin)
% PANEL_IEEG_ANATOMICAL: Create a panel to manually add/remove/edit seeg contacts on an isosurface generated from thresholding CT.
% 
% USAGE:  bstPanelNew = panel_ieeg_anatomical('CreatePanel')
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
% Authors: Chinmay Chinara, 2023-2024

eval(macro_method);
end

%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'ContactLabelIeeg';
    
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;

    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelNew.setPreferredSize(java_scaled('dimension', 320,500));

    % Create list for keeping track of the selected contact points
    jListModel = javax.swing.DefaultListModel();

    % Hack keyboard callback
    hFig = bst_figures('GetCurrentFigure', '3D');
    get(hFig, 'KeyPressFcn');
    set(hFig, 'KeyPressFcn', @KeyPress_Callback);

    % ===== CREATE TOOLBAR =====
    jToolbar = gui_component('Toolbar', jPanelNew, BorderLayout.WEST);
    jToolbar.setOrientation(jToolbar.VERTICAL);
    jToolbar.setPreferredSize(java_scaled('dimension', 70,25));
        % Button "Setting reference electrode based on tip and entry"
        jButtonDrawRefElectrode = gui_component('ToolbarButton', jToolbar, [], 'DrawRef', IconLoader.ICON_SCOUT_NEW, 'Draw reference electrode', @(h,ev)bst_call(@DrawRefElectrode, 0));
        % Button "Show/Hide reference"
        gui_component('ToolbarButton', jToolbar, [], 'DispRef', IconLoader.ICON_SCOUT_NEW, 'Show/Hide reference contacts for an electrode', @ShowHideReference);
        
        % add separator
        jToolbar.addSeparator();

        % Button "Remove selection" (THIS IS UNDER CONTRUCTION)
        % jButtonRemoveSelected = gui_component('ToolbarButton', jToolbar, [], 'DelSel', IconLoader.ICON_DELETE, 'Remove selected contact', @(h,ev)bst_call(@RemoveContactAtLocation_Callback,h,ev));
        % Button "Remove last"
        jButtonRemoveLast = gui_component('ToolbarButton', jToolbar, [], 'DelLast', IconLoader.ICON_DELETE, 'Remove last contact', @RemoveLastContact);
        % Button "Remove all"
        jButtonRemoveAll = gui_component('ToolbarButton', jToolbar, [], 'DelAll', IconLoader.ICON_DELETE, 'Remove all the contacts', @RemoveAllContacts);
        
        % add separator
        jToolbar.addSeparator();

        % Button "Save all to database"
        jButtonSaveAll = gui_component('ToolbarButton', jToolbar, [], 'Save', IconLoader.ICON_SAVE, 'Save all to database', @SaveAll);
    
    % ===== Main panel =====
    jPanelMain = gui_component('Panel');
    jPanelMain.setBorder(BorderFactory.createEmptyBorder(7,7,7,7));   

        jPanelFirstPart = gui_component('Panel');
            % ===== LIST FOR CONTACTS =====
            jPanelElecList = gui_component('Panel');
                jBorder = java_scaled('titledborder', 'sEEG contact localization');
                jPanelElecList.setBorder(jBorder);
                % Electrodes list
                jListElec = java_create('org.brainstorm.list.BstClusterList');
                jListElec.setBackground(Color(.9,.9,.9));
                java_setcb(jListElec, ...
                    'MouseClickedCallback', @(h,ev)bst_call(@ElecListClick_Callback,h,ev), ...
                    'KeyTypedCallback',     @(h,ev)bst_call(@ElecListKeyTyped_Callback,h,ev));
                jPanelScrollList = JScrollPane();
                jPanelScrollList.getLayout.getViewport.setView(jListElec);
                jPanelScrollList.setHorizontalScrollBarPolicy(jPanelScrollList.HORIZONTAL_SCROLLBAR_ALWAYS);
                jPanelScrollList.setVerticalScrollBarPolicy(jPanelScrollList.VERTICAL_SCROLLBAR_ALWAYS);
                jPanelScrollList.setBorder([]);
                jPanelElecList.add(jPanelScrollList);
            jPanelFirstPart.add(jPanelElecList, BorderLayout.CENTER);
        jPanelMain.add(jPanelFirstPart);

        % ===== Variables for getting details of the electrodes =====
        jPanelIeegAnat = gui_river('');            
            jTextNcontacts = gui_component('label', jPanelIeegAnat, 'tab', '', [], [], [], 0);
            jTextLabel = gui_component('label', jPanelIeegAnat, 'tab', '', [], [], [], 0);
            jTextContactSpacing = gui_component('label', jPanelIeegAnat, 'tab', '', [], [], [], 0);
        jPanelMain.add(jPanelIeegAnat, BorderLayout.SOUTH);
    jPanelNew.add(jPanelMain, BorderLayout.CENTER);

    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jTextNcontacts',          jTextNcontacts, ...
                                  'jTextLabel',              jTextLabel, ...
                                  'jTextContactSpacing',     jTextContactSpacing, ...
                                  'jPanelIeegAnat',          jPanelIeegAnat, ...
                                  'jListElec',               jListElec, ...
                                  'jPanelElecList',          jPanelElecList, ...
                                  'jListModel',              jListModel, ...
                                  'jButtonRemoveLast',       jButtonRemoveLast, ...
                                  'jButtonRemoveAll',        jButtonRemoveAll, ...
                                  'jButtonDrawRefElectrode', jButtonDrawRefElectrode, ...
                                  'jButtonSaveAll',          jButtonSaveAll));

    %% ============================================================================
    %  ========= INTERNAL PANEL CALLBACKS  (WHEN USER IS ACTIVE ON THE PANEL) =========
    %  ============================================================================

    %% ===== LIST CLICK CALLBACK =====
    function ElecListClick_Callback(h, ev)
        % IF SINGLE CLICK
        if (ev.getClickCount() == 1)
            % ===== Update crosshair location in MRI Viewer =====
            
            % Get the panel controls
            ctrl = bst_get('PanelControls', 'ContactLabelIeeg'); 

            % Get the index of the contact coordinates in the list
            iIndex = uint16(ctrl.jListElec.getSelectedIndices())' + 1;

            % if user clicked elsewhere on the panel just return
            if isempty(iIndex)
                return;
            end

            % updates the crosshair location in MRI Viewer
            SetLocationMri(iIndex);
        end
    end   
    
    %% ===== LIST KEYTYPED CALLBACK =====
    function ElecListKeyTyped_Callback(h, ev)
        switch(uint8(ev.getKeyChar()))
            case {ev.VK_DELETE}
                % delete contact a location
                RemoveContactAtLocation_Callback(h, ev);
            case {ev.VK_ESCAPE}
                % exit the selection state to stop plotting contacts
                SetSelectionState(0);
        end
    end
    
    %% ===== REMOVE AT A LOCATION (DELETE SPECIFIC CONTACT) =====
    % THIS IS UNDER CONTRUCTION
    % function RemoveContactAtLocation_Callback(h, ev)
    %     % Delete selection
    %     ctrl = bst_get('PanelControls', 'ContactLabelIeeg'); 
    %     iPoint = uint16(ctrl.jListElec.getSelectedIndices())' + 1;
    %     if isempty(iPoint)
    %         return;
    %     end
    %     isDelete = java_dialog('confirm', ...
    %     '<HTML><BR>Do you want to delete the label?<BR><BR>', ...
    %     'Delete label');  
    %     if isDelete
    %         RemoveContactAtLocation(iPoint);
    %     end
    % end
end
           
%% =================================================================================
%  === EXTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================

%% ===== LOAD DATA =====
% checks for loading of saved channel data on start
function LoadOnStart() %#ok<DEFNU>
    % global variables intitialization
    % for storing/loading channel details
    global ChannelAnatomicalMat;
    ChannelAnatomicalMat = [];
    
    % for keeping track of points used for plotting reference line
    global refLinePlotLoc;
    refLinePlotLoc = [];
    
    % for showing/hiding reference lines and points rendering
    global isRefVisible;
    isRefVisible = 1;

    % for keeping track of the total number of contacts for the current
    % electrode
    global totalNumContacts;
    totalNumContacts = 0;

    % for keeping track of click counts on surface
    global clickOnSurfaceCount;
    clickOnSurfaceCount = 0;
    
    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end
    
    % get figure handles
    hFig = bst_figures('GetCurrentFigure', '3D');
    SubjectFile = getappdata(hFig, 'SubjectFile');
    if ~isempty(SubjectFile)
        sSubject = bst_get('Subject', SubjectFile);
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end

    % get the protocol info and the channel file info
    ProtocolInfo = bst_get('ProtocolInfo');
    CoordDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(MriFile));
    CoordFile  = bst_fullfile(CoordDir, 'channel_seeg.mat');
    
    
    % if channel file exists for the subject
    if isfile(CoordFile)
        % load the data
        ChannelAnatomicalMat = load(CoordFile);
        
        % display the MRI viewer
        hFigMri = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName);
        
        isProgress = bst_progress('isVisible');
        if ~isProgress
            bst_progress('start', 'Loading sEEG contacts', 'Loading sEEG contact');
        end

        % reset the list for fresh data
        ctrl.jListModel.removeAllElements();
        
        % traverse through each data and update the diplay figures
        for i=1:length(ChannelAnatomicalMat.Channel)
            bst_progress('text', sprintf('Loading sEEG contact [%d/%d]', i, length(ChannelAnatomicalMat.Channel)));
            
            % ----- STEP-1: update the Panel with laoded data -----
            sMri = bst_memory('LoadMri', MriFile);
            str = string(ChannelAnatomicalMat.Channel(i).Name);
            label_name = regexp(str, '[A-Za-z'']', 'match'); % A-Z, a-z, '
            curContactNum = regexp(str, '\d*', 'match');
            
            ctrl.jTextLabel.setText(strjoin(label_name, ''));
            ctrl.jTextNcontacts.setText(curContactNum);

            ctrl.jListModel.addElement(sprintf('%s   %3.2f   %3.2f   %3.2f', strjoin(label_name, '') + curContactNum, ChannelAnatomicalMat.Channel(i).Loc));
            plotLocWorld = ChannelAnatomicalMat.Channel(i).Loc ./ 1000;
            plotLocScs = cs_convert(sMri, 'world', 'scs', plotLocWorld); 

            % ----- STEP-2: update the 3D points on the surface with loaded data -----
            hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
            line(plotLocScs(1), plotLocScs(2), plotLocScs(3), ...
                 'MarkerFaceColor', [1 1 0], ...
                 'MarkerEdgeColor', [1 1 0], ...
                 'Marker',          'o',  ...
                 'MarkerSize',      10, ...
                 'LineWidth',       2, ...
                 'Parent',          hAxes, ...
                 'Tag',             'ptCoordinates');

            text(plotLocScs(1), plotLocScs(2), plotLocScs(3), ...
                '         ' + string(strjoin(label_name, '') + curContactNum), ...
                'HorizontalAlignment','center', ...
                'FontSize', 10, ...
                'Color',  [1 1 0], ...
                'Parent', hAxes, ...
                'Tag', 'txtCoordinates');
            
            % find the index of the current label in the IntraELectrode field
            idx = find(ismember({ChannelAnatomicalMat.IntraElectrodes.Name}, label_name));
            ctrl.jTextContactSpacing.setText(string(ChannelAnatomicalMat.IntraElectrodes(idx).ContactSpacing * 1000));
            totalNumContacts = ChannelAnatomicalMat.IntraElectrodes(idx).ContactNumber;
            
            % update the global variable for reference line only for tip
            % and entry
            if round(str2double(curContactNum)) == 1
                refLinePlotLoc = [refLinePlotLoc, plotLocScs'];
            end
            if round(str2double(curContactNum)) == ChannelAnatomicalMat.IntraElectrodes(idx).ContactNumber
                refLinePlotLoc = [refLinePlotLoc, plotLocScs'];
                DrawRefElectrode(1);
            end

            % ----- STEP-3: update the 3D points on the surface with loaded data -----
            Handles = bst_figures('GetFigureHandles', hFigMri);
            
            % Select the required point
            plotLocMri = cs_convert(sMri, 'scs', 'mri', plotLocScs);
            Handles.LocEEG(1,:) = plotLocMri .* 1000;
            Channels(1).Name = string(ctrl.jTextLabel.getText()) + string(ctrl.jTextNcontacts.getText());
            Handles.hPointEEG(1,:) = figure_mri('PlotPoint', sMri, Handles, Handles.LocEEG(1,:), [1 1 0], 5, Channels(1).Name);
            Handles.hTextEEG(1,:)  = figure_mri('PlotText', sMri, Handles, Handles.LocEEG(1,:), [1 1 0], Channels(1).Name, Channels(1).Name);
        
            curContactNum = round(str2double(ctrl.jTextNcontacts.getText()));
            if curContactNum==2
                ctrl.jTextNcontacts.setText('0');
            end
            % ctrl.jTextNcontacts.setText(sprintf("%d", curContactNum-1));
            % 
            % if curContactNum==1
            %     % disable user interactivity to plot points 
            %     SetSelectionState(0);
            % end
        
            figure_mri('UpdateVisibleLandmarks', sMri, Handles);
        end
        
        % disable user interactivity to plot points
        SetSelectionState(0);
    
    % if file does not exist for the subject just start fresh 
    else
        ChannelAnatomicalMat = db_template('channelmat'); 
        
        % saving the reference electrode data (FOR FUTURE USE - UNDER
        % CONSTRUCTION)
        ChannelAnatomicalMat.RefElectrodeChannel = [];
        
        SetNewElectrode();
    end
    
    % update the panel
    UpdatePanel();

    bst_progress('stop');
end

%% ===== UPDATE CALLBACK =====
function UpdatePanel() %#ok<DEFNU>
    % Global variables
    global ChannelAnatomicalMat;
    global totalNumContacts;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end

    % Get current 3D figure
    hFig = bst_figures('GetCurrentFigure', '3D');

    % If a figure is available: get if a point is selected 
    if ~isempty(hFig) && ishandle(hFig)
        CoordinatesSelector = getappdata(hFig, 'CoordinatesSelector');
    else
        CoordinatesSelector = [];
    end
    
    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.MRI)
        % get hte panel variables
        curContactNum = round(str2double(ctrl.jTextNcontacts.getText()));
        label_name = string(ctrl.jTextLabel.getText());

        % update the list in panel
        ctrl.jListModel.addElement(sprintf('%s   %3.2f   %3.2f   %3.2f', label_name + num2str(curContactNum), CoordinatesSelector.World .* 1000));
        
        % add new contact data as a channel
        CoordData = db_template('channeldesc');
        CoordData.Name = char(label_name + num2str(curContactNum));
        CoordData.Comment = 'World Coordinate System';
        CoordData.Type = 'EEG';
        CoordData.Loc = CoordinatesSelector.World' .* 1000;
        CoordData.Weight = 1;
        
        % add the contact to the main channel structure
        ChannelAnatomicalMat.Channel = [ChannelAnatomicalMat.Channel, CoordData];
        ChannelAnatomicalMat.HeadPoints.Loc(:,end+1) = CoordData.Loc;
        ChannelAnatomicalMat.HeadPoints.Label = [ChannelAnatomicalMat.HeadPoints.Label, {CoordData.Name}];
        ChannelAnatomicalMat.HeadPoints.Type = [ChannelAnatomicalMat.HeadPoints.Type, {'EXTRA'}];
        
        % if IntraElectrode field is emeoty then add the electrode details
        % above to it
        if isempty(ChannelAnatomicalMat.IntraElectrodes)
            IntraElecData = db_template('intraelectrode');
            IntraElecData.Name = char(ctrl.jTextLabel.getText());
            IntraElecData.Type = 'SEEG';
            IntraElecData.Color = [0 0.8 0];
            IntraElecData.ContactNumber = totalNumContacts;
            IntraElecData.ContactSpacing = str2double(ctrl.jTextContactSpacing.getText()) / 1000;
            IntraElecData.Visible = 1;

            ChannelAnatomicalMat.IntraElectrodes = [ChannelAnatomicalMat.IntraElectrodes, IntraElecData];
        % if electrode already present then skip updating IntraElectrode
        % field else append the new electrode data to it
        else
            isPresent = 0;
            for i=1:length(ChannelAnatomicalMat.IntraElectrodes)
                if strcmpi(ChannelAnatomicalMat.IntraElectrodes(i).Name, char(ctrl.jTextLabel.getText()))
                    isPresent = 1;
                end
            end

            if ~isPresent
                IntraElecData = db_template('intraelectrode');
                IntraElecData.Name = char(ctrl.jTextLabel.getText());
                IntraElecData.Type = 'SEEG';
                IntraElecData.Color = [0 0.8 0];
                IntraElecData.ContactNumber = totalNumContacts;
                IntraElecData.ContactSpacing = str2double(ctrl.jTextContactSpacing.getText()) / 1000;
                IntraElecData.Visible = 1;
    
                ChannelAnatomicalMat.IntraElectrodes = [ChannelAnatomicalMat.IntraElectrodes, IntraElecData];
            end
        end
    end

    % Set this list to be dispalyed on the panel with the new values
    ctrl.jListElec.setModel(ctrl.jListModel);
    ctrl.jListElec.repaint();
    drawnow;
end

%% ===== DRAW REFERENCE ELECTRODE =====
% this function renders a line between the 1st two initial points of the electrode
% - the tip point and the entry point - that gives the orientation of the electrode
% along with the contacts placed based on the contact spacing specified which 
% serve as a guideline for the user in order to select the actual contacts
function DrawRefElectrode(isLoading) %#ok<DEFNU>
    % global variables
    global refLinePlotLoc;
    
    % Get axes handle
    hFig = bst_figures('GetFiguresByType', '3DViz');
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');

    % plot the reference line between tip and entry
    line(refLinePlotLoc(1,end-1:end), refLinePlotLoc(2,end-1:end), refLinePlotLoc(3,end-1:end), ...
         'Color', [1 1 0], ...
         'LineWidth',       2, ...
         'Parent', hAxes, ...
         'Tag', 'lineCoordinates');
    
    % plot the reference contacts based on the contact spacing specified
    % by the user
    ReferenceContacts(isLoading);

    % enable plotting of contacts by user
    SetSelectionState(1);
end

%% ===== REFERENCE CONTACTS FOR AN ELECTRODE =====
% plot the reference contacts on the reference line to act as a guideline
function ReferenceContacts(isLoading) %#ok<DEFNU>
    global ChannelAnatomicalMat;
    global totalNumContacts;
    global refLinePlotLoc;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end
    
    % get the contact spacing specified
    contact_spacing = str2double(ctrl.jTextContactSpacing.getText());
    
    % get the handles
    hFig = bst_figures('GetFiguresByType', '3DViz');
    SubjectFile = getappdata(hFig, 'SubjectFile');
    if ~isempty(SubjectFile)
        sSubject = bst_get('Subject', SubjectFile);
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    sMri = bst_memory('LoadMri', MriFile);
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');

    % Get electrode orientation using the tip and entry
    elecTipMri = cs_convert(sMri, 'scs', 'mri', refLinePlotLoc(:, end-1));
    entryMri = cs_convert(sMri, 'scs', 'mri', refLinePlotLoc(:, end));
    orient = entryMri - elecTipMri;
    orient = orient ./ sqrt(sum(orient .^ 2));
    
    % get the current electrode label
    label_name = string(ctrl.jTextLabel.getText());
    
    % plot the reference contacts using the orientation calculated above
    for i = 1:totalNumContacts
        % Compute the default position of the contact
        posMri = elecTipMri + (i - 1) * (contact_spacing/1000) * orient;
        pos = cs_convert(sMri, 'mri', 'scs', posMri);
        
        % plotting a contact
        line(pos(1), pos(2), pos(3), ...
             'MarkerFaceColor', [1 0 1], ...
             'MarkerEdgeColor', [1 0 1], ...
             'Marker',          'o',  ...
             'MarkerSize',      10, ...
             'LineWidth',       2, ...
             'Parent',          hAxes, ...
             'Tag',             'ptCoordinatesRef');
        
        % this is used only while saved session data is being loaded
        if ~isLoading
            % add reference data to the structure
            refWorld = cs_convert(sMri, 'scs', 'world', pos);
    
            CoordData = db_template('channeldesc');
            CoordData.Name = char(label_name + num2str(i));
            CoordData.Comment = 'Reference values (world)';
            CoordData.Type = 'SEEG';
            CoordData.Loc = refWorld' .* 1000;
            CoordData.Weight = 1;
    
            ChannelAnatomicalMat.RefElectrodeChannel = [ChannelAnatomicalMat.RefElectrodeChannel, CoordData];
        end
    end
    
    % keep the DrawRef button disabled as condition is still not met fopr
    % setting it active
    ctrl.jButtonDrawRefElectrode.setEnabled(0);
    
    % update the panel for changes
    UpdatePanel();
end

%% ===== SET CROSSHAIR POSITION ON MRI =====
% on clicking on the coordinates on the panel, the crosshair on the MRI
% viewer gets updated to show the corresponding location
function SetLocationMri(iIndex) %#ok<DEFNU>
    % global variables
    global ChannelAnatomicalMat;

    % Get the handles
    hFig = bst_figures('GetFiguresByType', {'MriViewer'});
    if isempty(hFig)
        return
    end    
    SubjectFile = getappdata(hFig, 'SubjectFile');
    if ~isempty(SubjectFile)
        sSubject = bst_get('Subject', SubjectFile);
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    sMri = bst_memory('LoadMri', MriFile);

    % Select the required point and adjust the coordinate space
    plotLocWorld = ChannelAnatomicalMat.Channel(iIndex).Loc ./ 1000;
    plotLocScs = cs_convert(sMri, 'world', 'scs', plotLocWorld); 
    plotLocMri = cs_convert(sMri, 'scs', 'mri', plotLocScs);
    
    % update the cross-hair position on the MRI
    figure_mri('SetLocation', 'mri', hFig, [], plotLocMri);    
end

%% ===== FOCUS CHANGED ======
function FocusChangedCallback(isFocused) %#ok<DEFNU>
    if ~isFocused
        % remove all the contacts
        RemoveAllContacts();
    end
end

%% ===== CURRENT FIGURE CHANGED =====
function CurrentFigureChanged_Callback() %#ok<DEFNU>
    % update the panel
    UpdatePanel();
end

%% ===== KEYBOARD CALLBACK =====
% handle the keyboard callbacks for the 3D figure
function KeyPress_Callback(hFig, keyEvent) %#ok<DEFNU>
    switch (keyEvent.Key)
        % LABEL NEW ELECTRODE
        case {'l'}
            % Set new electrode
            SetNewElectrode();
        
        % DISABLE CONTACT LABELING
        case {'escape'}
            % exit the selection state to stop plotting contacts
            SetSelectionState(0);
        
        % RESUME CONTACT LABELING
        case {'r'}
            % resume labelling
            ResumeLabeling();           
            
        otherwise
            return;
    end
end

%% ===== SET NEW ELECTRODE FOR LABELING =====
% starts creation of a new electrode
function SetNewElectrode(varargin) %#ok<DEFNU>
    % global variables
    global clickOnSurfaceCount;
    global totalNumContacts;
    
    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return;
    end
    
    % reset click on surface count
    clickOnSurfaceCount = 0;

    % label contacts
    res = java_dialog('input', {'Number of contacts', 'Label Name', 'Contact Spacing (mm)'}, ...
                        'Enter electrode details', ...
                        [], ...
                        {num2str(10), 'A', num2str(2)});
    if isempty(res)
        return;
    end

    % enable coordinate selection on surface
    SetSelectionState(1);

    % set the parameters for the electrode
    ctrl.jTextNcontacts.setText(res{1});
    ctrl.jTextLabel.setText(res{2});
    ctrl.jTextContactSpacing.setText(res{3});

    % keep the DrawRef button disabled as condition is still not met fopr
    % setting it active
    ctrl.jButtonDrawRefElectrode.setEnabled(0);
    
    % get the total number of contacts for the electrodes
    totalNumContacts = round(str2double(ctrl.jTextNcontacts.getText()));

    % set the current contact to be plotted as the tip
    ctrl.jTextNcontacts.setText('1');
    
    % ask user to set the tip and entry
    java_dialog('msgbox', '1st two points for electrode ''' + string(ctrl.jTextLabel.getText()) + [''' should be marked as: ' ...
        '1. Tip ' ...
        '2. Skull entry'], 'Set electrode tip and skull entry');
end

%% ===== RESUME ELECTRODE LABELING =====
% resume from the last left session/contact
function ResumeLabeling(varargin) %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return;
    end
    
    % get the panel variables
    curContactNum = round(str2double(ctrl.jTextNcontacts.getText()));
    label_name = string(ctrl.jTextLabel.getText());
    
    % if the last electrode labelling was completed then ask user if they 
    % want to start from a new electrode
    if curContactNum==0
        isNewLabel = java_dialog('confirm', 'Last electrode label was completed. Do you want to start labeling a new electrode ?', 'Resume labeling');
        if isNewLabel
            % Set new electrode
            SetNewElectrode();
        end

    % if the last electrode labelling was abrubtly ended then ask
    % user to resume labelling from there else start from setting 
    % a new electrode
    else
        isResumeLabeling = java_dialog('confirm', [...
        '<HTML><B>Do you want to resume labelling?</B><BR><BR>' ...
        'Selecting "Yes" will resume from label ' + label_name + num2str(curContactNum)], ...
        'Resume labeling'); 
        if isResumeLabeling
            SetSelectionState(1);
        else
            java_dialog('msgbox', 'Press ''L'' to start labelling a new electrode', 'Resume labeling');
            SetSelectionState(0);
        end
    end
end

%% ===== POINT SELECTION : start/stop =====
% allow manual selection of a surface point : start(1), or stop(0)
function SetSelectionState(isSelected) %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end
    % Get list of all figures
    hFigures = bst_figures('GetAllFigures');
    if isempty(hFigures)
        return
    end
    % Start selection
    if isSelected      
        % Set 3DViz figures in 'SelectingContactLabelIeeg' mode
        for hFig = hFigures
            % Keep only figures with surfaces
            TessInfo = getappdata(hFig, 'Surface');
            if ~isempty(TessInfo)
                setappdata(hFig, 'isSelectingContactLabelIeeg', 1);
                set(hFig, 'Pointer', 'cross');
            end
        end
    % Stop selection
    else
        % Exit 3DViz figures from SelectingCorticalSpot mode
        for hFig = hFigures
            set(hFig, 'Pointer', 'arrow');
            setappdata(hFig, 'isSelectingContactLabelIeeg', 0);      
        end
    end
end

%% ===== SELECT POINT =====
% Usage : SelectPoint(hFig) : Point location = user click in figure hFig
function vi = SelectPoint(hFig, AcceptMri) %#ok<DEFNU>
    % global variables
    global refLinePlotLoc;
    global totalNumContacts;

    % parse arguments
    if (nargin < 2) || isempty(AcceptMri)
        AcceptMri = 1;
    end

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return;
    end

    % Get axes handle
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Find the closest surface point that was selected
    [TessInfo, iTess, pout, vout, vi, hPatch] = ClickPointInSurface(hFig);
    if isempty(TessInfo)
        return
    end
    Value = [];
    
    % Get real location of the selected point (in SCS coord, millimeters)
    switch (TessInfo(iTess).Name)
        case 'Anatomy'
            % If MRI is not accepted
            if ~AcceptMri
                vi = [];
                return
            end
            scsLoc  = pout';
            plotLoc = scsLoc;
            iVertex = [];
            
            % Get MRI
            sMri = bst_memory('GetMri', TessInfo(iTess).SurfaceFile);
            
        case {'Scalp', 'InnerSkull', 'OuterSkull', 'Cortex', 'Other', 'FEM'}
            sSurf = bst_memory('GetSurface', TessInfo(iTess).SurfaceFile);
            scsLoc = sSurf.Vertices(vi,:);
            % disp(sSurf);
            plotLoc = vout;
            iVertex = vi;
            % Get value
            if ~isempty(TessInfo(iTess).Data)
                if ~isempty(TessInfo(iTess).DataSource.GridAtlas)
                    Value = [];
                elseif isempty(TessInfo(iTess).DataSource.Atlas)
                    Value = TessInfo(iTess).Data(vi);
                else
                    % Look for the selected point in one of the scouts
                    iRow = panel_scout('GetScoutForVertex', TessInfo(iTess).DataSource.Atlas, vi);
                    % Return value
                    Value = TessInfo(iTess).Data(iRow(1));
                end
            end
            % Get subject
            SubjectFile = getappdata(hFig, 'SubjectFile');
            if ~isempty(SubjectFile)
                sSubject = bst_get('Subject', SubjectFile);
                % == GET MRI ==
                % If subject has a MRI defined
                if ~isempty(sSubject.iAnatomy)
                    % Load MRI
                    MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                    sMri = bst_memory('LoadMri', MriFile);
                else
                    sMri = [];
                end
            else
                sMri = [];
            end
        otherwise
            scsLoc = vout;
            plotLoc = scsLoc;
            iVertex = [];
            sMri = [];
    end
    
    % ===== CONVERT TO ALL COORDINATES SYSTEMS =====
    % Save selected point
    CoordinatesSelector.SCS     = plotLoc;
    CoordinatesSelector.MRI     = cs_convert(sMri, 'scs', 'mri', plotLoc);
    CoordinatesSelector.MNI     = cs_convert(sMri, 'scs', 'mni', plotLoc);
    CoordinatesSelector.World   = cs_convert(sMri, 'scs', 'world', plotLoc);
    CoordinatesSelector.iVertex = iVertex;
    CoordinatesSelector.Value   = Value;
    CoordinatesSelector.hPatch  = hPatch;
    setappdata(hFig, 'CoordinatesSelector', CoordinatesSelector);
    
    % ===== CONTACT MARKER =====
    % Mark new contact 
    line(plotLoc(1), plotLoc(2), plotLoc(3), ...
         'MarkerFaceColor', [1 1 0], ...
         'MarkerEdgeColor', [1 1 0], ...
         'Marker',          'o',  ...
         'MarkerSize',      10, ...
         'LineWidth',       2, ...
         'Parent',          hAxes, ...
         'Tag',             'ptCoordinates');
    
    % Add label to the contact
    text(plotLoc(1), plotLoc(2), plotLoc(3), ...
        '         ' + string(ctrl.jTextLabel.getText()) + string(ctrl.jTextNcontacts.getText()), ...
        'HorizontalAlignment','center', ...
        'FontSize', 10, ...
        'Color',  [1 1 0], ...
        'Parent', hAxes, ...
        'Tag', 'txtCoordinates');
    
    % add the reference line points to an array to keep track of tip and
    % entry
    if round(str2double(ctrl.jTextNcontacts.getText())) == 1 ...
       || round(str2double(ctrl.jTextNcontacts.getText())) == totalNumContacts
        refLinePlotLoc = [refLinePlotLoc, plotLoc'];
    end
    
    % Update the panel
    UpdatePanel();

    % Update the MRI viewer
    ViewInMriViewer();
end

%% ===== POINT SELECTION: Surface detection =====
% click a point on the surface to generate a contact
function [TessInfo, iTess, pout, vout, vi, hPatch] = ClickPointInSurface(hFig, SurfacesType) %#ok<DEFNU>
    % set global variable to track the vetices in around a selected point on surface
    global VertexList;
    VertexList = [];
    global clickOnSurfaceCount;
    
    % Parse inputs
    if (nargin < 2)
        SurfacesType = [];
    end
    iTess = [];
    pout = {};
    vout = {};
    vi = {};
    hPatch = [];
    
    % === GET SURFACES INFORMATION ===
    % Get axes handle
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Get camera position
    CameraPosition = get(hAxes, 'CameraPosition');
    % Get all the surfaces in the figure
    TessInfo = getappdata(hFig, 'Surface');
    
    [iTess, TessInfo, hFig, sSurf] = panel_surface('GetSelectedSurface', hFig);

    if isempty(TessInfo)
        return
    end

    % === CHECK SURFACE TYPE ===
    % Keep only surfaces that are of the required type
    if ~isempty(SurfacesType)
        iAcceptableTess = find(strcmpi({TessInfo.Name}, SurfacesType));
    else
        iAcceptableTess = 1:length(TessInfo);
    end
    
    % ===== GET SELECTION ON THE CLOSEST SURFACE =====
    % Get the closest point for all the surfaces and patches
    hPatch = [TessInfo(iAcceptableTess).hPatch];

    hPatch = hPatch(ishandle(hPatch));
    patchDist = zeros(1,length(hPatch));
    for i = 1:length(hPatch)
        [pout{i}, vout{i}, vi{i}, facevout{i}, fi{i}] = select3d(hPatch(i));
        
        if ~isempty(pout{i})
            patchDist(i) = norm(pout{i}' - CameraPosition);
            clickOnSurfaceCount = clickOnSurfaceCount + 1;
            
            % avoid centroid calculation for tip and skull entry
            if clickOnSurfaceCount ~= 1 && clickOnSurfaceCount ~= 2
                FindCentroid(sSurf, find(sSurf.VertConn(vi{i},:)), 1, 6);
                vout{i} = mean(sSurf.Vertices(VertexList(:), :));
                VertexList = [];
            end
        else
            patchDist(i) = Inf;
        end
    end

    if all(isinf(patchDist))
        TessInfo = [];
        pout = [];
        vout = [];
        vi = [];
        return
    end
    % Find closest surface from the camera
    [minDist, iClosestPatch] = min(patchDist);
    % Keep only the point from the closest surface
    hPatch = hPatch(iClosestPatch);
    pout   = pout{iClosestPatch};
    if clickOnSurfaceCount ~= 1 && clickOnSurfaceCount ~= 2
        vout   = vout{iClosestPatch};
    else
        vout   = vout{iClosestPatch}';
    end
    vi     = vi{iClosestPatch};
    
    % Find to which surface this tesselation belongs
    for i = 1:length(TessInfo)
        if any(TessInfo(i).hPatch == hPatch);
            iTess = i;
            break;
        end
    end
end

%% ===== FIND CENTROID OF A CONTACT =====
% finds the centroid of the selected contact blob from the isosurface using
% flood-fill alogrithm
function FindCentroid(sSurf, listCoord, cnt, cntThresh) %#ok<DEFNU>
    global VertexList;

    if cnt == cntThresh
        return;
    else
        for i=1:length(listCoord)
            if ~any(VertexList(:) == listCoord(i))
                VertexList = [VertexList, listCoord(i)];
                listCoord1 = find(sSurf.VertConn(listCoord(i),:));
                FindCentroid(sSurf, listCoord1, cnt, cntThresh);
                cnt = cnt + 1;
            end
        end
    end
end

%% ===== SHOW/HIDE REFERENCE ELECTRODES =====
function ShowHideReference(varargin) %#ok<DEFNU>
    global isRefVisible;

    refCoord = findobj(0, 'Tag', 'ptCoordinatesRef');
    lineCoord = findobj(0, 'Tag', 'lineCoordinates');
    
    if isRefVisible
        set(refCoord, 'Visible', 'off');
        set(lineCoord, 'Visible', 'off');
        isRefVisible = 0;
    else
        set(refCoord, 'Visible', 'on');
        set(lineCoord, 'Visible', 'on');
        isRefVisible = 1;
    end
end

%% ===== REMOVE AT A LOCATION (DELETE SPECIFIC CONTACT) =====
% THIS FUNCTION IS UNDER CONSTRUCTION
% function RemoveContactAtLocation(Loc) %#ok<DEFNU> 
%     global ChannelAnatomicalMat;
% 
%     ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
%     % Find all selected points
%     hCoord = findobj(0, 'Tag', 'ptCoordinates'); 
%     % Remove coordinates from the figures
%     for i = 1:length(hCoord)
%         hFig = get(get(hCoord(i), 'Parent'), 'Parent');
%         if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
%             rmappdata(hFig, 'CoordinatesSelector');
%         end
%     end
%     % Delete selected points
%     if ~isempty(hCoord)
%         delete(hCoord(length(hCoord)-Loc+1));
%         ctrl.jListModel.remove(Loc-1);
% 
%         % delete from mat
%         ChannelAnatomicalMat.Channel(Loc) = [];
% 
%         % make sure the Channel sturture field is cleared when no contacts
%         % are marked
%         if length(hCoord) == 1
%             ChannelAnatomicalMat.Channel = [];
%         end
% 
%         ChannelAnatomicalMat.HeadPoints.Loc(:, Loc) = [];
%         ChannelAnatomicalMat.HeadPoints.Label(Loc) = [];
%         ChannelAnatomicalMat.HeadPoints.Type(Loc) = [];
%     end
% 
%     % Find all selected points text
%     hText = findobj(0, 'Tag', 'txtCoordinates'); 
%     % Remove coordinates from the figures
%     for i = 1:length(hText)
%         hFig = get(get(hText(i), 'Parent'), 'Parent');
%         if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
%             rmappdata(hFig, 'CoordinatesSelector');
%         end
%     end
%     % Delete selected points text
%     if ~isempty(hText)
%         delete(hText(length(hText)-Loc+1));
%     end
% 
%     % Find all selected points Coordinates1 in MRI space
%     mriCoord1 = findobj(0, 'Tag', 'PointMarker1'); 
%     % Remove coordinates from the figures
%     for i = 1:length(mriCoord1)
%         hFig = get(get(mriCoord1(i), 'Parent'), 'Parent');
%         if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
%             rmappdata(hFig, 'CoordinatesSelector');
%         end
%     end
%     % Delete selected points in MRI space
%     if ~isempty(hCoord)
%         delete(mriCoord1(length(hCoord)-Loc+1));
%     end
% 
%     % Find all selected points Text1 in MRI space
%     mriText1 = findobj(0, 'Tag', 'TextMarker1'); 
%     % Remove coordinates from the figures
%     for i = 1:length(mriText1)
%         hFig = get(get(mriText1(i), 'Parent'), 'Parent');
%         if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
%             rmappdata(hFig, 'CoordinatesSelector');
%         end
%     end
%     % Delete selected points text in MRI space
%     if ~isempty(hCoord)
%         delete(mriText1(length(hCoord)-Loc+1));
%     end
% 
%     % Find all selected points Coordinates2 in MRI space
%     mriCoord2 = findobj(0, 'Tag', 'PointMarker2'); 
%     % Remove coordinates from the figures
%     for i = 1:length(mriCoord2)
%         hFig = get(get(mriCoord2(i), 'Parent'), 'Parent');
%         if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
%             rmappdata(hFig, 'CoordinatesSelector');
%         end
%     end
%     % Delete selected points in MRI space
%     if ~isempty(hCoord)
%         delete(mriCoord2(length(hCoord)-Loc+1));
%     end
% 
%     % Find all selected points Text2 in MRI space
%     mriText2 = findobj(0, 'Tag', 'TextMarker2'); 
%     % Remove coordinates from the figures
%     for i = 1:length(mriText2)
%         hFig = get(get(mriText2(i), 'Parent'), 'Parent');
%         if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
%             rmappdata(hFig, 'CoordinatesSelector');
%         end
%     end
%     % Delete selected points text in MRI space
%     if ~isempty(hCoord)
%         delete(mriText2(length(hCoord)-Loc+1));
%     end
% 
%     % Find all selected points Coordinates3 in MRI space
%     mriCoord3 = findobj(0, 'Tag', 'PointMarker3'); 
%     % Remove coordinates from the figures
%     for i = 1:length(mriCoord3)
%         hFig = get(get(mriCoord3(i), 'Parent'), 'Parent');
%         if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
%             rmappdata(hFig, 'CoordinatesSelector');
%         end
%     end
%     % Delete selected points in MRI space
%     if ~isempty(hCoord)
%         delete(mriCoord3(length(hCoord)-Loc+1));
%     end
% 
%     % Find all selected points Text3 in MRI space
%     mriText3 = findobj(0, 'Tag', 'TextMarker3'); 
%     % Remove coordinates from the figures
%     for i = 1:length(mriText3)
%         hFig = get(get(mriText3(i), 'Parent'), 'Parent');
%         if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
%             rmappdata(hFig, 'CoordinatesSelector');
%         end
%     end
%     % Delete selected points text in MRI space
%     if ~isempty(hCoord)
%         delete(mriText3(length(hCoord)-Loc+1));
%     end
% 
%     % Update displayed coordinates
%     UpdatePanel();
% end

%% ===== REMOVE LAST CONTACT =====
% remove last plotted contact
function RemoveLastContact(varargin) %#ok<DEFNU>
    % global variables
    global ChannelAnatomicalMat;
    global clickOnSurfaceCount;
    global totalNumContacts;
    global refLinePlotLoc;
    
    % get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end

    % Find all selected contacts
    hCoord = findobj(0, 'Tag', 'ptCoordinates'); 
    % Remove coordinates from the figures
    for i = 1:length(hCoord)
        hFig = get(get(hCoord(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end

    % Delete selected contact
    if ~ctrl.jListModel.isEmpty()
        lastElement = ctrl.jListModel.lastElement();
        label_name = regexp(lastElement, '[A-Za-z'']', 'match');
        curContactNumStr = regexp(lastElement, '\d*', 'match');
        curContactNum = round(str2double(curContactNumStr(1)));
    else
        return;
    end

    if ~isempty(hCoord)
        % just delete the last contact plotted
        delete(hCoord(1));
        % remove the last element from the list on panel
        ctrl.jListModel.remove(length(hCoord)-1);
        
        % delete the last channel data
        ChannelAnatomicalMat.Channel(length(hCoord)) = [];
        ChannelAnatomicalMat.HeadPoints.Loc(:, length(hCoord)) = [];
        ChannelAnatomicalMat.HeadPoints.Label(length(hCoord)) = [];
        ChannelAnatomicalMat.HeadPoints.Type(length(hCoord)) = [];

        % make sure the channel sturture field is cleared when no contacts
        % are marked
        if length(hCoord) == 1
            ChannelAnatomicalMat.Channel = [];
        end
    end

    % Find all selected contact labels
    hText = findobj(0, 'Tag', 'txtCoordinates'); 
    % Remove labels from the figures
    for i = 1:length(hText)
        hFig = get(get(hText(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete last contact label
    if ~isempty(hText)
        delete(hText(1));
    end
    
    % Find all selected contacts in MRI space for saggital view
    mriCoord1 = findobj(0, 'Tag', 'PointMarker1'); 
    % Remove contacts from the figures
    for i = 1:length(mriCoord1)
        hFig = get(get(mriCoord1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete last contact in MRI space for saggital view
    if ~isempty(hCoord)
        delete(mriCoord1(1));
    end

    % Find all selected contact labels in MRI space for saggital view
    mriText1 = findobj(0, 'Tag', 'TextMarker1'); 
    % Remove contact labels from the figures
    for i = 1:length(mriText1)
        hFig = get(get(mriText1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete last contact label in MRI space for saggital view
    if ~isempty(hCoord)
        delete(mriText1(1));
    end
    
    % Find all selected contacts in MRI space for coronal view
    mriCoord2 = findobj(0, 'Tag', 'PointMarker2'); 
    % Remove contacts from the figures
    for i = 1:length(mriCoord2)
        hFig = get(get(mriCoord2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete last contact in MRI space for coronal view
    if ~isempty(hCoord)
        delete(mriCoord2(1));
    end

    % Find all selected contact labels in MRI space for coronal view
    mriText2 = findobj(0, 'Tag', 'TextMarker2'); 
    % Remove contact labels from the figures
    for i = 1:length(mriText2)
        hFig = get(get(mriText2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete last contact label in MRI space for coronal view
    if ~isempty(hCoord)
        delete(mriText2(1));
    end

    % Find all selected contacts in MRI space for axial view
    mriCoord3 = findobj(0, 'Tag', 'PointMarker3'); 
    % Remove contacts from the figures
    for i = 1:length(mriCoord3)
        hFig = get(get(mriCoord3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete last contact in MRI space for axial view
    if ~isempty(hCoord)
        delete(mriCoord3(1));
    end

    % Find all selected contact labels in MRI space for axial view
    mriText3 = findobj(0, 'Tag', 'TextMarker3'); 
    % Remove contact labels from the figures
    for i = 1:length(mriText3)
        hFig = get(get(mriText3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete last contact label in MRI space for axial view
    if ~isempty(hCoord)
        delete(mriText3(1));
    end
    
    % used to update the IntraElectrode field int the channel data
    % find the index of the current label in the IntraELectrode field
    idx = find(ismember({ChannelAnatomicalMat.IntraElectrodes.Name}, label_name));
    
    % this section handles the deletion of contact if the current contact 
    % to be deleted is the entry of the electrode
    if curContactNum == ChannelAnatomicalMat.IntraElectrodes(idx).ContactNumber 
        % Find all reference lines
        lineCoord = findobj(0, 'Tag', 'lineCoordinates'); 
        % Remove referene line
        for i = 1:length(lineCoord)
            hFig = get(get(lineCoord(i), 'Parent'), 'Parent');
            if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
                rmappdata(hFig, 'CoordinatesSelector');
            end
        end
        % Delete reference line
        if ~isempty(lineCoord)
            delete(lineCoord(1));
        end
        
        % Find all reference contacts
        hCoordRef = findobj(0, 'Tag', 'ptCoordinatesRef'); 
        % Remove reference contacts from the figures
        for i = 1:length(hCoordRef)
            hFig = get(get(hCoordRef(i), 'Parent'), 'Parent');
            if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
                rmappdata(hFig, 'CoordinatesSelector');
            end
        end
        % Delete reference contacts
        if ~isempty(hCoordRef)
            delete(hCoordRef(1:ChannelAnatomicalMat.IntraElectrodes(idx).ContactNumber));
        end
        
        % update the channel structure
        refLinePlotLoc(:, end) = [];
        totalNumContacts = ChannelAnatomicalMat.IntraElectrodes(idx).ContactNumber;
    end
    
    % this section handles the deletion of contact if the current contact 
    % to be deleted is the tip of the electrode
    if curContactNum == 1
        % update the channel structure
        refLinePlotLoc(:, end) = [];
        ChannelAnatomicalMat.IntraElectrodes(idx) = [];
    end
    
    % uddate the panel variables
    ctrl.jTextNcontacts.setText(sprintf("%d", curContactNum));
    ctrl.jTextLabel.setText(label_name);

    clickOnSurfaceCount = clickOnSurfaceCount - 1;
    
    % update the panel
    UpdatePanel();
end

%% ===== REMOVE ALL CONTACTS =====
% remove all the contacts
function RemoveAllContacts(varargin) %#ok<DEFNU>
    % global variables
    global ChannelAnatomicalMat;
    global clickPointInSurface;
    global refLinePlotLoc;

    % Unselect selection button 
    SetSelectionState(0);
    
    % get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return;
    end

    % Find all the user plotted contacts
    hCoord = findobj(0, 'Tag', 'ptCoordinates'); 
    % Remove coordinates from the figures
    for i = 1:length(hCoord)
        hFig = get(get(hCoord(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    
    if ~isempty(hCoord)
        % delete the contacts
        delete(hCoord);
        % delete the list
        ctrl.jListModel.removeAllElements();
        % reset the current contact location
        ctrl.jTextNcontacts.setText(sprintf("%d", 0));

        % reset all the channel file data
        ChannelAnatomicalMat.Channel = [];
        ChannelAnatomicalMat.HeadPoints.Loc = [];
        ChannelAnatomicalMat.HeadPoints.Label = [];
        ChannelAnatomicalMat.HeadPoints.Type = [];
    end

    % Find all selected contacts labels
    hText = findobj(0, 'Tag', 'txtCoordinates'); 
    % Remove labels from the figures
    for i = 1:length(hText)
        hFig = get(get(hText(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end

    if ~isempty(hText)
        % delete the labels
        delete(hText);
    end
    
    % Find all selected contacts in MRI space for saggital view
    mriCoord1 = findobj(0, 'Tag', 'PointMarker1'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord1)
        hFig = get(get(mriCoord1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete contacts in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            % delete point in saggital view
            delete(mriCoord1(i));
        end
    end

    % Find all selected contact labels in MRI space for sagittal view
    mriText1 = findobj(0, 'Tag', 'TextMarker1'); 
    % Remove contact labels from the figures
    for i = 1:length(mriText1)
        hFig = get(get(mriText1(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete contact labels in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            % Find all selected contact labels in MRI space for sagittal view
            delete(mriText1(i));
        end
    end
    
    % Find all selected contacts in MRI space for coronal view
    mriCoord2 = findobj(0, 'Tag', 'PointMarker2'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord2)
        hFig = get(get(mriCoord2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete contacts in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            % delete point in coronal view
            delete(mriCoord2(i));
        end
    end

    % Find all selected contact labels in MRI space for coronal view
    mriText2 = findobj(0, 'Tag', 'TextMarker2'); 
    % Remove contact labels from the figures
    for i = 1:length(mriText2)
        hFig = get(get(mriText2(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete contact labels in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            % Find all selected contact labels in MRI space for coronal view
            delete(mriText2(i));
        end
    end

    % Find all selected contacts in MRI space for axial view
    mriCoord3 = findobj(0, 'Tag', 'PointMarker3'); 
    % Remove coordinates from the figures
    for i = 1:length(mriCoord3)
        hFig = get(get(mriCoord3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete contacts in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            % delete point in axial view
            delete(mriCoord3(i));
        end
    end

    % Find all selected contact labels in MRI space for axial view
    mriText3 = findobj(0, 'Tag', 'TextMarker3'); 
    % Remove contact labels from the figures
    for i = 1:length(mriText3)
        hFig = get(get(mriText3(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete contact labels in MRI space
    if ~isempty(hCoord)
        for i=1:length(hCoord)
            % Find all selected contact labels in MRI space for axial view
            delete(mriText3(i));
        end
    end
    
    % Find all reference lines
    lineCoord = findobj(0, 'Tag', 'lineCoordinates'); 
    % Remove coordinates from the figures
    for i = 1:length(lineCoord)
        hFig = get(get(lineCoord(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected line
    if ~isempty(lineCoord)
        % delete reference line
        delete(lineCoord);
    end
    
    % Find all reference contacts
    hCoordRef = findobj(0, 'Tag', 'ptCoordinatesRef'); 
    % Remove coordinates from the figures
    for i = 1:length(hCoordRef)
        hFig = get(get(hCoordRef(i), 'Parent'), 'Parent');
        if ~isempty(hFig) && isappdata(hFig, 'CoordinatesSelector')
            rmappdata(hFig, 'CoordinatesSelector');
        end
    end
    % Delete selected points
    if ~isempty(hCoordRef)
        % delete reference contacts
        delete(hCoordRef);
    end
    
    % reset global variables
    clickPointInSurface = 0;
    refLinePlotLoc = [];

    % Update panel
    UpdatePanel();
end

%% ===== VIEW IN MRI VIEWER =====
% view changes in MRI viewer
function ViewInMriViewer(varargin) %#ok<DEFNU>
    % global variables
    global GlobalData;
    global totalNumContacts;
    global clickOnSurfaceCount;
    global refLinePlotLoc;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return;
    end

    % Get current 3D figure
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '3D');
    if isempty(hFig)
        return
    end

    % Get current selected point
    CoordinatesSelector = getappdata(hFig, 'CoordinatesSelector');
    if isempty(CoordinatesSelector) || isempty(CoordinatesSelector.MRI)
        return
    end
    % Get subject and subject's MRI
    sSubject = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
    if isempty(sSubject) || isempty(sSubject.iAnatomy)
        return 
    end
    
    % Display subject's anatomy in MRI Viewer
    hFig = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName);
    sMri = panel_surface('GetSurfaceMri', hFig);
    Handles = bst_figures('GetFigureHandles', hFig);  

    % update and plot points in the MRI Viewer
    % (THIS IS WHERE HIDDEN CHANNELS WILL BE HANDLED - UNDER CONSTRUCTION)
    figure_mri('SetLocation', 'mri', hFig, [], CoordinatesSelector.MRI);
    Handles.LocEEG(1,:) = CoordinatesSelector.MRI .* 1000;
    Channels(1).Name = string(ctrl.jTextLabel.getText()) + string(ctrl.jTextNcontacts.getText());
    Handles.hPointEEG(1,:) = figure_mri('PlotPoint', sMri, Handles, Handles.LocEEG(1,:), [1 1 0], 5, Channels(1).Name);
    Handles.hTextEEG(1,:)  = figure_mri('PlotText', sMri, Handles, Handles.LocEEG(1,:), [1 1 0], Channels(1).Name, Channels(1).Name);

    if ~isempty(CoordinatesSelector) && ~isempty(CoordinatesSelector.MRI)
        % get the current contact
        curContactNum = round(str2double(ctrl.jTextNcontacts.getText()));
        
        % if the tip was marked then set entry as the next point to be plotted 
        if clickOnSurfaceCount == 1
            ctrl.jTextNcontacts.setText(sprintf("%d", totalNumContacts));
        % if tip, entry and reference electrode have been plotted then
        % just set the contact labels to decrement as the user clicks ob
        % the contact blobs from entry towards the tip
        else
            ctrl.jTextNcontacts.setText(sprintf("%d", curContactNum-1));
        end

        % if last contact then disable clicking on surface so that user cannot plot any more points
        if curContactNum==2
            ctrl.jTextNcontacts.setText('0');
            % Unselect selection button 
            SetSelectionState(0);
            totalNumContacts = 0;
        end
    end
    
    % update the landmarks
    figure_mri('UpdateVisibleLandmarks', sMri, Handles);
    
    % ask user if the tip and entry points were marked correctly
    % after completion of marking the entry point
    if curContactNum == totalNumContacts
        isConfirm = java_dialog('confirm', 'Did you select the points in the right order: 1. Tip 2. Skull entry', 'Set electrode tip and skull entry');
        if ~isConfirm
            RemoveLastContact();
            RemoveLastContact();
            SetSelectionState(1);
            java_dialog('msgbox', 'Re-enter the tip and skull entry for electrode ''' + string(ctrl.jTextLabel.getText()) + '''', 'Set electrode tip and skull entry');
            refLinePlotLoc = [];
        else
            java_dialog('confirm', 'Click on the ''DrawRef'' button on the panel to generate a reference ideal electrode as a guideline', 'Set electrode tip and skull entry');
            
            % set the DrawRef button enabled as the condition is met i.e.
            % the tip and entry have been set properly
            ctrl.jButtonDrawRefElectrode.setEnabled(1);

            % disable selection of contacts by user till the DrawRef button
            % has been clicked by user
            SetSelectionState(0);
        end
    end
end

%% ===== SAVE ALL TO DATABASE =====
% save everything to database
function SaveAll(varargin) %#ok<DEFNU>
    % global variables
    global ChannelAnatomicalMat;

    % Get panel controls
    ctrl = bst_get('PanelControls', 'ContactLabelIeeg');
    if isempty(ctrl)
        return
    end
    
    % get figure handles
    hFig = bst_figures('GetCurrentFigure', '3D');
    SubjectFile = getappdata(hFig, 'SubjectFile');
    if ~isempty(SubjectFile)
        sSubject = bst_get('Subject', SubjectFile);
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
    end
    
    bst_progress('start', 'Saving sEEG contact labeling', 'Saving new file...');

    % Create output filenames
    ProtocolInfo = bst_get('ProtocolInfo');
    CoordDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(MriFile));
    CoordFile  = bst_fullfile(CoordDir, 'channel_seeg.mat');
    
    % Save to file and update BST history
    ChannelAnatomicalMat.Comment = sprintf('sEEG manual contact localization');
    ChannelAnatomicalMat = bst_history('add', ChannelAnatomicalMat, 'seeg_manual_contact_localization', 'Saved sEEG manual contact localization');
    bst_save(CoordFile, ChannelAnatomicalMat, 'v7');
    
    bst_progress('stop');
end
