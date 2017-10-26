%----UPDATE AXIS DATA/LAYOUT----%

function obj = updateAxis(obj,axIndex)

% title: ...[DONE]
% titlefont:...[DONE]
% range:...[DONE]
% domain:...[DONE]
% type:...[DONE]
% rangemode:...[NOT SUPPORTED IN MATLAB]
% autorange:...[DONE]
% showgrid:...[DONE]
% zeroline:...[DONE]
% showline:...[DONE
% autotick:...[DONE]
% nticks:...[DONE]
% ticks:...[DONE]
% showticklabels:...[DONE]
% tick0:...[DONE]
% dtick:...[DONE]
% ticklen:...[DONE]
% tickwidth:...[DONE]
% tickcolor:...[DONE]
% tickangle:...[NOT SUPPORTED IN MATLAB]
% tickfont:...[DONE]
% tickfont.family...[DONE]
% tickfont.size...[DONE]
% tickfont.color...[DONE]
% tickfont.outlinecolor...[NOT SUPPORTED IN MATLAB]
% exponentformat:...[DONE]
% showexponent:...[NOT SUPPORTED IN MATLAB]
% mirror:...[DONE]
% gridcolor:...[DONE]
% gridwidth:...[DONE]
% zerolinecolor:...[NOT SUPPORTED IN MATLAB]
% zerolinewidth:...[NOT SUPPORTED IN MATLAB]
% linecolor:...[DONE]
% linewidth:...[DONE]
% anchor:...[DONE]
% overlaying:...[DONE]
% side:...[DONE]
% position:...[NOT SUPPORTED IN MATLAB]

%-STANDARDIZE UNITS-%
axisunits = get(obj.State.Axis(axIndex).Handle,'Units');
fontunits = get(obj.State.Axis(axIndex).Handle,'FontUnits');
set(obj.State.Axis(axIndex).Handle,'Units','normalized');
set(obj.State.Axis(axIndex).Handle,'FontUnits','points');

%-AXIS DATA STRUCTURE-%
axis_data = get(obj.State.Axis(axIndex).Handle);

%-------------------------------------------------------------------------%

%-xaxis domain-%
xaxis.domain = min([axis_data.Position(1) axis_data.Position(1)+axis_data.Position(3)],1);

%-------------------------------------------------------------------------%

%-yaxis domain-%
yaxis.domain = min([axis_data.Position(2) axis_data.Position(2)+axis_data.Position(4)],1);

%-------------------------------------------------------------------------%

%-xaxis-side-%
xaxis.side = axis_data.XAxisLocation;

%-------------------------------------------------------------------------%

%-yaxis-side-%
yaxis.side = axis_data.YAxisLocation;

%-------------------------------------------------------------------------%

%-layout plot bg color-%
obj.layout.plot_bgcolor = 'rgba(0,0,0,0)';

%-------------------------------------------------------------------------%

%-xaxis zeroline-%
xaxis.zeroline = false;

%-------------------------------------------------------------------------%

%-xaxis autorange-%
xaxis.autorange = false;

%-------------------------------------------------------------------------%

%-yaxis zeroline-%
yaxis.zeroline = false;

%-------------------------------------------------------------------------%

%-yaxis autorange-%
yaxis.autorange = false;

%-------------------------------------------------------------------------%

%-xaxis exponent format-%
xaxis.exponentformat = obj.PlotlyDefaults.ExponentFormat;

%-------------------------------------------------------------------------%

%-yaxis exponent format-%
yaxis.exponentformat = obj.PlotlyDefaults.ExponentFormat;

%-------------------------------------------------------------------------%

%-xaxis tick font size-%
xaxis.tickfont.size = axis_data.FontSize;

%-------------------------------------------------------------------------%

%-yaxis tick font size-%
yaxis.tickfont.size = axis_data.FontSize;

%-------------------------------------------------------------------------%

%-xaxis tick font family-%
xaxis.tickfont.family = matlab2plotlyfont(axis_data.FontName);

%-------------------------------------------------------------------------%

%-yaxis tick font family-%
yaxis.tickfont.family = matlab2plotlyfont(axis_data.FontName);

%-------------------------------------------------------------------------%

ticklength = min(obj.PlotlyDefaults.MaxTickLength,...
    max(axis_data.TickLength(1)*axis_data.Position(3)*obj.layout.width,...
    axis_data.TickLength(1)*axis_data.Position(4)*obj.layout.height));
%-xaxis ticklen-%
xaxis.ticklen = ticklength;
%-yaxis ticklen-%
yaxis.ticklen = ticklength;

%-------------------------------------------------------------------------%

col = 255*axis_data.XColor;
xaxiscol = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];

