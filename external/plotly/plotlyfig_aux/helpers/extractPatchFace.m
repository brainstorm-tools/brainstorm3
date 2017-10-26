function marker = extractPatchFace(patch_data)
% EXTRACTS THE FACE STYLE USED FOR MATLAB OBJECTS
% OF TYPE "PATCH". THESE OBJECTS ARE USED BOXPLOTS.

%-------------------------------------------------------------------------%

%-AXIS STRUCTURE-%
axis_data = get(ancestor(patch_data.Parent,'axes'));

%-FIGURE STRUCTURE-%
figure_data = get(ancestor(patch_data.Parent,'figure'));

%-INITIALIZE OUTPUT-%
marker = struct(); 

%-------------------------------------------------------------------------%

%-PATCH EDGE WIDTH-%
marker.line.width = patch_data.LineWidth;

%-------------------------------------------------------------------------%

%-PATCH FACE COLOR-%

colormap = figure_data.Colormap;

if isnumeric(patch_data.FaceColor)
    
    %-paper_bgcolor-%
    col = 255*patch_data.FaceColor;
    marker.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    
else
    switch patch_data.FaceColor
        
        case 'none'
            marker.color = 'rgba(0,0,0,0)';
            
        case {'flat','interp'}
            
            switch patch_data.CDataMapping
                
                case 'scaled'
                    capCD = max(min(patch_data.FaceVertexCData(1,1),axis_data.CLim(2)),axis_data.CLim(1));
                    scalefactor = (capCD -axis_data.CLim(1))/diff(axis_data.CLim);
                    col =  255*(colormap(1+ floor(scalefactor*(length(colormap)-1)),:));
                case 'direct'
                    col =  255*(colormap(patch_data.FaceVertexCData(1,1),:));
                    
            end
            
            marker.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
            
    end
end

%-------------------------------------------------------------------------%

%-PATCH EDGE COLOR-%

if isnumeric(patch_data.EdgeColor)
    
    col = 255*patch_data.EdgeColor;
    marker.line.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    
else
    switch patch_data.EdgeColor
        
        case 'none'
            marker.line.color = 'rgba(0,0,0,0,)';
            
        case 'flat'
            
            switch patch_data.CDataMapping
                
                case 'scaled'
                    capCD = max(min(patch_data.FaceVertexCData(1,1),axis_data.CLim(2)),axis_data.CLim(1));
                    scalefactor = (capCD -axis_data.CLim(1))/diff(axis_data.CLim);
                    col =  255*(colormap(1+floor(scalefactor*(length(colormap)-1)),:));
                    
                case 'direct'
                    col =  255*(colormap(patch_data.FaceVertexCData(1,1),:));
                    
            end
            
            marker.line.color = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    end
end
end
