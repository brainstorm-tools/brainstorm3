function node_delete(bstNodes, isUserConfirm)
% NODE_DELETE: Delete the input nodes from tree, and eventually delete the associated files.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2019

%% ===== INITIALIZATION =====
% Parse inputs
if (nargin < 2) || isempty(isUserConfirm)
    isUserConfirm = 1;
end
% Get protocol description
ProtocolInfo     = bst_get('ProtocolInfo');
ProtocolSubjects = bst_get('ProtocolSubjects');
iModifiedStudies  = [];
iModifiedSubjects = [];
isTreeUpdateModel = 0;
% Get all nodes descriptions
nodeType = cell(length(bstNodes), 1);
iItem    = zeros(1, length(bstNodes));
iSubItem = zeros(1, length(bstNodes));
FileName = cell(length(bstNodes), 1);
for i = 1:length(bstNodes)
    nodeType{i} = char(bstNodes(i).getType());
    iItem(i)    = bstNodes(i).getStudyIndex();
    iSubItem(i) = bstNodes(i).getItemIndex();
    FileName{i} = char(bstNodes(i).getFileName());
end

% Cannot delete node if it is a special node
nodeComment = char(bstNodes(1).getComment());
isSpecialNode = ~isempty(nodeComment) && ismember(nodeType{1}, {'subject','defaultstudy'}) && (nodeComment(1) == '(');
if isSpecialNode
    return
end
% Get the parent of the first node
parentNode = bstNodes(1).getParent();

% Process the diffent nodes types
switch (lower(nodeType{1}))
%% ===== DATABASE =====
    case {'subjectdb', 'studydbsubj', 'studydbcond'}
        % Remove current protocol from ProtocolsList (do not delete any file)
        db_delete_protocol(isUserConfirm, 1);

%% ===== SUBJECT =====
    case {'subject', 'studysubject'}
        % Ask user the confirmation for deleting subject
        if isUserConfirm
            isConfirmed = java_dialog('confirm', 'Remove selected subject(s) from database ?', 'Delete subjects');
            if ~isConfirmed
                return;
            end
        end
        bst_progress('start', 'Delete nodes', 'Deleting subjects...');
        % For 'StudySubject' nodes, both iItem and iSubject are stored in node
        if strcmpi(nodeType{1}, 'studysubject')
            iSubjects = iSubItem;
        else
            iSubjects = iItem;
        end
        % Delete
        db_delete_subjects(iSubjects);
        
        %iModifiedSubjects = -1;   
        %iModifiedStudies  = -1;


%% ===== CONDITION =====
    case {'condition', 'rawcondition'}
        % Ask user the confirmation for deleting subject
        if isUserConfirm
            if strcmpi(nodeType{1}, 'rawcondition')
                % Identify if the raw file is in the brainstorm datbase or not
                sStudy = bst_get('StudyWithCondition', FileName{1});
                if isempty(sStudy) || isempty(sStudy.Data) || ~strcmpi(sStudy.Data(1).DataType, 'raw')
                    questStr = [];
                % Raw file to delete is in the database
                elseif ~isempty(dir(bst_fullfile(bst_fileparts(file_fullpath(sStudy.Data(1).FileName)), '*.bst')))
                    questStr = ['<BR><BR><FONT color="#CC0000">Warning: This continuous file is saved in the Brainstorm database.<BR>' ...
                        'Deleting this link will delete permanently the file associated with it.</FONT>'];
                % Raw file to delete is NOT in the database
                else
                    questStr = ['<BR><BR><FONT color="#008000">Removing links to raw files does not delete the original recordings from<BR>' ...
                        'your hard drive. You can only do this from your operating system file manager.<BR><BR></FONT>'];
                end
            else
                questStr = [];
            end
            isConfirmed = java_dialog('confirm', ['<HTML>Remove selected dataset(s) from database ?' questStr], 'Delete datasets');
            if ~isConfirmed
                return;
            end
        end
        bst_progress('start', 'Delete nodes', 'Deleting conditions...');
        % For each condition
        for iFile = 1:length(FileName)
            % Get all the studies related to this condition
            [sStudies, iStudies] = bst_get('StudyWithCondition', FileName{iFile});
            % Remove from the list the studies that cannot be deleted : DefaultStudy and AnalysisStudy
            iAnalysisStudy = -2;
            iDefaultStudy  = -3;
            iStudies = setdiff(iStudies, [iAnalysisStudy, iDefaultStudy]);
            % Delete them
            if ~isempty(iStudies)
                db_delete_studies(iStudies);
            end
        end
        iModifiedStudies  = -1;


