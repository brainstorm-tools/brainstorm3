function varargout = panel_spikes(varargin)
% PANEL_SPIKES: Panel used for supervised spike sorting.
% 
% USAGE:  bstPanel = panel_spikesorting('CreatePanel')
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
        LoadElectrode();
    end
    function ButtonSaveAndNextElectrode(varargin)
        global GlobalData;
        
        % Save current electrode
        bst_progress('start', 'Spike Sorting', 'Saving electrode...');
        SaveElectrode();

        % Load next electrode
        bst_progress('text', 'Loading next electrode...');
        nextElectrode = GetNextElectrode();
        if GlobalData.SpikeSorting.Selected ~= nextElectrode
            GlobalData.SpikeSorting.Selected = nextElectrode;
            LoadElectrode();
        end

        UpdatePanel();
        bst_progress('stop');
    end
end

%% ===== UPDATE CALLBACK =====
function UpdatePanel()
    global GlobalData;
    ctrl = bst_get('PanelControls', 'Spikes');
    if FigureIsOpen(1)
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


%% ===== UPDATE ELECTRODE LIST =====
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


%% ===== GET SPIKE NAME =====
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


%% =================================================================================================
%  ===== EXTERNAL CALLBACKS ========================================================================
%  =================================================================================================

%% ===== OPEN SPIKE FILE =====
function OpenSpikeFile(SpikeFile)
    global GlobalData;

    % Load input file
    DataMat = in_bst_data(SpikeFile);

    % Relative to absolute paths
    DataMat.Parent = file_fullpath(DataMat.Parent);
    DataMat.Name   = file_fullpath(DataMat.Name);
    for i = 1 : length(DataMat.Spikes)
        DataMat.Spikes(i).Path = file_fullpath(DataMat.Spikes(i).Path);
    end
    
    % Make sure spikes exist and were generated by WaveClus
    if ~isfield(DataMat, 'Spikes') || ~isstruct(DataMat.Spikes) ...
            || ~isfield(DataMat, 'Parent') ...
            || exist(DataMat.Parent, 'dir') ~= 7 ...
            || isempty(dir(DataMat.Parent))
        bst_error('No spikes found. Make sure to run the unsupervised Spike Sorter first.', 'Load spike file', 0);
        return;
    end

    switch lower(DataMat.Device)
        case 'waveclus'
            % Load plugin
            [isInstalled, errMsg] = bst_plugin('Install', 'waveclus');
            if ~isInstalled
                error(errMsg);
            end
        case 'ultramegasort2000'
            % Load plugin
            [isInstalled, errMsg] = bst_plugin('Install', 'ultramegasort2000');
            if ~isInstalled
                error(errMsg);
            end
        case 'kilosort'
            KlustersExecutable = bst_get('KlustersExecutable');
            if isempty(KlustersExecutable) || exist(KlustersExecutable, 'file') ~= 2
                % Try a common places for Klusters to be installed
                commonPaths = {'C:\Program Files (x86)\Klusters\bin\klusters.exe', ...
                    'C:\Program Files\Klusters\bin\klusters.exe'};
                foundPath = 0;
                for iPath = 1:length(commonPaths)
                    if exist(commonPaths{iPath}, 'file') == 2
                        KlustersExecutable = commonPaths{iPath};
                        bst_set('KlustersExecutable', KlustersExecutable);
                        foundPath = 1;
                        break;
                    end
                end
                % If we cannot find it, prompt user
                if ~foundPath
                    [res, isCancel] = java_dialog('question', ...
                        ['<html><body><p>We cannot find an installation of Klusters on your computer.<br>', ...
                        'Would you like to download it or look for the Klusters executable yourself?'], ...
                        'Klusters executable', [], {'Download', 'Pick executable', 'Cancel'}, 'Cancel');
                    if isCancel || isempty(res) || strcmpi(res, 'Cancel')
                        return;
                    end
                    if strcmpi(res, 'Download')
                        % Display web page
                        klusters_url = 'http://neurosuite.sourceforge.net/';
                        status = web(klusters_url, '-browser');
                        if (status ~= 0)
                            web(klusters_url);
                        end
                        return;
                    end
                    % For Windows, look for EXE files.
                    if ~isempty(strfind(bst_get('OsType'), 'win'))
                        filters = {'*.exe', 'Klusters executable (*.exe)'};
                    else
                        filters = {'*', 'Klusters executable'};
                    end
                    KlustersExecutable = java_getfile('open', 'Klusters executable', [], 'single', 'files', filters, {});
                    if isempty(KlustersExecutable) || exist(KlustersExecutable, 'file') ~= 2
                        return;
                    end
                end
                bst_set('KlustersExecutable', KlustersExecutable);
            end
        otherwise
            bst_error('The chosen spike sorter is currently unsupported by Brainstorm.');
    end
    
    CloseFigure();
    
    GlobalData.SpikeSorting = struct();
    GlobalData.SpikeSorting.Data = DataMat;
    GlobalData.SpikeSorting.Selected = 0;
    GlobalData.SpikeSorting.Fig = -1;
    
    gui_brainstorm('ShowToolTab', 'Spikes');
    OpenFigure();
    panel_spikes('UpdatePanel');
