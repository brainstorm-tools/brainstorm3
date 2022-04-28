function varargout = scenario_epilepto( varargin )
% SCENARIO_EPILEPTO: Compute epileptogenicity maps with O David procedure.

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
% Authors: Francois Tadel, 2017

eval(macro_method);
end


%% ===== CREATE PANEL =====
function ctrl = CreatePanels() %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.icon.*;
    import org.brainstorm.list.*;

    % Initialize global variables
    global GlobalData;
    GlobalData.Guidelines.SubjectName  = [];
    GlobalData.Guidelines.MriPre       = [];
    GlobalData.Guidelines.MriPost      = [];
    GlobalData.Guidelines.RawLinks     = {};
    GlobalData.Guidelines.RawFiles     = {};
    GlobalData.Guidelines.ChannelFiles = {};
    GlobalData.Guidelines.ChannelMats  = {};
    GlobalData.Guidelines.Baselines    = {};
    GlobalData.Guidelines.Onsets       = {};
    GlobalData.Guidelines.isPos        = [];
    GlobalData.Guidelines.nSEEG        = [];
    GlobalData.Guidelines.strOnset     = '';
    GlobalData.Guidelines.strBaseline  = '';
    
    % Initialize list of panels
    nPanels = 6;
    ctrl.jPanels = javaArray('javax.swing.JPanel', nPanels);
    ctrl.fcnValidate = cell(1, nPanels);
    ctrl.fcnReset    = cell(1, nPanels);
    ctrl.fcnUpdate   = cell(1, nPanels);
    ctrl.isSkip      = zeros(1, nPanels);

    % ===== PANEL: INTRODUCTION =====
    i = 1;
    ctrl.jPanels(i) = gui_river([3,3], [8,10,1,4], sprintf('Step #%d: Introduction', i));
    % Introduction
    gui_component('Label', ctrl.jPanels(i), 'hfill', ['<HTML>This pipeline is designed to help you compute epileptogenicity maps based on SEEG ictal recordings.<BR><BR>' ...
        'David O, Blauwblomme T, Job AS, Chabardès S, Hoffmann D, Minotti L, Kahane P. ' ...
        'Imaging the seizure onset zone with stereo-electroencephalography. Brain (2011)']);
    gui_component('Label', ctrl.jPanels(i), 'br', '<HTML><FONT COLOR="#0000C0">https://f-tract.eu/index.php/tutorials/</FONT>', [], [], @(h,ev)web('https://f-tract.eu/index.php/tutorials/', '-browser'));
    % Callbacks
    ctrl.fcnValidate{i} = @ValidateIntroduction;
    ctrl.fcnUpdate{i}   = @UpdateIntroduction;
    
    % ===== PANEL: IMPORT ANATOMY =====
    i = i + 1;
    ctrl.jPanels(i) = gui_river([3,3], [8,10,1,4], sprintf('Step #%d: Import anatomy', i));
    % Set subject name
    gui_component('Label', ctrl.jPanels(i), '', 'Subject name: ');
    ctrl.jComboSubj = gui_component('ComboBox', ctrl.jPanels(i), 'tab', [], {{' '}});
    ctrl.jComboSubj.setEditable(1);
    % Select subject MRI/pre
    gui_component('label', ctrl.jPanels(i), 'br', 'Pre-implantation MRI: ');
    ctrl.jTextMriPre = gui_component('text', ctrl.jPanels(i), 'tab hfill', '');
    gui_component('button', ctrl.jPanels(i), '', '', IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)panel_guidelines('PickFile', ctrl.jTextMriPre, ...
        'ImportAnat', 'single', 'files', bst_get('FileFilters', 'mri'), 'MriIn'));
    % Select subject MRI/post
    gui_component('label', ctrl.jPanels(i), 'br', 'Post-implantation MRI/CT: ');
    ctrl.jTextMriPost = gui_component('text', ctrl.jPanels(i), 'tab hfill', '');
    gui_component('button', ctrl.jPanels(i), '', '', IconLoader.ICON_FOLDER_OPEN, [], @(h,ev)panel_guidelines('PickFile', ctrl.jTextMriPost, ...
        'ImportAnat', 'single', 'files', bst_get('FileFilters', 'mri'), 'MriIn'));
    % Subject selection callback
    java_setcb(ctrl.jComboSubj, 'ItemStateChangedCallback', @(h,ev)SelectSubject());
    % MRI are already registered
    ctrl.jCheckRegistered = gui_component('checkbox', ctrl.jPanels(i), 'br', 'MRI volumes are already registered (.nii format only)');
    % Radio: Surface resolution
    gui_component('label', ctrl.jPanels(i), 'br', '<HTML><FONT color="#a0a0a0">Cortex resolution:</FONT>');
    jButtonGroupSurf = ButtonGroup();
    ctrl.jRadioSurf1 = gui_component('radio', ctrl.jPanels(i), '', '<HTML><FONT color="#a0a0a0">5124V</FONT>', jButtonGroupSurf);
    ctrl.jRadioSurf2 = gui_component('radio', ctrl.jPanels(i), '', '<HTML><FONT color="#a0a0a0">8196V</FONT>', jButtonGroupSurf);
    ctrl.jRadioSurf3 = gui_component('radio', ctrl.jPanels(i), '', '<HTML><FONT color="#a0a0a0">20484V</FONT>', jButtonGroupSurf);
    ctrl.jRadioSurf4 = gui_component('radio', ctrl.jPanels(i), '', '<HTML><FONT color="#a0a0a0">7861V+hip+amyg</FONT>', jButtonGroupSurf);
    ctrl.jRadioSurf3.setSelected(1);
    % Event names
    gui_component('label', ctrl.jPanels(i), 'br', '<HTML><FONT color="#a0a0a0">Onset event name: </FONT>');
    ctrl.jTextEvtOnset = gui_component('text', ctrl.jPanels(i), '', 'Onset');
    ctrl.jTextEvtOnset.setForeground(java.awt.Color(0.63,0.63,0.63));
    gui_component('label', ctrl.jPanels(i), '', '<HTML><FONT color="#a0a0a0">&nbsp;&nbsp;&nbsp;&nbsp;Baseline event name: </FONT>');
    ctrl.jTextEvtBaseline = gui_component('text', ctrl.jPanels(i), '', 'Baseline');
    ctrl.jTextEvtBaseline.setForeground(java.awt.Color(0.63,0.63,0.63));
    % Callbacks
    ctrl.fcnValidate{i} = @(c)ValidateImportAnatomy();
    ctrl.fcnReset{i}    = @(c)ResetImportAnatomy();
    ctrl.fcnUpdate{i}   = @(c)UpdateImportAnatomy();
    
    % ===== PANEL: IMPORT RECORDINGS =====
    i = i + 1;
    ctrl.jPanels(i) = gui_river([3,3], [8,10,-20,4], sprintf('Step #%d: Prepare recordings', i));
    % Toolbar
    buttonInsets = Insets(2,3,2,3);
    gui_component('button', ctrl.jPanels(i), '', '',  {buttonInsets, IconLoader.ICON_FOLDER_OPEN}, 'Add ictal recordings for this subject', @(h,ev)ButtonRawAdd());
    gui_component('button', ctrl.jPanels(i), '', '',  {buttonInsets, IconLoader.ICON_DELETE}, 'Remove recordings from this subject', @(h,ev)ButtonRawDel());
    gui_component('label', ctrl.jPanels(i), 'hfill', ' ');
    gui_component('button', ctrl.jPanels(i), '', 'Channels',    {buttonInsets, IconLoader.ICON_EDIT}, 'Edit the names and types of the data channels for the selected files', @(h,ev)ButtonRawEditChannel());
    gui_component('button', ctrl.jPanels(i), '', '3D',          {buttonInsets, IconLoader.ICON_CHANNEL}, 'Set the 3D positions for the SEEG contacts', @(h,ev)ButtonRawPos());
    gui_component('button', ctrl.jPanels(i), '', 'Review',      {buttonInsets, IconLoader.ICON_DATA}, 'Edit the bad channels for the selected files', @(h,ev)ButtonRawReview());
    gui_component('button', ctrl.jPanels(i), '', 'Onset',       {buttonInsets, IconLoader.ICON_EVT_OCCUR_ADD}, 'Identify the seizure onset with an event marker', @(h,ev)ButtonRawEvent('Onset'));
    gui_component('button', ctrl.jPanels(i), '', 'Baseline',    {buttonInsets, IconLoader.ICON_EVT_OCCUR_ADD}, 'Identify a baseline segment with an extended event marker', @(h,ev)ButtonRawEvent('Baseline'));
    
    % Create JTable
    ctrl.jTableRaw = JTable();
    ctrl.jTableRaw.setFont(bst_get('Font'));
    ctrl.jTableRaw.setRowHeight(22);
    ctrl.jTableRaw.setForeground(Color(.2, .2, .2));
    ctrl.jTableRaw.setSelectionBackground(Color(.72, 0.81, 0.89));
    ctrl.jTableRaw.setSelectionForeground(Color(.2, .2, .2));
    ctrl.jTableRaw.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
    ctrl.jTableRaw.getTableHeader().setReorderingAllowed(0);
    java_setcb(ctrl.jTableRaw, 'KeyTypedCallback',     @RawTableKeyTyped, ...
                               'MouseClickedCallback', @RawTableClick);
                               
    % Add table to import panel
    jPanelTable = JScrollPane(ctrl.jTableRaw);
    jPanelTable.setBorder([]);
    ctrl.jPanels(i).add('br hfill vfill', jPanelTable);
    % Callbacks
    ctrl.fcnValidate{i} = @(c)ValidatePrepareRaw();
    ctrl.fcnReset{i}    = @(c)ResetPrepareRaw();
    ctrl.fcnUpdate{i}   = @(c)UpdatePrepareRaw();
    
    % ===== PANEL: IMPORT EPOCHS =====
    i = i + 1;
    ctrl.jPanels(i) = gui_river([3,3], [8,10,1,4], sprintf('Step #%d: Import epochs', i));
    % Epoch window
    gui_component('label', ctrl.jPanels(i), '', 'Time window around seizure onset:');
    ctrl.jTextEpochStart = gui_component('texttime', ctrl.jPanels(i), '', ' ');
    gui_component('label', ctrl.jPanels(i), [], ' - ');
    ctrl.jTextEpochStop = gui_component('texttime',  ctrl.jPanels(i), [], ' ');
    % Set time controls callbacks
    TimeUnit = gui_validate_text(ctrl.jTextEpochStart, [], ctrl.jTextEpochStop, {-100, 100, 1000}, 's', [], -10, []);
    TimeUnit = gui_validate_text(ctrl.jTextEpochStop, ctrl.jTextEpochStart, [], {-100, 100, 1000}, 's', [], 40, []);
    gui_component('label', ctrl.jPanels(i), [], [' ' TimeUnit]);
    gui_component('label', ctrl.jPanels(i), 'br', ['<HTML><FONT color="#808080"><I>Includes the baseline for the time-frequency analysis and<BR>' ...
                                                                                  'the full time window for the epileptogenicity/latency maps.</I></FONT>']);
    % Bipolar montage
    gui_component('label', ctrl.jPanels(i), 'br', 'Electrode montage:');
    jButtonGroupMontage = ButtonGroup();
    ctrl.jRadioMontageBip1 = gui_component('radio', ctrl.jPanels(i), 'tab', '<HTML>Bipolar 1 <FONT color="#808080"></I>(eg. a1-a2, a3-a4, ...)<I><FONT>', jButtonGroupMontage);
    ctrl.jRadioMontageBip2 = gui_component('radio', ctrl.jPanels(i), 'br tab', '<HTML>Bipolar 2 <FONT color="#808080"></I>(eg. a1-a2, a2-a3, a3-a4, ...)<I><FONT>', jButtonGroupMontage);
    ctrl.jRadioMontageNone = gui_component('radio', ctrl.jPanels(i), 'br tab', '<HTML>None <FONT color="#808080"></I>(keep original montage)<I><FONT>', jButtonGroupMontage);
    ctrl.jRadioMontageBip2.setSelected(1);
    % Callbacks
    ctrl.fcnValidate{i} = @(c)ValidateEpoch();
    ctrl.fcnReset{i}    = @(c)ResetEpoch();
    
    % ===== PANEL: TIME-FREQUENCY =====
    i = i + 1;
    ctrl.jPanels(i) = gui_river([3,3], [8,10,1,4], sprintf('Step #%d: Time-frequency', i));
    % Taper
    gui_component('Label', ctrl.jPanels(i), '', 'Taper: ');
    ctrl.jComboTaper = gui_component('combobox', ctrl.jPanels(i), '', [], {{'Hanning','DPSS'}});
    % Frequencies
    gui_component('label', ctrl.jPanels(i), 'br', 'Frequencies (start:step:stop): ');
    ctrl.jTextFreq = gui_component('texttime', ctrl.jPanels(i), '', '10:3:220');
    % Callbacks
    ctrl.fcnValidate{i} = @(c)ValidateTimefreq();
    ctrl.fcnReset{i}    = @(c)ResetTimefreq();
    ctrl.isSkip(i)      = 1;
    
    % ===== PANEL: EPILEPTOGENICITY =====
    i = i + 1;
    % Epileptogenicity options
    jPanelEpilOptions = gui_river([3,3], [0,0,0,0]);
    gui_component('label', jPanelEpilOptions, '', 'Frequency band (Hz): ');
    ctrl.jTextFreqBand = gui_component('text', jPanelEpilOptions, 'tab', '[120 200]');
    gui_component('button', jPanelEpilOptions, 'tab', 'Get', {Insets(2,4,2,4)}, [], @(h,ev)GetFreqBand(ctrl.jTextFreqBand));
    gui_component('label', jPanelEpilOptions, '', '  ');
    gui_component('label', jPanelEpilOptions, 'br', 'Latency list (s): ');
    ctrl.jTextLatency = gui_component('text', jPanelEpilOptions, 'tab', '0:2:20');
    gui_component('label', jPanelEpilOptions, 'br', 'Time constant (s): ');
    ctrl.jTextTimeConstant = gui_component('texttime', jPanelEpilOptions, 'tab', '3');
    gui_component('label', jPanelEpilOptions, 'br', 'Propagation threshold (p or T): ');
    ctrl.jTextThDelay = gui_component('texttime', jPanelEpilOptions, 'tab', '0.05');
    % Output type
    gui_component('label', jPanelEpilOptions, 'br', 'Output type:');
    jButtonGroupOutput = ButtonGroup();
    ctrl.jRadioOutputVolume = gui_component('radio', jPanelEpilOptions, '', 'Volume', jButtonGroupOutput);
    ctrl.jRadioOutputSurface = gui_component('radio', jPanelEpilOptions, '', 'Surface', jButtonGroupOutput);
    ctrl.jRadioOutputVolume.setSelected(1);
    % File list
    ctrl.jListFiles = JList([BstListItem('', '', 'Component 1', int32(0)), BstListItem('', '', 'Component 2', int32(1))]);
        fontSize = round(11 * bst_get('InterfaceScaling') / 100);
        jCellRenderer = BstCheckListRenderer(fontSize);
        jCellRenderer.setRenderSelection(0);
        ctrl.jListFiles.setCellRenderer(jCellRenderer);
        ctrl.jListFiles.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        java_setcb(ctrl.jListFiles, 'MouseClickedCallback', @ListFilesClick_Callback);
        jScrollFiles = JScrollPane(ctrl.jListFiles);
    % Assemble panel
    ctrl.jPanels(i) = gui_river([0,0], [5,10,0,4], sprintf('Step #%d: Epileptogenicity', i));
    ctrl.jPanels(i).add('vtop', jPanelEpilOptions);
    ctrl.jPanels(i).add('hfill vfill', jScrollFiles);
    % Callbacks
    ctrl.fcnValidate{i} = @(c)ValidateEpileptogenicity();
    ctrl.fcnReset{i}    = @(c)ResetEpileptogenicity();
    ctrl.fcnUpdate{i}   = @(c)UpdateEpileptogenicity();
    
    % Save references to all the controls
    GlobalData.Guidelines.ctrl = ctrl;
