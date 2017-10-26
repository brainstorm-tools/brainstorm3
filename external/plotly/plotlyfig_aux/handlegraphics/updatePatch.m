function obj = updatePatch(obj, patchIndex)

%----PATCH FIELDS----%

% x - [DONE]
% y - [DONE]
% r - [HANDLED BY SCATTER]
% t - [HANDLED BY SCATTER]
% mode - [DONE]
% name - [DONE]
% text - [NOT SUPPORTED IN MATLAB]
% error_y - [HANDLED BY ERRORBAR]
% error_x - [HANDLED BY ERRORBAR]
% marler.color - [DONE]
% marker.size - [DONE]
% marker.line.color - [DONE]
% marker.line.width - [DONE]
% marker.line.dash - [NOT SUPPORTED IN MATLAB]
% marker.line.opacity --- [TODO]
% marker.line.smoothing - [NOT SUPPORTED IN MATLAB]
% marker.line.shape - [NOT SUPPORTED IN MATLAB]
% marker.opacity - [NOT SUPPORTED IN MATLAB]
% marker.colorscale - [NOT SUPPORTED IN MATLAB]
% marker.sizemode - [NOT SUPPORTED IN MATLAB]
% marker.sizeref - [NOT SUPPORTED IN MATLAB]
% marker.maxdisplayed - [NOT SUPPORTED IN MATLAB]
% line.color - [DONE]
% line.width - [DONE]
% line.dash - [DONE]
% line.opacity --- [TODO]
% line.smoothing - [NOT SUPPORTED IN MATLAB]
% line.shape - [NOT SUPPORTED IN MATLAB]
% connectgaps - [NOT SUPPORTED IN MATLAB]
% fill - [HANDLED BY PATCH]
% fillcolor - [HANDLED BY PATCH]
% opacity --- [TODO]
% textfont - [NOT SUPPORTED IN MATLAB]
% textposition - [NOT SUPPORTED IN MATLAB]
% xaxis [DONE]
% yaxis [DONE]
% showlegend [DONE]
% stream - [HANDLED BY PLOTLYSTREAM]
% visible [DONE]
% type [DONE]

%-AXIS INDEX-%
axIndex = obj.getAxisIndex(obj.State.Plot(patchIndex).AssociatedAxis);

%-PATCH DATA STRUCTURE- %
patch_data = get(obj.State.Plot(patchIndex).Handle);

%-CHECK FOR MULTIPLE AXES-%
[xsource, ysource] = findSourceAxis(obj,axIndex);

%-AXIS DATA-%
eval(['xaxis = obj.layout.xaxis' num2str(xsource) ';']);
eval(['yaxis = obj.layout.yaxis' num2str(ysource) ';']);

%-------------------------------------------------------------------------%

%-patch xaxis-%
obj.data{patchIndex}.xaxis = ['x' num2str(xsource)];

%-------------------------------------------------------------------------%

%-patch yaxis-%
obj.data{patchIndex}.yaxis = ['y' num2str(ysource)];

%-------------------------------------------------------------------------%

%-patch type-%
if any(nonzeros(patch_data.ZData))
    if obj.PlotOptions.TriangulatePatch
        obj.data{patchIndex}.type = 'mesh3d';
        
        % update the patch data using reducepatch
        patch_data_red = reducepatch(obj.State.Plot(patchIndex).Handle, 1);
        
    else
        obj.data{patchIndex}.type = 'scatter3d';
    end
else
    obj.data{patchIndex}.type = 'scatter'; 
end

%-------------------------------------------------------------------------%

