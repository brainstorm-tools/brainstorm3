function varargout = panel_edit_groups(varargin)
% PANEL_EDIT_GROUPS:  Edit user group memberships.
% USAGE:  [bstPanelNew, panelName] = panel_edit_groups('CreatePanel')

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
    global GlobalData;
    % Constants
    panelName = 'EditGroups';
    
    % Create main main panel
    jPanelNew = gui_river([0 0], [0 0 0 0], 'Groups');
    
    % Create Group
    jPanelCreate = gui_river([5 0], [0 2 0 2]);
    gui_component('Text',  jPanelCreate, 'br hfill', '', [], [], []);
    gui_component('Button', jPanelCreate, [], 'Create Group', [], [], @ButtonCreateGroup_Callback);
    jPanelNew.add('br hfill', jPanelCreate);
    
    % Main panel
    jPanelMain = gui_river([5 0], [0 2 0 2]);
    jPanelNew.add('br hfill', jPanelMain);
    
    % Font size for the lists
    fontSize = round(10 * bst_get('InterfaceScaling') / 100);
    
    % List of groups
    jListGroups = JList();
    jListGroups.setCellRenderer(BstStringListRenderer(fontSize));
    java_setcb(jListGroups, 'ValueChangedCallback', @GroupListValueChanged_Callback);
    jPanelGroupsScrollList = JScrollPane();
    jPanelGroupsScrollList.getLayout.getViewport.setView(jListGroups);
    jPanelMain.add('hfill', jPanelGroupsScrollList);
    
    % List of members
    jPanelMembers = gui_river([5 0], [0 2 0 2], 'Members');
    jListMembers = JList();
    jListMembers.setCellRenderer(BstStringListRenderer(fontSize));
    jPanelMembersScrollList = JScrollPane();
    jPanelMembersScrollList.getLayout.getViewport.setView(jListMembers);
    jPanelMembers.add('hfill', jPanelMembersScrollList);
    jPanelMain.add('hfill', jPanelMembers);
    
    % Buttons
    jPanelButtons = gui_river([5 0], [0 2 0 2]);
    gui_component('Button', jPanelButtons, [], 'Add', [], [], @ButtonAddMember_Callback);
    gui_component('Button', jPanelButtons, 'hfill', 'Edit permissions', [], [], @ButtonEditMember_Callback);
    gui_component('Button', jPanelButtons, [], 'Remove', [], [], @ButtonRemoveMember_Callback);
    jPanelNew.add('br hfill', jPanelButtons);

    % ===== LOAD DATA =====
    UpdateGroupsList();
    UpdateMembersList();
        
    % ===== CREATE PANEL =====   
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jListGroups',  jListGroups, ...
                                  'jListMembers', jListMembers));
                       
    %% ===== UPDATE GROUPS LIST =====
    function UpdateGroupsList()
        % Load groups
        groups = LoadGroups();
        % Remove JList callback
        bakCallback = java_getcb(jListGroups, 'ValueChangedCallback');
        java_setcb(jListGroups, 'ValueChangedCallback', []);

        % Create a new empty list
        listModel = java_create('javax.swing.DefaultListModel');
        % Add an item in list for each group
        for i = 1:length(groups)
            listModel.addElement(groups{i});
        end
        % Update list model
        jListGroups.setModel(listModel);

        % Restore callback
        drawnow
        java_setcb(jListGroups, 'ValueChangedCallback', bakCallback);
    end

    %% ===== UPDATE MEMBERS LIST =====
    function UpdateMembersList()
        % Load members
        group = jListGroups.getSelectedValue();
        [members, permissions] = LoadMembers(group);
        if isempty(group) || isempty(members)
            return
        end
        % Remove JList callback
        bakCallback = java_getcb(jListMembers, 'ValueChangedCallback');
        java_setcb(jListMembers, 'ValueChangedCallback', []);

        % Create a new empty list
        listModel = java_create('javax.swing.DefaultListModel');
        % Add an item in list for each group
        for i = 1:length(members)
            listModel.addElement([members{i} ' [' permissions{i} ']']);
        end
        % Update list model
        jListMembers.setModel(listModel);

        % Restore callback
        drawnow
        java_setcb(jListMembers, 'ValueChangedCallback', bakCallback);
    end


    %% =================================================================================
    %  === CONTROLS CALLBACKS  =========================================================
    %  =================================================================================

    function GroupListValueChanged_Callback(h, ev)
        UpdateMembersList();
    end

    %% ===== BUTTON: CREATE GROUP =====
    function ButtonCreateGroup_Callback(varargin)
        disp('TODO: Create Group');
        UpdateGroupsList();
    end

    %% ===== BUTTON: ADD MEMBER =====
    function ButtonAddMember_Callback(varargin)
        group = jListGroups.getSelectedValue();
        if isempty(group)
            return
        end
        
        [res, isCancel] = java_dialog('input', 'What is the name or email of the person you would like to add?', 'Add member', jPanelNew);
        if ~isCancel && ~isempty(res)
            [res, error] = AddMember(group, res);
            if res
                UpdateMembersList();
            else
                java_dialog('error', error, 'Add member');
            end
        end
    end

    %% ===== BUTTON: EDIT PERMISSIONS =====
    function ButtonEditMember_Callback(varargin)
        group = jListGroups.getSelectedValue();
        member = ExtractMemberName(jListMembers.getSelectedValue());
        if isempty(group) || isempty(member)
            return
        end
        
        [res, isCancel] = java_dialog('combo', 'What permissions would you like to give this member?', 'Edit permissions', [], {'Read-only','Read & write', 'Admin'});
        if ~isCancel
            disp(['TODO: Edit permissions of member "' member '" of group "' group '" to "' res '"']);
            UpdateMembersList();
        end
    end

    %% ===== BUTTON: REMOVE MEMBER =====
    function ButtonRemoveMember_Callback(varargin)
        member = ExtractMemberName(jListMembers.getSelectedValue());
        if isempty(member)
            return
        end
        disp(['TODO: Remove member "' member '"']);
        UpdateMembersList();
    end

    %% ===== LOAD GROUPS =====
    function groups = LoadGroups()
        disp('TODO: Load groups');
        groups = {'NeuroSPEED', 'OMEGA', 'Ste-Justine Project'};
    end
    %% ===== LOAD MEMBERS =====
    function [members, permissions] = LoadMembers(group)
        if isempty(group)
            members = [];
            permissions = [];
            return
        end
        
        disp(['TODO: Load members of group "' group '"']);
        members = {'Martin Cousineau', 'Sylvain Baillet', 'Marc Lalancette'};
        permissions = {'admin', 'write', 'read'};
    end
    %% ===== ADD MEMBER TO GROUP =====
    function [res, error] = AddMember(group, member)        
        disp(['TODO: Create member "' member '" to group "' group '"']);
        res = 1;
        error = [];
        %error = 'Could not find member.';
    end
end

% Extract member name if permission present in brackets
function member = ExtractMemberName(member)
    iPermission = strfind(member, ' [');
    if ~isempty(iPermission) && iPermission > 2
        member = member(1:iPermission(end)-1);
    end
end


