function node_rename(bstNode, newComment)
% NODE_RENAME: Rename a node and perform all the modifications in files and database.
%
% USAGE:  node_rename(bstNode)  : Ask the user what is the new comment field
%         node_rename(bstNode, newComment) 

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
% Authors: Francois Tadel, 2008-2015
%          Raymundo Cassani, 2022


%% ===== INITIALIZATION =====
% If newComment is not define, just initialize it (defined later)
if (nargin == 1)
    newComment = [];
end

% Get Protocol directories
ProtocolInfo      = bst_get('ProtocolInfo');
iModifiedStudies  = [];
iModifiedSubjects = [];
isUpdateLinks     = 0;
% Get all node description
nodeType = char(bstNode.getType());
iItem    = bstNode.getStudyIndex();
iSubItem = bstNode.getItemIndex();
% Get short filename
fileName = char(bstNode.getFileName());
nodeSel = [];

% Switch between nodes types
switch lower(nodeType)
    
%% ===== SUBJECT (Name) =====
    case {'subject', 'studysubject'}
        % For 'StudySubject' nodes, both iItem and iSubject are stored in node
        if strcmpi(nodeType, 'studysubject')
            iSubject = iSubItem;
        else
            iSubject = iItem;
        end
        % Get subject
        sSubject = db_get('Subject', iSubject, {'Name', 'FileName'}, 1);
        % If subject is not default subject or group subject
        if strcmp(sSubject.Name, bst_get('DirDefaultSubject')) || strcmp(sSubject.Name, bst_get('NormalizedSubjectName'))
            return
        end
        
        % Get new comment
        if isempty(newComment)
            newComment = GetNewComment(bstNode, 'Name');
        end
        if isempty(newComment), return, end
        % Rename condition
        oldName = bst_fileparts(sSubject.FileName);
        newName = file_standardize(newComment);
        if ~strcmpi(oldName, newName)
            db_rename_subject(oldName, newName);
        end
        
        
%% ===== ANATOMY AND SURFACES (Comment) =====
    case {'anatomy', 'scalp', 'outerskull', 'innerskull', 'cortex', 'other', 'fibers', 'fem'}
        iSubject = iItem;
        iSurface = iSubItem;
        % Get new comment
        if isempty(newComment)
            newComment = GetNewComment(bstNode, 'Comment');
        end
        if isempty(newComment), return, end
        % Update File, Node display and Database
        if file_update(bst_fullfile(ProtocolInfo.SUBJECTS, fileName), 'Field', 'Comment', newComment);
            bstNode.setComment(newComment);
            % Update comment
            [iAnatFile, sAnatFile] = db_set('AnatomyFile', struct('Name', newComment), iSurface);
            % If new tess comment contains a keyword (head, cortex, scalp, brain, ...)
            % => update surface type (only if surface type changed)
            prevType = sAnatFile.SurfaceType;
            % SCALP
            if ~strcmpi(prevType, 'Scalp') && (~isempty(strfind(lower(newComment), 'head')) || ~isempty(strfind(lower(newComment), 'scalp')) || ~isempty(strfind(lower(newComment), 'skin')))
                node_set_type(bstNode, 'Scalp');
            % CORTEX
            elseif ~strcmpi(prevType, 'Cortex') && ~isempty(strfind(lower(newComment), 'cortex'))
                node_set_type(bstNode, 'Cortex');
            % OUTER SKULL
            elseif ~strcmpi(prevType, 'OuterSkull') && ~isempty(strfind(lower(newComment), 'outer'))
                node_set_type(bstNode, 'OuterSkull');
            % INNER SKULL
            elseif ~strcmpi(prevType, 'InnerSkull') && ~isempty(strfind(lower(newComment), 'inner'))
                node_set_type(bstNode, 'InnerSkull');
            else
                iModifiedSubjects = iSubject;
            end
            nodeSel = bstNode;
        end

%% ===== STUDY (Name) =====
    case 'study'
        iStudy = iItem;
        sStudy = db_get('Study', iStudy, 'Name');
        % Check that it is not a default study
        if ismember(sStudy.Name, {bst_get('DirAnalysisIntra'), bst_get('DirAnalysisInter')})
            return 
        end
        % Get new comment
        if isempty(newComment)
            newComment = GetNewComment(bstNode, 'Name');
        end
        if isempty(newComment)
            return
        end
        % Update File, Node display and Database
        if file_update(bst_fullfile(ProtocolInfo.STUDIES, fileName), 'Field', 'Name', newComment);
            bstNode.setComment(newComment);
            db_set('Study', struct('Name', newComment), iStudy);
            iModifiedStudies = iStudy;
        end

%% ===== CONDITION =====
    % Modify: Directory name + studies definition
    case 'condition'
        % Rename condition
        fileName = bst_fileparts(fileName);
        [SubjectName, oldCond] = bst_fileparts(fileName, 1);
        newCond = file_standardize(newComment);
        if ~strcmpi(oldCond, newCond)
            oldPath = bst_fullfile(SubjectName, oldCond);
            newPath = bst_fullfile(SubjectName, newCond);
            db_rename_condition(oldPath, newPath);
        end

