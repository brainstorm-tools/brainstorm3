function varargout = process_extract_scout( varargin )
% PROCESS_EXTRACT_SCOUT Extract scouts values.
%
% USAGE:  [sScoutsFinal, AllAtlasNames, sSurf] = process_extract_scout('GetScoutsInfo', sProcess, sInputs, SurfaceFile, AtlasList)

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
% Authors: Francois Tadel, 2010-2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Scouts time series';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Extract';
    sProcess.Index       = 352;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Scouts';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results', 'timefreq'};
    sProcess.OutputTypes = {'matrix',  'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === SCOUTS
    sProcess.options.scouts.Comment = '';
    sProcess.options.scouts.Type    = 'scout';
    sProcess.options.scouts.Value   = {};
    % === SCOUT FUNCTION ===
    sProcess.options.scoutfunc.Comment    = {'Mean', 'Max', 'PCA', 'Std', 'All', 'Scout function:'};
    sProcess.options.scoutfunc.Type       = 'radio_line';
    sProcess.options.scoutfunc.Value      = 1;
    % === FLIP SIGN
    sProcess.options.isflip.Comment    = 'Flip the sign of sources with opposite directions';
    sProcess.options.isflip.Type       = 'checkbox';
    sProcess.options.isflip.Value      = 1;
    sProcess.options.isflip.InputTypes = {'results'};
    % === NORM XYZ
    sProcess.options.isnorm.Comment = 'Unconstrained sources: Norm of the three orientations (x,y,z)';
    sProcess.options.isnorm.Type    = 'checkbox';
    sProcess.options.isnorm.Value   = 0;
    sProcess.options.isnorm.InputTypes = {'results'};
    % === CONCATENATE
    sProcess.options.concatenate.Comment = 'Concatenate output in one unique matrix';
    sProcess.options.concatenate.Type    = 'checkbox';
    sProcess.options.concatenate.Value   = 1;
    % === SAVE OUTPUT
    sProcess.options.save.Comment = '';
    sProcess.options.save.Type    = 'ignore';
    sProcess.options.save.Value   = 1;
    % === ADD ROW COMMENT IN THE DESCRIPTION
    sProcess.options.addrowcomment.Comment = '';
    sProcess.options.addrowcomment.Type    = 'ignore';
    sProcess.options.addrowcomment.Value   = 1;
    % === ADD FILE COMMENT IN THE DESCRIPTION
    sProcess.options.addfilecomment.Comment = '';
    sProcess.options.addfilecomment.Type    = 'ignore';
    sProcess.options.addfilecomment.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    % Get type of data
    Comment = [sProcess.Comment, ':'];
    % Get selected scouts
    ScoutsList = sProcess.options.scouts.Value;
    % Get scouts names
    if ~isempty(ScoutsList) && iscell(ScoutsList) && (size(ScoutsList, 2) >= 2) && ~isempty(ScoutsList{1,2}) && iscell(ScoutsList{1,2})
        ScoutsNames = ScoutsList{1,2};
    elseif ~isempty(ScoutsList) && isstruct(ScoutsList)
        ScoutsNames = {ScoutsList.Label};
    else
        ScoutsNames = [];
    end
    % Format comment
    if isempty(ScoutsNames)
        Comment = [Comment, ' [no selection]'];
    else
        if (length(ScoutsNames) > 15)
            Comment = [Comment, ' [', num2str(length(ScoutsNames)), ' scouts]'];
        else
            for i = 1:length(ScoutsNames)
                Comment = [Comment, ' ', ScoutsNames{i}];
            end
        end
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned variable
    OutputFiles = {};
    % Get scouts
    AtlasList = sProcess.options.scouts.Value;
    % Convert from older structure (keep for backward compatibility)
    if isstruct(AtlasList) && ~isempty(AtlasList)
        AtlasList = {'User scouts', {AtlasList.Label}};
    end
    % No scouts selected: exit
    if isempty(AtlasList) || ~iscell(AtlasList) || (size(AtlasList,2) < 2) || isempty(AtlasList{1,2})
        bst_report('Error', sProcess, [], 'No scout selected.');
        return;
    end
    % Override scouts function
    if ~isempty(sProcess.options.scoutfunc.Value)
        switch lower(sProcess.options.scoutfunc.Value)
            case {1, 'mean'}, ScoutFunc = 'mean';
            case {2, 'max'},  ScoutFunc = 'max';
            case {3, 'pca'},  ScoutFunc = 'pca';
            case {4, 'std'},  ScoutFunc = 'std';
            case {5, 'all'},  ScoutFunc = 'all';
            otherwise,  bst_report('Error', sProcess, [], 'Invalid scout function.');  return;
        end
    else
        ScoutFunc = [];
    end
    % Get time window
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    % Output options
    isConcatenate = sProcess.options.concatenate.Value && (length(sInputs) > 1);
    isSave = sProcess.options.save.Value;
    isNorm = isfield(sProcess.options, 'isnorm') && isfield(sProcess.options.isnorm, 'Value') && isequal(sProcess.options.isnorm.Value, 1);
    isFlip = isfield(sProcess.options, 'isflip') && isfield(sProcess.options.isflip, 'Value') && isequal(sProcess.options.isflip.Value, 1);
    AddRowComment  = sProcess.options.addrowcomment.Value;
    AddFileComment = sProcess.options.addfilecomment.Value;
    % If flip is not set: auto-detect and do not trigger errors
    if isempty(isFlip)
        isFlip = 1;
        isFlipWarning = 0;
    else
        isFlipWarning = 1;
    end
    % Unconstrained function
    if isNorm
        XyzFunction = 'norm';
    else
        XyzFunction = 'none';
    end
    
    % ===== LOOP ON THE FILES =====
    for iInput = 1:length(sInputs)
        ScoutOrient = [];
        SurfOrient  = [];
        SurfaceFile = [];
        sResults = [];
        ZScore = [];
        GridAtlas  = [];
        GridLoc    = [];
        GridOrient = [];
        iFileScouts = [];
        nComponents = [];
        % Progress bar
        if (length(sInputs) > 1)
            bst_progress('text', sprintf('Extracting scouts for file: %d/%d...', iInput, length(sInputs)));
        end
        
        % === READ FILES ===
        switch (sInputs(iInput).FileType)
            case 'results'
                % Load results
                sMat = in_bst_results(sInputs(iInput).FileName, 0);
                % Atlas-based files
                if isfield(sMat, 'Atlas') && ~isempty(sMat.Atlas)
                    snames = AtlasList{1,2};
                    % Try to look the requested scouts in the file
                    for i = 1:length(snames)
                        iTmp = find(strcmpi(snames{i}, {sMat.Atlas(1).Scouts.Label}));
                        if ~isempty(iTmp)
                            iFileScouts(end+1) = iTmp;
                        end
                    end
                    % If the scout names cannot be found: error
                    if (length(iFileScouts) ~= length(snames))
                        bst_report('Error', sProcess, sInputs(iInput), 'File is already based on an atlas, but the selected scouts don''t match this atlas.');
                        continue;
                    end
                end
                % Get surface vertex normals
                if ~isempty(sMat.SurfaceFile)
                    SurfaceFile = sMat.SurfaceFile;
                end
                % FULL RESULTS
                if isfield(sMat, 'ImageGridAmp') && ~isempty(sMat.ImageGridAmp)
                    sResults = sMat;
                    matValues = sMat.ImageGridAmp;
                    % Standard deviation
                    if isfield(sMat, 'Std') && ~isempty(sMat.Std)
                        matStd = sMat.Std;
                    else
                        matStd = [];
                    end
                % KERNEL ONLY
                elseif isfield(sMat, 'ImagingKernel') && ~isempty(sMat.ImagingKernel)
                    sResults = sMat;
                    sMat = in_bst(sResults.DataFile, TimeWindow);
                    matValues = [];
                    matStd = [];
                end
                % Get ZScore parameter
                if isfield(sResults, 'ZScore') && ~isempty(sResults.ZScore)
                    ZScore = sResults.ZScore;
                end
                % Get GridAtlas/GridLoc/GridOrient parameter
                if isfield(sResults, 'GridAtlas') && ~isempty(sResults.GridAtlas)
                    GridAtlas = sResults.GridAtlas;
                end
                if isfield(sResults, 'GridLoc') && ~isempty(sResults.GridLoc)
                    GridLoc = sResults.GridLoc;
                end
                if isfield(sResults, 'GridOrient') && ~isempty(sResults.GridOrient)
                    GridOrient = sResults.GridOrient;
                end
                % Input filename
                if isequal(sInputs(iInput).FileName(1:4), 'link')
                    % Get data filename
                    [KernelFile, DataFile] = file_resolve_link(sInputs(iInput).FileName);
                    condComment = [file_short(DataFile) '/' sInputs(iInput).Comment];
                else
                    condComment = sInputs(iInput).FileName;
                end
                
            case 'timefreq'
                % Load file
                sMat = in_bst_timefreq(sInputs(iInput).FileName, 0);
                if ~strcmpi(sMat.DataType, 'results')
                    bst_report('Error', sProcess, sInputs(iInput), 'This file does not contain any valid cortical maps.');
                    continue;
                end
                % Make sure 
                if strcmpi(sMat.Measure, 'none')
                    bst_report('Error', sProcess, sInputs(iInput), 'Please apply a measure on these complex values first.');
                    continue;
                end
                % If this is a kernel-based result: need to load the kernel as well
                if ~isempty(strfind(sInputs(iInput).FileName, '_KERNEL_'))
                    % sResults = in_bst_results(sMat.DataFile, 0);
                    % matValues = [];
                    % sMat.F = sMat.TF;
                    bst_report('Error', sProcess, sInputs(iInput), 'Kernel-based time-frequency files are not supported in this process. Please apply a measure on them first.');
                    continue;
                else
                    matValues = sMat.TF;
                end
                % Standard deviation
                if isfield(sMat, 'Std') && ~isempty(sMat.Std)
                    matStd = sMat.Std;
                else
                    matStd = [];
                end
                % Error: cannot process atlas-based files
                if isfield(sMat, 'Atlas') && ~isempty(sMat.Atlas)
                    bst_report('Error', sProcess, sInputs(iInput), 'File is already based on an atlas.');
                    continue;
                end
                % Get ZScore parameter
                if isfield(sMat, 'ZScore') && ~isempty(sMat.ZScore)
                    ZScore = sMat.ZScore;
                end
                % Get GridAtlas/GridLoc/GridOrient parameter
                if isfield(sMat, 'GridAtlas') && ~isempty(sMat.GridAtlas)
                    GridAtlas = sMat.GridAtlas;
                end
                if isfield(sMat, 'GridLoc') && ~isempty(sMat.GridLoc)
                    GridLoc = sMat.GridLoc;
                end
                % Copy surface filename
                if isfield(sMat, 'SurfaceFile') && ~isempty(sMat.SurfaceFile)
                    SurfaceFile = sMat.SurfaceFile;
                end
                % Input filename
                condComment = sInputs(iInput).FileName;
               
            otherwise
                bst_report('Error', sProcess, sInputs(iInput), 'Unsupported file type.');
                continue;
        end
        % Nothing loaded
        if isempty(sMat) || (isempty(matValues) && (isempty(sResults) || ~isfield(sResults, 'ImagingKernel') || isempty(sResults.ImagingKernel)))
            bst_report('Error', sProcess, sInputs(iInput), 'Could not load anything from the input file. Check the requested time window.');
            return;
        end
        % Do not accept time bands (unless there is only one)
        if isfield(sMat, 'TimeBands') && ~isempty(sMat.TimeBands) && ~((size(matValues,2)==1) && (size(sMat.TimeBands,1)==1))
            bst_report('Error', sProcess, sInputs(iInput), 'Time bands are not supported yet by this process.');
            continue;
        end
        % Add possibly missing fields
        if ~isfield(sMat, 'ChannelFlag')
            sMat.ChannelFlag = [];
        end
        if ~isfield(sMat, 'History')
            sMat.History = {};
        end
        % Replicate if no time
        if (length(sMat.Time) == 1)
            sMat.Time = [0,1];
        end
        if ~isempty(matValues) && (size(matValues,2) == 1)
            matValues = [matValues, matValues];
            if ~isempty(matStd)
                matStd = [matStd, matStd];
            end
        elseif isfield(sMat, 'F') && (size(sMat.F,2) == 1)
            sMat.F = cat(2, sMat.F, sMat.F);
        end
        
        % === LOAD SURFACE ===
        % Surface file not defined in the file
        if isempty(SurfaceFile)
            % Warning message
            bst_report('Warning', sProcess, sInputs(iInput), 'Surface file is not defined for the input file, using the default cortex.');
            % Get input subject
            sSubject = bst_get('Subject', sInputs(iInput).SubjectFile);
            % Get default cortex surface 
            SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
        end
        % Load surface
        sSurf = in_tess_bst(SurfaceFile);
        if isempty(sSurf) || ~isfield(sSurf, 'Atlas')
            bst_report('Error', sProcess, sInputs(iInput), ['Invalid surface file: ' SurfaceFile]);
            continue;
        end
        % Get orientations
        if strcmpi(sInputs(iInput).FileType, 'results')
            SurfOrient = sSurf.VertNormals;
        end
                    
        % === TIME ===
        % Check time vectors
        if (iInput == 1)
            initTimeVector = sMat.Time;
        elseif (length(initTimeVector) ~= length(sMat.Time)) && isConcatenate
            bst_report('Error', sProcess, sInputs(iInput), 'Time definition should be the same for all the files.');
            continue;
        end
        % Option: Time window
        if ~isempty(TimeWindow)
            % Get time indices
            if (length(sMat.Time) <= 2)
                iTime = 1:length(sMat.Time);
            else
                iTime = panel_time('GetTimeIndices', sMat.Time, TimeWindow);
                if isempty(iTime)
                    bst_report('Error', sProcess, sInputs(iInput), 'Invalid time window option.');
                    continue;
                end
            end
            % If only one time point selected: double it
            if (length(iTime) == 1)
                iTime = [iTime, iTime];
            end
            % Keep only the requested time window
            if ~isempty(matValues)
                matValues = matValues(:,iTime,:);
                if ~isempty(matStd)
                    matStd = matStd(:,iTime,:,:);
                end
            else
                sMat.F = sMat.F(:,iTime,:);
            end
            sMat.Time = sMat.Time(iTime);
            % If there are only two time points, make sure they are not identical
            if (length(sMat.Time) == 2)
                sMat.Time(2) = sMat.Time(1) + 0.001;
            end
        end
        
        % === LOOP ON SCOUTS ===
        scoutValues  = [];
        scoutStd     = [];
        Description  = {};
        scoutComment = [];
        sScoutsFinal = [];
        % Loop on all the atlases in the list
        for iAtlas = 1:size(AtlasList,1)
            % Get the index of the atlas in the scout
            AtlasName = AtlasList{iAtlas,1};
            iAtlasSurf = find(strcmpi(AtlasList{iAtlas,1}, {sSurf.Atlas.Name}));
            % Is this a volume atlas?
            isVolumeAtlas = panel_scout('ParseVolumeAtlas', AtlasName);
            % Loop on the scouts selected for this atlas
            for iScout = 1:length(AtlasList{iAtlas,2})
                % Get scout name
                ScoutName = AtlasList{iAtlas,2}{iScout};
                
                % === ATLAS-BASED FILES ===
                if ~isempty(iFileScouts)
                    scoutValues = cat(1, scoutValues, matValues(iFileScouts(iScout),:,:));
                    Description = cat(1, Description, ScoutName);
                    nComponents = 1;
                    continue;
                end
                
                % === FIND SCOUT NAMES IN SURFACE ATLASES ===
                sScout = [];
                % Search in selected atlas
                if ~isempty(iAtlasSurf)
                    % Search for scout name
                    if ~isempty(sSurf.Atlas(iAtlasSurf).Scouts)
                        iScoutSurf = find(strcmpi(ScoutName, {sSurf.Atlas(iAtlasSurf).Scouts.Label}));
                    else
                        iScoutSurf = [];
                    end
                    % Multiple scouts with the same name in an atlas: Error
                    if (length(iScoutSurf) > 1)
                        bst_report('Error', sProcess, sInputs(iInput), ['Multiple scouts have the same name in atlas "' AtlasName '", please fix this error.']);
                        return;
                    % Scout was found
                    elseif ~isempty(iScoutSurf)
                        sScout = sSurf.Atlas(iAtlasSurf).Scouts(iScoutSurf);
                    end
                end
                % If either the selected atlas or the selected scout was not found: search in all the atlases
                if isempty(sScout)
                    iAllAtlas = [];
                    iAllScout = [];
                    % Search all the other atlases
                    for ia = 1:length(sSurf.Atlas)
                        % Search for scout name
                        if ~isempty(sSurf.Atlas(ia).Scouts)
                            iScoutSurf = find(strcmpi(ScoutName, {sSurf.Atlas(ia).Scouts.Label}));
                        else
                            iScoutSurf = [];
                        end
                        % Multiple scouts with the same name in an atlas: Error
                        if (length(iScoutSurf) > 1)
                            bst_report('Error', sProcess, sInputs(iInput), ['Multiple scouts have the same name in atlas "' sSurf.Atlas(iAtlasSurf).Name '", please fix this error.']);
                            return;
                        % Scout was found
                        elseif ~isempty(iScoutSurf)
                            iAllAtlas(end+1) = ia;
                            iAllScout(end+1) = iScoutSurf;
                        end
                    end
                    % If the scout name was found in multiple atlases: Error
                    if (length(iAllAtlas) > 1)
                        bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" was not found in selected atlas "' AtlasName '", but exists in multiple other atlases. Please select the atlas you want to use.']);
                        return;
                    % Scout name was found in only one atlas: Use it with a warning
                    elseif ~isempty(iAllAtlas)
                        bst_report('Warning', sProcess, sInputs(iInput), ['Scout "' ScoutName '" was not found in selected atlas "' AtlasName '". Using the one that was found in atlas "' sSurf.Atlas(iAllAtlas).Name '".']);
                        sScout = sSurf.Atlas(iAllAtlas).Scouts(iAllScout);
                    end
                end
                % Scout was not found: Error
                if isempty(sScout)
                    bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" was not found in any atlas saved in the surface.']);
                    continue;
                end
                % Get scout function
                if ~isempty(ScoutFunc)
                    SelScoutFunc = ScoutFunc;
                    sScout.Function = SelScoutFunc;
                else
                    SelScoutFunc = sScout.Function;
                end
                % Add to the list of selected scouts
                if isempty(sScoutsFinal)
                    sScoutsFinal = sScout;
                else
                    sScoutsFinal(end+1) = sScout;
                end


                % === GET ROWS INDICES ===
                % Sort vertices indices
                iVertices = sort(unique(sScout.Vertices));
                % Get the number of components per vertex
                if strcmpi(sInputs(iInput).FileType, 'results')
                    nComponents = sResults.nComponents;
                elseif ~isempty(GridAtlas)
                    nComponents = 0;
                else
                    nComponents = 1;
                end
                % Get row names
                if strcmpi(SelScoutFunc, 'All')
                    RowNames = cellfun(@num2str, num2cell(iVertices), 'UniformOutput', 0);
                else
                    RowNames = [];
                end
                % Get the vertex indices of the scout in ImageGridAmp/ImagingKernel
                [iRows, iRegionScouts, iVertices] = bst_convert_indices(iVertices, nComponents, GridAtlas, ~isVolumeAtlas);
                % Mixed headmodel results
                if (nComponents == 0)
                    % Do not accept scouts that span over multiple regions
                    if isempty(iRegionScouts)
                        bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" is not included in the source model.'  10 'If you use this region as a volume, create a volume scout instead (menu Atlas > New atlas > Volume scouts).']);
                        return;
                    elseif (length(iRegionScouts) > 1)
                        bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" spans over multiple regions of the "Source model" atlas.']);
                        return;
                    end
                    % Do not accept volume atlases with non-volume head models
                    if ~isVolumeAtlas && strcmpi(GridAtlas.Scouts(iRegionScouts).Region(2), 'V')
                        bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" is a surface scout but region "' GridAtlas.Scouts(iRegionScouts).Label '" is a volume region.']);
                        return;
                    elseif isVolumeAtlas && strcmpi(GridAtlas.Scouts(iRegionScouts).Region(2), 'S')
                        bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" is a volume scout but region "' GridAtlas.Scouts(iRegionScouts).Label '" is a surface region.']);
                        return;
                    end
                    % Set the scout computation properties based on the information in the "Source model" atlas
                    if strcmpi(GridAtlas.Scouts(iRegionScouts).Region(3), 'C')
                        nComponents = 1;
                        if ~isempty(GridOrient)
                            ScoutOrient = GridOrient(iVertices,:);
                        end
                    else
                        nComponents = 3;
                        ScoutOrient = [];
                    end
                % Simple head models
                else
                    % Do not accept volume atlases with non-volume head models
                    if ~isVolumeAtlas && ~isempty(GridLoc)
                        bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" is a surface scout but the sources are calculated on a volume grid.']);
                        return;
                    elseif isVolumeAtlas && isempty(GridLoc)
                        bst_report('Error', sProcess, sInputs(iInput), ['Scout "' ScoutName '" is a volume scout but the sources are calculated on a surface.']);
                        return;
                    end
                    % Get the scout orientation
                    if ~isVolumeAtlas && ~isempty(SurfOrient)
                        ScoutOrient = SurfOrient(iVertices,:);
                    end
                end

                % === GET SOURCES ===
                % Get all the sources values
                if ~isempty(matValues)
                    sourceValues = matValues(iRows,:,:);
                    if ~isempty(matStd)
                        sourceStd = matStd(iRows,:,:,:);
                    else
                        sourceStd = [];
                    end
                elseif (size(sMat.F,3) == 1)
                    sourceValues = sResults.ImagingKernel(iRows,:) * sMat.F(sResults.GoodChannel,:);
                    sourceStd = [];
                else
                    % sourceValues = zeros(length(iRows), size(sMat.F,2), size(sMat.F,3));
                    % for iFreq = 1:size(sMat.F,3)
                    %     sourceValues(:,:,iFreq) = sResults.ImagingKernel(iRows,:) * sMat.F(:,:, iFreq);
                    % end
                    bst_report('Error', sProcess, sInputs(iInput), 'Kernel-based time-frequency files are not supported here.');
                    return;
                end

                % === APPLY DYNAMIC ZSCORE ===
                if ~isempty(ZScore)
                    ZScoreScout = ZScore;
                    % Keep only the selected vertices
                    if ~isempty(iRows) && ~isempty(ZScoreScout.mean)
                        ZScoreScout.mean = ZScoreScout.mean(iRows,:);
                        ZScoreScout.std  = ZScoreScout.std(iRows,:);
                    end
                    % Calculate mean/std
                    if isempty(ZScoreScout.mean)
                        sourceValues = process_zscore_dynamic('Compute', sourceValues, ZScoreScout, sMat.Time, sResults.ImagingKernel(iRows,:), sMat.F(sResults.GoodChannel,:,:));
                        if ~isempty(sourceStd)
                            for iBound = 1:size(sourceStd,4)
                                sourceStd(:,:,:,iBound) = process_zscore_dynamic('Compute', sourceStd(:,:,:,iBound), ZScoreScout, sMat.Time, sResults.ImagingKernel(iRows,:), sMat.F(sResults.GoodChannel,:,:));
                            end
                        end
                    % Apply existing mean/std
                    else
                        sourceValues = process_zscore_dynamic('Compute', sourceValues, ZScoreScout);
                        if ~isempty(sourceStd)
                            for iBound = 1:size(sourceStd,4)
                                sourceStd(:,:,:,iBound) = process_zscore_dynamic('Compute', sourceStd(:,:,:,iBound), ZScoreScout);
                            end
                        end
                    end
                end

                % === COMPUTE CLUSTER VALUES ===
                % Process differently the unconstrained sources
                isUnconstrained = (nComponents ~= 1) && ~strcmpi(XyzFunction, 'norm');
                % If the flip was requested but not a good thing to do on this file
                wrnMsg = [];
                if isFlip && isUnconstrained
                    % wrnMsg = 'Sign flip was not performed: it is only necessary for constrained orientations.';
                    isFlipScout = 0;
                elseif isFlip && strcmpi(sInputs(iInput).FileType, 'timefreq') 
                    wrnMsg = 'Sign flip was not performed: not applicable for time-frequency files.';
                    isFlipScout = 0;
                elseif isFlip && ~isempty(strfind(sInputs(iInput).FileName, '_abs'))
                    wrnMsg = 'Sign flip was not performed: an absolute value was already applied to the source maps.';
                    isFlipScout = 0;
                else
                    isFlipScout = isFlip;
                end
                % Warning
                if ~isempty(wrnMsg) && isFlipWarning
                    disp(['BST> ' wrnMsg '. File: ' sInputs(iInput).FileName]);
                    bst_report('Info', sProcess, sInputs(iInput), wrnMsg);
                end
                % Save the name of the scout
                scoutComment = [scoutComment, ' ', ScoutName];
                % Loop on frequencies
                nFreq = size(sourceValues,3);
                for iFreq = 1:nFreq
                    % Apply scout function
                    tmpScout = bst_scout_value(sourceValues(:,:,iFreq), SelScoutFunc, ScoutOrient, nComponents, XyzFunction, isFlipScout, ScoutName);
                    scoutValues = cat(1, scoutValues, tmpScout);
                    if ~isempty(sourceStd)
                        tmpScoutStd = [];
                        for iBound = 1:size(sourceStd,4)
                            tmp = bst_scout_value(sourceStd(:,:,iFreq,iBound), SelScoutFunc, ScoutOrient, nComponents, XyzFunction, 0);
                            if isempty(tmpScoutStd)
                                tmpScoutStd = tmp;
                            else
                                tmpScoutStd = cat(4, tmpScoutStd, tmp);
                            end
                        end
                        scoutStd = cat(1, scoutStd, tmpScoutStd);
                    end
                    % Loop on the rows to comment them
                    for iRow = 1:size(tmpScout,1)
                        % Start with the scout name
                        scoutDesc = ScoutName;
                        % Add the row name 
                        if AddRowComment && ~isempty(RowNames)
                            if isUnconstrained
                                iRowUnconstr = floor((iRow-1) / nComponents + 1);
                                scoutDesc = [scoutDesc '.' RowNames{iRowUnconstr}];
                            else
                                scoutDesc = [scoutDesc '.' RowNames{iRow}];
                            end
                        end
                        % Add the component index (unconstrained sources)
                        if isUnconstrained
                            iComp = mod(iRow-1,nComponents) + 1;
                            scoutDesc = [scoutDesc '.' num2str(iComp)];
                        end
                        % Add file comment
                        if AddFileComment
                            % Frequency comment
                            if (nFreq > 1)
                                if iscell(sMat.Freqs)
                                    freqComment = [' ' sMat.Freqs{iFreq,1}];
                                else
                                    freqComment = [' ' num2str(sMat.Freqs(iFreq)), 'Hz'];
                                end
                            else
                                freqComment = '';
                            end
                            % Add it to the scout comment
                            scoutDesc = [scoutDesc ' @ ' condComment freqComment];
                        end
                        % Add the scout description
                        Description = cat(1, Description, scoutDesc);
                    end
                end
            end
        end
        % If nothing was found
        if isempty(scoutValues)
            return;
        end
        
        % === OUTPUT STRUCTURE ===
        if (iInput == 1)
            % Create structure
            newMat = db_template('matrixmat');
            newMat.Value       = [];
            newMat.ChannelFlag = ones(size(sMat.ChannelFlag));
        end
        newMat.Time = sMat.Time;
        % If the number of averaged files is defined: use it
        if isfield(sMat, 'nAvg') && ~isempty(sMat.nAvg)
            newMat.nAvg = sMat.nAvg;
        else
            newMat.nAvg = 1;
        end
        if isfield(sMat, 'Leff') && ~isempty(sMat.Leff)
            newMat.Leff = sMat.Leff;
        else
            newMat.Leff = 1;
        end
        % Concatenate new values to existing ones
        if isConcatenate
            newMat.Value       = cat(1, newMat.Value,       scoutValues);
            newMat.Description = cat(1, newMat.Description, Description);
            newMat.ChannelFlag(sMat.ChannelFlag == -1) = -1;
            if ~isempty(scoutStd)
                newMat.Std = cat(1, newMat.Std, scoutStd);
            end
        else
            newMat.Value       = scoutValues;
            newMat.Description = Description;
            newMat.ChannelFlag = sMat.ChannelFlag;
            if ~isempty(scoutStd)
                newMat.Std = scoutStd;
            end
        end

        % Save the original surface file
        if ~isempty(SurfaceFile)
            newMat.SurfaceFile = SurfaceFile;
        end
        % Save the atlas in the file
        newMat.Atlas = db_template('atlas');
        newMat.Atlas.Name = 'process_extract_scout';
        newMat.Atlas.Scouts = sScoutsFinal;

        % === HISTORY ===
        if ~isConcatenate || (iInput == 1)
            % Re-use the history of the initial file
            newMat.History = sMat.History;
            % History: process name
            newMat = bst_history('add', newMat, 'process', FormatComment(sProcess));
        end
        % History: File name
        newMat = bst_history('add', newMat, 'process', [' - File: ' sInputs(iInput).FileName]);
                
        % === SAVE FILE ===
        % One file per input: save one matrix file per input file
        if ~isConcatenate
            % Comment: forced in the options
            if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
                newMat.Comment = sProcess.options.Comment.Value;
            % Comment: Process default (limit size of scout comment)
            elseif (length(sScoutsFinal) > 1) && (length(scoutComment) > 20)
                newMat.Comment = [sMat.Comment, ' | ' num2str(length(sScoutsFinal)) ' scouts'];
            elseif ~isempty(scoutComment)
                newMat.Comment = [sMat.Comment, ' | scouts (' scoutComment(2:end) ')'];
            else
                newMat.Comment = [sMat.Comment, ' | scouts'];
            end
            % Save new file in database
            if isSave
                % Output study = input study
                [sStudy, iStudy] = bst_get('Study', sInputs(iInput).iStudy);
                % Output filename
                OutFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_scout');
                % Save on disk
                bst_save(OutFile, newMat, 'v6');
                % Register in database
                db_add_data(iStudy, OutFile, newMat);
                % Out to list of output files
                OutputFiles{end+1} = OutFile;
            % Just return scout values
            else
                % Add nComponents to indicate how many components per vertex
                if (nComponents == 1) || strcmpi(XyzFunction, 'norm')
                    newMat.nComponents = 1;
                else
                    newMat.nComponents = nComponents;
                end
                % Return structure
                if isempty(OutputFiles)
                    OutputFiles = newMat;
                else
                    OutputFiles(end+1) = newMat;
                end
            end
        end
    end
    
    % === SAVE FILE ===
    % Only one concatenated output matrix
    if isConcatenate
        % Get output study
        [sStudy, iStudy, Comment] = bst_process('GetOutputStudy', sProcess, sInputs);
        % Comment: forced in the options
        if isfield(sProcess.options, 'Comment') && isfield(sProcess.options.Comment, 'Value') && ~isempty(sProcess.options.Comment.Value)
            newMat.Comment = sProcess.options.Comment.Value;
        % Comment: Process default
        else
            newMat.Comment = [strrep(FormatComment(sProcess), ' time series', ''), ' (' Comment ')'];
        end
        % Save new file in database
        if isSave
            % Output filename
            OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), 'matrix_scout');
            % Save on disk
            bst_save(OutputFiles{1}, newMat, 'v6');
            % Register in database
            db_add_data(iStudy, OutputFiles{1}, newMat);
        % Just return scout values
        else
            OutputFiles = newMat;
        end
    end
