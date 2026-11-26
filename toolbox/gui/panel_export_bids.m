function varargout = panel_export_bids(varargin)
% PANEL_EXPORT_BIDS: Metadata options for the BIDS export (tabbed panel).
%
% Tabs: General | MEG | EEG | NIRS  (modality tabs are shown only for the
% modalities found in the files selected for export).
%
% If the BIDS output folder already exists, the metadata it contains
% (dataset_description.json, README, modality sidecar JSON files) is read and
% displayed, so that the user can keep it identical or modify it.
%
% USAGE:  bstPanelNew = panel_export_bids('CreatePanel', sProcess, sFiles)
%                   s = panel_export_bids('GetPanelContents')
%                   s = panel_export_bids('GetOptions')            % defaults + saved preferences
%                   s = panel_export_bids('GetDefaultOptions')
%       [s, nFound] = panel_export_bids('ReadExistingMetadata', bidsFolder)
%                   r = panel_export_bids('ParseReadme', readmeFile)

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
% Authors: Martin Cousineau, 2018-2019

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(sProcess, sFiles)  %#ok<DEFNU>
    panelName = 'ExportBidsOptions';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    % No input
    if isempty(sFiles) || strcmpi(sFiles(1).FileType, 'import')
        bstPanelNew = [];
        panelName = [];
        return;
    end

    % Output folder selected in the process options
    bidsFolder = '';
    if isfield(sProcess, 'options') && isfield(sProcess.options, 'bidsdir') && iscell(sProcess.options.bidsdir.Value) && ~isempty(sProcess.options.bidsdir.Value)
        bidsFolder = sProcess.options.bidsdir.Value{1};
    end
    % Modalities present in the selected files
    modalities = DetectModalities(sFiles);
    % Initial values: existing dataset metadata if available, last used values otherwise
    [Options, infoMsg] = GetInitialOptions(bidsFolder);

    % Create main panel
    jPanelMain = java_create('javax.swing.JPanel');
    jPanelMain.setLayout(java_create('java.awt.GridBagLayout'));
    c = GridBagConstraints();
    c.fill = GridBagConstraints.BOTH;
    c.gridx = 1;
    c.weightx = 1;
    c.insets = Insets(3,5,3,5);

    % ===== INFO LINE =====
    c.gridy = 1;
    c.weighty = 0;
    jPanelMain.add(javax.swing.JLabel(infoMsg), c);

    % ===== TABS =====
    jTabs = javax.swing.JTabbedPane();
    ctrl = struct();
    ctrl.BidsFolder = bidsFolder;
    
    % --- General tab ---
    jTab = javax.swing.JPanel();
    jTab.setLayout(javax.swing.BoxLayout(jTab, javax.swing.BoxLayout.Y_AXIS));
    jSec = CreateSection(jTab, 'Project description (README)');
    ctrl.jTextProjName   = AddTextRow(jSec,  'Project name: ');
    ctrl.jTextProjID     = AddTextRow(jSec,  'Project ID: ');
    ctrl.jTextProjDesc   = AddTextArea(jSec, 'Project description: ', 4);
    ctrl.jTextCategories = AddTextArea(jSec, 'Participant categories: ', 2);
    jSec = CreateSection(jTab, 'Dataset description (dataset_description.json)');
    ctrl.jTextAuthors          = AddTextRow(jSec,  'Authors, separated with commas (required): ');
    ctrl.jTextLicense          = AddTextRow(jSec,  'License: ');
    ctrl.jTextDatasetDOI       = AddTextRow(jSec,  'Dataset DOI: ');
    ctrl.jTextHowToAcknowledge = AddTextRow(jSec,  'How to acknowledge: ');
    ctrl.jTextAcknowledgements = AddTextArea(jSec, 'Acknowledgements: ', 2);
    ctrl.jTextFunding          = AddTextArea(jSec, 'Funding (one per line): ', 2);
    ctrl.jTextEthics           = AddTextArea(jSec, 'Ethics approvals (one per line): ', 2);
    ctrl.jTextReferences       = AddTextArea(jSec, 'References and links (one per line): ', 2);
    ctrl.jTextJsonDataset      = AddTextArea(jSec, 'Additional dataset_description.json fields (JSON): ', 3);
    jSec = CreateSection(jTab, 'Recording (all modalities)');
    gui_component('Label', jSec, '', 'Power line frequency: ');
    ctrl.jRadioPL50 = gui_component('Radio', jSec, '', '50 Hz');
    ctrl.jRadioPL60 = gui_component('Radio', jSec, '', '60 Hz');
    ctrl.jRadioPL0  = gui_component('Radio', jSec, '', 'Not specified (n/a)');
    jGroupPL = javax.swing.ButtonGroup();
    jGroupPL.add(ctrl.jRadioPL50);
    jGroupPL.add(ctrl.jRadioPL60);
    jGroupPL.add(ctrl.jRadioPL0);
    AddTab(jTabs, 'General', jTab);
    
    % --- MEG tab ---
    if modalities.meg
        jTab = javax.swing.JPanel();
        jTab.setLayout(javax.swing.BoxLayout(jTab, javax.swing.BoxLayout.Y_AXIS));
        jSec = CreateSection(jTab, 'MEG sidecar (*_meg.json)');
        ctrl.jTextDewarPosition = AddTextRow(jSec,  'Position of the dewar during the scan: ');
        ctrl.jTextDewarPosition.setToolTipText('Upright, Supine or Degrees of angle');
        ctrl.jTextJsonMeg       = AddTextArea(jSec, 'Additional MEG sidecar fields (JSON): ', 6);
        AddTab(jTabs, 'MEG', jTab);
    end
    
    % --- EEG tab ---
    if modalities.eeg
        jTab = javax.swing.JPanel();
        jTab.setLayout(javax.swing.BoxLayout(jTab, javax.swing.BoxLayout.Y_AXIS));
        jSec = CreateSection(jTab, 'EEG sidecar (*_eeg.json)');
        ctrl.jTextEegReference       = AddTextRow(jSec,  'Electrode reference used: ');
        ctrl.jTextEegGround          = AddTextRow(jSec,  'Ground electrode: ');
        ctrl.jTextEegCapManufacturer = AddTextRow(jSec,  'Cap manufacturer: ');
        ctrl.jTextEegCapModel        = AddTextRow(jSec,  'Cap model: ');
        ctrl.jTextJsonEeg            = AddTextArea(jSec, 'Additional EEG sidecar fields (JSON): ', 6);
        AddTab(jTabs, 'EEG', jTab);
    end
    
    % --- NIRS tab ---
    if modalities.nirs
        jTab = javax.swing.JPanel();
        jTab.setLayout(javax.swing.BoxLayout(jTab, javax.swing.BoxLayout.Y_AXIS));
        jSec = CreateSection(jTab, 'NIRS sidecar (*_nirs.json)');
        ctrl.jTextNirsSourceType      = AddTextRow(jSec,  'Source type (e.g. LED, laser): ');
        ctrl.jTextNirsDetectorType    = AddTextRow(jSec,  'Detector type (e.g. APD, SiPD, PMT): ');
        ctrl.jTextNirsCapManufacturer = AddTextRow(jSec,  'Cap manufacturer: ');
        ctrl.jTextNirsCapModel        = AddTextRow(jSec,  'Cap model: ');
        ctrl.jTextJsonNirs            = AddTextArea(jSec, 'Additional NIRS sidecar fields (JSON): ', 6);
        AddTab(jTabs, 'NIRS', jTab);
    end
    
    jTabs.setPreferredSize(Dimension(round(java_scaled('value', 640)), round(java_scaled('value', 520))));
    c.gridy = 2;
    c.weighty = 1;
    jPanelMain.add(jTabs, c);
    
    % ===== VALIDATION BUTTON =====
    jPanelOk = gui_river();
    gui_component('Button', jPanelOk, 'br right', 'OK', [], [], @ButtonOk_Callback);
    c.gridy = 3;
    c.weighty = 0;
    jPanelMain.add(jPanelOk, c);

    % ===== PANEL CREATION =====
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);
    % Create the BstPanel object that is returned by the function
    bstPanelNew = BstPanel(panelName, jPanelMain, ctrl);
    
    UpdatePanel();
    
    
