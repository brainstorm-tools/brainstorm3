function varargout = panel_digitize_2024(varargin)
% PANEL_DIGITIZE_2024: Digitize EEG sensors and head shape.
% 
% USAGE:             panel_digitize_2024('Start')
%                    panel_digitize_2024('CreateSerialConnection')
%                    panel_digitize_2024('ResetDataCollection')
%      bstPanelNew = panel_digitize_2024('CreatePanel')
%                    panel_digitize_2024('SetSimulate', isSimulate)   Run this from command window BEFORE opening the Digitize panel.

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
% Authors: Elizabeth Bock & Francois Tadel, 2012-2017
%          Marc Lalancette, 2024
%          Chinmay Chinara, 2024

eval(macro_method);
end


%% ========================================================================
%  ======= INITIALIZE =====================================================
%  ========================================================================

%% ===== START =====
function Start(varargin) 
    global Digitize
    % Intialize global variable
    Digitize = struct(...
        'Options',          bst_get('DigitizeOptions'), ...
        'Type'            , [], ...
        'SerialConnection', [], ...
        'Mode',             0, ...
        'hFig',             [], ...
        'iDS',              [], ...
        'SubjectName',      [], ...
        'ConditionName',    [], ...
        'iStudy',           [], ...
        'BeepWav',          [], ...
        'isEditPts',        0, ... % for correcting a wrongly detected point manually
        'Points',           struct(...
            'Label',        [], ...
            'Type',         [], ...
            'Loc',          []), ...
        'iPoint',           0, ...
        'Transf',           []);
    
    % Fix old structure (bef 2024) for Digitize.Options.Montages
    if length(Digitize.Options.Montages) > 1 && ~isfield(Digitize.Options.Montages, 'ChannelFile')
        Digitize.Options.Montages(end).ChannelFile = [];
    end

    % ===== PARSE INPUT =====
    DigitizerType = 'Digitize';
    sSubject = [];
    iSubject = [];
    surfaceFile = [];
    if nargin > 0 && ~isempty(varargin{1})
        DigitizerType = varargin{1};
    end
    if nargin > 1 && ~isempty(varargin{2})
        sSubject = varargin{2};
    end
    if nargin > 2 && ~isempty(varargin{3})
        iSubject = varargin{3};
    end
    if nargin > 3 && ~isempty(varargin{4})
        surfaceFile = varargin{4};
    end
    Digitize.Type = DigitizerType;
    switch DigitizerType
        case 'Digitize'
            % Do nothing
        case '3DScanner'
            % Simulate
            SetSimulate(1);
        otherwise
            bst_error(sprintf('DigitizerType : "%s" is not supported', DigitizerType));
            return
    end

    % ===== PREPARE DATABASE =====
    % If no protocol: exit
    if (bst_get('iProtocol') <= 0)
        bst_error('Please create a protocol first.', Digitize.Type, 0);
        return;
    end

    % Ask for subject id
    if isempty(sSubject)
        Digitize.Options.PatientId = java_dialog('input', 'Please, enter subject ID:', Digitize.Type, [], Digitize.Options.PatientId);
        if isempty(Digitize.Options.PatientId)
            return;
        end
        % Save new ID
        bst_set('DigitizeOptions', Digitize.Options);
        
        % ===== GET SUBJECT =====
        % Save the new SubjectName
        if strcmpi(Digitize.Type, '3DScanner')
            Digitize.SubjectName = [Digitize.Type, '_', Digitize.Options.PatientId];
        else
            Digitize.SubjectName = Digitize.Type;
        end
    
        [sSubject, iSubject] = bst_get('Subject', Digitize.SubjectName);
    else
        Digitize.SubjectName = sSubject.Name;
    end

    % Create if subject doesnt exist
    if isempty(iSubject)
        % Default anat / one channel file per subject
        if strcmpi(Digitize.Type, '3DScanner')
            [sSubject, iSubject] = db_add_subject(Digitize.SubjectName, iSubject);
            sTemplates = bst_get('AnatomyDefaults');
            db_set_template(iSubject, sTemplates(1), 1);
        else
            UseDefaultAnat = 1;
            UseDefaultChannel = 0;
            [sSubject, iSubject] = db_add_subject(Digitize.SubjectName, iSubject, UseDefaultAnat, UseDefaultChannel);
        end
        % Update tree
        panel_protocols('UpdateTree');
    end

    % ===== INITIALIZE CONNECTION =====
    % Start Serial Connection
    if ~CreateSerialConnection()
        return;
    end
    
    % ===== CREATE CONDITION =====
    % Get current date/time
%     CurrentDate = char(datetime('now'), 'yyyyMMdd');
    c = clock;
    % Condition name: PatientId_Date_Run
    for i = 1:99
        % Generate new condition name
        Digitize.ConditionName = sprintf('%s_%02d%02d%02d_%02d', Digitize.Options.PatientId, c(1), c(2), c(3), i);
        % Get condition
        sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
        % If condition doesn't exist: ok, keep this one
        if isempty(sStudy)
            break;
        end
    end
    % Create condition
    Digitize.iStudy = db_add_condition(Digitize.SubjectName, Digitize.ConditionName);
    sStudy = bst_get('Study', Digitize.iStudy);
    % Create an empty channel file in there
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = Digitize.ConditionName;
    % Save new channel file
    ChannelFile = bst_fullfile(bst_fileparts(file_fullpath(sStudy.FileName)), ['channel_' Digitize.ConditionName '.mat']);
    bst_save(ChannelFile, ChannelMat, 'v7');
    % Reload condition to update the functional nodes
    db_reload_studies(Digitize.iStudy);

    if strcmpi(Digitize.Type, '3DScanner')
        if isempty(surfaceFile)
            % Import surface
            iSurface = find(cellfun(@(x)~isempty(regexp(x, 'tess_textured', 'match')), {sSubject.Surface.FileName}));
            if isempty(iSurface)
                [~, surfaceFiles] = import_surfaces(iSubject);
                if isempty(surfaceFiles)
                    return
                end
                surfaceFile = file_short(surfaceFiles{end});
            else
                [res, isCancel] = java_dialog('question', ['There is already scanned mesh available for this subject.' 10 10 ...
                                                           'What do you want to do?'], ...
                                                           'Import surface', [], {'Use existing', 'Add new', 'Cancel'}, 'Use existing');
                if strcmpi(res, 'cancel') || isCancel
                    return
                elseif strcmpi(res, 'use existing')
                    % If more than one surface present, user can choose
                    if length(iSurface) > 1
                        texSurfComment = java_dialog('combo', '<HTML>Select the textured surface:<BR><BR>', 'Choose textured surface', [], {sSubject.Surface(iSurface).Comment});
                        texSurfComment = strrep(texSurfComment, '_defaced', '');
                        if isempty(texSurfComment)
                            return
                        end
                        iSurfFile = find(cellfun(@(x)~isempty(regexp(x, [texSurfComment '.mat'], 'match')), {sSubject.Surface.FileName}));
                        surfaceFile = sSubject.Surface(iSurfFile).FileName;
                    % If only one surface is present, then load it directly
                    else                    
                        surfaceFile = sSubject.Surface(iSurface(end)).FileName;
                    end
                elseif strcmpi(res, 'add new')
                    % Import a new textured mesh and append it to the list
                    [~, surfaceFiles] = import_surfaces(iSubject);
                    if isempty(surfaceFiles)
                        return
                    end
                    surfaceFile = file_short(surfaceFiles{end});
                end
            end
        end
        bst_progress('start', Digitize.Type, 'Loading surface file...');
        Digitize.surfaceFile = surfaceFile;
        sSurf = bst_memory('LoadSurface', Digitize.surfaceFile);
        % Display surface
        view_surface_matrix(sSurf.Vertices, sSurf.Faces, [], sSurf.Color, [], [], Digitize.surfaceFile);
    end

    % ===== DISPLAY DIGITIZE WINDOW =====
    % Display panel
    % Set the window to the position of the main Bst window, which is then hidden
    % Set window title to Digitize.Type
    panelContainer = gui_show('panel_digitize_2024', 'JavaWindow', Digitize.Type, [], [], [], [], [0,0]);
    
    % Hide Brainstorm window
    jBstFrame = bst_get('BstFrame');
    jBstFrame.setVisible(0);
    drawnow;
    
    % Hard-coded window size for now
    panelContainer.handle{1}.setSize(600, 600);
    % Set the window to the left of the screen
    loc = panelContainer.handle{1}.getLocation();
    loc.x = 0;
    panelContainer.handle{1}.setLocation(loc);
    
    % Load beep sound
    wavfile = bst_fullfile(bst_get('BrainstormHomeDir'), 'toolbox', 'sensors', 'private', 'bst_beep.wav');
    [Digitize.BeepWav.data, Digitize.BeepWav.fs] = audioread(wavfile);

    % Reset collection
    ResetDataCollection();    
end


%% ========================================================================
%  ======= PANEL FUNCTIONS ================================================
%  ========================================================================

