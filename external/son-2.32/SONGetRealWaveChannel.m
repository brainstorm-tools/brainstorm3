function[data,h]=SONGetRealWaveChannel(fid, chan, varargin)
% SONGETREALWAVECHANNEL reads an ADC (waveform) channel from a SON file.
%
% [DATA {, HEADER}]=SONGETREALWAVECHANNEL(FID,...
%                       CHAN{, START{, STOP{, OPTIONS}}})
% FID is the matlab file handle, CHAN is the channel number (1=max)
%
% [DATA, HEADER]=SONGETREALWAVECHANNEL(FID, 1{, OPTIONS})
%       reads all the data on channel 1
% [DATA, HEADER]=SONGETREALWAVECHANNEL(FID, 1, 10{, OPTIONS})
%       reads disc block 10 for continuous data or epoch 10 for triggered
%       data
% [DATA, HEADER]=SONGETREALWAVECHANNEL(FID, 1, 10, 20{, OPTIONS})
%       reads disc blocks 10-20 for continuous data or epochs 10-20
%       for triggered data
%
% When present, OPTIONS must be the last input argument. Valid options
% are:
% 'ticks', 'microseconds', 'milliseconds' and 'seconds' cause times to
%    be scaled to the appropriate unit (seconds by default)in HEADER
% 'progress' - causes a progress bar to be displayed during the read.
% 'mat' - the loaded data will be appended to the MAT-file specified 
%         in the next optional input e.g.:
%       [d,h]=SONGetADCChannel(fid,1,'progress','mat','myfile.mat');

%
% For continuously sampled data, DATA is a simple vector.
% If sampling was triggered, DATA will be  2-dimensional matrix
% with each epoch (frame) of data in a separate row.
%
% Examples:
% [data, header]=SONGetADCChannel(fid, 1, 'ticks')
%      reads all data on channel 1 returning an int16 vector or matrix
%      Times in header will be in clock ticks
%
% options={'progress' 'ticks'}
% [data, header]=SONGetRealWaveChannel(fid, 1, 200, 399, options{:})
%    reads epochs 200-399 from channel 1 and displays a progress bar. Data is
%    returned in double-precision floating point. If sampling was
%    continuous, data will be a vector containing data blocks 200-399.
%    If triggered, data will be a 200 row matrix, each row containing one
%    data epoch.
%
% HEADER could have the following example field values
%       FileName: source filename (and path)
%         system: SON version identifier
%    FileChannel: Channel number in file
%        phyChan: Physical (hardware) port.
%           kind: 9 - channel type identifier
%        comment: Channel comment
%          title: Channel title
% sampleinterval: sampling interval in microseconds (Changed in v2.2)
%            min: minimum value loaded
%            max: maximum value loaded
%          units: Channel units
%        npoints: e.g. [1x200 double] number of valid data points
%                   in each column of DATA
%           mode: 'Triggered' or 'Continuous' sampling
%          start: e.g [1x200 double] start time for each column in data
%                       in 'TimeUnits'
%           stop: e.g. [1x200 double] end time for each column in data
%                       in 'TimeUnits'
%         Epochs: a cell array e.g. {[200]  [399]  'of'  [961]  'epochs'}
%                       lists the blocks or epochs read
%      TimeUnits: e.g. 'Ticks' the time units
%      transpose: default 0, a flag, 0 for row-wise and 1 for columnwise
%      organization of data
%
%   See also 
%
%   See also SONGETADCCHANNEL
%
% 11/03/06
% Memory pre-allocations changed to speed up execution
% SONADCToDouble code embedded in function
% Memory mapping embedded in function
% 20/5/06
% Varargin handling tidied
% Memory mapping improved. Now uses the ADCARRAY class
% 12/7/06
% Memory mapping removed. Now files data in a Level 5 Version 6
% compatible MAT file. Use 'where.m' to map the MAT-file.
% 20/02/08
% Always build header, whether nargout==2 or not

% Malcolm Lidierth 03/02
% Updated 07/06 ML
% Copyright © The Author & King's College London 2002-2006

