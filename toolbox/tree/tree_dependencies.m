function [ iDepStudies, iDepItems, targetNodeType ] = tree_dependencies( bstNodes, targetNodeType, NodelistOptions, GetBadTrials )
% TREE_DEPENDENCIES: Get all the data or results files that depend on the input nodes.
%
% USAGE:  [ iDepStudies, iDepItems, targetNodeType ] = tree_dependencies( bstNodes, targetNodeType, NodelistOptions, GetBadTrials )
%         [ iDepStudies, iDepItems, targetNodeType ] = tree_dependencies( bstNodes, targetNodeType, NodelistOptions )
%         [ iDepStudies, iDepItems, targetNodeType ] = tree_dependencies( bstNodes, targetNodeType )
%
% INPUT:
%     - bstNodes       : Array of BstNode
%     - targetNodeType : {'data', 'results', 'pdata', 'presults','ptimefreq','pspectrum', 'pmatrix', 'raw', 'rawcondition', 'matrix', 'any'}
%     - NodelistOptions: Structure to filter the files by name or comment
%     - GetBadTrials   : If 1, get all the data files (default)
%                        If 0, get only the data files that are NOT marked as bad trials 
%
% OUTPUT:
%     - iDepStudies     : Indices of the studies that were found
%     - iDepItems       : Indices of the data or results files, in each study
%     - targetNodeType  : Data type that is selected in the case of "any" nodetype

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
% Authors: Francois Tadel, 2008-2013

% Parse inputs
if (nargin < 3) || isempty(NodelistOptions)
    NodelistOptions = [];
end
if (nargin < 4) || isempty(GetBadTrials)
    GetBadTrials = 1;
end

% Get all nodes descriptions
for i = 1:length(bstNodes)
    nodeTypes{i}     = char(bstNodes(i).getType());
    nodeStudies(i)   = bstNodes(i).getStudyIndex();
    nodeSubItems(i)  = bstNodes(i).getItemIndex();
    nodeFileNames{i} = char(bstNodes(i).getFileName());
    nodeComments{i}  = char(bstNodes(i).getComment());
end

% Auto-detect data type: use first node
if strcmpi(targetNodeType, 'any') && (length(bstNodes) >= 1)
    switch (lower(nodeTypes{1}))
        case {'data', 'rawdata', 'datalist'}
            targetNodeType = 'data';
        case {'results', 'link'}
            targetNodeType = 'results';
        case {'timefreq', 'spectrum'}
            targetNodeType = 'timefreq';
        case {'ptimefreq', 'pspectrum'}
            targetNodeType = 'ptimefreq';
        case {'matrix', 'matrixlist'}
            targetNodeType = 'matrix';
        case {'pdata', 'presults', 'dipoles', 'pmatrix'}
            targetNodeType = lower(nodeTypes{1});
        otherwise
            iDepStudies = [];
            iDepItems = [];
            targetNodeType = 'none';
            return;
    end
end

iSearch = panel_protocols('GetSelectedSearch');

% Pre-process file filters
if ~isempty(NodelistOptions)
    if ~isempty(strtrim(NodelistOptions.String))
        % Options
        NodelistOptions.isSelect  = strcmpi(NodelistOptions.Action, 'Select');
    end
elseif iSearch > 0
    NodelistOptions = bst_get('NodelistOptions');
    NodelistOptions.String = '';
end

