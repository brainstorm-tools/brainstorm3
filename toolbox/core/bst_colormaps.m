function varargout = bst_colormaps( varargin )
% BST_COLORMAPS: Colormaps configuration.
% 
% USAGE:
%  sColormaps = bst_colormaps('Initialize')
%               bst_colormaps('RestoreDefaults')
%   sColormap = bst_colormaps('GetColormap', ColormapType)
%   sColormap = bst_colormaps('GetColormap', hFig)
%               bst_colormaps('SetColormap', ColormapType, sColormap)
%               bst_colormaps('FireColormapChanged')
%               bst_colormaps('CreateColormapMenu',   jMenu,    dataType, DisplayUnits=[])
%               bst_colormaps('ConfigureColorbar',    hFig,     ColormapType, DataType, DisplayUnits=[])
%               bst_colormaps('SetColormapName',      ColormapType, colormapName)
%               bst_colormaps('SetColormapAbsolute',  ColormapType, status)
%               bst_colormaps('SetDisplayColorbar',   ColormapType, status)
%               bst_colormaps('SetMaxMode',           ColormapType, maxmode, DisplayUnits=[])
%               bst_colormaps('SetMaxCustom',         ColormapType, DisplayUnits=[], newmin=[ask], newmax=[ask])
%               bst_colormaps('NewCustomColormap',    ColormapType, Name=[ask], CMap=[ask])
%               bst_colormaps('DeleteCustomColormap', ColormapType)
%               bst_colormaps('SetColorbarVisible',   hFig,     isVisible)
%               bst_colormaps('AddColormapToFigure',  hFig,     ColormapType)
%               bst_colormaps('RemoveColormapFromFigure', hFig, ColormapType)
%
% ==== NOTES ====================================================================
% Brainstorm manages five colormaps, that are saved in the user brainstorm.mat :
%    - 'eeg'     : to display the EEG recordings (default: 'mandrill',  relative)
%    - 'meg'     : to display the MEG recordings (default: 'mandrill',  relative)
%    - 'source'  : to display the sources        (default: 'royal_gramma',  absolute)
%    - 'anatomy' : to display the MRIs           (default: 'bone', absolute, no colorbar)
%    - 'time'    : to display time values        (default: 'viridis',  relative)
%    - 'stat1'   : to display the statistics / 1 input  (default: 'dory', absolute)
%    - 'stat2'   : to display the statistics / 2 inputs (default: 'mandrill', relative)
%    - 'timefreq': time-frequency maps (default: 'magma', absolute, normalized)
%    - 'percent' : percentage values (default: 'dory', absolute)
%    - 'overlay' : plain overlay masks in the MRI Viewer (default: 'overlay', plain yellow)
%    - 'connect1': connectivity values on 2D maps and surfaces (default: 'viridis', absolute)
%    - 'connectn': connectivity graphs (default: 'viridis', absolute)
%    - 'pac'     : PAC measures (default: 'viridis2', absolute)
%    - 'image'   : Indexed images
%    - 'cluster' : Statistic clusters
%
% Each colormap is described by a structure (sColormap):
%    |- Name             : Colormap description
%    |- CMap             : Colormap definition, [nbColors x 3 double]
%    |- DisplayColorbar  : {0,1} - If 1: colorbar is displayed in the visualization figures
%    |- isAbsoluteValues : {0,1} - If 1: use absolute values to display this type of data
%    |- MaxMode          : {'local', 'global', 'custom'}
%    |- MaxValue         : Custom maximum value of the colorbar
%    |- MinValue         : Custom mimum value of the colorbar
%    |- Contrast         : [-1,1] - Contrast for current colormap
%    |- Brightness       : [-1,1] - Brightness for current colormap

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2019
%          Thomas Vincent, 2019

eval(macro_method);
end


%% ====== (Re)INITIALIZATION ======
function sColormaps = Initialize() %#ok<DEFNU>
    % Create colormaps structures
    sColormaps = struct('eeg',      GetDefaults('eeg'), ...
                        'meg',      GetDefaults('meg'), ...
                        'nirs',     GetDefaults('nirs'), ...
                        'source',   GetDefaults('source'), ...
                        'anatomy',  GetDefaults('anatomy'), ...
                        'stat1',    GetDefaults('stat1'), ...
                        'stat2',    GetDefaults('stat2'), ...
                        'time',     GetDefaults('time'), ...
                        'timefreq', GetDefaults('timefreq'), ...
                        'connect1', GetDefaults('connect1'), ...
                        'connectn', GetDefaults('connectn'), ...
                        'pac',      GetDefaults('pac'), ...
                        'image',    GetDefaults('image'), ...
                        'percent',  GetDefaults('percent'), ...
                        'overlay',  GetDefaults('overlay'), ...
                        'cluster',  GetDefaults('cluster'));
end
   

