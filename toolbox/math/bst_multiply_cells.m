function out = bst_multiply_cells(ImageGridAmp)
%BST_MULTIPLY_CELLS. Given a list of array in ImageGridAmp, return the
% product of each array : 
% out = ImageGridAmp{1} * ImageGridAmp{2} * ... * ImageGridAmp{N}
    
    if length(ImageGridAmp) == 2

        out = ImageGridAmp{1} * ImageGridAmp{2};

    elseif size(ImageGridAmp{end}, 2) < size(ImageGridAmp{1}, 1) % multiply starting from the right

        out = ImageGridAmp{end};
        for iDecomposition = (length(ImageGridAmp) - 1) : -1 : 1
            out = ImageGridAmp{iDecomposition} * out;
        end

    else  % multiply starting from the left

        out = ImageGridAmp{1};
        for iDecomposition = 2 : length(ImageGridAmp)
            out = out * ImageGridAmp{iDecomposition};
        end

    end

    out = full(out);
end

