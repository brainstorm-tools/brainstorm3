function OutputFile = db_add(iTarget, InputFile, isReload)
% DB_ADD: Create a new file in a given study.
%
% USAGE:  db_add(iStudy/iSubject, InputFile, isReload)
%         db_add(iStudy/iSubject, sNew     , isReload)
%         db_add(iStudy/iSubject)             : Read a variable from Matlab workspace

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
% Authors: Francois Tadel, 2011-2019

%% ===== GET INPUT FILE =====
if (nargin < 3) || isempty(isReload)
    isReload = 1;
end
% USAGE:  db_add(iTarget)
if (nargin < 2) || isempty(InputFile)
    % Get variable from workspace
    [InputFile, varname] = in_matlab_var([], 'struct');
    if isempty(InputFile)
        OutputFile = [];
        return
    end
end
% USAGE:  db_add(iTarget, sMat)
if isstruct(InputFile)
    % Get structure
    sMat = InputFile;
    InputFile = [];
    % Detect file type
    fileType = file_gettype(sMat);
    % Add sub-category for timefreq files
    fileSubType = '';
    if ismember(fileType, {'timefreq', 'ptimefreq'})
        if ismember(lower(sMat.Method), {'corr', 'cohere', 'granger', 'spgranger', 'plv', 'plvt', 'aec', 'pte'})
            if isfield(sMat,'Options') && isfield(sMat.Options, 'ProcessName') && ~isempty(sMat.Options.ProcessName)
                if ismember(sMat.Options.ProcessName, {'process_corr1n', 'process_cohere1n', 'process_granger1n', 'process_spgranger1n', 'process_plv1n', 'process_aec1n', 'process_pte1n'})
                    fileSubType = ['connectn_', lower(sMat.Method), '_'];
                else
                    fileSubType = ['connect1_', lower(sMat.Method), '_'];
                end
            elseif (length(sMat.RefRowNames) > 1) && (isequal(sMat.RowNames, sMat.RefRowNames) || isequal(sMat.RowNames, sMat.RefRowNames'))
                fileSubType = ['connectn_', lower(sMat.Method), '_'];
                if (size(sMat.TF,1) == length(sMat.RefRowNames)*length(sMat.RowNames))
                    sMat.Options.isSymmetric = 0;
                else
                    sMat.Options.isSymmetric = 1;
                end
            else
                fileSubType = ['connect1_', lower(sMat.Method), '_'];
                sMat.Options.isSymmetric = 0;
            end
        elseif ismember(lower(sMat.Method), {'pac', 'dpac'}) && isfield(sMat,'sPAC') && ((isfield(sMat.sPAC,'DynamicPAC') && ~isempty(sMat.sPAC.DynamicPAC)) || (isfield(sMat.sPAC,'DirectPAC') && ~isempty(sMat.sPAC.DirectPAC)))
            fileSubType = [lower(sMat.Method), '_fullmaps_'];
        else
            fileSubType = [lower(sMat.Method), '_'];
        end
    end
    % Add stat thresholding method
    if ismember(fileType, {'pdata', 'presults', 'ptimefreq', 'pmatrix'})
        if isfield(sMat, 'Correction') && ~isempty(sMat.Correction)
            fileSubType = [fileSubType, lower(sMat.Correction), '_'];
        end
    end
    % Add zscore tag
    if isfield(sMat, 'ZScore') && ~isempty(sMat.ZScore)
        if isfield(sMat.ZScore, 'abs') && isequal(sMat.ZScore.abs, 1)
            fileSubType = [fileSubType 'abs_zscore_'];
        else
            fileSubType = [fileSubType 'zscore_'];
        end
    end
    % Some files cannot be imported
    if ismember(fileType, {'brainstormsubject', 'brainstormstudy', 'unknown'})
        bst_error('This structure cannot be imported in the database.', 'Add file to database', 0);
        return;
    end
    % Surfaces subtypes
    if ismember(fileType, {'fibers', 'fem'})
        fileSubType = fileType;
        fileType = 'tess';
    end
    isAnatomy = ismember(fileType, {'subjectimage', 'tess'});
    % Create a new output filename
    c = clock;
    strTime = sprintf('%02.0f%02.0f%02.0f_%02.0f%02.0f', c(1)-2000, c(2:5));
    OutputFile = [fileType '_' fileSubType strTime '.mat'];
    
% USAGE:  db_add(iTarget, InputFile)
else
    % Get full file path and type
    [InputFileFull, fileType, isAnatomy] = file_fullpath(InputFile);
    % Output filename
    [fPath, fBase] = bst_fileparts(InputFile);
    OutputFile = [fBase, '.mat'];
    % Read file
    sMat = load(InputFileFull);
end


%% ===== OUTPUT FILENAME =====
% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
% Full output filename
if isAnatomy
    % Get destination study
    sSubject = bst_get('Subject', iTarget);
    % Build full filename
    OutputFileFull = file_unique(bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(sSubject.FileName), OutputFile));
    OutputFile = file_short(OutputFileFull);
else
    % Get destination study
    sStudy = bst_get('Study', iTarget);
    % Build full filename
    OutputFileFull = file_unique(bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sStudy.FileName), OutputFile));
    OutputFile = file_short(OutputFileFull);