%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel() 
    global Digitize
    
    % Constants
    panelName = 'Digitize';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import java.awt.event.KeyEvent;
    import org.brainstorm.list.*;
    import org.brainstorm.icon.*;
    % Create new panel
    jPanelNew = gui_component('Panel');
    % Font size for the lists
    veryLargeFontSize = round(100 * bst_get('InterfaceScaling') / 100);
    largeFontSize = round(20 * bst_get('InterfaceScaling') / 100);
    fontSize      = round(11 * bst_get('InterfaceScaling') / 100);

    % ===== MENU BAR =====
    jPanelMenu = gui_component('panel');
    jMenuBar = java_create('javax.swing.JMenuBar');
    jPanelMenu.add(jMenuBar, BorderLayout.NORTH);
    jLabelNews = gui_component('label', jPanelMenu, BorderLayout.CENTER, ...
                               ['<HTML><div align="center"><b>Digitize version: "2024"</b></div>' ...
                                '&bull To go back to previous version: <i>File > Switch to Digitize "legacy"</i> &#8198&#8198' ...
                                '&bull More details: <i>Help > Digitize tutorial</i>'], [], [], [], fontSize);
    jLabelNews.setHorizontalAlignment(SwingConstants.CENTER);
    jLabelNews.setOpaque(true);
    jLabelNews.setBackground(java.awt.Color.yellow);

    % ===== FILE MENU =====
    jMenu = gui_component('Menu', jMenuBar, [], 'File', [], [], [], []);
    gui_component('MenuItem', jMenu, [], 'Start over', IconLoader.ICON_RELOAD, [], @(h,ev)bst_call(@ResetDataCollection, 1), []);
    gui_component('MenuItem', jMenu, [], 'Edit settings...', IconLoader.ICON_EDIT, [], @(h,ev)bst_call(@EditSettings), []);
    gui_component('MenuItem', jMenu, [], 'Switch to Digitize "legacy"', [], [], @(h,ev)bst_call(@SwitchVersion), []);
    if ~strcmpi(Digitize.Type, '3DScanner')
        gui_component('MenuItem', jMenu, [], 'Reset serial connection', IconLoader.ICON_FLIP, [], @(h,ev)bst_call(@CreateSerialConnection), []);
    end
    jMenu.addSeparator();
    if exist('bst_headtracking', 'file') && ~strcmpi(Digitize.Type, '3DScanner')
        gui_component('MenuItem', jMenu, [], 'Start head tracking', IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)bst_call(@(h,ev)bst_headtracking([],1,1)), []);
        jMenu.addSeparator();
    end
    gui_component('MenuItem', jMenu, [], 'Save as...', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@Save_Callback), []);
    gui_component('MenuItem', jMenu, [], 'Save in database and exit', IconLoader.ICON_RESET, [], @(h,ev)bst_call(@Close_Callback), []);
    % ===== EEG MONTAGE MENU =====
    jMenuEeg = gui_component('Menu', jMenuBar, [], 'EEG montage', [], [], [], []);    
    CreateMontageMenu(jMenuEeg);
    % ===== HELP MENU =====
    jMenuHelp = gui_component('Menu', jMenuBar, [], 'Help', [], [], [], []);
    gui_component('MenuItem', jMenuHelp, [], 'Digitize tutorial', [], [], @(h,ev)web('https://neuroimage.usc.edu/brainstorm/Tutorials/TutDigitize', '-browser'), []);
    
    jPanelNew.add(jPanelMenu, BorderLayout.NORTH);

    % ===== CONTROL PANEL =====
    jPanelControl = gui_component('panel');
    jPanelControl.setBorder(BorderFactory.createEmptyBorder(0,0,7,0));

    % ===== NEXT POINT PANEL =====
    jPanelNext = gui_river([5,4], [4,4,4,4], 'Next point');
        % Next point label
        jLabelNextPoint = gui_component('label', jPanelNext, [], '', [], [], [], veryLargeFontSize);
        jButtonFids = gui_component('button', jPanelNext, 'br', 'Add fiducials', [], 'Add set of fiducials to digitize', @(h,ev)bst_call(@Fiducials_Callback));
        jButtonFids.setEnabled(0);
        if strcmpi(Digitize.Type, '3DScanner')
            jButtonEEGAutoDetectElectrodes = gui_component('button', jPanelNext, [], 'Auto', [], GenerateTooltipTextAuto(), @(h,ev)bst_call(@EEGAutoDetectElectrodes));
        else
            % Separator
            jButtonEEGAutoDetectElectrodes = gui_component('label', jPanelNext, 'hfill', '');
        end
        jButtonEEGAutoDetectElectrodes.setEnabled(0);
    jPanelControl.add(jPanelNext, BorderLayout.NORTH);

    % ===== INFO PANEL =====
    jPanelInfo = gui_river([5,4], [10,10,10,10], '');
        % Message label
        jLabelWarning = gui_component('label', jPanelInfo, 'br', ' ', [], [], [], largeFontSize);
        gui_component('label', jPanelInfo, 'br', ''); % spacing
        % Number of head points collected
        gui_component('label', jPanelInfo, 'br', 'Head shape points');
        jTextFieldExtra = gui_component('text', jPanelInfo, [], '0', [], 'Head shape points digitized', @(h,ev)bst_call(@ExtraChangePoint_Callback), largeFontSize);
        initSize = jTextFieldExtra.getPreferredSize();
        jTextFieldExtra.setPreferredSize(Dimension(initSize.getWidth()*1.5, initSize.getHeight()*1.5))
        if strcmpi(Digitize.Type, '3DScanner')
            % Add 150 random head shape points generation button
            jButtonRandomHeadPts = gui_component('button', jPanelInfo, [], 'Random', [], 'Collect 150 head shape points from mesh', @(h,ev)bst_call(@CollectRandomHeadPts_Callback), largeFontSize);
            jButtonRandomHeadPts.setPreferredSize(Dimension(initSize.getWidth()*2.2, initSize.getHeight()*1.7));
        else
            % Separator
            jButtonRandomHeadPts = gui_component('label', jPanelInfo, 'hfill', '');
        end
        jButtonRandomHeadPts.setEnabled(0);
    jPanelControl.add(jPanelInfo, BorderLayout.CENTER);
    
    % ===== OTHER BUTTONS =====
    jPanelMisc = gui_river([5,4], [10,4,4,4]);
        if ~strcmpi(Digitize.Type, '3DScanner') 
            jButtonCollectPoint = gui_component('button', jPanelMisc, 'br', 'Collect point', [], [], @(h,ev)bst_call(@ManualCollect_Callback));
        else
            jButtonCollectPoint = gui_component('label', jPanelMisc, 'hfill', ''); % spacing
        end
        % Until initial fids are collected and figure displayed, "delete" button is used to "restart".
        jButtonDeletePoint = gui_component('button', jPanelMisc, [], 'Start over', [], [], @(h,ev)bst_call(@ResetDataCollection, 1));
        gui_component('label', jPanelMisc, 'hfill', ''); % spacing 
        gui_component('button', jPanelMisc, [], 'Save as...', [], [], @(h,ev)bst_call(@Save_Callback));
    jPanelControl.add(jPanelMisc, BorderLayout.SOUTH);
    jPanelNew.add(jPanelControl, BorderLayout.WEST);
                               
    % ===== COORDINATE DISPLAY PANEL =====
    jPanelDisplay = gui_component('Panel');
    jPanelDisplay.setBorder(java_scaled('titledborder', 'Coordinates (cm)'));
        % List of coordinates
        jListCoord = JList(fontSize);
        jListCoord.setCellRenderer(BstStringListRenderer(fontSize));
        java_setcb(jListCoord, ...
            'KeyTypedCallback',     @(h,ev)bst_call(@CoordListKeyTyped_Callback,h,ev), ...
            'MouseClickedCallback', @(h,ev)bst_call(@CoordListClick_Callback,h,ev));
        jPanelScrollList = JScrollPane(jListCoord);
        jPanelScrollList.setViewportView(jListCoord);
        jPanelScrollList.setHorizontalScrollBarPolicy(jPanelScrollList.HORIZONTAL_SCROLLBAR_NEVER);
        jPanelScrollList.setVerticalScrollBarPolicy(jPanelScrollList.VERTICAL_SCROLLBAR_ALWAYS);
        jPanelScrollList.setBorder(BorderFactory.createEmptyBorder(10,10,10,10));
        jPanelDisplay.add(jPanelScrollList, BorderLayout.CENTER);
    jPanelNew.add(jPanelDisplay, BorderLayout.CENTER);

    % Create the controls structure
    ctrl = struct('jMenuEeg',                       jMenuEeg, ...
                  'jButtonFids',                    jButtonFids, ...
                  'jLabelNextPoint',                jLabelNextPoint, ...
                  'jLabelWarning',                  jLabelWarning, ...
                  'jListCoord',                     jListCoord, ...
                  'jButtonEEGAutoDetectElectrodes', jButtonEEGAutoDetectElectrodes, ...
                  'jButtonRandomHeadPts',           jButtonRandomHeadPts, ...
                  'jTextFieldExtra',                jTextFieldExtra, ...
                  'jButtonCollectPoint',            jButtonCollectPoint, ...
                  'jButtonDeletePoint',             jButtonDeletePoint);
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);

    %% =================================================================================
    %  === INTERNAL CALLBACKS  =========================================================
    %  =================================================================================
    %% ===== COORDINATE LIST KEY TYPED CALLBACK =====
    function CoordListKeyTyped_Callback(h, ev)
        switch(uint8(ev.getKeyChar()))
            % Delete
            case {ev.VK_DELETE, ev.VK_BACK_SPACE}
                ctrl = bst_get('PanelControls', 'Digitize');
                % If contact list rendering is blank in panel then dont't proceed
                if ctrl.jListCoord.isSelectionEmpty()
                    return;
                end

                [sCoordName, iSelCoord] = GetSelectedCoord();
                spl = regexp(sCoordName,'\s+','split');
                nameFinal = spl{1};
                if (~strcmpi(nameFinal, 'NAS') &&...
                    ~strcmpi(nameFinal, 'LPA') &&...
                    ~strcmpi(nameFinal, 'RPA'))
                    listModel = ctrl.jListCoord.getModel();
                    listModel.setElementAt(nameFinal, iSelCoord-1);  
                    Digitize.iPoint = iSelCoord;
                    Digitize.isEditPts = 1;
                    DeletePoint_Callback();
                end
        end
    end
    
    %% ===== COORDINATE LIST CLICK CALLBACK =====
    function CoordListClick_Callback(h, ev)
        % If single click
        if (ev.getClickCount() == 1)
            ctrl = bst_get('PanelControls', 'Digitize');
            % If contact list rendering is blank in panel then dont't proceed
            if ctrl.jListCoord.isSelectionEmpty()
                return;
            end
            
            [sCoordName, ~] = GetSelectedCoord();
            spl = regexp(sCoordName,'\s+','split');
            nameFinal = spl{1};
            bst_figures('SetSelectedRows', nameFinal);
        end
    end
