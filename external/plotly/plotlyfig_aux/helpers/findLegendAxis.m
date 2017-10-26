function legendAxis = findLegendAxis(obj,legendHandle)
  if verLessThan('matlab','9.0.0')
    legendAxisIndex = find(arrayfun(@(x)(isequal(handle(getappdata(x.Handle,'LegendPeerHandle')),legendHandle)),obj.State.Axis), 1);
  else
    legendAxisIndex = find(arrayfun(@(x)(isequal(handle(get(x.Handle,'Legend')),legendHandle)),obj.State.Axis), 1);
  end

  legendAxis = obj.State.Axis(legendAxisIndex).Handle;
end
