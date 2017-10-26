function line = extractAreaLine(area_data)

% EXTRACTS THE LINE STYLE USED FOR MATLAB OBJECTS
% OF TYPE "LINE". THESE OBJECTS ARE USED IN LINESERIES,
% STAIRSERIES, STEMSERIES, BASELINESERIES, AND BOXPLOTS

%-------------------------------------------------------------------------%

%-INITIALIZE OUTPUT-%
line = struct(); 

%-------------------------------------------------------------------------%

%-AREA LINE COLOR-%

if(~strcmp(area_data.LineStyle,'none'))
    
    % marker edge color
    LineColor = area_data.EdgeColor;
    
    if isnumeric(LineColor)
        col = 255*LineColor;
        linecolor = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    else
        linecolor = 'rgba(0,0,0,0)';
    end
    
    line.color = linecolor; 
    
%-------------------------------------------------------------------------%
    
    %-PATCH LINE WIDTH (STYLE)-%
    line.width = area_data.LineWidth;
    
%-------------------------------------------------------------------------%
    
    %-PATCH LINE DASH (STYLE)-%
    switch area_data.LineStyle
        case '-'
            LineStyle = 'solid';
        case '--'
            LineStyle = 'dash';
        case ':'
            LineStyle = 'dot';
        case '-.'
            LineStyle = 'dashdot';
    end
    
    line.dash = LineStyle;
    
%-------------------------------------------------------------------------%

end
end