%% ====== GET DEFAULTS ======
function sColormap = GetDefaults(ColormapType)
    % Constants
    DEFAULT_CMAP_SIZE = 256;
    % Initialize colormap structure
    sColormap = db_template('Colormap');
    % Get content
    switch lower(ColormapType)
        % EEG Recordings colormap
        case {'eeg', 'meg','nirs'}
            sColormap.Name             = 'cmap_mandrill';
            sColormap.CMap             = cmap_mandrill(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 0;
            sColormap.MaxMode          = 'local';
        % Sources colormap
        case 'source'
            sColormap.Name             = 'cmap_royal_gramma';
            sColormap.CMap             = cmap_royal_gramma(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 1;
            sColormap.MaxMode          = 'global';
        % Anatomy colormap
        case 'anatomy'
            sColormap.Name             = 'bone';
            sColormap.CMap             = bone(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 1;
            sColormap.MaxMode          = 'local';
        % Stat colormap (1 inputs)
        case 'stat1'
            sColormap.Name             = 'cmap_dory';
            sColormap.CMap             = cmap_dory(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 1;
            sColormap.MaxMode          = 'global';
        % Stat colormap (2 input)
        case 'stat2'
            sColormap.Name             = 'cmap_mandrill';
            sColormap.CMap             = cmap_mandrill(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 0;
            sColormap.MaxMode          = 'local';
            sColormap.UseStatThreshold = 0;
        % Time colormap
        case 'time'
            sColormap.Name             = 'cmap_viridis';
            sColormap.CMap             = cmap_viridis(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 0;
            sColormap.MaxMode          = 'global';
        % Time-frequency maps
        case 'timefreq'
            sColormap.Name             = 'cmap_magma';
            sColormap.CMap             = cmap_magma(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 1;
            sColormap.MaxMode          = 'local';
        % Connectivity links 1xN
        case 'connect1'
            sColormap.Name             = 'cmap_viridis';
            sColormap.CMap             = cmap_viridis(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 1;
            sColormap.MaxMode          = 'local';
        % Connectivity links NxN
        case 'connectn'
            sColormap.Name             = 'cmap_viridis';
            sColormap.CMap             = cmap_viridis(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 1;
            sColormap.MaxMode          = 'local';
        % PAC Measures
        case 'pac'
            sColormap.Name             = 'cmap_viridis2';
            sColormap.CMap             = cmap_viridis2(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 1;
            sColormap.MaxMode          = 'local';
        % Image
        case 'image'
            sColormap.Name             = 'cmap_viridis';
            sColormap.CMap             = cmap_viridis(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 1;
            sColormap.MaxMode          = 'local';
        % Overlay colormap
        case 'overlay'
            sColormap.Name             = 'cmap_overlay';
            sColormap.CMap             = cmap_overlay(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 0;
            sColormap.MaxMode          = 'global';
            sColormap.DisplayColorbar  = 0;
        % Percentage colormap
        case 'percent'
            sColormap.Name             = 'cmap_dory';
            sColormap.CMap             = cmap_dory(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 1;
            sColormap.MaxMode          = 'global';
        % Cluster colormap
        case 'cluster'
            sColormap.Name             = 'cmap_cluster';
            sColormap.CMap             = cmap_cluster(DEFAULT_CMAP_SIZE);
            sColormap.isAbsoluteValues = 0;
            sColormap.MaxMode          = 'global';
            sColormap.isRealMin        = 1;
    end
end


%% ====== RESOTRE DEFAULTS ======
function RestoreDefaults(ColormapType)
    global GlobalData;
    % Reset only target colormap
    GlobalData.Colormaps.(lower(ColormapType)) = GetDefaults(ColormapType);
    % Update colormap in all figures
    FireColormapChanged(ColormapType);
end

%% ====== GET COLORMAP ======
% USAGE:  sCMap = GetColormap()
%         sCMap = GetColormap(ColormapType)
%         sCMap = GetColormap(hFig)
function sCMap = GetColormap(ColormapType)
    global GlobalData;
    if isempty(ColormapType) || isempty(GlobalData) || isempty(GlobalData.Colormaps)
        sCMap = db_template('Colormap');
        return
    end
    % If argument is a figure handle
    if ~ischar(ColormapType)
        ColormapInfo = getappdata(ColormapType, 'Colormap');
        ColormapType = ColormapInfo.Type;
    end
    if isempty(ColormapType)
        sCMap = db_template('Colormap');
        return
    end
    % Get colormaps for a given modality
    ColormapType = lower(ColormapType);
    if ~isfield(GlobalData.Colormaps, ColormapType)
        error('Colormap type does not exist.');
    end
    sCMap = GlobalData.Colormaps.(ColormapType);
end

%% ====== SET COLORMAP ======
% USAGE:  SetColormap(ColormapType, sColormap)
%         SetColormap(hFig,         sColormap)
function SetColormap(ColormapType, sColormap)
    global GlobalData;
    % Get colormap type
    if isempty(ColormapType) || isempty(GlobalData) || isempty(GlobalData.Colormaps)
        return
    end
    % If argument is a figure handle
    if ~ischar(ColormapType)
        ColormapInfo = getappdata(ColormapType, 'Colormap');
        ColormapType = ColormapInfo.Type;
    end
    % Save colormap
    ColormapType = lower(ColormapType);
    if ~isfield(GlobalData.Colormaps, ColormapType)
        error('Colormap type does not exist.');
    end
    GlobalData.Colormaps.(ColormapType) = sColormap;
end


%% ====== COLORMAP CHANGES NOTIFICATION ======
function FireColormapChanged(ColormapType, isAbsoluteChanged)
% disp('=== bst_colormaps > FireColormapChanged ===');
    global GlobalData;
    if (nargin < 1)
        ColormapType = '';
    end
    if (nargin < 2)
        isAbsoluteChanged = 0;
    end
    if isempty(GlobalData)
        return;
    end
    for iDataSet = 1:length(GlobalData.DataSet)
        for iFig = 1:length(GlobalData.DataSet(iDataSet).Figure)
            sFigure = GlobalData.DataSet(iDataSet).Figure(iFig);
            % Get list of data types displayed in this figure
            ColormapInfo = getappdata(sFigure.hFigure, 'Colormap');
            % Only fires for currently visible displayed figures for RIGHT COLORMAP TYPE
            if isempty(ColormapType) || (ismember(lower(ColormapType), ColormapInfo.AllTypes) && strcmpi(get(sFigure.hFigure, 'Visible'), 'on'))
                switch (sFigure.Id.Type)
                    case 'Topography'
                        figure_topo('ColormapChangedCallback', iDataSet, iFig);
                        figure_topo('CurrentTimeChangedCallback', iDataSet, iFig);
                    case '3DViz'
                        if isAbsoluteChanged
                            panel_surface('UpdateSurfaceData', sFigure.hFigure);
                        else
                            figure_3d('ColormapChangedCallback', iDataSet, iFig);
                        end
                    case 'MriViewer'
                        if isAbsoluteChanged
                            panel_surface('UpdateSurfaceData', sFigure.hFigure);
                        else
                            figure_mri('ColormapChangedCallback', iDataSet, iFig);
                        end
                    case 'Timefreq'
                        figure_timefreq('ColormapChangedCallback', sFigure.hFigure);
                    case 'Connect'
                        figure_connect('ColormapChangedCallback', sFigure.hFigure);
                    case 'Pac'
                        figure_pac('ColormapChangedCallback', sFigure.hFigure);
                    case 'Image'
                        figure_image('ColormapChangedCallback', sFigure.hFigure);
                    case 'Video'
                        % Nothing to do
                end
            end
        end 
    end
    % Update permanent menus
    if ~isempty(GlobalData.Program.ColormapPanels)
        % Look for the permanent menu for this colormap
        iWnd = find(strcmpi(ColormapType, {GlobalData.Program.ColormapPanels.ColormapType}));
        if ~isempty(iWnd)
            jPanel = GlobalData.Program.ColormapPanels(iWnd).jPanel;
            % Get window window is visible
            jFrame = jPanel.getTopLevelAncestor();
            % Create colormap menu
            if jFrame.isVisible()
                CreateColormapMenu(jPanel, ColormapType);
                jFrame.pack();
            end
        end
    end
end


%% ====== SET CUSTOM MAX VALUE ======
% USAGE: SetMaxCustom(ColormapType, DisplayUnits=[], newMin=[ask], newMax=[ask])
%        SetMaxCustom(ColormapType, DisplayUnits)
function SetMaxCustom(ColormapType, DisplayUnits, newMin, newMax)
    global GlobalData;
    % Parse inputs
    if (nargin < 2) || isempty(DisplayUnits)
        DisplayUnits = [];
    end
    % Get target colormap
    sColormap = GetColormap(ColormapType);
    % If new value is not provided: detect a good guess, and ask the user to validate
    if (nargin < 3) || isempty(newMax) || isempty(newMin)
        % Get the maximum over the data files loaded
        estimMin = Inf;
        estimMax = -Inf;
        DataType = [];
        % Process all the loaded datasets to find the current maximum value
        for iDS = 1:length(GlobalData.DataSet)
            % Process all the opened figures in each DataSet
            for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
                % Get colormap for this figure
                sFigure = GlobalData.DataSet(iDS).Figure(iFig);
                ColormapInfo = getappdata(sFigure.hFigure, 'Colormap');
                % If colormap not involved in this figure: next figure
                if isempty(ColormapInfo) || isempty(ColormapInfo.Type) || ~strcmpi(ColormapInfo.Type, ColormapType)
                    continue;
                end
                DataFig = 0;
                switch (sFigure.Id.Type)
                    case 'Topography'
                        % Get timefreq display structure
                        TfInfo = getappdata(sFigure.hFigure, 'Timefreq');
                        % If not defined: get data normally
                        if isempty(TfInfo) || isempty(TfInfo.FileName)
                            DataFig = figure_topo('GetFigureData', iDS, iFig, 1);
                            DataType = sFigure.Id.Modality;
                        else
                            % Find timefreq structure
                            iTf = find(file_compare({GlobalData.DataSet(iDS).Timefreq.FileName}, TfInfo.FileName), 1);
                            % Get  values for all time window (only one frequency)
                            DataFig = bst_memory('GetTimefreqMaximum', iDS, iTf, TfInfo.Function);
                            DataType = 'timefreq';
                        end

                    case 'Timefreq'
                        DataFig = GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax;
                        DataType = 'timefreq';

                    case {'3DViz', 'MriViewer'}
                        % Get surfaces defined in this figure
                        TessInfo = getappdata(sFigure.hFigure, 'Surface');
                        DataFig = TessInfo.DataMinMax;
                        if ~isempty(TessInfo.DataSource.Type)
                            DataType = TessInfo.DataSource.Type;
                            isSLORETA = strcmpi(DataType, 'Source') && ~isempty(strfind(lower(TessInfo.DataSource.FileName), 'sloreta'));
                            if isSLORETA 
                                DataType = 'sLORETA';
                            end
                        end
                        
                    case 'Pac'
                        DataFig = GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax;
                        DataType = 'pac';
                        
                    case 'Connect'
                        DataFig = getappdata(sFigure.hFigure, 'DataMinMax');
                        DataType = 'connect';
                        
                    case 'Image'
                        DataFig = GlobalData.DataSet(iDS).Figure(iFig).Handles.DataMinMax;
                        DataType = 'connect';
                        
                end
                % If no data available in the figure
                if isempty(DataFig)
                    continue;
                end
                % Get maximum of the data represented in the figure
                try
                    fMinMax = GetMinMax(sColormap, DataFig);
                    fMin = fMinMax(1);
                    fMax = fMinMax(2);
                catch 
                    % In case there is a Out of Memory error
                    fMin = Inf;
                    fMax = -Inf;
                end
                % Global maximum
                if (fMin < estimMin)
                    estimMin = fMin;
                end
                if (fMax > estimMax)
                    estimMax = fMax;
                end
            end
        end
        % Warning if no data is loaded at all (cannot set the maximum)
        if isequal(estimMax, -Inf) || isequal(estimMin, Inf)
            bst_error('You should load some data before setting the maximum value of the colormap.', 'Set colormap max value', 0);
            return;
        end
        % Get old min and max
        if ~isempty(sColormap.MinValue)
            oldMin = sColormap.MinValue;
        else
            oldMin = estimMin;
        end
        if ~isempty(sColormap.MaxValue)
            oldMax = sColormap.MaxValue;
        else
            oldMax = estimMax;
        end
        % Get the maximum value units
        amplitudeMax = max(abs([estimMin estimMax]));
        % If the units are percents: force to factor=1
        if isinf(amplitudeMax)
            fFactor = 1;
            fUnits = 'Inf';
        elseif isequal(DisplayUnits, '%')
            fFactor = 1;
            fUnits = DisplayUnits;
        else
            % Guess the display units
            [tmp, fFactor, fUnits ] = bst_getunits(amplitudeMax, DataType);
            % For readability: replace '\sigma' with 'no units'
            fUnits = strrep(fUnits, '\sigma', 'no units');
            fUnits = strrep(fUnits, '{', '');
            fUnits = strrep(fUnits, '}', '');
        end
        % Format estimated value correctly
        if isinf(amplitudeMax)
            strPrecision = '%g';
        elseif (amplitudeMax * fFactor > 0.01) && (amplitudeMax * fFactor < 1e6)
            strPrecision = '%4.3f';
        else
            strPrecision = '%e';
        end
        strOldMin = sprintf(strPrecision, oldMin * fFactor);
        strOldMax = sprintf(strPrecision, oldMax * fFactor);
        % Ask the new colormap max value
        res = java_dialog('input', {[sprintf('<HTML>Enter amplitude range for "%s" data (%s).<BR><BR>', ColormapType, fUnits), ...
                                     sprintf(['Minimum: &nbsp;&nbsp;&nbsp;&nbsp;[Default=' strPrecision ']'], estimMin*fFactor)], ...
                                     sprintf(['Maximum:     [Default=' strPrecision ']'], estimMax*fFactor)}, ...
                                    ['Colormap limits: ' ColormapType], [], ...
                                    {strOldMin, strOldMax});
        if isempty(res)
            return
        end
        % If user did not change the min: use previous min
        if strcmpi(res{1}, strOldMin)
            newMin = oldMin;
        else
            newMin = str2num(res{1}) ./ fFactor;
        end
        % If user did not change the max: use previous max        
        if strcmpi(res{2}, strOldMax)
            newMax = oldMax;
        else
            newMax = str2num(res{2}) ./ fFactor;
        end
        % Check for invalid values
        if isempty(newMax) || isempty(newMin) || (newMin >= newMax)
            disp('BST> Set colorbar custom maximum: Invalid values.');
            return
        end
    end
    % Update colormap
    sColormap.MaxMode  = 'custom';
    sColormap.MinValue = newMin;
    sColormap.MaxValue = newMax;
    SetColormap(ColormapType, sColormap);
    % Update all figures
    FireColormapChanged(ColormapType);
end


%% ===== GET MIN/MAX VALUES =====
% USAGE:  fMinMax = GetMinMax(ColormapType, Data, DataMinMax=[])
%         fMinMax = GetMinMax(sColormap, Data, DataMinMax=[])
function fMinMax = GetMinMax(ColormapType, Data, DataMinMax)
    % Get target colormap
    if isstruct(ColormapType)
        sColormap = ColormapType;
    else
        sColormap = GetColormap(ColormapType);
    end
    % No data minmax
    if (nargin < 3) || isempty(DataMinMax)
        DataMinMax = [];
        sColormap.MaxMode = 'local';
    end
    % Fix cases where Data is empty
    if isempty(Data) && ~isempty(DataMinMax)
        Data = DataMinMax;
    end
    % Method depends on the colormap configuration
    switch lower(sColormap.MaxMode)
        case 'custom'
            fMinMax = [sColormap.MinValue, sColormap.MaxValue];
        case 'local'
            % Real min: search min and max
            if sColormap.isRealMin
                if sColormap.isAbsoluteValues
                    fMin = min(abs(Data(:)));
                    fMax = max(abs(Data(:)));
                else
                    fMin = min(Data(:));
                    fMax = max(Data(:));
                end
            % Not real min: Search max in absolute value
            else
                fMax = max(abs(Data(:)));
                if sColormap.isAbsoluteValues
                    fMin = 0;
                else
                    fMin = -fMax;
                end
            end
            fMinMax = [fMin, fMax];
        case 'global'
            DataAmp = max(abs(DataMinMax));
            % Case of real minimum + absolute value: we don't have the real minimum value => Setting to zero
            if sColormap.isRealMin 
                if sColormap.isAbsoluteValues
                    fMinMax = [max(0, DataMinMax(1)), DataAmp];
                else
                    fMinMax = DataMinMax;
                end
            else
                if sColormap.isAbsoluteValues
                    fMinMax = [0, DataAmp];
                else
                    fMinMax = [-DataAmp, DataAmp];
                end
            end
    end
    % Ensure the output is a double
    fMinMax = double(full(fMinMax));
end


%% ============================================================================
%  ====== COLORMAP MENUS CALLBACKS ============================================
%  ============================================================================
%% ====== CREATE COLORMAP MENU ======
% USAGE: CreateColormapMenu(jMenu, ColormapType, DisplayUnits=[])
function CreateColormapMenu(jMenu, ColormapType, DisplayUnits)
    import javax.swing.*;
    import java.awt.*;
    import org.brainstorm.icon.*;
    
    % Parse inputs
    if (nargin < 3) || isempty(DisplayUnits)
        DisplayUnits = [];
    end
    % Permanent figure or popup
    isPermanent = isa(jMenu, 'javax.swing.JPanel');
    % Remove all previous menus
    jMenu.removeAll();
    % Get colormap definition
    sColormap = GetColormap(ColormapType);
    if isempty(sColormap)
        return
    end

    % Parent
    if isPermanent
        % Left panel
        jMenuL = gui_river([0 0], [0 0 0 0], 'Colormap');
        jMenu.add(jMenuL, BorderLayout.WEST);
        jMenuLeft = java_create('javax.swing.JPanel');
        jMenuLeft.setLayout(BoxLayout(jMenuLeft, BoxLayout.PAGE_AXIS));
        jMenuL.add(jMenuLeft);
        % Right panel
        jMenuR = gui_river([0 0], [0 0 0 0], 'Properties');
        jMenu.add(jMenuR, BorderLayout.EAST);
        jMenuRight = java_create('javax.swing.JPanel');
        jMenuRight.setLayout(BoxLayout(jMenuRight, BoxLayout.PAGE_AXIS));
        jMenuR.add(jMenuRight);
        % Output at the beginning: Left
        jMenuColormap = jMenuLeft;
        jMenuSeq = jMenuColormap;
        jMenuDiv = jMenuColormap;
        jMenuRainbow = jMenuColormap;
    else
        jMenuColormap = gui_component('Menu', jMenu, [], 'Colormap');
        jMenuSeq = gui_component('Menu', jMenuColormap, [], 'Sequential');
        jMenuDiv = gui_component('Menu', jMenuColormap, [], 'Diverging');
        jMenuRainbow = gui_component('Menu', jMenuColormap, [], 'Rainbow');
    end
    
    % Colormap list: Standard
    cmapList_seq = {'hot', 'cmap_hot2', 'bone', 'gray', 'pink', 'copper', 'cmap_nih_fire', 'cmap_ge', 'cmap_tpac', 'cool', 'cmap_parula', 'cmap_magma', 'cmap_royal_gramma','cmap_viridis2','cmap_viridis','cmap_dory'};
    iconList_seq = [IconLoader.ICON_COLORMAP_HOT, IconLoader.ICON_COLORMAP_HOT2, IconLoader.ICON_COLORMAP_BONE, IconLoader.ICON_COLORMAP_GREY, IconLoader.ICON_COLORMAP_PINK,   ...
                    IconLoader.ICON_COLORMAP_COPPER, IconLoader.ICON_COLORMAP_NIHFIRE, IconLoader.ICON_COLORMAP_GE,  IconLoader.ICON_COLORMAP_TPAC,  IconLoader.ICON_COLORMAP_COOL, ...
                    IconLoader.ICON_COLORMAP_PARULA, IconLoader.ICON_COLORMAP_MAGMA, IconLoader.ICON_COLORMAP_ROYAL_GRAMMA, IconLoader.ICON_COLORMAP_VIRIDIS2, IconLoader.ICON_COLORMAP_VIRIDIS, IconLoader.ICON_COLORMAP_DORY];
    for i = 1:length(cmapList_seq)
        % If the colormap #i is currently used for this surface : check the menu
        isSelected = strcmpi(cmapList_seq{i}, sColormap.Name);
        % Create menu item
        cmapDispName = strrep(cmapList_seq{i}, 'cmap_', '');
        jItem = gui_component('CheckBoxMenuItem', jMenuSeq, [], cmapDispName, iconList_seq(i), [], @(h,ev)SetColormapName(ColormapType, cmapList_seq{i}));
        jItem.setSelected(isSelected);
    end

    cmapList_div = {'cmap_rbw', 'cmap_gin', 'cmap_ovun', 'cmap_cluster', 'cmap_mandrill','cmap_ns_green', 'cmap_ns_white', 'cmap_ns_grey'};
    iconList_div = [IconLoader.ICON_COLORMAP_RBW,   IconLoader.ICON_COLORMAP_GIN, IconLoader.ICON_COLORMAP_OVUN, IconLoader.ICON_COLORMAP_CLUSTER, ...
                    IconLoader.ICON_COLORMAP_MANDRILL,IconLoader.ICON_COLORMAP_NEUROSPEED, IconLoader.ICON_COLORMAP_NEUROSPEED, IconLoader.ICON_COLORMAP_NEUROSPEED];
    for i = 1:length(cmapList_div)
        % If the colormap #i is currently used for this surface : check the menu
        isSelected = strcmpi(cmapList_div{i}, sColormap.Name);
        % Create menu item
        cmapDispName = strrep(cmapList_div{i}, 'cmap_', '');
        jItem = gui_component('CheckBoxMenuItem', jMenuDiv, [], cmapDispName, iconList_div(i), [], @(h,ev)SetColormapName(ColormapType, cmapList_div{i}));
        jItem.setSelected(isSelected);
    end

    cmapList_rainbow = {'cmap_nih', 'jet', 'cmap_jetinv', 'hsv', 'cmap_rainramp', 'cmap_spectrum', 'cmap_atlas', 'cmap_turbo'};
    iconList_rainbow = [IconLoader.ICON_COLORMAP_NIH, IconLoader.ICON_COLORMAP_JET, IconLoader.ICON_COLORMAP_JETINV, IconLoader.ICON_COLORMAP_HSV, ...
                        IconLoader.ICON_COLORMAP_RAINRAMP, IconLoader.ICON_COLORMAP_SPECTRUM, IconLoader.ICON_COLORMAP_ATLAS, IconLoader.ICON_COLORMAP_TURBO];
    for i = 1:length(cmapList_rainbow)
        % If the colormap #i is currently used for this surface : check the menu
        isSelected = strcmpi(cmapList_rainbow{i}, sColormap.Name);
        % Create menu item
        cmapDispName = strrep(cmapList_rainbow{i}, 'cmap_', '');
        jItem = gui_component('CheckBoxMenuItem', jMenuRainbow, [], cmapDispName, iconList_rainbow(i), [], @(h,ev)SetColormapName(ColormapType, cmapList_rainbow{i}));
        jItem.setSelected(isSelected);
    end

    % Colormap list: Custom
    CustomColormaps = bst_get('CustomColormaps');
    if ~isempty(CustomColormaps)
        CreateSeparator(jMenuColormap, isPermanent);
    end
    isCustom = 0;
    for i = 1:length(CustomColormaps)
        % If the colormap #i is currently used for this surface : check the menu
        isSelected = strcmpi(CustomColormaps(i).Name, sColormap.Name);
        if isSelected
            isCustom = 1;
        end
        % Create menu item
        cmapDispName = strrep(CustomColormaps(i).Name, 'custom_', '');
        jItem = gui_component('CheckBoxMenuItem', jMenuColormap, [], cmapDispName, IconLoader.ICON_COLORMAP_CUSTOM, [], @(h,ev)SetColormapName(ColormapType, CustomColormaps(i).Name));
        jItem.setSelected(isSelected);
    end
    % Colormap list: Add new colormap
    CreateSeparator(jMenuColormap, isPermanent);
    gui_component('MenuItem', jMenuColormap, [], 'New...', IconLoader.ICON_COLORMAP_CUSTOM, [], @(h,ev)NewCustomColormap(ColormapType));
    gui_component('MenuItem', jMenuColormap, [], 'Load...', IconLoader.ICON_COLORMAP_CUSTOM, [], @(h,ev)LoadColormap(ColormapType));
    % Colormap list: Delete selected colormap
    jMenuDelete = gui_component('MenuItem', jMenuColormap, [], 'Delete', IconLoader.ICON_COLORMAP_CUSTOM, [], @(h,ev)DeleteCustomColormap(ColormapType));
    if ~isCustom
        jMenuDelete.setEnabled(0);
    end
    
    if ~isPermanent
        CreateSeparator(jMenu, isPermanent);
    else
        jMenu = jMenuRight;
    end

    % Not for anatomy or time colormap
    if ~strcmpi(ColormapType, 'Anatomy') && ~strcmpi(ColormapType, 'Time') && ~strcmpi(ColormapType, 'Overlay')
        % Options : Absolute values
        jCheckAbs = gui_component('CheckBoxMenuItem', jMenu, [], 'Absolute values', [], [], @(h,ev)SetColormapAbsolute(ColormapType, ev.getSource.isSelected()));
        jCheckAbs.setSelected(sColormap.isAbsoluteValues);
        
        % Options : use statistics threshold(s)
        if strcmpi(ColormapType, 'stat2')
            jCheckStatThresh = gui_component('CheckBoxMenuItem', jMenu, [], 'Use stat threshold', [], [], @(h,ev)SetUseStatThreshold(ColormapType, ev.getSource.isSelected()));
            jCheckStatThresh.setSelected(sColormap.UseStatThreshold);
        end
        
        CreateSeparator(jMenu, isPermanent);
        % Options : Maximum
        jRadioGlobal = gui_component('RadioMenuItem', jMenu, [], 'Maximum: Global',    [], [], @(h,ev)SetMaxMode(ColormapType, 'global', DisplayUnits));
        jRadioLocal  = gui_component('RadioMenuItem', jMenu, [], 'Maximum: Local',     [], [], @(h,ev)SetMaxMode(ColormapType, 'local', DisplayUnits));
        jRadioCustom = gui_component('RadioMenuItem', jMenu, [], 'Maximum: Custom...', [], [], @(h,ev)SetMaxMode(ColormapType, 'custom', DisplayUnits));
        switch lower(sColormap.MaxMode)
            case 'local',  jRadioLocal.setSelected(1);
            case 'global', jRadioGlobal.setSelected(1);
            case 'custom', jRadioCustom.setSelected(1);
        end
        jButtonGroup = ButtonGroup();
        jButtonGroup.add(jRadioLocal);
        jButtonGroup.add(jRadioGlobal);
        jButtonGroup.add(jRadioCustom);
        CreateSeparator(jMenu, isPermanent);
        % Options : Range
        if sColormap.isAbsoluteValues
            strRange = 'Range: [0,max]';
        else
            strRange = 'Range: [-max,max]';
        end
        jRadio1 = gui_component('RadioMenuItem', jMenu, [], strRange, [], [], @(h,ev)SetColormapRealMin(ColormapType, 0));
        jRadio1.setSelected(~sColormap.isRealMin);
        jRadio2 = gui_component('RadioMenuItem', jMenu, [], 'Range: [min,max]', [], [], @(h,ev)SetColormapRealMin(ColormapType, 1));
        jRadio2.setSelected(sColormap.isRealMin);
        jButtonGroup = ButtonGroup();
        jButtonGroup.add(jRadio1);
        jButtonGroup.add(jRadio2);
        CreateSeparator(jMenu, isPermanent);
        % If custom: min definition is not very useful
        if strcmpi(sColormap.MaxMode, 'custom')
            jRadio1.setForeground(Color(.5,.5,.5));
            jRadio2.setForeground(Color(.5,.5,.5));
        end
    end
    
    % ===== CONTRAST / BRIGHTNESS PANEL =====
    strTooltip = ['<HTML><BLOCKQUOTE><B>Contrast and brightness</B>: <BR><BR>' ...
      'These values can be directly modified from any figure<BR>' ...
      'by clicking on the colorbar and moving the mouse.<BR><BR>' ...
      '- Horizontal moves : increase/decrease contrast<BR>' ...
      '- Vertical moves : increase/decrease brightness<BR>' ...
      '</BLOCKQUOTE></HTML>' ];
    % == CONTRAST ==
    % Create base menu entry
    jPanel = gui_component('Panel');
    jPanel.setOpaque(0);
    jPanel.setBorder(BorderFactory.createEmptyBorder(0,30,0,0));
    jMenu.add(jPanel);
    % Title
    jLabel = gui_component('label', [], '', 'Contrast:  ');
    jPanel.add(jLabel, BorderLayout.CENTER);
    % Spin button
    val = round(sColormap.Contrast * 100);
    spinmodel = SpinnerNumberModel(val, -100, 100, 2);
    jSpinner = JSpinner(spinmodel);
    jSpinner.setPreferredSize(Dimension(55,23));
    jSpinner.setToolTipText(strTooltip);
    java_setcb(spinmodel, 'StateChangedCallback', @(h,ev)SpinnerCallback(ev, ColormapType, 'Contrast'));
    jPanel.add(jSpinner, BorderLayout.EAST);

    % == BRIGHTNESS ==
    % Create base menu entry
    jPanel = gui_component('Panel');
    jPanel.setOpaque(0);
    jPanel.setBorder(BorderFactory.createEmptyBorder(0,30,0,0));
    jMenu.add(jPanel);
    % Title
    jLabel = gui_component('label', [], '', 'Brightness:  ');
    jPanel.add(jLabel, BorderLayout.WEST);
    % Spin button
    val = -round(sColormap.Brightness * 100);
    spinmodel = SpinnerNumberModel(val, -100, 100, 2);
    jSpinner = JSpinner(spinmodel);
    jSpinner.setPreferredSize(Dimension(55,23));
    jSpinner.setToolTipText(strTooltip);
    java_setcb(spinmodel, 'StateChangedCallback', @(h,ev)SpinnerCallback(ev, ColormapType, 'Brightness'));
    jPanel.add(jSpinner, BorderLayout.EAST);

    % Display/hide colorbar
    CreateSeparator(jMenu, isPermanent);
    jCheckDisp = gui_component('CheckBoxMenuItem', jMenu, [], 'Display colorbar', [], [], @(h,ev)SetDisplayColorbar(ColormapType, ev.getSource.isSelected()));
    jCheckDisp.setSelected(sColormap.DisplayColorbar);
    

    
    % Open menu in a new window
    if ~isPermanent
        gui_component('MenuItem', jMenu, [], 'Permanent menu', [], [], @(h,ev)CreatePermanentMenu(ColormapType));
    end
    CreateSeparator(jMenu, isPermanent);
    % Display/hide colorbar
    gui_component('MenuItem', jMenu, [], 'Restore defaults', [], [], @(h,ev)RestoreDefaults(ColormapType));
    
    drawnow;
    if ~isPermanent
        jMenu.getParent().pack();
    end
    jMenu.getParent().invalidate();
    jMenu.getParent().repaint();
end


%% ====== MENU FUNCTIONS =====
function CreateSeparator(jMenu, isPermanent)
    if ~isPermanent
        jMenu.addSeparator();
    else
        jLabel = javax.swing.JLabel('  ');
        jMenu.add(jLabel);
    end
end

%% ====== CREATE ALL COLORMAP MENUS =====
function CreateAllMenus(jMenu, hFig, isDynamic) %#ok<DEFNU>
    import org.brainstorm.icon.*;
    % Parse inputs
    if (nargin < 2)
        hFig = [];
    end
    if (nargin < 3) || isempty(isDynamic)
        isDynamic = 0;
    end
    % Get the colormaps available for the figure
    AllTypes = {};
    DisplayUnits = [];
    if ~isempty(hFig)
        ColormapInfo = getappdata(hFig, 'Colormap');
        if ~isempty(ColormapInfo) && ~isempty(ColormapInfo.AllTypes)
            AllTypes = ColormapInfo.AllTypes;
            DisplayUnits = ColormapInfo.DisplayUnits;
        end
    end
    % If for the popup menu figure: add "Colormap: " to the menu name
    if ~isempty(hFig)
        spre  = 'Colormap: ';
    else
        spre  = '';
    end
    % Create all menus
    if isempty(hFig) || ismember('anatomy', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'Anatomy'], IconLoader.ICON_COLORMAP_ANATOMY);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'anatomy', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'anatomy', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('eeg', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'EEG Recordings'], IconLoader.ICON_COLORMAP_RECORDINGS);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'eeg', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'eeg', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('meg', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'MEG Recordings'], IconLoader.ICON_COLORMAP_RECORDINGS);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'meg', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'meg', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('nirs', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'NIRS Recordings'], IconLoader.ICON_COLORMAP_RECORDINGS);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'nirs', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'nirs', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('source', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'Sources'], IconLoader.ICON_COLORMAP_SOURCES);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'source', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'source', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('stat1', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'Stat 1'], IconLoader.ICON_COLORMAP_STAT);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'stat1', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'stat1', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('stat2', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'Stat 2'], IconLoader.ICON_COLORMAP_STAT);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'stat2', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'stat2', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('time', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'Time'], IconLoader.ICON_COLORMAP_TIME);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'time', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'time', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('timefreq', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'Timefreq'], IconLoader.ICON_COLORMAP_TIMEFREQ);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'timefreq', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'timefreq', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('connect1', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'Connect 1xN'], IconLoader.ICON_COLORMAP_CONNECT);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'connect1', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'connect1', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('connectn', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'Connect NxN'], IconLoader.ICON_COLORMAP_CONNECT);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'connectn', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'connectn', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('pac', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'PAC'], IconLoader.ICON_COLORMAP_PAC);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'pac', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'pac', DisplayUnits);
        end
    end
    if isempty(hFig) || ismember('image', AllTypes)
        jMenuColormap = gui_component('Menu', jMenu, [], [spre 'Image'], IconLoader.ICON_COLORMAP_TIMEFREQ);
        if isDynamic
            java_setcb(jMenuColormap, 'MenuSelectedCallback', @(h,ev)CreateColormapMenu(ev.getSource(), 'image', DisplayUnits));
        else
            CreateColormapMenu(jMenuColormap, 'image', DisplayUnits);
        end
    end
