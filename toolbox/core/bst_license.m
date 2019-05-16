function isOk = bst_license()
% BST_LICENSE: Display Brainstorm license and ask user to approve it.

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
% Authors: Francois Tadel, 2008-2019

% Initializations
import java.awt.*;
import javax.swing.*;
import javax.swing.text.*;
import org.brainstorm.icon.*;
isOk = 0;
% Get doc path
docPath = bst_get('BrainstormDocDir');
% Background color
bgColor = Color(0.2039, 0.3059, 0.4275);

% ===== READ LICENSE FILE =====
% Read license file
fid = fopen(fullfile(docPath, 'license.html'), 'r');
strLicense = char(fread(fid, Inf, 'char')');
fclose(fid);
% Add some attributes
strLicense = strrep(strLicense, '<body', '<body style="color: rgb(190, 203, 149); background-color: rgb(52, 78, 109);"');

% ===== DIALOG INITIALIZATION =====
% Main JFrame
jFrame = java_create('javax.swing.JFrame', 'Ljava.lang.String;', 'License agreement');
jFrame.setAlwaysOnTop(1);
jFrame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
% Set icon
jFrame.setIconImage(IconLoader.ICON_APP.getImage());
% Set callback
java_setcb(jFrame, 'WindowClosingCallback', @CloseDialog);
jFrame.setPreferredSize(java_scaled('dimension', 510, 590));
jPanelMain = jFrame.getContentPane();

% === HEADER PANEL ===
jPanelHeader = gui_component('Panel');
jPanelHeader.setBackground(bgColor);
    % Get logo filename
    logo_file = bst_fullfile(docPath, 'logo_license.gif');
    % Image in label
    jLabel = JLabel();
    jLabel.setIcon(javax.swing.ImageIcon(logo_file));
    jPanelHeader.add(jLabel, BorderLayout.CENTER);
jPanelMain.add(jPanelHeader, BorderLayout.NORTH);

% === LICENSE TEXT AREA ===
% Create HTML viewer component
jTextLicense = JEditorPane();
jTextLicense.setContentType('text/html');
jTextLicense.setText(strLicense);
jTextLicense.setEditable(false);
jTextLicense.setBackground(bgColor);
java_setcb(jTextLicense, 'HyperlinkUpdateCallback', @HyperTextUpdate);
jScrollText = JScrollPane(jTextLicense);
jPanelMain.add(jScrollText, BorderLayout.CENTER);

% === AGREE BUTTONS ===
jPanelAgree = gui_river([10,10], [10,20,0,20]);
jPanelAgree.setPreferredSize(java_scaled('dimension', 500, 60));
    % Text
    gui_component('label', jPanelAgree, '', 'Do you agree with this copyright notice ?');
    gui_component('label', jPanelAgree, 'hfill', ' ');
    % BUttons
    gui_component('button', jPanelAgree, '', '<HTML><B>Cancel</B>', [], [], @jButtonCancel_Callback);
    gui_component('button', jPanelAgree, '', '<HTML><B>I agree</B>', [], [], @jButtonAgree_Callback);
jPanelMain.add(jPanelAgree, BorderLayout.SOUTH);
    
% Display figure
jFrame.pack();
jFrame.setLocationRelativeTo(jFrame.getParent());
jFrame.setVisible(1);

% Create mutex
bst_mutex('create', 'License');
% Wait for mutex (release when window is closed)
bst_mutex('waitfor', 'License');    



%% =================================================================================================
%  ====== CALLBACKS ================================================================================ 
%  =================================================================================================
%% ===== AGREE =====
    function jButtonAgree_Callback(varargin)
        isOk = 1;
        % Close dialog
        CloseDialog();
    end

%% ===== CANCEL =====
    function jButtonCancel_Callback(varargin)
        % Close dialog
        CloseDialog();
    end

%% ===== CLOSE DIALOG =====
    function CloseDialog(varargin)
        % Release mutex
        bst_mutex('release', 'License');
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





