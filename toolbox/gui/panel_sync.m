function panel_sync()

filename = '/Users/chaoyiliu/Desktop/L08-GPIO.pdf';
blocksize = 1000000; % 1MB per request

url = strcat(string(bst_get('UrlAdr')),"/FunctionalFile/test/", "L08-GPIO.pdf");
[response,status] = bst_call(@HTTP_request,'POST','Default',struct(),url);
if strcmp(status,'OK')~=1
    java_dialog('warning',status);
    return;
end
uploadid = jsondecode(response.Body.Data);
uploadid = uploadid.result;
%uploadid = "4deb53de-b4c0-4d1b-9f9d-3b448bb158ba";

counter = 1;
fileID = fopen(filename,'r');
url=strcat(string(bst_get('UrlAdr')),"/file/testupload/", uploadid, "/");
while ~feof(fileID)
    blockcontent = fread(fileID,blocksize,'*uint8');
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