%% ===== ANATOMY =====
    case {'anatomy', 'volatlas'}
        bst_progress('start', 'Delete nodes', 'Deleting files...');
        % Full file names
        FullFilesList = cellfun(@(f)fullfile(ProtocolInfo.SUBJECTS,f), FileName', 'UniformOutput',0);
        % Delete file
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            uniqueSubject = unique(iItem);
            for i = 1:length(uniqueSubject)
                % Get indices
                iSubject = uniqueSubject(i);
                iAnatomies = iSubItem(iItem == iSubject);
                % Delete surface
                if (iSubject == 0)
                    ProtocolSubjects.DefaultSubject.Anatomy(iAnatomies) = [];
                else
                    ProtocolSubjects.Subject(iSubject).Anatomy(iAnatomies) = [];
                end
                % Update default surfaces
                bst_set('ProtocolSubjects', ProtocolSubjects);
                db_surface_default(iSubject, 'Anatomy', [], 0);
                drawnow;
                ProtocolSubjects = bst_get('ProtocolSubjects');
                % Subject was modified
                iModifiedSubjects = [iModifiedSubjects iSubject];
            end
            drawnow;
        end 


%% ===== SURFACES =====
    case {'scalp', 'outerskull', 'innerskull', 'cortex', 'fibers', 'fem', 'other'}
        bst_progress('start', 'Delete nodes', 'Deleting surfaces...');
        % Full file names
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.SUBJECTS,f), FileName', 'UniformOutput',0);
        % Add the openmeeg.bin files linked to the InnerSkull       
        for i = 1:length(FullFilesList)
            if strcmpi(file_gettype(FullFilesList{i}), 'innerskull')
                % Read OpenMEEG structure from tess file
                warning off
                TessMat = load(FullFilesList{i}, 'OpenMEEG');
                warning on
                % Add OpenMEEG files to delete list (.bin or _openmeeg.mat)
                if isfield(TessMat,  'OpenMEEG') && isfield(TessMat.OpenMEEG, 'HmFile') && ~isempty(TessMat.OpenMEEG.HmFile) 
                    BinFile = bst_fullfile(bst_fileparts(FullFilesList{i}), TessMat.OpenMEEG.HmFile);
                    if file_exist(BinFile)
                        FullFilesList{end+1} = BinFile;
                    end
                end
            end
        end
        % Delete files
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            uniqueSubject = unique(iItem);
            for i = 1:length(uniqueSubject)
                % Get indices
                iSubject = uniqueSubject(i);
                iSurfaces = iSubItem(iItem == iSubject);
                % Delete surface
                if (iSubject == 0)
                    ProtocolSubjects.DefaultSubject.Surface(iSurfaces) = [];
                else
                    ProtocolSubjects.Subject(iSubject).Surface(iSurfaces) = [];
                end
                % Update default surfaces
                bst_set('ProtocolSubjects', ProtocolSubjects);
                for SurfType = {'Scalp', 'Cortex', 'InnerSkull', 'OuterSkull', 'Fibers', 'FEM'}
                    db_surface_default(iSubject, SurfType{1}, [], 0);
                end
                drawnow;
                ProtocolSubjects = bst_get('ProtocolSubjects');
                % Subject was modified
                iModifiedSubjects = [iModifiedSubjects iSubject];
            end
        end

%% ===== CHANNEL FILE =====
    case 'channel'
        iStudies = iItem;
        bst_progress('start', 'Delete nodes', 'Deleting channels...');
        % Get full filenames
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), FileName', 'UniformOutput',0);
        % Delete file
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            % Process each study
            for i = 1:length(iStudies)
                % Find file in DataBase  
                iStudy = iStudies(i);
                sStudy = bst_get('Study', iStudy);                
                % Remove file description from database
                sStudy.Channel = [];
                % Study was modified
                bst_set('Study', iStudy, sStudy);
            end
            iModifiedStudies = iStudies;
        end

