function VecInd  = bst_closest(VecGuess, VecRef)
% BST_CLOSEST: Find entries of closest elements between two vectors.
%
% USAGE:  VecInd  = bst_closest(VecGuess, VecRef);
%
% DESCRIPTION:
%     VecGuess is a vector for which one wants to find the closest entries in vector VecRef
%     VecInd is the vector of indices pointing atr the entries in vector VecRef that are the closest to VecWin
%     VecInd is of the length of VecGuess
% 
%     In other words, VecRef(VecInd(i)) is the element of VecRef closest to VecGuess(j)
% 
%     VecRef and VecGuess do not need to be the same length

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

if size(VecRef,1) == 1
    VecRef = VecRef';
end

tmp = repmat(VecRef,1,length(VecGuess));
[minn VecInd] = min(abs(repmat(VecGuess,length(VecRef),1) - tmp));