%-xaxis linecolor-%
xaxis.linecolor = xaxiscol;
%-xaxis tickcolor-%
xaxis.tickcolor = xaxiscol;
%-xaxis tickfont-%
xaxis.tickfont.color = xaxiscol;
%-xaxis grid color-%
xaxis.gridcolor = xaxiscol;

%-------------------------------------------------------------------------%

col = 255*axis_data.YColor;
yaxiscol = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];

%-yaxis linecolor-%
yaxis.linecolor = yaxiscol;
%-yaxis tickcolor-%
yaxis.tickcolor = yaxiscol;
%-yaxis tickfont-%
yaxis.tickfont.color = yaxiscol;
%-yaxis grid color-%
yaxis.gridcolor = yaxiscol;

%-------------------------------------------------------------------------%

if strcmp(axis_data.XGrid, 'on') || strcmp(axis_data.XMinorGrid, 'on')
    %-xaxis show grid-%
    xaxis.showgrid = true;
else
    xaxis.showgrid = false;
end

%-------------------------------------------------------------------------%

if strcmp(axis_data.YGrid,'on') || strcmp(axis_data.YMinorGrid,'on')
    %yaxis show grid-%
    yaxis.showgrid = true;
else
    yaxis.showgrid = false;
end

%-------------------------------------------------------------------------%

linewidth = max(1,axis_data.LineWidth*obj.PlotlyDefaults.AxisLineIncreaseFactor);

%-xaxis line width-%
xaxis.linewidth = linewidth;
%-yaxis line width-%
yaxis.linewidth = linewidth;
%-xaxis tick width-%
xaxis.tickwidth = linewidth;
%-yaxis tick width-%
yaxis.tickwidth = linewidth;
%-xaxis grid width-%
xaxis.gridwidth = linewidth;
%-yaxis grid width-%
yaxis.gridwidth = linewidth;

%-------------------------------------------------------------------------%

%-xaxis type-%
xaxis.type = axis_data.XScale;

%-------------------------------------------------------------------------%

%-xaxis showtick labels / ticks-%
if isempty(axis_data.XTick)
    
    %-xaxis ticks-%
    xaxis.ticks = '';
    xaxis.showticklabels = false;
    
    %-xaxis autorange-%
    xaxis.autorange = true; 
    
    %---------------------------------------------------------------------%
    
    switch axis_data.Box
        case 'on'
            %-xaxis mirror-%
            xaxis.mirror = true;
        case 'off'
            xaxis.mirror = false;
    end
    
    %---------------------------------------------------------------------%
    
else
    
    %-xaxis tick direction-%
    switch axis_data.TickDir
        case 'in'
            xaxis.ticks = 'inside';
        case 'out'
            xaxis.ticks = 'outside';
    end
    
    %---------------------------------------------------------------------%
    
    switch axis_data.Box
        case 'on'
            %-xaxis mirror-%
            xaxis.mirror = 'ticks';
        case 'off'
            xaxis.mirror = false;
    end
    
    %---------------------------------------------------------------------%
    
    if strcmp(xaxis.type,'log')
        
        %-xaxis range-%
        xaxis.range = log10(axis_data.XLim);
        
    elseif strcmp(xaxis.type,'linear')
        
        if strcmp(axis_data.XTickLabelMode,'auto')
            %-xaxis range-%
            xaxis.range = axis_data.XLim;
        else
            %-xaxis show tick labels-%
            if isempty(axis_data.XTickLabel)
                %-hide tick labels-%
                xaxis.showticklabels = false;
                %-xaxis autorange-%
                xaxis.autorange = true;
            else
                try datevec(axis_data.XTickLabel(1,:),axis_data.UserData.plotly.xdateformat);
                    %-xaxis type date-%
                    xaxis.type = 'date';
                    %-range (overwrite)-%
                    xaxis.range = [convertDate(datenum(axis_data.XTickLabel(1,:),axis_data.UserData.plotly.xdateformat)), ...
                        convertDate(datenum(axis_data.XTickLabel(end,:),axis_data.UserData.plotly.xdateformat))];
                catch
                    %x-axis labels
                    xlabels = str2double(axis_data.XTickLabel);
                    try
                        %find numbers in labels
                        labelnums = find(~isnan(xlabels));
                        %-yaxis type linear-%
                        xaxis.type = 'linear';
                        %-range (overwrite)-%
                        delta = (xlabels(labelnums(2)) - xlabels(labelnums(1)))/(labelnums(2)-labelnums(1));
                        xaxis.range = [xlabels(labelnums(1))-delta*(labelnums(1)-1) xlabels(labelnums(1)) + (length(xlabels)-labelnums(1))*delta];
                        %-yaxis autotick-%
                        xaxis.autotick = true;
                        %-yaxis numticks-%
                        xaxis.nticks = length(axis_data.XTick) + 1;
                    catch
                        %-yaxis type category-%
                        xaxis.type = 'category';
                        %-range (overwrite)-%
                        xaxis.autorange = true;
                        %-yaxis autotick-%
                        xaxis.autotick = true;
                    end
                end
            end
        end
    end
    
    %-xaxis autotick-%
    xaxis.autotick = true;
    %-xaxis numticks-%
    xaxis.nticks = length(axis_data.XTick) + 1;
    