end

%% ===== CREATE PRESISTENT MENU =====
function CreatePermanentMenu(ColormapType)
    import java.awt.BorderLayout;
    global GlobalData;
    
    % Look for already registered window
    if ~isempty(GlobalData.Program.ColormapPanels)
        iWnd = find(strcmpi(ColormapType, {GlobalData.Program.ColormapPanels.ColormapType}));
    else
        iWnd = [];
    end
    % Create new window
    if isempty(iWnd)
        iWnd = length(GlobalData.Program.ColormapPanels) + 1;
        % Create dialog window
        jBstFrame = bst_get('BstFrame');
        figTitle = ['Colormap: ' ColormapType];
        jFrame = java_create('javax.swing.JDialog', 'Ljava.awt.Frame;Ljava.lang.String;Z', jBstFrame, figTitle, 0);
        jFrame.setDefaultCloseOperation(jFrame.HIDE_ON_CLOSE);
        jPanel = jFrame.getContentPane();
        jPanel.setLayout(BorderLayout());
        % Register window
        GlobalData.Program.ColormapPanels(iWnd).jPanel = jPanel;
        GlobalData.Program.ColormapPanels(iWnd).ColormapType = ColormapType;
    % Show previous window
    else
        jPanel = GlobalData.Program.ColormapPanels(iWnd).jPanel;
        jFrame = jPanel.getTopLevelAncestor();
    end
    
    % Create colormap menu
    CreateColormapMenu(jPanel, ColormapType);
    % Show figure
    jFrame.pack();
    jFrame.setLocationRelativeTo(jFrame.getParent());
    jFrame.setVisible(1);
    jFrame.show();
