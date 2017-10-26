function obj = updateBoxplot(obj, boxIndex)

% y: ...[DONE]
% x0: ...[DONE]
% x: ...[DONE]
% name: ...[DONE]
% boxmean: ...[NOT SUPPORTED IN MATLAB]
% boxpoints: ...[NOT SUPPORTED IN MATLAB]
% jitter: ...[NOT SUPPORTED IN MATLAB]
% pointpos: ...[NOT SUPPORTED IN MATLAB]
% whiskerwidth: ........................[TODO]
% fillcolor: ...[DONE]
% opacity: ---[TODO]
% xaxis: ...[DONE]
% yaxis: ...[DONE]
% showlegend: ...[DONE]
% stream: ...[HANDLED BY PLOTLY STREAM]
% visible: ...[DONE]
% type: ...[DONE]

% MARKER
% color: ...[NA]
% width: ...[NA]
% dash: ...[NA]
% opacity: ...[NA]
% shape: ...[NA]
% smoothing: ...[NA]
% outliercolor: ...[NOT SUPPORTED IN MATLAB]
% outlierwidth: ...[NOT SUPPORTED IN MATLAB]

% LINE
% color: ...[DONE]
% width: ...[DONE]
% dash: ...[DONE]
% opacity: ---[TODO]
% shape: ...[DONE]
% smoothing: ...[NOT SUPPORTED IN MATLAB]

%-------------------------------------------------------------------------%

%-AXIS INDEX-%
axIndex = obj.getAxisIndex(obj.State.Plot(boxIndex).AssociatedAxis);

%-BOX DATA STRUCTURE-%
box_data = get(obj.State.Plot(boxIndex).Handle);

%-BOX CHILDREN-%
box_child = box_data.Children;

%-------------------------------------------------------------------------%

%-CONFIRM PROPER BOXPLOT STRUCTURE-%

% check for compact boxplot
isCompact = ~isempty(findobj(obj.State.Plot(boxIndex).Handle,'Tag','Whisker'));

% number of boxplots
if isCompact
    bpcompnum = 6;
    bpnum = length(box_child)/bpcompnum;
    % check for assumed box structure
    if mod(length(box_child), bpcompnum)~=0
        return
    end
else
    bpcompnum = 8;
    bpnum = length(box_child)/bpcompnum;
    % check for assumed box structure
    if mod(length(box_child),bpcompnum)~=0
        return
    end
end

% initialize ydata
ydata = [];

%-------------------------------------------------------------------------%

%-box groupgap-%
obj.layout.bargroupgap = 1/bpnum;

%-------------------------------------------------------------------------%

%-box name-%
obj.data{boxIndex}.name = box_data.DisplayName;

%-------------------------------------------------------------------------%

