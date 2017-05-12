function[data,h]=SONGetTextMarkerChannel(fid, chan, varargin)
% SONGETTEXTMARKERCHANNEL reads a marker channel from a SON file.
%
% [data{, h}]=SONGETMARKER(FID, CHAN)
% FID is the MATLAB file handle and CHAN is the channel number (1 to Max)
% DATA is a structure containing:
%   DATA.TIMINGS: a length n vector with the marker timestamps
%   DATA.MARKERS: an n x 4 array of uint8 type, containing the marker
%   values
%	DATA.TEXT: an n x m array, with m characters for each of the n tiemstamps
% When present, OPTIONS must be the last input argument. Valid options
% are:
% 'ticks', 'microseconds', 'milliseconds' and 'seconds' cause times to
%    be scaled to the appropriate unit (seconds by default)in HEADER
% 'scale' - no effect
% 'progress' - causes a progress bar to be displayed during the read.
%
% 
% Revised
% 01/05/06
% Bug: Remove double call to SONTicksToSeconds introduced with v2.00.
% 26/9/06
% Change: Now returns uint8
%
% Malcolm Lidierth 02/02
% Updated 06/05 ML
% Copyright © The Author & King's College London 2002-2006

Info=SONChannelInfo(fid,chan);

if isempty (Info)
    data=[];
    h=[];
    return;
end;

if(Info.kind~=8) 
    warning('SONGetTextMarkerChannel: Channel %d No data or not a TextMark channel',chan);
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

if ~isempty(header)   % FT,12-May-2017: Test for newer version of Matlab
    NumberOfMarkers = sum(header(5,startBlock:endBlock)); % Sum of samples in required blocks
else
    NumberOfMarkers = 0;
end


if TickFlag==true && ~scverLessThan('MATLAB','7')
    data.timings=zeros(NumberOfMarkers,1,'int32');
    data.markers=zeros(NumberOfMarkers,4,'uint8');
    data.text=zeros(NumberOfMarkers,Info.nExtra,'uint8');
else
    data.timings=zeros(NumberOfMarkers,1);
    data.markers=uint8(zeros(NumberOfMarkers,4));
    data.text=uint8(zeros(NumberOfMarkers,Info.nExtra));
end


count=1;
for block=1:Info.blocks
    fseek(fid, header(1, block)+SizeOfHeader, 'bof');               % Start of block
    for i=1:header(5,block)                                         % loop for each marker
        data.timings(count,1)=fread(fid,1,'int32');          % Time
        data.markers(count,:)=fread(fid,4,'uint8=>uint8');            % 4x marker bytes
        data.text(count,:)=fread(fid,Info.nExtra,'uint8=>uint8'); % changed to uint8 for mapping 12/3/06
        k=findstr(data.text(count,:),0);                            % Look for NULL terminator and clear succeeding characters
        data.text(count,k(1):Info.nExtra)=0;
        count=count+1;
    end;
    if ShowProgress==1 && rem(block,10)==0
        done=(block-1)/max(1,Info.blocks);
%         progressbar(done, progbar,...
%             sprintf('Reading Channel %d....     %3.0f%% Done',chan,done*100));
    end;
end;

if(nargout>1)
    h.FileName=Info.FileName; % Set up the header information to return
    h.system=['SON' num2str(FileH.systemID)];
    h.FileChannel=chan;
    h.phyChan=Info.phyChan;
    h.kind=Info.kind;
    h.blocks=Info.blocks;
    h.npoints=NumberOfMarkers;
    h.values=Info.nExtra;
    h.preTrig=Info.preTrig;
    h.comment=Info.comment;
    h.title=Info.title;
    h.sampleinterval=NaN;
    h.scale=NaN;
    h.offset=NaN;
    h.units='uint8';
    h.interleave=1;
end;

[data.timings,h.TimeUnits]=SONTicksToSeconds(fid,data.timings, varargin{:});                % Convert time
h.Epochs={startBlock endBlock 'of' Info.blocks 'blocks'};
if ShowProgress==1
%     close(progbar);
    drawnow;
end;