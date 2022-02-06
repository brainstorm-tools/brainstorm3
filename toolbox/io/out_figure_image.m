function varargout = out_figure_image( hFig, imgFile, imgLegend)
% OUT_FIGURE_IMAGE: Save window contents as a bitmap image.
%
% USAGE: img = out_figure_image(hFig)           : Extract figure image and return it
%              out_figure_image(hFig, imgFile)  : Extract figure image and save it to imgFile
%              out_figure_image(hFig, 'Viewer') : Extract figure image and open it with the image viewer
%              out_figure_image(hFig, figFile)  : Save figure as a Matlab .fig file after removing some callbacks
%              out_figure_image(hFig, 'Figure') : Copy figure and removes callbacks 
%              out_figure_image(hFig)           : Extract figure image and save it to a user selected file
%              out_figure_image(hFig, ..., imgLegend)
%              out_figure_image(hFig, ..., 'time')

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

global GlobalData;
drawnow;

% No legend: plot the time 
if (nargin < 3)
    imgLegend = 'time';
elseif isempty(imgLegend)
    imgLegend = '';
end

%% ===== GET FILENAME =====
% If image filename is not specified
if (nargin <= 1) && (nargout == 0)
    % === Build a default filename ===
    % Get default directories and format
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    if isempty(DefaultFormats.ImageOut)
        DefaultFormats.ImageOut = 'tif';
    end
    % Get the default filename (from the window title)
    wndTitle = get(hFig, 'Name');
    if isempty(wndTitle)
        imgDefautFile = 'img_default';
    else
        imgDefautFile = file_standardize(wndTitle, 0, '_', 1);
        imgDefautFile = strrep(imgDefautFile, '__', '_');
    end
    % Add extension
    imgDefautFile = [imgDefautFile, '.', lower(DefaultFormats.ImageOut)];
    imgDefautFile = strrep(imgDefautFile, '_.', '.');
    
    % === Ask user filename ===
    % Ask confirmation for the figure filename
    imgDefaultFile = bst_fullfile(LastUsedDirs.ExportImage, imgDefautFile);
    [imgFile, FileFormat] = java_getfile('save', 'Save figure as...', imgDefaultFile, 'single', 'files', ...
        {{'.tif'}, 'TIFF image, compressed (*.tif)',      'TIF'; ...
         {'.jpg'}, 'JPEG image (*.jpg)',                  'JPG'; ...
         {'.bmp'}, 'Bitmap file (*.bmp)',                 'BMP'; ...
         {'.fig'}, 'Matlab figure (*.fig)',               'FIG'; ...
         {'.png'}, 'Portable Network Graphics (*.png)',   'PNG'; ...
         {'.hdf'}, 'Hierarchical Data Format (*.hdf)',    'HDF'; ...
         {'.pbm'}, 'Portable bitmap (*.pbm)',             'PBM'; ...
         {'.pgm'}, 'Portable Graymap (*.pgm)',            'PGM'; ...
         {'.ppm'}, 'Portable Pixmap (*.ppm)',             'PPM';}, DefaultFormats.ImageOut);
    if isempty(imgFile)
        return
    end
    % Save new default export path
    LastUsedDirs.ExportImage = bst_fileparts(imgFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default export format
    DefaultFormats.ImageOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
elseif (nargout == 0)
    [fPath,fBase,fExt] = bst_fileparts(imgFile);
    if ~isempty(fExt)
        FileFormat = upper(fExt(2:end));
    else
        FileFormat = '';
    end
else 
    FileFormat = 'ARRAY';
    imgFile = '';
end

%% ===== PREPARE FIGURE =====
% Get figure Type
[tmp,iFig,iDS] = bst_figures('GetFigure', hFig);
if ~isempty(iDS)
    FigureId = GlobalData.DataSet(iDS).Figure(iFig).Id;
else
    FigureId = [];
end
% If figure is a registered data figure
if ~isempty(iDS) && ~isempty(imgLegend)
    % If 3DAxes => Add a time legend
    if strcmpi(imgLegend, 'time') 
        isAddTime = ~isempty(FigureId) && (strcmpi(FigureId.Type, '3DViz') || strcmpi(FigureId.Type, 'Topography'));
        if isAddTime && ~isempty(GlobalData.UserTimeWindow.CurrentTime)
            if (GlobalData.UserTimeWindow.CurrentTime > 2)
                imgLegend = sprintf('%4.3fs ', GlobalData.UserTimeWindow.CurrentTime);
            else
                imgLegend = sprintf('%dms ', round(GlobalData.UserTimeWindow.CurrentTime * 1000));
            end
        else
            imgLegend = '';
        end
    end
    % Create legend
    if ~isempty(imgLegend)
        % Get figure color
        figColor = get(hFig, 'Color');
        figPos   = get(hFig, 'Position');
        % Find opposite colors
        if (sum(figColor .^ 2) > 0.8)
            textColor = [0 0 0];
        else
            textColor = [.3 1 .3];
        end
        % Create axes
        hAxesLabel = axes(...
            'Parent',        hFig, ...
            'Tag',           'AxesTimestamp', ...
            'Units',         'Pixels', ...
            'Position',      [0, 0, figPos(3), 30], ...
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
        hLabel = text(...
            10 / figPos(3), .5, imgLegend, ...
            'FontUnits',   'points', ...
            'FontWeight',  'bold', ...
            'FontSize',    15, ...
            'Color',       textColor, ...
            'Interpreter', 'none', ...
            'Tag',         'LabelTimestamp', ...
            'Parent',      hAxesLabel);
    end
else
    imgLegend = '';
end
% For time series figures: hide buttons
if ~isempty(FigureId) && ismember(FigureId.Type, {'DataTimeSeries', 'ResultsTimeSeries', 'Spectrum'})
    % Find existing buttons
    if bst_get('isJavacomponent')
        hButtons = findobj(hFig, 'Type', 'hgjavacomponent');
    else
        hButtons = findobj(hFig, 'Type', 'uicontrol');
        if (length(hButtons) > 1)
            hButtons(cellfun(@(c)isempty(strfind(c, 'Button')), get(hButtons, 'Tag'))) = [];
        elseif (length(hButtons) == 1) && isempty(strfind(get(hButtons, 'Tag'), 'Button'))
            hButtons = [];
        end
    end
    isVisible = get(hButtons, 'Visible');
    % Hide them
    set(hButtons, 'Visible', 'off');
else
    hButtons = [];
end
% Focus on figure (captures the contents the topmost figure)
pause(.01);
drawnow;
figure(hFig);
drawnow;


%% ===== SAVE FIGURE =====
if (~isempty(FileFormat) && strcmpi(FileFormat, 'FIG')) || strcmpi(imgFile, 'Figure')
    % === PREPARE FIGURE ===
    % Check figure type
    if ~isempty(FigureId) && ((strcmpi(FigureId.Type, 'Topography') && strcmpi(FigureId.SubType, '2DLayout')) || strcmpi(FigureId.Type, 'Connect') || strcmpi(FigureId.Type, 'MriViewer'))
        bst_error('This figure cannot be exported as a Matlab .fig file.', 'Save figure', 0);
        return;
    end
    % Ask use to remove callbacks or not
    if strcmpi(imgFile, 'Figure')
        isRemoveCallbacks = 0;
    else
        isRemoveCallbacks = java_dialog('confirm', ...
            ['If you save the figure with all the callback functions, you will' 10 ...
             'keep the interactivity of the figure but you will need to have ' 10 ...
             'the same version of Brainstorm running to open it again.' 10 10 ... 
             'Remove callbacks from the figure?' 10], 'Save figure');
    end
    
    % Save existing callbacks
    CloseRequestFcn_bak       = get(hFig, 'CloseRequestFcn');
    KeyPressFcn_bak           = get(hFig, 'KeyPressFcn');
    WindowButtonDownFcn_bak   = get(hFig, 'WindowButtonDownFcn');
    WindowButtonMotionFcn_bak = get(hFig, 'WindowButtonMotionFcn');
    WindowButtonUpFcn_bak     = get(hFig, 'WindowButtonUpFcn');
    ResizeFcn_bak             = get(hFig, 'ResizeFcn');
    if isprop(hFig, 'KeyReleaseFcn')
        KeyReleaseFcn_bak = get(hFig, 'KeyReleaseFcn');
    end
    if isprop(hFig, 'WindowScrollWheelFcn')
        WindowScrollWheelFcn_bak = get(hFig, 'WindowScrollWheelFcn');
    end
    
    % Remove callbacks that crash without Brainstorm
    set(hFig, 'CloseRequestFcn', 'closereq');
    set(hFig, 'KeyPressFcn', []);
    if isprop(hFig, 'KeyReleaseFcn')
        set(hFig, 'KeyReleaseFcn', []);
    end
    % Remove other callbacks
    if isRemoveCallbacks
        set(hFig, 'WindowButtonDownFcn', []);
        set(hFig, 'WindowButtonMotionFcn', []);
        set(hFig, 'WindowButtonUpFcn', []);
        set(hFig, 'ResizeFcn', []);
        if isprop(hFig, 'WindowScrollWheelFcn')
            set(hFig, 'WindowScrollWheelFcn', []);
        end
    end
    % Find colorbar
    hColorbar = findobj(hFig, '-depth', 1, 'Tag', 'Colorbar');
    if ~isempty(hColorbar)
        ColorbarButton_bak = get(hColorbar, 'ButtonDownFcn');
        set(hColorbar, 'ButtonDownFcn', []);
    end
    % Display figure toolbar
    set(hFig, 'MenuBar', 'figure', 'ToolBar', 'auto');
    
    % Copy figure
    if strcmpi(imgFile, 'Figure')
        % Copy graphic objects
        hNewFig = copyobj(hFig, 0);
        % Copy callbacks
        set(hNewFig, 'CloseRequestFcn',       'closereq');
        set(hNewFig, 'KeyPressFcn',           []);
        set(hNewFig, 'WindowButtonDownFcn',   WindowButtonDownFcn_bak);
        set(hNewFig, 'WindowButtonMotionFcn', WindowButtonMotionFcn_bak);
        set(hNewFig, 'WindowButtonUpFcn',     WindowButtonUpFcn_bak);
        set(hNewFig, 'ResizeFcn',             ResizeFcn_bak);
        if isprop(hNewFig, 'KeyReleaseFcn')
            set(hNewFig, 'KeyReleaseFcn', []);
        end
        if isprop(hNewFig, 'WindowScrollWheelFcn')
            set(hNewFig, 'WindowScrollWheelFcn', WindowScrollWheelFcn_bak);
        end
        % Copy appdata
        AppData = getappdata(hFig);
        fields = fieldnames(AppData);
        for i = 1:length(fields)
            setappdata(hNewFig, fields{i}, AppData.(fields{i}));
        end
        % Reposition figure
        set(hNewFig, 'Position', get(hNewFig, 'Position') - [0, 70, 0, 0]);
    % Save figure
    else
        saveas(hFig, imgFile, 'fig');
    end
    
    % === RESTORE FIGURE ===
    % Restore common callbacks
    set(hFig, 'CloseRequestFcn', CloseRequestFcn_bak);
    set(hFig, 'KeyPressFcn',     KeyPressFcn_bak);
    if isprop(hFig, 'KeyReleaseFcn')
        set(hFig, 'KeyReleaseFcn', KeyReleaseFcn_bak);
    end
    % Restore colobar
    if ~isempty(hColorbar)
        set(hColorbar, 'ButtonDownFcn', ColorbarButton_bak);
    end
    % Restore optional callbaks
    if isRemoveCallbacks
        set(hFig, 'WindowButtonDownFcn',   WindowButtonDownFcn_bak);
        set(hFig, 'WindowButtonMotionFcn', WindowButtonMotionFcn_bak);
        set(hFig, 'WindowButtonUpFcn',     WindowButtonUpFcn_bak);
        set(hFig, 'ResizeFcn',             ResizeFcn_bak);
        if isprop(hFig, 'WindowScrollWheelFcn')
            set(hFig, 'WindowScrollWheelFcn',  WindowScrollWheelFcn_bak);
        end
    end
    % Remove figure toolbar
    set(hFig, 'MenuBar', 'none', 'ToolBar', 'none');
    
    
% ===== SAVE IMAGE =====
else
    % If figure contains a video in an ActiveX control: must be extracted with screencapture()
    isForceScreencapture = ~isempty(FigureId) && strcmpi(FigureId.Type, 'Video') && ~isempty(iDS) && ismember(GlobalData.DataSet(iDS).Figure(iFig).Handles.PlayerType, {'VLC', 'WMPlayer'});
    % Headless display: we must print the figure 
    if (GlobalData.Program.GuiLevel == -1)
        frameGfx.cdata = print(hFig, '-noui', '-r0', '-RGBImage');        
    % Get figure bitmap
    elseif (bst_get('MatlabVersion') >= 804) && ~isForceScreencapture
        % Matlab function getframe() was finally fixed in R2014b
        frameGfx = getframe(hFig);
        % MRI Viewer: We need to update the figure to redraw all the java objects
        if ~isempty(FigureId) && strcmpi(FigureId.Type, 'MriViewer')
            figure_mri('ResizeCallback', hFig);
        end
    else
        % frameGfx = getscreen(hFig);
        figPos = get(hFig, 'Position');
        decoSize = bst_get('DecorationSize');
        % Get the screen definition 
        ScreenDef = bst_get('ScreenDef');
        % Single screen (TODO: Handle the cases where the two screens are organized in different ways)
        if (length(ScreenDef) == 1)
            ZoomFactor = ScreenDef(1).zoomFactor;
        elseif (figPos(1) < ScreenDef(1).matlabPos(1) + ScreenDef(1).matlabPos(3))
            ZoomFactor = ScreenDef(1).zoomFactor;
        else
            ZoomFactor = ScreenDef(2).zoomFactor;
        end
        % Altman's screencapture doesn't work with ZoomFactor higher than 1
        if (ZoomFactor > 1.01)
            figFix   = round(figPos .* ZoomFactor);
            decoSize = round(decoSize .* ZoomFactor);
            capturePos = [figFix(1) - figPos(1) + decoSize(1), ...
                          -figFix(4) + figPos(4) + decoSize(4), ...
                          figFix(3) - decoSize(3) + 1, ...
                          figFix(4) - decoSize(4)];            
        else
            capturePos = [decoSize(1), ...
                          decoSize(4), ...
                          figPos(3), ...
                          figPos(4)];
        end
        % Capture figure
        frameGfx.cdata = screencapture(hFig, capturePos);
    end
    % Save image file or return it in argument
    if (nargout == 0) && ~isempty(imgFile)
        if strcmpi(imgFile, 'Viewer')
            view_image(frameGfx.cdata);
        else
            out_image(imgFile, frameGfx.cdata);
        end
    else
        varargout{1} = frameGfx.cdata;
    end
end


%% ===== RESTORE IMAGE ======
% Delete created label
if ~isempty(imgLegend)
    delete(hAxesLabel);
end
% Show the buttons again
if ~isempty(hButtons)
    for i = 1:length(hButtons)
        set(hButtons(i), 'Visible', isVisible{i});
    end
end







