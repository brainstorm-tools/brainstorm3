function varargout = panel_protocol_editor(varargin)
% PANEL_PROTOCOL_EDITOR: Protocol editor (GUI).
%
% USAGE:  bstPanelNew = panel_protocol_editor('CreatePanel', 'edit')
%         bstPanelNew = panel_protocol_editor('CreatePanel', 'load')
%         bstPanelNew = panel_protocol_editor('CreatePanel', 'create')

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2012

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
    % Protocol name
    jPanelBase.add(JLabel('Protocol name :'));
    ctrl.jTextProtocolName = JTextField('');
    if ~strcmpi(action, 'load')
        java_setcb(ctrl.jTextProtocolName, 'KeyTypedCallback', @ProtocolNameChanged_Callback);
    end
    jPanelBase.add('tab hfill', ctrl.jTextProtocolName);
    ctrl.jTextProtocolName.setPreferredSize(Dimension(280,22));
    % PROTOCOL select dir button
    if strcmpi(action, 'load')
        ctrl.jButtonSelectProtocol = JButton('...');
        java_setcb(ctrl.jButtonSelectProtocol, 'ActionPerformedCallback', @ButtonProtocolCallback);
        jPanelBase.add(ctrl.jButtonSelectProtocol);
    end
    
    % SUBJECTS path text field
    jPanelBase.add('p', JLabel('Anatomy path :'));
    ctrl.jTextSubjectsPath = JTextField('');
    jPanelBase.add('tab hfill', ctrl.jTextSubjectsPath);
    % SUBJECTS select dir button
    ctrl.jButtonSelectSubjPath = JButton('...');
    java_setcb(ctrl.jButtonSelectSubjPath, 'ActionPerformedCallback', @ButtonSubjectsDirCallback);
    jPanelBase.add(ctrl.jButtonSelectSubjPath);

    % Datasets path text field
    jPanelBase.add('p', JLabel('Datasets path :'));
    ctrl.jTextStudiesPath = JTextField('');
    jPanelBase.add('tab hfill', ctrl.jTextStudiesPath);
    % SUBJECTS select dir button
    ctrl.jButtonSelectStudiesPath = JButton('...');
    java_setcb(ctrl.jButtonSelectStudiesPath, 'ActionPerformedCallback', @ButtonStudiesDirCallback);
    jPanelBase.add(ctrl.jButtonSelectStudiesPath);

    % Add Base panel 
    jPanelNew.add('hfill', jPanelBase);
    
    % ===== SUBJECTS DEFAULTS =====
    if strcmpi(action, 'create') || strcmpi(action, 'edit')
        jPanelDefaults = gui_river([1,4], [1,4,8,4], 'Default properties for the subjects');
        % === DEFAULT ANATOMY ===
        jPanelDefaults.add('br', JLabel('<HTML><B>Default anatomy</B>: '));
        jButtonGroupAnatomy = ButtonGroup();
        ctrl.jRadioAnatomyIndividual = JRadioButton('No, use individual anatomy');
        ctrl.jRadioAnatomyDefault    = JRadioButton('Yes, use protocol''s default anatomy');
        ctrl.jRadioAnatomyIndividual.setToolTipText('<HTML><BLOCKQUOTE><B>UseDefaultAnat=0</B><BR><BR> MRI and surfaces for this subject are saved in: <P>[ protocol/anat/<I>subject_dir</I> ]<BR><BR></BLOCKQUOTE></HTML>');
        ctrl.jRadioAnatomyDefault.setToolTipText(['<HTML><BLOCKQUOTE><B>UseDefaultAnat=1</B><BR><BR> MRI and surfaces for this subject are saved in: <P>[ protocol/anat/' bst_get('DirDefaultSubject') ' ]<BR><BR></BLOCKQUOTE></HTML>']);
        jButtonGroupAnatomy.add(ctrl.jRadioAnatomyIndividual);
        jButtonGroupAnatomy.add(ctrl.jRadioAnatomyDefault);
        jPanelDefaults.add('br', JLabel('     '));
        jPanelDefaults.add('tab', ctrl.jRadioAnatomyIndividual);
        jPanelDefaults.add('br tab', ctrl.jRadioAnatomyDefault);
        % By default : Individual anatomy
        ctrl.jRadioAnatomyIndividual.setSelected(1);

        % === DEFAULT CHANNEL FILE ===
        jPanelDefaults.add('p', JLabel('<HTML><B>Default channel file</B>: &nbsp;&nbsp;&nbsp;&nbsp;<FONT color=#7F7F7F><I>(includes the SSP/ICA projectors)</I></FONT>'));
        jButtonGroupChannel = ButtonGroup();
        ctrl.jRadioChannelIndividual     = JRadioButton('No, use one channel file per acquisition run (MEG/EEG)');
        ctrl.jRadioChannelDefaultSubject = JRadioButton('Yes, use one channel file per subject  (one run per subject)');
        ctrl.jRadioChannelDefaultGlobal  = JRadioButton('Yes, use only one global channel file');
        ctrl.jRadioChannelIndividual.setToolTipText(     '<HTML><BLOCKQUOTE><B>UseDefaultChannel=0</B><BR><BR> Sensors locations and headmodel files for this subject are saved in: <P>[ protocol/data/<I>subject_dir</I>/<I>condition_name</I> ]<BR><BR></BLOCKQUOTE></HTML>');
        ctrl.jRadioChannelDefaultSubject.setToolTipText(['<HTML><BLOCKQUOTE><B>UseDefaultChannel=1</B><BR><BR> Sensors locations and headmodel files for this subject are saved in: <P>[ protocol/data/<I>subject_dir</I>/' bst_get('DirDefaultStudy') ' ]<BR><BR></BLOCKQUOTE></HTML>']);
        ctrl.jRadioChannelDefaultGlobal.setToolTipText( ['<HTML><BLOCKQUOTE><B>UseDefaultChannel=2</B><BR><BR> Sensors locations and headmodel files for this subject are saved in: <P>[ protocol/data/' bst_get('DirDefaultStudy') ' ]<BR><BR></BLOCKQUOTE></HTML>']);
        jButtonGroupChannel.add(ctrl.jRadioChannelIndividual);
        jButtonGroupChannel.add(ctrl.jRadioChannelDefaultSubject);
        jButtonGroupChannel.add(ctrl.jRadioChannelDefaultGlobal);       
        jPanelDefaults.add('br tab vtop', ctrl.jRadioChannelIndividual);
        jPanelDefaults.add('br tab', ctrl.jRadioChannelDefaultSubject);
        jPanelDefaults.add('br tab', ctrl.jRadioChannelDefaultGlobal);
        jPanelDefaults.add('br', JLabel());
        
        % By default : Individual channel file
        ctrl.jRadioChannelIndividual.setSelected(1);
        % Try to prevent people to share channel files between protocol
        ctrl.jRadioChannelDefaultGlobal.setForeground(Color(.5,.5,.5));
        java_setcb(ctrl.jRadioChannelDefaultGlobal, 'ActionPerformedCallback', @GlobalWarning);

        jPanelNew.add('p hfill', jPanelDefaults);
    end
    
    % ===== Validation buttons =====
    jPanelNew.add('p right', JLabel(''));
    % Help button
    if ismember(action, {'create', 'edit'})
        jButtonHelp = JButton('Help');
        jButtonHelp.setForeground(Color(.7, 0, 0));
        java_setcb(jButtonHelp, 'ActionPerformedCallback', @(h,ev)bst_help('ProtocolEditor.html'));
        jPanelNew.add(jButtonHelp);
    end
    % Cancel button
    ctrl.jButtonCancel = JButton('Cancel');
    java_setcb(ctrl.jButtonCancel, 'ActionPerformedCallback', @ButtonCancelCallback);
    jPanelNew.add(ctrl.jButtonCancel);
    % Save button
    switch (action)
        case 'create'
            ctrl.jButtonSave = JButton('Create');
            jPanelNew.add(ctrl.jButtonSave);
        case 'edit'
            ctrl.jButtonSave = JButton('Save');
            jPanelNew.add(ctrl.jButtonSave);
        case 'load'
            ctrl.jButtonSave = JButton('Load');
            jPanelNew.add(ctrl.jButtonSave);
    end

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
                                       'Most users will click on "Cancel", and then select "Use one channel file per subject".' 10 ...
                                       'To set the channel file and compute the headmodels for all the subjects at once:' 10 ...
                                       'right-click on the protocol node instead of each subject individually.' 10 10 ...
                                       'Are you sure you want to select this option ?' 10 10], 'Warning', [], {'Confirm', 'Cancel'}, 'Cancel');
        % Select the default option "Use one channel file per subject"
        if (isempty(res) || ~strcmpi(res, 'Confirm'))
            ctrl.jRadioChannelDefaultSubject.setSelected(1);
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
    protocolDir = java_getfile('open', 'Load protocol...', bst_fileparts(protocolDir, 1), 'single', 'dirs', ...
                               {{'*'}, 'Brainstorm protocol (folder)', 'protocol'}, 1);
    % Show again main frame
    jBstFrame = bst_get('BstFrame');
    jBstFrame.show();
    % Check for valid input
    if ~ischar(protocolDir) || isempty(protocolDir)
        return
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



