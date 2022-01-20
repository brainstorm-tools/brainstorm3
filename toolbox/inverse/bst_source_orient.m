function [SourceValues, GridAtlas, RowNames] = bst_source_orient(iVertices, nComponents, GridAtlas, SourceValues, Function, DataType, RowNames)
% BST_SOURCE_ORIENT: Constrain source orientation for an unconstrained or mixed source model.
%
% USAGE:  SourceValues = bst_source_orient(iVertices=[], nComponents, GridAtlas, SourceValues, Function, DataType=[], RowNames=[])
%
% INPUT: 
%    - iVertices    : Array of vertex indices of the source space, to reference to rows in Results.GridLoc (volume) or Surface.Vertices (surface)
%                     If empty, use all the vertices
%    - nComponents  : Number of entries per vertex in SourceValues (1,2,3)
%                     If 0, the number varies, the properties of each region are defined in input GridAtlas
%    - GridAtlas    : Set of scouts that defines the properties of the source space regions, when nComponents=0
%                     GridAtlas.Scouts(i).Region(2) is the source type (V=volume, S=surface, D=dba, X=exclude)
%                     GridAtlas.Scouts(i).Region(3) is the orientation constrain (U=unconstrained, C=contrained, L=loose)
%    - SourceValues : [Nvertices x Nsensors] or [Nvertices x Ntime], source values
%    - Function     : Name of the function to apply to group multiple components {'sum', 'sum_power', 'rms', 'max', 'pca', 'mean'}
%    - DataType     : Type of data being processed {'data', 'results', 'scouts', 'matrix'}
%    - RowNames     : Description of signals being processed: {empty, array of doubles, array of cells}
%
% OUTPUT: 
%    - SourceValues : Constrained source values
%    - GridAtlas    : Modified atlas (unconstrained regions transformed into constrained regions)
%    - RowNames     : Description of the new list of signals

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
% Authors: Francois Tadel, 2014

% Parse inputs
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

% === MIXED SOURCE MODELS ===
if (nComponents == 0)
    % Check that GridAtlas is defined
    if isempty(GridAtlas) || ~isfield(GridAtlas, 'Scouts') || ~isfield(GridAtlas.Scouts, 'Vertices')
        error('GridAtlas variable is empty');
    end
    % Initialize blocks of indices
    SourceBlocks = {};
    RowNamesBlocks = {};
    % Loop on all the regions
    for iScout = 1:length(GridAtlas.Scouts)
        % Get the vertices for this scouts
        if ~isempty(iVertices)
            iVertGrid = intersect(iVertices, GridAtlas.Scouts(iScout).GridRows);
        else
            iVertGrid = GridAtlas.Scouts(iScout).GridRows;
        end
        % Convert to indices in the source matrix
        iVertSource = bst_convert_indices(iVertGrid, nComponents, GridAtlas, 0);
        % If no vertices to read from this region: skip
        if isempty(iVertSource)
            continue;
        end
        % Get correpsonding row indices based on the type of region (constrained or unconstrained)
        switch (GridAtlas.Scouts(iScout).Region(3))
            case 'C'
                SourceBlocks{end+1} = SourceValues(iVertSource,:,:,:);
            case {'U','L'}
                % Apply grouping function
                SourceBlocks{end+1} = ApplyFunction(SourceValues(iVertSource,:,:,:), 1:3:length(iVertSource), 2:3:length(iVertSource), 3:3:length(iVertSource), Function);
                % If the row names are defined
                if ~isempty(RowNames) && iscell(RowNames)
                    RowNamesBlocks{end+1} = RemoveComponentTag(DataType, reshape(RowNames,1,[]), size(SourceBlocks{end},1), iVertSource);
                end
                % Set that the region is now constrained
                GridAtlas.Scouts(iScout).Region(3) = 'C';
            otherwise
                error(['Invalid region "' GridAtlas.Scouts(iScout).Region '"']);
        end
    end
    % Concatenate all the blocks together
    SourceValues = cat(1, SourceBlocks{:});
    if ~isempty(RowNames) && iscell(RowNames)
        RowNames = cat(2, RowNamesBlocks{:});
    end
    % Modify the grid/row correspondance matrix
    if ~isempty(GridAtlas.Grid2Source)
        GridAtlas.Grid2Source = speye(size(SourceValues,1));
    end
    
    
% === SIMPLE SOURCE MODELS ===
else
    % Select only a few vertices
    if ~isempty(iVertices)
        % Convert to indices in the source matrix
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
            SourceValues = ApplyFunction(SourceValues(iVertSource,:,:,:), 1:2:length(iVertSource), 2:2:length(iVertSource), [], Function);
            % If the row names are defined
            if ~isempty(RowNames) && iscell(RowNames)
                RowNames = RemoveComponentTag(DataType, reshape(RowNames,1,[]), size(SourceValues,1), iVertSource);
            end
        case 3
            % Apply grouping function
            SourceValues = ApplyFunction(SourceValues(iVertSource,:,:,:), 1:3:length(iVertSource), 2:3:length(iVertSource), 3:3:length(iVertSource), Function);
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
function Values = ApplyFunction(Values, i1, i2, i3, Function)
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
        case 'pca'
            if ~isempty(i3)
                Values = bst_scout_value(Values, 'none', [], 3, 'pca', 0);
            else
                Values = bst_scout_value(Values, 'none', [], 2, 'pca', 0);
            end
        case 'none'
            % Nothing to do
        otherwise
            error(['Invalid function "' Function '".']);
    end
end


%% ===== REMOVE COMPONENT TAG =====
function RowNames = RemoveComponentTag(DataType, RowNames, nRows, iRows)
    % Select one row name every three
    if (length(iRows) == 3 * nRows) && (max(iRows) <= length(RowNames))
        RowNames = RowNames(iRows(1:3:end));
    end
    % Remove the ".1" appended to the scouts names
    if (isempty(DataType) || ismember(DataType, {'matrix','scout'})) && iscell(RowNames) && ischar(RowNames{1}) && (length(RowNames{1}) > 2) && strcmp(RowNames{1}(end-1:end), '.1')
        RowNames = cellfun(@(c)c(1:end-2), RowNames, 'UniformOutput', 0);
    end
end


