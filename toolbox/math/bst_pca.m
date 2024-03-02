function OutputFiles = bst_pca(sProcess, sInputs, PcaOptions, AtlasList, isOutMatrix, OutTimeWindow, OutComment)
% BST_PCA: Dimension reduction with principal component analysis (PCA) for scouts, or unconstrained sources.
%
% USAGE:  OutputFiles = bst_pca(sProcess, sInputs, PcaOptions, AtlasList, isOutMatrix, OutTimeWindow)
%
% INPUTS:
%    - PcaOptions: Specifies PCA method and covariance settings, usually obtained in the calling
%      process through the PcaOptions panel, with defaults/preferences from bst_get('PcaOptions').
%      3 available PCA methods (PcaOptions.Method):
%          'pca'  : old approach (pre 2023-06), separately for each file, resulting in sign inconsistencies
%                   between files.
%          'pcaa' : *Across* files.  Computes a single "reference" component based on all the source data
%                   concatenated (per subject).
%          'pcai' : *Individual* files.  Computes a separate PCA component for each file, but correcting
%                   the sign so it aligns (positive projection) with the 'pcaa' reference component.
%    - AtlasList: If provided, run PCA to extract one time series per scout, per source orientation
%      (i.e. 3 per scout for unconstrained sources). If empty: flatten unconstrained sources
%      instead.  Both scout extraction and flattening cannot be run from the same bst_pca call. If
%      both are needed, it is recommended to flatten first, then do scout extraction.
%    - isOutMatrix: If true, force scout PCA to save 'matrix' type files; otherwise, saves 'results',
%      in kernel form when possible (when all inputs from a condition are kernel links).
%    - OutTimeWindow: Requested time window for output time series when isOutMatrix is true. It is
%      widened if needed to include baseline and data time windows that are used to compute the PCA
%      (in PcaOptions).
%    - OutComment: Optional, string to use for new node in tree, instead of default based on inputs.
%
% OUTPUTS:
%    - OutputFiles: This function can save and return deprecated atlas-based result files (full or
%    kernel), when provided with an AtlasList and isOutMatrix is false. These files can only be read
%    properly by process_extract_scout. By extension, they can be read by processes that use
%    bst_process('LoadInputFile', Target) with a scouts-type "Target" (e.g. bst_connectivity and
%    process_pac), or that call directly process_extract_scout (e.g. process_timefreq). These files
%    are deprecated but some Brainstorm processes create them through bst_pca temporarily, deleting
%    them after use (e.g. connectivity processes).
%
% IMPLEMENTATION NOTES:
%    PCA for scout extraction (when non empty AtlasList provided) with unconstrained sources could
%    in theory be done as a single step and provide a single time series; not requiring to flatten
%    separately first. However, to simplify the possible workflows, they must be done sequentially
%    in Brainstorm, flat then scout. (Note that for viewing scout timeseries through the GUI, this
%    function is bypassed and PCA is applied for both scouts and flattening together in
%    view_scouts.)
%
%    Scout PCA components (and so also the timeseries or kernel) are rescaled to have norm
%    1/sqrt(nVertices) instead of 1, to match the scale of the 'mean' component and be more
%    comparable to it, and to other scouts.  By definition, PCA will still always give timeseries
%    with more power than 'mean'.  This scaling is done in bst_scout_value.
%
%    The differences between the 3 PCA methods are all dealt with within this function (with one
%    exception pushed to bst_source_orient for convenience for now).  As such, 'pca2023' is used for
%    all 3 cases in other processes and functions.  'pca' in other functions was kept for the
%    previous (now deprecated) method with sign issues and without other improvements within this function.

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
% Authors: Marc Lalancette, 2023

OutputFiles = {};
AvgType = 2; % group by subject

if nargin < 7 || isempty(OutComment)
    OutComment = [];
end
if nargin < 6 || isempty(OutTimeWindow)
    OutTimeWindow = [];
end
if nargin < 5 || isempty(isOutMatrix)
    isOutMatrix = false;
end
if nargin < 4 || isempty(AtlasList)
    isScout = false;
else
    isScout = true;
end
% PcaOptions = sProcess.options.pcaedit.Value;
if nargin < 3 || isempty(PcaOptions) || isempty(sInputs)
    error('Missing inputs');
end

% Sort inputs to be able to efficiently re-use reference components.
[~, iSorted] = sort({sInputs.FileName});
sInputs = sInputs(iSorted);
% Group by subject.
iGroups = process_average('SortFiles', sInputs, AvgType); % = 2; by subject
if numel(iGroups) > 1
    % Run separately for each group, recursive call.
    for iG = 1:numel(iGroups)
        GroupOutputFiles = bst_pca(sProcess, sInputs(iGroups{iG}), PcaOptions, AtlasList, isOutMatrix, OutTimeWindow, OutComment);
        if isempty(GroupOutputFiles)
            OutputFiles = {};
            return; % Error already reported.
        end
        OutputFiles = [OutputFiles, GroupOutputFiles];
    end
    return;
end

% Run on one subject.
nInputs = numel(sInputs);