sqlConn = sql_connect();
% Capture selection errors
try
    % Define target studies
    iTargetStudies = [];
    iParentFiles   = [];
    iDepStudies = [];
    iDepItems   = [];
    % Process all the selected nodes
    for iNode = 1:length(bstNodes)
        % Process all the studies of this node
        switch (lower(nodeTypes{iNode}))
            % ==== DATABASE ====
            case {'studydbsubj', 'studydbcond'}
                % Get the whole database
                sSubjects = db_get(sqlConn, 'Subjects', 0, {'Id', 'FileName', 'Name'});
                % Get list of subjects (sorted alphabetically => same order as in the tree)
                iGroupSubject = find(strcmp({sSubjects.Name}, bst_get('NormalizedSubjectName')), 1);
                [tmp__, iSubjectsSorted] = sort_nat({sSubjects.Name});
                % Place group analysis subject at the top of the list
                if ~isempty(iGroupSubject)
                    iSubjectsSorted(iSubjectsSorted == iGroupSubject) = [];
                    iSubjectsSorted = [iGroupSubject, iSubjectsSorted];
                end
                % Add inter-subject node
                iTargetStudies = [iTargetStudies, -2];
                iParentFiles = [iParentFiles, 0];
                % Process each subject
                for i = 1:length(iSubjectsSorted)
                    iSubject = iSubjectsSorted(i);
                    % Get subject filename
                    SubjectFile = sSubjects(iSubject).FileName;
                    % Get all the studies for this subject
                    sStudies = db_get(sqlConn, 'StudiesFromSubject', SubjectFile, 'Id', 'intra_subject');
                    iTargetStudies = [iTargetStudies, [sStudies.Id]];
                    iParentFiles = [iParentFiles, 0];
                end

            % ==== SUBJECT ====
            case 'studysubject'
                % If directory (in subject/condition display, StudyIndex = 0)
                if (nodeStudies(iNode) == 0)
                    % Get all the studies related to this subject
                    sStudies = db_get(sqlConn, 'StudiesFromSubject', nodeFileNames{iNode}, 'Id', 'intra_subject');
                    iTargetStudies = [iTargetStudies, [sStudies.Id]];
                    iParentFiles = [iParentFiles, 0];
                % Else : study node (in condition/subject display, StudyIndex = 0)
                else
                    % Just add the study
                    iTargetStudies = [iTargetStudies, nodeStudies(iNode)];
                    iParentFiles = [iParentFiles, 0];
                end

            % ==== STUDY ====
            case {'study', 'defaultstudy'}
                % Intra-subject node in display by condition: Treat as a condition
                if (nodeStudies(iNode) == 0)
                    sStudies = db_get(sqlConn, 'StudyWithCondition', bst_fileparts(nodeFileNames{iNode}), 'Id');
                    iTargetStudies = [iTargetStudies, [sStudies.Id]];
                    iParentFiles = [iParentFiles, 0];
                % Else: regular study
                else
                    % Just add the study
                    iTargetStudies = [iTargetStudies, nodeStudies(iNode)];
                    iParentFiles = [iParentFiles, 0];
                end
            % ==== CONDITION ====
            case {'condition', 'rawcondition'}
                % Get all the studies related with the condition name
                sStudies = db_get(sqlConn, 'StudyWithCondition', bst_fileparts(nodeFileNames{iNode}), 'Id');
                iTargetStudies = [iTargetStudies, [sStudies.Id]];
                iParentFiles = [iParentFiles, 0];
                
            % ==== SUBFOLDER ====
            case 'folder'
                %TODO
                % Add the study and ParentFile
                iTargetStudies = [iTargetStudies, nodeStudies(iNode)];
                iParentFiles = [iParentFiles, nodeSubItems(iNode)];

            % ==== HEADMODEL ====
            case 'headmodel'
                % If looking for headmodel in headmodel, return headmodel
                if strcmpi(targetNodeType, 'headmodel')
                     iTargetStudies = [iTargetStudies, nodeStudies(iNode)];
                     iParentFiles = [iParentFiles, 0];
                end

            % ==== DATA ====
            case {'data', 'rawdata'}
                iStudy = nodeStudies(iNode);
                % Check for bad trials
                if ~GetBadTrials
                    % Get study
                    sFuncFile = db_get(sqlConn, 'FunctionalFile', nodeFileNames{iNode});
                    % Ignore bad trials
                    if sFuncFile.ExtraNum % .BadTrial
                        continue;
                    end
                end
                % Items to include depend on the node type to include
                switch lower(targetNodeType)
                    case 'data'
                        % Check search options
                        if ~isempty(NodelistOptions) && ~isFileSelected(nodeFileNames{iNode}, nodeComments{iNode}, NodelistOptions, targetNodeType)
                            continue;
                        end
                        % Include the selected data nodes
                        iDepStudies = [iDepStudies nodeStudies(iNode)];
                        iDepItems   = [iDepItems   nodeSubItems(iNode)];

                    case 'results'
                        % Find the results associated with this data node
                        sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', nodeSubItems(iNode), 'result', {'Id', 'FileName', 'Name', 'ExtraNum'});
                        iFoundResults = [sFuncFiles.Id];
                        if ~isempty(iFoundResults)
                            ResultsFiles = {sFuncFiles.FileName};
                            ResultsComments = {sFuncFiles.Name};
                            ResultsTypes = {'results', 'link'};
                            ResultsTypes = ResultsTypes(1 + [sFuncFiles.ExtraNum]); %.isLink
                            % === Check file filters ===
                            if ~isempty(NodelistOptions)
                                iFoundResults = iFoundResults(isFileSelected(ResultsFiles, ResultsComments, NodelistOptions, ResultsTypes, iStudy));
                            end
                            iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundResults))];
                            iDepItems   = [iDepItems iFoundResults];
                        end

                    case 'timefreq'
                        iStudy = nodeStudies(iNode);
                        % Find the results associated with this data node
                        sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', nodeSubItems(iNode), 'timefreq', {'Id', 'FileName', 'Name'});
                        iFoundTf = [sFuncFiles.Id];
                        if ~isempty(iFoundTf)
                            TimefreqFiles = {sFuncFiles.FileName};
                            TimefreqComments = {sFuncFiles.Name};
                            % === Check file filters ===
                            if ~isempty(NodelistOptions)
                                iFoundTf = iFoundTf(isFileSelected(TimefreqFiles, TimefreqComments, NodelistOptions, targetNodeType));
                            end
                            iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundTf))];
                            iDepItems   = [iDepItems iFoundTf];
                        end

                    case 'dipoles'
                        iStudy = nodeStudies(iNode);
                        % Find the files associated with this data node
                        sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', nodeSubItems(iNode), 'dipoles', {'Id', 'FileName', 'Name'});
                        iFoundDip = [sFuncFiles.Id];
                        if ~isempty(iFoundDip)
                            DipolesFiles = {sFuncFiles.FileName};
                            DipolesComments = {sFuncFiles.Name};
                            % === Check file filters ===
                            if ~isempty(NodelistOptions)
                                iFoundDip = iFoundDip(isFileSelected(DipolesFiles, DipolesComments, NodelistOptions, targetNodeType));
                            end
                            iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundDip))];
                            iDepItems   = [iDepItems iFoundDip];
                        end
                end

            % ==== DATA LIST ====
            case 'datalist'
                % Get selected study
                iStudy = nodeStudies(iNode);
                % Get all the data files held by this datalist
                sFuncFiles = db_get(sqlConn, 'FilesInFileList', nodeSubItems(iNode), {'Id', 'FileName', 'Name', 'ExtraNum'});
                iFoundData = [sFuncFiles.Id];
                % Remove bad trials
                if ~GetBadTrials
                    iFoundData = iFoundData([sFuncFiles.ExtraNum] == 0); % .BadTrial
                end
                % If some files were found
                if ~isempty(iFoundData)
                    % Items to include depend on the node type to include
                    switch lower(targetNodeType)
                        case 'data'
                            % === Check file filters ===
                            FoundDataFiles = {sFuncFiles.FileName};
                            FoundDataComments = {sFuncFiles.Name};
                            if ~isempty(NodelistOptions)
                                iFoundData = iFoundData(isFileSelected(FoundDataFiles, FoundDataComments, NodelistOptions, targetNodeType));
                            end
                            iDepItems = [iDepItems, iFoundData];
                            iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundData))];

                        case 'results'
                            % If there are result files associated to a datafile
                            if sql_query('EXIST', 'FunctionalFile', struct('Type', 'result', 'Study', iStudy), 'AND ParentFile IS NOT NULL AND ExtraStr1 IS NOT NULL')
                                for id = 1:length(iFoundData)
                                    % Find the results associated with this data node
                                    sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', iFoundData(id), 'result', {'Id', 'FileName', 'Name', 'ExtraNum'});
                                    iFoundResults = [sFuncFiles.Id];
                                    ResultsFiles = {sFuncFiles.FileName};
                                    ResultsComment = {sFuncFiles.Name};
                                    ResultsTypes = {'results', 'link'};
                                    ResultsTypes = ResultsTypes(1 + [sFuncFiles.ExtraNum]); %.isLink
                                    % The results that were found
                                    if ~isempty(iFoundResults)
                                        % === Check file filters ===
                                        if ~isempty(NodelistOptions)
                                            iFoundResults = iFoundResults(isFileSelected(ResultsFiles, ResultsComment, NodelistOptions, ResultsTypes, iStudy));
                                        end
                                        iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundResults))];
                                        iDepItems   = [iDepItems iFoundResults];
                                    end
                                end
                            end

                        case 'timefreq'
                            for id = 1:length(iFoundData)
                                % Find the files associated with this data node
                                sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', iFoundData(id), 'timefreq', {'Id', 'FileName', 'Name'});
                                iFoundTf = [sFuncFiles.Id];
                                TimefreqFiles = {sFuncFiles.FileName};
                                TimefreqComments = {sFuncFiles.Name};
                                % The files that were found
                                if ~isempty(iFoundTf)
                                    % === Check file filters ===
                                    if ~isempty(NodelistOptions)
                                        iFoundTf = iFoundTf(isFileSelected(TimefreqFiles, TimefreqComments, NodelistOptions, targetNodeType));
                                    end
                                    iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundTf))];
                                    iDepItems   = [iDepItems iFoundTf];
                                end
                            end

                        case 'dipoles'
                            for id = 1:length(iFoundData)
                                % Find the files associated with this data node
                                sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', iFoundData(id), 'dipoles', {'Id', 'FileName', 'Name'});
                                iFoundDip = [sFuncFiles.Id];
                                DipolesFiles = {sFuncFiles.FileName};
                                DipolesComments = {sFuncFiles.Name};
                                % The files that were found
                                if ~isempty(iFoundDip)
                                    % === Check file filters ===
                                    if ~isempty(NodelistOptions)
                                        iFoundDip = iFoundDip(isFileSelected(DipolesFiles, DipolesComments, NodelistOptions, targetNodeType));
                                    end
                                    iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundDip))];
                                    iDepItems   = [iDepItems iFoundDip];
                                end
                            end
                    end
                end

            % ==== RESULTS ====
            case {'results', 'link'}
                % Items to include depend on the node type to include
                switch lower(targetNodeType)
                    case 'data'
                        % Nothing to include
                    case 'results'
                        % Get selected study
                        iStudy = nodeStudies(iNode);
                        iResult = nodeSubItems(iNode);
                        fileName = nodeFileNames{iNode};
                        fileComment = nodeComments{iNode};
                        % If results is not a shared kernel (not attached to a datafile)
                        sResult = db_get(sqlConn, 'FunctionalFile', iResult);
                        if ~isPureKernel(sResult)
                            if isempty(NodelistOptions) || isFileSelected(fileName, fileComment, NodelistOptions, targetNodeType, iStudy)
                                % Include results list
                                iDepStudies = [iDepStudies iStudy];
                                iDepItems   = [iDepItems   iResult];
                            end
                        end
                    case 'timefreq'
                        iStudy = nodeStudies(iNode);
                        % Find the timefreq associated with this result node
                        sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', nodeSubItems(iNode), 'timefreq', {'Id', 'FileName', 'Name'});
                        iFoundTf = [sFuncFiles.Id];
                        if ~isempty(iFoundTf)
                            TimefreqFiles = {sFuncFiles.FileName};
                            TimefreqComments = {sFuncFiles.Name};
                            % === Check file filters ===
                            if ~isempty(NodelistOptions)
                                iFoundTf = iFoundTf(isFileSelected(TimefreqFiles, TimefreqComments, NodelistOptions, targetNodeType));
                            end
                            iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundTf))];
                            iDepItems   = [iDepItems iFoundTf];
                        end
                    case 'dipoles'
                        iStudy = nodeStudies(iNode);
                        % Find the file associated with this data node
                        sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', nodeSubItems(iNode), 'dipoles', {'Id', 'FileName', 'Name'});
                        iFoundDip = [sFuncFiles.Id];
                        if ~isempty(iFoundDip)
                            DipolesFiles = {sFuncFiles.FileName};
                            DipolesComments = {sFuncFiles.Name};
                            % The files that were found
                            if ~isempty(iFoundDip)
                                % === Check file filters ===
                                if ~isempty(NodelistOptions)
                                    iFoundDip = iFoundDip(isFileSelected(DipolesFiles, DipolesComments, NodelistOptions, targetNodeType));
                                end
                                iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundDip))];
                                iDepItems   = [iDepItems iFoundDip];
                            end
                        end
                end

            % ==== TIMEFREQ ====
            case {'timefreq', 'spectrum'}
                % Get file
                if strcmpi(targetNodeType, 'timefreq')
                    % Check search options
                    if ~isempty(NodelistOptions) && ~isFileSelected(nodeFileNames{iNode}, nodeComments{iNode}, NodelistOptions, targetNodeType)
                        continue;
                    end
                    iDepStudies = [iDepStudies nodeStudies(iNode)];
                    iDepItems   = [iDepItems   nodeSubItems(iNode)];
                end

            % ==== STAT: TIMEFREQ ====
            case {'ptimefreq', 'pspectrum'}
                % Get file
                if strcmpi(targetNodeType, 'ptimefreq')
                    % Check search options
                    if ~isempty(NodelistOptions) && ~isFileSelected(nodeFileNames{iNode}, nodeComments{iNode}, NodelistOptions, targetNodeType)
                        continue;
                    end
                    iDepStudies = [iDepStudies nodeStudies(iNode)];
                    iDepItems   = [iDepItems   nodeSubItems(iNode)];
                end
                
            % ==== STAT: OTHER ====
            case {'pdata', 'presults', 'pmatrix'}
                if strcmpi(targetNodeType, nodeTypes{iNode})
                    % Check search options
                    if ~isempty(NodelistOptions) && ~isFileSelected(nodeFileNames{iNode}, nodeComments{iNode}, NodelistOptions, targetNodeType)
                        continue;
                    end
                    iDepStudies = [iDepStudies nodeStudies(iNode)];
                    iDepItems   = [iDepItems   nodeSubItems(iNode)];
                end
                
            % ==== DIPOLES ====
            case 'dipoles'
                if strcmpi(targetNodeType, nodeTypes{iNode})
                    % Check search options
                    if ~isempty(NodelistOptions) && ~isFileSelected(nodeFileNames{iNode}, nodeComments{iNode}, NodelistOptions, targetNodeType)
                        continue;
                    end
                    iDepStudies = [iDepStudies nodeStudies(iNode)];
                    iDepItems   = [iDepItems   nodeSubItems(iNode)];
                end
                
            % ==== MATRIX ====
            case 'matrix'
                % Get file
                switch lower(targetNodeType)
                    case 'matrix'
                        % Check file filters
                        if ~isempty(NodelistOptions) && ~isFileSelected(nodeFileNames{iNode}, nodeComments{iNode}, NodelistOptions, targetNodeType)
                            continue;
                        end
                        % Include the selected data node
                        iDepStudies = [iDepStudies nodeStudies(iNode)];
                        iDepItems   = [iDepItems   nodeSubItems(iNode)];
                        
                    case 'timefreq'
                        iStudy = nodeStudies(iNode);
                        % Find the timefreq associated with this data node in same Study
                        sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', nodeSubItems(iNode), 'timefreq', {'Id', 'FileName', 'Name'});
                        iFoundTf = [sFuncFiles.Id];
                        if ~isempty(sFuncFiles)
                            TimefreqFiles = {sFuncFiles.FileName};
                            TimefreqComments = {sFuncFiles.Name};
                            % === Check file filters ===
                            if ~isempty(NodelistOptions)
                                iFoundTf = iFoundTf(isFileSelected(TimefreqFiles, TimefreqComments, NodelistOptions, targetNodeType));
                            end
                            iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundTf))];
                            iDepItems   = [iDepItems iFoundTf];
                        end
                end

            % ==== MATRIX LIST ====
            case 'matrixlist'
                % Get selected study
                iStudy = nodeStudies(iNode);
                % Get all the matrix files held by this matrixlist
                sFuncFiles = db_get(sqlConn, 'FilesInFileList', nodeSubItems(iNode), {'Id', 'FileName', 'Name'});
                iFoundMatrix = [sFuncFiles.Id];
                % If some files were found
                if ~isempty(iFoundMatrix)
                    % Items to include depend on the node type to include
                    switch lower(targetNodeType)
                        case 'matrix'
                            % === Check file filters ===
                            FoundMatrixFiles = {sFuncFiles.FileName};
                            FoundMatrixComments = {sFuncFiles.Name};
                            if ~isempty(NodelistOptions)
                                iFoundMatrix = iFoundMatrix(isFileSelected(FoundMatrixFiles, FoundMatrixComments, NodelistOptions, targetNodeType));
                            end
                            iDepItems = [iDepItems, iFoundMatrix];
                            iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundMatrix))];

                        case 'timefreq'
                            for id = 1:length(iFoundMatrix)
                                iMatrix = iFoundMatrix(id);
                                % Find the files associated with this data node
                                sFuncFiles = db_get(sqlConn, 'ChildrenFromFunctionalFile', iMatrix, 'timefreq', {'Id', 'FileName', 'Name'});
                                iFoundTf = [sFuncFiles.Id];
                                TimefreqFiles = {sFuncFiles.FileName};
                                TimefreqComments = {sFuncFiles.Name};
                                % The files that were found
                                if ~isempty(iFoundTf)
                                    % === Check file filters ===
                                    if ~isempty(NodelistOptions)
                                        iFoundTf = iFoundTf(isFileSelected(TimefreqFiles, TimefreqComments, NodelistOptions, targetNodeType));
                                    end
                                    iDepStudies = [iDepStudies, repmat(iStudy, size(iFoundTf))];
                                    iDepItems   = [iDepItems iFoundTf];
                                end
                            end
                    end
                end
        end
    end
