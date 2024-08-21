function varargout = figure_topo( varargin )
% FIGURE_TOPO: Creation and callbacks for topography figures.
%
% USAGE:  figure_topo('CurrentTimeChangedCallback', iDS, iFig)
%         figure_topo('ColormapChangedCallback',    iDS, iFig)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2022

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
    % Get topography type requested (3DSensorCap, 2DDisc, 2DSensorCap, 2DLayout)
    TopoType = GlobalData.DataSet(iDS).Figure(iFig).Id.SubType;
    % Get TimeFreq info
    TfInfo = getappdata(hFig, 'Timefreq');
    % If no frequencies (time series) in this figure
    if getappdata(hFig, 'isStaticFreq')
        return;
    end
    % Update frequency to display
    if ~isempty(TfInfo) && ~(strcmpi(TopoType, '2DLayout') && getappdata(hFig, 'isStatic'))
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
    [DataToPlot, Time, selChan, overlayLabels, dispNames, StatThreshUnder, StatThreshOver] = GetFigureData(iDS, iFig, 0);
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
    % Displaying LOG values   : always use the "RealMin" display and not absolutes values
    % Displaying Power values : always use absolutes values
    if ~isempty(TfInfo) && strcmpi(ColormapInfo.Type, 'timefreq')
        isAbsoluteValues = sColormap.isAbsoluteValues;
        if strcmpi(TfInfo.Function, 'log')
            sColormap.isRealMin = 1;
            isAbsoluteValues = 0;
        elseif strcmpi(TfInfo.Function, 'power')
            isAbsoluteValues = 1;
        end
        if isAbsoluteValues ~= sColormap.isAbsoluteValues
            sColormap.isAbsoluteValues = isAbsoluteValues;
            bst_colormaps('SetColormap', ColormapInfo.Type, sColormap);
        end
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
    % Adapt colormap for stat threshold
    if sColormap.UseStatThreshold && (~isempty(StatThreshUnder) || ~isempty(StatThreshOver))
        % Extend the color of null value to non-significant values and put all the color dynamics for significant values
        sColormap.CMap = bst_colormaps('StatThreshold', sColormap.CMap, CLim(1), CLim(2), ...
                                       sColormap.isAbsoluteValues, StatThreshUnder, StatThreshOver, ...
                                       [0.7 0.7 0.7]);

        % Update figure colorbar accordingly
        set(hFig, 'Colormap', sColormap.CMap);
        % Create/Delete colorbar
        bst_colormaps('SetColorbarVisible', hFig, sColormap.DisplayColorbar);
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
        if (length(TopoHandles.hLines) == 1)
            for i = 1:length(TopoHandles.hLines{1})
                set(TopoHandles.hLines{1}(i), 'Color', dataRGB(i,:));
            end
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
% Warning: xAxis output is only defined for the timefreq plots
%          xAxis = 'Time'  for TF maps
%          xAxis = 'Freqs' for Spectra
function [F, xAxis, selChan, overlayLabels, dispNames, StatThreshUnder, StatThreshOver] = GetFigureData(iDS, iFig, isAllTime, isMultiOutput)
    global GlobalData;
    % Initialize returned values
    F = [];
    xAxis = [];
    selChan = [];
    overlayLabels = {};
    dispNames = {};
    StatThreshUnder = [];
    StatThreshOver = [];
    % Parse inputs
    if (nargin < 4) || isempty(isMultiOutput)
        isMultiOutput = 0;
    end
    % ===== GET INFORMATION =====
    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    TopoInfo = getappdata(hFig, 'TopoInfo');
    TsInfo = getappdata(hFig, 'TsInfo');
    if isempty(TopoInfo)
        return
    end
    % Get multiple data files
    if ~isempty(TopoInfo.MultiDataFiles)
        ReadFiles = TopoInfo.MultiDataFiles;
    else
        ReadFiles = {TopoInfo.FileName};
    end
    % Get selected channels for topography
    selChan = GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels;
    % Get time
    if isAllTime
        TimeDef = 'UserTimeWindow';
    else
        TimeDef = 'CurrentTimeIndex';
    end
    Fall = {};
    % Get data description
    if ~isempty(TopoInfo.DataToPlot)
        F = {TopoInfo.DataToPlot};
    else
        F = cell(1, length(ReadFiles));
        for iFile = 1:length(ReadFiles)
            switch lower(TopoInfo.FileType)
                case {'data', 'pdata'}
                    % Get file comment
                    switch (file_gettype(ReadFiles{iFile}))
                        case 'data'
                            [sStudy, iStudy, iData] = bst_get('DataFile', ReadFiles{iFile});
                            if ~isempty(sStudy)
                                overlayLabels{iFile} = sStudy.Data(iData).Comment;
                            end
                        case 'pdata'
                            [sStudy, iStudy, iStat] = bst_get('StatFile', ReadFiles{iFile});
                            if ~isempty(sStudy)
                                overlayLabels{iFile} = sStudy.Stat(iStat).Comment;
                            end
                    end
                    % Get loaded recordings
                    iDSread = bst_memory('LoadDataFile', ReadFiles{iFile});
                    % If data matrix is not loaded: load it now
                    if isempty(GlobalData.DataSet(iDSread).Measures) || isempty(GlobalData.DataSet(iDSread).Measures.F)
                        bst_memory('LoadRecordingsMatrix', iDSread);
                    end
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
                        F2 = bst_memory('GetRecordingsValues', iDSread, iGrad2, TimeDef, isGradMagScale);
                        F3 = bst_memory('GetRecordingsValues', iDSread, iGrad3, TimeDef, isGradMagScale);
                        % Use the norm of the two
                        F{iFile} = sqrt(F2.^2 + F3.^2);
                        % Error if montages are applied on this
                        if ~isempty(TsInfo.MontageName)
                            error('You cannot apply a montage when displaying the norm of the gradiometers.');
                        end
                    % Regular recordings
                    else
                        % Get recordings (ALL the sensors, for re-referencing montages)
                        Fall{iFile} = bst_memory('GetRecordingsValues', iDSread, [], TimeDef, isGradMagScale);
                        % Select only a subset of sensors
                        F{iFile} = Fall{iFile}(selChan,:);
                    end
                    % Stat threshold
                    if strcmpi(file_gettype(ReadFiles{iFile}), 'pdata')
                        StatThreshOver = GlobalData.DataSet(iDS).Measures.StatThreshOver;
                        StatThreshUnder = GlobalData.DataSet(iDS).Measures.StatThreshUnder;
                    end
                case 'timefreq'
                    [sStudy, iStudy, iTimefreq] = bst_get('TimefreqFile', ReadFiles{iFile});
                    if ~isempty(sStudy)
                        overlayLabels{iFile} = sStudy.Timefreq(iTimefreq).Comment;
                    end
                    % Get loaded timefreq values (only first file DS is the same as Fig)
                    TfInfo = getappdata(hFig, 'Timefreq');
                    TfInfo.FileName = file_short(ReadFiles{iFile});
                    setappdata(hFig, 'Timefreq', TfInfo);
                    [Time, Freqs, TfInfo, TF, RowNames] = figure_timefreq('GetFigureData', hFig, TimeDef);
                    xAxis = Time;      % TF map
                    isStatic = getappdata(hFig, 'isStatic');
                    if isStatic
                        xAxis = Freqs; % Spectrum
                    end
                    % Initialize returned matrix
                    F{iFile} = zeros(length(selChan), length(xAxis));

                    % Re-order channels
                    for i = 1:length(selChan)
                        selrow = GlobalData.DataSet(iDS).Channel(selChan(i)).Name;
                        % If displaying the norm of the gradiometers (Neuromag only)
                        if strcmpi(GlobalData.DataSet(iDS).Figure(iFig).Id.Modality, 'MEG GRADNORM')
                            iRow2 = find(strcmpi(RowNames, [selrow(1:end-1), '2']));
                            iRow3 = find(strcmpi(RowNames, [selrow(1:end-1), '3']));
                            % If bock gradiometers were found
                            if ~isempty(iRow2) && ~isempty(iRow3)
                                F{iFile}(i,:) = sqrt(TF(iRow2(1),:).^2 + TF(iRow3(1),:).^2);
                            end
                        % Regular map
                        else
                            % Look for a sensor that is required in TF matrix
                            iRow = find(strcmpi(selrow, RowNames));
                            % If channel was found (if there is time-freq decomposition available for it)
                            if ~isempty(iRow)
                                if isStatic
                                    F{iFile}(i,:) = TF(iRow(1),1,:); % Spectrum
                                else
                                    F{iFile}(i,:) = TF(iRow(1),:,1); % Freq slice in TF
                                end
                            end
                        end
                    end
            end
        end
        % Reset TfInfo with first TF file
        if strcmpi(TopoInfo.FileType, 'timefreq')
            TfInfo.FileName = file_short(ReadFiles{1});
            setappdata(hFig, 'Timefreq', TfInfo);
        end
    end
    % Get time if required and not defined yet
    if (nargout >= 2) && isempty(xAxis) &&  ismember(lower(TopoInfo.FileType), {'data', 'pdata'})
        xAxis = bst_memory('GetTimeVector', iDS, [], TimeDef);
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
            % Loop on files
            for iFile = 1:length(F)
                % Matrix: must be a full transformation, same list of inputs and outputs
                if strcmpi(sMontage.Type, 'matrix') && isequal(sMontage.DispNames, sMontage.ChanNames) % && (length(iChannels) == size(F{iFile},1))
                    F{iFile} = zeros(size(Fall{iFile}));
                    F{iFile}(iChannels,:) = sMontage.Matrix(iMatrixDisp,iMatrixChan) * Fall{iFile}(iChannels,:);
                    F{iFile} = F{iFile}(selChan,:);
                    % Select channel names (number of channels does not change)
                    dispNames = ChanNames;
                    dispNames(iChannels) = sMontage.DispNames(iMatrixDisp);
                    dispNames = dispNames(selChan);
                % Text: Bipolar montages only
                elseif strcmpi(sMontage.Type, 'text') && all(sum(sMontage.Matrix,2) < eps) && all(sum(sMontage.Matrix > 0,2) == 1)
                    % Find the first channel in the bipolar montage (the one with the "+")
                    iChanPlus = sum(bst_bsxfun(@times, sMontage.Matrix(iMatrixDisp,iMatrixChan) > 0, 1:length(iMatrixChan)), 2);
                    % Cannot apply montages that give non-unique lists of channels
                    if (length(iChanPlus) ~= length(unique(iChanPlus)))
                        disp(['BST> Error: Montage "' sMontage.Name '" cannot be represented in a 2D/3D topography: it gives non-unique list of channels.']);
                    end
                    % Apply montage (all the channels that not defined are set to zero)
                    Ftmp = sMontage.Matrix(iMatrixDisp,iMatrixChan) * Fall{iFile}(iChannels,:);
                    F{iFile} = zeros(size(Fall{iFile}));
                    F{iFile}(iChannels(iChanPlus),:) = Ftmp;
                    % JUSTIFICATIONS OF THOSE INDICES: The two statements below are equivalent
                    %ChanPlusNames = sMontage.ChanNames(iMatrixChan(iChanPlus))
                    %ChanPlusNames = ChanNames(iChannels(iChanPlus))
                    % Return only the channels selected in this figure
                    F{iFile} = F{iFile}(selChan,:);
                    % Keep channel names that were not changed (same logic as above)
                    dispNames = ChanNames;
                    dispNames(iChannels(iChanPlus)) = sMontage.DispNames(iMatrixDisp);
                    dispNames = dispNames(selChan);
                elseif strcmpi(sMontage.Type, 'selection')
                    selChan = intersect(iChannels, selChan);
                    F{iFile} = Fall{iFile}(selChan,:);
                    dispNames = ChanNames(selChan);
                % NIRS: Represent the multiple data types as overlay, with legends
                elseif strcmpi(sMontage.Name, 'NIRS overlay[tmp]') && (length(F) == 1)
                    overlayLabels = unique({GlobalData.DataSet(iDS).Channel(selChan).Group});
                    % Select channel names (number of channels does not change)
                    dispNames = ChanNames;
                    dispNames(iChannels) = sMontage.DispNames(iMatrixDisp);
                    dispNames = dispNames(selChan);
                else
                    disp(['BST> Montage "' sMontage.Name '" cannot be used for this view.']);
                end
            end
        end
    end
    % If same comments: replace labels with file names
    if (length(overlayLabels) > 1)
        if (length(overlayLabels) ~= length(unique(overlayLabels)))
            overlayLabels = ReadFiles;
        end
        [commonLabel, overlayLabels] = str_common_path(overlayLabels);
    end
    % Replace NaN with zeros
    for iFile = 1:length(F)
        Nnan = nnz(isnan(F{iFile}));
        if (Nnan > 0)
            disp(sprintf('BST> WARNING: %d NaN values replaced with zeros.', Nnan));
            F{iFile}(isnan(F{iFile})) = 0;
        end
    end
    % Return only one file if required
    if ~isMultiOutput
        F = F{1};
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
    % 2D/3D ELECTRODES: Separate function
    elseif strcmpi(TopoInfo.TopoType, '3DElectrodes') || strcmpi(TopoInfo.TopoType, '2DElectrodes')
        CreateTopo3dElectrodes(iDS, iFig, Channel(selChan), markers_loc(selChan,:), TopoInfo.TopoType);
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
    [F, xAxis, selChanGlobal, overlayLabels, dispNames] = GetFigureData(iDS, iFig, 1, 1);
    selChan = bst_closest(selChanGlobal, modChan);
    if isempty(selChan)
        disp('2DLAYOUT> No good sensor to display...');
        return;
    end
    % Convert x axis (time or frequency) bands in time vector
    if iscell(xAxis)
        % Take the middle of each time band
        xAxisVector = zeros(1, size(xAxis,1));
        xAxisVector(:) = mean(process_tf_bands('GetBounds', xAxis), 2);
    else
        xAxisVector = xAxis;
    end

    % Get 2DLayout display options
    TopoLayoutOptions = bst_get('TopoLayoutOptions');

    hFig = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    isStatic     = getappdata(hFig, 'isStatic');     % Time static
    isStaticFreq = getappdata(hFig, 'isStaticFreq'); % Freq static

    % Flip Y axis if needed
    if TopoLayoutOptions.FlipYAxis && isStaticFreq
        F = cellfun(@(c)times(c,-1), F, 'UniformOutput', 0);
    end

    % Handle xAxis as Time
    if ~isStatic
        % Default time window: all the window
        if isempty(TopoLayoutOptions.TimeWindow)
            TopoLayoutOptions.TimeWindow = GlobalData.UserTimeWindow.Time;
        % Otherwise, center the time window around the current time
        else
            winLen = (TopoLayoutOptions.TimeWindow(2) - TopoLayoutOptions.TimeWindow(1));
            TopoLayoutOptions.TimeWindow = bst_saturate(GlobalData.UserTimeWindow.CurrentTime + winLen ./ 2 .* [-1, 1] , GlobalData.UserTimeWindow.Time, 1);
        end
        xWindow = TopoLayoutOptions.TimeWindow;
    else
        % Default freq window: all spectrum
        if isempty(TopoLayoutOptions.FreqWindow)
            TopoLayoutOptions.FreqWindow = [xAxisVector(1), xAxisVector(end)];
        end
        xWindow = TopoLayoutOptions.FreqWindow;
    end

    % Get only requested x axis window
    ixAxis = find((xAxisVector >= xWindow(1)) & (xAxisVector <= xWindow(2)));
    % Check for errors
    if isempty(ixAxis)
        error('Invalid x-axis window.');
    elseif (length(ixAxis) < 2)
        if (ixAxis + 1 <= length(xAxisVector))
            ixAxis = [ixAxis, ixAxis + 1];
        elseif (ixAxis >= 2)
            ixAxis = [ixAxis - 1, ixAxis];
        else
            error('Invalid x-axis window.');
        end
    end
    % Keep only the selected time indices
    xAxisVector = xAxisVector(ixAxis);
    % Flip x axis vector (it's the way the data will be represented too)
    xAxisVector = fliplr(xAxisVector);
    if ~isStatic
        % Look for current time in TimeVector
        iCurrentX = bst_closest(GlobalData.UserTimeWindow.CurrentTime, xAxisVector);
    else
        if iscell(GlobalData.UserFrequencies.Freqs)
            bands = mean(process_tf_bands('GetBounds', xAxis), 2);
            currentX = bands(GlobalData.UserFrequencies.iCurrentFreq);
        else
            currentX = GlobalData.UserFrequencies.Freqs(GlobalData.UserFrequencies.iCurrentFreq);
        end
        iCurrentX = bst_closest(currentX, xAxisVector);
    end
    % Current position
    if isempty(iCurrentX)
        iCurrentX = 1;
    end
    % Normalize xAxis between 0 and 1
    xAxisVector = (xAxisVector - xAxisVector(1)) ./ (xAxisVector(end) - xAxisVector(1));
    % Get graphic objects handles
    PlotHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    isDrawZeroLines   = isempty(PlotHandles.hZeroLines)    || any(~ishandle(PlotHandles.hZeroLines));
    isDrawLines       = isempty(PlotHandles.hLines)        || any(~ishandle(PlotHandles.hLines{1}));
    isDrawLegend      = isempty(PlotHandles.hLabelLegend);
    isDrawSensorLabels= isempty(PlotHandles.hSensorLabels) || any(~ishandle(PlotHandles.hSensorLabels));

    % Default figure colors
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
    % If multiple files, get default color table
    if (length(F) > 1)
        % ColorTable = panel_scout('GetScoutsColorTable');
        ColorTable = [...
                 0    0.4470    0.7410
            0.8500    0.3250    0.0980
            0.9290    0.6940    0.1250
            0.4940    0.1840    0.5560
            0.4660    0.6740    0.1880
            0.3010    0.7450    0.9330
            0.6350    0.0780    0.1840];
        dataColor = ColorTable(mod(0:length(F)-1, length(ColorTable)) + 1, :);
    end
    % If a montage was used: name and color are redefined
    if ~isempty(dispNames)
        [linesLabels, linesColor] = panel_montage('ParseMontageLabels', dispNames, dataColor);
    else
        linesLabels = {Channel(selChan).Name};
        linesColor = [];
    end
    
    % ===== CREATE SURFACE =====
    LabelRows = {};
    LabelRowsRef = [];
    plotSize = [];
    % SEEG/ECOG: DO no use real positions
    if ismember(Channel(1).Type, {'SEEG','ECOG'}) && ~isempty(GlobalData.DataSet(iDS).IntraElectrodes)
        [X, Y, LabelRows, LabelRowsRef] = GetSeeg2DPositions(Channel, GlobalData.DataSet(iDS).IntraElectrodes);
        maxX = max(abs(X));
        maxY = max(abs(Y));
        plotSize = [0.8/maxX, 0.8/maxY];
    % 2D Projection
    elseif all(Vertices(:,3) < 0.0001)
        X = Vertices(:,1);
        Y = Vertices(:,2);
    % Regular sensors with 3D coordinates: Project in 2D
    else
        [X,Y] = bst_project_2d(Vertices(:,1), Vertices(:,2), Vertices(:,3), '2dlayout');
    end
    % Zoom factor: size of each signal depends on the number of signals
    if isempty(plotSize)
        if strcmpi(Channel(selChan(1)).Type, 'NIRS')
            nPlots = length(selChan) ./ length(unique({Channel(selChan).Group}));
        else
            nPlots = length(selChan);
        end
        if (nPlots < 60)
            plotSize = [0.05, 0.044] .* sqrt(120 ./ nPlots);
        else
            plotSize = [0.05, 0.05];
        end
    end
    % Normalize positions between 0 and 1
    X = (X - min(X)) ./ (max(X) - min(X)) .* (1-plotSize(1))   + plotSize(1) ./ 2;
    Y = (Y - min(Y)) ./ (max(Y) - min(Y)) .* (1-plotSize(2)*2) + plotSize(2);
    % Get display factor
    DispFactor = PlotHandles.DisplayFactor; % * figure_timeseries('GetDefaultFactor', GlobalData.DataSet(iDS).Figure(iFig).Id.Modality);
    
    % Loop on multiple files
    MinMaxs = zeros(2, length(F));
    for iFile = 1:length(F)
        % Keep only selected time points
        F{iFile} = F{iFile}(:, ixAxis);
        % Find minimum and maximum
        MinMaxs(1, iFile) = double(min(F{iFile}(:)));
        MinMaxs(2, iFile) = double(max(F{iFile}(:)));
    end
    % Get scale and offset to normalize data
    TfInfo = getappdata(hFig, 'Timefreq');
    if isStatic && isfield(TfInfo, 'Function') && strcmpi(TfInfo.Function, 'log') && max(MinMaxs(:)) < 0
        % Data is dB
        offset = max(MinMaxs(2,:));
        % Remove offset
        M = max(abs(MinMaxs(1,:) - offset));
        F = cellfun(@(c)minus(c, offset), F, 'UniformOutput', 0);
    else
        offset = 0;
        M = max(abs(MinMaxs(2,:)));
    end
    % Normalize data
    F = cellfun(@(c)rdivide(c, M), F, 'UniformOutput', 0);

    % Draw each sensor
    displayedLabels = {};
    for i = 1:length(selChan)
        Xi = X(selChan(i));
        Yi = Y(selChan(i));
        % Loop on multiple files
        for iFile = 1:length(F)
            % Get sensor data
            dat = F{iFile}(i,:);
            datMin = min(dat);
            datMax = max(dat);
            % Draw sensor time serie
            PlotHandles.ChannelOffsets(i) = Xi;
            % Define lines to trace
            XData  = plotSize(1) * dat(end:-1:1) * DispFactor + Xi;
            Xrange = plotSize(1) * [min(0,datMin), max(0,datMax)] * DispFactor + Xi;
            Xrange = Xrange + 0.2.*[-1, 1].*(abs(diff(Xrange)));
            YData  = plotSize(2) * (xAxisVector - 0.5) + Yi;
            ZData  = 0;
            
            % === DATA LINE ===
            if isDrawLines
                % Draw new lines
                PlotHandles.hLines{iFile}(i) = line(XData, YData, 0*XData + ZData + 0.001, ...
                        'Tag',           'Lines2DLayout', ...
                        'Parent',        hAxes, ...
                        'UserData',      selChanGlobal(i), ...
                        'ButtonDownFcn', @(h,ev)LineClickedCallback(h,selChanGlobal(i)));
            else
                % Update existing lines
                set(PlotHandles.hLines{iFile}(i), ...
                    'XData', XData, ...
                    'YData', YData, ...
                    'ZData', 0*XData + ZData + 0.001);
            end
            % Set color: default if only one, colors otherwise
            if ~isempty(linesColor) && (length(selChan) == size(linesColor,1))
                curColor = linesColor(i,:);
            else
                curColor = dataColor(iFile,:);
            end
            set(PlotHandles.hLines{iFile}(i), 'Color', curColor);
            PlotHandles.LinesColor{iFile}(i,:) = curColor;
        end
        % Save position of each graph
        PlotHandles.BoxesCenters(i,:) = [Xi, mean(YData([1,end]))];
            
        % === ZERO LINE / TIME CURSOR ===
        if TopoLayoutOptions.ShowRefLines
            if isDrawZeroLines
                % Zero line
                PlotHandles.hZeroLines(i) = line([Xi, Xi], [YData(1), YData(end)], [ZData, ZData], ...
                        'Tag',    '2DLayoutZeroLines', ...
                        'Parent', hAxes);
                % X axis cursor
                PlotHandles.hCursors(i) = line([Xrange(1), Xrange(2)], [YData(iCurrentX), YData(iCurrentX)], [ZData, ZData], ...
                        'Tag',    '2DLayoutTimeCursor', ...
                        'Parent', hAxes);
            else
                set(PlotHandles.hZeroLines(i),   'XData', [Xi, Xi], 'YData', [YData(1), YData(end)]);
                set(PlotHandles.hCursors(i), 'XData', [Xrange(1), Xrange(2)], 'YData', [YData(iCurrentX), YData(iCurrentX)]);
            end
        else
            if ~isempty(PlotHandles.hZeroLines)
                delete(PlotHandles.hZeroLines);
                PlotHandles.hZeroLines = [];
            end
            if ~isempty(PlotHandles.hCursors)
                delete(PlotHandles.hCursors);
                PlotHandles.hCursors = [];
            end
        end
        
        % === SENSOR NAME ===
        if isDrawSensorLabels
            Xtext = 1.2 * plotSize(2) * datMax + Xi;
            Ytext = Yi;
            % Display empty object for labels that are already displayed
            if ismember(linesLabels{i}, displayedLabels)
                curLabel = '';
            else
                curLabel = linesLabels{i};
                displayedLabels{end+1} = linesLabels{i};
            end
            PlotHandles.hSensorLabels(i) = text(Xtext, Ytext, 0*Xtext + ZData, ...
                       curLabel, ...
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
    
    % ===== ROW LABELS =====
    if ~isempty(LabelRows)
        for iRow = 1:length(LabelRows)
            Xtext = X(LabelRowsRef(iRow));
            Ytext = 1.03;
            hText = text(Xtext, Ytext, 0*Xtext + 1, ...
                LabelRows{iRow}, ...
                'VerticalAlignment',   'baseline', ...
                'HorizontalAlignment', 'left', ...
                'FontSize',            bst_get('FigFont'), ...
                'FontUnits',           'points', ...
                'Interpreter',         'none', ...
                'Color',               [0 1 0], ...
                'Visible',             'on', ...
                'Tag',                 'RowLabels', ...
                'Parent',              hAxes);
        end
        % Why do we have to print something else to have the labels displayed??????
        line([-1,-1],[-1,-1],[-1,-1], 'color', [1 1 1], 'Parent', hAxes);
    end
    
    % ===== LEGEND =====
    if TopoLayoutOptions.ShowLegend
        % Create legend label
        if isDrawLegend
            % Scale figure
            Scaling = bst_get('InterfaceScaling') / 100;
            % Get figure position
            figPos = get(hFig, 'Position');
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
                'Position',      [0, 0, figPos(3), 50.*Scaling], ...
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
                10 / figPos(3), .6, '', ...
                'FontUnits',   'points', ...
                'FontWeight',  'bold', ...
                'FontSize',    8 .* Scaling, ...
                'Color',       textColor, ...
                'Interpreter', 'none', ...
                'Tag',         'LabelTimestamp', ...
                'Parent',      PlotHandles.hAxesLegend);
            % Reset current axes
            set(hFig, 'CurrentAxes', hAxes);
            % Overlay legend
            if (length(overlayLabels) > 1)
                TsInfo = getappdata(hFig, 'TsInfo');
                % NIRS: One label per signal type (attach legend to first channel found)
                if (length(F) == 1) && isequal(TsInfo.MontageName, 'NIRS overlay[tmp]')
                    % Legend should be the channel Group
                    hFirstLines = {};
                    iRemove = [];
                    for iGroup = 1:length(overlayLabels)
                        iChanGroup = find(strcmpi(overlayLabels{iGroup}, {Channel(selChan).Group}));
                        if ~isempty(iChanGroup)
                            hFirstLines{end+1} = PlotHandles.hLines{1}(iChanGroup(1));
                        else
                            iRemove(end+1) = iGroup;
                        end
                    end
                    % Remove groups that were not found
                    overlayLabels(iRemove) = [];
                % Otherwise: Represents multiple files (one legend per file)
                else
                    hFirstLines = cellfun(@(c)c(1), PlotHandles.hLines, 'UniformOutput', 0);
                end
                PlotHandles.hOverlayLegend = legend([hFirstLines{:}], strrep(overlayLabels, '_', '-'), ...
                    'Interpreter', 'None', ...
                    'Location',    'NorthEast', ...
                    'Tag',         'LegendOverlay');
            else
                delete(findobj(hFig, '-depth', 1, 'Tag', 'LegendOverlay'));
            end
        end
        % Get data type
        if isappdata(hFig, 'Timefreq') && ~isStatic
            DataType = 'Timefreq';
        else
            DataType = GlobalData.DataSet(iDS).Figure(iFig).Id.Modality;
        end
        % Get data units and time window
        [fScaled, fFactor, fUnits] = bst_getunits( M, DataType );
        fUnits = strrep(fUnits, 'x10^{', 'e');
        fUnits = strrep(fUnits, '10^{', 'e');
        fUnits = strrep(fUnits, '}', '');
        fUnits = strrep(fUnits, '\mu', 'u');
        fUnits = strrep(fUnits, '\Delta', 'd');
        % Handle units for PSD
        if isappdata(hFig, 'Timefreq') && isStatic
            TfInfo = getappdata(hFig, 'Timefreq');
            if isempty(TfInfo.Normalized) && (~isfield(TfInfo, 'FreqUnits') || isempty(TfInfo.FreqUnits))
                switch lower(TfInfo.Function)
                    case 'power',      fUnits = [fUnits '^2/Hz']; fScaled = fScaled * fFactor;
                    case 'magnitude',  fUnits = [fUnits '/sqrt(Hz)'];
                    case 'log',        fUnits = 'dB';
                end
            end
        end
        % Round values if large values
        if (fScaled > 5)
            strAmp = sprintf('%d', round(fScaled));
        else
            fRound = 10^(round(-log10(fScaled)) + 3);
            fScaled = round(fScaled * fRound) / fRound;
            strAmp = sprintf('%g', fScaled);
        end
        % Create legend text
        strLegend = '';
        if offset ~= 0
            % Offset legend
            strLegend = [sprintf('Offset level: %d %s', round(offset), fUnits)];
        end
        % Amplitude legend
        strLegend = [strLegend 10 sprintf('Max amplitude: %s %s', strAmp, fUnits)];
        % Time legend
        if ~isStatic
            msTime = round(TopoLayoutOptions.TimeWindow * 1000);
            strLegend = [strLegend 10 sprintf('Time window: [%d, %d] ms', msTime(1), msTime(2))];
        % Frequency legend
        else
            hzFreq = round(TopoLayoutOptions.FreqWindow * 100) / 100;
            strLegend = [strLegend 10  sprintf('Frequency range: [%s, %s] Hz', num2str(hzFreq(1)), num2str(hzFreq(2)))];
        end
        % Update legend
        set(PlotHandles.hLabelLegend, 'String', strLegend, 'Visible', 'on');
        set(PlotHandles.hOverlayLegend, 'Visible', 'on');
    elseif ~isDrawLegend
        set(PlotHandles.hLabelLegend, 'Visible', 'off');
        set(PlotHandles.hOverlayLegend, 'Visible', 'off');
    end
    
    % ===== AXES LIMITS =====
    % Set axes limits
    set(hAxes, 'XLim', [0 1], 'YLim', [0 1]);
    
    % ===== FIGURE COLORS =====
    % Set figure background
    set(hFig, 'Color', figColor);
    % Set objects lines color (only the non-selected ones, selected channels remain red)
    if ~isempty(PlotHandles.hZeroLines)
        set(PlotHandles.hZeroLines, 'Color', refColor);
        set(PlotHandles.hCursors, 'Color', refColor);
    end
    if ~isempty(PlotHandles.hSensorLabels)
        set(PlotHandles.hSensorLabels, 'Color', textColor);
    end
    if ~isempty(PlotHandles.hLabelLegend)
        set(PlotHandles.hLabelLegend, 'Color', textColor);
    end
    % Save properties
    PlotHandles.Channel  = Channel;
    PlotHandles.Vertices = Vertices;
    PlotHandles.ModChan  = modChan;
    PlotHandles.SelChanGlobal = selChanGlobal;
    GlobalData.DataSet(iDS).Figure(iFig).Handles = PlotHandles;
    
    % Create scale buttons
    if isDrawLegend
        CreateButtons2dLayout(iDS, iFig);
    else    
        hButtons = [findobj(hFig, '-depth', 1, 'Tag', 'ButtonGainPlus'), ...
                    findobj(hFig, '-depth', 1, 'Tag', 'ButtonGainMinus'), ...
                    findobj(hFig, '-depth', 1, 'Tag', 'ButtonSetTimeWindow'), ...
                    findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomTimePlus'), ...
                    findobj(hFig, '-depth', 1, 'Tag', 'ButtonZoomTimeMinus')];
        if ~isempty(hButtons) && TopoLayoutOptions.ShowLegend
            set(hButtons, 'Visible', 'on');
        else
            set(hButtons, 'Visible', 'off');
        end
    end

    % Update selected channels
    figure_3d('UpdateFigSelectedRows', iDS, iFig);
end


%% ===== 2D LAYOUT: GET SEEG/ECOG POSITIONS =====
function [X, Y, LabelRows, LabelRowsRef] = GetSeeg2DPositions(Channel, sElectrodes)
    % Parse channel names
    [AllGroups, AllTags, AllInd, isNoInd] = panel_montage('ParseSensorNames', Channel);
    % Initialize variables
    X = zeros(length(Channel),1);
    Y = zeros(length(Channel),1);
    iRow = 0;
    % Plot all the contacts of each electrode in a row
    for iElec = 1:length(sElectrodes)
        % Get the contacts for this electrode
        iChan = find(strcmpi(sElectrodes(iElec).Name, AllGroups));
        if isempty(iChan)
            continue;
        end
        % Multiple rows
        if (length(sElectrodes(iElec).ContactNumber) >= 2)
            Nrows = sElectrodes(iElec).ContactNumber(1);
            % Continuous numbering of contacts (eg. 1..64)
            if (max(AllInd(iChan)) < prod(sElectrodes(iElec).ContactNumber)) ...
                || any(mod(AllInd(iChan), 10) == 0) ...
                || ((sElectrodes(iElec).ContactNumber(2) < 9) && any(mod(AllInd(iChan), 10) == 9))
                isContinuous = 1;
                Ncols = sElectrodes(iElec).ContactNumber(2);
            % Discontinuous number of contacts (eg. 1..8, 11..18, 21..28, ..., 81..88)
            else
                isContinuous = 0;
                Ncols = 10;
            end
        elseif (length(iChan) > 16)
            Ncols = 10;
            Nrows = ceil(max(AllInd(iChan)) / Ncols);
            isContinuous = 0;
        else
            Nrows = 1;
        end
        if (Nrows > 1)
            for iEcogLine = 1:Nrows
                if isContinuous
                    iChanLine = find((AllInd(iChan) > (iEcogLine - 1) * Ncols) & (AllInd(iChan) <= iEcogLine * Ncols));
                else
                    iChanLine = find((AllInd(iChan) >= (iEcogLine - 1) * Ncols) & (AllInd(iChan) < iEcogLine * Ncols));
                end
                if ~isempty(iChanLine)
                    iRow = iRow + 1;
                    X(iChan(iChanLine)) = repmat(iRow, length(iChanLine), 1);
                    Y(iChan(iChanLine)) = AllInd(iChan(iChanLine)) - (iEcogLine - 1) * Ncols;
                    LabelRows{iRow} = [sElectrodes(iElec).Name, num2str(iEcogLine)];
                    LabelRowsRef(iRow) = iChan(iChanLine(1));
                end
           end
        % Single row
        else
            % Start new row
            iRow = iRow + 1;
            X(iChan) = repmat(iRow, length(iChan), 1);
            Y(iChan) = AllInd(iChan);
            LabelRows{iRow} = sElectrodes(iElec).Name;
            LabelRowsRef(iRow) = iChan(1);
        end
    end
    % Flip both axes
    X = -X;
    Y = -Y;
end

%% ===== 2D LAYOUT: UPDATE =====
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


%% ===== 2D LAYOUT: CREATE BUTTONS =====
function CreateButtons2dLayout(iDS, iFig)
    import org.brainstorm.icon.*;
    global GlobalData;
    % Get figure
    hFig  = GlobalData.DataSet(iDS).Figure(iFig).hFigure;
    % Callbacks to adjsut x axis
    if ~getappdata(hFig, 'isStatic')
        xAxisName   = 'Time';
        xAxisOption = 'TimeWindow';
        UpdateTopoXWindow = @UpdateTopoTimeWindow;
    else
        xAxisName   = 'Frequency';
        xAxisOption = 'FreqWindow';
        UpdateTopoXWindow = @UpdateTopoFreqWindow;
    end
    % Create scale buttons
    h1 = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_SCROLL_UP, ...
        '<HTML><TABLE><TR><TD>Increase gain</TD></TR><TR><TD>Shortcuts:<BR><B> &nbsp; [+]<BR> &nbsp; [SHIFT + Mouse wheel]</B></TD></TR></TABLE>', ...
        @(h,ev)UpdateTimeSeriesFactor(hFig, 1.1), 'ButtonGainPlus');
    h2 = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_SCROLL_DOWN, ...
        '<HTML><TABLE><TR><TD>Decrease gain</TD></TR><TR><TD>Shortcuts:<BR><B> &nbsp; [-]<BR> &nbsp; [SHIFT + Mouse wheel]</B></TD></TR></TABLE>', ...
        @(h,ev)UpdateTimeSeriesFactor(hFig, .9091), 'ButtonGainMinus');
    h3 = bst_javacomponent(hFig, 'button', [], '...', [], ...
        ['Set ' lower(xAxisName) ' window manually'], ...
        @(h,ev)SetTopoLayoutOptions(xAxisOption), 'ButtonSetTimeWindow');
    h4 = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_SCROLL_LEFT, ...
        '<HTML><TABLE><TR><TD>Horizontal zoom out</TD></TR><TR><TD>Shortcuts:<BR><B> &nbsp; [CTRL + Mouse wheel]</B></TD></TR></TABLE>', ...
        @(h,ev)UpdateTopoXWindow(hFig, .9091), 'ButtonZoomTimePlus');
    h5  = bst_javacomponent(hFig, 'button', [], [], IconLoader.ICON_SCROLL_RIGHT, ...
        '<HTML><TABLE><TR><TD>Horizontal zoom in</TD></TR><TR><TD>Shortcuts:<BR><B> &nbsp; [CTRL + Mouse wheel]</B></TD></TR></TABLE>', ...
        @(h,ev)UpdateTopoXWindow(hFig, 1.1), 'ButtonZoomTimeMinus');
    % Visible / not visible
    TopoLayoutOptions = bst_get('TopoLayoutOptions');
    if ~TopoLayoutOptions.ShowLegend
        set([h1 h2 h3 h4 h5], 'Visible', 'off');
    end
