function hFig = view_scouts(ResultsFiles, ScoutsArg, hFig)
% VIEW_SCOUTS: Display time series for all the scouts selected in the JList.
%
% USAGE:  view_scouts()                               : Display selected sources file time series for selected scouts
%         view_scouts(ResultsFiles, 'SelectedScouts') : Display input sources file time series for selected scouts
%         view_scouts(ResultsFiles, iScouts)          : Display input sources file time series for input scouts

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
% Authors: Francois Tadel, 2008-2016

global GlobalData;  
%% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(hFig)
    hFig = [];
end
% If no parameters were given 
if (nargin == 0)
    % === GET SURFACES LIST ===
    hFigures = bst_figures('GetFiguresByType', '3DViz');
    % Process all figures : and keep them that have a ResultsFile defined
    ResultsFiles = {};
    for i = 1:length(hFigures)
        resFile = getappdata(hFigures(i), 'ResultsFile');
        if ~isempty(resFile)
            ResultsFiles{end+1} = resFile;
        else
            TfInfo = getappdata(hFigures(i), 'Timefreq');
            if ~isempty(TfInfo) && ~isempty(TfInfo.FileName)
                ResultsFiles{end+1} = TfInfo.FileName;
            end
        end
    end
    ResultsFiles = unique(ResultsFiles);
    ScoutsArg = 'SelectedScouts';
    clear hFigures resFile;
end
if isempty(ResultsFiles)
    % Try displaying scouts from tree selection
    tree_view_scouts();
    return
end

%% ===== GET SCOUTS LIST =====
isVolumeAtlas = 0;
% No scout
if isempty(ScoutsArg)
    return
% Use the scouts selected in the "Scouts" panel
elseif ischar(ScoutsArg) && strcmpi(ScoutsArg, 'SelectedScouts')
    % Get current atlas
    [sAtlas, iAtlas, sSurf] = panel_scout('GetAtlas');
    if isempty(sAtlas)
        return;
    end
    % Cannot display scouts from the "Source model" atlas (different regions)
    if ~isempty(strfind(sAtlas.Name, 'Source model'))
        bst_error('Cannot use the atlas "Source model" to calculate scouts time series.', 'Display scouts', 0);
        return;
    end
    % Volume scout: Get number of vertices of the atlas
    [isVolumeAtlas, nAtlasGrid] = panel_scout('ParseVolumeAtlas', sAtlas.Name);
    % Get selected scouts
    [sScouts, iScouts, sSurf] = panel_scout('GetSelectedScouts');
% Else: use directly the scout indices in argument
else
    iScouts = ScoutsArg;
    [sScouts, sSurf] = panel_scout('GetScouts', iScouts);
end
if isempty(sScouts)
    return
end
clear ScoutsArg;


%% ===== CHECK CORRESPONDANCE SCOUTS/SURFACES =====
iDroppedRes = [];
FileType = {};
% Check each results file
for i = 1:length(ResultsFiles)
    FileType{i} = file_gettype(ResultsFiles{i});
    % Load surface file from sources file
    switch (FileType{i})
        case {'link', 'results', 'presults'}
            ResMat = in_bst_results(ResultsFiles{i}, 0, 'SurfaceFile', 'HeadModelType', 'GridLoc');
            if isVolumeAtlas && (size(ResMat.GridLoc,1) ~= nAtlasGrid)
                disp(['BST> Error: The number of grid points in this atlas (' num2str(nAtlasGrid) ') does not match the loaded source file (' num2str(size(ResMat.GridLoc,1)) ').']);
                iDroppedRes(end+1) = i;
                continue;
            elseif ~isVolumeAtlas && strcmpi(ResMat.HeadModelType, 'volume')
                disp(['BST> Error: Cannot use a surface scout to extract value from a volume grid.']);
                iDroppedRes(end+1) = i;
                continue;
            end
        case {'timefreq', 'ptimefreq'}
            ResMat = in_bst_timefreq(ResultsFiles{i}, 0, 'SurfaceFile', 'HeadModelType', 'DataFile');
            if isempty(ResMat.SurfaceFile) && ~isempty(ResMat.DataFile)
                ResMat = in_bst_results(ResMat.DataFile, 0, 'SurfaceFile', 'HeadModelType');
            else
                ResMat.SurfaceFile   = sSurf.FileName;
                ResMat.HeadModelType = 'surface';
            end
    end
    % If surface is not the same as scouts' one, drop this results file
    if ~isempty(ResMat.SurfaceFile) && ~file_compare(ResMat.SurfaceFile, sSurf.FileName)    % || ismember(ResMat.HeadModelType, {'volume', 'mixed'})
        iDroppedRes = [iDroppedRes, i];
    end