end


%% ====== COLORMAP SELECTION ======
function SetColormapName(ColormapType, colormapName)
    % The purpose of this function changed: return error if it is used the old way
    if isempty(colormapName)
        error('Not supported anymore. Use NewCustomColormap() instead.');
    end
    % Get colormap description
    sColormap = GetColormap(ColormapType);
    sColormap.Name = colormapName;
    % Get the selected colormap
    if isempty(strfind(colormapName, 'custom_'))
        DEFAULT_CMAP_SIZE = 256;
        sColormap.CMap = eval(sprintf('%s(%d)', colormapName, DEFAULT_CMAP_SIZE));
    % Get a custom colormap
    else
        % Get all the custom colormaps
        CustomColormaps = bst_get('CustomColormaps');
        % Find colormap name
        iColormap = find(strcmpi(colormapName, {CustomColormaps.Name}));
        if isempty(iColormap)
            error(['Custom colormap "' colormapName '" does not exist.']);
        end
        % Use the custom colormap
        sColormap.CMap = CustomColormaps(iColormap).CMap;
    end
    % Reset Contrast/Brightness values
    sColormap.Contrast   = 0;
    sColormap.Brightness = 0;
    % Update colormap description
    SetColormap(ColormapType, sColormap);   
    % Fire change notificiation to all figures (3DViz and Topography)
    FireColormapChanged(ColormapType);
