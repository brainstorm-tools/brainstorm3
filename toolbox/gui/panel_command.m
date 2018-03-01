function varargout = panel_command(varargin)
% PANEL_COMMAND: Create a panel to execute matlab code in the base workspace.
% 
% USAGE:  bstPanelNew = panel_command('CreatePanel')

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013-2014

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Command';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelNew.setPreferredSize(java_scaled('dimension', 400, 300));
    
    % Text editor
    jText = JTextArea(6, 12);
    jText.setFont(Font('Monospaced', Font.PLAIN, 11));
    jScroll = JScrollPane(jText);
    jPanelNew.add(jScroll, BorderLayout.CENTER);
    
    % Confirmation buttons
    jPanelBottom = gui_river();   
    gui_component('Button', jPanelBottom, 'br right', 'Execute', [], [], @ButtonRun_Callback, []);
    gui_component('Button', jPanelBottom, [],         'Close',   [], [], @ButtonClose_Callback,   []);
    jPanelNew.add(jPanelBottom, BorderLayout.SOUTH);
           
    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jText', jText));

                       
                       
%% =================================================================================
%  === CONTROLS CALLBACKS  =========================================================
%  =================================================================================               
%% ===== SAVE OPTIONS =====
    function ButtonRun_Callback(varargin)
        try
            evalin('base', char(jText.getText()));
        catch
            disp('BST> Error executing command:');
            disp(lasterr);
        end
    end

%% ===== CANCEL BUTTON =====
    function ButtonClose_Callback(varargin)
        % Hide panel
        gui_hide(panelName);
    end
    
end


