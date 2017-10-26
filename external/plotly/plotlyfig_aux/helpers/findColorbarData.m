function colorbarDataIndex = findColorbarData(obj,colorbarIndex)
%locate index of data associated with colorbar
colorbarDataIndex = find(arrayfun(@(x)eq(x.AssociatedAxis,obj.State.Colorbar(colorbarIndex).AssociatedAxis),obj.State.Plot),1);
%if no matching data index found
if isempty(colorbarDataIndex)
    colorbarDataIndex = max(min(colorbarIndex,obj.State.Figure.NumPlots),1);
end
end