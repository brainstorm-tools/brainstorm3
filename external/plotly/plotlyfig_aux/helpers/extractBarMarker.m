function marker = extractBarMarker(bar_data)
% EXTRACTS THE FACE STYLE USED FOR MATLAB OBJECTS
% OF TYPE "bar". THESE OBJECTS ARE USED BARGRAPHS.

%-------------------------------------------------------------------------%

%-AXIS STRUCTURE-%
axis_data = get(ancestor(bar_data.Parent,'axes'));

%-FIGURE STRUCTURE-%
figure_data = get(ancestor(bar_data.Parent,'figure'));

%-INITIALIZE OUTPUT-%
marker = struct(); 

%-------------------------------------------------------------------------%

%-bar EDGE WIDTH-%
marker.line.width = bar_data.LineWidth;

%-------------------------------------------------------------------------%

%-bar FACE COLOR-%

colormap = figure_data.Colormap;

if isnumeric(bar_data.FaceColor)
    
    %-paper_bgcolor-%
    col = 255*bar_data.FaceColor;
    marker.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    
else
    switch bar_data.FaceColor
        
        case 'none'
            marker.color = 'rgba(0,0,0,0,)';
            
        case 'flat'
            
            switch bar_data.CDataMapping
                
                case 'scaled'
                    capCD = max(min(bar_data.FaceVertexCData(1,1),axis_data.CLim(2)),axis_data.CLim(1));
                    scalefactor = (capCD -axis_data.CLim(1))/diff(axis_data.CLim);
                    col =  255*(colormap(1+ floor(scalefactor*(length(colormap)-1)),:));
                case 'direct'
                    col =  255*(colormap(bar_data.FaceVertexCData(1,1),:));
                    
            end
            
            marker.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
            
    end
end

%-------------------------------------------------------------------------%

%-bar EDGE COLOR-%

if isnumeric(bar_data.EdgeColor)
    
    col = 255*bar_data.EdgeColor;
    marker.line.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    
else
    switch bar_data.EdgeColor
        
        case 'none'
            marker.line.color = 'rgba(0,0,0,0,)';
            
        case 'flat'
            
            switch bar_data.CDataMapping
                
                case 'scaled'
                    capCD = max(min(bar_data.FaceVertexCData(1,1),axis_data.CLim(2)),axis_data.CLim(1));
                    scalefactor = (capCD -axis_data.CLim(1))/diff(axis_data.CLim);
                    col =  255*(colormap(1+floor(scalefactor*(length(colormap)-1)),:));
                    
                case 'direct'
                    col =  255*(colormap(bar_data.FaceVertexCData(1,1),:));
                    
            end
            
            marker.line.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    end
end
end
