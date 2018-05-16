function varargout = process_select_files_data( varargin )
% PROCESS_SELECT_FILES_DATA: Select files from the database, based on the subject name and the condition.
%
% USAGE:  sProcess = process_select_files_data('GetDescription')
%                    process_select_files_data('Run', sProcess, sInputs)
%        FileNames = process_select_files_data('SelectFiles', ConditionPath, FileType, IncludeBad, IncludeIntra, IncludeCommon, CommentTag)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Select files: Recordings';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 1010;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/SelectFiles';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    % Definition of the options
    % SUBJECT NAME
    sProcess.options.subjectname.Comment = 'Subject name (empty=all):';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = 'All';
    % CONDITION
    sProcess.options.condition.Comment = 'Condition name (empty=all):';
    sProcess.options.condition.Type    = 'text';
    sProcess.options.condition.Value   = '';
    % COMMENT TAG
    sProcess.options.tag.Comment = 'File comment contains tag: ';
    sProcess.options.tag.Type    = 'text';
    sProcess.options.tag.Value   = '';
    % INCLUDE BAD TRIALS
    sProcess.options.includebad.Comment = 'Include the bad trials';
    sProcess.options.includebad.Type    = 'checkbox';
    sProcess.options.includebad.Value   = 0;
    % INCLUDE INTRA-SUBJECT
    sProcess.options.includeintra.Comment = 'Include the folder "Intra-subject"';
    sProcess.options.includeintra.Type    = 'checkbox';
    sProcess.options.includeintra.Value   = 0;
    % INCLUDE INTRA-SUBJECT
    sProcess.options.includecommon.Comment = 'Include the folder "Common files"';
    sProcess.options.includecommon.Type    = 'checkbox';
    sProcess.options.includecommon.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    % Subject name
    if isfield(sProcess.options, 'subjectname') && isfield(sProcess.options.subjectname, 'Value') && ~isempty(sProcess.options.subjectname.Value) && ischar(sProcess.options.subjectname.Value)
        SubjectName = strtrim(sProcess.options.subjectname.Value);
        if isempty(SubjectName) || any(SubjectName == '*') || strcmpi(SubjectName, 'all')
            SubjectName = '*';
        end
    else
        SubjectName = '*';
    end
    % Condition
    if isfield(sProcess.options, 'condition') && isfield(sProcess.options.condition, 'Value') && ~isempty(sProcess.options.condition.Value) && ischar(sProcess.options.condition.Value)
        Condition = strtrim(sProcess.options.condition.Value);
        if isempty(Condition) || any(Condition == '*') || strcmpi(Condition, 'all')
            Condition = '*';
        end
    else
        Condition = '*';
    end
    % File type
    if isfield(sProcess.options, 'filetype') && isfield(sProcess.options.filetype, 'Value') && ~isempty(sProcess.options.filetype.Value)
        FileType = sProcess.options.filetype.Value;
    else
        FileType = 'data';
    end
    % File type
    if isfield(sProcess.options, 'tag') && isfield(sProcess.options.tag, 'Value') && ~isempty(sProcess.options.tag.Value)
        CommentTag = sProcess.options.tag.Value;
    else
        CommentTag = [];
    end
    % Comment
    Comment = ['Select ' FileType ' files in: ' SubjectName '/' Condition];
    if ~isempty(CommentTag)
        Comment = [Comment, '/', CommentTag];
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Subject name
    if isfield(sProcess.options, 'subjectname') && isfield(sProcess.options.subjectname, 'Value') && ~isempty(sProcess.options.subjectname.Value) && ischar(sProcess.options.subjectname.Value)
        SubjectName = strtrim(sProcess.options.subjectname.Value);
        if isempty(SubjectName) || any(SubjectName == '*') || strcmpi(SubjectName, 'all')
            SubjectName = '*';
        end
    else
        SubjectName = '*';
    end
    % Condition
    if isfield(sProcess.options, 'condition') && isfield(sProcess.options.condition, 'Value') && ~isempty(sProcess.options.condition.Value) && ischar(sProcess.options.condition.Value)
        Condition = strtrim(sProcess.options.condition.Value);
        if isempty(Condition) || any(Condition == '*') || strcmpi(Condition, 'all')
            Condition = '*';
        end
    else
        Condition = '*';
    end
    % File type
    if isfield(sProcess.options, 'tag') && isfield(sProcess.options.tag, 'Value') && ~isempty(sProcess.options.tag.Value)
        CommentTag = sProcess.options.tag.Value;
    else
        CommentTag = [];
    end
    % File type
    if isfield(sProcess.options, 'filetype') && isfield(sProcess.options.filetype, 'Value') && ~isempty(sProcess.options.filetype.Value)
        FileType = sProcess.options.filetype.Value;
    else
        FileType = 'data';
    end
    % Bad channels and special folders
    if isfield(sProcess.options, 'includebad') && isfield(sProcess.options.includebad, 'Value') && ~isempty(sProcess.options.includebad.Value)
        IncludeBad = sProcess.options.includebad.Value;
    else
        IncludeBad = 0;
    end
    if isfield(sProcess.options, 'includeintra') && isfield(sProcess.options.includeintra, 'Value') && ~isempty(sProcess.options.includeintra.Value)
        IncludeIntra = sProcess.options.includeintra.Value;
    else
        IncludeIntra = 0;
    end
    if isfield(sProcess.options, 'includecommon') && isfield(sProcess.options.includecommon, 'Value') && ~isempty(sProcess.options.includecommon.Value)
        IncludeCommon = sProcess.options.includecommon.Value;
    else
        IncludeCommon = 0;
    end
    % Get files
    OutputFiles = SelectFiles([SubjectName '/' Condition], FileType, IncludeBad, IncludeIntra, IncludeCommon, CommentTag);

    % Build process comment
    strInfo = [FormatComment(sProcess) ' '];
    if IncludeCommon
        strInfo = [strInfo '+Common'];
    end
    if IncludeIntra
        strInfo = [strInfo '+Intra'];
    end
    if IncludeBad
        strInfo = [strInfo '+Bad'];
    end
    strInfo = [strInfo 10 'Found ' num2str(length(OutputFiles)) ' files.'];
    % Save in the report
    bst_report('Info', sProcess, [], strInfo);