try


% Get MATLAB version number
v=ver;
v=str2double(v(1).Version);

% Get Channel information
Info=SONChannelInfo(fid,chan);
if isempty (Info)
    data=[];
    h=[];
    return;
end;
if Info.kind ~=9
    warning('SONGetRealWaveChannel: Channel #%d No data or not a RealWave channel',chan);
    data=[];
    h=[];
    return;
end;

% Set up for optional arguments
ShowProgress=0;
ScaleData=0;
MatFlag=0;
arguments=nargin;
for i=1:length(varargin)
    if ischar(varargin{i})==1
        arguments=arguments-1;% decrement for all char entries
        switch varargin{i}
            case 'progress'
                if Info.blocks>10
                    ShowProgress=1;
%                     progbar=progressbar(0,sprintf('Analyzing %d blocks on channel %d',Info.blocks,chan),...
%                         'Name',sprintf('%s',fopen(fid)));
                end;

            case 'mat'
                %arguments=arguments-1;% decrement again for map
                MatFlag=1;
                fname=varargin{i+1};
                fh=OpenMATFile(fname);
                temp=whos(['chan' num2str(chan)],'-file',fname);
                if ~isempty(temp)
                    warning('SONGetADCChannel: This channel has already been saved to %s',fname);
                    data=[];
                    h=[];
					fclose(fh);
                    if ShowProgress==1
%                         close(progbar);
                        drawnow;
                    end;
                    return;
                end;
        end;
    end;
end;

if MatFlag==1
    Offset=InitMATDataElementHeader(fh, chan, ScaleData);
end

% Set up header
FileH=SONFileHeader(fid);
SizeOfHeader=20;                                            % Block header is 20 bytes long
header=SONGetBlockHeaders(fid,chan);


SampleInterval=(header(3,1)-header(2,1))/(header(5,1)-1);   % Sample interval in clock ticks

% 20.02.08 Remove IF
h.FileName=Info.FileName;                                   % Set up the header information to return
h.system=['SON' num2str(FileH.systemID)];                   % if wanted
h.FileChannel=chan;
h.phyChan=Info.phyChan;
h.kind=Info.kind;
%h.blocks=Info.blocks;
%h.preTrig=Info.preTrig;
h.comment=Info.comment;
h.title=Info.title;
h.sampleinterval=SONGetSampleInterval(fid,chan);
h.scale=6535.6;% added 16/8/06
h.offset=0;
h.min=Inf;
h.max=-Inf;
h.units=Info.units;
h.interleave=1;%25/8/06



NumFrames=1;                                                % Number of frames. Initialize to one.
Frame(1)=1;
for i=1:Info.blocks-1                                       % Check for discontinuities in data record
    IntervalBetweenBlocks=header(2,i+1)-header(3,i);
    if IntervalBetweenBlocks>SampleInterval                 % If true data is discontinuous (triggered)
        NumFrames=NumFrames+1;                              % Count discontinuities (NumFrames)
        Frame(i+1)=NumFrames;                               % Record the frame number that each block belongs to
    else
        Frame(i+1)=Frame(i);                                % Pad between discontinuities
    end;
end;

switch arguments
    case {2}
        FramesToReturn=NumFrames;
        h.npoints=zeros(1,FramesToReturn);
        startEpoch=1;           %Read all data
        endEpoch=Info.blocks;
    case {3}
        if NumFrames==1                     % Read one epoch
            startEpoch=varargin{1};
            endEpoch=varargin{1};
        else
            FramesToReturn=1;
            h.npoints=0;
            startEpoch=find(Frame<=varargin{1});
            endEpoch=startEpoch(end);
            startEpoch=endEpoch;
        end;
    case {4}
        if NumFrames==1
            startEpoch=varargin{1};         % Read a range of epochs
            endEpoch=varargin{2};
        else
            FramesToReturn=varargin{2}-varargin{1}+1;
            h.npoints=zeros(1,FramesToReturn);
            startEpoch=find(Frame==varargin{1});
            startEpoch=startEpoch(1);
            endEpoch=find(Frame<=varargin{2});
            endEpoch=endEpoch(end);
        end;

