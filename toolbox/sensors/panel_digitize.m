function varargout = panel_digitize(varargin)
% PANEL_DIGITIZE: Digitize EEG sensors and head shape.
% 
% USAGE:             panel_digitize('Start')
%                    panel_digitize('CreateSerialConnection')
%                    panel_digitize('ResetDataCollection')
%      bstPanelNew = panel_digitize('CreatePanel')
%                    panel_digitize('SetSimulate', isSimulate)

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
%          Chinmay Chinara, 2024

eval(macro_method);
end


%% ========================================================================
%  ======= INITIALIZE =====================================================
%  ========================================================================
% Pragma to include the classes used by serial.m: DO NOT REMOVE
%#function serial
%#function icinterface

%% ===== START =====
function Start(DigitizerType) %#ok<DEFNU>
    global Digitize

    % ===== INITIALIZE CONNECTION =====
    % Intialize global variable
    Digitize = struct(...
        'Type'            , [], ...
        'SerialConnection', [], ...
        'Mode',             0, ...
        'hFig',             [], ...
        'iDS',              [], ...
        'FidSets',          2, ...
        'EEGlabels',        [], ...
        'SubjectName',      [], ...
        'ConditionName',    [], ...
        'BeepWav',          [], ...
        'isEditPts',        0, ...
        'Points',           struct(...
            'nasion',   [], ...
            'LPA',      [], ...
            'RPA',      [], ...
            'hpiN',     [], ...
            'hpiL',     [], ...
            'hpiR',     [], ...
            'EEG',      [], ...
            'headshape',[], ...
            'trans',    []));
    
    % ===== PARSE INPUTS =====
    if nargin == 0 || isempty(DigitizerType)
        Digitize.Type = 'Digitize';
    elseif nargin == 1
        if strcmpi(DigitizerType, 'revopoint')
            Digitize.Type = 'Revopoint';
            % Simulate
            SetSimulate(1);
        else
            Digitize.Type = 'Digitize';
        end
    else
        error('Usage : panel_digitize(DigitizerType)');
    end

    % ===== PREPARE DATABASE =====
    % If no protocol: exit
    if (bst_get('iProtocol') <= 0)
        bst_error('Please create a protocol first.', Digitize.Type, 0);
        return;
    end
    
    % ===== PATIENT ID =====
    % Get Digitize options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Ask for subject id
    PatientId = java_dialog('input', 'Please, enter subject name or id:', Digitize.Type, [], DigitizeOptions.PatientId);
    if isempty(PatientId)
        return;
    end
    % Save the new default patient id
    DigitizeOptions.PatientId = PatientId;
    bst_set('DigitizeOptions', DigitizeOptions);

    % ===== GET SUBJECT =====
    if strcmpi(Digitize.Type, 'Revopoint')
        SubjectName = [Digitize.Type, '_', PatientId];
    else
        SubjectName = Digitize.Type;
    end
    % Save the new SubjectName
    Digitize.SubjectName = SubjectName;

    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % Create if subject doesnt exist
    if isempty(iSubject)
        % Default anat / one channel file per subject
        if strcmpi(Digitize.Type, 'Revopoint')
            [sSubject, iSubject] = db_add_subject(SubjectName, iSubject);
            sTemplates = bst_get('AnatomyDefaults');
            db_set_template(iSubject, sTemplates(1), 1);
        else
            UseDefaultAnat = 1;
            UseDefaultChannel = 0;
            [sSubject, iSubject] = db_add_subject(SubjectName, iSubject, UseDefaultAnat, UseDefaultChannel);
        end
        % Update tree
        panel_protocols('UpdateTree');
    end
    
    % Start Serial Connection
    if ~CreateSerialConnection();
        return;
    end
    
    % ===== CREATE CONDITION =====
    % Get current date/time
    c = clock;
    % Condition name: PatientId_Date_Run
    for i = 1:99
        % Generate new condition name
        ConditionName = sprintf('%s_%02d%02d%02d_%02d', DigitizeOptions.PatientId, c(1), c(2), c(3), i);
        % Get condition
        [sStudy, iStudy] = bst_get('StudyWithCondition', [SubjectName '/' ConditionName]);
        % If condition doesn't exist: ok, keep this one
        if isempty(sStudy)
            break;
        end
    end
    % Create condition
    iStudy = db_add_condition(SubjectName, ConditionName);
    sStudy = bst_get('Study', iStudy);
    % Create an empty channel file in there
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = ConditionName;
    % Save new channel file
    ChannelFile = bst_fullfile(bst_fileparts(file_fullpath(sStudy.FileName)), ['channel_' ConditionName '.mat']);
    save(ChannelFile, '-struct', 'ChannelMat');
    % Reload condition
    db_reload_studies(iStudy);
    % Save condition name
    Digitize.ConditionName = ConditionName;
    
    if strcmpi(Digitize.Type, 'Revopoint')
        % import surface
        iTargetSurface = find(cellfun(@(c)~isempty(strfind(c, 'revopoint')), {sSubject.Surface.Comment}));
        if(isempty(iTargetSurface))
            [iNewSurfaces, OutputSurfacesFiles, nVertices] = import_surfaces(iSubject);
            sSurf = bst_memory('LoadSurface', OutputSurfacesFiles{end});
            [sSubject, iSubject] = bst_get('Subject', SubjectName);
            iTargetSurface = find(cellfun(@(c)~isempty(strfind(c, 'revopoint')), {sSubject.Surface.Comment})); 
        else
            sSurf = bst_memory('LoadSurface', sSubject.Surface(iTargetSurface(end)).FileName);
        end
        
        % view the surface
        view_surface_matrix(sSurf.Vertices, sSurf.Faces, [], sSurf.Color, [], [], sSubject.Surface(iTargetSurface(end)).FileName);
    end

    % ===== DISPLAY DIGITIZE WINDOW =====
    % Display panel
    panelContainer = gui_show('panel_digitize', 'JavaWindow', Digitize.Type, [], [], [], []);
    % Hide Brainstorm window
    jBstFrame = bst_get('BstFrame');
    jBstFrame.setVisible(0);
    % Set the window to the left of the screen
    drawnow;
    loc = panelContainer.handle{1}.getLocation();
    loc.x = 0;
    panelContainer.handle{1}.setLocation(loc);
    % Reset collection
    ResetDataCollection();
    
    % Load beep sound
    if bst_iscompiled()
        wavfile = bst_fullfile(bst_get('BrainstormHomeDir'), 'toolbox', 'sensors', 'private', 'bst_beep_wav.mat');
        filemat = load(wavfile, 'wav');
        Digitize.BeepWav = filemat.wav;
    end
end


%% ========================================================================
%  ======= PANEL FUNCTIONS ================================================
%  ========================================================================

