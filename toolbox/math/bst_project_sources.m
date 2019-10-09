function OutputFiles = bst_project_sources( ResultsFile, destSurfFile, isAbsoluteValues, isInteractive )
% BST_PROJECT_SOURCES: Project source files on a different surface (currents or timefreq).
%
% USAGE:  OutputFiles = bst_project_sources( ResultsFile, DestSurfFile, isAbsoluteValues=0, isInteractive=1 )
% 
% INPUT:
%    - ResultsFile      : Relative path to sources file to reproject
%    - destSurfFile     : Relative path to destination surface file
%    - isAbsoluteValues : If 1, interpolate absolute values of the sources instead of relative values
%    - isInteractive    : If 1, displays questions and dialog boxes
%                         If 0, consider that it is running from the process interface

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
% Authors: Francois Tadel, 2010-2016

%% ===== PARSE INPUTS ======
if (nargin < 4) || isempty(isInteractive)
    isInteractive = 1;
end
if (nargin < 3) || isempty(isAbsoluteValues)
    isAbsoluteValues = 0;
end

%% ===== GROUP BY SURFACES =====
% Group the results files to process by the surface on which they were computed
% Objective: Computing only once the transformation for all the files in the same group
ResultsGroups = {};
SurfaceGroups = {};
nGroup = 0;
OutputFiles = {};
errMsg = [];
HeadModelType = [];
% Display progress bar
if isInteractive
    bst_progress('start', 'Project sources', 'Initialization...');
end
% Get file type: results or timefreq
isTimefreq = strcmpi(file_gettype(ResultsFile{1}), 'timefreq');
% For each sources file: get surface
for iRes = 1:length(ResultsFile)
    % Read surface file
    if isTimefreq
        ResMat = in_bst_timefreq(ResultsFile{iRes}, 0, 'SurfaceFile', 'DataType', 'DataFile', 'HeadModelType');
        % Check the data type: timefreq must be source/surface based, and no kernel-based file
        if ~strcmpi(ResMat.DataType, 'results')
            errMsg = 'Only cortical maps can be projected.';
            bst_report('Error', 'process_project_sources', ResultsFile{iRes}, errMsg);
            continue;
        elseif ~isempty(strfind(ResultsFile{iRes}, '_KERNEL_'))
            errMsg = 'Cannot re-project kernel-based time-frequency cortical maps.';
            bst_report('Error', 'process_project_sources', ResultsFile{iRes}, errMsg);
            continue;
        elseif isempty(ResMat.SurfaceFile) && ~isempty(ResMat.DataFile)
            ResAssocMat = in_bst_results(ResMat.DataFile, 0, 'SurfaceFile');
            ResMat.SurfaceFile = ResAssocMat.SurfaceFile;
        end
        % Load related source file
        if ~isempty(ResMat.DataFile) && isempty(ResMat.HeadModelType)
            [AssociateMat,AssociateFile] = in_bst_results(ResMat.DataFile, 0, 'HeadModelType');
            ResMat.HeadModelType = AssociateMat.HeadModelType;
        end
    else
        ResMat = in_bst_results(ResultsFile{iRes}, 0, 'SurfaceFile', 'HeadModelType');
    end
    
    % Default HeadModelType: surface
    if ~isfield(ResMat, 'HeadModelType') || isempty(ResMat.HeadModelType)
        ResMat.HeadModelType = 'surface';
    % Else : Check the type of grid (skip volume head models)
    elseif ismember(ResMat.HeadModelType, {'volume'})
        wrnMsg = ['To project source grids, see online tutorial "Group analysis: Subjects corergistration":' 10 ...
                  'https://neuroimage.usc.edu/brainstorm/Tutorials/CoregisterSubjects#Volume_source_models' 10 ...
                  'Skipping file: "' ResultsFile{iRes} '"...'];
        if isInteractive
            disp(wrnMsg);
        else
            bst_report('Error', 'process_project_sources', ResultsFile{iRes}, wrnMsg);
        end
        continue;
    end
    % Check head model type: must be the same for all the files
    if isempty(HeadModelType)
        HeadModelType = ResMat.HeadModelType;
    elseif ~isempty(ResMat.HeadModelType) && ~isequal(HeadModelType, ResMat.HeadModelType)
        errMsg = 'All the source files must be of the type (surface, volume or mixed).';
        bst_report('Error', 'process_project_sources', ResultsFile{iRes}, errMsg);
        continue;
    end
    
    % Associated surface not defined: error
    if isempty(ResMat.SurfaceFile)
        errMsg = 'Associated surface file is not defined.';
        bst_report('Error', 'process_project_sources', ResultsFile{iRes}, errMsg);
        continue;
    end
    % Check that it is not the destination surface
    if file_compare(ResMat.SurfaceFile, destSurfFile)
        if isInteractive
            disp(['BST> WARNING: Source and destination surfaces are the same for file: ' ResultsFile{iRes}]);
        else
            errMsg = 'Source and destination surfaces are the same.';
            bst_report('Error', 'process_project_sources', ResultsFile{iRes}, errMsg);
        end
        continue;
    end
    % Look for surface filename in SurfaceGroups
    iGroup = find(file_compare(ResMat.SurfaceFile, SurfaceGroups));
    % If does not exist yet: create it
    if isempty(iGroup)
        nGroup = nGroup + 1;
        SurfaceGroups{nGroup} = ResMat.SurfaceFile;
        ResultsGroups{nGroup} = ResultsFile(iRes);
    % Group exist: add file to the group
    else
        ResultsGroups{iGroup}{end+1} = ResultsFile{iRes};
    end
