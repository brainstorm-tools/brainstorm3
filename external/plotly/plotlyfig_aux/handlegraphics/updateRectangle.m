function obj = updateRectangle(obj, rectIndex)

%----RECTANGLE FIELDS----%

% x - [DONE]
% y - [DONE]
% mode - [DONE]
% name - [DONE]
% text - [NOT SUPPORTED IN MATLAB]
% error_y - [HANDLED BY ERRORBAR]
% error_x - [HANDLED BY ERRORBAR]
% line.color - [DONE]
% line.width - [DONE]
% line.dash - [DONE]
% line.opacity - [NOT SUPPORTED IN MATLAB]
% line.smoothing - [NOT SUPPORTED IN MATLAB]
% line.shape - [NOT SUPPORTED IN MATLAB]
% connectgaps - [NOT SUPPORTED IN MATLAB]
% fill - [HANDLED BY RECTANGLE]
% fillcolor - [HANDLED BY RECTANGLE]
% opacity - [NOT SUPPORTED IN MATLAB]
% textfont - [NOT SUPPORTED IN MATLAB]
% textposition - [NOT SUPPORTED IN MATLAB]
% xaxis [DONE]
% yaxis [DONE]
% showlegend [DONE]
% stream - [HANDLED BY PLOTLYSTREAM]
% visible [DONE]
% type [DONE]

%-AXIS INDEX-%
axIndex = obj.getAxisIndex(obj.State.Plot(rectIndex).AssociatedAxis);

%-RECTANGLE DATA STRUCTURE- %
rect_data = get(obj.State.Plot(rectIndex).Handle);

%-CHECK FOR MULTIPLE AXES-%
[xsource, ysource] = findSourceAxis(obj,axIndex);

%-AXIS DATA-%
eval(['xaxis = obj.layout.xaxis' num2str(xsource) ';']);
eval(['yaxis = obj.layout.yaxis' num2str(ysource) ';']);

%-------------------------------------------------------------------------%

%-rectangle xaxis-%
obj.data{rectIndex}.xaxis = ['x' num2str(xsource)];

%-------------------------------------------------------------------------%

%-rectangle yaxis-%
obj.data{rectIndex}.yaxis = ['y' num2str(ysource)];

%-------------------------------------------------------------------------%

%-rectangle type-%
obj.data{rectIndex}.type = 'scatter';

%-------------------------------------------------------------------------%

%-rectangle x-%
obj.data{rectIndex}.x = [rect_data.Position(1) rect_data.Position(1) ...
    rect_data.Position(1) + rect_data.Position(3) ...
    rect_data.Position(1) + rect_data.Position(3) ...
    rect_data.Position(1)];

%-------------------------------------------------------------------------%

%-rectangle y-%
obj.data{rectIndex}.y = [rect_data.Position(2) rect_data.Position(2) + rect_data.Position(4) ...
    rect_data.Position(2) + rect_data.Position(4) ...
    rect_data.Position(2) ...
    rect_data.Position(2)];

%-------------------------------------------------------------------------%

%-rectangle name-%
obj.data{rectIndex}.name = rect_data.DisplayName;

%-------------------------------------------------------------------------%

%-rectangle mode-%
obj.data{rectIndex}.mode = 'lines';

%-------------------------------------------------------------------------%

%-rectangle fill-%
obj.data{rectIndex}.visible = strcmp(rect_data.Visible,'on');


%-------------------------------------------------------------------------%

%-rectangle fill-%
obj.data{rectIndex}.fill = 'tonexty';

%-------------------------------------------------------------------------%

%-rectangle line-%
obj.data{rectIndex}.line = extractPatchLine(rect_data);

%-------------------------------------------------------------------------%

%-rectangle fillcolor-%
fill = extractPatchFace(rect_data);
obj.data{rectIndex}.fillcolor = fill.color;

%-------------------------------------------------------------------------%

%-rectangle showlegend-%
leg = get(rect_data.Annotation);
legInfo = get(leg.LegendInformation);

switch legInfo.IconDisplayStyle
    case 'on'
        showleg = true;
    case 'off'
        showleg = false;
end

obj.data{rectIndex}.showlegend = showleg;

%-------------------------------------------------------------------------%

end