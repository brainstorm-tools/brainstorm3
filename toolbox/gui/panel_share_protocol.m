function varargout = panel_share_protocol(varargin)
% PANEL_SHARE_PROTOCOL:  Edit user group memberships.
% USAGE:  [bstPanelNew, panelName] = panel_share_protocol('CreatePanel')

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
    panelName = 'ShareProtocol';
    
    % Create main main panel
    jPanelNew = gui_river([0 0], [0 0 0 0]);
    
    % Font size for the lists
    fontSize = round(10 * bst_get('InterfaceScaling') / 100);
    
    % List of groups
    jPanelGroups = gui_river([5 0], [0 2 0 2], 'Groups');
    jPanelNew.add('br hfill', jPanelGroups);
    jListGroups = JList();
    jListGroups.setCellRenderer(BstStringListRenderer(fontSize));
    jPanelGroupsScrollList = JScrollPane();
    jPanelGroupsScrollList.getLayout.getViewport.setView(jListGroups);
    jPanelGroups.add('hfill', jPanelGroupsScrollList);
    
    % Buttons
    jPanelGroupButtons = gui_river([5 0], [0 2 0 2]);
    gui_component('Button', jPanelGroupButtons, [], 'Add', [], [], @ButtonAddGroup_Callback);
    gui_component('Button', jPanelGroupButtons, 'hfill', 'Edit permissions', [], [], @ButtonEditGroup_Callback);
    gui_component('Button', jPanelGroupButtons, [], 'Remove', [], [], @ButtonRemoveGroup_Callback);
    jPanelGroups.add('br hfill', jPanelGroupButtons);
    
    % List of members
    jPanelMembers = gui_river([5 0], [0 2 0 2], 'Members');
    jPanelNew.add('br hfill', jPanelMembers);
    jListMembers = JList();
    jListMembers.setCellRenderer(BstStringListRenderer(fontSize));
    jPanelMembersScrollList = JScrollPane();
    jPanelMembersScrollList.getLayout.getViewport.setView(jListMembers);
    jPanelMembers.add('hfill', jPanelMembersScrollList);
    
    % Buttons
    jPanelMemberButtons = gui_river([5 0], [0 2 0 2]);
    gui_component('Button', jPanelMemberButtons, [], 'Add', [], [], @ButtonAddMember_Callback);
    gui_component('Button', jPanelMemberButtons, 'hfill', 'Edit permissions', [], [], @ButtonEditMember_Callback);
    gui_component('Button', jPanelMemberButtons, [], 'Remove', [], [], @ButtonRemoveMember_Callback);
    jPanelMembers.add('br hfill', jPanelMemberButtons);

    % ===== LOAD DATA =====
    ShareProtocol();
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
        [groups, permissions] = LoadGroups();
        % Remove JList callback
        bakCallback = java_getcb(jListGroups, 'ValueChangedCallback');
        java_setcb(jListGroups, 'ValueChangedCallback', []);

        % Create a new empty list
        listModel = java_create('javax.swing.DefaultListModel');
        % Add an item in list for each group
        for i = 1:length(groups)
            listModel.addElement([groups{i} ' [' permissions{i} ']']);
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
        [members, permissions] = LoadMembers();
        if isempty(members)
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

    %% ===== BUTTON: ADD GROUP =====
    function ButtonAddGroup_Callback(varargin)
        [group, isCancel] = java_dialog('input', 'What is the name of the group you would like to add?', 'Add group', jPanelNew);
        if ~isCancel && ~isempty(group)
            [success, error] = AddGroup(group);
            if success
                UpdateGroupsList();
            else
                java_dialog('error', error, 'Add group');
            end
        end
    end

    %% ===== BUTTON: ADD MEMBER =====
    function ButtonAddMember_Callback(varargin)        
        [member, isCancel] = java_dialog('input', 'What is the name or email of the person you would like to add?', 'Add member', jPanelNew);
        if ~isCancel && ~isempty(member)
            [success, error] = AddMember(member);
            if success
                UpdateMembersList();
            else
                java_dialog('error', error, 'Add member');
            end
        end
    end

    %% ===== BUTTON: EDIT GROUP PERMISSIONS =====
    function ButtonEditGroup_Callback(varargin)
        sProtocol = bst_get('ProtocolInfo');
        group = ExtractName(jListGroups.getSelectedValue());
        if isempty(sProtocol) || isempty(group)
            return
        end
        
        [res, isCancel] = java_dialog('combo', 'What permissions would you like to give this group?', 'Edit permissions', [], {'Read-only','Read & write'});
        if ~isCancel
            disp(['TODO: Edit permissions of group "' group '" of protocol "' sProtocol.Comment '" to "' res '"']);
            UpdateGroupsList();
        end
    end

    %% ===== BUTTON: EDIT MEMBER PERMISSIONS =====
    function ButtonEditMember_Callback(varargin)
        sProtocol = bst_get('ProtocolInfo');
        member = ExtractName(jListMembers.getSelectedValue());
        if isempty(sProtocol) || isempty(member)
            return
        end
        
        [res, isCancel] = java_dialog('combo', 'What permissions would you like to give this member?', 'Edit permissions', [], {'Read-only','Read & write'});
        if ~isCancel
            disp(['TODO: Edit permissions of member "' member '" of protocol "' sProtocol.Comment '" to "' res '"']);
            UpdateMembersList();
        end
    end

    %% ===== BUTTON: REMOVE GROUP =====
    function ButtonRemoveGroup_Callback(varargin)
        sProtocol = bst_get('ProtocolInfo');
        group = ExtractName(jListGroups.getSelectedValue());
        if isempty(sProtocol) || isempty(group)
            return
        end
        
        disp(['TODO: Remove group "' group '" from protocol "' sProtocol.Comment '"']);
        UpdateGroupsList();
    end

    %% ===== BUTTON: REMOVE MEMBER =====
    function ButtonRemoveMember_Callback(varargin)
        sProtocol = bst_get('ProtocolInfo');
        member = ExtractName(jListMembers.getSelectedValue());
        if isempty(sProtocol) || isempty(member)
            return
        end
        
        disp(['TODO: Remove member "' member '" from protocol "' sProtocol.Comment '"']);
        UpdateMembersList();
    end

    %% ===== LOAD GROUPS =====
    function [groups, permissions] = LoadGroups()
        sProtocol = bst_get('ProtocolInfo');
        if isempty(sProtocol)
            java_dialog('warning', "No protocol currently!");
            %return
        end
       
        [groups, permissions] = LoadProtocolGroups();
        %disp(['TODO: Load groups of protocol "' sProtocol.Comment '"']);
        %groups = {'NeuroSPEED', 'OMEGA', 'Ste-Justine Project'};
        %permissions = {'write', 'read', 'write'};
    end
    %% ===== LOAD MEMBERS =====
    function [members, permissions] = LoadMembers()
        sProtocol = bst_get('ProtocolInfo');
        if isempty(sProtocol)
            %return
        end
        
        [members,permissions] = LoadProtocolMembers();
        %disp(['TODO: Load members of protocol "' sProtocol.Comment '"']);
        %members = {'Martin Cousineau', 'Sylvain Baillet', 'Marc Lalancette'};
        %permissions = {'admin', 'write', 'read'};
    end
    %% ===== ADD MEMBER =====
    function [res, error] = AddMember(member)
        sProtocol = bst_get('ProtocolInfo');
        if isempty(sProtocol)
            return
        end
        
        disp(['TODO: Share protocol "' sProtocol.Comment '" to member "' member '"']);
        res = 1;
        error = [];
        %error = 'Could not find member.';
    end
    %% ===== ADD GROUP =====
    function [res, error] = AddGroup(group)
        sProtocol = bst_get('ProtocolInfo');
        if isempty(sProtocol)
            return
        end
        
        disp(['TODO: Share protocol "' sProtocol.Comment '" to group "' group '"']);
        res = 1;
        error = [];
        %error = 'Could not find group.';
    end
