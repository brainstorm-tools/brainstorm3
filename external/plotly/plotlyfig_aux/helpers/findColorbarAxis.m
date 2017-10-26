function colorbarAxis = findColorbarAxis(obj,colorbarHandle)
if isHG2
    colorbarAxisIndex = find(arrayfun(@(x)(isequal(getappdata(x.Handle,'ColorbarPeerHandle'),colorbarHandle)),obj.State.Axis));
else
    colorbarAxisIndex = find(arrayfun(@(x)(isequal(getappdata(x.Handle,'LegendColorbarInnerList'),colorbarHandle) + ...
        isequal(getappdata(x.Handle,'LegendColorbarOuterList'),colorbarHandle)),obj.State.Axis));
end
colorbarAxis = obj.State.Axis(colorbarAxisIndex).Handle;
end