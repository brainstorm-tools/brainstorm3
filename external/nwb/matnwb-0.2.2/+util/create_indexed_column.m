function [data_vector, data_index] = create_indexed_column(data, path, ids, description, table)
%CREATE_INDEXED_COLUMN creates the index and vector NWB objects for storing
%a vector column in an NWB DynamicTable
%
%   [DATA_VECTOR, DATA_INDEX] = CREATE_INDEXED_COLUMN(DATA, PATH)
%   expects DATA as a cell array where each cell is all of the data
%   for a row and PATH is the path to the indexed data in the NWB file
%   EXAMPLE: [data_vector, data_index] = util.create_indexed_colum({[1,2,3], [1,2,3,4]}, '/units/spike_times')
%
%   [DATA_VECTOR, DATA_INDEX] = CREATE_INDEXED_COLUMN(DATA, PATH, IDS)
%   expects DATA as a single array 1D of doubles and IDS as a single 1D array of ints.
%   EXAMPLE: [data_vector, data_index] = util.create_indexed_colum([1,2,3,1,2,3,4], '/units/spike_times', [0,0,0,1,1,1,1])
%   
%   [DATA_VECTOR, DATA_INDEX] = CREATE_INDEXED_COLUMN(DATA, PATH, IDS, DESCRIPTION)
%   adds the string DESCRIPTION in the description field of the data vector
%   
%   [DYNAMICTABLEREGION, DATA_INDEX] = CREATE_INDEXED_COLUMN(DATA, PATH, IDS, DESCRIPTION, TABLE)
%   If TABLE is supplied as on ObjectView of an NWB DynamicTable, a
%   DynamicTableRegion is instead output which references this table.
%   DynamicTableRegions can be indexed just like DataVectors

if ~exist('description', 'var') || isempty(description)
    description = 'no description';
end

if ~exist('ids', 'var') || isempty(ids)
    bounds = NaN(length(data),1);
    for i = 1:length(data)
        bounds(i) = length(data{i});
    end
    bounds = int64(cumsum(bounds));
    data = cell2mat(data)';
else
    [sorted_ids, order] = sort(ids);
    data = data(order);
    bounds = int64([find(diff(sorted_ids)), length(ids)]);
end

if exist('table', 'var')
    data_vector = types.hdmf_common.DynamicTableRegion('table', table, ...
        'description', description, 'data', data);
else
    data_vector = types.hdmf_common.VectorData('data', data, 'description', description);
end

ov = types.untyped.ObjectView(path);
data_index = types.hdmf_common.VectorIndex('data', bounds, 'target', ov);


