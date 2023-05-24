function [SourceValues, GridAtlas, RowNames, PcaOrient, HistoryMsg] = bst_source_orient(iVertices, nComponents, GridAtlas, SourceValues, Function, DataType, RowNames, OrientCov, PcaOrient)
% BST_SOURCE_ORIENT: Constrain source orientation for an unconstrained or mixed source model.
%
% USAGE:  [SourceValues, GridAtlas, RowNames, PcaOrient, HistoryMsg] = bst_source_orient(iVertices=[], nComponents, ...
%                   GridAtlas, SourceValues, Function, DataType=[], RowNames=[], OrientCov=[], PcaOrient=[])
%
% INPUT: 
%    - iVertices    : Array of vertex indices of the source space, to reference to rows in Results.GridLoc (volume) or Surface.Vertices (surface)
%                     If empty, use all the vertices
%    - nComponents  : Number of entries per vertex in SourceValues (1,2,3)
%                     If 0, the number varies, the properties of each region are defined in input GridAtlas
%    - GridAtlas    : Set of scouts that defines the properties of the source space regions, when nComponents=0
%                     GridAtlas.Scouts(i).Region(2) is the source type (V=volume, S=surface, D=dba, X=exclude)
%                     GridAtlas.Scouts(i).Region(3) is the orientation constrain (U=unconstrained, C=contrained, L=loose)
%    - SourceValues : [Nvertices*nComponents x Nsensors] or [Nvertices*nComponents x Ntime], source values
%    - Function     : Name of the function to apply to group multiple components {'sum', 'sum_power', 'rms', 'max', 'pca', 'pca2023', 'pcaa', 'mean'}
%    - DataType     : Type of data being processed {'data', 'results', 'scouts', 'matrix'}
%    - RowNames     : Description of signals being processed: {empty, array of doubles, array of cells}
%    - OrientCov    : [3 x 3 x Nvertices] Covariance between 3 rows of SourceValues (3 source orientations) at each vertex, pre-computed from one or more epochs.
%                     For mixed models: cell array of such covariance, for each region.
%    - PcaOrient    : [3 x Nvertices] Reference PCA components computed across epochs, used to pick consistent sign for each epoch.
%                     For mixed models: cell array of such components, for each region.
%
% OUTPUT: 
%    - SourceValues : Constrained source values
%    - GridAtlas    : Modified atlas (unconstrained regions transformed into constrained regions)
%    - RowNames     : Description of the new list of signals
%    - PcaOrient    : [3 x Nvertices] Direction vector of the first mode of the PCA, for each source
%                     For mixed models: cell array of such components, for each region.
%    - HistoryMsg   : For PCA, indication of kept variance in 1st principal component(s), as a cell array of strings.
%                     this is computed with the PCA options (PCA time window and possibly DC offset
%                     on baseline), which may differ from the data on which the component is later applied.

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
% Authors: Francois Tadel, 2014-2022
%          Marc Lalancette, 2022

% Parse inputs
if (nargin < 9) || isempty(PcaOrient)
    PcaOrient = [];
end
if (nargin < 8) || isempty(OrientCov)
    OrientCov = [];
end
if (nargin < 7) || isempty(RowNames)
	RowNames = [];
end
if (nargin < 6) || isempty(DataType)
	DataType = [];
end
if (nargin < 5) || isempty(Function)
	Function = 'none';
end
if (nargin < 4) || isempty(SourceValues)
	SourceValues = [];
end
if (nargin < 3) || isempty(GridAtlas)
	GridAtlas = [];
end
if (nargin < 2) || isempty(nComponents)
	error('Invalid call');
end

