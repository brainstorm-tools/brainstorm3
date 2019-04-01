function jSplash = bst_splash(action)
% BST_SPLASH:  Display/hide the Brainstorm splash screen.
%
% USAGE: bst_splash('show')
%        bst_splash('hide')

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
% Authors: Francois Tadel, 2008-2018

import org.brainstorm.icon.*;
global GlobalData BrainstormSplash;

% Do nothing in case of server mode
if ~isempty(GlobalData) && ~isempty(GlobalData.Program) && isfield(GlobalData.Program, 'GuiLevel') && (GlobalData.Program.GuiLevel == -1)
    jSplash = [];
    return;
end

% Select action
switch lower(action)
    case 'show'
        % If panel exist: show it
        if ~isempty(BrainstormSplash)
            BrainstormSplash.jDialog.setVisible(1);
            
        % Else: create it
        else
            % Main JFrame
            jSplash = java_create('javax.swing.JDialog', 'Ljava.awt.Frame;Ljava.lang.String;Z', [], 'Brainstorm', 0);
            jSplash.setUndecorated(1);
            jSplash.setAlwaysOnTop(1);
            jSplash.setDefaultCloseOperation(jSplash.DISPOSE_ON_CLOSE);
            frameW = 400;
            frameH = 226;
            jSplash.setPreferredSize(java.awt.Dimension(frameW, frameH));
            % Set icon
            try
                jSplash.setIconImage(IconLoader.ICON_APP.getImage());
            catch
                % Old matlab... just ignore...
            end
            % Main panel
            jPanel = gui_component('Panel');
            jPanel.setBorder(javax.swing.BorderFactory.createBevelBorder(javax.swing.border.BevelBorder.RAISED, java.awt.Color.lightGray, java.awt.Color.white, [], []));
            java_setcb(jPanel, 'MouseClickedCallback', @(h,ev)bst_splash('hide'));
            jSplash.getContentPane.add(jPanel);

            % Get logo path
            logo_file = bst_fullfile(bst_get('BrainstormDocDir'), 'logo_splash.gif');
            % Image in label
            jLabel = java_create('javax.swing.JLabel');
            jLabel.setIcon(javax.swing.ImageIcon(logo_file));
            jPanel.add(jLabel, java.awt.BorderLayout.CENTER);

            % Finalize figure layouts
            jSplash.pack();
            % Center on first screen
            try 
                ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
                jBounds = ge.getDefaultScreenDevice().getDefaultConfiguration().getBounds();
                frameX = (jBounds.getX() + jBounds.getWidth() - frameW) ./ 2;
                frameY = (jBounds.getY() + jBounds.getHeight() - frameH) ./ 2;
                jSplash.setLocation(frameX, frameY);
            catch
                jSplash.setLocationRelativeTo([]);
            end
            % Display figure
            jSplash.setVisible(1);
            BrainstormSplash.jDialog = jSplash;
        end
        % Update last call time
        BrainstormSplash.lastCall = clock();
        
    case 'hide'
        if ~isempty(BrainstormSplash)
            duration = etime(clock(), BrainstormSplash.lastCall);
            if (duration < 1.5)
                pause(1.5 - duration);
            end
            BrainstormSplash.jDialog.setVisible(0);
        end
end

end

