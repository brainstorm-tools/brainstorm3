function db_delete_subjects( iSubjects )
% DB_DELETE_SUBJECTS: Delete some subjects from the brainstorm database.
%
% USAGE:  db_delete_subjects( iSubjects )
%
% INPUT:
%    - iSubjects : indices of the subejcts to delete

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
% Authors: Francois Tadel, 2012

ProtocolInfo     = bst_get('ProtocolInfo');
ProtocolSubjects = bst_get('ProtocolSubjects');
% Remove invalid indices and default subject
iInvalid = find(iSubjects <= 0);
if ~isempty(iInvalid)
    disp('DELETE> Cannot delete default subject.');
    iSubjects(iInvalid) = [];
end

% For each subject
for i = 1:length(iSubjects)
    SubjectFile = ProtocolSubjects.Subject(iSubjects(i)).FileName;
    % === DELETE STUDIES ===
    % Find all the studies that are associated with the current brainstormsubject file
    [sStudies, iStudies] = bst_get('StudyWithSubject', SubjectFile, 'intra_subject', 'default_study');
    if ~isempty(sStudies)
        db_delete_studies(iStudies);
        % Delete the studies folder for the subject
        if (file_delete(bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(bst_fileparts(sStudies(1).FileName))), 1, 1) ~= 1)
            return;
        end
    end    
    % === DELETE SUBJECT ===
    % Remove subject's directory
    if (file_delete(bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(SubjectFile)), 1, 1) ~= 1)
        return;
    end
end
% Remove subjects from database
ProtocolSubjects.Subject(iSubjects) = [];
bst_set('ProtocolSubjects', ProtocolSubjects);
% Update tree
panel_protocols('UpdateTree');
% Save database
db_save();





