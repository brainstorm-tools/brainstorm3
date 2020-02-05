function [bstDefaultNode, nodeSubjectsDB, numTotalElems] = node_create_db_subjects( nodeRoot , iSearch )
% NODE_CREATE_DB_SUBJECTS: Create a tree to represent the subjects registered in current protocol.
% Populate a tree from its root node.
%
% USAGE:  node_create_db_subjects(nodeRoot)
%
% INPUT: 
%    - nodeRoot       : BstNode Java object (tree root)
%    - iSearch        : ID of the active DB search, or empty/0 if none
% OUTPUT: 
%    - bstDefaultNode : default BstNode, that should be expanded and selected automatically
%                       or empty matrix if no default node is defined
%    - nodeSubjectsDB : Root node of the subjects database tree
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
% Authors: Francois Tadel, 2008-2010

global GlobalData
import org.brainstorm.tree.*;

%% ===== PARSE INPUTS =====
if (nargin < 1) || ~isa(nodeRoot, 'org.brainstorm.tree.BstNode')
    error('Usage : node_create_db_subjects(nodeRoot, ProtocolSubjects)');
end
if nargin < 2 || isempty(iSearch)
    iSearch = 0;
end

% Set default node
bstDefaultNode = [];
nodeSubjectsDB = [];
numTotalElems  = 0;
% Get current protocol subjects list
ProtocolSubjects = bst_get('ProtocolSubjects');
if (isempty(ProtocolSubjects))
    %warning('Brainstorm:NoProtocol', 'No protocol selected')
    return
end;
% Get current protocol description
ProtocolInfo = bst_get('ProtocolInfo');
% Get current subject
CurrentSubject = bst_get('Subject');
if (isempty(CurrentSubject) || isempty(CurrentSubject.FileName))
    selectedSubjectFileName = '';
else
    selectedSubjectFileName = CurrentSubject.FileName;
end
    

%% ===== CREATE TREE =====
% Create 'Subjects database' node
nodeSubjectsDB = BstNode('subjectdb', [ProtocolInfo.Comment ' (anatomy)'], ProtocolInfo.SUBJECTS, 0, 0);

% Add default subject node (if it exists)
if ~isempty(ProtocolSubjects.DefaultSubject)
    % Create subject node
    nodeSubject = BstNode('subject', '');
    % Fill it with MRI and surfaces children nodes
    numElems = node_create_subject( nodeSubject, ProtocolSubjects.DefaultSubject, 0, iSearch);
    % Add new node if it has elements that passed the search filter
    if numElems > 0
        % Add subject node to 'Subjects database' node
        nodeSubjectsDB.add(nodeSubject);
        numTotalElems = numTotalElems + numElems;
        % If default subject is the subject associated with the default study
        % Mark it as the default subject
        if file_compare(selectedSubjectFileName, ProtocolSubjects.DefaultSubject.FileName)
            bstDefaultNode = nodeSubject;
        end
    end
end

% Sort subjects by Name
[tmp__, iSubjectsSorted] = sort({ProtocolSubjects.Subject.Name});
% Find subject "Group_analysis"
iSubjectGroup = find(strcmpi({ProtocolSubjects.Subject.Name}, bst_get('NormalizedSubjectName')));
% If it exists: Remove it from the sorted list
if ~isempty(iSubjectGroup)
    iSubjectsSorted(iSubjectsSorted == iSubjectGroup) = [];
    % iSubjectsSorted = [iSubjectGroup, iSubjectsSorted];
end

% Add subjects entries for current protocol
for i = 1:length(iSubjectsSorted)
    iSubject = iSubjectsSorted(i);
    % Create subject node
    nodeSubject = BstNode('subject', '');
    % Fill it with MRI and surfaces children nodes
    try
        numElems = node_create_subject( nodeSubject, ProtocolSubjects.Subject(iSubject), iSubject, iSearch);
        % Add subject node to 'Subjects database' node
        if numElems > 0
            nodeSubjectsDB.add(nodeSubject);
            numTotalElems = numTotalElems + numElems;
            % If current subject is the subject associated with the default study
            % Mark it as the default subject
            if file_compare(selectedSubjectFileName, ProtocolSubjects.Subject(iSubject).FileName)
                bstDefaultNode = nodeSubject;
            end
        end
    catch
        % Could not create node
        warning('Brainstorm:NodeError', ['Cannot create node for subject: "' ProtocolSubjects.Subject(iSubject).Name '"']);
    end
end

% Add 'Subjects database' node to root node
nodeRoot.add(nodeSubjectsDB);


end