end
if ~isempty(iDroppedRes)
    ResultsFiles(iDroppedRes) = [];
    FileType(iDroppedRes) = [];
end
% Check number of results files
if isempty(ResultsFiles)
    java_dialog('warning', 'No available source files.', 'Display scouts');
    return
end


%% ===== PREPARE DATA TO DISPLAY =====
% Initialize common descriptors (between all files)
SubjectFile    = '*';
StudyFile      = '*';
FigureDataFile = '*';

% Get display options        
ScoutsOptions = panel_scout('GetScoutsOptions');
% if (length(iScouts) == 1)
%     ScoutsOptions.overlayScouts = 0;
% end
if (length(ResultsFiles) == 1)
    ScoutsOptions.overlayConditions = 0;
end
% Initialize data to display
scoutsActivity = cell(length(ResultsFiles), length(iScouts));
scoutsStd      = cell(length(ResultsFiles), length(iScouts));
scoutsLabels   = cell(length(ResultsFiles), length(iScouts));
scoutsColors   = cell(length(ResultsFiles), length(iScouts));
axesLabels     = cell(length(ResultsFiles), length(iScouts));
allComponents  = [];
TimeVector     = [];
issloreta      = 0;
% Process each Results file
for iResFile = 1:length(ResultsFiles)
    % Is stat
    isStat = ismember(FileType{iResFile}, {'presults', 'ptimefreq'});
    isTimefreq = ismember(FileType{iResFile}, {'timefreq', 'ptimefreq'});
    
    % ===== GET/CREATE RESULTS DATASET =====
    bst_progress('start', 'Display scouts time series', ['Loading results file: "' ResultsFiles{iResFile} '"...']);
    % Load results
    if ~isTimefreq
        [iDS, iResult] = bst_memory('LoadResultsFileFull', ResultsFiles{iResFile});
        if ~isempty(strfind(lower(ResultsFiles{iResFile}), 'sloreta')) || ~isempty(strfind(lower(GlobalData.DataSet(iDS).Results(iResult).Comment), 'sloreta'))
            issloreta = 1;
        end
    else
        %[iDS, iTimefreq, iResult] = bst_memory('LoadTimefreqFile', ResultsFiles{iResFile}, 1, 1);
        [iDS, iTimefreq, iResult] = bst_memory('LoadTimefreqFile', ResultsFiles{iResFile}, 1, 0);
    end
    % If no DataSet is accessible : error
    if isempty(iDS)
        disp(['BST> Cannot load file : "', ResultsFiles{iResFile}, '"']);
        bst_progress('stop');
        return;
    end

    % Get results subjectName/condition/#solInverse (FOR TITLE ONLY)
    [sStudy,   iStudy]   = bst_get('Study',   GlobalData.DataSet(iDS).StudyFile);
    [sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
    isInterSubject = (iStudy == -2);
    % Get identification of figure
    if ~isempty(SubjectFile)
        if (SubjectFile(1) == '*')
            SubjectFile = sStudy.BrainStormSubject;
        elseif ~file_compare(SubjectFile, sStudy.BrainStormSubject)
            SubjectFile = [];
        end
    end
    if ~isempty(StudyFile)
        if (StudyFile(1) == '*')
            StudyFile = GlobalData.DataSet(iDS).StudyFile;
        elseif ~file_compare(StudyFile, GlobalData.DataSet(iDS).StudyFile)
            StudyFile = [];
        end
    end
    if ~isempty(FigureDataFile)
        if (FigureDataFile(1) == '*')
            FigureDataFile = GlobalData.DataSet(iDS).DataFile;
        elseif ~file_compare(FigureDataFile, GlobalData.DataSet(iDS).DataFile)
            FigureDataFile = [];
        end
    end
    % If DataFile is not defined for this dataset
    if isempty(FigureDataFile)
        % Get DataFile associated to results file in brainstorm database
        [sDbStudy, iDbStudy, iDbRes] = bst_get('ResultsFile', ResultsFiles{iResFile});
        if ~isempty(iDbRes)
            if isStat
                DataFile = sStudy.Stat(iDbRes).DataFile;
            else
                DataFile = sStudy.Result(iDbRes).DataFile;
            end
        else
            DataFile = '';
        end
    else
        DataFile = FigureDataFile;
    end
    % If no study loaded: ignore file
    if isempty(sStudy)
        error(['No study registered for file: ' strrep(ResultsFiles{iResFile},'\\','\')]);
    end
   
    % ===== Prepare cell array containing time series to display =====
    TfFunction = [];
    for k = 1:length(sScouts)
        % ===== Get data to display =====
        % Get list of useful vertices in ImageGridAmp
        if ~isempty(iResult) && ~isempty(GlobalData.DataSet(iDS).Results(iResult).Atlas)
            % Atlas-based source file: use only the seed of the scout, and find it in the file atlas
            iVertices = panel_scout('GetScoutForVertex', GlobalData.DataSet(iDS).Results(iResult).Atlas, sScouts(k).Seed);
            % Error management
            if isempty(iVertices)
                disp('BST> Error: No data to display.');
                bst_progress('stop');
                return;
            end
        else
            % SORT and select unique vertices
            iVertices = sort(unique(sScouts(k).Vertices));
        end
        % Fix errors in color definition
        if isequal(size(sScouts(k).Color), [3,1])
            sScouts(k).Color = sScouts(k).Color';
        end
        % Get data (over current time window)
        if ~isTimefreq
            [DataToPlot, nComponents, DataStd] = bst_memory('GetResultsValues', iDS, iResult, iVertices, 'UserTimeWindow', 0, isVolumeAtlas);
        else
            iFreqs = GlobalData.UserFrequencies.iCurrentFreq;
            [DataToPlot, iTimeBands, iRow, nComponents] = bst_memory('GetTimefreqValues', iDS, iTimefreq, iVertices, iFreqs, 'UserTimeWindow', []);
            DataStd = [];
            % If the values are complex: try to get the measure from the Display tab
            if ~all(isreal(DataToPlot(:)))
                % If time-frequency function not found yet
                if isempty(TfFunction)
                    % Get current panel options
                    sOptions = panel_display('GetDisplayOptions');
                    TfFunction = sOptions.Function;
                    % Display warning
                    disp(['BST> Warning: We don''t know how to convert these complex values to real values. Trying function "' TfFunction '".']);
                end
                % Apply function
                [DataToPlot, isError] = process_tf_measure('Compute', DataToPlot, 'none', TfFunction);
                if isError
                    bst_error(['Invalid measure conversion: none => ' TfFunction], 'Display scouts', 0);
                    return;
                end
            end
        end
        
        % Get the time vector
        if isTimefreq && ~isempty(iTimeBands)
            TimeBands = process_tf_bands('GetBounds', GlobalData.DataSet(iDS).Timefreq(iTimefreq).TimeBands(iTimeBands,:));
            TimeVectorTmp = mean(TimeBands,2)';
        else
            [TimeVectorTmp, iTime] = bst_memory('GetTimeVector', iDS, [], 'UserTimeWindow');
            TimeVectorTmp = TimeVectorTmp(iTime);
        end
        if ~isempty(TimeVector) && (length(TimeVectorTmp) ~= length(TimeVector))
            bst_error('The time definition between the different files do not match.', 'Display scouts', 0);
            return;
        elseif isempty(TimeVector)
            TimeVector = TimeVectorTmp;
        end

        % Compute the scout values
        if ~isStat || strcmpi(sScouts(k).Function, 'All')
            ScoutFunction = sScouts(k).Function;
        else
            ScoutFunction = 'stat';
        end
        
        % Mixed headmodel results
        if (nComponents == 0)
            % Get atlas "Source model"
            GridAtlas = GlobalData.DataSet(iDS).Results(iResult).GridAtlas;
            % Get the vertex indices of the scout in GridLoc
            [iRows, iRegionScouts, iVertices] = bst_convert_indices(iVertices, nComponents, GridAtlas, ~isVolumeAtlas);
            % Do not accept scouts that span over multiple regions
            if isempty(iRegionScouts)
                bst_error(['Scout "' sScouts(k).Label '" is not included in the source model.' 10 'If you use this region as a volume, create a volume scout instead (menu Atlas > New atlas > Volume scouts).'], 'Display scouts', 0);
                return;
            elseif (length(iRegionScouts) > 1)
                bst_error(['Scout "' sScouts(k).Label '" spans over multiple regions of the "Source model" atlas.'], 'Display scouts', 0);
                return;
            end
            % Do not accept volume atlases with non-volume head models
            if ~isVolumeAtlas && strcmpi(GridAtlas.Scouts(iRegionScouts).Region(2), 'V')
                bst_error(['Scout "' sScouts(k).Label '" is a surface scout but region "' GridAtlas.Scouts(iRegionScouts).Label '" is a volume region.'], 'Display scouts', 0);
                return;
            elseif isVolumeAtlas && strcmpi(GridAtlas.Scouts(iRegionScouts).Region(2), 'S')
                bst_error(['Scout "' sScouts(k).Label '" is a volume scout but region "' GridAtlas.Scouts(iRegionScouts).Label '" is a surface region.'], 'Display scouts', 0);
                return;
            end
            % Set the scout computation properties based on the information in the "Source model" atlas
            if strcmpi(GridAtlas.Scouts(iRegionScouts).Region(3), 'C')
                nComponents = 1;
                VertNormals = GlobalData.DataSet(iDS).Results(iResult).GridOrient(iVertices,:);
            else
                nComponents = 3;
                VertNormals = [];
            end
        % Volume scouts
        elseif (nComponents == 3)
            VertNormals = [];
        else
            % Get vertex normals
            VertNormals = sSurf.VertNormals(iVertices,:);
        end
        % Keep track of how many components are available
        allComponents(end+1) = nComponents;
        
        % Only one component
        if (nComponents == 1)
            isFlipSign = ~isStat && ~isTimefreq && ...
                         strcmpi(GlobalData.DataSet(iDS).Results(iResult).DataType, 'results') && ...
                         isempty(strfind(ResultsFiles{iResFile}, '_abs_')) && ...
                         isempty(strfind(ResultsFiles{iResFile}, '_norm_'));
            iTrace = k;
            scoutsActivity{iResFile,iTrace} = bst_scout_value(DataToPlot, ScoutFunction, VertNormals, nComponents, 'none', isFlipSign);
            if ~isempty(DataStd)
                scoutsStd{iResFile,iTrace} = bst_scout_value(DataStd, ScoutFunction, VertNormals, nComponents, 'none', 0);
            else
                scoutsStd{iResFile,iTrace} = [];
            end
            if ScoutsOptions.displayAbsolute
                scoutsActivity{iResFile,iTrace} = abs(scoutsActivity{iResFile,iTrace});
            end
        % More than one component & Absolute: Display the norm
        elseif ScoutsOptions.displayAbsolute
            iTrace = k;
            scoutsActivity{iResFile,iTrace} = bst_scout_value(DataToPlot, ScoutFunction, VertNormals, nComponents, 'norm');
            if ~isempty(DataStd)
                scoutsStd{iResFile,iTrace} = bst_scout_value(DataStd, ScoutFunction, VertNormals, nComponents, 'norm');
            else
                scoutsStd{iResFile,iTrace} = [];
            end
        % More than one component & Relative: Display the three components
        else
            iTrace = nComponents * (k-1) + (1:nComponents);
            tmp = bst_scout_value(DataToPlot, ScoutFunction, VertNormals, nComponents, 'none');
            for iComp = 1:nComponents
                scoutsActivity{iResFile,iTrace(iComp)} = tmp(iComp:nComponents:end,:);
            end
            % Std
            if ~isempty(DataStd)
                tmp = bst_scout_value(DataStd, ScoutFunction, VertNormals, nComponents, 'none');
                for iComp = 1:nComponents
                    scoutsStd{iResFile,iTrace(iComp)} = tmp(iComp:nComponents:end,:);
                end
            else
                scoutsStd(iResFile,iTrace) = repmat({[]}, 1, nComponents);
            end
        end
            
        % === AXES LABELS ===
        % === SUBJECT NAME ===
        % Format: SubjectName/CondName/(DataComment)/(Sol#iResult)/(ScoutName)
        strAxes = '';
        if ~isempty(sSubject) && (iSubject > 0)
            strAxes = sSubject.Name;
        end
        % === CONDITION ===
        % If inter-subject node
        if isInterSubject
            strAxes = [strAxes, 'Inter'];
        % Else: display conditions name
        else
            for i = 1:length(sStudy.Condition)
                strAxes = [strAxes, '/', sStudy.Condition{i}];
            end
        end
        % === DATA COMMENT ===
        % If more than one data file in this study : display current data comments
        if ~isempty(DataFile) && ((length(sStudy.Data) > 1) || isInterSubject)
            % Find DataFile in current study
            iData = find(file_compare({sStudy.Data.FileName}, DataFile));
            % Add Data comment
            if ~isempty(iData)
                strAxes = [strAxes, '/', sStudy.Data(iData).Comment];
            end
        end
        % === RESULTS COMMENT ===
        % If more than one results file in study : display indice
        if ~isempty(DataFile) && isStat && (length(sStudy.Stat) > 1)   % Stat
            % Get list of results files for current data file
            [tmp__, tmp__, iStatInStudy] = bst_get('StatForDataFile', DataFile, iStudy);
            % More than one results file for this data file
            if (length(iStatInStudy) > 1)
                strAxes = [strAxes, '/', GlobalData.DataSet(iDS).Results(iResult).Comment];
            end
        elseif ~isempty(DataFile) && isTimefreq && (length(sStudy.Timefreq) > 1)    % Time-frequency
            % Get list of results files for current data file
            [tmp__, tmp__, iTfInStudy] = bst_get('TimefreqForFile', DataFile, iStudy);
            % More than one results file for this data file
            if (length(iTfInStudy) > 1)
                strAxes = [strAxes, '/', GlobalData.DataSet(iDS).Timefreq(iTimefreq).Comment];
            end
        elseif ~isempty(DataFile) && ~isTimefreq && (length(sStudy.Result) > 1)    % Source maps
            % Get list of results files for current data file
            [tmp__, tmp__, iResInStudy] = bst_get('ResultsForDataFile', DataFile, iStudy);
            % More than one results file for this data file
            if (length(iResInStudy) > 1)
                strAxes = [strAxes, '/', GlobalData.DataSet(iDS).Results(iResult).Comment];
            end
        % Inter-subject: always display whole
        elseif (isempty(DataFile) || isInterSubject)
           strAxes = [strAxes, '/', GlobalData.DataSet(iDS).Results(iResult).Comment];
        end
        [axesLabels{iResFile,iTrace}] = deal(strAxes);

        % === SCOUTS LABELS/COLORS ===
        if (length(iTrace) == 1)
            scoutsLabels{iResFile,iTrace} = sScouts(k).Label;
            [scoutsColors{iResFile,iTrace}] = deal(sScouts(k).Color);
        else
            for iComp = 1:length(iTrace)
                scoutsLabels{iResFile,iTrace(iComp)} = sprintf('%s%d', sScouts(k).Label, iComp);
                scoutsColors{iResFile,iTrace(iComp)} = sScouts(k).Color .* (1 - .25 * (iComp-1));
            end
        end
    end
end


% ===== DISPLAY STATIC VALUES =====
% Get the number of time samples for all the scouts
nbTimes = cellfun(@(c)size(c,2), scoutsActivity(:));
% If both real scouts and static values
if ((max(nbTimes) > 2) && any(nbTimes == 2))
    iCellToExtend = find(nbTimes == 2);
    for i = 1:length(iCellToExtend)
        scoutsActivity{iCellToExtend(i)} = repmat(scoutsActivity{iCellToExtend(i)}(:,1), [1,max(nbTimes)]);
        if ~isempty(scoutsStd)
            scoutsStd{iCellToExtend(i)} = repmat(scoutsStd{iCellToExtend(i)}(:,1), [1,max(nbTimes)]);
        end
    end
end


%% ===== LEGENDS =====
% Get common beginning part in all the axesLabels
[ strAxesCommon, axesLabels ] = str_common_path( axesLabels );
% Only one time series: no overlay scout
if (size(scoutsActivity,2) == 1)
    ScoutsOptions.overlayScouts = 0;
end
% Cannot mix number of components
isMixedComponents = ~ScoutsOptions.displayAbsolute && (length(allComponents) > 1) && any(allComponents ~= allComponents(1));
if isMixedComponents
    bst_error(['Cannot display scouts with mixed numbers of components at the same time ' 10 'when the option "Values: Relative" is selected.'], 'Display scouts', 0);
    return;
end
% If at least one of the scouts functions is "All", ignore the overlay checkboxes
if ~isempty(sScouts) && any(strcmpi({sScouts.Function}, 'All'))
    ScoutsOptions.overlayScouts     = 0;
    ScoutsOptions.overlayConditions = 0;
end


% === NO OVERLAY ===
% Display all timeseries (ResultsFiles/Scouts) in different axes on the same figure
if (~ScoutsOptions.overlayScouts && ~ScoutsOptions.overlayConditions)
    % One graph for each line => Ngraph, Nscouts*Ncond
    % Scouts activity = cell-array {1, Ngraph} of doubles [1,Nt]
    scoutsActivity = scoutsActivity(:)';
    % Axes labels (subj/cond) = cell-array of strings {1, Ngraph}
    axesLabels = axesLabels(:)';
    % Scouts labels = cell-array of strings {1, Ngraph}
    scoutsLabels = scoutsLabels(:)';
    scoutsColors = scoutsColors(:)';
    % Eliminate empty entries
    iEmpty = find(cellfun(@isempty, scoutsActivity));
    if ~isempty(iEmpty)
        scoutsActivity(iEmpty) = [];
        scoutsLabels(iEmpty) = [];
        axesLabels(iEmpty) = [];
        if ~isempty(scoutsColors)
            scoutsColors(iEmpty) = [];
        end
    end
    % Std
    if ~isempty(scoutsStd)
        scoutsStd = scoutsStd(:)';
        if ~isempty(iEmpty)
            scoutsStd(iEmpty) = [];
        end
    end
    
% === OVERLAY SCOUTS AND CONDITIONS ===
% Only one graph with Nlines = Nscouts*Ncond
elseif (ScoutsOptions.overlayScouts && ScoutsOptions.overlayConditions)
    % Linearize entries
    scoutsActivity = scoutsActivity(:);
    scoutsLabels = scoutsLabels(:);
    axesLabels = axesLabels(:);
    % Eliminate empty entries
    iEmpty = find(cellfun(@isempty, scoutsActivity));
    if ~isempty(iEmpty)
        scoutsActivity(iEmpty) = [];
        scoutsLabels(iEmpty) = [];
        axesLabels(iEmpty) = [];
    end
    % Scouts activity = double [Nlines, Nt] 
    scoutsActivity = cat(1, scoutsActivity{:});
    % Scouts labels = cell-array {Nlines}
    % => "scoutName @ subject/condition"
    for iTrace = 1:size(scoutsActivity,1)
        if ~isempty(axesLabels{iTrace})
            scoutsLabels{iTrace} = [scoutsLabels{iTrace} ' @ ' axesLabels{iTrace}];
        end
    end
    scoutsColors = [];
    % Only one graph => legend is common scouts parts
    if ~isempty(strAxesCommon)
        axesLabels = {strAxesCommon};
    else
        axesLabels = {'Mixed subjects'};
    end
    % Std
    if ~isempty(scoutsStd)
        scoutsStd = scoutsStd(:);
        if ~isempty(iEmpty)
            scoutsStd(iEmpty) = [];
        end
        scoutsStd = cat(1, scoutsStd{:});
    end
    
% === OVERLAY SCOUTS ONLY ===
elseif ScoutsOptions.overlayScouts
    % One graph per condition => Ngraph = Ncond
    % Scouts activity = cell-array {1, Ncond} of doubles [Nscout, Nt]
    for i = 1:size(scoutsActivity,1)
        scoutsActivityTmp(i) = {cat(1, scoutsActivity{i,:})};
    end
    scoutsActivity = scoutsActivityTmp;
    % Axes labels (subj/cond) = cell-array of strings {1, Ncond} 
    axesLabels   = axesLabels(:,1)';
    % Scouts labels = cell-array of strings {Nscout, Ncond} 
    scoutsLabels = scoutsLabels';
    scoutsColors = scoutsColors';
    % Std
    if ~isempty(scoutsStd)
        for i = 1:size(scoutsStd,1)
            scoutsStdTmp(i) = {cat(1, scoutsStd{i,:})};
        end
        scoutsStd = scoutsStdTmp;
    end
    
% === OVERLAY CONDITIONS ONLY ===
elseif ScoutsOptions.overlayConditions
    % One graph per scout => Ngraph = Nscout
    % Scouts activity = cell-array {1, Nscout} of doubles [Ncond, Nt]
    for j = 1:size(scoutsActivity,2)
        scoutsActivityTmp(j) = {cat(1, scoutsActivity{:,j})};
    end
    scoutsActivity = scoutsActivityTmp;
    % Axes labels (scout names @ common_subject/cond part) = cell-array of strings {1, Nscout} 
    tmpAxesLabels = axesLabels;
    axesLabels = scoutsLabels(1,:);
    % Lines labels (subject/condition) = cell-array of strings {Ncond, Nscout}  
    scoutsLabels = tmpAxesLabels;
    scoutsColors = [];
    % Std
    if ~isempty(scoutsStd)
        for j = 1:size(scoutsStd,2)
            scoutsStdTmp(j) = {cat(1, scoutsStd{:,j})};
        end
        scoutsStd = scoutsStdTmp;
    end
end
% Close progress bar
bst_progress('stop');


%% ===== CALL DISPLAY FUNCTION ====
% Get type of the first file
switch (file_gettype(ResultsFiles{1}))
    case {'results', 'link'}
        if issloreta
            Modality = 'sloreta';
        else
            Modality = 'results';
        end
    case 'timefreq'
        Modality = 'timefreq';
    case 'presults'
        Modality = 'stat';
    otherwise
        Modality = 'none';
end
% Plot time series
hFig = view_timeseries_matrix(ResultsFiles, scoutsActivity, TimeVector, Modality, axesLabels, scoutsLabels, scoutsColors, hFig, scoutsStd);
% Associate the file with one specific result file 
setappdata(hFig, 'ResultsFiles', ResultsFiles);
if (length(ResultsFiles) == 1)
    setappdata(hFig, 'ResultsFile', ResultsFiles);
else
    setappdata(hFig, 'ResultsFile', []);
end
% Update figure name
bst_figures('UpdateFigureName', hFig);
% Set the time label visible
figure_timeseries('SetTimeVisible', hFig, 1);

    
end


 
 