end

%% ===== GET SELECTED ELECTRODE =====
function [sCoordName, iSelCoord] = GetSelectedCoord()
    global Digitize
    % Get panel handles
    ctrl = bst_get('PanelControls', 'Digitize');
    if isempty(ctrl)
        return;
    end

    % Get JList selected indices
    iSelCoord = uint16(ctrl.jListCoord.getSelectedIndices())' + 1;
    listModel = ctrl.jListCoord.getModel();
    sCoordName = listModel.getElementAt(iSelCoord-1);
end

%% ===== SWITCH TO OLD VERSION =====
function SwitchVersion()
    % Always confirm this switch.
    if ~java_dialog('confirm', ['<HTML>Switch to legacy version of the Digitize panel?<BR>', ...
            'See Digitize tutorial (Digitize panel > Help menu).<BR>', ...
            '<B>This will close the window. Any unsaved points will be lost.</B>'], 'Digitize version')
        return;
    end
    % Close this panel
    Close_Callback();
    % Save the preferred version. Must be after closing
    DigitizeOptions = bst_get('DigitizeOptions');
    DigitizeOptions.Version = 'legacy';
    bst_set('DigitizeOptions', DigitizeOptions);
end

%% ===== CLOSE =====
function Close_Callback()
    % Save channel file
    SaveDigitizeChannelFile();
    % Close panel
    gui_hide('Digitize');
end

%% ===== HIDING CALLBACK =====
function isAccepted = PanelHidingCallback() 
    global Digitize;
    % If Brainstorm window was hidden before showing the Digitizer
    if bst_get('isGUI')
        % Get Brainstorm frame
        jBstFrame = bst_get('BstFrame');
        % Hide Brainstorm window
        jBstFrame.setVisible(1);
    end
    % Get study
    [sStudy, iStudy] = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    % If nothing was clicked: delete the condition that was just created
    if isempty(Digitize.Transf)
        % Delete study
        if ~isempty(iStudy)
            db_delete_studies(iStudy);
            panel_protocols('UpdateTree');
        end
    % Else: reload to get access to the EEG type of sensors
    else
        db_reload_studies(iStudy);
    end
    % Close serial connection, in particular to avoid further callbacks if stylus is pressed.
    if ~isempty(Digitize.SerialConnection)
        delete(Digitize.SerialConnection);
        Digitize.SerialConnection = []; % cleaner than "handle to deleted serialport".
    end
    % Could also: clear Digitize;
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    isAccepted = 1;
end


%% ===== EDIT SETTINGS =====
function isOk = EditSettings()
    global Digitize
    
    isOk = 0;
    % Ask for new options
    if isfield(Digitize.Options, 'Fids') && iscell(Digitize.Options.Fids)
        FidsString = sprintf('%s, ', Digitize.Options.Fids{:});
        FidsString(end-1:end) = '';
    else
        FidsString = 'NAS, LPA, RPA';
    end
    if isfield(Digitize.Options, 'ConfigCommands') && iscell(Digitize.Options.ConfigCommands) && ...
            ~isempty(Digitize.Options.ConfigCommands)
        ConfigString = sprintf('%s; ', Digitize.Options.ConfigCommands{:});
        ConfigString(end-1:end) = '';
    else
        ConfigString = '';
    end
    
    % GUI all potential options: {Description, default values}
    options_all = {'<HTML><B>Serial connection settings</B><BR><BR>Serial port name (COM1):', ...
                    Digitize.Options.ComPort;
                   'Unit Type (Fastrak or Patriot):', ...
                    Digitize.Options.UnitType; ...
                   '<HTML>Additional device configuration commands, separated by ";"<BR>(see device documentation, e.g. H1,0,0,-1;H2,0,0,-1):', ...
                    ConfigString; ...
                   '<HTML><BR><B>Collection settings</B><BR><BR>List anatomy and possibly MEG fiducials, in desired order<BR>(NAS, LPA, RPA, HPI-N, HPI-L, HPI-R, HPI-X):', ...
                    FidsString; ...
                   '<HTML>How many times do you want to localize<BR>these fiducials at the start:', ...
                    num2str(Digitize.Options.nFidSets); ...
                   'Distance threshold for repeated measure of fiducial locations (mm):', ...
                    num2str(Digitize.Options.DistThresh * 1000); ... % m to mm
                   'Beep when collecting point (0=no, 1=yes):', ...;
                    num2str(Digitize.Options.isBeep)};

    % Options to show for each type
    switch lower(Digitize.Type)     
        case 'digitize'
            iOptionsType = [1:7];
        case '3dscanner'
            iOptionsType = [4:7];
    end
    
    % Ask options
    [resType, isCancel] = java_dialog('input', options_all(iOptionsType,1), [Digitize.Type ' configuration'], [], options_all(iOptionsType,2));                
    if isempty(resType) || isCancel
        return
    end

    % Results from options asked to user
    options_all(iOptionsType, 3) = resType;
    % Results from options not asked to user
    iOptionsKeep = setdiff([1:length(options_all)], iOptionsType);
    options_all(iOptionsKeep, 3) = options_all(iOptionsKeep,2);
    res = options_all(:,3);

    % Check values
    if length(resType) < length(iOptionsType) ||  (ismember(1, iOptionsType) && isempty(res{1})) || ...
                                                  (ismember(2, iOptionsType) && isempty(res{2})) || ...
                                                  (ismember(5, iOptionsType) && isnan(str2double(res{5}))) || ...
                                                  (ismember(6, iOptionsType) && isnan(str2double(res{6}))) || ...
                                                  (ismember(7, iOptionsType) && ~ismember(str2double(res{7}), [0 1]))
            bst_error('Invalid values.', 'Digitize', 0);
        return;
    end
    % Digitizer: COM port
    Digitize.Options.ComPort  = res{1};
    % Digitizer: Type
    Digitize.Options.UnitType = lower(res{2});
    % Digitizer: COM properties
    if isempty(Digitize.Options.UnitType)
        % Do nothing
    elseif strcmp(Digitize.Options.UnitType,'fastrak')
        Digitize.Options.ComRate = 9600;
        Digitize.Options.ComByteCount = 94;
    elseif strcmp(Digitize.Options.UnitType,'patriot')
        Digitize.Options.ComRate = 115200;
        Digitize.Options.ComByteCount = 120;
    else
        bst_error('Incorrect unit type.', Digitize.Type, 0);
        return;
    end
    % Digitizer: Parse device configuration commands. Remove all spaces, and split at ";"
    Digitize.Options.ConfigCommands = str_split(strrep(res{3}, ' ', ''), ';', true); % remove empty
    % Common: Parse fiducials.
        Digitize.Options.Fids = str_split(res{4}, '()[],;"'' ', true); % remove empty
    if isempty(Digitize.Options.Fids) || ~iscell(Digitize.Options.Fids) || numel(Digitize.Options.Fids) < 3
        bst_error('At least 3 anatomy fiducials are required, e.g. NAS, LPA, RPA.', Digitize.Type, 0);
        Digitize.Options.Fids = {'NAS', 'LPA', 'RPA'};
        return;
    end
    % Common: Number of fiducial sets
    if ~isempty(res{5})
        Digitize.Options.nFidSets = str2double(res{5});
    end
    % Common: Threshold for distance in fiducial sets
    if ~isempty(res{6})
        Digitize.Options.DistThresh = str2double(res{6}) / 1000; % mm to m
    end
    % Common: Beep
    if ~isempty(res{7})
        Digitize.Options.isBeep = str2double(res{7});
    end

    for iFid = 1:numel(Digitize.Options.Fids)
        switch lower(Digitize.Options.Fids{iFid})
            % Possible names copied from channel_detect_type
            case {'nas', 'nasion', 'nz', 'fidnas', 'fidnz', 'n', 'na'}
                Digitize.Options.Fids{iFid} = 'NAS';
            case {'lpa', 'pal', 'og', 'left', 'fidt9', 'leftear', 'l'}
                Digitize.Options.Fids{iFid} = 'LPA';
            case {'rpa', 'par', 'od', 'right', 'fidt10', 'rightear', 'r'}
                Digitize.Options.Fids{iFid} = 'RPA';
            otherwise
                if ~strfind(lower(Digitize.Options.Fids{iFid}), 'hpi')
                    bst_error(sprintf('Unrecognized fiducial: %s', Digitize.Options.Fids{iFid}), Digitize.Type, 0);
                    return;
                end
                Digitize.Options.Fids{iFid} = upper(Digitize.Options.Fids{iFid});
        end
    end
    
    % Save values
    bst_set('DigitizeOptions', Digitize.Options);
    isOk = 1;

    % If no points collected, reset.
    if isempty(Digitize.Points) || ~isfield(Digitize.Points, 'Loc') || isempty(Digitize.Points(1).Loc)
        ResetDataCollection(1);
    end
end


%% ===== SET SIMULATION MODE =====
% USAGE:  panel_digitize_2024('SetSimulate', isSimulate)
% Run this from command line BEFORE opening the Digitize panel.
function SetSimulate(isSimulate) 
    DigitizeOptions = bst_get('DigitizeOptions');
    % Change value
    DigitizeOptions.isSimulate = isSimulate;
    bst_set('DigitizeOptions', DigitizeOptions);
