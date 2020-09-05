function db_load_subjects(isTreeUpdate, isFix)
% DB_LOAD_SUBJECTS: Load all the subjects of the current protocol.
%
% USAGE:  db_load_subjects(isTreeUpdate=1, isFix=1)
%
% DESCRIPTION: 
%     Analyze all the files located in the SUBJECTS directory (and subdirectories) 
%     of the current protocol.
%     Structure of the SUBJECTS directory :
%        - Each subject (ie. all the related files) is located in a subdirectory
%          named after the subject's name (without spaces)
%        - There should be only one 'brainstormsubject*.mat' file per directory
% 
%     Process steps : 
%        1. Check that there is no 'brainstormsubject*.mat' in the SUBJECTS directory
%           (it is important to perform this verification, because many Brainstorm users 
%           put subject files directly in the 'SUBJECTS' directory)
%           => If there is such a file, create a new subject subdirectory and
%              move all the MAT files in this directory.
%        2. Look for a 'DirDefaultSubject' directory. If it exists, parse its contents
%           and stores it in the DefaultSubject field of the protocol subjects structure (ProtocolSubjects).
%           All the other subjects will be stored in the ProtocolSubjects.Subject array.
%        3. Process all the subjects (ie. all the subdirectories) 
%           => Call to : db_parse_subject()

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
% Authors: Francois Tadel, 2008-2012

% Process inputs
if (nargin < 1) || isempty(isTreeUpdate)
    isTreeUpdate = 1;
end
if (nargin < 2) || isempty(isFix)
    isFix = 1;
end

% Get protocol information
ProtocolInfo = bst_get('ProtocolInfo');
% Check protocol validity
if isempty(ProtocolInfo)
    bst_error('No valid protocol selected. Please set Brainstorm context variable iProtocol to a valid protocol index.', 'Reload subject', 0);
    return
elseif ~file_exist(ProtocolInfo.SUBJECTS)
    bst_error(['Anatomy folder has been deleted or moved:' 10 ProtocolInfo.STUDIES], 'Reload studies', 0);
    return
elseif ~file_exist(bst_fullfile(ProtocolInfo.SUBJECTS, bst_get('DirDefaultSubject')))
    if isFix
        db_fix_protocol();
    else
        % Empty protocol
        ProtocolSubjects = db_template('ProtocolSubjects');
        ProtocolStudies = db_template('ProtocolStudies');
        bst_set('ProtocolSubjects', ProtocolSubjects);
        bst_set('ProtocolStudies', ProtocolStudies);
    end
    bst_progress('stop');
    return;
end

%% ===== PROCESS SUBJECTS ROOT FILES =====
% Get files in SUBJECTS root directory
rootSubjectFiles = dir(bst_fullfile(ProtocolInfo.SUBJECTS, 'brainstormsubject*.mat'));
% If more than one brainstormsubject file in directory : error
if (length(rootSubjectFiles) > 1)
    warning('Brainstorm:InvalidSubjDir','There is more than one brainstormsubject file in directory ''%s'' : ignoring directory.', ProtocolInfo.SUBJECTS);
% Else, if there is one and only one Brainstormsubject in the ProtocolInfo.SUBJECTS
% => create a new subject subdirectory and move all the .MAT files in it
elseif ~isempty(rootSubjectFiles)
    % Read the brainstormsubject file
    try
        subjMat = load(bst_fullfile(ProtocolInfo.SUBJECTS, rootSubjectFiles(1).name));
    catch
        warning('Brainstorm:CannotOpenFile', 'Cannot open file ''%s'' : ignoring subject', rootSubjectFiles(1).name);
        subjMat = [];
    end

    if ~isempty(subjMat)
        % Define a new subdirectory name for the current subject
        % (Remove all the spaces, all the non-alphanumeric chars and the accents)
        newDirName = bst_fileparts(rootSubjectFiles(1).name);
        % If newDirName is empty : call the directory 'Unnamed'
        if (isempty(newDirName))
            newDirName = 'Unnamed';
        end
        % Make the directory directory name unique
        newDirName = file_unique(newDirName);
        % Create the new subject subdirectory
        status = mkdir(ProtocolInfo.SUBJECTS, newDirName);
        % If directory was created successfully 
        if (status)
            % Move all files in the newly created directory
            status = file_move(bst_fullfile(ProtocolInfo.SUBJECTS, '*.*'), bst_fullfile(ProtocolInfo.SUBJECTS, newDirName));
            if (~status)
                warning('Brainstorm:CannotMoveFile', 'Cannot move subject file ''%s'' to directory ''%s''.', bst_fullfile(ProtocolInfo.SUBJECTS, rootSubjectFiles(1).name), bst_fullfile(ProtocolInfo.SUBJECTS, newDirName));
            end
        else
            warning('Brainstorm:CannotCreateDir', 'Cannot create subject subdirectory ''%s''.', bst_fullfile(ProtocolInfo.SUBJECTS, newDirName));
        end
    end
end


%% ===== PROCESS ALL FILES IN SUBJECTS DIRECTORY =====
ProtocolSubjects = db_template('ProtocolSubjects');
% Parse SUBJECTS/<DirDefaultSubject>/ directory, if it exists
ProtocolSubjects.DefaultSubject = db_parse_subject(ProtocolInfo.SUBJECTS, bst_get('DirDefaultSubject'), 5);
% Parse SUBJECTS directory ('DirDefaultSubject' directories will be ignored)
ProtocolSubjects.Subject = db_parse_subject(ProtocolInfo.SUBJECTS, '', 45);
% Update protocol in DataBase
bst_set('ProtocolSubjects', ProtocolSubjects);


%% ===== SUBJECTS TEMPLATE =====
% If Default anat status not defined for protocol
if isempty(ProtocolInfo.UseDefaultAnat)
    % Subjects are available : use majority
    if ~isempty(ProtocolSubjects.Subject) 
        % Default anatomy
        ProtocolInfo.UseDefaultAnat = (nnz([ProtocolSubjects.Subject.UseDefaultAnat]) / length((ProtocolSubjects.Subject)) > 0.5);
        % Default channel file
        nbCat = [nnz([ProtocolSubjects.Subject.UseDefaultChannel] == 0), ...
                 nnz([ProtocolSubjects.Subject.UseDefaultChannel] == 1), ...
                 nnz([ProtocolSubjects.Subject.UseDefaultChannel] == 2)];
        ProtocolInfo.UseDefaultChannel = find(nbCat == max(nbCat), 1) - 1;
    else
        ProtocolInfo.UseDefaultAnat    = 1;
        ProtocolInfo.UseDefaultChannel = 2;
    end
    % Update protocol in DataBase
    bst_set('ProtocolInfo', ProtocolInfo);
end

% Refresh tree display
if isTreeUpdate
    panel_protocols('UpdateTree');
end

end








