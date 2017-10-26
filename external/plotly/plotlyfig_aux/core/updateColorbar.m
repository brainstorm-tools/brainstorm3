function obj = updateColorbar(obj,colorbarIndex)

% title: ...[DONE]
% titleside: ...[DONE]
% titlefont: ...[DONE]
% thickness: ...[DONE]
% thicknessmode: ...[DONE]
% len: ...[DONE]
% lenmode: ...[DONE]
% x: ...[DONE]
% y: ...[DONE]
% autotick: ...[DONE]
% nticks: ...[DONE]
% ticks: ...[DONE]
% showticklabels: ...[DONE]
% tick0: ...[DONE]
% dtick: ...[DONE]
% ticklen: ...[DONE]
% tickwidth: ...[DONE]
% tickcolor: ...[DONE]
% tickangle: ...[NOT SUPPORTED IN MATLAB]
% tickfont: ...[DONE]
% exponentformat: ...[DONE]
% showexponent: ...[NOT SUPPORTED IN MATLAB]
% xanchor: ...[DONE]
% yanchor: ...[DONE]
% bgcolor: ...[DONE]
% outlinecolor: ...[DONE]
% outlinewidth: ...[DONE]
% borderwidth: ...[NOT SUPPORTED IN MATLAB]
% bordercolor: ...[NOT SUPPORTED IN MATLAB]
% xpad: ...[DONE]
% ypad: ...[DONE]

%-FIGURE STRUCTURE-%
figure_data = get(obj.State.Figure.Handle);

%-PLOT DATA STRUCTURE- %
try
    colorbar_data = get(obj.State.Colorbar(colorbarIndex).Handle);
catch
    disp('here');
end

%-STANDARDIZE UNITS-%
colorbarunits = colorbar_data.Units;
set(obj.State.Colorbar(colorbarIndex).Handle,'Units','normalized');

%-------------------------------------------------------------------------%

%-x anchor-%
colorbar.xanchor = 'left';

%-------------------------------------------------------------------------%

%-y anchor-%
colorbar.yanchor = 'bottom';

%-------------------------------------------------------------------------%

%-x position-%
colorbar.x = colorbar_data.Position(1);

%-------------------------------------------------------------------------%

%-y position-%
colorbar.y = colorbar_data.Position(2);

%-------------------------------------------------------------------------%

%-exponent format-%
colorbar.exponentformat = obj.PlotlyDefaults.ExponentFormat;

%-------------------------------------------------------------------------%

% get colorbar title and labels
if isHG2
    colorbar_title = colorbar_data.Label;
    colorbar_title_data = get(colorbar_title);
    colorbar_ylabel = colorbar_data.Label;
    colorbar_ylabel_data = get(colorbar_data.Label);
    colorbar_xlabel_data.String = [];
else
    colorbar_title = colorbar_data.Title;
    colorbar_title_data = get(colorbar_title);
    colorbar_xlabel = colorbar_data.XLabel;
    colorbar_xlabel_data = get(colorbar_xlabel);
    colorbar_ylabel = colorbar_data.YLabel;
    colorbar_ylabel_data = get(colorbar_ylabel);
end

%-colorbar title-%
if ~isempty(colorbar_title_data.String)
    %-colorbar title-%
    colorbar.title = parseString(colorbar_title_data.String,colorbar_title_data.Interpreter);
elseif ~isempty(colorbar_xlabel_data.String)
    %-colorbar title-%
    colorbar.title = parseString(colorbar_xlabel_data.String,colorbar_xlabel_data.Interpreter);
elseif ~isempty(colorbar_ylabel_data.String)
    %-colorbar title-%
    colorbar.title = parseString(colorbar_ylabel_data.String,colorbar_ylabel_data.Interpreter);
    
end


%-------------------------------------------------------------------------%

