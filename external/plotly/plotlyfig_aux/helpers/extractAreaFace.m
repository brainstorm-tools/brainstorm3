function face = extractAreaFace(area_data)

% EXTRACTS THE FACE STYLE USED FOR MATLAB OBJECTS
% OF TYPE "PATCH". THESE OBJECTS ARE USED IN AREASERIES
% BARSERIES, CONTOURGROUP, SCATTERGROUP.

%-------------------------------------------------------------------------%

%-AXIS STRUCTURE-%
axis_data = get(ancestor(area_data,'axes'));

%-FIGURE STRUCTURE-%
figure_data = get(ancestor(area_data,'figure'));

%-------------------------------------------------------------------------%

%-INITIALIZE OUTPUT-%
face = struct();

%-------------------------------------------------------------------------%

%--FACE FILL COLOR--%

%-figure colormap-%
colormap = figure_data.Colormap;

% face face color
MarkerColor = area_data.FaceColor;

if isnumeric(MarkerColor)
    col = 255*MarkerColor;
    facecolor = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
else
    switch MarkerColor
        
        case 'none'
            
            facecolor = 'rgba(0,0,0,0)';
            
        case 'flat'
            areaACData = area_data.getColorAlphaDataExtents;
            capCD = max(min(areaACData(1,1),axis_data.CLim(2)),axis_data.CLim(1));
            scalefactor = (capCD - axis_data.CLim(1))/diff(axis_data.CLim);
            col =  255*(colormap(1 + floor(scalefactor*(length(colormap)-1)),:));
            facecolor = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    end
end

face.color = facecolor;

%-------------------------------------------------------------------------%

end