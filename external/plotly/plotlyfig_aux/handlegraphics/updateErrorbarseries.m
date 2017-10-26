function obj = updateErrorbarseries(obj, errorbarIndex)

% type: ...[DONE]
% symmetric: ...[DONE]
% array: ...[DONE]
% value: ...[NA]
% arrayminus: ...{DONE]
% valueminus: ...[NA]
% color: ...[DONE]
% thickness: ...[DONE]
% width: ...[DONE]
% opacity: ---[TODO]
% visible: ...[DONE]

%-------------------------------------------------------------------------%

%-ERRORBAR STRUCTURE-%
errorbar_data = get(obj.State.Plot(errorbarIndex).Handle);

%-ERRORBAR CHILDREN-%
errorbar_child = get(obj.State.Plot(errorbarIndex).Handle,'Children');

%-ERROR BAR LINE CHILD-%
errorbar_line_child_data = get(errorbar_child(2));

%-------------------------------------------------------------------------%

%-UPDATE LINESERIES-%
updateLineseries(obj, errorbarIndex);

%-------------------------------------------------------------------------%

%-errorbar visible-%
obj.data{errorbarIndex}.error_y.visible = true;

%-------------------------------------------------------------------------%

%-errorbar type-%
obj.data{errorbarIndex}.error_y.type = 'data';

%-------------------------------------------------------------------------%

%-errorbar symmetry-%
obj.data{errorbarIndex}.error_y.symmetric = false;

%-------------------------------------------------------------------------%

%-errorbar value-%
obj.data{errorbarIndex}.error_y.array = errorbar_data.UData;

%-------------------------------------------------------------------------%

%-errorbar valueminus-%
obj.data{errorbarIndex}.error_y.arrayminus = errorbar_data.LData;

%-------------------------------------------------------------------------%

%-errorbar thickness-%
obj.data{errorbarIndex}.error_y.thickness = errorbar_line_child_data.LineWidth;

%-------------------------------------------------------------------------%

%-errorbar width-%
obj.data{errorbarIndex}.error_y.width = obj.PlotlyDefaults.ErrorbarWidth;

%-------------------------------------------------------------------------%

%-errorbar color-%
col = 255*errorbar_line_child_data.Color;
obj.data{errorbarIndex}.error_y.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];

%-------------------------------------------------------------------------%

end