end




%% ===== GET SCOUTS INFO =====
% USAGE:  [sScoutsFinal, AllAtlasNames, sSurf] = process_extract_scout('GetScoutsInfo', sProcess, sInputs, SurfaceFile, AtlasList)
function [sScoutsFinal, AllAtlasNames, sSurf] = GetScoutsInfo(sProcess, sInputs, SurfaceFile, AtlasList)
    sScoutsFinal  = [];
    AllAtlasNames = {};
    
    % Convert from older structure (keep for backward compatibility)
    if isstruct(AtlasList) && ~isempty(AtlasList)
        AtlasList = {'User scouts', {AtlasList.Label}};
    end
    % No scouts selected: exit
    if isempty(AtlasList) || ~iscell(AtlasList) || (size(AtlasList,2) < 2) || isempty(AtlasList{1,2})
        bst_report('Error', sProcess, [], 'No scout selected.');
        return;
    end
    
    % === LOAD SURFACE ===
    % Surface file not defined in the file
    if isempty(SurfaceFile)
        % Get input subject
        sSubject = bst_get('Subject', sInputs(1).SubjectFile);
        % Error: no default cortex
        if isempty(sSubject.iCortex) || (sSubject.iCortex > length(sSubject.Surface))
            bst_report('Error', sProcess, sInputs(1), ['Invalid surface file: ' SurfaceFile]);
        else        
            bst_report('Warning', sProcess, sInputs(1), 'Surface file is not defined for the input file, using the default cortex.');
        end
        % Get default cortex surface 
        SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
    end
    % Load surface
    sSurf = in_tess_bst(SurfaceFile);
    if isempty(sSurf) || ~isfield(sSurf, 'Atlas')
        bst_report('Error', sProcess, sInputs(1), ['Invalid surface file: ' SurfaceFile]);
        return;
    end

    % === LOOP ON SCOUTS ===
    sScoutsFinal = [];
    % Loop on all the atlases in the list
    for iAtlas = 1:size(AtlasList,1)
        % Get the index of the atlas in the scout
        AtlasName = AtlasList{iAtlas,1};
        iAtlasSurf = find(strcmpi(AtlasList{iAtlas,1}, {sSurf.Atlas.Name}));
        % Loop on the scouts selected for this atlas
        for iScout = 1:length(AtlasList{iAtlas,2})
            % === FIND SCOUT NAMES IN SURFACE ATLASES ===
            ScoutName = AtlasList{iAtlas,2}{iScout};
            sScout = [];
            % Search in selected atlas
            if ~isempty(iAtlasSurf)
                % Search for scout name
                iScoutSurf = find(strcmpi(ScoutName, {sSurf.Atlas(iAtlasSurf).Scouts.Label}));
                % Multiple scouts with the same name in an atlas: Error
                if (length(iScoutSurf) > 1)
                    bst_report('Error', sProcess, sInputs(1), ['Multiple scouts have the same name in atlas "' AtlasName '", please fix this error.']);
                    sScoutsFinal = [];
                    return;
                % Scout was found
                elseif ~isempty(iScoutSurf)
                    sScout = sSurf.Atlas(iAtlasSurf).Scouts(iScoutSurf);
                end
            end
            % If either the selected atlas or the selected scout was not found: search in all the atlases
            if isempty(sScout)
                iAllAtlas = [];
                iAllScout = [];
                % Search all the other atlases
                for ia = 1:length(sSurf.Atlas)
                    if isempty(sSurf.Atlas(ia).Scouts)
                        continue;
                    end
                    % Search for scout name
                    iScoutSurf = find(strcmpi(ScoutName, {sSurf.Atlas(ia).Scouts.Label}));
                    % Multiple scouts with the same name in an atlas: Error
                    if (length(iScoutSurf) > 1)
                        bst_report('Error', sProcess, sInputs(1), ['Multiple scouts have the same name in atlas "' sSurf.Atlas(iAtlasSurf).Name '", please fix this error.']);
                        sScoutsFinal = [];
                        return;
                    % Scout was found
                    elseif ~isempty(iScoutSurf)
                        iAllAtlas(end+1) = ia;
                        iAllScout(end+1) = iScoutSurf;
                    end
                end
                % If the scout name was found in multiple atlases: Error
                if (length(iAllAtlas) > 1)
                    bst_report('Error', sProcess, sInputs(1), ['Scout "' ScoutName '" was not found in selected atlas "' AtlasName '", but exists in multiple other atlases. Please select the atlas you want to use.']);
                    sScoutsFinal = [];
                    return;
                % Scout name was found in only one atlas: Use it with a warning
                elseif ~isempty(iAllAtlas)
                    bst_report('Warning', sProcess, sInputs(1), ['Scout "' ScoutName '" was not found in selected atlas "' AtlasName '". Using the one that was found in atlas "' sSurf.Atlas(iAllAtlas).Name '".']);
                    sScout = sSurf.Atlas(iAllAtlas).Scouts(iAllScout);
                end
            end
            % Scout was not found: Error
            if isempty(sScout)
                bst_report('Error', sProcess, sInputs(1), ['Scout "' ScoutName '" was not found in any atlas saved in the surface.']);
                sScoutsFinal = [];
                return;
            end
            % Add to the list of selected scouts
            if isempty(sScoutsFinal)
                sScoutsFinal = sScout;
            else
                sScoutsFinal(end+1) = sScout;
            end
            AllAtlasNames{end+1} = AtlasName;
        end
    end
end