%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel() %#ok<DEFNU>
    global Digitize

    % Constants
    panelName = Digitize.Type;
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import java.awt.event.KeyEvent;
    import org.brainstorm.list.*;
    import org.brainstorm.icon.*;
    % Create new panel
    jPanelNew = gui_component('Panel');
    % Font size for the lists
    largeFontSize = round(20 * bst_get('InterfaceScaling') / 100);
    fontSize      = round(11 * bst_get('InterfaceScaling') / 100);
    
    % ===== MENU BAR =====
    jMenuBar = java_create('javax.swing.JMenuBar');
    jPanelNew.add(jMenuBar, BorderLayout.NORTH);
    % File menu
    jMenu = gui_component('Menu', jMenuBar, [], 'File', [], [], [], []);
    gui_component('MenuItem', jMenu, [], 'Start over', IconLoader.ICON_RELOAD, [], @(h,ev)bst_call(@ResetDataCollection, 1), []);
    gui_component('MenuItem', jMenu, [], 'Save as...', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@Save_Callback), []);
    jMenu.addSeparator();
    gui_component('MenuItem', jMenu, [], 'Edit settings...',    IconLoader.ICON_EDIT, [], @(h,ev)bst_call(@EditSettings), []);
    gui_component('MenuItem', jMenu, [], 'Reset serial connection', IconLoader.ICON_FLIP, [], @(h,ev)bst_call(@CreateSerialConnection), []);
    jMenu.addSeparator();
    if exist('bst_headtracking')
        gui_component('MenuItem', jMenu, [], 'Start head tracking',     IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)bst_call(@(h,ev)bst_headtracking([],1,1)), []);
        jMenu.addSeparator();
    end
    gui_component('MenuItem', jMenu, [], 'Save and exit', IconLoader.ICON_RESET, [], @(h,ev)bst_call(@Close_Callback), []);
    % EEG Montage menu
    jMenuEeg = gui_component('Menu', jMenuBar, [], 'EEG montage', [], [], [], []);    
    CreateMontageMenu(jMenuEeg);
    
    % ===== Control Panel =====
    jPanelControl = java_create('javax.swing.JPanel');
    jPanelControl.setLayout(BoxLayout(jPanelControl, BoxLayout.Y_AXIS));
    jPanelControl.setBorder(BorderFactory.createEmptyBorder(7,7,7,7));
    modeButtonGroup = javax.swing.ButtonGroup();
           
    % ===== Coils panel =====
    jPanelCoils = gui_river([5,4], [10,10,10,10], 'Head Localization Coils');
        % Fiducials
        jButtonhpiN = gui_component('toggle', jPanelCoils, [], 'HPI-N', {modeButtonGroup}, 'Center Coil',    @(h,ev)SwitchToNewMode(1), largeFontSize);
        jButtonhpiL = gui_component('toggle', jPanelCoils, [], 'HPI-L',   {modeButtonGroup}, 'Left Coil',  @(h,ev)SwitchToNewMode(2), largeFontSize);
        jButtonhpiR = gui_component('toggle', jPanelCoils, [], 'HPI-R',  {modeButtonGroup}, 'Right Coil', @(h,ev)SwitchToNewMode(3), largeFontSize);
        % Set size
        initButtonSize = jButtonhpiR.getPreferredSize();
        newButtonSize = Dimension(initButtonSize.getWidth(), initButtonSize.getHeight()*1.5);
        jButtonhpiN.setPreferredSize(newButtonSize);
        jButtonhpiL.setPreferredSize(newButtonSize);
        jButtonhpiR.setPreferredSize(newButtonSize);
        % Non-selectable
        jButtonhpiN.setFocusable(0);
        jButtonhpiL.setFocusable(0);
        jButtonhpiR.setFocusable(0);
        % Message label
        jLabelCoilMessage = gui_component('label', jPanelCoils, 'br', '');
        jLabelCoilMessage.setForeground(Color.red);
    jPanelControl.add(jPanelCoils);
    jPanelControl.add(Box.createVerticalStrut(20));
    
    % ===== Fiducials panel =====
    jPanelHeadCoord = gui_river([5,4], [10,10,10,10], 'Anatomical fiducials');
        % Fiducials
        jButtonNasion = gui_component('toggle', jPanelHeadCoord, [], 'Nasion', {modeButtonGroup}, 'Nasion',    @(h,ev)SwitchToNewMode(4), largeFontSize);
        jButtonLPA    = gui_component('toggle', jPanelHeadCoord, [], 'LPA',   {modeButtonGroup}, 'Left Ear',  @(h,ev)SwitchToNewMode(5), largeFontSize);
        jButtonRPA    = gui_component('toggle', jPanelHeadCoord, [], 'RPA',  {modeButtonGroup}, 'Right Ear', @(h,ev)SwitchToNewMode(6), largeFontSize);
        % Set size
        initButtonSize = jButtonNasion.getPreferredSize();
        newButtonSize = Dimension(initButtonSize.getWidth(), initButtonSize.getHeight()*1.5);
        jButtonNasion.setPreferredSize(newButtonSize);
        jButtonLPA.setPreferredSize(newButtonSize);
        jButtonRPA.setPreferredSize(newButtonSize);
        jButtonhpiN.setPreferredSize(newButtonSize);
        jButtonhpiL.setPreferredSize(newButtonSize);
        jButtonhpiR.setPreferredSize(newButtonSize);
        % Non-selectable
        jButtonNasion.setFocusable(0);
        jButtonLPA.setFocusable(0);
        jButtonRPA.setFocusable(0);
        % Message label
        jLabelFidMessage = gui_component('label', jPanelHeadCoord, 'br', '');
        jLabelFidMessage.setForeground(Color.red);
    jPanelControl.add(jPanelHeadCoord);
    jPanelControl.add(Box.createVerticalStrut(20));
 
    % ===== EEG panel =====
    jPanelEEG = gui_river([5,4], [10,10,10,10], 'EEG electrodes coordinates');
        % Start EEG coord collection
        jButtonEEGStart = gui_component('toggle', jPanelEEG, [], 'EEG', {modeButtonGroup}, 'Start/Restart EEG digitization', @(h,ev)SwitchToNewMode(7), largeFontSize);
        newButtonSize = Dimension(initButtonSize.getWidth()*1.5, initButtonSize.getHeight()*1.5);
        jButtonEEGStart.setPreferredSize(newButtonSize);
        jButtonEEGStart.setFocusable(0);
        
        if strcmpi(Digitize.Type, 'Revopoint')
            % Auto EEG cap electrodes detection button
            jButtonEEGAutoDetectElectrodes = gui_component('button', jPanelEEG, [], 'Auto', [], 'Automatically detect and label electrodes on EEG cap', @EEGAutoDetectElectrodes, largeFontSize);
            jButtonEEGAutoDetectElectrodes.setPreferredSize(newButtonSize);
        else
            % Separator
            jButtonEEGAutoDetectElectrodes = gui_component('label', jPanelEEG, 'hfill', '');
        end

        % Number
        jTextFieldEEG = gui_component('text',jPanelEEG, [], '1', [], 'EEG Sensor # to be digitized', @EEGChangePoint_Callback, largeFontSize);
        jTextFieldEEG.setPreferredSize(newButtonSize)
        jTextFieldEEG.setColumns(3); 
    jPanelControl.add(jPanelEEG);
    jPanelControl.add(Box.createVerticalStrut(20));
    
    % ===== Extra points panel =====
    jPanelExtra = gui_river([5,4], [10,10,10,10], 'Head shape coordinates');
        % Start Extra coord collection
        jButtonExtraStart = gui_component('toggle',jPanelExtra, [], 'Shape', {modeButtonGroup}, 'Start/Restart head shape digitization', @(h,ev)SwitchToNewMode(8), largeFontSize);
        jButtonExtraStart.setPreferredSize(newButtonSize);
        jButtonExtraStart.setFocusable(0);
        
        if strcmpi(Digitize.Type, 'Revopoint')
            % Add Random 100 points generation button
            jButtonRandomHeadPts = gui_component('button', jPanelExtra, [], 'Random', [], 'Collect 100 random points from head surface', @CollectRandomHeadPts_Callback, largeFontSize);
            jButtonRandomHeadPts.setPreferredSize(newButtonSize);
        else
            % Separator
            jButtonRandomHeadPts = gui_component('label', jPanelExtra, 'hfill', '');
        end

        % Number
        jTextFieldExtra = gui_component('text',jPanelExtra, [], '1',[], 'Head shape point to be digitized', @ExtraChangePoint_Callback, largeFontSize);
        jTextFieldExtra.setPreferredSize(newButtonSize)
        jTextFieldExtra.setColumns(3);                        
    jPanelControl.add(jPanelExtra);
    jPanelControl.add(Box.createVerticalStrut(20));
    
    % ===== Extra buttons =====
    jPanelMisc = gui_river([5,4], [2,4,4,0]);
        gui_component('button', jPanelMisc, [], 'Collect point', [], [], @ManualCollect_Callback);
        jButtonDeletePoint = gui_component('button', jPanelMisc, 'hfill', 'Delete last point', [], [], @DeletePoint_Callback);
        gui_component('Button', jPanelMisc, [], 'Save as...', [], [], @Save_Callback);
    jPanelControl.add(jPanelMisc);
    jPanelControl.add(Box.createVerticalStrut(20));
    jPanelNew.add(jPanelControl, BorderLayout.WEST);
                               
    % ===== Coordinate Display Panel =====
    jPanelDisplay = gui_component('Panel');
    jPanelDisplay.setBorder(java_scaled('titledborder', 'Coordinates (cm)'));
        % List of coordinates
        jListCoord = JList(largeFontSize);
        jListCoord.setCellRenderer(BstStringListRenderer(fontSize));
        java_setcb(jListCoord, ...
            'KeyTypedCallback',     @(h,ev)bst_call(@CoordListKeyTyped_Callback,h,ev), ...
            'MouseClickedCallback', @(h,ev)bst_call(@CoordListClick_Callback,h,ev));
        % Size
        jPanelScrollList = JScrollPane();
        jPanelScrollList.getLayout.getViewport.setView(jListCoord);
        jPanelScrollList.setHorizontalScrollBarPolicy(jPanelScrollList.HORIZONTAL_SCROLLBAR_NEVER);
        jPanelScrollList.setVerticalScrollBarPolicy(jPanelScrollList.VERTICAL_SCROLLBAR_ALWAYS);
        jPanelScrollList.setBorder(BorderFactory.createEmptyBorder(10,10,10,10));
        jPanelDisplay.add(jPanelScrollList, BorderLayout.CENTER);
    jPanelNew.add(jPanelDisplay, BorderLayout.CENTER);

    % create the controls structure
    ctrl = struct('jMenuEeg',                       jMenuEeg, ...
                  'jButtonNasion',                  jButtonNasion, ...
                  'jButtonLPA',                     jButtonLPA, ...
                  'jButtonRPA',                     jButtonRPA, ...
                  'jLabelCoilMessage',              jLabelCoilMessage, ...
                  'jLabelFidMessage',               jLabelFidMessage, ...
                  'jButtonhpiN',                    jButtonhpiN, ...
                  'jButtonhpiL',                    jButtonhpiL, ...
                  'jButtonhpiR',                    jButtonhpiR, ...
                  'jListCoord',                     jListCoord, ...
                  'jButtonEEGStart',                jButtonEEGStart, ...
                  'jButtonEEGAutoDetectElectrodes', jButtonEEGAutoDetectElectrodes, ...
                  'jTextFieldEEG',                  jTextFieldEEG, ...
                  'jButtonExtraStart',              jButtonExtraStart, ...
                  'jButtonRandomHeadPts',           jButtonRandomHeadPts, ...
                  'jTextFieldExtra',                jTextFieldExtra, ...
                  'jButtonDeletePoint',             jButtonDeletePoint);
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
    
    %% =================================================================================
    %  === INTERNAL CALLBACKS  =========================================================
    %  =================================================================================
    %% ===== COORDINATE LIST KEY TYPED CALLBACK =====
    function CoordListKeyTyped_Callback(h, ev)
        switch(uint8(ev.getKeyChar()))
            % DELETE
            case {ev.VK_DELETE, ev.VK_BACK_SPACE}
                ctrl = bst_get('PanelControls', Digitize.Type);
                % if contact list rendering is blank in panel then dont't proceed
                if ctrl.jListCoord.isSelectionEmpty()
                    return;
                end

                [sCoordName, iSelCoord] = GetSelectedCoord();
                spl = regexp(sCoordName,'\s+','split');
                nameFinal = spl{1};
                if (~strcmpi(nameFinal, 'Nasion') &&...
                    ~strcmpi(nameFinal, 'LPA') &&...
                    ~strcmpi(nameFinal, 'RPA'))
                    listModel = ctrl.jListCoord.getModel();
                    listModel.setElementAt(nameFinal, iSelCoord-1);  
                    RemoveCoordinates('EEG', iSelCoord-3);
                    Digitize.isEditPts = 1;
                    SwitchToNewMode(7);
                end
        end
    end
    
    %% ===== COORDINATE LIST CLICK CALLBACK =====
    function CoordListClick_Callback(h, ev)
        % IF SINGLE CLICK
        if (ev.getClickCount() == 1)
            ctrl = bst_get('PanelControls', Digitize.Type);
            % if contact list rendering is blank in panel then dont't proceed
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
    ctrl = bst_get('PanelControls', Digitize.Type);
    if isempty(ctrl)
        return;
    end

    % Get JList selected indices
    iSelCoord = uint16(ctrl.jListCoord.getSelectedIndices())' + 1;
    listModel = ctrl.jListCoord.getModel();
    sCoordName = listModel.getElementAt(iSelCoord-1);
end

%% ===== CLOSE =====
function Close_Callback()
    global Digitize

    gui_hide(Digitize.Type);
end

%% ===== HIDING CALLBACK =====
function isAccepted = PanelHidingCallback() %#ok<DEFNU>
    global Digitize

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
    if isempty(Digitize.Points.trans)
        % Delete study
        if ~isempty(iStudy)
            db_delete_studies(iStudy);
            panel_protocols('UpdateTree');
        end
    % Else: reload to get access to the EEG type of sensors
    else
        db_reload_studies(iStudy);
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    isAccepted = 1;
end


%% ===== EDIT SETTINGS =====
function isOk = EditSettings()
    global Digitize

    isOk = 0;
    % Get options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Ask for new options
    if strcmpi(Digitize.Type, 'Revopoint')
        [res, isCancel] = java_dialog('input', ...
                {'<HTML><B>Collection settings</B><BR><BR>Digitize MEG HPI coils (0=no, 1=yes):', ...
                 '<HTML>How many times do you want to collect<BR>the three fiducials (NAS,LPA,RPA):', ...
                 'Beep when collecting point (0=no, 1=yes):'}, ...
                'Revopoint configuration', [], ...
                {num2str(DigitizeOptions.isMEG), ...
                 num2str(DigitizeOptions.nFidSets), ...
                 num2str(DigitizeOptions.isBeep)});       
    else
        [res, isCancel] = java_dialog('input', ...
                {'<HTML><B>Serial connection settings</B><BR><BR>Serial port name (COM1):', ...
                 'Unit Type (Fastrak or Patriot):', ...
                 '<HTML><BR><B>Collection settings</B><BR><BR>Digitize MEG HPI coils (0=no, 1=yes):', ...
                 '<HTML>How many times do you want to collect<BR>the three fiducials (NAS,LPA,RPA):', ...
                 'Beep when collecting point (0=no, 1=yes):'}, ...
                'Digitizer configuration', [], ...
                {DigitizeOptions.ComPort, ...
                 DigitizeOptions.UnitType, ...
                 num2str(DigitizeOptions.isMEG), ...
                 num2str(DigitizeOptions.nFidSets), ...
                 num2str(DigitizeOptions.isBeep)});       
    end 
    if isempty(res) || isCancel
        return
    end
    % Check values
    if (length(res) < 5) || isempty(res{1}) || isempty(res{2}) || ~ismember(str2double(res{3}), [0 1]) || isnan(str2double(res{4})) || ~ismember(str2double(res{5}), [0 1])
        bst_error('Invalid values.', 'Digitize', 0);
        return;
    end
    % Get entered values
    DigitizeOptions.ComPort      = res{1};
    DigitizeOptions.UnitType     = lower(res{2});
    DigitizeOptions.isMEG        = str2double(res{3});
    DigitizeOptions.nFidSets     = str2double(res{4});
    DigitizeOptions.isBeep       = str2double(res{5});
    
    if strcmp(DigitizeOptions.UnitType,'fastrak')
        DigitizeOptions.ComRate = 9600;
        DigitizeOptions.ComByteCount = 94;
    elseif strcmp(DigitizeOptions.UnitType,'patriot')
        DigitizeOptions.ComRate = 115200;
        DigitizeOptions.ComByteCount = 120;
    else
        bst_error('Incorrect unit type.', 'Digitize', 0);
        return;
    end
    
    % Save values
    bst_set('DigitizeOptions', DigitizeOptions);
    %ResetDataCollection();
    isOk = 1;
