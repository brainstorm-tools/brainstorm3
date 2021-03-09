%% ===== POPUP MENU V1: Display Options menu with no sub-menus=====
%TODO: Saved image to display current values from Display Panel filters 
%TODO: Remove '(in dev)' for features once fully functional
function DisplayFigurePopup(hFig)
    import java.awt.event.KeyEvent;
    import java.awt.Dimension;
    import javax.swing.KeyStroke;
    import javax.swing.JLabel;
    import javax.swing.JSlider;
    import org.brainstorm.icon.*;
    % Get figure description
    hFig = bst_figures('GetFigure', hFig);
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes)
        return
    end
    
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
   
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);
    
    % ==== MENU: SNAPSHOT ====
    jPopup.addSeparator();
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshot', IconLoader.ICON_SNAPSHOT);
        % === SAVE AS IMAGE ===
        %TODO: Saved image to display current values from Display Panel filters 
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@out_figure_image, hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Viewer'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));       
    jPopup.add(jMenuSave);
    
    % ==== MENU: 2D LAYOUT (DISPLAY OPTIONS)====
    jDisplayMenu = gui_component('Menu', jPopup, [], 'Display options', IconLoader.ICON_CONNECTN);
        
            % === TOGGLE LABEL OPTIONS ===
            TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
            % Measure (outer) node labels
            jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Show scout labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 1));
            jItem.setSelected(ismember(1,TextDisplayMode));
            % Region (lobe/hemisphere) node labels
            if (DisplayInRegion)
                jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Show region labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 2));
                jItem.setSelected(ismember(2,TextDisplayMode));
            end
            % Selected Nodes' labels only
            jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Show labels for selection only', [], [], @(h, ev)SetTextDisplayMode(hFig, 3));
            jItem.setSelected(ismember(3,TextDisplayMode));
        
        jDisplayMenu.addSeparator();

        if (DisplayInRegion)
            % === TOGGLE HIERARCHY/REGION NODE VISIBILITY ===
            HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
            jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Hide region nodes (in dev)', [], [], @(h, ev)SetHierarchyNodeIsVisible(hFig, 1 - HierarchyNodeIsVisible));
            jItem.setSelected(~HierarchyNodeIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_H, 0));
            jDisplayMenu.addSeparator();
        end
        
        % == LINK DISPLAY OPTIONS ==
        if (bst_get('MatlabVersion') >= 705) % Check Matlab version: Works only for R2007b and newer
            
            % === MODIFY NODE AND LINK SIZE (Mar 2021)===
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            % uses node size to update text and slider
            NodeSize = GetNodeSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Node & label size');
            % Slider
            jSliderContrast = JSlider(1,15); % changed Jan 3 2020 (uses factor of 2 for node sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(NodeSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(NodeSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)NodeLabelSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
            if (~DisplayInRegion)
                jDisplayMenu.addSeparator();
            end
            
            % == MODIFY LINK SIZE ==
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            LinkSize = GetLinkSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Link size');
            % Slider
            jSliderContrast = JSlider(1,10); % changed Jan 3 2020 (uses factor of 2 for link sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(LinkSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(LinkSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)LinkSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
            
            % == MODIFY LINK TRANSPARENCY ==
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            Transparency = getappdata(hFig, 'LinkTransparency');
            % Label
            gui_component('label', jPanelModifiers, '', 'Link transp');
            % Slider
            jSliderContrast = JSlider(0,100,100);
            jSliderContrast.setValue(round(Transparency * 100));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f %%', Transparency * 100));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)TransparencySliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
        end
        
            % === TOGGLE BINARY LINK STATUS ===
            Method = getappdata(hFig, 'Method');
            if ismember(Method, {'granger'}) || ismember(Method, {'spgranger'})
                IsBinaryData = getappdata(hFig, 'IsBinaryData');
                jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'Binary Link Display', IconLoader.ICON_CHANNEL_LABEL, [], @(h, ev)SetIsBinaryData(hFig, 1 - IsBinaryData));
                jItem.setSelected(IsBinaryData);
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));
            end
        
        % === BACKGROUND OPTIONS (NOTE: DONE)===
        jDisplayMenu.addSeparator();
        BackgroundColor = getappdata(hFig, 'BgColor');
        isWhite = all(BackgroundColor == [1 1 1]);
        jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'White background', [], [], @(h, ev)ToggleBackground(hFig));
        jItem.setSelected(isWhite);
  
 
    % ==== GRAPH OPTIONS ====
    % NOTE: now all 'Graph Options' are directly shown in main pop-up menu
        jPopup.addSeparator();
        % === SELECT ALL THE NODES ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select all', [], [], @(h, n, s, r)SetSelectedNodes(hFig, [], 1, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, 0));
        % === SELECT NEXT REGION ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select next region', [], [], @(h, ev)ToggleRegionSelection(hFig, -1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, 0));
        % === SELECT PREVIOUS REGION===
        jItem = gui_component('MenuItem', jPopup, [], 'Select previous region', [], [], @(h, ev)ToggleRegionSelection(hFig, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, 0));
        jPopup.addSeparator();

        if (DisplayInRegion)
            % === TOGGLE DISPLAY REGION LINKS ===
            % TODO: IMPLEMENT REGION LINKS
            RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
            RegionFunction = getappdata(hFig, 'RegionFunction');
            jItem = gui_component('CheckBoxMenuItem', jPopup, [], ['Display region ' RegionFunction ' (in dev)'], [], [], @(h, ev)ToggleMeasureToRegionDisplay(hFig));
            jItem.setSelected(RegionLinksIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));

            % === TOGGLE REGION FUNCTIONS===
            IsMean = strcmp(RegionFunction, 'mean');
            jLabelMenu = gui_component('Menu', jPopup, [], 'Choose region function (in dev)');
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Mean (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'mean'));
                jItem.setSelected(IsMean);
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Max (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'max'));
                jItem.setSelected(~IsMean);
        end
    
    % Display Popup menu
    gui_popup(jPopup, hFig);