end


%% ===== OPEN FIGURE =====
function OpenFigure()
    global GlobalData;
    
    bst_progress('start', 'Spike Sorting', 'Loading spikes...');
    CloseFigure();
    
    GlobalData.SpikeSorting.Selected = GetNextElectrode();

    electrodeFile = bst_fullfile(...
        GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).Path, ...
        GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).File);
    
    switch lower(GlobalData.SpikeSorting.Data.Device)
        case 'waveclus'
            GlobalData.SpikeSorting.Fig = wave_clus(electrodeFile);
            
            % Some Wave Clus visual hacks
            load_button = findall(GlobalData.SpikeSorting.Fig, 'Tag', 'load_data_button');
            if ishandle(load_button)
                load_button.Visible = 'off';
            end
            save_button = findall(GlobalData.SpikeSorting.Fig, 'Tag', 'save_clusters_button');
            if ishandle(save_button)
                save_button.Visible = 'off';
            end

        case 'ultramegasort2000'
            DataMat = load(electrodeFile, 'spikes');
            GlobalData.SpikeSorting.Fig = figure('Units', 'Normalized', 'Position', ...
                DataMat.spikes.params.display.default_figure_size);
            % Just open figure, rest of the code in LoadElectrode()
        
        case 'kilosort'
            % Do nothing.
        
        otherwise
            bst_error('This spike sorting structure is currently unsupported by Brainstorm.');
    end
    
    panel_spikes('UpdatePanel');
    LoadElectrode();
    
    % Close Spike panel when you close the figure
    function my_closereq(src, callbackdata)
        delete(src);
        panel_spikes('UpdatePanel');
    end
    if FigureIsOpen()
        GlobalData.SpikeSorting.Fig.CloseRequestFcn = @my_closereq;
    end
    
    bst_progress('stop');
end


%% ===== IS FIGURE OPEN =====
function isOpen = FigureIsOpen(varargin)
    global GlobalData;
    
    if nargin < 1
        lenient = 0;
    else
        lenient = varargin{1};
    end
    
    isOpen = isfield(GlobalData, 'SpikeSorting') ...
        && (isfield(GlobalData.SpikeSorting, 'Fig') ...
        && ishandle(GlobalData.SpikeSorting.Fig)) ...
        || (lenient && strcmpi(GlobalData.SpikeSorting.Data.Device, 'kilosort'));
    % For KiloSort, we're not sure it is open since it's outside matlab...
end


%% ===== CLOSE FIGURE =====
function CloseFigure()
    global GlobalData;
    if ~FigureIsOpen()
        return;
    end
    close(GlobalData.SpikeSorting.Fig);
    panel_spikes('UpdatePanel');
end


