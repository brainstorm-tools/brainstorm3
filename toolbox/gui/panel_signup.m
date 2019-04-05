function varargout = panel_signup(varargin)
%PANEL_LOGIN Summary of this function goes here
%   Detailed explanation goes here
eval(macro_method);
end

function [bstPanelNew, panelName] = CreatePanel()
    import java.awt.Dimension;
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    
    panelName = 'SignUp';
  
    jPanelNew = gui_river();
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));
    jPanelLogin = gui_river();
    
    jLabelUrl = gui_component('Label', jPanelLogin,'br', 'Server URL: ', [], [], []);
    jTextUrl  = gui_component('Text', jPanelLogin, '', '', [], [], []);
    jTextUrl.setPreferredSize(java_scaled('dimension', 180, 30));
    
    jLabelFirstname = gui_component('Label', jPanelLogin,'br', 'First name: ', [], [], []);
    jTextFirstname = gui_component('Text', jPanelLogin, '', '', [], [], []);
    jTextFirstname.setPreferredSize(java_scaled('dimension', 180, 30));
    
    jLabelLastname = gui_component('Label', jPanelLogin,'br', 'Last name: ', [], [], []);
    jTextLastname = gui_component('Text', jPanelLogin, '', '', [], [], []);
    jTextLastname.setPreferredSize(java_scaled('dimension', 180, 30));
    
    jLabelEmail = gui_component('Label', jPanelLogin,'br', 'Email address: ', [], [], []);
    jTextEmail  = gui_component('Text', jPanelLogin, '', '', [], [], []);
    jTextEmail.setPreferredSize(java_scaled('dimension', 180, 30));
    
    jLabelPassword = gui_component('Label', jPanelLogin,'br', 'Password: ', [], [], []);
    jTextPassword = gui_component('password', jPanelLogin, '', '', [], [], []);
    jTextPassword.setPreferredSize(java_scaled('dimension', 180, 30));
    
    jLabelRePassword = gui_component('Label', jPanelLogin,'br', 'Confirm password: ', [], [], []);
    jTextRePassword = gui_component('password', jPanelLogin, '', '', [], [], []);
    jTextRePassword.setPreferredSize(java_scaled('dimension', 180, 30));
    
    jButtonSignup = gui_component('Button', jPanelLogin, 'br center', 'Register', [], [],@ButtonSign_Callback);
    jButtonSignup.setPreferredSize(java_scaled('dimension', 80, 40));
    jPanelLogin.setPreferredSize(java_scaled('dimension', 400, 500));
    
    jPanelNew.add(jPanelLogin);
    
    jPanelLogin.setPreferredSize(java_scaled('dimension', 310, 280));
    
    % ===== LOAD OPTIONS =====
    LoadOptions();
    
    % ===== CREATE PANEL ===== 
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct());
    jPanelNew.setVisible(1);
    
    function LoadOptions()
        jTextUrl.setText(bst_get('UrlAdr'));
        gui_hide('Preferences');
    end

    function ButtonSign_Callback(varargin)
        import matlab.net.*;
        import matlab.net.http.*;
        
        if(strcmp(jTextUrl.getText(),'')==1)
            java_dialog('warning', 'Url cannot be empty!');
        elseif(strcmp(jTextEmail.getText(),'')==1)
            java_dialog('warning', 'Email cannot be empty!');
        elseif (strcmp(jTextFirstname.getText(),'')==1||strcmp(jTextLastname.getText(),'')==1)
            java_dialog('warning', 'Name cannot be empty!');
        elseif strcmp(jTextPassword.getText(),'')==1
            java_dialog('warning', 'Password cannot be empty!');
        elseif strcmp(jTextPassword.getText(),jTextRePassword.getText())~=1
            java_dialog('warning', 'Different password!');
        else
            if(isempty(bst_get('DeviceId')))
                device=string(jTextEmail.getText())+datestr(datetime('now'));
                 bst_set('DeviceId',device);
            else
                device=bst_get('DeviceId');
            end
 
            data = struct('firstName',char(jTextFirstname.getText()),'lastName',char(jTextLastname.getText()),...
                'email',char(jTextEmail.getText()),'password',char(jTextPassword.getText()),...
                'deviceid',char(device));
            body=MessageBody(data);
            contentTypeField = matlab.net.http.field.ContentTypeField('application/json');
            type1 = matlab.net.http.MediaType('text/*');
            type2 = matlab.net.http.MediaType('application/json','q','.5');
            acceptField = matlab.net.http.field.AcceptField([type1 type2]);
            header = [acceptField contentTypeField];
            method =RequestMethod.POST;
            r=RequestMessage(method,header,body);
            show(r);
            url=string(jTextUrl.getText());
            url=url+"/createuser";
            uri= URI(url);
            try
                [resp,~,hist]=send(r,uri);
                status = resp.StatusCode;
                txt=char(status);
                if strcmp(txt,'200')==1 ||strcmp(txt,'OK')==1
                    newUrlAdr = char(jTextUrl.getText());
                    if ~isempty(newUrlAdr)
                        bst_set('UrlAdr',newUrlAdr)
                    end
                    content=resp.Body;
                    show(content);
                    bst_set('Email',jTextEmail.getText());
                    session=strtok(string(content),',');
                    session=char(extractAfter(session,":"));
                    bst_set('SessionId',session);
                    bst_set('UrlAdr',jTextUrl.getText());
                    gui_hide(panelName);
                else
                    java_dialog('warning', 'Check your url or Internet!');
                    f=msgbox(txt);
                end
            catch
                java_dialog('warning', 'Check your url!');              
            end
        end
    end

end




