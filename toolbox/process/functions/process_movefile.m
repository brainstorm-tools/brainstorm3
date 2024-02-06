function varargout = process_movefile( varargin )
% PROCESS_MOVEFILE: Delete files, subject, or condition.
%
% USAGE:     sProcess = process_delete('GetDescription')
%                       process_delete('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Move files';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1024;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Option: Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'NewSubject';
    % Option: Condition
    sProcess.options.folder.Comment = 'Folder name:';
    sProcess.options.folder.Type    = 'text';
    sProcess.options.folder.Value   = 'NewFolder';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = [sProcess.Comment ': ' sProcess.options.subjectname.Value '/' sProcess.options.folder.Value];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    % Get subject name
    SubjectName = file_standardize(sProcess.options.subjectname.Value);
    if isempty(SubjectName)
        bst_report('Error', sProcess, sInputs, 'Subject name is empty.');
        return
    end
    % Get folder name
    Folder = file_standardize(sProcess.options.folder.Value);
    
    % ===== OUTPUT FOLDER =====
    % Get condition asked by user
    [sStudyTarget, iStudyTarget] = bst_get('StudyWithCondition', bst_fullfile(SubjectName, Folder));
    % Condition does not exist: create it
    if isempty(sStudyTarget)
        iStudyTarget = db_add_condition(SubjectName, Folder, 1);
        if isempty(iStudyTarget)
            bst_report('Error', sProcess, sInputs, ['Cannot create folder: "' bst_fullfile(SubjectName, Folder) '"']);
            return;
        end
    end
    
    % ===== MOVE FILES =====
    for i = 1:length(sInputs)
        OutputFiles{i} = panel_protocols('CopyFile', iStudyTarget, sInputs(i).FileName);
        if isempty(OutputFiles{i})
            bst_report('Error', sProcess, sInputs(i), ['Cannot opy file to: "' bst_fullfile(SubjectName, Folder) '"']);
            return;
        end
    end
    % Delete all the input files
    file_delete(file_fullpath({sInputs.FileName}), 1);
    % Reload studies
    db_reload_studies(unique([sInputs.iStudy, iStudyTarget]));
end



