function varargout = figure_topo( varargin )
% FIGURE_TOPO: Creation and callbacks for topography figures.
%
% USAGE:  figure_topo('CurrentTimeChangedCallback', iDS, iFig)
%         figure_topo('ColormapChangedCallback',    iDS, iFig)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2008-2017

eval(macro_method);
end


%% =========================================================================================
%  ===== FIGURE CALLBACKS ==================================================================
%  =========================================================================================
%% ===== CURRENT TIME CHANGED =====
function CurrentTimeChangedCallback(iDS, iFig) %#ok<DEFNU>
    % Update topo plot
    UpdateTopoPlot(iDS, iFig);
end

%% ===== CURRENT FREQ CHANGED =====
function CurrentFreqChangedCallback(iDS, iFig) %#ok<DEFNU>
    global GlobalData;
    % Get figure appdata
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    TfInfo = getappdata(hFig, 'Timefreq');
    % If no frequencies in this figure
    if getappdata(hFig, 'isStaticFreq')
        return;
    end
    % Update frequency to display
    if ~isempty(TfInfo)
        TfInfo.iFreqs = GlobalData.UserFrequencies.iCurrentFreq;
        setappdata(hFig, 'Timefreq', TfInfo);
    end
    % Update plot
    UpdateTopoPlot(iDS, iFig);
end


%% ===== COLORMAP CHANGED =====
% Usage:  ColormapChangedCallback(iDS, iFig) : Update display anyway
function ColormapChangedCallback(iDS, iFig)
    global GlobalData;
     % Get figure and axes handles
    hFig  = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    % Get topography type requested (3DSensorCap, 2DDisc, 2DSensorCap, 2DLayout)
    TopoType = GlobalData.DataSet(iDS).Figure(iFig).Id.SubType;
    % Get colormap type
    ColormapInfo = getappdata(hFig, 'Colormap');
    
    % ==== Update colormap ====
    % Get colormap to use
    sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
    % Set figure colormap (for display of the colorbar only)
    set(hFig, 'Colormap', sColormap.CMap);
       
    % ==== Create/Delete colorbar ====
    % For all the display modes, but the 2DLayout
    if ~strcmpi(TopoType, '2DLayout') 
        bst_colormaps('SetColorbarVisible', hFig, sColormap.DisplayColorbar);
    end
end


%% ===== UPDATE PLOT =====
function UpdateTopoPlot(iDS, iFig)
    global GlobalData;

    % 2D LAYOUT: separate function
    if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, '2DLayout')
        UpdateTopo2dLayout(iDS, iFig);
        return
    end
    
    % ===== GET ALL INFORMATION =====
    % Get figure and axes handles
    hFig        = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    hAxes       = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    TopoHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Get data to display
    [DataToPlot, Time, selChan] = GetFigureData(iDS, iFig, 0);
    if isempty(DataToPlot)
        disp('BST> Warning: No data to update the topography surface.');
        % Remove color in topography display
        set(TopoHandles.hSurf, 'EdgeColor',       'g', ...
                               'FaceVertexCData', [], ...
                               'FaceColor',       'none');
        % Delete contour objects
        delete(TopoHandles.hContours);
        GlobalData.DataSet(iDS).Figure(iFig).Handles.hContours = [];
        return;
    end
    
    % ===== COMPUTE DATA MINMAX =====
    % Get timefreq display structure
    TfInfo = getappdata(hFig, 'Timefreq');
    % If min-max not calculated for the figure
    if isempty(TopoHandles.DataMinMax)
        % If not defined: get data normally
        if isempty(TfInfo) || isempty(TfInfo.FileName)
            Fall = GetFigureData(iDS, iFig, 1);
        else
            % Find timefreq structure
            iTf = find(file_compare({GlobalData.DataSet(iDS).Timefreq.FileName}, TfInfo.FileName), 1);
            % Get  values for all time window (only one frequency)
            Fall = bst_memory('GetTimefreqMaximum', iDS, iTf, TfInfo.Function);
        end
        % Get all the time instants
        TopoHandles.DataMinMax = [min(Fall(:)), max(Fall(:))];
        clear Fall;
    end

    % ===== APPLY TRANSFORMATION =====
    % Mapping on a different surface (magnetic source reconstruction of just smooth display)
    if ~isempty(TopoHandles.Wmat)
        % Apply interpolation matrix sensors => display surface
        if (size(TopoHandles.Wmat,1) == length(DataToPlot))
            DataToPlot = full(TopoHandles.Wmat * DataToPlot);
        % Find first corresponding indices
        else
            [tmp,I,J] = intersect(selChan, GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels);
            DataToPlot = full(TopoHandles.Wmat(:,J) * DataToPlot(I));
        end
    end

    % ===== Colormapping =====
    % Get figure colormap
    ColormapInfo = getappdata(hFig, 'Colormap');
    sColormap = bst_colormaps('GetColormap', ColormapInfo.Type);
    % Displaying LOG values: always use the "RealMin" display
    if ~isempty(TfInfo) && strcmpi(TfInfo.Function, 'log')
        sColormap.isRealMin = 1;
    end
    % Get figure maximum
    CLim = bst_colormaps('GetMinMax', sColormap, DataToPlot, TopoHandles.DataMinMax);
    if (CLim(1) == CLim(2))
        CLim = CLim + [-eps, +eps];
    end
    % Update figure colormap
    set(hAxes, 'CLim', CLim); 
    % Absolute values
    if sColormap.isAbsoluteValues
        DataToPlot = abs(DataToPlot);
    end
    
    % ===== Map data on target patch =====
    if ~isempty(TopoHandles.hSurf)
        set(TopoHandles.hSurf, 'FaceVertexCData', DataToPlot, ...
                               'EdgeColor', 'none');
                               % 'FaceColor', 'interp');
    elseif ~isempty(TopoHandles.hLines)
        % Convert data values to RGB
        iDataCmap = round( ((size(sColormap.CMap,1)-1)/(CLim(2)-CLim(1))) * (DataToPlot - CLim(1))) + 1;
        iDataCmap(iDataCmap <= 0) = 1;
        iDataCmap(iDataCmap > size(sColormap.CMap,1)) = size(sColormap.CMap,1);
        dataRGB = sColormap.CMap(iDataCmap, :);
        % Set lines colors
        for i = 1:length(TopoHandles.hLines)
            set(TopoHandles.hLines(i), 'Color', dataRGB(i,:));
        end
    end
    
    % ===== Colorbar ticks and labels =====
    % Data type
    if isappdata(hFig, 'Timefreq')
        DataType = 'timefreq';
    else
        DataType = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    end
    bst_colormaps('ConfigureColorbar', hFig, ColormapInfo.Type, DataType, ColormapInfo.DisplayUnits);
    
    % == Add contour plot ==
    if ismember(GlobalData.DataSet(iDS).Figure(iFig).Id.SubType, {'2DDisc', '2DSensorCap'})
        % Delete previous contours
        if ~isempty(TopoHandles.hContours) 
            if all(ishandle(TopoHandles.hContours))
                delete(TopoHandles.hContours);
                % Make sure the deletion work is done
                waitfor(TopoHandles.hContours);
            else
                TopoHandles.hContours = [];
            end
        end
        % Get 2DLayout display options
        TopoLayoutOptions = bst_get('TopoLayoutOptions');
        % Create new contours
        if (nnz(DataToPlot) > 0) && (TopoLayoutOptions.ContourLines > 0)
            Vertices = get(TopoHandles.hSurf, 'Vertices');
            Faces    = get(TopoHandles.hSurf, 'Faces');
            % Compute contours
            TopoHandles.hContours = tricontour(Vertices(:,1:2), Faces, DataToPlot, TopoLayoutOptions.ContourLines, hAxes);
        end
    end
    
    % Update stat clusters
    TopoInfo = getappdata(hFig, 'TopoInfo');
    if ~isempty(TopoInfo) && ~isempty(TopoInfo.FileName) && ismember(file_gettype(TopoInfo.FileName), {'pdata','ptimefreq','presult'})
        ViewStatClusters(hFig);
    end
    % Update current display structure
    GlobalData.DataSet(iDS).Figure(iFig).Handles = TopoHandles;