end


%% ===== SET SIMULATION MODE =====
% USAGE:  panel_digitize('SetSimulate', isSimulate)
function SetSimulate(isSimulate) %#ok<DEFNU>
    % Get options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Change value
    DigitizeOptions.isSimulate = isSimulate;
    % Save values
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
    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    % Reset points structure
    Digitize.Points = struct(...
        'nasion',    [], ...
        'LPA',       [], ...
        'RPA',       [], ...
        'hpiN',     [], ...
        'hpiL',     [], ...
        'hpiR',     [], ...
        'EEG',       [], ...
        'headshape', [], ...
        'trans',     []);
    % Reset counters
    if ~isempty(ctrl)
        ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(1)));
        ctrl.jTextFieldExtra.setText(java.lang.String.valueOf(int16(1)));
    end
    % Reset figure
    if isfield(Digitize, 'hFig') && ~isempty(Digitize.hFig) && ishandle(Digitize.hFig)
        %close(Digitize.hFig);
        if ~strcmpi(Digitize.Type, 'Revopoint')
            bst_figures('DeleteFigure', Digitize.hFig, []);
        end
    end
    Digitize.iDS = [];
    
    % Reset buttons, start with Nasion
    SwitchToNewMode(0);
    % Update list of loaded points
    UpdateList();
    % Close progress bar
    bst_progress('stop');
end


%% ===== SWITCH TO NEW GUI MODE =====
% INPUTS:
%    - Mode 0 = Start over
%    - Mode 1 = Center coil
%    - Mode 2 = Left coil
%    - Mode 3 = Right coil
%    - Mode 4 = Nasion
%    - Mode 5 = LPA
%    - Mode 6 = RPA
%    - Mode 7 = EEG
%    - Mode 8 = Headshape
function SwitchToNewMode(mode)
    global Digitize

    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    % Get options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Select mode
    switch mode
        % Re-initialize interface
        case 0
            % Clear out any existing collection
            ctrl.jLabelFidMessage.setText('');
            ctrl.jLabelCoilMessage.setText('');
            RemoveCoordinates([]);
            if DigitizeOptions.isMEG
                ctrl.jButtonhpiN.setEnabled(1);
                ctrl.jButtonhpiL.setEnabled(1);
                ctrl.jButtonhpiR.setEnabled(1);
                ctrl.jButtonNasion.setEnabled(0);
                ctrl.jButtonLPA.setEnabled(0);
                ctrl.jButtonRPA.setEnabled(0);
                ctrl.jButtonDeletePoint.setEnabled(0);
                ctrl.jButtonEEGAutoDetectElectrodes.setEnabled(0);
                % always switch to next mode to start with the nasion
                SwitchToNewMode(1);
            else
                ctrl.jButtonhpiN.setEnabled(0);
                ctrl.jButtonhpiL.setEnabled(0);
                ctrl.jButtonhpiR.setEnabled(0);
                ctrl.jButtonNasion.setEnabled(1);
                ctrl.jButtonLPA.setEnabled(1);
                ctrl.jButtonRPA.setEnabled(1);
                ctrl.jButtonDeletePoint.setEnabled(0);
                ctrl.jButtonEEGAutoDetectElectrodes.setEnabled(0);
                % always switch to next mode to start with the nasion
                SwitchToNewMode(4);
            end
            
            ctrl.jButtonEEGStart.setEnabled(0);
            ctrl.jTextFieldEEG.setEnabled(0);
            ctrl.jButtonExtraStart.setEnabled(0);
            ctrl.jButtonRandomHeadPts.setEnabled(0);
            ctrl.jTextFieldExtra.setEnabled(0);

            
        % Center Coil
        case 1
            SetSelectedButton(1);
            Digitize.Mode = 1; 

        % Left Coil
        case 2
            SetSelectedButton(2);
            Digitize.Mode = 2;
        
        % Right Coil
        case 3
            SetSelectedButton(3);
            Digitize.Mode = 3;
            
        % Nasion
        case 4
            ctrl.jButtonhpiN.setEnabled(0);
            ctrl.jButtonhpiL.setEnabled(0);
            ctrl.jButtonhpiR.setEnabled(0);
            ctrl.jButtonNasion.setEnabled(1);
            ctrl.jButtonLPA.setEnabled(1);
            ctrl.jButtonRPA.setEnabled(1);
            SetSelectedButton(4);
            Digitize.Mode = 4;
            
        % LPA
        case 5
            SetSelectedButton(5);
            Digitize.Mode = 5;
            
        % RPA
        case 6
            SetSelectedButton(6);
            if strcmpi(Digitize.Type, 'Revopoint')
                ctrl.jButtonEEGAutoDetectElectrodes.setEnabled(1);
            end
            Digitize.Mode = 6;
            
        % EEG
        case 7
            % Get current montage
            [curMontage, nEEG] = GetCurrentMontage();
            % There are EEG electrodes: enter EEG collection
            if (nEEG > 0)
                % Enable buttons
                ctrl.jButtonEEGStart.setEnabled(1);
                ctrl.jTextFieldEEG.setEnabled(1);
                % Switch to EEG acquisition
                SetSelectedButton(7);
                Digitize.Mode = 7;
            % Else: switch directly to mode 8 (head shape)
            else
                ctrl.jButtonExtraStart.setEnabled(1);
                if strcmpi(Digitize.Type, 'Revopoint')
                    ctrl.jButtonEEGAutoDetectElectrodes.setEnabled(1);
                    ctrl.jButtonRandomHeadPts.setEnabled(0);
                end
                ctrl.jTextFieldExtra.setEnabled(1);
                SetSelectedButton(8);
                Digitize.Mode = 8;
            end
        % Shape
        case 8
            ctrl.jButtonExtraStart.setEnabled(1);
            if strcmpi(Digitize.Type, 'Revopoint')
                ctrl.jButtonEEGAutoDetectElectrodes.setEnabled(0);
                ctrl.jButtonRandomHeadPts.setEnabled(1);
            end
            ctrl.jTextFieldExtra.setEnabled(1);
            SetSelectedButton(8);
            Digitize.Mode = 8;            
    end
end


%% ===== UPDATE LIST =====
function UpdateList()
    global Digitize

    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    % Define the model
    listModel = javax.swing.DefaultListModel();
    % Get current montage
    [curMontage, nEEG] = GetCurrentMontage();
    % Get options
    DigitizeOptions = bst_get('DigitizeOptions');
    nFidSets = DigitizeOptions.nFidSets;
    isMEG = DigitizeOptions.isMEG;
    % === COILS ===
    % Center, Left, Right
    if isMEG
        for i = 1:nFidSets
            if size(Digitize.Points.hpiN,1) >= i
                listModel.addElement(sprintf('HPI-N     %3.3f   %3.3f   %3.3f', Digitize.Points.hpiN(i,:) .* 100));
            else
                listModel.addElement('HPI-N');
            end

            if size(Digitize.Points.hpiL,1) >= i
                listModel.addElement(sprintf('HPI-L     %3.3f   %3.3f   %3.3f', Digitize.Points.hpiL(i,:) .* 100));
            else
                listModel.addElement('HPI-L');
            end

            if size(Digitize.Points.hpiR,1) >= i
                listModel.addElement(sprintf('HPI-R     %3.3f   %3.3f   %3.3f', Digitize.Points.hpiR(i,:) .* 100));
            else
                listModel.addElement('HPI-R');
            end
        end
    end
    
    % === FIDUCIALS ===
    % Nasion, left, right
    for i = 1:nFidSets
        if size(Digitize.Points.nasion,1) >= i
            listModel.addElement(sprintf('Nasion     %3.3f   %3.3f   %3.3f', Digitize.Points.nasion(i,:) .* 100));
        else
            listModel.addElement('Nasion');
        end
        
        if size(Digitize.Points.LPA,1) >= i
            listModel.addElement(sprintf('LPA     %3.3f   %3.3f   %3.3f', Digitize.Points.LPA(i,:) .* 100));
        else
            listModel.addElement('LPA');
        end
        
        if size(Digitize.Points.RPA,1) >= i
            listModel.addElement(sprintf('RPA     %3.3f   %3.3f   %3.3f', Digitize.Points.RPA(i,:) .* 100));
        else
            listModel.addElement('RPA');
        end
    end
    
    % === EEG ===
    nRecEEG = size(Digitize.Points.EEG,1);
    % EEG electrodes already digitized
    for i = 1:nRecEEG
        listModel.addElement(sprintf('%s     %3.3f   %3.3f   %3.3f', curMontage.Labels{i}, Digitize.Points.EEG(i,:) .* 100));
    end
    % EEG electrodes remaining
    for i = (nRecEEG+1):nEEG
        listModel.addElement(curMontage.Labels{i});
    end
    
    % === HEADSHAPE ===
    nHeadShape = size(Digitize.Points.headshape,1);
    for i = 1:nHeadShape
        listModel.addElement(sprintf('%03d     %3.3f   %3.3f   %3.3f', i, Digitize.Points.headshape(i,:) .* 100));
    end

    % === EXTRA FIDUCIALS ===
    nExtraFids = size(Digitize.Points.nasion,1) - nFidSets;
    if nExtraFids > 0
        % write the extra points
        for i = (nFidSets+1):nFidSets+nExtraFids
            if size(Digitize.Points.nasion,1) >= i
                listModel.addElement(sprintf('Nasion     %3.3f   %3.3f   %3.3f', Digitize.Points.nasion(i,:) .* 100));
            else
                listModel.addElement('Nasion');
            end

            if size(Digitize.Points.LPA,1) >= i
                listModel.addElement(sprintf('LPA     %3.3f   %3.3f   %3.3f', Digitize.Points.LPA(i,:) .* 100));
            else
                listModel.addElement('LPA');
            end

            if size(Digitize.Points.RPA,1) >= i
                listModel.addElement(sprintf('RPA     %3.3f   %3.3f   %3.3f', Digitize.Points.RPA(i,:) .* 100));
            else
                listModel.addElement('RPA');
            end
        end
    end
    
    % Set this list
    ctrl.jListCoord.setModel(listModel);
    ctrl.jListCoord.repaint();
    drawnow;
    % Scroll down
    lastIndex = min(listModel.getSize(), 12 + nRecEEG + nHeadShape);
    selRect = ctrl.jListCoord.getCellBounds(lastIndex-1, lastIndex-1);
    %ctrl.jListCoord.scrollRectToVisible(selRect);
    ctrl.jListCoord.repaint();
    ctrl.jListCoord.getParent().getParent().repaint();