end


%% ===== NEW CUSTOM COLORMAP =====
% USAGE:  NewCustomColormap(ColormapType, Name=[ask], CMap=[ask])
%         NewCustomColormap(ColormapType, Name=[ask], nColors=[ask])
function isModified = NewCustomColormap(ColormapType, Name, CMap)
    % Parse inputs
    if (nargin < 3) || isempty(CMap)
        CMap = [];
    end
    if (nargin < 2) || isempty(Name)
        Name = [];
    end
    isModified = 0;
    % Get colormap description
    sColormap = GetColormap(ColormapType);
    % Get existing custom colormaps
    CustomColormaps = bst_get('CustomColormaps');
    % Ask for colormap name
    if isempty(Name) || isempty(CMap)
        res = java_dialog('input', {'Colormap name: ', 'Number of colors [integer]:'}, 'New colormap', [], {'custom', num2str(size(sColormap.CMap,1))});
        % If user cancelled: return
        if isempty(res)
            return
        end
        % Get new values
        Name = lower(res{1});
        nColors = str2num(res{2});
        % If invalid values: error
        if isempty(Name) || (nColors < 1)
            bst_error('Invalid values.', 'New colormap', 0);
        end
        % Build full colormap name
        Name = ['custom_' Name];
        isConfirm = 1;
    % Passing only the number of colors
    elseif (length(CMap) == 1)
        nColors = CMap;
        CMap = [];
        isConfirm = 0;
    else
        isConfirm = 0;
    end
    % Check if colormap name already exists
    if ~isempty(CustomColormaps) 
        % Find colormap name
        iColormap = find(strcmpi(Name, {CustomColormaps.Name}));
        % Colormap exists: asks for overwriting confirmation
        if ~isempty(iColormap)
            if isConfirm && ~java_dialog('confirm', ['Overwrite existing colormap "' strrep(Name,'custom_','') '"?'], 'New colormap')
                return;
            end
        % Else: new entry
        else
            iColormap = length(CustomColormaps) + 1;
        end
    else
        iColormap = 1;
    end
    % Set the colors
    if isempty(CMap)
        % Hide all the figures in workspace
        hFigAll = findobj(0, 'Type', 'Figure');
        isVisible = get(hFigAll, 'Visible');
        set(hFigAll, 'Visible', 'off');
        if ~iscell(isVisible)
            isVisible = {isVisible};
        end
        % Adapts number of colors
        CMap = ResizeColormap(sColormap.CMap, nColors);
        % Create a hidden figure to store colormap result
        hTmp = figure('Visible',  'on', ...
                      'Position', [-100 -100 1 1], ...
                      'Colormap', CMap);
        drawnow;
        % Display colormap editor
        colormapeditor(hTmp);
        % Hide base figure
        set(hTmp, 'Visible', 'off');
        % Get Colormap figure handle
        cme = getappdata(0, 'CMEditor');
        % Wait for the end of the Colormap Editor execution
        while ~isempty(cme.getFrame())
            pause(0.3);
        end
        CMap = get(hTmp, 'Colormap');
        % Close editor figure
        close(hTmp);
        % Restore the "visible" status of all the existing figures
        for i = 1:length(hFigAll)
            set(hFigAll(i), 'Visible', isVisible{i});
        end
    end
    % New custom colormaps
    CustomColormaps(iColormap).Name = Name;
    CustomColormaps(iColormap).CMap = CMap;
    % Update custom colormaps list
    bst_set('CustomColormaps', CustomColormaps);
    % Update colormap selection
    SetColormapName(ColormapType, Name);
    isModified = 1;
