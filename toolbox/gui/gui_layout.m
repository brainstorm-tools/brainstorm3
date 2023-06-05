function varargout = gui_layout(varargin)
% GUI_LAYOUT: Automated management of the visualization figures (size and position).
%
% USAGE: gui_layout('Update')                   : Apply current layout
%        gui_layout('GetDecorationSize',jFrame) : Get figure decorations
%        gui_layout('GetScreenClientArea')      : Get the screen areas that are used by Brainstorm
%        gui_layout('GetScreenBrainstormAreas') : Get figure area(s)
%        gui_layout('GetFigureGroups')          : Get all the registered Brainstorm figures, grouped by dataset
%        gui_layout('TileWindows', UseWeights)  : Use 'TileWindows' window layout
%        gui_layout('PositionFigure', hFigure, figArea, decorationSize)
%        gui_layout('ShowAllWindows')           : Show all figures

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
% Authors: Francois Tadel, 2008-2019

eval(macro_method);
end


%% ===== UPDATE LAYOUT =====
function Update() %#ok<DEFNU>
    % Cancel call in headless mode
    if (bst_get('GuiLevel') == -1)
        return;
    end
    % Call the appropriate function
    switch bst_get('Layout', 'WindowManager')
        case 'WeightWindows'
            % Call the tile windows layout
            TileWindows(1);
        case 'TileWindows'
            % Call the tile windows layout WITHOUT WEIGHTS CORRECTION
            TileWindows(0);
        case 'FullArea'
            [jArea, figArea] = GetScreenBrainstormAreas();
            FixedSizeWindows(figArea);
        otherwise
            % Nothing to do
    end
end


%% ===== GET DECORATION SIZE =====
% Get decorations size for a window: [left, top, right, bottom, menubarHeight, toolbarHeight]
function decorationSize = GetDecorationSize(jBstWindow)
    % Do not try to get it when running in server or nogui mode
    if (bst_get('GuiLevel') <= 0)
        decorationSize = [0 0 0 0 0 0];
        return;
    end
    % Get brainstorm window if needed
    if (nargin < 1) || isempty(jBstWindow)
        jBstWindow = bst_get('BstFrame');
    end
    % Get decorations size (left, top, right, bottom, menubarHeight, toolbarHeight) for a window
    decorationSize = [...
        jBstWindow.getRootPane.getBounds.getX(), ...
        jBstWindow.getRootPane.getBounds.getY(), ...
        jBstWindow.getBounds.getWidth() - jBstWindow.getRootPane.getBounds.getWidth() - jBstWindow.getRootPane.getBounds.getX(), ...
        jBstWindow.getBounds.getHeight() - jBstWindow.getRootPane.getBounds.getHeight() - jBstWindow.getRootPane.getBounds.getY(), ...
        20, ...% jBstWindow.getJMenuBar.getSize.getHeight(), ...
        28]; % TOOLBAR HEIGHT
    % For windows 10 and macos, remove the borders of the figures (they are transparent)
    if ispc && ~isempty(strfind(system_dependent('getos'), '10'))
        decorationSize(1) = 0;
        decorationSize(2) = 31;
        decorationSize(3) = 2;
        decorationSize(4) = 1;
    end
end


%% ===== GET MAXIMUM WINDOW =====
% Size and position of the rectangle usable by client applications on each screen.
%    - jMaxWindow : Position as seen by Java/Swing (real number of pixels on the screen)
%    - MaxWindow  : Position as seen by Matlab (scaled if there is a scale factor applied on high-DPI screens)
%
% Possible ways to get these information:
%    tk = java.awt.Toolkit.getDefaultToolkit();
%    ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
%
%    1) get(0,'ScreenSize')
%       tk.getScreenSize()
%       ge.getDefaultScreenDevice().getDefaultConfiguration().getBounds()
%        - WINDOWS: current screen size (including toolbars...)
%        - LINUX  : total screen size (all the screens together, including toolbars...)
%
%    2) get(0,'MonitorPositions')
%     ** - WINDOWS: one entry per screen (including toolbars...)
%        - LINUX  : identical to get(0,'ScreenSize')
%    
%    4) ge.getMaximumWindowBounds()
%     ** - WINDOWS: current screen size (EXCLUDING toolbars...)
%        - LINUX  : identical to get(0,'ScreenSize')
%        - MACOS  : Available area (corrects for position of dock and top menu)
%
%    6) ge.getScreenDevices()[].getDefaultConfiguration().getBounds()
%     ** - WINDOWS: size of each screen
%        - LINUX  : identical to get(0,'ScreenSize')
%
%    7) jFrame.setExtendedState(JFrame.MAXIMIZED_BOTH)
%        - WINDOWS: works well
%        - LINUX  : does not work on simple terminals (but works on CentOS/KDE workstations)
%
%    8) java.awt.Toolkit.getDefaultToolkit().getScreenInsets(jScreens(2).getDefaultConfiguration())
%        => Works for each screen separately
% function [jMaxWindow, MaxWindow, ZoomFactor] = GetMaximumWindow()
%     % Get graphic environment
%     ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
%     % Get the default size
%     jMaxWindow = ge.getMaximumWindowBounds();
%     MaxWindow = [jMaxWindow.getX(), jMaxWindow.getY(), jMaxWindow.getWidth(), jMaxWindow.getHeight()];
%     % Try to get better for X11 systems
%     try
%         % Check if X11 classes exists
%         isX11 = strcmpi(class(ge), 'sun.awt.X11GraphicsEnvironment');
%         % In case of X11: rebuild information
%         if isX11
%             % Run xprop to get information about the desktop
%             panelWorkaround = java.lang.ProcessBuilder({'xprop', '-root', '-notype', '_NET_WORKAREA'});
%             proc = panelWorkaround.start();
%             % Get the result
%             br = java.io.BufferedReader(java.io.InputStreamReader(proc.getInputStream()));
%             res = br.readLine();
%             % Split to get the values
%             xprop = res.split('=');
%             xprop = str2num(char(xprop(2)));
%             % Read values
%             MaxWindow = xprop(1:4);
%         end
%     catch
%         % Nothing to do, just keep the regular values
%     end
%     % Return values in a Rectangle object
%     jMaxWindow = java.awt.Rectangle(MaxWindow(1), MaxWindow(2), MaxWindow(3), MaxWindow(4));
%     % Adjust with the OS scaling factor (for high-DPI screens)
%     javaScreenSize   = ge.getDefaultScreenDevice().getDisplayMode();
%     matlabScreenSize = get(0, 'ScreenSize');
%     ZoomFactor = double(javaScreenSize.getWidth()) ./ double(matlabScreenSize(3));
%     ZoomFactor = round(ZoomFactor * 100) / 100;
%     % For Matlab R2015b and above: the maximum window is not scaled coordinates, need to fix this
%     if (ZoomFactor >= 1.05) && (bst_get('MatlabVersion') >= 806) 
%         MaxWindow = floor(MaxWindow ./ ZoomFactor);
%     end
% end


