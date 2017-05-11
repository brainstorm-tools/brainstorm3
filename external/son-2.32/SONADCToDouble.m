function[out,h]=SONADCToDouble(in,header)
% SONADCTODOUBLE scales a SON ADC channel to double precision floating point
%
% [OUT {, HEADER}]=SONADCTODOUBLE(IN {, HEADER})
%
% Applies the scale and offset supplied in HEADER to the data contained in
% IN. These values are derived form the channel header on disc.
%               OUT=(IN*SCALE/6553.6)+OFFSET
% If no HEADER is supplied as input, a scale of 1.0 and offset of 0.0
% are assumed.
% If supplied as output, HEADER will be updated with fields
% for the min and max values and channel kind will be replaced with 9 (i.e.
% the RealWave channel value).
%
%
% Malcolm Lidierth 03/02
% Updated 03/06 ML
% Copyright © The Author & King's College London 2005-2006

if(nargin<2)
    header.scale=1;
    header.offset=0;
end;

if isstruct(header)
    if(isfield(header,'kind'))
        if header.kind~=1 && header.kind~=6
            warning('SONADCToDouble: Not an  ADC or ADCMark channel on input');
            out=[];
            h=[];
            return;
        end;
    end;
end;

if ~isstruct(in)
    if strcmp(class(in),'int16')~=1 % ADC Data
        warning('SONADCToDouble: 16 bit integer expected');
        out=[];
        h=[];
        return;
    end;
else
    if strcmp(class(in.adc),'int16')~=1; % ADCMark Data
        out.adc=[];
        h=[];
        return;
    end;
end;


s=header.scale/6553.6;
o=header.offset;

if(nargin==2)
    h=header;
end;

if isstruct(in)
    out.timings=in.timings;
    out.markers=in.markers;
    out.adc=(double(in.adc)*s)+o;
    h.max=(double(max(in.adc(:)))*s)+o;
    h.min=(double(min(in.adc(:)))*s)+o;
else
    out=(double(in)*s)+o;
    h.max=(double(max(in(:)))*s)+o;
    h.min=(double(min(in(:)))*s)+o;
    h.kind=9;
end;