end



%% ===== CREATE 3D ELECTRODES =====
function CreateTopo3dElectrodes(iDS, iFig, Channel, ChanLoc, TopoType)
    global GlobalData;
    % Get figure handles
    PlotHandles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Display the electrodes
    [PlotHandles.hSurf, MarkersLocs2D] = figure_3d('PlotSensors3D', iDS, iFig, Channel, ChanLoc, TopoType);
    if strcmpi(TopoType, '2DElectrodes')
        PlotHandles.MarkersLocs = MarkersLocs2D;
    end
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
    hPairs = figure_3d('PlotNirsCap', GlobalData.DataSet(iDS).Figure(iFig).hFigure, 1);
    % Save as a cell array, for compatibility with the newer version of the 2DLayout
    PlotHandles.hLines = {hPairs};
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
function UpdateTimeSeriesFactor(hFig, changeFactor)
    global GlobalData;
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    Handles = GlobalData.DataSet(iDS).Figure(iFig).Handles;
    % Update figure lines
    for iFile = 1:length(Handles.hLines)
        for iLine = 1:length(Handles.hLines{iFile})
            % Get values
            XData = get(Handles.hLines{iFile}(iLine), 'XData');
            % Re-center them on zero, and change the factor
            XData = (XData - Handles.ChannelOffsets(iLine)) * changeFactor + Handles.ChannelOffsets(iLine);
            % Update value
            set(Handles.hLines{iFile}(iLine), 'XData', XData);
        end
    end
    % Update time cursors
    for iLine = 1:length(Handles.hCursors)
        % Get values
        XData = get(Handles.hCursors(iLine), 'XData');
        % Re-center them on zero, and change the factor
        XData = (XData - Handles.ChannelOffsets(iLine)) * changeFactor + Handles.ChannelOffsets(iLine);
        % Update value
        set(Handles.hCursors(iLine), 'XData', XData);
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
function UpdateTopoTimeWindow(hFig, changeFactor)
    global GlobalData;
    % Get current time window
    TopoLayoutOptions = bst_get('TopoLayoutOptions');
    % If the window hasn't been changed yet: use the full time definition
    if isempty(TopoLayoutOptions.TimeWindow)
        TopoLayoutOptions.TimeWindow = GlobalData.UserTimeWindow.Time;
    end
    % Apply zoom factor
    Xlength =  TopoLayoutOptions.TimeWindow(2) - TopoLayoutOptions.TimeWindow(1);
    newTimeWindow = GlobalData.UserTimeWindow.CurrentTime + Xlength/changeFactor/2 * [-1, 1];
    % New time window cannot exceed initial time window
    newTimeWindow = bst_saturate(newTimeWindow, GlobalData.UserTimeWindow.Time, 1);
    % Set new time window
    SetTopoLayoutOptions('TimeWindow', newTimeWindow);
