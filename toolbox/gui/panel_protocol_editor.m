function varargout = panel_protocol_editor(varargin)
% PANEL_PROTOCOL_EDITOR: Protocol editor (GUI).
%
% USAGE:  bstPanelNew = panel_protocol_editor('CreatePanel', 'edit')
%         bstPanelNew = panel_protocol_editor('CreatePanel', 'load')
%         bstPanelNew = panel_protocol_editor('CreatePanel', 'create')

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
% Authors: Francois Tadel, 2008-2017

eval(macro_method);
end


%% ===== CREATE PANEL =====
% Usage : bstPanelNew = CreatePanel('edit')
%         bstPanelNew = CreatePanel('create')
%         bstPanelNew = CreatePanel('load')
function bstPanelNew = CreatePanel(action) %#ok<DEFNU>
    panelName = 'panel_protocol_editor';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    
    % Create tool panel
    jPanelNew = gui_river();
    ctrl = struct();
    
    % ===== Panel Protocol definition =====
    jPanelBase = gui_river([4,4], [1,4,8,4], 'Protocol definition');
    colorDisable = Color(.6,.6,.6);
    % Protocol name
    gui_component('label', jPanelBase, '', 'Protocol name :');
    ctrl.jTextProtocolName = JTextField('');
    ctrl.jTextProtocolName.setFont(bst_get('Font'));
    if ~strcmpi(action, 'load')
        java_setcb(ctrl.jTextProtocolName, 'KeyTypedCallback', @ProtocolNameChanged_Callback);
    end
    jPanelBase.add('tab hfill', ctrl.jTextProtocolName);
    ctrl.jTextProtocolName.setPreferredSize(java_scaled('dimension', 280,22));
    % PROTOCOL select dir button
    if strcmpi(action, 'load')
        ctrl.jButtonSelectProtocol = gui_component('button', jPanelBase, '', '...', [], [], @ButtonProtocolCallback);
    end
    
    % SUBJECTS path text field
    jLabelAnatomy = gui_component('label', jPanelBase, 'p', 'Anatomy path :');
    jLabelAnatomy.setForeground(colorDisable);
    ctrl.jTextSubjectsPath = JTextField('');
    ctrl.jTextSubjectsPath.setFont(bst_get('Font'));
    ctrl.jTextSubjectsPath.setForeground(colorDisable);
    jPanelBase.add('tab hfill', ctrl.jTextSubjectsPath);
    % SUBJECTS select dir button
    ctrl.jButtonSelectSubjPath = gui_component('button', jPanelBase, '', '...', [], [], @ButtonSubjectsDirCallback);
    ctrl.jButtonSelectSubjPath.setForeground(colorDisable);
    
    % Datasets path text field
    jLabelData = gui_component('label', jPanelBase, 'p', 'Datasets path :');
    jLabelData.setForeground(colorDisable);
    ctrl.jTextStudiesPath = JTextField('');
    ctrl.jTextStudiesPath.setFont(bst_get('Font'));
    ctrl.jTextStudiesPath.setForeground(colorDisable);
    jPanelBase.add('tab hfill', ctrl.jTextStudiesPath);
    % SUBJECTS select dir button
    ctrl.jButtonSelectStudiesPath = gui_component('button', jPanelBase, '', '...', [], [], @ButtonStudiesDirCallback);
    ctrl.jButtonSelectStudiesPath.setForeground(colorDisable);
    
    % Add Base panel 
    jPanelNew.add('hfill', jPanelBase);
    
    % ===== SUBJECTS DEFAULTS =====
    if strcmpi(action, 'create') || strcmpi(action, 'edit')
        jPanelDefaults = gui_river([1,4], [1,4,8,4], 'Default properties for the subjects');
        % === DEFAULT ANATOMY ===
        gui_component('label', jPanelDefaults, 'br', '<HTML><B>Default anatomy</B>: ');
        jButtonGroupAnatomy = ButtonGroup();
        gui_component('label', jPanelDefaults, 'br', '     ');
        ctrl.jRadioAnatomyIndividual = gui_component('radio', jPanelDefaults, 'tab', 'No, use individual anatomy');
        ctrl.jRadioAnatomyDefault    = gui_component('radio', jPanelDefaults, 'br tab', 'Yes, use protocol''s default anatomy');
        ctrl.jRadioAnatomyIndividual.setToolTipText('<HTML><BLOCKQUOTE><B>UseDefaultAnat=0</B><BR><BR> MRI and surfaces for this subject are saved in: <P>[ protocol/anat/<I>subject_dir</I> ]<BR><BR></BLOCKQUOTE></HTML>');
        ctrl.jRadioAnatomyDefault.setToolTipText(['<HTML><BLOCKQUOTE><B>UseDefaultAnat=1</B><BR><BR> MRI and surfaces for this subject are saved in: <P>[ protocol/anat/' bst_get('DirDefaultSubject') ' ]<BR><BR></BLOCKQUOTE></HTML>']);
        jButtonGroupAnatomy.add(ctrl.jRadioAnatomyIndividual);
        jButtonGroupAnatomy.add(ctrl.jRadioAnatomyDefault);
        % By default : Individual anatomy
        ctrl.jRadioAnatomyIndividual.setSelected(1);

        % === DEFAULT CHANNEL FILE ===
        gui_component('label', jPanelDefaults, 'p', '<HTML><B>Default channel file</B>: &nbsp;&nbsp;&nbsp;&nbsp;<FONT color=#7F7F7F><I>(includes the SSP/ICA projectors)</I></FONT>');
        jButtonGroupChannel = ButtonGroup();
        ctrl.jRadioChannelIndividual     = gui_component('radio', jPanelDefaults, 'br tab vtop', 'No, use one channel file per acquisition run (MEG/EEG)');
        ctrl.jRadioChannelDefaultSubject = gui_component('radio', jPanelDefaults, 'br tab', 'Yes, use one channel file per subject  (one run per subject)');
        ctrl.jRadioChannelDefaultGlobal  = gui_component('radio', jPanelDefaults, 'br tab', 'Yes, use only one global channel file');
        ctrl.jRadioChannelIndividual.setToolTipText(     '<HTML><BLOCKQUOTE><B>UseDefaultChannel=0</B><BR><BR> Sensors locations and headmodel files for this subject are saved in: <P>[ protocol/data/<I>subject_dir</I>/<I>condition_name</I> ]<BR><BR></BLOCKQUOTE></HTML>');
        ctrl.jRadioChannelDefaultSubject.setToolTipText(['<HTML><BLOCKQUOTE><B>UseDefaultChannel=1</B><BR><BR> Sensors locations and headmodel files for this subject are saved in: <P>[ protocol/data/<I>subject_dir</I>/' bst_get('DirDefaultStudy') ' ]<BR><BR></BLOCKQUOTE></HTML>']);
        ctrl.jRadioChannelDefaultGlobal.setToolTipText( ['<HTML><BLOCKQUOTE><B>UseDefaultChannel=2</B><BR><BR> Sensors locations and headmodel files for this subject are saved in: <P>[ protocol/data/' bst_get('DirDefaultStudy') ' ]<BR><BR></BLOCKQUOTE></HTML>']);
        jButtonGroupChannel.add(ctrl.jRadioChannelIndividual);
        jButtonGroupChannel.add(ctrl.jRadioChannelDefaultSubject);
        jButtonGroupChannel.add(ctrl.jRadioChannelDefaultGlobal);
        gui_component('label', jPanelDefaults, 'br', '');
        
        % By default : Individual channel file
        ctrl.jRadioChannelIndividual.setSelected(1);
        % Try to prevent people to share channel files between protocol
        ctrl.jRadioChannelDefaultSubject.setForeground(Color(.5,.5,.5));
        ctrl.jRadioChannelDefaultGlobal.setForeground(Color(.5,.5,.5));
        java_setcb(ctrl.jRadioChannelDefaultSubject, 'ActionPerformedCallback', @SharedWarning);
        java_setcb(ctrl.jRadioChannelDefaultGlobal, 'ActionPerformedCallback', @GlobalWarning);

        jPanelNew.add('p hfill', jPanelDefaults);
    end
    
    % ===== Validation buttons =====
    jPanelNew.add('p right', JLabel(''));
    % Help button
    if ismember(action, {'create', 'edit'})
        jButtonHelp = gui_component('button', jPanelNew, '', 'Help', [], [], @(h,ev)bst_help('ProtocolEditor.html'));
        jButtonHelp.setForeground(Color(.7, 0, 0));
    end
    % Cancel button
    ctrl.jButtonCancel = gui_component('button', jPanelNew, '', 'Cancel', [], [], @ButtonCancelCallback);
    % Save button
    switch (action)
        case 'create', strSave = 'Create';
        case 'edit',   strSave = 'Save';
        case 'load',   strSave = 'Load';
    end
    ctrl.jButtonSave = gui_component('button', jPanelNew, '', strSave);

    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           ctrl);

