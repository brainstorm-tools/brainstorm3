function jComp = gui_component(compType, jParent, constrain, compText, compOptions, compTooltip, compCallback, fontSize)
% GUI_COMPONENT: Create a Java/Swing control, and add it to an existing component.

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
% Authors: Francois Tadel, 2010-2019

% Java imports
import org.brainstorm.icon.*;
% Parse inputs
if (nargin < 2),  jParent      = []; end
if (nargin < 3),  constrain    = []; end
if (nargin < 4),  compText     = []; end
if (nargin < 5),  compOptions  = []; end
if (nargin < 6),  compTooltip  = []; end
if (nargin < 7),  compCallback = []; end
% Default font size: depends on the system
if (nargin < 8)
    if strncmp(computer,'MAC',3)
        fontSize = 12;
    else
        fontSize = 11;
    end
end
% Constants
jScroll = [];
callbackName = 'ActionPerformedCallback';

% Get options
compIcon   = [];
compInsets = [];
compSize   = [];
compAlign  = [];
compGroup  = [];
compModel  = [];
if ~isempty(compOptions)
    if ~iscell(compOptions)
        compOptions = {compOptions};
    end
    for i = 1:length(compOptions)
        switch class(compOptions{i})
            case 'java.awt.Dimension',      compSize   = compOptions{i};
            case 'java.awt.Insets',         compInsets = compOptions{i};
            case 'javax.swing.ImageIcon',   compIcon   = compOptions{i};
            case 'javax.swing.ButtonGroup', compGroup  = compOptions{i};
            case 'double',                  compAlign  = compOptions{i};
            case 'cell',                    compModel  = compOptions{i};
            otherwise,  disp(['GUI> Unknown option type "' class(compOptions{i}) '".']);
        end
    end
end

% Standardize font size
if isempty(fontSize)
    jFont = [];
elseif isnumeric(fontSize)
    jFont = bst_get('Font', fontSize);
else
    jFont = fontSize;
end