end



%% ===== LOAD COLORMAP =====
% USAGE:  LoadColormap(ColormapType, FileName)
function isModified = LoadColormap(ColormapType, FileName)
    % Parse inputs
    if (nargin < 2) || isempty(FileName)
        FileName = [];
    end
    isModified = 0;
    % Get existing custom colormaps
    CustomColormaps = bst_get('CustomColormaps');
    
    % Ask for filename
    if isempty(FileName)
        % Get default import directory and formats
        LastUsedDirs = bst_get('LastUsedDirs');
        % Get LUT files
        FileName = java_getfile( 'open', ...
           'Import colormap...', ...      % Window title
           LastUsedDirs.ImportAnat, ...   % Default directory
           'single', 'files', ...         % Selection mode
           {{'.lut'}, 'Color lookup table (*.lut)', 'LUT'}, 'LUT');
        % If no file was selected: exit
        if isempty(FileName)
            return
        end
        % Save default import directory
        LastUsedDirs.ImportAnat = bst_fileparts(FileName);
        bst_set('LastUsedDirs', LastUsedDirs);
        isConfirm = 1;
    else
        isConfirm = 0;
    end
    
    % Open file
	fid = fopen(FileName, 'rb');
    if (fid < 0)
        error(['Cannot open LUT file:' FileName]);
    end
    % Read file
    CMap = fread(fid, Inf, 'uint8');
    if (length(CMap) < 6)
        error('Not a valid LUT file.');
    end
    % Close file 
    fclose(fid);
    % Convert to Matlab format: [Ncolor x 3], values between 0 and 1
    CMap = reshape(CMap ./ 255, [], 3);

    % Read as a fixed list of colors
    if isConfirm
        if java_dialog('confirm', 'Does this file represent the colors of a labelled atlas?', 'Load colormap')
            strType = 'atlas_';
        else
            strType = '';
        end
    else
        strType = 'atlas_';
    end
    
    % Colormap name: file name
    [fPath, fBase, fExt] = bst_fileparts(FileName);
    % Build full colormap name
    Name = ['custom_' strType fBase];
    % Check if colormap name already exists
    if ~isempty(CustomColormaps) 
        % Find colormap name
        iColormap = find(strcmpi(Name, {CustomColormaps.Name}));
        % Colormap exists: asks for overwriting confirmation
        if ~isempty(iColormap)
            if isConfirm && ~java_dialog('confirm', ['Overwrite existing colormap "' strrep(Name,'custom_','') '"?'], 'New colormap')
                return;
            end
        % Else: new entry
        else
            iColormap = length(CustomColormaps) + 1;
        end
    else
        iColormap = 1;
    end
    % New custom colormaps
    CustomColormaps(iColormap).Name = Name;
    CustomColormaps(iColormap).CMap = CMap;
    % Update custom colormaps list
    bst_set('CustomColormaps', CustomColormaps);
    % Update colormap selection
    SetColormapName(ColormapType, Name);
    isModified = 1;
end


%% ===== DELETE CUSTOM COLORMAP =====
% USAGE:  DeleteCustomColormap(ColormapType)
function DeleteCustomColormap(ColormapType)
    % Get colormap description
    sColormap = GetColormap(ColormapType);
    % Get existing custom colormaps
    CustomColormaps = bst_get('CustomColormaps');
    % Check that there is something to do
    if isempty(CustomColormaps) || isempty(strfind(sColormap.Name, 'custom_'))
        return;
    end
    % Find colormap name
    iColormap = find(strcmpi(sColormap.Name, {CustomColormaps.Name}));
    if isempty(iColormap)
        return;
    end
    % Ask for confirmation
    if ~java_dialog('confirm', ['Delete colormap "' strrep(sColormap.Name,'custom_','') '"?'], 'Delete colormap')
        return;
    end
    % Delete custom colormap entry
    CustomColormaps(iColormap) = [];
    % Update custom colormaps list
    bst_set('CustomColormaps', CustomColormaps);
    % Update colormap selection
    RestoreDefaults(ColormapType);
end


%% ====== CHECKBOXES CALLBACKS ======
function SetColormapAbsolute(ColormapType, status)
    % If trying to uncheck 'Absolute values' for the Sources colormap: display a warning
    if (strcmpi(ColormapType, 'Source') && (status == 0))
        isConfirmed = java_dialog('confirm', ['Please keep this option selected, unless you know exactly what you are doing.' 10 10 ...
                                              'Are you sure you want to display relative values for source activations ?'], 'Colormaps');
        if ~isConfirmed
            return;
        end
    end
    % Update colormap
    sColormap = GetColormap(ColormapType);
    sColormap.isAbsoluteValues = status;
    SetColormap(ColormapType, sColormap);
    % Fire change notificiation to all figures (3DViz and Topography)
    isAbsoluteChanged = 1;
    FireColormapChanged(ColormapType, isAbsoluteChanged);
    % Mutually exclusive with UseStatThreshold
    if status && sColormap.UseStatThreshold
        SetUseStatThreshold(ColormapType, 0);
    end
end
function SetColormapRealMin(ColormapType, status)
    sColormap = GetColormap(ColormapType);
    sColormap.isRealMin = status;
    SetColormap(ColormapType, sColormap);
    % Fire change notificiation to all figures (3DViz and Topography)
    FireColormapChanged(ColormapType);
end
function SetMaxMode(ColormapType, maxmode, DisplayUnits)
    % Parse inputs
    if (nargin < 3) || isempty(DisplayUnits)
        DisplayUnits = [];
    end
    % Check values
    if ~ismember(lower(maxmode), {'local','global','custom'})
        error(['Invalid maximum mode: "' maxmode '"']);
    end
    % Custom: ask for custom values
    if strcmpi(maxmode, 'custom')
        SetMaxCustom(ColormapType, DisplayUnits);
    else
        % Update colormap
        sColormap = GetColormap(ColormapType);
        sColormap.MaxMode = lower(maxmode);
        SetColormap(ColormapType, sColormap);
        % Fire change notificiation to all figures (3DViz and Topography)
        FireColormapChanged(ColormapType);
    end
end
function SetDisplayColorbar(ColormapType, status)
    sColormap = GetColormap(ColormapType);
    sColormap.DisplayColorbar = status;
    SetColormap(ColormapType, sColormap);
    % Fire change notificiation to all figures (3DViz and Topography)
    FireColormapChanged(ColormapType);
end
function SetUseStatThreshold(ColormapType, status)
    sColormap = GetColormap(ColormapType);
    sColormap.UseStatThreshold = status;
    SetColormap(ColormapType, sColormap);
    % Fire change notificiation to all figures (3DViz and Topography)
    FireColormapChanged(ColormapType);
    % Mutually exclusive with Absolute
    if status && sColormap.isAbsoluteValues
        SetColormapAbsolute(ColormapType, 0);
    end
end

%% ====== SLIDERS CALLBACKS ======
function SpinnerCallback(ev, ColormapType, Modifier)
    % Get colormap
    sColormap = GetColormap(ColormapType);
    % Update Modifier value
    newValue = double(ev.getSource().getValue()) / 100;
    % Brightness : inverted
    if strcmpi(Modifier, 'Brightness')
        newValue = - newValue;
    end
    sColormap.(Modifier) = newValue;
    % Apply modifiers
    sColormap = ApplyColormapModifiers(sColormap);
    % Save colormap
    SetColormap(ColormapType, sColormap);
    % Notify all figures
    FireColormapChanged(ColormapType);
end