end

%% ===== POPUP MENU V2: Display Options menu with titled sections (NOT CURRENTLY WORKING)=====
% NOTE: titled subsections are jPanels, mouse interactions currently do not
% work with them, need improving.
%TODO: Saved image to display current values from Display Panel filters 
%TODO: Remove '(in dev)' for features once fully functional
function DisplayFigurePopup(hFig)
    import java.awt.event.KeyEvent;
    import java.awt.Dimension;
    import javax.swing.BoxLayout;
    import javax.swing.KeyStroke;
    import javax.swing.JLabel;
    import javax.swing.JSlider;
    import org.brainstorm.icon.*;
    % Get figure description
    hFig = bst_figures('GetFigure', hFig);
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes)
        return
    end
    
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
   
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);
    
    % ==== MENU: SNAPSHOT ====
    jPopup.addSeparator();
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshot', IconLoader.ICON_SNAPSHOT);
        % === SAVE AS IMAGE ===
        %TODO: Saved image to display current values from Display Panel filters 
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@out_figure_image, hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Viewer'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));       
    jPopup.add(jMenuSave);
    
    % ==== MENU: 2D LAYOUT (DISPLAY OPTIONS)====
    jDisplayMenu = gui_component('Menu', jPopup, [], 'Display options', IconLoader.ICON_CONNECTN);
        
        % === LABEL DISPLAY OPTIONS ===
        jLabelPanel = java_create('javax.swing.JPanel');
        jLabelPanel.setLayout(BoxLayout(jLabelPanel, BoxLayout.Y_AXIS));
        jLabelBorder = java_scaled('titledborder', 'Label options');
        jLabelPanel.setBorder(jLabelBorder);
        
        % === TOGGLE LABEL OPTIONS ===
        TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
        % Measure (outer) node labels
        jItem = gui_component('CheckBoxMenuItem', jLabelPanel, [], 'Show scout labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 1));
        jItem.setSelected(ismember(1,TextDisplayMode));
        % Region (lobe/hemisphere) node labels
        if (DisplayInRegion)
            jItem = gui_component('CheckBoxMenuItem', jLabelPanel, [], 'Show region labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 2));
            jItem.setSelected(ismember(2,TextDisplayMode));
        end
        % Selected Nodes' labels only
        jItem = gui_component('CheckBoxMenuItem', jLabelPanel, [], 'Show labels for selection only', [], [], @(h, ev)SetTextDisplayMode(hFig, 3));
        jItem.setSelected(ismember(3,TextDisplayMode));
        jDisplayMenu.add(jLabelPanel);
            
        % === NODE DISPLAY OPTIONS ===
        jNodePanel = java_create('javax.swing.JPanel');
        jNodePanel.setLayout(BoxLayout(jNodePanel, BoxLayout.Y_AXIS));
        jNodeBorder = java_scaled('titledborder', 'Node options');
        jNodePanel.setBorder(jNodeBorder);

        if (DisplayInRegion)
            % === TOGGLE HIERARCHY/REGION NODE VISIBILITY ===
            HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
            jItem = gui_component('CheckBoxMenuItem', jNodePanel, [], 'Hide region nodes (in dev)', [], [], @(h, ev)SetHierarchyNodeIsVisible(hFig, 1 - HierarchyNodeIsVisible));
            jItem.setSelected(~HierarchyNodeIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_H, 0));
        end
        jDisplayMenu.add(jNodePanel);
        
        % == LINK DISPLAY OPTIONS ==
        jLinkPanel = java_create('javax.swing.JPanel');
        jLinkPanel.setLayout(BoxLayout(jLinkPanel, BoxLayout.Y_AXIS));
        jLinkBorder = java_scaled('titledborder', 'Link options');
        jLinkPanel.setBorder(jLinkBorder);
        if (bst_get('MatlabVersion') >= 705) % Check Matlab version: Works only for R2007b and newer
            
            % === MODIFY NODE AND LINK SIZE (Mar 2021)===
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            % uses node size to update text and slider
            NodeSize = GetNodeSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Node & label size');
            % Slider
            jSliderContrast = JSlider(1,15); % changed Jan 3 2020 (uses factor of 2 for node sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(NodeSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(NodeSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)NodeLabelSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
            if (~DisplayInRegion)
                jDisplayMenu.addSeparator();
            end
            
            % == MODIFY LINK SIZE ==
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            LinkSize = GetLinkSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Link size');
            % Slider
            jSliderContrast = JSlider(1,10); % changed Jan 3 2020 (uses factor of 2 for link sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(LinkSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(LinkSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)LinkSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jLinkPanel.add(jPanelModifiers);
            
            % == MODIFY LINK TRANSPARENCY ==
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            Transparency = getappdata(hFig, 'LinkTransparency');
            % Label
            gui_component('label', jPanelModifiers, '', 'Link transp');
            % Slider
            jSliderContrast = JSlider(0,100,100);
            jSliderContrast.setValue(round(Transparency * 100));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f %%', Transparency * 100));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)TransparencySliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jLinkPanel.add(jPanelModifiers);
        end
        
            % === TOGGLE BINARY LINK STATUS ===
            Method = getappdata(hFig, 'Method');
            if ismember(Method, {'granger'}) || ismember(Method, {'spgranger'})
                IsBinaryData = getappdata(hFig, 'IsBinaryData');
                jItem = gui_component('CheckBoxMenuItem', jLinkPanel, [], 'Binary Link Display', IconLoader.ICON_CHANNEL_LABEL, [], @(h, ev)SetIsBinaryData(hFig, 1 - IsBinaryData));
                jItem.setSelected(IsBinaryData);
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));
            end
        jDisplayMenu.add(jLinkPanel);
        
        % === BACKGROUND OPTIONS (NOTE: DONE)===
        BackgroundColor = getappdata(hFig, 'BgColor');
        isWhite = all(BackgroundColor == [1 1 1]);
        jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'White background', [], [], @(h, ev)ToggleBackground(hFig));
        jItem.setSelected(isWhite);
  
 
    % ==== GRAPH OPTIONS ====
    % NOTE: now all 'Graph Options' are directly shown in main pop-up menu
        jPopup.addSeparator();
        % === SELECT ALL THE NODES ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select all', [], [], @(h, n, s, r)SetSelectedNodes(hFig, [], 1, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, 0));
        % === SELECT NEXT REGION ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select next region', [], [], @(h, ev)ToggleRegionSelection(hFig, -1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, 0));
        % === SELECT PREVIOUS REGION===
        jItem = gui_component('MenuItem', jPopup, [], 'Select previous region', [], [], @(h, ev)ToggleRegionSelection(hFig, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, 0));
        jPopup.addSeparator();

        if (DisplayInRegion)
            % === TOGGLE DISPLAY REGION LINKS ===
            % TODO: IMPLEMENT REGION LINKS
            RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
            RegionFunction = getappdata(hFig, 'RegionFunction');
            jItem = gui_component('CheckBoxMenuItem', jPopup, [], ['Display region ' RegionFunction ' (in dev)'], [], [], @(h, ev)ToggleMeasureToRegionDisplay(hFig));
            jItem.setSelected(RegionLinksIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));

            % === TOGGLE REGION FUNCTIONS===
            IsMean = strcmp(RegionFunction, 'mean');
            jLabelMenu = gui_component('Menu', jPopup, [], 'Choose region function (in dev)');
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Mean (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'mean'));
                jItem.setSelected(IsMean);
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Max (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'max'));
                jItem.setSelected(~IsMean);
        end
    
    % Display Popup menu
    gui_popup(jPopup, hFig);