%____________________________________________________________________________________________
% Checks and initializations

% In most cases, keep full time window.  Full data file time vector needed when saving kernels.
TimeWindow = [];
if isOutMatrix && ~isempty(OutTimeWindow)
    % TimeWindow widened as needed for baseline and data, but requested OutTimeWindow reapplied when saving.
    TimeWindow = [min([PcaOptions.Baseline(1), PcaOptions.DataTimeWindow(1), OutTimeWindow(1)]), ...
        max([PcaOptions.Baseline(2), PcaOptions.DataTimeWindow(2), OutTimeWindow(2)])];
elseif ~isOutMatrix && ~isempty(OutTimeWindow)
    % Warn if requested window.
    Message = 'OutTimeWindow ignored when output is ''result'' type (isOutMatrix=false): full time returned.';
    bst_report('Warning', sProcess, sInputs, Message);
end

% Check all files are same type.
FileType = unique({sInputs.FileType});
if numel(FileType) > 1
    Message = 'Multiple file types detected.';
    bst_report('Error', sProcess, sInputs, Message);
    return;
end
% Checks for timefreq files.
if ~strcmpi(FileType, 'results')
    if ~isScout % should not occur
        Message = 'No scout list provided, and inputs are non-result files. Incompatible options for PCA.';
        bst_report('Error', sProcess, sInputs, Message);
        return;
    end
    if ~isOutMatrix
        Message = 'Inputs for scout PCA are non-result files. Output must be matrix type.';
        bst_report('Warning', sProcess, sInputs, Message);
        isOutMatrix = true;
    end
end
if isOutMatrix && ~isScout
    Message = 'Matrix output is only available for scout PCA, not flattening unconstrained sources.';
    bst_report('Warning', sProcess, sInputs, Message);
end

% Load first file. (not re-loaded later which is why we have all outputs)
[sResults, matSourceValues, matDataValues, FileComment] = process_extract_scout('LoadFile', sProcess, sInputs(1), TimeWindow);
if isempty(sResults)
    return; % Error already reported.
end
if nInputs == 1
    % No need for file in RowName
    FileComment = '';
end
isKernel = isempty(matSourceValues);

nFreq = size(matSourceValues,3);
if nFreq > 1
    Message = 'PCA not available for files with multiple frequencies.';
    bst_report('Error', sProcess, sInputs, Message);
    return;
end

% Check if unconstrained sources. 
% nComponent = 0 for mixed models and is kept unchanged. nComp is used later for different uses,
% e.g. for the actual number for each region. 
[isUnconstrained, nComponents] = process_extract_scout('CheckUnconstrained', sProcess, sInputs(1), sResults);
if isempty(isUnconstrained)
    return; % Error already reported.
end
% We now allow 3d scout PCA on unconstrained sources.
% if any(isUnconstrained) && isScout
%     Message = 'Unconstrained sources detected, flatten sources before PCA for scouts.';
%     bst_report('Error', sProcess, sInputs, Message);
%     return;
if all(~isUnconstrained) && ~isScout
    % Nothing to do.
    OutputFiles = {sInputs.FileName};
    return;
end

% Keep surface file for compatibility check on each file.
SurfaceFile = sResults.SurfaceFile;
DisplayUnits = sResults.DisplayUnits;

% Progress bar
isProgressBar = bst_progress('isVisible');
if isProgressBar
    PrevBarParams = bst_progress('getbarparams');
end
if isScout
    bst_progress('start', 'Extract scouts with PCA', sprintf('Extract scouts for %d files', nInputs), 0, 10*nInputs);
else
    bst_progress('start', 'Unconstrained to flat map', sprintf('Flattening %d files', nInputs), 0, 10*nInputs);
end

%____________________________________________________________________________________________
% Prepare scouts list, and some output fields common across files

% Build scouts list.  For flattening mixed models, it's the source regions list.  For flattening
% simple model, no list (single region).
if isScout
    ScoutFunc = 'pca2023'; % we don't use 4-letter pcaa or pcai outside this function.
    UnconstrFunc = [];
    % For scouts, we decided to keep sign flipping for all PCA methods.  For pcaa/pcai, it still
    % affects the overall sign of the reference component to be based on the geometry of the
    % region. (Without this, the sign would rather be representative of where the activity is
    % coming from, i.e. it would depend on the data.  Both choices are acceptable, but one had
    % to be picked for consistency/reproducibility, we kept the previous choice.)
    isSignFlip = true;
    [sScouts, AllAtlasNames, sSurf, isVolumeAtlas] = process_extract_scout('GetScoutsInfo', ...
        sProcess, sInputs(1), sResults.SurfaceFile, AtlasList, sResults.Atlas, ScoutFunc);
    % Selected scout function now applied in GetScoutInfo (overrides the one from the scout panel).
    if isempty(sScouts)
        return; % Error already reported.
    end
    nScouts = numel(sScouts);
    % (nComp set later for each scout using GetScoutsRow - in case we allow 3d scout PCA.)
    nComp = ones(nScouts, 1);
    % Prepare output atlas.
    % If saving a result file, it is then a deprecated atlas-based result file.
    sResultsOut.Atlas = db_template('atlas');
    if size(AtlasList,1) == 1
        sResultsOut.Atlas.Name = AllAtlasNames{1};
    else
        sResultsOut.Atlas.Name = 'process_extract_scout';
    end
    sResultsOut.Atlas.Scouts = sScouts;
