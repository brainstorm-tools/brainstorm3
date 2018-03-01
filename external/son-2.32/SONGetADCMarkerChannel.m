function[data,h]=SONGetADCMarkerChannel(fid, chan, varargin)
% SONGETADCMARKERCHANNEL reads an ADCMark channel from a SON file.
%
% [DATA {, HEADER}]=SONGETADCMARKERCHANNEL(FID, CHAN{, START{, STOP{, OPTIONS}}})
% FID is the matlab file handle, CHAN is the channel number (1=max)
%
% [DATA, HEADER]=SONGETADCMARKERCHANNEL(FID, 1{, OPTIONS})
%       reads all the data on channel 1
% [DATA, HEADER]=SONGETADCMARKERCHANNEL(FID, 1, 10{, OPTIONS})
%       reads disc block 10 for continuous data or epoch 10 for triggered
%       data
% [DATA, HEADER]=SONGETADCMARKERCHANNEL(FID, 1, 10, 20{, OPTIONS})
%       reads disc blocks 10-20
%
% DATA is a structure with 3 fields.
%       DATA.TIMINGS contains timestamps
%       DATA.MARKERS contains 4 uint8 marker values for each event
%       DATA.ADC contains the ADC data associated with each timestamp
%
% When present, OPTIONS must be the last input argument. Valid options
% are:
% 'ticks', 'microseconds', 'milliseconds' and 'seconds' cause times to
%    be scaled to the appropriate unit (seconds by default)in HEADER
% 'scale' - calls SONADCToDouble to apply the channel scale and offset to
%    DATA.ADC which will  be cast to double precision
% 'progress' - causes a progress bar to be displayed during the read.
%
% Returns the signed 16 bit integer ADC values in DATA.ADC (scaled, offset and
% cast to double if 'scale' is used as an option). If present, HEADER
% will be returned with the channel header information from the file.
%
% Example:
% options={'scale' 'microseconds'}
% [data, header]=SONGetADCMarkerChannel(fid, 1, 20, 40, options{:})
%    reads blocks 20-40 from channel 1 and displays a progress bar.
%   Timestamps in data.timings wil be in microseconds
%   data.adc will be returned in double-precision floating point after
%   scaling and applying the offset stored on disc via SONADCToDouble.
%
% in this case HEADER could have the following example field values
%          FileName: 'c:\matlab704\work\02feb00.smr'
%             system: 'SON4'
%        FileChannel: 3
%            phyChan: -1
%               kind: 6
%            npoints: 9273
%             values: 100
%            preTrig: 10
%            comment: 'No comment'
%              title: 'Memory'
%     sampleinterval: 2.0000e-004
%              scale: 1
%             offset: 0
%              units: ' volt'
%         interleave: []
%          TimeUnits: 'microseconds'
%             Epochs: {[20]  [40]  'of'  [95]  'blocks'}
%          transpose: 0
%
% Malcolm Lidierth 02/02
% Updated 09/05 ML
% Copyright © The Author & King's College London 2002-2006

Info=SONChannelInfo(fid,chan);

if isempty (Info)
    data=[];
    h=[];
    return;
end;

if Info.kind ~=6
    warning('SONGetADCMarkerChannel: Channel %d No data or wrong channel type', chan);
    data=[];
    h=[];
    return;
end;

ShowProgress=0;
arguments=nargin;
ScaleData=0;
TickFlag=false;
for i=1:length(varargin)
    if ischar(varargin{i})
        arguments=arguments-1;
        if strcmpi(varargin{i},'progress') && Info.blocks>10
            ShowProgress=1;
%             progbar=progressbar(0,sprintf('Analyzing %d blocks on channel %d',Info.blocks,chan),...
%                 'Name',sprintf('%s',fopen(fid)));
        end;
        if strcmpi(varargin{i},'scale')
            ScaleData=1;
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


FileH=SONFileHeader(fid);
SizeOfHeader=20;                                            % Block header is 20 bytes long
header=SONGetBlockHeaders(fid,chan);
NumberOfMarkers=sum(header(5,startBlock:endBlock)); % Sum of samples in required blocks


nValues=Info.nExtra/2;                                                    % 2 because 2 bytes per int16 value



if TickFlag==true && ~scverLessThan('MATLAB','7')
    data.timings=zeros(NumberOfMarkers,1,'int32');
    data.markers=zeros(NumberOfMarkers,4,'uint8');
    data.adc=zeros(NumberOfMarkers,nValues,'int16');
else
    data.timings=zeros(NumberOfMarkers,1);
    data.markers=uint8(zeros(NumberOfMarkers,4));
    data.adc=int16(zeros(NumberOfMarkers,nValues));
end

count=1;
for block=startBlock:endBlock
    fseek(fid, header(1, block)+SizeOfHeader, 'bof');                         % Start of block
    for i=1:header(5,block)                                                   % loop for each marker
        data.timings(count)=fread(fid,1,'int32');                    % Time
        data.markers(count,:)=fread(fid,4,'uint8=>uint8');                    % 4x marker bytes
        data.adc(count,:)=fread(fid,nValues ,'int16=>int16');
        count=count+1;
    end;
    if ShowProgress==1 && rem(block,10)==0
        done=(block-startBlock)/max(1,endBlock-startBlock);
%         progressbar(done, progbar,...
%             sprintf('Reading Channel %d....     %3.0f%% Done',chan,done*100));
    end;
end

if(nargout>1)
    h.FileName=Info.FileName;                                   % Set up the header information to return
    h.system=['SON' num2str(FileH.systemID)];
    h.FileChannel=chan;
    h.phyChan=Info.phyChan;
    h.kind=Info.kind;
    h.npoints=NumberOfMarkers;
    h.values=Info.nExtra/2;
    h.preTrig=Info.preTrig;
    h.comment=Info.comment;
    h.title=Info.title;
    h.sampleinterval=SONGetSampleInterval(fid,chan);
    h.scale=Info.scale;
    h.offset=Info.offset;
    h.units=Info.units;
    if(isfield(Info,'interleave'))
        h.interleave=Info.interleave;
    else
        h.interleave=1;%25/8/06
    end;
end;

[data.timings,h.TimeUnits]=SONTicksToSeconds(fid,data.timings,varargin{:});                % Convert time
h.Epochs={startBlock endBlock 'of' Info.blocks 'blocks'};

if ScaleData
    [data, h]=SONADCToDouble(data, h);
end;

if ShowProgress==1
%     close(progbar);
    drawnow;
end;
