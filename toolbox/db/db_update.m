function db_update(CurrentDbVersion)
% DB_UPDATESTRUCTURE: Updates any existing Brainstorm database to the current database structure.
% 
% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2013

global GlobalData;
% Get list of protocols
ProtocolsListStudies = GlobalData.DataBase.ProtocolStudies;
ProtocolsListSubjects = GlobalData.DataBase.ProtocolSubjects;
isFirstWarning = 1;

%% ===== UPDATE 31-Jul-2009 =====
% Modification: Add 'Image' field to the studies
function sStudy = AddImage(sStudy)
    sStudy.Image = repmat(db_template('Image'), 0);
end
% Perform update
if ~isempty(ProtocolsListStudies) && ~isempty(ProtocolsListStudies(1).Study) && ~isfield(ProtocolsListStudies(1).Study, 'Image')
    disp('BST> Database structure: Adding image support...');
    ApplyToDatabase(@AddImage);
    disp('BST> Database structure: Done.');
end

%% ===== UPDATE 16-Oct-2009 =====
% Modification: Add 'NoiseCov' field to the studies
function sStudy = AddNoiseCov(sStudy)
    sStudy.NoiseCov = repmat(db_template('NoiseCov'), 0);
end
% Perform update
if ~isempty(ProtocolsListStudies) && ~isempty(ProtocolsListStudies(1).Study) && ~isfield(ProtocolsListStudies(1).Study, 'NoiseCov')
    disp('BST> Database structure: Adding noise covariance matrix...');
    ApplyToDatabase(@AddNoiseCov);
    disp('BST> Database structure: Done.');
end

%% ===== UPDATE 20-Mar-2010 =====
% Modification: Add 'Dipoles' field to the studies
function sStudy = AddDipoles(sStudy)
    sStudy.Dipoles = repmat(db_template('Dipoles'), 0);
end
% Perform update
if ~isempty(ProtocolsListStudies) && ~isempty(ProtocolsListStudies(1).Study) && ~isfield(ProtocolsListStudies(1).Study, 'Dipoles')
    disp('BST> Database structure: Adding dipoles...');
    ApplyToDatabase(@AddDipoles);
    disp('BST> Database structure: Done.');
end
    
%% ===== UPDATE 15-Apr-2010 =====
% Modification: Add 'Timefreq' field to the studies
function sStudy = AddTimefreq(sStudy)
    sStudy.Timefreq = repmat(db_template('Timefreq'), 0);
end
% Perform update
if ~isempty(ProtocolsListStudies) && ~isempty(ProtocolsListStudies(1).Study) && ~isfield(ProtocolsListStudies(1).Study, 'Timefreq')
    disp('BST> Database structure: Adding time-frequency...');
    ApplyToDatabase(@AddTimefreq);
    disp('BST> Database structure: Done.');
end

%% ===== UPDATE 25-Jun-2010 =====
% Modifications: - Rename 'HeadModelName' field in 'Comment'
%                - Remove GridName field
function sStudy = UpdateHeadmodel(sStudy)
    % If no head models
    if isempty(sStudy.HeadModel)
        sStudy.HeadModel = repmat(db_template('headmodel'), 0);
    else
        if isfield(sStudy.HeadModel, 'HeadModelName')
            % For each headmodel in this study
            for iHeadModel = 1:length(sStudy.HeadModel)
                % Copy HeadModelName to Comment
                sStudy.HeadModel(iHeadModel).Comment = sStudy.HeadModel(iHeadModel).HeadModelName;
            end
            % Remove HeadModelName field
            sStudy.HeadModel = rmfield(sStudy.HeadModel, 'HeadModelName');
        end
        % Remove GridName field
        if isfield(sStudy.HeadModel, 'GridName')
            sStudy.HeadModel = rmfield(sStudy.HeadModel, 'GridName');
        end
    end
