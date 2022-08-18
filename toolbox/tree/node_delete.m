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
%          Raymundo Cassani 2022

%% ===== INITIALIZATION =====
% Parse inputs
if (nargin < 2) || isempty(isUserConfirm)
    isUserConfirm = 1;
end
% Get protocol description
ProtocolInfo     = bst_get('ProtocolInfo');
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

sqlConn = sql_connect();
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
                sStudy = db_get(sqlConn, 'StudyWithCondition', bst_fileparts(FileName{1}), 'Id');
                sFuncFileRaw = db_get(sqlConn, 'FunctionalFile', struct('Study', sStudy.Id, 'Type', 'Data', 'SubType', 'raw'), 'FileName');
                if isempty(sFuncFileRaw)
                    questStr = [];
                % Raw file to delete is in the database
                elseif ~isempty(dir(bst_fullfile(bst_fileparts(file_fullpath(sFuncFileRaw.FileName)), '*.bst')))
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
        % Studies that cannot be deleted : DefaultStudy and AnalysisStudy
        sStudyInter = db_get(sqlConn, 'Study', '@inter', 'Id');
        sStudyDef   = db_get(sqlConn, 'Study', '@default_study', 'Id');
        iStudyKeep  = [sStudyInter.Id, sStudyDef.Id];
        % For each condition
        for iFile = 1:length(FileName)
            % Get all the studies related to this condition
            sStudies = db_get(sqlConn, 'StudyWithCondition', bst_fileparts(FileName{iFile}), 'Id');
            % Remove studies that cannot be deleted
            iStudies = setdiff([sStudies.Id], iStudyKeep);
            % Delete them
            if ~isempty(iStudies)
                db_delete_studies(iStudies);
            end
        end
        iModifiedStudies  = -1;


%% ===== ANATOMY and SURFACES =====
    case {'anatomy', 'scalp', 'outerskull', 'innerskull', 'cortex', 'fibers', 'fem', 'other'}
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
            uniqueSubjects = unique(iItem);
            for i = 1:length(uniqueSubjects)
                % Anatomy files in the same Subject
                iSubject = uniqueSubjects(i);
                ixs = find(iItem == iSubject);
                for j = 1 : length(ixs)
                    db_set(sqlConn, 'AnatomyFile', 'Delete', iSubItem(ixs(j)));
                end
                % Update default anatomy and surfaces
                for SurfType = {'Anatomy', 'Scalp', 'Cortex', 'InnerSkull', 'OuterSkull', 'Fibers', 'FEM'}
                    db_surface_default(iSubject, SurfType{1}, [], 0);
                end
                drawnow;
                % Subject was modified
                iModifiedSubjects = [iModifiedSubjects iSubject];
            end
        end

