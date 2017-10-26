function obj = updateStem(obj,dataIndex)

%------------------------------------------------------------------------%

%-update line-%
updateLineseries(obj,dataIndex);
stem_temp_data = obj.data{dataIndex};

%------------------------------------------------------------------------%

%-scatter mode-%
stem_temp_data.mode = 'lines+markers';

%------------------------------------------------------------------------%

%-allocated space for extended data-%
xdata_extended = zeros(1,3*length(stem_temp_data.x)); 
ydata_extended = zeros(1,3*length(stem_temp_data.y));

%-format x data-%
m = 1; 
for n = 1:length(stem_temp_data.x)
    xdata_extended(m) = stem_temp_data.x(n); 
    xdata_extended(m+1) = stem_temp_data.x(n); 
    xdata_extended(m+2) = nan; 
    m = m + 3; 
end

%-format y data-%
m = 1; 
for n = 1:length(stem_temp_data.y)
    ydata_extended(m) = 0; 
    ydata_extended(m+1) = stem_temp_data.y(n); 
    ydata_extended(m+2) = nan; 
    m = m + 3; 
end

%-hide every other marker-%
color_temp = cell(1,3*length(stem_temp_data.y));
line_color_temp = cell(1,3*length(stem_temp_data.y));

for n = 1:3:length(color_temp)
    color_temp{n} = 'rgba(0,0,0,0)';
    color_temp{n+1} = stem_temp_data.marker.color;
    color_temp{n+2} = 'rgba(0,0,0,0)';
    line_color_temp{n} = 'rgba(0,0,0,0)';
    line_color_temp{n+1} = stem_temp_data.marker.line.color;
    line_color_temp{n+2} = 'rgba(0,0,0,0)';
end

% add new marker/line colors
stem_temp_data.marker.color = color_temp;
stem_temp_data.marker.line.color = line_color_temp;

%------------------------------------------------------------------------%

stem_temp_data.x = xdata_extended; 
stem_temp_data.y = ydata_extended; 

%------------------------------------------------------------------------%

obj.data{dataIndex} = stem_temp_data;

end