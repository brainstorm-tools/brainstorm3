function [response, status] = Checksession(method,header,data,url)
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
% Authors: Zeyu Chen, Chaoyi Liu 2019

url = strcat(string(bst_get('UrlAdr')),"/user/checksession");
[response,status] = bst_call(@HTTP_request,'POST','Default',data,url);
if strcmp(status,'200')~=1 && strcmp(status,'OK')~=1
    java_dialog('warning',status);
    return;
else
    disp('session on');
end


end

