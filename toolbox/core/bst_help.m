function jHelp = bst_help(helpfile, isModal, figTitle, figSize, jHelp)
% BST_HELP: Display a help file in HTML format.
%
% USAGE:  jHelp = bst_help(helpfile, isModal=1, figTitle='Help', figSize=[510,590], jHelp=[new])
%         jHelp = bst_help(strHtml, ...)  

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
% Authors: Francois Tadel, 2008-2012

% Initializations
import java.awt.*;
import javax.swing.*;

% ===== PARSE INPUTS =====
if (nargin < 5) || isempty(jHelp)
    jHelp = [];
end
if (nargin < 4) || isempty(figSize) 
    figSize = [510,590];
end
if (nargin < 3) || isempty(figTitle) 
    figTitle = 'Help';
end
if (nargin < 2) || isempty(isModal)
    isModal = 1;
end
if (helpfile(1) == '<')
    % Get HTML help string
    strHtml = helpfile;
    helpfile = [];
else
    % Figure title
    figTitle = [figTitle ': ' helpfile];
    % Get documents path
    helppath = bst_fullfile(bst_get('BrainstormDocDir'), 'help');
    % Get full filename
    helpfile = bst_fullfile(helppath, helpfile);
end

% ===== DIALOG INITIALIZATION =====
jBstFrame = bst_get('BstFrame');
% Create a new window
if isempty(jHelp)
    jFrame = java_create('javax.swing.JDialog', 'Ljava.awt.Frame;Ljava.lang.String;Z', jBstFrame, figTitle, isModal);
    jFrame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
    jFrame.setPreferredSize(Dimension(figSize(1), figSize(2)));
    jPanelMain = jFrame.getContentPane();
% Re-use an existing window
else
    jFrame = jHelp.jFrame;
    jPanelMain = jFrame.getContentPane();
    jPanelMain.removeAll();
end

% === HELP TEXT AREA ===
% Create HTML viewer component
jTextHtml = JEditorPane();
jTextHtml.setEditable(false);
% Add an html editor kit
kit = javax.swing.text.html.HTMLEditorKit();
jTextHtml.setEditorKit(kit);
% Set content
if ~isempty(helpfile)
    jTextHtml.setPage(java.net.URL(['file:///' helpfile]));
else
    doc = kit.createDefaultDocument();
    jTextHtml.setDocument(doc);
    %jTextHtml.setContentType('text/html');
    jTextHtml.setText(strHtml);
end
% Callback when clicking on hyperlinks
java_setcb(jTextHtml, 'HyperlinkUpdateCallback', @HyperTextUpdate);
% Enclose in scroll panel
jScrollText = java_create('javax.swing.JScrollPane', 'Ljava.awt.Component;', jTextHtml);
jPanelMain.add(jScrollText, BorderLayout.CENTER);

% === FOOTER ===
% Add a "Close" button
jButtonClose = JButton('Close');
java_setcb(jButtonClose, 'ActionPerformedCallback', @CloseDialog);
jPanelMain.add(jButtonClose, BorderLayout.SOUTH);

% Display figure
jFrame.pack();
jFrame.setLocationRelativeTo(jFrame.getParent());
jFrame.setVisible(1);

% Return handle
jHelp.close  = @CloseDialog;
jHelp.jFrame = jFrame;


%% =================================================================================================
%  ====== CALLBACKS ================================================================================ 
%  =================================================================================================
%% ===== CLOSE DIALOG =====
    function CloseDialog(varargin)
        drawnow
        % If dialog was already closed
        if ~jFrame.isVisible()
            return
        end
        % Release mutex
        bst_mutex('release', 'Help');
        % Close dialog
        jFrame.dispose();
    end

%% ===== HYPERTEXT =====
    function HyperTextUpdate(h, ev)
        % If user clicked link
        if (ev.getEventType() == ev.getEventType().ACTIVATED)
            % Remove the 'Always on top' attribute
            jFrame.setAlwaysOnTop(0);
            % Display web page with Matlab browser
            web(char(ev.getURL()), '-browser');
        end
    end
end





