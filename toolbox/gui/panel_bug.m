function varargout = panel_bug( varargin )
% PANEL_BUG: Configure and send bug report when an error occurs.
%
% USAGE:  [bstPanel] = panel_bug('CreatePanel')
%                      panel_bug('ClosePanel')
%                      panel_bug('SendBugReport', msg)

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

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel() %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    panelName = 'Bug';
      
    % Create main main panel
    jPanelNew = gui_river([10,5], [15,20,15,15]);

    % ENABLE CHECKBOX
    jEnableCheckbox = JCheckBox('Send a bug report when an error occurs');
    jPanelNew.add(jEnableCheckbox);
    
    % SMTP SERVER
    jPanelNew.add('p', JLabel('SMTP server (eg. smtp.yourdomain.com):'));
    jTextSmtpServer = JTextField();
    jPanelNew.add('br hfill', jTextSmtpServer);
    
    % EMAIL ADRESS
    jPanelNew.add('p', JLabel('Your email address:'));
    jTextUserEmail = JTextField();
    jPanelNew.add('br hfill', jTextUserEmail);
    
    % ===== Validation buttons =====
    % Cancel
    jButtonCancel = JButton('Cancel');
    java_setcb(jButtonCancel, 'ActionPerformedCallback', @ClosePanel);
    jPanelNew.add('p right', jButtonCancel);
    % Save
    jButtonSave = JButton('Save');
    java_setcb(jButtonSave, 'ActionPerformedCallback', @SaveOptions);
    jPanelNew.add(jButtonSave);

    
    % ===== LOAD OPTIONS =====
    LoadOptions();
    
    % Create a mutex for this panel
    bst_mutex('create',panelName);
    
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jEnableCheckbox',     jEnableCheckbox, ...
                                  'jTextSmtpServer',     jTextSmtpServer, ...
                                  'jTextUserEmail',      jTextUserEmail));
      
                              
%% =================================================================================
%  === PANEL CALLBACKS  ============================================================
%  =================================================================================
    %% ===== Load Options =====
    function LoadOptions(varargin)
        % Get saved options
        BugReportOptions = bst_get('BugReportOptions');
        % Update controls
        jEnableCheckbox.setSelected(BugReportOptions.isEnabled);
        jTextSmtpServer.setText(BugReportOptions.SmtpServer);
        jTextUserEmail.setText(BugReportOptions.UserEmail);  
    end

    %% ===== Save Options =====
    function SaveOptions(varargin)
        % Get saved options
        BugReportOptions = bst_get('BugReportOptions');
        % Get controls values
        BugReportOptions.isEnabled  = jEnableCheckbox.isSelected();
        BugReportOptions.SmtpServer = char(jTextSmtpServer.getText());
        BugReportOptions.UserEmail  = char(jTextUserEmail.getText());
        % Update options
        bst_set('BugReportOptions', BugReportOptions);
        % Close "Options" window
        ClosePanel();
    end
end

%% ===== GET PANEL CONTENTS =====
% GET Panel contents in a structure
function s = GetPanelContents() %#ok<DEFNU>
    s = [];
end

%% ===== CLOSE PANEL =====
function ClosePanel(varargin)
    panelName = 'Bug';
    % Hide panel
    gui_hide(panelName);
    % Release mutex
    bst_mutex('release',panelName);
end

    
%% =================================================================================
%  === SEND BUG REPORT =============================================================
%  =================================================================================
function SendBugReport(msg) %#ok<DEFNU>
    % ================================================================
    % Adress where the bug reports are sent
    BugReportsRecipient = 'francois.tadel@chups.jussieu.fr';
    % ================================================================
    
    % Get bug reporting options
    BugReportOptions = bst_get('BugReportOptions');
    % Check that bug report sending is activated
    if ~BugReportOptions.isEnabled
        return
    end
    % Check if bug reporting is well configured
    if isempty(BugReportOptions.SmtpServer) || isempty(BugReportOptions.UserEmail)
        java_dialog('error', ['Please configure bug reporting options.' 10 'Menu: Options > Bug reporting...'], 'Bug reporting');
        return
    end
    % Bug report progress bar
    bst_progress('start', 'Brainstorm error', 'Sending bug report...');
    drawnow
    % Get Brainstorm version
    bstVersion = bst_get('Version');
    % Build mail body
    mailBody = ['Date: ' date 10 ...
                'From: ' BugReportOptions.UserEmail 10 ...
                'Matlab version: ' version 10 ...
                'Brainstorm version: ' bstVersion.Version 10 ...
                '-------------------------------------------------------------' 10 ...
                msg];
    % Configure SMTP
    setpref('Internet', 'E_mail',      BugReportOptions.UserEmail);
    setpref('Internet', 'SMTP_Server', BugReportOptions.SmtpServer);
    % Send mail
    try
        sendmail(BugReportsRecipient, 'Brainstorm bug report', mailBody);
    catch
        bst_progress('stop');
        java_dialog('error', ...
                    ['Could not send bug report.' 10 10 ...
                     'To enable bug reporting:' 10 ...
                     '1) Check the bug reporting configuration (Help>Bug reporting...),' 10 ...
                     '2) Configure your firewall to allow Matlab access on port 25 (SMTP),' 10 ...
                     '3) Check that you do not have an antivirus that filters the port 25,' 10 ...
                     '4) It the error persists, disable this option.' 10 ...
                     '_______________________________________________' 10 ...
                     lasterr 10 ...
                     '_______________________________________________'], 'Bug reporting');
    end
    % Hide progress bar
    bst_progress('stop');
end














