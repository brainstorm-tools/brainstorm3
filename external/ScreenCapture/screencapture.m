function imageData = screencapture(varargin)
% screencapture - get a screen-capture of a figure frame, component handle, or screen area rectangle
%
% ScreenCapture gets a screen-capture of any Matlab GUI handle (including desktop, 
% figure, axes, image or uicontrol), or a specified area rectangle located relative to
% the specified handle. Screen area capture is possible by specifying the root (desktop)
% handle (=0). The output can be either to an image file or to a Matlab matrix (useful
% for displaying via imshow() or for further processing) or to the system clipboard.
% This utility also enables adding a toolbar button for easy interactive screen-capture.
%
% Syntax:
%    imageData = screencapture(handle, position, target, 'PropName',PropValue, ...)
%
% Input Parameters:
%    handle   - optional handle to be used for screen-capture origin.
%                 If empty/unsupplied then current figure (gcf) will be used.
%    position - optional position array in pixels: [x,y,width,height].
%                 If empty/unsupplied then the handle's position vector will be used.
%                 If both handle and position are empty/unsupplied then the position
%                   will be retrieved via interactive mouse-selection.
%                 If handle is an image, then position is in data (not pixel) units, so the
%                   captured region remains the same after figure/axes resize (like imcrop)
%    target   - optional filename for storing the screen-capture, or the
%               'clipboard'/'printer' strings.
%                 If empty/unsupplied then no output to file will be done.
%                 The file format will be determined from the extension (JPG/PNG/...).
%                 Supported formats are those supported by the imwrite function.
%    'PropName',PropValue - 
%               optional list of property pairs (e.g., 'target','myImage.png','pos',[10,20,30,40],'handle',gca)
%               PropNames may be abbreviated and are case-insensitive.
%               PropNames may also be given in whichever order.
%               Supported PropNames are:
%                 - 'handle'    (default: gcf handle)
%                 - 'position'  (default: gcf position array)
%                 - 'target'    (default: '')
%                 - 'toolbar'   (figure handle; default: gcf)
%                      this adds a screen-capture button to the figure's toolbar
%                      If this parameter is specified, then no screen-capture
%                        will take place and the returned imageData will be [].
%
% Output parameters:
%    imageData - image data in a format acceptable by the imshow function
%                  If neither target nor imageData were specified, the user will be
%                    asked to interactively specify the output file.
%
% Examples:
%    imageData = screencapture;  % interactively select screen-capture rectangle
%    imageData = screencapture(hListbox);  % capture image of a uicontrol
%    imageData = screencapture(0,  [20,30,40,50]);  % capture a small desktop region
%    imageData = screencapture(gcf,[20,30,40,50]);  % capture a small figure region
%    imageData = screencapture(gca,[10,20,30,40]);  % capture a small axes region
%      imshow(imageData);  % display the captured image in a matlab figure
%      imwrite(imageData,'myImage.png');  % save the captured image to file
%    img = imread('cameraman.tif');
%      hImg = imshow(img);
%      screencapture(hImg,[60,35,140,80]);  % capture a region of an image
%    screencapture(gcf,[],'myFigure.jpg');  % capture the entire figure into file
%    screencapture(gcf,[],'clipboard');     % capture the entire figure into clipboard
%    screencapture(gcf,[],'printer');       % print the entire figure
%    screencapture('handle',gcf,'target','myFigure.jpg'); % same as previous, save to file
%    screencapture('handle',gcf,'target','clipboard');    % same as previous, copy to clipboard
%    screencapture('handle',gcf,'target','printer');      % same as previous, send to printer
%    screencapture('toolbar',gcf);  % adds a screen-capture button to gcf's toolbar
%    screencapture('toolbar',[],'target','sc.bmp'); % same with default output filename
%
% Technical description:
%    http://UndocumentedMatlab.com/blog/screencapture-utility/
%
% Bugs and suggestions:
%    Please send to Yair Altman (altmany at gmail dot com)
%
% See also:
%    imshow, imwrite, print
%
% Release history:
%    1.17 2016-05-16: Fix annoying warning about JavaFrame property becoming obsolete someday (yes, we know...)
%    1.16 2016-04-19: Fix for deployed application suggested by Dwight Bartholomew
%    1.10 2014-11-25: Added the 'print' target
%    1.9  2014-11-25: Fix for saving GIF files
%    1.8  2014-11-16: Fixes for R2014b
%    1.7  2014-04-28: Fixed bug when capturing interactive selection
%    1.6  2014-04-22: Only enable image formats when saving to an unspecified file via uiputfile
%    1.5  2013-04-18: Fixed bug in capture of non-square image; fixes for Win64
%    1.4  2013-01-27: Fixed capture of Desktop (root); enabled rbbox anywhere on desktop (not necesarily in a Matlab figure); enabled output to clipboard (based on Jiro Doke's imclipboard utility); edge-case fixes; added Java compatibility check
%    1.3  2012-07-23: Capture current object (uicontrol/axes/figure) if w=h=0 (e.g., by clicking a single point); extra input args sanity checks; fix for docked windows and image axes; include axes labels & ticks by default when capturing axes; use data-units position vector when capturing images; many edge-case fixes
%    1.2  2011-01-16: another performance boost (thanks to Jan Simon); some compatibility fixes for Matlab 6.5 (untested)
%    1.1  2009-06-03: Handle missing output format; performance boost (thanks to Urs); fix minor root-handle bug; added toolbar button option
%    1.0  2009-06-02: First version posted on <a href="http://www.mathworks.com/matlabcentral/fileexchange/authors/27420">MathWorks File Exchange</a>

% License to use and modify this code is granted freely to all interested, as long as the original author is
% referenced and attributed as such. The original author maintains the right to be solely associated with this work.

% Programmed and Copyright by Yair M. Altman: altmany(at)gmail.com
% $Revision: 1.17 $  $Date: 2016/05/16 17:59:36 $

    % Ensure that java awt is enabled...
    if ~usejava('awt')
        error('YMA:screencapture:NeedAwt','ScreenCapture requires Java to run.');
    end

    % Ensure that our Java version supports the Robot class (requires JVM 1.3+)
    try
        robot = java.awt.Robot; %#ok<NASGU>
    catch
        uiwait(msgbox({['Your Matlab installation is so old that its Java engine (' version('-java') ...
                        ') does not have a java.awt.Robot class. '], ' ', ...
                        'Without this class, taking a screen-capture is impossible.', ' ', ...
                        'So, either install JVM 1.3 or higher, or use a newer Matlab release.'}, ...
                        'ScreenCapture', 'warn'));
        if nargout, imageData = [];  end
        return;
    end

    % Process optional arguments
    paramsStruct = processArgs(varargin{:});
    
    % If toolbar button requested, add it and exit
    if ~isempty(paramsStruct.toolbar)
        
        % Add the toolbar button
        addToolbarButton(paramsStruct);
        
        % Return the figure to its pre-undocked state (when relevant)
        redockFigureIfRelevant(paramsStruct);
        
        % Exit immediately (do NOT take a screen-capture)
        if nargout,  imageData = [];  end
        return;
    end
    
    % Convert position from handle-relative to desktop Java-based pixels
    [paramsStruct, msgStr] = convertPos(paramsStruct);
    
    % Capture the requested screen rectangle using java.awt.Robot
    imgData = getScreenCaptureImageData(paramsStruct.position);
    
    % Return the figure to its pre-undocked state (when relevant)
    redockFigureIfRelevant(paramsStruct);
    
    % Save image data in file or clipboard, if specified
    if ~isempty(paramsStruct.target)
        if strcmpi(paramsStruct.target,'clipboard')
            if ~isempty(imgData)
                imclipboard(imgData);
            else
                msgbox('No image area selected - not copying image to clipboard','ScreenCapture','warn');
            end
        elseif strncmpi(paramsStruct.target,'print',5)  % 'print' or 'printer'
            if ~isempty(imgData)
                hNewFig = figure('visible','off');
                imshow(imgData);
                print(hNewFig);
                delete(hNewFig);
            else
                msgbox('No image area selected - not printing screenshot','ScreenCapture','warn');
            end
        else  % real filename
            if ~isempty(imgData)
                imwrite(imgData,paramsStruct.target);
            else
                msgbox(['No image area selected - not saving image file ' paramsStruct.target],'ScreenCapture','warn');
            end
        end
    end

    % Return image raster data to user, if requested
    if nargout
        imageData = imgData;
        
    % If neither output formats was specified (neither target nor output data)
    elseif isempty(paramsStruct.target) & ~isempty(imgData)  %#ok ML6
        % Ask the user to specify a file
        %error('YMA:screencapture:noOutput','No output specified for ScreenCapture: specify the output filename and/or output data');
        %format = '*.*';
        formats = imformats;
        for idx = 1 : numel(formats)
            ext = sprintf('*.%s;',formats(idx).ext{:});
            format(idx,1:2) = {ext(1:end-1), formats(idx).description}; %#ok<AGROW>
        end
        [filename,pathname] = uiputfile(format,'Save screen capture as');
        if ~isequal(filename,0) & ~isequal(pathname,0)  %#ok Matlab6 compatibility
            try
                filename = fullfile(pathname,filename);
                imwrite(imgData,filename);
            catch  % possibly a GIF file that requires indexed colors
                [imgData,map] = rgb2ind(imgData,256);
                imwrite(imgData,map,filename);
            end
        else
            % TODO - copy to clipboard
        end
    end

    % Display msgStr, if relevant
    if ~isempty(msgStr)
        uiwait(msgbox(msgStr,'ScreenCapture'));
        drawnow; pause(0.05);  % time for the msgbox to disappear
    end

    return;  % debug breakpoint

%% Process optional arguments
function paramsStruct = processArgs(varargin)

    % Get the properties in either direct or P-V format
    [regParams, pvPairs] = parseparams(varargin);

    % Now process the optional P-V params
    try
        % Initialize
        paramName = [];
        paramsStruct = [];
        paramsStruct.handle = [];
        paramsStruct.position = [];
        paramsStruct.target = '';
        paramsStruct.toolbar = [];
        paramsStruct.wasDocked = 0;       % no false available in ML6
        paramsStruct.wasInteractive = 0;  % no false available in ML6

        % Parse the regular (non-named) params in recption order
        if ~isempty(regParams) & (isempty(regParams{1}) | ishandle(regParams{1}(1)))  %#ok ML6
            paramsStruct.handle = regParams{1};
            regParams(1) = [];
        end
        if ~isempty(regParams) & isnumeric(regParams{1}) & (length(regParams{1}) == 4)  %#ok ML6
            paramsStruct.position = regParams{1};
            regParams(1) = [];
        end
        if ~isempty(regParams) & ischar(regParams{1})  %#ok ML6
            paramsStruct.target = regParams{1};
        end

        % Parse the optional param PV pairs
        supportedArgs = {'handle','position','target','toolbar'};
        while ~isempty(pvPairs)

            % Disregard empty propNames (may be due to users mis-interpretting the syntax help)
            while ~isempty(pvPairs) & isempty(pvPairs{1})  %#ok ML6
                pvPairs(1) = [];
            end
            if isempty(pvPairs)
                break;
            end

            % Ensure basic format is valid
            paramName = '';
            if ~ischar(pvPairs{1})
                error('YMA:screencapture:invalidProperty','Invalid property passed to ScreenCapture');
            elseif length(pvPairs) == 1
                if isempty(paramsStruct.target)
                    paramsStruct.target = pvPairs{1};
                    break;
                else
                    error('YMA:screencapture:noPropertyValue',['No value specified for property ''' pvPairs{1} '''']);
                end
            end

            % Process parameter values
            paramName  = pvPairs{1};
            if strcmpi(paramName,'filename')  % backward compatibility
                paramName = 'target';
            end
            paramValue = pvPairs{2};
            pvPairs(1:2) = [];
            idx = find(strncmpi(paramName,supportedArgs,length(paramName)));
            if ~isempty(idx)
                %paramsStruct.(lower(supportedArgs{idx(1)})) = paramValue;  % incompatible with ML6
                paramsStruct = setfield(paramsStruct, lower(supportedArgs{idx(1)}), paramValue);  %#ok ML6

                % If 'toolbar' param specified, then it cannot be left empty - use gcf
                if strncmpi(paramName,'toolbar',length(paramName)) & isempty(paramsStruct.toolbar)  %#ok ML6
                    paramsStruct.toolbar = getCurrentFig;
                end

            elseif isempty(paramsStruct.target)
                paramsStruct.target = paramName;
                pvPairs = {paramValue, pvPairs{:}};  %#ok (more readable this way, although a bit less efficient...)

            else
                supportedArgsStr = sprintf('''%s'',',supportedArgs{:});
                error('YMA:screencapture:invalidProperty','%s \n%s', ...
                      'Invalid property passed to ScreenCapture', ...
                      ['Supported property names are: ' supportedArgsStr(1:end-1)]);
            end
        end  % loop pvPairs

    catch
        if ~isempty(paramName),  paramName = [' ''' paramName ''''];  end
        error('YMA:screencapture:invalidProperty','Error setting ScreenCapture property %s:\n%s',paramName,lasterr); %#ok<LERR>
    end
%end  % processArgs

%% Convert position from handle-relative to desktop Java-based pixels
function [paramsStruct, msgStr] = convertPos(paramsStruct)
    msgStr = '';
    try
        % Get the screen-size for later use
        screenSize = get(0,'ScreenSize');

        % Get the containing figure's handle
        hParent = paramsStruct.handle;
        if isempty(paramsStruct.handle)
            paramsStruct.hFigure = getCurrentFig;
            hParent = paramsStruct.hFigure;
        else
            paramsStruct.hFigure = ancestor(paramsStruct.handle,'figure');
        end

        % To get the acurate pixel position, the figure window must be undocked
        try
            if strcmpi(get(paramsStruct.hFigure,'WindowStyle'),'docked')
                set(paramsStruct.hFigure,'WindowStyle','normal');
                drawnow; pause(0.25);
                paramsStruct.wasDocked = 1;  % no true available in ML6
            end
        catch
            % never mind - ignore...
        end

        % The figure (if specified) must be in focus
        if ~isempty(paramsStruct.hFigure) & ishandle(paramsStruct.hFigure)  %#ok ML6
            isFigureValid = 1;  % no true available in ML6
            figure(paramsStruct.hFigure);
        else
            isFigureValid = 0;  % no false available in ML6
        end

        % Flush all graphic events to ensure correct rendering
        drawnow; pause(0.01);

        % No handle specified
        wasPositionGiven = 1;  % no true available in ML6
        if isempty(paramsStruct.handle)
            
            % Set default handle, if not supplied
            paramsStruct.handle = paramsStruct.hFigure;
            
            % If position was not specified, get it interactively using RBBOX
            if isempty(paramsStruct.position)
                [paramsStruct.position, jFrameUsed, msgStr] = getInteractivePosition(paramsStruct.hFigure); %#ok<ASGLU> jFrameUsed is unused
                paramsStruct.wasInteractive = 1;  % no true available in ML6
                wasPositionGiven = 0;  % no false available in ML6
            end
            
        elseif ~ishandle(paramsStruct.handle)
            % Handle was supplied - ensure it is a valid handle
            error('YMA:screencapture:invalidHandle','Invalid handle passed to ScreenCapture');
            
        elseif isempty(paramsStruct.position)
            % Handle was supplied but position was not, so use the handle's position
            paramsStruct.position = getPixelPos(paramsStruct.handle);
            paramsStruct.position(1:2) = 0;
            wasPositionGiven = 0;  % no false available in ML6
            
        elseif ~isnumeric(paramsStruct.position) | (length(paramsStruct.position) ~= 4)  %#ok ML6
            % Both handle & position were supplied - ensure a valid pixel position vector
            error('YMA:screencapture:invalidPosition','Invalid position vector passed to ScreenCapture: \nMust be a [x,y,w,h] numeric pixel array');
        end
        
        % Capture current object (uicontrol/axes/figure) if w=h=0 (single-click in interactive mode)
        if paramsStruct.position(3)<=0 | paramsStruct.position(4)<=0  %#ok ML6
            %TODO - find a way to single-click another Matlab figure (the following does not work)
            %paramsStruct.position = getPixelPos(ancestor(hittest,'figure'));
            paramsStruct.position = getPixelPos(paramsStruct.handle);
            paramsStruct.position(1:2) = 0;
            paramsStruct.wasInteractive = 0;  % no false available in ML6
            wasPositionGiven = 0;  % no false available in ML6
        end

        % First get the parent handle's desktop-based Matlab pixel position
        parentPos = [0,0,0,0];
        dX = 0;
        dY = 0;
        dW = 0;
        dH = 0;
        if ~isFigure(hParent)
            % Get the reguested component's pixel position
            parentPos = getPixelPos(hParent, 1);  % no true available in ML6

            % Axes position inaccuracy estimation
            deltaX = 3;
            deltaY = -1;
            
            % Fix for images
            if isImage(hParent)  % | (isAxes(hParent) & strcmpi(get(hParent,'YDir'),'reverse'))  %#ok ML6

                % Compensate for resized image axes
                hAxes = get(hParent,'Parent');
                if all(get(hAxes,'DataAspectRatio')==1)  % sanity check: this is the normal behavior
                    % Note 18/4/2013: the following fails for non-square images
                    %actualImgSize = min(parentPos(3:4));
                    %dX = (parentPos(3) - actualImgSize) / 2;
                    %dY = (parentPos(4) - actualImgSize) / 2;
                    %parentPos(3:4) = actualImgSize;

                    % The following should work for all types of images
                    actualImgSize = size(get(hParent,'CData'));
                    dX = (parentPos(3) - min(parentPos(3),actualImgSize(2))) / 2;
                    dY = (parentPos(4) - min(parentPos(4),actualImgSize(1))) / 2;
                    parentPos(3:4) = actualImgSize([2,1]);
                    %parentPos(3) = max(parentPos(3),actualImgSize(2));
                    %parentPos(4) = max(parentPos(4),actualImgSize(1));
                end

                % Fix user-specified img positions (but not auto-inferred ones)
                if wasPositionGiven

                    % In images, use data units rather than pixel units
                    % Reverse the YDir
                    ymax = max(get(hParent,'YData'));
                    paramsStruct.position(2) = ymax - paramsStruct.position(2) - paramsStruct.position(4);

                    % Note: it would be best to use hgconvertunits, but:
                    % ^^^^  (1) it fails on Matlab 6, and (2) it doesn't accept Data units
                    %paramsStruct.position = hgconvertunits(hFig, paramsStruct.position, 'Data', 'pixel', hParent);  % fails!
                    xLims = get(hParent,'XData');
                    yLims = get(hParent,'YData');
                    xPixelsPerData = parentPos(3) / (diff(xLims) + 1);
                    yPixelsPerData = parentPos(4) / (diff(yLims) + 1);
                    paramsStruct.position(1) = round((paramsStruct.position(1)-xLims(1)) * xPixelsPerData);
                    paramsStruct.position(2) = round((paramsStruct.position(2)-yLims(1)) * yPixelsPerData + 2*dY);
                    paramsStruct.position(3) = round( paramsStruct.position(3) * xPixelsPerData);
                    paramsStruct.position(4) = round( paramsStruct.position(4) * yPixelsPerData);

                    % Axes position inaccuracy estimation
                    if strcmpi(computer('arch'),'win64')
                        deltaX = 7;
                        deltaY = -7;
                    else
                        deltaX = 3;
                        deltaY = -3;
                    end
                    
                else  % axes/image position was auto-infered (entire image)
                    % Axes position inaccuracy estimation
                    if strcmpi(computer('arch'),'win64')
                        deltaX = 6;
                        deltaY = -6;
                    else
                        deltaX = 2;
                        deltaY = -2;
                    end
                    dW = -2*dX;
                    dH = -2*dY;
                end
            end

            %hFig = ancestor(hParent,'figure');
            hParent = paramsStruct.hFigure;

        elseif paramsStruct.wasInteractive  % interactive figure rectangle

            % Compensate for 1px rbbox inaccuracies
            deltaX = 2;
            deltaY = -2;

        else  % non-interactive figure

            % Compensate 4px figure boundaries = difference betweeen OuterPosition and Position
            deltaX = -1;
            deltaY = 1;
        end
        %disp(paramsStruct.position)  % for debugging
        
        % Now get the pixel position relative to the monitor
        figurePos = getPixelPos(hParent);
        desktopPos = figurePos + parentPos;

        % Now convert to Java-based pixels based on screen size
        % Note: multiple monitors are automatically handled correctly, since all
        % ^^^^  Java positions are relative to the main monitor's top-left corner
        javaX  = desktopPos(1) + paramsStruct.position(1) + deltaX + dX;
        javaY  = screenSize(4) - desktopPos(2) - paramsStruct.position(2) - paramsStruct.position(4) + deltaY + dY;
        width  = paramsStruct.position(3) + dW;
        height = paramsStruct.position(4) + dH;
        paramsStruct.position = round([javaX, javaY, width, height]);
        %paramsStruct.position

        % Ensure the figure is at the front so it can be screen-captured
        if isFigureValid
            figure(hParent);
            drawnow;
            pause(0.02);
        end
    catch
        % Maybe root/desktop handle (root does not have a 'Position' prop so getPixelPos croaks
        if isequal(double(hParent),0)  % =root/desktop handle;  handles case of hParent=[]
            javaX = paramsStruct.position(1) - 1;
            javaY = screenSize(4) - paramsStruct.position(2) - paramsStruct.position(4) - 1;
            paramsStruct.position = [javaX, javaY, paramsStruct.position(3:4)];
        end
    end
%end  % convertPos

%% Interactively get the requested capture rectangle
function [positionRect, jFrameUsed, msgStr] = getInteractivePosition(hFig)
    msgStr = '';
    try
        % First try the invisible-figure approach, in order to
        % enable rbbox outside any existing figure boundaries
        f = figure('units','pixel','pos',[-100,-100,10,10],'HitTest','off');
        drawnow; pause(0.01);
        oldWarn = warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
        jf = get(handle(f),'JavaFrame');
        warning(oldWarn);
        try
            jWindow = jf.fFigureClient.getWindow;
        catch
            try
                jWindow = jf.fHG1Client.getWindow;
            catch
                jWindow = jf.getFigurePanelContainer.getParent.getTopLevelAncestor;
            end
        end
        com.sun.awt.AWTUtilities.setWindowOpacity(jWindow,0.05);  %=nearly transparent (not fully so that mouse clicks are captured)
        jWindow.setMaximized(1);  % no true available in ML6
        jFrameUsed = 1;  % no true available in ML6
        msg = {'Mouse-click and drag a bounding rectangle for screen-capture ' ...
               ... %'or single-click any Matlab figure to capture the entire figure.' ...
               };
    catch
        % Something failed, so revert to a simple rbbox on a visible figure
        try delete(f); drawnow; catch, end  %Cleanup...
        jFrameUsed = 0;  % no false available in ML6
        msg = {'Mouse-click within any Matlab figure and then', ...
               'drag a bounding rectangle for screen-capture,', ...
               'or single-click to capture the entire figure'};
    end
    uiwait(msgbox(msg,'ScreenCapture'));
    
    k = waitforbuttonpress;  %#ok k is unused
    %hFig = getCurrentFig;
    %p1 = get(hFig,'CurrentPoint');
    positionRect = rbbox;
    %p2 = get(hFig,'CurrentPoint');

    if jFrameUsed
        jFrameOrigin = getPixelPos(f);
        delete(f); drawnow;
        try
            figOrigin = getPixelPos(hFig);
        catch  % empty/invalid hFig handle
            figOrigin = [0,0,0,0];
        end
    else
        if isempty(hFig)
            jFrameOrigin = getPixelPos(gcf);
        else
            jFrameOrigin = [0,0,0,0];
        end
        figOrigin = [0,0,0,0];
    end
    positionRect(1:2) = positionRect(1:2) + jFrameOrigin(1:2) - figOrigin(1:2);

    if prod(positionRect(3:4)) > 0
        msgStr = sprintf('%dx%d area captured',positionRect(3),positionRect(4));
    end
%end  % getInteractivePosition

%% Get current figure (even if its handle is hidden)
function hFig = getCurrentFig
    oldState = get(0,'showHiddenHandles');
    set(0,'showHiddenHandles','on');
    hFig = get(0,'CurrentFigure');
    set(0,'showHiddenHandles',oldState);
%end  % getCurrentFig

%% Get ancestor figure - used for old Matlab versions that don't have a built-in ancestor()
function hObj = ancestor(hObj,type)
    if ~isempty(hObj) & ishandle(hObj)  %#ok for Matlab 6 compatibility
        try
            hObj = get(hObj,'Ancestor');
        catch
            % never mind...
        end
        try
            %if ~isa(handle(hObj),type)  % this is best but always returns 0 in Matlab 6!
            %if ~isprop(hObj,'type') | ~strcmpi(get(hObj,'type'),type)  % no isprop() in ML6!
            try
                objType = get(hObj,'type');
            catch
                objType = '';
            end
            if ~strcmpi(objType,type)
                try
                    parent = get(handle(hObj),'parent');
                catch
                    parent = hObj.getParent;  % some objs have no 'Parent' prop, just this method...
                end
                if ~isempty(parent)  % empty parent means root ancestor, so exit
                    hObj = ancestor(parent,type);
                end
            end
        catch
            % never mind...
        end
    end
%end  % ancestor

%% Get position of an HG object in specified units
function pos = getPos(hObj,field,units)
    % Matlab 6 did not have hgconvertunits so use the old way...
    oldUnits = get(hObj,'units');
    if strcmpi(oldUnits,units)  % don't modify units unless we must!
        pos = get(hObj,field);
    else
        set(hObj,'units',units);
        pos = get(hObj,field);
        set(hObj,'units',oldUnits);
    end
%end  % getPos

%% Get pixel position of an HG object - for Matlab 6 compatibility
function pos = getPixelPos(hObj,varargin)
    persistent originalObj
    try
        stk = dbstack;
        if ~strcmp(stk(2).name,'getPixelPos')
            originalObj = hObj;
        end

        if isFigure(hObj) %| isAxes(hObj)
        %try
            pos = getPos(hObj,'OuterPosition','pixels');
        else  %catch
            % getpixelposition is unvectorized unfortunately!
            pos = getpixelposition(hObj,varargin{:});

            % add the axes labels/ticks if relevant (plus a tiny margin to fix 2px label/title inconsistencies)
            if isAxes(hObj) & ~isImage(originalObj)  %#ok ML6
                tightInsets = getPos(hObj,'TightInset','pixel');
                pos = pos + tightInsets.*[-1,-1,1,1] + [-1,1,1+tightInsets(1:2)];
            end
        end
    catch
        try
            % Matlab 6 did not have getpixelposition nor hgconvertunits so use the old way...
            pos = getPos(hObj,'Position','pixels');
        catch
            % Maybe the handle does not have a 'Position' prop (e.g., text/line/plot) - use its parent
            pos = getPixelPos(get(hObj,'parent'),varargin{:});
        end
    end

    % Handle the case of missing/invalid/empty HG handle
    if isempty(pos)
        pos = [0,0,0,0];
    end
%end  % getPixelPos

%% Adds a ScreenCapture toolbar button
function addToolbarButton(paramsStruct)
    % Ensure we have a valid toolbar handle
    hFig = ancestor(paramsStruct.toolbar,'figure');
    if isempty(hFig)
        error('YMA:screencapture:badToolbar','the ''Toolbar'' parameter must contain a valid GUI handle');
    end
    set(hFig,'ToolBar','figure');
    hToolbar = findall(hFig,'type','uitoolbar');
    if isempty(hToolbar)
        error('YMA:screencapture:noToolbar','the ''Toolbar'' parameter must contain a figure handle possessing a valid toolbar');
    end
    hToolbar = hToolbar(1);  % just in case there are several toolbars... - use only the first

    % Prepare the camera icon
    icon = ['3333333333333333'; ...
            '3333333333333333'; ...
            '3333300000333333'; ...
            '3333065556033333'; ...
            '3000000000000033'; ...
            '3022222222222033'; ...
            '3022220002222033'; ...
            '3022203110222033'; ...
            '3022201110222033'; ...
            '3022204440222033'; ...
            '3022220002222033'; ...
            '3022222222222033'; ...
            '3000000000000033'; ...
            '3333333333333333'; ...
            '3333333333333333'; ...
            '3333333333333333'];
    cm = [   0      0      0; ...  % black
             0   0.60      1; ...  % light blue
          0.53   0.53   0.53; ...  % light gray
           NaN    NaN    NaN; ...  % transparent
             0   0.73      0; ...  % light green
          0.27   0.27   0.27; ...  % gray
          0.13   0.13   0.13];     % dark gray
    cdata = ind2rgb(uint8(icon-'0'),cm);

    % If the button does not already exit
    hButton = findall(hToolbar,'Tag','ScreenCaptureButton');
    tooltip = 'Screen capture';
    if ~isempty(paramsStruct.target)
        tooltip = [tooltip ' to ' paramsStruct.target];
    end
    if isempty(hButton)
        % Add the button with the icon to the figure's toolbar
        hButton = uipushtool(hToolbar, 'CData',cdata, 'Tag','ScreenCaptureButton', 'TooltipString',tooltip, 'ClickedCallback',['screencapture(''' paramsStruct.target ''')']);  %#ok unused
    else
        % Otherwise, simply update the existing button
        set(hButton, 'CData',cdata, 'Tag','ScreenCaptureButton', 'TooltipString',tooltip, 'ClickedCallback',['screencapture(''' paramsStruct.target ''')']);
    end
%end  % addToolbarButton

%% Java-get the actual screen-capture image data
function imgData = getScreenCaptureImageData(positionRect)
    if isempty(positionRect) | all(positionRect==0) | positionRect(3)<=0 | positionRect(4)<=0  %#ok ML6
        imgData = [];
    else
        % Use java.awt.Robot to take a screen-capture of the specified screen area
        rect = java.awt.Rectangle(positionRect(1), positionRect(2), positionRect(3), positionRect(4));
        robot = java.awt.Robot;
        jImage = robot.createScreenCapture(rect);

        % Convert the resulting Java image to a Matlab image
        % Adapted for a much-improved performance from:
        % http://www.mathworks.com/support/solutions/data/1-2WPAYR.html
        h = jImage.getHeight;
        w = jImage.getWidth;
        %imgData = zeros([h,w,3],'uint8');
        %pixelsData = uint8(jImage.getData.getPixels(0,0,w,h,[]));
        %for i = 1 : h
        %    base = (i-1)*w*3+1;
        %    imgData(i,1:w,:) = deal(reshape(pixelsData(base:(base+3*w-1)),3,w)');
        %end

        % Performance further improved based on feedback from Urs Schwartz:
        %pixelsData = reshape(typecast(jImage.getData.getDataStorage,'uint32'),w,h).';
        %imgData(:,:,3) = bitshift(bitand(pixelsData,256^1-1),-8*0);
        %imgData(:,:,2) = bitshift(bitand(pixelsData,256^2-1),-8*1);
        %imgData(:,:,1) = bitshift(bitand(pixelsData,256^3-1),-8*2);

        % Performance even further improved based on feedback from Jan Simon:
        pixelsData = reshape(typecast(jImage.getData.getDataStorage, 'uint8'), 4, w, h);
        imgData = cat(3, ...
            transpose(reshape(pixelsData(3, :, :), w, h)), ...
            transpose(reshape(pixelsData(2, :, :), w, h)), ...
            transpose(reshape(pixelsData(1, :, :), w, h)));
    end
%end  % getInteractivePosition

%% Return the figure to its pre-undocked state (when relevant)
function redockFigureIfRelevant(paramsStruct)
  if paramsStruct.wasDocked
      try
          set(paramsStruct.hFigure,'WindowStyle','docked');
          %drawnow;
      catch
          % never mind - ignore...
      end
  end
%end  % redockFigureIfRelevant

%% Copy screen-capture to the system clipboard
% Adapted from http://www.mathworks.com/matlabcentral/fileexchange/28708-imclipboard/content/imclipboard.m
function imclipboard(imgData)
    % Import necessary Java classes
    import java.awt.Toolkit.*
    import java.awt.image.BufferedImage
    import java.awt.datatransfer.DataFlavor

    % Add the necessary Java class (ImageSelection) to the Java classpath
    if ~exist('ImageSelection', 'class')
        % Obtain the directory of the executable (or of the M-file if not deployed) 
        %javaaddpath(fileparts(which(mfilename)), '-end');
        if isdeployed % Stand-alone mode. 
            [status, result] = system('path');  %#ok<ASGLU>
            MatLabFilePath = char(regexpi(result, 'Path=(.*?);', 'tokens', 'once'));
        else % MATLAB mode. 
            MatLabFilePath = fileparts(mfilename('fullpath')); 
        end 
        javaaddpath(MatLabFilePath, '-end'); 
    end
        
    % Get System Clipboard object (java.awt.Toolkit)
    cb = getDefaultToolkit.getSystemClipboard;  % can't use () in ML6!
    
    % Get image size
    ht = size(imgData, 1);
    wd = size(imgData, 2);
    
    % Convert to Blue-Green-Red format
    imgData = imgData(:, :, [3 2 1]);
    
    % Convert to 3xWxH format
    imgData = permute(imgData, [3, 2, 1]);
    
    % Append Alpha data (not used)
    imgData = cat(1, imgData, 255*ones(1, wd, ht, 'uint8'));
    
    % Create image buffer
    imBuffer = BufferedImage(wd, ht, BufferedImage.TYPE_INT_RGB);
    imBuffer.setRGB(0, 0, wd, ht, typecast(imgData(:), 'int32'), 0, wd);
    
    % Create ImageSelection object
    %    % custom java class
    imSelection = ImageSelection(imBuffer);
    
    % Set clipboard content to the image
    cb.setContents(imSelection, []);
%end  %imclipboard

%% Is the provided handle a figure?
function flag = isFigure(hObj)
    flag = isa(handle(hObj),'figure') | isa(hObj,'matlab.ui.Figure');
%end  %isFigure

%% Is the provided handle an axes?
function flag = isAxes(hObj)
    flag = isa(handle(hObj),'axes') | isa(hObj,'matlab.graphics.axis.Axes');
%end  %isFigure

%% Is the provided handle an image?
function flag = isImage(hObj)
    flag = isa(handle(hObj),'image') | isa(hObj,'matlab.graphics.primitive.Image');
%end  %isFigure

%%%%%%%%%%%%%%%%%%%%%%%%%% TODO %%%%%%%%%%%%%%%%%%%%%%%%%
% find a way in interactive-mode to single-click another Matlab figure for screen-capture