end
% If update was not performed yet
if ~isempty(ProtocolsListStudies) && ~isempty(ProtocolsListStudies(1).DefaultStudy) && isfield(ProtocolsListStudies(1).DefaultStudy.HeadModel, 'GridName')
    disp('BST> Database structure: Updating headmodel definition...');
    ApplyToDatabase(@UpdateHeadmodel);
    disp('BST> Database structure: Done.');
end

%% ===== UPDATE 25-Jun-2010 =====
% Modification: Add 'HeadModelType' to the Results structure
function sStudy = AddHeadModelType(sStudy)
    if ~isempty(sStudy.Result)
        [sStudy.Result.HeadModelType] = deal('surface');
    else
        sStudy.Result = repmat(db_template('results'), 0);
    end
end
% If update was not performed yet
if ~isempty(ProtocolsListStudies) && ~isempty(ProtocolsListStudies(1).AnalysisStudy) && ~isfield(ProtocolsListStudies(1).AnalysisStudy.Result, 'HeadModelType')
    disp('BST> Database structure: Adding HeadModelType to the Results structures...');
    ApplyToDatabase(@AddHeadModelType);
    disp('BST> Database structure: Done.');
end

%% ===== UPDATE 12-Jul-2010 =====
% Modification: Add 'BadTrial' and 'DataType' to the Data structure
% Function to update structure
function sStudy = AddBadTrial(sStudy)
    if ~isempty(sStudy.Data)
        [sStudy.Data.DataType] = deal('recordings');
        [sStudy.Data.BadTrial] = deal(0);
    else
        sStudy.Data = repmat(db_template('data'), 0);
    end
end
% If update was not performed yet
if ~isempty(ProtocolsListStudies) && ~isempty(ProtocolsListStudies(1).AnalysisStudy) && ~isfield(ProtocolsListStudies(1).AnalysisStudy.Data, 'DataType')
    disp('BST> Database structure: Adding BadTrial definition...');
    ApplyToDatabase(@AddBadTrial);
    disp('BST> Database structure: Done.');
end

%% ===== UPDATE 14-Jul-2010 =====
% Modification: Remove the "linkresults" files, now links are represented by filenames of the type "link|resultsfile.mat|datafile.mat"
if (GlobalData.DataBase.DbVersion < 3)
    % Hide splash screen
    bst_splash('hide');
    % A full reload of the database is necessary to update all the links
    java_dialog('msgbox', ['Brainstorm was updated: the database structure changed.' 10 10 ...
                           'Please click on "Ok" and wait while all the database is being reloaded.' 10 ...
                           'Be patient, it might take several minutes...' 10 10], ...
                           'Database update');
    disp('BST> Reloading database... This might take several minutes...');
    % Reload database
    db_reload_database();
    % Get again the list of protocols for successive updates
    ProtocolsListStudies = GlobalData.DataBase.ProtocolStudies;
end

%% ===== UPDATE 07-October-2010 =====
% Modification: Add 'Matrix' field to the studies
function sStudy = AddMatrix(sStudy)
    sStudy.Matrix = repmat(db_template('Matrix'), 0);
end
% Perform update
if ~isempty(ProtocolsListStudies) && ~isempty(ProtocolsListStudies(1).Study) && ~isfield(ProtocolsListStudies(1).Study, 'Matrix')
    disp('BST> Database structure: Adding custom "matrix" file type...');
    ApplyToDatabase(@AddMatrix);
    disp('BST> Database structure: Done.');
end

%% ===== UPDATE 03-March-2011 =====
% Modification: Setting the subject file of "inter-subject" data to the default anatomy
if (GlobalData.DataBase.DbVersion < 3.2)
    disp('BST> Database update: Setting the inter-subject nodes anatomy to the default anatomy.');
    % Set it protocol by protocol (if not set)
    for i = 1:length(ProtocolsListStudies)
        defSubjFile = bst_fullfile(bst_get('DirDefaultSubject'), 'brainstormsubject.mat');
        defSubjFileFull = bst_fullfile(GlobalData.DataBase.ProtocolInfo(i).SUBJECTS, defSubjFile);
        if ~isempty(ProtocolsListStudies(i).AnalysisStudy) && isempty(ProtocolsListStudies(i).AnalysisStudy.BrainStormSubject) && file_exist(defSubjFileFull)
            ProtocolsListStudies(i).AnalysisStudy.BrainStormSubject = file_win2unix(defSubjFile);
        end
    end
    % Save database
    GlobalData.DataBase.ProtocolStudies = ProtocolsListStudies;