%% ===== NOISECOV =====
    case {'noisecov', 'ndatacov'}
        iStudies = iItem;
        iNoiseCov = iSubItem;
        % Get full filenames
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), FileName', 'UniformOutput',0);
        % Delete file
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            % Process each study
            for i = 1:length(iStudies)
                % Find file in DataBase  
                iStudy = iStudies(i);
                sStudy = bst_get('Study', iStudy);                
                % Remove file description from database
                if (iNoiseCov(i) == 1)
                    if (length(sStudy.NoiseCov) >= 2)
                        sStudy.NoiseCov(1) = db_template('noisecov');
                    else
                        sStudy.NoiseCov = repmat(db_template('noisecov'),0);
                    end
                elseif (iNoiseCov(i) == 2)
                    if ~isempty(sStudy.NoiseCov(1).FileName)
                        sStudy.NoiseCov(2) = [];
                    else
                        sStudy.NoiseCov = repmat(db_template('noisecov'),0);
                    end
                end
                % Study was modified
                bst_set('Study', iStudy, sStudy);
            end
            iModifiedStudies = iStudies;
        end

%% ===== HEAD MODEL =====
    case 'headmodel'
        iStudies    = iItem;
        iHeadModels = iSubItem;
        % Get full filenames
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), FileName', 'UniformOutput',0);
        % Delete headmodel files
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            % Get unique list of studies
            uniqueStudies = unique(iStudies);
            for i = 1:length(uniqueStudies)
                iStudy = uniqueStudies(i);
                iHeadModelDel = iHeadModels(iStudies == iStudy);
                sStudy = bst_get('Study', iStudy);
                % Remove files descriptions from database
                sStudy.HeadModel(iHeadModelDel) = [];
                % Update default headmodel
                nbHeadModel = length(sStudy.HeadModel);
                if (nbHeadModel <= 0)
                    sStudy.iHeadModel = [];
                elseif (nbHeadModel == 1)
                    sStudy.iHeadModel = 1;
                elseif (sStudy.iHeadModel > nbHeadModel)
                    sStudy.iHeadModel = nbHeadModel;
                else
                    % Do not change iHeadModel
                end
                % Study was modified
                bst_set('Study', iStudy, sStudy);
            end
            iModifiedStudies = uniqueStudies;
        end