%-STANDARDIZE UNITS-%
titleunits = colorbar_title_data.Units;
titlefontunits = colorbar_title_data.FontUnits;
ylabelunits = colorbar_ylabel_data.Units;
ylabelfontunits = colorbar_ylabel_data.FontUnits;
set(colorbar_title,'Units','data');
set(colorbar_ylabel,'Units','data');
set(colorbar_ylabel,'FontUnits','points');
if ~isHG2
    xlabelunits = colorbar_xlabel_data.Units;
    xlabelfontunits = colorbar_xlabel_data.FontUnits;
    set(colorbar_title,'FontUnits','points');
    set(colorbar_xlabel,'Units','data');
    set(colorbar_xlabel,'FontUnits','points');
end


if ~isempty(colorbar_title_data.String)
    %-colorbar titleside-%
    colorbar.titleside = 'top';
    %-colorbar titlefont family-%:
    colorbar.titlefont.family = matlab2plotlyfont(colorbar_title_data.FontName);
    %-colorbar titlefont color-%
    col = 255*colorbar_title_data.Color;
    colorbar.titlefont.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    %-colorbar titlefont size-%
    colorbar.titlefont.size = colorbar_title_data.FontSize;
elseif ~isempty(colorbar_xlabel_data.String)
    %-colorbar titleside-%
    colorbar.titleside = 'right';
    %-colorbar titlefont family-%:
    colorbar.titlefont.family = matlab2plotlyfont(colorbar_xlabel_data.FontName);
    %-colorbar titlefont color-%
    col = 255*colorbar_xlabel_data.Color;
    colorbar.titlefont.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    %-colorbar titlefont size-%
    colorbar.titlefont.size = colorbar_xlabel_data.FontSize;
elseif ~isempty(colorbar_ylabel_data.String)
    %-colorbar titleside-%
    colorbar.titleside = 'bottom';
    %-colorbar titlefont family-%:
    colorbar.titlefont.family = matlab2plotlyfont(colorbar_ylabel_data.FontName);
    %-colorbar titlefont color-%
    col = 255*colorbar_ylabel_data.Color;
    colorbar.titlefont.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    %-colorbar titlefont size-%
    colorbar.titlefont.size = colorbar_ylabel_data.FontSize;
end

%-REVERT UNITS-%
set(colorbar_title,'Units',titleunits);
set(colorbar_title,'FontUnits',titlefontunits);
set(colorbar_ylabel,'Units',ylabelunits);
set(colorbar_ylabel,'FontUnits',ylabelfontunits);

if ~isHG2
    set(colorbar_xlabel,'Units',xlabelunits);
    set(colorbar_xlabel,'FontUnits',xlabelfontunits);
end


%-thicknessmode-%
colorbar.thicknessmode = 'fraction';

%-------------------------------------------------------------------------%

%-thickness-%
colorbar.thickness = colorbar_data.Position(3);

%-------------------------------------------------------------------------%

%-lenmode-%
colorbar.lenmode = 'fraction';

%-------------------------------------------------------------------------%

%-length-%
colorbar.len = colorbar_data.Position(4);

%-------------------------------------------------------------------------%

% orientation vertical check
orientVert = colorbar.len > colorbar.thickness;

%-------------------------------------------------------------------------%

%-outline width-%
linewidth = colorbar_data.LineWidth*obj.PlotlyDefaults.AxisLineIncreaseFactor;
colorbar.outlinewidth = linewidth;

%-------------------------------------------------------------------------%

%-tickwidth-%
colorbar.tickwidth = linewidth;

%-------------------------------------------------------------------------%

ticklength = min(obj.PlotlyDefaults.MaxTickLength,...
    max(colorbar_data.TickLength(1)*colorbar_data.Position(3)*obj.layout.width,...
    colorbar_data.TickLength(1)*colorbar_data.Position(4)*obj.layout.height));

%-xaxis ticklen-%
colorbar.ticklen = ticklength;

%-------------------------------------------------------------------------%

% check orientation for x/y properties

if isHG2
    col = [0 0 0];
else
    if orientVert
        col = 255*colorbar_data.YColor;
    else
        col = 255*colorbar_data.XColor;
    end
end

colorbar_col = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];

