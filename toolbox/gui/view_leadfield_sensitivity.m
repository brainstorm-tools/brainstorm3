function hFig = view_leadfield_sensitivity(HeadmodelFile, Modality, DisplayMode)
% VIEW_LEADFIELD_SENTIVITY: Show the leadfield sensitivity on the MRI slices.
% 
% USAGE:  hFig = view_leadfield_sensitivity(HeadmodelFile, Modality, DisplayMode='Mri3D')
%
% INPUTS:
%    - HeadmodelFile : Relative file path to Brainstorm forward model
%    - Modality      : {'MEG', 'EEG', 'ECOG', 'SEEG'}
%    - DisplayMode   : {'Mri3D', 'MriViewer', 'Surface'}

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
% Authors: Francois Tadel, 2022
%          Takfarinas Medani, 2022

% Parse inputs
if (nargin < 3) || isempty(DisplayMode)
    DisplayMode = 'Mri3D';
end
hFig = [];

% ===== LOAD DATA =====
bst_progress('start', 'View leadfields', 'Loading headmodels...');
% Load channel file
[sStudy, iStudy, iHeadModel] = bst_get('HeadModelFile', HeadmodelFile);
ChannelFile = sStudy.Channel.FileName;
ChannelMat = in_bst_channel(sStudy.Channel.FileName, 'Channel');
% Get modality channels
iModChannels = good_channel(ChannelMat.Channel, [], Modality);
if isempty(iModChannels)
    error(['No channels "' Modality '" in channel file: ' ChannelFile]);
end
Channels = ChannelMat.Channel(iModChannels);
markersLocs = cell2mat(cellfun(@(c)c(:,1), {Channels.Loc}, 'UniformOutput', 0))';
isMeg = ismember(Modality, {'MEG', 'MEG MAG', 'MEG GRAD'});
% Load leadfield matrix
HeadmodelMat = in_bst_headmodel(HeadmodelFile);
GainMod = HeadmodelMat.Gain(iModChannels, :);
isVolumeGrid = ismember(HeadmodelMat.HeadModelType, {'volume', 'mixed'});
% Get subject
sSubject = bst_get('Subject', sStudy.BrainStormSubject);
MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
sMri = in_mri_bst(MriFile);

% ===== CREATE FIGURE =====
is3D = 0;
grid2mri_interp = [];
switch (HeadmodelMat.HeadModelType)
    % === VOLUME ===
    case {'volume', 'mixed'}
        % Compute interpolation
        sMri.FileName = MriFile;
        ComputeMriInterp();
        % Create figure
        switch lower(DisplayMode)
            case 'mri3d'
                hFig = view_mri_3d(MriFile, HeadmodelFile, [], 'NewFigure');
                is3D = 1;
            case 'mriviewer'
                hFig = view_mri(MriFile, HeadmodelFile, Modality, 1);
            otherwise
                error(['Unknown display mode: "' DisplayMode '"']);
        end
        % Save update callback (for external calls, e.g. when changing the interpolation properties)
        setappdata(hFig, 'UpdateCallback', @UpdateMriInterp);

    % === SURFACE ===
    case 'surface'
        hFig = view_surface_data(HeadmodelMat.SurfaceFile, HeadmodelFile, Modality, 'NewFigure', 0);
        is3D = 1;
end
if isempty(hFig)
    error('No anatomy could be displayed.');
end

% ===== CONFIGURE FIG ======
% By default: average reference
isAvgRef = 1;
iRef = [];
% By default: the target is the first channel available
iChannel = 1;
% Update figure name
set(hFig, 'Name', ['Leadfield: ' HeadmodelFile]);
% Hack keyboard callback
KeyPressFcn_bak = get(hFig, 'KeyPressFcn');
set(hFig, 'KeyPressFcn', @KeyPress_Callback);
% 3D figure: Add label and display dots
if is3D
    % Set orientation: left
    figure_3d('SetStandardView', hFig, 'left');
    % Get axes handles
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
end
% Create legend
hLabel = uicontrol('Style', 'text', ...
    'String',              '...', ...
    'Units',               'Pixels', ...
    'Position',            [6 0 400 38], ...
    'HorizontalAlignment', 'left', ...
    'FontUnits',           'points', ...
    'FontSize',            bst_get('FigFont'), ...
    'ForegroundColor',     [.3 1 .3], ...
    'BackgroundColor',     [0 0 0], ...
    'Parent',              hFig);
