function varargout = panel_ssp_selection(varargin)
% PANEL_SSP_SELECTION: Select active SSP.
%
% USAGE:  panel_ssp_selection('OpenRaw')

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
% Authors: Francois Tadel, 2012-2016

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel() %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    import org.brainstorm.list.*;
    panelName = 'EditSsp';
    % Font size for the lists
    fontSize = round(11 * bst_get('InterfaceScaling') / 100);
    
    % Create main panel
    jPanelNew = gui_component('Panel');
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(6, 6, 6, 6));
    
    % PANEL: left panel (list of available categories)
    jPanelLeft = gui_component('Panel');
    jPanelCat = gui_component('Panel');
    jPanelCat.setBorder(BorderFactory.createCompoundBorder(...
                        java_scaled('titledborder', 'Projector categories'), ...
                        BorderFactory.createEmptyBorder(3, 6, 6, 6)));
        % ===== TOOLBAR =====
        jToolbar = gui_component('Toolbar', jPanelCat, BorderLayout.NORTH);
        jToolbar.setPreferredSize(java_scaled('dimension', 100,25));
            TB_SIZE = java_scaled('dimension', 25,25);
            gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_FOLDER_OPEN, TB_SIZE}, 'Load projectors', @(h,ev)bst_call(@ButtonLoadFile_Callback));
            gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_SAVE, TB_SIZE}, 'Save active projectors', @(h,ev)bst_call(@ButtonSaveFile_Callback));
            jToolbar.addSeparator();
            gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_EDIT, TB_SIZE},   'Rename category', @(h,ev)bst_call(@ButtonRename_Callback));
            gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_DELETE, TB_SIZE}, 'Delete category', @(h,ev)bst_call(@ButtonDelete_Callback));
            jToolbar.addSeparator();
            gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_TOPOGRAPHY, TB_SIZE}, 'Display component topography', @(h,ev)bst_call(@(h,ev)PlotComponents([], 1, 0)));
            jButtonNoInterp = gui_component('ToolbarButton', jToolbar, [], '', {IconLoader.ICON_TOPO_NOINTERP, TB_SIZE}, 'Display component topography [No magnetic interpolation]', @(h,ev)bst_call(@(h,ev)PlotComponents(0, 1, 0)));
            jButtonTS       = gui_component('ToolbarButton', jToolbar, [], [], {IconLoader.ICON_TS_DISPLAY, TB_SIZE}, 'Display component time series', @(h,ev)bst_call(@(h,ev)PlotComponents([], 0, 1)));
        % LIST: Create list
        jListCat = JList([BstListItem('', '', 'Projector 1', int32(0)), BstListItem('', '', 'Projector 2', int32(1))]);
            jListCat.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
            jListCat.setCellRenderer(BstCheckListRenderer(fontSize));
            java_setcb(jListCat, 'MouseClickedCallback', @ListCatClick_Callback, ...
                                 'KeyTypedCallback',     @ListCatKey_Callback, ...
                                 'ValueChangedCallback', []);
            % Create scroll panel
            jScrollPanelCat = JScrollPane(jListCat);
            jScrollPanelCat.setPreferredSize(java_scaled('dimension', 205,200));
        jPanelCat.add(jScrollPanelCat, BorderLayout.CENTER);
    jPanelLeft.add(jPanelCat, BorderLayout.CENTER)
    jPanelNew.add(jPanelLeft, BorderLayout.CENTER);
    
    % PANEL: right panel (sensors list)
    jPanelRight = gui_component('Panel');
    jPanelComp = gui_component('Panel');
    jPanelComp.setBorder(BorderFactory.createCompoundBorder(...
                            java_scaled('titledborder', 'Projector components'), ...
                            BorderFactory.createEmptyBorder(6, 6, 6, 6)));
        % LABEL: Title
        gui_component('label', jPanelComp, BorderLayout.NORTH, '<HTML><DIV style="height:15px;">Components to remove:</DIV>');
        % LIST: Create list 
        jListComp = JList([BstListItem('', '', 'Component 1', int32(0)), BstListItem('', '', 'Component 2', int32(1))]);
            jListComp.setCellRenderer(BstCheckListRenderer(fontSize));
            java_setcb(jListComp, 'MouseClickedCallback', @ListCompClick_Callback);
            % Create scroll panel
            jScrollPanelComp = JScrollPane(jListComp);
            jScrollPanelComp.setPreferredSize(java_scaled('dimension', 165,200));
        jPanelComp.add(jScrollPanelComp, BorderLayout.CENTER);
    jPanelRight.add(jPanelComp, BorderLayout.CENTER);
    
    % PANEL: Selections buttons
    jPanelValidation = gui_river([10 0], [6 10 0 10]);
        % Cancel
        gui_component('button', jPanelValidation, 'center', 'Cancel', [], [], @ButtonCancel_Callback);
        % Save
        gui_component('button', jPanelValidation, '', 'Save', [], [], @ButtonSave_Callback);
    jPanelLeft.add(jPanelValidation, BorderLayout.SOUTH);
    jPanelNew.add(jPanelRight, BorderLayout.EAST);
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jListCat',         jListCat, ...
                                  'jListComp',        jListComp, ...
                                  'jButtonTS',        jButtonTS, ...
                                  'jButtonNoInterp',  jButtonNoInterp));

                              