HistoryMsg = {};
% === MIXED SOURCE MODELS ===
% iVertices is assumed to be grid rows here, NOT surface vertices.
if (nComponents == 0)
    % Check that GridAtlas is defined
    if isempty(GridAtlas) || ~isfield(GridAtlas, 'Scouts') || ~isfield(GridAtlas.Scouts, 'Vertices')
        error('GridAtlas variable is empty');
    end
    nScouts = length(GridAtlas.Scouts);
    % Convert empty PCA-specific variables for convenience (for mixed models).
    if isempty(OrientCov) || ~strncmpi(Function, 'pca', 3)
        OrientCov = cell(nScouts, 1);
    elseif ~iscell(OrientCov) || length(OrientCov) ~= nScouts
        error('OrientCov size incompatible with GridAtlas.');
    end
    if isempty(PcaOrient) || ~strncmpi(Function, 'pca', 3)
        PcaOrient = cell(nScouts, 1);
    elseif ~iscell(PcaOrient) || length(PcaOrient) ~= nScouts
        error('PcaOrient size incompatible with GridAtlas.');
    end
    % Initialize blocks of indices
    SourceBlocks = {};
    RowNamesBlocks = {};
    iSourceBlocks = {};
    % Loop on all the regions
    for iScout = 1:nScouts
        % Get the vertices for this scouts
        if ~isempty(iVertices)
            iVertGrid = intersect(iVertices, GridAtlas.Scouts(iScout).GridRows);
        elseif ~isempty(SourceValues)
            iVertGrid = GridAtlas.Scouts(iScout).GridRows;
        elseif ~isempty(OrientCov{1})
            % For PCA, we don't always need to project values, e.g. for reference component.
            iVertGrid = [];
        else
            error('SourceValues and OrientCov should not both be empty.');
        end
        if ~isempty(iVertGrid)
            % Convert to indices in the source matrix
            iVertSource = bst_convert_indices(iVertGrid, nComponents, GridAtlas, 0);
        else
            iVertSource = [];
        end
        % If no vertices to read from this region: skip
        if isempty(iVertSource) && isempty(OrientCov{1})
            continue;
        end
        % Get correpsonding row indices based on the type of region (constrained or unconstrained)
        switch (GridAtlas.Scouts(iScout).Region(3))
            case 'C'
                SourceBlocks{end+1} = SourceValues(iVertSource,:,:,:);
                if ~isempty(RowNames) && iscell(RowNames)
                    RowNamesBlocks{end+1} = RowNames(iVertSource)';
                end
                iSourceBlocks{end+1} = iVertSource;
            case {'U','L'}
                % Apply grouping function
                [SourceBlocks{end+1}, PcaOrient{iScout}, tmpHistoryMsg] = ApplyFunction(SourceValues(iVertSource,:,:,:), 1:3:length(iVertSource), 2:3:length(iVertSource), 3:3:length(iVertSource), ...
                    Function, OrientCov{iScout}, PcaOrient{iScout});
                % Collect PCA "kept variance" messages
                if ~isempty(tmpHistoryMsg)
                    HistoryMsg = cat(1, HistoryMsg, tmpHistoryMsg);
                    % Add region name
                    HistoryMsg{end} = [HistoryMsg{end}(1:end-1) ' in ' GridAtlas.Scouts(iScout).Label '.'];
                end
                % If the row names are defined
                if ~isempty(RowNames) && iscell(RowNames)
                    RowNamesBlocks{end+1} = RemoveComponentTag(DataType, reshape(RowNames,1,[]), size(SourceBlocks{end},1), iVertSource);
                end
                iSourceBlocks{end+1} = iVertSource(1:3:end);
                % Set that the region is now constrained
                GridAtlas.Scouts(iScout).Region(3) = 'C';
            otherwise
                error(['Invalid region "' GridAtlas.Scouts(iScout).Region '"']);
        end
    end
    % Concatenate all the blocks together
    SourceValues = cat(1, SourceBlocks{:});
    if ~isempty(RowNamesBlocks)
        RowNames = cat(2, RowNamesBlocks{:});
    end
    % Modify the grid/row correspondance matrix
    if ~isempty(GridAtlas.Grid2Source)
        GridAtlas.Grid2Source = GridAtlas.Grid2Source(cat(2, iSourceBlocks{:}), :);
        %         GridAtlas.Grid2Source = speye(size(SourceValues,1));
    end
    
    
% === SIMPLE SOURCE MODELS ===
else
    % Remove enclosing cells from PCA-specific variables.
    if iscell(OrientCov) && strncmpi(Function, 'pca', 3)
        if length(OrientCov) > 1
            error('Unexpected multi-cell OrientCov for simple source model.');
        end
        OrientCov = OrientCov{1};
    end
    if iscell(PcaOrient) && strncmpi(Function, 'pca', 3)
        if length(PcaOrient) > 1
            error('Unexpected multi-cell PcaOrient for simple source model.');
        end
        PcaOrient = PcaOrient{1};
    end
    % Select only a few vertices
    if ~isempty(iVertices)
        % Convert to indices in the source matrix
        % The last two arguments are not used in this case (not mixed model).
        iVertSource = bst_convert_indices(iVertices, nComponents, GridAtlas, 0);
    else
        iVertSource = 1:size(SourceValues,1);
    end
    % Group all the components
    switch (nComponents)
        case 1
            % Keep only the vertices of interest
            SourceValues = SourceValues(iVertSource,:,:,:);
        case 2
            % Apply grouping function
            [SourceValues, PcaOrient, HistoryMsg] = ApplyFunction(SourceValues(iVertSource,:,:,:), 1:2:length(iVertSource), 2:2:length(iVertSource), [], ...
                Function, OrientCov, PcaOrient);
            % If the row names are defined
            if ~isempty(RowNames) && iscell(RowNames)
                RowNames = RemoveComponentTag(DataType, reshape(RowNames,1,[]), size(SourceValues,1), iVertSource);
            end
        case 3
            % Apply grouping function
            [SourceValues, PcaOrient, HistoryMsg] = ApplyFunction(SourceValues(iVertSource,:,:,:), 1:3:length(iVertSource), 2:3:length(iVertSource), 3:3:length(iVertSource), ...
                Function, OrientCov, PcaOrient);
            % If the row names are defined
            if ~isempty(RowNames) && iscell(RowNames)
                RowNames = RemoveComponentTag(DataType, reshape(RowNames,1,[]), size(SourceValues,1), iVertSource);                
            end
    end
