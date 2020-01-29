function varargout = process_add_tag( varargin )
% PROCESS_ADD_TAG: Add a comment tag.
%
% USAGE:     sProcess = process_add_tag('GetDescription')
%                       process_add_tag('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2012-2013

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Add tag';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1021;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles#How_to_control_the_output_file_names';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix', 'raw', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix', 'raw', 'pdata', 'presults', 'ptimefreq', 'pmatrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === TARGET
    sProcess.options.tag.Comment = 'Tag to add:';
    sProcess.options.tag.Type    = 'text';
    sProcess.options.tag.Value   = '';
    % === FILENAME / COMMENT
    sProcess.options.output.Comment = {'Add to file name', 'Add to file path'};
    sProcess.options.output.Type    = 'radio';
    sProcess.options.output.Value   = 1;
    % === WARNING
    sProcess.options.label_warning.Comment    = '&nbsp;<FONT color=#7F7F7F>Warning: Tags cannot contain square brackets.</FONT>';
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
    % Get new tag
    tag = sProcess.options.tag.Value;
    if isempty(tag)
        bst_report('Error', sProcess, sInputs, 'Tag is not defined.');
        return
    elseif ~isempty(strfind(tag, '[')) || ~isempty(strfind(tag, ']'))
        bst_report('Error', sProcess, sInputs, 'Tags cannot contain square brackets.');
        return
    end
    
    % === ADD TO COMMENT ===
    if (sProcess.options.output.Value == 1)
        % Update each file
        for i = 1:length(sInputs)
            % Load file
            FileName = file_fullpath(sInputs(i).FileName);
            FileMat = load(FileName, 'Comment');
            % Add comment
            FileMat.Comment = [FileMat.Comment ' | ' tag];
            % Save file
            bst_save(FileName, FileMat, 'v6', 1);
        end
        
    % === ADD TO FILE NAME ===
    else
        % File tag
        fileTag = file_standardize(tag);
        if (fileTag(1) ~= '_')
            fileTag = ['_', fileTag];
        end
        % Update each file
        for i = 1:length(sInputs)
            % Get study structure
            sStudy = bst_get('Study', sInputs(i).iStudy);
            % Check if files has dependent files
            AllDepFiles = {sStudy.Dipoles.DataFile, sStudy.Result.DataFile, sStudy.Timefreq.DataFile};
            AllDepFiles(cellfun(@isempty, AllDepFiles)) = [];
            if any(cellfun(@(c)file_compare(c,sInputs(i).FileName), AllDepFiles))
                bst_report('Error', sProcess, sInputs(i), 'The input file has some dependent files. In order to preserve the links in the database, it cannot be renamed.');
                continue;
            end
            % Rename file
            OldFileName = file_fullpath(sInputs(i).FileName);
            NewFileName = strrep(OldFileName, '.mat', [fileTag '.mat']);
            OutputFiles{i} = strrep(OutputFiles{i}, '.mat', [fileTag '.mat']);
            if ~strcmpi(OldFileName, NewFileName)
                try 
                    file_move(OldFileName, NewFileName);
                    FileName = NewFileName;
                catch
                    bst_report('Error', sProcess, sInputs, ['Cannot rename file "' OldFileName '" to "' NewFileName '".']);
                    FileName = OldFileName;
                    continue;
                end
            end
        end
    end
    % Reload studies
    db_reload_studies(unique([sInputs.iStudy]));
end