else
    ScoutFunc = [];
    UnconstrFunc = 'pca2023'; % we don't use 4-letter pcaa or pcai outside this function.
    % Sign flipping does not apply to flattening unconstrained sources.
    isSignFlip = false;
    % nComponent = 0 for mixed models, nComp is used for the actual number for each region.
    if nComponents == 0
        sScouts = sResults.GridAtlas.Scouts;
        nScouts = numel(sScouts);
    else
        nScouts = 1;
    end
    % We will only use nComp for unconstrained regions, constrained ones are skipped.  But set
    % correctly here anyway for clarity.
    nComp = ones(nScouts, 1);
    nComp(isUnconstrained) = 3; % implied by GridAtlas.Scouts.Region(3) = 'U' or 'L', but not otherwise saved.
    sResultsOut.Atlas = [];
end

% History
if isScout
    % History: process name
    tmpProcess.Comment = 'Scouts time series';
    tmpProcess.options.scouts.Value = AtlasList;
    sResultsOut = bst_history('add', sResultsOut, 'process', process_extract_scout('FormatComment', tmpProcess));
    % History: Source file name added later for matrix file type.
else
    sResultsOut = bst_history('add', sResultsOut, 'flat', ['Convert unconstrained sources to a flat map with option: ' PcaOptions.Method]);
end
if ismember(PcaOptions.Method, {'pcaa', 'pcai'})
    % Add list of input files in history
    sResultsOut = bst_history('add', sResultsOut, 'compute', sprintf('PCA reference component(s) computed across %d files: ', nInputs));
    for iInput = 1:nInputs
        sResultsOut = bst_history('add', sResultsOut, 'compute', [' - ' sInputs(iInput).FileName]);
    end
end
% Comment
if ~isempty(OutComment)
    % Forced in the options
    isForceComment = true;
    sResultsOut.Comment = OutComment;
else
    isForceComment = false;
    sResultsOut.Comment = [' | ' PcaOptions.Method];
    if isScout
        % Make single string of all scout names.
        ScoutNames = {sScouts.Label};
        if ~isempty(ScoutNames) % because of use of (end), though probably never empty.
            ScoutNames(2,:) = {' '};
            ScoutNames = [ScoutNames{:}];
            ScoutNames(end) = '';
        end
        % Limit size of scout comment
        if length(ScoutNames) > 20
            sResultsOut.Comment = [sResultsOut.Comment, ' ' num2str(nScouts) ' scouts'];
        elseif ~isempty(ScoutNames)
            sResultsOut.Comment = [sResultsOut.Comment, ' scouts (' ScoutNames ')'];
        else
            sResultsOut.Comment = [sResultsOut.Comment, ' scouts'];
        end
    else
        % Flattening
        sResultsOut.Comment = [sResultsOut.Comment, ' flat'];
    end
end
% Update number of components when flattening
% (note: sResultsOut.nComponents is ignored for matrix output: no nComponents)
if ~isScout && nComponents > 1
    sResultsOut.nComponents = 1;
else
    % For mixed models, we must keep 0, even if it's flattened.
    sResultsOut.nComponents = nComponents;
end

% Initialize source space covariance, and PCA components.
if ismember(PcaOptions.Method, {'pcaa', 'pcai'})
    SourceCov = cell(nScouts, 1);
    PcaReference = cell(nScouts, 1);
end
if ismember(PcaOptions.Method, {'pca', 'pcai'})
    PcaComp = cell(nInputs, nScouts);
end
OutField = cell(nInputs, 1);
% Number of sources (xyz components counted separately) for consistency check across files.
if isKernel
    nSource = size(sResults.ImagingKernel, 1);
else
    nSource = size(matSourceValues, 1);
end
for iScout = 1:nScouts % scouts or regions of the mixed model
    if isScout
        % Get scout row indices and more.
        % Support for atlas-based & mixed model files was added in GetScoutRows.
        % Unconstrained sources: xyz are separate rows
        % sScouts.RowNames is not saved in result files (sResultsOut.Atlas already set above), but used for matrix output.
        [sScouts(iScout).iRows, sScouts(iScout).RowNames, sScouts(iScout).ScoutOrient, nComp(iScout)] = ...
            process_extract_scout('GetScoutRows', sProcess, sInputs(1), sScouts(iScout), sResults, sSurf, isVolumeAtlas(iScout), ScoutFunc);
        if isempty(sScouts(iScout).iRows)
            OutputFiles = {};
            return; % Error already reported.
        end
        % Covariance per scout, in cells.
        if ismember(PcaOptions.Method, {'pcaa', 'pcai'})
            SourceCov{iScout} = zeros(numel(sScouts(iScout).iRows) / nComp(iScout));
        end
    else % flattening
        if nComponents == 0
            % Convert to indices in the source matrix
            sScouts(iScout).iRows = bst_convert_indices(sScouts(iScout).GridRows, nComponents, sResults.GridAtlas, 0);
        else 
            % Only 1 region, all rows
            sScouts(iScout).iRows = 1:nSource;
        end
        % If no vertices to read from this region: skip
        if isempty(sScouts(iScout).iRows)
            isUnconstrained(iScout) = false;
        end
        if isUnconstrained(iScout) && ismember(PcaOptions.Method, {'pcaa', 'pcai'})
            % Covariance by region for mixed model, in cells; one cell for simple models.
            SourceCov{iScout} = zeros(nComp(iScout), nComp(iScout), numel(sScouts(iScout).iRows) / nComp(iScout));
        end
    end