%% ===== GET CLIENT SCREEN SIZE =====
% Process information from GetMaximumWindow
function ScreenDef = GetScreenClientArea()
    % If running in headless mode, return a fake configuration
    if (bst_get('GuiLevel') == -1)
        ScreenDef.screenInsets = java.awt.Insets(0,0,0,0);
        ScreenDef.javaPos      = java.awt.Rectangle(1,1,1024,768);
        ScreenDef.matlabPos    = [0 0 1024 768];
        ScreenDef.zoomFactor   = 1;
        return;
    end
    % Get Java GraphicsEnvironment
    ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
    tk = java.awt.Toolkit.getDefaultToolkit();
    % Get list of screens
    jScreens = ge.getScreenDevices();
    % Matlab monitor positions
    MonitorPositions = get(0, 'MonitorPositions');
    isOldPositions = (bst_get('MatlabVersion') < 804);
    % Fix discrepancies (reported in: https://neuroimage.usc.edu/forums/t/using-brainstorm-on-two-screens-under-linux/28418)
    if length(jScreens) > size(MonitorPositions,1)
        jScreens = jScreens(1:size(MonitorPositions,1));
    end
    % Find default screen
    % iDefaultScreen = ge.getDefaultScreenDevice().getScreen() + 1;   %%% CRASHES ON JAVA 7/Matlab2013 ON MACOSX
    jDefScreen = ge.getDefaultScreenDevice();
    iDefaultScreen = 1;
    for i = 2:length(jScreens)
        if (jScreens(i) == jDefScreen)
            iDefaultScreen = i;
        end
    end
    % Put the default screen in first position
    if (iDefaultScreen > 1)
        jScreens = [jScreens(iDefaultScreen), jScreens(1)];
        if (size(MonitorPositions,1) > 1)
            MonitorPositions = [MonitorPositions(iDefaultScreen,:); MonitorPositions(1,:)];
        end
    end
    % If there is a second screen but it is disabled: keep only the first one
    isDoubleScreen = bst_get('Layout', 'DoubleScreen');
    if (length(jScreens) > 1) && (isempty(isDoubleScreen) || ~isDoubleScreen)
        jScreens = jScreens(1);
        MonitorPositions = MonitorPositions(1,:);
    end
    
    % Get values for each screen
    for i = 1:length(jScreens)
        % === SCREEN SIZE ===
        % Get screen size
        jBounds = jScreens(i).getDefaultConfiguration().getBounds();
        % Get the screen insets
        jInsets = tk.getScreenInsets(jScreens(i).getDefaultConfiguration());
        ScreenDef(i).screenInsets = jInsets;
        % Maximum window size
        MaxWin = [jBounds.getX() + 1 + jInsets.left, ...
                  jBounds.getY() + 1 + jInsets.bottom, ...
                  jBounds.getWidth() - jInsets.left - jInsets.right, ...
                  jBounds.getHeight() - jInsets.top - jInsets.bottom];
        % Convert to a Java rectangle
        ScreenDef(i).javaPos = java.awt.Rectangle(MaxWin(1), MaxWin(2), MaxWin(3), MaxWin(4));
        % For Matlab < 2014b:  Adjust position of secondary monitors based on the size of the first one
        if isOldPositions
            % Secondary screens
            if (i > 1) && (i <= size(MonitorPositions,1))
                isVertical = (MonitorPositions(i,1) == MonitorPositions(1,1));
                % Vertical extension
                if isVertical && (MonitorPositions(i,2) ~= MonitorPositions(1,2))
                    MaxWin(1) = MaxWin(1) - MaxWin(3) + MonitorPositions(1,3);
                % Horizontal extension
                elseif (MonitorPositions(i,4) ~= MonitorPositions(1,4))
                    MaxWin(2) = MaxWin(2) - MaxWin(4) + MonitorPositions(1,4);
                end
            end
        % Newer Matlab: Rely on MonitorPositions directly
        else
            MaxWin = [MonitorPositions(i,1) + jInsets.left, ...
                      MonitorPositions(i,2) + jInsets.bottom, ...
                      MonitorPositions(i,3) - jInsets.left - jInsets.right, ...
                      MonitorPositions(i,4) - jInsets.top - jInsets.bottom];
        end
        
        % === SCALING ===
        try
            % Adjust with the OS scaling factor (for high-DPI screens)
            javaScreenSize = jScreens(i).getDefaultConfiguration().getBounds().getWidth();
            if (i == 1) || (i > size(MonitorPositions,1))
                matlabScreenSize = MonitorPositions(1,3) - MonitorPositions(1,1) + 1;
            else
                % For Matlab < 2014b:
                if isOldPositions
                    matlabScreenSize = MonitorPositions(i,3) - (MonitorPositions(i,1) - MonitorPositions(i-1,3)) + 1;
                % Newer Matlab
                else
                    matlabScreenSize = MonitorPositions(i,3);
                end
            end
            ZoomFactor = double(javaScreenSize) ./ double(matlabScreenSize);
            ZoomFactor = round(ZoomFactor * 100) / 100;
%             % For Matlab R2015b and above: the screen size not in scaled coordinates, need to fix this
%             if (ZoomFactor >= 1.05) && (bst_get('MatlabVersion') >= 806) 
%                 MaxWin = floor(MaxWin ./ ZoomFactor);
%             end
        catch
            ZoomFactor = 1;
        end
        % Save maximum window position and zoom factor
        ScreenDef(i).matlabPos = MaxWin;
        ScreenDef(i).zoomFactor = ZoomFactor;
    end
end


%% ===== GET BRAINSTORM SCREEN AREAS =====
% Two workspace configurations are available :
%      .---------------.           .---------------.
%   1) | BST | Figures |   OR   2) | Figures | BST |
%      '---------------'           '---------------'
function [jBstArea, FigArea, nbScreens, jFigArea, jInsets] = GetScreenBrainstormAreas(jBstWindow)
    % Jave window not provided
    if (nargin < 1) || isempty(jBstWindow)
        jBstWindow = bst_get('BstFrame');
    end
    % Get client area in whole screen
    ScreenDef = bst_get('ScreenDef');
    nbScreens = length(ScreenDef);

    % ===== NO GUI OR FULLSCREEN =====
    if ~bst_get('isGUI') || bst_get('Layout', 'FullScreen')
        jBstArea = java.awt.Rectangle(0,0,0,0);
        FigArea  = ScreenDef(1).matlabPos;
        jFigArea = ScreenDef(1).javaPos;
        jInsets  = ScreenDef(1).screenInsets;
        
    % ===== ONE SCREEN =====
    elseif (nbScreens == 1)
        javaArea   = ScreenDef.javaPos;
        matlabArea = ScreenDef.matlabPos;
        jInsets    = ScreenDef.screenInsets;
        ZoomFactor = ScreenDef.zoomFactor;
        % Check that Brainstorm window is completely inside the client area
        fixedBounds = jBstWindow.getBounds.intersection(javaArea);
        % If the window is outside of the principal screen: reset its default positions
        if ((fixedBounds.getWidth() < 200) || (fixedBounds.getHeight() < 300))
            fixedBounds.setRect(...
                javaArea.getX(), ...
                javaArea.getY(), ...
                round(450 * bst_get('InterfaceScaling') / 100), ...
                javaArea.getHeight() .* .9);
        end
        jBstWindow.setBounds(fixedBounds);
        % Compute distance from main BST window to borders
        distanceToLeft  = jBstWindow.getBounds.getX() - javaArea.getX();
        distanceToRight = javaArea.getWidth() ...
                          - (jBstWindow.getBounds.getX() + jBstWindow.getBounds.getWidth());
        % === CONFIG 1 ===
        % If BST window is more on the left : configuration 1)
        if (distanceToLeft < distanceToRight)
            % Get the area covered by the Brainstorm window
            jBstArea = java.awt.Rectangle(...
                            javaArea.getX(), ...
                            javaArea.getY(), ...
                            jBstWindow.getBounds.getX() + jBstWindow.getBounds.getWidth() - javaArea.getX(), ...
                            javaArea.getHeight());
            % Get the limit of the Brainstorm window
            bstWinX = (jBstArea.getX() + jBstArea.getWidth() + 1);
            % For Matlab R2015b and above: the screen size not in scaled coordinates, need to fix this
            if (ZoomFactor >= 1.05) && (bst_get('MatlabVersion') >= 806) 
                bstWinX = floor(bstWinX ./ ZoomFactor);
            end
            FigArea = [bstWinX, ...
                       matlabArea(2), ...
                       matlabArea(1) + matlabArea(3) - bstWinX, ...
                       matlabArea(4)];
        % === CONFIG 2 ===
        else
            jBstArea = java.awt.Rectangle(...
                            jBstWindow.getBounds.getX(), ...
                            javaArea.getY(), ...
                            javaArea.getX() + javaArea.getWidth() - jBstWindow.getBounds.getX(), ...
                            javaArea.getHeight());
            % Get the limit of the Brainstorm window
            bstWinX = jBstArea.getX() - javaArea.getX();
            % For Matlab R2015b and above: the screen size not in scaled coordinates, need to fix this
            if (ZoomFactor >= 1.05) && (bst_get('MatlabVersion') >= 806) 
                bstWinX = floor(bstWinX ./ ZoomFactor);
            end
            FigArea = [matlabArea(1), ...
                       matlabArea(2), ...
                       bstWinX, ...
                       matlabArea(4)];
        end
        jFigArea = java.awt.Rectangle(floor((FigArea(1)-1) .* ZoomFactor), ...
                                      javaArea.getY(), ...
                                      floor(FigArea(3) .* ZoomFactor), ...
                                      floor(FigArea(4) .* ZoomFactor));
                                  
    % ===== TWO SCREENS (OR MORE) =====
    elseif (nbScreens >= 2)
        % If Brainstorm window is on screen 2
        tol = 30;
        if (jBstWindow.getBounds.getX() >= ScreenDef(2).javaPos.getX() - tol) && (jBstWindow.getBounds.getX() <= ScreenDef(2).javaPos.getX() + ScreenDef(2).javaPos.getWidth() + tol) && ...
           (jBstWindow.getBounds.getY() >= ScreenDef(2).javaPos.getY() - tol) && (jBstWindow.getBounds.getY() <= ScreenDef(2).javaPos.getY() + ScreenDef(2).javaPos.getHeight() + tol)
            jBstArea = ScreenDef(2).javaPos;
            FigArea  = ScreenDef(1).matlabPos;
            jFigArea = ScreenDef(1).javaPos;
            jInsets  = ScreenDef(1).screenInsets;
        % If Brainstorm window is on screen 1
        else
            jBstArea = ScreenDef(1).javaPos;
            FigArea  = ScreenDef(2).matlabPos;
            jFigArea = ScreenDef(2).javaPos;
            jInsets  = ScreenDef(2).screenInsets;
        end
    end
