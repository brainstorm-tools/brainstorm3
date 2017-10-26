function obj = updateContourgroup(obj,contourIndex)

% z: ...[DONE]
% x: ...[DONE]
% y: ...[DONE]
% name: ...[DONE]
% zauto: ...[DONE]
% zmin: ...[DONE]
% zmax: ...[DONE]
% autocontour: ...[DONE]
% ncontours: ...[N/A]
% contours: ...[DONE]
% colorscale: ...[DONE]
% reversescale: ...[DONE]
% showscale: ...[DONE]
% colorbar: ...[DONE]
% opacity: ---[TODO]
% xaxis: ...[DONE]
% yaxis: ...[DONE]
% showlegend: ...[DONE]
% stream: ...[HANDLED BY PLOTLYSTREAM]
% visible: ...[DONE]
% x0: ...[DONE]
% dx: ...[DONE]
% y0: ...[DONE]
% dy: ...[DONE]
% xtype: ...[DONE]
% ytype: ...[DONE]
% type: ...[DONE]

% LINE

% color: ...[DONE]
% width: ...[DONE]
% dash: ...[DONE]
% opacity: ---[TODO]
% shape: ...[NOT SUPPORTED IN MATLAB]
% smoothing: ...[DONE]
% outliercolor: ...[N/A]
% outlierwidth: ...[N/A]

%-FIGURE DATA STRUCTURE-%
figure_data = get(obj.State.Figure.Handle);

%-AXIS INDEX-%
axIndex = obj.getAxisIndex(obj.State.Plot(contourIndex).AssociatedAxis);

%-AXIS DATA STRUCTURE-%
axis_data = get(obj.State.Plot(contourIndex).AssociatedAxis);

%-PLOT DATA STRUCTURE- %
contour_data = get(obj.State.Plot(contourIndex).Handle);

%-CHECK FOR MULTIPLE AXES-%
[xsource, ysource] = findSourceAxis(obj,axIndex);

%-AXIS DATA-%
eval(['xaxis = obj.layout.xaxis' num2str(xsource) ';']);
eval(['yaxis = obj.layout.yaxis' num2str(ysource) ';']);

%-------------------------------------------------------------------------%

%-contour xaxis-%
obj.data{contourIndex}.xaxis = ['x' num2str(xsource)];

%-------------------------------------------------------------------------%

%-contour yaxis-%
obj.data{contourIndex}.yaxis = ['y' num2str(ysource)];

%-------------------------------------------------------------------------%

%-contour type-%
obj.data{contourIndex}.type = 'contour';

%-------------------------------------------------------------------------%

%-contour name-%
obj.data{contourIndex}.name = contour_data.DisplayName;

%-------------------------------------------------------------------------%

%-contour x data-%
if ~isvector(contour_data.XData)
    obj.data{contourIndex}.x = contour_data.XData(1,:);
else
    obj.data{contourIndex}.x = contour_data.XData;
end

%-------------------------------------------------------------------------%

%-contour y data-%
if ~isvector(contour_data.YData)
    obj.data{contourIndex}.y = contour_data.YData(:,1)';
else
    obj.data{contourIndex}.y = contour_data.YData';
end

%-------------------------------------------------------------------------%

%-contour z data-%
obj.data{contourIndex}.z = contour_data.ZData;

%-------------------------------------------------------------------------%

%-contour x type-%

obj.data{contourIndex}.xtype = 'array';

%-------------------------------------------------------------------------%

%-contour y type-%

obj.data{contourIndex}.ytype = 'array';

%-------------------------------------------------------------------------%

%-contour visible-%

obj.data{contourIndex}.visible = strcmp(contour_data.Visible,'on');

%-------------------------------------------------------------------------%

%-contour showscale-%
obj.data{contourIndex}.showscale = false;

%-------------------------------------------------------------------------%

%-zauto-%
obj.data{contourIndex}.zauto = false;

%-------------------------------------------------------------------------%

%-zmin-%
obj.data{contourIndex}.zmin = axis_data.CLim(1);

%-------------------------------------------------------------------------%

%-zmax-%
obj.data{contourIndex}.zmax = axis_data.CLim(2);

%-------------------------------------------------------------------------%

%-colorscale (ASSUMES PATCH CDATAMAP IS 'SCALED')-%
colormap = figure_data.Colormap;

for c = 1:size((colormap),1)
    col =  255*(colormap(c,:));
    obj.data{contourIndex}.colorscale{c} = {(c-1)/(size(colormap,1)-1), ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')']};
end

%-------------------------------------------------------------------------%

%-contour reverse scale-%
obj.data{contourIndex}.reversescale = false;

%-------------------------------------------------------------------------%

%-autocontour-%
obj.data{contourIndex}.autocontour = false;

%-------------------------------------------------------------------------%

%-contour contours-%

%-coloring-%
switch contour_data.Fill
    case 'off'
        obj.data{contourIndex}.contours.coloring = 'lines';
    case 'on'
        obj.data{contourIndex}.contours.coloring = 'fill';
end

%-start-%
obj.data{contourIndex}.contours.start = contour_data.TextList(1);

%-end-%
obj.data{contourIndex}.contours.end = contour_data.TextList(end);

%-step-%
obj.data{contourIndex}.contours.size = diff(contour_data.TextList(1:2));

%-------------------------------------------------------------------------%

if(~strcmp(contour_data.LineStyle,'none'))
    
    %-contour line colour-%
    if isnumeric(contour_data.LineColor)
        col = 255*contour_data.LineColor;
        obj.data{contourIndex}.line.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    else
        obj.data{contourIndex}.line.color = 'rgba(0,0,0,0)';
    end
    
    %-contour line width-%
    obj.data{contourIndex}.line.width = contour_data.LineWidth;
    
    %-contour line dash-%
    switch contour_data.LineStyle
        case '-'
            LineStyle = 'solid';
        case '--'
            LineStyle = 'dash';
        case ':'
            LineStyle = 'dot';
        case '-.'
            LineStyle = 'dashdot';
    end
    
    obj.data{contourIndex}.line.dash = LineStyle;
    
    %-contour smoothing-%
    obj.data{contourIndex}.line.smoothing = 0;
    
else
    
    %-contours showlines-%
    obj.data{contourIndex}.contours.showlines = false;
    
end

%-------------------------------------------------------------------------%

%-contour showlegend-%

leg = get(contour_data.Annotation);
legInfo = get(leg.LegendInformation);

switch legInfo.IconDisplayStyle
    case 'on'
        showleg = true;
    case 'off'
        showleg = false;
end

obj.data{contourIndex}.showlegend = showleg;

%-------------------------------------------------------------------------%

end
