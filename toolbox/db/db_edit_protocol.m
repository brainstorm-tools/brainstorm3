function iProtocol = db_edit_protocol(action, sProtocol, iProtocol)
% DB_EDIT_PROTOCOL: Load, create or edit a protocol in Brainstorm database.
%
% USAGE:  [iProtocol] = db_edit_protocol('create', sProtocol);              % Create a new protocol
%         [iProtocol] = db_edit_protocol('load',   sProtocol);              % Load an existing protocol
%         [iProtocol] = db_edit_protocol('edit',   sProtocol, iProtocol);   % Edit an existing protocol (index #iProtocol in ProtocolsListInfo)
% 
% INPUT:
%     - sProtocol : Protocol structure, with the following fields (some fields are ignored, depending on the action)
%          |- Comment  : Name of the protocol
%          |- SUBJECTS : Directory that contains the anatomies of the subjects (MRI + surfaces)
%          |- STUDIES  : Directory that contains the functional data (recordings, sensors, sources...)
%          |- iStudy   : Ignored
%          |- UseDefaultAnat    : Default subject's properties: 0=No default anat, 1=Use default anat
%          |- UseDefaultChannel : Default subject's properties: 0=No default channel, 1=One channel file per subject, 2=One channel file for all subjects
%     - iProtocol : Indice of the sProtocol structure in the Brainstorm database
%
% OUTPUT:
%     - iProtocol : Indice of the created protocol, or -1 if an error occured

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
% Authors: Francois Tadel, 2008-2013; Martin Cousineau, 2019


%% ===== PARSE INPUTS =====
global GlobalData;
% Get ProtocolsListInfo structure 
sProtocolsListInfo     = GlobalData.DataBase.ProtocolInfo;
sProtocolsListSubjects = GlobalData.DataBase.ProtocolSubjects;
sProtocolsListStudies  = GlobalData.DataBase.ProtocolStudies;
isProtocolLoaded       = GlobalData.DataBase.isProtocolLoaded;
isProtocolModified     = GlobalData.DataBase.isProtocolModified;
nbProtocols = length(sProtocolsListInfo);
% Switch between actions
switch (action)
    case {'create', 'load'}
        if (nargin < 2)
            error('Usage:  db_edit_protocol(''create'', sProtocol).');
        end
        iProtocol = nbProtocols + 1;
    case 'edit'
        if (nargin < 3)
            error('Usage:  db_edit_protocol(action, sProtocol, iProtocol).');
        end
        if ((iProtocol <= 0) || (iProtocol > nbProtocols))
            error('Protocol #%d does not exist.', iProtocol);
        end
    otherwise
        error('Unknown action.');
end


%% ===== CREATE FOLDERS =====
if ~isdir(sProtocol.SUBJECTS)
    % SUBJECTS path does not exist: Create it
    if ~mkdir(sProtocol.SUBJECTS)
        bst_error(['Could not create directory "' sProtocol.SUBJECTS '".'], 'Protocol editor', 0);
        iProtocol = -1;
        return
    end
elseif strcmpi(action, 'create') && (length(dir(sProtocol.SUBJECTS)) > 2)
    % Folder must be empty
    bst_error(['Folder "' sProtocol.SUBJECTS '" is not empty.'], 'Protocol editor', 0);
    iProtocol = -1;
    return
end
% Check the existence of the STUDIES directory
if ~isdir(sProtocol.STUDIES)
    % STUDIES path does not exist : create it
    if ~mkdir(sProtocol.STUDIES)
        bst_error(['Could not create directory "' sProtocol.STUDIES '".'], 'Protocol editor', 0);
        iProtocol = -1;
        return
    end
elseif strcmpi(action, 'create') && (length(dir(sProtocol.STUDIES)) > 2)
    bst_error(['Folder "' sProtocol.STUDIES '" is not empty.'], 'Protocol editor', 0);
    iProtocol = -1;
    return
end
% If currently edited protocol is a NEW protocol :
if strcmpi(action, 'load') || strcmpi(action, 'create')
    % Check if a protocol with this name is already registered in ProtocolsListInfo
    if any(strcmpi(sProtocol.Comment, {sProtocolsListInfo.Comment})) 
        % A protocol with the same name is found : display an error box and return to 'Protocol editor' window
        bst_error(sprintf('Protocol ''%s'' already exists in database.', sProtocol.Comment), 'Protocol editor', 0);
        iProtocol = -1;
        return
    end
end

%% ===== UPDATE PROTOCOL =====
% Register protocol in ProtocolsListInfo
sProtocolsListInfo(iProtocol).Comment  = sProtocol.Comment;
sProtocolsListInfo(iProtocol).SUBJECTS = sProtocol.SUBJECTS;
sProtocolsListInfo(iProtocol).STUDIES  = sProtocol.STUDIES;
% ===== SUBJECT DEFAULTS =====
if strcmpi(action, 'edit') || strcmpi(action, 'create')
    % Anatomy class (defaults or individual)
    sProtocolsListInfo(iProtocol).UseDefaultAnat = sProtocol.UseDefaultAnat;
    % Channel/Headmodel class (defaults or individual)
    sProtocolsListInfo(iProtocol).UseDefaultChannel = sProtocol.UseDefaultChannel;
end

%% ===== UPDATE EXISTING PROTOCOL DATABASE =====
if strcmpi(action, 'load')
    db_update(GlobalData.DataBase.DbVersion, sProtocol);
end

%% ===== NEW PROTOCOL =====
if strcmpi(action, 'load') || strcmpi(action, 'create')
    % Register protocol in ProtocolsListSubjects and ProtocolsListStudies
    if isempty(sProtocolsListSubjects) || isempty(sProtocolsListStudies)
        sProtocolsListSubjects = db_template('ProtocolSubjects');
        sProtocolsListStudies  = db_template('ProtocolStudies');
        isProtocolLoaded       = 0;
        isProtocolModified     = 1;
    else
        sProtocolsListSubjects(iProtocol) = db_template('ProtocolSubjects');
        sProtocolsListStudies(iProtocol)  = db_template('ProtocolStudies');
        isProtocolLoaded(iProtocol)       = 0;
        isProtocolModified(iProtocol)     = 1;
    end
    
    % === DEFAULT SUBJECT ===
    % Create a "SUBJECTS/DirDefaultSubject" directory
    defaultDir = bst_fullfile(sProtocolsListInfo(iProtocol).SUBJECTS, bst_get('DirDefaultSubject'));
    if ~isdir(defaultDir)
        mkdir(defaultDir);
    end
    % If file subject file already exist : do not overwrite it
    newSubjectFile = bst_fullfile(defaultDir, 'brainstormsubject.mat');
    if ~file_exist(newSubjectFile)
        % Create an empty default subject
        SubjectMat = db_template('subjectmat');
        SubjectMat.UseDefaultAnat    = 1;
        SubjectMat.UseDefaultChannel = 1;
        % Save brainstormsubject file in 'DirDefaultSubject' directory
        bst_save(newSubjectFile, SubjectMat, 'v7');
    end

    % === DEFAULT STUDY ===
    % Create a "STUDIES/DirDefaultStudy" directory
    defaultDir = bst_fullfile(sProtocolsListInfo(iProtocol).STUDIES, bst_get('DirDefaultStudy'));
    if ~isdir(defaultDir)
        mkdir(defaultDir);
    end
    % If file subject file already exist : do not overwrite it
    newStudyFile = bst_fullfile(defaultDir, 'brainstormstudy.mat');
    if ~file_exist(newStudyFile)
        StudyMat = db_template('studymat');
        StudyMat.Name = bst_get('DirDefaultStudy');
        bst_save(newStudyFile, StudyMat, 'v7');
    end
    
    % === ANALYSIS STUDY ===
    % Create a "STUDIES/DirAnalysisInter" directory
    defaultDir = bst_fullfile(sProtocolsListInfo(iProtocol).STUDIES, bst_get('DirAnalysisInter'));
    if ~isdir(defaultDir)
        mkdir(defaultDir);
    end
    % If file subject file already exist : do not overwrite it
    newStudyFile = bst_fullfile(defaultDir, 'brainstormstudy.mat');
    if ~file_exist(newStudyFile)
        StudyMat = db_template('studymat');
        StudyMat.Name = bst_get('DirAnalysisInter');
        bst_save(newStudyFile, StudyMat, 'v7');
    end
    
    % === UPDATE DATABASE ===
    GlobalData.DataBase.ProtocolInfo       = sProtocolsListInfo;
    GlobalData.DataBase.ProtocolSubjects   = sProtocolsListSubjects;
    GlobalData.DataBase.ProtocolStudies    = sProtocolsListStudies;
    GlobalData.DataBase.isProtocolLoaded   = isProtocolLoaded;
    GlobalData.DataBase.isProtocolModified = isProtocolModified;
    % Update GUI, build exploration tree, etc...
    gui_brainstorm('UpdateProtocolsList');

% ===== ACTION: EDIT  =====
elseif strcmpi(action, 'edit')
    % Update ProtocolInfo fields
    sProtocolsListInfo(iProtocol).Comment = sProtocol.Comment;
    % Update ProtocolInfo
    GlobalData.DataBase.ProtocolInfo = sProtocolsListInfo;
    GlobalData.DataBase.isProtocolModified(iProtocol) = 1;
    % Update tree display
    panel_protocols('UpdateTree');
end

% Save Brainstorm database
% db_save();