end


%% ========================================================================
%  ======= ACQUISITION FUNCTIONS ==========================================
%  ========================================================================

%% ===== RESET DATA COLLECTION =====
function ResetDataCollection(isResetSerial)
    global Digitize
    bst_progress('start', Digitize.Type, 'Initializing...');
    % Reset serial?
    if (nargin == 1) && isequal(isResetSerial, 1)
        CreateSerialConnection();
    end
    % Reset points structure
    Digitize.Points = struct(...
            'Label',     [], ...
            'Type',      [], ...
            'Loc',       []);
    Digitize.iPoint = 0;
    Digitize.Transf = [];
    % Reset figure (also unloads in global data)
    if ~isempty(Digitize.hFig) && ishandle(Digitize.hFig)
        bst_figures('DeleteFigure', Digitize.hFig, []);

        % For 3D Scanner reload the surface
        if strcmpi(Digitize.Type, '3DScanner')
            % Load the surface
            sSurf = bst_memory('LoadSurface', Digitize.surfaceFile);
            % Display surface
            view_surface_matrix(sSurf.Vertices, sSurf.Faces, [], sSurf.Color, [], [], Digitize.surfaceFile);
        end
    end
    Digitize.iDS = [];
    
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    % Reset counters
    ctrl.jTextFieldExtra.setText(num2str(0));
    ctrl.jTextFieldExtra.setEnabled(0);
    java_setcb(ctrl.jButtonDeletePoint, 'ActionPerformedCallback', @(h,ev)bst_call(@ResetDataCollection, 1));
    ctrl.jButtonDeletePoint.setText('Start over');
    ctrl.jLabelWarning.setText('');
    ctrl.jLabelWarning.setBackground([]);

    % Generate list of labeled points
    % Initial fiducials
    for iP = 1:numel(Digitize.Options.Fids)
        Digitize.Points(iP).Label = Digitize.Options.Fids{iP};
        Digitize.Points(iP).Type = 'CARDINAL';
    end
    if Digitize.Options.nFidSets > 1
        Digitize.Points = repmat(Digitize.Points, 1, Digitize.Options.nFidSets);
    end
    % EEG
    [curMontage, nEEG] = GetCurrentMontage();
    for iEEG = 1:nEEG
        Digitize.Points(end+1).Label = curMontage.Labels{iEEG};
        Digitize.Points(end).Type = 'EEG';
    end
    
    % Display list in text box
    UpdateList();

    % Close progress bar
    bst_progress('stop');
end


%% ===== UPDATE LIST OF POINTS IN TEXT BOX =====
function UpdateList()
    global Digitize;
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    % Define the model
    listModel = javax.swing.DefaultListModel();
    % Add points to list
    iHeadPoints = 0;
    lastIndex = 0;
    for iP = 1:numel(Digitize.Points)
        if ~isempty(Digitize.Points(iP).Label)
            listModel.addElement(sprintf('%s     %3.3f   %3.3f   %3.3f', Digitize.Points(iP).Label, Digitize.Points(iP).Loc .* 100));
        else % Head points
            iHeadPoints = iHeadPoints + 1;
            listModel.addElement(sprintf('%03d     %3.3f   %3.3f   %3.3f', iHeadPoints, Digitize.Points(iP).Loc .* 100));
        end
        if ~isempty(Digitize.Points(iP).Loc)
            lastIndex = iP;
        end
    end
    % Set this list
    ctrl.jListCoord.setModel(listModel);
    % Scroll to last collected point (non-empty Loc), +1 if more points listed.
    if listModel.getSize() > lastIndex
        ctrl.jListCoord.ensureIndexIsVisible(lastIndex); % 0-indexed
    else
        ctrl.jListCoord.ensureIndexIsVisible(lastIndex-1); % 0-indexed, -1 works even if 0
    end
    % Also update label of next point to digitize.
    if numel(Digitize.Points) >= Digitize.iPoint + 1 && ~isempty(Digitize.Points(Digitize.iPoint + 1).Label)
        ctrl.jLabelNextPoint.setText(Digitize.Points(Digitize.iPoint + 1).Label);
    else
        ctrl.jLabelNextPoint.setText(num2str(iHeadPoints + 1));
    end

    % Update tooltip text for 'Auto' button
    if strcmpi(Digitize.Type, '3DScanner')
        ctrl.jButtonEEGAutoDetectElectrodes.setToolTipText(GenerateTooltipTextAuto());
    end
end

%% ===== 3DSCANNER: AUTOMATICALLY DETECT AND LABEL EEG CAP ELECTRODES =====
function EEGAutoDetectElectrodes()
    global Digitize GlobalData

    % Add disclaimer to users that 'Auto' feature is experimental
    if ~java_dialog('confirm', ['<HTML> Automatic detection of EEG sensors is an <B>experimental</B> feature. <BR>' ...
                                'Please verify the results carefully. <BR><BR>' ...
                                'Do you want to continue?'], 'Auto detect EEG electrodes')
        return
    end
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    % Disable Auto button
    ctrl.jButtonEEGAutoDetectElectrodes.setEnabled(0);
    % Progress bar
    bst_progress('start', Digitize.Type, 'Automatic labelling of EEG sensors...');

    % Get current montage
    curMontage = GetCurrentMontage();
    isWhiteCap = 0;
    % For white caps change the color space by inverting the colors
    % NOTE: only 'Acticap' is the tested white cap (needs work on finding a better aprrooach)
    if ~isempty(regexp(curMontage.Name, 'ActiCap', 'match'))
        isWhiteCap = 1;
    end

    % Get the cap surface from 3D scanner
    hFig = bst_figures('GetCurrentFigure','3D');
    TessInfo = getappdata(hFig, 'Surface');
    sSurf = bst_memory('LoadSurface', TessInfo.SurfaceFile);
    
    % Automatically find electrodes locations on EEG cap
    [capCenters2d, capImg2d, surface3dscannerUv] = channel_detect_eegcap_auto('FindElectrodesEegCap', sSurf, isWhiteCap);
    if isempty(Digitize.Options.Montages(Digitize.Options.iMontage).ChannelFile)
        bst_error('EEG cap layout not selected. Go to EEG', Digitize.Type, 1);
        bst_progress('stop');
        return;
    else
        ChannelMat = in_bst_channel(Digitize.Options.Montages(Digitize.Options.iMontage).ChannelFile);
    end

    % Get acquired EEG points
    iEeg = and(cellfun(@(x) ~isempty(regexp(x, 'EEG', 'match')), {Digitize.Points.Type}), ~cellfun(@isempty, {Digitize.Points.Loc}));
    pointsEEG = Digitize.Points(iEeg);
    
    % Warp points from layout to mesh
    capPoints3d = channel_detect_eegcap_auto('WarpLayout2Mesh', capCenters2d, capImg2d, surface3dscannerUv, ChannelMat.Channel, pointsEEG);

    % Plot the electrodes and their labels
    for iPoint= 1:length(capPoints3d)        
        % Find found point in current montage and set it in global
        [~, Digitize.iPoint] = ismember(capPoints3d(iPoint).Label, {Digitize.Points.Label});
        Digitize.Points(Digitize.iPoint).Loc = capPoints3d(iPoint).Loc;
        Digitize.Points(Digitize.iPoint).Type = 'EEG';
        % Add the point to the display (in cm)
        PlotCoordinate();
    end

    UpdateList();
    % Enable Random button
    ctrl.jButtonRandomHeadPts.setEnabled(1);
    bst_progress('stop');

end

%% ===== MANUAL COLLECT CALLBACK ======
function ManualCollect_Callback()
    global Digitize
    ctrl = bst_get('PanelControls', 'Digitize');
    ctrl.jButtonCollectPoint.setEnabled(0);
    % Simulation: call the callback directly
    if Digitize.Options.isSimulate
        BytesAvailable_Callback();
    % Else: Send a collection request to the Polhemus
    else
        % User clicked the button, collect a point
        writeline(Digitize.SerialConnection,'P');
        pause(0.2);
    end
    ctrl.jButtonCollectPoint.setEnabled(1);
end

%% ===== COLLECT RANDOM HEADPOINTS =====
function CollectRandomHeadPts_Callback()
    global Digitize
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    % Disable Random button
    ctrl.jButtonRandomHeadPts.setEnabled(0);
    % Progress bar
    bst_progress('start', Digitize.Type, 'Plotting 150 random head shape points...');

    hFig = bst_figures('GetCurrentFigure','3D');
    TessInfo = getappdata(hFig, 'Surface');
    TessMat = bst_memory('LoadSurface', TessInfo.SurfaceFile);
    
    % Brainstorm recommends to collect approximately 100-150 points from the head
    % 5-10 points from the boney part of the nose
    PlotHeadShapePoints(TessMat.Vertices, 'nose', 10);
    % 10-20 points across the left eyebrow   
    PlotHeadShapePoints(TessMat.Vertices, 'leyebrow', 20);
    % 10-20 points across the right eyebrow
    PlotHeadShapePoints(TessMat.Vertices, 'reyebrow', 20);
    % 100 points on the scalp
    PlotHeadShapePoints(TessMat.Vertices, 'scalp', 100);
    
    UpdateList();
    bst_progress('stop');
end

