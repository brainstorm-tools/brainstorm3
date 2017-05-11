function result=scverLessThan(toolboxstr, verstr)
% scverLessThan is needed for MATLAB versions without the verLessThan function

try
    result=verLessThan(toolboxstr, verstr);
catch
    toolboxver = ver(toolboxstr);
    toolboxParts = getParts(toolboxver(1).Version);
    verParts = getParts(verstr);
    
    result = (sign(toolboxParts - verParts) * [1; .1; .01]) < 0;
end
return
end

function parts = getParts(V)
parts = sscanf(V, '%d.%d.%d')';
if length(parts) < 3
    parts(3) = 0;
end
return
end