%% ===== DATA FILE / DATA LIST =====
    case {'data', 'datalist', 'rawdata'}
        bst_progress('start', 'Delete nodes', 'Deleting files...');
        % Get data files do delete
        [ iStudies_data,     iDatas    ] = tree_dependencies( bstNodes, 'data' );
        [ iStudies_results,  iResults  ] = tree_dependencies( bstNodes, 'results' );
        [ iStudies_timefreq, iTimefreq ] = tree_dependencies( bstNodes, 'timefreq' );
        [ iStudies_dipoles,  iDipoles  ] = tree_dependencies( bstNodes, 'dipoles' );
        % If an error occurred when looking for the for the files in the database
        if isequal(iStudies_data, -10) || isequal(iStudies_results, -10) || isequal(iStudies_timefreq, -10) || isequal(iStudies_dipoles, -10)
            disp('BST> Error in tree_dependencies.');
            bst_progress('stop');
            return;
        end
        % Get studies
        sStudies_data     = bst_get('Study', iStudies_data);
        sStudies_results  = bst_get('Study', iStudies_results);
        sStudies_timefreq = bst_get('Study', iStudies_timefreq);
        sStudies_dipoles  = bst_get('Study', iStudies_dipoles);
        % Build full files list 
        FullFilesList = {};
        isRecursive = 0;
        for i = 1:length(iStudies_data)
            DataFile = bst_fullfile(ProtocolInfo.STUDIES, sStudies_data(i).Data(iDatas(i)).FileName);
            FullFilesList{end+1} = DataFile;
            % Raw files: delete associated .bin file
            if strcmpi(nodeType{1}, 'rawdata')
                BinFile = strrep(DataFile, '.mat', '.bst');
                BinFile = strrep(BinFile, 'data_0raw_', '');
                if file_exist(BinFile)
                    FullFilesList{end+1} = BinFile;
                end
                % Spike sorting files: delete spikes folder
                if ~isempty(strfind(DataFile, 'data_0ephys_'))
                    DataMat = load(DataFile, 'Parent');
                    FullFilesList{end+1} = DataMat.Parent;
                    isRecursive = 1;
                end
            end
        end
        for i = 1:length(sStudies_results)
            if ~sStudies_results(i).Result(iResults(i)).isLink
                FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sStudies_results(i).Result(iResults(i)).FileName);
            end
        end
        for i = 1:length(sStudies_timefreq)
            FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sStudies_timefreq(i).Timefreq(iTimefreq(i)).FileName);
        end
        for i = 1:length(sStudies_dipoles)
            FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sStudies_dipoles(i).Dipoles(iDipoles(i)).FileName);
        end

        % === DELETE FILES ===
        if (file_delete(FullFilesList, ~isUserConfirm, isRecursive) == 1)
            % Get unique list of studies
            uniqueStudies = unique([iStudies_data, iStudies_results]);
            for i = 1:length(uniqueStudies)
                iStudy = uniqueStudies(i);
                iDataDel     = iDatas(iStudies_data == iStudy);
                iResultDel   = iResults(iStudies_results == iStudy);
                iTimefreqDel = iTimefreq(iStudies_timefreq == iStudy);
                iDipolesDel  = iDipoles(iStudies_dipoles == iStudy);
                sStudy = bst_get('Study', iStudy);
                % Update list of bad trials
                iBad = find([sStudy.Data(iDataDel).BadTrial]);
                if ~isempty(iBad)
                    % Load study file
                    StudyFile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.FileName);
                    StudyMat = load(StudyFile);
                    % Remove delete trials
                    fPath = bst_fileparts(sStudy.FileName);
                    badFiles = cellfun(@(c)bst_fullfile(fPath, c), StudyMat.BadTrials, 'UniformOutput', 0);
                    iDel = find(ismember(badFiles, {sStudy.Data(iDataDel(iBad)).FileName}));
                    StudyMat.BadTrials(iDel) = [];
                    % Save list of bad trials in the study file
                    bst_save(StudyFile, StudyMat, 'v7');
                end
                % Remove files descriptions from database
                sStudy.Data(iDataDel)         = [];
                sStudy.Result(iResultDel)     = [];
                sStudy.Timefreq(iTimefreqDel) = [];
                sStudy.Dipoles(iDipolesDel)   = [];
                % Study was modified
                bst_set('Study', iStudy, sStudy);
            end
            iModifiedStudies = uniqueStudies;
        end