catch
    iDepStudies = -10;
    iDepItems = -10;
    sql_close(sqlConn);
    return;
end

% If studies were found => Select all the data files in these studies
if ~isempty(iTargetStudies)
    iStudies = iTargetStudies;
    for i = 1:length(iStudies)
        if iParentFiles(i) > 0
            qryCond = struct('ParentFile', iParentFiles(i));
        else
            qryCond = struct();
        end
        qryCond.Study = iStudies(i);
        % Items to include depend on the node type to include
        switch lower(targetNodeType)
            case 'data'
                qryCond.Type = 'data';
                % Remove bad trials
                if ~GetBadTrials
                    qryCond.ExtraNum = 0;
                end
                sFuncFiles = db_get(sqlConn, 'FunctionalFile', qryCond, {'Id', 'FileName', 'Name', 'SubType'});
                iFoundData = [sFuncFiles.Id];
                % Add data files to list
                if ~isempty(iFoundData)
                    % Check file filters
                    if ~isempty(NodelistOptions)
                        % Get specific Data/RawData type
                        FileType = {sFuncFiles.SubType};
                        iRaw = strcmpi(FileType, 'raw');
                        FileType(iRaw) = {'rawdata'};
                        FileType(~iRaw) = {'data'};
                        FoundDataFiles = {sFuncFiles.FileName};
                        FoundDataComments = {sFuncFiles.Name};
                        iFoundData = iFoundData(isFileSelected(FoundDataFiles, FoundDataComments, NodelistOptions, FileType));
                    end
                    iDepStudies = [iDepStudies, repmat(iStudies(i), 1, length(iFoundData))];
                    iDepItems   = [iDepItems,   iFoundData];
                end

            case 'results'
                % Get all results of this study that ARE NOT SHARED KERNELS (imaging kernel not attched to a datafile)
                % === Check file filters ===
                sFuncFiles = db_get(sqlConn, 'FilesWithStudy', iStudies(i), 'result', {'Id', 'FileName', 'Name', 'ExtraNum', 'ExtraStr1'});
                ResultsFiles = {sFuncFiles.FileName};
                ResultsComments = {sFuncFiles.Name};
                ResultsTypes = {'results', 'link'};
                ResultsTypes = ResultsTypes(1 + [sFuncFiles.ExtraNum]); %.isLink
                ResultsIds = [sFuncFiles.Id];
                if ~isempty(ResultsFiles)
                    % Get non-pure kernels + Check file filters
                    if ~isempty(NodelistOptions)
                        iValidResult = ~isPureKernel(sFuncFiles) & isFileSelected(ResultsFiles, ResultsComments, NodelistOptions, ResultsTypes, iStudies(i));
                    else
                        iValidResult = ~isPureKernel(sFuncFiles);
                    end
                    % Remove bad trials
                    for iRes = 1:length(iValidResult)
                        if iValidResult(iRes)
                            sFuncFileData = db_get(sqlConn, 'ParentFromFunctionalFile', ResultsIds(iRes), 'ExtraNum');
                            iValidResult(iRes) = ~sFuncFileData.ExtraNum;
                        end
                    end
                    % Return selected files
                    if ~isempty(ResultsIds(iValidResult))
                        % Add valid results files
                        iDepStudies = [iDepStudies, repmat(iStudies(i), 1, length(ResultsIds(iValidResult)))];
                        iDepItems   = [iDepItems,   ResultsIds(iValidResult)];
                    end
                end
                
            case 'timefreq'
                % Get all timefreq files of this study
                sFuncFiles = db_get(sqlConn, 'FilesWithStudy', iStudies(i), 'timefreq', {'Id', 'FileName', 'Name'});
                if ~isempty(sFuncFiles)
                    iFoundTf = [sFuncFiles.Id];
                    % Check file filters
                    if ~isempty(NodelistOptions)
                        PossibleFiles = {sFuncFiles.FileName};
                        PossibleComments = {sFuncFiles.Name};
                        iFoundTf = iFoundTf(isFileSelected(PossibleFiles, PossibleComments, NodelistOptions, targetNodeType));
                    end
                    % Remove bad trials
                    if ~GetBadTrials
                        iBadTrial = zeros(size(iFoundTf));
                        % Check file by file
                        for iTf = 1:length(iFoundTf)
                            % Get DataFile
                            sFuncFileParent = db_get(sqlConn, 'ParentFromFunctionalFile', iFoundTf(iTf), {'Id','Type','ParentFile'});
                            if isempty(sFuncFileParent)
                                continue;
                            end
                            % Time-freq on data
                            DataFileId = sFuncFileParent.Id;
                            % Time-freq on results: get DataFile
                            if ismember(sFuncFileParent.Type, {'result'})
                                DataFileId = sFuncFileParent.ParentFile;
                            % Time-freq on results: get DataFile
                            elseif strcmpi(sFuncFileParent.Type, 'matrix')
                                DataFileId = [];
                            end
                            % Check if bad trials
                            if ~isempty(DataFileId)
                                % Get the associated data file
                                sFuncFileData = db_get(sqlConn, 'FunctionalFile', DataFileId, 'ExtraNum');
                                % Check if data file is bad
                                iBadTrial(iTf) = sFuncFileData.ExtraNum;
                            end
                        end
                        % Remove all the detected bad trials
                        iFoundTf = iFoundTf(~iBadTrial);
                    end
                    % Add data files to list
                    if ~isempty(iFoundTf)
                        iDepStudies = [iDepStudies, repmat(iStudies(i), 1, length(iFoundTf))];
                        iDepItems   = [iDepItems,   iFoundTf];
                    end
                end

            case 'matrix'
                % Get all "matrix" files of this study
                sFuncFiles = db_get(sqlConn, 'FilesWithStudy', iStudies(i), 'matrix', {'Id', 'FileName', 'Name'});
                iFoundMat = [sFuncFiles.Id];
                if ~isempty(iFoundMat)
                    % === Check file filters ===
                    if ~isempty(NodelistOptions)
                        PossibleFiles = {sFuncFiles.FileName};
                        PossibleComments = {sFuncFiles.Name};
                        iFoundMat = iFoundMat(isFileSelected(PossibleFiles, PossibleComments, NodelistOptions, targetNodeType));
                    end
                    % Add data files to list
                    if ~isempty(iFoundMat)
                        iDepStudies = [iDepStudies, repmat(iStudies(i), 1, length(iFoundMat))];
                        iDepItems   = [iDepItems,   iFoundMat];
                    end
                end

            case 'headmodel'
                % Get all headmodels of this study
                sStudy = db_get(sqlConn, 'Study', iStudies(i), 'iHeadModel');
                if ~isempty(sStudy.iHeadModel)
                    iDepStudies = [iDepStudies, iStudies(i)];
                    iDepItems   = [iDepItems,   sStudy.iHeadModel];
                end
                
            case {'pdata', 'presults', 'ptimefreq', 'pspectrum', 'pmatrix'}
                % Get the stat files of the appropriate type
                qryCond = struct('Study', iStudies(i));
                qryCond.Type = 'stat';
                qryCond.SubType = targetNodeType(2:end);
                sFuncFiles = db_get(sqlConn, 'FunctionalFile', qryCond, {'Id', 'FileName', 'Name'});
                iStat = [sFuncFiles.Id] ;
                % If some valid files were found
                if ~isempty(iStat)
                    if ~isempty(NodelistOptions)
                        StatFiles = {sFuncFiles.FileName};
                        StatComments = {sFuncFiles.Comment};
                        iFoundMat = iStat(isFileSelected(StatFiles, StatComments, NodelistOptions, targetNodeType));
                    else
                        iFoundMat = iStat;
                    end
                    % Add stat files to list
                    if ~isempty(iFoundMat)
                        iDepStudies = [iDepStudies, repmat(iStudies(i), 1, length(iFoundMat))];
                        iDepItems   = [iDepItems,   iFoundMat];
                    end
                end
        end
    end
