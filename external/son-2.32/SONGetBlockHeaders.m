function[header]=SONGetBlockHeaders(fid,chan)
% SONGETBLOCKHEADERS returns a matrix containing the SON data block headers
% in file 'fid' for channel 'chan'.
% The returned header in memory contains, for each disk block,
% a column with rows 1-5 representing:
%                       Offset to start of block in file
%                       Start time in clock ticks
%                       End time in clock ticks
%                       Chan number
%                       Items
% See CED documentation for details - note this header is a modified form of
% the disk header
%
% Malcolm Lidierth 02/02
% Updated 06/05 ML
% Copyright © The Author & King's College London 2002-2006

succBlock=2;
Info=SONChannelInfo(fid,chan);

if(Info.firstblock==-1)
%    warning('SONGetBlockHeaders: No data on channel #%d', chan);
    header=[];
    return;
end;
    
header=zeros(6,Info.blocks);                                %Pre-allocate memory for header data
fseek(fid,Info.firstblock,'bof');                           % Get first data block    
header(1:4,1)=fread(fid,4,'int32');                         % Last and next block pointers, Start and end times in clock ticks
header(5:6,1)=fread(fid,2,'int16');                         % Channel number and number of items in block

if(header(succBlock,1)==-1)
    header(1,1)=Info.firstblock;                            % If only one block
else
    fseek(fid,header(succBlock,1),'bof');                   % Loop if more blocks
    for i=2:Info.blocks
        header(1:4,i)=fread(fid,4,'int32');                         
        header(5:6,i)=fread(fid,2,'int16');
        fseek(fid,header(succBlock,i),'bof');
        header(1,i-1)=header(1,i);                          
    end;
    header(1,Info.blocks)=header(2,Info.blocks-1);          % Replace predBlock for previous column
end;
header(2,:)=[];                                           % Delete succBlock data


