function [normeM] = bst_inorcol(Mat)
% INORCOL: Compute the (pseudo)inverse of the column norms of matrix Mat.
%
% DESCRIPTION:
%     normeM is a sparse diagonal matrix whose diagonal elements 
%     are the inverse of the corresponding column norm of matrix Mat.
%     If a column is zero, then its inverse is set to zero as well.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
%
% Authors: John C Mosher, 2003

cn = sqrt(sum(Mat.*Mat,1)'); % sum only the rows into a column vector
Zero = max(cn)*eps; % relative concept of zero
ndx = cn > Zero;
cn(ndx) = 1 ./ cn(ndx); % zero values are kept zero for a pseudoinverse

normeM = spdiags(cn,0,length(cn),length(cn));