%% ===== PLOT HEAD SHAPE POINTS =====
function PlotHeadShapePoints(Vertices, plotRegion, nPoints)
    global Digitize
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    
    % Get the plotting parameters based on the region in the head
    switch plotRegion
        case 'nose'
            nosePoint     = Digitize.Points(1).Loc;
            % Get 600 nearest points to the 'nosePoint' and choose 'nPoints' from it
            nearPointsIdx = bst_nearest(Vertices, nosePoint, 600, 0, []);
            range         = length(nearPointsIdx);
            stepFactor    = range/nPoints;            
        case 'leyebrow'
            lEyebrowPoint = (1.25 * Digitize.Points(1).Loc) + (0.5 * Digitize.Points(2).Loc);
            % Get 400 nearest points to the 'lEyebrowPoint' and choose 'nPoints' from it
            nearPointsIdx = bst_nearest(Vertices, lEyebrowPoint, 400, 0, []);
            range         = length(nearPointsIdx);
            stepFactor    = range/nPoints;
        case 'reyebrow'
            rEyebrowPoint = (1.25 * Digitize.Points(1).Loc) + (0.5 * Digitize.Points(3).Loc);
            % Get 400 nearest points to the 'rEyebrowPoint' and choose 'nPoints' from it
            nearPointsIdx = bst_nearest(Vertices, rEyebrowPoint, 400, 0, []);
            range         = length(nearPointsIdx);
            stepFactor    = range/nPoints;
        case 'scalp'
            range         = length(Vertices);
            stepFactor    = ceil(range/nPoints);
        otherwise
            bst_error([plotRegion 'is invalid for plotting head shape'], Digitize.Type, 0);
            bst_progress('stop');
            return
    end
    
    % Plot the head shape points
    for i= 1:stepFactor:range
        % Increment current point index
        Digitize.iPoint = Digitize.iPoint + 1;
        % Update the coordinate and Type 
        if strcmpi(plotRegion, 'scalp')
            Digitize.Points(Digitize.iPoint).Loc = Vertices(i, :);
        else
            Digitize.Points(Digitize.iPoint).Loc = Vertices(nearPointsIdx(i), :);
        end
        Digitize.Points(Digitize.iPoint).Type = 'EXTRA';
        % Add the point to the display (in cm)
        PlotCoordinate();
        % Update text field counter to the next point in the list
        iCount = str2double(ctrl.jTextFieldExtra.getText());
        ctrl.jTextFieldExtra.setText(num2str(iCount + 1));
    end
end

%% ===== DELETE POINT CALLBACK =====
function DeletePoint_Callback()
    global Digitize
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');

    % If we're down to initial fids only, change delete button label and callback to "restart" instead of delete.
    if Digitize.iPoint <= numel(Digitize.Options.Fids) * Digitize.Options.nFidSets + 1
        java_setcb(ctrl.jButtonDeletePoint, 'ActionPerformedCallback', @(h,ev)bst_call(@ResetDataCollection, 1));
        ctrl.jButtonDeletePoint.setText('Start over');
        % Safety check, but this should not happen.
        if Digitize.iPoint <= numel(Digitize.Options.Fids) * Digitize.Options.nFidSets
            error('Cannot delete initial fiducials.');
        end
    end

    % Remove last point from figure. It must still be in the list.
    PlotCoordinate(false); % isAdd = false: remove last point instead of adding one

    % Decrement head shape point count
    if strcmpi(Digitize.Points(Digitize.iPoint).Type, 'EXTRA')
        nShapePts = str2num(ctrl.jTextFieldExtra.getText());
        ctrl.jTextFieldExtra.setText(num2str(max(0, nShapePts - 1)));
    end

    % Remove last point in list
    if ~isempty(Digitize.Points(Digitize.iPoint).Label)
        % Keep point in list, but remove location and decrease index to collect again
        Digitize.Points(Digitize.iPoint).Loc = [];
    else
        % Delete the point from the list entirely
        Digitize.Points(Digitize.iPoint) = [];
    end
    Digitize.iPoint = Digitize.iPoint - 1;

    % Update coordinates list
    UpdateList();
end

%% ===== CHECK FIDUCIALS: ADD SET TO DIGITIZE NOW =====
function Fiducials_Callback()
    global Digitize
    nRemaining = numel(Digitize.Points) - Digitize.iPoint;
    nFids = numel(Digitize.Options.Fids);
    if nRemaining > 0
        % Add space in points array.
        Digitize.Points(Digitize.iPoint + nFids + (1:nRemaining)) = Digitize.Points(Digitize.iPoint + (1:nRemaining));
    end
    for iP = 1:nFids
        Digitize.Points(Digitize.iPoint + iP).Label = Digitize.Options.Fids{iP};
        Digitize.Points(Digitize.iPoint + iP).Type = 'CARDINAL';
    end
    UpdateList();
end

%% ===== CREATE FIGURE =====
function CreateHeadpointsFigure()
    global Digitize    
    if isempty(Digitize.hFig) || ~ishandle(Digitize.hFig) || isempty(Digitize.iDS)
        % Get study
        sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
        % Plot head points and save handles in global variable
        [Digitize.hFig, Digitize.iDS] = view_headpoints(file_fullpath(sStudy.Channel.FileName));
        % Hide head surface
        panel_surface('SetSurfaceTransparency', Digitize.hFig, 1, 0.8);
        % Get Digitizer JFrame
        bstContainer = get(bst_get('Panel', 'Digitize'), 'container');
        % Get maximum figure position
        decorationSize = bst_get('DecorationSize');
        [~, FigArea] = gui_layout('GetScreenBrainstormAreas', bstContainer.handle{1});
        FigPos = FigArea(1,:) + [decorationSize(1),  decorationSize(4),  - decorationSize(1) - decorationSize(3),  - decorationSize(2) - decorationSize(4)];
        if (FigPos(3) > 0) && (FigPos(4) > 0)
            set(Digitize.hFig, 'Position', FigPos);
        end
        % Remove the close handle function
        set(Digitize.hFig, 'CloseRequestFcn', []);
    else
        % Hide figure
        set(Digitize.hFig, 'Visible', 'off');
        % Get study
        sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
        % Plot head points and save handles in global variable
        [Digitize.hFig, Digitize.iDS] = view_headpoints(file_fullpath(sStudy.Channel.FileName));
        % Get the surface
        sSurf = bst_memory('LoadSurface', Digitize.surfaceFile);
        % Apply the transformation
        sSurf.Vertices = [sSurf.Vertices ones(size(sSurf.Vertices,1),1)] * Digitize.Transf';
        % Remove the surface
        panel_surface('RemoveSurface', Digitize.hFig, 1);
        % Deface the surface
        if isempty(regexp(sSurf.Comment, 'defaced', 'match'))
            sSurf = tess_deface(sSurf);
        end
        % Save the surface and update the node
        ProtocolInfo = bst_get('ProtocolInfo');
        surfaceFile = bst_fullfile(ProtocolInfo.SUBJECTS, Digitize.surfaceFile);
        bst_save(surfaceFile, sSurf, 'v7');
        [~, iSubject] = bst_get('Subject', Digitize.SubjectName);
        db_reload_subjects(iSubject);
        % Get Digitizer JFrame
        bstContainer = get(bst_get('Panel', 'Digitize'), 'container');
        % Get maximum figure position
        decorationSize = bst_get('DecorationSize');
        [~, FigArea] = gui_layout('GetScreenBrainstormAreas', bstContainer.handle{1});
        FigPos = FigArea(1,:) + [decorationSize(1),  decorationSize(4),  - decorationSize(1) - decorationSize(3),  - decorationSize(2) - decorationSize(4)];
        % Display updated surface
        view_surface_matrix(sSurf.Vertices, sSurf.Faces, [], sSurf.Color, Digitize.hFig, [], Digitize.surfaceFile);
        if (FigPos(3) > 0) && (FigPos(4) > 0)
            set(Digitize.hFig, 'Position', FigPos);
        end
        % Remove the close handle function
        set(Digitize.hFig, 'CloseRequestFcn', []);
    end 
end