end



%% ==========================================================================================
%  ===== INTRODUCTION =======================================================================
%  ==========================================================================================

%% ===== INTRODUCTION: VALIDATE =====
function [isValidated, errMsg] = ValidateIntroduction()
    % Initialize returned variables
    isValidated = 1;
    errMsg = '';
    % Display the anatomy of the subjects
    gui_brainstorm('SetExplorationMode', 'Subjects');
end

%% ===== INTRODUCTION: UPDATE =====
function [isValidated, errMsg] = UpdateIntroduction()
    % Initialize returned variables
    isValidated = 1;
    errMsg = '';
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
end


%% ==========================================================================================
%  ===== IMPORT ANATOMY =====================================================================
%  ==========================================================================================

%% ===== IMPORT ANATOMY: VALIDATE =====
function [isValidated, errMsg] = ValidateImportAnatomy()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Initialize returned variables
    isValidated = 0;
    errMsg = '';
    % Display the anatomy of the subjects
    gui_brainstorm('SetExplorationMode', 'Subjects');
    
    % === GET INPUTS ===
    SubjectName = char(ctrl.jComboSubj.getSelectedItem());
    MriFilePre  = char(ctrl.jTextMriPre.getText());
    MriFilePost = char(ctrl.jTextMriPost.getText());
    isRegistered = ctrl.jCheckRegistered.isSelected();
    % Get surface resolution
    if ctrl.jRadioSurf1.isSelected()
        SurfResolution = 1;
    elseif ctrl.jRadioSurf2.isSelected()
        SurfResolution = 2;
    elseif ctrl.jRadioSurf3.isSelected()
        SurfResolution = 3;
    elseif ctrl.jRadioSurf4.isSelected()
        SurfResolution = 4;
    end
    % Get event names
    GlobalData.Guidelines.strOnset = char(ctrl.jTextEvtOnset.getText());
    GlobalData.Guidelines.strBaseline = char(ctrl.jTextEvtBaseline.getText());
    if isempty(GlobalData.Guidelines.strOnset) || isempty(GlobalData.Guidelines.strBaseline) || strcmpi(GlobalData.Guidelines.strOnset, GlobalData.Guidelines.strBaseline)
        errMsg = 'Invalid event names.';
        return;
    end
    
    % === GET SUBJECT ===
    % Subject name
    if isempty(SubjectName)
        errMsg = ['You must enter the name of a new subject ' 10 'or select an existing subject.'];
        return;
    end
    % Find the subject in database
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % If subject is not found in DB: create it
    if isempty(sSubject)
        [sSubject, iSubject] = db_add_subject(SubjectName, [], 0, 0);
        % If subject cannot be created: error: stop everything
        if isempty(sSubject)
            errMsg = ['Could not create subject "' SubjectName '"'];
            return;
        end
    % Else: Check that it does not use any default
    elseif ((sSubject.UseDefaultChannel ~= 0) || (sSubject.UseDefaultAnat ~= 0))
        errMsg = ['Subject "' SubjectName '" uses a default anatomy or channel file.' 10 'Change the configuration of the subject to use it.'];
        return;
    end
    
    % === IMPORT MRI VOLUMES ===
    % Anatomy folder
    AnatDir = bst_fileparts(file_fullpath(sSubject.FileName));
    MriPre  = fullfile(AnatDir, 'subjectimage_pre.mat');
    MriPostOrig = fullfile(AnatDir, 'subjectimage_post_orig.mat');
    MriPostReslice = fullfile(AnatDir, 'subjectimage_post.mat');
    % Check if there are already two volumes in the subject
    if ~file_exist(MriPre) || ~file_exist(MriPostReslice)
        % MRI files
        if isempty(MriFilePre) || isempty(MriFilePost)
            errMsg = ['You must select the pre- and post-implantation scans for subject "' SubjectName '".'];
            return;
        end
        % If using an anatomy template (one MRI only)
        if (length(sSubject.Anatomy) == 1) && strcmpi(MriFilePre, sSubject.Anatomy(1).Comment) && strcmpi(MriFilePost, sSubject.Anatomy(1).Comment)
            MriPre = file_fullpath(sSubject.Anatomy(1).FileName);
            MriPostOrig = MriPre;
            MriPostReslice = MriPre;
        % Otherwise: Import selected files
        else
            if ~file_exist(MriFilePre)
                errMsg = 'The pre-implantation MRI file you selected does not exist.';
                return;
            end
            if ~file_exist(MriFilePost)
                errMsg = 'The post-implantation MRI/CT file you selected does not exist.';
                return;
            end
            % Delete existing anatomy
            sSubject = db_delete_anatomy(iSubject);
            
            % === REGISTER ===
            % Import both volumes
            DbMriFilePre = import_mri(iSubject, MriFilePre, 'ALL', 0, 0);
            if isempty(DbMriFilePre)
                errMsg = ['Cannot import pre-implantation volume: "' 10 MriFilePre '".'];
                return
            end
            DbMriFilePost = import_mri(iSubject, MriFilePost, 'ALL', 0, 0);
            if isempty(DbMriFilePost)
                errMsg = ['Cannot import pre-implantation volume: "' 10 MriFilePost '".'];
                return
            end
            % Compute the MNI coordinates for both volumes
            [sMriPre, errMsg] = bst_normalize_mni(DbMriFilePre);
            if ~isempty(errMsg)
                errMsg = ['Cannot normalize pre-implantation volume: "' 10 errMsg '".'];
                return;
            end
            % Volumes are not registered: Register with SPM
            if ~isRegistered
                [DbMriFilePostReg, errMsg, fileTag, sMriPostReg] = mri_coregister(DbMriFilePost, DbMriFilePre, 'spm', 0);
            % Volumes are registered: Copy SCS and NCS fiducials to post volume
            else
                [DbMriFilePostReg, errMsg, fileTag, sMriPostReg] = mri_coregister(DbMriFilePost, DbMriFilePre, 'vox2ras', 0);
            end
            if ~isempty(errMsg)
                return;
            end
            
            % === RESLICE ===
            % Get the .nii transformation in both volumes
            iTransfPre  = find(strcmpi(sMriPre.InitTransf(:,1),  'vox2ras'));
            iTransfPost = find(strcmpi(sMriPostReg.InitTransf(:,1), 'vox2ras'));
            if (isempty(iTransfPre) || isempty(iTransfPost)) && (~isequal(size(sMriPre.Cube(:,:,:,1)), size(sMriPost.Cube(:,:,:,1))) || ~isequal(sMriPre.Voxsize, sMriPostReg.Voxsize))
                errMsg = 'The pre and post volumes are not registered or were not initially in .nii format.';
                return;
            end
            % Reslice the "post" volume
            [DbMriFilePostReslice, errMsg, fileTag, sMriPostReslice] = mri_reslice(DbMriFilePostReg, DbMriFilePre, 'vox2ras', 'vox2ras');

            % === RE-ORGANIZE FILES ===
            % Get updated subject structure
            [sSubject, iSubject] = bst_get('Subject', SubjectName);
            % Delete non-registered post MRI
            file_delete(DbMriFilePost, 1);
            sSubject.Anatomy(2) = [];
            % Rename imported volumes
            file_move(file_fullpath(DbMriFilePre), MriPre);
            file_move(file_fullpath(DbMriFilePostReg), MriPostOrig);
            file_move(file_fullpath(DbMriFilePostReslice), MriPostReslice);
            sSubject.Anatomy(1).FileName = file_short(MriPre);
            sSubject.Anatomy(2).FileName = file_short(MriPostOrig);
            sSubject.Anatomy(3).FileName = file_short(MriPostReslice);
            % Update database
            bst_set('Subject', iSubject, sSubject);
            panel_protocols('UpdateNode', 'Subject', iSubject);
            % Save MRI pre as permanent default
            db_surface_default(iSubject, 'Anatomy', 1, 0);
            % Compute SPM canonical surfaces
            process_generate_canonical('ComputeInteractive', iSubject, 1, SurfResolution);
        end
    end
    % Save for later
    GlobalData.Guidelines.SubjectName = SubjectName;
    GlobalData.Guidelines.MriPre      = MriPre;
    GlobalData.Guidelines.MriPost     = MriPostOrig;
    
    % === DISPLAY RESULT ===
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Only if the two volumes are not the same
    if ~strcmpi(MriPre, MriPostOrig)
        % Open the post volume as an overlay of the pre volume
        hFig = view_mri(MriPre, MriPostReslice);
        % Set the amplitude threshold to 50%
        panel_surface('SetDataThreshold', hFig, 1, 0.3);
        % Select surface tab
        gui_brainstorm('SetSelectedTab', 'Surface');
    end
    
    % Panel is validated
    isValidated = 1;