%% ===== CHANNEL, HEAD MODEL, DATA, RESULTS, STAT, DIPOLES, MATRIX, TIMEFREQ  (Comment) =====
    case {'channel', 'headmodel', 'data', 'rawdata', 'results', 'kernel', ...
          'pdata', 'presults', 'ptimefreq', 'pspectrum', 'pmatrix', ...
          'dipoles', 'matrix', 'timefreq', 'spectrum'}
        iStudy = iItem;
        % Get new comment
        if isempty(newComment)
            newComment = GetNewComment(bstNode, 'Comment');
        end
        if isempty(newComment), return, end
        % Update File, Node display and Database
        if file_update(bst_fullfile(ProtocolInfo.STUDIES, fileName), 'Field', 'Comment', newComment);
            bstNode.setComment(newComment);
            db_set('FunctionalFile', struct('Name', newComment), iSubItem);
            iModifiedStudies = iStudy;
            % If results file is a kernel-only file: Update links
            isUpdateLinks = strcmpi(nodeType, 'kernel');
            nodeSel = bstNode;
        end    

%% ===== DATA LIST and MATRIX LIST (Comment) =====
    case {'datalist', 'matrixlist'}
        % Get selected study
        iStudy = iItem;
        sqlConn = sql_connect();
        % Get all the data files held by this list
        sFuncFiles = db_get(sqlConn, 'FilesInFileList', iSubItem, 'Id');
        iFoundData = [sFuncFiles.Id];
        % If some data files were found
        if ~isempty(iFoundData)
            % Get new comment
            if isempty(newComment)
                newComment = GetNewComment(bstNode, 'Comment');
            end
            if isempty(newComment), return, end
            % Remove parenthesis
            newComment = str_remove_parenth(newComment);
            % Update list name in Brainstorm database
            db_set(sqlConn, 'FunctionalFile', struct('Name', newComment), iSubItem);
            % Rename all child files
            for i = 1:length(iFoundData)
                % Build file comment
                fileComment = sprintf('%s (#%d)', newComment, i);
                % Children filename
                sFuncFile = db_get(sqlConn, 'FunctionalFile', iFoundData(i), 'FileName');
                % Update File, Node display and Database
                if file_update(bst_fullfile(ProtocolInfo.STUDIES, sFuncFile.FileName), 'Field', 'Comment', fileComment);
                    % Update Brainstorm database
                    db_set('FunctionalFile', struct('Name', fileComment), iFoundData(i));
                end
            end
            iModifiedStudies = iStudy;
        end
        sql_close(sqlConn);
        
%% ===== DATABASE (edit) =====
    case {'subjectdb', 'studydbsubj', 'studydbcond'}
        % Edit protocol
        % iProtocol = bst_get('iProtocol');
        % gui_edit_protocol('edit', iProtocol);

    otherwise
        % Node that cannot be renamed
        return
end


%% ===== UPDATE ENVIRONMENT =====
% Progress bar
bst_progress('start', 'Rename', 'Updating database...');
% If some subjects were modified
if ~isempty(iModifiedSubjects)
    % Refresh whole tree
    if (iModifiedSubjects(1) < 0)
        panel_protocols('UpdateTree');
    % Refresh only specific subjects
    else
        panel_protocols('UpdateNode', 'Subject', iModifiedSubjects);
    end
end
% If some studies were modified
if ~isempty(iModifiedStudies)
    panel_protocols('UpdateNode', 'Study', iModifiedStudies);
    % Update results links
    if isUpdateLinks
        sStudy = db('Study', iStudy, {'Name', 'Subject'});
        % Check if default study
        isDefaultStudy = strcmpi(sStudy.Name, bst_get('DirDefaultStudy'));
        % If added to a 'default_study' node: need to update results links 
        if isDefaultStudy
            % Update links to the new results file 
            db_links('Subject', sStudy.Subject);
            % Update whole tree display
            panel_protocols('UpdateTree');
        else
            % Update links to the new results file 
            db_links('Study', iStudy);
            % Update display of the study node
            panel_protocols('UpdateNode', 'Study', iStudy);
        end
    end
end  
% Re-select edited node
if ~isempty(nodeSel)
    panel_protocols('SelectNode', [], char(nodeSel.getType()), nodeSel.getStudyIndex(), nodeSel.getItemIndex());
end
% Progress bar
bst_progress('stop');


end



%% ===== UPDATE FIELD IN FILE =====
function newComment = GetNewComment(bstNode, fieldName)
    % Ask user new Comment field
    newComment = java_dialog('input', ['Edit field "' fieldName '":'], 'Rename object', [], char(bstNode.getComment()));
    % If user did not answer or did not change the Comment field
    if isempty(newComment) || strcmpi(newComment, char(bstNode.getComment()))
        newComment = [];
        return;
    end
end