end


%% ===== GET FIGURE DATA =====
% Warning: Time output is only defined for the time-frequency plots
function [F, Time, selChan] = GetFigureData(iDS, iFig, isAllTime)
    global GlobalData;
    Time = [];
    % ===== GET INFORMATION =====
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    TopoInfo = getappdata(hFig, 'TopoInfo');
    TsInfo   = getappdata(hFig, 'TsInfo');
    if isempty(TopoInfo)
        return
    end
    % Get selected channels for topography
    selChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    % Get time
    if isAllTime
        TimeDef = 'UserTimeWindow';
    else
        TimeDef = 'CurrentTimeIndex';
    end
    Fall = [];
    % Get data description
    if ~isempty(TopoInfo.DataToPlot)
        F = TopoInfo.DataToPlot;
    else
        switch lower(TopoInfo.FileType)
            case {'data', 'pdata'}
                % Do not apply Meg/Grad correction if the field is extrapolated (this function already scales the sensors values)
                isGradMagScale = ~TopoInfo.UseSmoothing && ~strcmpi(TopoInfo.FileType, 'pdata');
                % Gradiometers norm
                if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality, 'MEG GRADNORM')
                    % Get Grad2 and Grad3 gradiometers
                    iGrad2 = good_channel(GlobalData.DataSet(iDS).Channel, GlobalData.DataSet(iDS).Measures.ChannelFlag, 'MEG GRAD2');
                    iGrad3 = good_channel(GlobalData.DataSet(iDS).Channel, GlobalData.DataSet(iDS).Measures.ChannelFlag, 'MEG GRAD3');
                    [iGrad2,I,J] = intersect(iGrad2, selChan);
                    iGrad3 = iGrad3(I);
                    % Get recordings
                    F2 = bst_memory('GetRecordingsValues', iDS, iGrad2, TimeDef, isGradMagScale);
                    F3 = bst_memory('GetRecordingsValues', iDS, iGrad3, TimeDef, isGradMagScale);
                    % Use the norm of the two
                    F = sqrt(F2.^2 + F3.^2);
                    % Error if montages are applied on this
                    if ~isempty(TsInfo.MontageName)
                        error('You cannot apply a montagne when displaying the norm of the gradiometers.');
                    end
                % Regular recordings
                else
                    % Get recordings (ALL the sensors, for re-referencing montages)
                    Fall = bst_memory('GetRecordingsValues', iDS, [], TimeDef, isGradMagScale);
                    % Select only a subset of sensors
                    F = Fall(selChan,:);
                end
            case 'timefreq'
                % Get timefreq values
                [Time, Freqs, TfInfo, TF, RowNames] = figure_timefreq('GetFigureData', hFig, TimeDef);
                % Initialize returned matrix
                F = zeros(length(selChan), size(TF, 2));
                % Re-order channels
                for i = 1:length(selChan)
                    selrow = GlobalData.DataSet(iDS).Channel(selChan(i)).Name;
                    % If displaying the norm of the gradiometers (Neuromag only)
                    if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality, 'MEG GRADNORM')
                        iRow2 = find(strcmpi(RowNames, [selrow(1:end-1), '2']));
                        iRow3 = find(strcmpi(RowNames, [selrow(1:end-1), '3']));
                        % If bock gradiometers were found
                        if ~isempty(iRow2) && ~isempty(iRow3)
                            F(i,:) = sqrt(TF(iRow2(1),:).^2 + TF(iRow3(1),:).^2);
                        end
                    % Reglar map
                    else
                        % Look for a sensor that is required in TF matrix
                        iRow = find(strcmpi(selrow, RowNames));
                        % If channel was found (if there is time-freq decomposition available for it)
                        if ~isempty(iRow)
                            F(i,:) = TF(iRow(1),:);
                        end
                    end
                end
        end
    end
    % Get time if required and not defined yet
    if (nargout >= 2) && isempty(Time)
        Time = bst_memory('GetTimeVector', iDS, [], TimeDef);
    end
    
    % ===== APPLY MONTAGE =====
    % Not available when the data is already saved in the figure (TopoInfo.DataToPlot)
    if strcmpi(TopoInfo.FileType, 'data') && ~isempty(TsInfo) && ~isempty(TsInfo.MontageName) && isempty(TopoInfo.DataToPlot)
        % Get channel names 
        ChanNames = {GlobalData.DataSet(iDS).Channel.Name};
        % Get montage
        sMontage = panel_montage('GetMontage', TsInfo.MontageName, hFig);
        % Do not do anything with the sensor selection only
        if ~isempty(sMontage) % && ismember(sMontage.Type, {'text','matrix'})
            % Get montage
            [iChannels, iMatrixChan, iMatrixDisp] = panel_montage('GetMontageChannels', sMontage, ChanNames);
            % Matrix: must be a full transformation, same list of inputs and outputs
            if strcmpi(sMontage.Type, 'matrix') && isequal(sMontage.DispNames, sMontage.ChanNames) && (length(iChannels) == size(F,1))
                F = sMontage.Matrix(iMatrixDisp,iMatrixChan) * Fall(iChannels,:);
            % Text: Bipolar montages only
            elseif strcmpi(sMontage.Type, 'text') && all(sum(sMontage.Matrix,2) < eps) && all(sum(sMontage.Matrix > 0,2) == 1)
                % Find the first channel in the bipolar montage (the one with the "+")
                iChanPlus = sum(bst_bsxfun(@times, sMontage.Matrix(iMatrixDisp,iMatrixChan) > 0, 1:length(iMatrixChan)), 2);
                % Warning
                if (length(iChanPlus) ~= length(unique(iChanPlus)))
                    disp(['BST> Error: Montage "' sMontage.Name '" contains repeated channels, topography contains errors.']);
                end
                % Apply montage (all the channels that not defined are set to zero)
                Ftmp = sMontage.Matrix(iMatrixDisp,iMatrixChan) * Fall(iChannels,:);
                F = zeros(size(Fall));
                F(iChannels(iChanPlus),:) = Ftmp;
                % JUSTIFICATIONS OF THOSE INDICES: The two statements below are equivalent
                %ChanPlusNames = sMontage.ChanNames(iMatrixChan(iChanPlus))
                %ChanPlusNames = ChanNames(iChannels(iChanPlus))
                % Return only the channels selected in this figure
                F = F(selChan,:);
            elseif strcmpi(sMontage.Type, 'selection')
                [selChan, I, J] = intersect(iChannels, selChan);
                F = F(J,:);
            elseif ~strcmpi(sMontage.Name, 'NIRS overlay[tmp]')
                disp(['BST> Montage "' sMontage.Name '" cannot be used for the 2D/3D topography views.']);
            end
        end
    end