%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================
    %% ===== VALIDATION BUTTONS =====
    function ButtonCancel_Callback(varargin)
        global EditSspPanel;
        % Cancel current modifications
        EditSspPanel.isSave = 0;
        % Close panel without saving
        gui_hide(panelName);
    end
    function ButtonSave_Callback(varargin)
        global EditSspPanel;
        % Mark that modifications have to be saved permanently (default)
        EditSspPanel.isSave = 1;
        % Close panel
        gui_hide(panelName);
    end

    %% ===== LISTS CATEGORY CLICK =====
    function ListCatClick_Callback(h,ev)
        global EditSspPanel;
        % Double-click
        if (ev.getClickCount() == 2)
            ButtonRename_Callback();
        % Right-click: Popup menu
        elseif (ev.getButton() == ev.BUTTON3)
            % Create popup menu
            jPopup = java_create('javax.swing.JPopupMenu');
            % Menu "Remove from list"
            gui_component('MenuItem', jPopup, [], 'Select all',   [], [], @(h,ev)SelectAllComponents(1));
            gui_component('MenuItem', jPopup, [], 'Deselect all', [], [], @(h,ev)SelectAllComponents(0));
            % Show popup menu
            jPopup.pack();
            jPopup.show(jListCat, ev.getPoint.getX(), ev.getPoint.getY());
        % Single click
        else
            % Toggle checkbox status
            [iCat, Status] = ToggleCheck(ev);
            if (Status == 2)
                return
            end
            % Propagate changes
            if ~isempty(iCat)
                % Update loaded structure
                EditSspPanel.Projector(iCat).Status = Status;
                % Update displays
                if EditSspPanel.isRaw
                    UpdateRaw();
                end
                % Update components list
                UpdateComp();
            end
        end
    end

    %% ===== LIST COMPONENTS CLICK =====
    function ListCompClick_Callback(h,ev)
        import org.brainstorm.icon.*;
        global EditSspPanel;
        % Toggle checkbox status
        [iComp,Status] = ToggleCheck(ev);
        if (Status == 2)
            return
        end
        % Get selected catgory
        [sCat,iCat] = GetSelectedCat();
        if isempty(iCat)
            return;
        end
        % Right-click: Popup menu
        if (ev.getButton() > 1)
            % Get selected components
            iSelComp = double(jListComp.getSelectedIndices()) + 1;
            if isempty(iSelComp)
                return;
            end
            nComp = jListComp.getModel().getSize();
            % Create popup menu
            jPopup = java_create('javax.swing.JPopupMenu');
            % Add menus
            gui_component('MenuItem', jPopup, [], 'Check selected components', [], [], @(h,ev)SelSelectedComp(iCat, iSelComp), []);
            gui_component('MenuItem', jPopup, [], 'Check all but selected', [], [], @(h,ev)SelSelectedComp(iCat, setdiff(1:nComp, iSelComp)), []);
            % Show popup menu
            jPopup.pack();
            jPopup.show(jListComp, ev.getPoint.getX(), ev.getPoint.getY());
        % Left-click: Select components and update views
        elseif ~isempty(iComp)
            % Update loaded structure
            EditSspPanel.Projector(iCat).CompMask(iComp) = Status;
            % Update displays
            if EditSspPanel.isRaw
                UpdateRaw();
            end
        end
    end

    %% ===== LIST: KEY TYPED CALLBACK =====
    function ListCatKey_Callback(h, ev)
        switch(uint8(ev.getKeyChar()))
            case {ev.VK_DELETE, ev.VK_BACK_SPACE}
                ButtonDelete_Callback();
        end
    end