%% ===== LOAD ELECTRODE =====
function LoadElectrode()
    global GlobalData;
    if ~FigureIsOpen(1)
        return;
    end
    
    electrodeFile = bst_fullfile(...
        GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).Path, ...
        GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).File);
    
    switch lower(GlobalData.SpikeSorting.Data.Device)
        case 'waveclus'
            wave_clus('load_data_button_Callback', GlobalData.SpikeSorting.Fig, ...
                electrodeFile, guidata(GlobalData.SpikeSorting.Fig));
            
            name_text = findall(GlobalData.SpikeSorting.Fig, 'Tag', 'file_name');
            if ishandle(name_text)
                name_text.String = panel_spikes('GetSpikeName', GlobalData.SpikeSorting.Selected); 
            end

        case 'ultramegasort2000'
            % Reload figure altogether, same behavior as builtin load...
            DataMat = load(electrodeFile, 'spikes');
            clf(GlobalData.SpikeSorting.Fig, 'reset');
            splitmerge_tool(DataMat.spikes, 'all', GlobalData.SpikeSorting.Fig);
            
            % Some UMS2k visual hacks
            save_button = findall(GlobalData.SpikeSorting.Fig, 'Tag', 'saveButton');
            if ishandle(save_button)
                save_button.Visible = 'off';
            end
            save_button = findall(GlobalData.SpikeSorting.Fig, 'Tag', 'saveFileButton');
            if ishandle(save_button)
                save_button.Visible = 'off';
            end
            load_button = findall(GlobalData.SpikeSorting.Fig, 'Tag', 'loadFileButton');
            if ishandle(load_button)
                load_button.Visible = 'off';
            end
        
        case 'kilosort'
            KlustersExecutable = bst_get('KlustersExecutable');
            status = system(['"' KlustersExecutable, '" "', electrodeFile, '" &']);
            if status ~= 0
                bst_error('An error has occurred, could not start Klusters.');
            end
            
        otherwise
            bst_error('This spike sorting structure is currently unsupported by Brainstorm.');
    end
end


%% ===== SAVE ELECTRODE =====
function SaveElectrode()
    global GlobalData;
    
    if ~FigureIsOpen(1)
        return;
    end
    
    electrodeFile = bst_fullfile(...
        GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).Path, ...
        GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).File);
    
    % Save through Spike Sorting software
    switch lower(GlobalData.SpikeSorting.Data.Device)
        case 'waveclus'
            save_button = findall(GlobalData.SpikeSorting.Fig, 'Tag', 'save_clusters_button');
            wave_clus('save_clusters_button_Callback', save_button, ...
                [], guidata(GlobalData.SpikeSorting.Fig), 0);

        case 'ultramegasort2000'
            figdata = get(GlobalData.SpikeSorting.Fig, 'UserData');
            spikes = figdata.spikes;
            save(electrodeFile, 'spikes');
            OutMat = struct();
            OutMat.pathname = GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).Path;
            OutMat.filename = GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).File;
            set(figdata.sfb, 'UserData', OutMat);

        case 'kilosort'
            % Do nothing.
            
        otherwise
            bst_error('This spike sorting structure is currently unsupported by Brainstorm.');
    end
    
    % Save updated brainstorm file
    GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).Mod = 1;
    bst_save(GlobalData.SpikeSorting.Data.Name, GlobalData.SpikeSorting.Data, 'v6');
    
    % Add event to linked raw file
    CreateSpikeEvents(GlobalData.SpikeSorting.Data.RawFile, ...
        GlobalData.SpikeSorting.Data.Device, ...
        electrodeFile, ...
        GlobalData.SpikeSorting.Data.Spikes(GlobalData.SpikeSorting.Selected).Name, ...
        1);
end


%% ===== NEXT ELECTRODE =====
function nextElectrode = GetNextElectrode()
    global GlobalData;
    if ~isfield(GlobalData, 'SpikeSorting') ...
            || ~isfield(GlobalData.SpikeSorting, 'Selected') ...
            || isempty(GlobalData.SpikeSorting.Selected)
        GlobalData.SpikeSorting.Selected = 0;
    end
    
    numSpikes = length(GlobalData.SpikeSorting.Data.Spikes);
    nextElectrode = [];
    
    if GlobalData.SpikeSorting.Selected < numSpikes
        nextElectrode = GlobalData.SpikeSorting.Selected + 1;
        while nextElectrode <= numSpikes && ...
                isempty(GlobalData.SpikeSorting.Data.Spikes(nextElectrode).File)
            nextElectrode = nextElectrode + 1;
        end
    end
    if isempty(nextElectrode) || nextElectrode > numSpikes || isempty(GlobalData.SpikeSorting.Data.Spikes(nextElectrode).File)
        nextElectrode = GlobalData.SpikeSorting.Selected;
    end
end


