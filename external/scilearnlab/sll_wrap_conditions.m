function data_wrapped = wrap_conditions(data,cdims)
% function data_wrapped = wrap_conditions(data,cdims)
%
% Converts an N-dimensional matrix from [condition x condition x ...] into [condition*(condition-1)/2 x ...]
% Conditions are wrapped by converting to squareform (lower triangle of condition x condition matrix). condition_wrapped = condition*(condition-1)/2
% 
% INPUTS:
%   data: N-dimensional matrix of dimensions (condition x condition x ...)
%       The additional dimensions are the measurement space (time points for MEG or EEG recordings, voxels for fMRI, electrodes for depth recordings, etc.)
%
% OUTPUTS:
%   data_wrapped: (N-1)-dimensional matrix (condition*(condition-1)/2 x ...)
%
% Author: Dimitrios Pantazis, MIT, September 2016
%

%initialize
N = ndims(data); %number of dimensions
nd = size(data); %data dimensions

if N == 2 %if 2D data
    data_wrapped = data(tril(true(nd(1)),-1));
else %if N-D data
    if ~exist('cdims')
        cdims = [1 2]; %by default wrap first 2 dimensions
    end
    nd_left = nd; nd_left(cdims(1):end)=[]; %find dimensions left from conditions
    nd_right = nd; nd_right(1:cdims(2))=[]; %find dimensions left from conditions
    nd_middle = nd(cdims); %condition dimensions (should be MxM)
    d_left = repmat({':'},1,cdims(1)-1); %length of dimensions
    d_right = repmat({':'},1,N-cdims(2));
    data_wrapped = reshape(data,[nd_left,nd_middle(1)^2,nd_right]); %condition x condition -> condition^2
    data_wrapped = data_wrapped(d_left{:},tril(true(nd_middle(1)),-1),d_right{:}); %keep lower triangle
end