% Update colormap units
ColormapInfo = getappdata(hFig, 'Colormap');
ColormapInfo.DisplayUnits = 'a.u.';
setappdata(hFig, 'Colormap', ColormapInfo);
% Update display
UpdateLeadfield();



%% ==================================================================================================
%  ===== INTERFACE CALLBACKS ========================================================================
%  ==================================================================================================

%% ===== KEYBOARD CALLBACK =====
    function KeyPress_Callback(hFig, keyEvent)
        isUpdate = 0;
        switch (keyEvent.Key)
            % === LEFT, RIGHT, UP, DOWN: CHANGE CHANNEL ===
            case 'leftarrow'
                iChannel = iChannel - 1;
                if ~isempty(iRef) && (iChannel == iRef)
                    iChannel = iChannel - 1;
                end
                if (iChannel < 1)
                    if ~isempty(iRef) && (iRef == length(Channels))
                        iChannel = length(Channels) - 1;
                    else
                        iChannel = length(Channels);
                    end
                end
                isUpdate = 1;
            case 'rightarrow'
                iChannel = iChannel + 1;
                if ~isempty(iRef) && (iChannel == iRef)
                    iChannel = iChannel + 1;
                end
                if (iChannel > length(Channels))
                    if ~isempty(iRef) && (iRef == 1)
                        iChannel = 2;
                    else
                        iChannel = 1;
                    end
                end
                isUpdate = 1;
            case 'downarrow'
                if ~isMeg
                    if isempty(iRef)
                        iRef = length(Channels) + 1;
                    end
                    iRef = iRef - 1;
                    if (iRef == iChannel)
                        iRef = iRef - 1;
                    end
                    if (iRef < 1)
                        iRef = [];
                        isAvgRef = 1;
                    else
                        isAvgRef = 0;
                    end
                    isUpdate = 1;
                end
            case 'uparrow'
                if ~isMeg
                    if isempty(iRef)
                        iRef = 0;
                    end
                    iRef = iRef + 1;
                    if (iRef == iChannel)
                        iRef = iRef + 1;
                    end
                    if (iRef > length(Channels))
                        iRef = [];
                        isAvgRef = 1;
                    else
                        isAvgRef = 0;
                    end
                    isUpdate = 1;
                end               
            case 'r' % not for MEG
                if SelectReference()
                    isUpdate = 1;
                end
            case 't'
                if SelectTarget()
                    isUpdate = 1;
                end
            case 'e'
                if is3D
                    if ~ismember('shift', keyEvent.Modifier)
                        % Plot sensors
                        if ~isempty(findobj(hAxes, 'Tag', 'allChannel'))
                            delete(findobj(hAxes, 'Tag', 'allChannel'))
                        else
                            if length(Channels) > 10
                                hSensors = figure_3d('PlotSensorsNet', hAxes, markersLocs, 0, 0);
                                set(hSensors, 'LineWidth', 1, 'MarkerSize', 5,'Tag','allChannel');
                            end
                        end
                    else
                        % Plot sensors name
                        if ~isempty(findobj(hAxes, 'Tag', 'allChannelName'))
                            delete(findobj(hAxes, 'Tag', 'allChannelName'))
                        else
                            if length(Channels) > 10
                                %hSensors = figure_3d('PlotSensorsNet', hAxes, markersLocs, 0, 0);
                                %set(hSensors,'Tag','allChannelName');
                                channelAllName = cell(length(Channels),1);
                                for iChan = 1 : length(Channels)
                                    channelAllName{iChan} = Channels(iChan).Name;
                                end
                                text(markersLocs(:,1), markersLocs(:,2), markersLocs(:,3),channelAllName,...
                                    'color','y',...
                                    'Parent', hAxes, ...
                                    'Tag', 'allChannelName');
                            end
                        end
                    end
                end
            case 'h'
                if is3D
                    strHelp3D = [...
                        '<TR><TD><B>E</B></TD><TD>Show/hide the sensors</TD></TR>' ...
                        '<TR><TD><B>Shift + E</B></TD><TD>Show/hide the sensors labels</TD></TR>' ...
                        '<TR><TD><B>0 to 9</B></TD><TD>Change view</TD></TR>'];
                else
                    strHelp3D = '';
                end
                java_dialog('msgbox', ['<HTML><TABLE>' ...
                    '<TR><TD><B>Left arrow</B></TD><TD>Previous target channel (red color)</TD></TR>' ...
                    '<TR><TD><B>Right arrow</B></TD><TD>Next target channel (red color)</TD></TR>' ...
                    '<TR><TD><B>Up arrow</B></TD><TD>Previous ref channel (green color)</TD></TR>' ...
                    '<TR><TD><B>Down arrow</B></TD><TD>Next ref channel (green color)</TD></TR>' ...
                    '<TR><TD><B>R</B></TD><TD>Select the <B>R</B>eference channel</TD></TR>' ...
                    '<TR><TD><B>T</B></TD><TD>Select the <B>T</B>arget channel</TD></TR>' ...
                    strHelp3D ...
                    '</TABLE>'], 'Keyboard shortcuts');      
            otherwise
                KeyPressFcn_bak(hFig, keyEvent); 
                return;
        end
        % Recompute leadfields and update figure
        if isUpdate
            UpdateLeadfield();
        end
    end