end
if isScout
    % Output row numbers is more complicated if allowing unconstrained (and therefore mixed models)
    iOutRow = cumsum(nComp);
    %nOutRow = iOutRow(end);
    iOutRow = [iOutRow - nComp(1) + 1, iOutRow];
end

% Atlas-based files: no PCA needed.
% GetScoutRows already checked that scout function was PCA (in first file).
% Warn and return input files.
if isScout && ~isempty(sResults.Atlas)
    Message = 'Scout PCA already present in first input file. Returning all inputs unchanged.';
    bst_report('Warning', sProcess, sInputs, Message);
    OutputFiles = {sInputs.FileName};
    return;
end

%____________________________________________________________________________________________
% First loop over files for 2 reasons: for pcaa and pcai we accumulate covariances in source
% space (NxN for scouts or 3x3 xyz covariance matrices) across files for the reference
% components, and for pca and pcai we compute individual file PCA components. This however means
% that for pcai we have to correct the sign of components in a second loop in this function
% instead of in bst_scout_value.
for iInput = 1:nInputs
    % Load file (except first which was loaded before loop)
    if iInput > 1
        [sResults, matSourceValues, matDataValues, FileComment] = process_extract_scout('LoadFile', sProcess, sInputs(iInput), TimeWindow);
        if isempty(sResults)
            OutputFiles = {};
            return; % Error already reported.
        end
        isKernel = isempty(matSourceValues);
    end
    % Do some basic compatibility checks.  While these are not required for old per-file 'pca'
    % method, probably good to flag these and require users to run separately for files with
    % different dimensions, surfaces or units.
    if (isfield(sResults, 'nComponents') && nComponents ~= sResults.nComponents) || ...
            (isKernel && nSource ~= size(sResults.ImagingKernel, 1)) || (~isKernel && nSource ~= size(matSourceValues, 1))
        Message = 'Incompatible result dimensions (number of sources or orientations).';
        bst_report('Error', sProcess, sInputs, Message);
        OutputFiles = {};
        return;
    elseif ~isempty(SurfaceFile) && ~strcmpi(SurfaceFile, sResults.SurfaceFile)
        Message = 'Incompatible result files from different surfaces.';
        bst_report('Error', sProcess, sInputs, Message);
        OutputFiles = {};
        return;
    elseif ~isempty(DisplayUnits) && ~isempty(sResults.DisplayUnits) && ~strcmpi(DisplayUnits, sResults.DisplayUnits) 
        % Could accept mixed units if not combining files, but not if concatenating.
        Message = 'Incompatible result files with different units.';
        bst_report('Error', sProcess, sInputs, Message);
        OutputFiles = {};
        return;
    end
    if isKernel
        % Compute data covariance for this file only.
        DataCov = ComputeCovariance(matDataValues(sResults.GoodChannel,:), sResults.Time, PcaOptions);
        %DataCov = GetDataCovariance(sResults.DataFile, PcaOptions, sInputs(iInput).iStudy);
        % Copy kernel for convenience, used when applying the PCA components.
        matSourceValues = sResults.ImagingKernel;
    end
    for iScout = 1:nScouts
        % Skip regions that don't need flattening.
        if ~isScout && ~isUnconstrained(iScout)
            continue;
        end
        % Get source covariance
        if isKernel
            if isScout
                % add K * DataCov * K' with appropriate kernel rows for this scout
                % Sum over xyz in case we allow 3d scout PCA.
                FileSourceCov{iScout} = zeros(numel(sScouts(iScout).iRows) / nComp(iScout));
                for i = 1:nComp(iScout)
                    Kernel = sResults.ImagingKernel(sScouts(iScout).iRows(i:nComp(iScout):end), :);
                    FileSourceCov{iScout} = FileSourceCov{iScout} + Kernel * DataCov * Kernel';
                end
            else
                nVert = numel(sScouts(iScout).iRows) / nComp(iScout);
                Kernel = permute(reshape(sResults.ImagingKernel(sScouts(iScout).iRows, :), nComp(iScout), nVert, []), [2, 3, 1]); % (nVert, nChan, nComp)
                % For each source (each 3 rows of ImagingKernel), get K * Cov * K' -> [3 x 3]
                % For efficiency, loop on components instead of sources.
                tmpFileSourceCov = zeros([1, nComp(iScout), nVert, size(Kernel,2)]);
                for i = 1:nComp(iScout)
                    tmpFileSourceCov(1,i,:,:) = Kernel(:,:,i) * DataCov;
                end
                % Permuted Kernel: (nComp, 1, nVert, nChan), FileSourceCov: (1, nComp, nVert, nChan)
                FileSourceCov{iScout} = sum(bsxfun(@times, permute(Kernel, [3,4,1,2]), tmpFileSourceCov), 4); % (nComp, nComp, nVert)
            end
        else % no kernel
            FileSourceCov{iScout} = ComputeCovariance(matSourceValues(sScouts(iScout).iRows, :), sResults.Time, PcaOptions, nComp(iScout), isScout);
        end
        % Accumulate source covariance
        if ismember(PcaOptions.Method, {'pcaa', 'pcai'})
            SourceCov{iScout} = SourceCov{iScout} + FileSourceCov{iScout};
        end
    end % scouts loop

    % Main values array field name
    if isOutMatrix % forced for timefreq inputs
        OutField{iInput} = 'Value';
    elseif isKernel
        OutField{iInput} = 'ImagingKernel';
    else % not link
        OutField{iInput} = 'ImageGridAmp';
    end

    % Use single file covariance(s) to get single file PCA component(s). Full or kernel.
    if ismember(PcaOptions.Method, {'pca', 'pcai'})
        if isScout
            sResults.(OutField{iInput}) = zeros(nScouts, size(matSourceValues, 2));
            HistoryMsg = cell(nScouts,1);
            for iScout = 1:nScouts
                % To allow 3d scout PCA: more than one row returned.
                [sResults.(OutField{iInput})(iOutRow(iScout,1):iOutRow(iScout,2), :), PcaComp{iInput, iScout}, HistoryMsg(iScout)] = ...
                    bst_scout_value(matSourceValues(sScouts(iScout).iRows, :), ScoutFunc, sScouts(iScout).ScoutOrient, ...
                    nComp(iScout), UnconstrFunc, isSignFlip, sScouts(iScout).Label, FileSourceCov{iScout}); % PcaReference not yet available
            end
            % Project data if we want to save timeseries
            if isKernel && isOutMatrix
                sResults.(OutField{iInput}) = sResults.(OutField{iInput}) * matDataValues(sResults.GoodChannel,:);
            end
        else
            % Flattening is done for whole file at once even for mixed models.
            [sResults.(OutField{iInput}), sResults.GridAtlas, ~, PcaComp{iInput, :}, HistoryMsg] = bst_source_orient([], ...
                nComponents, sResults.GridAtlas, matSourceValues, UnconstrFunc, [], [], FileSourceCov); % PcaReference not yet available
        end

        % Save individual files.  We still need to correct the sign later for pcai.
        sResults = MergeFields(sInputs(iInput), sResults, sResultsOut, isForceComment, isOutMatrix);
        % Add kept variance to history.
        for iH = 1:numel(HistoryMsg) % can have multiple when flattening mixed head models
            sResults = bst_history('add', sResults, 'compute', HistoryMsg{iH});
        end
        if isOutMatrix % forced for timefreq inputs
            OutputFiles{iInput} = SaveMatrixFile(sInputs(iInput), sResults, PcaOptions.Method, cat(1, sScouts.RowNames), FileComment, OutTimeWindow);
        else
            % Save single-file result file, full or kernel. For scouts, this is a deprecated
            % atlas-based result file, meant only to be used temporarily and then deleted by the
            % calling process.
            OutputFiles{iInput} = SaveResultFile(sInputs(iInput), sResults, PcaOptions.Method);
        end
    end
    if strcmpi(PcaOptions.Method, 'pca')
        % Only one file loop for old pca method.
        bst_progress('inc', 10);
    else
        bst_progress('inc', 9);
    end