end


%% ===== SELECT FILES =====
function FileNames = SelectFiles(ConditionPath, FileType, IncludeBad, IncludeIntra, IncludeCommon, CommentTag)
    FileNames = {};
    % Parse inputs
    if (nargin < 6) || isempty(CommentTag)
        CommentTag = [];
    end
    if (nargin < 5) || isempty(IncludeCommon)
        IncludeCommon = 0;
    end
    if (nargin < 4) || isempty(IncludeIntra)
        IncludeIntra = 0;
    end
    if (nargin < 3) || isempty(IncludeBad)
        IncludeBad = 0;
    end
    % Error in file selection
    try
        % Get all the conditions in the protocol
        if (ConditionPath(end) == '*') && (ConditionPath(1) == '*')
            % Get regular studies
            sProtocolStudies = bst_get('ProtocolStudies');
            sStudies = sProtocolStudies.Study;
            iStudies = 1:length(sProtocolStudies.Study);
            % Get/remove common files folder
            if IncludeCommon
                sStudies = [sStudies, sProtocolStudies.DefaultStudy];
                iStudies = [iStudies, -3];
            else
                iRem = find(cellfun(@(c)isequal(c,{bst_get('DirDefaultStudy')}), {sStudies.Condition}));
                if ~isempty(iRem)
                    sStudies(iRem) = [];
                    iStudies(iRem) = [];
                end
            end
            % Get/remove intra subject folder
            if IncludeIntra
                sStudies = [sStudies, sProtocolStudies.AnalysisStudy];
                iStudies = [iStudies, -2];
            else
                iRem = find(cellfun(@(c)isequal(c,{bst_get('DirAnalysisIntra')}), {sStudies.Condition}));
                if ~isempty(iRem)
                    sStudies(iRem) = [];
                    iStudies(iRem) = [];
                end
            end
        % Get all the conditions in one subject
        elseif (ConditionPath(end) == '*')
            % Get subject
            SubjectName = bst_fileparts(ConditionPath);
            sSubject = bst_get('Subject', SubjectName, 1);
            % Get studies in subject
            if ~isempty(sSubject)
                paramGet = {sSubject.FileName};
                if IncludeCommon
                    paramGet{end+1} = 'default_study';
                end
                if IncludeIntra
                    paramGet{end+1} = 'intra_subject';
                end  
                [sStudies, iStudies] = bst_get('StudyWithSubject', paramGet{:});
            else
                sStudies = [];
                iStudies = [];
            end
        % Get one condition in one subject
        else
            [sStudies, iStudies] = bst_get('StudyWithCondition', ConditionPath);
        end
    catch
        sStudies = [];
        iStudies = [];
    end
    % Nothing found
    if isempty(sStudies)
        bst_report('Error', 'process_select_files_data', [], ['No study found with path "' ConditionPath '".']);
        return
    end
    % Get entries in the selected studies
    switch lower(FileType)
        case 'data'
            sData = [sStudies.Data];
            % Exclude bad trials
            if ~IncludeBad
                isBadTrial = logical([sData.BadTrial]);
                sData = sData(~isBadTrial);
            end
            
        case 'results'
            sData = [sStudies.Result];
            % Exclude shared kernels
            isSharedKernel = cellfun(@isempty, {sData.DataFile}) & ~cellfun(@(c)isempty(strfind(c, 'KERNEL')), {sData.FileName});
            sData(isSharedKernel) = [];
            % Exclude bad trials
            if ~IncludeBad
                % Get the bad trials in these folders
                sDataRef = [sStudies.Data];
                isBadRef = logical([sDataRef.BadTrial]);
                % Get the files to which the trials are attached
                DataRefFiles = {sData.DataFile};
                iDataFile = find(~cellfun(@isempty, DataRefFiles));
                % Find which results are attached to bad trials
                iBadTrial = find(ismember({sData(iDataFile).DataFile}, {sDataRef(isBadRef).FileName}));
                % Remove results attached to bad trials
                if ~isempty(iBadTrial)
                    sData(iDataFile(iBadTrial)) = [];
                end
            end
            
        case 'timefreq'
            sData = [sStudies.Timefreq];
            % Exclude bad trials
            if ~IncludeBad
                iBadTrial = [];
                iTrial = 0;
                % Check file by file
                for i = 1:length(sStudies)
                    for iTf = 1:length(sStudies(i).Timefreq)
                        iTrial = iTrial + 1;
                        % Get DataFile
                        DataFile = sStudies(i).Timefreq(iTf).DataFile;
                        if isempty(DataFile)
                            continue;
                        end
                        DataType = file_gettype(DataFile);
                        % Time-freq on results: get DataFile
                        if ismember(DataType, {'results','link'})
                            [tmp__,tmp__,iRes] = bst_get('ResultsFile', DataFile, iStudies(i));
                            if ~isempty(iRes)
                                DataFile = sStudies(i).Result(iRes).DataFile;
                            else
                                DataFile = [];
                            end
                        % Time-freq on results: get DataFile
                        elseif strcmpi(DataType, 'matrix')
                            DataFile = [];
                        end
                        % Check if bad trials
                        if ~isempty(DataFile)
                            % Get the associated data file
                            [tmp__,tmp__,iData] = bst_get('DataFile', DataFile, iStudies(i));
                            % In the case of projected sources: the source file might not be in the same folder
                            if isempty(iData)
                                [sStudy_tmp,iStudy_tmp,iData] = bst_get('DataFile', DataFile);
                                if ~isempty(iData) && sStudy_tmp.Data(iData).BadTrial
                                    iBadTrial(end+1) = iTrial;
                                end
                            % Check if data file is bad
                            elseif sStudies(i).Data(iData).BadTrial
                                iBadTrial(end+1) = iTrial;
                            end
                        end
                    end
                    % Remove all the bad files
                    if ~isempty(iBadTrial)
                        sData(iBadTrial) = [];
                    end
                end
            end
            
        case 'matrix'
            sData = [sStudies.Matrix];
            
        case 'dipoles'
            sData = [sStudies.Dipoles];
            
        otherwise
            bst_report('Error', 'process_select_files', [], ['Invalid file type ' FileType '.']);
            return;
    end
    % Search by comment tag
    if ~isempty(CommentTag) && ~isempty(sData)
        % Find the tag in the file comments
        isTag = ~cellfun(@(c)isempty(strfind(upper(c),upper(CommentTag))), {sData.Comment});
        % Keep only these files
        sData = sData(isTag);
    end
    % Nothing found
    if isempty(sData)
        bst_report('Error', 'process_select_files_data', [], ['No data files found in folder "' ConditionPath '".']);
        return
    end    
    % Return file names
    FileNames = {sData.FileName};
end