end


%% ===== GET FIGURE GROUPS =====
function Figures = GetFigureGroups(isSkipMriViewer)
    global GlobalData;
    % Parse inputs
    if (nargin < 1) || isempty(isSkipMriViewer)
        isSkipMriViewer = 1;
    end

    % Get visualization figures list
    Figures = repmat(struct('fDataTimeSeries',    [], ...
                            'fRawViewer',         [], ...
                            'fTopography',        [], ...
                            'f3DViz',             [], ...
                            'fResultsTimeSeries', [], ...
                            'fTimefreq',          [], ...
                            'fSpectrum',          [], ...
                            'fOther',             [], ...
                            'fMriViewer',         [], ...
                            'fConnect',           [], ...
                            'fPac',               [], ...
                            'fImage',             [], ...
                            'fVideo',             [], ...
                            'iDataSet',           [], ...
                            'VerticalWeight',     [], ...
                            'nFigures',           [], ...
                            'nRawChannels',       []), 0);
    % Search in all the DataSets
    for iDS = 1:length(GlobalData.DataSet)
        dsFigs = GlobalData.DataSet(iDS).Figure;
        isRaw = strcmpi(GlobalData.DataSet(iDS).Measures.DataType, 'raw');
        % If there are visible figures registered in this DataSet
        if ~isempty(dsFigs) && any(~strcmpi(get([dsFigs.hFigure], 'WindowStyle'), 'docked'))
            % Detect raw viewer figures: Create one block of figure PER RAW VIEWER
            iRawViewer = [];
            if isRaw
                for iFig = 1:length(dsFigs)
                    if strcmpi(dsFigs(iFig).Id.Type, 'DataTimeSeries') && ~isempty(dsFigs(iFig).Id.Modality) && (dsFigs(iFig).Id.Modality(1) ~= '$')
                        iRawViewer = [iRawViewer, iFig];
                        % Create a new group
                        if isempty(Figures) || isempty(Figures(iFigureGroups).fRawViewer) || (Figures(iFigureGroups).iDataSet ~= iDS)
                            iFigureGroups = length(Figures) + 1;
                            Figures(iFigureGroups).iDataSet       = iDS;
                            Figures(iFigureGroups).VerticalWeight = 4;
                            Figures(iFigureGroups).fRawViewer     = dsFigs(iFig).hFigure;
                            Figures(iFigureGroups).nFigures = 1;
                        % Add figure to existing group
                        else
                            Figures(iFigureGroups).fRawViewer(end+1) = dsFigs(iFig).hFigure;
                            Figures(iFigureGroups).nFigures = Figures(iFigureGroups).nFigures + 1;
                        end
                        % EEG, MEG: Ration 3:1 with respect with isolated channels
                        Figures(iFigureGroups).nRawChannels(end+1) = length(dsFigs(iFig).SelectedChannels);
                    end
                end
                % Remove raw viewer figures from the list of figures
                if ~isempty(iRawViewer)
                    dsFigs(iRawViewer) = [];
                end
                % No more figures in this dataset: skip to the next one
                if isempty(dsFigs)
                    continue;
                end
            end

            % If MriViewer figure only in this dataset: put in in the first figure group always (does not count as a figure group)
            if isSkipMriViewer && (length(dsFigs) == 1) && strcmpi(dsFigs(1).Id.Type, 'MriViewer')
                iFigureGroups = 1;
            else
                iFigureGroups = length(Figures) + 1;
                Figures(iFigureGroups).nFigures = 0;
            end
            % Get all figures for this figure group
            Figures(iFigureGroups).iDataSet = iDS;
            for iFig = 1:length(dsFigs)
                % Figure must not be docked
                if strcmpi(get(dsFigs(iFig).hFigure,'WindowStyle'), 'docked')
                    continue;
                end
                % Add figure to the list
                Figures(iFigureGroups).(['f' dsFigs(iFig).Id.Type]) = [Figures(iFigureGroups).(['f' dsFigs(iFig).Id.Type]), dsFigs(iFig).hFigure];
                Figures(iFigureGroups).VerticalWeight = 1;
                Figures(iFigureGroups).nFigures = Figures(iFigureGroups).nFigures + 1;
            end
        end
    end

    % ===== GROUP ISOLATED FIGURES =====
    % Combine together lists of isolated figure groups (example: many results from different datasets in memory)
    % => group them so that they can be displayed as a mosaique instead of flat vertical list
    if (length(Figures) > 3) && all([Figures.nFigures] == 1) && ...
            (~isempty(Figures(1).fMriViewer) || ~isempty(Figures(1).fTopography) || ~isempty(Figures(1).f3DViz)    || ~isempty(Figures(1).fResultsTimeSeries) || ...
             ~isempty(Figures(1).fTimefreq)   || ~isempty(Figures(1).fSpectrum) || ~isempty(Figures(1).fConnect) || ~isempty(Figures(1).fPac) || ~isempty(Figures(1).fImage) || ~isempty(Figures(1).fVideo))
        uniqueFigures = Figures(1);
        uniqueFigures.fMriViewer         = [Figures.fMriViewer];
        uniqueFigures.fTopography        = [Figures.fTopography];
        uniqueFigures.f3DViz             = [Figures.f3DViz];
        uniqueFigures.fRawViewer         = [Figures.fRawViewer];
        uniqueFigures.fDataTimeSeries    = [Figures.fDataTimeSeries];
        uniqueFigures.fResultsTimeSeries = [Figures.fResultsTimeSeries];
        uniqueFigures.fTimefreq          = [Figures.fTimefreq];
        uniqueFigures.fSpectrum          = [Figures.fSpectrum];
        uniqueFigures.fConnect           = [Figures.fConnect];
        uniqueFigures.fPac               = [Figures.fPac];
        uniqueFigures.fImage             = [Figures.fImage];
        uniqueFigures.fVideo             = [Figures.fVideo];
        uniqueFigures.fOther             = [Figures.fOther];
        uniqueFigures.nFigures           = length(Figures);
        Figures = uniqueFigures;
    end