%% ===== RESULT FILE =====
    case {'results', 'kernel'}
        bst_progress('start', 'Delete nodes', 'Deleting files...');
        % Get results files
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), FileName', 'UniformOutput',0);
        % Get dependent time-freq files
        [ iStudies_timefreq, iTimefreq ] = tree_dependencies( bstNodes, 'timefreq' );
        [ iStudies_dipoles,  iDipoles ]  = tree_dependencies( bstNodes, 'dipoles' );
        % If an error occurred when looking for the for the files in the database
        if isequal(iStudies_timefreq, -10) || isequal(iStudies_dipoles, -10)
            disp('BST> Error in tree_dependencies.');
            bst_progress('stop');
            return;
        end
        % Get all the associated links for the shared kernels
        if strcmpi(nodeType{1}, 'kernel')
            for i = 1:length(FileName)
                % Get dependent files: timefreq
                [sStudies_dep, iStudies_dep, iTimefreq_dep] = bst_get('TimefreqForKernel', FileName{i});
                if ~isempty(sStudies_dep)
                    % Add files to the delete list
                    iStudies_timefreq = [iStudies_timefreq, iStudies_dep];
                    iTimefreq = [iTimefreq, iTimefreq_dep];
                end
                % Get dependent files: dipoles
                [sStudies_dep, iStudies_dep, iDipoles_dep] = bst_get('DipolesForKernel', FileName{i});
                if ~isempty(sStudies_dep)
                    % Add files to the delete list
                    iStudies_dipoles = [iStudies_dipoles, iStudies_dep];
                    iDipoles = [iDipoles, iDipoles_dep];
                end
            end
        end
        % Get studies: timefreq
        sStudies_timefreq = bst_get('Study', iStudies_timefreq);
        for i = 1:length(sStudies_timefreq)
            FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sStudies_timefreq(i).Timefreq(iTimefreq(i)).FileName);
        end
        % Get studies: dipoles
        sStudies_dipoles = bst_get('Study', iStudies_dipoles);
        for i = 1:length(sStudies_dipoles)
            FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sStudies_dipoles(i).Dipoles(iDipoles(i)).FileName);
        end
        % Delete files
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            iStudies     = iItem;
            iResultsList = iSubItem;
            % Get unique list of studies
            uniqueStudies = unique([iStudies, iStudies_timefreq, iStudies_dipoles]);
            for i = 1:length(uniqueStudies)
                iStudy = uniqueStudies(i);
                iResultsDel  = iResultsList(iStudies == iStudy);
                iTimefreqDel = iTimefreq(iStudies_timefreq == iStudy);
                iDipolesDel  = iDipoles(iStudies_dipoles == iStudy);
                sStudy = bst_get('Study', iStudy);
                % Remove file description from database
                sStudy.Result(iResultsDel) = [];
                sStudy.Timefreq(iTimefreqDel) = [];
                sStudy.Dipoles(iDipolesDel) = [];
                % Study was modified
                bst_set('Study', iStudy, sStudy);
                % If result deleted from a 'default_study' node
                isDefaultStudy = strcmpi(sStudy.Name, bst_get('DirDefaultStudy'));
                if isDefaultStudy
                    db_links('Subject', sStudy.BrainStormSubject);
                    isTreeUpdateModel = 1;
                else
                    db_links('Study', iStudy);
                    panel_protocols('UpdateNode', 'Study', iStudy);
                end
            end
            iModifiedStudies = unique(iItem);
        end

        
%% ===== STAT FILE =====
    case {'pdata', 'presults', 'ptimefreq', 'pspectrum', 'pmatrix'}
        bst_progress('start', 'Delete nodes', 'Deleting files...');
        % Delete file
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), FileName', 'UniformOutput',0);
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            iUniqueStudy = unique(iItem);
            for i=1:length(iUniqueStudy)
                iStudy = iUniqueStudy(i);
                iStats = iSubItem(iItem == iStudy);
                sStudy = bst_get('Study', iStudy);
                % Remove file description from database
                sStudy.Stat(iStats) = [];
                % Study was modified
                bst_set('Study', iStudy, sStudy);
            end
            iModifiedStudies = unique(iItem);
        end

%% ===== MATRIX =====
    case {'matrix', 'matrixlist'}
        bst_progress('start', 'Delete nodes', 'Deleting files...');
        FullFilesList = {};
        % Get dependent time-freq files
        [ iStudies_matrix,   iMatrix   ] = tree_dependencies( bstNodes, 'matrix' );
        [ iStudies_timefreq, iTimefreq ] = tree_dependencies( bstNodes, 'timefreq' );
        % If an error occurred when looking for the for the files in the database
        if isequal(iStudies_timefreq, -10)
            disp('BST> Error in tree_dependencies.');
            bst_progress('stop');
            return;
        end
        % Get matrix files
        sStudies_matrix = bst_get('Study', iStudies_matrix);
        for i = 1:length(sStudies_matrix)
            FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sStudies_matrix(i).Matrix(iMatrix(i)).FileName);
        end
        % Get time-freq files
        sStudies_timefreq = bst_get('Study', iStudies_timefreq);
        for i = 1:length(sStudies_timefreq)
            FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sStudies_timefreq(i).Timefreq(iTimefreq(i)).FileName);
        end
        % Delete files
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            iUniqueStudy = unique(iItem);
            for i=1:length(iUniqueStudy)
                iStudy = iUniqueStudy(i);
                iMatrixDel   = iMatrix(iStudies_matrix == iStudy);
                iTimefreqDel = iTimefreq(iStudies_timefreq == iStudy);
                sStudy = bst_get('Study', iStudy);
                % Remove file description from database
                sStudy.Matrix(iMatrixDel)     = [];
                sStudy.Timefreq(iTimefreqDel) = [];
                % Study was modified
                bst_set('Study', iStudy, sStudy);
            end
            iModifiedStudies = unique(iItem);
        end
        