%% ===== CREATE SPIKE EVENTS =====
function newEvents = CreateSpikeEvents(rawFile, deviceType, electrodeFile, electrodeName, import, eventNamePrefix)
    global GlobalData;
    if nargin < 6
        eventNamePrefix = '';
    elseif ~isempty(eventNamePrefix)
        eventNamePrefix = [eventNamePrefix ' '];
    end
    newEvents = struct();
    DataMat = in_bst_data(rawFile);
    eventName = [eventNamePrefix GetSpikesEventPrefix() ' ' electrodeName];
    gotEvents = 0;

    % Load spike data and convert to Brainstorm event format
    switch lower(deviceType)
        case 'waveclus'
            if exist(electrodeFile, 'file') == 2
                ElecData = load(electrodeFile, 'cluster_class');
                neurons = unique(ElecData.cluster_class(ElecData.cluster_class(:,1) > 0,1));
                numNeurons = length(neurons);
                tmpEvents = struct();
                if numNeurons == 1
                    tmpEvents(1).epochs = ones(1, sum(ElecData.cluster_class(:,1) ~= 0));
                    tmpEvents(1).times  = ElecData.cluster_class(ElecData.cluster_class(:,1) ~= 0, 2)' ./ 1000 + DataMat.F.prop.times(1);
                else
                    for iNeuron = 1:numNeurons
                        tmpEvents(iNeuron).epochs = ones(1, length(ElecData.cluster_class(ElecData.cluster_class(:,1) == iNeuron, 1)));
                        tmpEvents(iNeuron).times = ElecData.cluster_class(ElecData.cluster_class(:,1) == iNeuron, 2)' ./ 1000 + DataMat.F.prop.times(1);
                    end
                end
            else
                numNeurons = 0;
            end

        case 'ultramegasort2000'
            ElecData = load(electrodeFile, 'spikes');
            ElecData.spikes.spiketimes = double(ElecData.spikes.spiketimes);
            numNeurons = size(ElecData.spikes.labels,1);
            tmpEvents = struct();
            if numNeurons == 1
                tmpEvents(1).epochs = ones(1,length(ElecData.spikes.assigns));
                tmpEvents(1).times = ElecData.spikes.spiketimes + DataMat.F.prop.times(1);
            elseif numNeurons > 1
                for iNeuron = 1:numNeurons
                    tmpEvents(iNeuron).epochs = ones(1,length(ElecData.spikes.assigns(ElecData.spikes.assigns == ElecData.spikes.labels(iNeuron,1))));
                    tmpEvents(iNeuron).times = ElecData.spikes.spiketimes(ElecData.spikes.assigns == ElecData.spikes.labels(iNeuron,1)) + DataMat.F.prop.times(1);
                end
            end
            
        case 'kilosort'
            [newEvents, Channels_new_montages] = process_spikesorting_kilosort('LoadKlustersEvents', ...
                GlobalData.SpikeSorting.Data, GlobalData.SpikeSorting.Selected);
            gotEvents = 1;
                        
            % In the case of Kilosort, the entire Shank is considered the
            % 'electrode'. Therefore there are multiple events assigned
            % simultaneously on every manual inspection.
            channelsInMontage = Channels_new_montages(ismember({Channels_new_montages.Group}, electrodeName));
            
            eventName = cell(length(channelsInMontage), 1);
            for iChannel = 1:length(channelsInMontage)
                eventName{iChannel} = ['Spikes Channel ' channelsInMontage(iChannel).Name];
            end
            
        otherwise
            bst_error('This spike sorting structure is currently unsupported by Brainstorm.');
    end
    
    if ~gotEvents
        if numNeurons == 1
            newEvents(1).label      = eventName;
            newEvents(1).color      = [rand(1,1), rand(1,1), rand(1,1)];
            newEvents(1).epochs     = tmpEvents(1).epochs;
            newEvents(1).times      = tmpEvents(1).times;
            newEvents(1).reactTimes = [];
            newEvents(1).select     = 1;
            newEvents(1).notes      = [];
            newEvents(1).channels   = repmat({{electrodeName}}, 1, size(newEvents(1).times, 2));

            
        elseif numNeurons > 1
            for iNeuron = 1:numNeurons
                newEvents(iNeuron).label      = [eventName ' |' num2str(iNeuron) '|'];
                newEvents(iNeuron).color      = [rand(1,1), rand(1,1), rand(1,1)];
                newEvents(iNeuron).epochs     = tmpEvents(iNeuron).epochs;
                newEvents(iNeuron).times      = tmpEvents(iNeuron).times;
                newEvents(iNeuron).reactTimes = [];
                newEvents(iNeuron).select     = 1;
                newEvents(iNeuron).notes      = [];
                newEvents(iNeuron).channels   = repmat({{electrodeName}}, 1, size(newEvents(iNeuron).times, 2));

            end
        else
            % This electrode just picked up noise, no event to add.
            newEvents(1).label      = eventName;
            newEvents(1).color      = [rand(1,1), rand(1,1), rand(1,1)];
            newEvents(1).epochs     = [];
            newEvents(1).times      = [];
            newEvents(1).reactTimes = [];
            newEvents(1).select     = 1;
            newEvents(1).channels = [];
            newEvents(1).notes    = [];
        end
    end

    if import
        ProtocolInfo = bst_get('ProtocolInfo');
        % Add event to linked raw file
        numEvents = length(DataMat.F.events);
        % Delete existing event(s)
        if numEvents > 0
            if ~iscell(eventName)  % Waveclus / UltraMegaSort2000
                iDelEvents = cellfun(@(x) ~isempty(x), strfind({DataMat.F.events.label}, strtrim(eventName)));
            else % Kilosort - Delete all spiking events that are derived from any channels from the shank that is being currently manually spike-sorted
                iDelEvents = false(length(eventName), length({DataMat.F.events.label}));
                for iEventName = 1:length(eventName)
                    iDelEvents(iEventName,:) = cellfun(@(x) ~isempty(x), strfind({DataMat.F.events.label}, strtrim(eventName{iEventName})));
                end
            end
            iDelEvents = any(iDelEvents,1);
                
            DataMat.F.events = DataMat.F.events(~iDelEvents);
            numEvents = length(DataMat.F.events);
        end
        % Add as new event(s);
        if ~isempty(fieldnames(newEvents))
            for iEvent = 1:length(newEvents)
                DataMat.F.events(numEvents + iEvent) = newEvents(iEvent);
            end
        end
        bst_save(bst_fullfile(ProtocolInfo.STUDIES, rawFile), DataMat, 'v6');
    end
