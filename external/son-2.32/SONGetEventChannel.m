function[data,h]=SONGetEventChannel(fid, chan, varargin)
% SONGETEVENTCHANNEL reads an event channel from a SON file
%
% DATA{, H}]=SONGETEVENTCHANNEL(FID, CHAN{, START{, STOP{, OPTIONS}}})
%
% FID is the matlab file handle and chan is the channel number (1-max)
% If START/STOP are absent, all data is read. When present, START or
% START and STOP together set the disc blocks to read. This allows large
% data files to be read in parts.
% OPTIONS, if present, must be a cell array of strings and must be the last
% argument in the list. Valid options:
% 'ticks', 'microseconds', 'milliseconds', 'seconds' (default). Other
% options will be ignored.
%
% DATA is returned as a double precision array with the timestamps,
% in units determined by OPTIONS. H, if present, is returned with the
% channel header.
%
% e.g.
% [data,h]=SONGetEventChannel(fid, 1, 10, 11, 'microseconds')
%     reads Block 10-11 of Channel 1 and returns that data in microseconds
% [data,h]=SONGetEventChannel(fid, 1, 'ticks')
%     reads all blocks returning data in clock ticks
%
% See also SONGetMarkerChannel, SONGetADCMarkerChannel,
% SONGetRealMarkerChannel, SONGetTextMarkerChannel
%
% Malcolm Lidierth 02/02
% Updated 10/06 ML
% Copyright © The Author & King's College London 2002-2006


Info=SONChannelInfo(fid,chan);

if isempty (Info)
    data=[];
    h=[];
    return;
end;

if(Info.kind < 2 || Info.kind > 4) 
    warning('SONGetEventChannel: Channel #%d Not an event channel',chan);
    data=[];
    h=[];
    return;
end;

if Info.blocks==0
    data=[];
    h=[];
    return;
end;

FileH=SONFileHeader(fid);
SizeOfHeader=20;                                            % Block header is 20 bytes long
header=SONGetBlockHeaders(fid,chan);

ShowProgress=0;
arguments=nargin;
TickFlag=false;
for i=1:length(varargin)
    if ischar(varargin{i}) 
        arguments=arguments-1;
        if strcmpi(varargin{i},'progress') && Info.blocks>10
            ShowProgress=1;
%             progbar=progressbar(0,sprintf('Analyzing %d blocks on channel %d',Info.blocks,chan),...
%                 'Name',sprintf('%s',fopen(fid)));
        end;
        if strcmpi(varargin{i},'ticks')
            TickFlag=true;
        end
    end;
end;

switch arguments
    case {2}
        startBlock=1;
        endBlock=Info.blocks;
    case {3}
        startBlock=varargin{1};
        endBlock=varargin{1};
    otherwise
        startBlock=varargin{1};
        endBlock=min(Info.blocks,varargin{2});
end;

NumberOfSamples=sum(header(5,startBlock:endBlock)); % Sum of samples in required blocks

if TickFlag==true && ~scverLessThan('MATLAB','7')
    data=zeros(NumberOfSamples,1,'int32');
else
    data=zeros(NumberOfSamples,1);
end

pointer=1;

for block=startBlock:endBlock
    fseek(fid,header(1,block)+SizeOfHeader,'bof');
    data(pointer:pointer+header(5,block)-1)=fread(fid,header(5,block),'int32');%Changed from single
    pointer=pointer+header(5,block);
    if ShowProgress==1 && rem(block,10)==0
        done=(block-startBlock)/max(1,block-startBlock);
%         progressbar(done, progbar,...
%             sprintf('Reading Channel %d....     %3.0f%% Done',chan,done*100));
    end;
end;


    h.FileName=Info.FileName;                                   % Set up the header information to return
    h.system=['SON' num2str(FileH.systemID)];                   % if it's been requested
    h.FileChannel=chan;
    h.phyChan=Info.phyChan;
    h.kind=Info.kind;
    h.npoints=NumberOfSamples;
    h.comment=Info.comment;
    h.title=Info.title;
    if (Info.kind==4)
        h.initLow=Info.initLow;
        h.nextLow=Info.nextLow; 
    end;


[data,h.TimeUnits]=SONTicksToSeconds(fid, data, varargin{:});      % Convert time
h.Epochs={startBlock endBlock 'of' Info.blocks 'blocks'};
if ShowProgress==1
%     close(progbar);
    drawnow;
end;
