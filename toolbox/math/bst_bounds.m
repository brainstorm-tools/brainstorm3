function out = bst_bounds(A)
% Return the bounds of the matrix A:
% out = [min(A(:)), max(A(:))]
    
    if (bst_get('MatlabVersion') <= 1802) % if older than 2018b
        out = [min(A(:)), max(A(:))];
    else
        [minA,maxA] = bounds(A, 'all');
        out = [minA, maxA];
    end
    
end