end

%% ===== IMPORT ANATOMY: RESET =====
function ResetImportAnatomy()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Get subject name
    SubjectName = char(ctrl.jComboSubj.getSelectedItem());
    % Subject is found: delete its anatomy
    if ~isempty(SubjectName)
        % Get subject
        [sSubject, iSubject] = bst_get('Subject', SubjectName);
        % Delete anatomy
        if ~isempty(iSubject) && ~isempty(sSubject.Anatomy)
            % Ask confirmation
            if ~java_dialog('confirm', ['Delete the anatomy for subject "' SubjectName '"?'])
                return;
            end
            % Delete files
            db_delete_anatomy(iSubject);
        end
    end
    % Reset all fields
    % ctrl.jComboSubj.setSelectedItem([]);
    ctrl.jTextMriPre.setText('');
    ctrl.jTextMriPost.setText('');
    ctrl.jCheckRegistered.setSelected(0);
end

%% ===== IMPORT ANATOMY: UPDATE =====
function [isValidated, errMsg] = UpdateImportAnatomy()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Initialize returned variables
    isValidated = 1;
    errMsg = '';
    % Get subjects in this protocol
    ProtocolSubjects = bst_get('ProtocolSubjects');
    iNoCommon = find(([ProtocolSubjects.Subject.UseDefaultAnat] == 0) & ([ProtocolSubjects.Subject.UseDefaultChannel] == 0));
    strItems = sort({ProtocolSubjects.Subject(iNoCommon).Name});
    % Update combobox
    jModel = ctrl.jComboSubj.getModel();
    jModel.removeAllElements();
    jModel.addElement('');
    for i = 1:length(strItems)
        jModel.addElement(strItems{i});
    end
    % Empty other boxes
    ctrl.jTextMriPre.setText('');
    ctrl.jTextMriPost.setText('');
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Display the anatomy of the subjects
    gui_brainstorm('SetExplorationMode', 'Subjects');
end

%% ===== SELECT SUBJECT =====
function SelectSubject()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Get subject
    SubjectName = char(ctrl.jComboSubj.getSelectedItem());
    if isempty(SubjectName)
        ctrl.jTextMriPre.setText('');
        ctrl.jTextMriPost.setText('');
        return;
    end
    sSubject = bst_get('Subject', SubjectName);
    if isempty(sSubject)
        ctrl.jTextMriPre.setText('');
        ctrl.jTextMriPost.setText('');
        return;
    end
    % Select subject node in the database explorer
    % panel_protocols('UpdateTree');
    panel_protocols('ExpandAll', 0);
    panel_protocols('SelectSubject', SubjectName);
    % Anatomy folder
    AnatDir = bst_fileparts(file_fullpath(sSubject.FileName));
    MriPre  = fullfile(AnatDir, 'subjectimage_pre.mat');
    MriPost = fullfile(AnatDir, 'subjectimage_post.mat');
    % Check if there are already two volumes in the subject
    if file_exist(MriPre) && file_exist(MriPost)
        [sSubject, iSubject, iPre]  = bst_get('MriFile', MriPre);
        [sSubject, iSubject, iPost] = bst_get('MriFile', MriPost);
        ctrl.jTextMriPre.setText(sSubject.Anatomy(iPre).Comment);
        ctrl.jTextMriPost.setText(sSubject.Anatomy(iPost).Comment);
    % Otherwise, if there is one volume only: use it twice
    elseif (length(sSubject.Anatomy) == 1)
        ctrl.jTextMriPre.setText(sSubject.Anatomy(1).Comment);
        ctrl.jTextMriPost.setText(sSubject.Anatomy(1).Comment);
    else
        ctrl.jTextMriPre.setText('');
        ctrl.jTextMriPost.setText('');
    end
end



%% ==========================================================================================
%  ===== PREPARE RECORDINGS =================================================================
%  ==========================================================================================

%% ===== PREPARE RECORDINGS: VALIDATE =====
function [isValidated, errMsg] = ValidatePrepareRaw()
    global GlobalData;
    % Initialize returned variables
    isValidated = 0;
    errMsg = '';
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Reload panel
    UpdatePrepareRaw();
    % Check that all the necessary data is available
    if isempty(GlobalData.Guidelines.RawLinks)
        errMsg = 'You must add at least one SEEG file.';
        return;
    elseif any(GlobalData.Guidelines.nSEEG == 0)
        errMsg = 'You must identify SEEG channels in all the files.';
        return;
    elseif all(cellfun(@isempty, GlobalData.Guidelines.Onsets))
        errMsg = 'You must identify at least one seizure with an "Onset" event.';
        return;
    elseif all(cellfun(@isempty, GlobalData.Guidelines.Baselines))
        errMsg = 'You must identify at least one baseline period in the select files.';
        return;
    end
    isValidated = 1;
end

