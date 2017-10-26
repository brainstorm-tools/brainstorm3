function updateScatter(obj,scatterIndex)

%check: http://undocumentedmatlab.com/blog/undocumented-scatter-plot-behavior

%----SCATTER FIELDS----%

% x - [DONE]
% y - [DONE]
% r - [HANDLED BY SCATTER]
% t - [HANDLED BY SCATTER]
% mode - [DONE]
% name - [DONE]
% text - [NOT SUPPORTED IN MATLAB]
% error_y - [HANDLED BY ERRORBAR]
% error_x - [NOT SUPPORTED IN MATLAB]
% textfont - [NOT SUPPORTED IN MATLAB]
% textposition - [NOT SUPPORTED IN MATLAB]
% xaxis [DONE]
% yaxis [DONE]
% showlegend [DONE]
% stream - [HANDLED BY PLOTLYSTREAM]
% visible [DONE]
% type [DONE]
% opacity ---[TODO]

% MARKER
% marler.color - [DONE]
% marker.size - [DONE]
% marker.opacity - [NOT SUPPORTED IN MATLAB]
% marker.colorscale - [NOT SUPPORTED IN MATLAB]
% marker.sizemode - [DONE]
% marker.sizeref - [DONE]
% marker.maxdisplayed - [NOT SUPPORTED IN MATLAB]

% MARKER LINE
% marker.line.color - [DONE]
% marker.line.width - [DONE]
% marker.line.dash - [NOT SUPPORTED IN MATLAB]
% marker.line.opacity - [DONE]
% marker.line.smoothing - [NOT SUPPORTED IN MATLAB]
% marker.line.shape - [NOT SUPPORTED IN MATLAB]

% LINE
% line.color - [NA]
% line.width - [NA]
% line.dash - [NA]
% line.opacity [NA]
% line.smoothing - [NOT SUPPORTED IN MATLAB]
% line.shape - [NOT SUPPORTED IN MATLAB]
% connectgaps - [NOT SUPPORTED IN MATLAB]
% fill - [HANDLED BY AREA]
% fillcolor - [HANDLED BY AREA]

%-AXIS INDEX-%
axIndex = obj.getAxisIndex(obj.State.Plot(scatterIndex).AssociatedAxis);

%-SCATTER DATA STRUCTURE- %
scatter_data = get(obj.State.Plot(scatterIndex).Handle);

%-CHECK FOR MULTIPLE AXES-%
[xsource, ysource] = findSourceAxis(obj,axIndex);

%-AXIS DATA-%
eval(['xaxis = obj.layout.xaxis' num2str(xsource) ';']);
eval(['yaxis = obj.layout.yaxis' num2str(ysource) ';']);

%-------------------------------------------------------------------------%

%-scatter xaxis-%
obj.data{scatterIndex}.xaxis = ['x' num2str(xsource)];

%-------------------------------------------------------------------------%

%-scatter yaxis-%
obj.data{scatterIndex}.yaxis = ['y' num2str(ysource)];

%-------------------------------------------------------------------------%

%-scatter type-%
obj.data{scatterIndex}.type = 'scatter';

%-------------------------------------------------------------------------%

%-scatter mode-%
obj.data{scatterIndex}.mode = 'markers';

%-------------------------------------------------------------------------%

%-scatter visible-%
obj.data{scatterIndex}.visible = strcmp(scatter_data.Visible,'on');

%-------------------------------------------------------------------------%

%-scatter name-%
obj.data{scatterIndex}.name = scatter_data.DisplayName;

%-------------------------------------------------------------------------%

%-scatter patch data-%
for m = 1:length(scatter_data)
    
    %reverse counter
    n = length(scatter_data) - m + 1;
    
    %---------------------------------------------------------------------%
    
    %-scatter x-%
    if length(scatter_data) > 1
        obj.data{scatterIndex}.x(m) = scatter_data(n).XData;
    else
        obj.data{scatterIndex}.x = scatter_data.XData;
    end
    
    %---------------------------------------------------------------------%
    
    %-scatter y-%
    if length(scatter_data) > 1
        obj.data{scatterIndex}.y(m) = scatter_data(n).YData;
    else
        obj.data{scatterIndex}.y = scatter_data.YData;
    end
    
    %---------------------------------------------------------------------%
    
    %-scatter z-%
    if isHG2()
        if isfield(scatter_data,'ZData')
            if any(scatter_data.ZData)
                if length(scatter_data) > 1
                    obj.data{scatterIndex}.z(m) = scatter_data(n).ZData;
                else
                    obj.data{scatterIndex}.z = scatter_data.ZData;
                end
                % overwrite type
                obj.data{scatterIndex}.type = 'scatter3d';
            end
        end
    end
    
    %---------------------------------------------------------------------%
    
    %-scatter showlegend-%
    leg = get(scatter_data.Annotation);
    legInfo = get(leg.LegendInformation);
    
    switch legInfo.IconDisplayStyle
        case 'on'
            showleg = true;
        case 'off'
            showleg = false;
    end
    
    obj.data{scatterIndex}.showlegend = showleg;
    
    %---------------------------------------------------------------------%
    
    %-scatter marker-%
    childmarker = extractScatterMarker(scatter_data(n));
    
    %---------------------------------------------------------------------%
    
    %-line color-%
    if length(scatter_data) > 1
        obj.data{scatterIndex}.marker.line.color{m} = childmarker.line.color{1};
    else
        obj.data{scatterIndex}.marker.line.color = childmarker.line.color;
    end
    
    %---------------------------------------------------------------------%
    
    %-marker color-%
    if length(scatter_data) > 1
        obj.data{scatterIndex}.marker.color{m} = childmarker.color{1};
    else
        obj.data{scatterIndex}.marker.color = childmarker.color;
    end
    
    %---------------------------------------------------------------------%
    
    %-sizeref-%
    obj.data{scatterIndex}.marker.sizeref = childmarker.sizeref;
    
    %---------------------------------------------------------------------%
    
    %-sizemode-%
    obj.data{scatterIndex}.marker.sizemode = childmarker.sizemode;
    
    %---------------------------------------------------------------------%
    
    %-symbol-%
    obj.data{scatterIndex}.marker.symbol{m} = childmarker.symbol;
    
    %---------------------------------------------------------------------%
    
    %-size-%
    obj.data{scatterIndex}.marker.size = childmarker.size;
  
    %---------------------------------------------------------------------%
    
    %-line width-%
    
    if length(scatter_data) > 1 || ischar(childmarker.line.color)
        obj.data{scatterIndex}.marker.line.width(m) = childmarker.line.width;
    else
        obj.data{scatterIndex}.marker.line.width(1:length(childmarker.line.color)) = childmarker.line.width;
    end
    
    %---------------------------------------------------------------------%
    
end
end

