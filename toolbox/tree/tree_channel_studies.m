function iStudies = tree_channel_studies( bstNodes, varargin )
% TREE_CHANNEL_STUDIES: Get all the studies that may contain a channel file in the selected nodes.
%
% USAGE: iStudies = tree_channel_studies( bstNodes )
%        iStudies = tree_channel_studies( bstNodes, 'NoIntra')
%
% INPUT:
%    - bstNodes  : Array of BstNode
%    - 'NoIntra' : Do not consider 'intra_subject' studies in the bstNodes dependencies
%
% OUTPUT:
%    - iStudies  : Indices of all the studies that where found in the input nodes

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
% Authors: Francois Tadel, 2008-2010

% Parse inputs
if (length(varargin) >= 1)
    NoIntra = strcmpi(varargin{1}, 'NoIntra');
else
    NoIntra = 0;
end
% Process all nodes
iStudies = [];
for iNode = 1:length(bstNodes)
    nodeType = lower(char(bstNodes(iNode).getType()));
    % Switch between different node types
    switch nodeType
        % ==== DATABASE (Studies/cond, Studies/subj) ====
        case {'studydbsubj', 'studydbcond'}
            % Get all the protocol subjects
            nbSubjects = bst_get('SubjectCount');
            if (nbSubjects <= 0)
                return
            end
            % Get the channel studies for all the subjects of the protocol
            iStudies = addAllSubjectsStudies(iStudies, 1:nbSubjects, NoIntra);
            
        % ==== SUBJECT ====
        case 'studysubject'
            iStudy   = bstNodes(iNode).getStudyIndex();
            iSubject = bstNodes(iNode).getItemIndex();
            sSubject = bst_get('Subject', iSubject);
            % If subject/condition mode => 'studysubject' contains many study nodes
            % OR: subject uses default channel file
            if (iStudy == 0) || (sSubject.UseDefaultChannel ~= 0)
                iStudies = addAllSubjectsStudies(iStudies, iSubject, NoIntra);
            % Else: condition/subject mode => 'studysubject' node is a study node
            else
                iStudies = [iStudies, iStudy];
            end
            
        % ==== CONDITION ====
        case {'condition', 'rawcondition'}
            iStudy = bstNodes(iNode).getStudyIndex();
            % If subject/condition mode => 'condition' is a study node
            if ~isempty(iStudy)
                iStudies = [iStudies, iStudy];
            % Else: condition/subject mode => 'condition' contains many study nodes
            else
                % Get condition name
                ConditionPath = bstNodes(iNode).getFileName();
                % Get all the studies related with the condition name
                [sStudies, iNewStudies] = bst_get('StudyWithCondition', ConditionPath);
                iStudies = [iStudies, iNewStudies];
            end
            
        % ==== STUDY ====
        case 'study'
            iStudy = bstNodes(iNode).getStudyIndex();
            iStudies = [iStudies, iStudy];
            
        % ==== DEFAULT STUDY ====
        case 'defaultstudy'
            iStudy = bstNodes(iNode).getStudyIndex();
            % If node is a study node
            if (iStudy ~= 0) 
                % Set filename for this study only
                iStudies = [iStudies, iStudy];
            % Else: node is a 'Subject common files' in cond/subject view mode
            else
                % Get all the protocol subjects
                nbSubjects = bst_get('SubjectCount');
                if (nbSubjects <= 0)
                    return
                end
                % For each subject
                for iSubject = 1:nbSubjects
                    sSubject = bst_get('Subject', iSubject, 1); 
                    % If subject uses local default subject (shares Channel file but not anatomy)
                    if (sSubject.UseDefaultChannel == 1)
                        iStudies = addAllSubjectsStudies(iStudies, iSubject, NoIntra);
                    end
                end
            end
        
        % ==== CHANNEL ====
        case {'channel', 'headmodel'}
            iStudy = bstNodes(iNode).getStudyIndex();
            iStudies = [iStudies, iStudy];
            
        % ==== DATA ====
        case {'data', 'rawdata'}
            iStudy = bstNodes(iNode).getStudyIndex();
            iStudies = [iStudies, iStudy];
            
        % ==== DATA LIST ====
        case 'datalist'
            iStudiesTmp = tree_dependencies(bstNodes(iNode), 'data');
            if isequal(iStudiesTmp, -10)
                disp('BST> Error in tree_dependencies.');
            else
                iStudies = [iStudies, iStudiesTmp];
            end
    end
end
% Get the channel files corresponding to these studies
[sChannels, iStudies] = bst_get('ChannelForStudy', unique(iStudies));
iStudies = unique(iStudies);

end



%% ===============================================================================
%  ===== HELPERS =================================================================
%  ===============================================================================
%% ===== ADD ALL SUBJECT STUDIES =====
function iStudies = addAllSubjectsStudies(iStudies, iSubject, NoIntra)
    % Get the studies in which the channel file should be imported
    if NoIntra
        iStudies = [iStudies, bst_get('ChannelStudiesWithSubject', iSubject, 'NoIntra')];
    else
        iStudies = [iStudies, bst_get('ChannelStudiesWithSubject', iSubject)];
    end
end