end


%% ===== TILE WINDOWS =====
% Divide vertically the available area for figures between the DataSets
% For each DataSet with figures :
%     - One line for DataTimeSeries
%     - One line for TopoGraphy and 3DViz figure
%     - One line for ResultsTimeSeries
function TileWindows(UseWeights)
    % Get Brainstorm window
    jBstWindow = bst_get('BstFrame');
    % Get the figures
    isSkipMriViewer = 0;
    Figures = GetFigureGroups(isSkipMriViewer);
    % Get Brainstorm Main window and figures areas
    [jBstArea, FigArea, nbScreens] = GetScreenBrainstormAreas(jBstWindow);
    % Check that the space to display figures is sufficient, else use the whole screen
    if (FigArea(3) < 250) 
        % Use all whole screen
        FigArea = [1, FigArea(2), jBstArea.getWidth() + FigArea(3), FigArea(4)];
    end
    % Get decoration dimensions on the current operating system (left, top, right, bottom, menubarHeight)
    decorationSize = bst_get('DecorationSize');
    
    % For each Figures block
    nbBlocks = length(Figures);
    % Define maximum size for each figure type (in pixels)
    if UseWeights || (nbBlocks > 1)
        maxSizeOtherFigures = [4096, 4096];
    elseif (nbScreens == 1)
        maxSizeOtherFigures = [700, 600];
    else
        maxSizeOtherFigures = [2048, 600];
    end

    % Total weights
    totalWeight = sum([Figures.VerticalWeight]);
    % Process each block
    for iBlock = 1:nbBlocks
        if UseWeights
            blockWeight = Figures(iBlock).VerticalWeight ./ totalWeight;
            prevWeight = sum([Figures(iBlock+1:end).VerticalWeight]) ./ totalWeight;
        else
            blockWeight = 1/nbBlocks;
            prevWeight = 1 - iBlock/nbBlocks;
        end
        % Define the area reserved for this figures block
        blockArea = [FigArea(1), ...
                     FigArea(2) + round(FigArea(4) * prevWeight), ...
                     FigArea(3), ...
                     round(FigArea(4) * blockWeight)];
        
        % ===== 3DViz, Topography and ResultsTimeSeries figures =====
        OtherFigures = [Figures(iBlock).fDataTimeSeries, Figures(iBlock).fTopography, ...
                        Figures(iBlock).f3DViz, Figures(iBlock).fResultsTimeSeries, ...
                        Figures(iBlock).fTimefreq, Figures(iBlock).fSpectrum, Figures(iBlock).fConnect,...
                        Figures(iBlock).fPac, Figures(iBlock).fImage, Figures(iBlock).fVideo, Figures(iBlock).fOther];
        % Add MRI Viewer
        if ~isSkipMriViewer
            OtherFigures = [OtherFigures, Figures(iBlock).fMriViewer];
        end
        nbOtherFigures = length(OtherFigures);
        % Always display full screen MRI viewer if it is the only figure
        isFullScreenMri = isSkipMriViewer || ((nbBlocks == 1) && (nbOtherFigures == 1));
        % Position regular figures
        if (nbOtherFigures >= 1)                      
            % Divide list of figures in many rows
            if (nbBlocks == 1) && (nbOtherFigures == 3)
                nbCols = 2;
                nbRows = 2;
            else
                if (blockArea(3) <= blockArea(4))
                    nbCols = floor(sqrt(nbOtherFigures));
                    nbRows = ceil(nbOtherFigures / nbCols);
                elseif (blockArea(3) > blockArea(4))
                    nbRows = floor(sqrt(nbOtherFigures));
                    nbCols = ceil(nbOtherFigures / nbRows);
                end
            end

            % Divide horizontally the available space between all DataTimeSeries figures
            for iOtherFigures = 1:nbOtherFigures
                % If this figure is a full screen MRI figure: skip
                if isFullScreenMri && ~isempty(Figures(iBlock).fMriViewer) && ismember(OtherFigures(iOtherFigures), Figures(iBlock).fMriViewer)
                    continue;
                end
                % Get figure row and column
                iRow = floor((iOtherFigures-1) / nbCols);
                iCol = mod((iOtherFigures-1), nbCols);
                
                % Compute new position for this DataTimeSeries figure
                figArea = [blockArea(1) + iCol * round(blockArea(3) / nbCols), ...
                           blockArea(2) + (nbRows - iRow - 1) * round(blockArea(4) / nbRows), ...
                           round(blockArea(3) / nbCols), ...
                           round(blockArea(4) / nbRows)];
                       
                % Limit figure size
                if (nbOtherFigures == 1) && ~ismember(OtherFigures, Figures(iBlock).fDataTimeSeries) && ~ismember(OtherFigures, Figures(iBlock).fResultsTimeSeries)
                    figArea(3) = min(figArea(3), maxSizeOtherFigures(1));
                end
                figArea(2) = figArea(2) + (figArea(4) - min(figArea(4), maxSizeOtherFigures(2)));
                figArea(4) = min(figArea(4), maxSizeOtherFigures(2));
                
                % Apply this new position
                PositionFigure(OtherFigures(iOtherFigures), figArea, decorationSize);
            end
        end
        
        % === RAW VIEWER ===
        % Get the display weight of each view
        if UseWeights && ~isempty(Figures(iBlock).nRawChannels)
            rawWeight = [Figures(iBlock).nRawChannels] ./ max([Figures(iBlock).nRawChannels]);
            rawWeight(rawWeight == 1)  = 7;
            rawWeight(rawWeight < .1) = 1;
            rawWeight(rawWeight < .2) = 4;
            rawWeight(rawWeight < .4) = 5;
            rawWeight(rawWeight <  1)  = 6;
        else
            rawWeight = ones(1, length(Figures(iBlock).fRawViewer));
        end
        % Position each raw viewer
        for iRawFig = 1:length(Figures(iBlock).fRawViewer)
            % If only one block: fill vertically AND horizontally
            if (nbBlocks == 1)
                rawArea = FigArea;
            % If many blocks: fill only horizontally (full block area)
            else
                rawArea = blockArea;
            end
            % Assign a weight to each figure based on the number of sensors on each view
            curHeight = round(rawWeight(iRawFig) ./ sum(rawWeight) .* rawArea(4));
            prevHeight = round(sum(rawWeight(iRawFig+1:end)) ./ sum(rawWeight) .* rawArea(4));
            % Calculate position
            figRawArea = [rawArea(1), ...
                          rawArea(2) + prevHeight, ...
                          rawArea(3), ...
                          curHeight];
            % Set figure position
            PositionFigure(Figures(iBlock).fRawViewer(iRawFig), figRawArea, decorationSize);
        end
        % === MRI VIEWER FIGURES ===
        % Set to the whole avaiable space
        if isSkipMriViewer || ((nbBlocks == 1) && (nbOtherFigures == 1))
            for iMriFig = 1:length(Figures(iBlock).fMriViewer)
                PositionFigure(Figures(iBlock).fMriViewer(iMriFig), FigArea, decorationSize);
            end
        end
    end

    % === MASK EDITOR ===
    % Set to the entire avaiable space
    global gEditMaskData;
    if ~isempty(gEditMaskData) && isfield(gEditMaskData, 'Handles') && ishandle(gEditMaskData.Handles.mri_editMask)
        PositionFigure(gEditMaskData.Handles.mri_editMask, FigArea, decorationSize);
    end