end


%% ===== PLOT FIGURE =====
function isOk = PlotFigure(iDS, iFig, isReset) %#ok<DEFNU>
    global GlobalData;
    % Parse inputs
    if (nargin < 3) || isempty(isReset)
        isReset = 1;
    end
    isOk = 1;
    
    % ===== GET FIGURE INFORMATION =====
    % Get figure description
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    TopoInfo = getappdata(hFig, 'TopoInfo');
    if isempty(TopoInfo)
        return
    end
    % Get axes
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Prepare PlotHandles structure
    PlotHandles = db_template('DisplayHandlesTopography');
    % Set plot handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
    
    % ===== RESET VIEW =====
    if isReset
        % Delete all axes children except lights and anatomical surfaces
        hChildren = get(hAxes, 'Children');
        if ~isempty(hChildren)
            isDelete = ~strcmpi(get(hChildren, 'Type'), 'light') & ...
                       ~ismember(get(hChildren, 'Tag'), {'AnatSurface', 'MriCut1', 'MriCut2', 'MriCut3'});
            delete(hChildren(isDelete));
        end
        % Set Topography axes as current axes
        set(0,    'CurrentFigure', hFig);
        set(hFig, 'CurrentAxes',   hAxes);
        hold on
    end

    % ===== GET CHANNEL POSITIONS =====
    % Get modality channels
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    modChan  = good_channel(GlobalData.DataSet(iDS).Channel, [], Modality);
    Channel  = GlobalData.DataSet(iDS).Channel(modChan);
    % Get selected channels
    selChan = bst_closest(GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels, modChan);
    % Get sensor positions (Separate the gradiometers and magnetometer)
    [chan_loc, markers_loc] = figure_3d('GetChannelPositions', iDS, modChan);
    
    % 2D LAYOUT: separate function
    if strcmpi(TopoInfo.TopoType, '2DLayout')
        CreateTopo2dLayout(iDS, iFig, hAxes, Channel, markers_loc, modChan);
        return
    % 3D ELECTRODES: Separate function
    elseif strcmpi(TopoInfo.TopoType, '3DElectrodes')
        CreateTopo3dElectrodes(iDS, iFig, Channel(selChan), markers_loc(selChan,:));
        return
    % 3D OPTODES: Separate function
    elseif strcmpi(TopoInfo.TopoType, '3DOptodes')
        CreateTopo3dOptodes(iDS, iFig, Channel(selChan), markers_loc(selChan,:));
        return
    end
    
    % ===== CREATE A HIGH-DEF SURFACE =====
    % Remove the duplicated positions
    precision = 1e4;
    Vertices = unique(round(chan_loc * precision)/precision,'rows');
    % Remove the points at (0,0,0)
    iZero = find(all(abs(Vertices) < 1/precision, 2));
    if ~isempty(iZero)
        Vertices(iZero,:) = [];
    end
    % Compute best fitting sphere from sensors
    [bfs_center, bfs_radius] = bst_bfs(Vertices);
    % Tesselate sensor cap
    Faces = channel_tesselate(Vertices, 1);
    % Remove some  pathological triangles
    Faces = tess_threshold(Vertices, Faces, 5, 3, 170);
    % Refine mesh
    [Vertices, Faces] = tess_refine(Vertices, Faces, [], [], 1);
    
