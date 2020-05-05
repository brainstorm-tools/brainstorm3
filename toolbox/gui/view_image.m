function hFig = view_image(img, cmap, windowName, defaultFile, clickCallback)
% VIEW_IMAGE: Display an indexed image.
%
% USAGE:  view_image(img [, cmap | cmapname] [, windowName] [, defaultFile])
%
% INPUT:
%     - img          : 2D-image to display (indexed color image or RGB)
%                      or filename to an image file (RGB)
%     - windowName   : (optional) String displayed in the title bar of the window (default : 'viewImage')
%     - colormapName :(optional) name of the colormap used to display the image (default : gray)
%                      Can be any of the colormap functions of Matlab
%     - cmap         : exact colormap to display the image (cannot be modified with the interface)
%     - defaultFile  : default filename while saving image
%     - clickCallback: Function called when clicking on the image (no move, left click)
%
% OUTPUT: 
%     - hFig : object handle to the figure opened to display the image

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2006 (University of Geneva), 2008-2010 (USC), 2012-2012 (McGill)
            
%% ===== PARSE INPUTS =====
% Defaults
colormapContrast = 256;
hFig = [];

% Arg #1 : img
% If input is a filename
if ischar(img)
    [img, cmap] = imread(img);
    colormapName = [];
end
% Is loaded image an RGB or an Indexed image ?
if (size(img,3) == 3)
    isRGB = 1;
else
    isRGB = 0;
end

% Arg #2 : cmap or cmapname
if (nargin < 2) || isempty(cmap)
    colormapName = 'bone';
    cmap = [];
elseif ischar(cmap)
    colormapName = cmap;
    cmap = [];
else
    colormapName = '';
end
% Arg #3 : windowName
if (nargin < 3)  || isempty(windowName)
    windowName = 'View image';
elseif (length(windowName) > 55)
    windowName = [windowName(1:55) '...'];
end
% Arg #4 : defaultFile
if (nargin < 4) || isempty(defaultFile)
    defaultFile = 'figure.tif';
end
% Arg #5: clickCallback
if (nargin < 5) || isempty(clickCallback)
    clickCallback = [];
end


%% -------- MAIN : Figure configuration -------------------------------
% --------------------------------------------------------------------- 
% Mouse management initialization
isClicked = 0;
isMoved = 0;
clickPositionFigure = [0 0];
isWindowInitialized = 0;

% Calculate optimal reduction
imageDims = size(img);
reduction = 1;
if (max(imageDims)<550)
%     while (max(imageDims) * reduction < 550 && reduction<6)
%         reduction = reduction + 1;
%     end
%     reduction = 1./reduction;
else
    while (max(imageDims) / reduction > 800)
        reduction = reduction + 1;
    end
end

% Brainstorm is running: Center on the available figure area
if isappdata(0, 'BrainstormRunning') && bst_get('isGUI')
    [jBstArea, FigArea] = gui_layout('GetScreenBrainstormAreas');
    scrSize = FigArea;
% Center the window on the screen (at 30% from the left and 30% from the top)
else
    scrSize = get(0, 'ScreenSize');
end
figurePos = [1, 1, round(imageDims(2)./reduction), round(imageDims(1)./reduction)];
figurePos(1:2) = scrSize(1:2) + round((scrSize(3:4) - figurePos(3:4)).*[.3 .7]);
figurePos = max(1,figurePos);

% Open figure
hFig = figure(...
    'Name',                    sprintf('%s (%d%%)',windowName, round(1./reduction*100)), ...
    'NumberTitle',             'off', ...
    'IntegerHandle',           'off', ...
    'Units',                   'pixels', ...
    'Position',                figurePos, ...
    'WindowButtonDownFcn',     @imageMouseClick_Callback, ...
    'WindowButtonMotionFcn',   @imageMouseMove_Callback, ...
    'WindowButtonUpFcn',       @imageMouseRelease_Callback, ...
    bst_get('ResizeFunction'), @ResizeFcn_Callback, ...
    'Color',                   [0 0 0], ...
    'Pointer',                 'arrow', ...
    'Toolbar',                 'none', ...
    'Menubar',                 'none', ...
    'DockControls',            'on');

% Define Mouse wheel callback separately (not supported by old versions of Matlab)
if isprop(hFig, 'WindowScrollWheelFcn')
    set(hFig, 'WindowScrollWheelFcn', @imageMouseWheel_Callback);
end

% Add File->Save as... menu
hMenu = uimenu('Label', 'File');
    uimenu(hMenu, 'Label', 'Save as...', 'Accelerator', 's', 'Callback', @(h,ev)out_figure_image(hFig));
    uimenu(hMenu, 'Label', 'Close', 'Accelerator', 'q', 'Callback', @menuFileClose_Callback);