end


%% ===== FIXED LAYOUT =====
% Set the same size/position for all the figures
function FixedSizeWindows(figArea)
    % Get the figures
    Figures = GetFigureGroups();
    % Get decoration dimensions on the current operating system (left, top, right, bottom, menubarHeight)
    decorationSize = bst_get('DecorationSize');
    % Process each block of figures
    for iBlock = 1:length(Figures)
        % Get all the figures
        hAllFig = [Figures(iBlock).fDataTimeSeries, Figures(iBlock).fTopography, ...
                   Figures(iBlock).f3DViz, Figures(iBlock).fResultsTimeSeries, ...
                   Figures(iBlock).fTimefreq, Figures(iBlock).fSpectrum, Figures(iBlock).fConnect, Figures(iBlock).fPac, Figures(iBlock).fImage, Figures(iBlock).fVideo, ...
                   Figures(iBlock).fOther, Figures(iBlock).fRawViewer, Figures(iBlock).fMriViewer];
        % Set the position
        for iFig = 1:length(hAllFig)
            PositionFigure(hAllFig(iFig), figArea, decorationSize);
        end
    end
end


%% ===== POSITION FIGURES =====
function PositionFigure(hFigure, figArea, decorationSize)
    drawnow;
    if ~ishandle(hFigure)
        return
    end
    % If figure has a menu bar
    if ~strcmpi(get(hFigure, 'MenuBar'), 'none')
        menubarHeight = decorationSize(5);
    else
        menubarHeight = 0;
    end
    % If figure has a figure toolbar
    toolbarHeight = 0;
    if ~strcmpi(get(hFigure, 'ToolBar'), 'none')
        toolbarHeight = toolbarHeight + decorationSize(6);
    end
    if ~isempty(findobj(hFigure, '-depth', 1, 'Tag', 'AlignToolbar'))
        toolbarHeight = toolbarHeight + decorationSize(6);
    end
    % If figure has a plot edit toolbar
    isPlotEditToolbar = getappdata(hFigure, 'isPlotEditToolbar');
    if ~isempty(isPlotEditToolbar) && isPlotEditToolbar
        toolbarHeight = toolbarHeight + decorationSize(6);
    end
    % Remove decorations dimensions
    figDim = figArea + [decorationSize(1), ...
                        decorationSize(4), ...
                        - decorationSize(1) - decorationSize(3), ...
                        - decorationSize(2) - decorationSize(4) - menubarHeight - toolbarHeight];
    % Older versions of Matlab/MacOSX have random 22px positionning problem (fixed for versions >= R2011b)
    if strncmp(computer, 'MAC', 3) && (bst_get('MatlabVersion') <= 712)
        figDim(2) = figDim(2) - 22;
    end
    % Force all figures to have positive dimensions
    figDim(3:4) = max(figDim(3:4), [10 10]);