end


%% ===== REPLACE EXISTING FILES =====
% Check for files that can exist in only one version
if ismember(fileType, {'subjectimage', 'channel', 'noisecov', 'ndatacov'})
    % Get file to replace
    delfile = '';
    switch(fileType)
        case 'subjectimage'
%             if ~isempty(sSubject.Anatomy)
%                 delfile = bst_fullfile(ProtocolInfo.SUBJECTS, sSubject.Anatomy(1).FileName);
%             end
        case 'channel'
            if ~isempty(sStudy.Channel)
                delfile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.Channel(1).FileName);
            end
        case 'noisecov'
            if ~isempty(sStudy.NoiseCov) && ~isempty(sStudy.NoiseCov(1).FileName)
                delfile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.NoiseCov(1).FileName);
            end
        case 'ndatacov'
            if ~isempty(sStudy.NoiseCov) && (length(sStudy.NoiseCov) >= 2) && ~isempty(sStudy.NoiseCov(2).FileName)
                delfile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.NoiseCov(2).FileName);
            end
    end
    % Replace file
    if ~isempty(delfile)
        % Ask for user confirmation
        isdel = java_dialog('confirm', ['Replace existing ' fileType ' file?'], 'Add file to database');
        if ~isdel
            OutputFile = [];
            return
        end
        % Delete existing file
        file_delete(delfile, 1);
    end
end


%% ===== ADD COMMENT TAG =====
matVer = 'v7';
if isAnatomy
    % Get subject structure
    sSubject = bst_get('Subject', iTarget);
    % Update comment with a file tag, to make it unique
    switch (fileType)
        case 'subjectimage'
            % Nothing to do: file is replaced anyway
        case {'tess', 'cortex', 'scalp', 'outerskull', 'innerskull', 'fibers', 'fem'}
            sMat.Comment = file_unique(sMat.Comment, {sSubject.Surface.Comment});
    end
else
    % Add comment if missing
    if isempty(sMat.Comment)
        [tmp__, sMat.Comment] = bst_fileparts(InputFile);
    end
    % Get study structure
    sStudy = bst_get('Study', iTarget);
    % Update comment with a file tag, to make it unique
    switch (fileType)
        case 'data'
            sMat.Comment = file_unique(sMat.Comment, {sStudy.Data.Comment});
            matVer = 'v6';
        case 'headmodel'
            sMat.Comment = file_unique(sMat.Comment, {sStudy.HeadModel.Comment});
        case 'results'
            if ~isempty(sMat.DataFile)
                iRes = find(file_compare(sMat.DataFile, {sStudy.Result.DataFile}));
                if isempty(iRes)
                    iRes = find(cellfun(@isempty, {sStudy.Result.DataFile}));
                end
                if ~isempty(iRes)
                    sMat.Comment = file_unique(sMat.Comment, {sStudy.Result(iRes).Comment});
                end
            else
                sMat.Comment = file_unique(sMat.Comment, {sStudy.Result.Comment});
            end
            matVer = 'v6';
        case 'stat'
            sMat.Comment = file_unique(sMat.Comment, {sStudy.Stat.Comment});
            matVer = 'v6';
        case 'dipoles'
            sMat.Comment = file_unique(sMat.Comment, {sStudy.Dipoles.Comment});
        case 'timefreq'
            sMat.Comment = file_unique(sMat.Comment, {sStudy.Timefreq.Comment});
            matVer = 'v6';
        case 'matrix'
            sMat.Comment = file_unique(sMat.Comment, {sStudy.Matrix.Comment});
            matVer = 'v6';
    end
end

%% ===== ADD NEW FILE TO DATABASE =====
% Progress bar
isProgress = bst_progress('isVisible');
if ~isProgress
    bst_progress('start', 'Add file to database', 'Saving new file...');
else
    bst_progress('text', 'Saving new file...');
end
% Save new file
bst_save(OutputFileFull, sMat, matVer);
% Close progress bar
if ~isProgress
    bst_progress('stop');
end
% Reload output study
if isReload
    if isAnatomy
        db_reload_subjects(iTarget);
    else
        db_reload_studies(iTarget);
    end
    panel_protocols('UpdateTree');
    panel_protocols('SelectNode', [], OutputFileFull);
end



