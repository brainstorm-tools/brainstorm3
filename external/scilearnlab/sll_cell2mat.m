function [m] = fl_cell2mat(c)


% Author: Dimitrios Pantazis

n = length(c);
cln = repmat({':'},1,ndims(c{1})); %to select the variables
outclass = class(c{1});

m = zeros([n size(c{1})],outclass);
for i = 1:n
    m(i,cln{:}) = c{i};
end






