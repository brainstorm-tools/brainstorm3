function obj = updateAnnotation(obj,anIndex)

%-------X/YLABEL FIELDS--------%
% title...[DONE]
% titlefont.size...[DONE]
% titlefont.family...[DONE]
% titlefont.color...[DONE]

%------ANNOTATION FIELDS-------%

% x: ...[DONE]
% y: ...[DONE]
% xref: ...[DONE]
% yref: ...[DONE]
% text: ...[DONE]
% showarrow: ...[HANDLED BY CALL TO ANNOTATION];
% font: ...[DONE]
% xanchor: ...[DONE]
% yanchor: ...[DONE]
% align: ...[DONE]
% arrowhead: ...[HANDLED BY CALL FROM ANNOTATION];
% arrowsize: ...[HANDLED BY CALL FROM ANNOTATION];
% arrowwidth: ...[HANDLED BY CALL FROM ANNOTATION];
% arrowcolor: ...[HANDLED BY CALL FROM ANNOTATION];
% ax: ...[HANDLED BY CALL FROM ANNOTATION];
% ay: ...[HANDLED BY CALL FROM ANNOTATION];
% textangle: ...[DONE]
% bordercolor: ...[DONE]
% borderwidth: ...[DONE]
% borderpad: ...[DONE]
% bgcolor: ...[DONE]
% opacity: ...[NOT SUPPORTED IN MATLAB]

%-AXIS INDEX-%
axIndex = obj.getAxisIndex(obj.State.Text(anIndex).AssociatedAxis);

%-CHECK FOR MULTIPLE AXES-%
[xsource, ysource] = findSourceAxis(obj,axIndex);

%-STANDARDIZE UNITS-%
textunits = get(obj.State.Text(anIndex).Handle,'Units');
fontunits = get(obj.State.Text(anIndex).Handle,'FontUnits');
set(obj.State.Text(anIndex).Handle,'Units','data');
set(obj.State.Text(anIndex).Handle,'FontUnits','points');

%-TEXT DATA STRUCTURE-%
text_data = get(obj.State.Text(anIndex).Handle);

%-------------------------------------------------------------------------%

%-show arrow-%
obj.layout.annotations{anIndex}.showarrow = false;

%-------------------------------------------------------------------------%

%-anchor title to paper-%
if obj.State.Text(anIndex).Title
    %-xref-%
    obj.layout.annotations{anIndex}.xref = 'paper';
    %-yref-%
    obj.layout.annotations{anIndex}.yref = 'paper';
else
    %-xref-%
    obj.layout.annotations{anIndex}.xref = ['x' num2str(xsource)];
    %-yref-%
    obj.layout.annotations{anIndex}.yref = ['y' num2str(ysource)];
end

%-------------------------------------------------------------------------%

%-xanchor-%
obj.layout.annotations{anIndex}.xanchor = text_data.HorizontalAlignment;

%-------------------------------------------------------------------------%

%-align-%
obj.layout.annotations{anIndex}.align = text_data.HorizontalAlignment;

%-------------------------------------------------------------------------%

switch text_data.VerticalAlignment
    %-yanchor-%
    case {'top', 'cap'}
        obj.layout.annotations{anIndex}.yanchor = 'top';
    case 'middle'
        obj.layout.annotations{anIndex}.yanchor = 'middle';
    case {'baseline','bottom'}
        obj.layout.annotations{anIndex}.yanchor = 'bottom';
end

%-------------------------------------------------------------------------%

%-text-%
obj.layout.annotations{anIndex}.text = parseString(text_data.String,text_data.Interpreter);
if obj.State.Text(anIndex).Title && isempty(text_data.String)
    obj.layout.annotations{anIndex}.text = '<b></b>'; %empty string annotation
end

%-------------------------------------------------------------------------%

if obj.State.Text(anIndex).Title
    
    %-AXIS DATA-%
    eval(['xaxis = obj.layout.xaxis' num2str(xsource) ';']);
    eval(['yaxis = obj.layout.yaxis' num2str(ysource) ';']);
    
    %-x position-%
    obj.layout.annotations{anIndex}.x = mean(xaxis.domain);
    %-y position-%
    obj.layout.annotations{anIndex}.y = (yaxis.domain(2) + obj.PlotlyDefaults.TitleHeight);
else
    %-x position-%
    obj.layout.annotations{anIndex}.x = text_data.Position(1);
    %-y position-%
    obj.layout.annotations{anIndex}.y = text_data.Position(2);
end



%-font color-%
col = 255*text_data.Color;
obj.layout.annotations{anIndex}.font.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];

%---------------------------------------------------------------------%

%-font family-%
obj.layout.annotations{anIndex}.font.family = matlab2plotlyfont(text_data.FontName);

%---------------------------------------------------------------------%

%-font size-%
obj.layout.annotations{anIndex}.font.size = text_data.FontSize;

%---------------------------------------------------------------------%

switch text_data.FontWeight
    case {'bold','demi'}
        %-bold text-%
        obj.layout.annotations{anIndex}.text = ['<b>' obj.layout.annotations{anIndex}.text '</b>'];
    otherwise
end

%---------------------------------------------------------------------%

%-background color-%
if ~ischar(text_data.BackgroundColor)
    switch text_data.BackgroundColor
        
        case 'ne'
            obj.layout.annotations{anIndex}.bgcolor = 'rgba(0,0,0,0)';
        otherwise
            
    end
end

%---------------------------------------------------------------------%

%-border color-%
if ~ischar(text_data.EdgeColor)
    col = 255*text_data.EdgeColora;
    obj.layout.annotations{anIndex}.bordercolor = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
else
    %-none-%
    obj.layout.annotations{anIndex}.bordercolor = 'rgba(0,0,0,0)';
end

%---------------------------------------------------------------------%

%-text angle-%
obj.layout.annotations{anIndex}.textangle = text_data.Rotation;
if text_data.Rotation > 180
    obj.layout.annotations{anIndex}.textangle = text_data.Rotation - 360;
end

%---------------------------------------------------------------------%

%-border width-%
obj.layout.annotations{anIndex}.borderwidth = text_data.LineWidth;

%---------------------------------------------------------------------%

%-border pad-%
obj.layout.annotations{anIndex}.borderpad = text_data.Margin;


%hide text (a workaround)
if strcmp(text_data.Visible,'off')
    obj.layout.annotations{anIndex}.text = ' ';
else
    obj.layout.annotations{anIndex}.text = obj.layout.annotations{anIndex}.text;
end

%-------------------------------------------------------------------------%

%-REVERT UNITS-%
set(obj.State.Text(anIndex).Handle,'Units',textunits);
set(obj.State.Text(anIndex).Handle,'FontUnits',fontunits);

%-------------------------------------------------------------------------%

end