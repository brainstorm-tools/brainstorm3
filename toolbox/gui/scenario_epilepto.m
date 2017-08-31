function varargout = scenario_epilepto( varargin )
% SCENARIO_EPILEPTO: Compute maps of epileptogenicity index with O David procedure.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
    import org.brainstorm.icon.*;
    import java.awt.*;
    import javax.swing.*;

    % Initialize global variables
    global GlobalData;
    GlobalData.Guidelines.SubjectName  = [];
    GlobalData.Guidelines.iSubject     = [];
    GlobalData.Guidelines.MriPre       = [];
    GlobalData.Guidelines.MriPost      = [];
    GlobalData.Guidelines.RawLinks     = {};
    GlobalData.Guidelines.RawFiles     = {};
    GlobalData.Guidelines.ChannelFiles = {};
    GlobalData.Guidelines.ChannelMats  = {};
    GlobalData.Guidelines.Baselines    = {};
    GlobalData.Guidelines.Onsets       = {};
    GlobalData.Guidelines.isPos        = {};
    
    % Initialize list of panels
    nPanels = 6;
    ctrl.jPanels = javaArray('javax.swing.JPanel', nPanels);
    ctrl.fcnValidate = cell(1, nPanels);
    ctrl.fcnReset    = cell(1, nPanels);
    ctrl.fcnUpdate   = cell(1, nPanels);
    % Get subjects in this protocol
    ProtocolSubjects = bst_get('ProtocolSubjects');
    
    % ===== PANEL: INTRODUCTION =====
    i = 1;
    ctrl.jPanels(i) = gui_river([3,3], [8,10,1,4], sprintf('Step #%d: Introduction', i));
    % Introduction
    gui_component('Label', ctrl.jPanels(i), 'hfill', ['<HTML>This pipeline is designed to help you compute maps of epileptogenicity index based on SEEG ictal recordings.<BR><BR>' ...
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
    ctrl.jComboSubj = gui_component('ComboBox', ctrl.jPanels(i), 'tab', [], {{'', ProtocolSubjects.Subject.Name}});
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
    % Help
    gui_component('Label', ctrl.jPanels(i), 'br', '<HTML><FONT color="#a0a0a0"><I>MRI or CT in DICOM format: Convert them to .nii with MRIcron.</I></FONT>');
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
    gui_component('Label', ctrl.jPanels(i), '', 'Seizure onset evaluation window:');
    % Time range : start
    ctrl.jTextEpochStart = gui_component('texttime', ctrl.jPanels(i), '', ' ');
    gui_component('label',  ctrl.jPanels(i), [], ' - ');
    ctrl.jTextEpochStop = gui_component('texttime',  ctrl.jPanels(i), [], ' ');
    % Set time controls callbacks
    TimeUnit = gui_validate_text(ctrl.jTextEpochStart, [], ctrl.jTextEpochStop, {-100, 100, 1000}, 's', [], -10, []);
    TimeUnit = gui_validate_text(ctrl.jTextEpochStop, ctrl.jTextEpochStart, [], {-100, 100, 1000}, 's', [], 10, []);
    % Add unit label
    gui_component('label',  ctrl.jPanels(i), [], [' ' TimeUnit]);
    % Callbacks
    ctrl.fcnValidate{i} = @(c)ValidateEpoch();
    ctrl.fcnReset{i}    = @(c)ResetEpoch();
    ctrl.fcnUpdate{i}   = @(c)UpdateEpoch();
    
    % ===== PANEL: TIME-FREQUENCY =====
    i = i + 1;
    ctrl.jPanels(i) = gui_river([3,3], [8,10,1,4], sprintf('Step #%d: Compute time-frequency', i));
    gui_component('Label', ctrl.jPanels(i), '', 'Compute time-frequency');
    
    
    % ===== PANEL: EPILEPTOGENICITY =====
    i = i + 1;
    ctrl.jPanels(i) = gui_river([3,3], [8,10,1,4], sprintf('Step #%d: Compute epileptogenicity', i));
    gui_component('Label', ctrl.jPanels(i), '', 'Epileptogenicity maps');
    
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
    end
    
    % === IMPORT MRI VOLUMES ===
    % Anatomy folder
    AnatDir = bst_fileparts(file_fullpath(sSubject.FileName));
    MriPre  = fullfile(AnatDir, 'subjectimage_pre.mat');
    MriPost = fullfile(AnatDir, 'subjectimage_post.mat');
    % Check if there are already two volumes in the subject
    if ~file_exist(MriPre) || ~file_exist(MriPost)
        % MRI files
        if isempty(MriFilePre) || isempty(MriFilePost)
            errMsg = ['You must select the pre- and post-implantation scans for subject "' SubjectName '".'];
            return;
        end
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
        [sMriPost, errMsg] = bst_normalize_mni(DbMriFilePost);
        if ~isempty(errMsg)
            errMsg = ['Cannot normalize post-implantation volume: "' 10 errMsg '".'];
            return;
        end
        % Volumes are not registered: Register and reslice
        if ~isRegistered
            % Register and reslice
            [DbMriFilePostReg, errMsg] = mri_coregister(DbMriFilePost, DbMriFilePre);
        % Volumes are registered: Reslice only
        else
            % Get the .nii transformation in both volumes
            iTransfPre  = find(strcmpi(sMriPre.InitTransf(:,1),  'vox2ras'));
            iTransfPost = find(strcmpi(sMriPost.InitTransf(:,1), 'vox2ras'));
            if (isempty(iTransfPre) || isempty(iTransfPost)) && (~isequal(size(sMriPre.Cube), size(sMriPost.Cube)) || ~isequal(sMriPre.Voxsize, sMriPost.Voxsize))
                errMsg = 'The pre and post volumes are not registered or were not initially in .nii format.';
                return;
            end
            % Reslice the "post" volume
            [DbMriFilePostReg, errMsg] = mri_coregister(DbMriFilePost, DbMriFilePre, sMriPost.InitTransf{iTransfPost(1),2}, sMriPre.InitTransf{iTransfPre(1),2});
        end

        % === RE-ORGANIZE FILES ===
        % Get updated subject structure
        [sSubject, iSubject] = bst_get('Subject', SubjectName);
        % Delete non-registered post MRI
        file_delete(DbMriFilePost, 1);
        sSubject.Anatomy(2) = [];
        % Rename imported volumes
        movefile(file_fullpath(DbMriFilePre), MriPre);
        movefile(file_fullpath(DbMriFilePostReg), MriPost);
        sSubject.Anatomy(1).FileName = file_short(MriPre);
        sSubject.Anatomy(2).FileName = file_short(MriPost);
        % Update database
        bst_set('Subject', iSubject, sSubject);
        panel_protocols('UpdateNode', 'Subject', iSubject);
    end
    % Save for later
    GlobalData.Guidelines.SubjectName = SubjectName;
    GlobalData.Guidelines.iSubject    = iSubject;
    GlobalData.Guidelines.MriPre      = MriPre;
    GlobalData.Guidelines.MriPost     = MriPost;
    
    % === DISPLAY RESULT ===
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Open the post volume as an overlay of the pre volume
    hFig = view_mri(MriPre, MriPost);
    % Set the amplitude threshold to 50%
    panel_surface('SetDataThreshold', hFig, 1, 0.3);
    % Select surface tab
    gui_brainstorm('SetSelectedTab', 'Surface');
    
    % Panel is validated
    isValidated = 1;
end

%% ===== IMPORT ANATOMY: RESET =====
function ResetImportAnatomy()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Get subject name
    SubjectName = GlobalData.Guidelines.SubjectName;
    iSubject    = GlobalData.Guidelines.iSubject;
    if ~isempty(SubjectName)
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
    ctrl.jComboSubj.setSelectedItem([]);
    ctrl.jTextMriPre.setText('');
    ctrl.jTextMriPost.setText('');
    ctrl.jCheckRegistered.setSelected(0);
end

%% ===== IMPORT ANATOMY: UPDATE =====
function [isValidated, errMsg] = UpdateImportAnatomy()
    % Initialize returned variables
    isValidated = 1;
    errMsg = '';
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    % Display the anatomy of the subjects
    gui_brainstorm('SetExplorationMode', 'Subjects');
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
    elseif all(cellfun(@isempty, GlobalData.Guidelines.Baselines))
        errMsg = 'You must identify at least one seizure with an "Onset" event.';
        return;
    elseif all(cellfun(@isempty, GlobalData.Guidelines.Onsets))
        errMsg = 'You must identify at least one baseline period in the select files.';
        return;
    elseif any(cellfun(@isempty, GlobalData.Guidelines.Onsets) & cellfun(@isempty, GlobalData.Guidelines.Baselines))
        errMsg = ['All the files must include an event of interest (seizure onset or baseline).' 10 'Remove the files that are not used.'];
        return;
    elseif ~all(GlobalData.Guidelines.isPos)
        errMsg = 'You must set the 3D position of all the SEEG contacts in all the selected files.';
        return;
    end
    isValidated = 1;
end

%% ===== PREPARE RECORDINGS: RESET =====
function ResetPrepareRaw()
    global GlobalData;
    % Get subject name
    SubjectName = GlobalData.Guidelines.SubjectName;
    iSubject    = GlobalData.Guidelines.iSubject;
    % Delete all the data for this subject
    if ~isempty(iSubject)
        % Get subject
        sSubject = bst_get('Subject', iSubject);
        % Get all the studies for this subject
        [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
        % Delete studies
        if ~isempty(iStudies)
            % Ask confirmation
            if ~java_dialog('confirm', ['Remove all the recordings from subject "' SubjectName '"?'])
                return;
            end
            % Delete data
            db_delete_studies(iStudies);
            % Update tree
            panel_protocols('UpdateTree');
        end
    end
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
    % Display the anatomy of the subjects
    gui_brainstorm('SetExplorationMode', 'StudiesSubj');
    % Column names
    columnNames = {'Path', 'File', '#', '3D', 'Bad', 'Onset', 'Baseline'};
    % Progress bar
    bst_progress('start', 'Import recordings', 'Loading...');
    
    % === GET LIST OF RAW FILES ===
    % Get list of raw files for this subject
    RawLinks = {};
    GlobalData.Guidelines.ChannelFiles = {};
    GlobalData.Guidelines.ChannelMats  = {};
    if ~isempty(GlobalData.Guidelines.iSubject)
        % Get subject index
        sSubject = bst_get('Subject', GlobalData.Guidelines.iSubject);
        % Get all the folders for this subject
        [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
        % Get all the raw files in this study
        if ~isempty(iStudies)
            [iDataStudies, iDataFiles] = bst_get('DataForStudies', iStudies);
            for i = 1:length(iDataStudies)
                sDataStudy = bst_get('Study', iDataStudies(i));
                if strcmpi(sDataStudy.Data(iDataFiles(i)).DataType, 'raw')
                    RawLinks{end+1} = sDataStudy.Data(iDataFiles(i)).FileName;
                    % Load channel file
                    GlobalData.Guidelines.ChannelFiles{end+1} = sDataStudy.Channel(1).FileName;
                    GlobalData.Guidelines.ChannelMats{end+1}  = in_bst_channel(sDataStudy.Channel(1).FileName);
                end
            end
        end
    end
    GlobalData.Guidelines.RawLinks  = RawLinks;
    GlobalData.Guidelines.Baselines = cell(size(RawLinks));
    GlobalData.Guidelines.Onsets    = cell(size(RawLinks));
    GlobalData.Guidelines.isPos     = zeros(size(RawLinks));

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
            iEvtOnset = find(strcmpi({sFile.events.label}, 'onset'));
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
            iEvtBaseline = find(strcmpi({sFile.events.label}, 'baseline'));
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
    OutputFiles = import_raw(RawFiles, FileFormat, GlobalData.Guidelines.iSubject);
    AllChannelFiles = {};
    % Edit output channel files: set the channels to SEEG
    for iFile = 1:length(OutputFiles)
        % Get channel file
        ChannelFile = bst_get('ChannelFileForStudy', OutputFiles{iFile});
        % Load channel file
        ChannelMat = in_bst_channel(ChannelFile);        
        % Get channels classified as EEG
        iEEG = channel_find(ChannelMat.Channel, 'EEG,SEEG,ECOG,ECG,EKG');
        % If there are no channels classified at EEG, take all the channels
        if isempty(iEEG)
            disp('Warning: No EEG channels identified, trying to use all the channels...');
            iEEG = 1:length(ChannelMat.Channel);
        end
        % Detect channels of interest
        [iSelEeg, iEcg] = ImaGIN_select_channels({ChannelMat.Channel(iEEG).Name}, 1);
        % Set channels as SEEG
        if ~isempty(iSelEeg)
            [ChannelMat.Channel(iEEG(iSelEeg)).Type] = deal('SEEG');
        end
        if ~isempty(iEcg)
            [ChannelMat.Channel(iEEG(iEcg)).Type] = deal('ECG');
        end
        % Save modified file
        bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
        % Save channel files
        AllChannelFiles{end+1} = ChannelFile;
    end
    % Save file format
    UpdatePrepareRaw();
    % Edit channel files
    ButtonRawEditChannel(OutputFiles);
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
        % Update panel
        UpdatePrepareRaw();
    end
    % Add a hook to capture when the channel editor is closed
    if (length(RawLinks) > 1)
        java_setcb(jFrame, 'WindowClosingCallback', @(h,ev)ChannelEditorClosed_Callback());
    end
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
function ButtonRawEvent(strEvent)
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
    switch (strEvent)
        case 'Onset'
            % Reset time selection
            figure_timeseries('SetTimeSelectionLinked', hFig, []);
            % Delete existing markers
            if ~isempty(panel_record('GetEvents', strEvent))
                panel_record('EventTypeDel', strEvent, 1);
            end
        case 'Baseline'
            % A time selection must be available
            GraphSelection = getappdata(hFig, 'GraphSelection');
            if isempty(GraphSelection) || any(isinf(GraphSelection))
                bst_error('You must select a time segment before setting it as the baseline.', 'Set event', 0);
                return;
            end
    end
    % Set new onset marker
    panel_record('ToggleEvent', strEvent);
    % Save modifcations
    panel_record('SaveModifications', iDS);
    
%     % Get file index
%     iFile = find(strcmpi(GlobalData.DataSet(iDS).DataFile, GlobalData.Guidelines.RawLinks));
%     if isempty(iFile)
%         disp('Error: File not found... Reload the Guidelines tab.');
%         return;
%     end
%     % Format event times
%     sEvt = panel_record('GetEvents', 'Onset');
%     strEvent = FormatEvent(sEvt.times);
%     % Update guidelines table
%     ctrl.jTableRaw.getModel().setValueAt(java.lang.String(strEvent), iFile-1, 5);
%     % DOESN'T WORK TWICE??? WHY???

    % Update panel
    UpdatePrepareRaw();
end


%% ===== RECORDINGS: SET POSITION =====
function ButtonRawPos()
    global GlobalData;
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
        'Set positions', [], {'Import', 'Edit'}, 'Edit');
    if isempty(res)
        return;
    end

    % Get list of files to edit
    RawLinks = GlobalData.Guidelines.RawLinks;
    iStudiesSet = [];
    AllChanNames = {};
    AllChannelMats = {};
    for iFile = 1:length(RawLinks)
        % Get file in the database
        [sStudy, iStudy] = bst_get('DataFile', RawLinks{iFile});
        iStudiesSet = [iStudiesSet, iStudy];
        % Load channel file
        AllChannelMats{iFile} = in_bst_channel(sStudy.Channel(1).FileName);
        % Get channel names
        AllChanNames = union(AllChanNames, {AllChannelMats{iFile}.Channel.Name});
    end
    
    % Process request
    switch (res)
        case 'Import'
            % Get 3D positions from an external file
            channel_add_loc(iStudiesSet, [], 1);
        case 'Edit'
            
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
%     import org.brainstorm.icon.*;
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
    elseif (ev.getButton() > 1)
%         % Create popup menu
%         jPopup = java_create('javax.swing.JPopupMenu');
%         % Add menus
%         gui_component('MenuItem', jPopup, [], 'Set channel type', IconLoader.ICON_CHANNEL, [], @(h,ev)SetChannelsField('type'), []);
%         gui_component('MenuItem', jPopup, [], 'Set channel group', IconLoader.ICON_CHANNEL, [], @(h,ev)SetChannelsField('group'), []);
%         gui_component('MenuItem', jPopup, [], 'Set channel comment', IconLoader.ICON_CHANNEL, [], @(h,ev)SetChannelsField('comment'), []);
%         % Show popup menu
%         jPopup.pack();
%         jPopup.show(jTableChannel, ev.getPoint.getX(), ev.getPoint.getY());
    end
end

%% ===== RECORDINGS: REVIEW FILE =====
function ReviewFile(RawLink)
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
    % Wait for the end of this session
    waitfor(hFig);
    % Update table
    UpdatePrepareRaw();
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
    % Get onset time window
    OnsetTimeRange = [str2double(char(ctrl.jTextEpochStart.getText())), ...
                      str2double(char(ctrl.jTextEpochStop.getText()))];
    % Import the baselines and seizures
    nFiles = length(GlobalData.Guidelines.RawLinks);
    GlobalData.Guidelines.OnsetFiles    = cell(1, nFiles);
    GlobalData.Guidelines.BaselineFiles = cell(1, nFiles);
    for iFile = 1:nFiles
        % Get subject name
        sFile = bst_process('GetInputStruct', GlobalData.Guidelines.RawLinks{iFile});
        % Get corresponding imported folder
        sStudyImport = bst_get('StudyWithCondition', strrep(bst_fileparts(sFile.FileName), '@raw', ''));
        if ~isempty(sStudyImport)
            iDataBaseline = find(~cellfun(@(c)isempty(strfind(c,'Baseline')), {sStudyImport.Data.FileName}));
            iDataOnset    = find(~cellfun(@(c)isempty(strfind(c,'Onset')),    {sStudyImport.Data.FileName}));
        else
            iDataBaseline = [];
            iDataOnset = [];
        end
        % Baseline files already imported
        if (length(iDataBaseline) == size(GlobalData.Guidelines.Baselines{iFile},2))
            GlobalData.Guidelines.BaselineFiles{iFile} = {sStudyImport.Data(iDataBaseline).FileName};
        % Import baselines
        elseif ~isempty(GlobalData.Guidelines.Baselines{iFile})
            sFilesBaselines = bst_process('CallProcess', 'process_import_data_event', sFile, [], ...
                'subjectname', sFile.SubjectName, ...
                'eventname',   'Baseline', ...
                'timewindow',  [], ...
                'createcond',  0, ...
                'ignoreshort', 0, ...
                'usessp',      1);
            GlobalData.Guidelines.BaselineFiles{iFile} = {sFilesBaselines.FileName};
        end
        % Onset files already imported
        if (length(iDataOnset) == length(GlobalData.Guidelines.Onsets{iFile}))
            GlobalData.Guidelines.OnsetFiles{iFile} = {sStudyImport.Data(iDataOnset).FileName};
        % Import onsets
        elseif ~isempty(GlobalData.Guidelines.Onsets{iFile})
            sFilesOnsets = bst_process('CallProcess', 'process_import_data_event', sFile, [], ...
                'subjectname', sFile.SubjectName, ...
                'eventname',   'Onset', ...
                'epochtime',   OnsetTimeRange, ...
                'timewindow',  [], ...
                'createcond',  0, ...
                'ignoreshort', 0, ...
                'usessp',      1);
            GlobalData.Guidelines.OnsetFiles{iFile} = {sFilesOnsets.FileName};
        end
    end
    isValidated = 1;
end

%% ===== PREPARE RECORDINGS: RESET =====
function ResetEpoch()
    global GlobalData;
    % Get subject name
    SubjectName = GlobalData.Guidelines.SubjectName;
    iSubject    = GlobalData.Guidelines.iSubject;
    % Delete all the imported data for this subject
    if ~isempty(iSubject)
        % Get subject
        sSubject = bst_get('Subject', iSubject);
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
end

%% ===== PREPARE RECORDINGS: UPDATE =====
function UpdateEpoch()
    
end



%% ==========================================================================================
%  ===== HELPER FUNCTIONS ===================================================================
%  ==========================================================================================

%% ===== SELECT SUBJECT =====
function SelectSubject()
    global GlobalData;
    ctrl = GlobalData.Guidelines.ctrl;
    % Get subject
    SubjectName = char(ctrl.jComboSubj.getSelectedItem());
    sSubject = bst_get('Subject', SubjectName);
    % Select subject node in the database explorer 
    panel_protocols('SelectSubject', SubjectName);
    % Anatomy folder
    AnatDir = bst_fileparts(file_fullpath(sSubject.FileName));
    MriPre  = fullfile(AnatDir, 'subjectimage_pre.mat');
    MriPost = fullfile(AnatDir, 'subjectimage_post.mat');
    % Check if there are already two volumes in the subject
    if file_exist(MriPre) && file_exist(MriPost)
        ctrl.jTextMriPre.setText(sSubject.Anatomy(1).Comment);
        ctrl.jTextMriPost.setText(sSubject.Anatomy(2).Comment);
    end
end

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


