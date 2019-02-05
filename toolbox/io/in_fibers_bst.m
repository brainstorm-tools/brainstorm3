function FibMat = in_fibers_bst(FibFile, N)
% IN_FIBERS_BST: Read Brainstorm fibers file (tess_fibers_*.mat)
%
% USAGE:  FibMat = in_fibers_bst(FibFile);
%
% INPUT: 
%     - FibFile : full path to a fibers file
%     - N: Number of points per streamline (if different from input file)
% OUTPUT:
%     - FibMat:  Brainstorm fibers structure
%
% SEE ALSO: in_fibers

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Martin Cousineau, 2019

% Parse inputs
if (nargin < 2)
    N = [];
end

FibMat = load(file_fullpath(FibFile));

if ~isempty(N) && (N ~= size(FibMat.Points, 2))
    error('Cannot interpolate the number of coordinates from an already imported fibers file.');
end