%     figure; plot3([chan_loc(:,1); markers_loc(:,1)], [chan_loc(:,2); markers_loc(:,2)], [chan_loc(:,3); markers_loc(:,3)], 'Marker', '+', 'LineStyle', 'none'); axis equal; rotate3d
%     figure; plot3(Vertices(:,1), Vertices(:,2), Vertices(:,3), 'Marker', '+', 'LineStyle', 'none'); axis equal; rotate3d
%     figure; patch('Vertices', Vertices, 'Faces', Faces, 'EdgeColor', [1 0 0]); axis equal; rotate3d

    % ===== TRANSFORM SURFACE =====
    switch lower(TopoInfo.TopoType) 
        % ===== 3D SENSOR CAP ===== 
        case '3dsensorcap'
            % Refine only low resolution surfaces
            if (length(markers_loc) < 100)
                [Vertices, Faces] = tess_refine(Vertices, Faces, [], [], 1);
            end
            % Display surface "as is"
            Vertices_surf = Vertices;
            Faces_surf    = Faces;
            % Store the sensor markers positions
            PlotHandles.MarkersLocs = markers_loc(selChan,:);

        % ===== 2D SENSOR CAP =====       
        case '2dsensorcap'
            % Refine only low resolution surfaces
            if (length(markers_loc) < 100)
                [Vertices, Faces] = tess_refine(Vertices, Faces, [], [], 1);
            end
            % 2D Projection
            if all(Vertices(:,3) < 0.0001)
                X = Vertices(:,1);
                Y = Vertices(:,2);
            else
                [X,Y] = bst_project_2d(Vertices(:,1), Vertices(:,2), Vertices(:,3), '2dcap');
            end
            % Center and scale in a [-1,-1,2,2] reclangle
            Xm = [min(X), max(X)];
            Ym = [min(Y), max(Y)];
            R = max(Xm(2)-Xm(1), Ym(2)-Ym(1));
            X = (X - Xm(1)) / R * 2 - (Xm(2)-Xm(1))/R;
            Y = (Y - Ym(1)) / R * 2 - (Ym(2)-Ym(1))/R;
            % Get 2D vertices coordinates, re-tesselate
            Vertices_surf = [X, Y, 0*X];
            Faces_surf = delaunay(X,Y);
            % Clean from some pathological triangles
            Faces_surf = tess_threshold(Vertices_surf, Faces_surf, 25, 20, 179);
            % Plot nose / ears
            PlotNoseEars(hAxes, 0);
            % Store the sensor markers positions
            [Xmark,Ymark] = bst_project_2d(markers_loc(:,1), markers_loc(:,2), markers_loc(:,3), '2dcap');
            Xmark = (Xmark - Xm(1)) / R * 2 - (Xm(2)-Xm(1))/R;
            Ymark = (Ymark - Ym(1)) / R * 2 - (Ym(2)-Ym(1))/R;
            PlotHandles.MarkersLocs = [Xmark(selChan), Ymark(selChan), 0.05 * ones(length(selChan),1)];

        % ===== 2D DISC SURFACE =====
        case '2ddisc'         
            % Data surface: Center on sphere
            Vertices_2d = bst_bsxfun(@minus, Vertices, bfs_center(:)');
            markers_loc = bst_bsxfun(@minus, markers_loc, bfs_center(:)');
            % Project 2D: Data surface
            [X2d,Y2d]   = bst_project_2d(Vertices_2d(:,1), Vertices_2d(:,2), Vertices_2d(:,3), 'circle');
            Vertices_2d = [X2d, Y2d, 0*X2d];
            % Project 2D: markers
            [Xmark,Ymark] = bst_project_2d(markers_loc(selChan,1), markers_loc(selChan,2), markers_loc(selChan,3), 'circle');
            MarkersLocs   = [Xmark, Ymark, 0*Xmark + 0.05];
            
            % Create 2D disc (display surface)
            [Vertices_surf, Faces_surf] = tess_disc(0.07);
            Vertices_surf = [Vertices_surf, 0*Vertices_surf(:,1)];
            % Interpolation: 2D projected data => 2D disc
            PlotHandles.Wmat = bst_shepards(Vertices_surf, Vertices_2d, 12, 0, 1);
            
            % Plot nose / ears (radius = 1)
            PlotNoseEars(hAxes, 1);
            % Markers positions in 2D
            PlotHandles.MarkersLocs = MarkersLocs;
            
        otherwise
            error('Invalid topography type : %s', OPTIONS.TimeSeriesSpatialTopo);
    end
    
    % ===== DISPLAY SURFACE =====
    % Create surface
    PlotHandles.hSurf = patch(...
        'Faces',            Faces_surf, ...
        'Vertices',         Vertices_surf, ...
        'EdgeColor',        'g', ...
        'FaceColor',        'interp', ...
        'FaceVertexCData',  repmat([0 0 0], size(Vertices_surf,1), 1), ...
        'BackfaceLighting', 'lit', ...
        'AmbientStrength',  0.95, ...
        'DiffuseStrength',  0, ...
        'SpecularStrength', 0, ...
        'FaceLighting',     'gouraud', ...
        'EdgeLighting',     'gouraud', ...
        'Parent',           hAxes, ...
        'Tag',              'TopoSurface');

    % ===== COMPUTE INTERPOLATION =====
    % Magnetic interpolation: we want values everywhere
    if TopoInfo.UseSmoothing && ismember(Modality, {'MEG', 'MEG MAG', 'MEG GRAD', 'MEG GRAD2', 'MEG GRAD3'})
        % Ignoring the bad senosors in the interpolation, so some values will be interpolated from the good sensors
        WExtrap = GetInterpolation(iDS, iFig, TopoInfo, Vertices, Faces, bfs_center, bfs_radius, chan_loc(selChan,:));
    % No magnetic interpolation: we want only values over the GOOD sensors
    else
        % Use all the modality sensors in the interpolation, so the sensors can influence only the values close to them
        WExtrap = GetInterpolation(iDS, iFig, TopoInfo, Vertices, Faces, bfs_center, bfs_radius, chan_loc);
        % Re-interpolate values for bad channels
        if size(WExtrap,2) > length(selChan)
            % Calculate interpolation bad sensors => good sensors
            iBad = setdiff(1:size(chan_loc,1), selChan);
            Wbad = eye(size(chan_loc,1));
            Wbad(iBad, selChan) = bst_shepards(chan_loc(iBad,:), chan_loc(selChan,:), 4);
            % Add this bad channel interpolator to the topography interpolator
            WExtrap = WExtrap * Wbad;
            % Keep only the good channels in the interpolation matrix
            WExtrap = WExtrap(:,selChan);
        end
    end
    if isempty(WExtrap)
        isOk = 0;
        return
    end
    % Combine with eventual previous interpolation matrix
    if isempty(PlotHandles.Wmat)
        PlotHandles.Wmat = WExtrap;
    else
        PlotHandles.Wmat = PlotHandles.Wmat * double(WExtrap);
    end
    % Set plot handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
    % Update display
    ColormapChangedCallback(iDS, iFig);
    UpdateTopoPlot(iDS, iFig);
end


%% ===== MAGNETIC EXTRAPOLATION =====
% If working with MEG data from Neuromag Vectorview machine, 
% for each sensor location, there are 3 channels of data recorded (2 gradiometers, 1 magnetometer)
% For those channels, Magnetic extrapolation needed 
function WExtrap = GetInterpolation(iDS, iFig, TopoInfo, Vertices, Faces, bfs_center, bfs_radius, chan_loc)
    global GlobalData;
    % Get selected channels
    selChan  = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    Modality = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
    % Get channel file
    ChannelFile = GlobalData.DataSet(iDS).ChannelFile;
    if ~isempty(ChannelFile)
        ProtocolInfo = bst_get('ProtocolInfo');
        ChannelFile = bst_fullfile(ProtocolInfo.STUDIES, ChannelFile);
    end
    
    % Signature for interpolation
    Signature = [double(TopoInfo.UseSmoothing), double(ChannelFile), double(Vertices(:,1)'), double(chan_loc(:,1)'), double(selChan(:)'), double(bfs_center(:)'), double(bfs_radius)];
    % Look for an existing interpolation
    if ~isempty(GlobalData.Interpolations)
        iInter = find(cellfun(@(c)isequal(c,Signature), {GlobalData.Interpolations.Signature}), 1);
        if ~isempty(iInter)
            WExtrap = GlobalData.Interpolations(iInter).WInterp;
            return
        end
    end
    
    % MEG: Perform extrapolation for all topo modes except 2DLayout
    if TopoInfo.UseSmoothing && ismember(Modality, {'MEG', 'MEG MAG', 'MEG GRAD', 'MEG GRAD2', 'MEG GRAD3'})
        % Getting only the baseline
        F = GetFigureData(iDS, iFig, 1);
        TimeVector = bst_memory('GetTimeVector', iDS, [], 'UserTimeWindow');
        iPreStim = find(TimeVector < 0);
        if (length(iPreStim) > 50) && ~any(iPreStim > size(F,2))
            FpreStim = F(:, iPreStim);
        else
            FpreStim = F;
        end
        % This function does everything that is needed here
        WExtrap = channel_extrapm('GetTopoInterp', ChannelFile, selChan, Vertices, Faces, bfs_center, bfs_radius, FpreStim);
    % No magenetic extrap: Compute interpolation function from sensors to patch surface (simple 3D interp)
    else
        % Detect the points at (0,0,0)
        precision = 1e6;
        iChanZero = find(all(abs(chan_loc) < 1/precision, 2));
        % Check if some sensors are located at the same position
        GoodChanLoc = chan_loc;
        GoodChanLoc(iChanZero,:) = [];
        uniqueChanLoc = unique(round(GoodChanLoc * precision)/precision,'rows');
        % If number of unique positions is different from total number of channels, there are multiple sensors at the same place
        if (size(uniqueChanLoc,1) ~= size(GoodChanLoc, 1)) && ~isequal(TopoInfo.Modality, 'NIRS')
            bst_error('Two or more sensors are located at the same position. Please try to fix this problem.', 'Plot topography', 0);
        end
        % Perform interpolation Sensors => Surface
        WExtrap = bst_shepards(Vertices, chan_loc, 12, 0, 1);
        % Set the bad sensors to zero
        WExtrap(:,iChanZero) = 0;
        
        % For EEG: Smooth the data
        if TopoInfo.UseSmoothing && strcmpi(TopoInfo.Modality, 'EEG')
            % Compute distance matrix
            N = size(chan_loc,1);
            dist = sqrt((repmat(chan_loc(:,1),1,N) - repmat(chan_loc(:,1),1,N)') .^ 2 + ...
                        (repmat(chan_loc(:,2),1,N) - repmat(chan_loc(:,2),1,N)') .^ 2 + ...
                        (repmat(chan_loc(:,3),1,N) - repmat(chan_loc(:,3),1,N)') .^ 2);
            % Remove all the distances > threshold
            dist(dist > 0.04) = 0;
            dist(iChanZero,:) = 0;
            dist(:,iChanZero) = 0;
            dist = dist + eye(N) .* 0.01;
            % Compute interpolation matrix
            W = zeros(N);
            W(dist~=0) = 1 ./ dist(dist~=0);
            iGood = any(W > 0);
            W(iGood,:) = bst_bsxfun(@rdivide, W(iGood,:), sum(W(iGood,:),2));
            % Apply weights to interpolation matrix
            WExtrap = WExtrap * W;
        end
    end

    % Save interpolation
    sInterp = db_template('interpolation');
    sInterp.WInterp   = WExtrap;
    sInterp.Signature = Signature;
    if isempty(GlobalData.Interpolations)
        GlobalData.Interpolations = sInterp;
    else
        GlobalData.Interpolations(end+1) = sInterp;
    end
end


%% ===== CREATE 2D LAYOUT =====
function CreateTopo2dLayout(iDS, iFig, hAxes, Channel, Vertices, modChan)
    global GlobalData;
    % ===== GET ALL DATA ===== 
    % Get data
    [F, Time, selChanGlobal] = GetFigureData(iDS, iFig, 1);
    selChan = bst_closest(selChanGlobal, modChan);
    if isempty(selChan)
        disp('2DLAYOUT> No good sensor to display...');
        return;
    end
    % Convert time bands in time vector
    if iscell(Time)
        nBands = size(Time,1);
        TimeVector = zeros(1,nBands);
        for i = 1:nBands
            % Take the middle of each time band
            TimeVector(i) = (Time{i,2} + Time{i,3}) / 2;
        end
    else
        TimeVector = Time;
    end
    % Center time vector on the CurrentTime
    TimeVector = TimeVector - GlobalData.UserTimeWindow.CurrentTime;
    % Get 2DLayout display options
    TopoLayoutOptions = bst_get('TopoLayoutOptions');
    % Default time window: all the window
    if isempty(TopoLayoutOptions.TimeWindow)
        TopoLayoutOptions.TimeWindow = abs(GlobalData.UserTimeWindow.Time(2) - GlobalData.UserTimeWindow.Time(1)) .* [-1, 1];
    end
    % Get only the 2DLayout time window
    iTime = find((TimeVector >= TopoLayoutOptions.TimeWindow(1)) & (TimeVector <= TopoLayoutOptions.TimeWindow(2)));
    % Check for errors
    if isempty(iTime)
        error('Invalid time window.');
    elseif (length(iTime) < 2)
        if (iTime + 1 <= length(TimeVector))
            iTime = [iTime, iTime + 1];
        elseif (iTime >= 2)
            iTime = [iTime - 1, iTime];
        else
            error('Invalid time window.');
        end
    end
    % Keep only the selected time indices
    TimeVector = TimeVector(iTime);
    F = F(:, iTime);
    % Flip Time vector (it's the way the data will be represented too)
    TimeVector = fliplr(TimeVector);
    % Look for current time in TimeVector
    iCurrentTime = bst_closest(0, TimeVector);
    if isempty(iCurrentTime)
        iCurrentTime = 1;
    end
    % Get graphic objects handles
    PlotHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    isDrawZeroLines   = isempty(PlotHandles.hZeroLines)    || any(~ishandle(PlotHandles.hZeroLines));
    isDrawLines       = isempty(PlotHandles.hLines)        || any(~ishandle(PlotHandles.hLines));
    isDrawLegend      = isempty(PlotHandles.hLabelLegend);
    isDrawSensorLabels= isempty(PlotHandles.hSensorLabels) || any(~ishandle(PlotHandles.hSensorLabels));

    % ===== CREATE SURFACE =====
    % 2D Projection
    if all(Vertices(:,3) < 0.0001)
        X = Vertices(:,1);
        Y = Vertices(:,2);
    else
        [X,Y] = bst_project_2d(Vertices(:,1), Vertices(:,2), Vertices(:,3), '2dlayout');
    end
    % Zoom factor: size of each signal depends on the number of signals
    if (length(selChan) < 60)
        plotSize = [0.05, 0.05] .* sqrt(120 ./ length(selChan));
    else
        plotSize = [0.05, 0.05];
    end
    % Normalize positions between 0 and 1
    X = (X - min(X)) ./ (max(X) - min(X)) .* (1-plotSize(1))   + plotSize(1) ./ 2;
    Y = (Y - min(Y)) ./ (max(Y) - min(Y)) .* (1-plotSize(2)*2) + plotSize(2);
    % Normalize data
    M = double(max(abs(F(:))));
    F = F ./ M;
    % Normalize time between 0 and 1
    TimeVector = (TimeVector - TimeVector(1)) ./ (TimeVector(end) - TimeVector(1));
    % Get display factor
    DispFactor = PlotHandles.DisplayFactor; % * figure_timeseries('GetDefaultFactor', GlobalData.DataSet(iDS).Figure(iFig).Id.Modality);
    % Draw each sensor
    for i = 1:length(selChan)
        Xi = X(selChan(i));
        Yi = Y(selChan(i));
        % Get sensor data
        dat = F(i,:);
        datMin = min(dat);
        datMax = max(dat);
        % Draw sensor time serie
        PlotHandles.ChannelOffsets(i) = Xi;
        % Define lines to trace
        XData  = plotSize(1) * dat(end:-1:1)    * DispFactor + Xi;
        Xrange = plotSize(1) * [datMin, datMax] * DispFactor + Xi;
        YData  = plotSize(2) * (TimeVector - 0.5) + Yi;
        ZData  = 0;
        
        % === ZERO LINE / TIME CURSOR ===
        if TopoLayoutOptions.ShowRefLines
            if isDrawZeroLines
                % Zero line
                PlotHandles.hZeroLines(i) = line([Xi, Xi], [YData(1), YData(end)], [ZData, ZData], ...
                        'Tag',    '2DLayoutZeroLines', ...
                        'Parent', hAxes);
                % Time cursor
                PlotHandles.hCursors(i) = line([Xrange(1), Xrange(2)], [Yi, Yi], [ZData, ZData], ...
                        'Tag',    '2DLayoutTimeCursor', ...
                        'Parent', hAxes);
            else
                set(PlotHandles.hZeroLines(i),   'XData', [Xi, Xi], 'YData', [YData(1), YData(end)]);
                set(PlotHandles.hCursors(i), 'XData', [Xrange(1), Xrange(2)], 'YData', [YData(iCurrentTime), YData(iCurrentTime)]);
            end
        else
            delete(findobj(hAxes, '-depth', 1, 'Tag', '2DLayoutZeroLines'));
            delete(findobj(hAxes, '-depth', 1, 'Tag', '2DLayoutTimeCursor'));
            PlotHandles.hZeroLines   = [];
            PlotHandles.hCursors = [];
        end
        
        % === DATA LINE ===
        if isDrawLines
            % Draw new lines
            PlotHandles.hLines(i) = line(XData, YData, 0*XData + ZData + 0.001, ...
                    'Tag',           'Lines2DLayout', ...
                    'Parent',        hAxes, ...
                    'UserData',      selChanGlobal(i), ...
                    'ButtonDownFcn', @(h,ev)LineClickedCallback(h,selChanGlobal(i)));
        else
            % Update xisting lines
            set(PlotHandles.hLines(i), ...
                'XData', XData, ...
                'YData', YData, ...
                'ZData', 0*XData + ZData + 0.001);
        end
        PlotHandles.BoxesCenters(i,:) = [Xi, mean(YData([1,end]))];
        
        % === SENSOR NAME ===
        Xtext = 1.2 * plotSize(2) * datMax + Xi;
        Ytext = Yi;
        if isDrawSensorLabels
            PlotHandles.hSensorLabels(i) = text(Xtext, Ytext, 0*Xtext + ZData, ...
                       Channel(selChan(i)).Name, ...
                       'VerticalAlignment',   'baseline', ...
                       'HorizontalAlignment', 'center', ...
                       'FontSize',            bst_get('FigFont'), ...
                       'FontUnits',           'points', ...
                       'Interpreter',         'none', ...
                       'Visible',             'off', ...
                       'Tag',                 'SensorsLabels', ...
                       'Parent',              hAxes);
%         else
%             => CANNOT KEEP THAT: UPDATE IS WAY TOO SLOW
%             set(PlotHandles.hSensorLabels(i), 'Position', [Xtext, Ytext, 0]);
        end
    end
    
    % ===== LEGEND =====
    if TopoLayoutOptions.ShowLegend
        % Create legend label
        if isDrawLegend
            % Get figure color
            figColor = get(hFig, 'Color');
            figPos   = get(hFig, 'Position');
            % Find opposite colors
            if (sum(figColor .^ 2) > 0.8)
                textColor = [0 0 0];
            else
                textColor = [.8 .8 .8];
            end
            % Create axes
            PlotHandles.hAxesLegend = axes(...
                'Parent',        hFig, ...
                'Tag',           'AxesTimestamp', ...
                'Units',         'Pixels', ...
                'Position',      [0, 0, figPos(3), 50], ...
                'Color',         'none', ...
                'XColor',        figColor, ...
                'YColor',        figColor, ...
                'XLim',          [0,1], ...
                'YLim',          [0,1], ...
                'YGrid',         'off', ...
                'XGrid',         'off', ...
                'XMinorGrid',    'off', ...
                'XTick',         [], ...
                'YTick',         [], ...
                'TickLength',    [0,0], ...
                'XTickLabel',    [], ...
                'Box',           'off', ...
                'Interruptible', 'off', ...
                'BusyAction',    'queue');
            % Create label
            PlotHandles.hLabelLegend = text(...
                10 / figPos(3), .5, '', ...
                'FontUnits',   'points', ...
                'FontWeight',  'bold', ...
                'FontSize',    8, ...
                'Color',       textColor, ...
                'Interpreter', 'none', ...
                'Tag',         'LabelTimestamp', ...
                'Parent',      PlotHandles.hAxesLegend);
            % Reset current axes
            set(hFig, 'CurrentAxes', hAxes);
        end
        % Get data type
        if isappdata(hFig, 'Timefreq')
            DataType = 'timefreq';
        else
            DataType = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
        end
        % Get data units and time window
        [fScaled, fFactor, fUnits] = bst_getunits( M, DataType );
        msTime = round(TopoLayoutOptions.TimeWindow * 1000);
        fUnits = strrep(fUnits, 'x10^{', 'e');
        fUnits = strrep(fUnits, '10^{', 'e');
        fUnits = strrep(fUnits, '}', '');
        fUnits = strrep(fUnits, '\mu', 'u');
        fUnits = strrep(fUnits, '\Delta', 'd');
        % Create legend text
        strLegend = sprintf(['Max amplitude: %d %s\n' ...
                             'Time window: [%d, %d] ms'], ...
                            round(fScaled), fUnits, msTime(1), msTime(2));
        % Update legend
        set(PlotHandles.hLabelLegend, 'String', strLegend, 'Visible', 'on');
    elseif ~isDrawLegend
        set(PlotHandles.hLabelLegend, 'Visible', 'off');
    end
    
    % ===== AXES LIMITS =====
    % Set axes limits
    set(hAxes, 'XLim', [0 1], 'YLim', [0 1]);
    
    % ===== FIGURE COLORS =====
    if TopoLayoutOptions.WhiteBackground
        figColor  = [1,1,1];
        dataColor = [0,0,0];
        refColor  = .8 * [1,1,1];
        textColor = .7 * [1 1 1];
    else
        figColor  = [0,0,0];
        dataColor = [1,1,1];
        refColor  = .4 * [1,1,1];
        textColor = .8 * [1 1 1];
    end
    % Set figure background
    set(hFig, 'Color', figColor);
    % Set objects lines color (only the non-selected ones, selected channels remain red)
    set(PlotHandles.hLines, 'Color', dataColor);
    if ~isempty(PlotHandles.hZeroLines)
        set(PlotHandles.hZeroLines,   'Color', refColor);
        set(PlotHandles.hCursors, 'Color', refColor);
    end
    if ~isempty(PlotHandles.hSensorLabels)
        set(PlotHandles.hSensorLabels, 'Color', textColor);
    end
    if ~isempty(PlotHandles.hLabelLegend)
        set(PlotHandles.hLabelLegend, 'Color', textColor);
    end
    % Save lines color
    PlotHandles.LinesColor = dataColor;
    % Save properties
    PlotHandles.Channel  = Channel;
    PlotHandles.Vertices = Vertices;
    PlotHandles.ModChan  = modChan;
    PlotHandles.SelChanGlobal = selChanGlobal;

    GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
    % Update selected channels
    figure_3d('UpdateFigSelectedRows', iDS, iFig);
end


%% ===== UPDATE 2DLAYOUT =====
function UpdateTopo2dLayout(iDS, iFig)
    global GlobalData;
    % Get plot handles
    PlotHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    hAxes = findobj(GlobalData.DataSet(iDS).Figure(iFig).hFigure, '-depth', 1, 'Tag', 'Axes3D');
    % Get previous values
    if isfield(PlotHandles, 'Channel') && ~isempty(PlotHandles.Channel)
        CreateTopo2dLayout(iDS, iFig, hAxes, PlotHandles.Channel, PlotHandles.Vertices, PlotHandles.ModChan);
    end
end


%% ===== CREATE 3D ELECTRODES =====
function CreateTopo3dElectrodes(iDS, iFig, Channel, ChanLoc)
    global GlobalData;
    % Get figure handles
    PlotHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Display the electrodes
    PlotHandles.hSurf = figure_3d('PlotSensors3D', iDS, iFig, Channel, ChanLoc);
    % Create interpolation matrix [Nvertices x Nchannels]
    vert2chan = get(PlotHandles.hSurf, 'UserData');
    Wi = 1:length(vert2chan);
    Wj = vert2chan;
    PlotHandles.Wmat = sparse(Wi, Wj, ones(size(Wi)), length(vert2chan), size(ChanLoc,1));
    % Set plot handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
    % Update display
    ColormapChangedCallback(iDS, iFig);
    UpdateTopoPlot(iDS, iFig);
end


%% ===== CREATE 3D OPTODES =====
function CreateTopo3dOptodes(iDS, iFig, Channel, ChanLoc)
    global GlobalData;
    % Get figure handles
    PlotHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Display the electrodes
    PlotHandles.hLines = figure_3d('PlotNirsCap', GlobalData.DataSet(iDS).Figure(iFig).hFigure, 1);
    % Set plot handles
    GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
    % Update display
    ColormapChangedCallback(iDS, iFig);
    UpdateTopoPlot(iDS, iFig);
end


%% ===== CALLBACK: LINE CLICKED =====
function LineClickedCallback(hLine, iChan)
    hFig = ancestor(hLine, 'figure');
    setappdata(hFig, 'ChannelsToSelect', iChan);
end


%% ===== PLOT NOSE AND EARS =====
function PlotNoseEars(hAxes, isDisc)
    % Define coordinates
    Z = 0.0005;
    NoseX = [0.983; 1.15; 0.983];
    NoseY = [.18;       0;   -.18];
    NoseZ = 0*NoseX + Z;
    EarX  = [.0555 .0775 .0783 .0746  .0555  -.0055 -.0932 -.1313 -.1384 -.1199] * 2;
    EarY  = ([.973, 1     1.016 1.0398 1.0638  1.06   1.074  1.044, 1      .951 ] + 0.02);
    EarZ  = 0*EarX + Z;
    % Line properties
    LineWidth = 2;
    LineColor = [.4 .4 .4];
    % Plot nose
    plot3(NoseX, NoseY, NoseZ, ...
         'Color',     LineColor, ...
         'LineWidth', LineWidth, ...
         'Tag',       'RefTopo', ...
         'Parent',    hAxes);
    % Plot left ear
    plot3(EarX, EarY, EarZ, ...
         'Color',     LineColor, ...
         'LineWidth', LineWidth, ...
         'Tag',       'RefTopo', ...
         'Parent',    hAxes);
    % Plot right ear
    plot3(EarX, -EarY, EarZ, ...
         'Color',     LineColor, ...
         'LineWidth', LineWidth, ...
         'Tag',       'RefTopo', ...
         'Parent',    hAxes);
     % Plot circle
     if isDisc
        t = 0:pi/50:2*pi;
        CircX = 1 * cos(t);
        CircY = 1 * sin(t);
        CircZ = 0 * t + Z;
        plot3(CircX, CircY, CircZ, ...
             'Color',     LineColor, ...
             'LineWidth', LineWidth, ...
             'Tag',       'RefTopo', ...
             'Parent',    hAxes);
     end
end


%% ===== UPDATE TIME SERIES FACTOR =====
function UpdateTimeSeriesFactor(hFig, changeFactor) %#ok<DEFNU>
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles;

    % Update figure lines
    for iLine = 1:length(Handles.hLines)
        % Get values
        XData = get(Handles.hLines(iLine), 'XData');
        % Re-center them on zero, and change the factor
        XData = (XData - Handles.ChannelOffsets(iLine)) * changeFactor + Handles.ChannelOffsets(iLine);
        % Update value
        set(Handles.hLines(iLine), 'XData', XData);
    end
    % Update factor value
    GlobalData.DataSet(iDS).Figure(iFig).Handles.DisplayFactor = Handles.DisplayFactor * changeFactor;

%     % Save current change factor
%     isSave = 1;
%     if isSave
%         figure_timeseries('SetDefaultFactor', iDS, iFig, changeFactor);
%     end
end


%% ===== UPDATE TIME SERIES FACTOR =====
function UpdateTopoTimeWindow(hFig, changeFactor) %#ok<DEFNU>
    global GlobalData;
    % Get current time window
    TopoLayoutOptions = bst_get('TopoLayoutOptions');
    % If the window hasn't been changed yet: use the full time definition
    if isempty(TopoLayoutOptions.TimeWindow)
        TopoLayoutOptions.TimeWindow = abs(GlobalData.UserTimeWindow.Time(2) - GlobalData.UserTimeWindow.Time(1)) .* [-1, 1];
    end
    % Increase time window by a given factor in each direction
    newTimeWindow = changeFactor * TopoLayoutOptions.TimeWindow;
    % Set new time window
    SetTopoLayoutOptions('TimeWindow', newTimeWindow);
end


%% ===== SET 2DLAYOUT OPTIONS =====
function SetTopoLayoutOptions(option, value)
    % Parse inputs
    if (nargin < 2)
        value = [];
    end
    % Get current options
    TopoLayoutOptions = bst_get('TopoLayoutOptions');
    % Apply changes
    switch(option)
        case 'TimeWindow'
            % If time window is provided
            if ~isempty(value)
                newTimeWindow = value;
            % Else: Ask user for new time window
            else
                maxTimeWindow = [-Inf, Inf];
                newTimeWindow = panel_time('InputTimeWindow', maxTimeWindow, 'Time window around the current time in the 2DLayout views:', TopoLayoutOptions.TimeWindow, 'ms');
                if isempty(newTimeWindow)
                    return;
                end
            end
            % Save new time window
            TopoLayoutOptions.TimeWindow = newTimeWindow;
            isLayout = 1;
        case 'WhiteBackground'
            TopoLayoutOptions.WhiteBackground = value;
            isLayout = 1;
        case 'ShowRefLines'
            TopoLayoutOptions.ShowRefLines = value;
            isLayout = 1;
        case 'ShowLegend'
            TopoLayoutOptions.ShowLegend = value;
            isLayout = 1;
        case 'ContourLines'
            TopoLayoutOptions.ContourLines = value;
            isLayout = 0;
    end
    % Save options permanently
    bst_set('TopoLayoutOptions', TopoLayoutOptions);
    % Update all 2DLayout figures
    bst_figures('FireTopoOptionsChanged', isLayout);
end


%% ===== VIEW STAT CLUSTERS =====
function ViewStatClusters(hFig)
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    if isempty(iDS)
        return
    end
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
    % Delete existing markers
    hClusterMarkers = findobj(hAxes, '-depth', 1, 'Tag', 'ClusterMarkers');
    if ~isempty(hClusterMarkers)
        delete(hClusterMarkers);
    end
    % Get active clusters
    sClusters = panel_stat('GetDisplayedClusters', hFig);
    if isempty(sClusters)
        return;
    end
    % Check if there is a channel file associated with this figure
    if isempty(GlobalData.DataSet(iDS).Channel)
        return
    end
    % Get figure type
    Figure = GlobalData.DataSet(iDS).Figure(iFig);
    selChan = Figure.SelectedChannels;
    % Get TimeVector and current time indice
    [TimeVector, iTime] = bst_memory('GetTimeVector', iDS);
    % Get stat display properties 
    StatInfo = getappdata(hFig, 'StatInfo');
    TfInfo   = getappdata(hFig, 'Timefreq');   
    
    % === TOPOGRAPHY ===
    if strcmpi(Figure.Id.Type, 'Topography')
        % Markers locations where stored in the Handles structure while creating topography patch
        if ~isempty(Figure.Handles.MarkersLocs)
            markersLocs = Figure.Handles.MarkersLocs;
        % 3DElectrodes/3DOptodes: get directly the channel positions
        else
            markersLocs = figure_3d('GetChannelPositions', iDS, selChan);
        end
        % Flag=1 if 2D display
        switch (Figure.Id.SubType)
            case {'2DDisc','2DSensorCap'}
                markersLocs(:,3) = markersLocs(:,3) + 0.001;
            case '3DSensorCap'
                markersLocs = markersLocs * 1.01;
            case {'3DElectrodes', '3DOptodes'}
                markersLocs = markersLocs * 1.02;
        end
        % Time-freq: use all the sensors
        if ~isempty(TfInfo) && ~isempty(TfInfo.FileName)
            [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', TfInfo.FileName);
            RowNames = {GlobalData.DataSet(iDS).Channel(selChan).Name};
            [Values, iTimeBands, iRow, nComponents] = bst_memory('GetTimefreqValues', iDS, iTimefreq, RowNames);
            selChan = iRow;
        end
        % Plot each cluster separately
        for iClust = 1:length(sClusters)
            % Select currnet data from mask
            if ~isempty(GlobalData.UserFrequencies.iCurrentFreq) && (size(sClusters(iClust).mask,3) > 1)
                curMask = sClusters(iClust).mask(selChan, :, GlobalData.UserFrequencies.iCurrentFreq);
            else
                curMask = sClusters(iClust).mask(selChan, :, 1);
            end
            % Get significant sensors at current time
            if ~isempty(StatInfo) && strcmpi(StatInfo.DisplayMode, 'longest')
                [lenMax, iSelMarker] = max(sum(curMask,2));
                MarkerSize = 30;
            else
                iSelMarker = curMask(:,iTime);
                MarkerSize = 14;
            end
            % Plot dots to indicate the significant sensors
            if ~isempty(iSelMarker)
                line(markersLocs(iSelMarker,1), markersLocs(iSelMarker,2), markersLocs(iSelMarker,3), ...
                    'Parent',          hAxes, ...
                    'LineWidth',       1, ...
                    'LineStyle',       'none', ...
                    'MarkerFaceColor', sClusters(iClust).color, ...
                    'MarkerEdgeColor', sClusters(iClust).color, ...
                    'MarkerSize',      MarkerSize, ...
                    'Marker',          '.', ...
                    'Tag',             'ClusterMarkers');
            end
        end
    end
end


