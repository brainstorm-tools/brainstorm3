function bd = blk_diag(A,n)
%BLK_DIAG Make or extract a sparse block diagonal matrix
% function bd = blk_diag(A,n);
% If A is not sparse, then
% returns a sparse block diagonal "bd", diagonalized from the
% elements in "A".
% "A" is ma x na, comprising bdn=(na/"n") blocks of submatrices.
% Each submatrix is ma x "n", and these submatrices are
% placed down the diagonal of the matrix.
%
% If A is already sparse, then the operation is reversed, yielding a block
% row matrix, where each set of n columns corresponds to a block element
% from the block diagonal.
%
% Routine uses NO for-loops for speed considerations.

% Copyright (c) 1993-1995, The Regents of the University of California.
% This software was produced under a U.S. Government contract
% (W-7405-ENG-36) by Los Alamos National Laboratory, which is operated
% by the University of California for the U.S. Department of Energy,
% and was funded in part by NIH grant R01-MH53213 through the University
% of Southern California to Los Alamos National Laboratory, 
% and was funded in part by NIH grant R01-EY08610 to Los Alamos
% National Laboratory.
% The U.S. Government is licensed to use, reproduce, and distribute this
% software.  Permission is granted to the public to copy and use this
% software without charge, provided that this Notice and any statement
% of authorship are reproduced on all copies.  Neither the Government
% nor the University makes any warranty, express or implied, or assumes
% any liability or responsibility for the use of this software.
%
% Author: John C. Mosher, Ph.D.
% Los Alamos National Laboratory
% Group ESA-MT, MS J580
% Los Alamos, NM 87545
% email: mosher@LANL.Gov

% July 29, 1993 Author
% September 28, 1993 JCM Conversion to sparse
% July 27, 1995 JCM inverse block diagonal added

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@

if(~issparse(A)),		% then make block sparse
    [ma,na] = size(A);
    bdn = na/n; 			% number of submatrices
    
    if(bdn - fix(bdn)),
        error('Width of matrix must be even multiple of n');
    end
    
    if(0)
        i = [1:ma]';
        i = i(:,ones(1,n));
        i = i(:); 			% row indices first submatrix
        
        ml = length(i); 		% ma*n
        
        % ndx = [0:(bdn-1)]*ma; 	% row offsets per submatrix
        ndx = [0:ma:(ma*(bdn-1))]; 	% row offsets per submatrix
        
        i = i(:,ones(1,bdn)) + ndx(ones(ml,1),:);
    else
        tmp = reshape([1:(ma*bdn)]',ma,bdn);
        i = zeros(ma*n,bdn);
        for iblock = 1:n,
            i((iblock-1)*ma+[1:ma],:) = tmp;
        end
    end
    
    i = i(:); 			% row indices foreach sparse bd
    
    
    j = [1:na];
    j = j(ones(ma,1),:);
    j = j(:); 			% column indices foreach sparse bd
    
    bd = sparse(i,j,A(:));
    
else 				% already is sparse, unblock it
    
    [mA,na] = size(A);		% matrix always has na columns
    % how many entries in the first column?
    bdn = na/n;			% number of blocks
    ma = mA/bdn;			% rows in first block
    
    % blocks may themselves contain zero entries.  Build indexing as above
    if(0)
        i = [1:ma]';
        i = i(:,ones(1,n));
        i = i(:); 			% row indices first submatrix
        
        ml = length(i); 		% ma*n
        
        % ndx = [0:(bdn-1)]*ma; 	% row offsets per submatrix
        ndx = [0:ma:(ma*(bdn-1))]; 	% row offsets per submatrix
        
        i = i(:,ones(1,bdn)) + ndx(ones(ml,1),:);
    else
        tmp = reshape([1:(ma*bdn)]',ma,bdn);
        i = zeros(ma*n,bdn);
        for iblock = 1:n,
            i((iblock-1)*ma+[1:ma],:) = tmp;
        end
    end
    
    i = i(:); 			% row indices foreach sparse bd
    
    
    if(0)
        j = [1:na];
        j = j(ones(ma,1),:);
        j = j(:); 			% column indices foreach sparse bd
        
        % so now we have the complete two dimensional indexing. Convert to
        % one dimensional
        
        i = i + (j-1)*mA;
    else
        j = [0:mA:(mA*(na-1))];
        j = j(ones(ma,1),:);
        j = j(:);
        
        i = i + j;
    end
    
    bd = full(A(i)); 	% column vector
    bd = reshape(bd,ma,na);	% full matrix
end