%% ===== PLOT NEXT POINT, OR REMOVE LAST OR REMOVE SELECTED POINT =====
function PlotCoordinate(isAdd)
    if nargin < 1 || isempty(isAdd)
        isAdd = true;
    end
    global Digitize GlobalData

    % Add EEG sensor locations to channel stucture
    if strcmpi(Digitize.Points(Digitize.iPoint).Type, 'EEG')
        if ~isstruct(GlobalData.DataSet(Digitize.iDS).Channel) || ~isfield(GlobalData.DataSet(Digitize.iDS).Channel, 'Name')
            % First point in the list. This creates one channel, with empty fields.
            GlobalData.DataSet(Digitize.iDS).Channel = db_template('channeldesc');
        end
        if numel(GlobalData.DataSet(Digitize.iDS).Channel) == 1 && isempty(GlobalData.DataSet(Digitize.iDS).Channel(1).Name)
            % Overwrite empty channel created by template.
            iP = 1;
        else
            if Digitize.isEditPts
                % 'iP' points to the 'GlobalData's Channel' which just contains 
                % EEG data and not the fiducials so an offset is required
                % from 'Digitize.iPoint' to exclude the fiducials
                if isAdd
                    iP = Digitize.iPoint - 3;
                else
                    iP = Digitize.iPoint - 2;
                end
            else
                iP = numel(GlobalData.DataSet(Digitize.iDS).Channel) + 1;
            end
        end

        if isAdd 
            GlobalData.DataSet(Digitize.iDS).Channel(iP).Name = Digitize.Points(Digitize.iPoint).Label;
            GlobalData.DataSet(Digitize.iDS).Channel(iP).Type = Digitize.Points(Digitize.iPoint).Type; % 'EEG'
            GlobalData.DataSet(Digitize.iDS).Channel(iP).Loc  = Digitize.Points(Digitize.iPoint).Loc';
        else % Remove last point or a selected point
            iP = iP - 1;
            if iP > 0
                if Digitize.isEditPts % remove selected point
                    % Keep point in list, but remove location 
                    GlobalData.DataSet(Digitize.iDS).Channel(iP).Loc = [];
                else  % Remove last point
                    GlobalData.DataSet(Digitize.iDS).Channel(iP) = [];
                end
            end
        end
    else % FIDs or head points
        iP = size(GlobalData.DataSet(Digitize.iDS).HeadPoints.Loc, 2) + 1;
        if isAdd
            GlobalData.DataSet(Digitize.iDS).HeadPoints.Label{iP} = Digitize.Points(Digitize.iPoint).Label;
            GlobalData.DataSet(Digitize.iDS).HeadPoints.Type{iP}  = Digitize.Points(Digitize.iPoint).Type; % 'CARDINAL' or 'EXTRA'
            GlobalData.DataSet(Digitize.iDS).HeadPoints.Loc(:,iP) = Digitize.Points(Digitize.iPoint).Loc';
        else
            if iP > 0
                GlobalData.DataSet(Digitize.iDS).HeadPoints.Label(iP) = [];
                GlobalData.DataSet(Digitize.iDS).HeadPoints.Type(iP)  = [];
                GlobalData.DataSet(Digitize.iDS).HeadPoints.Loc(:,iP) = [];
            end
        end
    end     
    
    % Remove old HeadPoints
    hAxes = findobj(Digitize.hFig, '-depth', 1, 'Tag', 'Axes3D');
    hHeadPointsMarkers = findobj(hAxes, 'Tag', 'HeadPointsMarkers');
    hHeadPointsLabels  = findobj(hAxes, 'Tag', 'HeadPointsLabels');
    delete(hHeadPointsMarkers);
    delete(hHeadPointsLabels);
    % If all EEG were removed, ViewSensors won't remove the last remaining (first) EEG from the figure, so do it manually.
    if isempty(GlobalData.DataSet(Digitize.iDS).Channel)
        hSensorMarkers = findobj(hAxes, 'Tag', 'SensorsMarkers');
        hSensorLabels  = findobj(hAxes, 'Tag', 'SensorsLabels');
        delete(hSensorMarkers);
        delete(hSensorLabels);
    end
    % View all points in the channel file
    figure_3d('ViewHeadPoints', Digitize.hFig, 1);
    % This would give error if the channel structure is not truely empty: db_template creates effectively 1 channel with empty fields.
    if ~isempty(GlobalData.DataSet(Digitize.iDS).Channel) && ~isempty(GlobalData.DataSet(Digitize.iDS).Channel(1).Name)
        figure_3d('ViewSensors', Digitize.hFig, 1, 1, 0, 'EEG');
    end
    % Hide template head surface
    if ~strcmpi(Digitize.Type, '3DScanner')
        panel_surface('SetSurfaceTransparency', Digitize.hFig, 1, 1);
    end
end

%% ===== SAVE CALLBACK =====
% This saves a .pos file, which requires first saving the channel file.
function Save_Callback(OutFile)
    global Digitize
    % Do nothing if no points to save
    if isempty(Digitize.Points) || ~isfield(Digitize.Points, 'Loc') || isempty(Digitize.Points(1).Loc)
        java_dialog('msgbox', 'No points yet collected. Nothing to save.', 'Save as...', []);
        return;
    end
    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    SaveDigitizeChannelFile();
    % Export
    if nargin > 0 && ~isempty(OutFile)
        export_channel(ChannelFile, OutFile, 'POLHEMUS', 0);
    else
        export_channel(ChannelFile);
    end
end

%% ===== SAVE CHANNEL FILE WITH CONTENTS OF POINTS LIST =====
function SaveDigitizeChannelFile()
    global Digitize
    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = load(ChannelFile);
    % GlobalData may not exist here: before 3d figure is created or after it is closed.
    % So fill in ChannelMat from Digitize.Points.
    iHead = 0;
    iChan = 0;
    % Reset points
    ChannelMat.Channel = db_template('channeldesc');
    ChannelMat.HeadPoints.Loc = [];
    ChannelMat.HeadPoints.Label = [];
    ChannelMat.HeadPoints.Type = [];
    for iP = 1:numel(Digitize.Points)
        % Skip uncollected points
        if isempty(Digitize.Points(iP).Loc)
            continue;
        end
        if ~isempty(Digitize.Points(iP).Label) && strcmpi(Digitize.Points(iP).Type, 'EEG')
            % Add EEG sensor locations to channel stucture
            iChan = iChan + 1;
            ChannelMat.Channel(iChan).Name = Digitize.Points(iP).Label;
            ChannelMat.Channel(iChan).Type = Digitize.Points(iP).Type;
            ChannelMat.Channel(:,iChan).Loc = Digitize.Points(iP).Loc';
        else % Head points, including fiducials
            iHead = iHead + 1;
            ChannelMat.HeadPoints.Loc(:,iHead) = Digitize.Points(iP).Loc';
            ChannelMat.HeadPoints.Label{iHead} = Digitize.Points(iP).Label;
            ChannelMat.HeadPoints.Type{iHead}  = Digitize.Points(iP).Type;
        end
    end
    bst_save(ChannelFile, ChannelMat, 'v7');
end

%% ===== CREATE MONTAGE MENU =====
function CreateMontageMenu(jMenu)
    import org.brainstorm.icon.*;
    global Digitize

    % Get menu pointer if not in argument
    if (nargin < 1) || isempty(jMenu)
        ctrl = bst_get('PanelControls', 'Digitize');
        jMenu = ctrl.jMenuEeg;
    end
    % Empty menu
    jMenu.removeAll();
    % Button group
    buttonGroup = javax.swing.ButtonGroup();
    % Display all the montages
    for i = 1:length(Digitize.Options.Montages)
        jMenuMontage = gui_component('RadioMenuItem', jMenu, [], Digitize.Options.Montages(i).Name, buttonGroup, [], @(h,ev)bst_call(@SelectMontage, i), []);
        if (i == 2) && (length(Digitize.Options.Montages) > 2)
            jMenu.addSeparator();
        end
        if (i == Digitize.Options.iMontage)
            jMenuMontage.setSelected(1);
        end
    end
    % Add new montage / reset list
    jMenu.addSeparator();
    
    if strcmpi(Digitize.Type, '3DScanner')
        jMenuAddMontage = gui_component('Menu', jMenu, [], 'Add EEG montage...', [], [], [], []);
            gui_component('MenuItem', jMenuAddMontage, [], 'From file...', [], [], @(h,ev)bst_call(@AddMontage), []);
            % Creating montages from EEG cap layout mat files (only for 3DScanner)
            jMenuEegCaps = gui_component('Menu', jMenuAddMontage, [], 'From default EEG cap', IconLoader.ICON_CHANNEL, [], [], []);
            % Use default channel file
            menu_default_eegcaps(jMenuEegCaps);
    else % If not 3DScanner
        gui_component('MenuItem', jMenu, [], 'Add EEG montage...', [], [], @(h,ev)bst_call(@AddMontage), []);
    end
    gui_component('MenuItem', jMenu, [], 'Unload all montages', [], [], @(h,ev)bst_call(@UnloadAllMontages), []);
end

%% ===== SELECT MONTAGE =====
function SelectMontage(iMontage)
    global Digitize
    % Default montage: ask for number of channels
    if (iMontage == 2)
        % Get previous number of electrodes
        nEEG = length(Digitize.Options.Montages(iMontage).Labels);
        if (nEEG == 0)
            nEEG = 56;
        end
        % Ask user for the number of electrodes
        res = java_dialog('input', 'Number of EEG channels in your montage:', 'Default EEG montage', [], num2str(nEEG));
        if isempty(res) || isnan(str2double(res))
            CreateMontageMenu();
            return;
        end
        nEEG = str2double(res);
        % Create default montage
        Digitize.Options.Montages(iMontage).Name = sprintf('Default (%d)', nEEG);
        Digitize.Options.Montages(iMontage).Labels = {};
        for i = 1:nEEG
            if (nEEG > 99)
                strFormat = 'EEG%03d';
            else
                strFormat = 'EEG%02d';
            end
            Digitize.Options.Montages(iMontage).Labels{i} = sprintf(strFormat, i);
        end
    end
    % Save currently selected montage
    Digitize.Options.iMontage = iMontage;
    % Save Digitize options
    bst_set('DigitizeOptions', Digitize.Options);
    % Update menu
    CreateMontageMenu();
    % Restart acquisition
    ResetDataCollection();
end

%% ===== TOOLTIP TEXT FOR AUTO BUTTON =====
function autoButtonTooltip = GenerateTooltipTextAuto()
    global Digitize
    % Get cap landmark labels for selected montage
    eegCapLandmarkLabels = channel_detect_eegcap_auto('GetEegCapLandmarkLabels', Digitize.Options.Montages(Digitize.Options.iMontage).Name);
    autoButtonTooltip = 'Auto localization of EEG sensor is not suported for this cap.';
    if ~isempty(eegCapLandmarkLabels)
        strSensors = sprintf('%s, ',eegCapLandmarkLabels{:});
        strSensors = strSensors(1:end-2);
        autoButtonTooltip = ['Set at least sensors: [' strSensors '] to enable.'];
    end
end

%% ===== GET CURRENT MONTAGE =====
function [curMontage, nEEG] = GetCurrentMontage()
    global Digitize
    % Return current montage
    curMontage = Digitize.Options.Montages(Digitize.Options.iMontage);
    nEEG = length(curMontage.Labels);
end