end


%% ===== UPDATE FREQUENCY AXIS FACTOR =====
function UpdateTopoFreqWindow(hFig, changeFactor)
    global GlobalData;
    % Get current time window
    TopoLayoutOptions = bst_get('TopoLayoutOptions');
    tmp = [GlobalData.UserFrequencies.Freqs(1), GlobalData.UserFrequencies.Freqs(end)];
    % If the window hasn't been changed yet: ignore
    if isempty(TopoLayoutOptions.FreqWindow)
        TopoLayoutOptions.FreqWindow = tmp;
    end
    % Apply zoom factor
    Xlength = TopoLayoutOptions.FreqWindow(2) - TopoLayoutOptions.FreqWindow(1);
    newFreqWindow = GlobalData.UserFrequencies.Freqs(GlobalData.UserFrequencies.iCurrentFreq) + Xlength/changeFactor/2 * [-1, 1];
    % New time window cannot exceed initial time window
    newFreqWindow = bst_saturate(newFreqWindow, tmp, 1);
    % Set new time window
    SetTopoLayoutOptions('FreqWindow', newFreqWindow);
end


%% ===== SET 2DLAYOUT OPTIONS =====
function SetTopoLayoutOptions(option, value)
    global GlobalData;
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
                newTimeWindow = panel_time('InputTimeWindow', GlobalData.UserTimeWindow.Time, 'Time window in the 2DLayout view:', TopoLayoutOptions.TimeWindow, 'ms');
                if isempty(newTimeWindow)
                    return;
                end
            end
            % Check time window consistency
            newTimeWindow = bst_saturate(newTimeWindow, GlobalData.UserTimeWindow.Time, 1);
            % Set the current time to the center of this new time window
            panel_time('SetCurrentTime', (newTimeWindow(2) + newTimeWindow(1)) / 2);
            % Save new time window
            TopoLayoutOptions.TimeWindow = newTimeWindow;
            isLayout = 1;
        case 'FreqWindow'
            tmp = [GlobalData.UserFrequencies.Freqs(1), GlobalData.UserFrequencies.Freqs(end)];
            % If frequency window is provided
            if ~isempty(value)
                newFreqWindow = value;
            % Else: Ask user for new frequency window
            else
                newFreqWindow = panel_freq('InputSelectionWindow', tmp, 'Time window in the 2DLayout view:', 'Hz');
                if isempty(newFreqWindow)
                    return;
                end
            end
            % Check frequency window consistency
            newFreqWindow = bst_saturate(newFreqWindow, tmp, 1);
            newFreqPosition = bst_saturate(GlobalData.UserFrequencies.Freqs(GlobalData.UserFrequencies.iCurrentFreq), newFreqWindow);
            panel_freq('SetCurrentFreq', newFreqPosition, 0);
            % Save new frequency window
            TopoLayoutOptions.FreqWindow = newFreqWindow;
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
        case 'FlipYAxis'
            TopoLayoutOptions.FlipYAxis = value;
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
            case {'3DElectrodes', '3DOptodes', '2DElectrodes'}
                markersLocs = markersLocs * 1.02;
        end
        % Time-freq: use all the channels from the TF file
        if ~isempty(TfInfo) && ~isempty(TfInfo.FileName)
            % Get channel names from the TF file
            [iDS, iTimefreq] = bst_memory('GetDataSetTimefreq', TfInfo.FileName);
            RowNames = {GlobalData.DataSet(iDS).Channel(selChan).Name};
            % Get corresponding channel indices
            [Values, iTimeBands, iRow, nComponents] = bst_memory('GetTimefreqValues', iDS, iTimefreq, RowNames);
            % Get positions of the markers only for the selected channels
            clusMarkersLocs = zeros(length(iRow), 3);
            for i = 1:length(iRow)
                iClusChan = find(strcmpi(GlobalData.DataSet(iDS).Timefreq(iTimefreq).RowNames(iRow(i)), RowNames));
                if (length(iClusChan) == 1)
                    clusMarkersLocs(i,:) = markersLocs(iClusChan,:);
                end
            end
            % Replace current selection of channels
            markersLocs = clusMarkersLocs;
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