end
sql_close(sqlConn);

    %% ===== CHECK FILE NAME/COMMENT =====
    function isSelected = isFileSelected(FileNames, Comments, NodelistOptions, FileType, iStudy)
        % Parse inputs
        if (nargin < 5) || isempty(iStudy)
            iStudy = [];
        end
        % No input
        if isempty(FileNames) || isempty(Comments)
            isSelected = [];
            return;
        end
        % Force files list in cells
        if ischar(FileNames)
            FileNames = {FileNames};
        end
        if ischar(Comments)
            Comments = {Comments};
        end
        isActiveSearch = iSearch > 0;
        isActiveFilter = ~isempty(NodelistOptions.String);
        % Get active search
        if isActiveSearch
            searchRoot = panel_protocols('ActiveSearch', 'get', iSearch);
            if isempty(searchRoot)
                error('Could not find active search #%d', iSearch);
            end
        end
        % Get process box filter
        if isActiveFilter
            searchString = strtrim(NodelistOptions.String);
            % Advanced (shortened) search syntax
            if isempty(strfind(searchString, '"'))
                % If no quotes found in search string, consider it as a
                % whole string matching and not search syntax
                searchString = ['"' searchString '"'];
            end
            filterRoot = panel_search_database('StringToSearch', searchString, NodelistOptions.Target);
            invertSelection = ~NodelistOptions.isSelect;
            % Concatenate to search filter
            if isActiveSearch
                searchRoot = panel_search_database('ConcatenateSearches', ...
                    searchRoot, filterRoot, 'AND', invertSelection);
                invertSelection = 0;
            else
                searchRoot = filterRoot;
            end
        else
            invertSelection = 0;
        end

        if isActiveSearch || isActiveFilter
            % Apply search and filter together
            isSelected = node_apply_search(searchRoot, FileType, Comments, FileNames, iStudy);
            if invertSelection
                isSelected = ~isSelected;
            end
        else
            % Default: all the files are selected
            nFiles = length(FileNames);
            isSelected = true(1, nFiles);
        end
    end

end


%% ===== CHECK RESULTS TYPE =====
% Get all results of this study that ARE SHARED KERNELS (imaging kernel not attched to a datafile)
function isPure = isPureKernel(sResults)
    isPure = cellfun(@isempty, {sResults.ExtraStr1}) & ...
             ~cellfun(@(c)isempty(strfind(c, 'KERNEL')), {sResults.FileName});   
end