%% ====== CONFIGURE COLORBAR ======
% Update the display of the colorbar in the given figure
function ConfigureColorbar(hFig, ColormapType, DataType, DisplayUnits) %#ok<DEFNU>
    global GlobalData;
    % No default units
    if (nargin < 4) || isempty(DisplayUnits)
        DisplayUnits = [];
    end
    % Get colorbar and axes handles
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    hAxes     = setdiff(findobj(hFig, '-depth', 1, 'Type', 'axes'), hColorbar);
    hConnect  = getappdata(hFig, 'OpenGLDisplay');
    % If a colorbar is defined
    if ~isempty(hColorbar)
        fFactor = [];
        % === GET COLOR BOUNDS ===
        if ~isempty(hAxes)
            if strcmpi(ColormapType, 'time')
                [tmp__, iFig, iDS] = bst_figures('GetFigure', hFig);
                % Get time bounds
                if ~isempty(GlobalData.DataSet(iDS).Dipoles) && ~isempty(GlobalData.DataSet(iDS).Dipoles(1).Time)
                    dataBounds = GlobalData.DataSet(iDS).Dipoles(1).Time;
                else
                    dataBounds = GlobalData.DataSet(iDS).Measures.Time;
                end
                if (max(abs(dataBounds)) > 2)
                    fFactor = 1;
                    fUnits = 's';
                else
                    dataBounds = dataBounds * 1000;
                    fFactor = 1;
                    fUnits = 'ms';
                end
                % Set color limits to time values
                set(hAxes(1), 'CLim', dataBounds);
                %setappdata(hFig, 'tUnits', fUnits);
            % Percentage
            elseif strcmpi(ColormapType, 'percent')
                dataBounds = [0 100];
                set(hAxes(1), 'CLim', dataBounds);
                fFactor = 1;
                fUnits = '%';
            % Stat:  get min/max from the figure
            elseif strcmpi(ColormapType, 'stat1') || strcmpi(ColormapType, 'stat2')
                % Get minimum and maximum values in the figure color data
                dataBounds = get(hAxes(1), 'CLim');
                DataType = 'stat';
            else
                % Get minimum and maximum values in the figure color data
                dataBounds = get(hAxes(1), 'CLim');
            end
        elseif ~isempty(hConnect)
            % Get minimum and maximum values in the figure color data
            dataBounds = getappdata(hFig, 'CLim');
        else
            return; 
        end
        % Get units if not defined by the type of data
        if isempty(fFactor)
            % Use imposed units 
            if ~isempty(DisplayUnits)
                switch(DisplayUnits)
                    case 't',    fFactor = 1;
                    case 'mol.l-1', fFactor = 1;
                    case 'mmol.l-1', fFactor = 1e3;
                    case 'umol.l-1', fFactor = 1e6;
                    case 'U.A.'
                        fmax = max(abs(dataBounds));
                        if fmax < 1e3
                            fFactor=1e6;
                            DisplayUnits='U.A(*10^6)';
                        elseif fmax < 1
                            fFactor=1e3;
                            DisplayUnits='U.A(*10^3)';
                        else
                            fFactor=1;
                        end
                    otherwise,   fFactor = 1;
                end
                fUnits = DisplayUnits;
            % Get data units from file maximum
            else
                fmax = max(abs(dataBounds));
                [fScaled, fFactor, fUnits] = bst_getunits( fmax, DataType );
            end
        end
        
        % === DEFINE TICKS ===
        YLim = get(hColorbar, 'YLim');
        % Guess the most reasonable ticks spacing
        [YTickNorm, YTickLabel] = GetTicks(dataBounds, YLim, fFactor);
        % Invalid scale
        if isempty(YTickLabel)
            fUnits = 'Invalid scale';
        end
        % Update ticks of the colorbar
        set(hColorbar, 'YTick',      YTickNorm, ...
                       'YTickLabel', YTickLabel);
        xlabel(hColorbar, fUnits);
    end    
end


