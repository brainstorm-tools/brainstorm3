function varargout = process_delete( varargin )
% PROCESS_DELETE: Delete files, subject, or condition.
%
% USAGE:     sProcess = process_delete('GetDescription')
%                       process_delete('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2012-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Delete files';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1023;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles?highlight=%28Delete+files%29';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'raw', 'data', 'results', 'timefreq', 'matrix', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === TARGET
    sProcess.options.target.Comment = {'Delete selected files', 'Delete folders', 'Delete subjects'};  % , 'Delete raw file'
    sProcess.options.target.Type    = 'radio';
    sProcess.options.target.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = [sProcess.options.target.Comment{sProcess.options.target.Value}];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Get options
    DeleteTarget = sProcess.options.target.Value;
    % Returned files: NONE
    OutputFiles = {};

    % Group files in different ways: by subject, by condition, or all together
    switch (DeleteTarget)
        % === DATA FILES ===
        case 1
            % Delete all the files
            file_delete(file_fullpath(unique({sInputs.FileName})), 1);
            % Reload studies
            db_reload_studies(unique([sInputs.iStudy]));
                
        % === CONDITIONS ===
        case 2
            % Remove all the special studies (intra, inter...)
            specialNames = {bst_get('DirDefaultStudy'), bst_get('DirAnalysisIntra'), bst_get('DirAnalysisInter')};
            iSpecial = find(cellfun(@(c)ismember(c,specialNames), {sInputs.Condition}));
            if ~isempty(iSpecial)
                bst_report('Warning', sProcess, sInputs(iSpecial), 'Some studies cannot be remove (inter-subject, intra-subject, default study).');
                sInputs(iSpecial) = [];
            end
            % Nothing to delete
            if isempty(sInputs)
                return;
            end
            % Delete the studies
            db_delete_studies(unique([sInputs.iStudy]));
            % Update whole tree
            panel_protocols('UpdateTree');

        % === SUBJECTS ===
        case 3
            % Process each subject independently
            uniqueSubj = unique({sInputs.SubjectName});
            % Get subject indices
            iSubjects = [];
            for iSubj = 1:length(uniqueSubj)
                [sSubject, iSubjects(iSubj)] = bst_get('Subject', uniqueSubj{iSubj});
            end
            % Remove default subject
            if any(iSubjects == 0)
                bst_report('Warning', sProcess, sInputs, 'Cannot delete default subject.');
                iSubjects(iSubjects == 0) = [];
            end
            % No subject
            if isempty(iSubjects)
                return
            end
            % Delete subjects
            db_delete_subjects( iSubjects );
            
%         % === RAW FILES ===
%         case 4
%             % Continuous raw file 
%             if strcmpi(sInputs(1).FileType, 'raw')
%                 for i = 1:length(sInputs)
%                     panel_record('DeleteRawFile', sInputs(i).FileName, 1);
%                 end
%             % Other files
%             else
%                 bst_report('Error', sProcess, sInputs, 'The option "Delete raw file" can be used only to remove raw files.');
%             end
    end
end