% Create component
switch lower(compType)
    case 'label'
        jComp = java_create('javax.swing.JLabel');
        callbackName = 'MouseClickedCallback';
    case 'texttime'
        jComp = java_create('javax.swing.JTextField');
        jComp.setPreferredSize(java_scaled('dimension', 54, 20));
        jComp.setHorizontalAlignment(javax.swing.JTextField.RIGHT);
        callbackName = 'KeyTypedCallback';
    case 'textfreq'
        jComp   = java_scaled('textarea', 6, 12);
        jScroll = java_create('javax.swing.JScrollPane', 'Ljava.awt.Component;', jComp);
        callbackName = 'FocusLostCallback';
        if isempty(jFont) && bst_iscompiled()
            jFont = bst_get('Font', 11, 'Arial');
        end
    case 'textarea'
        jComp   = java_scaled('textarea', 15, 30);
        jScroll = java_create('javax.swing.JScrollPane', 'Ljava.awt.Component;', jComp);
        callbackName = 'FocusLostCallback';
        if isempty(jFont) && bst_iscompiled()
            jFont = bst_get('Font', 11, 'Arial');
        end
    case 'text'
        jComp = java_create('javax.swing.JTextField');
        jComp.setPreferredSize(java_scaled('dimension', 54, 20));
        callbackName = 'KeyTypedCallback';
    case 'spinner'
        jComp = java_create('javax.swing.JSpinner');
        jComp.setPreferredSize(java_scaled('dimension', 57, 20));
        jComp.getEditor().getFormat().setGroupingSize(0);
        callbackName = 'MouseReleasedCallback';
        if ~isempty(jFont)
            jComp.setFont(jFont);
        end
    case 'button'
        jComp = java_create('javax.swing.JButton');
        jComp.setFocusPainted(0);
    case 'toggle'
        jComp = java_create('javax.swing.JToggleButton');
        jComp.setFocusPainted(0);
    case 'checkbox'
        jComp = java_create('javax.swing.JCheckBox');
    case 'radio'
        jComp = java_create('javax.swing.JRadioButton');
    case 'combobox'
        if ~isempty(compModel)
            %jComp = java_create('javax.swing.JComboBox', 'Ljavax.swing.ComboBoxModel;', compModel);
            if exist('javaObjectEDT', 'builtin')
                jComp = javaObjectEDT('javax.swing.JComboBox', compModel);
            else
                jComp = javax.swing.JComboBox(compModel);
            end
        else
            jComp = java_create('javax.swing.JComboBox');
        end
        jComp.setBackground(javax.swing.UIManager.getColor('Panel.background'));
        jComp.setBorder([]);
        if ~isempty(jFont)
            jComp.setFont(jFont);
        elseif ispc
            jComp.setFont(bst_get('Font', 12, 'Segoe UI'));
        else
            jComp.setFont(bst_get('Font', 12));
        end
        jComp.invalidate();
        jComp.repaint();
        callbackName = 'ItemStateChangedCallback';
    case 'menubar'
        jComp = java_create('javax.swing.JMenuBar');
    case 'menu'
        jComp = java_create('javax.swing.JMenu');
        callbackName = 'MenuSelectedCallback';
    case 'menuitem'
        jComp = java_create('javax.swing.JMenuItem');
        %jFont = [];
    case 'radiomenuitem'
        jComp = java_create('javax.swing.JRadioButtonMenuItem');
        %jFont = [];
    case 'checkboxmenuitem'
        jComp = java_create('javax.swing.JCheckBoxMenuItem');
        %jFont = [];
    case 'toolbar'
        jComp = java_create('javax.swing.JToolBar');
        jComp.setBorderPainted(0);
        jComp.setFloatable(0);
        jComp.setRollover(1);
    case 'toolbarbutton'
        jComp = java_create('javax.swing.JButton');
        if ~isempty(compSize)
            jComp.setPreferredSize(compSize);
            jComp.setMaximumSize(compSize);
            jComp.setMinimumSize(compSize);
        end
        jComp.setFocusable(0);
        jComp.setOpaque(0);
    case 'toolbartoggle'
        jComp = java_create('javax.swing.JToggleButton');
        if ~isempty(compSize)
            jComp.setPreferredSize(compSize);
            jComp.setMaximumSize(compSize);
            jComp.setMinimumSize(compSize);
        end
        jComp.setFocusable(0);
        jComp.setOpaque(0);
    case 'panel'
        jComp = java_create('javax.swing.JPanel');
        jComp.setLayout(java_create('java.awt.BorderLayout'));
    otherwise
        error(['Unknown component type: "' compType '"']);
end

% Set properties
if ~isempty(compText)
    jComp.setText(compText);
end
if ~isempty(jFont)
    jComp.setFont(jFont);
end
if ~isempty(compIcon)
    InterfaceScaling = bst_get('InterfaceScaling');
    if (InterfaceScaling ~= 100)
        jComp.setIcon(IconLoader.scaleIcon(compIcon, InterfaceScaling / 100));
    else
        jComp.setIcon(compIcon);
    end
end
if ~isempty(compTooltip)
    jComp.setToolTipText(compTooltip);
end
if ~isempty(compSize)
    jComp.setPreferredSize(compSize);
end
if ~isempty(compInsets)
    jComp.setMargin(compInsets);
end
if ~isempty(compAlign)
    jComp.setHorizontalAlignment(compAlign);
end
if ~isempty(compGroup)
    compGroup.add(jComp);
end
% Add callback
if ~isempty(compCallback)
    java_setcb(jComp, callbackName, compCallback);
end
% Add to parent
if ~isempty(jParent)
    % Add scroll panel instead of component
    if ~isempty(jScroll)
        jCompAdd = jScroll;
    else
        jCompAdd = jComp;
    end
    % Add component to parent
    if isempty(constrain)
        jParent.add(jCompAdd);
    elseif ischar(constrain)
        jParent.add(constrain, jCompAdd);
    else
        jParent.add(jCompAdd, constrain);
    end
end

