function OutputFiles = db_set_headmodel(HeadModelFile, Target)
% DB_SET_HEADMODEL: Copy a head model node to other studies
%
% USAGE:  OutputFiles = db_set_headmodel(HeadModelFile, iDestStudies)   : Apply to the target studies
%         OutputFiles = db_set_headmodel(HeadModelFile, 'AllConditions'): Apply to all the conditons in the same subject
%         OutputFiles = db_set_headmodel(HeadModelFile, 'AllSubjects')  : Apply to all the conditons in all the subjects

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
% Authors: Martin Cousineau, 2018

OutputFiles = {};

% ===== GET SOURCE STUDY =====
% Get source study
[sSrcStudy, iSrcStudy] = bst_get('AnyFile', HeadModelFile);
    
% ===== GET TARGET STUDIES =====
if isnumeric(Target)
    % Destination studies are passed in argument
    iDestStudies = Target;
elseif strcmpi(Target, 'AllConditions')
    % Get all the studies for this subject
    [sDestStudies, iDestStudies] = bst_get('StudyWithSubject', sSrcStudy.BrainStormSubject);
elseif strcmpi(Target, 'AllSubjects')
    % Get the whole database
    ProtocolSubjects = bst_get('ProtocolSubjects');
    % Get list of subjects (sorted alphabetically => same order as in the tree)
    [uniqueSubjects, iUniqueSubjects] = sort({ProtocolSubjects.Subject.Name});
    % Process each subject
    iDestStudies = [];
    for iSubj = 1:length(uniqueSubjects)
        % Get subject filename
        iSubject = iUniqueSubjects(iSubj);
        SubjectFile = ProtocolSubjects.Subject(iSubject).FileName;
        % Get all the studies for this subject
        [sStudies, iStudies] = bst_get('StudyWithSubject', SubjectFile, 'intra_subject', 'default_study');
        iDestStudies = [iDestStudies, iStudies];
    end
else 
    return;
end

% ===== COPY HEADMODEL =====
% Process each target study
nCopied = 0;
for i = 1:length(iDestStudies)
    % Get destination study
    iDestStudy = iDestStudies(i);
    destStudy = bst_get('Study', iDestStudy);
    
    % Skip source study
    if iDestStudy == iSrcStudy
        continue;
    end
    
    % Skip studies without non-raw data
    foundNonRawData = 0;
    for iData = 1:length(destStudy.Data)
        if ~strcmpi(destStudy.Data(iData).DataType, 'raw')
            foundNonRawData = 1;
            break;
        end
    end
    if ~foundNonRawData
        continue;
    end
    
    % Check whether destination study has head model
    destHeadModel = bst_get('HeadModelForStudy', iDestStudy);
    if ~isempty(destHeadModel)
        destSubject = bst_get('Subject', destStudy.BrainStormSubject);
        disp(['BST> Study "' destStudy.Name '" of subject "' destSubject.Name '" already contains a head model. Skipping.']);
        continue;
    end
    
    % Copy head model file
    OutputFiles{end + 1} = panel_protocols('CopyFile', iDestStudy, HeadModelFile, 'headmodel', iSrcStudy);
    nCopied = nCopied + 1;
end

% ===== RELOAD STUDIES =====
if nCopied > 0
    db_reload_studies(iDestStudies);
else
    java_dialog('warning', ['No file was copied. To avoid errors, folders with existing head models, only raw data, or empty' 10 ...
        'are not supported by this process. You need to copy them manually via File -> Copy/Paste.']);
end