end;

% Make sure we are in range if using START and STOP
if (startEpoch>Info.blocks || startEpoch>endEpoch)
    data=[];
    h=[];
%     close(progbar);
    warning('SONGetRealWaveChannel: Invalid START and/or STOP')
    return;
end;
if endEpoch>Info.blocks
    endEpoch=Info.blocks;
end;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Continuous sampling
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if NumFrames==1
    if MatFlag==1
        NumberOfSamples=max(header(5,:)); %  Map each block in turn
        count=0; %count elements written - last block may contain fewer points
    else
        NumberOfSamples=sum(header(5,startEpoch:endEpoch));     % Sum of samples in all blocks
    end;
       if v>=7
            data=zeros(NumberOfSamples,1,'single'); %Version 7
        else

    		data=single(zeros(NumberOfSamples, 1));                   % Pre-allocate memory for data
       end;
    readformat='single=>single';
    pointer=1;

    h.mode='Continuous';
    h.npoints=sum(header(5,startEpoch:endEpoch));
    h.start=header(2,startEpoch); % Time of first data point (clock ticks)
    h.stop=header(3,endEpoch);    % End of data (clock ticks)

    for i=startEpoch:endEpoch
        fseek(fid,header(1,i)+SizeOfHeader,'bof');
        if MatFlag==1
            data(1:header(5,i))=fread(fid,header(5,i),readformat);
            count=count+fwrite(fh, data(1:header(5,i)),class(data));
            h.min=min(h.min,min(data(1:header(5,i))));
            h.max=max(h.max,max(data(1:header(5,i))));
            data(1:end)=NaN;
        else
            data(pointer:pointer+header(5,i)-1)=fread(fid,header(5,i),readformat);
            pointer=pointer+header(5,i);
        end;
        
        if ShowProgress==1 && rem(i,10)==0
            done=(i-startEpoch)/max(1,endEpoch-startEpoch);
%             progressbar(done, progbar,...
%                 sprintf('Reading Channel %d....     %3.0f%% Done',chan,done*100));
        end;
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Triggered sampling
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
else
    NumberOfSamples=sum(header(5,startEpoch:endEpoch));  % Sum of samples in required epochs
    FrameLength=GetFrameLengths(Frame,header);% Maximum data points to a frame

    if MatFlag==1
        if v>=7
            data=zeros(1,FrameLength,'single');%Version 7
        else
            data=single(zeros(1,FrameLength));
        end;
    else
        if v>=7
            data=zeros(FrameLength, FramesToReturn,'single');%Version 7
        else
            data=single(zeros(FrameLength, FramesToReturn));

        end;
    end;
    readformat='single=>single';
    count=0;
    p=1;                  % Pointer into data array for each disk data block
    Frame(Info.blocks+1)=-99; % Dummy entry to avoid index error in for loop
    h.mode='Triggered';
    h.start(1)=header(2,startEpoch);% Time of first data point in first returned epoch (clock ticks)
    index=1; %epoch counter

    for i=startEpoch:endEpoch
        fseek(fid,header(1,i)+SizeOfHeader,'bof');
        if MatFlag==1
            data(p:p+header(5,i)-1)=fread(fid,header(5,i),readformat);
            h.min=min(h.min,min(data(p:p+header(5,i)-1)));
            h.max=max(h.max,max(data(p:p+header(5,i)-1)));
        else
            data(p:p+header(5,i)-1,index)=fread(fid,header(5,i),readformat);
        end;
        h.npoints(index)=h.npoints(index)+header(5,i);
        if Frame(i+1)==Frame(i)
            p=p+header(5,i);               % Increment pointer or.....
        else
            h.stop(index)=header(3,i);     % End time for this frame, clock ticks
            if MatFlag==1
                if ScaleData==1
                    s=h.scale/6553.6;
                    o=h.offset;
                    data=data*s+o;
                end;
                count=count+fwrite(fh, data, class(data));
                data(1:end)=NaN;% will be zero for int16
            end;
            if(i<endEpoch)
                p=1;                          % begin new frame
                index=index+1;
                h.start(index)=header(2,i+1); % Time of first data point in next frame (clock ticks)
            end;
        end;
        if ShowProgress==1 && rem(i,10)==0
            done=(i-startEpoch)/max(1,endEpoch-startEpoch);