%% ===== EXTERNAL UPDATE =====
    function UpdateMriInterp()
        ComputeMriInterp();
        UpdateLeadfield();
    end


%% ===== COMPUTE MRI INTERPOLATION =====
    function ComputeMriInterp()
        MriOptions = bst_get('MriOptions');
        GridSmooth = 1;
        grid2mri_interp = grid_interp_mri(HeadmodelMat.GridLoc, sMri, [], 1, MriOptions.InterpDownsample, MriOptions.DistanceThresh, GridSmooth);
    end


%% ===== UPDATE LEADFIELD =====
    function UpdateLeadfield()
        % Compute sensitivity
        bst_progress('start', 'View leadfields', 'Computing sensitivity...');
        if isAvgRef
            LeadField = GainMod(iChannel,:) - mean(GainMod,1);
        elseif ~isempty(iRef)
            LeadField = GainMod(iChannel,:) - GainMod(iRef,:);
        end
        LeadField = reshape(LeadField,3,[])'; % each column is a vector
        normLF = sqrt((LeadField(:,1) ).^2 +(LeadField(:,2) ).^2 + (LeadField(:,3)).^2);
        % Surface or volume
        switch lower(DisplayMode)
            case {'mriviewer', 'mri3d'}
                FigData = tess_interp_mri_data(grid2mri_interp, size(sMri.Cube), normLF, isVolumeGrid);
                OverlayCube = FigData;
            case 'surface'
                FigData = normLF;
                OverlayCube = [];
        end

        % Compute min/max
        minVol = min(FigData(:));
        maxVol = max(FigData(:));
        if (minVol == maxVol)
            error('No data to be displayed.');
        end

        % Get displayed objects description
        TessInfo = getappdata(hFig, 'Surface');
        % Add overlay cube
        TessInfo(1).DataSource.Type      = 'Source';
        TessInfo(1).DataSource.FileName  = HeadmodelFile;
        TessInfo(1).Data                 = FigData;
        TessInfo(1).OverlayCube          = OverlayCube;
        TessInfo(1).OverlayThreshold     = 0;
        TessInfo(1).OverlaySizeThreshold = 1;
        TessInfo(1).DataLimitValue       = [minVol, maxVol];
        TessInfo(1).DataMinMax           = [minVol, maxVol];
        % Update structures
        setappdata(hFig, 'Surface', TessInfo);

        % Update figure
        switch lower(DisplayMode)
            case 'mriviewer'
                figure_mri('UpdateMriDisplay', hFig);
            case {'mri3d', 'surface'}
                panel_surface('UpdateSurfaceColormap', hFig);
        end
        % Update legend
        UpdateLegend();
        if is3D
            UpdateMarkers();
        end
        % Close progress bar
        bst_progress('stop');
    end


