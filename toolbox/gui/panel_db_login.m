function varargout = panel_db_login(varargin)
% PANEL_DB_LOGIN: Login or Register dialog for remote database
% 
% USAGE:  bstPanelNew = panel_export_bids('CreatePanel')
%                   s = panel_export_bids('GetPanelContents')

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
% Authors: Martin Cousineau, 2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(mode)  %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    
    panelName = 'DbLoginRegister';
    
    if nargin >= 1 && ~isempty(mode) && strcmpi(mode, 'register')
        isRegister = 1;
    else
        isRegister = 0;
    end
    
    % Create main main panel
    jPanelMain = java_create('javax.swing.JPanel');
    jPanelMain.setLayout(java_create('java.awt.GridBagLayout'));
    c = GridBagConstraints();
    c.fill = GridBagConstraints.BOTH;
    c.gridx = 1;
    c.weightx = 1;
    c.weighty = 1;
    c.insets = Insets(3,5,3,5);
    
    % ===== PANEL CONTENT =====
    jPanelProj = gui_component('Panel');
    jPanelProj.setLayout(BoxLayout(jPanelProj, BoxLayout.Y_AXIS));
    jPanelOpt = gui_river([2,2], [2,4,2,4]);
    gui_component('Label', jPanelOpt, '', 'Server URL: ');
    jTextServerUrl = gui_component('text', jPanelOpt, 'hfill', '');
    jPanelProj.add(jPanelOpt);
    
    if isRegister
        jPanelOpt = gui_river([2,2], [2,4,2,4]);
        gui_component('Label', jPanelOpt, 'br', 'First name: ');
        jTextFirstName = gui_component('text', jPanelOpt, 'hfill', '');
        jPanelProj.add(jPanelOpt);
        jPanelOpt = gui_river([2,2], [2,4,2,4]);
        gui_component('Label', jPanelOpt, 'br', 'Last name: ');
        jTextLastName = gui_component('text', jPanelOpt, 'hfill', '');
        jPanelProj.add(jPanelOpt);
    else
        jTextFirstName = [];
        jTextLastName = [];
    end
    
    jPanelOpt = gui_river([2,2], [2,4,2,4]);
    gui_component('Label', jPanelOpt, 'br', 'Email address: ');
    jTextEmail = gui_component('text', jPanelOpt, 'hfill', '');
    jPanelProj.add(jPanelOpt);
    jPanelOpt = gui_river([2,2], [2,4,2,4]);
    gui_component('label', jPanelOpt, 'br', 'Password: ');
    jTextPassword = gui_component('password', jPanelOpt, 'hfill', '');
    jPanelProj.add(jPanelOpt);
    
    if isRegister
        jPanelOpt = gui_river([2,2], [2,4,2,4]);
        gui_component('label', jPanelOpt, 'br', 'Confirm password: ');
        jTextPassword2 = gui_component('password', jPanelOpt, 'hfill', '');
        jPanelProj.add(jPanelOpt);
    else
        jTextPassword2 = [];
    end
    
    jPanelMain.add(jPanelProj, c);
    
    % ===== VALIDATION BUTTON =====
    jPanelOk = gui_river();
    if isRegister
        btnLabel = 'Register';
    else
        btnLabel = 'Login';
    end
    gui_component('Button', jPanelOk, 'br right', btnLabel, [], [], @ButtonOk_Callback);
    c.gridy = 2;
    jPanelMain.add(jPanelOk, c);

    % ===== PANEL CREATION =====
    % Put everything in a big scroll panel
    jPanelScroll = javax.swing.JScrollPane(jPanelMain);
    % Controls list
    ctrl = struct('jTextServerUrl', jTextServerUrl, ...
                  'jTextFirstName', jTextFirstName, ...
                  'jTextLastName',  jTextLastName, ...
                  'jTextEmail',     jTextEmail, ...
                  'jTextPassword',  jTextPassword, ...
                  'jTextPassword2', jTextPassword2);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelScroll, ctrl);
    
    UpdatePanel();
    
    
%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)
        if isRegister
            disp('TODO: Register');
            java_dialog('msgbox', ['Your registration request was sent to the database administrator.' 10 'You will be notified by email once it is approved.'], 'Register');
        else
            disp('TODO: Login');
        end
        
        gui_hide(panelName);
    end

%% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)
        %TODO
    end

end


%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'DbLoginRegister');
    
    %TODO
    s = [];
end

