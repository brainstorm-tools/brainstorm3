function obj = updateImage(obj, imageIndex)

% HEATMAPS
% z: ...[DONE]
% x: ...[DONE]
% y: ...[DONE]
% name: ...[DONE]
% zauto: ...[DONE]
% zmin: ...[DONE]
% zmax: ...[DONE]
% colorscale: ...[DONE]
% reversescale: ...[DONE]
% showscale: ...[DONE]
% colorbar: ...[HANDLED BY COLORBAR]
% zsmooth: ...[NOT SUPPORTED BY MATLAB]
% opacity: ---[TODO]
% xaxis: ...[DONE]
% yaxis: ...[DONE]
% showlegend: ...[DONE]
% stream: ...[HANDLED BY PLOTLYSTREAM]
% visible: ...[DONE]
% x0: ...[NOT SUPPORTED IN MATLAB]
% dx: ...[NOT SUPPORTED IN MATLAB]
% y0: ...[NOT SUPPORTED IN MATLAB]
% dy: ...[NOT SUPPORTED IN MATLAB]
% xtype: ...[NOT SUPPORTED IN MATLAB]
% ytype: ...[NOT SUPPORTED IN MATLAB]
% type: ...[DONE]

%-FIGURE STRUCTURE-%
figure_data = get(obj.State.Figure.Handle);

%-AXIS STRUCTURE-%
axis_data = get(obj.State.Plot(imageIndex).AssociatedAxis);

%-AXIS INDEX-%
axIndex = obj.getAxisIndex(obj.State.Plot(imageIndex).AssociatedAxis);

%-CHECK FOR MULTIPLE AXES-%
[xsource, ysource] = findSourceAxis(obj,axIndex);

%-IMAGE DATA STRUCTURE- %
image_data = get(obj.State.Plot(imageIndex).Handle);

%-AXIS DATA-%
eval(['xaxis = obj.layout.xaxis' num2str(xsource) ';']);
eval(['yaxis = obj.layout.yaxis' num2str(ysource) ';']);

%-------------------------------------------------------------------------%

%-image xaxis-%
obj.data{imageIndex}.xaxis = ['x' num2str(xsource)];

%-------------------------------------------------------------------------%

%-image yaxis-%
obj.data{imageIndex}.yaxis = ['y' num2str(ysource)];

%-------------------------------------------------------------------------%

%-image type-%
obj.data{imageIndex}.type = 'heatmap';

%-------------------------------------------------------------------------%

%-image x-%
if (size(image_data.XData,2) == 2)
    obj.data{imageIndex}.x = image_data.XData(1):image_data.XData(2);
else
    obj.data{imageIndex}.x = image_data.XData;
end

%-------------------------------------------------------------------------%

%-image y-%
if (size(image_data.YData,2) == 2)
    obj.data{imageIndex}.y = image_data.YData(1):image_data.YData(2);
else
    obj.data{imageIndex}.y = image_data.YData;
end

%-------------------------------------------------------------------------%

%-image z-%
if(size(image_data.CData,3) > 1)
    % TODO: ALLOW FOR TRUE COLOUR SPECS.
    obj.data{imageIndex}.z = image_data.CData(:,:,1);
else
    obj.data{imageIndex}.z = image_data.CData;
end

%-------------------------------------------------------------------------%

%-image name-%
obj.data{imageIndex}.name = image_data.DisplayName;

%-------------------------------------------------------------------------%

%-image visible-%
obj.data{imageIndex}.visible = strcmp(image_data.Visible,'on');

%-------------------------------------------------------------------------%

%-image showscale-%
obj.data{imageIndex}.showscale = false;

%-------------------------------------------------------------------------%

%-image zauto-%
obj.data{imageIndex}.zauto = false;

%-------------------------------------------------------------------------%

%-image zmin-%
obj.data{imageIndex}.zmin = axis_data.CLim(1);

%-------------------------------------------------------------------------%

%-image zmax-%
obj.data{imageIndex}.zmax = axis_data.CLim(2);

%-------------------------------------------------------------------------%

%-COLORSCALE (ASSUMES IMAGE CDATAMAP IS 'SCALED')-%

%-image colorscale-%
colormap = figure_data.Colormap;

for c = 1:length(colormap)
    col =  255*(colormap(c,:));
    obj.data{imageIndex}.colorscale{c} = {(c-1)/length(colormap), ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')']};
end

%-------------------------------------------------------------------------%

%-image showlegend-%
leg = get(image_data.Annotation);
legInfo = get(leg.LegendInformation);

switch legInfo.IconDisplayStyle
    case 'on'
        showleg = true;
    case 'off'
        showleg = false;
end

obj.data{imageIndex}.showlegend = showleg;

%-------------------------------------------------------------------------%

end

