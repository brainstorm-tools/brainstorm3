function gui_zoom( hFig, direction, factor )
% GUI_ZOOM: Zoom in/out from a figure.
% 
% USAGE:  gui_zoom( hFig, direction, factor )
%
% INPUT:
%    - hFig      : Figure handle
%    - direction : {'vertical', 'horizontal', 'both'}
%    - factor    : Zoom factor (>1 zoom in, <1 zoom out)

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
% Authors: Francois Tadel, 2010-2012

% Some Matlab versions do not support this "zoom" function
try
    % Get zoom object for this figure
    hZoom = zoom(hFig);
    % Set zoom direction
    oldDirection = hZoom.Motion;
    hZoom.Motion = direction;
    % Apply zoom
    zoom(factor);
    % Reset zoom (usually to horizontal motion)
    hZoom.Motion = oldDirection;
catch
    warning('The zoom function is not supported on this old version of Matlab...');
end