end


%% ===== SET SELECTED BUTTON =====
function SetSelectedButton(iButton)
    global Digitize

    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    % Create list of buttons
    jButton = javaArray('javax.swing.JToggleButton', 8);
    jButton(1) = ctrl.jButtonhpiN;
    jButton(2) = ctrl.jButtonhpiL;
    jButton(3) = ctrl.jButtonhpiR;
    jButton(4) = ctrl.jButtonNasion;
    jButton(5) = ctrl.jButtonLPA;
    jButton(6) = ctrl.jButtonRPA;
    jButton(7) = ctrl.jButtonEEGStart;
    jButton(8) = ctrl.jButtonExtraStart;
    % Set the selected button color
    jButton(iButton).setSelected(1);
    jButton(iButton).setForeground(java.awt.Color(.8,0,0));
    % Reset the other buttons colors
    for i = setdiff([1 2 3 4 5 6 7 8], iButton)
        if jButton(i).isEnabled()
            color = java.awt.Color(0,0,0);
        else
            color = javax.swing.UIManager.getColor('Label.disabledForeground');
            if isempty(color)
                color = java.awt.Color(.5,.5,.5);
            end
        end
        jButton(i).setForeground(color);
    end
end

%% REVOPOINT: AUTOMATICALLY DETECT AND LABEL EEG CAP ELECTRODES
function EEGAutoDetectElectrodes(h, ev)
    global Digitize

    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    
    % Get the surface
    hFig = bst_figures('GetCurrentFigure','3D');
    [~, TessInfo, ~, ~] = panel_surface('GetSurfaceMri', hFig);
    sSurf.Vertices = TessInfo.hPatch.Vertices;
    sSurf.Faces = TessInfo.hPatch.Faces;
    sSurf.Color = TessInfo.hPatch.FaceVertexCData;
    
    % call automation functions to get the EEG cap electrodes
    [centers_cap, cap_img, sSurf] = findElectrodesEegCap(sSurf);
    DigitizeOptions = bst_get('DigitizeOptions');
    if isempty(DigitizeOptions.Montages(DigitizeOptions.iMontage).ChannelFile)
        bst_error('EEG cap layout not selected. Go to EEG', 'Revopoint', 1);
        return;
    else
        ChannelMat = in_bst_channel(DigitizeOptions.Montages(DigitizeOptions.iMontage).ChannelFile);
    end
    capPoints3d = warpLayout2Mesh(centers_cap, ChannelMat.Channel, cap_img, sSurf, Digitize.Points.EEG);
    
    % Plot the electrodes and their labels
    for i= 1:length(capPoints3d)
        pointCoord = capPoints3d(i, :);
        % find the index for the current point
        iPoint = str2double(ctrl.jTextFieldEEG.getText());
        % Transform coordinate
        Digitize.Points.EEG(iPoint,:) = pointCoord;
        % Add the point to the display
        % Get current montage
        [curMontage, nEEG] = GetCurrentMontage();
        PlotCoordinate(Digitize.Points.EEG(iPoint,:), curMontage.Labels{iPoint}, 'EEG', iPoint)
        % update text field counter to the next point in the list
        nextPoint = max(size(Digitize.Points.EEG,1)+1, 1);
        if nextPoint > nEEG
            % all EEG points have been collected, switch to next mode
            ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(nEEG)));
            SwitchToNewMode(8);
        else
            ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(nextPoint)));
        end
    end
    
    UpdateList();
    ctrl.jButtonEEGAutoDetectElectrodes.setEnabled(0);
end

%% ===== MANUAL COLLECT CALLBACK ======
function ManualCollect_Callback(h, ev)
    global Digitize

    % Get Digitize options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Simulation: call the callback directly
    if DigitizeOptions.isSimulate
        BytesAvailable_Callback(h, ev);
    % Else: Send a collection request to the Polhemus
    else
        % User clicked the button, collect a point
        fprintf(Digitize.SerialConnection,'%s','P');
        pause(0.2);
    end
end

%% ===== COLLECT RANDOM HEADPOINTS =====
function CollectRandomHeadPts_Callback(h, ev)
    global Digitize;
    
    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);

    hFig = bst_figures('GetCurrentFigure','3D');
    [sMri, TessInfo, iTess, iMri] = panel_surface('GetSurfaceMri', hFig);
    TessMat.Vertices = double(TessInfo.hPatch.Vertices);
    TessMat.Faces = double(TessInfo.hPatch.Faces);
    TessMat.Color = TessInfo.hPatch.FaceVertexCData;
    dsFactor = 100 / size(TessMat.Vertices, 1); 
    % Reduce number of vertices
    [NewTessMat.Faces, NewTessMat.Vertices] = reducepatch(TessMat.Faces, TessMat.Vertices, dsFactor);
    
    for i= 1:100
        % pointCoord = sSurf.Vertices(randi(length(sSurf.Vertices)), :);
        pointCoord = NewTessMat.Vertices(i, :);
        % find the index for the current point in the headshape points
        iPoint = str2double(ctrl.jTextFieldExtra.getText());
        % Transformed points_pen from original points_pen
        Digitize.Points.headshape(iPoint,:) = pointCoord;
        % add the point to the display (in cm)
        PlotCoordinate(Digitize.Points.headshape(iPoint,:), 'EXTRA', 'EXTRA', iPoint)
        % update text field counter to the next point in the list
        nextPoint = iPoint+1;
        ctrl.jTextFieldExtra.setText(java.lang.String.valueOf(int16(nextPoint)));
    end
    UpdateList();
end

%% ===== DELETE POINT CALLBACK =====
function DeletePoint_Callback(h, ev) %#ok<INUSD>
    global Digitize

    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    DigitizeOptions = bst_get('DigitizeOptions');
    
    % only remove cardinal points when MEG coils are used for the
    % transformation.
    if ismember(Digitize.Mode, [4 5 6]) && DigitizeOptions.isMEG
        % Remove the last cardinal point that was collected
        iPoint = size(Digitize.Points.nasion,1);
        coordInd = (iPoint-1)*3;
        if iPoint == 0
            return; 
        end
        point_type = 'cardinal';
    end
    
    if Digitize.Mode == 7
    	%  find the last EEG point collected
        iPoint = str2double(ctrl.jTextFieldEEG.getText()) - 1;
        if iPoint == 0
            % if no EEG points are collected, delete the last cardinal point
            iPoint = size(Digitize.Points.nasion,1);
            coordInd = (iPoint-1)*3;
            point_type = 'cardinal';
        else
            % delete last EEG point
            point_type = 'eeg';
        end
               
    elseif Digitize.Mode == 8
        % headshape point
        iPoint = str2double(ctrl.jTextFieldExtra.getText()) - 1;
        if iPoint == 0 
            % If no headpoints are collected:
            [tmp, nEEG] = GetCurrentMontage();
            if nEEG > 0
                % check for EEG, then delete the last point
                iPoint = str2double(ctrl.jTextFieldEEG.getText());
                point_type = 'eeg';
            else
                % delete the last cardinal point
                iPoint = size(Digitize.Points.nasion,1);
                coordInd = (iPoint-1)*3;
                point_type = 'cardinal';
            end
        else
            point_type = 'extra';
        end
    end
    
    % Now delete the define point
    switch point_type
        case 'cardinal'
            if size(Digitize.Points.LPA,1) < iPoint
                % The LPA has not been collected, remove the nasion point;
                Digitize.Points.nasion(iPoint,:) = [];
                % Find the index of the cardinal points
                RemoveCoordinates('CARDINAL', coordInd+1);
                SwitchToNewMode(4);  
            elseif size(Digitize.Points.RPA,1) < iPoint
                % The RPA has not been collected, remove the LPA point
                Digitize.Points.LPA(iPoint,:) = [];
                % Find the index of the cardinal points
                RemoveCoordinates('CARDINAL', coordInd+2);
                SwitchToNewMode(5);  
            else
                % One full set has been collected, remove the last RPA point
                Digitize.Points.RPA(iPoint,:) = [];
                % Find the index of the cardinal points
                RemoveCoordinates('CARDINAL', coordInd+3);
                SwitchToNewMode(6);  
            end
        case 'eeg'
            Digitize.Points.EEG(iPoint,:) = [];
            RemoveCoordinates('EEG', iPoint);
            ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(iPoint)));
            SwitchToNewMode(7)
        case 'extra'
            Digitize.Points.headshape(iPoint,:) = [];
            RemoveCoordinates('EXTRA', iPoint);
            ctrl.jTextFieldExtra.setText(java.lang.String.valueOf(int16(iPoint)));
            SwitchToNewMode(8)
    end
    
    % Update coordinates list
    UpdateList();   
end

