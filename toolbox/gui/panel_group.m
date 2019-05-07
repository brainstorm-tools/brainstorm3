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
    
    panelName = 'Group';
  
    jPanelNew = gui_river();
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));
    jPanelGroup = gui_river();

    jLabelName = gui_component('Label', jPanelGroup,'br', 'Group name: ', [], [], []);
    jTextName  = gui_component('Text', jPanelGroup, '', '', [], [], []);
    jTextName.setPreferredSize(java_scaled('dimension', 180, 30));
    
    jLabelDescription = gui_component('Label', jPanelGroup,'br', 'Description: ', [], [], []);
    jTextDescription = gui_component('textarea', jPanelGroup, '', '', [], [], []);
    
    jButtonSignup = gui_component('Button', jPanelGroup, 'br center', 'Create', [], [],@ButtonSign_Callback);
    jButtonSignup.setPreferredSize(java_scaled('dimension', 80, 40));
    jPanelGroup.setPreferredSize(java_scaled('dimension', 400, 500));
    
    jPanelNew.add(jPanelGroup);
    
    jPanelGroup.setPreferredSize(java_scaled('dimension', 400, 300));
    
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
            java_dialog('warning', 'Password cannot be empty!');
        else
            data=containers.Map(...
                {'groupname';'gDescription'},...
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
                    show(content);
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