end

%% ===== POPUP MENU V3: Display Options menu with sub-menus for Label, Node, Link=====
%TODO: Saved image to display current values from Display Panel filters 
%TODO: Remove '(in dev)' for features once fully functional
function DisplayFigurePopup(hFig)
    import java.awt.event.KeyEvent;
    import java.awt.Dimension;
    import javax.swing.KeyStroke;
    import javax.swing.JLabel;
    import javax.swing.JSlider;
    import org.brainstorm.icon.*;
    % Get figure description
    hFig = bst_figures('GetFigure', hFig);
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes)
        return
    end
    
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
   
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);
    
    % ==== MENU: SNAPSHOT ====
    jPopup.addSeparator();
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshot', IconLoader.ICON_SNAPSHOT);
        % === SAVE AS IMAGE ===
        %TODO: Saved image to display current values from Display Panel filters 
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@out_figure_image, hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Viewer'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));       
    jPopup.add(jMenuSave);
    
    % ==== MENU: 2D LAYOUT (DISPLAY OPTIONS)====
    jDisplayMenu = gui_component('Menu', jPopup, [], 'Display options', IconLoader.ICON_CONNECTN);
        
        % === LABEL DISPLAY OPTIONS ===
        jLabelMenu = gui_component('Menu', jDisplayMenu, [], 'Label options');
        
            % === TOGGLE LABEL OPTIONS ===
            TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
            % Measure (outer) node labels
            jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Show scout labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 1));
            jItem.setSelected(ismember(1,TextDisplayMode));
            % Region (lobe/hemisphere) node labels
            if (DisplayInRegion)
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Show region labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 2));
                jItem.setSelected(ismember(2,TextDisplayMode));
            end
            % Selected Nodes' labels only
            jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Show labels for selection only', [], [], @(h, ev)SetTextDisplayMode(hFig, 3));
            jItem.setSelected(ismember(3,TextDisplayMode));
        
        % === NODE DISPLAY OPTIONS ===
        jNodeMenu = gui_component('Menu', jDisplayMenu, [], 'Node options');

        if (DisplayInRegion)
            % === TOGGLE HIERARCHY/REGION NODE VISIBILITY ===
            HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
            jItem = gui_component('CheckBoxMenuItem', jNodeMenu, [], 'Hide region nodes (in dev)', [], [], @(h, ev)SetHierarchyNodeIsVisible(hFig, 1 - HierarchyNodeIsVisible));
            jItem.setSelected(~HierarchyNodeIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_H, 0));
        end
        
        % == LINK DISPLAY OPTIONS ==
        jLinkMenu = gui_component('Menu', jDisplayMenu, [], 'Link options');
        if (bst_get('MatlabVersion') >= 705) % Check Matlab version: Works only for R2007b and newer
            % === MODIFY NODE AND LINK SIZE (Mar 2021)===
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            % uses node size to update text and slider
            NodeSize = GetNodeSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Node & label size');
            % Slider
            jSliderContrast = JSlider(1,15); % changed Jan 3 2020 (uses factor of 2 for node sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(NodeSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(NodeSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)NodeLabelSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jDisplayMenu.add(jPanelModifiers);
            if (~DisplayInRegion)
                jDisplayMenu.addSeparator();
            end
            
            % == MODIFY LINK SIZE ==
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            LinkSize = GetLinkSize(hFig);
            % Label
            gui_component('label', jPanelModifiers, '', 'Link size');
            % Slider
            jSliderContrast = JSlider(1,10); % changed Jan 3 2020 (uses factor of 2 for link sizes 0.5 to 5.0 with increments of 0.5 in actuality)
            jSliderContrast.setValue(round(LinkSize * 2));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(LinkSize * 2)));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)LinkSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jLinkMenu.add(jPanelModifiers);
            
            % == MODIFY LINK TRANSPARENCY ==
            jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
            Transparency = getappdata(hFig, 'LinkTransparency');
            % Label
            gui_component('label', jPanelModifiers, '', 'Link transp');
            % Slider
            jSliderContrast = JSlider(0,100,100);
            jSliderContrast.setValue(round(Transparency * 100));
            jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
            %jSliderContrast.setToolTipText(tooltipSliders);
            jSliderContrast.setFocusable(0);
            jSliderContrast.setOpaque(0);
            jPanelModifiers.add('tab hfill', jSliderContrast);
            % Value (text)
            jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f %%', Transparency * 100));
            jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
            jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
            jPanelModifiers.add(jLabelContrast);
            % Slider callbacks
            java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)TransparencySliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
            jLinkMenu.add(jPanelModifiers);
        end
        
            % === TOGGLE BINARY LINK STATUS ===
            Method = getappdata(hFig, 'Method');
            if ismember(Method, {'granger'}) || ismember(Method, {'spgranger'})
                IsBinaryData = getappdata(hFig, 'IsBinaryData');
                jItem = gui_component('CheckBoxMenuItem', jLinkMenu, [], 'Binary Link Display', IconLoader.ICON_CHANNEL_LABEL, [], @(h, ev)SetIsBinaryData(hFig, 1 - IsBinaryData));
                jItem.setSelected(IsBinaryData);
                jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));
            end
        
        % === BACKGROUND OPTIONS (NOTE: DONE)===
        BackgroundColor = getappdata(hFig, 'BgColor');
        isWhite = all(BackgroundColor == [1 1 1]);
        jItem = gui_component('CheckBoxMenuItem', jDisplayMenu, [], 'White background', [], [], @(h, ev)ToggleBackground(hFig));
        jItem.setSelected(isWhite);
  
 
    % ==== GRAPH OPTIONS ====
    % NOTE: now all 'Graph Options' are directly shown in main pop-up menu
        jPopup.addSeparator();
        % === SELECT ALL THE NODES ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select all', [], [], @(h, n, s, r)SetSelectedNodes(hFig, [], 1, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, 0));
        % === SELECT NEXT REGION ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select next region', [], [], @(h, ev)ToggleRegionSelection(hFig, -1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, 0));
        % === SELECT PREVIOUS REGION===
        jItem = gui_component('MenuItem', jPopup, [], 'Select previous region', [], [], @(h, ev)ToggleRegionSelection(hFig, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, 0));
        jPopup.addSeparator();

        if (DisplayInRegion)
            % === TOGGLE DISPLAY REGION LINKS ===
            % TODO: IMPLEMENT REGION LINKS
            RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
            RegionFunction = getappdata(hFig, 'RegionFunction');
            jItem = gui_component('CheckBoxMenuItem', jPopup, [], ['Display region ' RegionFunction ' (in dev)'], [], [], @(h, ev)ToggleMeasureToRegionDisplay(hFig));
            jItem.setSelected(RegionLinksIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));

            % === TOGGLE REGION FUNCTIONS===
            IsMean = strcmp(RegionFunction, 'mean');
            jLabelMenu = gui_component('Menu', jPopup, [], 'Choose region function (in dev)');
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Mean (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'mean'));
                jItem.setSelected(IsMean);
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Max (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'max'));
                jItem.setSelected(~IsMean);
        end
    
    % Display Popup menu
    gui_popup(jPopup, hFig);