%% ===== COMPUTE TRANFORMATION =====
function ComputeTransform()
    global Digitize

    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    
    % Get options
    DigitizeOptions = bst_get('DigitizeOptions');
    
    % if MEG coils are used, these will determine the coodinate system
    if DigitizeOptions.isMEG
        % find the difference between the first two collections to determine error
        if (size(Digitize.Points.hpiN, 1) > 1)
            diffPoint = Digitize.Points.hpiN(1,:) - Digitize.Points.hpiN(2,:);
            normPoint(1) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            diffPoint = Digitize.Points.hpiL(1,:) - Digitize.Points.hpiL(2,:);
            normPoint(2) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            diffPoint = Digitize.Points.hpiR(1,:) - Digitize.Points.hpiR(2,:);
            normPoint(3) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            if any(abs(normPoint) > .005)
                ctrl.jLabelCoilMessage.setText('Difference error exceeds 5 mm');
            end
        end
        % find the average across collections to compute the transformation
        na = mean(Digitize.Points.hpiN,1); % these values are in meters
        la = mean(Digitize.Points.hpiL,1);
        ra = mean(Digitize.Points.hpiR,1);
    
    else
        % if only EEG is used, the cardinal points will determine the
        % coordinate system
        
        % find the difference between the first two collections to determine error
        if (size(Digitize.Points.nasion, 1) > 1)
            diffPoint = Digitize.Points.nasion(1,:) - Digitize.Points.nasion(2,:);
            normPoint(1) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            diffPoint = Digitize.Points.LPA(1,:) - Digitize.Points.LPA(2,:);
            normPoint(2) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            diffPoint = Digitize.Points.RPA(1,:) - Digitize.Points.RPA(2,:);
            normPoint(3) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            if any(abs(normPoint) > .005)
                ctrl.jLabelFidMessage.setText('Difference error exceeds 5 mm');
            end
        end
        % find the average across collections to compute the transformation
        na = mean(Digitize.Points.nasion,1); % these values are in meters
        la = mean(Digitize.Points.LPA,1);
        ra = mean(Digitize.Points.RPA,1);
    end
    
    % Compute the transformation
    sMRI.SCS.NAS = na*1000; %m => mm for the brainstorm fxn
    sMRI.SCS.LPA = la*1000;
    sMRI.SCS.RPA = ra*1000;
    scsTransf = cs_compute(sMRI, 'scs');
    T = scsTransf.T ./ 1000; % mm => m
    R = scsTransf.R;
    Origin = scsTransf.Origin ./ 1000; %#ok<NASGU> % mm => m
    Digitize.Points.trans = [R, T];

    % Get the channel file
    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = load(ChannelFile);
    ChannelMat.HeadPoints.Loc = [];
    ChannelMat.HeadPoints.Label = [];
    ChannelMat.HeadPoints.Type = [];
    % Transform coordinates and save  
    if DigitizeOptions.isMEG
        for i = 1:size(Digitize.Points.hpiN,1)
            Digitize.Points.hpiN(i,:) = ([R, T] * [Digitize.Points.hpiN(i,:) 1]')';
            Digitize.Points.hpiL(i,:)    = ([R, T] * [Digitize.Points.hpiL(i,:) 1]')';
            Digitize.Points.hpiR(i,:)    = ([R, T] * [Digitize.Points.hpiR(i,:) 1]')';

            % Nasion
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,  Digitize.Points.hpiN(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'HPI-N'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'HPI'}];
            % LPA
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   Digitize.Points.hpiL(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'HPI-L'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'HPI'}];
            % RPA
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   Digitize.Points.hpiR(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'HPI-R'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'HPI'}];
        end
    else
        for i = 1:size(Digitize.Points.nasion,1)
            Digitize.Points.nasion(i,:) = ([R, T] * [Digitize.Points.nasion(i,:) 1]')';
            Digitize.Points.LPA(i,:)    = ([R, T] * [Digitize.Points.LPA(i,:) 1]')';
            Digitize.Points.RPA(i,:)    = ([R, T] * [Digitize.Points.RPA(i,:) 1]')';

            % Nasion
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,  Digitize.Points.nasion(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'NA'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'CARDINAL'}];
            % LPA
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   Digitize.Points.LPA(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'LPA'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'CARDINAL'}];
            % RPA
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   Digitize.Points.RPA(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'RPA'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'CARDINAL'}];
        end
    end
        
    save(ChannelFile, '-struct', 'ChannelMat');
    
end

%% ===== CREATE FIGURE =====
function CreateHeadpointsFigure()
    global Digitize

    if isempty(Digitize.hFig) || ~ishandle(Digitize.hFig) || isempty(Digitize.iDS)
        % Get study
        sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
        % Plot head points
        [hFig, iDS] = view_headpoints(file_fullpath(sStudy.Channel.FileName));
        % Hide head surface
        panel_surface('SetSurfaceTransparency', hFig, 1, 0.8);
        % Get Digitizer JFrame
        bstContainer = get(bst_get('Panel',Digitize.Type), 'container');
        % Get maximum figure position
        decorationSize = bst_get('DecorationSize');
        [jBstArea, FigArea] = gui_layout('GetScreenBrainstormAreas', bstContainer.handle{1});
        FigPos = FigArea(1,:) + [decorationSize(1),  decorationSize(4),  - decorationSize(1) - decorationSize(3),  - decorationSize(2) - decorationSize(4)];
        if (FigPos(3) > 0) && (FigPos(4) > 0)
            set(hFig, 'Position', FigPos);
        end
        % Remove the close handle function
        set(hFig, 'CloseRequestFcn', []);
        % Save handles in global variable
        Digitize.hFig = hFig;
        Digitize.iDS = iDS;
    else
        % Get study
        sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
        % Plot head points
        [hFig, iDS] = view_headpoints(file_fullpath(sStudy.Channel.FileName));
        % Get subject
        [sSubject, iSubject] = bst_get('Subject', Digitize.SubjectName);
        iTargetSurface = find(cellfun(@(c)~isempty(strfind(c, 'revopoint')), {sSubject.Surface.Comment})); 
        sSurf = bst_memory('LoadSurface', sSubject.Surface(iTargetSurface(end)).FileName);
        [nRows,nCols] = size(sSurf.Vertices);
        sSurf.Vertices = (Digitize.Points.trans * [sSurf.Vertices ones(nRows,1)]')';
        panel_surface('RemoveSurface', hFig, 1);
        % view the surface
        sSurf = tess_deface(sSurf);
        view_surface_matrix(sSurf.Vertices, sSurf.Faces, [], sSurf.Color, hFig, [], sSubject.Surface(iTargetSurface(end)).FileName);
        % Hide head surface
        if ~strcmpi(Digitize.Type, 'Revopoint')
            panel_surface('SetSurfaceTransparency', hFig, 1, 0.8);
        end
        % Get Digitizer JFrame
        bstContainer = get(bst_get('Panel', Digitize.Type), 'container');
        % Get maximum figure position
        decorationSize = bst_get('DecorationSize');
        [jBstArea, FigArea] = gui_layout('GetScreenBrainstormAreas', bstContainer.handle{1});
        FigPos = FigArea(1,:) + [decorationSize(1),  decorationSize(4),  - decorationSize(1) - decorationSize(3),  - decorationSize(2) - decorationSize(4)];
        if (FigPos(3) > 0) && (FigPos(4) > 0)
            set(hFig, 'Position', FigPos);
        end
        % Remove the close handle function
        set(hFig, 'CloseRequestFcn', []);
        % Save handles in global variable
        Digitize.hFig = hFig;
        Digitize.iDS = iDS;
    end
end

%% ===== PLOT POINTS =====
function PlotCoordinate(Loc, Label, Type, iPoint)
    global Digitize GlobalData  

    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = load(ChannelFile);

    % Add EEG sensor locations to channel stucture
    if strcmp(Type, 'EEG')
        if isempty(ChannelMat.Channel)
            % first point in the list
            ChannelMat.Channel = db_template('channeldesc');
        end
        ChannelMat.Channel(iPoint).Name = Label;
        ChannelMat.Channel(iPoint).Type = 'EEG';
        ChannelMat.Channel(:,iPoint).Loc = Loc';       
    else   
        ind = size(ChannelMat.HeadPoints.Loc,2) + 1;
        ChannelMat.HeadPoints.Loc(:,ind) = Loc';
        ChannelMat.HeadPoints.Label{ind} = Label;
        ChannelMat.HeadPoints.Type{ind}  = Type;
    end     
    
    save(ChannelFile, '-struct', 'ChannelMat');
    GlobalData.DataSet(Digitize.iDS).HeadPoints  = ChannelMat.HeadPoints;
    GlobalData.DataSet(Digitize.iDS).Channel  = ChannelMat.Channel;
    % Remove old HeadPoints
    hAxes = findobj(Digitize.hFig, '-depth', 1, 'Tag', 'Axes3D');
    hHeadPointsMarkers = findobj(hAxes, 'Tag', 'HeadPointsMarkers');
    hHeadPointsLabels  = findobj(hAxes, 'Tag', 'HeadPointsLabels');
    delete(hHeadPointsMarkers);
    delete(hHeadPointsLabels);
    % View all points in the channel file
    figure_3d('ViewHeadPoints', Digitize.hFig, 1);
    figure_3d('ViewSensors',Digitize.hFig, 1, 1, 0,'EEG');
    % Hide head surface
    if ~strcmpi(Digitize.Type, 'Revopoint')
        panel_surface('SetSurfaceTransparency', Digitize.hFig, 1, 1);
    end
end

%% ===== EEG CHANGE POINT CALLBACK =====
function EEGChangePoint_Callback(h, ev) %#ok<INUSD>
    global Digitize

    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    % Get digitize options
    DigitizeOptions = bst_get('DigitizeOptions');
    
    initPoint = str2num(ctrl.jTextFieldEEG.getText());
    % restrict to a maximum of points collected or defined max points and minimum of '1'
    [curMontage, nEEG] = GetCurrentMontage();
    newPoint = max(min(initPoint, min(length(Digitize.Points.EEG)+1, nEEG)), 1);
    ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(newPoint)));
end

%% ===== EXTRA CHANGE POINT CALLBACK =====
function ExtraChangePoint_Callback(h, ev) %#ok<INUSD>
    global Digitize

    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    
    initPoint = str2num(ctrl.jTextFieldExtra.getText()); %#ok<*ST2NM>
    % restrict to a maximum of points collected and minimum of '1'
    newPoint = max(min(initPoint, length(Digitize.Points.headshape)+1), 1);
    ctrl.jTextFieldExtra.setText(java.lang.String.valueOf(int16(newPoint)));
end

%% ===== SAVE CALLBACK =====
function Save_Callback(h, ev) %#ok<INUSD>
    global Digitize

    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);  
    export_channel( ChannelFile );
end

%% ===== CREATE MONTAGE MENU =====
function CreateMontageMenu(jMenu)
    import org.brainstorm.icon.*;
    global Digitize

    % Get menu pointer if not in argument
    if (nargin < 1) || isempty(jMenu)
        ctrl = bst_get('PanelControls', Digitize.Type);
        jMenu = ctrl.jMenuEeg;
    end
    % Get Digitize options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Empty menu
    jMenu.removeAll();
    % Button group
    buttonGroup = javax.swing.ButtonGroup();
    % Display all the montages
    for i = 1:length(DigitizeOptions.Montages)
        jMenuMontage = gui_component('RadioMenuItem', jMenu, [], DigitizeOptions.Montages(i).Name, buttonGroup, [], @(h,ev)bst_call(@SelectMontage, i), []);
        if (i == 2) && (length(DigitizeOptions.Montages) > 2)
            jMenu.addSeparator();
        end
        if (i == DigitizeOptions.iMontage)
            jMenuMontage.setSelected(1);
        end
    end
    % Add new montage / reset list
    jMenu.addSeparator();

    % Adding montage from text files only available for Polhemus Digitizer
    if ~strcmpi(Digitize.Type, 'Revopoint')
        gui_component('MenuItem', jMenu, [], 'Add EEG montage...', [], [], @(h,ev)bst_call(@AddMontage), []);
    end
    gui_component('MenuItem', jMenu, [], 'Unload all montages', [], [], @(h,ev)bst_call(@UnloadAllMontages), []);
    
    % Creating montages from EEG cap layout mat files (only for Revopoint)
    if strcmpi(Digitize.Type, 'Revopoint')
        jMenu = gui_component('Menu', jMenu, [], 'Use default EEG cap', IconLoader.ICON_CHANNEL, [], [], 12);
    
        % === USE DEFAULT CHANNEL FILE ===
        % Get registered Brainstorm EEG defaults
        bstDefaults = bst_get('EegDefaults');
        if ~isempty(bstDefaults)
            % Add a directory per template block available
            for iDir = 1:length(bstDefaults)
                jMenuDir = gui_component('Menu', jMenu, [], bstDefaults(iDir).name, IconLoader.ICON_FOLDER_CLOSE, [], [], 12);
                isMni = strcmpi(bstDefaults(iDir).name, 'ICBM152');
                % Create subfolder for cap manufacturer
                jMenuOther = gui_component('Menu', [], [], 'Generic', IconLoader.ICON_FOLDER_CLOSE, [], [], 12);
                jMenuAnt = gui_component('Menu', [], [], 'ANT', IconLoader.ICON_FOLDER_CLOSE, [], [], 12);
                jMenuBs  = gui_component('Menu', [], [], 'BioSemi', IconLoader.ICON_FOLDER_CLOSE, [], [], 12);
                jMenuBp  = gui_component('Menu', [], [], 'BrainProducts', IconLoader.ICON_FOLDER_CLOSE, [], [], 12);
                jMenuEgi = gui_component('Menu', [], [], 'EGI', IconLoader.ICON_FOLDER_CLOSE, [], [], 12);
                jMenuNs  = gui_component('Menu', [], [], 'NeuroScan', IconLoader.ICON_FOLDER_CLOSE, [], [], 12);
                % Add an item per Template available
                fList = bstDefaults(iDir).contents;
                % Sort in natural order
                [tmp,I] = sort_nat({fList.name});
                fList = fList(I);
                for iFile = 1:length(fList)
                    % Define callback function to add montage from mat file
                    fcnCallback = @(h,ev)AddMontage(fList(iFile).fullpath);
                    
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
                    else
                        jMenuType = jMenuOther;
                    end
                    % Create item
                    gui_component('MenuItem', jMenuType, [], fList(iFile).name, IconLoader.ICON_CHANNEL, [], fcnCallback, 12);
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
            end
        end
    end