if ~strcmp(obj.data{patchIndex}.type, 'mesh3d')
    %-patch x-%
    xdata = patch_data.XData;
    if isvector(xdata)
        obj.data{patchIndex}.x = [xdata' xdata(1)];
    else
        xtemp = reshape(xdata,[],1);
        xnew = [];
        for n = 1:size(xdata,2)
            xnew = [xnew ; xdata(:,n) ; xdata(1,n); NaN];
        end
        obj.data{patchIndex}.x = xnew;
    end

    %---------------------------------------------------------------------%

    %-patch y-%
    ydata = patch_data.YData;
    if isvector(ydata)
        obj.data{patchIndex}.y = [ydata' ydata(1)];
    else
        ytemp = reshape(ydata,[],1);
        ynew = [];
        for n = 1:size(ydata,2)
            ynew = [ynew ; ydata(:,n) ; ydata(1,n); NaN];
        end
        obj.data{patchIndex}.y = ynew;
    end

    %---------------------------------------------------------------------%

    %-patch z-%
    if any(nonzeros(patch_data.ZData))
        zdata = patch_data.ZData;

        if isvector(ydata)
            obj.data{patchIndex}.z = [zdata' zdata(1)];
        else
            ztemp = reshape(zdata,[],1);
            znew = [];
            for n = 1:size(zdata,2)
                znew = [znew ; zdata(:,n) ; zdata(1,n); NaN];
            end
            obj.data{patchIndex}.z = znew;
        end
    end

    %---------------------------------------------------------------------%

    %-patch name-%
    if ~isempty(patch_data.DisplayName);
        obj.data{patchIndex}.name = patch_data.DisplayName;
    else
        obj.data{patchIndex}.name = patch_data.DisplayName;
    end

    %---------------------------------------------------------------------%

    %-patch visible-%
    obj.data{patchIndex}.visible = strcmp(patch_data.Visible,'on');

    %---------------------------------------------------------------------%

    %-patch fill-%
    obj.data{patchIndex}.fill = 'tozeroy';

    %-PATCH MODE-%
    if ~strcmpi('none', patch_data.Marker) && ~strcmpi('none', patch_data.LineStyle)
        mode = 'lines+markers';
    elseif ~strcmpi('none', patch_data.Marker)
        mode = 'markers';
    elseif ~strcmpi('none', patch_data.LineStyle)
        mode = 'lines';
    else
        mode = 'none';
    end

    obj.data{patchIndex}.mode = mode;

    %---------------------------------------------------------------------%

    %-patch marker-%
    obj.data{patchIndex}.marker = extractPatchMarker(patch_data);

    %---------------------------------------------------------------------%

    %-patch line-%
    obj.data{patchIndex}.line = extractPatchLine(patch_data);

    %---------------------------------------------------------------------%

    %-patch fillcolor-%
    fill = extractPatchFace(patch_data);

    if strcmp(obj.data{patchIndex}.type,'scatter');
        obj.data{patchIndex}.fillcolor = fill.color; 
    else
        obj.data{patchIndex}.surfacecolor = fill.color;
    end

    %---------------------------------------------------------------------%

    %-surfaceaxis-%
    if strcmp(obj.data{patchIndex}.type,'scatter3d');
        minstd = min([std(patch_data.XData) std(patch_data.YData) std(patch_data.ZData)]);
        ind = find([std(patch_data.XData) std(patch_data.YData) std(patch_data.ZData)] == minstd)-1;
        obj.data{patchIndex}.surfaceaxis = ind; 
    end
else
    
    % handle vertices
    x_data = patch_data_red.vertices(:,1);
    y_data = patch_data_red.vertices(:,2);
    z_data = patch_data_red.vertices(:,3);

    % specify how vertices connect to form the faces
    i_data = patch_data_red.faces(:,1)-1; 
    j_data = patch_data_red.faces(:,2)-1;
    k_data = patch_data_red.faces(:,3)-1;
       
    %-patch x/y/z-%
    obj.data{patchIndex}.x = x_data; 
    obj.data{patchIndex}.y = y_data; 
    obj.data{patchIndex}.z = z_data; 
    
    %-patch i/j/k-%
    obj.data{patchIndex}.i = i_data; 
    obj.data{patchIndex}.j = j_data; 
    obj.data{patchIndex}.k = k_data;
    
    %-patch fillcolor-%
    fill = extractPatchFace(patch_data);
    obj.data{patchIndex}.color = fill.color;

end

%-------------------------------------------------------------------------%

%-patch showlegend-%
leg = get(patch_data.Annotation);
legInfo = get(leg.LegendInformation);

switch legInfo.IconDisplayStyle
    case 'on'
        showleg = true;
    case 'off'
        showleg = false;
end

obj.data{patchIndex}.showlegend = showleg;

%-------------------------------------------------------------------------%

end
