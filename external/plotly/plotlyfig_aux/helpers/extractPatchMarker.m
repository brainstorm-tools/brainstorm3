function marker = extractPatchMarker(patch_data)

% EXTRACTS THE MARKER STYLE USED FOR MATLAB OBJECTS
% OF TYPE "PATCH". THESE OBJECTS ARE USED IN AREASERIES
% BARSERIES, CONTOURGROUP, SCATTERGROUP.

%-------------------------------------------------------------------------%

%-AXIS STRUCTURE-%
axis_data = get(ancestor(patch_data.Parent,'axes'));

%-FIGURE STRUCTURE-%
figure_data = get(ancestor(patch_data.Parent,'figure'));

%-INITIALIZE OUTPUT-%
marker = struct();

%-------------------------------------------------------------------------%

%-MARKER SIZEREF-%
marker.sizeref = 1;

%-------------------------------------------------------------------------%

%-MARKER SIZEMODE-%
marker.sizemode = 'diameter';

%-------------------------------------------------------------------------%

%-MARKER SIZE (STYLE)-%
marker.size = patch_data.MarkerSize;

%-------------------------------------------------------------------------%

%-MARKER SYMBOL (STYLE)-%
if ~strcmp(patch_data.Marker,'none')
    
    switch patch_data.Marker
        case '.'
            marksymbol = 'circle';
        case 'o'
            marksymbol = 'circle';
        case 'x'
            marksymbol = 'x-thin-open';
        case '+'
            marksymbol = 'cross-thin-open';
        case '*'
            marksymbol = 'asterisk-open';
        case {'s','square'}
            marksymbol = 'square';
        case {'d','diamond'}
            marksymbol = 'diamond';
        case 'v'
            marksymbol = 'triangle-down';
        case '^'
            marksymbol = 'triangle-up';
        case '<'
            marksymbol = 'triangle-left';
        case '>'
            marksymbol = 'triangle-right';
        case {'p','pentagram'}
            marksymbol = 'star';
        case {'h','hexagram'}
            marksymbol = 'hexagram';
    end
    
    marker.symbol = marksymbol;
end

%-------------------------------------------------------------------------%

%-MARKER LINE WIDTH (STYLE)-%
marker.line.width = patch_data.LineWidth;

%-------------------------------------------------------------------------%

%--MARKER FILL COLOR--%

%-figure colormap-%
colormap = figure_data.Colormap;

% marker face color
MarkerColor = patch_data.MarkerFaceColor;

filledMarkerSet = {'o','square','s','diamond','d',...
    'v','^', '<','>','hexagram','pentagram'};

filledMarker = ismember(patch_data.Marker,filledMarkerSet);

% initialize markercolor output
markercolor = cell(1,length(patch_data.FaceVertexCData));

if filledMarker
    
    if isnumeric(MarkerColor)
        col = 255*MarkerColor;
        markercolor = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
    else
        switch MarkerColor
            
            case 'none'
                
                markercolor = 'rgba(0,0,0,0)';
                
            case 'auto'
                
                if ~strcmp(axis_data.Color,'none')
                    col = 255*axis_data.Color;
                else
                    col = 255*figure_data.Color;
                end
                
                markercolor  = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
                
                
            case 'flat'
                
                for n = 1:length(patch_data.FaceVertexCData)
                    
                    switch patch_data.CDataMapping
                        
                        case 'scaled'
                            capCD = max(min(patch_data.FaceVertexCData(n,1),axis_data.CLim(2)),axis_data.CLim(1));
                            scalefactor = (capCD - axis_data.CLim(1))/diff(axis_data.CLim);
                            col =  255*(colormap(1 + floor(scalefactor*(length(colormap)-1)),:));
                        case 'direct'
                            col =  255*(colormap(patch_data.FaceVertexCData(n,1),:));
                    end
                    
                    markercolor{n} = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
                    
                end
        end
    end
    
    marker.color = markercolor;
    
end


%-------------------------------------------------------------------------%

%-MARKER LINE COLOR-%

% marker edge color
MarkerLineColor = patch_data.MarkerEdgeColor;

filledMarker = ismember(patch_data.Marker,filledMarkerSet);

% initialize marker line color
markerlinecolor = cell(1,length(patch_data.FaceVertexCData));

if isnumeric(MarkerLineColor)
    col = 255*MarkerLineColor;
    markerlinecolor = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
else
    switch MarkerLineColor
        
        case 'none'
            
            markerlinecolor = 'rgba(0,0,0,0)';
            
        case 'auto'
            
            EdgeColor = patch_data.EdgeColor;
            
            if isnumeric(EdgeColor)
                col = 255*EdgeColor;
                markerlinecolor = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
            else
                
                switch EdgeColor
                    
                    case 'none'
                        
                        markerlinecolor = 'rgba(0,0,0,0)';
                        
                    case {'flat', 'interp'}
                        
                        for n = 1:length(patch_data.FaceVertexCData)
                            
                            switch patch_data.CDataMapping
                                
                                case 'scaled'
                                    capCD = max(min(patch_data.FaceVertexCData(n,1),axis_data.CLim(2)),axis_data.CLim(1));
                                    scalefactor = (capCD - axis_data.CLim(1))/diff(axis_data.CLim);
                                    col =  255*(colormap(1 + floor(scalefactor*(length(colormap)-1)),:));
                                    
                                case 'direct'
                                    col =  255*(colormap(patch_data.FaceVertexCData(n,1),:));
                                    
                            end
                            
                            markerlinecolor{n} = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
                            
                        end
                        
                end
            end
            
        case 'flat'
            
            for n = 1:length(patch_data.FaceVertexCData)
                
                switch patch_data.CDataMapping
                    
                    case 'scaled'
                        capCD = max(min(patch_data.FaceVertexCData(n,1),axis_data.CLim(2)),axis_data.CLim(1));
                        scalefactor = (capCD - axis_data.CLim(1))/diff(axis_data.CLim);
                        col =  255*(colormap(1+floor(scalefactor*(length(colormap)-1)),:));
                    case 'direct'
                        col =  255*(colormap(patch_data.FaceVertexCData(n,1),:));
                        
                end
                
                markerlinecolor{n} = ['rgb(' num2str(col(1)) ',' num2str(col(2)) ',' num2str(col(3)) ')'];
                
            end
    end
end

if filledMarker
    marker.line.color = markerlinecolor;
else
    marker.color = markerlinecolor;
end

%-------------------------------------------------------------------------%

end