%-outlinecolor-%
colorbar.outlinecolor = colorbar_col;

%-------------------------------------------------------------------------%

%-tickcolor-%
colorbar.tickcolor = colorbar_col;

%-------------------------------------------------------------------------%

%-tickfont-%
colorbar.tickfont.color = colorbar_col;

%-------------------------------------------------------------------------%

%-xaxis tick font size-%
colorbar.tickfont.size = colorbar_data.FontSize;

%-------------------------------------------------------------------------%

%-xaxis tick font family-%
colorbar.tickfont.family = matlab2plotlyfont(colorbar_data.FontName);

%-------------------------------------------------------------------------%

%-colorbar pad-%
colorbar.xpad = obj.PlotlyDefaults.MarginPad;
colorbar.ypad = obj.PlotlyDefaults.MarginPad;

%-------------------------------------------------------------------------%

% check orientation for x/y properties
if ~isHG2
    if orientVert
        if isempty(colorbar_data.YTick)
            %-show tick labels-%
            colorbar.ticks = '';
            colorbar.showticklabels = false;
        else
            %-tick direction-%
            switch colorbar_data.TickDir
                case 'in'
                    colorbar.ticks = 'inside';
                case 'out'
                    colorbar.ticks = 'outside';
            end
            
            if strcmp(colorbar_data.YTickLabelMode,'auto')
                %-autotick-%
                colorbar.autotick = true;
                %-numticks-%
                colorbar.nticks = length(colorbar_data.YTick) + 1; %nticks = max ticks (so + 1)
            else
                %-show tick labels-%
                if isempty(colorbar_data.YTickLabel)
                    colorbar.showticklabels = false;
                else
                    %-autotick-%
                    colorbar.autotick = false;
                    %-tick0-%
                    colorbar.tick0 = str2double(colorbar_data.YTickLabel(1,:));
                    %-dtick-%
                    colorbar.dtick = str2double(colorbar_data.YTickLabel(2,:)) - str2double(colorbar_data.YTickLabel(1,:));
                end
            end
        end
    else
        if isempty(colorbar_data.XTick)
            %-show tick labels-%
            colorbar.ticks = '';
            colorbar.showticklabels = false;
        else
            %-tick direction-%
            switch colorbar_data.TickDir
                case 'in'
                    colorbar.ticks = 'inside';
                case 'out'
                    colorbar.ticks = 'outside';
            end
            
            if strcmp(colorbar_data.XTickLabelMode,'auto')
                %-autotick-%
                colorbar.autotick = true;
                %-numticks-%
                colorbar.nticks = length(colorbar_data.XTick) + 1;
            else
                %-show tick labels-%
                if isempty(colorbar_data.XTickLabel)
                    colorbar.showticklabels = false;
                else
                    %-autotick-%
                    colorbar.autotick = false;
                    %-tick0-%
                    colorbar.tick0 = str2double(colorbar_data.XTickLabel(1,:));
                    %-dtick-%
                    colorbar.dtick = str2double(colorbar_data.XTickLabel(2,:)) - str2double(colorbar_data.XTickLabel(1,:));
                end
            end
        end
    end
end
%-------------------------------------------------------------------------%

if ~isHG2
    %-colorbar bg-color-%
    if ~ischar(colorbar_data.Color)
        col = 255*colorbar_data.Color;
    else
        col = 255*figure_data.Color;
    end
    
    obj.layout.plot_bgcolor = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
end
%-------------------------------------------------------------------------%


%--------------------------ASSOCIATED DATA--------------------------------%

if isfield(colorbar_data.UserData,'dataref')
    colorbarDataIndex = colorbar_data.UserData.dataref;
else
    colorbarDataIndex = findColorbarData(obj,colorbarIndex);
end

%-set colorbar-%
obj.data{colorbarDataIndex}.colorbar = colorbar;

%-show scale-%
obj.data{colorbarDataIndex}.showscale = true;

%-REVERT UNITS-%
set(obj.State.Colorbar(colorbarIndex).Handle,'Units',colorbarunits);

end

