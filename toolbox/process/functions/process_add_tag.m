function varargout = process_add_tag( varargin )
% PROCESS_ADD_TAG: Add a comment tag.
%
% USAGE:     sProcess = process_add_tag('GetDescription')
%                       process_add_tag('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2012-2020
%          Raymundo Cassani, 2023

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
    sProcess.options.output.Comment = {'Add to file name', 'Add to file path', 'Add to file name and file path'; ...
                                       'name', 'path', 'name_path'};
    sProcess.options.output.Type    = 'radio_label';
    sProcess.options.output.Value   = 'name';
    % === WARNING
    sProcess.options.label_warning.Comment    = '&nbsp;<FONT color=#7F7F7F>Warning: Tags cannot contain square brackets.</FONT>';
    sProcess.options.label_warning.Type       = 'label';
    % === WARNING
    sProcess.options.label_warning2.Comment   = '&nbsp;<FONT color=#7F7F7F>Warning: Tags cannot be added to file path if there are dependent files.</FONT>';
    sProcess.options.label_warning2.Type      = 'label';

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
    % Where to add tag
    isNameTag = 0;
    isPathTag = 0;
    switch sProcess.options.output.Value
        case {1, 'name'}
            isNameTag = 1;
        case {2, 'path'}
            isPathTag = 1;
        case {3, 'name_path'}
            isNameTag = 1;
            isPathTag = 1;
    end
    % Standardize tag for file name
    if isPathTag
        fileTag = file_standardize(tag);
        if (fileTag(1) ~= '_')
            fileTag = ['_', fileTag];
        end
    end

    % Update each file
    reloadDatabase   = 0;
    subjectsToReload = [];
    studiesToReload  = [];
    RenamedKernels = {};
    for i = 1:length(sInputs)
        % Get file type
        fileType = file_gettype(sInputs(i).FileName);
            
        % === ADD TO COMMENT ===
        if isNameTag
            % Rename link => Rename shared kernel instead
            if strcmpi(fileType, 'link')
                % Handle reload depending on kernel in GlobalDefault, Default and Normal Study
                sStudy = bst_get('Study', sInputs(i).iStudy);
                [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
                if sSubject.UseDefaultChannel == 2
                    reloadDatabase = 1;
                elseif sSubject.UseDefaultChannel == 1
                    subjectsToReload(end+1) = iSubject;
                elseif sSubject.UseDefaultChannel == 0
                    studiesToReload(end+1) = sInputs(i).iStudy;
                end
                KernelFile = file_resolve_link(sInputs(i).FileName);
                % Check if this kernel has already been renamed
                if ismember(KernelFile, RenamedKernels)
                    continue;
                end
                RenamedKernels{end+1} = KernelFile;
            end
            % Load file
            FileName = file_fullpath(sInputs(i).FileName);
            FileMat = load(FileName, 'Comment');
            % Add comment
            FileMat.Comment = [FileMat.Comment ' | ' tag];
            % Save file
            bst_save(FileName, FileMat, 'v6', 1);
        end

        % === ADD TO FILE NAME ===
        if isPathTag
            % Get study structure
            sStudy = bst_get('Study', sInputs(i).iStudy);
            % Check if files has dependent files
            AllDepFiles = {sStudy.Dipoles.DataFile, sStudy.Result.DataFile, sStudy.Timefreq.DataFile};
            AllDepFiles(cellfun(@isempty, AllDepFiles)) = [];
            if any(cellfun(@(c)file_compare(c,sInputs(i).FileName), AllDepFiles))
                bst_report('Error', sProcess, sInputs(i), ...
                    ['The input file has some dependent files.' ...
                    'To preserve links in the database, a tag cannot be added to the file path.']);
                continue;
            end
            % Rename link => Rename shared kernel instead
            if strcmpi(fileType, 'link')
                % Add tag to kernel file name
                OldFileName = file_resolve_link(sInputs(i).FileName);
                [fPath, fBase, fExt] = bst_fileparts(OldFileName);
                NewFileName = bst_fullfile(fPath, [fBase, fileTag, fExt]);
                OutputFiles{i} = strrep(sInputs(i).FileName, file_short(OldFileName), file_short(NewFileName));
                % Handle reload depending on kernel in GlobalDefault, Default and Normal Study
                sStudy = bst_get('Study', sInputs(i).iStudy);
                [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
                if sSubject.UseDefaultChannel == 2
                    reloadDatabase = 1;
                elseif sSubject.UseDefaultChannel == 1
                    subjectsToReload(end+1) = iSubject;
                elseif sSubject.UseDefaultChannel == 0
                    studiesToReload(end+1) = sInputs(i).iStudy;
                end
                % Check if this kernel has already been renamed
                if ismember(OldFileName, RenamedKernels)
                    continue;
                end
                RenamedKernels{end+1} = OldFileName;
            % Regular file
            else
                % Add tag to filename
                OldFileName = file_fullpath(sInputs(i).FileName);
                [fPath, fBase, fExt] = bst_fileparts(OldFileName);
                NewFileName = bst_fullfile(fPath, [fBase, fileTag, fExt]);
                OutputFiles{i} = file_short(NewFileName);
            end
            % Rename file
            try 
                file_move(OldFileName, NewFileName);
            catch
                bst_report('Error', sProcess, sInputs, ['Cannot rename file "' OldFileName '" to "' NewFileName '".']);
                continue;
            end
        end
    end
    % Reload necessary subjects and studies
    if reloadDatabase
        db_reload_database('current');
    else
        if ~isempty(subjectsToReload)
            db_reload_conditions(unique(subjectsToReload));
        end
        db_reload_studies(unique([studiesToReload, sInputs.iStudy]));
    end
end



