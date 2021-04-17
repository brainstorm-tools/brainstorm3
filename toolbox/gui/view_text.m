function jFrame = view_text( wndText, wndTitle, isFile, isWait )
% VIEW_TEXT: Display a text in a Java window.
%
% USAGE:  jFrame = view_text( wndText,  wndTitle='', isFile=0, isWait=0 )
%         jFrame = view_text( filename, wndTitle='', isFile=1, isWait=0 )

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
% Authors: Francois Tadel, 2008

% Java imports
import javax.swing.*;
import java.awt.*;
import org.brainstorm.icon.*;

% Parse inputs
if (nargin < 4) || isempty(isWait)
    isWait = 0;
end
if (nargin < 3) || isempty(isFile)
    isFile = 0;
end
if (nargin < 2) || isempty(wndTitle)
    wndTitle = 'Text viewer';
end

% Read input file
if isFile
    filename = wndText;
    fid = fopen(filename);
    wndText = fread(fid, [1 Inf], '*char');
    fclose(fid);
end

% Create Java window with a Text field to display this file
jFrame = java_create('javax.swing.JFrame', 'Ljava.lang.String;', wndTitle);
% Set window icon
jFrame.setIconImage(IconLoader.ICON_APP.getImage());
% Set close callback
jFrame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);

jTextArea = java_create('javax.swing.JTextArea', 'Ljava.lang.String;', wndText);
jTextArea.setEditable(0);
jTextArea.setBackground(Color(1,1,1));
jTextArea.setMargin(java_create('java.awt.Insets', 'IIII', 10,25,10,25));
jTextArea.setFont(bst_get('Font', 12, 'Courier New'));
jFrame.getContentPane.add(JScrollPane(jTextArea));

% Add OK button if need to wait
if isWait
    gui_component('button', jFrame.getContentPane(), BorderLayout.SOUTH, '<HTML><B>I agree</B>', [], [], @CloseDialog);
end

% Show window
jFrame.pack();
jFrame.setVisible(1);

% Get size available for windows
maxSize  = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment.getMaximumWindowBounds();
framSize = jFrame.getSize();
newWidth  = min(framSize.getWidth(),  maxSize.getWidth()  - 30);
newHeight = min(framSize.getHeight(), maxSize.getHeight() - 30);
% Resize window
jFrame.setSize(newWidth, newHeight);
    
% Wait until closed
if isWait
    % Bring to front
    jFrame.setAlwaysOnTop(1);
    % Set callback
    java_setcb(jFrame, 'WindowClosingCallback', @CloseDialog);
    % Create mutex
    bst_mutex('create', 'License');
    % Wait for mutex (release when window is closed)
    bst_mutex('waitfor', 'License');
end


%% ===== CLOSE CALLBACK =====
function CloseDialog(varargin)
    % Release mutex
    bst_mutex('release', 'License');
    % Close dialog
    jFrame.dispose();
end

end
    