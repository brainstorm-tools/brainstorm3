function pBar = bst_progress(varargin)
% bst_progress: Manage the Brainstorm progress bar
%
% USAGE : pBar = bst_progress('start', title, msg, valStart, valStop) : Create a progress bar with start and stop bounds
%         pBar = bst_progress('start', title, msg)                    : Create a progress bar (unlimited)
%         pBar = bst_progress('stop')        : stop and hide progress bar
%         pBar = bst_progress('inc', valInc) : increment of 'valInc' the position of the progress bar
%         pBar = bst_progress('set', pos)    : set the position
%          pos = bst_progress('get')         : get the position
%         pBar = bst_progress('text', txt)   : set the text
%    isVisible = bst_progress('isvisible')   : return 1 if progress bar is visible, 0 else
%         pBar = bst_progress('show')        : display previously defined progress bar
%         pBar = bst_progress('hide')        : hide progress bar
%         pBar = bst_progress('setimage', imagefile) : display an image in the wait bar
%         pBar = bst_progress('setlink', url)        : clicking on the image opens a browser to display the url
%         pBar = bst_progress('removeimage')         : Remove the image from the wait bar
%         pBar = bst_progress('removelink')          : Remove click-on-image action
%   pBarParams = bst_progress('getbarparams')        : Get current bar parameters
%         pBar = bst_progress('setbarparams', pBarParams) : Set bar parameters
%         pBar = bst_progress('setpluginlogo', plugName/plugDesc) : display plugin logo with click-on image link

% NOTES : The window is created once, and then never deleted, just hidden.
%         Progress bar is represented by a structure: 
%            |- jWindow
%            |- jLabel
%            |- jProgressBar
%
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
% Authors: Francois Tadel, 2008-2013

global GlobalData;

%% ===== PARSE INPUTS =====
if ((nargin >= 1) && ischar(varargin{1}))
    commandName = varargin{1};
else
    error('Usage : bst_progress(commandName, parameters)');
end


%% ===== GET OR CREATE PROGRESS BAR =====
% Do nothing in case of server mode
if ~isempty(GlobalData) && ~isempty(GlobalData.Program) && isfield(GlobalData.Program, 'GuiLevel') && (GlobalData.Program.GuiLevel == -1)
    if ismember(lower(commandName), {'pos','isvisible'})
        pBar = 0;
    else
        pBar = [];
    end
    return;
end


% If running in NOGUI mode: just display the message in the command window
if ~bst_get('isGUI')
    switch lower(commandName)
        case 'start',     disp(['PROGRESS> ' varargin{2} ': ' varargin{3}]); pBar = [];
        case 'text',      disp(['PROGRESS> ' varargin{2}]); pBar = [];
        case 'get',       pBar = 1;
        case 'isvisible', pBar = 0;
    end
    return;
end

end