%% =================================================================================
%  === LOCAL CALLBACKS  ============================================================
%  =================================================================================
    % PROTOCOL '...' button
    function ButtonProtocolCallback(varargin)
        % Get the input protocol name
        protocolTextField = char(ctrl.jTextProtocolName.getText());
        % Default protocol dir
        protocolDir = bst_fullfile(bst_get('BrainstormDbDir'), protocolTextField);
        if ~isdir(protocolDir)
            protocolDir = bst_get('BrainstormDbDir');
        end
        % Select protocol folder
        [subjectDir, studyDir, protocolName] = SelectProtocolDir(protocolDir);
        % Update text fields
        ctrl.jTextProtocolName.setText(protocolName);
        ctrl.jTextSubjectsPath.setText(subjectDir);
        ctrl.jTextStudiesPath.setText(studyDir);
        % Warning if SUBJECTS=STUDIES
        if ~isempty(subjectDir) && file_compare(subjectDir, studyDir)
            bst_error(['This protocol is corrupted.' 10 10 ...
                       'The detected anatomy and datasets folders are the same.' 10 ...
                       'There is probably an error in the structure of this database.' 10 10 ...
                       'You should try to fix this problem before loading this protocol:' 10 ...
                       'loading it could damage your protocol more than it is now.'], 'Protocol error', 0);
        end
    end

    % SUBJECTS '...' button
    function ButtonSubjectsDirCallback(varargin)
        % Warning
        if ~java_dialog('confirm', ['Warning: This folder is an element of the Brainstorm database and should not contain' 10 ...
                'any of your own data. Using an inappropriate folder may result in data loss.' 10 ...
                'Do not try to modify it unless you know exactly what you are doing.' 10 10 ...
                'To save your new protocol in a different Brainstorm database folder, use the menu' 10 ...
                '"File > Load protocol > Change database folder" first, then create the protocol.' 10 10 ...
                'Do you really want to modify the protocol path?'], 'Edit protocol path')
            return;
        end
        % Get the input subjects path
        subjectsTextField = getFirstExistingParent(char(ctrl.jTextSubjectsPath.getText()));
        % Open 'Select directory' dialog
        subjectsDir = uigetdir(subjectsTextField, 'Select anatomy directory.');
        % If no directory was selected : return without doing anything
        if (isempty(subjectsDir) || (subjectsDir(1) == 0))
            return
        end
        % Else : update control text
        ctrl.jTextSubjectsPath.setText(subjectsDir);
    end

    % STUDIES '...' button
    function ButtonStudiesDirCallback(varargin)
        % Get the input studies path
        studiesTextField = getFirstExistingParent(char(ctrl.jTextStudiesPath.getText()));
        % Open 'Select directory' dialog
        studiesDir = uigetdir(studiesTextField, 'Select datasets directory.');
        % If no directory was selected : return without doing anything
        if (isempty(studiesDir) || (studiesDir(1) == 0))
            return
        end
        % Else : update control text
        ctrl.jTextStudiesPath.setText(studiesDir);
    end

    % CANCEL button
    function ButtonCancelCallback(varargin)
        gui_hide(panelName);
    end

    % PROTOCOL NAME CHANGED
    function ProtocolNameChanged_Callback(varargin)
        % Get protocol name
        ProtocolName = file_standardize(char(ctrl.jTextProtocolName.getText()));
        % Fix the protocol name for weird characters
        if ~strcmp(char(ctrl.jTextProtocolName.getText()), ProtocolName)
            ctrl.jTextProtocolName.setText(ProtocolName);
            ctrl.jTextProtocolName.setCaretPosition(length(ProtocolName));
        end
        % Update the folders
        if ctrl.jTextSubjectsPath.isEditable()
            % Default directory for protocol
            BrainstormDbDir = bst_get('BrainstormDbDir');
            if isempty(BrainstormDbDir)
                return;
            end
            % Get anatomy and data subdirs
            [tmp__, AnatSubdir] = bst_fileparts(char(ctrl.jTextSubjectsPath.getText()));
            [tmp__, DataSubdir] = bst_fileparts(char(ctrl.jTextStudiesPath.getText()));
            % Update path text fields
            ctrl.jTextSubjectsPath.setText(bst_fullfile(BrainstormDbDir, ProtocolName, AnatSubdir));
            ctrl.jTextStudiesPath.setText( bst_fullfile(BrainstormDbDir, ProtocolName, DataSubdir));
        end
    end

    % WARNING FOR SHARED CHANNEL FILE
    function SharedWarning(varargin)
        % Display warning
        res = java_dialog('question', ['We do not recommend using this option anymore.' 10 10 ...
                                       'Sharing the same electrodes cap for multiple continuous files may lead to errors.' 10 ...
                                       'The channel file contains the linear operators (SSP, ICA, re-referencing operator)' 10 ...
                                       'applied dynamically to the continuous files, which means that applying a spatial filter' 10 ...
                                       'to one file applies it to all the files in the subject. This constraint is often' 10 ...
                                       'misunderstood and leads to errors in the manipulation of the files.' 10  ...
                                       'Use this option only if you clearly understand the meaning of this warning.' 10 10 ...
                                       'Are you sure you want to select this option ?' 10 10], 'Warning', [], {'Confirm', 'Cancel'}, 'Cancel');
        % Select the default option "Use one channel file per subject"
        if (isempty(res) || ~strcmpi(res, 'Confirm'))
            ctrl.jRadioChannelIndividual.setSelected(1);
        end
    end

    % WARNING FOR GLOBAL CHANNEL FILE
    function GlobalWarning(varargin)
        % Display warning
        res = java_dialog('question', ['Warning: We do not recommend this option.' 10 10 ...
                                       'Sharing the same electrodes cap for all the subjects is fast but can be inaccurate.' 10 ...
                                       'If you do so, you also have to share several other files: ' 10 ...
                                       'the headmodel, the noise covariance, and the inverse solution.' 10 10 ...
                                       'The problem is that the noise covariance matrix depends on the quality of the' 10 ...
                                       'EEG recordings, which is usually very different from a subject to another.' 10 ...
                                       'Practically, it is impossible to get the same impedences for all the subjects.' 10 10 ...
                                       'To set the channel file and compute the headmodels for all the subjects at once:' 10 ...
                                       'right-click on the protocol node instead of each subject individually.' 10 10 ...
                                       'Are you sure you want to select this option ?' 10 10], 'Warning', [], {'Confirm', 'Cancel'}, 'Cancel');
        % Select the default option "Use one channel file per subject"
        if (isempty(res) || ~strcmpi(res, 'Confirm'))
            ctrl.jRadioChannelIndividual.setSelected(1);
        end
    end