end % first file loop

%____________________________________________________________________________________________
% Compute reference components across files.
if ismember(PcaOptions.Method, {'pcaa', 'pcai'})
    % Divide summed covariance by number of files. While this is not the optimal way to compute a
    % "real" covariance across files, it is fine for PCA - or we could even skip this: the absolute
    % scale of the matrix has no effect because we only keep the unit norm components.
    for iScout = 1:nScouts
        SourceCov{iScout} = SourceCov{iScout} / nInputs;
    end

    if isScout
        HistoryMsg = {};
        for iScout = 1:nScouts
            [~, PcaReference{iScout}, HistoryMsgTmp] = bst_scout_value([], ...
                ScoutFunc, sScouts(iScout).ScoutOrient, nComp(iScout), UnconstrFunc, isSignFlip, sScouts(iScout).Label, SourceCov{iScout});
            % PcaReference{iScout} is size [Nsources, 1]
            HistoryMsg = cat(1, HistoryMsg, HistoryMsgTmp(:));
        end
    else
        [~, ~, ~, PcaReference, HistoryMsg] = bst_source_orient([], ...
            nComponents, sResults.GridAtlas, [], UnconstrFunc, [], [], SourceCov);
        % Convert to cell for convenience when simple model.
        if ~iscell(PcaReference)
            PcaReference = {PcaReference};
        end
        % PcaReference{iScout} is size [3, Nsources]
    end
