function [outputArg1] = HTTP_request(method,header,data,url)
% HTTP_REQUEST: POST,GET request to construct interaction between front end
% and back end.

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
% Authors: Zeyu Chen, 2019
    import matlab.net.*;
    import matlab.net.http.*;
    
    body=MessageBody(data);
    contentTypeField = matlab.net.http.field.ContentTypeField('application/json');
    type1 = matlab.net.http.MediaType('text/*');
    type2 = matlab.net.http.MediaType('application/json','q','.5');
    acceptField = matlab.net.http.field.AcceptField([type1 type2]);
    h1 = HeaderField('Content-Type','application/json');
    h2 = HeaderField('sessionid',bst_get('SessionId'));
    h3 = HeaderField('deviceid',bst_get('DeviceId'));
    switch (header)
        case 'None'
            header = [acceptField,contentTypeField];
        case 'Default'
            header = [acceptField,h1,h2,h3];
    end
    disp(method);
    if strcmp(method,"POST")==1
        method =RequestMethod.POST;    
    elseif  strcmp(method,"GET")==1
        method =RequestMethod.GET;
    else
        java_dialog('warning',"wrong method");
        return;
    end
    r=RequestMessage(method,header,body);
    show(r);
    disp(url);
    uri= URI(url); 
    [resp,~,hist]=send(r,uri);
    status = resp.StatusCode;
    outputArg1 = char(status);

end

