function [overlapping, overlapaxes] = isOverlappingAxis(obj, axIndex)

%-STANDARDIZE UNITS-%
axis_units = cell(1,axIndex);
for a = 1:axIndex
    axis_units{a} = get(obj.State.Axis(a).Handle,'Units');
    set(obj.State.Axis(a).Handle,'Units','normalized');
end

% check axis overlap
overlapaxes = find(arrayfun(@(x)(isequal(get(x.Handle,'Position'),get(obj.State.Axis(axIndex).Handle,'Position'))),obj.State.Axis(1:axIndex)));
overlapping = length(overlapaxes) > 1; %greater than 1 because obj.State.Axis(axIndex) will always be an overlapping axis

%-REVERT UNITS-%
for a = 1:axIndex
    set(obj.State.Axis(a).Handle,'Units',axis_units{a});
end

end
