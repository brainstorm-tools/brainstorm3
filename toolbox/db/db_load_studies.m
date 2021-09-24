function db_load_studies(isTreeUpdate, isFix)
% DB_LOAD_STUDIES: Load all the studies of the current protocol.
%
% USAGE:  db_load_studies(isTreeUpdate=1, isFix=1)
%
% NOTES:
% Analyze all the files located in the given studies directory (and subdirectories).
%    - Each dataset is relative to a subject/condition couple.
%    - 1 subject/condition = 1 directory (only one 'brainstormstudy*.mat' file per directory)
%    
% Structure of the STUDIES directory :
%    |- Subject1
%    |    |- Condition1
%    |    |    |- SubCondition1
%    |    |    |    |- brainstormstudy*.mat (ONE AND ONLY ONE)
%    |    |    |    |- channel*.mat (ONE AND ONLY ONE)
%    |    |    |    |- *data*.mat (1 file/recording)
%    |    |    |    |- *headmodel*.mat (0..N : VolGrid or SurfGrid)
%    |    |    |    |- *results*.mat (0..N)
%    |    |    |- SubCondition2
%    |    |- Condition2
%    |- Subject2
%
% Process steps : 
%    1. Check that there is no 'brainstormstudy*.mat' in the STUDIES directory
%       (it is important to perform this verification, because many Brainstorm users 
%       put studies files directly in the 'STUDIES' directory)
%       1.a. If there is such a file, create a new subject subdirectory and
%            move all the STUDIES root directory files file in this subdirectory.
%    2. Process all the subjects (ie. all the subdirectories) 
%       For each study subdirectory :
%           2.a. If there is a 'brainstormstudy*.mat' directory right in this directory
%                create a new 'conditionName' directory and move the .mat files in it
%           2.b. Process each condition subdirectory (recursively : for sub-conditions)
%                => call to db_parse_study

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
% Authors: Francois Tadel, 2008-2013

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
    bst_error('No valid protocol selected. Please set Brainstorm variable iProtocol to a valid protocol index.', 'Reload studies', 0);
    return
elseif ~file_exist(ProtocolInfo.STUDIES)
    bst_error(['Data folder has been deleted or moved:' 10 ProtocolInfo.STUDIES], 'Reload studies', 0);
    return
elseif ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, bst_get('DirDefaultStudy'))) || ...
       ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, bst_get('DirAnalysisInter')))
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

%% ===== STUDIES root folder =====
rootStudyFiles = dir(bst_fullfile(ProtocolInfo.STUDIES, 'brainstormstudy*.mat'));
% If more than one brainstormstudy file in directory : error
if (length(rootStudyFiles) > 1)
    warning('Brainstorm:InvalidDataDir', 'There is more than one brainstormstudy file in directory ''%s'' : ignoring directory.', ProtocolInfo.STUDIES);
% Else, if there is one and only one brainstormstudy in the STUDIES directory
% => create a new subject subdirectory and move all the .MAT files in it
elseif ~isempty(rootStudyFiles)
    % Read the brainstormstudy file
    try
        studyMat = load(bst_fullfile(ProtocolInfo.STUDIES, rootStudyFiles(1).name));
    catch
        warning('Brainstorm:CannotOpenFile', 'Cannot open file ''%s'' : ignoring study', rootStudyFiles(1).name);
        studyMat = [];
    end

    if ~isempty(studyMat)
        % Create a new subject subdirectory that has the subject file name
        [fpath_, newDirName] = bst_fileparts(studyMat.BrainStormSubject);
        % If newDirName is empty : call the directory 'Unnamed'
        if (isempty(newDirName))
            newDirName = 'NoSubject';
        end
        
        % If the directory newDirName already exists
        if (file_exist(bst_fullfile(ProtocolInfo.STUDIES, newDirName)))
            % Add a number to newDirName
            newIndex = 1;
            while (file_exist(bst_fullfile(ProtocolInfo.STUDIES, sprintf('%s_%02d', newDirName, newIndex))))
                newIndex = newIndex + 1;
            end
            newDirName = sprintf('%s_%02d', newDirName, newIndex);
        end
        % Create the new subject subdirectory
        status = mkdir(ProtocolInfo.STUDIES, newDirName);
        % If directory was created successfully 
        if (status)
            % Move all the files in the newly created directory
            status = file_move(bst_fullfile(ProtocolInfo.STUDIES, '*.*'), bst_fullfile(ProtocolInfo.STUDIES, newDirName));
            if (~status)
                warning('Brainstorm:CannotMoveFile', 'Cannot move files to directory ''%s''.', bst_fullfile(ProtocolInfo.STUDIES, rootStudyFiles(1).name), bst_fullfile(ProtocolInfo.STUDIES, newDirName));
            end
        else
            warning('Brainstorm:CannotCreateDir', 'Cannot create subject subdirectory ''%s''.', bst_fullfile(ProtocolInfo.STUDIES, newDirName));
        end
    end
end


%% ===== LOAD ALL STUDIES =====
ProtocolStudies = db_template('ProtocolStudies');
% Parse STUDIES folder
ProtocolStudies.Study = db_parse_study(ProtocolInfo.STUDIES, '', 130);
% Parse INTER-SUBJECT folder
ProtocolStudies.AnalysisStudy = db_parse_study(ProtocolInfo.STUDIES, bst_get('DirAnalysisInter'), 10);
if (length(ProtocolStudies.AnalysisStudy) > 1)        
    disp('BST> Database error: multiple @inter studies found for the same protocol, please keep only one of the following:');
    for i = 1:length(ProtocolStudies.AnalysisStudy)
        disp(['BST>    ' ProtocolStudies.AnalysisStudy(i).FileName]);
    end
    ProtocolStudies.AnalysisStudy = ProtocolStudies.AnalysisStudy(1);
end
% Parse DEFAULT_STUDY folder
ProtocolStudies.DefaultStudy = db_parse_study(ProtocolInfo.STUDIES, bst_get('DirDefaultStudy'), 10);
if (length(ProtocolStudies.DefaultStudy) > 1)        
    disp('BST> Database error: multiple @default_study folders found for the same protocol, please keep only one of the following:');
    for i = 1:length(ProtocolStudies.DefaultStudy)
        disp(['BST>    ' ProtocolStudies.DefaultStudy(i).FileName]);
    end
    ProtocolStudies.DefaultStudy = ProtocolStudies.DefaultStudy(1);
end


%% ===== SAVE CHANGES =====
% Update protocol in DataBase
bst_set('ProtocolStudies', ProtocolStudies);
% Update all results links
db_links();
% Refresh tree display
if isTreeUpdate
    panel_protocols('UpdateTree');
end


end