end

% Add kept variance to history. Only pcaa; for pcai we save the per-file value instead.
if strcmpi(PcaOptions.Method, 'pcaa') && nInputs > 1
    for iH = 1:numel(HistoryMsg) % can have multiple when flattening mixed head models
        % Clarify that this value is for the reference component, across all files.
        sResultsOut = bst_history('add', sResultsOut, 'compute', [HistoryMsg{iH}(1:end-1) ' on average across files.']);
    end
end

%____________________________________________________________________________________________
% Apply PCA reference to individual files
switch PcaOptions.Method
    % pcai: correct signs.  This is named sign "correction" consistently to distinguish from the
    % sign "flipping" based on constrained orientations which is done before computing PCA.
    case 'pcai'
        for iInput = 1:nInputs
            % Which scouts/sources need sign correction?  Check before loading file.
            isSignCorrect = false(0);
            for iScout = 1:nScouts
                % Skip untouched regions of mixed model.
                if ~isScout && ~isUnconstrained(iScout)
                    isSignCorrect = [isSignCorrect, false(1, numel(sScouts(iScout).iRows))];
                else
                    % Project component onto reference, by columns (multiple when flattening)
                    isSignCorrect = [isSignCorrect, sum(bsxfun(@times, PcaReference{iScout}, PcaComp{iInput, iScout}), 1) < 0];
                end
            end
            % No correction needed.
            if ~any(isSignCorrect)
                continue;
            end
            % Load file.  Cannot be a shared kernel here.
            sOut = load(file_fullpath(OutputFiles{iInput}));
            % Correct signs.
            sOut.(OutField{iInput})(isSignCorrect, :) = -sOut.(OutField{iInput})(isSignCorrect, :);
            % Save file.
            bst_save(file_fullpath(OutputFiles{iInput}), sOut, 'v6');

            bst_progress('inc', 1);
        end

    % pcaa: project sources (possibly kernel) with common reference components.
    case 'pcaa'
        PrevCond = '';
        isOutSharedKernel = false;
        for iInput = 1:nInputs
            % If saving shared kernels, only one per condition (files already sorted).
            if ~isOutMatrix && ~strcmp(sInputs(iInput).Condition, PrevCond) %&& ~strcmp(sInputs(iInput).SubjectName, PrevSub)
                % We just changed condition.
                PrevCond = sInputs(iInput).Condition;
                % Check if all files from this condition are kernel links.
                isOutSharedKernel = true;
                for iIn = iInput:nInputs
                    if ~strcmp(sInputs(iIn).Condition, PrevCond)
                        % Reached end of this condition.
                        break;
                    end
                    if ~strcmpi(file_gettype(sInputs(iIn).FileName), 'link')
                        isOutSharedKernel = false;
                        break;
                    end
                end
            elseif isOutSharedKernel % implies ~isOutMatrix and same condition
                % Already saved a flattened version of this kernel.
                % Find new link for this data file.
                OutputFiles{iInput} = FindLinkFile(sInputs(iInput).DataFile, SharedFile, LinkFiles); %#ok<*AGROW>
                if isempty(OutputFiles{iInput})
                    Message = ['Problem finding the correct linked file for ' sInputs(iInput).DataFile];
                    bst_report('Error', sProcess, sInputs, Message);
                    OutputFiles = {};
                    return;
                end
                bst_progress('inc', 1);
                continue;
            end

            % Load file
            [sResults, matSourceValues, matDataValues, FileComment] = process_extract_scout('LoadFile', sProcess, sInputs(iInput), TimeWindow);
            isKernel = isempty(matSourceValues);
            if isKernel
                % Copy kernel for convenience.
                matSourceValues = sResults.ImagingKernel;
            end
            % Apply PCA components
            if isScout
                sResults.(OutField{iInput}) = zeros(nScouts, size(matSourceValues, 2));
                for iScout = 1:nScouts
                    for i = 1:nComp(iScout)
                        sResults.(OutField{iInput})(iOutRow(iScout,1)+i-1, :) = PcaReference{iScout}' * matSourceValues(sScouts(iScout).iRows(i:nComp(iScout):end), :);
                    end
                end
                % Project data if we want to save timeseries
                if isKernel && isOutMatrix
                    sResults.(OutField{iInput}) = sResults.(OutField{iInput}) * matDataValues(sResults.GoodChannel,:);
                end
            else
                % TODO: Might be better to keep this simple projection as a subfunction here.
                % But easier for now to let source_orient deal with mixed models.  But this is
                % the only place where a 4-letter pca method 'pcaa' is used ouside bst_pca.
                [sResults.(OutField{iInput}), sResults.GridAtlas] = bst_source_orient([], ...
                    nComponents, sResults.GridAtlas, matSourceValues, 'pcaa', [], [], [], PcaReference);
            end
            % (The number of components for output is already updated in sResultsOut.)

            % Save individual files, or shared kernel.
            sResults = MergeFields(sInputs(iInput), sResults, sResultsOut, isForceComment, isOutMatrix);
            if isOutMatrix % forced for timefreq inputs
                OutputFiles{iInput} = SaveMatrixFile(sInputs(iInput), sResults, PcaOptions.Method, cat(1, sScouts.RowNames), FileComment, OutTimeWindow);
            elseif isOutSharedKernel
                % Save shared kernel and find link.  We only get here for the first file in this
                % condition.
                [OutputFiles{iInput}, SharedFile, LinkFiles] = SaveKernelFile(sInputs(iInput), sResults, PcaOptions.Method);
                if isempty(OutputFiles{iInput})
                    Message = ['Problem finding the correct linked file for ' sInputs(iInput).DataFile];
                    bst_report('Error', sProcess, sInputs, Message);
                    OutputFiles = {};
                    return;
                end
            else
                % Save single-file result file, full or kernel. For scouts, this is a deprecated
                % atlas-based result file, meant only to be used temporarily and then deleted by the
                % calling process.
                OutputFiles{iInput} = SaveResultFile(sInputs(iInput), sResults, PcaOptions.Method);
            end

            bst_progress('inc', 1);
        end
