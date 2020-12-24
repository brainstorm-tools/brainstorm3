function typeSize = getMatSize(type)
%GETMATSIZE Summary of this function goes here
%   Detailed explanation goes here
switch (type)
    case {'uint8', 'int8'}
        typeSize = 1;
    case {'uint16', 'int16'}
        typeSize = 2;
    case {'uint32', 'int32', 'single'}
        typeSize = 4;
    case {'uint64', 'int64', 'double'}
        typeSize = 8;
end

