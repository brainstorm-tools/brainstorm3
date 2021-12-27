function db_reload_subjects( iSubjects )
% DB_RELOAD_SUBJECTS: Reload a set of subjects of the current protocol.
%
% USAGE:  db_reload_subjects( iSubjects );
%
% INPUT:  iSubjects: indices of subjects to modify in protocol subjects array
%                    or 0, to specify the protocol's default subject
%
% DESCRIPTION: 
%     For each subject : Parse the subject's directory again and 
%     replace Subject structure in Brainstorm database.

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

% Get protocol information
ProtocolInfo     = bst_get('ProtocolInfo');
ProtocolSubjects = bst_get('ProtocolSubjects');
% Check input subject index
if isempty(ProtocolSubjects) || any(iSubjects < 0) || any(iSubjects > length(ProtocolSubjects.Subject))
    error('Invalid subject indices');
end

% If no progressbar is visible: create one
isProgressBar = ~bst_progress('isVisible');
if isProgressBar
    bst_progress('start', 'Reload subject', 'Reloading subjects...', 0, 50 * length(iSubjects));
end
% Loop on all subjects
for i = 1:length(iSubjects)
    iSubject = iSubjects(i);
    % Get subject directory (for default subject or regular subject)
    if (iSubject == 0)
        subjectSubDir = bst_fileparts(ProtocolSubjects.DefaultSubject.FileName);
    else
        subjectSubDir = bst_fileparts(ProtocolSubjects.Subject(iSubject).FileName);
    end
    % Check the existance of the subject's directory
    if ~file_exist(bst_fullfile(ProtocolInfo.SUBJECTS, subjectSubDir))
        db_fix_protocol();
        bst_progress('stop');
        return
    end
    % Parse subject directory
    sSubject = db_parse_subject(ProtocolInfo.SUBJECTS, subjectSubDir, 50);
    % If subject could not be loaded
    if isempty(sSubject)
        db_fix_protocol();
        bst_progress('stop');
        return
    end
    % Else subject was reloaded: update in ProtocolSubjects structure
    if (iSubject == 0)
        ProtocolSubjects.DefaultSubject = sSubject;
    else
        ProtocolSubjects.Subject(iSubject) = sSubject;
    end
end

% Update Brainstorm database
bst_set('ProtocolSubjects', ProtocolSubjects);
% Update display
panel_protocols('UpdateNode', 'Subject', iSubjects);
% Save database
db_save();
% Hide progress bar if it was started here
if isProgressBar
    bst_progress('stop');
end