% Zoom menu
hMenu = uimenu('Label', 'Zoom');
    uimenu(hMenu, 'Label', '200%', 'Callback', @(h,ev)SetZoomFactor(2));
    uimenu(hMenu, 'Label', '100%', 'Callback', @(h,ev)SetZoomFactor(1));
    uimenu(hMenu, 'Label', '50%',  'Callback', @(h,ev)SetZoomFactor(.5));
    uimenu(hMenu, 'Label', '25%',  'Callback', @(h,ev)SetZoomFactor(.25));
    uimenu(hMenu, 'Label', '10%',  'Callback', @(h,ev)SetZoomFactor(.10));
    
% Add colormap menu (Indexed images only)
if ~isRGB
    hMenu = uimenu('Label', 'Colormap');
    hItemGray   = uimenu(hMenu, 'Label', 'Gray',   'UserData', 'gray',   'Callback', @colormap_Callback);
    hItemBone   = uimenu(hMenu, 'Label', 'Bone',   'UserData', 'bone',   'Callback', @colormap_Callback);
    hItemCopper = uimenu(hMenu, 'Label', 'Copper', 'UserData', 'copper', 'Callback', @colormap_Callback);
    hItemHot    = uimenu(hMenu, 'Label', 'Hot',    'UserData', 'hot',    'Callback', @colormap_Callback);
    hItemPink   = uimenu(hMenu, 'Label', 'Pink',   'UserData', 'pink',   'Callback', @colormap_Callback);
    hItemAutumn = uimenu(hMenu, 'Label', 'Autumn', 'UserData', 'autumn', 'Callback', @colormap_Callback);
    hItemSpring = uimenu(hMenu, 'Label', 'Spring', 'UserData', 'spring', 'Callback', @colormap_Callback);
    hItemSummer = uimenu(hMenu, 'Label', 'Summer', 'UserData', 'summer', 'Callback', @colormap_Callback);
    hItemWinter = uimenu(hMenu, 'Label', 'Winter', 'UserData', 'winter', 'Callback', @colormap_Callback);
    hItemCool   = uimenu(hMenu, 'Label', 'Cool',   'UserData', 'cool',   'Callback', @colormap_Callback);
    hItemHsv    = uimenu(hMenu, 'Label', 'Hsv',    'UserData', 'hsv',    'Callback', @colormap_Callback);
    hItemJet    = uimenu(hMenu, 'Label', 'Jet',    'UserData', 'jet',    'Callback', @colormap_Callback);
    uimenu(hMenu, 'Label', 'Edit colormap...',  'Callback', @editColormap_Callback);
end

% Display image
imageHandle = image(img, 'CDataMapping', 'scaled');
hAxes = get(imageHandle, 'Parent');
set(hAxes, 'Units', 'normalized', ...
    'Position', [0 0 1 1]);
axis image off;
grid off;
zoom reset;

% Indexed image : initialize colormap
if ~isRGB
    % If a colormap was not defined in command line (colormapName ~= [])
    if ~isempty(colormapName)
        % Try to get the colormap matrix
        try 
            cmap = eval(sprintf('%s(%d);', colormapName, colormapContrast));
        % If the called function does not exist, use the colormap default (gray)
        catch
            colormapName = 'gray';
            cmap = eval(sprintf('%s(%d);', colormapName, colormapContrast));
            set(hItemGray, 'Checked', 'on');
        end
        % Try to check the correspondant menu in the colormap Menu
        try
            cmapMaj = lower(cmap);
            cmapMaj(1) = upper(cmapMaj(1));
            set(eval(['hItem' cmapMaj]), 'Checked', 'on');
        catch
        end
    end
    colormap(cmap);
end

