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
% Authors: Elizabeth Bock, 2014


bstPanel = panel_realtime('CreatePanel');

OPTIONS.FTHost = '10.0.0.1';
OPTIONS.FTPort = 1972;
OPTIONS.BlockTime = 400; %ms
OPTIONS.HeadMoveThresh = 5; %mm
OPTIONS.HP = 8;
OPTIONS.LP = 12;

%[panelContainer, bstPanel] = gui_show( bstPanel, contType, contName, contIcon, isModal, isAlwaysOnTop, isMaximized )
gui_show(bstPanel,'JavaWindow','Realtime',[],[],1);
panel_realtime('SetPreferences',OPTIONS);



