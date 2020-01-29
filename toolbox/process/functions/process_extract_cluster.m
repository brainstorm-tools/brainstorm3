function varargout = process_extract_cluster( varargin )
% PROCESS_EXTRACT_CLUSTER: Extract clusters values.
%
% THIS FUNCTION IS NOW DEPRECATED FOR EXTRACTING SCOUT TIME SERIES
% PLEASE USE PROCESS_EXTRACT_SCOUT INSTEAD

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
% Authors: Francois Tadel, 2010-2019

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Clusters time series';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Extract';
    sProcess.Index       = 351;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/ChannelClusters';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % === TIME WINDOW
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === CLUSTERS
    sProcess.options.clusters.Comment = '';
    sProcess.options.clusters.Type    = 'cluster';
    sProcess.options.clusters.Value   = [];
    % Atlas: surface/volume
    sProcess.options.isvolume.Comment = '';
    sProcess.options.isvolume.Type    = 'checkbox';
    sProcess.options.isvolume.Value   = 0;
    sProcess.options.isvolume.Hidden  = 1;
    % === NORM XYZ
    sProcess.options.isnorm.Comment = 'Unconstrained sources: Norm of the three orientations (x,y,z)';
    sProcess.options.isnorm.Type    = 'checkbox';
    sProcess.options.isnorm.Value   = 0;
    % === CONCATENATE
    sProcess.options.concatenate.Comment = 'Concatenate output in one unique matrix';
    sProcess.options.concatenate.Type    = 'checkbox';
    sProcess.options.concatenate.Value   = 1;
    % === SAVE OUTPUT
    sProcess.options.save.Comment = '';
    sProcess.options.save.Type    = 'ignore';
    sProcess.options.save.Value   = 1;
    % === USE ROW NAME
    sProcess.options.userowname.Comment = '';
    sProcess.options.userowname.Type    = 'ignore';
    sProcess.options.userowname.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    % Get type of data
    DataType = gui_brainstorm('GetProcessFileType', 'Process1');
    % Get name of the cluster (cluster or scout)
    switch (DataType)
        case 'data',      clusterType = 'clusters';
    	case 'results',   clusterType = 'scouts';
        case 'timefreq',  clusterType = 'scouts';
    end
    Comment = ['Extract ' clusterType ' time series:'];
