function varargout = panel_load_remote_protocol(varargin)
% PANEL_LOAD_REMOTE_PROTOCOL: Get a list of available remote protocols and select one
% USAGE:  [bstPanelNew, panelName] = panel_load_remote_protocol('CreatePanel')

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
function [bstPanelNew, panelName] = CreatePanel() %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.list.*;
    
    % Constants
    panelName = 'LoadRemoteProtocol';
    
    % Create main panel
    jPanelNew = gui_river([0 0], [0 0 0 0], 'Remote Protocols');
    
    % Main panel
    jPanelMain = gui_river([5 0], [0 2 0 2]);
    jPanelNew.add('br hfill', jPanelMain);
    
    % Font size for the lists
    fontSize = round(10 * bst_get('InterfaceScaling') / 100);
    
    % List of protocols
    jListProtocols = JList();
    jListProtocols.setCellRenderer(BstStringListRenderer(fontSize));
    jListProtocols.setPreferredSize(java_scaled('dimension', 200, 250));
    jPanelProtocolsScrollList = JScrollPane();
    jPanelProtocolsScrollList.getLayout.getViewport.setView(jListProtocols);
    jPanelMain.add('hfill', jPanelProtocolsScrollList);

    % Buttons
    jPanelButtons = gui_river([5 0], [0 2 0 2]);
    gui_component('Button', jPanelButtons, 'right', 'Load protocol', [], [], @ButtonLoadProtocol_Callback);
    jPanelNew.add('br hfill', jPanelButtons);

    % ===== LOAD DATA =====
    UpdateProtocolsList();

    % ===== CREATE PANEL =====   
    bst_mutex('create', panelName); % Return a mutex to wait for panel close
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jListProtocols',  jListProtocols));

    %% ===== UPDATE PROTOCOLS LIST =====
    function UpdateProtocolsList()
        % Load protocols
        protocols = LoadProtocols();

        % Create a new empty list
        listModel = java_create('javax.swing.DefaultListModel');
        % Add an item in list for each protocol
        for i = 1:length(protocols)
            listModel.addElement(protocols{i});
        end
        % Update list model
        jListProtocols.setModel(listModel);

        drawnow;
    end


    %% =================================================================================
    %  === CONTROLS CALLBACKS  =========================================================
    %  =================================================================================

    %% ===== BUTTON: LOAD PROTOCOL =====
    function ButtonLoadProtocol_Callback(varargin)
        protocol = jListProtocols.getSelectedValue();
        if isempty(protocol)
            return;
        end

        gui_hide(panelName); % Close panel
        bst_mutex('release', panelName); % Release the MUTEX
    end

    %% ===== LOAD PROTOCOLS =====
    function protocols = LoadProtocols()
        protocols = {'Protocol1', 'Protocol2'};
        disp('TODO: Get list of protocols');
    end

    
end