end

%% ===== POPUP MENU V4: No Display Options Menu =====
%TODO: Saved image to display current values from Display Panel filters 
%TODO: Remove '(in dev)' for features once fully functional
function DisplayFigurePopup(hFig)
    import java.awt.event.KeyEvent;
    import java.awt.Dimension;
    import javax.swing.KeyStroke;
    import javax.swing.JLabel;
    import javax.swing.JSlider;
    import org.brainstorm.icon.*;
    % Get figure description
    hFig = bst_figures('GetFigure', hFig);
    % Get axes handles
    hAxes = getappdata(hFig, 'clickSource');
    if isempty(hAxes)
        return
    end
    
    DisplayInRegion = getappdata(hFig, 'DisplayInRegion');
   
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);
    
    % ==== MENU: SNAPSHOT ====
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshot', IconLoader.ICON_SNAPSHOT);
        % === SAVE AS IMAGE ===
        %TODO: Saved image to display current values from Display Panel filters 
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@out_figure_image, hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Viewer'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));       
    jPopup.add(jMenuSave);
    
    % ==== GRAPH OPTIONS ====
    % NOTE: now all 'Graph Options' are directly shown in main pop-up menu
        jPopup.addSeparator();
        % === SELECT ALL THE NODES ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select all', [], [], @(h, n, s, r)SetSelectedNodes(hFig, [], 1, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_A, 0));
        % === SELECT NEXT REGION ===
        jItem = gui_component('MenuItem', jPopup, [], 'Select next region', [], [], @(h, ev)ToggleRegionSelection(hFig, -1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_RIGHT, 0));
        % === SELECT PREVIOUS REGION===
        jItem = gui_component('MenuItem', jPopup, [], 'Select previous region', [], [], @(h, ev)ToggleRegionSelection(hFig, 1));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_LEFT, 0));
        jPopup.addSeparator();

        if (DisplayInRegion)
            % === TOGGLE DISPLAY REGION LINKS ===
            % TODO: IMPLEMENT REGION LINKS
            RegionLinksIsVisible = getappdata(hFig, 'RegionLinksIsVisible');
            RegionFunction = getappdata(hFig, 'RegionFunction');
            jItem = gui_component('CheckBoxMenuItem', jPopup, [], ['Display region ' RegionFunction ' (in dev)'], [], [], @(h, ev)ToggleMeasureToRegionDisplay(hFig));
            jItem.setSelected(RegionLinksIsVisible);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));

            % === TOGGLE REGION FUNCTIONS===
            IsMean = strcmp(RegionFunction, 'mean');
            jLabelMenu = gui_component('Menu', jPopup, [], 'Choose region function (in dev)');
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Mean (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'mean'));
                jItem.setSelected(IsMean);
                jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Max (in dev)', [], [], @(h, ev)SetRegionFunction(hFig, 'max'));
                jItem.setSelected(~IsMean);
        end
    
    % === LABEL DISPLAY OPTIONS ===
    jPopup.addSeparator()
    jLabelMenu = gui_component('Menu', jPopup, [], 'Label options');
    
        % === TOGGLE LABEL OPTIONS ===
        TextDisplayMode = getappdata(hFig, 'TextDisplayMode');
        % Measure (outer) node labels
        jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Show scout labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 1));
        jItem.setSelected(ismember(1,TextDisplayMode));
        % Region (lobe/hemisphere) node labels
        if (DisplayInRegion)
            jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Show region labels', [], [], @(h, ev)SetTextDisplayMode(hFig, 2));
            jItem.setSelected(ismember(2,TextDisplayMode));
        end
        % Selected Nodes' labels only
        jItem = gui_component('CheckBoxMenuItem', jLabelMenu, [], 'Show labels for selection only', [], [], @(h, ev)SetTextDisplayMode(hFig, 3));
        jItem.setSelected(ismember(3,TextDisplayMode));

    % === NODE DISPLAY OPTIONS ===
    jNodeMenu = gui_component('Menu', jPopup, [], 'Node options');

    if (DisplayInRegion)
        % === TOGGLE HIERARCHY/REGION NODE VISIBILITY ===
        HierarchyNodeIsVisible = getappdata(hFig, 'HierarchyNodeIsVisible');
        jItem = gui_component('CheckBoxMenuItem', jNodeMenu, [], 'Hide region nodes (in dev)', [], [], @(h, ev)SetHierarchyNodeIsVisible(hFig, 1 - HierarchyNodeIsVisible));
        jItem.setSelected(~HierarchyNodeIsVisible);
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_H, 0));
    end

    % == LINK DISPLAY OPTIONS ==
    jLinkMenu = gui_component('Menu', jPopup, [], 'Link options');
    if (bst_get('MatlabVersion') >= 705) % Check Matlab version: Works only for R2007b and newer
        
        % === MODIFY NODE AND LINK SIZE (Mar 2021)===
        jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
        % uses node size to update text and slider
        NodeSize = GetNodeSize(hFig);
        % Label
        gui_component('label', jPanelModifiers, '', 'Node & label size');
        % Slider
        jSliderContrast = JSlider(1,15); % changed Jan 3 2020 (uses factor of 2 for node sizes 0.5 to 5.0 with increments of 0.5 in actuality)
        jSliderContrast.setValue(round(NodeSize * 2));
        jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
        %jSliderContrast.setToolTipText(tooltipSliders);
        jSliderContrast.setFocusable(0);
        jSliderContrast.setOpaque(0);
        jPanelModifiers.add('tab hfill', jSliderContrast);
        % Value (text)
        jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(NodeSize * 2)));
        jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
        jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
        jPanelModifiers.add(jLabelContrast);
        % Slider callbacks
        java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)NodeLabelSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
        jDisplayMenu.add(jPanelModifiers);
        if (~DisplayInRegion)
            jDisplayMenu.addSeparator();
        end
        
        % == MODIFY LINK SIZE ==
        jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
        LinkSize = GetLinkSize(hFig);
        % Label
        gui_component('label', jPanelModifiers, '', 'Link size');
        % Slider
        jSliderContrast = JSlider(1,10); % changed Jan 3 2020 (uses factor of 2 for link sizes 0.5 to 5.0 with increments of 0.5 in actuality)
        jSliderContrast.setValue(round(LinkSize * 2));
        jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
        %jSliderContrast.setToolTipText(tooltipSliders);
        jSliderContrast.setFocusable(0);
        jSliderContrast.setOpaque(0);
        jPanelModifiers.add('tab hfill', jSliderContrast);
        % Value (text)
        jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f', round(LinkSize * 2)));
        jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
        jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
        jPanelModifiers.add(jLabelContrast);
        % Slider callbacks
        java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)LinkSizeSliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
        jLinkMenu.add(jPanelModifiers);

        % == MODIFY LINK TRANSPARENCY ==
        jPanelModifiers = gui_river([0 0], [0, 29, 0, 0]);
        Transparency = getappdata(hFig, 'LinkTransparency');
        % Label
        gui_component('label', jPanelModifiers, '', 'Link transp');
        % Slider
        jSliderContrast = JSlider(0,100,100);
        jSliderContrast.setValue(round(Transparency * 100));
        jSliderContrast.setPreferredSize(java_scaled('dimension',100,23));
        %jSliderContrast.setToolTipText(tooltipSliders);
        jSliderContrast.setFocusable(0);
        jSliderContrast.setOpaque(0);
        jPanelModifiers.add('tab hfill', jSliderContrast);
        % Value (text)
        jLabelContrast = gui_component('label', jPanelModifiers, '', sprintf('%.0f %%', Transparency * 100));
        jLabelContrast.setPreferredSize(java_scaled('dimension',50,23));
        jLabelContrast.setHorizontalAlignment(JLabel.LEFT);
        jPanelModifiers.add(jLabelContrast);
        % Slider callbacks
        java_setcb(jSliderContrast.getModel(), 'StateChangedCallback', @(h,ev)TransparencySliderModifiersModifying_Callback(hFig, ev, jLabelContrast));
        jLinkMenu.add(jPanelModifiers);
    end

        % === TOGGLE BINARY LINK STATUS ===
        Method = getappdata(hFig, 'Method');
        if ismember(Method, {'granger'}) || ismember(Method, {'spgranger'})
            IsBinaryData = getappdata(hFig, 'IsBinaryData');
            jItem = gui_component('CheckBoxMenuItem', jLinkMenu, [], 'Binary Link Display', IconLoader.ICON_CHANNEL_LABEL, [], @(h, ev)SetIsBinaryData(hFig, 1 - IsBinaryData));
            jItem.setSelected(IsBinaryData);
            jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_M, 0));
        end

    % === BACKGROUND OPTIONS (NOTE: DONE)===
    BackgroundColor = getappdata(hFig, 'BgColor');
    isWhite = all(BackgroundColor == [1 1 1]);
    jItem = gui_component('CheckBoxMenuItem', jPopup, [], 'White background', [], [], @(h, ev)ToggleBackground(hFig));
    jItem.setSelected(isWhite);
  
 
    % Display Popup menu
    gui_popup(jPopup, hFig);
end