%% =================================================================================
%  === INTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== OK BUTTON =====
    function ButtonOk_Callback(varargin)
        % Validate JSON
        try
            ExportBidsOptions = GetPanelContents();
        catch e
            java_dialog('error', e.message, 'Invalid metadata', jPanelMain);
            return;
        end
        % Authors are required in dataset_description.json
        if isempty(ExportBidsOptions.Authors)
            jTabs.setSelectedIndex(0);
            java_dialog('warning', 'The list of authors cannot be empty.', 'Missing metadata', jPanelMain);
            return;
        end
        
        % Save new options
        bst_set('ExportBidsOptions', ExportBidsOptions);
        
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
        gui_release_dialog(panelName);
    end

%% ===== UPDATE PANEL =====
    function UpdatePanel(varargin)
        names = TextOptionNames();
        for iName = 1:length(names)
            ctrlName = ['jText' names{iName}];
            if isfield(ctrl, ctrlName)
                ctrl.(ctrlName).setText(Options.(names{iName}));
            end
        end
        switch Options.PowerLine
            case 50
                ctrl.jRadioPL50.setSelected(true);
            case 60
                ctrl.jRadioPL60.setSelected(true);
            otherwise
                ctrl.jRadioPL0.setSelected(true);
        end
    end

end


%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================   
%% ===== GET PANEL CONTENTS =====
function s = GetPanelContents() %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'ExportBidsOptions');
    % Start from the saved options: the tabs that are not displayed keep their values
    s = GetOptions();
    
    % Extract entered values
    names = TextOptionNames();
    for iName = 1:length(names)
        ctrlName = ['jText' names{iName}];
        if isfield(ctrl, ctrlName)
            s.(names{iName}) = strtrim(char(ctrl.(ctrlName).getText()));
        end
    end
    if isfield(ctrl, 'jRadioPL50')
        if ctrl.jRadioPL50.isSelected()
            s.PowerLine = 50;
        elseif ctrl.jRadioPL60.isSelected()
            s.PowerLine = 60;
        else
            s.PowerLine = 0;
        end
    end
    % Remember for which folder these options were validated
    if isfield(ctrl, 'BidsFolder')
        s.PreparedFor = ctrl.BidsFolder;
    end
    
    % Validate JSON
    jsonList = {'JsonDataset', 'dataset description'; ...
                'JsonMeg',     'MEG sidecar files'; ...
                'JsonEeg',     'EEG sidecar files'; ...
                'JsonNirs',    'NIRS sidecar files'};
    for iJson = 1:size(jsonList, 1)
        if ~ValidateJson(s.(jsonList{iJson,1}))
            error(['The JSON you entered for the ', jsonList{iJson,2}, ' is invalid.', ...
                10, 'It must be a JSON object, e.g. {"InstitutionName": "My hospital"}.', ...
                10, 'Please check your syntax and try again.']);
        end
    end
