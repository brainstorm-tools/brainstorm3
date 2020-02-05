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
ProtocolInfo     = bst_get('ProtocolInfo');
ProtocolSubjects = bst_get('ProtocolSubjects');
ProtocolStudies  = bst_get('ProtocolStudies');
if (isempty(ProtocolStudies))
    return
end
isExpandTrials = 1;
if nargin < 3 || isempty(iSearch)
    iSearch = 0;
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
% Create a hashtable to classify the study node
hashTableNodes = java.util.Hashtable();
% Create a node to store all the studies that do not have any condition defined
nodeNoCondition = BstNode('condition', 'Default condition', '', 0, 0);
isGlobalDisplayed = 0;

% === CREATE DEFAULT_SUBJECT/DEFAULT_STUDY NODE ===
nodeGlobal = [];
[sDefaultStudy, iDefaultStudy] = bst_get('DefaultStudy');
if ~isempty(sDefaultStudy) % && (~isempty(sDefaultStudy.Data) || ~isempty(sDefaultStudy.Result))
    % Create analysis node
    nodeGlobal = BstNode('defaultstudy', '(Common files)', sDefaultStudy.FileName, 0, iDefaultStudy);
    % Create node
    numElems = node_create_study(nodeGlobal, sDefaultStudy, iDefaultStudy, isExpandTrials, [], iSearch);
    if numElems > 0
        % Add node to database node
        nodeStudiesDB.add(nodeGlobal);
        numTotalElems = numTotalElems + numElems;
        % If global default study is default study (ProtocolInfo.iStudy)
        if (ProtocolInfo.iStudy == iDefaultStudy)
            bstDefaultNode = nodeGlobal;
        end
    end
end
% Get name of group subject
GroupSubject = bst_get('NormalizedSubjectName');

% === CREATE INTER-SUBJECT ANALYSIS NODE ===
[sAnalysisStudy, iAnalysisStudy] = bst_get('AnalysisInterStudy');
if ~isempty(sAnalysisStudy) && (~isempty(sAnalysisStudy.Data) || ~isempty(sAnalysisStudy.Result) || ~isempty(sAnalysisStudy.Stat) || ...
        ~isempty(sAnalysisStudy.Dipoles) || ~isempty(sAnalysisStudy.Timefreq) || ~isempty(sAnalysisStudy.Matrix))
    % Create analysis node
    nodeAnalysis = BstNode('study', '(Inter-subject)', sAnalysisStudy.FileName, 0, iAnalysisStudy);
    % Create node
    numElems = node_create_study(nodeAnalysis, sAnalysisStudy, iAnalysisStudy, isExpandTrials, [], iSearch);
    if numElems > 0
        % Add node to database node
        nodeStudiesDB.add(nodeAnalysis);
        numTotalElems = numTotalElems + numElems;
        % If inter-subject analysis study is default study (ProtocolInfo.iStudy)
        if (ProtocolInfo.iStudy == iAnalysisStudy)
            bstDefaultNode = nodeAnalysis;
        end
        % Display Global Common Files with it
        isGlobalDisplayed = 1;
    end
end

% === CREATE SUBJECTS NODES ===
% If exploration by subject : create at least a node per subject
if strcmpi(expandOrder, 'subject')
    % Sort subjects by Name
    [tmp__, iSubjectsSorted] = sort_nat({ProtocolSubjects.Subject.Name});
    % Find group analysis subject
    iSubjectGroup = find(strcmpi({ProtocolSubjects.Subject.Name}, GroupSubject));
    % If it exists: Place it at the top of the list
    if ~isempty(iSubjectGroup)
        iSubjectsSorted(iSubjectsSorted == iSubjectGroup) = [];
        iSubjectsSorted = [iSubjectGroup, iSubjectsSorted];
    end
    % Process all the subjects
    for i = 1:length(iSubjectsSorted)
        iSubject = iSubjectsSorted(i);
        sSubject = ProtocolSubjects.Subject(iSubject);
        % Display name for default subject
        if ~isempty(iSubjectGroup) && (iSubject == iSubjectGroup)
            strComment = '(Group analysis)';
        else
            strComment = sSubject.Name;
        end
        % Create subject node
        nodeSubject = BstNode('studysubject', strComment, sSubject.FileName, iSubject, 0);
        % Add subject node to root node
        nodeStudiesDB.add(nodeSubject);
        numTotalElems = numTotalElems + 1;
        % Add node reference to nodes hashtable
        hashTableNodes.put(sSubject.Name, nodeSubject);
    end
