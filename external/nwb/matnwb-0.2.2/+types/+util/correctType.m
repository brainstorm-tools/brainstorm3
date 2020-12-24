function val = correctType(val, type)
%CORRECTTYPE
%   Will error if type is simply incompatible
%   Will throw if casting is impossible

%check different types and correct

if startsWith(type, 'float')
% Compatibility with PyNWB
%     if strcmp(type, 'float32')
%         val = single(val);
%     else
        val = double(val);
%     end
elseif startsWith(type, 'int') || startsWith(type, 'uint')
    if strcmp(type, 'int')
        val = int32(val);
    elseif strcmp(type, 'uint')
        val = uint32(val);
    else
        val = feval(type, val);
    end
elseif strcmp(type, 'numeric') && ~isnumeric(val)
    val = double(val);
elseif strcmp(type, 'bool')
    val = logical(val);
end
end