end


%% =================================================================================
%  === INTERFACE CALLBACKS =========================================================
%  =================================================================================
%%  ===== TOGGLE CHECKBOX ======
function [i, newStatus] = ToggleCheck(ev)
    i = [];
    newStatus = [];
    % Ignore all the clicks if the JList is disabled
    if ~ev.getSource().isEnabled()
        return
    end
    % Only consider that it was selected if it was clicked next to the left of the component
    if (ev.getPoint().getX() > 17)
        return;
    end
    % Get selected element
    jList = ev.getSource();
    i    = jList.locationToIndex(ev.getPoint());
    item = jList.getModel().getElementAt(i);
    status = item.getUserData();
    % Process click (0:Not selected, 1:Selected, 2:Forced selected)
    switch(status)
        case 0,  newStatus = 1;
        case 1,  newStatus = 0;
        case 2,  newStatus = 2;
    end
    item.setUserData(int32(newStatus));
    jList.repaint(jList.getCellBounds(i, i));
    % Convert index to 1-based
    i = i + 1;
end


%% ===== CLOSING CALLBACK =====
function PanelHidingCallback(varargin) %#ok<DEFNU>
    global EditSspPanel;
    % If there were modifications, process them
    if ~isequal(EditSspPanel.Projector, EditSspPanel.InitProjector)
        % Save modifications
        if EditSspPanel.isSave
            SaveModifications();
        % Cancel modifications
        else
            % Restore initial projectors
            EditSspPanel.Projector = EditSspPanel.InitProjector;
            % Propagate
            if EditSspPanel.isRaw
                UpdateRaw();
            end
        end
    end
    % Close ICA/SSP components time series figures
    if ~isempty(EditSspPanel) && ~isempty(EditSspPanel.hFigTs)
        close(EditSspPanel.hFigTs(ishandle(EditSspPanel.hFigTs)));
    end
    % Close ICA/SSP topography figures
    if ~isempty(EditSspPanel) && ~isempty(EditSspPanel.hFigTopo)
        close(EditSspPanel.hFigTopo(ishandle(EditSspPanel.hFigTopo)));
    end
    % Reset field
    EditSspPanel = [];
end


%% ===== SAVE MODIFICATIONS =====
function SaveModifications()
     global GlobalData EditSspPanel;
     % Save modifications to channel file
     ChannelMat.Projector = EditSspPanel.Projector;
     ChannelFileFull = file_fullpath(GlobalData.DataSet(EditSspPanel.iDS).ChannelFile);
     bst_save(ChannelFileFull, ChannelMat, 'v7', 1);
%      % Save modifications to sFile structure (DataMat.F)
%      if EditSspPanel.isRaw
%          GlobalData.DataSet(EditSspPanel.iDS).Projector = EditSspPanel.Projector;
%          panel_record('SaveModifications', EditSspPanel.iDS);
%      end
end

