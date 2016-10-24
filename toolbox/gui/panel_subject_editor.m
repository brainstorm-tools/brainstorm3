function varargout = panel_subject_editor(varargin)
% PANEL_SUBJECT_EDITOR: Create or edit subject (GUI).
%
% USAGE: bstPanelNew = panel_subject_editor('CreatePanel')

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
function bstPanelNew = CreatePanel() %#ok<DEFNU>
    panelName = 'panel_subject_editor';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    
    % Create panel
    jPanelNew = gui_river();

    % ===== DEFINITION =====
    jPanelDefaults = gui_river('Subject');
        % Subject name
        jPanelDefaults.add(JLabel('Subject name: '));
        jTextSubjectName = JTextField();
        java_setcb(jTextSubjectName, 'KeyTypedCallback', @SubjectNameChanged_Callback);
        jPanelDefaults.add('tab hfill', jTextSubjectName);
        % Subject comments
        jPanelDefaults.add('p', JLabel('Comments: '));
        jTextSubjectComments = JTextField();
        jPanelDefaults.add('tab hfill', jTextSubjectComments);    
    jPanelNew.add('hfill', jPanelDefaults);
    
    % ===== DEFAULTS =====
    jPanelDefaults = gui_river('Defaults');
        % === DEFAULT ANATOMY ===
        jPanelDefaults.add(JLabel('<HTML><B>Default anatomy</B>: '));
        jButtonGroupAnatomy = ButtonGroup();
        jRadioAnatomyIndividual = JRadioButton('No, use individual anatomy');
        jRadioAnatomyDefault    = JRadioButton('Yes, use protocol''s default anatomy');
        jRadioAnatomyIndividual.setToolTipText('<HTML><BLOCKQUOTE><B>UseDefaultAnat=0</B><BR><BR> MRI and surfaces for this subject are saved in: <P>[ protocol/anat/<I>subject_dir</I> ]<BR><BR></BLOCKQUOTE></HTML>');
        jRadioAnatomyDefault.setToolTipText(['<HTML><BLOCKQUOTE><B>UseDefaultAnat=1</B><BR><BR> MRI and surfaces for this subject are saved in: <P>[ protocol/anat/' bst_get('DirDefaultSubject') ' ]<BR><BR></BLOCKQUOTE></HTML>']);
        jButtonGroupAnatomy.add(jRadioAnatomyIndividual);
        jButtonGroupAnatomy.add(jRadioAnatomyDefault);
        jPanelDefaults.add('br', JLabel('     '));
        jPanelDefaults.add('tab', jRadioAnatomyIndividual);
        jPanelDefaults.add('br tab', jRadioAnatomyDefault);
        % By default : Individual anatomy
        jRadioAnatomyIndividual.setSelected(1);

        % === DEFAULT CHANNEL FILE ===
        jPanelDefaults.add('p', JLabel('<HTML><B>Default channel file</B>: &nbsp;&nbsp;&nbsp;&nbsp;<FONT color=#7F7F7F><I>(includes the SSP/ICA projectors)</I></FONT>'));
        jButtonGroupChannel = ButtonGroup();
        jRadioChannelIndividual     = JRadioButton('No, use one channel file per acquisition run (MEG/EEG)');
        jRadioChannelDefaultSubject = JRadioButton('Yes, use one channel file per subject  (one run per subject)');
        jRadioChannelDefaultGlobal  = JRadioButton('Yes, use only one global channel file');
        jRadioChannelIndividual.setToolTipText(     '<HTML><BLOCKQUOTE><B>UseDefaultChannel=0</B><BR><BR> Sensors locations and headmodel files for this subject are saved in: <P>[ protocol/data/<I>subject_dir</I>/<I>condition_name</I> ]<BR><BR></BLOCKQUOTE></HTML>');
        jRadioChannelDefaultSubject.setToolTipText(['<HTML><BLOCKQUOTE><B>UseDefaultChannel=1</B><BR><BR> Sensors locations and headmodel files for this subject are saved in: <P>[ protocol/data/<I>subject_dir</I>/' bst_get('DirDefaultStudy') ' ]<BR><BR></BLOCKQUOTE></HTML>']);
        jRadioChannelDefaultGlobal.setToolTipText( ['<HTML><BLOCKQUOTE><B>UseDefaultChannel=2</B><BR><BR> Sensors locations and headmodel files for this subject are saved in: <P>[ protocol/data/' bst_get('DirDefaultStudy') ' ]<BR><BR></BLOCKQUOTE></HTML>']);
        jButtonGroupChannel.add(jRadioChannelIndividual);
        jButtonGroupChannel.add(jRadioChannelDefaultSubject);
        jButtonGroupChannel.add(jRadioChannelDefaultGlobal);
        java_setcb(jRadioChannelDefaultGlobal, 'ActionPerformedCallback', @GlobalWarning);
        jPanelDefaults.add('br tab vtop', jRadioChannelIndividual);
        jPanelDefaults.add('br tab', jRadioChannelDefaultSubject);
        jPanelDefaults.add('br tab', jRadioChannelDefaultGlobal);
        jPanelDefaults.add('br', JLabel());
        
        % By default : Individual channel file
        jRadioChannelIndividual.setSelected(1);
        % Try to prevent people to share channel files between protocol
        jRadioChannelDefaultGlobal.setForeground(Color(.5,.5,.5));
        java_setcb(jRadioChannelDefaultGlobal, 'ActionPerformedCallback', @GlobalWarning);
    jPanelNew.add('br hfill', jPanelDefaults);
    
    % Help button
    jButtonHelp = JButton('Help');
    jButtonHelp.setForeground(Color(.7, 0, 0));
    java_setcb(jButtonHelp, 'ActionPerformedCallback', @(h,ev)bst_help('ProtocolEditor.html'));
    jPanelNew.add('p right', jButtonHelp);
    % Cancel button
    jButtonCancel = JButton('Cancel');
    java_setcb(jButtonCancel, 'ActionPerformedCallback', @ButtonCancel_Callback);
    jPanelNew.add(jButtonCancel);
    % Save button
    jButtonSave = JButton('Save');
    jPanelNew.add(jButtonSave);

    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jTextSubjectName',            jTextSubjectName, ...
                                  'jTextSubjectComments',        jTextSubjectComments, ...
                                  'jRadioAnatomyIndividual',     jRadioAnatomyIndividual, ...
                                  'jRadioAnatomyDefault',        jRadioAnatomyDefault, ...
                                  'jRadioChannelIndividual',     jRadioChannelIndividual, ...
                                  'jRadioChannelDefaultSubject', jRadioChannelDefaultSubject, ...
                                  'jRadioChannelDefaultGlobal',  jRadioChannelDefaultGlobal, ...
                                  'jButtonSave',                 jButtonSave));

%% =================================================================================
%  === LOCAL CALLBACKS  ============================================================
%  =================================================================================
    % CANCEL button
    function ButtonCancel_Callback(varargin)
        gui_hide(panelName);
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
            jRadioChannelDefaultSubject.setSelected(1);
        end
    end

    % SUBJECT NAME CHANGED
    function SubjectNameChanged_Callback(varargin)
        % Get protocol name
        SubjectName = file_standardize(char(jTextSubjectName.getText()));
        % Fix the protocol name for weird characters
        if ~strcmp(char(jTextSubjectName.getText()), SubjectName)
            jTextSubjectName.setText(SubjectName);
            jTextSubjectName.setCaretPosition(length(SubjectName));
        end
    end
end


