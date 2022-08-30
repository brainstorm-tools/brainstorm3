function gui_popup( jPopup, jParent, x, y )
% GUI_POPUP: Show a JPopupMenu at the current location of the mouse cursor.

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

% Parse inputs
if (nargin < 2) || isempty(jParent)
    jParent = jPopup;
end
if (nargin < 4) || isempty(x) || isempty(y)
    mouseInfo = java.awt.MouseInfo.getPointerInfo();
    mouseLoc  = mouseInfo.getLocation();
else
    mouseLoc = java.awt.Point(x,y);
end
jPopup.pack();

% If parent is a figure handle
if ~isjava(jParent) && ~isempty(jParent)
    % Fix stupid bug in some older Matlab versions
    if any(bst_get('MatlabVersion') == [709, 710, 711])
        jParent = jPopup;
    % Matlab >= 2019b deprecated the JavaFrame property, impossible to attach JPopupMenu to a figure
    elseif (bst_get('MatlabVersion') >= 907)
        jParent = jPopup;
    else
        % Get the handle of the java figure
        jParent = bst_get('JFrame', jParent);
        % If the call crashed
        if isempty(jParent)
            jParent = jPopup;
        end
    end
end
% Show popup
jPopup.setLocation(mouseLoc);
jPopup.setInvoker(jPopup);
jPopup.setVisible(1);
drawnow;
    
    
    
    
    