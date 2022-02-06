function iNewStudies = db_reload_conditions(iSubjects)
% DB_RELOAD_CONDITIONS: Reload all the conditions for a subject
%
% USAGE:  db_reload_conditions( iSubjects );
%
% INPUT:  iSubjects: array of subjects indices to reload in protocol studies array

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
% Authors: Francois Tadel, 2009-2013

% Parse inputs
if isempty(iSubjects)
    return
end
iNewStudies = [];
% Get protocol information
ProtocolInfo = bst_get('ProtocolInfo');
ProtocolStudies = bst_get('ProtocolStudies');

% If no progressbar is visible: create one
isProgressBar = ~bst_progress('isVisible');
if isProgressBar
    bst_progress('start', 'Reload subject', 'Reloading datasets...', 0, 100 * length(iSubjects));
end
% Process all the subjects
for i = 1:length(iSubjects)
    % Get subject
    sSubject = bst_get('Subject', iSubjects(i), 1);
    % Get all the dependent studies at the moment
    [sOldStudies, iOldStudies] = bst_get('StudyWithSubject', sSubject.FileName, 'intra_subject', 'default_study');
    % Remove them all from protocol
    ProtocolStudies.Study(iOldStudies) = [];

    % Get subject directory for studies
    subjectSubDir = bst_fileparts(sSubject.FileName);
    % Protocol error
    if ~file_exist(ProtocolInfo.STUDIES)
        bst_error(['Data folder has been deleted or moved:' 10 ProtocolInfo.STUDIES], 'Reload studies', 0);
        return
    % Check the existance of the study's directory
    elseif ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, subjectSubDir)) || ...
       ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, subjectSubDir, bst_get('DirDefaultStudy'))) || ...
       ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, subjectSubDir, bst_get('DirAnalysisIntra')))
        db_fix_protocol();
        bst_progress('stop');
        return
    end
    
    % Read all the studies in the subject directory
    sReadStudies = db_parse_study(ProtocolInfo.STUDIES, subjectSubDir, 100);
    % Add all the new studies to the protocol
    ProtocolStudies.Study = [ProtocolStudies.Study, sReadStudies];
    % Update database
    bst_set('ProtocolStudies', ProtocolStudies);
    % Update links
    db_links('Subject', iSubjects(i));
end

% Save database to disk
db_save();
% Update tree display
panel_protocols('UpdateTree');
% Select and open subject node
panel_protocols('SelectNode', [], 'studysubject', -1, iSubjects(1) );
% Close progress bar
if isProgressBar
    bst_progress('stop');
end


