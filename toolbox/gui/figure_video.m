function varargout = figure_video( varargin )
% FIGURE_VIDEO Creation and callbacks for displaying videos.
%
% USAGE:  hFig = figure_image('CreateFigure', FigureId)

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
% Authors: Francois Tadel, 2015

eval(macro_method);
end


%% ===== CREATE FIGURE =====
function hFig = CreateFigure(FigureId) %#ok<DEFNU>
    % Get renderer name
    if (bst_get('DisableOpenGL') ~= 1)
        rendererName = 'opengl';
    elseif (bst_get('MatlabVersion') <= 803)   % zbuffer was removed in Matlab 2014b
        rendererName = 'zbuffer';
    else
        rendererName = 'painters';
    end
    % Create new figure
    hFig = figure('Visible',       'off', ...
                  'NumberTitle',   'off', ...
                  'IntegerHandle', 'off', ...
                  'MenuBar',       'none', ...
                  'Toolbar',       'none', ...
                  'DockControls',  'on', ...
                  'Units',         'pixels', ...
                  'Interruptible', 'off', ...
                  'BusyAction',    'queue', ...
                  'Tag',           FigureId.Type, ...
                  'Renderer',      rendererName, ...
                  'Color',         [0,0,0], ...
                  'CloseRequestFcn',          @(h,ev)bst_figures('DeleteFigure',h,ev), ...
                  'KeyPressFcn',              @FigureKeyPressedCallback, ...
                  'WindowButtonDownFcn',      @FigureMouseDownCallback, ...
                  'WindowButtonUpFcn',        @FigureMouseUpCallback, ...
                  bst_get('ResizeFunction'),  @ResizeCallback);
    % Define Mouse wheel callback separately (not supported by old versions of Matlab)
    if isprop(hFig, 'WindowScrollWheelFcn')
        set(hFig, 'WindowScrollWheelFcn',  @FigureMouseWheelCallback);
    end
    % Prepare figure appdata
    setappdata(hFig, 'FigureId', FigureId);
    setappdata(hFig, 'hasMoved', 0);
    setappdata(hFig, 'isPlotEditToolbar', 0);
    setappdata(hFig, 'isStatic', 0);
    setappdata(hFig, 'isStaticFreq', 1);
end


%% ===========================================================================
%  ===== FIGURE CALLBACKS ====================================================
%  ===========================================================================

%% ===== CURRENT TIME CHANGED =====
function CurrentTimeChangedCallback(hFig)   %#ok<DEFNU>
    global GlobalData;
    % Get figure handles
    Handles = bst_figures('GetFigureHandles', hFig);

    % Operation depends on the player
    switch Handles.PlayerType
        case 'WMPlayer'
            % If there is no valid player: return
            if ~ishandle(Handles.hPlayer)
                return;
            end
            % Pause the video and hide the controls
            Handles.hPlayer.controls.pause;
            Handles.hPlayer.uiMode = 'none';
            % Set the current time
            Handles.hPlayer.controls.currentPosition = max(0, GlobalData.UserTimeWindow.CurrentTime - Handles.VideoStart);
            
        case 'VideoReader'
            % If there is no valid player
            if isempty(Handles.hPlayer)
                return;
            end
            % Change the current time in the file
            Handles.hPlayer.CurrentTime = max(0, GlobalData.UserTimeWindow.CurrentTime - Handles.VideoStart);
            % Get the corresponding frame of the movie
            imgFrame = readFrame(Handles.hPlayer);
            % Update the image with the read frame
            set(Handles.hImage, 'CData', imgFrame);
    end
end


%% ===== RESIZE CALLBACK =====
function ResizeCallback(hFig, ev)
    % Get figure handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Get figure position and size in pixels
    figPos = get(hFig, 'Position');
    % Operation depends on the player
    switch Handles.PlayerType
        case 'WMPlayer'
            % If there is no valid player: return
            if ~ishandle(Handles.hPlayer)
                return;
            end
            % Resize to fit the entire window
            move(Handles.hPlayer, [0, 0, figPos(3), figPos(4)]);
            
        case 'VideoReader'
            % Nothing to do, image is already resized automatically
            
    end
end


%% ===========================================================================
%  ===== KEYBOARD AND MOUSE CALLBACKS =============================================
%  ===========================================================================
%% ===== FIGURE MOUSE DOWN =====
function FigureMouseDownCallback(hFig, ev)
    disp('Figure MouseDown')
end


%% ===== FIGURE MOUSE MOVE =====
function FigureMouseMoveCallback(hFig, event)
    disp('Figure move')