end

function isValid = ValidateJson(jsonText)
    if isempty(jsonText)
        isValid = 1;
    else
        try
            isValid = isstruct(bst_jsondecode(jsonText));
        catch
            isValid = 0;
        end
    end
end


%% ===== OPTIONS =====
% Names of all options edited with a text control (control name = ['jText' name])
function names = TextOptionNames()
    names = {'ProjName', 'ProjID', 'ProjDesc', 'Categories', ...
             'Authors', 'License', 'DatasetDOI', 'HowToAcknowledge', 'Acknowledgements', ...
             'Funding', 'Ethics', 'References', 'JsonDataset', ...
             'DewarPosition', 'JsonMeg', ...
             'EegReference', 'EegGround', 'EegCapManufacturer', 'EegCapModel', 'JsonEeg', ...
             'NirsSourceType', 'NirsDetectorType', 'NirsCapManufacturer', 'NirsCapModel', 'JsonNirs'};
end

function s = GetDefaultOptions() %#ok<DEFNU>
    s = struct();
    % General: README
    s.ProjName   = '';
    s.ProjID     = '';
    s.ProjDesc   = '';
    s.Categories = '';
    % General: dataset_description.json (multi-line fields: one item per line)
    s.Authors          = '';
    s.License          = '';
    s.DatasetDOI       = '';
    s.HowToAcknowledge = '';
    s.Acknowledgements = '';
    s.Funding          = '';
    s.Ethics           = '';
    s.References       = '';
    s.JsonDataset      = '';
    % General: sidecars (50, 60, or 0 = n/a)
    s.PowerLine = 60;
    % MEG
    s.DewarPosition = 'Upright';
    s.JsonMeg       = '';
    % EEG
    s.EegReference       = 'Cz';
    s.EegGround          = '';
    s.EegCapManufacturer = '';
    s.EegCapModel        = '';
    s.JsonEeg            = '';
    % NIRS
    s.NirsSourceType      = '';
    s.NirsDetectorType    = '';
    s.NirsCapManufacturer = '';
    s.NirsCapModel        = '';
    s.JsonNirs            = '';
    % Output folder for which the options were last validated in the panel
    s.PreparedFor = '';