%% ====== GET TICKS ======
% Guess the most reasonable ticks spacing
function [TickNorm, TickLabel] = GetTicks(dataBounds, axesLim, fFactor)
    % Try to find an easy to read scale for this data
    possibleTickSpaces = reshape([1; 2; 5] * [0.0001 0.001 0.01, 0.1, 1, 10, 100, 1000, 10000, 100000], 1, []);
    possibleNbTicks = (dataBounds(2) - dataBounds(1)) .* fFactor ./ possibleTickSpaces ;
    iTicks = find((possibleNbTicks >= 3) & (possibleNbTicks <= 500));
    % If at least one scale is found
    if ~isempty(iTicks)
        % Take the one with the smallest number of ticks
        tickSpace = possibleTickSpaces(iTicks(end));
        Tick = unique([bst_flip(0:-tickSpace/fFactor:dataBounds(1), 2), 0, 0:tickSpace/fFactor:dataBounds(2)]);
        TickLabel = fFactor * Tick;
        % Normalized Ticks
        TickNorm = (Tick-dataBounds(1)) / (dataBounds(2)-dataBounds(1)) * (axesLim(2)-axesLim(1)) + axesLim(1);
        % If displaying integer values (%d)
        if (round(tickSpace) == tickSpace)
            TickLabel = num2str(round(TickLabel)', '%d');
        % Else : display fractional values
        else
            nbDecimal = 1;
            while (tickSpace < power(10, -nbDecimal))
                nbDecimal = nbDecimal + 1;
            end
            TickLabel = num2str(TickLabel', sprintf('%%0.%df', nbDecimal));
        end
    % Cannot find a valid number of ticks : do not display ticks
    else
        TickNorm  = 0;
        TickLabel = [];
    end
end


%% ====== SET COLORBAR VISIBLE ======
function SetColorbarVisible(hFig, isVisible) %#ok<DEFNU>
    % Get colorbar and axes handles
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    hAxes     = setdiff(findobj(hFig, '-depth', 1, 'Type', 'axes'), hColorbar);
    % If colorbar is requested but does not exist : create it
    if isVisible && isempty(hColorbar)
        % Get figure type
        FigureId = getappdata(hFig, 'FigureId');
        % Get color for colorbar text
        switch (FigureId.Type)
            case {'3DViz', 'Topography', 'MriViewer', 'Connect'}
                textColor = [.8 .8 .8];
            case {'Timefreq', 'Pac', 'Image'}
                textColor = [0 0 0];
        end
        % Display colorbar
        drawnow

        % ===== USING HOMEMADE COLORBAR =====
        % To avoid buggy behaviour of OpenGL rendering for colormaps
        hColorbar = axes('Parent', hFig, ...
                         'tag',    'Colorbar', ...
                         'XLim',   [0,1], ...
                         'YLim',   [0,256], ...
                         'YTick',  [], ...
                         'XTick',  [], ...
                         'XTickLabel', []);
        hold(hColorbar, 'on');
        % Set color to figure colormap
        [X,Y,Z] = meshgrid(0:1, 0:256, 1);
        hImage = surf('Parent', hColorbar, ...
                      'XData',  X, ...
                      'YData',  Y, ...
                      'ZData',  Z, ...
                      'CData',  (1:256)', ...
                      ...'CDataMapping', 'Direct', ...
                      'EdgeColor', 'none', ...
                      'Tag',    'ColorbarSurf', ...
                      'ButtonDownFcn', @(h,ev)ColorbarButtonDown_Callback(hColorbar,ev));
        % ===== END SECTION =====
        
        set(hColorbar, 'TickLength',    [0 0], ...
                       'FontUnits',     'points', ...
                       'FontSize',      bst_get('FigFont'), ...
                       'YAxisLocation', 'right', ...
                       'XColor',        textColor, ...
                       'YColor',        textColor, ...
                       'Box',           'off', ...
                       'ButtonDownFcn', @(h,ev)ColorbarButtonDown_Callback(hColorbar,ev));
        % Execute Resize routine in order to set location and size of the colorbar
        ResizeCallback = get(hFig, bst_get('ResizeFunction'));
        ResizeCallback(hFig, []);
    % If color bar is not requested but exist : remove it
    elseif ~isVisible && ~isempty(hColorbar)
        delete(hColorbar);
        % Execute Resize routine in order to reset axes position
        ResizeCallback = get(hFig, bst_get('ResizeFunction'));
        ResizeCallback(hFig, []);
    end
    % Set back the main axes as the Current axes in figure
    if ~isempty(hAxes)
        set(hFig, 'CurrentAxes', hAxes(1));
    end
end


%% ====== COLORBAR CLICK CALLBACK ======
function ColorbarButtonDown_Callback(hColorbar,ev)
    % Get adjacent 3DAxes handle
    hFig  = get(hColorbar, 'Parent');
    hAxes = setdiff(findobj(hFig, '-depth', 1, 'Type', 'axes'), hColorbar);
    % Reset current axes
    if ~isempty(hAxes)
        set(hFig, 'CurrentAxes', hAxes(1));
    end
    % Double click: reset colormap           
    if strcmpi(get(hFig, 'SelectionType'), 'open')
        ColormapInfo = getappdata(hFig, 'Colormap');
        if ~isempty(ColormapInfo)
            SetColormap(ColormapInfo.Type, GetDefaults(ColormapInfo.Type));
            FireColormapChanged(ColormapInfo.Type);
        end
        return
    end
    % Button clicked ?
    switch (get(hFig, 'SelectionType'))
        case 'normal'
            % LEFT CLICK: Prepare for colorbar modification
            setappdata(hFig, 'clickAction', 'colorbar');
        case 'alt'
            % RIGHT CLICK: popup
            setappdata(hFig, 'clickAction', 'popup');
    end
end



%% ============================================================================
%  ====== CONTRAST/BRIGHTNESS =================================================
%  ============================================================================
%% ====== RESIZE COLORMAP ======
% Change le colormap number of samples
function resizedCMap = ResizeColormap(initCMap, N)
    if (size(initCMap,1) == N)
        resizedCMap = initCMap;
    else
        % Get X vectors of the 2 colormaps
        xInit    = linspace(0, 1, size(initCMap,1));
        xResized = linspace(0, 1, N);
        % Interpolate separately the 3 components R,G,B
        resizedCMap = interp1(xInit, initCMap, xResized);
        % Remove extreme values
        resizedCMap = bst_saturate(resizedCMap, [0 1]);
    end
end


%% ===== CHANGE COLORMAP MODIFIERS =====
% USAGE:  ColormapChangeModifiers(ColormapType, ChangeValues)
%         ColormapChangeModifiers(ColormapType, ChangeValues, isUpdateAll)
%
% INPUT:  
%      - ColormapType : {'data', 'source', 'anatomy', 'stat1', 'stat2', ...}
%      - ChangeValues : [changeContrast, changeBrightness]
%      - isUpdateAll  : {0,1} If 1, apply he modifications in all the figures
%                             Else, only update the current colorbar
%
function sColormap = ColormapChangeModifiers(ColormapType, ChangeValues, isUpdateAll) %#ok<DEFNU>
    % Parse inputs
    if (nargin < 3)
        isUpdateAll = 1;
    end
    % Get colormap
    sColormap = GetColormap(ColormapType);
    if isempty(sColormap)
        return
    end
    % Skip the custom colormaps
    if ~isempty(strfind(sColormap.Name, 'custom_'))
        return;
    end
    % Update Contrast value
    sColormap.Contrast   = bst_saturate(sColormap.Contrast   + ChangeValues(1), [-1 1]);
    sColormap.Brightness = bst_saturate(sColormap.Brightness + ChangeValues(2), [-1 1]);
    % Apply modifiers
    sColormap = ApplyColormapModifiers(sColormap);
    % Save colormap
    SetColormap(ColormapType, sColormap);
    % Notify all figures
    if isUpdateAll
        FireColormapChanged(ColormapType);
    end
end


%% ===== APPLY COLORMAP MODIFIERS =====
function sColormap = ApplyColormapModifiers(sColormap)
    DEFAULT_CMAP_SIZE = 256;
    % Cannot modify "Custom" colormaps
    if ~isempty(sColormap.Name)
        sColormap.CMap = eval(sprintf('%s(%d)', sColormap.Name, DEFAULT_CMAP_SIZE));
        mapSize = size(sColormap.CMap, 1);
        
        % === APPLY CONTRAST ===
        if (sColormap.Contrast ~= 0)
            % Concentrate
            if (sColormap.Contrast > 0)
                % Add values at top and at bottom of the colormap to "Concentrate" the colors
                totalSize = round(mapSize * (10 * sColormap.Contrast + 1));
                padSize = [ceil((totalSize - mapSize) / 2), floor((totalSize - mapSize) / 2)];
                sColormap.CMap = [repmat(sColormap.CMap(1,:), [padSize(1), 1]);
                                  sColormap.CMap;
                                  repmat(sColormap.CMap(end,:), [padSize(2), 1])];
            % Spread
            else
                % Keep only a part of the initial colormap to "spread" the central colors
                totalSize = round(mapSize - (mapSize - 3) * abs(sColormap.Contrast));
                if (totalSize ~= mapSize)
                    iStartColor = round((mapSize - totalSize) / 2);
                    sColormap.CMap = sColormap.CMap(iStartColor:iStartColor+totalSize, :);
                end
            end
            % Make sure that colormap size is constant
            if (size(sColormap.CMap, 1) ~= mapSize)
                sColormap.CMap = ResizeColormap(sColormap.CMap, mapSize);
            end
        end
        
        % === APPLY BRIGHTNESS ===
        % Moves "center" of colormap (middle colours) up or down in colormap
        if (sColormap.Brightness ~= 0)
            newCMap = zeros(mapSize,3);
            % Get middle indice of the colormap (for both initial and modified colormaps)
            iMiddleInit  = floor(mapSize / 2);
            iMiddleFinal = bst_saturate(round((sColormap.Brightness + 1) * iMiddleInit), [1,mapSize-1]);
            % Interpolate new values
            newCMap(1:iMiddleFinal,:)     = ResizeColormap(sColormap.CMap(1:iMiddleInit,:),     iMiddleFinal);
            newCMap(iMiddleFinal+1:end,:) = ResizeColormap(sColormap.CMap(iMiddleInit+1:end,:), mapSize-iMiddleFinal);
            % Update new colormap
            sColormap.CMap = newCMap;
        end
    end
end


%% ===== ADD COLORMAP TO FIGURE =====
function AddColormapToFigure(hFig, ColormapType, DisplayUnits) %#ok<DEFNU>
    % No default units
    if (nargin < 3) || isempty(DisplayUnits)
        DisplayUnits = [];
    end
    % Get existing list
    ColormapInfo = getappdata(hFig, 'Colormap');
    % Add new colormap to list
    ColormapInfo.AllTypes{end+1} = ColormapType;
    ColormapInfo.AllTypes        = unique(ColormapInfo.AllTypes);
    % Set default
    if isempty(ColormapInfo.Type) || ~strcmpi(ColormapType, 'Anatomy')
        ColormapInfo.Type = ColormapType;
    end
    % Set units
    ColormapInfo.DisplayUnits = DisplayUnits;
    % Update figure app data
    setappdata(hFig, 'Colormap', ColormapInfo);
end

%% ===== REMOVE COLORMAP FROM FIGURE =====
function RemoveColormapFromFigure(hFig, ColormapType) %#ok<DEFNU>
    % Get existing list
    ColormapInfo = getappdata(hFig, 'Colormap');
    % Add new colormap to list and set to default
    ColormapInfo.AllTypes = setdiff(ColormapInfo.AllTypes, ColormapType);
    if strcmpi(ColormapInfo.Type, ColormapType)
        if ~isempty(ColormapInfo.AllTypes)
            ColormapInfo.Type = ColormapInfo.AllTypes{end};
        else
            ColormapInfo.Type = '';
        end
    end
    % Update figure app data
    setappdata(hFig, 'Colormap', ColormapInfo);
end


%% ===== THRESHOLD COLORMAP =====
function cmapThreshed = StatThreshold(cMap, vMin, vMax, isAbs, tUnder, tOver, nsColor) %#ok<DEFNU>
    % Apply double thresholding to given cmap so that the color of values between
    % given thresholds is set to the color of the null value. 
    % Original color dynamics is tranfered to significant values.
    if vMin > vMax
        error('Bad value range: vMin > vMax');
    end
    if isempty(tUnder) && isempty(tOver)
        error('Both thresholds are undefined');
    end
    if tUnder == tOver % no thresholding -> nothing to do
        cmapThreshed = cMap;
        return;
    end
    if isempty(tUnder) % one-sided+
       tUnder = vMin; 
    end
    if isempty(tOver) % one-sided-
       tOver = vMax; 
    end
    if tUnder > tOver
        error('Bad thresholds: tUnder > tOver');
    end

    if isAbs
        % In case abs wasn't already applied to limits
        if vMin < 0 && vMax <= 0
            vMin = abs(vMax);
            vMax = abs(vMin);
        elseif vMin < 0 && vMax >= 0
            vMin = 0;
            vMax = max(abs(vMin), vMax);
        end
        % In case thresholds are not symetrical
        if tUnder < 0 && tOver <= 0
            tUnder = abs(tOver);
            tOver = abs(tUnder);
        elseif tUnder <  0 && tOver >= 0
            tOver = min(abs(tUnder), tOver); 
            tUnder = vMin;
        end
    end

    nc = length(cMap);
    % Convert value to color index, with clipping
    v2ci = @(v) max(1, min(round((nc-1)/(vMax-vMin) * (v-vMin) + 1), nc ));

    if nargin < 6
        nsColor = cMap(v2ci(0), :); % Take color of value=zero for non-significant
    end
    assert(all(size(nsColor) == [1, 3]));
    cmapThreshed = zeros(size(cMap));

    % Set non-significant range
    nsIndexes = v2ci(tUnder):v2ci(tOver);
    cmapThreshed(nsIndexes, :) = repmat(nsColor, length(nsIndexes), 1);

    % Compress initial color dynamics into significant range
    ci0 = v2ci(0);
    if tOver < vMax
        sigOverIndexes = v2ci(tOver):nc;
        posIndexes = (ci0+1):nc;
        targetOver = round(linspace(posIndexes(1), posIndexes(end), length(sigOverIndexes)));
        cmapThreshed(sigOverIndexes, :) = interp1(posIndexes,cMap(posIndexes,:), targetOver);
    end
    if tUnder > vMin
        sigUnderIndexes = 1:v2ci(tUnder);
        negIndexes = 1:(ci0-1);
        targetUnder = round(linspace(negIndexes(1), negIndexes(end), length(sigUnderIndexes)));
        cmapThreshed(sigUnderIndexes, :) = interp1(negIndexes,cMap(negIndexes, :), targetUnder);
    end
end