%% ===== ADD EEG MONTAGE =====
function AddMontage(ChannelFile)
    global Digitize
    % Add Montage from text file
    if nargin<1
        % Get recently used folders
        LastUsedDirs = bst_get('LastUsedDirs');
        % Open file
        MontageFile = java_getfile('open', 'Select montage file...', LastUsedDirs.ImportChannel, 'single', 'files', ...
                       {{'*.txt'}, 'Text files', 'TXT'}, 0);
        if isempty(MontageFile)
            return;
        end
        % Get filename
        [MontageDir, MontageName] = bst_fileparts(MontageFile);
        % Intialize new montage
        newMontage.Name = MontageName;
        newMontage.Labels = {};
        
        % Open file
        fid = fopen(MontageFile,'r');
        if (fid == -1)
            error('Cannot open file.');
        end
        % Read file
        while (1)
            tline = fgetl(fid);
            if ~ischar(tline)
                break;
            end
            spl = regexp(tline,'\s+','split');
            if (length(spl) >= 2)
                newMontage.Labels{end+1} = spl{2};
            end
        end
        % Close file
        fclose(fid);
        % If no labels were read: exit
        if isempty(newMontage.Labels)
            return
        end
        % Save last dir
        LastUsedDirs.ImportChannel = MontageDir;
        bst_set('LastUsedDirs', LastUsedDirs);
    else  % Add Montage from mat file of EEG caps
        % Load existing file
        ChannelMat = in_bst_channel(ChannelFile);
        
        % Intialize new montage
        newMontage.Name = ChannelMat.Comment;
        newMontage.Labels = {};
        newMontage.ChannelFile = ChannelFile;
        
        % Get cap landmark labels
        eegCapLandmarkLabels = channel_detect_eegcap_auto('GetEegCapLandmarkLabels', newMontage.Name);

        % Sort as per the initialization landmark labels of EEG Cap  
        nonLandmarkLabelsIdx = find(~ismember({ChannelMat.Channel.Name},eegCapLandmarkLabels));
        allLabels = {ChannelMat.Channel.Name};
        newMontage.Labels = cat(2, eegCapLandmarkLabels, allLabels(nonLandmarkLabelsIdx));
    end
    
    % Get existing montage with the same name
    iMontage = find(strcmpi({Digitize.Options.Montages.Name}, newMontage.Name));
    % If not found: create new montage entry
    if isempty(iMontage)
        iMontage = length(Digitize.Options.Montages) + 1;
    else
        iMontage = iMontage(1);
        disp('DIGITIZER> Warning: Montage name already exists. Overwriting...');
    end
    % Add new montage to registered montages
    Digitize.Options.Montages(iMontage) = newMontage;
    Digitize.Options.iMontage = iMontage;
    % Save options
    bst_set('DigitizeOptions', Digitize.Options);
    % Reload Menu
    CreateMontageMenu();
    % Restart acquisition
    ResetDataCollection();
end

%% ===== UNLOAD ALL MONTAGES =====
function UnloadAllMontages()
    global Digitize
    % Remove all montages
    Digitize.Options.Montages = [...
        struct('Name',   'No EEG', ...
               'Labels', [], ...
               'ChannelFile', []), ...
        struct('Name',   'Default', ...
               'Labels', [], ...
               'ChannelFile', [])];
    % Reset to "No EEG"
    Digitize.Options.iMontage = 1;
    % Save Digitize options
    bst_set('DigitizeOptions', Digitize.Options);
    % Reload menu bar
    CreateMontageMenu();
    % Reset list
    ResetDataCollection();
end


%% ========================================================================
%  ======= POLHEMUS COMMUNICATION =========================================
%  ========================================================================

%% ===== CREATE SERIAL COLLECTION =====
function isOk = CreateSerialConnection()
    global Digitize 
    isOk = 0;
    while ~isOk
        % Simulation: exit
        if Digitize.Options.isSimulate
            isOk = 1;
            return;
        end
        try
            % Delete previous connection.
            if ~isempty(Digitize.SerialConnection)
                delete(Digitize.SerialConnection);
            end
            % Create the serial port connection and store in global variable.
            Digitize.SerialConnection = serialport(Digitize.Options.ComPort, Digitize.Options.ComRate);
            if strcmp(Digitize.Options.UnitType,'patriot')
                configureTerminator(Digitize.SerialConnection, 'CR');
            else
                configureTerminator(Digitize.SerialConnection, 'LF');
            end
            if Digitize.SerialConnection.NumBytesAvailable > 0
                flush(Digitize.SerialConnection);
            end

            % Set up the Bytes Available function
            configureCallback(Digitize.SerialConnection, 'byte', Digitize.Options.ComByteCount, @BytesAvailable_Callback);
            if strcmp(Digitize.Options.UnitType, 'fastrak')
                %'c' - Disable Continuous Printing
                % Required for some configuration options.
                writeline(Digitize.SerialConnection,'c');
                %'u' - Metric Conversion Units (set units to cm)
                writeline(Digitize.SerialConnection,'u');
                %'F' - Enable ASCII Output Format
                writeline(Digitize.SerialConnection,'F');
                %'R' - Reset Alignment Reference Frame
                writeline(Digitize.SerialConnection,'R1');
                writeline(Digitize.SerialConnection,'R2');
                %'A' - Alignment Reference Frame
                %'l' - Active Station State
                % Could check here if 1 and 2 are active.
                %'N' - Define Tip Offsets % Always factory default on power-up.
                %    writeline(Digitize.SerialConnection,'N1'); data = readline(Digitize.SerialConnection)
                %    data = '21N  6.344  0.013  0.059
                %'O' - Output Data List
                writeline(Digitize.SerialConnection,'O1,2,4,1'); % default precision: position, Euler angles, CRLF
                writeline(Digitize.SerialConnection,'O2,2,4,1'); % default precision: position, Euler angles, CRLF
                %writeline(Digitize.SerialConnection,'O1,52,54,51'); % extended precision: position, Euler angles, CRLF
                %writeline(Digitize.SerialConnection,'O2,52,54,51'); % extended precision: position, Euler angles, CRLF
                %'x' - Position Filter Parameters
                % The macro setting used here also applies to attitude filtering.
                % 1=none, 2=low, 3=medium (default), 4=high
                writeline(Digitize.SerialConnection,'x3');

                %'e' - Define Stylus Button Function
                writeline(Digitize.SerialConnection,'e1,1'); % Point mode

                % These should be set through the options panel, since they depend on the geometry of setup.
                % e.g. 'H1,0,0,-1; H2,0,0,-1; Q1,180,90,180,-180,-90,-180; Q2,180,90,180,-180,-90,-180; V1,100,100,100,-100,-100,-100; V2,100,100,100,-100,-100,-100'
                %'H' - Hemisphere of Operation
                %writeline(Digitize.SerialConnection,'H1,0,0,-1'); % -Z hemisphere
                %writeline(Digitize.SerialConnection,'H2,0,0,-1'); % -Z hemisphere
                %'Q' - Angular Operational Envelope
                %writeline(Digitize.SerialConnection,'Q1,180,90,180,-180,-90,-180');
                %writeline(Digitize.SerialConnection,'Q2,180,90,180,-180,-90,-180');
                %'V' - Position Operational Envelope
                % Could use to warn if too far.
                %writeline(Digitize.SerialConnection,'V1,100,100,100,-100,-100,-100');
                %writeline(Digitize.SerialConnection,'V2,100,100,100,-100,-100,-100');

                %'^K' - *Save Operational Configuration
                % 'ctrl+K' = char(11)
                %'^Y' - *Reinitialize System
                % 'ctrl+Y' = char(25)

                % Apply commands from options after, so they can overwride.
                for iCmd = 1:numel(Digitize.Options.ConfigCommands)
                    writeline(Digitize.SerialConnection, Digitize.Options.ConfigCommands{iCmd});
                end
            elseif strcmp(Digitize.Options.UnitType,'patriot')
                % Request input from stylus
                writeline(Digitize.SerialConnection,'L1,1\r');
                % Set units to centimeters
                writeline(Digitize.SerialConnection,'U1\r');
            end
            pause(0.2);
        catch %#ok<CTCH>
            % If the connection cannot be established: error message
            bst_error(['Cannot open serial connection.' 10 10 'Please check the serial port configuration.' 10], Digitize.Type, 0);
            % Ask user to edit the port options
            isChanged = EditSettings();
            % If edit was canceled: exit
            if ~isChanged
                %Digitize.SerialConnection = [];
                return;
                % If not, try again
            else
                continue;
            end
        end
        isOk = 1;
    end
end