end

% Numeric row names: just number the new signals
if ~isempty(RowNames) && ~iscell(RowNames)
    RowNames = 1:size(SourceValues,1);
end

end


%% ====== APPLY FUNCTION =====
function [Values, PcaOrient, HistoryMsg] = ApplyFunction(Values, i1, i2, i3, Function, OrientCov, PcaOrient)
    HistoryMsg = {};
    switch (Function)
        case 'max'
            if ~isempty(i3)
                Values = max(cat(5, Values(i1,:,:,:), Values(i2,:,:,:), Values(i3,:,:,:)), [], 5);
            else
                Values = max(cat(5, Values(i1,:,:,:), Values(i2,:,:,:)), [], 5);
            end
        case 'min'
            if ~isempty(i3)
                Values = min(cat(5, Values(i1,:,:,:), Values(i2,:,:,:), Values(i3,:,:,:)), [], 5);
            else
                Values = min(cat(5, Values(i1,:,:,:), Values(i2,:,:,:)), [], 5);
            end
        case 'absmax'
            if ~isempty(i3)
                Values = bst_max(cat(5, Values(i1,:,:,:), Values(i2,:,:,:), Values(i3,:,:,:)), 5);
            else
                Values = bst_max(cat(5, Values(i1,:,:,:), Values(i2,:,:,:)), 5);
            end
        case 'mean'
            if ~isempty(i3)
                Values = (Values(i1,:,:,:) + Values(i2,:,:,:) + Values(i3,:,:,:)) / 3;
            else
                Values = (Values(i1,:,:,:) + Values(i2,:,:,:)) / 2;
            end
        case 'sum'
            if ~isempty(i3)
                Values = Values(i1,:,:,:) + Values(i2,:,:,:) + Values(i3,:,:,:);
            else
                Values = Values(i1,:,:,:) + Values(i2,:,:,:);
            end
        case 'rms'
            if ~isempty(i3)
                Values = sqrt(Values(i1,:,:,:).^2 + Values(i2,:,:,:).^2 + Values(i3,:,:,:).^2);
            else
                Values = sqrt(Values(i1,:,:,:).^2 + Values(i2,:,:,:).^2);
            end
        case 'sum_power'
            if ~isempty(i3)
                Values = abs(Values(i1,:,:,:)).^2 + abs(Values(i2,:,:,:)).^2 + abs(Values(i3,:,:,:)).^2;
            else
                Values = abs(Values(i1,:,:,:)).^2 + abs(Values(i2,:,:,:)).^2;
            end
        case {'pca', 'pca2023', 'pcaa'}
            % Values could be empty here. 
            if ~isempty(PcaOrient)
                nComp = size(PcaOrient, 1);
            elseif ~isempty(OrientCov)
                nComp = size(OrientCov, 1);
            elseif ~isempty(i3)
                nComp = 3;
            else
                nComp = 2;
            end
            % Shortcut if reference component already computed: just project the values.
            if strcmp(Function, 'pcaa') && ~isempty(PcaOrient)
                % This works for kernel or timeseries.
                % We reshape Values to [nSource, (nTime or nChan), nComp]  and
                % PcaOrient to [nSource, 1, nComp]  and then multiply them.
                Values = sum(bsxfun( @times, ...
                    permute(reshape(Values, nComp, size(PcaOrient, 2), []), [2, 3, 1]), ...
                    permute(PcaOrient, [2, 3, 1]) ), 3); % [nSource, (nTime or nChan)]
                % We don't compute the kept variance for this one file; HistoryMsg stays empty here.
                % What's saved in history (elsewhere) is for the reference component across all files. 
            % Compute and project on first PCA orientation at each location.
            else
                [Values, PcaOrient, HistoryMsg] = bst_scout_value(Values, 'none', [], nComp, Function, 0, [], OrientCov, PcaOrient);
            end
        case 'none'
            % Nothing to do
        otherwise
            error(['Invalid function "' Function '".']);
    end
end


%% ===== REMOVE COMPONENT TAG =====
function RowNames = RemoveComponentTag(DataType, RowNames, nRowsOut, iRowsIn)
    % Select one row name every three
    if (length(iRowsIn) == 3 * nRowsOut) && (max(iRowsIn) <= length(RowNames))
        RowNames = RowNames(iRowsIn(1:3:end));
    end
    % Remove the ".1" appended to the scouts names
    if (isempty(DataType) || ismember(DataType, {'matrix','scout'})) && iscell(RowNames) && ischar(RowNames{1}) && (length(RowNames{1}) > 2) && strcmp(RowNames{1}(end-1:end), '.1')
        RowNames = cellfun(@(c)c(1:end-2), RowNames, 'UniformOutput', 0);
    end
end


