function data = fl_unwrap_conditions(data_wrapped,cdim)
% function data = fl_unwrap_conditions(data_wrapped)
%
% Unwraps an N-dimensional  matrix (condition_wrapped x ...) into an
% N+1 dimensional matrix [condition x condition x ...].
% Conditions were wrapped by converting to squareform (lower triangle of condition x condition matrix, see function squareform). condition_wrapped = condition*(condition-1)/2
%
% INPUTS:
%   data_wrapped: N-dimensional  matrix (condition_wrapped x ...)
%
% OUTPUTS:
%   data: N+1 dimensional matrix [condition x condition x ...]
%
% Author: Dimitrios Pantazis, MIT, September 2016
%

%ADD INPUT: which 2 dimensions to wrap

if ~exist('cdim')
    cdim = 1; %by default unwrap the first dimension
end

%initialize
N = ndims(data_wrapped); %number of dimensions
nd = size(data_wrapped); %dimensions
nd_left = nd; nd_left(cdim:end)=[]; %find dimensions left from conditions
nd_right = nd; nd_right(1:cdim)=[]; %find dimensions right from conditions
nd_cond_wrapped = nd(cdim); %condition dimensions (should be MxM)
ncond = (1 + sqrt(1 + 8*nd_cond_wrapped)) / 2; %since ncondsq = ncond*(ncond-1)/2

%dimension indexing
cln_left = repmat({':'},1,length(nd_left)); %to select the left dimensions
cln_right = repmat({':'},1,length(nd_right)); %to select the right dimensions

%find indices of lower & upper triangular matrix
ndx_tril = find(tril(ones(ncond,ncond),-1)); %indices of lower triangle
[x y] = ind2sub([ncond,ncond],ndx_tril); %trick, cannot use triu instead since order will be wrong
ndx_triu = sub2ind([ncond,ncond],y,x); %indices of upper triangle (with proper order)

%convert data_wrapped to data
data = zeros([nd_left ncond*ncond nd_right],'single');
data(cln_left{:},ndx_tril,cln_right{:}) = data_wrapped;
data(cln_left{:},ndx_triu,cln_right{:}) = data_wrapped;
data = reshape(data,[nd_left,ncond,ncond,nd_right]);