end

%-------------------------------------------------------------------------%

if strcmp(axis_data.XDir,'reverse')
    xaxis.range = [xaxis.range(2) xaxis.range(1)];
end

%-------------------------------LABELS------------------------------------%

xlabel = axis_data.XLabel;
ylabel = axis_data.YLabel;

xlabel_data = get(xlabel);
ylabel_data = get(ylabel);

%STANDARDIZE UNITS
xfontunits = get(xlabel,'FontUnits');
set(xlabel,'FontUnits','points');
yfontunits = get(ylabel,'FontUnits');
set(ylabel,'FontUnits','points');

%-------------------------------------------------------------------------%

%-x title-%
if ~isempty(xlabel_data.String)
    xaxis.title = parseString(xlabel_data.String,xlabel_data.Interpreter);
end

%-------------------------------------------------------------------------%

%-xaxis title font color-%
col = 255*xlabel_data.Color;
xaxis.titlefont.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];

%-------------------------------------------------------------------------%

%-xaxis title font size-%
xaxis.titlefont.size = xlabel_data.FontSize;

%-------------------------------------------------------------------------%

%-xaxis title font family-%
xaxis.titlefont.family = matlab2plotlyfont(xlabel_data.FontName);

%-------------------------------------------------------------------------%

%-yaxis title-%
if ~isempty(ylabel_data.String)
    yaxis.title = parseString(ylabel_data.String, ylabel_data.Interpreter);
end

%-------------------------------------------------------------------------%

%-yaxis title font color-%
col = 255*ylabel_data.Color;
yaxis.titlefont.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];

%-------------------------------------------------------------------------%

%-yaxis title font size-%
yaxis.titlefont.size = ylabel_data.FontSize;

%-------------------------------------------------------------------------%

%-yaxis title font family-%
yaxis.titlefont.family = matlab2plotlyfont(ylabel_data.FontName);

%-------------------------------------------------------------------------%

%REVERT UNITS
set(xlabel,'FontUnits',xfontunits);
set(ylabel,'FontUnits',yfontunits);

%-------------------------------------------------------------------------%

%-yaxis type-%
yaxis.type = axis_data.YScale;

%-------------------------------------------------------------------------%

%-yaxis range-%
yaxis.range = axis_data.YLim;

%-------------------------------------------------------------------------%

%-yaxis show tick labels-%
yaxis.showticklabels = true;

%-------------------------------------------------------------------------%

%-yaxis showtick labels / ticks-%
if isempty(axis_data.YTick)
    
    %-yaxis ticks-%
    yaxis.ticks = '';
    yaxis.showticklabels = false;
    
    %-yaxis autorange-%
    yaxis.autorange = true; 
    
    %---------------------------------------------------------------------%
    
    switch axis_data.Box
        case 'on'
            %-yaxis mirror-%
            yaxis.mirror = true;
        case 'off'
            yaxis.mirror = false;
    end
    
    %---------------------------------------------------------------------%
    
