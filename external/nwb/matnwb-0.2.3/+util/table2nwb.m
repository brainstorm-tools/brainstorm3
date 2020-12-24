function nwbtable = table2nwb(T, description)
%TABLE2NWB converts from a MATLAB table to an NWB DynamicTable
%   NWBTABLE = TABLE2NWB(T) converts table T into a
%   types.core.DynamicTable
%
%   NWBTABLE = TABLE2NWB(T, DESCRIPTION) includes the DESCRIPTION in the 
%   DynamicTable 
% 
%EXAMPLE
%   T = table([.1, 1.5, 2.5]', [1., 2., 3.]', [0, 1, 0]', ...
%       'VariableNames', {'start', 'stop', 'condition'});
%NwbFile.trials = table2nwb(T, 'my description')

if ~exist('description', 'var')
    description = 'no description';
end

if ismember('id', T.Properties.VariableNames)
    id = T.id;
else
    id = 0:height(T)-1;
end

nwbtable = types.hdmf_common.DynamicTable( ...
    'colnames', T.Properties.VariableNames,...
    'description', description, ...
    'id', types.hdmf_common.ElementIdentifiers('data', id));

for col = T
    if ~strcmp(col.Properties.VariableNames{1},'id')
        nwbtable.vectordata.set(col.Properties.VariableNames{1}, ...
            types.hdmf_common.VectorData('data', col.Variables',...
            'description','my description'));
    end
end