end

% Extract group/member name if permission present in brackets
function member = ExtractName(member)
    iPermission = strfind(member, ' [');
    if ~isempty(iPermission) && iPermission > 2
        member = member(1:iPermission(end)-1);
    end
end


function ShareProtocol()
import matlab.net.*;
import matlab.net.http.*;
type1 = MediaType('text/*');
type2 = MediaType('application/json','q','.5');
acceptField = matlab.net.http.field.AcceptField([type1 type2]);
h1 = HeaderField('Content-Type','application/json');
h2 = HeaderField('sessionid',bst_get('SessionId'));
h3 = HeaderField('deviceid',bst_get('DeviceId'));
header = [acceptField,h1,h2,h3];
method = RequestMethod.POST;
sProtocol = bst_get('ProtocolInfo');
test = bst_get('iProtocol'); 
protocol = convertCharsToStrings(bst_get('ProtocolId'));
if(sProtocol.UseDefaultChannel == 0) udc = false;
else udc = true;
end  
data = struct('Id',protocol,'Name',sProtocol.Comment, 'Isprivate', false, ...
        'Comment',sProtocol.Comment, 'Istudy', size(sProtocol.iStudy,1), ...
        'Usedefaultanat',sProtocol.UseDefaultAnat, 'Usedefaultchannel',udc);
