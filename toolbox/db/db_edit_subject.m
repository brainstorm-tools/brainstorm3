function iSubject = db_edit_subject(varargin)
% DB_EDIT_SUBJECT: Open a dialog to edit or create a subject.
%
% USAGE: iSubject = db_edit_subject()         : edit a subject, create it and return its index
%        iSubject = db_edit_subject(iSubject) : edit an existing subject (index #iSubject in ProtocolStudies)

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
% Authors: Francois Tadel, 2008-2011

iSubject  = [];

%% ===== PARSE INPUTS =====
% Get ProtocolSubjects structure 
ProtocolInfo = bst_get('ProtocolInfo');
ProtocolSubjects = bst_get('ProtocolSubjects');
if isempty(ProtocolSubjects)
    error('No selected protocol'); 
end
nbSubjects = length(ProtocolSubjects.Subject);
% Get subject to edit (parse inputs)
if (nargin == 0)
    iSubjectsList = nbSubjects + 1;
elseif (nargin == 1)
    iSubjectsList = varargin{1};
    if (iSubjectsList <= 0)
        error('Subject #%d does not exist.', iSubjectsList);
    end
else
    error('Usage : db_edit_subject([iSubject])');
end


%% ===== DISPLAY "SUBJECT EDITOR" WINDOW =====
% Create Subject editor panel
panelSubjectEditor = panel_subject_editor('CreatePanel');
% Get handles to panel objects
ctrl = get(panelSubjectEditor, 'sControls');

% Set the 'Save' button callback
java_setcb(ctrl.jButtonSave, 'ActionPerformedCallback', @updateSubjectModifications);
% Show panel
panelContainer = gui_show(panelSubjectEditor, 'JavaWindow', 'Edit subject', [], 1, 0, 0);

% Start with the first subject of the list to edit
iSubject = iSubjectsList(1);
UpdatePanel();



%% =================================================================================
%  === CALLBACKS  ==================================================================
%  =================================================================================
%% ===== UPDATE PANEL FOR A GIVEN SUBJECT =====
    function UpdatePanel()
        % Get subject
        nbSubjects = bst_get('SubjectCount');
        isNewSubject = (iSubject > nbSubjects);
        sDefaultSubject = bst_get('Subject', 0);
        
        % EDITING EXISTING SUBJECT
        if ~isNewSubject
            panelTitle = sprintf('Edit subject #%d',iSubject);
            % Get subject
            sSubject = bst_get('Subject', iSubject, 1);
        % NEW SUBJECT
        else
            panelTitle = sprintf('Create subject #%d',iSubject);
            % Create new subject subject
            sSubject = db_template('Subject');
            sSubject.Name     = sprintf('Subject%02d', iSubject);
            sSubject.FileName = bst_fullfile(sprintf('Subject%02d', iSubject), 'brainstormsubject.mat');
            % Get subjects defaults from protocol
            sSubject.UseDefaultAnat    = ProtocolInfo.UseDefaultAnat;
            sSubject.UseDefaultChannel = ProtocolInfo.UseDefaultChannel;
        end

        % Window title
        panelContainer.handle{1}.setTitle(panelTitle);
        % Subject description
        ctrl.jTextSubjectName.setText(sSubject.Name);
        ctrl.jTextSubjectComments.setText(sSubject.Comments);
        % Default anatomy 
        if (~isfield(sSubject, 'UseDefaultAnat') || ~sSubject.UseDefaultAnat) || isempty(sDefaultSubject)
            ctrl.jRadioAnatomyIndividual.setSelected(1);
        else
            ctrl.jRadioAnatomyDefault.setSelected(1);
        end
        % Default channel + headmodel
        if (~isfield(sSubject, 'UseDefaultChannel') || (sSubject.UseDefaultChannel == 0))
            ctrl.jRadioChannelIndividual.setSelected(1);
        elseif (sSubject.UseDefaultChannel == 1)
            ctrl.jRadioChannelDefaultSubject.setSelected(1);
        elseif (sSubject.UseDefaultChannel == 2)
            ctrl.jRadioChannelDefaultGlobal.setSelected(1);
        end

        % If no protocol's default subject is available 
        % => Disable "Use protocol default" radio button for anatomy
        if isempty(sDefaultSubject)
            ctrl.jRadioAnatomyDefault.setEnabled(0);
        end
    end

        
%% ===== SAVE button : Update subject modifications =====
    function updateSubjectModifications(varargin)       
        % ==== GET INPUTS ====
        % Is it a new subject?
        nbSubjects = bst_get('SubjectCount');
        isNewSubject = (iSubject > nbSubjects);
        % Create subject structure
        if isNewSubject
            sSubject = db_template('Subject');
        else
            sOldSubject = bst_get('Subject', iSubject);
            sSubject = sOldSubject;
        end
        % Subject name, filename, comments
        sSubject.Name     = char(ctrl.jTextSubjectName.getText());
        sSubject.FileName = [sSubject.Name, '/brainstormsubject.mat'];
        sSubject.Comments = char(ctrl.jTextSubjectComments.getText());
        % Anatomy class (defaults or individual)
        sSubject.UseDefaultAnat = ctrl.jRadioAnatomyDefault.isSelected();
        % Channel/Headmodel class (defaults or individual)
        if ctrl.jRadioChannelIndividual.isSelected()
            sSubject.UseDefaultChannel = 0;
        elseif ctrl.jRadioChannelDefaultSubject.isSelected()
            sSubject.UseDefaultChannel = 1;
        elseif ctrl.jRadioChannelDefaultGlobal.isSelected()
            sSubject.UseDefaultChannel = 2;
        end
        
        % ==== CHECK INPUTS ====
        % SubjectName Do not accept a blank subject name
        if isempty(sSubject.Name)
            bst_error('You must specify a subject name.', 'Subject editor', 0);
            return
        end
        % Force the subject name to be compatible with the filesystem
        stdName = file_standardize(sSubject.Name);
        if ~strcmpi(stdName, sSubject.Name)
            ctrl.jTextSubjectName.setText(stdName);
            return
        end
        % Check for existing subject
        if ~isNewSubject && ~strcmpi(sOldSubject.Name, sSubject.Name) && file_exist(bst_fullfile(ProtocolInfo.SUBJECTS, sSubject.Name))
            bst_error(['Subject "' sSubject.Name '" already exists.'], 'Subject editor', 0);
            return
        end

        % ==== CLOSE PANEL ====
        % Close 'Subject Editor' panel
        gui_hide('panel_subject_editor');
        
        % ==== ADD SUBJECT ====
        % Create a new subject
        if isNewSubject
            sSubject = db_add_subject(sSubject, iSubject);
            if isempty(sSubject)
                bst_error('Subject could not be created.', 'Subject editor', 0);
                return
            end
        % ==== EDIT SUBJECT ====
        else
            % Get studies where there should be channel files for this subject
            iOldChannelStudies = bst_get('ChannelStudiesWithSubject', iSubject, 'NoIntra');
            % Normalization required
            if (sOldSubject.UseDefaultChannel < sSubject.UseDefaultChannel) && (length(iOldChannelStudies) > 1)
                % Ask user the confirmation
                isOk = java_dialog('confirm', ...
                    ['Grouping several channel files into one requires a co-registration of the runs or subjects.' 10 ...
                     'This is done by calling the process "Co-register MEG runs".' 10 10 ...
                     'Apply this co-registration now?'], 'Edit subject');
                if isOk 
                    % Perform registration
                    RegisterMegRuns(iOldChannelStudies);
                end
            end
            % If subject name was changed
            if ~strcmpi(sOldSubject.Name, sSubject.Name)
                % Rename subject
                db_rename_subject(sOldSubject.Name, sSubject.Name);
                % Get subject again (database was reloaded)
                [sOldSubject, iSubject] = bst_get('Subject', sSubject.Name);
            end
            % Save new subject
            sSubject = db_add_subject(sSubject, iSubject);
            % Update channel files
            if (sSubject.UseDefaultChannel ~= sOldSubject.UseDefaultChannel)
                % Get studies where there should be channel files for this subject
                iNewChannelStudies = bst_get('ChannelStudiesWithSubject', iSubject);
                % Update channel files
                UpdateSubjectChannelFiles(sOldSubject.UseDefaultChannel, iOldChannelStudies, sSubject.UseDefaultChannel, iNewChannelStudies);
                % Update results links
                db_links('Subject', iSubject);
            end
        end
        
        % ==== UPDATE TREE ====
        % Unload everything
        bst_memory('UnloadAll', 'Forced');
        % Reload database
        db_reload_subjects(iSubject);
        panel_protocols('UpdateTree');
        % Save database
        db_save();
    end        
end


%% ===== UPDATE CHANNEL FILES =====
function UpdateSubjectChannelFiles(oldStat, iOldChanStudy, newStat, iNewChanStudy)
    % Different cases: 
    % 1) One channel file per subject => One channel file per study   (1=>0)
    %    One global channel file      => One channel file per study   (2=>0)
    %    One global channel file      => One channel file per subject (2=>1)
    % => Distribute the shared channel file to all the subject's studies
    if (oldStat > newStat) 
        % Get source study
        sSourceStudy = bst_get('Study', iOldChanStudy);
        % Get destination study
        sNewChanStudy = bst_get('Study', iNewChanStudy);
        % If no channel initially: nothing to do
        if isempty(sSourceStudy.Channel)
            return
        end
        % Else: copy channel file
        for i = 1:length(iNewChanStudy)
            % If there is no data is this study: skip
            if isempty(sNewChanStudy(i).Data) && isempty(sNewChanStudy(i).Result) && isempty(sNewChanStudy(i).Stat) && isempty(sNewChanStudy(i).Timefreq) && isempty(sNewChanStudy(i).Matrix)
                continue;
            end
            % Copy channel file to destination study
            db_set_channel(iNewChanStudy(i), sSourceStudy.Channel(1).FileName, 0, 0);
        end
        
    % 2) One channel file per study   => One channel file per subject (0=>1)
    %    One channel file per study   => One global channel file      (0=>2)
    %    One channel file per subject => One global channel file      (1=>2)
    else
        % Progress bar
        bst_progress('start', 'Setting channel files...', 'Subject editor');
        % Get all the channel files to consider
        allChannelFiles = {};
        for i = 1:length(iOldChanStudy)
            sStudy = bst_get('Study', iOldChanStudy(i));
            if ~isempty(sStudy.Channel) && ~isempty(sStudy.Channel.FileName)
                allChannelFiles{end+1} = sStudy.Channel.FileName;
            end
        end
        % Copy the first channel file to the destination
        if (length(allChannelFiles) >= 1)
            db_set_channel(iNewChanStudy, allChannelFiles{1}, 0, 0);
        end
        % Hide progress bar
        bst_progress('stop');
    end
end


%% ===== REGISTER MEG RUNS =====
function RegisterMegRuns(iChanStudies)
    % Get all the channel files to consider
    allChannelFiles = {};
    for i = 1:length(iChanStudies)
        sStudy = bst_get('Study', iChanStudies(i));
        if ~isempty(sStudy.Channel) && ~isempty(sStudy.Channel.FileName)
            allChannelFiles{end+1} = sStudy.Channel.FileName;
        end
    end
    % More than one channel file: Require a co-registration step
    if (length(allChannelFiles) > 1)
        % Get all the data files
        allDataFiles = {};
        for i = 1:length(allChannelFiles)
            tmp = bst_get('DataForChannelFile', allChannelFiles{i});
            if ~isempty(allChannelFiles)
                allDataFiles = cat(2, allDataFiles, tmp);
            end
        end
        % Co-register MEG runs
        if ~isempty(allDataFiles)
            disp('BST> Applying process_megreg to the data, this will most likely alter the recordings.');
            bst_process('CallProcess', 'process_megreg', allDataFiles, [], 'targetchan', 1, 'sharechan', 2);
        end
    end
end


