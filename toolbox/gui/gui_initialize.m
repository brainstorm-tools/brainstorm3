function gui_initialize()
% GUI_INITIALIZE: Initialize the GUI for Brainstorm Toolbox.

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
% Authors: Francois Tadel, 2008-2014

global GlobalData;

% Reinitialize TimeSliderMutex
global TimeSliderMutex;
TimeSliderMutex = [];
% Create main Brainstorm window
GlobalData.Program.GUI = gui_brainstorm('CreateWindow');
% Abort if something went wrong or if in server mode
if isempty(GlobalData.Program.GUI) || (GlobalData.Program.GuiLevel == -1)
    return;
end
    
% Add main Brainstorm panels
% Explorer container
gui_show('panel_protocols', 'BrainstormPanel', 'explorer');
% Bottom container
gui_show('panel_process1',  'BrainstormTab', 'process');
gui_show('panel_process2',  'BrainstormTab', 'process');
%gui_show('panel_anova',     'BrainstormTab', 'process');

% Time window container
gui_show('panel_time', 'BrainstormPanel', 'timewindow');
gui_show('panel_freq', 'BrainstormPanel', 'freq');

% Tools
gui_show('panel_record', 'BrainstormTab', 'tools');
gui_show('panel_filter', 'BrainstormTab', 'tools');
gui_show('panel_surface', 'BrainstormTab', 'tools');
if (GlobalData.Program.GuiLevel == 1)
    gui_show('panel_scout', 'BrainstormTab', 'tools');
end
% gui_show('panel_cluster', 'BrainstormTab', 'tools');
% gui_show('panel_dipoles', 'BrainstormTab', 'tools');

% Select first tools panel
gui_brainstorm('SetSelectedTab', 'Record');

% Update maximum brainstorm window size
gui_layout('UpdateMaxBstSize');