%% ===== SET SELECTED COMPONENTS =====
function SelSelectedComp(iCat, iComp)
    global EditSspPanel;
    % Select only the target components
    EditSspPanel.Projector(iCat).CompMask        = 0 * EditSspPanel.Projector(iCat).CompMask;
    EditSspPanel.Projector(iCat).CompMask(iComp) = 1;
    % Update displays
    if EditSspPanel.isRaw
        UpdateRaw();
    end
    % Update components list
    UpdateComp();
end


%% ===== LISTS SELECTION CHANGE =====
function ListCatSelectionChange_Callback(hObj, ev)
    if ~ev.getValueIsAdjusting()
        UpdateComp();
    end
end

%% ===== BUTTON: DELETE =====
function ButtonDelete_Callback()
    global EditSspPanel;
    % Get selected category
    [sCat, iCat] = GetSelectedCat();
    if isempty(sCat) || (sCat.Status == 2)
        return
    end
    % Save new name
    EditSspPanel.Projector(iCat) = [];
    % Update changes
    UpdateCat();
    if EditSspPanel.isRaw
        UpdateRaw();
    end
end

%% ===== BUTTON: RENAME =====
function ButtonRename_Callback()
    global EditSspPanel;
    % Get selected category
    [sCat, iCat] = GetSelectedCat();
    if isempty(sCat)
        return
    end
    % Ask new label to the user
    newComment = java_dialog('input', 'Enter new projector comment:', 'Rename projectors', [], sCat.Comment);
    if isempty(newComment)
        return
    end
    % Save new name
    EditSspPanel.Projector(iCat).Comment = newComment;
    % Update changes
    UpdateCat();
end

%% ===== BUTTON: LOAD PROJECTORS =====
function ButtonLoadFile_Callback()
    global EditSspPanel;
    % Load projectors
    [newProj, errMsg] = import_ssp(EditSspPanel.ChannelFile, [], 0, 0);
    if isempty(newProj)
        if ~isempty(errMsg)
            bst_error(errMsg, 'Load SSP projectors', 0);
        end
        return;
    end
    % Save new name
    if isempty(EditSspPanel.Projector)
        EditSspPanel.Projector = newProj;
    else
        % Check number of sensors for new projectors
        for i = 1:length(newProj)
            nNew = size(newProj(i).Components,1);
            nOld = size(EditSspPanel.Projector(1).Components,1);
            if (nNew ~= nOld)
                bst_error(sprintf('Number of sensors in the loaded projectors (%d) do not match the other projectors (%d).', nNew, nOld), 'Load projectors', 0);
                return;
            end
        end
        % Add to existing list
        EditSspPanel.Projector = [EditSspPanel.Projector, newProj];
    end
    % Update changes
    UpdateCat();
    if EditSspPanel.isRaw
        UpdateRaw();
    end
    % Save modifications
    SaveModifications();
end


%% ===== BUTTON: SAVE PROJECTORS =====
function ButtonSaveFile_Callback()
    global GlobalData EditSspPanel;
    % Nothing to save
    if isempty(EditSspPanel.iDS) || isempty(EditSspPanel.Projector)
        return;
    end
    % Get projectors to save
    Projectors = EditSspPanel.Projector;
    if isempty(Projectors)
        bst_error('No selected projector', 'Save SSP projectors', 0);
        return;
    end
    % Export projectors
    export_ssp(Projectors, {GlobalData.DataSet(EditSspPanel.iDS).Channel.Name}, []);
end


%% ===== PLOT COMPONENTS =====
function PlotComponents(UseSmoothing, isPlotTopo, isPlotTs)
    global GlobalData EditSspPanel;
    % Get current dataset
    iDS = EditSspPanel.iDS;
    % Get selected components
    [sCat, iCat, iComp] = GetSelectedCat();
    % If there is nothing to display, exit
    if (isempty(sCat) || isempty(sCat.CompMask))
        return;
    end
    % If no components selected: select all components
    if isempty(iComp)
        iComp = 1:size(sCat.Components,2);
    end
    % Get information to plot
    DataFile = GlobalData.DataSet(iDS).DataFile;
    % Get modalities from projector
    iChanAll = any(sCat.Components,2);
    allMod = unique({GlobalData.DataSet(iDS).Channel(iChanAll).Type});
    % For Elekta-Neuromag: Split MEG GRAD in GRAD2+GRAD3
    if ~isempty(UseSmoothing) && ~UseSmoothing && ismember('MEG GRAD', allMod)
        iGrad2 = good_channel(GlobalData.DataSet(iDS).Channel(iChanAll), [], 'MEG GRAD2');
        iGrad3 = good_channel(GlobalData.DataSet(iDS).Channel(iChanAll), [], 'MEG GRAD3');
        isGradNorm = ~isempty(iGrad2) && ~isempty(iGrad3);
    else
        isGradNorm = 0;
    end
