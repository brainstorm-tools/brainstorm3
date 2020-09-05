function varargout = panel_spikes(varargin)
% PANEL_SPIKES: Panel used for supervised spike sorting.
% 
% USAGE:  bstPanel = panel_spikesorting('CreatePanel')
%
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
% Authors: Martin Cousineau, 2018

eval(macro_method);
end


%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'Spikes';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % Create tools panel
    jPanelNew = gui_component('Panel');
    jPanelTop = gui_component('Panel');
    jPanelNew.add(jPanelTop, BorderLayout.NORTH);
    TB_DIM = java_scaled('dimension', 25, 25);

    % ===== FREQUENCY FILTERING =====
    jPanelSpikes = gui_component('Panel');
    jBorder = java_scaled('titledborder', 'Spike Sorting');
    jPanelSpikes.setBorder(BorderFactory.createCompoundBorder(BorderFactory.createEmptyBorder(7,7,7,7), jBorder));
        jPanelElectrodes = gui_component('Panel');
        % Electrodes list
        jComboElectrodes = gui_component('ComboBox', jPanelElectrodes, BorderLayout.CENTER, [], [], [], [], []);
        jComboElectrodes.setFocusable(0);
        % ComboBox change selection callback
        jModel = jComboElectrodes.getModel();
        java_setcb(jModel, 'ContentsChangedCallback', @(h,ev)bst_call(@ElectrodesListValueChanged_Callback,h,ev));
        jPanelSpikes.add(jPanelElectrodes, BorderLayout.CENTER);
        
        jPanelButtons = gui_component('Panel');
        jButtonSaveAndNext = gui_component('button', jPanelButtons, BorderLayout.CENTER, 'Save and Next', {Dimension(java_scaled('value', 50), java_scaled('value', 22)), Insets(0,0,0,0)}, 'Save loaded electrode and load the next one', @ButtonSaveAndNextElectrode);
        jPanelSpikes.add(jPanelButtons, BorderLayout.SOUTH);
    jPanelTop.add(jPanelSpikes, BorderLayout.NORTH);

    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jPanel', jPanelTop, ...
                                  'jComboElectrodes', jComboElectrodes, ...
                                  'jButtonSaveAndNext', jButtonSaveAndNext));
                              
    UpdateElectrodesList(jComboElectrodes);
                                                            

%% =================================================================================
%  === INTERNAL PANEL CALLBACKS  ===================================================
%  =================================================================================
%% ===== LIST SELECTION CHANGED CALLBACK =====
    function ElectrodesListValueChanged_Callback(varargin)
        global GlobalData;
        % Get selected item in the combo box
        jItem = jComboElectrodes.getSelectedItem();
        if isempty(jItem)
            return
        end
        % Select electrode
        GlobalData.SpikeSorting.Selected = jItem.getUserData();
        process_spikesorting_supervised('LoadElectrode');
    end
    function ButtonSaveAndNextElectrode(varargin)
        global GlobalData;
        
        % Save current electrode
        bst_progress('start', 'Spike Sorting', 'Saving electrode...');
        process_spikesorting_supervised('SaveElectrode');

        % Load next electrode
        bst_progress('text', 'Loading next electrode...');
        nextElectrode = process_spikesorting_supervised('GetNextElectrode');
        if GlobalData.SpikeSorting.Selected ~= nextElectrode
            GlobalData.SpikeSorting.Selected = nextElectrode;
            process_spikesorting_supervised('LoadElectrode');
        end

        UpdatePanel();
        bst_progress('stop');
    end
end

%% ===== UPDATE CALLBACK =====
function UpdatePanel()
    global GlobalData;
    ctrl = bst_get('PanelControls', 'Spikes');
    if process_spikesorting_supervised('FigureIsOpen', 1)
        gui_enable(ctrl.jPanel, 1);
        UpdateElectrodesList();
        if strcmpi(GlobalData.SpikeSorting.Data.Device, 'kilosort')
            ctrl.jButtonSaveAndNext.setLabel('Save All');
        else
            ctrl.jButtonSaveAndNext.setLabel('Save and Next');
        end
    else
        gui_enable(ctrl.jPanel, 0);
    end
end

function UpdateElectrodesList(varargin)
    global GlobalData;
    import org.brainstorm.list.*;

    if nargin == 1
        jComboElectrodes = varargin{1};
    else
        % Get "Spike Sorting" panel controls
        ctrl = bst_get('PanelControls', 'Spikes');
        if isempty(ctrl)
            return;
        end
        jComboElectrodes = ctrl.jComboElectrodes;
    end

    % Save combobox callback
    jModel = jComboElectrodes.getModel();
    bakCallback = java_getcb(jModel, 'ContentsChangedCallback');
    java_setcb(jModel, 'ContentsChangedCallback', []);
    
    % Empty the ComboBox
    jComboElectrodes.removeAllItems();
    % Add all the database entries in the list of the combo box
    if isfield(GlobalData, 'SpikeSorting') && isfield(GlobalData.SpikeSorting, 'Data') ...
            && isfield(GlobalData.SpikeSorting.Data, 'Spikes') ...
            && ~isempty(fieldnames(GlobalData.SpikeSorting.Data.Spikes))
        jComboElectrodes.setEnabled(1);
        iList = 0;
        for i = 1:length(GlobalData.SpikeSorting.Data.Spikes)
            if ~isempty(GlobalData.SpikeSorting.Data.Spikes(i).File)
                spikeName = GetSpikeName(i);
                jComboElectrodes.addItem(BstListItem('protocol', '', spikeName, i))
                GlobalData.SpikeSorting.Data.Spikes(i).ItemList = iList;
                iList = iList + 1;
            end
        end
        if GlobalData.SpikeSorting.Selected > 0
            jComboElectrodes.setSelectedIndex(GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).ItemList);
        end
    else
        jComboElectrodes.setEnabled(0);
    end
    
    % Restore callback
    java_setcb(jModel, 'ContentsChangedCallback', bakCallback);
end

%% ===== FOCUS CHANGED ======
function FocusChangedCallback(isFocused) %#ok<DEFNU>
    UpdatePanel();
end

function spikeName = GetSpikeName(i)
    global GlobalData;
    if strcmpi(GlobalData.SpikeSorting.Data.Device, 'kilosort')
        prefix = 'Montage';
    else
        prefix = 'Channel';
    end
    spikeName = [prefix ' ' GlobalData.SpikeSorting.Data.Spikes(i).Name];
    if GlobalData.SpikeSorting.Data.Spikes(i).Mod
        spikeName = [spikeName ' *'];
    end
end
