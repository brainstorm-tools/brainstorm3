function [numElems, selectedNode] = node_create_studysubject(nodeSubject, nodeRoot, sSubject, iSubject, iSearch)
% NODE_CREATE_STUDYSUBJECT: Create subject node from subject structure for functional view.
%
% USAGE:  node_create_subject(nodeSubject, nodeRoot, sSubject, iSubject)
%
% INPUT: 
%     - nodeSubject : BstNode object with Type 'studysubject' => Root of the subject subtree
%     - nodeRoot    : BstNode object, root of the whole database tree
%     - sSubject    : Brainstorm subject structure
%     - iSubject    : indice of the subject node in Brainstorm subjects list
%     - iSearch     : ID of the active DB search, or empty/0 if none
% OUTPUT:
%     - numElems    : Number of node children elements (including self) that
%                     pass the active search filter. If 0, node should be hidden

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
% Authors: Martin Cousineau, 2020

import org.brainstorm.tree.*;

% Parse inputs
if nargin < 4 || isempty(iSearch) || iSearch == 0
    iSearch = 0;
    % No search applied: ensure the node is added to the database
    numElems = 1;
else
    numElems = 0;
end
selectedNode = [];
showParentNodes = node_show_parents(iSearch);
ProtocolInfo = bst_get('ProtocolInfo');

% Update node fields
nodeSubject.setFileName(sSubject.FileName);
nodeSubject.setItemIndex(iSubject);
nodeSubject.setStudyIndex(0);
if (iSubject ~= 0)
    nodeSubject.setComment(sSubject.Name);
else
    nodeSubject.setComment('(Default anatomy)');
end

% Get all studies of selected subject
sStudies = db_get('StudiesFromSubject', iSubject);
iDefaultStudy = find(strcmp({sStudies.Name}, bst_get('DirDefaultStudy')), 1);
iIntraStudy   = find(strcmp({sStudies.Name}, bst_get('DirAnalysisIntra')), 1);
% Extract raw studies
listRaw = strncmp('@raw', {sStudies.Name}, 4);
isRaw = find(listRaw);
isNonRaw = find(~listRaw);
% Sort studies by Condition (raw first, non-raw after)
[tmp__, iStudiesSortedRaw] = sort_nat({sStudies(isRaw).Name});
[tmp__, iStudiesSortedNonRaw] = sort_nat({sStudies(isNonRaw).Name});
iStudiesSorted = [isRaw(iStudiesSortedRaw), isNonRaw(iStudiesSortedNonRaw)];
% Check for database inconsistency
if (length(iStudiesSorted) ~= length(sStudies))
    bst_error(['There are structure errors in this protocol, please reload it.' 10 '=> Right click on protocol node > Reload.'], 'Update database explorer', 0);
    sStudies = [];
end

% 1. Default study (common files), 
if ~isempty(iDefaultStudy)
    % Only accessible when using default channel
    if sSubject.UseDefaultChannel == 1
        nodeStudy = BstNode('defaultstudy', '(Common files)', sStudies(iDefaultStudy).FileName, iSubject, sStudies(iDefaultStudy).Id);
        
        % Expand node if this is the currently selected study
        if ~isempty(ProtocolInfo.iStudy) && ProtocolInfo.iStudy == sStudies(iDefaultStudy).Id
            node_create_study(nodeStudy, nodeRoot, sStudies(iDefaultStudy), sStudies(iDefaultStudy).Id, [], 1, [], iSearch);
            selectedNode = nodeStudy;
        else
            % Set the node as un-processed
            nodeStudy.setUserObject(0);
            % Add a "Loading" node
            nodeStudy.add(BstNode('loading', 'Loading...'));
        end
        
        % Add node to tree
        nodeSubject.add(nodeStudy);
    end
else
    iDefaultStudy = -3;
end

% 2. Intra-analysis study
if ~isempty(iIntraStudy)
    nodeStudy = BstNode('study', '(Intra-subject)', sStudies(iIntraStudy).FileName, iSubject, sStudies(iIntraStudy).Id);
    
    % Expand node if this is the currently selected study
    if ~isempty(ProtocolInfo.iStudy) && ProtocolInfo.iStudy == sStudies(iIntraStudy).Id
        node_create_study(nodeStudy, nodeRoot, sStudies(iIntraStudy), sStudies(iIntraStudy).Id, [], 1, [], iSearch);
        selectedNode = nodeStudy;
    else
        % Set the node as un-processed
        nodeStudy.setUserObject(0);
        % Add a "Loading" node
        nodeStudy.add(BstNode('loading', 'Loading...'));
    end
    
    % Add node to tree
    nodeSubject.add(nodeStudy);
else
    iIntraStudy = -2;
end

% 3. All other studies
for i = 1:length(sStudies)
    iStudy = iStudiesSorted(i);
    sStudy = sStudies(iStudy);
    
    % Skip special studies
    if iStudy == iDefaultStudy || iStudy == iIntraStudy
        continue;
    end
    
    % Regular/Raw condition
    if listRaw(iStudy)
        nodeType = 'rawcondition';
        Comment  = sStudy.Name(5:end);
    else
        nodeType = 'condition';
        Comment  = sStudy.Name;
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
    
    %TODO: deal with Conditions?

    % If no condition is defined : create study node and add it directly in subject node
    % If study has no name : use study filename for display in tree
    if isempty(Comment)
        [temp_, Comment] = bst_fileparts(sStudy.FileName);
    end
        
    nodeStudy = BstNode(nodeType, Comment, sStudy.FileName, 0, sStudy.Id);

    % Expand node if this is the currently selected study
    if ~isempty(ProtocolInfo.iStudy) && ProtocolInfo.iStudy == sStudy.Id
        node_create_study(nodeStudy, nodeRoot, sStudy, sStudy.Id, [], 1, [], iSearch);
        selectedNode = nodeStudy;
    else
        % Set the node as un-processed
        nodeStudy.setUserObject(0);
        % Add a "Loading" node
        nodeStudy.add(BstNode('loading', 'Loading...'));
    end
    
    % Add node to tree
    nodeSubject.add(nodeStudy);
end

end