end


%% ===== CREATE STUDY NODES =====
% Build a list of all the intra-subjects analysis nodes
nodeListIntra_subj = [];
nodeListIntra_cond = [];
nodeListDefaultStudy_subj = [];
% Get list of raw conditions
listRaw = false(1, length(ProtocolStudies.Study));
for i = 1:length(ProtocolStudies.Study)
    cond = ProtocolStudies.Study(i).Condition;
    listRaw(i) = ~isempty(cond) && (length(cond{1}) > 4) && strcmpi(cond{1}(1:4), '@raw');
end
isRaw = find(listRaw);
isNonRaw = find(~listRaw);
% Sort studies by Condition (raw first, non-raw after)
[tmp__, iStudiesSortedRaw] = sort_nat(cellfun(@(c)c{1}, {ProtocolStudies.Study(isRaw).Condition}, 'UniformOutput', 0));
[tmp__, iStudiesSortedNonRaw] = sort_nat(cellfun(@(c)c{1}, {ProtocolStudies.Study(isNonRaw).Condition}, 'UniformOutput', 0));
iStudiesSorted = [isRaw(iStudiesSortedRaw), isNonRaw(iStudiesSortedNonRaw)];
% Check for database inconsistency
if (length(iStudiesSorted) ~= length(ProtocolStudies.Study))
    bst_error(['There are structure errors in this protocol, please reload it.' 10 '=> Right click on protocol node > Reload.'], 'Update database explorer', 0);
    ProtocolStudies.Study = [];
end

