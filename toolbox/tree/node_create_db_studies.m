function [bstDefaultNode, nodeStudiesDB, numTotalElems] = node_create_db_studies( nodeRoot, expandOrder, iSearch )
% NODE_CREATE_DB_STUDIES: Create a tree to represent the studies registered in current protocol.
% Populate a tree from its root node.
%
% USAGE:  bstDefaultNode = node_create_db_studies(nodeRoot, expandOrder)
%
% INPUT: 
%    - nodeRoot       : BstNode Java object (tree root)
%    - expandOrder    : {'condition', 'subject'}, type of the first level nodes:
%                        Describes how the information is organized : condition/subject or subject/condition
%    - iSearch        : ID of the active DB search, or empty/0 if none
% OUTPUT: 
%    - bstDefaultNode : default BstNode, that should be expanded and selected automatically
%                       or empty matrix if no default node is defined
%    - nodeStudiesDB  : Root node of the studies database tree
%    - numTotalElems  : Total number of nodes created

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
% Authors: Francois Tadel, 2008-2020
import org.brainstorm.tree.*;

%% ===== PARSE INPUTS =====
expandOrder = lower(expandOrder);
% Set default node
bstDefaultNode = [];
nodeStudiesDB  = [];
numTotalElems  = 0;
% Get current protocol directories, subjects and studies
ProtocolInfo = bst_get('ProtocolInfo');
isExpandTrials = 1;
if nargin < 3 || isempty(iSearch)
    iSearch = 0;
end
showParentNodes = node_show_parents(iSearch);

if strcmp(expandOrder, 'condition')
    disp('TODO: Functional view, conditions');
    return;
end


%% ===== CREATE TREE BASE =====  
% === CREATE ROOT ===
nodeListToSort = [];
% Create 'Datasets' node
switch (expandOrder)
    case 'subject'
        nodeStudiesDB = BstNode('studydbsubj', [ProtocolInfo.Comment ' (subjects)'], ProtocolInfo.STUDIES, 0, 0);
    case 'condition'
        nodeStudiesDB = BstNode('studydbcond', [ProtocolInfo.Comment ' (conditions)'], ProtocolInfo.STUDIES, 0, 0);
        % Sort conditions lists
        % nodeListToSort = [nodeListToSort, nodeStudiesDB];
end

% Get the default and inter study and all subjects
sqlConn = sql_connect();
sDefaultStudy  = db_get(sqlConn, 'DefaultStudy', '@default_subject', {'Id', 'FileName'});
sAnalysisStudy = db_get(sqlConn, 'Study', bst_get('DirAnalysisInter'), {'Id', 'FileName'});
sSubjects = db_get(sqlConn, 'Subjects', 1);
sql_close(sqlConn);
iDefaultSubject = find(strcmp({sSubjects.Name}, bst_get('DirDefaultSubject')), 1);
iGroupSubject   = find(strcmp({sSubjects.Name}, bst_get('NormalizedSubjectName')), 1);

% === CREATE DEFAULT_SUBJECT/DEFAULT_STUDY NODE ===
if ~isempty(sDefaultStudy)
    % Create analysis node
    nodeGlobal = BstNode('defaultstudy', '(Common files)', sDefaultStudy.FileName, 0, sDefaultStudy.Id);
    
    % Check whether we need to expand this node
    if ~isempty(ProtocolInfo.iStudy) && ProtocolInfo.iStudy == sDefaultStudy.Id
        node_create_study(nodeGlobal, nodeRoot, sDefaultStudy, sDefaultStudy.Id, [], isExpandTrials, [], iSearch);
        bstDefaultNode = nodeGlobal;
    else
        % Set the node as un-processed
        nodeGlobal.setUserObject(0);
        % Add a "Loading" node
        nodeGlobal.add(BstNode('loading', 'Loading...'));
    end
    
    % Add node to tree
    nodeStudiesDB.add(nodeGlobal);
end

% === CREATE INTER-SUBJECT ANALYSIS NODE ===
if ~isempty(sAnalysisStudy)
    % Create analysis node
    nodeAnalysis = BstNode('study', '(Inter-subject)', sAnalysisStudy.FileName, 0, sAnalysisStudy.Id);
    
    % Check whether we need to expand this node
    if ~isempty(ProtocolInfo.iStudy) && ProtocolInfo.iStudy == sAnalysisStudy.Id
        node_create_study(nodeAnalysis, nodeRoot, sAnalysisStudy, sAnalysisStudy.Id, [], isExpandTrials, [], iSearch);
        bstDefaultNode = nodeAnalysis;
    else
        % Set the node as un-processed
        nodeAnalysis.setUserObject(0);
        % Add a "Loading" node
        nodeAnalysis.add(BstNode('loading', 'Loading...'));
    end    

    % Add node to tree
    nodeStudiesDB.add(nodeAnalysis);
end

% === CREATE SUBJECTS NODES ===
% If exploration by subject : create at least a node per subject
if strcmpi(expandOrder, 'subject')
    % Sort subjects by Name
    [tmp__, iSubjectsSorted] = sort_nat({sSubjects.Name});
    % Place group analysis subject at the top of the list
    if ~isempty(iGroupSubject)
        iSubjectsSorted(iSubjectsSorted == iGroupSubject) = [];
        iSubjectsSorted = [iGroupSubject, iSubjectsSorted];
    end
    % Process all the subjects
    for i = 1:length(iSubjectsSorted)
        iSubject = iSubjectsSorted(i);
        % Skip default subject
        if iSubject == iDefaultSubject
            continue;
        end
        sSubject = sSubjects(iSubject);
        % Display name for default subject
        if ~isempty(iGroupSubject) && (iSubject == iGroupSubject)
            strComment = '(Group analysis)';
        else
            strComment = sSubject.Name;
        end
        
        % Create subject node
        nodeSubject = BstNode('studysubject', strComment, sSubject.FileName, sSubject.Id, 0);

        % Check whether we need to expand this node
        if ~isempty(ProtocolInfo.iSubject) && ProtocolInfo.iSubject == sSubject.Id
            [numElems, selectedStudy] = node_create_studysubject(nodeSubject, nodeRoot, sSubject, sSubject.Id, iSearch);
            % If subject is default subject (ProtocolInfo.iSubject)
            if ~isempty(selectedStudy)
                bstDefaultNode = selectedStudy;
            else
                bstDefaultNode = nodeSubject;
            end
        else
            % Set the node as un-processed
            nodeSubject.setUserObject(0);
            % Add a "Loading" node
            nodeSubject.add(BstNode('loading', 'Loading...'));
        end
        
        % Add node to tree
        nodeStudiesDB.add(nodeSubject);
    end
end

% Add 'Subjects database' node to root node
nodeRoot.add(nodeStudiesDB);

end