%% ===== CHANNEL, HEADMODEL, NOISECOV, NADATACOV, STAT, DIPOLES, TIMEFREQ, IMAGE and VIDEO FILES =====
    case {'channel', 'headmodel', 'noisecov', 'ndatacov', 'pdata', 'presults', 'ptimefreq', 'pspectrum', 'pmatrix', ...
          'dipoles', 'timefreq', 'spectrum', 'image', 'video'}
        bst_progress('start', 'Delete nodes', 'Deleting files...');
        % Get full filenames
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), FileName', 'UniformOutput',0);             
        % Delete files
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            iUniqueStudies = unique(iItem);
            for i = 1:length(iUniqueStudies)                              
                % Delete Functional files in the same Study
                iStudy = iUniqueStudies(i);
                ixs = find(iItem == iStudy);
                for j = 1 : length(ixs)
                    db_set(sqlConn, 'FunctionalFile', 'Delete', iSubItem(ixs(j)));
                end
                % Update default headmodel if necessary
                if strcmpi(nodeType{1}, 'headmodel')
                    sStudyHeadModels = db_get(sqlConn, 'FunctionalFile', struct('Study', iStudy, 'Type', 'headmodel'), 'Id');
                    % Update default headmodel
                    if isempty(sStudyHeadModels)
                        db_set(sqlConn, 'Study', 'ClearField', iStudy, 'iHeadModel');
                    else
                        sStudy = db_get(sqlConn, 'Study', iStudy, 'iHeadModel');
                        if ~ismember(sStudy.iHeadmodel, [sStudyHeadModels.Id])
                            sStudy.iHeadmodel = sStudyHeadModels(end).Id;
                            db_set(sqlConn, 'Study', sStudy, iStudy);
                        end
                    end
                end
                % Clear iChannel field if necessary
                if strcmpi(nodeType{1}, 'channel')
                    sStudyChannel = db_get(sqlConn, 'FunctionalFile', struct('Study', iStudy, 'Type', 'channel'), 'Id');
                    if isempty(sStudyChannel)
                        db_set(sqlConn, 'Study', 'ClearField', iStudy, 'iChannel');
                    end
                end
                drawnow;
                % Study was modified
                iModifiedStudies = [iModifiedStudies iStudy];
            end
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
        % Build full files list 
        FullFilesList = {};
        isRecursive = 0;
        for i = 1:length(iDatas)
            sFuncFile = db_get(sqlConn, 'FunctionalFile', iDatas(i), 'FileName');
            DataFile = bst_fullfile(ProtocolInfo.STUDIES, sFuncFile.FileName);
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
        for i = 1:length(iResults)
            sFuncFile = db_get(sqlConn, 'FunctionalFile', iResults(i), {'FileName', 'ExtraNum'});
            if ~sFuncFile.ExtraNum % .isLink
                FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sFuncFile.FileName);
            end
        end
        sFuncFiles = db_get(sqlConn, 'FunctionalFile', [iTimefreq, iDipoles], 'FileName');
        for i = 1:length(sFuncFiles)
            FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sFuncFiles(i).FileName);
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
                iFuncFiles   = [iDataDel, iResultDel, iTimefreqDel, iDipolesDel];
                % Update list of bad trials
                sFuncFiles = db_get(sqlConn, 'FunctionalFile', struct('Study', iStudy, 'Type', 'data'), {'Id', 'FileName', 'ExtraNum'});
                iBad = find([sFuncFiles.ExtraNum]); % .BadTrial
                if ~isempty(iBad)
                    sStudy = db_get(sqlConn, 'Study', iStudy, 'FileName');
                    % Load study file
                    StudyFile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.FileName);
                    StudyMat = load(StudyFile);
                    % Remove delete trials
                    fPath = bst_fileparts(sStudy.FileName);
                    badFiles = cellfun(@(c)bst_fullfile(fPath, c), StudyMat.BadTrials, 'UniformOutput', 0);
                    iDel = find(ismember(badFiles, {sFuncFiles(iBad).FileName}));
                    StudyMat.BadTrials(iDel) = [];
                    % Save list of bad trials in the study file
                    bst_save(StudyFile, StudyMat, 'v7');
                end
                % Delete functional files per study
                for j = 1 : length(iFuncFiles)
                    db_set(sqlConn, 'FunctionalFile', 'Delete', iFuncFiles(j));
                end
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
                sFuncFiles = db_get(sqlConn, 'FilesForKernel', FileName{i}, 'timefreq', {'Id', 'Study', 'FileName'});
                if ~isempty(sFuncFiles)
                    % Add files to the delete list
                    iStudies_timefreq = [iStudies_timefreq, [sFuncFiles.Study]];
                    iTimefreq = [iTimefreq, [sFuncFiles.Id]];
                end
                % Get dependent files: dipoles
                sFuncFiles = db_get(sqlConn, 'FilesForKernel', FileName{i}, 'dipoles', {'Id', 'Study', 'FileName'});
                if ~isempty(sFuncFiles)
                    % Add files to the delete list
                    iStudies_dipoles = [iStudies_dipoles, [sFuncFiles.Study]];
                    iDipoles = [iDipoles, [sFuncFiles.Id]];
                end
            end
        end
        % Build full files list
        sFuncFiles = db_get(sqlConn, 'FunctionalFile', [iTimefreq, iDipoles], 'FileName');
        for i = 1:length(sFuncFiles)
            FullFilesList{end+1} = bst_fullfile(ProtocolInfo.STUDIES, sFuncFiles(i).FileName);
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
                iFuncFiles   = [iResultsDel, iTimefreqDel, iDipolesDel];
                sStudy = db_get(sqlConn, 'Study', iStudy);
                % Delete functional files per study
                for j = 1 : length(iFuncFiles)
                    db_set(sqlConn, 'FunctionalFile', 'Delete', iFuncFiles(j));
                end
                % If result deleted from a 'default_study' node
                isDefaultStudy = strcmpi(sStudy.Name, bst_get('DirDefaultStudy'));
                if isDefaultStudy
                    db_links('Subject', sStudy.Subject);
                    isTreeUpdateModel = 1;
                else
                    db_links('Study', iStudy);
                    panel_protocols('UpdateNode', 'Study', iStudy);
                end
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
        % Get matrix and timefreq filenames
        sFuncFiles = db_get(sqlConn, 'FunctionalFile', [iMatrix, iTimefreq], {'Id', 'Study', 'FileName'});
        FullFilesList = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES,f), {sFuncFiles.FileName}, 'UniformOutput',0);
        % Delete files
        if (file_delete(FullFilesList, ~isUserConfirm) == 1)
            iUniqueStudies = unique([sFuncFiles.Study]);
            for i = 1:length(iUniqueStudies)
                % Delete functional files per study
                iStudy = iUniqueStudies(i);
                ixs = find([sFuncFiles.Study] == iStudy);
                for j = 1 : length(ixs)
                    db_set(sqlConn, 'FunctionalFile', 'Delete', sFuncFiles(ixs(j)).Id);
                end
            end
            iModifiedStudies = iUniqueStudies;
        end
        
    otherwise
        % Node that cannot be deleted
        return
end


%% ===== UPDATE DATABASE =====
% If some studies were modified
if ~isempty(iModifiedStudies)
    if isempty(db_get(sqlConn, 'Study', ProtocolInfo.iStudy))
        ProtocolInfo.iStudy = [];
        bst_set('ProtocolInfo', ProtocolInfo);
    end
end
sql_close(sqlConn);

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





