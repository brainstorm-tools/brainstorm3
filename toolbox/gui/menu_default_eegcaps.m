function menu_default_eegcaps(jMenu, iAllStudies, isAddLoc)
% MENU_DEFAULT_EEGCAPS: Generate Brainstorm available EEG caps menu
% 
% USAGE: menu_default_eegcaps(jMenu, iAllStudies, isAddLoc)
%
% PARAMETERS:
%    - jMenu       : The handle for the parent menu where this menu will be added 
%    - iAllStudies : All studies in the protocol
%    - isAddLoc    : if 1 (SEEG/ECOG) or 2 (EEG), call 'channel_add_loc' 
%                    if 0 call 'db_set_channel'
                        
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
% Authors: Raymundo Cassani, 2024 
%          Chinmay Chinara, 2024

import org.brainstorm.icon.*;

%% ===== PARSE INPUTS =====
if (nargin < 1) || isempty(jMenu)
    bst_error('Incorrect usage, first parameter ''jMenu'' is required', 'Menu EEG caps', 0);
    return
end
if (nargin < 2) || isempty(iAllStudies)
    iAllStudies = [];
end
if (nargin < 3) || isempty(isAddLoc)
    isAddLoc = [];
end

% Get the digitize options
DigitizeOptions = bst_get('DigitizeOptions');
% Get registered Brainstorm EEG defaults
bstDefaults = bst_get('EegDefaults');
if ~isempty(bstDefaults)
    % Add a directory per template block available
    for iDir = 1:length(bstDefaults)
        jMenuDir = gui_component('Menu', jMenu, [], bstDefaults(iDir).name, IconLoader.ICON_FOLDER_CLOSE, [], []);
        isMni = strcmpi(bstDefaults(iDir).name, 'ICBM152');
        % Create subfolder for cap manufacturer
        jMenuOther = gui_component('Menu', [], [], 'Generic', IconLoader.ICON_FOLDER_CLOSE, [], []);
        jMenuAnt = gui_component('Menu', [], [], 'ANT', IconLoader.ICON_FOLDER_CLOSE, [], []);
        jMenuBs  = gui_component('Menu', [], [], 'BioSemi', IconLoader.ICON_FOLDER_CLOSE, [], []);
        jMenuBp  = gui_component('Menu', [], [], 'BrainProducts', IconLoader.ICON_FOLDER_CLOSE, [], []);
        jMenuEgi = gui_component('Menu', [], [], 'EGI', IconLoader.ICON_FOLDER_CLOSE, [], []);
        jMenuNs  = gui_component('Menu', [], [], 'NeuroScan', IconLoader.ICON_FOLDER_CLOSE, [], []);
        jMenuWs  = gui_component('Menu', [], [], 'WearableSensing', IconLoader.ICON_FOLDER_CLOSE, [], []);
        % Add an item per Template available
        fList = bstDefaults(iDir).contents;
        % Sort in natural order
        [tmp,I] = sort_nat({fList.name});
        fList = fList(I);
        % Create an entry for each default
        for iFile = 1:length(fList)
            % Define callback function
            if isempty(isAddLoc)
                panel_fun = @panel_digitize;
                if isfield(DigitizeOptions, 'Version') && strcmpi(DigitizeOptions.Version, '2024')
                    panel_fun = @panel_digitize_2024;
                end
                fcnCallback = @(h,ev)panel_fun('AddMontage', fList(iFile).fullpath);
            else
                if isAddLoc 
                    fcnCallback = @(h,ev)channel_add_loc(iAllStudies, fList(iFile).fullpath, 1, isMni);
                else
                    fcnCallback = @(h,ev)db_set_channel(iAllStudies, fList(iFile).fullpath, 1, 0);
                end
            end
            % Find corresponding submenu
            if ~isempty(strfind(fList(iFile).name, 'ANT'))
                jMenuType = jMenuAnt;
            elseif ~isempty(strfind(fList(iFile).name, 'BioSemi'))
                jMenuType = jMenuBs;
            elseif ~isempty(strfind(fList(iFile).name, 'BrainProducts'))
                jMenuType = jMenuBp;
            elseif ~isempty(strfind(fList(iFile).name, 'GSN')) || ~isempty(strfind(fList(iFile).name, 'U562'))
                jMenuType = jMenuEgi;
            elseif ~isempty(strfind(fList(iFile).name, 'Neuroscan'))
                jMenuType = jMenuNs;
            elseif ~isempty(strfind(fList(iFile).name, 'WearableSensing'))
                jMenuType = jMenuWs;
            else
                jMenuType = jMenuOther;
            end
            % Create item
            gui_component('MenuItem', jMenuType, [], fList(iFile).name, IconLoader.ICON_CHANNEL, [], fcnCallback);
        end
        % Add if not empty
        if (jMenuOther.getMenuComponentCount() > 0)
            jMenuDir.add(jMenuOther);
        end
        if (jMenuAnt.getMenuComponentCount() > 0)
            jMenuDir.add(jMenuAnt);
        end
        if (jMenuBs.getMenuComponentCount() > 0)
            jMenuDir.add(jMenuBs);
        end
        if (jMenuBp.getMenuComponentCount() > 0)
            jMenuDir.add(jMenuBp);
        end
        if (jMenuEgi.getMenuComponentCount() > 0)
            jMenuDir.add(jMenuEgi);
        end
        if (jMenuNs.getMenuComponentCount() > 0)
            jMenuDir.add(jMenuNs);
        end
        if (jMenuWs.getMenuComponentCount() > 0)
            jMenuDir.add(jMenuWs);
        end
    end
end