%% ===== PREPARE RECORDINGS: RESET =====
function ResetPrepareRaw()
    global GlobalData;
    % Get subject name
    SubjectName = GlobalData.Guidelines.SubjectName;
    % Get subject
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    if isempty(iSubject)
        return;
    end
    % Get all the studies for this subject
    [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
    % Get files in intra folder
    [sStudyIntra, iStudyIntra] = bst_get('AnalysisIntraStudy', iSubject);
    FilesToDelete = {};
    if ~isempty(sStudyIntra.Data)
        FilesToDelete = cat(2, FilesToDelete, sStudyIntra.Data.FileName);
    end
    if ~isempty(sStudyIntra.Timefreq)
        FilesToDelete = cat(2, FilesToDelete, sStudyIntra.Timefreq.FileName);
    end
    if ~isempty(sStudyIntra.Channel) && ~isempty(sStudyIntra.Channel.FileName)
        FilesToDelete = cat(2, FilesToDelete, sStudyIntra.Channel.FileName);
    end
    % Nothing to remove
    if isempty(iStudies) && isempty(FilesToDelete)
        return;
    end
    % Ask confirmation
    if ~java_dialog('confirm', ['Remove all the recordings from subject "' SubjectName '"?'])
        return;
    end
    % Delete folders
    if ~isempty(iStudies)
        db_delete_studies(iStudies);
    end
    % Empty intra folder
    if ~isempty(FilesToDelete)
        % Delete files
        FilesToDelete = cellfun(@file_fullpath, FilesToDelete, 'UniformOutput', 0);
        file_delete(FilesToDelete, 1);
        % Update study
        sStudyIntra.Channel(:) = [];
        sStudyIntra.Data(:) = [];
        sStudyIntra.Timefreq(:) = [];
        bst_set('Study', iStudyIntra, sStudyIntra);
    end
    % Update tree
    panel_protocols('UpdateTree');
    % Update list of files
    UpdatePrepareRaw();
end

%% ===== PREPARE RECORDINGS: UPDATE =====
function UpdatePrepareRaw()
    import org.brainstorm.table.*;
    % Initialize global variables
    global GlobalData;
    if isempty(GlobalData) || ~isfield(GlobalData, 'Guidelines') || ~isfield(GlobalData.Guidelines, 'ctrl')
        return;
    end
    ctrl = GlobalData.Guidelines.ctrl;
    % Column names
    columnNames = {'Path', 'File', '#', '3D', 'Bad', GlobalData.Guidelines.strOnset, GlobalData.Guidelines.strBaseline};
    % Progress bar
    bst_progress('start', 'Import recordings', 'Loading...');
    
    % === GET LIST OF RAW FILES ===
    % Get list of raw files for this subject
    RawLinks = {};
    RawFolders = {};
    GlobalData.Guidelines.ChannelFiles = {};
    GlobalData.Guidelines.ChannelMats  = {};
    if ~isempty(GlobalData.Guidelines.SubjectName)
        % Get subject index
        sSubject = bst_get('Subject', GlobalData.Guidelines.SubjectName);
        % Get all the folders for this subject
        [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
        % Get all the raw files in this study
        if ~isempty(iStudies)
            [iDataStudies, iDataFiles] = bst_get('DataForStudies', iStudies);
            for i = 1:length(iDataStudies)
                sDataStudy = bst_get('Study', iDataStudies(i));
                if strcmpi(sDataStudy.Data(iDataFiles(i)).DataType, 'raw')
                    RawLinks{end+1} = sDataStudy.Data(iDataFiles(i)).FileName;
                    [tmp,RawFolders{end+1}] = bst_fileparts(bst_fileparts(RawLinks{end}));
                    % Load channel file
                    GlobalData.Guidelines.ChannelFiles{end+1} = sDataStudy.Channel(1).FileName;
                    GlobalData.Guidelines.ChannelMats{end+1}  = in_bst_channel(sDataStudy.Channel(1).FileName);
                    % Select first file in database explorer
                    if (length(RawLinks) == 1)
                        % Update selected study in ProtocolInfo
                        ProtocolInfo = bst_get('ProtocolInfo');
                        ProtocolInfo.iStudy = iDataStudies(i);
                        bst_set('ProtocolInfo', ProtocolInfo);
                        % panel_protocols('SelectStudyNode', iDataStudies(i));
                    end
                end
            end
        end
    end
    % Sort selected files by folder names (so it matches the order in the database explorer) 
    if ~isempty(RawLinks)
        [RawFolders, I] = sort(RawFolders);
        RawLinks = RawLinks(I);
        GlobalData.Guidelines.ChannelFiles = GlobalData.Guidelines.ChannelFiles(I);
        GlobalData.Guidelines.ChannelMats  = GlobalData.Guidelines.ChannelMats(I);
    end
    % Save in Brainstorm global variable
    GlobalData.Guidelines.RawLinks  = RawLinks;
    GlobalData.Guidelines.Baselines = cell(size(RawLinks));
    GlobalData.Guidelines.Onsets    = cell(size(RawLinks));
    GlobalData.Guidelines.isPos     = zeros(size(RawLinks));
    GlobalData.Guidelines.nSEEG     = zeros(size(RawLinks));
    % Display the anatomy of the subjects
    gui_brainstorm('SetExplorationMode', 'StudiesSubj');
    
    % === READ FILE INFO ===
    % Initialize data to represent
    filesData = cell(length(RawLinks), length(columnNames));
    % Read files one by one
    for iFile = 1:length(RawLinks)
        % Load file
        LinkMat = in_bst_data(RawLinks{iFile});
        sFile = LinkMat.F;
        % Get file name
        [filesData{iFile,1}, filesData{iFile,2}] = bst_fileparts(sFile.filename);
        
        % Get list of EEG channels
        iSeeg = channel_find(GlobalData.Guidelines.ChannelMats{iFile}.Channel, 'SEEG,ECOG');
        filesData{iFile,3} = length(iSeeg);
        GlobalData.Guidelines.nSEEG(iFile) = length(iSeeg);
        
        % Check positions
        isPos = 1;
        iSeeg = channel_find(GlobalData.Guidelines.ChannelMats{iFile}.Channel, 'SEEG,ECOG');
        for i = 1:length(iSeeg)
            if ~isequal(size(GlobalData.Guidelines.ChannelMats{iFile}.Channel(iSeeg(i)).Loc), [3,1]) || all(GlobalData.Guidelines.ChannelMats{iFile}.Channel(iSeeg(i)).Loc == 0)
                isPos = 0;
                break;
            end
        end
        GlobalData.Guidelines.isPos(iFile) = isPos;
        filesData{iFile,4} = java.lang.Boolean(isPos);
        
        % Get list of bad channels
        strBad = '';
        iBad = find(LinkMat.ChannelFlag == -1);
        for iChan = 1:length(iBad)
            strBad = [strBad, GlobalData.Guidelines.ChannelMats{iFile}.Channel(iBad(iChan)).Name];
            if (iChan < length(iBad))
                strBad = [strBad, ','];
            end
        end
        filesData{iFile,5} = strBad;
        
        % Get Onset event
        strOnset = ' ';
        if isfield(sFile, 'events') && ~isempty(sFile.events)
            iEvtOnset = find(strcmpi({sFile.events.label}, GlobalData.Guidelines.strOnset));
            % Event was found
            if ~isempty(iEvtOnset)
                strOnset = FormatEvent(sFile.events(iEvtOnset).times);
                % Save in memory
                GlobalData.Guidelines.Onsets{iFile} = sFile.events(iEvtOnset).times(1,:);
            end
        end
        filesData{iFile,6} = strOnset;
        
        % Get Baseline event
        strBaseline = ' ';
        if isfield(sFile, 'events') && ~isempty(sFile.events)
            iEvtBaseline = find(strcmpi({sFile.events.label}, GlobalData.Guidelines.strBaseline));
            % Skip baseline events that are not extended events
            if ~isempty(iEvtBaseline) && (size(sFile.events(iEvtBaseline).times,1) == 1)
                disp(['Baseline must be an extended event: ' RawLinks{iFile}]);
            % Keep event 
            elseif ~isempty(iEvtBaseline)
                strBaseline = FormatEvent(sFile.events(iEvtBaseline).times);
                % Save in memory
                GlobalData.Guidelines.Baselines{iFile} = sFile.events(iEvtBaseline).times;
            end
        end
        filesData{iFile,7} = strBaseline;
 
        % Save for later
        GlobalData.Guidelines.RawFiles{end+1} = sFile.filename;
    end

    % All cells are read-only
    isColEditable = zeros(1, length(columnNames));
    % Set as the JTable data model
    ctrl.jTableRaw.setModel(org.brainstorm.table.ChannelTableModel(ctrl.jTableRaw, filesData, columnNames, isColEditable));

    % COLUMN 0: PATH
    ctrl.jTableRaw.getColumnModel.getColumn(0).setPreferredWidth(10);
    % COLUMN 1: FILENAME
    ctrl.jTableRaw.getColumnModel.getColumn(1).setPreferredWidth(100);
    % COLUMN 2: SEEG CHANNELS
    ctrl.jTableRaw.getColumnModel.getColumn(2).setPreferredWidth(5);
    % COLUMN 3: POSITION
    ctrl.jTableRaw.getColumnModel.getColumn(3).setPreferredWidth(5);
    ctrl.jTableRaw.getColumnModel.getColumn(3).setCellRenderer(BooleanCellRenderer());
    % COLUMN 4: BAD CHANNELS
    ctrl.jTableRaw.getColumnModel.getColumn(4).setPreferredWidth(70);
    % COLUMN 5: ONSET
    ctrl.jTableRaw.getColumnModel.getColumn(5).setPreferredWidth(40);
    % COLUMN 6: BASELINE
    ctrl.jTableRaw.getColumnModel.getColumn(6).setPreferredWidth(100);

    % Force repaint of the table
    drawnow;
    ctrl.jTableRaw.invalidate();
    ctrl.jTableRaw.repaint();
    % Close progress bar
    bst_progress('stop');
end



%% ==========================================================================================
%  ===== PREPARE RECORDINGS CALLBACKS =======================================================
%  ==========================================================================================

%% ===== RECORDINGS: ADD FILES =====
function ButtonRawAdd()
    global GlobalData;
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Select files
    [RawFiles, FileFormat] = panel_guidelines('PickFile', [], 'ImportData', 'multiple', 'files_and_dirs', bst_get('FileFilters', 'raw'), 'DataIn');
    if isempty(RawFiles)
        return;
    end
    % Create raw links
    [sSubject, iSubject] = bst_get('Subject', GlobalData.Guidelines.SubjectName);
    OutputFiles = import_raw(RawFiles, FileFormat, iSubject);
    % Replace events start/stop with continuous events
    RawContinuousEvt(OutputFiles);
    % Process: Consider as SEEG/ECOG
    bst_process('CallProcess', 'process_channel_setseeg', OutputFiles, [], 'newtype', 'SEEG');
    % Save file format
    UpdatePrepareRaw();
    % Edit channel files
    ButtonRawEditChannel(OutputFiles);
end


%% ===== RECORDINGS: GET CONTINUOUS EVENTS =====
function RawContinuousEvt(OutputFiles)
    % Replace events start/stop with continuous events
    for iFile = 1:length(OutputFiles)
        % Load file
        LinkMat = in_bst_data(OutputFiles{iFile});
        events = LinkMat.F.events;
        if isempty(events)
            continue;
        end
        % Look for events with "start" in the name
        iEvtStart = find(~cellfun(@(c)isempty(strfind(lower(c), 'start')), {events.label}));
        if isempty(iEvtStart)
            continue;
        end
        % Process the start events
        iEvtDel = [];
        for i = 1:length(iEvtStart)
            % Look for stop event
            iEvtStop = find(strcmpi({events.label}, strrep(lower(events(iEvtStart(i)).label), 'start', 'stop')));
            if isempty(iEvtStop) || ~all(size(events(iEvtStop).times) == size(events(iEvtStart(i)).times)) || (size(events(iEvtStop).times,1) ~= 1) || ~all(events(iEvtStart(i)).times < events(iEvtStop).times)
                continue;
            end
            % New label
            if strcmpi(events(iEvtStart(i)).label, 'start')
                newLabel = 'ext';
            else
                newLabel = strrep(lower(events(iEvtStart(i)).label), 'start', '');
            end
            newLabel = file_unique(newLabel, {events.label});
            % Create new extended event
            iEvtNew = length(events) + 1;
            events(iEvtNew) = events(iEvtStart(i));
            events(iEvtNew).label   = newLabel;
            events(iEvtNew).times   = [events(iEvtStart(i)).times;   events(iEvtStop).times];
            % Save modifications
            iEvtDel = [iEvtDel, iEvtStart(i), iEvtStop];
        end
        % Save modification
        if ~isempty(iEvtDel)
            events(iEvtDel) = [];
            LinkMat.F.events = events;
            bst_save(file_fullpath(OutputFiles{iFile}), LinkMat, 'v7');
        end
    end
end


%% ===== RECORDINGS: REMOVE FILES =====
function ButtonRawDel()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % If there are not files: exit
    if isempty(GlobalData.Guidelines.RawLinks)
        return;
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Get selected files
    iSelFiles = ctrl.jTableRaw.getSelectedRows()' + 1;
    if isempty(iSelFiles)
        return;
    end
    % Ask confirmation
    if ~java_dialog('confirm', 'Remove selected files from database?')
        return;
    end
    % Get list of folders to delete
    iStudiesDel = [];
    for i = 1:length(iSelFiles)
        [sStudy, iStudy] = bst_get('DataFile', GlobalData.Guidelines.RawLinks{iSelFiles(i)});
        iStudiesDel = [iStudiesDel, iStudy];
    end
    % Delete data
    db_delete_studies(iStudiesDel);
    % Update tree
    panel_protocols('UpdateTree');
    % Save file format
    UpdatePrepareRaw();
end

%% ===== RECORDINGS: EDIT CHANNEL FILE =====
function ButtonRawEditChannel(RawLinks)
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % If there are not files: exit
    if isempty(GlobalData.Guidelines.RawLinks)
        return;
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Parse inputs
    if (nargin < 1) || isempty(RawLinks)
        % Get selected files
        iSelFiles = ctrl.jTableRaw.getSelectedRows()' + 1;
        % If no files are selected: select them all
        if isempty(iSelFiles)
            iSelFiles = 1:length(GlobalData.Guidelines.RawLinks);
        end
        RawLinks = GlobalData.Guidelines.RawLinks(iSelFiles);
    end
    
    % Read and compare all the corresponding channel files
    AllChannelFiles = {};
    AllChannelMats = {};
    for iFile = 1:length(RawLinks)
        % Get channel file
        AllChannelFiles{iFile} = bst_get('ChannelFileForStudy', RawLinks{iFile});
        % Read channel file
        AllChannelMats{iFile} = in_bst_channel(AllChannelFiles{iFile});
        % For multiple channel files: compare with the first one
        if (iFile >= 2) && ~isequal({AllChannelMats{iFile}.Channel.Name}, {AllChannelMats{1}.Channel.Name})
            bst_error(['The list of channels is different for each file.' 10 'You may need to edit the channels names and types separately for each file.'], 'Import files', 0);
            return;
        end
    end
    
    % Open channel editor
    jFrame = gui_edit_channel(AllChannelFiles{1});
    fcnCallback = java_getcb(jFrame, 'WindowClosingCallback');
    
    % Callback function to replicate the modifications to the other channel files
    function ChannelEditorClosed_Callback()
        % Call default callback to save the first file
        fcnCallback();
        % Copy changes to others
        if (length(RawLinks) > 1)
            % Load the first channel file again
            RefChannelMat = in_bst_channel(AllChannelFiles{1});
            % If there were modifications: Apply the same modifications to the other channel files
            if ~isequal({RefChannelMat.Channel.Name}, {AllChannelMats{1}.Channel.Name}) || ~isequal({RefChannelMat.Channel.Type}, {AllChannelMats{1}.Channel.Type})
                for iFile = 2:length(RawLinks)
                    % Replicate the modifications
                    [AllChannelMats{iFile}.Channel.Name] = deal(RefChannelMat.Channel.Name);
                    [AllChannelMats{iFile}.Channel.Type] = deal(RefChannelMat.Channel.Type);
                    % Save modifications
                    bst_save(file_fullpath(AllChannelFiles{iFile}), AllChannelMats{iFile}, 'v7');
                end
            end
        end
        % Update panel
        UpdatePrepareRaw();
    end
    % Add a hook to capture when the channel editor is closed
    java_setcb(jFrame, 'WindowClosingCallback', @(h,ev)ChannelEditorClosed_Callback());
end

%% ===== RECORDINGS: REVIEW =====
function ButtonRawReview()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % If there are not files: exit
    if isempty(GlobalData.Guidelines.RawLinks)
        return;
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Get selected files
    iSelFiles = ctrl.jTableRaw.getSelectedRows()' + 1;
    % If no or multiple files are selected: exit
    if (length(iSelFiles) ~= 1) 
        return;
    end
    % Review file
    ReviewFile(GlobalData.Guidelines.RawLinks{iSelFiles});
end


%% ===== RECORDINGS: BUTTON EVENT =====
function ButtonRawEvent(evtType)
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Get the raw dataset (currently being reviewed)
    iDS = bst_memory('GetRawDataSet');
    % If the viewer is not opened: open the selected file
    if isempty(iDS)
        % Get selected files
        iSelFiles = ctrl.jTableRaw.getSelectedRows()' + 1;
        % If no or multiple files are selected: exit
        if (length(iSelFiles) ~= 1) 
            bst_error('You must open a file before setting the seizure onset marker or baseline.', 'Set event', 0);
        % Else: review file
        else
            ReviewFile(GlobalData.Guidelines.RawLinks{iSelFiles});
        end
        return;
    end

    % Get raw time series figure
    [hFig,iFig,iDS] = bst_figures('GetCurrentFigure', '2D');
    if isempty(hFig)
        return
    end
    % Operations specific to the type of event
    switch (evtType)
        case 'Onset'
            % Current time point should not be zero
            if isempty(GlobalData.UserTimeWindow.CurrentTime) || (GlobalData.UserTimeWindow.CurrentTime == 0)
                return;
            end
            % Reset time selection
            figure_timeseries('SetTimeSelectionLinked', hFig, []);
            strEvent = GlobalData.Guidelines.strOnset;
        case 'Baseline'
            % A time selection must be available
            GraphSelection = getappdata(hFig, 'GraphSelection');
            if isempty(GraphSelection) || any(isinf(GraphSelection))
                bst_error('You must select a time segment before setting it as the baseline.', 'Set event', 0);
                return;
            end
            strEvent = GlobalData.Guidelines.strBaseline;
    end
    % Set new onset marker
    panel_record('ToggleEvent', strEvent);
    % Save modifcations
    panel_record('SaveModifications', iDS);
    % Update panel
    UpdatePrepareRaw();
end


%% ===== RECORDINGS: SET BAD CHANNELS =====
function RawInputBadChannels(action)
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Get selected files
    iFiles = ctrl.jTableRaw.getSelectedRows()' + 1;
    if isempty(iFiles)
        return;
    end
    % Update the channel flags
    tree_set_channelflag(GlobalData.Guidelines.RawLinks(iFiles), action);
    % Update panel
    UpdatePrepareRaw();
end


%% ===== RECORDINGS: INPUT EVENT =====
function RawInputEvents()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Get selected files
    iFile = ctrl.jTableRaw.getSelectedRows()' + 1;
    if isempty(iFile)
        return;
    elseif (length(iFile) >= 2)
        iFile = iFile(1);
        ctrl.jTableRaw.getSelectionModel().setSelectionInterval(iFile - 1, iFile - 1);
    end
    % Close everything
    bst_memory('UnloadAll', 'Forced');
    % Load file
    LinkMat = in_bst_data(GlobalData.Guidelines.RawLinks{iFile});
    sFile = LinkMat.F;
    % Get existing event: Onset
    iEvtOnset = find(strcmpi({sFile.events.label}, GlobalData.Guidelines.strOnset));
    if ~isempty(iEvtOnset) && ~isempty(sFile.events(iEvtOnset).times)
        strOnset = sprintf('%1.4f', sFile.events(iEvtOnset).times(1));
    else
        strOnset = '';
    end
    % Get existing event: Baseline
    iEvtBaseline = find(strcmpi({sFile.events.label}, GlobalData.Guidelines.strBaseline));
    if ~isempty(iEvtBaseline) && ~isempty(sFile.events(iEvtBaseline).times)
        strBaseline1 = sprintf('%1.4f', sFile.events(iEvtBaseline).times(1,1));
        strBaseline2 = sprintf('%1.4f', sFile.events(iEvtBaseline).times(2,1));
    else
        strBaseline1 = '';
        strBaseline2 = '';
    end

    % Ask new values
    res = java_dialog('input', {'Onset (s):', 'Baseline begin (s):', 'Baseline end (s):'} , 'Fill holes', [], {strOnset, strBaseline1, strBaseline2});
    if isempty(res) || isequal(res, {strOnset, strBaseline1, strBaseline2})
        return;
    end
    % Get new values
    newOnset = str2num(res{1});
    newBaseline = [str2num(res{2}); str2num(res{3})];
    if (~isempty(res{1}) && (length(newOnset) ~= 1)) || (~isempty(res{2}) && ~isempty(res{3}) && (length(newBaseline) ~= 2))
        bst_error('Invalid entries.', 'Set events', 0);
        return;
    elseif any([newOnset;newBaseline] < sFile.prop.times(1)) || any([newOnset;newBaseline] > sFile.prop.times(2))
        bst_error('Times are not available for the selected file.', 'Set events', 0);
        return;
    end
    % If the structure of events is not available
    if ~isstruct(sFile.events)
        sFile.events = repmat(db_template('event'), 0);
    end
    % Add Onset event
    if (length(newOnset) == 1)
        if isempty(iEvtOnset)
            iEvtOnset = length(sFile.events) + 1;
            sFile.events(iEvtOnset).label      = GlobalData.Guidelines.strOnset;
            sFile.events(iEvtOnset).color      = [125 27 126] / 255;
            sFile.events(iEvtOnset).reactTimes = [];
            sFile.events(iEvtOnset).select     = 1;
        end
        sFile.events(iEvtOnset).times    = round(newOnset * sFile.prop.sfreq) ./ sFile.prop.sfreq;
        sFile.events(iEvtOnset).epochs   = ones(1, size(sFile.events(iEvtOnset).times, 2));
        sFile.events(iEvtOnset).channels = {{}};
        sFile.events(iEvtOnset).notes    = {''};
    end
    % Add Baseline event
    if (length(newBaseline) == 2)
        if isempty(iEvtBaseline)
            iEvtBaseline = length(sFile.events) + 1;
            sFile.events(iEvtBaseline).label      = GlobalData.Guidelines.strBaseline;
            sFile.events(iEvtBaseline).color      = [0 89 255] / 255;
            sFile.events(iEvtBaseline).reactTimes = [];
            sFile.events(iEvtBaseline).select     = 1;
        end
        sFile.events(iEvtBaseline).times   = round(newBaseline * sFile.prop.sfreq) ./ sFile.prop.sfreq;
        sFile.events(iEvtBaseline).epochs  = ones(1, size(sFile.events(iEvtBaseline).times, 2));
        sFile.events(iEvtBaseline).channels = {{}};
        sFile.events(iEvtBaseline).notes    = {''};
    end
    % Save modification
    LinkMat.F = sFile;
    bst_save(file_fullpath(GlobalData.Guidelines.RawLinks{iFile}), LinkMat, 'v7');
    % Update panel
    UpdatePrepareRaw();
end


%% ===== RECORDINGS: SET POSITION =====
function ButtonRawPos()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % If there are not files: exit
    if isempty(GlobalData.Guidelines.RawLinks)
        return;
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Ask how to define the contact positions
    res = java_dialog('question', [...
        '<HTML>How do you want to define the 3D positions of the SEEG contacts?<BR><BR>', ...
        '<B><U>Import</U></B>: &nbsp;&nbsp;Import from a file (subject or MNI coordinates)<BR>', ...
        '<B><U>Edit</U></B>: &nbsp;&nbsp;Define manually using the MRI viewer<BR><BR>'], ...
        'Set positions', [], {'Import', 'Edit'}, 'Import');
    if isempty(res)
        return;
    end
    % Get list of files to edit
    RawLinks = GlobalData.Guidelines.RawLinks;
    % Get selected files
    iSelFiles = ctrl.jTableRaw.getSelectedRows()' + 1;
    % If no or multiple files are selected: exit
    if isempty(iSelFiles) || (length(iSelFiles) == length(RawLinks))
        iRawFiles = 1:length(RawLinks);
    else
        iRawFiles = [iSelFiles, setdiff(1:length(RawLinks), iSelFiles)];
    end
    % Get the files that have the same list of channels as the first file in the selection
    iStudiesSet = [];
    ChanNames = {};
    AllChannelFiles = {};
    for iFile = iRawFiles
        % Get file in the database
        [sStudy, iStudy] = bst_get('DataFile', RawLinks{iFile});
        % Load channel file
        ChannelMat = in_bst_channel(sStudy.Channel(1).FileName);
        % Skip file if it has a different list of channel names
        if isempty(ChanNames)
            ChanNames = {ChannelMat.Channel.Name};
        elseif ~isequal(ChanNames, {ChannelMat.Channel.Name})
            continue;
        end
        % Add files to the process list
        AllChannelFiles{end+1} = sStudy.Channel(1).FileName;
        iStudiesSet = [iStudiesSet, iStudy];
    end
    
    % Process request
    switch (res)
        case 'Import'
            % Get 3D positions from an external file
            channel_add_loc(iStudiesSet, [], 1);
%             % Display 3D positions on the subject MRI
%             hFig = view_mri_3d(GlobalData.Guidelines.MriPost, [], .1, 'NewFigure');
%             view_channels(AllChannelFiles{1}, 'SEEG', 0, 0, hFig, 1);
%             figure_3d('ViewSensors', hFig, 0, 1);
            % Display 3D positions on the subject MRI
            view_channels_3d(AllChannelFiles{1}, 'SEEG', GlobalData.Guidelines.MriPost, 1);
        case 'Edit'
            % Edit channel file in MRI
            hFig = panel_ieeg('DisplayChannelsMri', AllChannelFiles{1}, 'SEEG', GlobalData.Guidelines.MriPost);
            % Wait for the editor to be closed
            waitfor(hFig);
            % Copy positions to the other files
            if (length(RawLinks) > 1)
                channel_add_loc(iStudiesSet(2:end), AllChannelFiles{1}, 1);
            end
    end
    % Update panel
    UpdatePrepareRaw();
end


%% ===== RECORDINGS: JTABLE KEY TYPE =====
function RawTableKeyTyped(hObj, ev)
    switch(uint8(ev.getKeyChar()))
        % DELETE
        case {ev.VK_DELETE, ev.VK_BACK_SPACE}
            ButtonRawDel();
    end
end

%% ===== RECORDINGS: JTABLE CLICKED =====
function RawTableClick(hObj, ev)
    import org.brainstorm.icon.*;
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Get selected files
    iSelFiles = ctrl.jTableRaw.getSelectedRows()' + 1;
    if isempty(iSelFiles)
        return;
    end
    % Double-click: Open recordings
    if (ev.getClickCount() > 1)
        ReviewFile(GlobalData.Guidelines.RawLinks{iSelFiles});
    % Right-click: Popup menu
    elseif (ev.getButton() == ev.BUTTON3)
        % Create popup menu
        jPopup = java_create('javax.swing.JPopupMenu');
        gui_component('MenuItem', jPopup, [], 'Mark some channels as bad...',  IconLoader.ICON_BAD,  [], @(h,ev)RawInputBadChannels('AddBad'));
        gui_component('MenuItem', jPopup, [], 'Mark some channels as good...', IconLoader.ICON_GOOD, [], @(h,ev)RawInputBadChannels('ClearBad'));
        gui_component('MenuItem', jPopup, [], 'Mark all channels as good',     IconLoader.ICON_GOOD, [], @(h,ev)RawInputBadChannels('ClearAllBad'));
        jPopup.addSeparator();
        % gui_component('MenuItem', jPopup, [], 'Set bad channels',       IconLoader.ICON_GOODBAD,       [], @(h,ev)RawInputBadChannels());
        gui_component('MenuItem', jPopup, [], 'Set onset and baseline', IconLoader.ICON_EVT_OCCUR_ADD, [], @(h,ev)RawInputEvents());
        % Show popup menu
        jPopup.pack();
        jPopup.show(ctrl.jTableRaw, ev.getPoint.getX(), ev.getPoint.getY());
    end
end

%% ===== RECORDINGS: REVIEW FILE =====
function ReviewFile(RawLink, isWait)
    % Parse inputs
    if (nargin < 2) || isempty(isWait)
        isWait = 1;
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Open recordings
    hFig = view_timeseries(RawLink, 'SEEG');
    % Select the "SEEG" montage by default
    sAllMontages = panel_montage('GetMontagesForFigure', hFig);
    iSelMontage = find(~cellfun(@(c)isempty(strfind(c,'SEEG (bipolar 2)')), {sAllMontages.Name}));
    if ~isempty(iSelMontage)
        panel_montage('SetCurrentMontage', hFig, sAllMontages(iSelMontage).Name);
    end
    % Blocking call
    if isWait
        % Wait for the end of this session
        waitfor(hFig);
        % Update table
        UpdatePrepareRaw();
    end
end



%% ==========================================================================================
%  ===== EPOCH ==============================================================================
%  ==========================================================================================

%% ===== EPOCH: VALIDATE =====
function [isValidated, errMsg] = ValidateEpoch()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Initialize returned variables
    isValidated = 0;
    errMsg = '';
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Get onset time window
    OnsetTimeRange = [str2double(char(ctrl.jTextEpochStart.getText())), ...
                      str2double(char(ctrl.jTextEpochStop.getText()))];
    % Get montage name
    if ctrl.jRadioMontageBip1.isSelected()
        MontageName = [GlobalData.Guidelines.SubjectName, ': SEEG (bipolar 1)[tmp]'];
    elseif ctrl.jRadioMontageBip2.isSelected()
        MontageName = [GlobalData.Guidelines.SubjectName, ': SEEG (bipolar 2)[tmp]'];
    else
        MontageName = [];
    end
    
    % Import the baselines and seizures
    nFiles = length(GlobalData.Guidelines.RawLinks);
    GlobalData.Guidelines.OnsetFiles    = cell(1, nFiles);
    GlobalData.Guidelines.BaselineFiles = cell(1, nFiles);
    for iFile = 1:nFiles
        % Get subject name
        sFile = bst_process('GetInputStruct', GlobalData.Guidelines.RawLinks{iFile});
        bst_report('Start', GlobalData.Guidelines.RawLinks{iFile});
        % Get corresponding imported folder
        studyName = strrep(bst_fileparts(sFile.FileName), '@raw', '');
        sStudyImport = [bst_get('StudyWithCondition', [studyName '_bipolar_2']), ...
                        bst_get('StudyWithCondition', [studyName '_bipolar_1']), ...
                        bst_get('StudyWithCondition', studyName)];
        if ~isempty(sStudyImport)
            iDataBaseline = find(~cellfun(@(c)isempty(strfind(lower(c),lower(GlobalData.Guidelines.strBaseline))), {sStudyImport(1).Data.FileName}));
            iDataOnset    = find(~cellfun(@(c)isempty(strfind(lower(c),lower(GlobalData.Guidelines.strOnset))),    {sStudyImport(1).Data.FileName}));
        else
            iDataBaseline = [];
            iDataOnset = [];
        end
        
        % === IMPORT BASELINE ===
        sFilesBaselines = [];
        if ~isempty(GlobalData.Guidelines.Baselines{iFile})
            % Baseline files already imported
            if (length(iDataBaseline) == size(GlobalData.Guidelines.Baselines{iFile},2))
                GlobalData.Guidelines.BaselineFiles{iFile} = {sStudyImport(1).Data(iDataBaseline).FileName};
            % Import baselines
            elseif isempty(iDataBaseline)
                sFilesBaselines = bst_process('CallProcess', 'process_import_data_event', sFile, [], ...
                    'subjectname', sFile.SubjectName, ...
                    'eventname',   GlobalData.Guidelines.strBaseline, ...
                    'timewindow',  [], ...
                    'createcond',  0, ...
                    'ignoreshort', 0, ...
                    'usessp',      1);
            % Error in list of input files
            else
                errMsg = ['The number of ' GlobalData.Guidelines.strBaseline ' events does not match the number of' 10 'imported baseline files in folder "' bst_fileparts(sStudyImport(1).FileName) '".' 10 10 'Reset this processing step before continuing.'];
                return;
            end
        end
        
        % === IMPORT ONSET ===
        sFilesOnsets = [];
        if ~isempty(GlobalData.Guidelines.Onsets{iFile})
            % Onset files already imported
            if (length(iDataOnset) == size(GlobalData.Guidelines.Onsets{iFile},2))
                GlobalData.Guidelines.OnsetFiles{iFile} = {sStudyImport(1).Data(iDataOnset).FileName};
            % Import onsets
            elseif isempty(iDataOnset)
                sFilesOnsets = bst_process('CallProcess', 'process_import_data_event', sFile, [], ...
                    'subjectname', sFile.SubjectName, ...
                    'eventname',   GlobalData.Guidelines.strOnset, ...
                    'epochtime',   OnsetTimeRange, ...
                    'timewindow',  [], ...
                    'createcond',  0, ...
                    'ignoreshort', 0, ...
                    'usessp',      1);
            % Error in list of input files
            else
                errMsg = ['The number of ' GlobalData.Guidelines.strOnset ' events does not match the number of' 10 'imported onset files in folder "' bst_fileparts(sStudyImport(1).FileName) '".' 10 10 'Reset this processing step before continuing.'];
                return;
            end
        end
        
        % === BIPOLAR MONTAGE ===
        % Apply montage if needed 
        if ~isempty(MontageName) && (~isempty(sFilesOnsets) || ~isempty(sFilesBaselines))
            % Apply montage (create new folders)
            sFilesBaselinesBip = bst_process('CallProcess', 'process_montage_apply', sFilesBaselines, [], ...
                'montage',    MontageName, ...
                'createchan', 1);
            sFilesOnsetsBip = bst_process('CallProcess', 'process_montage_apply', sFilesOnsets, [], ...
                'montage',    MontageName, ...
                'createchan', 1);
            % Delete original imported folder
            bst_process('CallProcess', 'process_delete', [sFilesBaselines, sFilesOnsets], [], 'target', 2);  % Delete folders
            % Replace files with bipolar versions
            sFilesBaselines = sFilesBaselinesBip;
            sFilesOnsets = sFilesOnsetsBip;
        end
        % Save file names for laters
        if ~isempty(sFilesBaselines)
            GlobalData.Guidelines.BaselineFiles{iFile} = {sFilesBaselines.FileName};
        end
        if ~isempty(sFilesOnsets)
            GlobalData.Guidelines.OnsetFiles{iFile} = {sFilesOnsets.FileName};
        end
    end
    
    % === UNIFORM LIST OF CHANNELS ===
    % Check if all the files have the same list of channels
    isEqualChanList = 1;
    AllFiles = cat(2, GlobalData.Guidelines.OnsetFiles{:}, GlobalData.Guidelines.BaselineFiles{:});
    ChanNames = {};
    for iFile = 1:length(AllFiles)
        % Get file in the database
        [sStudy, iStudy] = bst_get('DataFile', AllFiles{iFile});
        % Load channel file
        ChannelMat = in_bst_channel(sStudy.Channel(1).FileName);
        % Skip file if it has a different list of channel names
        if isempty(ChanNames)
            ChanNames = {ChannelMat.Channel.Name};
        elseif ~isequal(ChanNames, {ChannelMat.Channel.Name})
            isEqualChanList = 0;
            break;
        end
    end
    % If the channes are not the same: normalize them
    if ~isEqualChanList
        % Process: Uniform list of channels (remove extra)
        bst_process('CallProcess', 'process_stdchan', AllFiles, [], ...
            'method',  1);  % Keep only the common channel names=> Remove all the others
        % Warning
        java_dialog('warning', [...
            'The files you imported do not have the same list of contacts.' 10 10 ...
            'When computing the epileptogenicity maps using all the files, ' 10 ...
            'only the contacts common to all the files will be used.' 10 ... 
            'This may lead to a wrong interpretation of the results.' 10 10 ...
            'In order to use all the contacts for a given file, compute the', 10 ...
            'epileptogenicity maps separately for this file (no group results).'], 'Different channel files');
    end
    
    % Select first imported file in the database explorer 
    if ~isempty(GlobalData.Guidelines.OnsetFiles)
        [sStudySel, iStudySel] = bst_get('DataFile', GlobalData.Guidelines.OnsetFiles{1}{1});
        panel_protocols('SelectStudyNode', iStudySel);
    end
    isValidated = 1;
    bst_progress('stop');
end

%% ===== EPOCH: RESET =====
function ResetEpoch()
    global GlobalData;
    % Get subject name
    SubjectName = GlobalData.Guidelines.SubjectName;
    % Delete all the imported data for this subject
    if ~isempty(SubjectName)
        % Get subject
        sSubject = bst_get('Subject', SubjectName);
        % Get all the studies for this subject
        [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
        % Remove all the continuous recordings
        iDel = find(cellfun(@(c)isempty(strfind(c,'@raw')), {sStudies.FileName}));
        % Delete studies
        if ~isempty(iDel)
            % Ask confirmation
            if ~java_dialog('confirm', ['Remove all the epoched recordings from subject "' SubjectName '"?'])
                return;
            end
            % Delete data
            db_delete_studies(iStudies(iDel));
            % Update tree
            panel_protocols('UpdateTree');
        end
    end
    % Select first imported file in the database explorer
    if ~isempty(GlobalData.Guidelines.RawLinks)
        [sStudySel, iStudySel] = bst_get('DataFile', GlobalData.Guidelines.RawLinks{1});
        panel_protocols('SelectStudyNode', iStudySel);
    end
end



%% ==========================================================================================
%  ===== TIME-FREQ ==========================================================================
%  ==========================================================================================

%% ===== TIME-FREQ: VALIDATE =====
function [isValidated, errMsg] = ValidateTimefreq()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Initialize returned variables
    isValidated = 0;
    errMsg = '';
    % Get taper
    Taper = lower(char(ctrl.jComboTaper.getSelectedItem()));
    % Get frequencies
    strFreq = char(ctrl.jTextFreq.getText());
    if isempty(eval(strFreq))
        errMsg = 'Invalid frequency selection';
        return;
    end
    % Get the list of all input files
    OnsetFiles = cat(2, GlobalData.Guidelines.OnsetFiles{:});
    BaselineFiles = cat(2, GlobalData.Guidelines.BaselineFiles{:});
    % Number of baselines/onsets is not the same
    for i = 1:length(GlobalData.Guidelines.OnsetFiles)
        nBaselines = length(cat(2,GlobalData.Guidelines.BaselineFiles{i}));
        nOnsets    = length(cat(2,GlobalData.Guidelines.OnsetFiles{i}));
        if (nBaselines ~= nOnsets)
            [tmp,strFolder] = bst_fileparts(bst_fileparts(GlobalData.Guidelines.OnsetFiles{i}{1}));
            errMsg = ['Folder "' strFolder '" contains:' 10 ...
                      num2str(nBaselines) ' baseline(s) and ' num2str(nOnsets) ' seizure(s).' 10 10 ...
                      'To specify one baseline for each seizure, proceed manually as indicated' 10 ...
                      'in the online tutorial "SEEG epileptogenicity maps":' 10 ...
                      'https://neuroimage.usc.edu/brainstorm/Tutorials/Epileptogenicity'];
            return;
        end
    end
    % Check if all the files are in the same folder
    allFolders = cellfun(@bst_fileparts, OnsetFiles, 'UniformOutput', 0);
    isOneFolder = all(strcmpi(allFolders(2:end), allFolders{1}));
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    bst_report('Start', OnsetFiles);
    
    % Get the averages
    iFileAvg = [];
    iFileAvgChan = [];
    % Single file OR Multiple files in the same folder
    if (length(OnsetFiles) == 1) || isOneFolder
        [sStudy,iStudy,iTf] = bst_get('TimefreqForFile', GlobalData.Guidelines.OnsetFiles{1}{1});
        if ~isempty(iTf) && (length(sStudy.Timefreq) >= 2)
            if isOneFolder
                iFileAvg     = find(~cellfun(@(c)isempty(strfind(c, 'Multitaper')), {sStudy.Timefreq.Comment}) &  cellfun(@(c)isempty(strfind(c, 'row_mean')), {sStudy.Timefreq.Comment}), 1);
                iFileAvgChan = find(~cellfun(@(c)isempty(strfind(c, 'Multitaper')), {sStudy.Timefreq.Comment}) & ~cellfun(@(c)isempty(strfind(c, 'row_mean')), {sStudy.Timefreq.Comment}), 1);
            else
                iFileAvg     = find(~cellfun(@(c)isempty(strfind(c, GlobalData.Guidelines.strOnset)), {sStudy.Timefreq.Comment}) &  cellfun(@(c)isempty(strfind(c, 'row_mean')), {sStudy.Timefreq.Comment}), 1);
                iFileAvgChan = find(~cellfun(@(c)isempty(strfind(c, GlobalData.Guidelines.strOnset)), {sStudy.Timefreq.Comment}) & ~cellfun(@(c)isempty(strfind(c, 'row_mean')), {sStudy.Timefreq.Comment}), 1);
            end
        end
    % Mutliple files in different folders
    else
        % Get intra-subject folder
        [sSubject, iSubject] = bst_get('Subject', GlobalData.Guidelines.SubjectName);
        sStudy = bst_get('AnalysisIntraStudy', iSubject);
        if (length(sStudy.Timefreq) >= 2)
            iFileAvg     = find(~cellfun(@(c)isempty(strfind(c, GlobalData.Guidelines.strOnset)), {sStudy.Timefreq.Comment}) &  cellfun(@(c)isempty(strfind(c, 'row_mean')), {sStudy.Timefreq.Comment}), 1);
            iFileAvgChan = find(~cellfun(@(c)isempty(strfind(c, GlobalData.Guidelines.strOnset)), {sStudy.Timefreq.Comment}) & ~cellfun(@(c)isempty(strfind(c, 'row_mean')), {sStudy.Timefreq.Comment}), 1);
        end
    end
    % If the output files were found: use them
    if ~isempty(iFileAvg) && ~isempty(iFileAvgChan)
        TimefreqFileAvg = sStudy.Timefreq(iFileAvg).FileName;
        TimefreqFileAvgChan = sStudy.Timefreq(iFileAvgChan).FileName;
    % If files do not exist yet: compute them
    else
        % Process: FieldTrip: ft_mtmconvol (Multitaper)
        sFilesTf = bst_process('CallProcess', 'process_ft_mtmconvol', OnsetFiles, [], ...
            'timewindow',     [-10, 10], ...
            'sensortypes',    'SEEG', ...
            'mt_taper',       Taper, ... 
            'mt_frequencies', strFreq, ...
            'mt_freqmod',     10, ...
            'mt_timeres',     1, ...
            'mt_timestep',    0.1, ...
            'measure',        'magnitude', ...  % Magnitude
            'avgoutput',      0);
        % Process: FieldTrip: ft_mtmconvol (Multitaper)
        sFilesTfBaseline = bst_process('CallProcess', 'process_ft_mtmconvol', BaselineFiles, [], ...
            'timewindow',     [-10, 10], ...
            'sensortypes',    'SEEG', ...
            'mt_taper',       Taper, ... 
            'mt_frequencies', strFreq, ...
            'mt_freqmod',     10, ...
            'mt_timeres',     1, ...
            'mt_timestep',    0.1, ...
            'measure',        'magnitude', ...  % Magnitude
            'avgoutput',      0);
        if isempty(sFilesTf) || isempty(sFilesTfBaseline)
            bst_report('Open', 'current');
            errMsg = 'Could not run FieldTrip multitaper.';
            return;
        end
        % Process: Z-score transformation: [All file]
        for i = 1:length(sFilesTf)
            sFilesTfNorm(i) = bst_process('CallProcess', 'process_baseline_norm2', sFilesTfBaseline(i), sFilesTf(i), ...
                'baseline', [], ...
                'method',   'zscore');  % Z-score transformation:    x_std = (x - &mu;) / &sigma;
        end
        % Process: Average: Everything
        if (length(sFilesTfNorm) > 1)
            sFilesTfAvg = bst_process('CallProcess', 'process_average', sFilesTfNorm, [], ...
                'avgtype',   1, ...  % Everything
                'avg_func',  1, ...  % Arithmetic average:  mean(x)
                'weighted',  0, ...
                'matchrows', 1, ...
                'iszerobad', 1);
        else
            sFilesTfAvg = sFilesTfNorm;
        end
        % Process: Average: All signals
        sFilesTfAvgChan = bst_process('CallProcess', 'process_average_rows', sFilesTfAvg, [], ...
            'avgtype',   1, ...  % Average all the signals together
            'avgfunc',   1, ...  % Arithmetic average: mean(x)
            'overwrite', 0);
        % Process: Delete selected files
        sFilesTf = bst_process('CallProcess', 'process_delete', [sFilesTf, sFilesTfBaseline], [], ...
            'target', 1);  % Delete selected files
        % Return files
        TimefreqFileAvg     = sFilesTfAvg.FileName;
        TimefreqFileAvgChan = sFilesTfAvgChan.FileName;
    end
    % Set colormap
    bst_colormaps('SetColormapName', 'stat2', 'cmap_gin');
    % View average time-frequency file
    hFig1 = view_timefreq(TimefreqFileAvgChan, 'SingleSensor');
    hFig2 = view_timefreq(TimefreqFileAvg, 'AllSensors');
    % Smooth display
    panel_display('SetSmoothDisplay', 1);
    isValidated = 1;
end

%% ===== TIME-FREQ: RESET =====
function ResetTimefreq()
    global GlobalData;
    % Get subject name
    SubjectName = GlobalData.Guidelines.SubjectName;
    % Delete all the imported data for this subject
    if ~isempty(SubjectName)
        % Get subject
        sSubject = bst_get('Subject', SubjectName);
        % Get all the studies for this subject
        [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName, 'intra_subject');
        % Get all the time frequency files in all the folders
        TimefreqFiles = {};
        for i = 1:length(sStudies)
            % Skip raw folders
            if ~isempty(strfind(sStudies(i).FileName,'@raw'))
                continue;
            end
            % Get all the TF files available in this folder
            if ~isempty(sStudies(i).Timefreq)
                TimefreqFiles = cat(2, TimefreqFiles, {sStudies(i).Timefreq.FileName});
            end
        end
        % Delete files
        if ~isempty(TimefreqFiles)
            % Ask confirmation
            if ~java_dialog('confirm', sprintf('Remove %d time-frequency files from subject "%s"?', length(TimefreqFiles), SubjectName))
                return;
            end
            % Delete files
            bst_report('Start', TimefreqFiles);
            bst_process('CallProcess', 'process_delete', TimefreqFiles, [], ...
                'target', 1);  % Delete data files
            % Update tree
            panel_protocols('UpdateTree');
        end
    end
end

%% ===== TIME-FREQ: GET FREQ BAND =====
function GetFreqBand(jText)
    global GlobalData;
    % Get all time-frequency figures
    hFigs = bst_figures('GetFiguresByType', 'timefreq');
    if isempty(hFigs)
        bst_error('No time-frequency figure available.', 'Get frequency band', 0);
        return;
    end
    % Look for frequency selection
    iFreq = [];
    for i = 1:length(hFigs)
        GraphSelection = getappdata(hFigs(i), 'GraphSelection');
        if isequal(size(GraphSelection), [2 2]) && ~any(isnan(GraphSelection(:)))
            iFreq = GraphSelection(2,:);
            break;
        end
    end
    % Nothing was found
    if isempty(iFreq)
        bst_error('No time-frequency selection found in the figures.', 'Get frequency band', 0);
        return;
    end
    % Set corresponding field
    jText.setText(sprintf('[%d %d]', sort(round(GlobalData.UserFrequencies.Freqs(iFreq)))));
end



%% ==========================================================================================
%  ===== EPILEPTOGENICITY ===================================================================
%  ==========================================================================================

%% ===== EPILEPTOGENICIY: VALIDATE =====
function [isValidated, errMsg] = ValidateEpileptogenicity()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Initialize returned variables
    isValidated = 0;
    errMsg = '';
    % Get options
    FreqBand       = str2num(char(ctrl.jTextFreqBand.getText()));
    Latency        = char(ctrl.jTextLatency.getText());
    TimeConstant   = str2num(char(ctrl.jTextTimeConstant.getText()));
    TimeResolution = .2;
    % ThDelay        = 0.05;
    ThDelay        = str2num(char(ctrl.jTextThDelay.getText()));
    % Check inputs
    if (length(FreqBand) < 2)
        errMsg = 'Invalid frequency band.';
        return;
    elseif isempty(eval(Latency))
        errMsg = 'Invalid list of latencies.';
        return;
    elseif isempty(TimeConstant) || (TimeConstant <= 0)
        errMsg = 'Invalid time constant.';
        return;
    elseif isempty(TimeResolution) || (TimeResolution <= 0)
        errMsg = 'Invalid time resolution.';
        return;
    elseif isempty(ThDelay) || (ThDelay <= 0)
        errMsg = 'Invalid propagation threshold.';
        return;
    end
    % Get output type
    if ctrl.jRadioOutputVolume.isSelected()
        OutputType = 'volume';
    elseif ctrl.jRadioOutputSurface.isSelected()
        OutputType = 'surface';
    end
    % Get subject name
    SubjectName = GlobalData.Guidelines.SubjectName;
    if isempty(SubjectName)
        return
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');

    % Get selected files
    iFiles = find(GlobalData.Guidelines.ctrl.isFileSelected);
    % Get input files
    BaselineFiles = cat(2, GlobalData.Guidelines.BaselineFiles{:});
    OnsetFiles    = cat(2, GlobalData.Guidelines.OnsetFiles{:});
    % Number of baselines/onsets is not the same
    for i = 1:length(GlobalData.Guidelines.OnsetFiles)
        nBaselines = length(cat(2,GlobalData.Guidelines.BaselineFiles{i}));
        nOnsets    = length(cat(2,GlobalData.Guidelines.OnsetFiles{i}));
        if (nBaselines ~= nOnsets)
            [tmp,strFolder] = bst_fileparts(bst_fileparts(GlobalData.Guidelines.OnsetFiles{i}{1}));
            errMsg = ['Folder "' strFolder '" contains:' 10 ...
                      num2str(nBaselines) ' baseline(s) and ' num2str(nOnsets) ' seizure(s).' 10 10 ...
                      'To specify one baseline for each seizure, use the Process2 tab:' 10 ...
                      'Select all the baselines on the left and all the seizures on the right.'];
            return;
        end
    end
    % Process: Epileptogenicity index (A=Baseline,B=Seizure)
    bst_report('Start', BaselineFiles(iFiles));
    sFiles = bst_process('CallProcess', 'process_epileptogenicity', BaselineFiles(iFiles), OnsetFiles(iFiles), ...
        'sensortypes',    'SEEG', ...
        'freqband',       FreqBand, ...
        'latency',        Latency, ...
        'timeconstant',   TimeConstant, ...
        'timeresolution', TimeResolution, ...
        'thdelay',        ThDelay, ...
        'type',           OutputType);
    % Error handling
    if isempty(sFiles)
        errMsg = 'Could not compute epileptogenicity maps.';
        bst_report('Open', 'current');
        return;
    end
    
    % Get updated folder structure
    sStudy = bst_get('AnyFile', sFiles(1).FileName);
    % Get epileptogenicity maps
    if ~isempty(sStudy.Stat)
        iStat = find(~cellfun(@(c)isempty(strfind(c, '_Group_')), {sStudy.Stat.Comment}));
        if isempty(iStat)
            iStat = 1:length(sStudy.Stat);
        end
    else
        iStat = [];
    end
    % Get delay maps
    if ~isempty(sStudy.Result)
        iResult = find(cellfun(@(c)and((length(c)>6) && strcmpi(c(1:6), 'Delay_'), ~isempty(strfind(c, '_Group_'))), {sStudy.Result.Comment}));
        if isempty(iResult)
            iResult = 1:length(sStudy.Result);
        end
    else
        iResult = [];
    end
    % View epileptogenicity maps
    for i = 1:length(iStat)
        if strcmpi(OutputType, 'surface')
            view_surface_data([], sStudy.Stat(iStat(i)).FileName, 'SEEG');
        else
            sSubject = bst_get('Subject', SubjectName);
            hFig = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, sStudy.Stat(iStat(i)).FileName, 'SEEG');
            figure_mri('JumpMaximum', hFig);
        end
    end
    % View delay maps
    for i = 1:length(iResult)
        if strcmpi(OutputType, 'surface')
            hFig = view_surface_data([], sStudy.Result(iResult(i)).FileName, 'SEEG');
        else
            sSubject = bst_get('Subject', SubjectName);
            hFig = view_mri(sSubject.Anatomy(sSubject.iAnatomy).FileName, sStudy.Result(iResult(i)).FileName, 'SEEG');
        end
        % Set the data threshold to 0
        panel_surface('SetDataThreshold', hFig, 1, 0);
    end
end


%% ===== EPILEPTOGENICIY: RESET =====
function ResetEpileptogenicity()
    global GlobalData;
    % Get subject name
    SubjectName = GlobalData.Guidelines.SubjectName;
    ctrl = GlobalData.Guidelines.ctrl;
    % Get output type
    if ctrl.jRadioOutputVolume.isSelected()
        OutputType = 'volume';
    elseif ctrl.jRadioOutputSurface.isSelected()
        OutputType = 'surface';
    end
    % Delete the folder "Epileptogenicity" for this subject
    if ~isempty(SubjectName)
        % Default condition name
        Condition = ['Epileptogenicity_' OutputType];
        % Get condition asked by user
        [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(SubjectName, Condition));
        % If there are no files: nothing to do
        if isempty(iStudy) || (isempty(sStudy.Stat) && isempty(sStudy.Result))
            return;
        end
        % User confirmation
        if ~java_dialog('confirm', sprintf('Remove all the epileptogenicity maps (%d files)?', length(sStudy.Stat) + length(sStudy.Result)))
            return;
        end
        % Delete folder
        db_delete_studies(iStudy);
        % Update tree
        panel_protocols('UpdateTree');
    end
end

%% ===== EPILEPTOGENICIY: UPDATE =====
function UpdateEpileptogenicity()
    global GlobalData;
    % Initialize new list
    listModel = javax.swing.DefaultListModel();
    % All files selected by default
    GlobalData.Guidelines.ctrl.isFileSelected = ones(1, length(cat(2, GlobalData.Guidelines.OnsetFiles{:})));
    % Prepare tooltip string
    strTooltip = '<HTML><PRE>';
    % Get list of file names
    for iRaw = 1:length(GlobalData.Guidelines.OnsetFiles)
        % Skip if nothing is imported
        if isempty(GlobalData.Guidelines.OnsetFiles{iRaw})
            continue;
        end
        % Get the folder comment
        [tmp, strFolder] = bst_fileparts(bst_fileparts(GlobalData.Guidelines.OnsetFiles{iRaw}{1}));
        strFolder = strrep(strFolder, '_bipolar_2', '');
        strFolder = strrep(strFolder, '_bipolar_1', '');
        % Only one file
        if (length(GlobalData.Guidelines.OnsetFiles{iRaw}) == 1)
            listModel.addElement(org.brainstorm.list.BstListItem('', '', strFolder, int32(1)));
            % Create tooltip
            strTooltip = [strTooltip, '<B>' strFolder '</B>:<BR> - Onset: &nbsp;&nbsp;&nbsp;' GlobalData.Guidelines.OnsetFiles{iRaw}{1} '<BR>'];
            if (length(GlobalData.Guidelines.BaselineFiles{iRaw}) >= 1)
                strTooltip = [strTooltip, ' - Baseline: ' GlobalData.Guidelines.BaselineFiles{iRaw}{1} '<BR>'];
            else
                strTooltip = [strTooltip, ' - <B>ERROR: Missing baseline file']; 
            end
        else
            for iFile = 1:length(GlobalData.Guidelines.OnsetFiles{iRaw})
                strDispFolder = sprintf('%s #%d', strFolder, iFile);
                listModel.addElement(org.brainstorm.list.BstListItem('', '', strDispFolder, int32(1)));
                % Create tooltip
                strTooltip = [strTooltip, '<B>' strDispFolder '</B>:<BR> - Onset: &nbsp;&nbsp;&nbsp;' GlobalData.Guidelines.OnsetFiles{iRaw}{iFile} '<BR>'];
                if (length(GlobalData.Guidelines.BaselineFiles{iRaw}) >= iFile)
                    strTooltip = [strTooltip, ' - Baseline: ' GlobalData.Guidelines.BaselineFiles{iRaw}{iFile} '<BR>'];
                else
                    strTooltip = [strTooltip, ' - <B>ERROR: Missing baseline file']; 
                end
            end
        end
    end
    % Update JList
    GlobalData.Guidelines.ctrl.jListFiles.setModel(listModel);
    GlobalData.Guidelines.ctrl.jListFiles.repaint();
    GlobalData.Guidelines.ctrl.jListFiles.setToolTipText(strTooltip);
end


%% ===== EPILEPTOGENICITY: LIST CLICK CALLBACKS =====
function ListFilesClick_Callback(h,ev)
    global GlobalData;
    % Toggle checkbox status
    [iFile,Status] = panel_ssp_selection('ToggleCheck', ev);
    % Save list of selections
    GlobalData.Guidelines.ctrl.isFileSelected(iFile) = Status;
end


%% ==========================================================================================
%  ===== HELPER FUNCTIONS ===================================================================
%  ==========================================================================================

%% ===== FORMAT BASELINE =====
function strEvent = FormatEvent(evtTimes)
    strEvent = '';
    nEvt = size(evtTimes,2);
    for i = 1:nEvt
        if (size(evtTimes,1) == 1)
            strEvent = [strEvent, sprintf('%0.2f', evtTimes(1,i))];
        elseif (size(evtTimes,1) == 2)
            strEvent = [strEvent, sprintf('[%0.2f,%0.2f]', evtTimes(1,i), evtTimes(2,i))];
        end
        if (i < nEvt)
            strEvent = [strEvent, ','];
        end
    end
end