%     % Close existing component topography figures
%     if isPlotTopo && ~isempty(EditSspPanel.hFigTopo) && (length(iComp) > 1)
%         close(EditSspPanel.hFigTopo(ishandle(EditSspPanel.hFigTopo)));
%         EditSspPanel.hFigTopo = [];
%     end
    % Loop on all the modalities
    for iMod = 1:length(allMod)
        % Get sensors for this topography
        iChannels = good_channel(GlobalData.DataSet(iDS).Channel, GlobalData.DataSet(iDS).Measures.ChannelFlag, allMod{iMod});
        % Type of components
        isICA = isequal(sCat.SingVal, 'ICA');
        % ICA: Get the topography to display
        if isICA
            % Field Components stores the mixing matrix W
            W = sCat.Components(iChannels,:)';
            Topo = pinv(W);
            % Display name
            strDisplay = 'IC';
        % SSP: Limit the maximum number of components to display
        else
            % Field Components stores the spatial components U
            U = sCat.Components(iChannels, :);
            Topo = U;
            % SSP/PCA results
            if ~isempty(sCat.SingVal) 
                Singular = sCat.SingVal ./ sum(sCat.SingVal);
            % SSP/Mean results
            else
                Singular = eye(size(U,2));
            end
            % Rebuild mixing matrix
            if isPlotTs
                % W = pinv(U);
                W = diag(sqrt(Singular)) * pinv(U);
            end
            % Select only the first 20 components
            iComp = intersect(iComp, 1:20);
            % Display name
            strDisplay = 'SSP';
        end
        % Keep only the requested components
        Topo = Topo(:,iComp);
        nComp = length(iComp);
        
        % === PLOT TOPOGRAPHY ===
        if isPlotTopo
            % Modality to plot
            if strcmpi(allMod{iMod}, 'MEG GRAD') && isGradNorm
                % Compute the norm of the gradiometers
                modPlot = 'MEG GRADNORM';
                iGrad2 = good_channel(GlobalData.DataSet(iDS).Channel(iChannels), GlobalData.DataSet(iDS).Measures.ChannelFlag(iChannels), 'MEG GRAD2');
                iGrad3 = good_channel(GlobalData.DataSet(iDS).Channel(iChannels), GlobalData.DataSet(iDS).Measures.ChannelFlag(iChannels), 'MEG GRAD3');
                Topo = sqrt(Topo(iGrad2,:).^2 + Topo(iGrad3,:).^2);
            else
                modPlot = allMod{iMod};
            end
            % Plot single topography
            if (length(iComp) == 1)
                EditSspPanel.hFigTopo(end+1) = view_topography(DataFile, modPlot, [], Topo, UseSmoothing, 'NewFigure');
            % Plot all the components in a contact sheet
            else
                % Open figure
                hFig = view_topography(DataFile, modPlot, [], zeros(size(Topo,1),1), UseSmoothing, 'NewFigure');
                if isempty(hFig)
                    return;
                end
                set(hFig, 'Position', [100 100 150 180]);
                imgFig = out_figure_image(hFig, [], '');
                TopoInfo = getappdata(hFig, 'TopoInfo');
                % Hide colorbar
                ColormapInfo = getappdata(hFig, 'Colormap');
                sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
                isPrevDisplay = sColormap.DisplayColorbar;
                bst_colormaps('SetDisplayColorbar', ColormapInfo.Type, 0);
                % Get extracted image size
                Height = size(imgFig, 1);
                Width = size(imgFig, 2);
                % Get number of column and rows of the contact sheet
                nRows = floor(sqrt(nComp));
                nCols = ceil(nComp / nRows);
                % Initialize final image
                imgFinal = zeros(nRows * Height, nCols * Width, 3, class(imgFig));
                % Loop on components
                for i = 1:nComp
                    % Update figure data
                    TopoInfo.DataToPlot = Topo(:, i);
                    setappdata(hFig, 'TopoInfo', TopoInfo);
                    bst_figures('ReloadFigures', hFig, 1);
                    % Capture image
                    if isICA
                        strLegend = sprintf('%s%d', strDisplay, iComp(i));
                    else
                        strLegend = sprintf('%s%d (%d%%)', strDisplay, iComp(i), round(100*Singular(iComp(i))));
                    end
                    imgFig = out_figure_image(hFig, [], strLegend);
                    % Find extacted image position in final sheet
                    iRow = floor((i-1) / nCols);
                    iCol = mod(i-1, nCols);
                    imgFinal(iRow*Height+1:(iRow+1)*Height, iCol*Width+1:(iCol+1)*Width, :) = imgFig;
                end
                % Close figure
                close(hFig);
                % Restore colorbar
                bst_colormaps('SetDisplayColorbar', ColormapInfo.Type, isPrevDisplay);
                % View result
                EditSspPanel.hFigTopo(end+1) = view_image(imgFinal);
            end
        end
        
        % === PLOT COMPONENT TIME SERIES ===
        if isPlotTs
            % Keep only the selected component
            W = W(iComp,:);
            % Create line labels
            LinesLabels = cell(nComp, 1);
            for i = 1:nComp
                LinesLabels{i} = sprintf('%s%d', strDisplay, iComp(i));
            end
            % Create new montage on the fly
            sMontage = db_template('Montage');
            if isICA
                sMontage.Name = 'ICA components[tmp]';
            else
                sMontage.Name = 'SSP components[tmp]';
            end
            sMontage.Type      = 'matrix';
            sMontage.ChanNames = {GlobalData.DataSet(iDS).Channel(iChannels).Name};
            sMontage.DispNames = LinesLabels;
            sMontage.Matrix    = W;
            % Add montage: orig
            panel_montage('SetMontage', sMontage.Name, sMontage);
            % If the ICA components figure is not displayed yet: open a new data figure
            if isempty(EditSspPanel.hFigTs) || ~ishandle(EditSspPanel.hFigTs)
                % Create figure
                EditSspPanel.hFigTs = view_timeseries(DataFile, allMod{iMod}, [], 'NewFigure');
                % Enforce auto-scale
                TsInfo = getappdata(EditSspPanel.hFigTs, 'TsInfo');
                TsInfo.AutoScaleY  = 1;
                TsInfo.DisplayMode = 'column';
                setappdata(EditSspPanel.hFigTs, 'TsInfo', TsInfo);
                % Re-plot figure
                bst_figures('ReloadFigures', EditSspPanel.hFigTs);
            end
            % Update the montage for this figure
            panel_montage('SetCurrentMontage', EditSspPanel.hFigTs, sMontage.Name);
        end
    end
