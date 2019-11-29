function [sSubject, iSubject] = db_add_subject( varargin )
% DB_ADD_SUBJECT: Add a subject to data base.
%
% USAGE:                        db_add_subject(sSubject, iSubject)
%        [sSubject, iSubject] = db_add_subject(sSubject)
%        [sSubject, iSubject] = db_add_subject(SubjectName)
%        [sSubject, iSubject] = db_add_subject(SubjectName, iSubject)
%        [sSubject, iSubject] = db_add_subject(SubjectName, iSubject, UseDefaultAnat, UseDefaultChannel)
%
% INPUT:
%     - SubjectName : Name of the subject
%     - sSubject    : subject structure
%     - iSubject    : Indice of the subject in the ProtocolSubjects.Subject array
%                     Set to [] to create a new subject
%     - UseDefaultAnat, UseDefaultChannel : values for new subject
% OUTPUT:
%     - sSubject : Subject structure (set to [] if an error occurs)
%     - iSubject : Subject indice in current protocol

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2011

% Get protocol description
ProtocolInfo     = bst_get('ProtocolInfo');
ProtocolSubjects = bst_get('ProtocolSubjects');
nbSubjects = length(ProtocolSubjects.Subject);

%% ===== PARSE INPUTS =====
% CALL: db_add_subject( sSubject )
if isstruct(varargin{1})
    sSubject = varargin{1};
% CALL: db_add_subject( SubjectName )
elseif ischar(varargin{1})
    % Get subject name
    SubjectName = file_standardize(varargin{1});
    % Create a new empty subject
    sSubject = db_template('Subject');
    sSubject.Name              = SubjectName;
    sSubject.FileName          = bst_fullfile(SubjectName, 'brainstormsubject.mat');
    sSubject.UseDefaultAnat    = ProtocolInfo.UseDefaultAnat;
    sSubject.UseDefaultChannel = ProtocolInfo.UseDefaultChannel;
else
    error('Invalid call to db_add_subject()');
end
% CALL: db_add_subject( ..., iSubject )
if (nargin < 2) || isempty(varargin{2})
    % New indice
    iSubject = nbSubjects + 1;
else
    iSubject = varargin{2};
end
% CALL: db_add_subject( ..., UseDefaultAnat, UseDefaultChannel )
if (nargin >= 3)
    sSubject.UseDefaultAnat = varargin{3};
end
if (nargin >= 4)
    sSubject.UseDefaultChannel = varargin{4};
end

% Is new subject ?
isNewSubject = (iSubject > nbSubjects);


%% ===== CHECK SUBJECT UNICITY =====
% Only if creating a new subject
if isNewSubject
    % Check the subject unicity
    if ~isempty(bst_get('Subject', sSubject.Name, 1))
        % A subject with the same Name is found : display an error box and return to 'Subject editor' window
        bst_error(sprintf('Subject "%s" already exists in protocol.', sSubject.Name), 'Subject editor', 0);
        sSubject = [];
        return
    end
end


%% ===== SAVE SUBJECT FILE =====
SubjectMat = db_template('subjectmat');
SubjectMat.Comments          = sSubject.Comments;
SubjectMat.UseDefaultAnat    = sSubject.UseDefaultAnat;
SubjectMat.UseDefaultChannel = sSubject.UseDefaultChannel;
try
    fullFileName = bst_fullfile(ProtocolInfo.SUBJECTS, sSubject.FileName);
    % Create target directory
    if ~file_exist(bst_fileparts(fullFileName))
        mkdir(bst_fileparts(fullFileName));
    end
    % Save file
    bst_save(fullFileName, SubjectMat, 'v7');
catch
    bst_error(sprintf('Error : cannot save subject file "%s".', sSubject.Name), 'Subject editor');
    sSubject = [];
    return
end


%% ===== UPDATE DATABASE =====
% === Update Subjects ===
% Register subject in ProtocolSubjects
ProtocolSubjects.Subject(iSubject) = sSubject;
% Update database in Matlab preferences
bst_set('ProtocolSubjects', ProtocolSubjects);

% === Create extra system conditions ===
% Only if it is a new subject
if isNewSubject
    % Add conditions: analysis_intra and default_study
    db_add_condition(sSubject.Name, bst_get('DirAnalysisIntra'), 0);
    db_add_condition(sSubject.Name, bst_get('DirDefaultStudy'),  0);
end
% Save database
db_save();


