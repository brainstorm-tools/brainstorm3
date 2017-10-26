function obj = updateBar(obj,barIndex)

% x: ...[DONE]
% y: ...[DONE]
% name: ...[DONE]
% orientation: ...[DONE]
% text: ...[NOT SUPPORTED IN MATLAB]
% error_y: ...[HANDLED BY ERRORBAR]
% error_x: ...[HANDLED BY ERRORBAR]
% opacity: ...[DONE]
% xaxis: ...[DONE]
% yaxis: ...[DONE]
% showlegend: ...[DONE]
% stream: ...[HANDLED BY PLOTLY STREAM]
% visible: ...[DONE]
% type: ...[DONE]
% r: ...[NA]
% t: ...[NA]
% textfont: ...[NA]

% MARKER:
% color: ...DONE]
% size: ...[NA]
% symbol: ...[NA]
% opacity: ...[NA]
% sizeref: ...[NA]
% sizemode: ...[NA]
% colorscale: ...[NA]
% cauto: ...[NA]
% cmin: ...[NA]
% cmax: ...[NA]
% outliercolor: ...[NA]
% maxdisplayed: ...[NA]

% MARKER LINE:
% color: ...[DONE]
% width: ...[DONE]
% dash: ...[NA]
% opacity: ---[TODO]
% shape: ...[NA]
% smoothing: ...[NA]
% outliercolor: ...[NA]
% outlierwidth: ...[NA]

%-------------------------------------------------------------------------%

%-AXIS INDEX-%
axIndex = obj.getAxisIndex(obj.State.Plot(barIndex).AssociatedAxis);

%-BAR DATA STRUCTURE- %
bar_data = obj.State.Plot(barIndex).Handle;

%-CHECK FOR MULTIPLE AXES-%
[xsource, ysource] = findSourceAxis(obj, axIndex);

%-AXIS DATA-%
eval(['xaxis = obj.layout.xaxis' num2str(xsource) ';']);
eval(['yaxis = obj.layout.yaxis' num2str(ysource) ';']);

%-------------------------------------------------------------------------%

%-bar xaxis-%
obj.data{barIndex}.xaxis = ['x' num2str(xsource)];

%-------------------------------------------------------------------------%

%-bar yaxis-%
obj.data{barIndex}.yaxis = ['y' num2str(ysource)];

%-------------------------------------------------------------------------%

%-bar visible-%
obj.data{barIndex}.visible = strcmp(bar_data.Visible,'on');

%-------------------------------------------------------------------------%

%-bar type-%
obj.data{barIndex}.type = 'bar';

%-------------------------------------------------------------------------%

%-bar name-%
obj.data{barIndex}.name = bar_data.DisplayName;

%-------------------------------------------------------------------------%

%-layout barmode-%
switch bar_data.BarLayout
    case 'grouped'
        obj.layout.barmode = 'group';
    case 'stacked'
        obj.layout.barmode = 'stack';
end

%-------------------------------------------------------------------------%

%-layout bargroupgap-%
obj.layout.bargroupgap = 1-bar_data.BarWidth;

%---------------------------------------------------------------------%

%-layout bargap-%
obj.layout.bargap = obj.PlotlyDefaults.Bargap;

%-------------------------------------------------------------------------%

%-bar orientation-%
switch bar_data.Horizontal
    
    case 'off'
        
        %-bar orientation-%
        obj.data{barIndex}.orientation = 'v';
        
        %-bar x data-%
        obj.data{barIndex}.x = bar_data.XData;
        
        %-bar y data-%
        obj.data{barIndex}.y = bar_data.YData;
        
        
    case 'on'
        
        %-bar orientation-%
        obj.data{barIndex}.orientation = 'h';
        
        %-bar x data-%
        obj.data{barIndex}.x = bar_data.YData;
        
        %-bar y data-%
        obj.data{barIndex}.y = bar_data.XData;
end

%---------------------------------------------------------------------%

%-bar showlegend-%
leg = get(bar_data.Annotation);
legInfo = get(leg.LegendInformation);

switch legInfo.IconDisplayStyle
    case 'on'
        showleg = true;
    case 'off'
        showleg = false;
end

obj.data{barIndex}.showlegend = showleg;

%-------------------------------------------------------------------------%

%-bar marker-%
obj.data{barIndex}.marker = extractAreaFace(bar_data);

%-------------------------------------------------------------------------%

%-bar marker line-%
markerline = extractAreaLine(bar_data); 
obj.data{barIndex}.marker.line = markerline; 

%-------------------------------------------------------------------------%
end


