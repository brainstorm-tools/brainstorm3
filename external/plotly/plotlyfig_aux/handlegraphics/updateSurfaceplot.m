function obj = updateSurfaceplot(obj, surfaceIndex)

%-AXIS INDEX-%
axIndex = obj.getAxisIndex(obj.State.Plot(surfaceIndex).AssociatedAxis);

%-CHECK FOR MULTIPLE AXES-%
[xsource, ysource] = findSourceAxis(obj,axIndex);

%-SURFACE DATA STRUCTURE- %
image_data = get(obj.State.Plot(surfaceIndex).Handle);

%-AXIS DATA-%
eval(['xaxis = obj.layout.xaxis' num2str(xsource) ';']);
eval(['yaxis = obj.layout.yaxis' num2str(ysource) ';']);

%-------------------------------------------------------------------------%

%-surface xaxis-%
obj.data{surfaceIndex}.xaxis = ['x' num2str(xsource)];

%-------------------------------------------------------------------------%

%-surface yaxis-%
obj.data{surfaceIndex}.yaxis = ['y' num2str(ysource)];

%-------------------------------------------------------------------------%

% check for 3D
if any(nonzeros(image_data.ZData))
    
    %-surface type-%
    obj.data{surfaceIndex}.type = 'surface';
    
    %---------------------------------------------------------------------%
    
    %-surface x-%
    obj.data{surfaceIndex}.x = image_data.XData;
    
    %---------------------------------------------------------------------%
    
    %-surface y-%
    obj.data{surfaceIndex}.y = image_data.YData;
    
    %---------------------------------------------------------------------%
    
    %-surface z-%
    obj.data{surfaceIndex}.z = image_data.ZData;
    
else
    
    %-surface type-%
    obj = updateImage(obj, surfaceIndex);
    
    %-surface x-%
    obj.data{surfaceIndex}.x = image_data.XData(1,:);
    
    %-surface y-%
    obj.data{surfaceIndex}.y = image_data.YData(:,1);
end

%-------------------------------------------------------------------------%

%-surface name-%
obj.data{surfaceIndex}.name = image_data.DisplayName;

%-------------------------------------------------------------------------%

%-surface showscale-%
obj.data{surfaceIndex}.showscale = false;

%-------------------------------------------------------------------------%

%-surface visible-%
obj.data{surfaceIndex}.visible = strcmp(image_data.Visible,'on');

%-------------------------------------------------------------------------%

leg = get(image_data.Annotation);
legInfo = get(leg.LegendInformation);

switch legInfo.IconDisplayStyle
    case 'on'
        showleg = true;
    case 'off'
        showleg = false;
end

obj.data{surfaceIndex}.showlegend = showleg;

%-------------------------------------------------------------------------%

end
