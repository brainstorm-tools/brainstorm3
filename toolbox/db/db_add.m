function OutputFile = db_add(iTarget, InputFile, isReload, ParentFile)
% DB_ADD: Create a new file in a given study.
%
% USAGE:  db_add(iStudy/iSubject, InputFile, isReload)
%         db_add(iStudy/iSubject, sNew     , isReload)
%         db_add(iStudy/iSubject)             : Read a variable from Matlab workspace

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
% Authors: Francois Tadel, 2011-2019

%% ===== GET INPUT FILE =====
if (nargin < 3) || isempty(isReload)
    isReload = 1;
end
if nargin < 4
    ParentFile = [];
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
        elseif ismember(lower(sMat.Method), {'pac', 'dpac', 'tpac'}) && isfield(sMat,'sPAC')
            if isfield(sMat.sPAC, 'DirectPAC') && ~isempty(sMat.sPAC.DirectPAC)
                fileSubType = 'pac_fullmaps_';
            else
                fileSubType = 'dpac_fullmaps_';
            end
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
sqlConn = sql_connect();
if isAnatomy
    % Get destination study
    sSubject = db_get(sqlConn, 'Subject', iTarget, 'FileName');
    % Build full filename
    OutputFileFull = file_unique(bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(sSubject.FileName), OutputFile));
    OutputFile = file_short(OutputFileFull);
else
    % Get parent file
    if ~isempty(ParentFile)
        sFuncFileParent = db_get(sqlConn, 'FunctionalFile', ParentFile, {'FileName', 'Type'});
        if strcmpi(sFuncFileParent.Type, 'folder')
            ParentFolder = sFuncFileParent.FileName;
        else
            ParentFolder = bst_fileparts(sFuncFileParent.FileName);
        end
    else
        sStudy = db_get(sqlConn, 'Study', iTarget, 'FileName');
        ParentFolder = bst_fileparts(sStudy.FileName);
    end
    % Build full filename
    OutputFileFull = file_unique(bst_fullfile(ProtocolInfo.STUDIES, ParentFolder, OutputFile));
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
            sFuncFile = db_get(sqlConn, 'FunctionalFile', struct('Study', iTarget, 'Type', 'channel'), 'Filename');
            if ~isempty(sFuncFile)
                delfile = bst_fullfile(ProtocolInfo.STUDIES, sFuncFile.FileName);
            end
        case 'noisecov'
            sFuncFile = db_get(sqlConn, 'FunctionalFile', struct('Study', iTarget, 'Type', 'noisecov'), 'Filename');
            if ~isempty(sFuncFile)
                delfile = bst_fullfile(ProtocolInfo.STUDIES, sFuncFile(1).FileName);
            end
        case 'ndatacov'
            sFuncFile = db_get(sqlConn, 'FunctionalFile', struct('Study', iTarget, 'Type', 'ndatacov'), 'Filename');
            if ~isempty(sFuncFile)
                delfile = bst_fullfile(ProtocolInfo.STUDIES, sFuncFile(1).FileName);
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
    % Update comment with a file tag, to make it unique
    switch (fileType)
        case 'subjectimage'
            % Nothing to do: file is replaced anyway
        case {'tess', 'cortex', 'scalp', 'outerskull', 'innerskull', 'fibers', 'fem'}
            sAnatFiles = db_get(sqlConn, 'AnatomyFile', struct('Subject', 0), 'Name');
            sMat.Comment = file_unique(sMat.Comment, {sAnatFiles.Name});
    end
else
    % Add comment if missing
    if isempty(sMat.Comment)
        [tmp__, sMat.Comment] = bst_fileparts(InputFile);
    end
    
    % Get names of other files in same folder to ensure it's unique
    qryCond = struct('Study', iTarget, 'Type', fileType);
    if isempty(ParentFile)
        extraQry = 'AND ParentFile IS NULL';
    else
        qryCond.ParentFile = ParentFile;
        extraQry = '';
    end
    % Special case: only check result files with same parent data file
    if strcmpi(fileType, 'results')
        if ~isempty(sMat.DataFile)
            qryCond.ExtraStr1 = sMat.DataFile;
        else
            extraQry = [extraQry ' AND ExtraStr1 IS NULL'];
        end
    end
    sFiles = sql_query(sqlConn, 'SELECT', 'FunctionalFile', qryCond, 'Name', extraQry);
    
    if ismember(fileType, {'data', 'results', 'stat', 'timefreq', 'matrix'})
        matVer = 'v6';
    end
    
    % Update comment with a file tag, to make it unique
    sMat.Comment = file_unique(sMat.Comment, {sFiles.Name});
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
% Add to database
if isAnatomy
    sFile = db_template('AnatomyFile');
    sFile.Subject = iTarget;
    sFile.Type = fileType;
    sFile.FileName = OutputFile;
    sFile.Name = sMat.Comment;
    %TODO: sFile.SurfaceType
    db_set(sqlConn, 'AnatomyFile', sFile);
else
    sFile = db_template('FunctionalFile');
    sFile.Study = iTarget;
    sFile.ParentFile = ParentFile;
    sFile.Type = fileType;
    sFile.FileName = OutputFile;
    sFile.Name = sMat.Comment;
    switch fileType
        case 'data'
            sFile.SubType = sMat.DataType;
            sFile.ExtraNum = 0; % BadTrial
        otherwise
            error('Unsupported for now.');
    end
    %TODO, get rest of metadata from file (see db_parse_study)
    db_set(sqlConn, 'FunctionalFile', sFile);
    % Update count of parent file
    db_set(sqlConn, 'ParentCount', ParentFile, '+', 1);
end
sql_close(sqlConn);

% Close progress bar
if ~isProgress
    bst_progress('stop');
end
% Refresh display
if isReload
    panel_protocols('UpdateTree');
    panel_protocols('SelectNode', [], OutputFileFull);
end



