function OutputFiles = bst_project_grid(ResultsFiles, iSubjectDest, isInteractive)
% BST_PROJECT_GRID: Project volume-based source files the template (files must have been computed from a template grid).
%
% USAGE:  OutputFiles = bst_project_grid(ResultsFiles, iSubjectDest=[group], isInteractive=1)
% 
% INPUT:
%    - ResultsFiles  : Relative path to sources file to project
%    - iSubjectDest  : Index of destination subject (by default: "Group analysis")
%    - isInteractive : If 1, displays questions and dialog boxes
%                      If 0, consider it is running from a process (no user interactions)

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
% Authors: Francois Tadel, 2016


% ===== INITIALIZATION ======
% Parse inputs
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 1;
end
if (nargin < 2) || isempty(iSubjectDest)
    [sSubjectDest, iSubjectDest] = bst_get('NormalizedSubject');
else
    sSubjectDest = bst_get('Subject', iSubjectDest);
end
OutputFiles = {};
errMsg = [];
isFirstWarning = 1;

% ===== GET DESTINATION SUBJECT =====
% Check for errors
if isempty(sSubjectDest) || isempty(sSubjectDest.Anatomy) || isempty(sSubjectDest.iAnatomy) 
    errMsg = 'Cannot get destination subject.';
    ResultsFiles = [];
end
% Get destination MRI
MriFileDest = sSubjectDest.Anatomy(sSubjectDest.iAnatomy).FileName;
sMriDest = in_mri_bst(MriFileDest);
if isempty(sMriDest) || ~isfield(sMriDest, 'NCS') || ~isfield(sMriDest.NCS, 'R') || isempty(sMriDest.NCS.R)
    errMsg = 'You should compute the MNI transformation for the destination MRI first.';
    ResultsFiles = [];
end
    

