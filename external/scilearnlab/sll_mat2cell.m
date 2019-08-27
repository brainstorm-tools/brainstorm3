function [data_cell] = fl_mat2cell(data)


% Author: Dimitrios Pantazis

n = size(data,1);

for i = 1:n
    data_cell{i} = shiftdim(data(i,:,:),1);
end






