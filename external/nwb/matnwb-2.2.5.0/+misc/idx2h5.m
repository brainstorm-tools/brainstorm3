function h5idx = idx2h5(idx, matSize, opt)
%IDX2H5 converts MATLAB style linear index to HDF5-compatible region coordinates
% h5idx = IDX2H5(idx, matSize) Converts MATLAB linear index to HDF5 region coordinates.  Will squeeze unused dimensions out.
% idx = The MATLAB-styled linear index
% matSize = The MATLAB-styled matrix size
%
% h5idx = IDX2H5(idx, matSize, 'preserve') As above but coordinates will preserve dimension size

% option flag `preserve` specifies whether or not to condense indices
% the distinction is important if you're reading from either MATLAB or DataStub objects.
preserve = false;
if nargin > 2
    switch opt
        case 'preserve'
            preserve = true;
    end
end
if islogical(idx)
    idx = find(idx);
end

%transform indices to cell array containing linear index bounds
idx = unique(idx);
% find ranges in sorted indices.
rangeBreaks = find(diff(idx) ~= 1);
% subscripts in HDF5 are inclusive ranges, so for each rangePart prepend its preceding
% value
rangeParts = ones(numel(rangeBreaks) * 2 + 1, 1); % the first index is 1
rangeParts(2:2:end) = rangeBreaks;
rangeParts(3:2:end) = rangeBreaks + 1;

if mod(numel(rangeParts), 2) ~= 0
    %case where last rangePart is not paired with the end idx.
    rangeParts(end+1) = length(idx);
end

% transform linear ranges to subscripts
% compress matSize dimensions
% don't touch if preserved
if ~preserve
    if nargin == 1 || all(matSize == 1) || (numel(matSize) == 2 && any(matSize == 1))
        matSize = 1;
    else
        matSize = matSize(1:find(matSize > 1, 1, 'last'));
    end
end

if numel(matSize) > 1
    ranges = zeros(numel(matSize), numel(rangeParts));
    
    % ind2sub nargout is dependent on total size, so eval is necessary to dynamically
    % capture all outputs.
    assgn_str = 'ranges(1,:) ranges(2,:)';
    for i = 3:numel(matSize)
        assgn_str = strcat(assgn_str, [' ranges(' int2str(i) ',:)']);
    end
    
    eval(['[' assgn_str '] = ind2sub(matSize, idx(rangeParts));']);
else
    ranges = idx(rangeParts);
end
ranges = rot90(ranges, -1) - 1; %transpose; fliplr; convert to 0-indexed values
h5idx = mat2cell(ranges, repmat(2, size(ranges,1)/2, 1), size(ranges,2));
end