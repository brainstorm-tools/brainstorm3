function F = in_fread_smr(sFile, sfid, SamplesBounds, iChannels)
% IN_FREAD_MICROMED:  Read a block of recordings from a Cambridge Electronic Design Spike2 file (.smr/.son)
%
% USAGE:  F = in_fread_smr(sFile, sfid, SamplesBounds=[], iChannels=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2017

% Parse inputs
if (nargin < 4) || isempty(iChannels)
    iChannels = 1:sFile.header.num_channels;
end
if (nargin < 3) || isempty(SamplesBounds)
    SamplesBounds = sFile.prop.samples;
end





% Import the data.
for i=1:length(c)
    chan=c(i).number;
    msg=[];

    % For each channel, call the SON library function then save the data
    % in Mode 0. If this fails, it is likely to be because of an
    % out-of-memory error so use the SON library's inbuilt 'mat' option
    % to save the adc data in Mode 1. If that fails then skip to next
    % channel.
    try
        % Normal write - kcl Mode 0
        [data,header]=SONGetChannel(fid, chan,'progress','ticks');
        Mode=0;
        if isempty(data)
            % Empty channel
            continue
        end
    catch
        % Too large?: if so try Mode 1
        % SONGetADCChannel & SONGetRealWaveChannel have builtin writing.
        % This will fail again if we are trying to load a different channel
        % type.
        try
            keyboard;
            [data,header]=SONGetChannel(fid, chan,'progress','ticks','mat',matfilename);
            % SON library uses chan1, chan2 etc. Convert to adc1, adc2...
            VarRename(matfilename,['chan' num2str(chan)],...
                ['adc' num2str(chan)]);
            Mode=1;
        catch
            % Failed again
            % Go to next channel
            continue;
        end
    end

    hdr.channel=chan;
    hdr.source=dir(header.FileName);
    hdr.source.name=header.FileName;
    hdr.title=header.title;
    hdr.comment=header.comment;
    if strcmpi(hdr.title,'Keyboard')
        hdr.markerclass='char';
    else
        hdr.markerclass='uint8';
    end

    switch header.kind
        case {1,9}% Waveform int16 or single in SMR file

            imp.tim(:,1)=int32(header.start);
            imp.tim(:,2)=int32(header.stop);
            imp.adc=data;
            imp.mrk=zeros(size(imp.tim,1),4,'uint8');

            if size(imp.adc,2)==1
                hdr.channeltype='Continuous Waveform';
                hdr.channeltypeFcn='';
                hdr.adc.Labels={'Time'};
            else
                hdr.channeltype='Episodic Waveform';
                hdr.adc.Labels={'Time' 'Epoch'};
            end

            hdr.adc.TargetClass='adcarray';
            hdr.adc.SampleInterval=[header.sampleinterval 1e-6];
            if header.kind==1
                hdr.adc.Scale=header.scale/6553.6;
                hdr.adc.DC=header.offset;
            else
                hdr.adc.Scale=1;
                hdr.adc.DC=0;
            end
            hdr.adc.Func=[];
            hdr.adc.Units=header.units;
            hdr.adc.Multiplex=header.interleave;
            hdr.adc.MultiInterval=[0 0];%not known from SMR format
            hdr.adc.Npoints=header.npoints;
            if Mode==0
                hdr.adc.YLim=[double(min(data(:)))*...
                hdr.adc.Scale+hdr.adc.DC...
                double(max(data(:)))*hdr.adc.Scale+hdr.adc.DC];
            else
                hdr.adc.YLim=[header.min header.max]*...
                    hdr.adc.Scale+hdr.adc.DC;
            end

            hdr.tim.Class='tstamp';
            % NB avoid IEEE rounding error
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {2,3}% Event+ or Event- in SMR file
            imp.tim(:,1)=data;
            imp.adc=[];
            imp.mrk=zeros(size(imp.tim,1),4,'uint8');
            if header.kind==2
                hdr.channeltype='Falling Edge';
            else
                hdr.channeltype='Rising Edge';
            end
            hdr.channeltypeFcn='';
            hdr.adc=[];

            hdr.tim.Class='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {4}% EventBoth in SMR file
            if header.initLow==0 % insert a rising edge...
                data=vertcat(-1, data);   % ...if initial state is high
            end
            imp.tim(:,1)=data(1:2:end-1);% rising edges
            imp.tim(:,2)=data(2:2:end);% falling edges
            imp.adc=[];
            imp.mrk=zeros(size(imp.tim,1),4,'uint8');

            hdr.channeltype='Pulse';
            hdr.channeltypeFcn='';
            hdr.adc=[];

            hdr.tim.Class='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {5}% Marker channel in SMR file
            imp.tim(:,1)=data.timings;
            imp.adc=[];
            imp.mrk=data.markers;

            hdr.channeltype='Edge';
            hdr.channeltypeFcn='';
            hdr.adc=[];

            hdr.tim.Class='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {6}% int16 ADC Marker in SMR file
            imp.tim(:,1)=data.timings;
            % 24.02.08 remove -1 and include interleave factor
            imp.tim(:,2)=data.timings...
                +(SONGetSampleTicks(fid,chan)*(header.preTrig));
            imp.tim(:,3)=data.timings...
                +(SONGetSampleTicks(fid,chan)*(header.values/header.interleave-1));

            imp.adc=data.adc;
            imp.mrk=data.markers;

            hdr.channeltype='Framed Waveform (Spike)';
            hdr.channeltypeFcn='';

            hdr.adc.Labels={'Time' 'Spike'};
            hdr.adc.TargetClass='adcarray';
            hdr.adc.SampleInterval=[header.sampleinterval 1e-6];
            hdr.adc.Scale=header.scale/6553.6;
            hdr.adc.DC=header.offset;
            hdr.adc.YLim=[double(min(data.adc(:)))*hdr.adc.Scale+hdr.adc.DC...
                double(max(data.adc(:)))*hdr.adc.Scale+hdr.adc.DC];
            hdr.adc.Func=[];
            hdr.adc.Units=header.units;
            hdr.adc.Npoints(1:size(imp.adc,2))=header.values;
            hdr.adc.Multiplex=header.interleave;
            hdr.adc.MultiInterval=[0 0];%not known from SMR format

            hdr.tim.TargetClass='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        case {7,8}% Real marker or text marker in SMR file
            imp.tim(:,1)=data.timings;
            switch header.kind
                case 7
                    imp.adc=data.real;
                    hdr.channeltype='Edge';
                    hdr.adc.TargetClass='single';
                    hdr.channeltypeFcn='';
                    hdr.adc.Labels={'Single'};
                case 8
                    imp.adc=data.text;
                    hdr.channeltype='Edge';
                    hdr.adc.TargetClass='char';
                    hdr.channeltypeFcn='SONMarkerDisplay';
                    hdr.adc.Labels={'Text'};
            end
            imp.mrk=data.markers;            
            hdr.adc.SampleInterval=NaN;
            hdr.adc.Func=[];
            hdr.adc.Scale=1;
            hdr.adc.DC=0;
            hdr.adc.Units='';
            hdr.adc.Multiplex=NaN;
            hdr.adc.MultiInterval=[0 0];%not known from SMR format
            hdr.adc.Npoints(1:size(imp.adc,2))=header.values;

            hdr.tim.TargetClass='tstamp';
            hdr.tim.Scale=F.usPerTime;
            hdr.tim.Shift=0;
            hdr.tim.Func=[];
            hdr.tim.Units=F.dTimeBase;

        otherwise
            continue
    end
    %Modified by Timo
    dataInMemory(i).hdr = hdr;
    dataInMemory(i).imp = imp;
    dataInMemory(i).Mode = Mode;
    dataInMemory(i).numer = chan;
    clear('imp','hdr','data','header');
end



%%%%%%%%%%%%%





% ===== COMPUTE OFFSETS =====
nChannels     = double(sFile.header.num_channels);
nReadTimes    = SamplesBounds(2) - SamplesBounds(1) + 1;
nReadChannels = double(ChannelsRange(2) - ChannelsRange(1) + 1);
% Data type
bytesPerVal = sFile.header.num_bytes;
switch bytesPerVal
    case 1, dataClass = 'uint8';
    case 2, dataClass = 'uint16';
    case 4, dataClass = 'uint32';
end

% Time offset
offsetTime = round(SamplesBounds(1) * nChannels * bytesPerVal);
% Channel offset at the beginning and end of each channel block
offsetChannelStart = round((ChannelsRange(1)-1) * bytesPerVal);
offsetChannelEnd   = (nChannels - ChannelsRange(2)) * bytesPerVal;
% Start reading at this point
offsetStart = sFile.header.data_offset + offsetTime + offsetChannelStart;
% Number of time samples to skip after each channel
offsetSkip = offsetChannelStart + offsetChannelEnd; 

% ===== READ DATA BLOCK =====
% Position file at the beginning of the trial
fseek(sfid, offsetStart, 'bof');
% Read trial data
% => WARNING: CALL TO FREAD WITH SKIP=0 DOES NOT WORK PROPERLY
if (offsetSkip == 0)
    F = fread(sfid, [nReadChannels, nReadTimes], dataClass);
else
    precision = sprintf('%d*%s', nReadChannels, dataClass);
    F = fread(sfid, [nReadChannels, nReadTimes], precision, offsetSkip);
end
% Check that data block was fully read
if (numel(F) < nReadTimes * nReadChannels)
    % Error message
    disp(sprintf('BST> ERROR: File is truncated (%d values were read instead of %d)...', numel(F), nReadTimes * nReadChannels));
    % Pad with zeros 
    Ftmp = zeros(nReadChannels, nReadTimes);
    Ftmp(1:numel(F)) = F(:);
    F = Ftmp;
end
% Apply gains
chan = sFile.header.electrode(ChannelsRange(1):ChannelsRange(2));
F = bst_bsxfun(@minus,   F, [chan.logicGround]');
F = bst_bsxfun(@rdivide, F, [chan.logicMax]' - [chan.logicMin]' + 1);
F = bst_bsxfun(@times,   F, [chan.physicalMin]' - [chan.physicalMax]');
% Convert from to Volts
F = bst_bsxfun(@times, F, [chan.unit_gain]');