end
            

%% ===== FIGURE MOUSE UP =====        
function FigureMouseUpCallback(hFig, event)
    disp('Figure MouseUp')
    % DisplayFigurePopup(hFig);
end


%% ===== FIGURE MOUSE WHEEL =====
function FigureMouseWheelCallback(hFig, event)
    global GlobalData;
    % Get current time
    CurrentTime = GlobalData.UserTimeWindow.CurrentTime;
    % Switch to next/previous video frame
    if isempty(event)
        return;
    elseif (event.VerticalScrollCount < 0)
        CurrentTime = CurrentTime + 0.30;
    elseif (event.VerticalScrollCount > 0)
        CurrentTime = CurrentTime - 0.30;
    else
        return;
    end
    % Update current time
    panel_time('SetCurrentTime', CurrentTime);
end


%% ===== KEYBOARD CALLBACK =====
function FigureKeyPressedCallback(hFig, keyEvent)
    % Prevent multiple executions
    hAxes = findobj(hFig, '-depth', 1, 'Tag', 'AxesVideo')';
    set([hFig hAxes], 'BusyAction', 'cancel');
    % Get figure description
    [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
    % Process event
    switch (keyEvent.Key)
        % === LEFT, RIGHT, PAGEUP, PAGEDOWN : Processed by TimeWindow ===
        case {'leftarrow', 'rightarrow', 'pageup', 'pagedown', 'home', 'end'}
            panel_time('TimeKeyCallback', keyEvent);
        % CTRL+D : Dock figure
        case 'd'
            if ismember('control', keyEvent.Modifier)
                isDocked = strcmpi(get(hFig, 'WindowStyle'), 'docked');
                bst_figures('DockFigure', hFig, ~isDocked);
            end
    end
    % Restore events
    set([hFig hAxes], 'BusyAction', 'queue');
end


%% ===== POPUP MENU =====
function DisplayFigurePopup(hFig)
    import java.awt.event.KeyEvent;
    import javax.swing.KeyStroke;
    import org.brainstorm.icon.*;
    % Create popup menu
    jPopup = java_create('javax.swing.JPopupMenu');
    
    % ==== MENU: COLORMAP =====
    bst_colormaps('CreateAllMenus', jPopup, hFig, 0);

    % ==== MENU: SNAPSHOT ====
    jPopup.addSeparator();
    jMenuSave = gui_component('Menu', jPopup, [], 'Snapshots', IconLoader.ICON_SNAPSHOT);
        % === SAVE AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Save as image', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@out_figure_image, hFig));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_I, KeyEvent.CTRL_MASK));
        % === OPEN AS IMAGE ===
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as image', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Viewer'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_J, KeyEvent.CTRL_MASK));
        jItem = gui_component('MenuItem', jMenuSave, [], 'Open as figure', IconLoader.ICON_IMAGE, [], @(h,ev)bst_call(@out_figure_image, hFig, 'Figure'));
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_F, KeyEvent.CTRL_MASK));
    % ==== MENU: FIGURE ====
    jMenuFigure = gui_component('Menu', jPopup, [], 'Figure', IconLoader.ICON_LAYOUT_SHOWALL, [], []);
        % Show Matlab controls
        isMatlabCtrl = ~strcmpi(get(hFig, 'MenuBar'), 'none') && ~strcmpi(get(hFig, 'ToolBar'), 'none');
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'Matlab controls', IconLoader.ICON_MATLAB_CONTROLS, [], @(h,ev)bst_figures('ShowMatlabControls', hFig, ~isMatlabCtrl));
        jItem.setSelected(isMatlabCtrl);
        % Show plot edit toolbar
        isPlotEditToolbar = getappdata(hFig, 'isPlotEditToolbar');
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'Plot edit toolbar', IconLoader.ICON_PLOTEDIT, [], @(h,ev)bst_figures('TogglePlotEditToolbar', hFig));
        jItem.setSelected(isPlotEditToolbar);
        % Dock figure
        isDocked = strcmpi(get(hFig, 'WindowStyle'), 'docked');
        jItem = gui_component('CheckBoxMenuItem', jMenuFigure, [], 'Dock figure', IconLoader.ICON_DOCK, [], @(h,ev)bst_figures('DockFigure', hFig, ~isDocked));
        jItem.setSelected(isDocked);
        jItem.setAccelerator(KeyStroke.getKeyStroke(KeyEvent.VK_D, KeyEvent.CTRL_MASK)); 
           
    % Display Popup menu
    gui_popup(jPopup, hFig);
end