%     % Get client area in whole screen
%     ScreenDef = bst_get('ScreenDef');
%     % If the figure is on a secondary screen and the two screens do not have the same size, need to fix the "Y=0" of the screen
%     if (length(ScreenDef) > 1) && (figDim(1) >= ScreenDef(1).matlabPos(1) + ScreenDef(1).matlabPos(3)) && (ScreenDef(1).matlabPos(4) ~= ScreenDef(2).matlabPos(4))
%         figDim(2) = figDim(2) - ScreenDef(2).matlabPos(4) + ScreenDef(1).matlabPos(4);
%     end
    % Apply position to figure
    set(hFigure, 'Position', figDim);
end


%% ===== SHOW ALL WINDOWS =====
function ShowAllWindows() %#ok<DEFNU>
    % Get Brainstorm window
    jBstWindow = bst_get('BstFrame');
    % Get the figures
    Figures = GetFigureGroups();
    % Set focus to each figure sequentially
    if ~isempty(Figures)
        fieldNames = {'fDataTimeSeries', 'fRawViewer', 'fTopography', 'f3DViz', 'fResultsTimeSeries', 'fTimefreq', 'fSpectrum', 'fMriViewer', 'fConnect', 'fPac', 'fImage', 'fVideo', 'fOther'};
        nbBlocks = length(Figures);
        for iBlock = 1:nbBlocks
            for iType = 1:length(fieldNames)
                if ~isempty(Figures(iBlock).(fieldNames{iType}))
                    for hFig = Figures(iBlock).(fieldNames{iType})
                        if strcmpi(get(hFig, 'Visible'), 'on')
                            figure(hFig);
                        end
                    end
                end
            end 
        end
    end
    % Put focus on the main brainstorm window again
    drawnow;
    jBstWindow.setVisible(1);
end


%% ===================================================================================================================================
%  ===== DISPLAY SETUPS ==============================================================================================================
%  ===================================================================================================================================

%% ===== CREATE SETUP MENU =====
function SetupMenu(jMenu) %#ok<DEFNU>
    import org.brainstorm.icon.*;
%     % Get all the open figures
%     hAllFig = bst_figures('GetAllFigures');
%     if isempty(hAllFig)
%         return;
%     end
    fontSize = [];
    % Get current setups
    UserSetups = bst_get('Layout', 'UserSetups');
    % List all the pipelines
    for iSetup = 1:length(UserSetups)
        gui_component('MenuItem', jMenu, [], UserSetups(iSetup).Name, IconLoader.ICON_LAYOUT_CASCADE, [], @(h,ev)LoadSetup(iSetup), fontSize);
    end
    % Separator
    if ~isempty(UserSetups)
        jMenu.addSeparator();
    end
    % Create new setup
    gui_component('MenuItem', jMenu, [], 'New setup', IconLoader.ICON_SAVE, [], @(h,ev)CreateNewSetup(), fontSize);
    % Delete entries
    if ~isempty(UserSetups)
        jMenuDel = gui_component('Menu', jMenu, [], 'Delete setup', IconLoader.ICON_DELETE, [], [], fontSize);
        % List all the pipelines
        for iSetup = 1:length(UserSetups)
            gui_component('MenuItem', jMenuDel, [], UserSetups(iSetup).Name, IconLoader.ICON_DELETE, [], @(h,ev)DeleteSetup(iSetup), fontSize);
        end
    end
end