end
    


%% =================================================================================
%  === HELPER FUNCTIONS ============================================================
%  =================================================================================

%% ===== GET SELECTED CATEGORY =====
function [sCat, iCat, iComp] = GetSelectedCat()
    global EditSspPanel;
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditSsp');
    if isempty(ctrl)
        sCat = [];
        iCat = [];
        iComp = [];
        return;
    end
    % Get selected category
    iCat = ctrl.jListCat.getSelectedIndex() + 1;
    % If something is selected
    if (iCat >= 1) && ~isempty(EditSspPanel.Projector)
        sCat = EditSspPanel.Projector(iCat);
    else
        sCat = [];
        iCat = [];
    end
    % Get selected components
    if (nargout >= 3) && (length(iCat) == 1) && ~isempty(sCat.CompMask)
        iComp = double(ctrl.jListComp.getSelectedIndices())' + 1;
        %iComp = ctrl.jListComp.getSelectedIndex() + 1;
        if (iComp == 0)
            iComp = [];
        end
    else
        iComp = [];
    end
end


%% ===== OPEN INTERFACE FOR CURRENT RAW FILE =====
function OpenRaw() %#ok<DEFNU>
    global EditSspPanel;
    global GlobalData;
    % Get current raw dataset
    iDS = bst_memory('GetRawDataSet');
    if isempty(iDS)
        error('No continuous/raw dataset currently open.');
    end
    % Build structure of data needed by this panel
    EditSspPanel.iDS           = iDS;
    EditSspPanel.ChannelFile   = GlobalData.DataSet(EditSspPanel.iDS).ChannelFile;
    if ~isempty(GlobalData.DataSet(EditSspPanel.iDS).Projector)
        EditSspPanel.Projector = GlobalData.DataSet(EditSspPanel.iDS).Projector;
    else
        EditSspPanel.Projector = repmat(db_template('projector'), 0);
    end
    EditSspPanel.InitProjector = EditSspPanel.Projector;
    EditSspPanel.isRaw         = 1;
    EditSspPanel.isSave        = 1;   % By default, save the modifications when the panel is hidden
    EditSspPanel.hFigTs        = [];
    EditSspPanel.hFigTopo      = [];
    % Display panel
    [panelContainer, bstPanel] = gui_show('panel_ssp_selection', 'JavaWindow', 'Select active projectors', [], 0, 1, 0);
    % Load current projectors
    UpdateCat();
    UpdateComp();
    % Get modalities from projector
    allMod = unique({GlobalData.DataSet(EditSspPanel.iDS).Channel.Type});
    % MEG: Enable the "No interp" button
    sControls = get(bstPanel, 'sControls');
    if ~any(ismember({'MEG','MEG GRAD', 'MEG MAG', 'EEG'}, allMod))
        sControls.jButtonNoInterp.setVisible(0);
    end