end

%% ===== SELECT MONTAGE =====
function SelectMontage(iMontage)
    % Get Digitize options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Default montage: ask for number of channels
    if (iMontage == 2)
        % Get previous number of electrodes
        nEEG = length(DigitizeOptions.Montages(iMontage).Labels);
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
        DigitizeOptions.Montages(iMontage).Name = sprintf('Default (%d)', nEEG);
        DigitizeOptions.Montages(iMontage).Labels = {};
        for i = 1:nEEG
            if (nEEG > 99)
                strFormat = 'EEG%03d';
            else
                strFormat = 'EEG%02d';
            end
            DigitizeOptions.Montages(iMontage).Labels{i} = sprintf(strFormat, i);
        end
    end
    % Save currently selected montage
    DigitizeOptions.iMontage = iMontage;
    % Save Digitize options
    bst_set('DigitizeOptions', DigitizeOptions);
    % Update menu
    CreateMontageMenu();
    % Restart acquisition
    ResetDataCollection();
end

%% ===== GET CURRENT MONTAGE =====
function [curMontage, nEEG] = GetCurrentMontage()
    % Get Digitize options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Return current montage
    curMontage = DigitizeOptions.Montages(DigitizeOptions.iMontage);
    nEEG = length(curMontage.Labels);
end

%% ===== ADD EEG MONTAGE =====
function AddMontage(ChannelFile)
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
    % Add Montage from mat file of EEG caps
    else
        % Load existing file
        ChannelMat = in_bst_channel(ChannelFile);
        
        % Intialize new montage
        newMontage.Name = ChannelMat.Comment;
        newMontage.Labels = {};
        newMontage.ChannelFile = ChannelFile;
        
        % Get labels
        [~,col] = size(ChannelMat.Channel);
        
        % if Acticap
        if ~isempty(regexp(newMontage.Name, 'ActiCap', 'match')) && col==66
            newMontage.Labels{end+1} = 'Oz';
            newMontage.Labels{end+1} = 'T8';
            newMontage.Labels{end+1} = 'GND';
            newMontage.Labels{end+1} = 'T7';
            for i=1:col
                if ~strcmpi(ChannelMat.Channel(i).Name, 'Oz') &&...
                   ~strcmpi(ChannelMat.Channel(i).Name, 'T8') &&...
                   ~strcmpi(ChannelMat.Channel(i).Name, 'GND') &&...
                   ~strcmpi(ChannelMat.Channel(i).Name, 'T7')
                    newMontage.Labels{end+1} = ChannelMat.Channel(i).Name;
                end
            end
        % if Waveguard
        elseif ~isempty(regexp(newMontage.Name, 'Waveguard', 'match')) && col==65
            newMontage.Labels{end+1} = 'Oz';
            newMontage.Labels{end+1} = 'T8';
            newMontage.Labels{end+1} = 'Fpz';
            newMontage.Labels{end+1} = 'T7';
            for i=1:col
                if ~strcmpi(ChannelMat.Channel(i).Name, 'Oz') &&...
                   ~strcmpi(ChannelMat.Channel(i).Name, 'T8') &&...
                   ~strcmpi(ChannelMat.Channel(i).Name, 'Fpz') &&...
                   ~strcmpi(ChannelMat.Channel(i).Name, 'T7')
                    newMontage.Labels{end+1} = ChannelMat.Channel(i).Name;
                end
            end
        end
        % If no labels were read: exit
        if isempty(newMontage.Labels)
            bst_error('EEG cap configuration not supported', 'Revopoint', 0);
            return
        end
    end
    
    
    % Get Digitize options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Get existing montage with the same name
    iMontage = find(strcmpi({DigitizeOptions.Montages.Name}, newMontage.Name));
    % If not found: create new montage entry
    if isempty(iMontage)
        iMontage = length(DigitizeOptions.Montages) + 1;
    else
        iMontage = iMontage(1);
        disp('DIGITIZER> Warning: Montage name already exists. Overwriting...');
    end
    % Add new montage to registered montages
    DigitizeOptions.Montages(iMontage) = newMontage;
    DigitizeOptions.iMontage = iMontage;
    % Save options
    bst_set('DigitizeOptions', DigitizeOptions);
    % Reload Menu
    CreateMontageMenu();
    if nargin<1
        % Restart acquisition
        ResetDataCollection();
    else
        % Update List
        UpdateList();
    end
end

%% ===== UNLOAD ALL MONTAGES =====
function UnloadAllMontages()
    % Get Digitize options
    DigitizeOptions = bst_get('DigitizeOptions');
    % Remove all montages
    DigitizeOptions.Montages = [...
        struct('Name',   'No EEG', ...
               'Labels', [], ...
               'ChannelFile', []), ...
        struct('Name',   'Default', ...
               'Labels', [], ...
               'ChannelFile', [])];
    % Reset to "No EEG"
    DigitizeOptions.iMontage = 1;
    % Save Digitize options
    bst_set('DigitizeOptions', DigitizeOptions);
    % Reload menu bar
    CreateMontageMenu();
    % Update List
    UpdateList();
end


%% ===== REMOVE POINTS =====
function RemoveCoordinates(type, iPoint)
% type: CARDINAL, EEG, EXTRA, leave empty to delete all headpoints
% iPoint: the index of the point to delete wthin the group, leave empty to delete the entire group
% TODO remove the points from the coordinate list also
    global GlobalData Digitize    
    
    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = load(ChannelFile);
    if isempty(type)
        % remove all points
        ChannelMat.HeadPoints = [];
        ChannelMat.Channel = [];
        % Save file back
        save(ChannelFile, '-struct', 'ChannelMat');
        % close the figure
        if ishandle(Digitize.hFig)
            %close(Digitize.hFig);
            bst_figures('DeleteFigure', Digitize.hFig, []);
        end
    else
        % find group and remove selected point        
        if isempty(iPoint)
            % create a mask of points to keep that exclude the specified
            % type
            mask = cellfun(@isempty,regexp([ChannelMat.HeadPoints.Type], type));
            ChannelMat.HeadPoints.Loc = ChannelMat.HeadPoints.Loc(:,mask);
            ChannelMat.HeadPoints.Label = ChannelMat.HeadPoints.Label(mask);
            ChannelMat.HeadPoints.Type = ChannelMat.HeadPoints.Type(mask);
            if strcmp(type, 'EEG')
                % remove all EEG channels from channel struct
                ChannelMat.Channel = [];
            end
        else
            % find the point in the type and create a mask of points to keep
            % that excludes the specified point
            if strcmp(type, 'EEG')
                if strcmpi(Digitize.Type, 'Revopoint')
                    % remove only location
                    ChannelMat.Channel(iPoint).Loc = [];
                else
                    % remove specific EEG channel
                    ChannelMat.Channel(iPoint) = [];
                end
            else
                %  all other types
                iType = find(~cellfun(@isempty,regexp([ChannelMat.HeadPoints.Type], type)));
                mask = true(1,size(ChannelMat.HeadPoints.Type,2));
                iDelete = iType(iPoint);
                mask(iDelete) = false;
                ChannelMat.HeadPoints.Loc = ChannelMat.HeadPoints.Loc(:,mask);
                ChannelMat.HeadPoints.Label = ChannelMat.HeadPoints.Label(mask);
                ChannelMat.HeadPoints.Type = ChannelMat.HeadPoints.Type(mask);
            end
            
        end
        % save changes
        save(ChannelFile, '-struct', 'ChannelMat');
        GlobalData.DataSet(Digitize.iDS).HeadPoints  = ChannelMat.HeadPoints;
        GlobalData.DataSet(Digitize.iDS).Channel  = ChannelMat.Channel;
        % Remove old HeadPoints
        hAxes = findobj(Digitize.hFig, '-depth', 1, 'Tag', 'Axes3D');
        hHeadPointsMarkers = findobj(hAxes, 'Tag', 'HeadPointsMarkers');
        hHeadPointsLabels  = findobj(hAxes, 'Tag', 'HeadPointsLabels');
        hHeadPointsFid = findobj(hAxes, 'Tag', 'HeadPointsFid');
        delete(hHeadPointsMarkers);
        delete(hHeadPointsLabels);
        delete(hHeadPointsFid);
        % View headpoints
        figure_3d('ViewHeadPoints', Digitize.hFig, 1);
        
        % manually remove any remaining EEG markers if the channel file is
        % empty.  
        if isempty(ChannelMat.Channel)
            hSensorMarkers = findobj(hAxes, 'Tag', 'SensorsMarkers');
            hSensorLabels  = findobj(hAxes, 'Tag', 'SensorsLabels');
            delete(hSensorMarkers);
            delete(hSensorLabels);
        end
        
        % view EEG sensors
        figure_3d('ViewSensors',Digitize.hFig, 1, 1, 0,'EEG');     
    end
end


%% ========================================================================
%  ======= POLHEMUS COMMUNICATION =========================================
%  ========================================================================

%% ===== CREATE SERIAL COLLECTION =====
function isOk = CreateSerialConnection(h, ev) %#ok<INUSD>
    global Digitize

    isOk = 0;
    while ~isOk
        % Get COM port options
        DigitizeOptions = bst_get('DigitizeOptions');
        % Simulation: exit
        if DigitizeOptions.isSimulate
            isOk = 1;
            return;
        end
        % Check for existing open connection
        s = instrfind('status','open');
        if ~isempty(s)
            fclose(s);
        end
        % Create connection
        SerialConnection = serial(DigitizeOptions.ComPort, 'BaudRate', DigitizeOptions.ComRate);
        if strcmp(DigitizeOptions.UnitType,'patriot')
            SerialConnection.terminator = 'CR';
        end
        % set up the Bytes Available function and open the connection (if needed)
        SerialConnection.BytesAvailableFcnCount = DigitizeOptions.ComByteCount;
        SerialConnection.BytesAvailableFcnMode  = 'byte';
        SerialConnection.BytesAvailableFcn      = @BytesAvailable_Callback;
        if (strcmp(SerialConnection.status,'closed'))
            try
                % Open connection
                fopen(SerialConnection); 
                if strcmp(DigitizeOptions.UnitType,'fastrak')
                    % Set units to centimeters
                    fprintf(SerialConnection,'%s','u');
                    % Force ASCII output format
                    fprintf(SerialConnection,'%s','F');
                elseif strcmp(DigitizeOptions.UnitType,'patriot')
                    % request input from stylus
                    fprintf(SerialConnection,'%s\r','L1,1');
                    % Set units to centimeters
                    fprintf(SerialConnection,'%s\r','U1');
                end
                pause(0.2);
            catch %#ok<CTCH>
                % If the connection cannot be established: error message
                bst_error(['Cannot open serial connection.' 10 10 'Please check the serial port configuration.' 10], 'Digitize', 0);
                % Ask user to edit the port options
                isChanged = EditSettings();
                % If edit was canceled: exit
                if ~isChanged
                    SerialConnection = [];
                    return
                % If not, try again
                else
                    continue;
                end
            end
        end
        % Save the current connection in global variable
        Digitize.SerialConnection = SerialConnection;
        isOk = 1;
    end