%% ===== BYTES AVAILABLE CALLBACK =====
function BytesAvailable_Callback() %#ok<INUSD>
    global Digitize
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    
    % Simulate: Generate random points
    if Digitize.Options.isSimulate
        % Increment current point index
        Digitize.iPoint = Digitize.iPoint + 1;
        if Digitize.iPoint > numel(Digitize.Points)
            Digitize.Points(Digitize.iPoint).Type = 'EXTRA';
        end
        if strcmpi(Digitize.Type, '3DScanner')
            % Get current 3D figure
            [Digitize.hFig,~,Digitize.iDS] = bst_figures('GetCurrentFigure', '3D');
            if isempty(Digitize.hFig)
                return
            end
            % Get current selected point
            CoordinatesSelector = getappdata(Digitize.hFig, 'CoordinatesSelector');
            isSelectingCoordinates = getappdata(Digitize.hFig, 'isSelectingCoordinates');
            if isempty(CoordinatesSelector) || isempty(CoordinatesSelector.MRI)
                return;
            else
                if isSelectingCoordinates
                    Digitize.Points(Digitize.iPoint).Loc = CoordinatesSelector.SCS;
                end
            end
        else
            Digitize.Points(Digitize.iPoint).Loc = rand(1,3) * .15 - .075;
        end

    % Else: Get digitized point coordinates
    else
        vals = zeros(1,7); % header, x, y, z, azimuth, elevation, roll
        rawpoints = zeros(2,7); % 2 receivers
        data = [];
        try
            for j=1:2 % 1 point * 2 receivers
                data = char(readline(Digitize.SerialConnection));
                if strcmp(Digitize.Options.UnitType, 'fastrak')
                    % This is fastrak
                    % The factory default ASCII output record x-y-z-azimuth-elevation-roll is composed of 
                    % 47 bytes (3 status bytes, 6 data words each 7 bytes long, and a CR LF terminator)
                    vals(1) = str2double(data(1:3)); % header is first three char
                    for v=2:7
                        % next 6 values are each 7 char
                        ind=(v-1)*7;
                        vals(v) = str2double(data((ind-6)+3:ind+3));
                    end
                elseif strcmp(Digitize.Options.UnitType, 'patriot')
                    % This is patriot
                    % The factory default ASCII output record x-y-z-azimuth-elevation-roll is composed of 
                    % 60 bytes (4 status bytes, 6 data words each 9 bytes long, and a CR LF terminator)
                    vals(1) = str2double(data(1:4)); % header is first 5 char
                    for v=2:7
                        % next 6 values are each 9 char
                        ind=(v-1)*9;
                        vals(v) = str2double(data((ind-8)+4:ind+4));
                    end
                end
                rawpoints(j,:) = vals;
            end
        catch
            disp(['Error reading data point. Try again.' 10, ...
                'If the problem persits, reset the serial connnection.' 10, ...
                data]);
            return;
        end
        % Increment current point index
        Digitize.iPoint = Digitize.iPoint + 1;
        if Digitize.iPoint > numel(Digitize.Points)
            Digitize.Points(Digitize.iPoint).Type = 'EXTRA';
        end
        % Motion compensation and conversion to meters 
        % This is not converting to SCS, but to another digitizer-specific head-fixed coordinate system.
        Digitize.Points(Digitize.iPoint).Loc = DoMotionCompensation(rawpoints) ./100; % cm => meters
    end
    % Beep at each click
    if Digitize.Options.isBeep
        sound(Digitize.BeepWav.data, Digitize.BeepWav.fs);
    end

    % Transform coordinates
    if ~isempty(Digitize.Transf) && ~strcmpi(Digitize.Type, '3DScanner')
        Digitize.Points(Digitize.iPoint).Loc = [Digitize.Points(Digitize.iPoint).Loc 1] * Digitize.Transf';
    end
    % Update coordinates list only when there is no updating of selected point
    % for which the updating happens at the end
    if ~Digitize.isEditPts
        UpdateList();
    end

    % Update counters
    switch upper(Digitize.Points(Digitize.iPoint).Type)
        case 'EXTRA'
            iCount = str2double(ctrl.jTextFieldExtra.getText());
            ctrl.jTextFieldExtra.setText(num2str(iCount + 1));
    end

    if ~isempty(Digitize.hFig) && ishandle(Digitize.hFig) && ~strcmpi(Digitize.Points(Digitize.iPoint).Type, 'CARDINAL')
        % Add this point to the figure
        % Saves in GlobalData, but NOT in actual channel file
        PlotCoordinate();
    end           

    % Check distance for fiducials and warn if greater than threshold.
    if strcmpi(Digitize.Points(Digitize.iPoint).Type, 'CARDINAL') && ...
            Digitize.iPoint > numel(Digitize.Options.Fids)
        iSameFid = find(strcmpi({Digitize.Points(1:(Digitize.iPoint-1)).Label}, Digitize.Points(Digitize.iPoint).Label));
        % Average location of this fiducial point initially, averaging those collected at start only.
        InitLoc = mean(cat(1, Digitize.Points(iSameFid(1:min(numel(iSameFid),max(1,Digitize.Options.nFidSets)))).Loc), 1);
        Distance = norm((InitLoc - Digitize.Points(Digitize.iPoint).Loc));
        if Distance > Digitize.Options.DistThresh
            ctrl.jLabelWarning.setText(sprintf('%s distance exceeds %1.0f mm', Digitize.Points(Digitize.iPoint).Label, Digitize.Options.DistThresh * 1000));
            fprintf('%s distance %1.1f mm\n', Digitize.Points(Digitize.iPoint).Label, Distance * 1000);
            ctrl.jLabelWarning.setOpaque(true);
            ctrl.jLabelWarning.setBackground(java.awt.Color.red);
            % Extra beep for large distances
            pause(0.15);
            sound(Digitize.BeepWav.data, Digitize.BeepWav.fs*.08);
        end
    end

    % When initial fids are all collected
    if Digitize.iPoint == numel(Digitize.Options.Fids) * Digitize.Options.nFidSets
        % Save temp pos file
        TmpDir = bst_get('BrainstormTmpDir');
        TmpPosFile = bst_fullfile(TmpDir, [Digitize.SubjectName '_' matlab.lang.makeValidName(Digitize.ConditionName) '.pos']);
        Save_Callback(TmpPosFile);
        % Re-import that .pos file. This converts to "Native" CTF coil-based coordinates.  
        HeadPointsMat = in_channel_pos(TmpPosFile);
        % Delete temp file
        file_delete(TmpPosFile, 1);
        % Check for coordinate system transformation. There should be only 1, either to Native CTF or to SCS.
        if ~isfield(HeadPointsMat, 'TransfMegLabels') || ~iscell(HeadPointsMat.TransfMegLabels) || numel(HeadPointsMat.TransfMegLabels) ~= 1
            error('Missing coordinate transformation');
        end
        Digitize.Transf = HeadPointsMat.TransfMeg{1}(1:3,:); % 3x4 transform matrix
        % Update coordinates in our list
        for iP = 1:Digitize.iPoint % there could be EEG after, with empty Loc
            Digitize.Points(iP).Loc = [Digitize.Points(iP).Loc, 1] * Digitize.Transf';
        end
        UpdateList();
        % Update the channel file to save these essential points, and possibly needed for creating figure.
        SaveDigitizeChannelFile();

        % Create figure, store hFig & iDS
        CreateHeadpointsFigure();
        % Enable fids button
        ctrl.jButtonFids.setEnabled(1);
    elseif Digitize.iPoint == numel(Digitize.Options.Fids) * Digitize.Options.nFidSets + 1
        % Change delete button label and callback such that we can delete the last point.
        java_setcb(ctrl.jButtonDeletePoint, 'ActionPerformedCallback', @(h,ev)bst_call(@DeletePoint_Callback));
        ctrl.jButtonDeletePoint.setText('Delete last point');
    end
    
    % Update coordinate list after the updating the selected point
    if Digitize.isEditPts
        % Reset global variable required for updating
        Digitize.isEditPts = 0;
        % Update the Digitize.iPoint
        iNotEmptyLoc = find(cellfun(@(x)~isempty(x), {Digitize.Points.Loc}));
        Digitize.iPoint = length(iNotEmptyLoc);
        % Update the coordinate list
        UpdateList();
    end
    % Enable 'Auto' button IFF all landmark fiducials have been acquired
    if strcmpi(Digitize.Type, '3DScanner') && ~strcmpi(Digitize.Points(Digitize.iPoint).Type, 'EXTRA')
        eegCapLandmarkLabels = channel_detect_eegcap_auto('GetEegCapLandmarkLabels', Digitize.Options.Montages(Digitize.Options.iMontage).Name);
        if ~isempty(eegCapLandmarkLabels)
            acqPoints = Digitize.Points(~cellfun(@isempty, {Digitize.Points.Loc}));
            if all(ismember([eegCapLandmarkLabels], {acqPoints.Label}))
                ctrl.jButtonEEGAutoDetectElectrodes.setEnabled(1);
            end
        end
    end
end


%% ===== MOTION COMPENSATION =====
function newPT = DoMotionCompensation(sensors)
    % Use sensor one and its orientation vectors as the new coordinate system
    % Define the origin as the position of sensor attached to the glasses
    WAND = 1;
    REMOTE1 = 2;

    C(1) = sensors(REMOTE1,2);
    C(2) = sensors(REMOTE1,3);
    C(3) = sensors(REMOTE1,4);

    % Deg2Rad = (angle / 180) * pi
    % alpha = Deg2Rad(sensors(REMOTE1).o.Azimuth)
    % beta = Deg2Rad(sensors(REMOTE1).o.Elevation)
    % gamma = Deg2Rad(sensors(REMOTE1).o.Roll)

    alpha = (sensors(REMOTE1,5)/180) * pi;
    beta = (sensors(REMOTE1,6)/180) * pi;
    gamma = (sensors(REMOTE1,7)/180) * pi;

    SA = sin(alpha);
    SE = sin(beta);
    SR = sin(gamma);
    CA = cos(alpha);
    CE = cos(beta);
    CR = cos(gamma);

    % Convert Euler angles to directional cosines using formulae in Polhemus manual
    rotMat(1, 1) = CA * CE;
    rotMat(1, 2) = SA * CE;
    rotMat(1, 3) = -SE;

    rotMat(2, 1) = CA * SE * SR - SA * CR;
    rotMat(2, 2) = CA * CR + SA * SE * SR;
    rotMat(2, 3) = CE * SR;

    rotMat(3, 1) = CA * SE * CR + SA * SR;
    rotMat(3, 2) = SA * SE * CR - CA * SR;
    rotMat(3, 3) = CE * CR;

    rotMat(4, 1:4) = 0;

    % Translate and rotate the WAND into new coordinate system
    pt(1) = sensors(WAND,2) - C(1);
    pt(2) = sensors(WAND,3) - C(2);
    pt(3) = sensors(WAND,4) - C(3);

    newPT(1) = pt(1) * rotMat(1, 1) + pt(2) * rotMat(1, 2) + pt(3) * rotMat(1, 3)'+ rotMat(1, 4);
    newPT(2) = pt(1) * rotMat(2, 1) + pt(2) * rotMat(2, 2) + pt(3) * rotMat(2, 3)'+ rotMat(2, 4);
    newPT(3) = pt(1) * rotMat(3, 1) + pt(2) * rotMat(3, 2) + pt(3) * rotMat(3, 3)'+ rotMat(3, 4);
end