end


%% ===== UPDATE PROJECTORS =====
function UpdateCat()
    import org.brainstorm.list.*;
    global EditSspPanel;
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditSsp');
    % Suspend callbacks
    java_setcb(ctrl.jListCat, 'ValueChangedCallback', @ListCatSelectionChange_Callback);
    % Create projector categories list
    listModel = javax.swing.DefaultListModel();
    for i = 1:length(EditSspPanel.Projector)
        listModel.addElement(BstListItem('', '', EditSspPanel.Projector(i).Comment, int32(EditSspPanel.Projector(i).Status)));
    end
    % Update JList
    ctrl.jListCat.setModel(listModel);
    ctrl.jListCat.repaint();
    % Select first element in the list
    if ~isempty(EditSspPanel.Projector)
        ctrl.jListCat.setSelectedIndex(0);
    end
    drawnow;
    % Restore callbacks
    java_setcb(ctrl.jListCat, 'ValueChangedCallback', @ListCatSelectionChange_Callback);
end


%% ===== UPDATE COMPONENTS =====
function UpdateComp()
    import org.brainstorm.list.*;
    % Get panel controls handles
    ctrl = bst_get('PanelControls', 'EditSsp');
    if isempty(ctrl)
        return;
    end
    % Initialize new list
    listModel = javax.swing.DefaultListModel();
    % Get selected category
    [sCat, iCat] = GetSelectedCat();
    % If there is something selected: Add components
    if ~isempty(sCat)
        isICA = isequal(sCat.SingVal, 'ICA');
        if (length(sCat.CompMask) > 1)
            % ICA: Show all components
            if isICA
                iDispComp = 1:size(sCat.Components,2);
            % PCA: Get only the components that grab 95% of the signal
            else
                Singular = sCat.SingVal ./ sum(sCat.SingVal);
                iDispComp = union(1, find(cumsum(Singular)<=.95));
                % Keep only the first components
                iDispComp = intersect(iDispComp, 1:20);
                % Always show at least the 10 first components
                iDispComp = union(iDispComp, 1:min(10,length(Singular)));
            end
            % Add all the components
            for i = iDispComp
                strComp = sprintf('Component #%d', i);
                if ~isempty(sCat.SingVal) && ~isICA
                    strComp = [strComp, sprintf(' [%d%%]', round(100 * Singular(i)))];
                end
                listModel.addElement(BstListItem('', '', strComp, int32(sCat.CompMask(i))));
            end
        else
            listModel.addElement(BstListItem('', '', 'Single component', int32(2)));
        end
    end
    % Enable / disable JList
    isEnableComp = ~isempty(sCat) && (sCat.Status == 1);
    ctrl.jListComp.setEnabled(isEnableComp);
    % Update JList
    ctrl.jListComp.setModel(listModel);
    ctrl.jListComp.repaint();
