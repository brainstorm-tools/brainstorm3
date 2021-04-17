function gui_update_toggle( hButtons )
% GUI_UPDATE_TOGGLE: Update Matlab toggle button icon color (selected or not).

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
% Authors: Francois Tadel, 2008-2010

% Get default colors
jColorBg1 = javax.swing.UIManager.getColor('ToggleButton.background');
jColorBg2 = [];
jColorSel = javax.swing.UIManager.getColor('ToggleButton.select');
if isempty(jColorSel) 
    jColorBg1  = javax.swing.UIManager.getColor('Button.background');
end
if isempty(jColorSel) 
    jColorSel = javax.swing.UIManager.getColor('Button.select');
end

% Get button type
isToolbar = (strcmpi(get(hButtons(1), 'Type'), 'uitoggletool'));

% If Not all the colors defaults are defined
if isempty(jColorSel) || isempty(jColorBg1)
    % Get current look and feel
    lf = javax.swing.UIManager.getLookAndFeel();   
    % Switch between look and feels
    switch lower(char(lf.getName()))
        case 'windows'
            % Toobar button
            if isToolbar
                % Check if "XP" or "Classic" style
                if ~isempty(jColorBg1) && (jColorBg1.getRed() == 236)
                    % XP Style
                    jColorBg1 = java.awt.Color(uint8(236), uint8(233), uint8(216));
                    jColorBg2 = [];
                    jColorSel = java.awt.Color(uint8(255), uint8(255), uint8(255));
                else
                    % Classic style
                    jColorBg1 = java.awt.Color(uint8(212), uint8(208), uint8(200));
                    jColorBg2 = [];
                    jColorSel = java.awt.Color(uint8(233), uint8(231), uint8(227));
                end
            % Normal uicontrol
            else
                % Check if "XP" or "Classic" style
                if ~isempty(jColorBg1) && (jColorBg1.getRed() == 236)
                    % XP Style
                    jColorBg1 = java.awt.Color(uint8(248), uint8(248), uint8(246));
                    jColorBg2 = java.awt.Color(uint8(236), uint8(233), uint8(216));
                    jColorSel = java.awt.Color(uint8(228), uint8(227), uint8(220));
                else
                    % Classic style
                    jColorBg1 = java.awt.Color(uint8(212), uint8(208), uint8(200));
                    jColorBg2 = [];
                    jColorSel = java.awt.Color(uint8(233), uint8(231), uint8(227));
                end
            end
        otherwise
            return
    end
end

% Process all buttons
for i = 1:length(hButtons)
    isSelected = (~isToolbar && (get(hButtons(i), 'Value')==1)) || (isToolbar && strcmpi(get(hButtons(i), 'State'), 'on'));
    % If toggle button selected
    if isSelected
        % Replace color
        replaceColor(hButtons(i), jColorBg1, jColorSel);
        if ~isempty(jColorBg2)
            replaceColor(hButtons(i), jColorBg2, jColorSel);
        end
    else
        % Replace color
        replaceColor(hButtons(i), jColorSel, jColorBg1);
        if ~isempty(jColorBg2)
            replaceColor(hButtons(i), jColorBg2, jColorBg1);
        end
    end
end
end


% Replace color
function replaceColor(hButton, jColorSrc, jColorDest)
    % Get button color
    CData = get(hButton, 'CData');
    if isempty(CData)
        return
    end
    % Replace color
    [iRep,jRep] = find((CData(:,:,1) == jColorSrc.getRed()) & (CData(:,:,2) == jColorSrc.getGreen()) & (CData(:,:,3) == jColorSrc.getBlue()));
    if ~isempty(iRep)
        CData(sub2ind(size(CData), iRep, jRep, 1*ones(size(iRep)))) = jColorDest.getRed();
        CData(sub2ind(size(CData), iRep, jRep, 2*ones(size(iRep)))) = jColorDest.getGreen();
        CData(sub2ind(size(CData), iRep, jRep, 3*ones(size(iRep)))) = jColorDest.getBlue();
        % Update button color
        set(hButton, 'CData', CData);
        drawnow
    end
end