end


%% ===== BYTES AVAILABLE CALLBACK =====
function BytesAvailable_Callback(h, ev) %#ok<INUSD>
    global Digitize rawpoints

    % Get controls
    ctrl = bst_get('PanelControls', Digitize.Type);
    % Get digitizer options
    DigitizeOptions = bst_get('DigitizeOptions');

    % Simulate: Generate random points
    if DigitizeOptions.isSimulate
        if strcmpi(Digitize.Type, 'Revopoint')
            % Get current 3D figure
            [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '3D');
            if isempty(hFig)
                return
            end
            % Get current selected point
            CoordinatesSelector = getappdata(hFig, 'CoordinatesSelector');
            isSelectingCoordinates = getappdata(hFig, 'isSelectingCoordinates');
            if isempty(CoordinatesSelector) || isempty(CoordinatesSelector.MRI)
                return;
            else
                if isSelectingCoordinates
                    pointCoord = CoordinatesSelector.SCS;
                else
                    [sSubject, ~] = bst_get('Subject', Digitize.SubjectName);
                    iTargetSurface = find(cellfun(@(c)~isempty(strfind(c, 'revopoint')), {sSubject.Surface.Comment}));
                    [sSurf, ~] = bst_memory('LoadSurface', sSubject.Surface(iTargetSurface(end)).FileName);
                    pointCoord = sSurf.Vertices(randi(length(sSurf.Vertices)), :);
                end
            end
            Digitize.hFig = hFig;
            Digitize.iDS = iDS;
        else
            switch (Digitize.Mode)
                case 1,     pointCoord = [.08 0 -.01];
                case 2,     pointCoord = [-.01 .07 0];
                case 3,     pointCoord = [-.01 -.07 0];
                case 4,     pointCoord = [.08 0 0];
                case 5,     pointCoord = [0  .07 0];
                case 6,     pointCoord = [0 -.07 0];
                otherwise,  pointCoord = rand(1,3) * .15 - .075;
            end
        end
    % Else: Get digitized point coordinates
    else
        vals = zeros(1,6);
        rawpoints = zeros(2,7);
        data = [];
        if Digitize.Mode == 0
            rawpoints = [];
        end
        try
            for j=1:2 % 1 point * 2 receivers
                data = fscanf(Digitize.SerialConnection);
                if strcmp(DigitizeOptions.UnitType, 'fastrak')
                    % This is fastrak
                    % The factory default ASCII output record x-y-z-azimuth-elevation-roll is composed of 
                    % 47 bytes (3 status bytes, 6 data words each 7 bytes long, and a CR LF terminator)
                    vals(1) = str2double(data(1:3)); % header is first three char
                    for v=2:7
                        % next 6 values are each 7 char
                        ind=(v-1)*7;
                        vals(v) = str2double(data((ind-6)+3:ind+3));
                    end
                elseif strcmp(DigitizeOptions.UnitType, 'patriot')
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
        % Motion compensation and conversion to meters
        pointCoord = DoMotionCompensation(rawpoints) ./100; % cm => meters
    end
    % Beep at each click AND not for headshape points
    if DigitizeOptions.isBeep 
        % Beep not working in compiled version, replacing with this:
        if bst_iscompiled() && (Digitize.Mode ~= 8)
            sound(Digitize.BeepWav(6000:2:16000,1), 22000);
        else
            beep on;
            beep();
        end
    end
    % check for change in Mode (click at least 1 meter away from transmitter)
    if any(abs(pointCoord) > 1.5)
        newMode = Digitize.Mode +1;
        SwitchToNewMode(newMode);
        return;
    end
    switch Digitize.Mode
        case 0
            % Waiting for the first mode
            SwitchToNewMode(1);
        
        % === HPI Coils ===
        case 1
            % Center (Nasion) coil
            iPoint = size(Digitize.Points.hpiN,1)+1;
            if ~isempty(Digitize.Points.trans)
                % Transform coordinate
                Digitize.Points.hpiN(iPoint,:) = (Digitize.Points.trans * [pointCoord 1]')';
                PlotCoordinate(Digitize.Points.hpiN(iPoint,:), 'HPI-N', 'HPI', iPoint);
            else
                % used to compute transform
                Digitize.Points.hpiN(iPoint,:) = pointCoord;  
            end
            SwitchToNewMode(2);
        case 2
            % Left coil
            iPoint = size(Digitize.Points.hpiN,1);
            if ~isempty(Digitize.Points.trans)
                % Transform coordinate
                Digitize.Points.hpiL(iPoint,:) = (Digitize.Points.trans * [pointCoord 1]')';
                PlotCoordinate(Digitize.Points.hpiL(iPoint,:), 'HPI-L', 'HPI', iPoint);
            else
                % used to compute transform
                Digitize.Points.hpiL(iPoint,:) = pointCoord;
            end
            SwitchToNewMode(3);
        case 3   
            % Right Coil
            iPoint = size(Digitize.Points.hpiN,1);
            if ~isempty(Digitize.Points.trans)
                % Transform coordinate
                Digitize.Points.hpiR(iPoint,:) = (Digitize.Points.trans * [pointCoord 1]')';
                PlotCoordinate(Digitize.Points.hpiR(iPoint,:), 'HPI-R', 'HPI', iPoint);
            else
                % used to compute transform
                Digitize.Points.hpiR(iPoint,:) = pointCoord;
            end
            % Check for multiple fiducial measurements
            if (size(Digitize.Points.hpiN,1) == DigitizeOptions.nFidSets)
                % Compute SCS transformation
                ComputeTransform();
                % Create the figure
                CreateHeadpointsFigure();
                % Allow points to be removed now that the transformation is complete
                ctrl.jButtonDeletePoint.setEnabled(1);
                SwitchToNewMode(4);
            else
                SwitchToNewMode(1);
            end
            
        % === Anatomical Fiducials ===    
        case 4
            % Nasion
            iPoint = size(Digitize.Points.nasion,1)+1;
            if ~isempty(Digitize.Points.trans)
                % Transform coordinate
                Digitize.Points.nasion(iPoint,:) = (Digitize.Points.trans * [pointCoord 1]')';
                PlotCoordinate(Digitize.Points.nasion(iPoint,:), 'Nasion', 'CARDINAL', iPoint);
            else
                % used to compute transform
                Digitize.Points.nasion(iPoint,:) = pointCoord;
            end
            SwitchToNewMode(5);
        case 5
            % Left coil
            iPoint = size(Digitize.Points.nasion,1);
            if ~isempty(Digitize.Points.trans)
                % Transform coordinate
                Digitize.Points.LPA(iPoint,:) = (Digitize.Points.trans * [pointCoord 1]')';
                PlotCoordinate(Digitize.Points.LPA(iPoint,:), 'LPA', 'CARDINAL', iPoint);
            else
                % used to compute transform
                Digitize.Points.LPA(iPoint,:) = pointCoord;
            end
            SwitchToNewMode(6);
        case 6   
            % Right coil
            iPoint = size(Digitize.Points.nasion,1);
            if ~isempty(Digitize.Points.trans)
                % Transform coordinate
                Digitize.Points.RPA(iPoint,:) = (Digitize.Points.trans * [pointCoord 1]')';
                PlotCoordinate(Digitize.Points.RPA(iPoint,:), 'RPA', 'CARDINAL', iPoint);
            else
                % used to compute transform
                Digitize.Points.RPA(iPoint,:) = pointCoord;
            end
            % Check for multiple fiducial measurements
            if (size(Digitize.Points.nasion,1) == DigitizeOptions.nFidSets)
                % Check for transformation
                if isempty(Digitize.Points.trans)
                    % Compute SCS transformation
                    ComputeTransform();
                    % Create the figure
                    CreateHeadpointsFigure();
                    % Allow points to be removed now that the transformation is complete
                    ctrl.jButtonDeletePoint.setEnabled(1);
                end
                SwitchToNewMode(7);
            else
                SwitchToNewMode(4);
            end

            
        % === EEG ===
        case 7
            % find the index for the current point
            % ADD A CONDITION HERE THAT EDITS EXISTING EEG POINTS
            if Digitize.isEditPts
                [~, iSelCoord] = GetSelectedCoord(); 
                iPoint = iSelCoord - 3;
            else
                % ELSE DOES THE BELOW OF ADDING NEW POINTS
                iPoint = str2double(ctrl.jTextFieldEEG.getText());
            end
            if strcmpi(Digitize.Type, 'Revopoint')
                Digitize.Points.EEG(iPoint,:) = pointCoord;
            else
                % Transform coordinate
                Digitize.Points.EEG(iPoint,:) = (Digitize.Points.trans * [pointCoord 1]')';
            end
            % Add the point to the display
            % Get current montage
            [curMontage, nEEG] = GetCurrentMontage();
            PlotCoordinate(Digitize.Points.EEG(iPoint,:), curMontage.Labels{iPoint}, 'EEG', iPoint)
            
            if Digitize.isEditPts
                Digitize.isEditPts = 0;
            else
                % update text field counter to the next point in the list
                nextPoint = max(size(Digitize.Points.EEG,1)+1, 1);
                if nextPoint > nEEG
                    % all EEG points have been collected, switch to next mode
                    ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(nEEG)));
                    SwitchToNewMode(8);
                else
                    ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(nextPoint)));
                end
            end
        % === EXTRA ===
        case 8
            % find the index for the current point in the headshape points
            iPoint = str2double(ctrl.jTextFieldExtra.getText());
            if strcmpi(Digitize.Type, 'Revopoint')
                Digitize.Points.headshape(iPoint,:) = pointCoord;
            else
                % Transformed points_pen from original points_pen
                Digitize.Points.headshape(iPoint,:) = (Digitize.Points.trans * [pointCoord 1]')';
            end
            % add the point to the display (in cm)
            PlotCoordinate(Digitize.Points.headshape(iPoint,:), 'EXTRA', 'EXTRA', iPoint)
            % update text field counter to the next point in the list
            nextPoint = iPoint+1;
            ctrl.jTextFieldExtra.setText(java.lang.String.valueOf(int16(nextPoint)));
    end
    % Update coordinates list
    UpdateList();
end


%% ===== MOTION COMPENSATION =====
function newPT = DoMotionCompensation(sensors)
    % use sensor one and its orientation vectors as the new coordinate system
    % Define the origin as the position of sensor attached to the glasses.
    WAND = 1;
    REMOTE1 = 2;

    C(1) = sensors(REMOTE1,2);
    C(2) = sensors(REMOTE1,3);
    C(3) = sensors(REMOTE1,4);

    % Deg2Rad = (angle / 180) * pie
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

    % Convert Euler angles to directional cosines
    % using formulae in Polhemus manual.
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

    %Translate and rotate the WAND into new coordinate system
    pt(1) = sensors(WAND,2) - C(1);
    pt(2) = sensors(WAND,3) - C(2);
    pt(3) = sensors(WAND,4) - C(3);

    newPT(1) = pt(1) * rotMat(1, 1) + pt(2) * rotMat(1, 2) + pt(3) * rotMat(1, 3)'+ rotMat(1, 4);
    newPT(2) = pt(1) * rotMat(2, 1) + pt(2) * rotMat(2, 2) + pt(3) * rotMat(2, 3)'+ rotMat(2, 4);
    newPT(3) = pt(1) * rotMat(3, 1) + pt(2) * rotMat(3, 2) + pt(3) * rotMat(3, 3)'+ rotMat(3, 4);
end

%% ========================================================================
%  ======= REVOPOINT AUTOMATION ===========================================
%  ========================================================================

%% ===== FIND ELECTRODES ON THE EEG CAP =====
function [centers_cap, cap_img, head_surface] = findElectrodesEegCap(head_surface)
    % Flatten the 3D mesh to 2D space
    [head_surface.u, head_surface.v] = bst_project_2d(head_surface.Vertices(:,1), head_surface.Vertices(:,2), head_surface.Vertices(:,3), '2dcap');
    
    % perform image processing to detect the electrode locations
    grayness = head_surface.Color*[1;1;1]/sqrt(3);
    ll=linspace(-1,1,512);
    [X,Y]=meshgrid(ll,ll);
    vc_sq = 0*X;
    vc_sq(:) = griddata(head_surface.u(1:end),head_surface.v(1:end),grayness,X(:),Y(:),'linear');

    [curMontage, nEEG] = GetCurrentMontage();
    if ~isempty(regexp(curMontage.Name, 'ActiCap', 'match'))
        vc_sq = imcomplement(vc_sq);
    end

    % toggle comment depending on cap
    if ~isempty(regexp(curMontage.Name, 'ActiCap', 'match'))
        [centers, radii, metric] = imfindcircles(vc_sq,[6 55]); % 66 easycap
    elseif ~isempty(regexp(curMontage.Name, 'Waveguard', 'match'))
        [centers, radii, metric] = imfindcircles(vc_sq,[1 25]); % 65 ANT waveguard
    else % NEED TO WORK ON THIS
        bst_error('EEG cap not supported', 'Revopoint', 0);
        return;
    end

    centers_cap = centers; 
    cap_img = vc_sq;
end

%% ===== WARP ELECTRODE LOCATIONS FROM EEG CAP MANUFACTURER LAYOUT AVAILABLE IN BRAINSTORM TO THE MESH =====
function capPoints3d = warpLayout2Mesh(centerscap, ChannelRef, cap_img, head_surface, EegPoints) 
    % hyperparameters for warping and interpolation
    NIT=1000;
    lambda = 100000;
    
    % Grt current montage
    [curMontage, nEEG] = GetCurrentMontage();

    % convert EEG cap manufacturer layout from 3D to 2D 
    X1 = [];
    Y1 = [];
    for i=1:nEEG
        [X,Y] = bst_project_2d(ChannelRef(i).Loc(1,:), ChannelRef(i).Loc(2,:), ChannelRef(i).Loc(3,:), '2dcap');
        X1 = [X1 X];
        Y1 = [Y1 Y];
    end
    centerssketch_temp = [X1' Y1'];
    centerssketch = [];

    %% sort as per the initialization points per EEG Cap 
    % order for 65: Oz, T8, Fpz, T7 (custom cap)
    if ~isempty(regexp(curMontage.Name, 'Waveguard', 'match')) && nEEG==65
        centerssketch = [centerssketch; centerssketch_temp(find(cellfun(@(c)strcmpi(c, 'Oz'), {ChannelRef.Name})),:)];
        centerssketch = [centerssketch; centerssketch_temp(find(cellfun(@(c)strcmpi(c, 'T8'), {ChannelRef.Name})),:)];
        centerssketch = [centerssketch; centerssketch_temp(find(cellfun(@(c)strcmpi(c, 'Fpz'), {ChannelRef.Name})),:)];
        centerssketch = [centerssketch; centerssketch_temp(find(cellfun(@(c)strcmpi(c, 'T7'), {ChannelRef.Name})),:)];

        for i=1:nEEG
            if ~strcmpi(ChannelRef(i).Name, 'Oz') &&...
               ~strcmpi(ChannelRef(i).Name, 'T8') &&...
               ~strcmpi(ChannelRef(i).Name, 'Fpz') &&...
               ~strcmpi(ChannelRef(i).Name, 'T7')
                centerssketch = [centerssketch; centerssketch_temp(i, :)];
            end
        end

    % order for ActiCap 66: Oz, T8, Fpz, T7 (custom cap)
    elseif ~isempty(regexp(curMontage.Name, 'ActiCap', 'match')) && nEEG==66
        centerssketch = [centerssketch; centerssketch_temp(find(cellfun(@(c)strcmpi(c, 'Oz'), {ChannelRef.Name})),:)];
        centerssketch = [centerssketch; centerssketch_temp(find(cellfun(@(c)strcmpi(c, 'T8'), {ChannelRef.Name})),:)];
        centerssketch = [centerssketch; centerssketch_temp(find(cellfun(@(c)strcmpi(c, 'GND'), {ChannelRef.Name})),:)];
        centerssketch = [centerssketch; centerssketch_temp(find(cellfun(@(c)strcmpi(c, 'T7'), {ChannelRef.Name})),:)];

        for i=1:nEEG
            if ~strcmpi(ChannelRef(i).Name, 'Oz') &&...
               ~strcmpi(ChannelRef(i).Name, 'T8') &&...
               ~strcmpi(ChannelRef(i).Name, 'GND') &&...
               ~strcmpi(ChannelRef(i).Name, 'T7')
                centerssketch = [centerssketch; centerssketch_temp(i, :)];
            end
        end
    
    % any other cap (NEED TO WORK ON THIS)
    else
        bst_error('EEG cap not supported', 'Revopoint', 0);
        return;
    end
    
    %% warping EEG cap layout electrodes to mesh 
    % for Waveguard 65
    if ~isempty(regexp(curMontage.Name, 'Waveguard', 'match')) && nEEG==65
        Oz = centerssketch(1,:);
        T8 = centerssketch(2,:);
        Fpz = centerssketch(3,:);
        T7 = centerssketch(4,:);
        sketch_pts = [Oz;T8;Fpz;T7];
    
        for i=1:4
            DeletePoint_Callback();
        end
    
        [Ozx, Ozy] = bst_project_2d(EegPoints(1,1), EegPoints(1,2), EegPoints(1,3), '2dcap');
        [T8x, T8y] = bst_project_2d(EegPoints(2,1), EegPoints(2,2), EegPoints(2,3), '2dcap');
        [Fpzx, Fpzy] = bst_project_2d(EegPoints(3,1), EegPoints(3,2), EegPoints(3,3), '2dcap');
        [T7x, T7y] = bst_project_2d(EegPoints(4,1), EegPoints(4,2), EegPoints(4,3), '2dcap');
        cap_pts = ([Ozx,Ozy;T8x,T8y;Fpzx,Fpzy;T7x,T7y]+1)*256;

    % for ActiCap 66
    elseif ~isempty(regexp(curMontage.Name, 'ActiCap', 'match')) && nEEG==66
        Oz = centerssketch(1,:);
        T8 = centerssketch(2,:);
        GND = centerssketch(3,:);
        T7 = centerssketch(4,:);
        sketch_pts = [Oz;T8;GND;T7];
    
        for i=1:4
            DeletePoint_Callback();
        end
    
        [Ozx, Ozy] = bst_project_2d(EegPoints(1,1), EegPoints(1,2), EegPoints(1,3), '2dcap');
        [T8x, T8y] = bst_project_2d(EegPoints(2,1), EegPoints(2,2), EegPoints(2,3), '2dcap');
        [GNDx, GNDy] = bst_project_2d(EegPoints(3,1), EegPoints(3,2), EegPoints(3,3), '2dcap');
        [T7x, T7y] = bst_project_2d(EegPoints(4,1), EegPoints(4,2), EegPoints(4,3), '2dcap');
        cap_pts = ([Ozx,Ozy;T8x,T8y;GNDx,GNDy;T7x,T7y]+1)*256;
    end
    
    %% Do the warping and interpolation
    warp = tpsGetWarp(10, sketch_pts(:,1)', sketch_pts(:,2)', cap_pts(:,1)', cap_pts(:,2)' );
    [xsR,ysR] = tpsInterpolate(warp, centerssketch(:,1)', centerssketch(:,2)', 0);
    centerssketch(:,1) = xsR;
    centerssketch(:,2) = ysR;
    centerssketch = max(min(centerssketch,512-15),15);
    
    for kk=1:NIT
        fprintf('.');
        %tic
        k=dsearchn(centerssketch,centerscap);
    
        %k is an index into sketch pts
        [vec_atlas_pts,ind]=unique(k);
    
        vec_atlas2sub=centerscap(ind,:)-centerssketch(vec_atlas_pts,:);
        dist = sqrt(vec_atlas2sub(:,1).^2+vec_atlas2sub(:,2).^2);
    
        [dist2,isoutlier]=rmoutliers(dist);
        ind(isoutlier) = [];
        vec_atlas_pts(isoutlier) = [];
    
        [warp,L,LnInv,bendE] = tpsGetWarp(lambda, centerssketch(vec_atlas_pts,1)', centerssketch(vec_atlas_pts,2)', centerscap(ind,1)', centerscap(ind,2)' );
    
        [xsR,ysR] = tpsInterpolate( warp, centerssketch(:,1)', centerssketch(:,2)', 0);
    
        if kk<NIT/2
            centerssketch(:,1) = 0.9*centerssketch(:,1) + 0.1*xsR;
            centerssketch(:,2) = 0.9*centerssketch(:,2) + 0.1*ysR;
        else
            centerssketch(:,1) = xsR;
            centerssketch(:,2) = ysR;
        end

        centerssketch = max(min(centerssketch,512-15),15);
    end

    NPTS = length(cap_img);
    ll=linspace(-1,1,NPTS);
    [X1,Y1]=meshgrid(ll,ll);
    
    u_sketch = interp2(X1,xsR,ysR);
    v_sketch = interp2(Y1,xsR,ysR);
    
    u_cap=head_surface.u;
    v_cap=head_surface.v;
    
    % get the desired electrodes on the 3D EEG cap 
    capPoints3d(:,1)=griddata(u_cap,v_cap,head_surface.Vertices(:,1),u_sketch,v_sketch);
    capPoints3d(:,2)=griddata(u_cap,v_cap,head_surface.Vertices(:,2),u_sketch,v_sketch);
    capPoints3d(:,3)=griddata(u_cap,v_cap,head_surface.Vertices(:,3),u_sketch,v_sketch);
end