%             progressbar(done, progbar,...
%                 sprintf('Reading Channel %d....     %3.0f%% Done',chan,done*100));
        end;
    end;
end;

% Complete header set up
if NumFrames==1
    h.Epochs={startEpoch endEpoch 'of' Info.blocks 'blocks'};
else
    h.Epochs={startEpoch endEpoch 'of' NumFrames 'epochs'};
end;
[h.start,h.TimeUnits]=SONTicksToSeconds(fid,h.start,varargin{:});
[h.stop,h.TimeUnits]=SONTicksToSeconds(fid,h.stop,varargin{:});


h.transpose=1;
if ShowProgress==1
%     close(progbar);
    drawnow;
end;

if MatFlag==1
    if NumFrames==1
        rows=count;
        columns=1;
    else
        rows=FrameLength;
        columns=FramesToReturn;
    end;
    CompleteMATDataElementHeader(fh,Offset,rows,columns);
    data=[];
    fclose(fh);
else
    h.min=min(data);
    h.max=min(data);
end

catch
%     close(progbar);
    data=[];
    h=[];
    fclose(fh);
    rethrow(lasterror);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function FrameLength=GetFrameLengths(Frames,header)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fl=zeros(1,length(Frames));
for j=1:length(Frames)
    fl(Frames(j))=fl(Frames(j))+header(5,j);
end;
FrameLength=max(fl);
return;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function CompleteMATDataElementHeader(fhandle, Offset, LengthOfFrame, NumOfFrames)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Save current offset - end of channel data area
pos=ftell(fhandle);
pad=8-rem(pos,8);

if pad~=8
for i=1:pad
fwrite(fhandle,0,'uint8');
end;
end;

eof=ftell(fhandle);

% Complete header for this channel
fseek(fhandle,Offset,'bof');
temp=fread(fhandle,1,'uint32');
if temp~=14
    warning('miMatrix value wrong')
end
fseek(fhandle,Offset+4,'bof');
temp=eof-Offset-8;
fwrite(fhandle,temp,'uint32');
fseek(fhandle,Offset+32,'bof');
fwrite(fhandle,LengthOfFrame,'uint32');
fwrite(fhandle,NumOfFrames,'uint32');
fseek(fhandle,Offset+60,'bof');
temp=eof-Offset-64-rem(pos,8);
fwrite(fhandle,temp,'uint32');
return;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function offset=InitMATDataElementHeader(fh, chan, ScaleData)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fseek(fh,0,'eof');
offset=ftell(fh);
fwrite(fh,14,'uint32');%miMATRIX
fwrite(fh,0,'uint32');% bytes - 0 for now
fwrite(fh,6,'uint32');%miUINT32
fwrite(fh,8,'uint32');%array flag bytes

fwrite(fh,7,'uint32',0);%mxSINGLE_CLASS

fwrite(fh,0,'uint32');%unused
fwrite(fh,5,'uint32');%miINT32
fwrite(fh,8,'uint32');
fwrite(fh,[0 0],'int32');%dimensions - fill in later
fwrite(fh,1,'uint32');%miINT8
name=['chan' num2str(chan)];
len=length(name);
fwrite(fh,len,'uint32');
fwrite(fh,name,'uint8');
% Pad to 8 byte boundary
pad=8-rem(len,8);
if pad~=8
    for i=1:pad
        fwrite(fh,0,'uint8');
    end;
end;
fwrite(fh,7,'uint32');%miSINGLE
fwrite(fh,0,'uint32');%bytes - fill in later
return;
                