end

% Default options overridden by the saved preferences
function s = GetOptions() %#ok<DEFNU>
    s = GetDefaultOptions();
    s = MergeStruct(s, bst_get('ExportBidsOptions'));
end

function s = MergeStruct(s, src)
    if isstruct(src) && ~isempty(src)
        srcFields = fieldnames(src);
        for i = 1:length(srcFields)
            s.(srcFields{i}) = src(1).(srcFields{i});
        end
    end
end

% Values to display when opening the panel
function [Options, infoMsg] = GetInitialOptions(bidsFolder)
    Options = GetDefaultOptions();
    nFound = 0;
    if ~isempty(bidsFolder) && exist(bidsFolder, 'dir') == 7
        [existing, nFound] = ReadExistingMetadata(bidsFolder);
    end
    if nFound > 0
        % Existing dataset: what is in the folder wins over saved preferences
        Options = MergeStruct(Options, existing);
        infoMsg = 'Existing BIDS metadata loaded from the output folder. Edit it or keep it as is.';
    else
        Options = GetOptions();
        if isempty(bidsFolder)
            infoMsg = 'No output folder selected: showing the last used values.';
        elseif exist(bidsFolder, 'dir') == 7
            infoMsg = 'No BIDS metadata found in the output folder: showing the last used values.';
        else
            infoMsg = 'New dataset: showing the last used values.';
        end
    end
end

% Modalities to display tabs for (all of them if they cannot be detected)
function modalities = DetectModalities(sFiles)
    modalities = struct('meg', false, 'eeg', false, 'nirs', false);
    for iFile = 1:length(sFiles)
        if isfield(sFiles, 'ChannelTypes') && iscell(sFiles(iFile).ChannelTypes) && ~isempty(sFiles(iFile).ChannelTypes)
            types = sFiles(iFile).ChannelTypes;
            modalities.meg  = modalities.meg  || any(strncmpi(types, 'MEG', 3));
            modalities.eeg  = modalities.eeg  || any(strcmpi(types, 'EEG'));
            modalities.nirs = modalities.nirs || any(strcmpi(types, 'NIRS'));
        end
    end
    if ~modalities.meg && ~modalities.eeg && ~modalities.nirs
        modalities = struct('meg', true, 'eeg', true, 'nirs', true);
    end
