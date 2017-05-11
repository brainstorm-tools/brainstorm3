function [Head]=SONFileHeader(fid)
% SONFILEHEADER reads the file header for a SON file
%
% HEADER=SONFILEHEADER(FID)
%
% Used internally by the library. 
% See CED documentation of SON system for details.
%
% 24/6/05 Fix filecomment - now 5x1 not 5x5
%
% Malcolm Lidierth 03/02
% Updated 06/05 ML
% Copyright © The Author & King's College London 2002-2006

try
    frewind(fid);
catch
    warning(['SONFileHeader:' ferror(fid) 'Invalid file handle?' ]);
    Head=[];
    return;
end;

Head.FileIdentifier=fopen(fid);
Head.systemID=fread(fid,1,'int16');
Head.copyright=fscanf(fid,'%c',10);
Head.Creator=fscanf(fid,'%c',8);
Head.usPerTime=fread(fid,1,'int16');
Head.timePerADC=fread(fid,1,'int16');
Head.filestate=fread(fid,1,'int16');
Head.firstdata=fread(fid,1,'int32');
Head.channels=fread(fid,1,'int16');
Head.chansize=fread(fid,1,'int16');
Head.extraData=fread(fid,1,'int16');
Head.buffersize=fread(fid,1,'int16');
Head.osFormat=fread(fid,1,'int16');
Head.maxFTime=fread(fid,1,'int32');
Head.dTimeBase=fread(fid,1,'float64');
if Head.systemID<6
    Head.dTimeBase=1e-6;
end;
Head.timeDate.Detail=fread(fid,6,'uint8');
Head.timeDate.Year=fread(fid,1,'int16');
if Head.systemID<6
    Head.timeDate.Detail=zeros(6,1);
    Head.timeDate.Year=0;
end;
Head.pad=fread(fid,52,'char=>char');
Head.fileComment=cell(5,1);    

pointer=ftell(fid);
for i=1:5
    bytes=fread(fid,1,'uint8');
    Head.fileComment{i}=fread(fid,bytes,'char=>char')';
    pointer=pointer+80;
    fseek(fid,pointer,'bof');
end;







