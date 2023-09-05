function gui_enable( controls, status, isRecursive )
% GUI_ENABLE: Enable/disable control and control's children.
%
% USAGE:  gui_enable( controls, status, isRecursive);
%
% INPUT:
%    - controls    : array of java components handles
%    - status      : {0,1} - If 1, controls are enabled
%    - isRecursive : enable/disable component's children recursively

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
% Authors: Francois Tadel, 2008

if (nargin < 3)
    isRecursive = 1;
end
for iControl = 1:length(controls)
    ctrl1 = controls(iControl);
    % Enable/Disable component
    ctrl1.setEnabled(status);
    % And all its children components
    if isRecursive && ~isa(ctrl1, 'javax.swing.JList')
        for iChild = 1:ctrl1.getComponentCount()
            ctrl2 = ctrl1.getComponent(iChild - 1);
            % Enable/Disable component child
            ctrl2.setEnabled(status);
            % And all its sub-children components
            for iChildChild = 1:ctrl2.getComponentCount()
                ctrl3 = ctrl2.getComponent(iChildChild - 1);
                ctrl3.setEnabled(status);
                for iChildChildChild = 1:ctrl3.getComponentCount()
                    ctrl4 = ctrl3.getComponent(iChildChildChild - 1);
                    ctrl4.setEnabled(status);
                end
            end
        end
    end
end



