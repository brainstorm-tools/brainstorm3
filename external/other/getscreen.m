function [X,m]=getscreen(varargin)
%GETSCREEN replacement for GETFRAME for systems with multiple monitors. Use it just like you use GETFRAME.
%Can also be used to take screenshots of non-MATLAB windows. Requires JAVA.
%
%Calling options:
% Output X is m*n*3 cdata array. Output m is corresponding colormap (if applicable.)
% [X,m]=getscreen         Gets screenshot of current figure
% [X,m]=getscreen(h)      Gets screenshot of axes or figure with handle h
% [X,m]=getscreen(h,rect) Gets screenshot of at position rect relative to axes or figure with handle h.
% [X,m]=getscreen(rect) Gets screenshot of whatever is on your screen at position vector rect. (Relative to bottom left corner.)
%   rect is a 4 element position vector in pixel units, referenced from bottom left as usual for MATLAB.
%
% By Matt Daskilewicz <mattdaskil@gatech.edu> 11/2008
% www.asdl.gatech.edu
%


%process inputs:
if nargin==0
    h=gcf;
    rect=get(h,'position');
    rect(1:2)=[0 0];

elseif nargin==1
    if numel(varargin{1})==1 %it should be a handle
        h=varargin{1};
        if ~strcmp(get(h,'type'),'axes') && ~strcmp(get(h,'type'),'figure')
            error('First input must be a handle to an axes or figure, or a position vector');
        end

        rect = hgconvertunits(h, get(h,'position'), get(h,'units'), 'pixels', get(h,'parent')); %x/y coords of fighandle in pixels
        rect(1:2)=[1 1];

    elseif numel(varargin{1})==4 %it is a position vector
        h=[];
        rect=varargin{1};
    else % isnt a handle or a position vector
        error('First input must be a handle to an axes or figure, or a position vector');
    end

elseif nargin==2 %should be a handle and a position vector
    h=varargin{1};
    if ~ismember(get(h,'type'),{'figure';'axes'})
        error('First input must be a handle to an axes or figure, or a position vector');
    end

    rect=varargin{2};
    if length(rect)~=4
        error('Second input must be a 4 element position vector.')
    end

else
    error('Too many input arguments')
end


%get monitor resolutions... because java references coords from top of screen, need to know how big
%screens is.
monitorz=get(0,'monitorpositions');
maxheight=max(monitorz(:,4)); %max vertical resolution of all monitors

if ~isempty(h)

    %h is the handle to figure or axes whose origin (first 2 elemetns of position vector) we're taking
    %rect with respect to.
    origin=getpixelposition(h,true);

    %if axes are in a uipanel, nudge rect slightly to account for panel border.
    if strcmp(get(get(h,'parent'),'type'),'uipanel')
        origin=origin+[1 1 0 0];
    end

    %also need position of the figure containing h, since origin is w.r.t this figure:
    fighandle = ancestor(h,'figure'); %handle of parent figure to h

    figorigin = hgconvertunits(fighandle, get(fighandle,'position'), get(fighandle,'units'), 'pixels', 0); %x/y coords of fighandle in pixels

    if strcmp(get(h,'type'),'figure')
        origin=[1 1 0 0]; %avoid double counting figorigin and origin if fighandle==h
    end


    %% calculate dimensions of rectangle to take screenshot of: (in java coordinates)
    %java coordinates start at top left instead of bottom left, and start at [0,0]. Also "top" is defined as the top of your
    %largest monitor, even if that's not the one you're taking a screenshot from.

    x=figorigin(1)+origin(1)+rect(1)-3;
    y=maxheight-figorigin(2)-origin(2)-rect(2)-rect(4)+3;
    w=floor(rect(3));
    h=floor(rect(4));

    figure(fighandle); %make sure figure is visible on screen
    drawnow;

else %there is no figure... just take a screenshot of whatever's on the screen at rect

    rect=floor(rect);

    x=rect(1);
    y=maxheight-rect(2)-rect(4); %java coordinates start at top of screen.
    w=rect(3);
    h=rect(4);
end


%% do java:
robo = java.awt.Robot;
target=java.awt.Rectangle(x,y,w,h);
image = robo.createScreenCapture(target); %take screenshot at rect
rasta=image.getRGB(0,0,w,h,[],0,w); %get RGB data from bufferedimage

%convert java color integers to matlab RGB format:
rasta=256^3+rasta;
B=uint8(mod(rasta,256));
G=uint8(mod((rasta-int32(B))./256,256));
R=uint8(mod((rasta-256*int32(G))./65536,256));

X.cdata=uint8(zeros(h,w,3));
X.cdata(:,:,1)=reshape(R,[w h])';
X.cdata(:,:,2)=reshape(G,[w h])';
X.cdata(:,:,3)=reshape(B,[w h])';
X.colormap=[];

if (nargout == 2)
    m=X.colormap;
    X=X.cdata;
end