%     % Get selected clusters
%     sClusters = sProcess.options.clusters.Value;
    % Get selected clusters
    sClusters = sProcess.options.clusters.Value;
    % Format comment
    if isempty(sClusters)
        Comment = [Comment, '[no selection]'];
    elseif (length(sClusters) > 15)
        Comment = [Comment, sprintf('[%d %s]', length(sClusters), clusterType)];
    else
        for i = 1:length(sClusters)
            Comment = [Comment, ' ', sClusters(i).Label];
        end
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % REDIRECTING SCOUT CALLS TO PROCESS_EXTRACT_SCOUTS
    if ismember(sInputs(1).FileType, {'results', 'timefreq'})
        % Issue redirection warning
        bst_report('Warning', sProcess, [], ['The use of process_extract_cluster is not recommended for processing scouts anymore.' 10 'Redirecting to process_extract_scout...']);
        % Add missing options
        sProcess.options.scouts.Value = sProcess.options.clusters.Value;
        sProcess.options.scoutfunc.Value = [];
        sProcess.options.isflip.Value = 1;
        sProcess.options.addrowcomment.Value = 1;
        sProcess.options.addfilecomment.Value = 1;
        % Call process_extract_scout
        OutputFiles = process_extract_scout('Run', sProcess, sInputs);
        return;
    end
    
    % Concatenate values ?
    isConcatenate = sProcess.options.concatenate.Value && (length(sInputs) > 1);
    isVolumeAtlas = sProcess.options.isvolume.Value;
    nAtlasGrid    = str2num(sProcess.options.isvolume.Comment);
    isSave = sProcess.options.save.Value;
    isNorm = sProcess.options.isnorm.Value;
    % If a time window was specified
    if isfield(sProcess.options, 'timewindow') && ~isempty(sProcess.options.timewindow) && ~isempty(sProcess.options.timewindow.Value) && iscell(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    OutputFiles = {};
    % Get clusters
    sClusters = sProcess.options.clusters.Value;
    if isempty(sClusters)
        bst_report('Error', sProcess, [], 'No cluster/scout selected.');
        return;
    end
    % Get protocol folders
    ProtocolInfo = bst_get('ProtocolInfo');
    % Use rown names by default
    if isfield(sProcess.options, 'userowname') && ~isempty(sProcess.options.userowname) && (length(sProcess.options.userowname.Value) == length(sClusters))
        UseRowName = sProcess.options.userowname.Value;
    else
        UseRowName = ones(size(sClusters));
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
        % === READ FILES ===
        switch (sInputs(iInput).FileType)
            case 'data'
                clustType = 'clusters';
                % Load recordings
                sMat = in_bst_data(sInputs(iInput).FileName);
                matValues = sMat.F;
                stdValues = sMat.Std;
                % Input filename
                condComment = sInputs(iInput).FileName;
                % Check for channel file
                if isempty(sInputs(iInput).ChannelFile)
                    bst_report('Error', sProcess, sInputs(iInput), 'This process requires a channel file.');
                    continue;
                end
                % Get channel file
                ChannelMat = in_bst_channel(sInputs(iInput).ChannelFile);

            case 'results'
                clustType = 'scouts';
                % Load results
                sMat = in_bst_results(sInputs(iInput).FileName, 0);
                % Atlas-based files
                if isfield(sMat, 'Atlas') && ~isempty(sMat.Atlas)
                    % Try to look the requested scouts in the file
                    for i = 1:length(sClusters)
                        iTmp = find(strcmpi(sClusters(i).Label, {sMat.Atlas(1).Scouts.Label}));
                        if ~isempty(iTmp)
                            iFileScouts(end+1) = iTmp;
                        end
                    end
                    % If the scout names cannot be found: error
                    if (length(iFileScouts) ~= length(sClusters))
                        bst_report('Error', sProcess, sInputs(iInput), 'File is already based on an atlas, but the selected scouts don''t match with it.');
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
                    stdValues = sMat.Std;
                % KERNEL ONLY
                elseif isfield(sMat, 'ImagingKernel') && ~isempty(sMat.ImagingKernel)
                    sResults = sMat;
                    %sMat = in_bst_data(sResults.DataFile);
                    sMat = in_bst(sResults.DataFile, TimeWindow);
                    matValues = [];
                    stdValues = [];
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
                    if isVolumeAtlas && ~isempty(nAtlasGrid) && (size(sResults.GridLoc,1) ~= nAtlasGrid)
                        bst_report('Error', sProcess, sInputs(iInput), ['The number of grid points in this atlas (' num2str(nAtlasGrid) ') does not match the loaded source file (' num2str(size(sResults.GridLoc,1)) ').']);
                        continue;
                    end
                end
                if isfield(sResults, 'GridOrient') && ~isempty(sResults.GridOrient)
                    GridOrient = sResults.GridOrient;
                end
                % Input filename
                if isequal(sInputs(iInput).FileName(1:4), 'link')
                    % Get data filename
                    [KernelFile, DataFile] = file_resolve_link(sInputs(iInput).FileName);
                    DataFile = strrep(DataFile, ProtocolInfo.STUDIES, '');
                    DataFile = file_win2unix(DataFile(2:end));
                    condComment = [DataFile '/' sInputs(iInput).Comment];
                else
                    condComment = sInputs(iInput).FileName;
                end
                
            case 'timefreq'
                clustType = 'scouts';
                % Load file
                sMat = in_bst_timefreq(sInputs(iInput).FileName, 0);
                if ~strcmpi(sMat.DataType, 'results')
                    bst_report('Error', sProcess, sInputs(iInput), 'This file does not contain any valid cortical maps.');
                    continue;
                end
                matValues = sMat.TF;
                stdValues = sMat.Std;
                % Error: cannot process atlas-based files
                if isfield(sMat, 'Atlas') && ~isempty(sMat.Atlas)
                    bst_report('Error', sProcess, sInputs(iInput), 'File is already based on an atlas.');
                    continue;
                end
                % Get ZScore parameter
                if isfield(sMat, 'ZScore') && ~isempty(sMat.ZScore)
                    ZScore = sMat.ZScore;
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
        % Add possibly missing fields
        if ~isfield(sMat, 'ChannelFlag')
            sMat.ChannelFlag = [];
        end
        if ~isfield(sMat, 'History')
            sMat.History = {};
        end
        % Replicate if no time
        if (size(matValues,2) == 1)
            matValues = cat(2, matValues, matValues);
            if ~isempty(stdValues)
                stdValues = cat(2, stdValues, stdValues);
            end
        end
        if (length(sMat.Time) == 1)
            sMat.Time = [0,1];
        end
        if ~isempty(matValues) && (size(matValues,2) == 1)
            matValues = [matValues, matValues];
            if ~isempty(stdValues)
                stdValues = [stdValues, stdValues];
            end
        elseif isfield(sMat, 'F') && (size(sMat.F,2) == 1)
            sMat.F = [sMat.F, sMat.F];
        end
        % Do not accecpt time bands
        if isfield(sMat, 'TimeBands') && ~isempty(sMat.TimeBands)
            bst_report('Error', sProcess, sInputs(iInput), 'Time bands are not supported yet by this process.');
            continue;
        end
        
        % === LOAD SURFACE ===
        isCheckModif = 1;
        % Load surface if not loaded
        if ismember(sInputs(iInput).FileType, {'results', 'timefreq'})
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
            elseif isempty(sSurf.Atlas) || isempty(sSurf.iAtlas) || ~isfield(sSurf.Atlas(sSurf.iAtlas), 'Scouts') || isempty(sSurf.Atlas(sSurf.iAtlas).Scouts)
                % bst_report('Warning', sProcess, sInputs(iInput), ['The current atlas "' sSurf.Atlas(sSurf.iAtlas).Name '" is empty. Not checking for scouts modifications...']);
                isCheckModif = 0;
            end
            % Get orientations
            if strcmpi(sInputs(iInput).FileType, 'results')
                SurfOrient = sSurf.VertNormals;
            end
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
            % Keep only the requested time window
            if ~isempty(matValues)
                matValues = matValues(:,iTime,:);
                if ~isempty(stdValues)
                    stdValues = stdValues(:,iTime,:,:);
                end
            else
                sMat.F = sMat.F(:,iTime);
            end
            sMat.Time = sMat.Time(iTime);
        end
        
        % === LOOP ON CLUSTERS ===
        scoutValues  = [];
        scoutStds    = [];
        Description  = {};
        clustComment = [];
        hasStds      = 0;
        for iClust = 1:length(sClusters)
            % === ATLAS-BASED FILES ===
            if ~isempty(iFileScouts)
                scoutValues = cat(1, scoutValues, matValues(iFileScouts(iClust),:,:));
                if ~isempty(stdValues)
                    scoutStds = cat(1, scoutStds, stdValues(iFileScouts(iClust),:,:,:));
                else
                    scoutStds = cat(1, scoutStds, zeros(size(matValues(iFileScouts(iClust),:,:))));
                end
                Description = cat(1, Description, sClusters(iClust).Label);
                nComponents = 1;
                continue;
            end
            
            % === GET ROWS INDICES ===
            switch (sInputs(iInput).FileType)
                case 'data'
                    nComponents = 1;
                    iRows = panel_cluster('GetChannelsInCluster', sClusters(iClust), ChannelMat.Channel, sMat.ChannelFlag);
                    
                case {'results', 'timefreq'}
                    % Get the number of components per vertex
                    if strcmpi(sInputs(iInput).FileType, 'results')
                        nComponents = sResults.nComponents;
                    else
                        nComponents = 1;
                    end
                    % Check for scout modifications, compare it with current atlas in the file
                    if isCheckModif
                        % Get scout in current file
                        iScout = find(strcmpi(sClusters(iClust).Label, {sSurf.Atlas(sSurf.iAtlas).Scouts.Label}));
                        if (length(iScout) > 1)
                            bst_report('Error', sProcess, sInputs(iInput), 'Multiple scouts have the same name, please fix this error.');
                            return;
                        end
                        % Scout is found
                        if ~isempty(iScout)
                            % Using the scout from the current surface 
                            iVertices = sort(sSurf.Atlas(sSurf.iAtlas).Scouts(iScout).Vertices);
                            % Check that the number of vertices between the two scouts (current surface and input option)
                            if ~isequal(iVertices, sort(sClusters(iClust).Vertices))
                                bst_report('Warning', sProcess, sInputs(iInput), ['Using scout "' sClusters(iClust).Label '" in atlas "' sSurf.Atlas(sSurf.iAtlas).Name '" in surface file "' SurfaceFile '".' 10 ...
                                    'Note it has a different number of vertices (' num2str(length(sSurf.Atlas(sSurf.iAtlas).Scouts(iScout).Vertices)) ...
                                    ') than the scout in input of the process (' num2str(length(sClusters(iClust).Vertices)) ').']);
                            end
                        end
                    else
                        iScout = [];
                    end
                    % Scout is not found in current atlas
                    if isempty(iScout)
                        % Use the scout in input, with a warning
                        iVertices = sort(sClusters(iClust).Vertices);
                        % Warning
                        bst_report('Warning', sProcess, sInputs(iInput), ['Scout "' sClusters(iClust).Label '" is not available in atlas "' sSurf.Atlas(sSurf.iAtlas).Name '" in surface file "' SurfaceFile '".' 10 ...
                            'You should make sure that the scout was initially defined on this surface. If it was defined on another surface, the vertex indices are probably wrong.']);
                    end
                    % Get the vertex indices of the scout in ImageGridAmp/ImagingKernel
                    [iRows, iRegionScouts, iVertices] = bst_convert_indices(iVertices, nComponents, GridAtlas, ~isVolumeAtlas);
                    % Mixed headmodel results
                    if (nComponents == 0)
                        % Do not accept scouts that span over multiple regions
                        if isempty(iRegionScouts)
                            bst_report('Error', sProcess, sInputs(iInput), ['Scout "' sClusters(iClust).Label '" is not included in the source model.']);
                            return;
                        elseif (length(iRegionScouts) > 1)
                            bst_report('Error', sProcess, sInputs(iInput), ['Scout "' sClusters(iClust).Label '" spans over multiple regions of the "Source model" atlas.']);
                            return;
                        end
                        % Do not accept volume atlases with non-volume head models
                        if ~isVolumeAtlas && strcmpi(GridAtlas.Scouts(iRegionScouts).Region(2), 'V')
                            bst_report('Error', sProcess, sInputs(iInput), ['Scout "' sClusters(iClust).Label '" is a volume scout but region "' GridAtlas.Scouts(iRegionScouts).Label '" is a volume region.']);
                            return;
                        elseif isVolumeAtlas && strcmpi(GridAtlas.Scouts(iRegionScouts).Region(2), 'S')
                            bst_report('Error', sProcess, sInputs(iInput), ['Scout "' sClusters(iClust).Label '" is a surface scout but region "' GridAtlas.Scouts(iRegionScouts).Label '" is a surface region.']);
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
                            bst_report('Error', sProcess, sInputs(iInput), ['Scout "' sClusters(iClust).Label '" is a surface scout but the sources are calculated on a volume grid.']);
                            return;
                        elseif isVolumeAtlas && isempty(GridLoc)
                            bst_report('Error', sProcess, sInputs(iInput), ['Scout "' sClusters(iClust).Label '" is a volume scout but the sources are calculated on a surface.']);
                            return;
                        end
                        % Get the scout orientation
                        if ~isempty(SurfOrient)
                            ScoutOrient = SurfOrient(iVertices,:);
                        end
                    end
            end
            % Get row names
            if strcmpi(sClusters(iClust).Function, 'All') && UseRowName(iClust) 
                if isfield(sClusters(iClust), 'Sensors')
                    RowNames = sClusters(iClust).Sensors;
                else
                    RowNames = cellfun(@num2str, num2cell(sClusters(iClust).Vertices), 'UniformOutput', 0);
                end
            else
                RowNames = [];
            end
            
            % === GET SOURCES ===
            % Get all the sources values
            sourceStd = [];
            if ~isempty(matValues)
                sourceValues = matValues(iRows,:,:);
                if ~isempty(stdValues)
                    sourceStd = stdValues(iRows,:,:,:);
                end
            else
                sourceValues = sResults.ImagingKernel(iRows,:) * sMat.F(sResults.GoodChannel,:);
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
                    sourceValues = process_zscore_dynamic('Compute', sourceValues, ZScoreScout, sMat.Time, sResults.ImagingKernel(iRows,:), sMat.F(sResults.GoodChannel,:));
                % Apply existing mean/std
                else
                    sourceValues = process_zscore_dynamic('Compute', sourceValues, ZScoreScout);
                end
                sourceStd = [];
            end
            
            % Split cluster function if applicable
            separator = strfind(sClusters(iClust).Function, '+');
            if ~isempty(separator)
                ClusterFunction = sClusters(iClust).Function(1:separator-1);
                StdFunction     = sClusters(iClust).Function(separator+1:end);
                hasStds         = 1;
            else
                ClusterFunction = sClusters(iClust).Function;
                StdFunction = [];
            end
            
            % === COMPUTE CLUSTER VALUES ===
            % Are we supposed to flip the sign of the vertices with different orientations
            isFlipSign = (nComponents == 1) && ...
                         strcmpi(sInputs(iInput).FileType, 'results') && ...
                         isempty(strfind(sInputs(iInput).FileName, '_abs_zscore'));
            % Save the name of the scout/cluster
            clustComment = [clustComment, ' ', sClusters(iClust).Label];
            % Loop on frequencies
            nFreq = size(sourceValues,3);
            for iFreq = 1:nFreq
                % Apply scout function
                tmpScout = bst_scout_value(sourceValues(:,:,iFreq), ClusterFunction, ScoutOrient, nComponents, XyzFunction, isFlipSign);
                if ~isempty(StdFunction)
                    tmpStd = bst_scout_value(sourceValues(:,:,iFreq), StdFunction, ScoutOrient, nComponents, XyzFunction, isFlipSign);
                elseif ~isempty(sourceStd) && (size(sourceValues,1) == 1)
                    tmpStd = sourceStd(:,:,iFreq,:);
                else
                    tmpStd = zeros(size(tmpScout));
                end
                % Add frequency
                if (nFreq > 1)
                % Get frequency comments
                    if iscell(sMat.Freqs)
                        freqComment = [' ' sMat.Freqs{iFreq,1}];
                    else
                        freqComment = [' ' num2str(sMat.Freqs(iFreq)), 'Hz'];
                    end
                else
                    freqComment = '';
                end
                % If there is only one component
                if (nComponents == 1) || strcmpi(XyzFunction, 'norm')
                    scoutValues = cat(1, scoutValues, tmpScout);
                    scoutStds = cat(1, scoutStds, tmpStd);
                    % Multiple rows for the same cluster (Function 'All')
                    if ~isempty(RowNames)
                        for iRow = 1:size(tmpScout,1)
                            Description = cat(1, Description, [sClusters(iClust).Label '.' RowNames{iRow} ' @ ' condComment freqComment]);
                        end
                    % One ouput row per cluster
                    else
                        scoutDesc   = repmat({[sClusters(iClust).Label, ' @ ', condComment freqComment]}, size(tmpScout,1), 1);
                        Description = cat(1, Description, scoutDesc{:});
                    end        
                else
                    scoutValues = cat(1, scoutValues, tmpScout);
                    scoutStds = cat(1, scoutStds, tmpStd);
                    for iRow = 1:(size(tmpScout,1) / nComponents) 
                        for iComp = 1:nComponents
                            if ~isempty(RowNames)
                                Description = cat(1, Description, [sClusters(iClust).Label '.' RowNames{iRow} '.' num2str(iComp) ' @ ' condComment freqComment]);
                            else
                                Description = cat(1, Description, [sClusters(iClust).Label '.' num2str(iComp) ' @ ' condComment freqComment]);
                            end
                        end
                    end
                end
            end
        end
        
        % === OUTPUT STRUCTURE ===
        if (iInput == 1)
            % Create structure
            newMat = db_template('matrixmat');
            newMat.Value       = [];
            newMat.ChannelFlag = ones(size(sMat.ChannelFlag));
            newMat.Time = sMat.Time;
            newMat.nAvg = sMat.nAvg;
            newMat.Leff = sMat.Leff;
        end
        % Concatenate new values to existing ones
        if isConcatenate
            newMat.Value       = cat(1, newMat.Value,       scoutValues);
            newMat.Description = cat(1, newMat.Description, Description);
            newMat.ChannelFlag(sMat.ChannelFlag == -1) = -1;
            if hasStds || isequal(size(scoutStds), size(scoutValues))
                newMat.Std = cat(1, newMat.Std, scoutValues);
            end
        else
            newMat.Value       = scoutValues;
            newMat.Description = Description;
            newMat.ChannelFlag = sMat.ChannelFlag;
            if hasStds || isequal(size(scoutStds), size(scoutValues))
                newMat.Std     = scoutStds;
            end
        end
        % For surface files / scouts
        if strcmpi(clustType, 'scouts')
            % Save the original surface file
            if ~isempty(SurfaceFile)
                newMat.SurfaceFile = SurfaceFile;
            end
            % Save the atlas in the file
            newMat.Atlas = db_template('atlas');
            newMat.Atlas.Name = 'process_extract_cluster';
            newMat.Atlas.Scouts = sClusters;
        end
        
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
            % Comment: Process default (limit size of cluster comment)
            elseif (length(sClusters) > 1) && (length(clustComment) > 20)
                newMat.Comment = [sMat.Comment, ' | ' num2str(length(sClusters)) ' ' clustType];
            elseif ~isempty(clustComment)
                newMat.Comment = [sMat.Comment, ' | ' clustType ' (' clustComment(2:end) ')'];
            else
                newMat.Comment = [sMat.Comment, ' | ' clustType];
            end
            % Save new file in database
            if isSave
                % Output study = input study
                [sStudy, iStudy] = bst_get('Study', sInputs(iInput).iStudy);
                % Output filename
                OutFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['matrix_' clustType(1:end-1)]);
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
            OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['matrix_' clustType(1:end-1)]);
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




