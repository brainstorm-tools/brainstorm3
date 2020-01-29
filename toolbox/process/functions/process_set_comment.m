function varargout = process_set_comment( varargin )
% PROCESS_SET_COMMENT: Edit the comment field of all the input files.

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
% Authors: Francois Tadel, 2012

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Set name';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1020;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix', 'raw', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix', 'raw', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === TARGET
    sProcess.options.tag.Comment = 'New name:';
    sProcess.options.tag.Type    = 'text';
    sProcess.options.tag.Value   = '';
    % === INDEX
    sProcess.options.isindex.Comment = 'Add a file index to the name';
    sProcess.options.isindex.Type    = 'checkbox';
    sProcess.options.isindex.Value   = 1;
    % === WARNING
    sProcess.options.label_warning.Comment    = '&nbsp;<FONT color=#7F7F7F>Warning: Names cannot contain square brackets.</FONT>';
    sProcess.options.label_warning.Type       = 'label';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    tag = strtrim(sProcess.options.tag.Value);
    if isempty(tag)
        tag = 'Not defined';
    end
    Comment = [sProcess.Comment ': ' tag];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Return all files
    OutputFiles = {sInputs.FileName};
    % Get new comment
    Comment = sProcess.options.tag.Value;
    if isempty(Comment)
        bst_report('Error', sProcess, sInputs, 'Name is not defined.');
        return
    elseif ~isempty(strfind(Comment, '[')) || ~isempty(strfind(Comment, ']'))
        bst_report('Error', sProcess, sInputs, 'Names cannot contain square brackets.');
        return
    end
    % Add index
    isIndex = sProcess.options.isindex.Value;
    % Group files by study
    uniqueStudy = unique([sInputs.iStudy]);
    % Update each study
    for i = 1:length(uniqueStudy)
        % Get study
        iStudy = uniqueStudy(i);
        sStudy = bst_get('Study', iStudy);
        % Get all the files for this condition
        iFiles = find([sInputs.iStudy] == iStudy);
        % Loop over all the files for this condition
        for k = 1:length(iFiles)
            % Get full filename
            FileName = file_fullpath(sInputs(iFiles(k)).FileName);
            % Load file
            FileMat = load(FileName, 'Comment');
            % Set comment
            FileMat.Comment = Comment;
            % Add index
            if isIndex && (length(iFiles) > 1)
%                 if (length(sInputs) > 999)
%                     format = '%04d';
%                 elseif (length(sInputs) > 99)
%                     format = '%03d';
%                 else
%                     format = '%02d';
%                 end
                format = '%d';
                FileMat.Comment = [FileMat.Comment, ' (#', sprintf(format, k), ')'];
            end
            % Save file
            save(FileName, '-struct', 'FileMat', '-append');
%             % Update file comment
%             switch (sInputs(iFiles(k)).FileType)
%                 case 'data'
%                     sStudy.Data(sInputs(iFiles(k)).iItem).Comment = FileMat.Comment;
%                 case 'results'
%             end
        end
        % Update study
        bst_set('Study', iStudy, sStudy);
    end
    % Reload studies
    db_reload_studies(uniqueStudy);
end