else
    
    %-yaxis tick direction-%
    switch axis_data.TickDir
        case 'in'
            yaxis.ticks = 'inside';
        case 'out'
            yaxis.ticks = 'outside';
    end
    
    %---------------------------------------------------------------------%
    
    switch axis_data.Box
        case 'on'
            %-yaxis mirror-%
            yaxis.mirror = 'ticks';
        case 'off'
            yaxis.mirror = false;
    end
    
    %---------------------------------------------------------------------%
    
    if strcmp(yaxis.type,'log')
        
        %-xaxis range-%
        yaxis.range = log10(axis_data.YLim);
        %-xaxis autotick-%
        yaxis.autotick = true;
        %-xaxis nticks-%
        yaxis.nticks = length(axis_data.YTick) + 1;
        
    elseif strcmp(yaxis.type,'linear')
        
        %-xaxis range-%
        yaxis.range = axis_data.YLim;
        
        if strcmp(axis_data.YTickLabelMode,'auto')
            %-yaxis autotick-%
            yaxis.autotick = true;
            %-yaxis numticks-%
            yaxis.nticks = length(axis_data.YTick) + 1;
        else
            %-yaxis show tick labels-%
            if isempty(axis_data.YTickLabel)
                %-hide tick labels-%
                yaxis.showticklabels = false;
                %-yaxis autorange-%
                yaxis.autorange = true;
            else
                try datevec(axis_data.YTickLabel(1,:),axis_data.UserData.plotly.ydateformat);
                    %-yaxis type date-%
                    yaxis.type = 'date';
                    %-range (overwrite)-%
                    yaxis.range = [convertDate(datenum(axis_data.YTickLabel(1,:),axis_data.UserData.plotly.ydateformat)), ...
                        convertDate(datenum(axis_data.YTickLabel(end,:),axis_data.UserData.plotly.ydateformat))];
                    %-yaxis autotick-%
                    yaxis.autotick = true;
                    %-yaxis numticks-%
                    yaxis.nticks = length(axis_data.YTick) + 1;
                catch
                    %y-axis labels
                    ylabels = str2double(axis_data.YTickLabel);
                    try
                        %find numbers in labels
                        labelnums = find(~isnan(ylabels));
                        %-yaxis type linear-%
                        yaxis.type = 'linear';
                        %-range (overwrite)-%
                        delta = (ylabels(labelnums(2)) - ylabels(labelnums(1)))/(labelnums(2)-labelnums(1));
                        yaxis.range = [ylabels(labelnums(1))-delta*(labelnums(1)-1) ylabels(labelnums(1)) + (length(ylabels)-labelnums(1))*delta];
                        %-yaxis autotick-%
                        yaxis.autotick = true;
                        %-yaxis numticks-%
                        yaxis.nticks = length(axis_data.YTick) + 1;
                    catch
                        %-yaxis type category-%
                        yaxis.type = 'category';
                        %-yaxis autorange-%
                        yaxis.autorange = true;
                        %-yaxis autotick-%
                        yaxis.autotick = true;
                    end
                end
            end
        end
    end
end

%-------------------------------------------------------------------------%

if strcmp(axis_data.YDir,'reverse')
    yaxis.range = [yaxis.range(2) yaxis.range(1)];
end

%-------------------------------------------------------------------------%



%-------------------------HANDLE MULTIPLE AXES----------------------------%

[xsource, ysource, xoverlay, yoverlay] = findSourceAxis(obj,axIndex);

%-------------------------------------------------------------------------%

%-xaxis anchor-%
xaxis.anchor = ['y' num2str(ysource)];

%-------------------------------------------------------------------------%

%-yaxis anchor-%
yaxis.anchor = ['x' num2str(xsource)];

%-------------------------------------------------------------------------%

%-xaxis overlaying-%
if xoverlay
    xaxis.overlaying = ['x' num2str(xoverlay)];
end

%-------------------------------------------------------------------------%

%-yaxis overlaying-%
if yoverlay
    yaxis.overlaying = ['y' num2str(yoverlay)];
end

%-------------------------------------------------------------------------%

if strcmp(axis_data.Visible,'on')
    %-xaxis showline-%
    xaxis.showline = true;
    %-yaxis showline-%
    yaxis.showline = true;
else
    %-xaxis showline-%
    xaxis.showline = false;
    %-xaxis showticklabels-%
    xaxis.showticklabels = false;
    %-xaxis ticks-%
    xaxis.ticks = '';
    %-yaxis showline-%
    yaxis.showline = false;
    %-yaxis showticklabels-%
    yaxis.showticklabels = false;
    %-yaxis ticks-%
    yaxis.ticks = '';
end

%-------------------------------------------------------------------------%

% update the layout field (do not overwrite source)
if xsource == axIndex
    obj.layout = setfield(obj.layout,['xaxis' num2str(xsource)],xaxis);
else
    
end

%-------------------------------------------------------------------------%

% update the layout field (do not overwrite source)
if ysource == axIndex
    obj.layout = setfield(obj.layout,['yaxis' num2str(ysource)],yaxis);
else
    
end
%-------------------------------------------------------------------------%

%-REVERT UNITS-%
set(obj.State.Axis(axIndex).Handle,'Units',axisunits);
set(obj.State.Axis(axIndex).Handle,'FontUnits',fontunits);

end
