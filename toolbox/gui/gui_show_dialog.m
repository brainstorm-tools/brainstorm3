function panelContents = gui_show_dialog(panelTitle, fcnPanel, isModal, winPos, varargin)
% GUI_SHOW_DIALOG: Display a BstPanel in a JDialog.
% Wait for the end of its execution, and return the panel contents.
%
% USAGE:  panelContents = gui_show_dialog(panelTitle, fcnPanel, isModal, winPos, varargin)
% 
% INPUT:
%     - panelTitle : Title of the JDialog
%     - fcnPanel   : handle to a panel_...() function
%     - isModal    : boolean
%     - winPos     : [x,y] Window position, relative with the main Braintorm frame
%     - varargin   : arguments to pass to the CreatePanel() function of the panel
% 
% OUTPUT:
%     - panelContents: structure returned by the GetPanelContents() of the panel
% SEE ALSO gui_hide gui_show

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
% Authors: Francois Tadel, 2008-2016

% Default options
if (nargin < 3) || isempty(isModal)
    isModal = 1;
end
if (nargin < 4) || isempty(winPos)
    winPos = [];
end

% Convert string to function
if ischar(fcnPanel)
    fcnPanel = str2func(fcnPanel);
end
% Display property window
[bstPanel, panelName] = fcnPanel('CreatePanel', varargin{:});
if isempty(bstPanel)
    panelContents = [];
    return
end
% Hide progress bar
isProgressBarHidden = bst_progress('isVisible');
if isProgressBarHidden
    bst_progress('hide');
end

% Create panel
isAlwaysOnTop = 1;
isMaximized = 0;
gui_show(bstPanel, 'JavaWindow', panelTitle, [], isModal, isAlwaysOnTop, isMaximized, winPos);

% Wait for the end of execution
bst_mutex('waitfor', panelName);

% Restore progress bar
if isProgressBarHidden
    bst_progress('show');
end

% Check if panel is still existing (if user did not abort the operation)
if (nargout >= 1) && gui_brainstorm('isTabVisible', get(bstPanel,'name'))
    % Try to execute 'GetPanelContents'
    try
        % Get user configuration
        panelContents = fcnPanel('GetPanelContents');
    catch
        panelContents = [];
    end
    % Close panel
    gui_hide(bstPanel);
else
    % User closed panel
    panelContents = [];
end