end


%% ===== SELECT PROTOCOL FOLDER =====
% USAGE:  [subjectDir, studyDir, protocolName] = panel_protocol_editor('SelectProtocolDir', protocolDir)
%         [subjectDir, studyDir, protocolName] = panel_protocol_editor('SelectProtocolDir')
function [subjectDir, studyDir, protocolName] = SelectProtocolDir(protocolDir)
    % Parse inputs
    if (nargin < 1) || isempty(protocolDir)
        protocolDir = bst_get('BrainstormDbDir');
    end
    % Initialize returned values
    subjectDir = [];
    studyDir   = [];
    protocolName = [];
    % Select folder
    protocolDir = java_getfile('open', 'Load protocol...', protocolDir, 'single', 'dirs', ...
                               {{'*'}, 'Brainstorm protocol (folder)', 'protocol'}, 1);
    % Show again main frame
    jBstFrame = bst_get('BstFrame');
    jBstFrame.show();
    % Check for valid input
    if ~ischar(protocolDir) || isempty(protocolDir)
        return
    end

    % Check if 'anat' or 'data' dirs were seletect
    % Windows users loading Protocols from a symbolic link need to select any of these subfolders
    [dirProtocolDir, protocolName] = bst_fileparts(protocolDir, 1);
    if ismember(protocolName, {'data', 'anat'})
        protocolDir = dirProtocolDir;
    end
    % Look for a "brainstormsubject" file and a "brainstormstudy" file
    subjectFile = file_find(protocolDir, 'brainstormsubject*.mat', 3);
    studyFile   = file_find(protocolDir, 'brainstormstudy*.mat',   4);
    % If not both files are found, exit
    if isempty(subjectFile) || isempty(studyFile)
        java_dialog('msgbox', ['Selected directory is not a valid protocol directory.' 10 10 ...
                               'A protocol directory must contain at least two subdirectories: ' 10 ...
                               'one for the subjects'' anatomies, and one for the recordings/results.'], ...
                               'Load protocol');
        return
    end
    % Extract first level of subdir
    subjectDirList = str_split(strrep(subjectFile, protocolDir, ''));
    studyDirList   = str_split(strrep(studyFile, protocolDir, ''));
    subjectDir = bst_fullfile(protocolDir, subjectDirList{1});
    studyDir   = bst_fullfile(protocolDir, studyDirList{1});
    % Get protocol name
    [tmp__, protocolName] = bst_fileparts(protocolDir, 1);
end


%% ===== GET FIRST EXISTING PARENT DIR ======
function existDir = getFirstExistingParent(testDir)
    % If existing dir, or empty: return it
    if isempty(testDir) || file_exist(testDir)
        existDir = testDir;
    % Else: recursive call on parent
    elseif strcmpi(bst_fileparts(testDir, 1), testDir)
        existDir = '';
    else
        existDir = getFirstExistingParent(bst_fileparts(testDir, 1));
    end
end



