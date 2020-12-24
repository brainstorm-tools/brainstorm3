function data = read_indexed_column(vector_index, vector_data, row)
%READ_INDEXED_COLUMN returns the data for a specific row of an indexed vector
%
%   DATA = READ_INDEXED_COLUMN(VECTOR_INDEX, ROW) takes a VectorIndex from a
%   DynamicTable and a ROW number and outputs the DATA for that row (1-indexed).

try
    upper_bound = vector_index.data.load(row);
catch
    upper_bound = vector_index.data(row);
end
if row == 1
    lower_bound = 1;
else
    try
        lower_bound = vector_index.data.load(row - 1) + 1;
    catch
        lower_bound = vector_index.data(row - 1) + 1;
    end
end
%%
% Then select the corresponding spike_times_index element
data = vector_data.data(lower_bound:upper_bound);

