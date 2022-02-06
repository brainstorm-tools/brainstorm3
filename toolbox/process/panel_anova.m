function varargout = panel_anova(varargin)
% PANEL_ANOVA: Creation and management of list of files to apply some batch proccess.
%
% USAGE:  bstPanelNew = panel_anova('CreatePanel')

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
% Authors: Francois Tadel, 2009

eval(macro_method);
end


%% ===== CREATE PANEL ===== 
function bstPanelNew = CreatePanel()
    panelName = 'ANOVA';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Create list of nodes (tree-table)
    nodelist = panel_nodelist('CreatePanel', 'Anova', 'Files', 'table');
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           nodelist.jPanel, ...
                           struct('nodelist', nodelist));
end

%% =========================================================================
%  ===== PROCESSING FUNCTIONS ==============================================
%  =========================================================================



  