%% ===========================================================================
%  ===== WINDOWS MEDIA PLAYER CALLBACKS ======================================
%  ===========================================================================
%% ===== WM PLAYER CLICK ===== 
function WMPlayer_Click(ObjName, EventID, nButton, nShiftState, fX, fY, sEvent, EventName)
    % If right-click: show figure popup
%     if (nButton == 2)
%         DisplayFigurePopup(gcf);
%     else
        disp(sprintf('X=%4d  Y=%4d', fX, fY));
%     end
end

function WMPlayer_MouseMove(varargin)
    % Reset the cursor
    fprintf(1, ' \b');
end


%% ===========================================================================
%  ===== DISPLAY FUNCTIONS ===================================================
%  ===========================================================================
%% ===== LOAD VIDEO =====
function isOk = LoadVideo(hFig, VideoFile)
    global GlobalData;
    % Get figure handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Check if some data is already loaded
    isStandAlone = isempty(GlobalData.UserTimeWindow.CurrentTime);
    % Capture errors
    try
        % Create video controls
        switch Handles.PlayerType
            case 'WMPlayer'
                Handles.hPlayer = actxcontrol('WMPlayer.OCX.7', [0 0 300 300], hFig, ...
                    {'Click', @WMPlayer_Click, 'MouseMove', @WMPlayer_MouseMove});
                Handles.hPlayer.settings.autoStart = 0;
                Handles.hPlayer.stretchToFit       = 0;
                Handles.hPlayer.windowlessVideo    = 1;
                Handles.PlayerType = 'WMPlayer';
                % Load video in the player
                Handles.hMedia = Handles.hPlayer.newMedia(VideoFile);
                Handles.hPlayer.CurrentMedia = Handles.hMedia;
                % Start playing to load the file
                Handles.hPlayer.controls.play;
                % If the video is not stand alone: hide the controls and pause when the media is loaded
                if ~isStandAlone
                    Handles.hPlayer.uiMode = 'none';
                    while ~strcmpi(Handles.hPlayer.playState, 'wmppsPlaying')
                        pause(0.05);
                    end
                    Handles.hPlayer.controls.pause;
                    Handles.hPlayer.controls.currentPosition = max(0, GlobalData.UserTimeWindow.CurrentTime - Handles.VideoStart);
                end

            case 'VideoReader'
                % Create a video reader object
                Handles.hPlayer = VideoReader(VideoFile);
                % Jump to the current frame
                if ~isempty(GlobalData.UserTimeWindow.CurrentTime)
                    Handles.hPlayer.CurrentTime = max(0, GlobalData.UserTimeWindow.CurrentTime - Handles.VideoStart);
                end
                % Get the first frame of the movie (or current frame)
                imgFrame = readFrame(Handles.hPlayer);
                % Create axes
                hAxes = axes(...
                    'Units',         'normalized', ...
                    'Position',      [0, 0, 1, 1], ...
                    'Interruptible', 'off', ...
                    'BusyAction',    'queue', ...
                    'Parent',        hFig, ...
                    'Tag',           'AxesVideo', ...
                    ... 'YDir',          'reverse', ...
                    'XGrid',         'off', ...
                    'YGrid',         'off', ...
                    'XTick',         [], ...
                    'YTick',         []);
                axis image equal;
                % Create an image object
                Handles.hImage = image(...
                    'CData', imgFrame, ...
                    'Parent', hAxes);
                % Get the first frame
                
        end
        isOk = 1;
    catch
        isOk = 0;
        bst_error(['Cannot load video file: ' 10 10 lasterr()], 'Open video', 0);
    end
    
    % Update figure handles
    bst_figures('SetFigureHandles', hFig, Handles);
    % Save filename
    setappdata(hFig, 'VideoFile', VideoFile);
end


%% ===== CLOSE VIDEO =====
function CloseVideo(hFig)
    % Get figure handles
    Handles = bst_figures('GetFigureHandles', hFig);
    % Operation depends on the player
    switch (Handles.PlayerType)
        case 'WMPlayer'
            % Release interfaces
            if ishandle(Handles.hMedia)
                Handles.hMedia.release;
            end
            if ishandle(Handles.hPlayer)   
                Handles.hPlayer.release;
            end
            
        case 'VideoReader'
            if ~isempty(Handles.hPlayer)
                delete(Handles.hPlayer);
            end
    end
    % Reset fields
    Handles.PlayerType = '';
    Handles.hMedia     = [];
    Handles.hPlayer    = [];
    % Update handles
    bst_figures('SetFigureHandles', hFig, Handles);
end






