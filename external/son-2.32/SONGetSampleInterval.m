function[interval, start]=SONGetSampleInterval(fid,chan)
% SONGETSAMPLEINTERVAL returns the sampling interval in microseconds 
% on a waveform data channel in a SON file, i.e. the reciprocal of the
% sampling rate for the channel, together with the time of the first sample
%
% [INTERVAL{, START}]=SONGETSAMPLEINTERVAL(FID, CHAN)
% FID is the matlab file handle and CHAN is the channel number (1-max)
% The sampling INTERVAL and, if requested START time for the data are
% returned in seconds.
%
% Note that, as of Version 2.2, the returned times are always in microseconds.
% Uncomment the last line for backwards compatibility
%
% Malcolm Lidierth 02/02
% Updated 09/06 ML
% Copyright © The Author & King's College London 2002-2006


FileH=SONFileHeader(fid);                                   % File header
Info=SONChannelInfo(fid,chan);                              % Channel header
header=SONGetBlockHeaders(fid,chan);
switch Info.kind                                            % Disk block headers
    case {1,6,7,9}
        switch FileH.systemID
            case {1,2,3,4,5} % Before version 6                                               
                if (isfield(Info,'divide'))
                    interval=Info.divide*FileH.usPerTime*FileH.timePerADC;
                    start=header(2,1)*FileH.usPerTime*FileH.timePerADC;
                else
                    warning('SONGetSampleInterval: ldivide not defined Channel #%d', chan);
                    interval=[];
                    start=[];
                end;
            otherwise  % Version 6 and above                                                     
                interval=Info.lChanDvd*FileH.usPerTime*(1e6*FileH.dTimeBase);
                start=header(2,1)*FileH.usPerTime*FileH.dTimeBase;
        end;
    otherwise
        warning('SONGetSampleInterval: Invalid channel type Channel #%d',chan);
        interval=[];
        start=[];
        return;
end;

% UNCOMMENT THE LINE BELOW FOR COMPATIBILITY WITH V2.1 AND BELOW
%interval=interval*1e-6;

