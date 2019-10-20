function panel_sync()

% fid = fopen('/Users/chaoyiliu/Desktop/sampledata.txt','w');
% fwrite(fid, 1:10000,'double');
% fclose(fid);

filename = '/Users/chaoyiliu/Desktop/L08-GPIO.pdf';
blocksize = 1000000; % 1MB per request

% url = strcat(string(bst_get('UrlAdr')),"/FunctionalFile/test/", "samplefilename");
% [response,status] = bst_call(@HTTP_request,'POST','Default',struct(),url);
% if strcmp(status,'OK')~=1
%     java_dialog('warning',status);
%     return;
% end
% uploadid = string(response.Body.Data);
uploadid = "4deb53de-b4c0-4d1b-9f9d-3b448bb158ba";

counter = 1;
fileID = fopen(filename,'r');
url=strcat(string(bst_get('UrlAdr')),"/file/testupload/", uploadid, "/");
while ~feof(fileID)
    blockcontent = fread(fileID,blocksize);
    counter = counter + 1;
    [response,status] = bst_call(@HTTP_request,'POST','Stream',blockcontent,url+"false");
    if strcmp(status,'200')~=1 && strcmp(status,'OK')~=1
        java_dialog('warning',status);
        return;
    end
end

[response,status] = bst_call(@HTTP_request,'POST','Stream',blockcontent,url+"true");
if strcmp(status,'200')~=1 && strcmp(status,'OK')~=1
    java_dialog('warning',status);
    return;
end
fclose(fileID);
disp(counter);

end