end


%% ===== UPDATE LOADED RAW FILE =====
function UpdateRaw()
    global EditSspPanel;
    global GlobalData;
    % Get current raw dataset
    if isempty(EditSspPanel) || isempty(EditSspPanel.iDS) || ~EditSspPanel.isRaw
        return;
    end
    % Update loaded projectors
    GlobalData.DataSet(EditSspPanel.iDS).Projector = EditSspPanel.Projector;
    % Reload windows
    panel_record('ReloadRecordings', 1);
end


%% ===== SAVE FIGURE AS SSP =====
function SaveFigureAsSsp(hFig, UseDirectly) %#ok<DEFNU>
    global GlobalData EditSspPanel;
    % Parse inputs
    if (nargin < 2) || isempty(UseDirectly)
        UseDirectly = 0;
    end
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return
    end
    % Get figure type
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;  
    FigureType = GlobalData.DataSet(iDS).Figure(iFig).Id.Type;
    Components = zeros(length(GlobalData.DataSet(iDS).Channel), 1);
    % Get figure data
    switch(FigureType)
        case 'Topography'
            [F, Time, selChan] = figure_topo('GetFigureData', iDS, iFig, 0);
            TopoInfo = getappdata(hFig, 'TopoInfo');
            FileName = TopoInfo.FileName;
            Components(selChan) = F;
        otherwise
            error('Operation not supported yet.');
    end
    
    % Normalize columns of the components
    Components = Components ./ sqrt(sum(Components .^2));
    % Build projector structure
    sProj = db_template('projector');
    sProj.Comment    = sprintf( '%s: %s (%0.3fs)', Modality, FileName, GlobalData.UserTimeWindow.CurrentTime);
    sProj.Components = Components;
    sProj.CompMask   = 1;
    sProj.Status     = 1;
    sProj.SingVal    = [];
    
    % Load for current data viewer
    if UseDirectly
        % Open projector selection interface
        if isempty(EditSspPanel)
            panel_ssp_selection('OpenRaw');
        end
        % Add projector to current list
        if isempty(EditSspPanel.Projector)
            EditSspPanel.Projector = sProj;
        else
            EditSspPanel.Projector = [EditSspPanel.Projector, sProj];
        end
        % Update changes
        UpdateCat();
        UpdateRaw();
        % Save modifications
        SaveModifications();
    % Save to a file
    else
        export_ssp(sProj, {GlobalData.DataSet(iDS).Channel.Name}, []);
    end
end


%% ===== SELECT ALL CATEGORIES =====
function SelectAllComponents(Status)
    global EditSspPanel;
    % Nothing to do if there are no projectors
    if isempty(EditSspPanel.Projector)
        return;
    end
    % Change the status of all the components
    iNonStatic = ([EditSspPanel.Projector.Status] < 2);
    [EditSspPanel.Projector(iNonStatic).Status] = deal(Status);
    % Update panel
    UpdateCat();
    UpdateComp();
    % Update display of recordings
    UpdateRaw();
end