%% ===== UPDATE LEGEND =====
    function UpdateLegend()
        if isMeg
            strTitle = sprintf('Target channel #%d/%d : %s (red)', iChannel, length(Channels), Channels(iChannel).Name);
        elseif isAvgRef
            strTitle = sprintf('Target channel #%d/%d : %s (red)  |  Average reference', iChannel, length(Channels), Channels(iChannel).Name);
        else
            strTitle = sprintf('Target channel #%d/%d : %s (red)  |  Reference : %s (green)', iChannel, length(Channels), Channels(iChannel).Name, Channels(iRef).Name);
        end
        if (iChannel == 1) && (length(Channels) > 1)
            strTitle = [strTitle, 10 '[Press arrows for next/previous channel (or H for help)]'];
        end
        set(hLabel, 'String', strTitle);
    end


%% ===== UPDATE CHANNEL MARKES =====
    function UpdateMarkers()
        % Remove previous selected sensor
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'SelChannel'));
        % Plot selected sensor
        line(Channels(iChannel).Loc(1,1), Channels(iChannel).Loc(2,1), Channels(iChannel).Loc(3,1), ...
            'Parent',          hAxes, ...
            'LineWidth',       2, ...
            'LineStyle',       'none', ...
            'Marker',          'o', ...
            'MarkerFaceColor', [1 0 0], ...
            'MarkerEdgeColor', [.4 .4 .4], ...
            'MarkerSize',      8, ...
            'Tag',             'SelChannel');
        % Remove previous selected reference
        delete(findobj(hAxes, '-depth', 1, 'Tag', 'RefChannel'));
        % Plot the reference electrode
        if ~isMeg && ~isAvgRef
            line(Channels(iRef).Loc(1,1), Channels(iRef).Loc(2,1), Channels(iRef).Loc(3,1), ...
                'Parent',          hAxes, ...
                'LineWidth',       2, ...
                'LineStyle',       'none', ...
                'Marker',          '*', ...
                'MarkerFaceColor', [0 1 1], ...
                'MarkerEdgeColor', [.4 .8 .4], ...
                'MarkerSize',      8, ...
                'Tag',             'RefChannel');
        end
    end


%% ===== SELECT REFERENCE =====
    function isOk = SelectReference()
        isOk = 0;
        if ~isMeg
            % Ask for the reference electrode
            refChan = java_dialog('combo', '<HTML>Select the reference channel:<BR><BR>', [Modality ' reference'], [], {'Average Ref', Channels.Name});
            if isempty(refChan)
                return;
            end
            iRefTmp = find(strcmpi({Channels.Name}, refChan));
            if (iRefTmp == iChannel)
                bst_error(['Channel ' refChan ' is currently selected as the target.'], 'Select reference', 0);
                return;
            end
            iRef = iRefTmp;
            if isempty(iRef)
                isAvgRef = 1;
            else
                isAvgRef = 0;
            end
            isOk = 1;
        end
    end

%% ===== SELECT TARGET =====
    function isOk = SelectTarget()
        isOk = 0;
        % Ask for the target electrode
        trgChan = java_dialog('combo', '<HTML>Select the target channel (red color):<BR><BR>', [Modality ' Target'], [], {Channels.Name});
        if isempty(trgChan)
            return;
        end
        iChannelTmp = find(strcmpi({Channels.Name}, trgChan));
        if ~isempty(iRef) && (iChannelTmp == iRef)
            bst_error(['Channel ' trgChan ' is currently selected as the reference.'], 'Select target channel', 0);
            return;
        end
        iChannel = iChannelTmp;
        isOk = 1;
    end

end