body=MessageBody(data);
request_message = RequestMessage(method,header,body);
show(request_message);


serveradr = string(bst_get('UrlAdr'));
url=strcat(serveradr,"/protocol/share");
disp(url);
try
    [resp,~,hist]=send(request_message,URI(url));
    status = resp.StatusCode;
    txt=char(status);
    if strcmp(status,'200')==1 ||strcmp(txt,'OK')==1
        content=resp.Body;
        show(content);
        protocolid = jsondecode(content.Data);
        bst_set('ProtocolId',string(protocolid.id));        
        %java_dialog('msgbox', 'Protocol uploaded!');
        disp('Protocol uploaded!');
    elseif strcmp(status,'404')==1 || strcmp(txt,'NotFound')==1
        java_dialog('error','Current protocol has not been uploaded!');
    else
        java_dialog('error', txt);
    end
catch
    java_dialog('warning', 'Load protocol failed!');
end
end


function [groups, permissions] = LoadProtocolGroups()
import matlab.net.*;
import matlab.net.http.*;
type1 = MediaType('text/*');
type2 = MediaType('application/json','q','.5');
acceptField = matlab.net.http.field.AcceptField([type1 type2]);
h1 = HeaderField('Content-Type','application/json');
h2 = HeaderField('sessionid',bst_get('SessionId'));
h3 = HeaderField('deviceid',bst_get('DeviceId'));
header = [acceptField,h1,h2,h3];
method = RequestMethod.GET;
request_message = RequestMessage(method,header,[]);
%show(request_message);
serveradr = string(bst_get('UrlAdr'));
protocol = convertCharsToStrings(bst_get('ProtocolId'));
url=strcat(serveradr,"/protocol/groups/",protocol);
disp(url);
try
    [resp,~,hist]=send(request_message,URI(url));
    status = resp.StatusCode;
    txt=char(status);
    if strcmp(status,'200')==1 ||strcmp(txt,'OK')==1
        content=resp.Body;
        show(content)
        responseData = jsondecode(content.Data);
        if(size(responseData) > 0)
            groups = cell(size(responseData));
            permissions = cell(size(responseData));
            for i = 1 : size(responseData)
                groups{i} = responseData(i).name;
                permissions{i} = responseData(i).access;
            end
        end
        %java_dialog('msgbox', 'Load protocol groups successfully!');
        disp('Load protocol groups successfully!');
    elseif strcmp(status,'404')==1 || strcmp(txt,'NotFound')==1
        java_dialog('error','Current protocol has not been uploaded!');
    else
        java_dialog('error', txt);
    end
catch
    java_dialog('warning', 'Load group failed!');
end
end


function [members, permissions] = LoadProtocolMembers()
import matlab.net.*;
import matlab.net.http.*;
type1 = MediaType('text/*');
type2 = MediaType('application/json','q','.5');
acceptField = matlab.net.http.field.AcceptField([type1 type2]);
h1 = HeaderField('Content-Type','application/json');
h2 = HeaderField('sessionid',bst_get('SessionId'));
h3 = HeaderField('deviceid',bst_get('DeviceId'));
header = [acceptField,h1,h2,h3];
method = RequestMethod.GET;
request_message = RequestMessage(method,header,[]);
%show(request_message);
serveradr = string(bst_get('UrlAdr'));
protocol = convertCharsToStrings(bst_get('ProtocolId'));
url=strcat(serveradr,"/protocol/members/",protocol);
disp(url);
try
    [resp,~,hist]=send(request_message,URI(url));
    status = resp.StatusCode;
    txt=char(status);
    if strcmp(status,'200')==1 ||strcmp(txt,'OK')==1
        content=resp.Body;
        show(content)
        responseData = jsondecode(content.Data);
        if(size(responseData) > 0)
            members = cell(size(responseData));
            permissions = cell(size(responseData));
            for i = 1 : size(responseData)
                members{i} = responseData(i).email;
                permissions{i} = responseData(i).access;
            end
        end
        %java_dialog('msgbox', 'Load protocol groups successfully!');
        disp('Load protocol groups successfully!');
    elseif strcmp(status,'404')==1 || strcmp(txt,'NotFound')==1
        java_dialog('error','Current protocol has not been uploaded!');
    else
        java_dialog('error', txt);
    end
catch
    java_dialog('warning', 'Load group failed!');
end

end