end


%% =================================================================================
%  === READ EXISTING METADATA ======================================================
%  =================================================================================
% Read the metadata of an existing BIDS dataset, in the format of the panel options.
% Only the fields found in the folder are returned. nFound = number of sources found.
function [s, nFound] = ReadExistingMetadata(bidsFolder)
    s = struct();
    nFound = 0;
    if isempty(bidsFolder) || exist(bidsFolder, 'dir') ~= 7
        return;
    end
    
    %% ===== dataset_description.json =====
    % {json field, option name, format}
    descMap = {'Name',               'ProjName',         'char'; ...
               'Authors',            'Authors',          'csv'; ...
               'License',            'License',          'char'; ...
               'DatasetDOI',         'DatasetDOI',       'char'; ...
               'HowToAcknowledge',   'HowToAcknowledge', 'char'; ...
               'Acknowledgements',   'Acknowledgements', 'char'; ...
               'Funding',            'Funding',          'lines'; ...
               'EthicsApprovals',    'Ethics',           'lines'; ...
               'ReferencesAndLinks', 'References',       'lines'};
    descFile = bst_fullfile(bidsFolder, 'dataset_description.json');
    if exist(descFile, 'file') == 2
        desc = ReadJsonFile(descFile);
        if isstruct(desc)
            nFound = nFound + 1;
            [s, desc] = PopFields(s, desc, descMap);
            % Fields rewritten by Brainstorm at each export, not worth showing
            desc = RemoveFields(desc, {'BIDSVersion', 'DatasetType'});
            if isfield(desc, 'GeneratedBy') && IsOnlyBrainstorm(desc.GeneratedBy)
                desc = rmfield(desc, 'GeneratedBy');
            end
            s.JsonDataset = StructToJson(desc);
        end
    end
    
    %% ===== README =====
    readmeFile = bst_fullfile(bidsFolder, 'README');
    if exist(readmeFile, 'file') == 2
        r = ParseReadme(readmeFile);
        if ~isempty(r)
            nFound = nFound + 1;
            readmeFields = {'ProjName', 'ProjID', 'ProjDesc', 'Categories'};
            for i = 1:length(readmeFields)
                val = r.(readmeFields{i});
                if strcmp(val, 'n/a')
                    val = '';
                end
                % The dataset name from dataset_description.json has priority
                if ~isempty(val) && ~(strcmp(readmeFields{i}, 'ProjName') && isfield(s, 'ProjName') && ~isempty(s.ProjName))
                    s.(readmeFields{i}) = val;
                end
            end
        end
    end
    
    %% ===== Sidecar JSON files =====
    % {folder/suffix, JSON option, {json field, option name; ...}}
    modInfo = {...
        'meg',  'JsonMeg',  {'DewarPosition', 'DewarPosition'}; ...
        'eeg',  'JsonEeg',  {'EEGReference', 'EegReference'; 'EEGGround', 'EegGround'; 'CapManufacturer', 'EegCapManufacturer'; 'CapManufacturersModelName', 'EegCapModel'}; ...
        'nirs', 'JsonNirs', {'SourceType', 'NirsSourceType'; 'DetectorType', 'NirsDetectorType'; 'CapManufacturer', 'NirsCapManufacturer'; 'CapManufacturersModelName', 'NirsCapModel'}};
    % Fields that are specific to each recording, generated at export: not copied to the additional JSON
    perFileFields = {'TaskName', 'SamplingFrequency', 'Manufacturer', 'DigitizedLandmarks', 'DigitizedHeadPoints', ...
        'SoftwareFilters', 'RecordingDuration', 'RecordingType', 'EpochLength', 'ContinuousHeadLocalization', ...
        'MEGChannelCount', 'MEGREFChannelCount', 'EEGChannelCount', 'ECOGChannelCount', 'SEEGChannelCount', ...
        'EOGChannelCount', 'ECGChannelCount', 'EMGChannelCount', 'MiscChannelCount', 'TriggerChannelCount', ...
        'NIRSChannelCount', 'NIRSSourceOptodeCount', 'NIRSDetectorOptodeCount', 'AssociatedEmptyRoom', ...
        'SubjectArtefactDescription', 'HeadCoilFrequency', 'MaxMovement', 'TaskDescription'};
    powerLineFound = false;
    for iMod = 1:size(modInfo, 1)
        sidecar = FindSidecar(bidsFolder, modInfo{iMod,1});
        if isempty(sidecar)
            continue;
        end
        nFound = nFound + 1;
        % Power line frequency is common to all modalities
        if isfield(sidecar, 'PowerLineFrequency')
            if ~powerLineFound
                s.PowerLine = ParsePowerLine(sidecar.PowerLineFrequency);
                powerLineFound = true;
            end
            sidecar = rmfield(sidecar, 'PowerLineFrequency');
        end
        [s, sidecar] = PopFields(s, sidecar, [modInfo{iMod,3}, repmat({'char'}, size(modInfo{iMod,3}, 1), 1)]);
        sidecar = RemoveFields(sidecar, perFileFields);
        s.(modInfo{iMod,2}) = StructToJson(sidecar);
    end