end


%% ===== GET SPIKES EVENT PREFIX =====
function prefix = GetSpikesEventPrefix(varargin)
    if length(varargin) < 1
        prefix = 'Spikes Channel';
    else
        prefix = {'Spikes Channel', 'Spikes Noise'};
    end
end


%% ===== IS SPIKE EVENT =====
function isSpikeEvent = IsSpikeEvent(eventLabel)
    prefixes = GetSpikesEventPrefix('all');
    
    isSpikeEvent = false(length(prefixes), 1);
    for iPrefix = 1:length(prefixes)
        isSpikeEvent(iPrefix) = strncmp(eventLabel, prefixes{iPrefix}, length(prefixes{iPrefix}));
    end
    isSpikeEvent = any(isSpikeEvent,1);
end


%% ===== GET NEURON FROM EVENT =====
function neuron = GetNeuronOfSpikeEvent(eventLabel)
    markers = strfind(eventLabel, '|');
    if length(markers) > 1
        neuron = str2num(eventLabel(markers(end-1)+1:markers(end)-1));
    else
        neuron = [];
    end
end


%% ===== GET CHANNEL FROM EVENT =====
function channel = GetChannelOfSpikeEvent(eventLabel)
    if ~IsSpikeEvent(eventLabel)
        channel = [];
        return;
    end
    
    eventLabel = strtrim(eventLabel);
    prefix = GetSpikesEventPrefix();
    neuron = GetNeuronOfSpikeEvent(eventLabel);
    bounds = [length(prefix) + 2, 0]; % 'Spikes Channel '
    
    if ~isempty(neuron)
        bounds(2) = length(num2str(neuron)) + 3; % ' |31|'
    end
    
    try
        channel = eventLabel(bounds(1):end-bounds(2));
    catch
        channel = [];
    end
end


%% ===== IS FIRST NEURON =====
function isFirst = IsFirstNeuron(eventLabel, onlyIsFirst)
    % onlyIsFirst = We assume a channel with a single neuron counts as a first neuron.
    if nargin < 2
        onlyIsFirst = 1;
    end
    neuron = GetNeuronOfSpikeEvent(eventLabel);
    isFirst = neuron == 1;
    if onlyIsFirst && isempty(neuron)
        isFirst = 1;
    end
end


%% ===== DELETE SPIKE EVENTS ======
function DeleteSpikeEvents(rawFile)
    ProtocolInfo = bst_get('ProtocolInfo');
    DataMat = in_bst_data(rawFile);
    events = DataMat.F.events;
    iKeepEvents = [];
    
    for iEvent = 1:length(events)
        if ~IsSpikeEvent(events(iEvent).label)
            iKeepEvents(end+1) = iEvent;
        end
    end
    
    DataMat.F.events = DataMat.F.events(iKeepEvents);
    bst_save(bst_fullfile(ProtocolInfo.STUDIES, rawFile), DataMat, 'v6');
end