%% ===== DIPOLES FILE =====
    case 'dipoles'
        bst_progress('start', 'Delete nodes', 'Deleting files...');
        % Delete file
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), FileName', 'UniformOutput',0);
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            iUniqueStudy = unique(iItem);
            for i=1:length(iUniqueStudy)
                iStudy = iUniqueStudy(i);
                iDipoles = iSubItem(iItem == iStudy);
                sStudy = bst_get('Study', iStudy);
                % Remove file description from database
                sStudy.Dipoles(iDipoles) = [];
                % Study was modified
                bst_set('Study', iStudy, sStudy);
            end
            iModifiedStudies = unique(iItem);
        end
        
%% ===== TIMEFREQ FILE =====
    case {'timefreq', 'spectrum'}
        bst_progress('start', 'Delete nodes', 'Deleting files...');
        % Delete file
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), FileName', 'UniformOutput',0);
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            iUniqueStudy = unique(iItem);
            for i=1:length(iUniqueStudy)
                iStudy = iUniqueStudy(i);
                iTimefreq = iSubItem(iItem == iStudy);
                sStudy = bst_get('Study', iStudy);
                % Remove file description from database
                sStudy.Timefreq(iTimefreq) = [];
                % Study was modified
                bst_set('Study', iStudy, sStudy);
            end
            iModifiedStudies = unique(iItem);
        end

%% ===== IMAGE FILE =====
    case {'image','video'}
        bst_progress('start', 'Delete nodes', 'Deleting files...');
        % Delete file
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), FileName', 'UniformOutput',0);
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            iUniqueStudy = unique(iItem);
            for i=1:length(iUniqueStudy)
                iStudy = iUniqueStudy(i);
                iImages = iSubItem(iItem == iStudy);
                sStudy = bst_get('Study', iStudy);
                % Remove file description from database
                sStudy.Image(iImages) = [];
                % Study was modified
                bst_set('Study', iStudy, sStudy);
            end
            iModifiedStudies = iUniqueStudy;
        end
    otherwise
        % Node that cannot be deleted
        return
end


%% ===== UPDATE DATABASE =====
% If some studies were modified
if ~isempty(iModifiedStudies)
    % Update default study
    nbStudies = bst_get('StudyCount');
    if (ProtocolInfo.iStudy > nbStudies)
        ProtocolInfo.iStudy = [];
        bst_set('ProtocolInfo', ProtocolInfo);
    end
end

%% ===== UPDATE TREE =====
% If studies or subjects removed : refresh whole tree
if isTreeUpdateModel || (~isempty(iModifiedSubjects) && (iModifiedSubjects(1) < 0)) ...
                     || (~isempty(iModifiedStudies)  && (iModifiedStudies(1) < 0))
    panel_protocols('UpdateTree');
% Subjects modified
elseif ~isempty(iModifiedSubjects)
    panel_protocols('UpdateNode', 'Subject', iModifiedSubjects);
% Studies modified
elseif ~isempty(iModifiedStudies)
    % Select the parent node after deleting
    selectNode = parentNode;
    selectFile = char(selectNode.getFileName());
    % Update node
    panel_protocols('UpdateNode', 'Study', iModifiedStudies);
    % Get root node
    nodeRoot = panel_protocols('GetRootNode');
    % Re-expand parent of the deleted node
    if ~isempty(selectFile)
        % If the parent node is not a file: find the node
        if (nnz(selectFile == '/') + nnz(selectFile == '\') < 2)
            selectNode = nodeRoot.findChild(selectNode.getType(), selectNode.getStudyIndex(), selectNode.getItemIndex(), 1);
            if ~isempty(selectNode)
                panel_protocols('ExpandPath', selectNode, 1);
            end
        % If the parent node is a file: find the filename
        else
            panel_protocols('SelectNode', nodeRoot, selectFile);
        end
    end
end
% Save database
db_save();
bst_progress('stop');

return
end





