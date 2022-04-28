function hComp = bst_javacomponent(hParent, compType, compPos, compText, compIcon, compTooltip, compCallback, compTag, compSelected, fontSize)
% BST_JAVACOMPONENT: Adds a component to a Matlab figure (buttons, ...)

% DESCRIPTION:
%    Replaces deprecated javacomponent in versions of Matlab >= 2020a

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
% Authors: Francois Tadel, 2020

% Parse inputs
if (nargin < 3) || isempty(compPos)
    compPos = [0, 0, .01, .01]; 
end
if (nargin < 4),  compText     = []; end
if (nargin < 5),  compIcon     = []; end
if (nargin < 6),  compTooltip  = []; end
if (nargin < 7),  compCallback = []; end
if (nargin < 8),  compTag      = []; end
if (nargin < 9),  compSelected = 0;  end
% Get interface scaling
InterfaceScaling = bst_get('InterfaceScaling');
% Default font size: depends on the system
if (nargin < 10)
    if strncmp(computer,'MAC',3)
        fontSize = 12 * InterfaceScaling / 100;
    else
        fontSize = 11 * InterfaceScaling / 100;
    end
end
% Get figure background color
if strcmpi(get(hParent, 'Type'), 'Figure')
    hFig = hParent;
    bgColor = get(hFig, 'Color');
else
    hFig = get(hParent, 'Parent');
    bgColor = get(hParent, 'BackgroundColor');
end
% If the background is too dark, use a light grey
if (sum(bgColor) < 0.5)
    bgColor = [.8 .8 .8];
end

% ===== OLD: JAVACOMPONENTS ======
% Older version of Matlab (< 2019b): use java components
if bst_get('isJavacomponent')
    switch (compType)
        case 'label'
            jComp = java_create('javax.swing.JLabel');
        case 'button'
            jComp = java_create('javax.swing.JButton');
            jComp.setMargin(java.awt.Insets(0,0,0,0));
        case 'toggle'
            jComp = java_create('javax.swing.JToggleButton');
            jComp.setMargin(java.awt.Insets(0,0,0,0));
            if compSelected
                jComp.setSelected(compSelected);
            end
    end
    % Icon
    if ~isempty(compIcon)
        if (InterfaceScaling ~= 100)
            compIcon = org.brainstorm.icon.IconLoader.scaleIcon(compIcon, InterfaceScaling / 100);
        end
        jComp.setIcon(compIcon);
    end
    % Create Matlab/Java object
    [jComp, hComp] = javacomponent(jComp, compPos, hParent);
    % Generic properties
    jComp.setFocusPainted(0);
    jComp.setFocusable(0);
    jComp.setOpaque(0);
    jComp.setBackground(java.awt.Color(bgColor(1), bgColor(2), bgColor(3)));
    % Text
    if ~isempty(compText)
        jComp.setText(compText);
        jFontDefault = bst_get('Font');
        jComp.setFont(java.awt.Font(jFontDefault.getFamily(), java.awt.Font.PLAIN, fontSize));
    end
    % Tooltip
    if ~isempty(compTooltip)
        jComp.setToolTipText(compTooltip);
    end
    % Callback
    if ~isempty(compCallback)
        java_setcb(jComp, 'ActionPerformedCallback', compCallback);
    end
    % Units
    set(hComp, 'Units', 'pixels');
    
    
% ===== NEW >= 2019b =====
% Newer matlab versions: use dedicated functions
else
    switch (compType)
        case 'label'
            hComp = uicontrol(hParent, ...
                'Style',    'text', ...
                'Units',    'pixels', ...
                'Position', compPos, ...
                'BackgroundColor', bgColor);
        case 'text'
            hComp = uicontrol(hParent, ...
                'Style',    'edit', ...
                'Units',    'pixels', ...
                'Position', compPos, ...
                'BackgroundColor', bgColor);
        case 'button'
            hComp = uicontrol(hParent, ...
                'Style',    'pushbutton', ...
                'Units',    'pixels', ...
                'Position', compPos, ...
                'BackgroundColor', bgColor);
        case 'toggle'
            hComp = uicontrol(hParent, ...
                'Style',    'togglebutton', ...
                'Units',    'pixels', ...
                'Position', compPos, ...
                'BackgroundColor', bgColor);
            if compSelected
                set(hComp, 'Value', 1);
            end
    end
    % Icon
    if ~isempty(compIcon)
        % Force calling the scaling function to get an image object easier to process
        compIcon = org.brainstorm.icon.IconLoader.scaleIcon(compIcon, InterfaceScaling / 100);
        % Get pixel array
        argb = typecast(compIcon.getImage().getBufferedImage().getRaster().getDataBuffer().getData(), 'uint8');
        w = compIcon.getIconWidth();
        h = compIcon.getIconHeight();
        argb = reshape(argb, 4, w, h);
        % Apply alpha layer on figure background
        alpha = double(argb(4,:,:)) ./ 255;
        rgb = double(argb(1:3,:,:)) ./ 255;
        bg = bsxfun(@times, ones(3, w, h), bgColor');
        rgb = bst_bsxfun(@times, rgb, alpha) + bst_bsxfun(@times, bg, 1-alpha);
        % Set button image
        rgb = permute(rgb, [3,2,1]);
        set(hComp, 'CData', rgb);
    end
    % Text
    if ~isempty(compText)
        jFontDefault = bst_get('Font');
        set(hComp, 'String', compText, 'FontName', char(jFontDefault.getFamily()), 'FontUnits', 'pixels', 'FontSize', fontSize, 'FontWeight', 'bold');
    end
    % Tooltip
    if ~isempty(compTooltip)
        set(hComp, 'Tooltip', compTooltip);
    end
    % Callback
    if ~isempty(compCallback)
        set(hComp, 'Callback', compCallback);
    end
end

% Tag
if ~isempty(compTag)
    set(hComp, 'Tag', compTag);
end