end
% If destination surface = source surface for all files
if (nGroup == 0)
    if isempty(errMsg)
        errMsg = ['Source and destination surfaces are the same for all the selected files.' 10 'Nothing to project...'];
    end   
    if isInteractive
        bst_error(errMsg, 'Project sources', 0);
        bst_progress('stop');
    else
        bst_report('Error', 'process_project_sources', ResultsFile, errMsg);
    end
    return;
end
% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');


%% ===== PROJECT SOURCES =====
isStopWarped = [];
iUpdatedStudies = [];
% Process each surface group
for iGroup = 1:nGroup
    % ===== GET INTERPOLATION =====
    srcSurfFile = SurfaceGroups{iGroup};
    if isInteractive
        bst_progress('start', 'Project sources', 'Loading surfaces...');
    end
    % Compute interpolation
    [WmatSurf, sSrcSubj, sDestSubj, srcSurfMat, destSurfMat, isStopWarped] = tess_interp_tess2tess(srcSurfFile, destSurfFile, isInteractive, isStopWarped);
    % Source subject and destination subject are the same
    isSameSubject = file_compare(sSrcSubj.FileName, sDestSubj.FileName);

    % ===== CREATE GROUP ANALYSIS SUBJECT =====
    % If src and dest subjects are not the same: create a "group analysis" subject
    if ~isSameSubject
        % If the destination is the group analysis subject: replace its name
        if strcmpi(sSrcSubj.Name, bst_get('DirDefaultSubject'))
            sSrcSubj.Name = bst_get('NormalizedSubjectName');
        end
        % If the destination is the group analysis subject: replace its name
        if strcmpi(sDestSubj.Name, bst_get('DirDefaultSubject'))
            sDestSubj = bst_get('NormalizedSubject');
            sDestSubj.Name = bst_get('NormalizedSubjectName');
        end
    end
    
    % ===== PROCESS EACH FILE =====
    nFile = length(ResultsGroups{iGroup});
    if isInteractive
        bst_progress('start', 'Project sources', 'Projecting sources...', 0, nFile);
    end
    % Process each results file in group
    for iFile = 1:nFile
        % Progress bar
        ResultsFile = ResultsGroups{iGroup}{iFile};
        if isInteractive
            bst_progress('inc', 1);
        end
        bst_progress('text', sprintf('Processing file #%d/%d: %s', iFile, nFile, ResultsFile));
        
        % ===== OUTPUT STUDY =====
        % Get source study
        [sSrcStudy, iSrcStudy] = bst_get('AnyFile', ResultsFile);
        % If result has to be save in "group analysis" subject
        if ~isSameSubject
            % New condition name
            NewCondition = strrep(sSrcStudy.Condition{1}, '@raw', '');
            % Get condition
            [sDestStudy, iDestStudy] = bst_get('StudyWithCondition', [sDestSubj.Name '/' NewCondition]);
            % Create condition if doesnt exist
            if isempty(iDestStudy)
                iDestStudy = db_add_condition(sDestSubj.Name, NewCondition, 0);
                if isempty(iDestStudy)
                    error(['Cannot create condition: "' normSubjName '/' NewCondition '".']);
                end
                sDestStudy = bst_get('Study', iDestStudy);
            end
        % Else: use the source study as output study
        else
            sDestStudy = sSrcStudy;
            iDestStudy = iSrcStudy;
        end

        % ===== LOAD INPUT FILE =====
        % Time-freq files
        if isTimefreq
            % Load file
            ResultsMat = in_bst_timefreq(ResultsFile, 0);
            ResFile = ResultsFile;
            % Change number of sources
            ResultsMat.RowNames = 1:size(ResultsMat.TF,1);
        % Source files: Read full
        else
            % Load file
            [ResultsMat,ResFile] = in_bst_results(ResultsFile, 1);
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
            % Compute absolute values
            elseif isAbsoluteValues
                ResultsMat.ImageGridAmp = abs(ResultsMat.ImageGridAmp);               
            end

            ResultsMat.ChannelFlag = [];
            ResultsMat.GoodChannel = [];
        end
        % Remove link with original file
        ResultsMat.DataFile = [];
        % Check if the file was reprojected on an atlas
        if isfield(ResultsMat, 'Atlas') && ~isempty(ResultsMat.Atlas)
            wrnMsg = ['Cannot process atlas-based source files: Skipping file "' ResultsFile '"...'];
            if isInteractive
                disp(wrnMsg);
            else
                bst_report('Error', 'process_project_sources', ResultsFile, wrnMsg);
            end
            continue;
        end

        % ===== INTERPOLATION MATRIX =====
        % Surface source model: Simply use the surface-surface interpolation
        if strcmpi(HeadModelType, 'surface')
            Wmat = WmatSurf;
        % Mixed source models: Compute volume grid interpolations
        elseif strcmpi(HeadModelType, 'mixed')
            % Load MRI files
            sMriSrc  = in_mri_bst(sSrcSubj.Anatomy(sSrcSubj.iAnatomy).FileName);
            sMriDest = in_mri_bst(sDestSubj.Anatomy(sDestSubj.iAnatomy).FileName);
            % Compute interpolation
            [Wmat, destGridAtlas, destGridLoc, destGridOrient] = tess_interp_mixed(ResultsMat, WmatSurf, srcSurfMat, destSurfMat, sMriSrc, sMriDest, isInteractive);
            % Update output structure
            ResultsMat.GridAtlas  = destGridAtlas;
            ResultsMat.GridLoc    = destGridLoc;
            ResultsMat.GridOrient = destGridOrient;
