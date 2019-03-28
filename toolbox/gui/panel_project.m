function varargout = panel_login(varargin)
%PANEL_LOGIN Summary of this function goes here
%   Detailed explanation goes here
eval(macro_method);
end

function [bstPanelNew, panelName] = CreatePanel()
    import java.awt.Dimension;
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    
    panelName = 'Project';
  
    jPanelNew = gui_river();
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));
    jPanelproject = gui_river();

    jLabelName = gui_component('Label', jPanelproject,'br', 'Projectname: ', [], [], []);
    jTextName  = gui_component('Text', jPanelproject, 'br', '', [], [], []);
    jTextName.setPreferredSize(java_scaled('dimension', 180, 30));
    
    jLabelDescription = gui_component('Label', jPanelproject,'br', 'Description: ', [], [], []);
    jTextDescription= gui_component('text', jPanelproject, 'br', '', [], [], []);
    jTextDescription.setPreferredSize(java_scaled('dimension', 180, 80));
    
    jLabelFiles = gui_component('Label', jPanelproject,'br', 'Files: ', [], [], []);
    jTextLastname = gui_component('Text', jPanelproject, 'br', '', [], [], []);
    jTextLastname.setPreferredSize(java_scaled('dimension', 180, 30));
    jButtonSpmDir = gui_component('Button', jPanelproject, [], '...', [], [], @ProjectDirectory_Callback);
    jButtonSpmDir.setMargin(Insets(2,2,2,2));
    jButtonSpmDir.setFocusable(0);
    
    jButtonSignup = gui_component('Button', jPanelproject, 'br center', 'Create', [], [],@ButtonSign_Callback);
    jButtonSignup.setPreferredSize(java_scaled('dimension', 80, 40));
    jPanelproject.setPreferredSize(java_scaled('dimension', 400, 500));
    
    jPanelNew.add(jPanelproject);
    
    jPanelproject.setPreferredSize(java_scaled('dimension', 300, 300));
    
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct());
    jPanelNew.setVisible(1);
    
    function ButtonSign_Callback(varargin)
        import matlab.net.*;
        import matlab.net.http.*;
    
        if(strcmp(jTextName.getText(),'')==1)
            java_dialog('warning', 'Email cannot be empty!');
        elseif strcmp(jTextDescription.getText(),'')==1
            java_dialog('warning', 'Name cannot be empty!');
        else
            data=containers.Map(...
                {'projectName';'pDescription'},...
                [string(jTextName.getText());string(jTextDescription.getText())]);
            datapass=jsonencode(data);
            body=MessageBody(datapass);
            contentTypeField = matlab.net.http.field.ContentTypeField('text/plain');
            type1 = matlab.net.http.MediaType('text/*');
            type2 = matlab.net.http.MediaType('application/json','q','.5');
            acceptField = matlab.net.http.field.AcceptField([type1 type2]);
            header = [acceptField contentTypeField];
            method =RequestMethod.POST;
            r=RequestMessage(method,header,body);
            show(r.Body);
            url=string(bst_get('UrlAdr'));
            uri= URI(url);
            try
                [resp,~,hist]=send(r,uri);
                status = resp.StatusCode;
                txt=char(status);
                if strcmp(txt,'200')==1 ||strcmp(txt,'OK')==1
                    content=resp.Body;
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