%% ===== CREATE NEW SETUP =====
function CreateNewSetup()
    global GlobalData;
    % Get layout structure
    UserSetups = GlobalData.Preferences.Layout.UserSetups;
    % Create new structure
    sSetup.Name = '';
    sSetup.Figures = repmat(struct(...
        'FigureId', [], ...
        'AppData',  [], ...
        'Position', [], ...
        'Color',    [], ...
        'Camera',   []), 0);
    DataFile = [];
    nWarningSkip = 0;
    % Loop on all the figures
    for iDS = 1:length(GlobalData.DataSet)
        for iFig = 1:length(GlobalData.DataSet(iDS).Figure)
            % Get figure infor
            Figure = GlobalData.DataSet(iDS).Figure(iFig);
            AppData = getappdata(Figure.hFigure);
            % Keep only simple figures with a data file
            if ~ismember(Figure.Id.Type, {'DataTimeSeries','3DViz','Topography'}) || isempty(AppData.DataFile) || (isfield(AppData, 'Timefreq') && ~isempty(AppData.Timefreq)) || strcmpi(file_gettype(AppData.DataFile), 'pdata')
                nWarningSkip = nWarningSkip + 1;
                continue;
            end
            % Remove unwanted objects from the AppData structure
            for field = fieldnames(AppData)'
                if ~isempty(strfind(field{1}, 'uitools')) || isjava(AppData.(field{1})) || ismember(field{1}, {'SubplotDefaultAxesLocation', 'SubplotDirty'})
                    AppData = rmfield(AppData, field{1});
                    continue;
                end
            end
            % Keep only the figures with the same DataFile as the first one
            if ~isempty(DataFile)
                if ~file_compare(DataFile, AppData.DataFile)
                    nWarningSkip = nWarningSkip + 1;
                    continue;
                end
            else
                DataFile = AppData.DataFile;
            end
            % Save figure
            iSaveFig = length(sSetup.Figures) + 1;
            sSetup.Figures(iSaveFig).FigureId = Figure.Id;
            sSetup.Figures(iSaveFig).AppData  = AppData;
            sSetup.Figures(iSaveFig).Position = get(Figure.hFigure, 'Position');
            sSetup.Figures(iSaveFig).Color    = get(Figure.hFigure, 'Color');
            % 3D figures: Get camera
            hAxes = findobj(Figure.hFigure, '-depth', 1, 'Tag', 'Axes3D');
            if strcmpi(Figure.Id.Type, '3DViz') && ~isempty(hAxes)
                % Copy view angle and camup
                [cam.az, cam.el] = view(hAxes);
                cam.up = camup(hAxes);
                sSetup.Figures(iSaveFig).Camera = cam;
            else
                sSetup.Figures(iSaveFig).Camera = [];
            end
        end
    end
    % Check the number of figures
    if (length(sSetup.Figures) < 1)
        bst_error('Not enough figures related with the same dataset to create a screen setup.', 'Screen setup', 0);
        return;
    elseif (nWarningSkip > 0)
        disp(['BST> Warning: ' num2str(nWarningSkip) ' figure(s) could not be included in the saved setup.']);
    end
    % Ask user the name for the new setup
    newName = java_dialog('input', 'Enter a name for the new screen setup:', 'Screen setup');
    if isempty(newName)
        return;
    end
    % Check if setup already exists
    if ~isempty(UserSetups) && any(strcmpi({UserSetups.Name}, newName))
        bst_error('This name already exists.', 'Screen setup', 0);
        return
    end
    % Save new setup name
    sSetup.Name = newName;
    % Add setup to list
    if isempty(UserSetups)
        UserSetups = sSetup;
    else
        UserSetups(end+1) = sSetup;
    end
    % Save modifications
    GlobalData.Preferences.Layout.UserSetups = UserSetups;
end

%% ===== DELETE SETUP =====
function DeleteSetup(iSetup)
    global GlobalData;
    % Ask confirmation
    if ~java_dialog('confirm', ['Delete setup "' GlobalData.Preferences.Layout.UserSetups(iSetup).Name '"?'], 'Screen setup');
        return;
    end    
    % Select first item in the pipeline
    GlobalData.Preferences.Layout.UserSetups(iSetup) = [];
end