% Set window as initialized
isWindowInitialized = 1;




    %% -------- CLOSE FIGURE ----------------------------------------------
    % ---------------------------------------------------------------------
    function menuFileClose_Callback(hObject, ev)
       close(gcf); 
    end


    %% -------- Mouse and keyboard management functions -------------------
    % ---------------------------------------------------------------------    
    % Callback executed when a mouse button is clicked on the image
    function imageMouseClick_Callback(hObject, ev)
        % Called when the user clicks somewhere on the image
        % => Record mouse position and action type (simple or double click)
        isClicked = 1;
        temp = get(hFig, 'CurrentPoint');
        clickPositionFigure = temp(1,1:2);
        % Double click
        switch(lower(get(hFig, 'SelectionType')))
            case 'open'
                axis([0 imageDims(2) 0 imageDims(1)]+.5);
                updateWindowName();
        end
    end

    % Callback executed when the mouse cursor is moved over the figure window
    function imageMouseMove_Callback(hObject, ev)
        % Called when the user moves the mouse above the figure (that contains
        % the image). If a mouse button is pressed, perform the needed action :
        %    - Left click : move in the image space (if image is larger than figure)
        %    - Right click OR CTRL+Click: Change color scale (adjust contrast/brightness)
        %    - Middle click OR Left+right click OR SHIFT+Click : Zoom
        if (isClicked == 1)
            isMoved = 1;
            curpt = get(hFig, 'CurrentPoint');
            mouseMotionFigure = clickPositionFigure - curpt(1,1:2);
            clickPositionFigure = curpt(1,1:2);
            xlim = get(hAxes, 'XLim');
            ylim = get(hAxes, 'YLim');
            switch(lower(get(hFig, 'SelectionType')))
                case 'normal' % Left click : move
                    xmin = max(0,xlim(1)+mouseMotionFigure(1)*2);
                    xmax = xmin + (xlim(2)-xlim(1));
                    if (xmax > imageDims(2))
                        xmin = xmin - (xmax - imageDims(2));
                        xmax = imageDims(2);
                    end
                    ymin = max(0,ylim(1)-mouseMotionFigure(2)*2);
                    ymax = ymin + (ylim(2)-ylim(1));
                    if (ymax > imageDims(1))
                        ymin = ymin - (ymax - imageDims(1));
                        ymax = imageDims(1);
                    end
                    axis([xmin xmax ymin ymax] + 0.5);

                case 'alt' % (Control + Left click) or right click : Change color scale
                    % Increase/decrease image contrast
                    colormapContrast = max(5, min(505, colormapContrast + mouseMotionFigure(2)));
                    fncUpdateColormap(colormapName, colormapContrast);

                case 'extend' % (SHIFT + Left click) or middle click

                case 'open' % Double click

            end
        end
        drawnow;
    end

    % Callback executed when a mouse button is released
    function imageMouseRelease_Callback(hObject, ev)
        % If pointer was not moved, left click, and callback function defined
        if isClicked && ~isMoved && strcmpi(get(hFig, 'SelectionType'), 'normal') && ~isempty(clickCallback)
            % Get coordinates
            curpt = get(hAxes, 'CurrentPoint');
            xy = round(curpt(1,[2,1]));
            % Check click position
            if any(xy <= 0) || (xy(1) > size(img,1)) || (xy(2) > size(img,2))
                return;
            end
            % Call function
            clickCallback(hFig, xy);
        end
        % Re-initialize window variables
        isClicked = 0;
        isMoved = 0;
    end

    % Mouse wheel callback
    function imageMouseWheel_Callback(hObject, ev)
        % Define the zoom factor
        if isempty(ev)
            return;
        elseif (ev.VerticalScrollCount < 0)
            % ZOOM IN
            Factor = 1 - double(ev.VerticalScrollCount) ./ 20;
        elseif (ev.VerticalScrollCount > 0)
            % ZOOM OUT
            Factor = 1./(1 + double(ev.VerticalScrollCount) ./ 20);
        else
            return;
        end

        % ZOOM
        xlim = get(hAxes, 'XLim');
        ylim = get(hAxes, 'YLim');
        width = (xlim(2) - xlim(1)) / Factor;
        height = (ylim(2) - ylim(1)) / Factor;

        if(width >= imageDims(2))
            xmin = 0;
            xmax = imageDims(2);
        else
            xmin = max(0, xlim(1) + ((xlim(2) - xlim(1)) - width)./2);
            xmax = xmin + width;
            % Test if bounds are corrects
            if(xmax > imageDims(2))
                xmin = xmin - (xmax - imageDims(2));
                xmax = imageDims(2);
            end
        end

        if(height >= imageDims(1))
            ymin = 0;
            ymax = imageDims(1);
        else
            ymin = max(0, ylim(1) + ((ylim(2) - ylim(1)) - height)./2);
            ymax = ymin + height;
            % Test if bounds are corrects
            if(ymax > imageDims(1))
                ymin = ymin - (ymax - imageDims(1));
                ymax = imageDims(1);
            end
        end

        if ((nnz(isnan([xmin xmax ymin ymax])) == 0) && (nnz([xmin xmax ymin ymax]<0) == 0) && (xmin < xmax) && (ymin < ymax))
            axis([xmin xmax ymin ymax]);
            updateWindowName();
        end
    end


    %% -------- Window callbacks ------------------------------------------
    % ---------------------------------------------------------------------    
    function ResizeFcn_Callback(hObject, ev)
        if (isWindowInitialized)
            updateWindowName();
        end
    end

    function updateWindowName()
        set(hFig, 'Name', sprintf('%s (%d%%)',windowName, round(GetZoomFactor()*100)));
    end



    %% -------- Colormap functions ----------------------------------------
    % ---------------------------------------------------------------------    
    % From colormap menu
    function colormap_Callback(hObject, ev)
        set([hItemGray, hItemBone, hItemCopper, hItemHot, hItemPink, ...
             hItemAutumn, hItemSpring, hItemSummer, hItemWinter, ...
             hItemCool, hItemHsv, hItemJet], 'Checked', 'off');
        set(hObject, 'Checked', 'on');
        colormapName = get(hObject, 'UserData');
        fncUpdateColormap(colormapName, colormapContrast);
    end

    % Edit colormap
    function editColormap_Callback(hObject, ev)
        colormapeditor;
    end


    %% -------- Zoom management functions ---------------------------------
    % ---------------------------------------------------------------------    
    function f = GetZoomFactor()
        % Get all the sizes
        imgSize = size(img);
        imgSize = imgSize([2 1]);
        axesXLim = get(hAxes,'XLim');
        axesYLim = get(hAxes,'YLim');
        axesSize = [axesXLim(2)-axesXLim(1), axesYLim(2)-axesYLim(1)];
        figureSize = get(hFig, 'Position');
        figureSize = figureSize(3:4);

        % Get the dimension (x or y) where the axes fit exactly the figure window
        axesTightInset = get(hAxes, 'TightInset')./[imgSize imgSize].*1000;
        [m,dim] = max([axesTightInset(1)+axesTightInset(3), axesTightInset(2)+axesTightInset(4)]);

        % Calculate zoom factor
        % f1 : zoom due to window size
        %f1 = figureSize(dim)/imgSize(dim)
        % f2 : zoom due to user actions with mouse
        %f2 = imgSize(dim)/axesSize(dim)
        % f = f1*f2
        f = figureSize(dim)/axesSize(dim);
    end

    function SetZoomFactor(fTarget)   
        % Get current zoom factor
        fCurrent = GetZoomFactor();
        nbMaxLoop = 100;
        iLoop = 1;
        % If need to zoom
        if (fCurrent < fTarget)
            % If figure can be resized
            while (abs(fTarget - fCurrent) > 0.001) && (iLoop < nbMaxLoop)
                ev.VerticalScrollCount = -abs(fTarget - fCurrent) * 10;
                imageMouseWheel_Callback(hFig, ev);
                fCurrent = GetZoomFactor();
                iLoop = iLoop + 1;
                drawnow
            end
        % Else, need to unzoom
        else
            % Get all needed dimensions
            imgSize = size(img);
            imgSize = imgSize([2 1]);
            figurePos = get(hFig, 'Position');
            % Check if figure needs to be resized
            if (imgSize(1)*fTarget < figurePos(3)) || (imgSize(2)*fTarget < figurePos(4))
                % Resize figure
                figurePos(3:4) = round(imgSize*fTarget);
                set(hFig, 'Position', figurePos);
                % Unzoom
                ev.VerticalScrollCount = 1000;
                imageMouseWheel_Callback(hFig, ev);

            % Else : juste unzoom
            else 
                while (abs(fTarget - fCurrent) > 0.001) && (iLoop < nbMaxLoop)
                    ev.VerticalScrollCount = abs(fTarget - fCurrent) * 10;
                    imageMouseWheel_Callback(hFig, ev);
                    fCurrent = GetZoomFactor();
                    iLoop = iLoop + 1;
                    drawnow
                end
            end
        end
    end

end


%% -------- Colormap and constrast functions --------------------------
% ---------------------------------------------------------------------    
% Update colormap
function fncUpdateColormap(colormapName, colormapContrast)
    % If a colormap was not defined in command line (colormapName ~= [])
    if ~isempty(colormapName)
        mapFunc = str2func(lower(colormapName));
        % Between 0 and 256 : fill the map with the top color of the colormap (bright)
        if (colormapContrast <= 256)
            map = mapFunc(colormapContrast);
            nmap = repmat(map(colormapContrast,:),256,1);
            nmap(1:colormapContrast, :) = map;
        % Between 256 and 512 : fill the map with the bottom color of the colormap (dark)
        else 
            map = mapFunc(256 - mod(colormapContrast, 256));
            nmap = repmat(map(1,:),256,1);
            nmap(257-length(map):256, :) = map;
        end
        colormap(nmap);
    end
end