end

if isProgressBar
    bst_progress('setbarparams', PrevBarParams);
else
    % Hide.
    bst_progress('stop');
end

% Don't update the tree here since the files may be temporary (e.g. flattening from process_extract_scout).
%     panel_protocols('UpdateNode', 'Study', unique([sInputs.iStudy]));
end

%____________________________________________________________________________________________
%% ===== SUBFUNCTIONS =====

% ===== Compute data covariance from one file =====
% function DataCov = GetDataCovariance(DataFile, Options, iStudy)
%     % Find data file index.
%     [~, ~, iData] = bst_get('DataFile', DataFile, iStudy);
%     CovMat = bst_noisecov(iStudy, iStudy, iData, Options, true, false); % isDataCov=true, isSave=false
%     DataCov = CovMat.NoiseCov;
% end

% ===== COMPUTE COVARIANCE =====
% Compute covariance from loaded data or sources.
% Since we have to do it here for sources, we use this functyion for data as well for efficiency instead of calling bst_noisecov.
% If nComp is 3 (unconstrained sources) and isScout=false, it returns a 3x3xN xyz covariances array, otherwise NxN.
% For nComp=3 and isScout=true, N is the number of vertices: we sum over separate x,y,z covariances.
function Cov = ComputeCovariance(Mat, Time, Options, nComp, isScout)
    if nargin < 5 || isempty(isScout)
        isScout = false;
    end
    if nargin < 4 || isempty(nComp)
        nComp = 1;
    end
    % Get times that are considered as baseline
    if isempty(Time)
        iTimeBaseline = [];
    elseif ~isempty(Options.Baseline)
        iTimeBaseline = panel_time('GetTimeIndices', Time, Options.Baseline);
    else
        iTimeBaseline = 1:length(Time);
    end
    % Get the time indices on which to compute the covariance
    if isempty(Time)
        iTimeCov = [];
    elseif ~isempty(Options.DataTimeWindow)
        iTimeCov = panel_time('GetTimeIndices', Time, Options.DataTimeWindow);
    else
        iTimeCov = 1:length(Time);
    end
    if strcmpi(Options.RemoveDcOffset, 'file')
        % Average baseline values
        SourceAvg = mean(Mat(:,iTimeBaseline), 2);
        % Remove average
        Mat = bst_bsxfun(@minus, Mat, SourceAvg);
    end

    % Compute covariance for this file
    if nComp == 1
        Cov = Mat(:,iTimeCov) * Mat(:,iTimeCov)';
    elseif isScout 
        % Sum over separate x,y,z covariances
        nVert = size(Mat, 1) / nComp;
        Cov = zeros(nVert);
        for iC = 1:nComp
            Cov = Cov + (Mat(iC:nComp:end, iTimeCov) * Mat(iC:nComp:end, iTimeCov)');
        end
    else % 3x3 orient cov
        nVert = size(Mat, 1) / nComp;
        % Loop over component pairs to get covariance
        Mat = permute(reshape(Mat(:,iTimeCov), nComp, nVert, []), [2, 3, 1]); % (nVert, nTime, nComp)
        Cov = zeros(nComp, nComp, nVert);
        for iC1 = 1:nComp
            for iC2 = iC1:nComp
                Cov(iC1,iC2,:) = sum(Mat(:, :, iC1) .* Mat(:, :, iC2), 2);
                if iC2 ~= iC1
                    % Fill symmetric matrix entries.
                    Cov(iC2,iC1,:) = Cov(iC1,iC2,:);
                end
            end
        end
    end
    % Divide by number of samples - 1.  Note that for PCA, this is not necessary: sum of power would
    % give the same result.
    if ~isempty(Cov) % avoid /0 if empty time window
        Cov = Cov / (numel(iTimeCov) - 1);
    end
end

%____________________________________________________________________________________________
% ===== SAVE FILE =====
function sResults = MergeFields(sInput, sResults, sResultsOut, isForceComment, isOutMatrix)
    % Copy fields that were prepared, common to all files.
    % History
    sResults = bst_history('add', sResults, sResultsOut.History);
    % Comment
    if isForceComment
        sResults.Comment = sResultsOut.Comment;
    elseif isOutMatrix
        % Append to original comment.
        sResults.Comment = [sResults.Comment sResultsOut.Comment];
    else % result
        % Replace with results comment. (LoadFile changed it to the data file comment for matrix output)
        sResults.Comment = [sInput.Comment sResultsOut.Comment];
    end
    % Atlas
    sResults.Atlas = sResultsOut.Atlas;
    % Components
    sResults.nComponents = sResultsOut.nComponents;
end

function OutputFile = SaveMatrixFile(sInput, sResults, Method, ScoutRowNames, FileComment, OutTimeWindow)
    % Create output structure
    sMatrix = db_template('matrixmat');
    % List of fields to copy from sResults to new matrix file.
    Fields = {'Value', 'Atlas', 'Time', 'SurfaceFile', 'DisplayUnits', 'nAvg', 'Leff', 'ChannelFlag', 'History', 'Comment'};
    for iF = 1:numel(Fields)
        if isfield(sResults, Fields{iF}) && ~isempty(sResults.(Fields{iF}))
            sMatrix.(Fields{iF}) = sResults.(Fields{iF});
        end
    end
    % Description: cell array of 'ScoutName[.Vert][.Comp][ @ File]' strings. 
    if ~isempty(FileComment)
        ScoutRowNames = cellfun(@(c) [c ' @ ' FileComment], ScoutRowNames, 'UniformOutput', false);
    end
    sMatrix.Description = ScoutRowNames;
    % History: File name
    sMatrix = bst_history('add', sMatrix, 'src', ['PCA applied to file: ' sInput.FileName]);

    % Adjust output time window as requested.
    if ~isempty(OutTimeWindow)
        % Get time indices
        iTime = panel_time('GetTimeIndices', sResults.Time, OutTimeWindow);
        if isempty(iTime)
            bst_report('Error', 'bst_pca', sInput, 'Invalid time window option, keeping full window used for PCA.');
        elseif iTime(1) > 1 || iTime(end) < numel(sResults.Time)
            if (length(iTime) == 1)
                % If only one time point selected: double it
                iTime = [iTime, iTime];
            end
            % Keep only the requested time window
            if ~isempty(sMatrix.Value)
                sMatrix.Value = sMatrix.Value(:,iTime,:);
            end
            sMatrix.Time = sMatrix.Time(iTime);
            % If there are only two time points, make sure they are not identical
            if (length(sMatrix.Time) == 2) && sMatrix.Time(2) == sMatrix.Time(1)
                sMatrix.Time(2) = sMatrix.Time(1) + 0.001;
            end
        end
    end

    % Output study = input study
    sStudy = bst_get('Study', sInput.iStudy);
    % Output filename
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['matrix_scout_' Method]);
    % Save on disk
    bst_save(OutputFile, sMatrix, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, OutputFile, sMatrix);