% ===== PROJECT FILES =====
iUpdatedStudies = [];
% Progress bar
bst_progress('start', 'Project sources', 'Projecting files...', 0, length(ResultsFiles));
% Loop on input source files
for iRes = 1:length(ResultsFiles)
    % === GET SOURCE SUBJECT ===
    % Find file in database
    [sStudySrc, iStudySrc, iFile, DataType] = bst_get('AnyFile', ResultsFiles{iRes});
    if isempty(sStudySrc)
        errMsg = ['File is not resgistered in database: ' ResultsFiles{iRes}];
        break;
    end
    % Get corresponding subject
    [sSubjectSrc, iSubjectSrc] = bst_get('Subject', sStudySrc.BrainStormSubject);
    if isempty(sSubjectSrc) || isempty(sSubjectSrc.Anatomy) || isempty(sSubjectSrc.iAnatomy) 
        errMsg = 'Cannot get source subject.';
        break;
    elseif (iSubjectSrc == iSubjectDest)
        errMsg = 'Source and destination anatomies are the same: nothing ot project.';
        break;
    end
    % Get destination MRI
    MriFileSrc = sSubjectSrc.Anatomy(sSubjectSrc.iAnatomy).FileName;
    sMriSrc = in_mri_bst(MriFileSrc);
    if isempty(sMriSrc) || ~isfield(sMriSrc, 'NCS') || ~isfield(sMriSrc.NCS, 'R') || isempty(sMriSrc.NCS.R)
        errMsg = 'You should compute the MNI transformation for the source MRI first.';
        ResultsFiles = [];
        break;
    end

    % === LOAD SOURCE FILE ===
    switch (DataType)
        case 'timefreq'
            % Load file
            ResultsMat = in_bst_timefreq(ResultsFiles{iRes}, 1);
            ResFile = ResultsFiles{iRes};
            % Check the data type: timefreq must be source/surface based, and no kernel-based file
            if ~strcmpi(ResultsMat.DataType, 'results')
                errMsg = 'Only source results can be projected.';
                break;
            end
            % Get source model type
            if isfield(ResultsMat, 'HeadModelType') && ~isempty(ResultsMat.HeadModelType)
                % Nothing to do
            elseif ~isempty(ResultsMat.DataFile)
                % Load related source file
                [AssociateMat,AssociateFile] = in_bst_results(ResultsMat.DataFile, 0, 'HeadModelType', 'HeadModelFile');
                ResultsMat.HeadModelType = AssociateMat.HeadModelType;
                ResultsMat.HeadModelFile = AssociateMat.HeadModelFile;
            else
                % By default: volume
                ResultsMat.HeadModelType = 'volume';
            end
            % Remove link to parent file
            ResultsMat.DataFile = [];
            ResultsMat.SurfaceFile = [];
        case {'results', 'link'}
            % Load file
            [ResultsMat, ResFile] = in_bst_results(ResultsFiles{iRes}, 1);
            % If it depends on the data file: try to use the comment of the data file
            if ~isempty(ResultsMat.DataFile) && strcmpi(file_gettype(ResultsMat.DataFile), 'data')
                % Find parent file in database
                [sStudy, iStudy, iData] = bst_get('DataFile', ResultsMat.DataFile);
                % If file was found: use its comment
                if ~isempty(sStudy) && ~isempty(sStudy.Data(iData).Comment)
                    ResultsMat.Comment = sStudy.Data(iData).Comment;
                end
            end
            % Unconstrained sources: Make a flat map
            if (ResultsMat.nComponents ~= 1)
                ResultsMat = process_source_flat('Compute', ResultsMat);
            end
            % Remove link to parent file
            ResultsMat.DataFile = [];
            ResultsMat.ChannelFlag = [];
            ResultsMat.GoodChannel = [];
            ResultsMat.SurfaceFile = [];
            ResultsMat.SourceDecompSa = [];
            ResultsMat.SourceDecompVa = [];
    end

    % Check source model type
    if strcmpi(ResultsMat.HeadModelType, 'surface')
        errMsg = 'To process surface-based source maps, use function bst_project_sources.m instead.';
        break;
    elseif strcmpi(ResultsMat.HeadModelType, 'mixed')
        errMsg = 'Mixed head models are not supported yet.';
        break;
    elseif ~isfield(ResultsMat, 'GridLoc') || isempty(ResultsMat.GridLoc)
        errMsg = ['No field "GridLoc" in the file to project.' 10 'To process surface-based source maps, use function bst_project_sources.m instead.'];
        break;
    end
    % Remove link to parent file
    if isfield(ResultsMat, 'DataFile') && ~isempty(ResultsMat.DataFile)
        ResultsMat.DataFile = [];
    end
    
    % === GET EXISTING GROUP COORDINATES ===
    GridLoc = [];
    SurfaceFile = [];
    isDestGroup = strcmpi(sSubjectDest.Name, bst_get('NormalizedSubjectName'));
    % Load forward model (only when projecting TO group analysis subject)
    if isDestGroup && isfield(ResultsMat, 'HeadModelFile') && ~isempty(ResultsMat.HeadModelFile)
        HeadModelMat = in_bst_headmodel(ResultsMat.HeadModelFile, 0, 'GridOptions');
        % If this file was computed from a template grid 
        if ~isempty(HeadModelMat.GridOptions) && isfield(HeadModelMat.GridOptions, 'Method') && strcmpi(HeadModelMat.GridOptions.Method, 'group') && isfield(HeadModelMat.GridOptions, 'FileName') && ~isempty(HeadModelMat.GridOptions.FileName)
            % Get template source grid
            TemplateFile = HeadModelMat.GridOptions.FileName;
            % If this template file still exists
            if ~isempty(bst_get('HeadModelFile', TemplateFile))
                % Load template source grid
                TemplateMat = in_bst_headmodel(TemplateFile, 0, 'GridLoc', 'SurfaceFile');
                % If the file exists and is not empty
                if ~isempty(TemplateMat) && ~isempty(TemplateMat.GridLoc)
                    GridLoc     = TemplateMat.GridLoc;
                    SurfaceFile = TemplateMat.SurfaceFile;
                end
            else
                disp(['BST> Warning: Template grid file does not exist anymore: ' TemplateFile]);
            end
        end
    end
    
    
    % === CONVERT COORDINATES ===
    % If there is no group grid: project with the MNI transformation
    if isempty(GridLoc)
        % Convert grid coordinates: Source SCS => MNI
        GridLoc = cs_convert(sMriSrc, 'scs', 'mni', ResultsMat.GridLoc);
        if isempty(ResultsMat.GridLoc)
            errMsg = 'Cannot convert grid locations to MNI coordinates.';
            break;
        end
        % Convert grid coordinates: MNI => Destination SCS
        GridLoc = cs_convert(sMriDest, 'mni', 'scs', GridLoc);
        % This is an error only when projecting TO the group analysis subject
        if isDestGroup
            % Display warning
            disp('BST> Warning: This source file was not computed based on a template grid.');
            if isInteractive && isFirstWarning
                isFirstWarning = 0;
                java_dialog('warning', ['Warning: This source file was not computed based on a template grid.' 10 ...
                    'You will not be able to average sources from multiple subjects.' 10 10 ...
                    'In order to get a common grid of points for all the subjects:' 10 ...
                    ' - Right-click on "Group analysis" > Generate source grid' 10 ...
                    ' - For each subject, compute the forward model with option "Use template grid"'], 'Project sources');
            end
        end
    end
    % If the surface is not defined (or not on the correct subject): get the default cortex in destination folder
    if (isempty(SurfaceFile) || ~strcmpi(bst_fileparts(SurfaceFile), bst_fileparts(sSubjectDest.FileName))) && ~isempty(sSubjectDest.Surface) && ~isempty(sSubjectDest.iCortex)
        SurfaceFile = sSubjectDest.Surface(sSubjectDest.iCortex).FileName;
    end
    % Update grid in the file structure
    ResultsMat.GridLoc     = GridLoc;
    ResultsMat.SurfaceFile = SurfaceFile;

    % === OUTPUT STUDY ===
    % New condition name
    NewCondition = strrep(sStudySrc.Condition{1}, '@raw', '');
    % Get condition
    [sStudyDest, iStudyDest] = bst_get('StudyWithCondition', [sSubjectDest.Name '/' NewCondition]);
    % Create condition if doesnt exist
    if isempty(iStudyDest)
        iStudyDest = db_add_condition(sSubjectDest.Name, NewCondition, 0);
        if isempty(iStudyDest)
            error(['Cannot create condition: "' sSubjectDest.Name  '/' NewCondition '".']);
        end
        sStudyDest = bst_get('Study', iStudyDest);
    end

    % === SAVE NEW RESULTS ===
    % Use source filename as a base
    [fPath, fBase] = bst_fileparts(ResFile);
    % Remove KERNEL tag for saving full source files
    fBase = strrep(fBase, '_KERNEL', '');
    % Build full filename
    newResultsFileFull = bst_fullfile(bst_fileparts(file_fullpath(sStudyDest.FileName)), [fBase, '_', file_standardize(sSubjectSrc.Name), '.mat']);    
    newResultsFileFull = file_unique(newResultsFileFull);
    newResultsFile = file_short(newResultsFileFull);
    % Update comment (add source filename)
    ResultsMat.Comment = [sSubjectSrc.Name '/' ResultsMat.Comment];
    % History: project source
    ResultsMat = bst_history('add', ResultsMat, 'project', ['Project source grid: ' sSubjectSrc.Name ' => ' sSubjectDest.Name]);
    % Save new results file
    bst_save(newResultsFileFull, ResultsMat, 'v6');

    % === ADD FILE IN DATABASE ===
    % Create Results/Timefreq structure for database
    switch (DataType)
        case 'timefreq'
            sNewResults = db_template('Timefreq');
            sNewResults.FileName = newResultsFile;
            sNewResults.Comment  = ResultsMat.Comment;
            sNewResults.DataFile = ResultsMat.DataFile;
            sNewResults.DataType = ResultsMat.DataType;
            % Add new result
            sStudyDest.Timefreq(end + 1) = sNewResults;
        case {'results', 'link'}
            sNewResults = db_template('Results');
            sNewResults.FileName = newResultsFile;
            sNewResults.Comment  = ResultsMat.Comment;
            sNewResults.DataFile = ResultsMat.DataFile;
            sNewResults.isLink   = 0;
            sNewResults.HeadModelType = ResultsMat.HeadModelType;
            % Add new result
            sStudyDest.Result(end + 1) = sNewResults;
    end
    % Update study in database
    bst_set('Study', iStudyDest, sStudyDest);
    iUpdatedStudies = [iUpdatedStudies, iStudyDest];
    % Add to list of returned files
    OutputFiles{end+1} = newResultsFile;
        
    % Increment progress bar
    bst_progress('inc', 1);
end
% Error handling
if ~isempty(errMsg)
    if isInteractive
        bst_error(errMsg, 'Project sources', 0);
        bst_progress('stop');
    else
        bst_report('Error', 'process_project_sources', ResultsFiles, errMsg);
    end
    return;
end


% ===== UDPATE DISPLAY =====
if isInteractive
    bst_progress('stop');
end
if isempty(OutputFiles)
    return;
end
% Update tree display
% panel_protocols('UpdateTree');
% Update node
panel_protocols('UpdateNode', 'Study', unique(iUpdatedStudies));
% Select first output study
panel_protocols('SelectStudyNode', iUpdatedStudies(1));
% Select first output file
panel_protocols('SelectNode', [], OutputFiles{1});
% Save database
db_save();




