function varargout = process_noisecov( varargin )
% PROCESS_NOISECOV: Compute a noise covariance matrix

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
% Authors: Francois Tadel, 2012-2022

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Compute covariance (noise or data)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 321;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/NoiseCovariance';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    sProcess.OutputTypes = {'data', 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Option: Baseline
    sProcess.options.baseline.Comment = 'Baseline:';
    sProcess.options.baseline.Type    = 'baseline';
    sProcess.options.baseline.Value   = [];
    % Option: Data
    sProcess.options.datatimewindow.Comment = 'Data: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    sProcess.options.datatimewindow.Type    = 'poststim';
    sProcess.options.datatimewindow.Value   = [];
    % Option: Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG, SEEG, ECOG';
    % Option: noisecov/ndatacov
    sProcess.options.label0.Comment = '<BR>Matrix to estimate:';
    sProcess.options.label0.Type    = 'label';
    sProcess.options.target.Comment = {'Noise covariance &nbsp;&nbsp;&nbsp; <FONT color="#777777"><I>(covariance over baseline time window)</I></FONT>', ...
                                       'Data covariance &nbsp;&nbsp;&nbsp;&nbsp; <FONT color="#777777"><I>(covariance over data time window)</I>'};
    sProcess.options.target.Type    = 'radio';
    sProcess.options.target.Value   = 1;
    % Options: Remove DC offset
    sProcess.options.label1.Comment = 'Remove DC offset: &nbsp;&nbsp;&nbsp; <FONT color="#777777"><I>(subtract average computed over the baseline)</I></FONT>';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.dcoffset.Comment = {'Block by block, to avoid effects of slow shifts in data', 'Compute global average and remove it to from all the blocks'};
    sProcess.options.dcoffset.Type    = 'radio';
    sProcess.options.dcoffset.Value   = 1;
    % Option: Identity matrix
    sProcess.options.identity.Comment = 'No noise modeling (use identity matrix instead)';
    sProcess.options.identity.Type    = 'checkbox';
    sProcess.options.identity.Value   = 0;
    sProcess.options.identity.Group   = 'Output';
    % Option: Copy to other folders
    sProcess.options.copycond.Comment = 'Copy to other folders';
    sProcess.options.copycond.Type    = 'checkbox';
    sProcess.options.copycond.Value   = 0;
    sProcess.options.copycond.Group   = 'Output';
    % Option: Copy to other subjects
    sProcess.options.copysubj.Comment = 'Copy to other subjects';
    sProcess.options.copysubj.Type    = 'checkbox';
    sProcess.options.copysubj.Value   = 0;
    sProcess.options.copysubj.Group   = 'Output';
    % Option: Match noise and subject recordings by acquisition data
    sProcess.options.copymatch.Comment = 'Match noise and subject recordings by acquisition date';
    sProcess.options.copymatch.Type    = 'checkbox';
    sProcess.options.copymatch.Value   = 0;
    sProcess.options.copymatch.Group   = 'Output';
    % Option: Replace file
    sProcess.options.replacefile.Comment = {'Replace', 'Merge', 'Keep', 'If file already exists: '};
    sProcess.options.replacefile.Type    = 'radio_line';
    sProcess.options.replacefile.Value   = 1;
    sProcess.options.replacefile.Group   = 'Output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % If the inputs are multiple RAW files: compute one noise covariance for each one
    if (length(sInputs) > 1) && strcmpi(sInputs(1).FileType, 'raw')
        for i = 1:length(sInputs)
            OutputFiles = [OutputFiles{:}, RunFile(sProcess, sInputs(i), sInputs(setdiff(1:length(sInputs), i)))];
        end
    else
        OutputFiles = RunFile(sProcess, sInputs, []);
    end
end