end

%% ===== UPDATE 15-March-2011 =====
% Database update: Changing the time reference in RAW FIF files from relative to absolute (the first sample is no longer t=0).
function sStudy = UpdateFifTimeRef(sStudy)
    for iData = 1:length(sStudy.Data)
        if strcmpi(sStudy.Data(iData).DataType, 'raw')
            try
                DataFile = file_fullpath(sStudy.Data(iData).FileName);
                disp(['UPDATE> Checking file: ' DataFile]);
                % Load file header
                DataMat = in_bst_data(DataFile);
                % If it is a RAW FIF file: Update time definition
                if strcmpi(DataMat.F.format, 'FIF') && isfield(DataMat.F.header,'raw') && (DataMat.F.header.raw.first_samp ~= 0) && (DataMat.Time(1) == 0)
                    disp('UPDATE> Updating file...');
                    addSamples = double(DataMat.F.header.raw.first_samp);
                    addTime    = addSamples / DataMat.F.prop.sfreq;
                    DataMat.Time           = DataMat.Time + addTime;
                    DataMat.F.prop.times   = DataMat.F.prop.times + addTime;
                    DataMat.F.prop.samples = DataMat.F.prop.samples + addSamples;
                    for iEvt = 1:length(DataMat.F.events)
                        DataMat.F.events(iEvt).samples = DataMat.F.events(iEvt).samples + addSamples;
                        DataMat.F.events(iEvt).times   = DataMat.F.events(iEvt).times + addTime;
                    end
                    % Save file back
                    bst_save(DataFile, DataMat, 'v6');
                end
            catch
                disp('UPDATE> Error updating file...');
            end
        end
    end
end
if (GlobalData.DataBase.DbVersion < 3.3)
    disp('BST> Database update: Changing the time reference in RAW FIF files from relative to absolute (the first sample is no longer t=0).');
    ApplyToDatabase(@UpdateFifTimeRef);
    disp('BST> Database update: Done.');
end

%% ===== UPDATE 07-Dec-2011 =====
% Modification: Subject name is now defined based on the folder name (previously: "Name" folder)
if (GlobalData.DataBase.DbVersion < 3.4)
    disp('BST> Database update: Forcing the subjects names to match the folder name.');
    % Update protocol by protocol
    for i = 1:length(ProtocolsListSubjects)
        % Process each subject
        for iSubj = 1:length(ProtocolsListSubjects(i).Subject)
            % Update name based on folder name
            ProtocolsListSubjects(i).Subject(iSubj).Name = bst_fileparts(ProtocolsListSubjects(i).Subject(iSubj).FileName);
        end
    end
    % Save database
    GlobalData.DataBase.ProtocolSubjects = ProtocolsListSubjects;
end

%% ===== UPDATE 31-Jan-2013 =====
% Modified lots of things in the pipeline editor: resetting the options
if (GlobalData.DataBase.DbVersion < 3.51)
    disp('BST> Software update: Resetting the process options...');
    % Reset all the saved options
    bst_set('ProcessOptions', []);
end
    
%% ===== UPDATE 21-Fev-2013 =====
% Function to update structure
function sStudy = AddIntraElectrodes(sStudy)
    if ~isempty(sStudy.HeadModel)
        [sStudy.HeadModel.ECOGMethod] = deal('');
        [sStudy.HeadModel.SEEGMethod] = deal('');
    else
        sStudy.Data = repmat(db_template('headmodel'), 0);
    end