end

% Move the fields listed in fieldMap ({json field, option name, format}) from the JSON struct to the options
function [s, jsonStruct] = PopFields(s, jsonStruct, fieldMap)
    for i = 1:size(fieldMap, 1)
        if isfield(jsonStruct, fieldMap{i,1})
            txt = ValueToText(jsonStruct.(fieldMap{i,1}), fieldMap{i,3});
            % Values that cannot be displayed as text stay in the additional JSON
            if ischar(txt)
                s.(fieldMap{i,2}) = txt;
                jsonStruct = rmfield(jsonStruct, fieldMap{i,1});
            end
        end
    end
end

function jsonStruct = RemoveFields(jsonStruct, fieldList)
    for i = 1:length(fieldList)
        if isfield(jsonStruct, fieldList{i})
            jsonStruct = rmfield(jsonStruct, fieldList{i});
        end
    end
end

function txt = StructToJson(jsonStruct)
    if isempty(fieldnames(jsonStruct))
        txt = '';
    else
        txt = bst_jsonencode(jsonStruct);
    end
end

% Returns [] if the value cannot be converted to text
function txt = ValueToText(val, mode)
    txt = [];
    if ischar(val)
        txt = strtrim(val);
    elseif isnumeric(val) && isscalar(val)
        txt = num2str(val);
    elseif iscell(val) && all(cellfun(@ischar, val(:))) && ~strcmp(mode, 'char')
        if strcmp(mode, 'csv')
            txt = strjoin(val(:)', ', ');
        else
            txt = strjoin(val(:)', char(10));
        end
    end
end

function pl = ParsePowerLine(val)
    pl = 0;
    if isnumeric(val) && isscalar(val) && ismember(val, [50, 60])
        pl = val;
    end
end

function isOnly = IsOnlyBrainstorm(generatedBy)
    isOnly = false;
    if isstruct(generatedBy)
        generatedBy = num2cell(generatedBy(:)');
    end
    if iscell(generatedBy) && ~isempty(generatedBy)
        isOnly = all(cellfun(@(x) isstruct(x) && isfield(x, 'Name') && strcmp(x.Name, 'Brainstorm3'), generatedBy));
    end
end

function s = ReadJsonFile(jsonFile)
    try
        s = bst_jsondecode(fileread(jsonFile));
    catch
        s = [];
    end
end

% First sidecar JSON found for a modality ('meg', 'eeg', 'nirs'), with or without session folders
function sidecar = FindSidecar(bidsFolder, modality)
    sidecar = [];
    subDirs = dir(bst_fullfile(bidsFolder, 'sub-*'));
    subDirs = subDirs([subDirs.isdir]);
    for iSub = 1:length(subDirs)
        % Empty-room recordings are not representative of the dataset
        if strcmp(subDirs(iSub).name, 'sub-emptyroom')
            continue;
        end
        subPath = bst_fullfile(bidsFolder, subDirs(iSub).name);
        files = [dir(bst_fullfile(subPath, 'ses-*', modality, ['*_' modality '.json'])); ...
                 dir(bst_fullfile(subPath, modality, ['*_' modality '.json']))];
        for iFile = 1:length(files)
            sidecar = ReadJsonFile(bst_fullfile(files(iFile).folder, files(iFile).name));
            if isstruct(sidecar)
                return;
            end
        end
    end
    sidecar = [];
end

% Parse a README file.
%   - Written by Brainstorm: extract the project fields (IsForeign = 0)
%   - Written by something else: the whole text is returned as project description (IsForeign = 1)
% Returns [] if the file cannot be read. Values are returned as written in the file (e.g. 'n/a').
function r = ParseReadme(readmeFile)
    r = [];
    try
        txt = fileread(readmeFile);
    catch
        return;
    end
    txt = strrep(txt, char(13), '');
    r = struct('ProjName', '', 'ProjID', '', 'ProjDesc', '', 'Categories', '', 'IsForeign', 0);
    tokTitle = regexp(txt, '^Project Title:[ \t]*([^\n]*)', 'tokens', 'once', 'lineanchors');
    if isempty(tokTitle)
        r.IsForeign = 1;
        r.ProjDesc = strtrim(txt);
        return;
    end
    r.ProjName = strtrim(tokTitle{1});
    tok = regexp(txt, '^Project ID:[ \t]*([^\n]*)', 'tokens', 'once', 'lineanchors');
    if ~isempty(tok)
        r.ProjID = strtrim(tok{1});
    end
    tok = regexp(txt, 'Project Description:\n(.*?)\n+Participant categories:', 'tokens', 'once');
    if ~isempty(tok)
        r.ProjDesc = strtrim(tok{1});
    end
    tok = regexp(txt, 'Participant categories:\n(.*?)\n+Trigger channels:', 'tokens', 'once');
    if ~isempty(tok)
        r.Categories = strtrim(tok{1});
    end
end


%% =================================================================================
%  === GUI HELPERS =================================================================
%  =================================================================================
% Titled section added to a tab
function jSection = CreateSection(jTab, sectionTitle)
    jSection = gui_river([2,2], [2,4,2,4]);
    jSection.setBorder(javax.swing.BorderFactory.createCompoundBorder(...
        java_scaled('titledborder', sectionTitle), javax.swing.BorderFactory.createEmptyBorder(0,5,0,0)));
    jTab.add(jSection);
end

% Label + single-line text field
function jText = AddTextRow(jSection, label)
    gui_component('Label', jSection, 'br', label);
    jText = gui_component('Text', jSection, 'hfill', '');
end

% Label + multi-line text area
function jArea = AddTextArea(jSection, label, nRows)
    gui_component('Label', jSection, 'br', label);
    jArea = javax.swing.JTextArea(nRows, 40);
    jArea.setLineWrap(true);
    jArea.setWrapStyleWord(true);
    jScroll = javax.swing.JScrollPane(jArea);
    jSection.add('br hfill', jScroll);
end

% Add a scrollable tab (anchored at the top so that sections keep their natural height)
function AddTab(jTabs, tabTitle, jTab)
    jOuter = javax.swing.JPanel(java.awt.BorderLayout());
    jOuter.add(jTab, java.awt.BorderLayout.NORTH);
    jScroll = javax.swing.JScrollPane(jOuter);
    jScroll.getVerticalScrollBar().setUnitIncrement(16);
    jTabs.addTab(tabTitle, jScroll);
end