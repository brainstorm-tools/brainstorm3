function panel_sync()

%download
filename = "300mb.zip";
blocksize = 10000000; %10mb
url=strcat(string(bst_get('UrlAdr')),"/file/download/",filename);
[response,status] = bst_call(@HTTP_request,'GET','Default',struct(),url);
if strcmp(status,'200')~=1 && strcmp(status,'OK')~=1
    java_dialog('warning',status);
    return;
end
filesize = double(response.Body.Data);
start = 0;
fileID = fopen(strcat('/Users/chaoyiliu/Desktop/data/',filename),'w');
bst_progress('start', 'downloading', 'downloading file',0,filesize);
while(start < filesize)
    [response,status] = bst_call(@HTTP_request,'GET','Default',struct(),strcat(url,"/", num2str(start),"/",num2str(blocksize)));
    if strcmp(status,'200')~=1 && strcmp(status,'OK')~=1
        java_dialog('warning',status);
        return;
    end
    bst_progress('set', start);
    start = start + blocksize;
    filestream = response.Body.Data;
    fwrite(fileID,filestream,'uint8');
end
bst_progress('stop');
fclose(fileID);
disp("finish download!");


%{
bst_set('ProtocolId',"341e0d29-c678-4e87-bb28-f0dc3042a826");
%upload local protocol to cloud
protocol = bst_get('ProtocolInfo');
%todo: http create protocol
protocolid = bst_get('ProtocolId');
disp(protocolid);
comment=getfield(protocol,"Comment");
istudy=getfield(protocol,"iStudy");
anat=getfield(protocol,"UseDefaultAnat");
channel=true;
disp(anat);
if(getfield(protocol,"UseDefaultChannel")==0)
    channel=false;
end
disp(channel);
url = strcat(string(bst_get('UrlAdr')),"/protocol/share");
data=struct('id',protocolid,'name','test1','isprivate',true,...
    'comment',comment,'istudy',istudy,'usedefaultanat',anat,...
  'usedefaultchannel',channel);
[response,status] = bst_call(@HTTP_request,'POST','Default',data,url);
if strcmp(status,'200')~=1 && strcmp(status,'OK')~=1
    java_dialog('warning',status);
    return;
else
    newid=response.Body.Data;
    newid=extractBetween(newid,8,strlength(newid)-2);
    disp(newid);
    if isempty(bst_get('ProtocolId'))
        bst_set('ProtocolId',newid);
        disp('store protocolId successfully');
    end
    disp('create protocal successfully');
end
%}

%{
%go through subjects
numofsubjects = bst_get('SubjectCount');
for i = 1:numofsubjects
    subject = bst_get('Subject', i); 
    url = strcat(string(bst_get('UrlAdr')),"/subject/create");
    %todo: http create subject
    subjectstudies = bst_get('StudyWithSubject',subject.FileName);
    for j = 1:length(subjectstudies)
        url = strcat(string(bst_get('UrlAdr')),"/study/create");
        data = struct('filename',1,'name',1,'condition',1,...
            'dataofStudy',1,'iChannel',1,iHeadModel,1,...
            'protocolId',protocolid,'subjectId',j,'channels',1);
        [response,status] = bst_call(@HTTP_request,'POST','Default',data,url);
        %todo: http create study
        %todo: check all files and http create file
    end 
end
%}



%upload
%{
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
%}


end
