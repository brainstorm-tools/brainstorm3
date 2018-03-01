function[data,header]=SONGetChannel(fid, chan, varargin)
% SONGETCHANNEL provides a gateway to the individual channel read functions.
%
% [DATA{, HEADER}]=SONGETCHANNEL(FID, CHAN{, OPTIONS});
% where:
%         FID is the matlab file handle
%         CHAN is the channel number to read (1 to Max)
%         OPTIONS if present, are a set of one or more arguments
%                   (see below)
%
%         DATA receives the data or structure from the read operation.
%         HEADER, if present, receives the channel header information
%
% When present, OPTIONS must be the last input argument. Valid options
% are:
% 'ticks', 'microseconds', 'milliseconds' and 'seconds' cause times to
%    be scaled to the appropriate unit (seconds by default)in HEADER
% 'scale' - calls SONADCToDouble to apply the channel scale and offset to DATA
%    which will  be cast to double precision
% 'progress' - causes a progress bar to be displayed during the read.
% 'mat' - the loaded data will be appended to the MAT-file whose name
%         is supplied in the next optional input e.g.:
%       [d,h]=SONGetADCChannel(fid,5,'progress','mat','myfile.mat');
%       In this case, d will be stored in variable chan5.
%       Use SONImport in preference to  this option or, better, ImportSMR in
%       sigTOOL.
%
% See also SONIMPORT
%
% Malcolm Lidierth 02/02
% Updated 06/07 ML
%       Error checking now allows Spike for Mac files to be loaded
% Copyright © The Author & King's College London 2002-2006

MatFlag=0;
SizeOfHeader=20;    % Block header is 20 bytes long

v=ver;
if str2double(v(1).Version)>=7
    fv='-v6';
else
    fv='';
end

if ischar(fid)==1
    warning('SONGetChannel: expecting a file handle from fopen(), not a string "%s" on input',fid );
    data=[];
    header=[];
    return;
end;


[path, name, ext]=fileparts(fopen(fid));
if strcmpi(ext,'.smr') ~=1 && strcmpi(ext,'.son') ~=1
    warning('SONGetChannel: file handle points to "%s". \nThis is not a valid Spike file',fopen(fid));
    data=[];
    header=[];
    return;
end;


Info=SONChannelInfo(fid,chan);
if(Info.kind==0)
    data=[];
    header=[];
    return;
end;

for i=1:length(varargin)
    if strcmpi(varargin{i},'mat');
        MatFlag=1;
        matfilename=varargin{i+1};
    end
end

switch Info.kind
    case {1}
        [data,header]=SONGetADCChannel(fid,chan,varargin{:});
    case {2,3,4}
        [data,header]=SONGetEventChannel(fid,chan,varargin{:});
    case {5}
        [data,header]=SONGetMarkerChannel(fid,chan,varargin{:});
    case {6}
        [data,header]=SONGetADCMarkerChannel(fid,chan,varargin{:});
        data.adc=data.adc';
        header.transpose=1;
    case {7}
        [data,header]=SONGetRealMarkerChannel(fid,chan,varargin{:});
        data.real=data.real';
        header.transpose=1;
    case {8}
        [data,header]=SONGetTextMarkerChannel(fid,chan,varargin{:});
        data.text=data.text';
        header.transpose=1;
    case {9}
        [data,header]=SONGetRealWaveChannel(fid,chan,varargin{:});
    otherwise
        warning('SONGetChannel: Channel type not supported');
        data=[];
        header=[];
        return;
end;

if MatFlag==1 && ~isempty(data)
    switch Info.kind
        case{2,3,4,5,6,7,8}
            temp=['chan' num2str(chan,'%d')];
            eval(sprintf('%s=data;',temp));
            save(matfilename,temp,'-append',fv);
    end
end

switch Info.kind
    case {6,7}
        if isempty(header)==0
            header.transpose=0;
        end;
end;

% Uncomment this if you want the header stored also (do not do this if
% using sigTOOL)

% if MatFlag==1 && ~isempty(header)
%     temp=['head' num2str(chan,'%d')];
%     eval(sprintf('%s=header;',temp));
%     save(matfilename,temp,'-append',fv);
% end

