end

function OutputFile = SaveResultFile(sInput, sResults, Method)
    % Verify and fix GridAtlas for atlas-based files
    if ~isempty(sResults.GridAtlas) || sResults.nComponents == 0
        sResults = process_extract_scout('FixAtlasBasedGrid', [], sInput, sResults);
    end
    % Get study description
    sStudy = bst_get('Study', sInput.iStudy);
    % File tag
    if ~isempty(strfind(sInput.FileName, '_abs_zscore'))
        FileType = 'results_abs_zscore';
    elseif ~isempty(strfind(sInput.FileName, '_zscore'))
        FileType = 'results_zscore';
    else
        FileType = 'results';
    end
    % Output filename
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [FileType '_' Method]);
    % Save on disk
    bst_save(OutputFile, sResults, 'v6');
    % Register in database.  This also makes the Comment unique for this data file.
    db_add_data(sInput.iStudy, OutputFile, sResults);
end

function [OutputFile, SharedFile, LinkFiles] = SaveKernelFile(sInput, sResults, Method)
    sResults.DataFile = '';
    % Keep original kernel file name, but ensure unique.
    [KernelPath, KernelName] = bst_fileparts(file_resolve_link(sInput.FileName));
    iK = strfind(KernelName, '_KERNEL_');
    SharedFile = bst_process('GetNewFilename', KernelPath, [KernelName(1:iK) 'KERNEL_' Method]);
    bst_save(SharedFile, sResults, 'v6');
    db_add_data(sInput.iStudy, SharedFile, sResults);
    %panel_protocols('UpdateNode', 'Study', sInput.iStudy);
    % Find link to the result kernel that was just created for this data file.
    LinkFiles = db_links('Study', sInput.iStudy);
    OutputFile = FindLinkFile(sInput.DataFile, SharedFile, LinkFiles);
end

function OutputFile = FindLinkFile(DataFile, SharedFile, LinkFiles)
    iLink = ~cellfun(@isempty, strfind(LinkFiles, [file_short(SharedFile) '|' DataFile]));
    if sum(iLink) ~= 1
        OutputFile = '';
    else
        OutputFile = LinkFiles{iLink};
    end
end