end
% Modification: Add 'SEEGMethod' and 'ECOGMethod' to the Headmodel structure
if (GlobalData.DataBase.DbVersion < 3.6) && ~isempty(ProtocolsListStudies) && ~isfield(ProtocolsListStudies(1).AnalysisStudy.HeadModel, 'ECOGMethod')
    disp('BST> Database structure: Adding intra-cranial electrodes definition...');
    ApplyToDatabase(@AddIntraElectrodes);
    disp('BST> Database structure: Done.');
    % Reset all the saved options
    bst_set('ProcessOptions', []);
end


%% ===== JUST BEFORE RETURNING TO STARTUP FUNCTION =====
% Save the new database version
isSave = (GlobalData.DataBase.DbVersion ~= CurrentDbVersion);
GlobalData.DataBase.DbVersion = CurrentDbVersion;
if isSave
    db_save();
end


%% ===================================================================================================
%  ===== HELPER FUNCTIONS ============================================================================
%  ===================================================================================================
%% ===== APPLY FUNCTION TO DATABASE =====
    function ApplyToDatabase(UpdateFcn)
        % ===== WARNING/BACKUP =====
        % Display warning before updating database
        if isFirstWarning
            % Hide splash screen
            bst_splash('hide');
            % Display warning message
            msgWarning = ['If after the update you cannot start Brainstorm anymore: ' 10 ...
                          '  - Do not try to run a previous version of the software, it would not help.' 10 ...
                          '  - Type "brainstorm reset", start Brainstorm, then re-import your protocols.' 10 ...
                          '  - Report the bug on the user forum'];
            disp(['*********************************************************************' 10 ...
                  msgWarning 10 ...
                  '*********************************************************************']);
            isOk = java_dialog('confirm', ...
                ['Warning: You are running a newer version of Brainstorm.' 10 ...
                 'Some modifications have to be performed on your database.' 10 10 ...
                 msgWarning  10 10 ...
                 'Update database now?' 10 10], 'Database update');
            if ~isOk
                error(['User cancelled database update.' 10 'This version of Brainstorm cannot be started, please try your previous version.']);
            end
            % Make a backup copy of the current database
            c = clock;
            DbFile = bst_get('BrainstormDbFile');
            BakDbFile = file_unique(strrep(DbFile, '.mat', sprintf('_%02.0f%02.0f%02.0f_%02.0f%02.0f.bak', c(1)-2000, c(2:5))));
            try
                copyfile(DbFile, BakDbFile, 'f');
            catch
                disp(['UPDATE> Cannot write backup file "' BakDbFile '".']);
            end
            % Do not display the warning again
            isFirstWarning = 0;
        end
        
        % ===== PROCESSING ======
        % Progress bar
        bst_progress('start', 'Update database', 'Updating database structure...');
        % For each protocol
        for ip = 1:length(ProtocolsListStudies)
            % If no study in the protocol
            if isempty(ProtocolsListStudies(ip).Study)
                %ProtocolsListStudies(ip).Study = repmat(db_template('Study'), 0);
                ProtocolsListStudies(ip).Study(1).Comment = 'update';
                ProtocolsListStudies(ip).Study = repmat(UpdateFcn(ProtocolsListStudies(ip).Study), 0);
            else
                % Update each study in this protocol
                ProtocolStudies = repmat(ProtocolsListStudies(ip).Study, 0);
                for is = 1:length(ProtocolsListStudies(ip).Study)
                    ProtocolStudies(is) = UpdateFcn(ProtocolsListStudies(ip).Study(is));
                end
                ProtocolsListStudies(ip).Study = ProtocolStudies;
            end
            if ~isempty(ProtocolsListStudies(ip).DefaultStudy)
                ProtocolsListStudies(ip).DefaultStudy = UpdateFcn(ProtocolsListStudies(ip).DefaultStudy);
            end
            if ~isempty(ProtocolsListStudies(ip).AnalysisStudy)
                ProtocolsListStudies(ip).AnalysisStudy = UpdateFcn(ProtocolsListStudies(ip).AnalysisStudy);
            end
        end
        % Save database
        GlobalData.DataBase.ProtocolStudies = ProtocolsListStudies;
        bst_progress('stop');
    end
end