%% ===== RUN: ONE OUTPUT FILE =====
function OutputFiles = RunFile(sProcess, sInputs, sInputsOther)
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    isDataCov = (sProcess.options.target.Value == 2);
    % Get default options
    OPTIONS = bst_noisecov();
    % Get options
    
    if isfield(sProcess.options, 'baseline') && isfield(sProcess.options.baseline, 'Value') && iscell(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value) && ~isempty(sProcess.options.baseline.Value{1})
        OPTIONS.Baseline = sProcess.options.baseline.Value{1};
    else
        OPTIONS.Baseline = [];
    end
    if isfield(sProcess.options, 'datatimewindow') && isfield(sProcess.options.datatimewindow, 'Value') && iscell(sProcess.options.datatimewindow.Value) && ~isempty(sProcess.options.datatimewindow.Value) && ~isempty(sProcess.options.datatimewindow.Value{1})
        OPTIONS.DataTimeWindow = sProcess.options.datatimewindow.Value{1};
    else
        OPTIONS.DataTimeWindow = [];
    end
    if isfield(sProcess.options, 'sensortypes') && ~isempty(sProcess.options.sensortypes)
        OPTIONS.ChannelTypes = strtrim(str_split(sProcess.options.sensortypes.Value, ','));
    else 
        OPTIONS.ChannelTypes = [];
    end
    switch (sProcess.options.dcoffset.Value)
        case 1,  OPTIONS.RemoveDcOffset = 'file';
        case 2,  OPTIONS.RemoveDcOffset = 'all';
    end
    if isfield(sProcess.options, 'identity') && ~isempty(sProcess.options.identity) && isfield(sProcess.options.identity, 'Value') && ~isempty(sProcess.options.identity.Value)
        isIdentity = sProcess.options.identity.Value;
    else 
        isIdentity = 0;
    end
    % Copy to other studies
    isCopyCond  = sProcess.options.copycond.Value;
    isCopySubj  = sProcess.options.copysubj.Value;
    isCopyMatch = sProcess.options.copymatch.Value;
    % Replace file?
    if isfield(sProcess.options, 'replacefile') && isfield(sProcess.options.replacefile, 'Value') && ~isempty(sProcess.options.replacefile.Value)
        switch (sProcess.options.replacefile.Value)
            case 1,   OPTIONS.ReplaceFile = 1;
            case 2,   OPTIONS.ReplaceFile = 2;
            case 3,   OPTIONS.ReplaceFile = 0;
        end
    else
        OPTIONS.ReplaceFile = 1;
    end

    % ===== GET DATA =====
    % Get all the input data files
    iStudies = [sInputs.iStudy];
    iDatas   = [sInputs.iItem];
    % Get channel studies
    [tmp, iChanStudies] = bst_get('ChannelForStudy', iStudies);
    % Keep only once each channel file
    iChanStudies = unique(iChanStudies);
    
    % ===== COMPUTE =====
    % No noise modeling: Use identity matrix
    if isIdentity
        NoiseCovFiles = import_noisecov(iChanStudies, 'Identity', OPTIONS.ReplaceFile, isDataCov);
    % Compute NoiseCov matrix
    else
        NoiseCovFiles = bst_noisecov(iChanStudies, iStudies, iDatas, OPTIONS, isDataCov);
    end
    if isempty(NoiseCovFiles)
        bst_report('Error', sProcess, sInputs, 'Unknown error.');
        return;
    end
        
    % ===== GET OUTPUT STUDY =====
    % Only the input studies
    if ~isCopyCond && ~isCopySubj
        iCopyStudies = [];
    % All the folders of the selected subjects
    elseif isCopyCond && ~isCopySubj
        iCopyStudies = [];
        AllSubjFile = unique({sInputs.SubjectFile});
        for iSubj = 1:length(AllSubjFile)
            [tmp, iNew] = bst_get('StudyWithSubject', AllSubjFile{iSubj});
            iCopyStudies = [iCopyStudies, iNew];
        end
    % The selected folders for all the subjects
    elseif ~isCopyCond && isCopySubj
        iCopyStudies = [];
        ProtocolSubjects = bst_get('ProtocolSubjects');
        AllCond = unique({sInputs.Condition});
        AllSubj = {ProtocolSubjects.Subject.Name};
        for iSubj = 1:length(AllSubj)
            for iCond = 1:length(AllCond)
                [tmp, iNew] = bst_get('StudyWithCondition', [AllSubj{iSubj}, '/', AllCond{iCond}]);
                iCopyStudies = [iCopyStudies, iNew];
            end
        end
    % All the studies
    elseif isCopyCond && isCopySubj
        ProtocolStudies = bst_get('ProtocolStudies');
        iCopyStudies = 1:length(ProtocolStudies.Study);
    end
    iCopyStudies = unique(iCopyStudies);
    % Remove input file
    if ~isempty(iCopyStudies)
        iCopyStudies = setdiff(iCopyStudies, [sInputs.iStudy]);
    end
    % Remove other input raw files, if any
    if ~isempty(iCopyStudies) && ~isempty(sInputsOther)
        iCopyStudies = setdiff(iCopyStudies, [sInputsOther.iStudy]);
    end
    
    % ===== MATCH NOISE AND SUBJECT FOLDERS BY DATE =====
    % Use the field DateOfStudy to copy only the noise covariance file closest in time in each subject folder
    if isCopyMatch && ~isempty(iCopyStudies) && ~isempty(sInputsOther)
        % Get the dates of all the inputs
        inputDate = GetStudyDate(sInputs(1).iStudy);
        for i = 1:length(sInputsOther)
            otherDates{i} = GetStudyDate(sInputsOther(i).iStudy);
        end
        % Loop through the folders to copy, remove the ones that have a closer noise file in the input list
        iSelect = [];
        for i = 1:length(iCopyStudies)
            % Skip folders that don't have any recordings in them
            if isempty(ProtocolStudies.Study(iCopyStudies(i)).Data)
                continue;
            end
            % Get acquisition date for current input file
            copyDate = GetStudyDate(iCopyStudies(i));
            % Skip if there are empty study dates
            if isempty(copyDate) || isempty(inputDate) || any(cellfun(@isempty, otherDates))
                bst_report('Warning', 'process_noisecov', sInputs, 'Date of study missing in at least one folder... Cannot match by dates.');
                continue;
            end
            % Keep the list only if it the closest to the current input file
            if all(abs(inputDate - copyDate) < abs([otherDates{:}] - copyDate))
                iSelect(end+1) = i;
            end
        end
        % Keep only the selected studies
        iCopyStudies = iCopyStudies(iSelect);
        % Report as a warning the matching
        if ~isempty(iCopyStudies)
            strMsg = ['Noise covariance from "' bst_fileparts(sInputs(1).FileName) '" copied to:'];
            for i = 1:length(iCopyStudies)
                strMsg = [strMsg, 10, ' - ' bst_fileparts(ProtocolStudies.Study(iCopyStudies(i)).FileName)];
            end
            bst_report('Warning', 'process_noiecov', sInputs, strMsg);
        end
    end
    
    % ===== COPY TO OTHER STUDIES =====
    if ~isempty(iCopyStudies)
        % Get channel studies
        [tmp, iCopyChanStudies] = bst_get('ChannelForStudy', iCopyStudies);
        % Remove studies that are already processed
        iCopyChanStudies = setdiff(unique(iCopyChanStudies), iChanStudies);
        % Copy noise covariance to other subjects/folders (overwrites)
        if ~isempty(iCopyChanStudies)
            db_set_noisecov(iChanStudies(1), iCopyChanStudies, isDataCov, OPTIONS.ReplaceFile);
        end
    end
    % Return the data files in input
    OutputFiles = {sInputs.FileName};
end



%% ===== GET STUDY DATE =====
function studyDate = GetStudyDate(iStudy)
    % Get the study definition
    sStudy = bst_get('Study', iStudy);
    % Get its acquisition date
    if ~isempty(sStudy.DateOfStudy)
        studyDate = datenum(sStudy.DateOfStudy);
    else
        studyDate = [];
    end
end