% iterate through box plot children in reverse order
for bp = bpnum:-1:1
    
    %-CHECK FOR MULTIPLE AXES-%
    [xsource, ysource] = findSourceAxis(obj,axIndex);
    
    %-AXIS DATA-%
    eval(['xaxis = obj.layout.xaxis' num2str(xsource) ';']);
    eval(['yaxis = obj.layout.yaxis' num2str(ysource) ';']);
    
    %---------------------------------------------------------------------%
    
    %-box xaxis-%
    obj.data{boxIndex}.xaxis = ['x' num2str(xsource)];
    
    %---------------------------------------------------------------------%
    
    %-box yaxis-%
    obj.data{boxIndex}.yaxis = ['y' num2str(ysource)];
    
    %---------------------------------------------------------------------%
    
    %-box type-%
    obj.data{boxIndex}.type = 'box';
    
    %---------------------------------------------------------------------%
    
    %-box visible-%
    obj.data{boxIndex}.visible = strcmp(box_data.Visible,'on');
    
    %---------------------------------------------------------------------%
    
    %-box fillcolor-%
    obj.data{boxIndex}.fillcolor = 'rgba(0, 0, 0, 0)';
    
    %---------------------------------------------------------------------%
    
    %-box showlegend-%
    leg = get(box_data.Annotation);
    legInfo = get(leg.LegendInformation);
    
    switch legInfo.IconDisplayStyle
        case 'on'
            showleg = true;
        case 'off'
            showleg = false;
    end
    
    obj.data{boxIndex}.showlegend = showleg;
    
    %-boxplot components-%
    Q1 = [];
    Q3 = [];
    median = [];
    outliers = [];
    uwhisker = [];
    lwhisker = [];
    
    % iterate through boxplot components
    for bpc = 1:bpcompnum
        
        %get box child data
        box_child_data = get(box_child(bp+bpnum*(bpc-1)));
        
        %box name
        if strcmp(box_child_data.Type,'text')
            if iscell(box_child_data.String)
                boxname =  box_child_data.String{1};
            else
                boxname =  box_child_data.String;
            end
        end
        
        % parse boxplot tags
        switch box_child_data.Tag
            
            %-median-%
            case 'Median'
                
                median =  box_child_data.YData(1);
                
                %-upper whisker-%
            case 'Upper Whisker'
                
                uwhisker = box_child_data.YData(2);
                
                %-boxplot whisker width-%
                obj.data{boxIndex}.whiskerwidth = 1;
                
                %-lower whisker-%
            case 'Lower Whisker'
                
                lwhisker = box_child_data.YData(1);
                
            case 'Box'
                
                %-Q1-%
                Q1 = min(box_child_data.YData);
                
                %-Q3-%
                Q3 = max(box_child_data.YData);
                
                %-boxplot line style-%
                
                if isCompact
                    col = 255*box_child_data.Color;
                    obj.data{boxIndex}.fillcolor = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
                else
                    obj.data{boxIndex}.line = extractLineLine(box_child_data);
                end
                
                
                %-outliers-%
            case 'Outliers'
                
                if ~isnan(box_child_data.YData)
                    %-outlier marker data-%
                    outliers = box_child_data.YData;
                    
                    %-outlier marker style-%
                    obj.data{boxIndex}.marker = extractLineMarker(box_child_data);
                end
                
                %-compact whiskers-%
            case 'Whisker'
                
                %-boxplot line style-%
                obj.data{boxIndex}.line = extractLineLine(box_child_data);
                
                %-boxplot whisker width-%
                obj.data{boxIndex}.whiskerwidth = 0;
                
                %-whisker data-%
                uwhisker = box_child_data.YData(2);
                lwhisker = box_child_data.YData(1);
                
                %-compact median-%
            case 'MedianInner'
                
                median = box_child_data.YData(1);
                
        end
    end
    
    %-generate boxplot data-%
    gendata = generateBoxData(outliers, lwhisker, Q1, median, Q3, uwhisker);
    
    %-boxplot y-data-%
    obj.data{boxIndex}.y(length(ydata)+1:length(ydata)+length(gendata)) = ...
        generateBoxData(outliers, lwhisker, Q1, median, Q3, uwhisker);
    
    %-boxplot x-data-%
    if (bpnum > 1)
        for n = (length(ydata)+1):(length(ydata)+length(gendata))
            obj.data{boxIndex}.x{n} = boxname;
        end
    end
    
    %-update ydata-%
    ydata = obj.data{boxIndex}.y;
    
end

%----------------------------!AXIS UPDATE!--------------------------------%

% take first text object as prototype for axis tick style/layout
text_child = findobj(obj.State.Plot(boxIndex).Handle,'Type','text');

%-STANDARDIZE UNITS-%
fontunits = get(text_child(1),'FontUnits');
set(text_child(1),'FontUnits','points');

%-text data -%
text_data = get(text_child(1));

%-------------------------------------------------------------------------%

%-xaxis tick font size-%
xaxis.tickfont.size = text_data.FontSize;

%-------------------------------------------------------------------------%

%-xaxis tick font family-%
xaxis.tickfont.family = matlab2plotlyfont(text_data.FontName);

%-------------------------------------------------------------------------%

%-xaxis tick font color-%
xaxis.tickfont.color = text_data.Color;

%-------------------------------------------------------------------------%

%-axis type-%
xaxis.type = 'category';

%-------------------------------------------------------------------------%

%-show tick labels-%
xaxis.showticklabels = true;

%-------------------------------------------------------------------------%

%-autorange-%
xaxis.autorange = true;

%-------------------------------------------------------------------------%

%-set the layout axis field-%
obj.layout = setfield(obj.layout,['xaxis' num2str(xsource)],xaxis);

%-------------------------------------------------------------------------%

%-REVERT UNITS-%
set(text_child(1),'FontUnits',fontunits);

end