%             % Check if there is a "Source model" atlas available
%             iModelSrc  = find(strcmpi({srcSurfMat.Atlas.Name}, 'Source model'));
%             iModelDest = find(strcmpi({destSurfMat.Atlas.Name}, 'Source model'));
%             if isempty(iModelDest) && ~isempty(iModelSrc)
%                 destSurfMat.Atlas(end+1) = srcSurfMat.Atlas(iModelSrc);
%             end
        else
            error(['Unsupported head model type: ' HeadModelType]);
        end
        
        % ===== PROJECT SOURCE MAPS =====
        % Time-freq file
        if isTimefreq
            % Apply interpolation matrix
            tmpTF = zeros(size(Wmat,1), size(ResultsMat.TF,2), size(ResultsMat.TF,3));
            for iFreq = 1:size(ResultsMat.TF,3)
                tmpTF(:,:,iFreq) = Wmat * ResultsMat.TF(:,:,iFreq);
            end
            ResultsMat.TF = tmpTF;
            % PAC: Apply interpolation to all measures
            if isfield(ResultsMat, 'sPAC') && ~isempty(ResultsMat.sPAC)
                if isfield(ResultsMat.sPAC, 'NestingFreq') && ~isempty(ResultsMat.sPAC.NestingFreq)
                    ResultsMat.sPAC.NestingFreq = Wmat * ResultsMat.sPAC.NestingFreq;
                end
                if isfield(ResultsMat.sPAC, 'NestedFreq') && ~isempty(ResultsMat.sPAC.NestedFreq)
                    ResultsMat.sPAC.NestedFreq = Wmat * ResultsMat.sPAC.NestedFreq;
                end
                if isfield(ResultsMat.sPAC, 'DirectPAC') && ~isempty(ResultsMat.sPAC.DirectPAC)
                    tmpTF = zeros(size(Wmat,1), size(ResultsMat.sPAC.DirectPAC,2), size(ResultsMat.sPAC.DirectPAC,3), size(ResultsMat.sPAC.DirectPAC,4));
                    for iLow = 1:size(ResultsMat.sPAC.DirectPAC,3)
                        for iHigh = 1:size(ResultsMat.sPAC.DirectPAC,4)
                            tmpTF(:,:,iLow,iHigh) = Wmat * ResultsMat.sPAC.DirectPAC(:,:,iLow,iHigh);
                        end
                    end
                    ResultsMat.sPAC.DirectPAC = tmpTF;
                end
            end
            ResultsMat.HeadModelType = HeadModelType;
            if ~isempty(ResultsMat.GridLoc) && (length(ResultsMat.RowNames) ~= size(ResultsMat.GridLoc,1))
                ResultsMat.RowNames = 1:size(ResultsMat.GridLoc,1);
            elseif isequal(ResultsMat.DataType, 'results') && isnumeric(ResultsMat.RowNames) && (length(ResultsMat.RowNames) ~= size(ResultsMat.TF,1))
                ResultsMat.RowNames = 1:size(ResultsMat.TF,1);
            end
        % Source file
        else
            % Apply interpolation matrix
            ResultsMat.ImageGridAmp = muliplyInterp(Wmat, double(ResultsMat.ImageGridAmp), ResultsMat.nComponents);
            
            % Apply interpolation to standart deviation matrix
            if isfield(ResultsMat, 'Std') && ~isempty(ResultsMat.Std)
                ResultsMat.Std = muliplyInterp(Wmat, double(ResultsMat.Std), ResultsMat.nComponents);
            end
            ResultsMat.ImagingKernel = [];
        end
        
        % === SAVE NEW RESULTS ===
        % Get source filename
        [tmp__, oldBaseName] = bst_fileparts(ResFile);
        % Remove KERNEL tag for saving full source files
        if ~isempty(strfind(oldBaseName, '_KERNEL_')) && isfield(ResultsMat, 'ImageGridAmp') && ~isempty(ResultsMat.ImageGridAmp)
            oldBaseName = strrep(oldBaseName, '_KERNEL', '');
        end
        % Prepare structure to be saved
        ResultsMat.SurfaceFile = destSurfFile;
        if ~isSameSubject
            ResultsMat.Comment = [sSrcSubj.Name '/' ResultsMat.Comment];
            newResultsFile = sprintf('%s_%s.mat', oldBaseName, file_standardize(sSrcSubj.Name));
        else
            ResultsMat.Comment = [ResultsMat.Comment ' | ' destSurfMat.Comment];
            newResultsFile = sprintf('%s_%dV.mat', oldBaseName, length(destSurfMat.Vertices));
        end
        % Surface file
        ResultsMat.SurfaceFile = file_win2unix(destSurfFile);
        % History: project source
        ResultsMat = bst_history('add', ResultsMat, 'project', ['Project sources: ' srcSurfFile ' => ' ResultsMat.SurfaceFile]);
        % Build full filename
        newResultsFileFull = bst_fullfile(ProtocolInfo.STUDIES, bst_fileparts(sDestStudy.FileName), newResultsFile);    
        newResultsFileFull = file_unique(newResultsFileFull);
        newResultsFile = file_short(newResultsFileFull);
        % Save new results file
        bst_save(newResultsFileFull, ResultsMat, 'v6');

        % === ADD FILE IN DATABASE ===
        % Create Results/Timefreq structure for database
        if isTimefreq
            sNewResults = db_template('Timefreq');
            sNewResults.FileName = newResultsFile;
            sNewResults.Comment  = ResultsMat.Comment;
            sNewResults.DataFile = ResultsMat.DataFile;
            sNewResults.DataType = ResultsMat.DataType;
            % If filename already exists in this study
            iExistingRes = find(file_compare({sDestStudy.Timefreq.FileName}, newResultsFile));
            if ~isempty(iExistingRes)
                % Replace previous Results
                sDestStudy.Timefreq(iExistingRes) = sNewResults;
            else
                % Add new result
                sDestStudy.Timefreq(end + 1) = sNewResults;
            end
        else
            sNewResults = db_template('Results');
            sNewResults.FileName = newResultsFile;
            sNewResults.Comment  = ResultsMat.Comment;
            sNewResults.DataFile = ResultsMat.DataFile;
            sNewResults.isLink   = 0;
            sNewResults.HeadModelType = HeadModelType;
            % If filename already exists in this study
            iExistingRes = find(file_compare({sDestStudy.Result.FileName}, newResultsFile));
            if ~isempty(iExistingRes)
                % Replace previous Results
                sDestStudy.Result(iExistingRes) = sNewResults;
            else
                % Add new result
                sDestStudy.Result(end + 1) = sNewResults;
            end
        end
        % Update study in database
        bst_set('Study', iDestStudy, sDestStudy);
        iUpdatedStudies = [iUpdatedStudies, iDestStudy];
        % Add to list of returned files
        OutputFiles{end+1} = newResultsFile;
    end
end


%% ===== UDPATE DISPLAY =====
if isInteractive
    bst_progress('stop');
end
if isempty(OutputFiles)
    return;
end
% Update node
panel_protocols('UpdateNode', 'Study', unique(iUpdatedStudies));
% Select first output study
panel_protocols('SelectStudyNode', iUpdatedStudies(1));
% Select first output file
panel_protocols('SelectNode', [], OutputFiles{1});
% Save database
db_save();


end



%% ===== APPLY INTERPOLATION MATRIX =====
function B = muliplyInterp(W, A, nComponents)
    switch (nComponents)
        case {0, 1}
            B = double(W * A);
        case 2
            B = zeros(2 * size(W,1), size(A,2));
            B(1:2:end,:) = double(W * A(1:2:end,:));
            B(2:2:end,:) = double(W * A(2:2:end,:));
        case 3
            B = zeros(3 * size(W,1), size(A,2));
            B(1:3:end,:) = double(W * A(1:3:end,:));
            B(2:3:end,:) = double(W * A(2:3:end,:));
            B(3:3:end,:) = double(W * A(3:3:end,:));
    end
    B = double(B);
end