% Add studies entries for current protocol
for i = 1:length(ProtocolStudies.Study)
    iStudy = iStudiesSorted(i);
    nodeStudy = [];
    % Get current study
    sStudy = ProtocolStudies.Study(iStudy);
    if isempty(sStudy.BrainStormSubject)
        [isError, isFixed] = db_fix_protocol();
        if isError && isFixed
            bst_progress('stop');
            return
        elseif isError
            continue;
        end
    end
    % Find associated subject 
    [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
    % If no subject was found
    if isempty(sSubject)
        disp(['DB> Subject file "' sStudy.BrainStormSubject '" does not exist. You should delete manually this subject in the data folder and reload the protocol.']);
        continue;
%         [isError, isFixed] = db_fix_protocol();
%         if isError && isFixed
%             bst_progress('stop');
%             return
%         elseif isError
%             continue;
%         end
    end
    % If subject uses default study (Channel + Headmodel)
    if ~isempty(sSubject) && (sSubject.UseDefaultChannel == 2)
        isGlobalDisplayed = 1;
    end
    
    % Switch between different ways to organize the tree
    switch (expandOrder)
        % =====================================================================
        % === ORDER : SUBJECT/CONDITIONS ======================================
        % =====================================================================
        case 'subject'
            % ==== SUBJECT LEVEL ====
            % Try to get the subject node associated with the study
            nodeSubject = hashTableNodes.get(sSubject.Name);
            % If node not found, it is because the some studies reference subject folders that do not exist anymore...
            if isempty(nodeSubject) 
                if ~strcmpi(sSubject.Name, bst_get('DirDefaultSubject'))
                    disp('ERROR: A subject was created with "@default_subject" as name. Don''t know how to fix.');
                    continue
                end
                bst_progress('stop');
                return
            end

            % ==== CONDITION LEVEL ====
            % If a condition is specified for this study
            if ~isempty(sStudy.Condition)
                % For each condition level : create a node
                pathCondition = sSubject.Name;
                nodeParent = nodeSubject;
                for iCondition = 1:length(sStudy.Condition)
                    % Extends node path to current condition
                    pathCondition = bst_fullfile(pathCondition, sStudy.Condition{iCondition});
                    % Try to get the current subject/condition node
                    nodeCondition = hashTableNodes.get(lower(pathCondition));
                    % If node does not already exist : create it
                    if isempty(nodeCondition)
                        % === ANALYSIS-INTRA ===
                        % "(Analysis)" node for intra-subjects results
                        if strcmpi(sStudy.Condition{iCondition}, bst_get('DirAnalysisIntra'))
                            % Special display
                            nodeDisplayName = '(Intra-subject)';
                            nodeCondition = BstNode('study', nodeDisplayName, bst_fullfile(pathCondition, 'brainstormstudy.mat'), iSubject, 0);
                            nodeListIntra_subj = [nodeListIntra_subj, nodeCondition];
                        % === DEFAULT STUDY ===
                        % Default study node : common subject files
                        elseif strcmpi(sStudy.Condition{iCondition}, bst_get('DirDefaultStudy'))
                            % Only if subject's local default study are used
                            if (sSubject.UseDefaultChannel == 1)
                                % Special display
                                nodeDisplayName = '(Common files)';
                                nodeCondition = BstNode('defaultstudy', nodeDisplayName, pathCondition, iSubject, 0);
                                nodeListDefaultStudy_subj = [nodeListDefaultStudy_subj, nodeCondition];
                            end
                        else
                            nodeDisplayName = sStudy.Condition{iCondition};
                            % Regular/Raw condition
                            if ismember(iStudy, isRaw)
                                nodeType = 'rawcondition';
                                nodeDisplayName = nodeDisplayName(5:end);
                            else
                                nodeType = 'condition';
                            end
                            % Get acquisition or creation date
                            intDate = 0;
                            if ~isempty(sStudy.DateOfStudy)
                                try
                                    c = datevec(sStudy.DateOfStudy);
                                    intDate = max(c(1)-1800,0)*13*32 + c(2)*32 + c(3);
                                    if (intDate < 13*32)
                                        intDate = 0;
                                    end
                                catch
                                end
                            end
                            % Create node
                            [foundSearch, nodeDisplayName] = node_apply_search(iSearch, nodeType, nodeDisplayName, pathCondition, iStudy);
                            nodeCondition = BstNode(nodeType, nodeDisplayName, pathCondition, iSubject, 0, intDate);
                        end
                        % If Condition node was create
                        if ~isempty(nodeCondition)
                            if iSearch ~= 0
                                % If we have a search filter active, only create
                                % node if it (or its children) passes the filter
                                numElems = node_create_study(nodeCondition, sStudy, iStudy, isExpandTrials, [], iSearch);
                                createNode = foundSearch || numElems > 0;
                            else
                                numElems = 1;
                                createNode = 1;
                            end
                            if createNode
                                % Add it to the 'StudyDB' node
                                nodeParent.add(nodeCondition); 
                                numTotalElems = numTotalElems + numElems;
                                % Reference this node in hashtable
                                hashTableNodes.put(lower(pathCondition), nodeCondition);
                            end
                        end
                    end
                    % Set parent node to current
                    nodeParent = nodeCondition;
                end
                % Finally, use the last condition node as the study node
                nodeStudy = nodeCondition;
                if ~isempty(nodeStudy)
                    nodeStudy.setStudyIndex(iStudy);
                end

            % If no condition is defined : create study node and add it directly in subject node
            else
                % If study has a name : use this name for display in tree
                if ~isempty(sStudy.Name)
                    Comment = sStudy.Name;
                % Else : use study filename for display in tree
                else
                   [temp_, Comment] = bst_fileparts(sStudy.FileName);
                end
                [foundSearch, Comment] = node_apply_search(iSearch, 'study', Comment, sStudy.FileName, iStudy);
                nodeStudy = BstNode('study', Comment, sStudy.FileName, iSubject, iStudy);
                % Add study node to subject node
                if iSearch ~= 0
                    % If we have a search filter active, only create
                    % node if it (or its children) passes the filter
                    numElems = node_create_study(nodeStudy, sStudy, iStudy, isExpandTrials, [], iSearch);
                    createNode = foundSearch || numElems > 0;
                else
                    numElems = 1;
                    createNode = 1;
                end
                if createNode
                    nodeSubject.add(nodeStudy);
                    numTotalElems = numTotalElems + numElems;
                end
            end
        
            
        % =====================================================================
        % === ORDER : CONDITIONS/SUBJECT ======================================
        % =====================================================================
        case 'condition'
            isDefaultStudyNode  = strcmpi(sStudy.Condition{1}, bst_get('DirDefaultStudy'));
            isAnalysisIntraNode = strcmpi(sStudy.Condition{1}, bst_get('DirAnalysisIntra'));
            % Excludes default study nodes for subjects that do not use default channel
            if ~isDefaultStudyNode || (sSubject.UseDefaultChannel == 1)
    
                % ==== CONDITION LEVEL ====
                % Path in hashtable for this node (studysubjectdir$BrainStormSubject.mat)
                pathCondition = '';
                % If a condition is specified for this study
                if ~isempty(sStudy.Condition)
                    % For each condition level : create a node
                    nodeParent = nodeStudiesDB;
                    for iCondition = 1:length(sStudy.Condition)
                        % Extends node path to current condition
                        pathCondition = bst_fullfile(pathCondition, sStudy.Condition{iCondition});
                        % Try to get the current condition node
                        nodeCondition = hashTableNodes.get(lower(pathCondition));
                        % If node does not already exist : create it
                        if isempty(nodeCondition)
                            % "(Analysis)" node for intra-subjects results
                            if isAnalysisIntraNode
                                % Special display
                                nodeDisplayName = '(Intra-subject)';
                                nodeCondition = BstNode('study', nodeDisplayName, bst_fullfile('*',pathCondition), 0, 0);
                                nodeListIntra_cond = nodeCondition;
                            % Default study node : common subject files
                            elseif isDefaultStudyNode
                                % Only if subject's local default study are used
                                if (sSubject.UseDefaultChannel == 1)
                                    % Special display
                                    nodeDisplayName = '(Subject common files)';
                                    nodeCondition = BstNode('defaultstudy', nodeDisplayName, pathCondition, iSubject, 0);
                                    nodeListDefaultStudy_subj = [nodeListDefaultStudy_subj, nodeCondition];
                                end
                            else
                                nodeDisplayName = sStudy.Condition{iCondition};
                                % Regular/Raw condition
                                if ismember(iStudy, isRaw)
                                    nodeType = 'rawcondition';
                                    nodeDisplayName = nodeDisplayName(5:end);
                                else
                                    nodeType = 'condition';
                                end
                                nodeCondition = BstNode(nodeType, nodeDisplayName, bst_fullfile('*',pathCondition), 0, 0);
                            end
                            % If Condition was created
                            if ~isempty(nodeCondition)
                                if iSearch ~= 0
                                    % If we have a search filter active, only create
                                    % node if it (or its children) passes the filter
                                    numElems = node_create_study(nodeCondition, sStudy, iStudy, isExpandTrials, [], iSearch);
                                    createNode = numElems > 0;
                                else
                                    numElems = 1;
                                    createNode = 1;
                                end
                                if createNode
                                    % Add it to the 'StudyDB' node
                                    nodeParent.add(nodeCondition);
                                    numTotalElems = numTotalElems + numElems;
                                    % Reference this node in hashtable
                                    hashTableNodes.put(lower(pathCondition), nodeCondition);
                                    % Add it to the list of node to sort
                                    nodeListToSort = [nodeListToSort nodeCondition];
                                end
                            end
                        end
                        % Set parent node to current
                        nodeParent = nodeCondition;
                    end
                % If no condition is defined : Add study to the 'Default Condition' node
                else
                    nodeCondition = nodeNoCondition;
                end  

                % ==== SUBJECT LEVEL ====
                fpath_ = str_split(sStudy.FileName);
                pathSubject = [pathCondition sStudy.BrainStormSubject '$' fpath_{1}];
                % Try to get the subject node associated with the study
                nodeSubject = hashTableNodes.get(lower(pathSubject));
                % If subject node does not exist : create it
                if isempty(nodeSubject) && ~isempty(nodeCondition)
                    % Display name for default subject
                    if strcmpi(sSubject.Name, GroupSubject)
                        strComment = '(Group analysis)';
                    else
                        strComment = sSubject.Name;
                    end
                    % Create a subject node
                    if ~isDefaultStudyNode
                        % Normal study node
                        nodeSubject = BstNode('studysubject', strComment, sStudy.BrainStormSubject, iSubject, iStudy);
                    else
                        % Default study node
                        nodeSubject = BstNode('defaultstudy', strComment, sStudy.BrainStormSubject, iSubject, iStudy);
                    end
                    if iSearch ~= 0
                        % If we have a search filter active, only create
                        % node if it (or its children) passes the filter
                        numElems = node_create_study(nodeSubject, sStudy, iStudy, isExpandTrials, [], iSearch);
                        createNode = numElems > 0;
                    else
                        numElems = 1;
                        createNode = 1;
                    end
                    if createNode
                        % Add it to the 'StudyDB' node
                        nodeCondition.add(nodeSubject);
                        numTotalElems = numTotalElems + numElems;
                        % Reference this node in hashtable
                        hashTableNodes.put(lower(pathSubject), nodeSubject);
                    end
                end
                % Set subject node as the current study node
                nodeStudy = nodeSubject;
            end
    end  % ==== END SWITCH ====

    % =====================================================================
    % === Add study files to new study node ===============================
    % =====================================================================
    if ~isempty(nodeStudy)
        % Use default channel?
        UseDefaultChannel  = ~isempty(sSubject) && (sSubject.UseDefaultChannel ~= 0);
        isDefaultStudyNode = strcmpi(sStudy.Condition{1}, bst_get('DirDefaultStudy'));
        % Create node (with or without channel/headmodel nodes)
        % node_create_study(nodeStudy, sStudy, iStudy, isExpandTrials, UseDefaultChannel); 
        
        % If there are some interesting things to display in the node: prepare for dynamic update
        % Note: No dynamic update for active searches, so ensure iSearch is empty.
        if iSearch == 0 && (~isempty(sStudy.Data) || ~isempty(sStudy.Result) || ~isempty(sStudy.Stat) || ~isempty(sStudy.Image) || ~isempty(sStudy.Dipoles) || ~isempty(sStudy.Timefreq) || ~isempty(sStudy.Matrix) || ...
            ((~UseDefaultChannel || isDefaultStudyNode) && (~isempty(sStudy.HeadModel) || ~isempty(sStudy.Channel) || ~isempty(sStudy.NoiseCov))))
            % Set the node as un-processed
            nodeStudy.setUserObject(0);
            % Add a "Loading" node
            nodeStudy.add(BstNode('loading', 'Loading...'));
        end
        % If current study is default study (ProtocolInfo.iStudy)
        if (iStudy == ProtocolInfo.iStudy)
            bstDefaultNode = nodeStudy;
        end
    end
    
end  % END FOR LOOP (iStudy)

%% ===== SORT NODES =====
% Process all nodes to sort
for i = 1:length(nodeListToSort)
    nodeListToSort(i).sortChildren();
end

%% ===== ANALYSIS NODES =====
% === SUBJ/COND EXPLORATION MODE ===
for i = 1:length(nodeListIntra_subj)
    % List of data/results/stats nodes in the study
    usefullnodes = [nodeListIntra_subj(i).findChild('data',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('rawdata',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('results',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('timefreq',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('spectrum',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('pdata',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('presults',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('ptimefreq',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('pspectrum',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('pmatrix',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('dipoles',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('matrix',-1,-1,0), ...
                    nodeListIntra_subj(i).findChild('loading',-1,-1,0)];
    % If no interesting node : remove the parent node
    if isempty(usefullnodes)
        nodeListIntra_subj(i).removeFromParent();
    % Else: put in on top on the other study nodes
    else
        nodeParent = nodeListIntra_subj(i).getParent();
        nodeListIntra_subj(i).removeFromParent();
        nodeParent.insert(nodeListIntra_subj(i), 0);
    end
end
% === COND/SUBJ EXPLORATION MODE ===
if ~isempty(nodeListIntra_cond)
    % ONE '(Analysis)' node only
    iChild = 0;
    while (iChild < nodeListIntra_cond.getChildCount())
        nodeSubject = nodeListIntra_cond.getChildAt(iChild);
%         % List of data/results/stats nodes in the study
%         usefullnodes = [nodeSubject.findChild('data',-1,-1,0), ...
%                         nodeSubject.findChild('rawdata',-1,-1,0), ...
%                         nodeSubject.findChild('results',-1,-1,0), ...
%                         nodeSubject.findChild('timefreq',-1,-1,0), ...
%                         nodeSubject.findChild('spectrum',-1,-1,0), ...
%                         nodeSubject.findChild('pdata',-1,-1,0), ...
%                         nodeSubject.findChild('presults',-1,-1,0), ...
%                         nodeSubject.findChild('pmatrix',-1,-1,0), ...
%                         nodeSubject.findChild('ptimefreq',-1,-1,0), ...
%                         nodeSubject.findChild('pspectrum',-1,-1,0)];
%         % If no interesting node : remove the parent node
%         if isempty(usefullnodes)
        % If the node is empty
        if (nodeSubject.getChildCount == 0)
            nodeSubject.removeFromParent();
        % Else: put in on top on the other study nodes
        else
            % Go to next subject
            iChild = iChild + 1;
        end
    end
    % If no child left: remove node
    if (nodeListIntra_cond.getChildCount() == 0)
        nodeListIntra_cond.removeFromParent();
    % Else: Put node on top of the other nodes
    else
        % Get parent node
        nodeParent = nodeListIntra_cond.getParent();
        nbChild = nodeParent.getChildCount();
        % Remove temporary analysis node
        nodeListIntra_cond.removeFromParent();
        % If there are other special nodes (Analysis-Inter, GlobalCommonfiles), put it after them
        if (nbChild >= 2) && (nodeParent.getChildAt(1).toString.charAt(0) == '(')
            iInsert = 2;
        elseif (nbChild >= 1) && (nodeParent.getChildAt(0).toString.charAt(0) == '(')
            iInsert = 1;
        else
            iInsert = 0;
        end
        % Insert node after other special nodes
        nodeParent.insert(nodeListIntra_cond, iInsert);
    end
end

%% ===== HIDE / PUT DEFAULT STUDY NODES ON TOP =====
% If no default study needed : Hide them
if ~isGlobalDisplayed && ~isempty(nodeGlobal)
    % Remove global default study
    nodeGlobal.removeFromParent();
end
% === SUBJ/COND EXPLORATION MODE ===
% Put subject's default studies on top
for i=1:length(nodeListDefaultStudy_subj)
    nodeDefStudy = nodeListDefaultStudy_subj(i);
    % Get parent node
    nodeParent = nodeDefStudy.getParent();
    if ~isempty(nodeParent) && (nodeParent.getChildCount() > 1)
        % Remove no from parent
        nodeDefStudy.removeFromParent();
        % If first node of parent node is the 'Analysis-intra' node, put it after
        isGlobalCommonNode = strcmpi(nodeParent.getChildAt(0).getType(), 'defaultstudy');
        if isGlobalCommonNode
            iInsert = 1;
        else
            iInsert = 0;
        end
        % Move node
        nodeParent.insert(nodeDefStudy, iInsert);
    end
end


%% ===== ADD DEFAULT NODES =====
switch(expandOrder)
    case 'condition'
        % Add nodeNoCondition if it is not empty
        if (nodeNoCondition.getChildCount() > 0)
            nodeStudiesDB.add(nodeNoCondition); 
        end
end

% Add 'Subjects database' node to root node
nodeRoot.add(nodeStudiesDB);

end