%% ===== LOAD SETUP =====
function LoadSetup(iSetup)
    global GlobalData;
    % Get all the loaded data files
    iDS = [];
    DataFile = [];
    for i = 1:length(GlobalData.DataSet)
        if ~isempty(GlobalData.DataSet(i).DataFile) && ~isempty(DataFile) && ~file_compare(GlobalData.DataSet(i).DataFile, DataFile)
            disp(['BST> Warning: The screen setup is applied only to the first loaded dataset, skipping data file: ' GlobalData.DataSet(i).DataFile]);
        elseif ~isempty(GlobalData.DataSet(i).DataFile)
            iDS = i;
            DataFile = GlobalData.DataSet(iDS).DataFile;
        end
    end
    % Check for loaded data
    if isempty(DataFile)
        bst_error('You have to load one dataset before applying a screen setup.', 'Screen setup', 0);
        return
    end
    % Get all the old figures
    hFigOldAll = bst_figures('GetAllFigures');
    % Get screen setup to load
    sSetup = GlobalData.Preferences.Layout.UserSetups(iSetup);
    % Disable temporarily the layout manager
    curWM = bst_get('Layout', 'WindowManager');
    if ~isempty(curWM)
        bst_set('Layout', 'WindowManager', sSetup.Name);
    end
    % Reload all the figures
    hNewFig = [];
    for i = 1:length(sSetup.Figures)
        % Progress bar
        bst_progress('start', 'Screen setup', 'Loading figures...');
        % Re-use existing figures: Get existing figures with the same FigureId
        [hFigOld, iFigOld] = bst_figures('GetFigure', iDS, sSetup.Figures(i).FigureId);
        hFigOld = setdiff(hFigOld, hNewFig);
        if ~isempty(hFigOld)
            hFig = hFigOld(1);
            iFig = iFigOld(1);
        % Else: Force creation 
        else
            [hFig, iFig] = bst_figures('CreateFigure', iDS, sSetup.Figures(i).FigureId, 'AlwaysCreate');
        end
        if isempty(hFig)
            disp(['BST> Error: Could not create figure #' num2str(i)]);
            continue;
        end
        hNewFig(end+1) = hFig;
        % Update AppData structure
        AppData = sSetup.Figures(i).AppData;
        if isfield(AppData, 'DataFile') && ~isempty(AppData.DataFile)
            AppData.DataFile = DataFile;
        end
        if isfield(AppData, 'TsInfo') && isfield(AppData.TsInfo, 'FileName') && ~isempty(AppData.TsInfo.FileName)
            AppData.TsInfo.FileName = DataFile;
            AppData.TsInfo = struct_copy_fields(AppData.TsInfo, db_template('TsInfo'), 0);
        end
        if isfield(AppData, 'TopoInfo') && isfield(AppData.TopoInfo, 'FileName') && ~isempty(AppData.TopoInfo.FileName)
            AppData.TopoInfo.FileName = DataFile;
            AppData.TopoInfo = struct_copy_fields(AppData.TopoInfo, db_template('TopoInfo'), 0);
        end
        if isfield(AppData, 'Surface') && ~isempty(AppData.Surface)
            % Save old surfaces
            Surface = AppData.Surface;
            % Remove all existing surfaces
            TessInfo = getappdata(hFig, 'Surface');
            for iDel = 1:length(TessInfo)
                panel_surface('RemoveSurface', hFig, iDel);
            end
            AppData.Surface = repmat(db_template('TessInfo'),0);
        else
            Surface = [];
        end
        if isfield(AppData, 'StudyFile') && ~isempty(AppData.StudyFile)
            sStudy = bst_get('AnyFile', DataFile);
            AppData.StudyFile = sStudy.FileName;
            sSubject = bst_get('Subject', sStudy.BrainStormSubject);
            AppData.SubjectFile = sSubject.FileName;
        end
        % Set AppData
        for field = fieldnames(AppData)'
            setappdata(hFig, field{1}, AppData.(field{1}));
        end
        % Position figure 
        set(hFig, 'Position', sSetup.Figures(i).Position);
        % Switch according to figure type
        switch (sSetup.Figures(i).FigureId.Type)
            case '3DViz'
                % Loop on the surface files to add
                for iSurf = 1:length(Surface)
                    % Get source file for the data
                    if ~isempty(Surface(iSurf).DataSource) && strcmpi(Surface(iSurf).DataSource.Type, 'Source')     
                        % Get first results file for data file
                        [sStudy, iStudy, iResults] = bst_get('ResultsForDataFile', DataFile);
                        if isempty(iResults)
                            disp('BST> Warning: Data file does not have any attached source file.');
                            close(hFig);
                            continue;
                        end
                        ResultsFile = sStudy.Result(iResults(1)).FileName;
                        % Get surface file
                        ResultsMat = in_bst_results(ResultsFile, 0, 'SurfaceFile');
                        % Add surface
                        panel_surface('AddSurface', hFig, ResultsMat.SurfaceFile);
                        % Load source file
                        bst_memory('LoadResultsFile', ResultsFile);
                        % Set surface data
                        panel_surface('SetSurfaceData', hFig, iSurf, 'Source', ResultsFile, 0);
                        % Set surface properties
                        panel_surface('SetSurfaceSmooth',       hFig, iSurf, Surface(iSurf).SurfSmoothValue, 0);
                        panel_surface('SetSurfaceTransparency', hFig, iSurf, Surface(iSurf).SurfAlpha);
                        panel_surface('SetShowSulci',           hFig, iSurf, Surface(iSurf).SurfShowSulci);
                        panel_surface('SetDataThreshold',       hFig, iSurf, Surface(iSurf).DataThreshold);
                        panel_surface('SetSizeThreshold',       hFig, iSurf, Surface(iSurf).SizeThreshold);
                    else
                        % Get surface type
                        SurfaceType = Surface(iSurf).Name;
                        % Get subject structure
                        sStudy = bst_get('DataFile', DataFile);
                        sSubject = bst_get('Subject', sStudy.BrainStormSubject);
                        if ismember(SurfaceType, {'Cortex', 'Scalp', 'InnerSkull', 'InnerSkull'})
                            SurfaceFile = sSubject.Surface(sSubject.(['i' SurfaceType])).FileName;
                        elseif strcmpi(SurfaceType, 'Anatomy')
                            SurfaceFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                        else
                            SurfaceFile = [];
                        end
                        % Add default surface
                        if ~isempty(SurfaceFile)
                            panel_surface('AddSurface', hFig, SurfaceFile);
                        else
                            disp(['BST> Warning: Cannot reload surface #' num2str(iSurf) '.']);
                        end
                    end
                end
                % Find 3D axes
                hAxes = findobj(hFig, '-depth', 1, 'Tag', 'Axes3D');
                if ~isempty(hAxes)
                    % Set camera
                    view(hAxes, sSetup.Figures(i).Camera.az, sSetup.Figures(i).Camera.el);
                    camup(hAxes, sSetup.Figures(i).Camera.up);
                    % Update head light position
                    camlight(findobj(hAxes, '-depth', 1, 'Tag', 'FrontLight'), 'headlight');
                end
                % Make it visible
                set(hFig, 'Visible', 'on');
                
            case 'Topography'
                % Plot figure
                figure_topo('PlotFigure', iDS, iFig, 1);
                % Make it visible
                set(hFig, 'Visible', 'on');
                
            case 'DataTimeSeries'
                view_timeseries(DataFile, sSetup.Figures(i).FigureId.Modality, AppData.TsInfo.RowNames, hFig);
                
            otherwise
                bst_figures('ReloadFigures', hFig);
        end
        % Set background
        if isfield(sSetup.Figures(i), 'Color') && ~isempty(sSetup.Figures(i).Color)
            set(hFig, 'Color', sSetup.Figures(i).Color);
        end
    end
    % Close all the figures that haven't been updated
    hFigClose = setdiff(hFigOldAll, hNewFig);
    if ~isempty(hFigClose)
        close(hFigClose);
    end
    % Close progress bar
    bst_progress('stop');
end


%% ===== UPDATE MAXIMUM BST WINDOW SIZE =====
function UpdateMaxBstSize() %#ok<DEFNU>
    % Get screen definition
    jBstFrame = bst_get('BstFrame');
    ScreenDef = bst_get('ScreenDef');
    sLayout   = bst_get('Layout');
    nbScreens = length(ScreenDef);
    
    % Max size for Brainstorm window
    if ~isempty(jBstFrame) && ~isempty(ScreenDef)
        % Detect on which screen was Brainstorm window at the previous session
        tol = 30;
        % If Brainstorm window is on screen 2
        if (length(ScreenDef) > 1) && ...
           (sLayout.MainWindowPos(1) >= ScreenDef(2).javaPos.getX() - tol) && (sLayout.MainWindowPos(1) <= ScreenDef(2).javaPos.getX() + ScreenDef(2).javaPos.getWidth() + tol) && ...
           (sLayout.MainWindowPos(2) >= ScreenDef(2).javaPos.getY() - tol) && (sLayout.MainWindowPos(2) <= ScreenDef(2).javaPos.getY() + ScreenDef(2).javaPos.getHeight() + tol)
            javaMax = ScreenDef(2).javaPos;
        % If Brainstorm window is on screen 1
        else
            javaMax = ScreenDef(1).javaPos;
        end
        % One screen: Half size
        if (nbScreens == 1)
            jBstFrame.setMaximumSize(java.awt.Dimension(javaMax.getWidth() / 2, javaMax.getHeight()));
            jBstFrame.setMaximizedBounds(java.awt.Rectangle(0,0,javaMax.getWidth() / 2, javaMax.getHeight()));
        % More screens: No limit
        else
            jBstFrame.setMaximumSize([]);
            jBstFrame.setMaximizedBounds([]);
        end
    end
end



