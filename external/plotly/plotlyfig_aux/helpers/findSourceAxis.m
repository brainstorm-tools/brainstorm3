function [xsource, ysource, xoverlay, yoverlay] = findSourceAxis(obj, axIndex)

% initialize output
xsource = axIndex; 
ysource = axIndex;
xoverlay = false;
yoverlay = false;

% check axis overlap
[overlapping, overlapaxes] = isOverlappingAxis(obj, axIndex);

% find x/y source axis (takes non-identity overlapaxes as source)
if overlapping
    if isequal(get(obj.State.Axis(axIndex).Handle, 'XAxisLocation'), get(obj.State.Axis(overlapaxes(1)).Handle,'XAxisLocation'))
        xsource = overlapaxes(1);
    else
        xoverlay = overlapaxes(1);
    end
    if isequal(get(obj.State.Axis(axIndex).Handle, 'YAxisLocation'), get(obj.State.Axis(overlapaxes(1)).Handle,'YAxisLocation'))
        ysource = overlapaxes(1);
    else
        yoverlay = overlapaxes(1);
    end  
end

end